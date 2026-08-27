#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <assert.h>
#include "memory.h"
#include "union.h"
#include "utf8.h"
#include "dict.h"
#include "tuple.h"

// ============================================================================
// Dream 语言 GC 管理系统
// ============================================================================
// 核心特性：
// 1. 双模式引用计数：局部对象（非原子）+ 共享对象（原子）
// 2. Python 风格循环引用检测：引用计数差值法
// 3. 三代分代 GC：年轻代/中年代/老年代
// 4. 对象提升机制：局部对象可提升为共享对象
// 5. 完整的并发支持：原子操作 + 互斥锁
// ============================================================================

// 对象类型标记(定义于 memory.h)
// 对象作用域
typedef enum {
    SCOPE_LOCAL,   // 局部对象（80-90%）- 单线程独占
    SCOPE_SHARED,  // 共享对象（10-20%）- 可能跨线程
} ObjectScope;

// 对象头 - 所有堆分配对象的通用头部
typedef struct ObjectHeader {
    ObjectType type;
    ObjectScope scope;
    uint32_t size;           // 对象大小（字节）

    // 引用计数（局部用普通计数，共享用原子计数）
    union {
        uint32_t local_refs;              // 局部对象：非原子引用计数
        _Atomic(uint32_t) shared_refs;    // 共享对象：原子引用计数
    };

    // Python 风格循环引用检测
    uint32_t gc_refs;        // GC 临时引用计数（用于差值法）
    uint8_t gc_generation;   // 所属代（0, 1, 2）

    // 链表指针
    struct ObjectHeader* next;       // 全局对象链表
    struct ObjectHeader* hash_next;  // 地址哈希桶链
    struct ObjectHeader* gc_next;    // 容器对象双向链表
    struct ObjectHeader* gc_prev;
} ObjectHeader;

// 全局对象链表头（用于所有对象）
static ObjectHeader* g_object_list = NULL;
static pthread_mutex_t g_object_list_lock = PTHREAD_MUTEX_INITIALIZER;

// 对象地址哈希索引：加速 gc_is_managed 查找（替代线性链表扫描）
#define OBJECT_HASH_BUCKETS 65536
static ObjectHeader* g_object_hash[OBJECT_HASH_BUCKETS] = {0};

static size_t object_hash_index(const void* object) {
    return (((uintptr_t)object) >> 4) % OBJECT_HASH_BUCKETS;
}

// 容器对象链表头（用于循环引用检测）
static ObjectHeader g_container_list_head = {
    .type = OBJ_DYNARRAY,
    .scope = SCOPE_LOCAL,
    .size = 0,
    .local_refs = 1,
    .gc_refs = 0,
    .gc_generation = 0,
    .next = NULL,
    .gc_next = &g_container_list_head,
    .gc_prev = &g_container_list_head,
};
static pthread_mutex_t g_container_lock = PTHREAD_MUTEX_INITIALIZER;

// 分代 GC 结构
#define NUM_GENERATIONS 3
typedef struct {
    int threshold;           // 触发 GC 的对象分配数阈值
    int count;              // 当前代的对象分配计数
    size_t object_count;    // 当前代的对象数量
} GCGeneration;

static GCGeneration generations[NUM_GENERATIONS] = {
    { .threshold = 700, .count = 0, .object_count = 0 },  // Gen 0: 年轻代
    { .threshold = 10,  .count = 0, .object_count = 0 },  // Gen 1: 中年代
    { .threshold = 10,  .count = 0, .object_count = 0 },  // Gen 2: 老年代
};

// 小对象内存池配置
#define POOL_SIZE_CLASSES 8
static const size_t pool_sizes[POOL_SIZE_CLASSES] = {
    16, 32, 64, 128, 256, 512, 1024, 2048
};

// 大对象阈值 (1MB)
#define LARGE_OBJECT_THRESHOLD (1024 * 1024)

// 内存池节点
typedef struct PoolNode {
    struct PoolNode* next;
} PoolNode;

