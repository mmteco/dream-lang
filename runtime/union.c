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
    u->type_name = NULL;
    u->value.as_int = value;
    return u;
}

union_t* union_create_float(double value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_FLOAT;
    u->type_name = NULL;
    u->value.as_float = value;
    return u;
}

union_t* union_create_string(const char* value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_STRING;
    u->type_name = NULL;
    // 字符串也通过 GC 分配（如果有 GC 字符串分配器）
    // 目前仍使用 strdup，但在 union_free 中释放
    u->value.as_string = strdup(value);
    return u;
}

union_t* union_create_bool(bool value) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_BOOL;
    u->type_name = NULL;
    u->value.as_bool = value;
    return u;
}

union_t* union_create_bytes(void* bytes_array) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_BYTES;
    u->type_name = NULL;
    u->value.as_bytes = bytes_array;
    return u;
}

union_t* union_create_none() {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_NONE;
    u->type_name = NULL;
    return u;
}

union_t* union_create_struct(void* ptr, const char* type_name) {
    union_t* u = (union_t*)gc_alloc(sizeof(union_t), OBJ_UNION);
    if (!u) return NULL;
    u->tag = UNION_STRUCT;
    u->type_name = strdup(type_name);  // 复制类型名
    u->value.as_ptr = ptr;
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

bool union_is_bytes(union_t* u) {
    return u != NULL && u->tag == UNION_BYTES;
}

bool union_is_none(union_t* u) {
    return u != NULL && u->tag == UNION_NONE;
}

bool union_is_struct(union_t* u, const char* type_name) {
    if (u == NULL || u->tag != UNION_STRUCT || u->type_name == NULL) {
        return false;
    }
    return strcmp(u->type_name, type_name) == 0;
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

void* union_get_bytes(union_t* u) {
    if (union_is_bytes(u)) {
        return u->value.as_bytes;
    }
    return NULL;  // 默认值
}

void* union_get_struct(union_t* u) {
    if (u != NULL && u->tag == UNION_STRUCT) {
        return u->value.as_ptr;
    }
    return NULL;  // 默认值
}

const char* union_get_struct_type(union_t* u) {
    if (u != NULL && u->tag == UNION_STRUCT) {
        return u->type_name;
    }
    return NULL;
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
        case UNION_BYTES:
            // bytes需要深拷贝，暂时返回同一个指针
            return union_create_bytes(u->value.as_bytes);
        case UNION_STRUCT:
            // struct 浅拷贝指针
            return union_create_struct(u->value.as_ptr, u->type_name);
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
        case UNION_BYTES:
            printf("Union(bytes: %p)", u->value.as_bytes);
            break;
        case UNION_STRUCT:
            printf("Union(struct %s: %p)", u->type_name ? u->type_name : "unknown", u->value.as_ptr);
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
        case UNION_BYTES: return "bytes";
        case UNION_STRUCT: return u->type_name ? u->type_name : "struct";
        case UNION_NONE: return "none";
        default: return "unknown";
    }
}

// 打印 union 的实际值（不带类型信息）
void union_print_value(union_t* u) {
    if (u == NULL) {
        printf("(null)\n");
        return;
    }

    switch (u->tag) {
        case UNION_INT:
            printf("%d\n", u->value.as_int);
            break;
        case UNION_FLOAT:
            printf("%f\n", u->value.as_float);
            break;
        case UNION_STRING:
            printf("%s\n", u->value.as_string);
            break;
        case UNION_BOOL:
            printf("%s\n", u->value.as_bool ? "true" : "false");
            break;
        case UNION_BYTES:
            printf("<bytes at %p>\n", u->value.as_bytes);
            break;
        case UNION_STRUCT:
            printf("<%s at %p>\n", u->type_name ? u->type_name : "struct", u->value.as_ptr);
            break;
        case UNION_NONE:
            printf("None\n");
            break;
        default:
            printf("(unknown)\n");
            break;
    }
}
