#include "enum.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
// 枚举创建函数（使用 GC 内存分配）
// ============================================================================

enum_t* enum_create_simple(int32_t tag) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;
    e->data = NULL;
    return e;
}

enum_t* enum_create_int(int32_t tag, int32_t value) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;

    // 为 int 分配内存
    int32_t* data = (int32_t*)malloc(sizeof(int32_t));
    if (!data) {
        gc_release(e);
        return NULL;
    }
    *data = value;
    e->data = data;
    return e;
}

enum_t* enum_create_float(int32_t tag, double value) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;

    double* data = (double*)malloc(sizeof(double));
    if (!data) {
        gc_release(e);
        return NULL;
    }
    *data = value;
    e->data = data;
    return e;
}

enum_t* enum_create_string(int32_t tag, const char* value) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;

    // 复制字符串
    e->data = strdup(value);
    if (!e->data && value != NULL) {
        gc_release(e);
        return NULL;
    }
    return e;
}

enum_t* enum_create_bool(int32_t tag, bool value) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;

    // 为 bool 分配内存
    bool* data = (bool*)malloc(sizeof(bool));
    if (!data) {
        gc_release(e);
        return NULL;
    }
    *data = value;
    e->data = data;
    return e;
}

enum_t* enum_create_tuple(int32_t tag, void* data, size_t data_size) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;

    if (data_size > 0 && data != NULL) {
        // 复制元组数据
        e->data = malloc(data_size);
        if (!e->data) {
            gc_release(e);
            return NULL;
        }
        memcpy(e->data, data, data_size);
    } else {
        e->data = NULL;
    }
    return e;
}

enum_t* enum_create_tuple_ptr(int32_t tag, void* tuple_ptr) {
    enum_t* e = (enum_t*)gc_alloc(sizeof(enum_t), OBJ_ENUM);
    if (!e) return NULL;
    e->tag = tag;
    // 直接存储元组指针，不复制
    e->data = tuple_ptr;
    return e;
}

// ============================================================================
// 枚举类型检查
// ============================================================================

bool enum_is_variant(enum_t* e, int32_t tag) {
    return e != NULL && e->tag == tag;
}

int32_t enum_get_tag(enum_t* e) {
    if (e == NULL) return -1;
    return e->tag;
}

// ============================================================================
// 枚举值提取
// ============================================================================

int32_t enum_get_int(enum_t* e) {
    if (e == NULL || e->data == NULL) return 0;
    return *(int32_t*)e->data;
}

double enum_get_float(enum_t* e) {
    if (e == NULL || e->data == NULL) return 0.0;
    return *(double*)e->data;
}

char* enum_get_string(enum_t* e) {
    if (e == NULL || e->data == NULL) return "";
    return (char*)e->data;
}

bool enum_get_bool(enum_t* e) {
    if (e == NULL || e->data == NULL) return false;
    return *(bool*)e->data;
}

void* enum_get_data(enum_t* e) {
    if (e == NULL) return NULL;
    return e->data;
}

// ============================================================================
// 枚举内存管理（GC 集成）
// ============================================================================

void enum_retain(enum_t* e) {
    if (e == NULL) return;
    gc_retain(e);
}

void enum_release(enum_t* e) {
    if (e == NULL) return;
    gc_release(e);
}

void enum_free(enum_t* e) {
    // enum_free 是 enum_release 的别名
    enum_release(e);
}

enum_t* enum_clone(enum_t* e) {
    if (e == NULL) return NULL;

    // 简化实现：假设数据是基本类型或字符串
    // 对于复杂类型，需要知道数据大小
    if (e->data == NULL) {
        return enum_create_simple(e->tag);
    }

    // 这里简化处理，实际应该根据变体类型来决定如何克隆
    // 暂时不实现完整的克隆
    return NULL;
}

// ============================================================================
// 枚举调试
// ============================================================================

void enum_print(enum_t* e) {
    if (e == NULL) {
        printf("NULL");
        return;
    }

    printf("Enum(tag=%d, data=%p)", e->tag, e->data);
}

void enum_print_value(enum_t* e) {
    if (e == NULL) {
        printf("(null)\n");
        return;
    }

    // 简化输出，只打印 tag
    // 实际应该根据枚举定义来格式化输出
    printf("Variant(%d)\n", e->tag);
}