// 每个大小类别的内存池
typedef struct {
    PoolNode* free_list;
    size_t object_size;
    size_t allocated_count;
    pthread_mutex_t lock;    // 每个池一把锁
} MemoryPool;

static MemoryPool pools[POOL_SIZE_CLASSES];
static pthread_once_t pools_once = PTHREAD_ONCE_INIT;

// 统计信息
static struct {
    _Atomic(size_t) total_allocations;
    _Atomic(size_t) total_frees;
    _Atomic(size_t) bytes_allocated;
    _Atomic(size_t) bytes_freed;
    _Atomic(size_t) gc_runs;
    _Atomic(size_t) objects_collected;
    _Atomic(size_t) local_allocs;
    _Atomic(size_t) shared_allocs;
    _Atomic(size_t) promotions;
} gc_stats = {0};

// 前向声明
void gc_cleanup(void);
void gc_collect_generation(int generation);
void gc_detect_cycles(void);
void gc_retain(void* object);
void gc_release(void* object);

// ============================================================================
// 内存池管理
// ============================================================================

static void initialize_pools(void) {
    for (int i = 0; i < POOL_SIZE_CLASSES; i++) {
        pools[i].free_list = NULL;
        pools[i].object_size = pool_sizes[i];
        pools[i].allocated_count = 0;
        pthread_mutex_init(&pools[i].lock, NULL);
    }

    atexit(gc_cleanup);
}

static void init_pools(void) {
    pthread_once(&pools_once, initialize_pools);
}

static int find_pool_index(size_t size) {
    for (int i = 0; i < POOL_SIZE_CLASSES; i++) {
        if (size <= pool_sizes[i]) {
            return i;
        }
    }
    return -1;
}

static void* pool_alloc(int pool_index) {
    MemoryPool* pool = &pools[pool_index];

    pthread_mutex_lock(&pool->lock);

    if (pool->free_list == NULL) {
        const size_t batch_size = 64;
        for (size_t i = 0; i < batch_size; i++) {
            PoolNode* node = (PoolNode*)malloc(pool->object_size);
            if (node == NULL) {
                pthread_mutex_unlock(&pool->lock);
                return NULL;
            }
            node->next = pool->free_list;
            pool->free_list = node;
        }
    }

    PoolNode* node = pool->free_list;
    pool->free_list = node->next;
    pool->allocated_count++;

    pthread_mutex_unlock(&pool->lock);

    return node;
}

static void pool_free(void* ptr, int pool_index) {
    MemoryPool* pool = &pools[pool_index];
    PoolNode* node = (PoolNode*)ptr;

    pthread_mutex_lock(&pool->lock);
    node->next = pool->free_list;
    pool->free_list = node;
    pool->allocated_count--;
    pthread_mutex_unlock(&pool->lock);
}

// ============================================================================
// 辅助函数
// ============================================================================

static ObjectHeader* get_header(void* object) {
    if (object == NULL) return NULL;
    return (ObjectHeader*)((char*)object - sizeof(ObjectHeader));
}

static bool is_container(ObjectType type) {
    return (type == OBJ_DYNARRAY || type == OBJ_DYNARRAY_PTR ||
            type == OBJ_DICT || type == OBJ_TUPLE);
}

// 将容器对象加入容器链表
static void add_to_container_list(ObjectHeader* header) {
    pthread_mutex_lock(&g_container_lock);

    // 插入到链表头部
    header->gc_next = g_container_list_head.gc_next;
    header->gc_prev = &g_container_list_head;
    g_container_list_head.gc_next->gc_prev = header;
    g_container_list_head.gc_next = header;

    pthread_mutex_unlock(&g_container_lock);
}

// 从容器链表移除
static void remove_from_container_list(ObjectHeader* header) {
    pthread_mutex_lock(&g_container_lock);

    if (header->gc_next != NULL && header->gc_prev != NULL) {
        header->gc_prev->gc_next = header->gc_next;
        header->gc_next->gc_prev = header->gc_prev;
        header->gc_next = NULL;
        header->gc_prev = NULL;
    }

    pthread_mutex_unlock(&g_container_lock);
}

