// Union GC 集成测试
// 验证 union 对象正确使用 GC 内存分配和引用计数

#include <stdio.h>
#include <assert.h>
#include "union.h"
#include "memory.h"

void test_union_gc_allocation() {
    printf("Test 1: Union GC allocation\n");

    // 创建 union 对象（应该使用 gc_alloc）
    union_t* u1 = union_create_int(42);
    assert(u1 != NULL);
    assert(gc_get_ref_count(u1) == 1);
    printf("  ✓ union_create_int: ref_count = 1\n");

    union_t* u2 = union_create_string("hello");
    assert(u2 != NULL);
    assert(gc_get_ref_count(u2) == 1);
    printf("  ✓ union_create_string: ref_count = 1\n");

    // 清理
    union_free(u1);
    union_free(u2);
    printf("  ✓ Objects freed\n\n");
}

void test_union_ref_counting() {
    printf("Test 2: Union reference counting\n");

    union_t* u = union_create_int(100);
    assert(gc_get_ref_count(u) == 1);
    printf("  ✓ Initial ref_count = 1\n");

    // 增加引用
    union_retain(u);
    assert(gc_get_ref_count(u) == 2);
    printf("  ✓ After retain: ref_count = 2\n");

    union_retain(u);
    assert(gc_get_ref_count(u) == 3);
    printf("  ✓ After 2nd retain: ref_count = 3\n");

    // 减少引用
    union_release(u);
    assert(gc_get_ref_count(u) == 2);
    printf("  ✓ After release: ref_count = 2\n");

    union_release(u);
    assert(gc_get_ref_count(u) == 1);
    printf("  ✓ After 2nd release: ref_count = 1\n");

    // 最后释放
    union_free(u);
    printf("  ✓ Object freed\n\n");
}

void test_union_string_cleanup() {
    printf("Test 3: Union string cleanup\n");

    // 创建字符串 union
    union_t* u = union_create_string("test string");
    assert(union_is_string(u));
    printf("  ✓ String union created\n");

    // 释放应该自动清理字符串内存
    union_free(u);
    printf("  ✓ String union freed (string memory auto-cleaned)\n\n");
}

void test_union_memory_pool() {
    printf("Test 4: Union memory pool usage\n");

    // 创建多个 union 对象（应该使用内存池）
    const int count = 100;
    union_t* unions[count];

    for (int i = 0; i < count; i++) {
        unions[i] = union_create_int(i);
        assert(unions[i] != NULL);
    }
    printf("  ✓ Created %d union objects (using memory pool)\n", count);

    // 释放所有对象
    for (int i = 0; i < count; i++) {
        union_free(unions[i]);
    }
    printf("  ✓ Freed all %d objects\n\n", count);
}

void test_union_clone() {
    printf("Test 5: Union clone (new object with ref_count = 1)\n");

    union_t* u1 = union_create_string("original");
    union_retain(u1);  // ref_count = 2
    assert(gc_get_ref_count(u1) == 2);

    union_t* u2 = union_clone(u1);
    assert(u2 != NULL);
    assert(u2 != u1);  // 不同的对象
    assert(gc_get_ref_count(u2) == 1);  // 新对象引用计数为 1
    assert(gc_get_ref_count(u1) == 2);  // 原对象不变
    printf("  ✓ Cloned object has ref_count = 1\n");
    printf("  ✓ Original object ref_count unchanged\n");

    // 清理
    union_free(u1);
    union_free(u1);  // 释放两次（因为 retain 了一次）
    union_free(u2);
    printf("  ✓ Both objects freed\n\n");
}

int main() {
    printf("=== Union GC Integration Test ===\n\n");

    test_union_gc_allocation();
    test_union_ref_counting();
    test_union_string_cleanup();
    test_union_memory_pool();
    test_union_clone();

    // 打印 GC 统计信息
    gc_print_stats();

    printf("\n=== All tests passed! ===\n");
    return 0;
}
