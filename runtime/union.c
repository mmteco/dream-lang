#include "union.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
// Union 创建函数（使用 GC 内存分配）
// ============================================================================

union_t* union_create_int(int32_t value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_INT;
    u->value.as_int = value;
    return u;
}

union_t* union_create_float(double value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_FLOAT;
    u->value.as_float = value;
    return u;
}

union_t* union_create_string(const char* value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_STRING;
    // 字符串也通过 GC 分配（如果有 GC 字符串分配器）
    // 目前仍使用 strdup，但在 union_free 中释放
    u->value.as_string = strdup(value);
    return u;
}

union_t* union_create_bool(bool value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_BOOL;
    u->value.as_bool = value;
    return u;
}

union_t* union_create_none() {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_NONE;
    return u;
}

// ============================================================================
// Union 类型检查
// ============================================================================

bool union_is_int(union_t* u) {
    return u != NULL && u->tag == UNION_INT;
}

bool union_is_float(union_t* u) {
    return u != NULL && u->tag == UNION_FLOAT;
}

bool union_is_string(union_t* u) {
    return u != NULL && u->tag == UNION_STRING;
}

bool union_is_bool(union_t* u) {
    return u != NULL && u->tag == UNION_BOOL;
}

bool union_is_none(union_t* u) {
    return u != NULL && u->tag == UNION_NONE;
}

// ============================================================================
// Union 值提取
// ============================================================================

int32_t union_get_int(union_t* u) {
    if (union_is_int(u)) {
        return u->value.as_int;
    }
    return 0;  // 默认值
}

double union_get_float(union_t* u) {
    if (union_is_float(u)) {
        return u->value.as_float;
    }
    return 0.0;  // 默认值
}

char* union_get_string(union_t* u) {
    if (union_is_string(u)) {
        return u->value.as_string;
    }
    return "";  // 默认值
}

bool union_get_bool(union_t* u) {
    if (union_is_bool(u)) {
        return u->value.as_bool;
    }
    return false;  // 默认值
}

// ============================================================================
// Union 值提取（安全版本）
// ============================================================================

bool union_try_get_int(union_t* u, int32_t* out) {
    if (union_is_int(u)) {
        *out = u->value.as_int;
        return true;
    }
    return false;
}

bool union_try_get_float(union_t* u, double* out) {
    if (union_is_float(u)) {
        *out = u->value.as_float;
        return true;
    }
    return false;
}

bool union_try_get_string(union_t* u, char** out) {
    if (union_is_string(u)) {
        *out = u->value.as_string;
        return true;
    }
    return false;
}

bool union_try_get_bool(union_t* u, bool* out) {
    if (union_is_bool(u)) {
        *out = u->value.as_bool;
        return true;
    }
    return false;
}

// ============================================================================
// Union 内存管理（GC 集成）
// ============================================================================

void union_retain(union_t* u) {
    if (u == NULL) return;
    gc_retain(u);
}

void union_release(union_t* u) {
    if (u == NULL) return;
    // 字符串内存会在 gc_release 的对象清理阶段自动释放
    gc_release(u);
}

void union_free(union_t* u) {
    // union_free 是 union_release 的别名，为了向后兼容
    union_release(u);
}

union_t* union_clone(union_t* u) {
    if (u == NULL) return NULL;

    switch (u->tag) {
        case UNION_INT:
            return union_create_int(u->value.as_int);
        case UNION_FLOAT:
            return union_create_float(u->value.as_float);
        case UNION_STRING:
            return union_create_string(u->value.as_string);
        case UNION_BOOL:
            return union_create_bool(u->value.as_bool);
        case UNION_NONE:
            return union_create_none();
        default:
            return NULL;
    }
}

// ============================================================================
// Union 调试
// ============================================================================

void union_print(union_t* u) {
    if (u == NULL) {
        printf("NULL");
        return;
    }

    switch (u->tag) {
        case UNION_INT:
            printf("Union(int: %d)", u->value.as_int);
            break;
        case UNION_FLOAT:
            printf("Union(float: %f)", u->value.as_float);
            break;
        case UNION_STRING:
            printf("Union(string: \"%s\")", u->value.as_string);
            break;
        case UNION_BOOL:
            printf("Union(bool: %s)", u->value.as_bool ? "true" : "false");
            break;
        case UNION_NONE:
            printf("Union(None)");
            break;
        default:
            printf("Union(unknown)");
            break;
    }
}

const char* union_type_name(union_t* u) {
    if (u == NULL) return "null";

    switch (u->tag) {
        case UNION_INT: return "int";
        case UNION_FLOAT: return "float";
        case UNION_STRING: return "string";
        case UNION_BOOL: return "bool";
        case UNION_NONE: return "None";
        default: return "unknown";
    }
}

// 打印 union 的实际值（不带类型信息）
void union_print_value(union_t* u) {
    if (u == NULL) {
        printf("(null)");
        return;
    }

    switch (u->tag) {
        case UNION_INT:
            printf("%d", u->value.as_int);
            break;
        case UNION_FLOAT:
            printf("%f", u->value.as_float);
            break;
        case UNION_STRING:
            printf("%s", u->value.as_string);
            break;
        case UNION_BOOL:
            printf("%s", u->value.as_bool ? "True" : "False");
            break;
        case UNION_NONE:
            printf("None");
            break;
        default:
            printf("(unknown)");
            break;
    }
}