static ObjectHeader* find_managed_header_locked(const void* object) {
    size_t bucket = object_hash_index(object);
    for (ObjectHeader* header = g_object_hash[bucket]; header != NULL; header = header->hash_next) {
        void* managed_object = (void*)((char*)header + sizeof(ObjectHeader));
        if (managed_object == object) return header;
    }
    return NULL;
}

bool gc_is_managed(const void* object) {
    if (object == NULL) return false;

    pthread_mutex_lock(&g_object_list_lock);
    bool is_managed = find_managed_header_locked(object) != NULL;
    pthread_mutex_unlock(&g_object_list_lock);
    return is_managed;
}

void gc_retain_if_managed(void* object) {
    if (gc_is_managed(object)) gc_retain(object);
}

void gc_release_if_managed(void* object) {
    if (gc_is_managed(object)) gc_release(object);
}

// ============================================================================
// 对象分配函数
// ============================================================================

// 分配局部对象（无原子操作，快速）
void* gc_alloc_local(size_t size, ObjectType type) {
    init_pools();

    size_t total_size = sizeof(ObjectHeader) + size;
    int pool_index = find_pool_index(total_size);

    void* memory;
    if (pool_index >= 0) {
        memory = pool_alloc(pool_index);
    } else {
        memory = malloc(total_size);
    }

    if (memory == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        return NULL;
    }

    ObjectHeader* header = (ObjectHeader*)memory;
    header->type = type;
    header->scope = SCOPE_LOCAL;
    header->size = size;
    header->local_refs = 1;  // 非原子
    header->gc_refs = 0;
    header->gc_generation = 0;  // 从年轻代开始
    header->gc_next = NULL;
    header->gc_prev = NULL;

    // 加入全局对象链表与地址哈希索引
    pthread_mutex_lock(&g_object_list_lock);
    header->next = g_object_list;
    g_object_list = header;
    header->hash_next = g_object_hash[object_hash_index(memory + sizeof(ObjectHeader))];
    g_object_hash[object_hash_index(memory + sizeof(ObjectHeader))] = header;
    pthread_mutex_unlock(&g_object_list_lock);

    // 容器对象加入容器链表
    if (is_container(type)) {
        add_to_container_list(header);
    }

    // 更新统计
    atomic_fetch_add(&gc_stats.total_allocations, 1);
    atomic_fetch_add(&gc_stats.bytes_allocated, total_size);
    atomic_fetch_add(&gc_stats.local_allocs, 1);

    return (void*)((char*)memory + sizeof(ObjectHeader));
}

// 分配共享对象（使用原子操作）
void* gc_alloc_shared(size_t size, ObjectType type) {
    init_pools();

    size_t total_size = sizeof(ObjectHeader) + size;
    int pool_index = find_pool_index(total_size);

    void* memory;
    if (pool_index >= 0) {
        memory = pool_alloc(pool_index);
    } else {
        memory = malloc(total_size);
    }

    if (memory == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        return NULL;
    }

    ObjectHeader* header = (ObjectHeader*)memory;
    header->type = type;
    header->scope = SCOPE_SHARED;
    header->size = size;
    atomic_store(&header->shared_refs, 1);  // 原子操作
    header->gc_refs = 0;
    header->gc_generation = 0;
    header->gc_next = NULL;
    header->gc_prev = NULL;

    // 加入全局对象链表与地址哈希索引
    pthread_mutex_lock(&g_object_list_lock);
    header->next = g_object_list;
    g_object_list = header;
    header->hash_next = g_object_hash[object_hash_index(memory + sizeof(ObjectHeader))];
    g_object_hash[object_hash_index(memory + sizeof(ObjectHeader))] = header;
    pthread_mutex_unlock(&g_object_list_lock);

    // 容器对象加入容器链表
    if (is_container(type)) {
        add_to_container_list(header);

        // 容器对象分配计数（用于触发 GC）
        generations[0].count++;
        if (generations[0].count >= generations[0].threshold) {
            gc_collect_generation(0);
        }
    }

    // 更新统计
    atomic_fetch_add(&gc_stats.total_allocations, 1);
    atomic_fetch_add(&gc_stats.bytes_allocated, total_size);
    atomic_fetch_add(&gc_stats.shared_allocs, 1);

    return (void*)((char*)memory + sizeof(ObjectHeader));
}

