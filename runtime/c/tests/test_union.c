#include "union.h"
#include <stdio.h>
#include <assert.h>
#include <string.h>

void test_union_int() {
    printf("测试 int union...\n");
    union_t* u = __c_union_create_int(42);

    assert(__c_union_is_int(u));
    assert(!__c_union_is_float(u));
    assert(!__c_union_is_str(u));
    assert(!__c_union_is_bool(u));
    assert(!__c_union_is_none(u));

    assert(__c_union_get_int(u) == 42);

    int32_t value;
    assert(__c_union_try_get_int(u, &value));
    assert(value == 42);

    printf("  类型: %s\n", __c_union_type_name(u));
    printf("  值: ");
    __c_union_print(u);
    printf("\n");

    __c_union_free(u);
    printf("✓ int union 测试通过\n\n");
}

void test_union_float() {
    printf("测试 float union...\n");
    union_t* u = __c_union_create_float(3.14);

    assert(__c_union_is_float(u));
    assert(!__c_union_is_int(u));

    assert(__c_union_get_float(u) == 3.14);

    double value;
    assert(__c_union_try_get_float(u, &value));
    assert(value == 3.14);

    printf("  类型: %s\n", __c_union_type_name(u));
    printf("  值: ");
    __c_union_print(u);
    printf("\n");

    __c_union_free(u);
    printf("✓ float union 测试通过\n\n");
}

void test_union_string() {
    printf("测试 string union...\n");
    union_t* u = __c_union_create_str("Hello, World!");

    assert(__c_union_is_str(u));
    assert(!__c_union_is_int(u));

    assert(strcmp(__c_union_get_str(u), "Hello, World!") == 0);

    char* value;
    assert(__c_union_try_get_str(u, &value));
    assert(strcmp(value, "Hello, World!") == 0);

    printf("  类型: %s\n", __c_union_type_name(u));
    printf("  值: ");
    __c_union_print(u);
    printf("\n");

    __c_union_free(u);
    printf("✓ string union 测试通过\n\n");
}

void test_union_bool() {
    printf("测试 bool union...\n");
    union_t* u = __c_union_create_bool(true);

    assert(__c_union_is_bool(u));
    assert(!__c_union_is_int(u));

    assert(__c_union_get_bool(u) == true);

    bool value;
    assert(__c_union_try_get_bool(u, &value));
    assert(value == true);

    printf("  类型: %s\n", __c_union_type_name(u));
    printf("  值: ");
    __c_union_print(u);
    printf("\n");

    __c_union_free(u);
    printf("✓ bool union 测试通过\n\n");
}

void test_union_none() {
    printf("测试 None union...\n");
    union_t* u = __c_union_create_none();

    assert(__c_union_is_none(u));
    assert(!__c_union_is_int(u));

    printf("  类型: %s\n", __c_union_type_name(u));
    printf("  值: ");
    __c_union_print(u);
    printf("\n");

    __c_union_free(u);
    printf("✓ None union 测试通过\n\n");
}

void test_union_clone() {
    printf("测试 union 克隆...\n");

    union_t* u1 = __c_union_create_int(100);
    union_t* u2 = __c_union_clone(u1);

    assert(__c_union_is_int(u2));
    assert(__c_union_get_int(u2) == 100);

    __c_union_free(u1);
    __c_union_free(u2);

    union_t* u3 = __c_union_create_str("test");
    union_t* u4 = __c_union_clone(u3);

    assert(__c_union_is_str(u4));
    assert(strcmp(__c_union_get_str(u4), "test") == 0);

    // 修改原字符串不应影响克隆
    __c_union_free(u3);
    assert(strcmp(__c_union_get_str(u4), "test") == 0);

    __c_union_free(u4);

    printf("✓ union 克隆测试通过\n\n");
}

void test_union_type_mismatch() {
    printf("测试类型不匹配...\n");

    union_t* u = __c_union_create_int(42);

    // 尝试以错误类型提取应该失败
    assert(__c_union_get_float(u) == 0.0);
    assert(strcmp(__c_union_get_str(u), "") == 0);
    assert(__c_union_get_bool(u) == false);

    double f_val;
    char* s_val;
    bool b_val;

    assert(!__c_union_try_get_float(u, &f_val));
    assert(!__c_union_try_get_str(u, &s_val));
    assert(!__c_union_try_get_bool(u, &b_val));

    __c_union_free(u);

    printf("✓ 类型不匹配测试通过\n\n");
}

int main() {
    printf("========================================\n");
    printf("Union 类型测试套件\n");
    printf("========================================\n\n");

    test_union_int();
    test_union_float();
    test_union_string();
    test_union_bool();
    test_union_none();
    test_union_clone();
    test_union_type_mismatch();

    printf("========================================\n");
    printf("所有测试通过！✓\n");
    printf("========================================\n");

    return 0;
}
