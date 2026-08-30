#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "memory.h"
#include "dynarray.h"

void test_basic_allocation() {
    printf("\n=== Test 1: Basic Allocation ===\n");

    dynarray_i32* arr1 = __c_create_dynarray_i32(10);
    assert(arr1 != NULL);
    assert(__c_len_dynarray_i32(arr1) == 0);
    assert(__c_capacity_dynarray_i32(arr1) == 10);
    printf("✓ Array created successfully\n");

    // 添加元素
    for (int i = 0; i < 5; i++) {
        __c_append_i32(arr1, i * 10);
    }
    assert(__c_len_dynarray_i32(arr1) == 5);
    printf("✓ Added 5 elements\n");

    // 验证元素
    for (int i = 0; i < 5; i++) {
        assert(__c_get_dynarray_i32(arr1, i) == i * 10);
    }
    printf("✓ Elements verified\n");

    // 释放
    __c_free_dynarray_i32(arr1);
    printf("✓ Array freed\n");
}

void test_reference_counting() {
    printf("\n=== Test 2: Reference Counting ===\n");

    dynarray_i32* arr = __c_create_dynarray_i32(5);
    assert(arr != NULL);
    printf("✓ Initial ref count: %u\n", gc_get_ref_count(arr));
    assert(gc_get_ref_count(arr) == 1);

    // 增加引用
    __c_retain_dynarray_i32(arr);
    printf("✓ After retain: %u\n", gc_get_ref_count(arr));
    assert(gc_get_ref_count(arr) == 2);

    // 减少引用（不会释放）
    __c_free_dynarray_i32(arr);
    printf("✓ After first release: %u\n", gc_get_ref_count(arr));
    assert(gc_get_ref_count(arr) == 1);

    // 最后一次释放（应该释放对象）
    __c_free_dynarray_i32(arr);
    printf("✓ Object freed when ref count reached 0\n");
}

void test_growth() {
    printf("\n=== Test 3: Array Growth ===\n");

    dynarray_i32* arr = __c_create_dynarray_i32(0);
    assert(arr != NULL);

    // 添加超过初始容量的元素
    for (int i = 0; i < 100; i++) {
        __c_append_i32(arr, i);
    }

    assert(__c_len_dynarray_i32(arr) == 100);
    printf("✓ Added 100 elements\n");
    printf("  Capacity: %d\n", __c_capacity_dynarray_i32(arr));
    assert(__c_capacity_dynarray_i32(arr) >= 100);

    // 验证所有元素
    for (int i = 0; i < 100; i++) {
        assert(__c_get_dynarray_i32(arr, i) == i);
    }
    printf("✓ All elements verified\n");

    __c_free_dynarray_i32(arr);
}

void test_copy_and_slice() {
    printf("\n=== Test 4: Copy and Slice ===\n");

    dynarray_i32* arr = __c_create_dynarray_i32(10);
    for (int i = 0; i < 10; i++) {
        __c_append_i32(arr, i);
    }

    // 测试复制
    dynarray_i32* copy = __c_copy_dynarray_i32(arr);
    assert(copy != NULL);
    assert(__c_len_dynarray_i32(copy) == __c_len_dynarray_i32(arr));

    for (int i = 0; i < 10; i++) {
        assert(__c_get_dynarray_i32(copy, i) == __c_get_dynarray_i32(arr, i));
    }
    printf("✓ Array copied successfully\n");

    // 测试切片
    dynarray_i32* slice = __c_slice_dynarray_i32(arr, 2, 7);
    assert(slice != NULL);
    assert(__c_len_dynarray_i32(slice) == 5);

    for (int i = 0; i < 5; i++) {
        assert(__c_get_dynarray_i32(slice, i) == i + 2);
    }
    printf("✓ Slice created successfully\n");

    __c_free_dynarray_i32(arr);
    __c_free_dynarray_i32(copy);
    __c_free_dynarray_i32(slice);
}

void test_concat() {
    printf("\n=== Test 5: Concatenation ===\n");

    dynarray_i32* arr1 = __c_create_dynarray_i32(5);
    dynarray_i32* arr2 = __c_create_dynarray_i32(5);

    for (int i = 0; i < 5; i++) {
        __c_append_i32(arr1, i);
        __c_append_i32(arr2, i + 10);
    }

    dynarray_i32* result = __c_concat_dynarray_i32(arr1, arr2);
    assert(result != NULL);
    assert(__c_len_dynarray_i32(result) == 10);

    // 验证前半部分
    for (int i = 0; i < 5; i++) {
        assert(__c_get_dynarray_i32(result, i) == i);
    }

    // 验证后半部分
    for (int i = 0; i < 5; i++) {
        assert(__c_get_dynarray_i32(result, i + 5) == i + 10);
    }

    printf("✓ Arrays concatenated successfully\n");

    __c_free_dynarray_i32(arr1);
    __c_free_dynarray_i32(arr2);
    __c_free_dynarray_i32(result);
}

void test_memory_leak_detection() {
    printf("\n=== Test 6: Memory Leak Detection ===\n");

    // 创建一些对象但不释放
    for (int i = 0; i < 5; i++) {
        dynarray_i32* arr = __c_create_dynarray_i32(10);
        __c_append_i32(arr, i);
        // 故意不释放
    }

    printf("Created 5 arrays without freeing\n");
    gc_print_stats();

    // 强制垃圾回收（标记-清除）
    gc_collect();
    printf("After GC:\n");
    gc_print_stats();
}

void test_stress() {
    printf("\n=== Test 7: Stress Test ===\n");

    const int num_arrays = 1000;
    dynarray_i32** arrays = (dynarray_i32**)malloc(num_arrays * sizeof(dynarray_i32*));

    // 创建大量数组
    for (int i = 0; i < num_arrays; i++) {
        arrays[i] = __c_create_dynarray_i32(10);
        for (int j = 0; j < 10; j++) {
            __c_append_i32(arrays[i], i + j);
        }
    }
    printf("✓ Created %d arrays\n", num_arrays);

    // 验证
    for (int i = 0; i < num_arrays; i++) {
        assert(__c_len_dynarray_i32(arrays[i]) == 10);
    }
    printf("✓ Verified %d arrays\n", num_arrays);

    // 释放
    for (int i = 0; i < num_arrays; i++) {
        __c_free_dynarray_i32(arrays[i]);
    }
    printf("✓ Freed %d arrays\n", num_arrays);

    free(arrays);

    gc_print_stats();
}

int main() {
    printf("===================================\n");
    printf("  Dream Memory Management Tests\n");
    printf("===================================\n");

    test_basic_allocation();
    test_reference_counting();
    test_growth();
    test_copy_and_slice();
    test_concat();
    test_memory_leak_detection();
    test_stress();

    printf("\n=== Final Statistics ===\n");
    gc_print_stats();

    printf("\n=== Cleanup ===\n");
    gc_cleanup();

    printf("\n✓ All tests passed!\n");
    return 0;
}