// 通用分配函数（默认使用局部分配）
void* gc_alloc(size_t size, ObjectType type) {
    return gc_alloc_local(size, type);
}

// ============================================================================
// 接口值对象装箱（引用计数管理，由编译器在函数返回前释放未逃逸对象）
// ============================================================================

void* dream_interface_alloc(int64_t size) {
    if (size < 0) return NULL;
    return gc_alloc((size_t)size, OBJ_INTERFACE);
}

void dream_interface_release(void* object) {
    gc_release(object);
}

// 接口 box：{对象指针, 类型 tag}，tag 为 struct 声明索引
typedef struct {
    void* object;
    int32_t tag;
} dream_interface_box_t;

void* __c_interface_box(void* object, int32_t tag) {
    dream_interface_box_t* box = (dream_interface_box_t*)gc_alloc(sizeof(dream_interface_box_t), OBJ_INTERFACE);
    if (!box) return NULL;
    box->object = object;
    box->tag = tag;
    return box;
}

void* __c_interface_obj(void* box) {
    if (!box) return NULL;
    return ((dream_interface_box_t*)box)->object;
}

int32_t __c_interface_tag(void* box) {
    if (!box) return -1;
    return ((dream_interface_box_t*)box)->tag;
}

// ============================================================================
// 引用计数操作
// ============================================================================

// 增加引用计数
void gc_retain(void* object) {
    if (object == NULL) return;

    ObjectHeader* header = get_header(object);

    if (header->scope == SCOPE_LOCAL) {
        header->local_refs++;  // 快速路径：非原子操作
    } else {
        atomic_fetch_add(&header->shared_refs, 1);  // 慢速路径：原子操作
    }
}

// 减少引用计数
void gc_release(void* object) {
    if (object == NULL) return;

    ObjectHeader* header = get_header(object);
    uint32_t new_count;

    if (header->scope == SCOPE_LOCAL) {
        assert(header->local_refs > 0);
        new_count = --header->local_refs;
    } else {
        uint32_t old_count = atomic_fetch_sub(&header->shared_refs, 1);
        assert(old_count > 0);
        new_count = old_count - 1;
    }

    // 引用计数归零，释放对象
    if (new_count == 0) {
        // 从容器链表移除
        if (is_container(header->type)) {
            remove_from_container_list(header);
        }

        // 从全局链表与地址哈希索引移除
        pthread_mutex_lock(&g_object_list_lock);
        ObjectHeader** current = &g_object_list;
        while (*current != NULL) {
            if (*current == header) {
                *current = header->next;
                break;
            }
            current = &((*current)->next);
        }
        ObjectHeader** hash_current = &g_object_hash[object_hash_index(object)];
        while (*hash_current != NULL) {
            if (*hash_current == header) {
                *hash_current = header->hash_next;
                break;
            }
            hash_current = &((*hash_current)->hash_next);
        }
        pthread_mutex_unlock(&g_object_list_lock);

        // 特定类型的清理
        void* obj_data = object;
        if (header->type == OBJ_STRING) {
            utf8_cache_forget(obj_data);
        }
        switch (header->type) {
            case OBJ_DYNARRAY: {
                typedef struct {
                    int capacity;
                    int length;
                    void* data;
                } DynArrayData;

                DynArrayData* arr = (DynArrayData*)obj_data;
                if (arr->data != NULL) {
                    free(arr->data);
                }
                break;
            }
            case OBJ_DYNARRAY_PTR: {
                dynarray_ptr* arr = (dynarray_ptr*)obj_data;
                if (arr->data != NULL) {
                    for (int index = 0; index < arr->length; index++) {
                        gc_release_if_managed((void*)arr->data[index]);
                    }
                    free(arr->data);
                }
                break;
            }
            case OBJ_DICT:
                dict_release_contents((dict_t*)obj_data);
                break;
            case OBJ_TUPLE: {
                tuple_t* tuple = (tuple_t*)obj_data;
                free(tuple->elements);
                tuple->elements = NULL;
                break;
            }
            case OBJ_UNION: {
                union_t* u = (union_t*)obj_data;
                if (u->tag == UNION_STRING && u->value.as_string != NULL) {
                    free(u->value.as_string);
                }
                if (u->tag == UNION_STRUCT && u->type_name != NULL) {
                    free(u->type_name);
                }
                break;
            }
            case OBJ_ENUM: {
                // Enum 类型的清理（释放数据指针）
                typedef struct {
                    int32_t tag;
                    void* data;
                } enum_t;

                enum_t* e = (enum_t*)obj_data;
                if (e->data != NULL) {
                    free(e->data);
                }
                break;
            }
            default:
                break;
        }

        // 释放内存
        size_t total_size = sizeof(ObjectHeader) + header->size;
        int pool_index = find_pool_index(total_size);

        if (pool_index >= 0) {
            pool_free(header, pool_index);
        } else {
            free(header);
        }

        atomic_fetch_add(&gc_stats.total_frees, 1);
        atomic_fetch_add(&gc_stats.bytes_freed, total_size);
    }
}

