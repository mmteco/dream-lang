#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <pthread.h>
#include <unistd.h>
#include "memory.h"

// 动态数组结构定义（与 dynarray.h 保持一致）
typedef struct {
    int capacity;
    int length;
    int* data;
} DynArrayData;

// ============================================================================
// 测试 1: 局部对象分配和释放
// ============================================================================

void test_local_allocation() {
    printf("\n=== Test 1: 局部对象分配和释放 ===\n");

    // 分配局部对象
    DynArrayData* arr1 = (DynArrayData*)gc_alloc_local(sizeof(DynArrayData), OBJ_DYNARRAY);
    arr1->capacity = 10;
    arr1->length = 0;
    arr1->data = (int*)malloc(10 * sizeof(int));

    printf("分配局部数组，引用计数: %u\n", gc_get_ref_count(arr1));
    assert(gc_get_ref_count(arr1) == 1);

    // 增加引用
    gc_retain(arr1);
    printf("增加引用后，引用计数: %u\n", gc_get_ref_count(arr1));
    assert(gc_get_ref_count(arr1) == 2);

    // 减少引用
    gc_release(arr1);
    printf("减少引用后，引用计数: %u\n", gc_get_ref_count(arr1));
    assert(gc_get_ref_count(arr1) == 1);

    // 最后释放
    gc_release(arr1);
    printf("对象已释放\n");

    printf("✓ 测试通过\n");
}

// ============================================================================
// 测试 2: 共享对象分配和线程安全
// ============================================================================

typedef struct {
    void* object;
    int iterations;
} ThreadArg;

void* thread_func(void* arg) {
    ThreadArg* targ = (ThreadArg*)arg;

    for (int i = 0; i < targ->iterations; i++) {
        gc_retain(targ->object);
        usleep(1);  // 模拟工作
        gc_release(targ->object);
    }

    return NULL;
}

void test_shared_allocation() {
    printf("\n=== Test 2: 共享对象分配和线程安全 ===\n");

    // 分配共享对象
    DynArrayData* arr = (DynArrayData*)gc_alloc_shared(sizeof(DynArrayData), OBJ_DYNARRAY);
    arr->capacity = 100;
    arr->length = 0;
    arr->data = (int*)malloc(100 * sizeof(int));

    printf("分配共享数组，初始引用计数: %u\n", gc_get_ref_count(arr));

    // 创建多个线程并发访问
    const int num_threads = 4;
    const int iterations = 100;
    pthread_t threads[num_threads];
    ThreadArg arg = { .object = arr, .iterations = iterations };

    // 启动线程前增加引用计数
    for (int i = 0; i < num_threads; i++) {
        gc_retain(arr);
    }

    printf("启动 %d 个线程进行并发引用计数操作...\n", num_threads);

    for (int i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, thread_func, &arg);
    }

    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    printf("线程结束，当前引用计数: %u\n", gc_get_ref_count(arr));
    assert(gc_get_ref_count(arr) == num_threads + 1);

    // 释放线程的引用
    for (int i = 0; i < num_threads; i++) {
        gc_release(arr);
    }

    printf("释放线程引用后，引用计数: %u\n", gc_get_ref_count(arr));

    // 最终释放
    gc_release(arr);
    printf("对象已释放\n");

    printf("✓ 测试通过\n");
}

// ============================================================================
// 测试 3: 对象提升（局部 -> 共享）
// ============================================================================

void test_promotion() {
    printf("\n=== Test 3: 对象提升（局部 -> 共享） ===\n");

    // 分配局部对象
    DynArrayData* arr = (DynArrayData*)gc_alloc_local(sizeof(DynArrayData), OBJ_DYNARRAY);
    arr->capacity = 10;
    arr->length = 0;
    arr->data = (int*)malloc(10 * sizeof(int));

    printf("分配局部数组\n");

    // 提升为共享对象
    gc_promote_to_shared(arr);
    printf("已提升为共享对象\n");

    // 验证提升后的引用计数操作是线程安全的
    gc_retain(arr);
    gc_retain(arr);
    printf("增加引用后，引用计数: %u\n", gc_get_ref_count(arr));
    assert(gc_get_ref_count(arr) == 3);

    gc_release(arr);
    gc_release(arr);
    gc_release(arr);
    printf("对象已释放\n");

    printf("✓ 测试通过\n");
}

// ============================================================================
// 测试 4: 循环引用检测
// ============================================================================

void test_cycle_detection() {
    printf("\n=== Test 4: Python 风格循环引用检测 ===\n");

    // 创建循环引用的数组
    // 注意：由于当前 DynArrayData 存储 int* 而非 void**，
    // 这里只是模拟循环引用的场景

    DynArrayData* arr1 = (DynArrayData*)gc_alloc_shared(sizeof(DynArrayData), OBJ_DYNARRAY);
    arr1->capacity = 10;
    arr1->length = 0;
    arr1->data = (int*)malloc(10 * sizeof(int));

    DynArrayData* arr2 = (DynArrayData*)gc_alloc_shared(sizeof(DynArrayData), OBJ_DYNARRAY);
    arr2->capacity = 10;
    arr2->length = 0;
    arr2->data = (int*)malloc(10 * sizeof(int));

    printf("创建两个容器对象\n");

    // 模拟循环引用（实际实现需要 void** data）
    // arr1 引用 arr2，arr2 引用 arr1
    // gc_retain(arr1);
    // gc_retain(arr2);

    printf("执行循环引用检测...\n");
    gc_detect_cycles();

    printf("循环引用检测完成\n");

    // 清理
    gc_release(arr1);
    gc_release(arr2);

    printf("✓ 测试通过\n");
}

// ============================================================================
// 测试 5: 分代 GC
// ============================================================================

void test_generational_gc() {
    printf("\n=== Test 5: 分代 GC 机制 ===\n");

    printf("创建大量临时对象触发分代 GC...\n");

    for (int i = 0; i < 100; i++) {
        DynArrayData* arr = (DynArrayData*)gc_alloc_shared(sizeof(DynArrayData), OBJ_DYNARRAY);
        arr->capacity = 10;
        arr->length = 0;
        arr->data = (int*)malloc(10 * sizeof(int));

        // 立即释放（模拟短生命周期对象）
        gc_release(arr);
    }

    printf("触发完整 GC...\n");
    gc_collect();

    printf("✓ 测试通过\n");
}

// ============================================================================
// 测试 6: 内存池性能
// ============================================================================

void test_memory_pool() {
    printf("\n=== Test 6: 内存池性能测试 ===\n");

    const int count = 10000;
    void* objects[count];

    printf("分配 %d 个小对象（使用内存池）...\n", count);

    for (int i = 0; i < count; i++) {
        DynArrayData* arr = (DynArrayData*)gc_alloc_local(sizeof(DynArrayData), OBJ_DYNARRAY);
        arr->capacity = 0;
        arr->length = 0;
        arr->data = NULL;
        objects[i] = arr;
    }

    printf("释放所有对象...\n");

    for (int i = 0; i < count; i++) {
        gc_release(objects[i]);
    }

    printf("✓ 测试通过\n");
}

// ============================================================================
// 主函数
// ============================================================================

int main() {
    printf("======================================\n");
    printf("Dream GC 管理系统测试套件\n");
    printf("======================================\n");

    test_local_allocation();
    test_shared_allocation();
    test_promotion();
    test_cycle_detection();
    test_generational_gc();
    test_memory_pool();

    printf("\n======================================\n");
    printf("所有测试通过！\n");
    printf("======================================\n");

    // 打印最终统计信息
    gc_print_stats();

    return 0;
}