// 获取当前引用计数（用于调试）
uint32_t gc_get_ref_count(void* object) {
    if (object == NULL) return 0;
    ObjectHeader* header = get_header(object);

    if (header->scope == SCOPE_LOCAL) {
        return header->local_refs;
    } else {
        return atomic_load(&header->shared_refs);
    }
}

// ============================================================================
// 对象提升机制（局部 -> 共享）
// ============================================================================

// 提升对象为共享对象
void gc_promote_to_shared(void* object) {
    if (!object) return;

    ObjectHeader* h = get_header(object);
    if (h->scope == SCOPE_SHARED) return;  // 已经是共享对象

    // 提升为共享对象
    uint32_t local_count = h->local_refs;
    h->scope = SCOPE_SHARED;
    atomic_store(&h->shared_refs, local_count);

    atomic_fetch_add(&gc_stats.promotions, 1);

    if (h->type == OBJ_DYNARRAY_PTR) {
        dynarray_ptr* arr = (dynarray_ptr*)object;
        for (int index = 0; arr->data != NULL && index < arr->length; index++) {
            void* child = (void*)arr->data[index];
            if (gc_is_managed(child)) gc_promote_to_shared(child);
        }
    } else if (h->type == OBJ_DICT) {
        dict_t* dict = (dict_t*)object;
        if (dict->val_type == DICT_VAL_PTR && dict->buckets != NULL) {
            for (int bucket_index = 0; bucket_index < dict->capacity; bucket_index++) {
                for (dict_entry_t* entry = dict->buckets[bucket_index];
                     entry != NULL; entry = entry->next) {
                    if (gc_is_managed(entry->value)) {
                        gc_promote_to_shared(entry->value);
                    }
                }
            }
        }
    }
}

// ============================================================================
// Python 风格循环引用检测（引用计数差值法）
// ============================================================================

// 减少子对象的 gc_refs
static void subtract_refs_from_children(ObjectHeader* obj) {
    switch (obj->type) {
        case OBJ_DYNARRAY:
            // dynarray_i32 不包含对象引用，不能进行指针遍历。
            break;
        case OBJ_DYNARRAY_PTR: {
            dynarray_ptr* arr = (dynarray_ptr*)((char*)obj + sizeof(ObjectHeader));
            for (int index = 0; arr->data != NULL && index < arr->length; index++) {
                void* child = (void*)arr->data[index];
                pthread_mutex_lock(&g_object_list_lock);
                ObjectHeader* child_header = find_managed_header_locked(child);
                if (child_header != NULL && child_header->gc_refs > 0) {
                    child_header->gc_refs--;
                }
                pthread_mutex_unlock(&g_object_list_lock);
            }
            break;
        }
        case OBJ_DICT: {
            dict_t* dict = (dict_t*)((char*)obj + sizeof(ObjectHeader));
            if (dict->val_type != DICT_VAL_PTR || dict->buckets == NULL) break;
            for (int bucket_index = 0; bucket_index < dict->capacity; bucket_index++) {
                for (dict_entry_t* entry = dict->buckets[bucket_index];
                     entry != NULL; entry = entry->next) {
                    pthread_mutex_lock(&g_object_list_lock);
                    ObjectHeader* child_header = find_managed_header_locked(entry->value);
                    if (child_header != NULL && child_header->gc_refs > 0) {
                        child_header->gc_refs--;
                    }
                    pthread_mutex_unlock(&g_object_list_lock);
                }
            }
            break;
        }
        case OBJ_TUPLE:
            // tuple_t 当前只保存 i32，不包含对象引用。
            break;

        default:
            break;
    }
}

// Python 风格的循环引用检测
void gc_detect_cycles() {
    pthread_mutex_lock(&g_container_lock);

    // 第 1 步：复制引用计数到 gc_refs
    ObjectHeader* obj = g_container_list_head.gc_next;
    while (obj != &g_container_list_head) {
        if (obj->scope == SCOPE_LOCAL) {
            obj->gc_refs = obj->local_refs;
        } else {
            obj->gc_refs = atomic_load(&obj->shared_refs);
        }
        obj = obj->gc_next;
    }

    // 第 2 步：遍历容器，减少被引用对象的 gc_refs
    obj = g_container_list_head.gc_next;
    while (obj != &g_container_list_head) {
        subtract_refs_from_children(obj);
        obj = obj->gc_next;
    }

    // 第 3 步：gc_refs == 0 的对象是循环引用，释放它们
    obj = g_container_list_head.gc_next;
    size_t collected = 0;

    while (obj != &g_container_list_head) {
        ObjectHeader* next = obj->gc_next;

        if (obj->gc_refs == 0) {
            // 循环引用，强制释放

            // 从容器链表移除
            obj->gc_prev->gc_next = obj->gc_next;
            obj->gc_next->gc_prev = obj->gc_prev;

            // 从全局链表与地址哈希索引移除
            pthread_mutex_lock(&g_object_list_lock);
            ObjectHeader** current = &g_object_list;
            while (*current != NULL) {
                if (*current == obj) {
                    *current = obj->next;
                    break;
                }
                current = &((*current)->next);
            }
            ObjectHeader** hash_current = &g_object_hash[object_hash_index((char*)obj + sizeof(ObjectHeader))];
            while (*hash_current != NULL) {
                if (*hash_current == obj) {
                    *hash_current = obj->hash_next;
                    break;
                }
                hash_current = &((*hash_current)->hash_next);
            }
            pthread_mutex_unlock(&g_object_list_lock);

            // 清理对象数据
            void* object = (void*)((char*)obj + sizeof(ObjectHeader));
            switch (obj->type) {
                case OBJ_DYNARRAY: {
                    typedef struct {
                        int capacity;
                        int length;
                        void* data;
                    } DynArrayData;

                    DynArrayData* arr = (DynArrayData*)object;
                    if (arr->data != NULL) {
                        free(arr->data);
                    }
                    break;
                }
                case OBJ_DYNARRAY_PTR: {
                    dynarray_ptr* arr = (dynarray_ptr*)object;
                    free(arr->data);
                    break;
                }
                case OBJ_DICT:
                    dict_destroy_contents((dict_t*)object);
                    break;
                case OBJ_TUPLE: {
                    tuple_t* tuple = (tuple_t*)object;
                    free(tuple->elements);
                    break;
                }
                default:
                    break;
            }

            // 释放内存
            size_t total_size = sizeof(ObjectHeader) + obj->size;
            int pool_index = find_pool_index(total_size);

            if (pool_index >= 0) {
                pool_free(obj, pool_index);
            } else {
                free(obj);
            }

            collected++;
            atomic_fetch_add(&gc_stats.total_frees, 1);
            atomic_fetch_add(&gc_stats.bytes_freed, total_size);
        }

        obj = next;
    }

    pthread_mutex_unlock(&g_container_lock);

    atomic_fetch_add(&gc_stats.objects_collected, collected);
}

// ============================================================================
// 分代 GC
// ============================================================================

// 分代垃圾回收
void gc_collect_generation(int generation) {
    if (generation < 0 || generation >= NUM_GENERATIONS) return;
    generations[generation].count = 0;
    gc_detect_cycles();
    atomic_fetch_add(&gc_stats.gc_runs, 1);
}

// 强制运行垃圾回收
void gc_collect(void) {
    gc_detect_cycles();
    atomic_fetch_add(&gc_stats.gc_runs, 1);
}

// ============================================================================
// 统计和清理
// ============================================================================

// 打印 GC 统计信息
void gc_print_stats() {
    printf("=== Dream GC Statistics ===\n");
    printf("Total allocations: %zu\n", atomic_load(&gc_stats.total_allocations));
    printf("  - Local:  %zu\n", atomic_load(&gc_stats.local_allocs));
    printf("  - Shared: %zu\n", atomic_load(&gc_stats.shared_allocs));
    printf("Total frees: %zu\n", atomic_load(&gc_stats.total_frees));
    printf("Bytes allocated: %zu\n", atomic_load(&gc_stats.bytes_allocated));
    printf("Bytes freed: %zu\n", atomic_load(&gc_stats.bytes_freed));
    printf("GC runs: %zu\n", atomic_load(&gc_stats.gc_runs));
    printf("Objects collected: %zu\n", atomic_load(&gc_stats.objects_collected));
    printf("Promotions (local->shared): %zu\n", atomic_load(&gc_stats.promotions));
    printf("Live objects: %zu\n",
           atomic_load(&gc_stats.total_allocations) - atomic_load(&gc_stats.total_frees));
    printf("==============================\n");
}

// 清理所有内存（程序退出时调用）
void gc_cleanup() {
    pthread_mutex_lock(&g_object_list_lock);

    ObjectHeader* obj = g_object_list;
    while (obj != NULL) {
        ObjectHeader* next = obj->next;

        // 清理对象数据
        void* object = (void*)((char*)obj + sizeof(ObjectHeader));
        if (obj->type == OBJ_STRING) {
            utf8_cache_forget(object);
        }
        switch (obj->type) {
            case OBJ_DYNARRAY: {
                typedef struct {
                    int capacity;
                    int length;
                    void* data;
                } DynArrayData;

                DynArrayData* arr = (DynArrayData*)object;
                if (arr->data != NULL) {
                    free(arr->data);
                }
                break;
            }
            case OBJ_DYNARRAY_PTR: {
                dynarray_ptr* arr = (dynarray_ptr*)object;
                free(arr->data);
                break;
            }
            case OBJ_DICT:
                dict_destroy_contents((dict_t*)object);
                break;
            case OBJ_TUPLE: {
                tuple_t* tuple = (tuple_t*)object;
                free(tuple->elements);
                break;
            }
            case OBJ_UNION: {
                union_t* u = (union_t*)object;
                if (u->tag == UNION_STRING && u->value.as_string != NULL) {
                    free(u->value.as_string);
                }
                if (u->tag == UNION_STRUCT && u->type_name != NULL) {
                    free(u->type_name);
                }
                break;
            }
            case OBJ_ENUM: {
                // Enum 类型的清理（释放数据指针）
                typedef struct {
                    int32_t tag;
                    void* data;
                } enum_t;

                enum_t* e = (enum_t*)object;
                if (e->data != NULL) {
                    free(e->data);
                }
                break;
            }
            default:
                break;
        }

        free(obj);
        obj = next;
    }

    g_object_list = NULL;
    memset(g_object_hash, 0, sizeof(g_object_hash));
    pthread_mutex_unlock(&g_object_list_lock);
}
