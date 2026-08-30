#ifndef DREAM_UNION_H
#define DREAM_UNION_H

#include <stdint.h>
#include <stdbool.h>

// Union 类型标签
typedef enum {
    UNION_INT,
    UNION_FLOAT,
    UNION_STRING,
    UNION_BOOL,
    UNION_BYTES,
    UNION_NONE,
    UNION_STRUCT,  // 自定义结构体类型
} UnionTag;

// Tagged Union 结构
// 使用 tag 区分当前存储的类型
// 使用 union 存储实际值（节省内存）
typedef struct {
    UnionTag tag;
    char* type_name;  // 仅当 tag == UNION_STRUCT 时有效，存储结构体类型名
    union {
        int32_t as_int;
        double as_float;
        char* as_string;
        bool as_bool;
        void* as_bytes;  // 指向 dynarray 结构
        void* as_ptr;    // 指向结构体的指针
    } value;
} union_t;

// 将 Union 的实际值转换为字符串。
char* __c_union_to_str(union_t* value);

// ============================================================================
// Union 创建函数
// ============================================================================

// 创建 int union
union_t* __c_union_create_int(int32_t value);

// 创建 float union
union_t* __c_union_create_float(double value);

// 创建 string union
union_t* __c_union_create_str(const char* value);

// 创建 bool union
union_t* __c_union_create_bool(bool value);

// 创建 bytes union (dynarray)
union_t* __c_union_create_bytes(void* bytes_array);

// 创建 None union
union_t* __c_union_create_none(void);

// 创建 struct union (存储结构体指针和类型名)
union_t* __c_union_create_struct(void* ptr, const char* type_name);

// ============================================================================
// Union 类型检查
// ============================================================================

// 检查 union 是否为特定类型
bool __c_union_is_int(union_t* u);
bool __c_union_is_float(union_t* u);
bool __c_union_is_str(union_t* u);
bool __c_union_is_bool(union_t* u);
bool __c_union_is_bytes(union_t* u);
bool __c_union_is_none(union_t* u);

// 检查 union 是否为指定类型名的结构体
bool __c_union_is_struct(union_t* u, const char* type_name);

// ============================================================================
// Union 值提取
// ============================================================================

// 提取 union 中的值（如果类型不匹配则返回默认值）
int32_t __c_union_get_int(union_t* u);
double __c_union_get_float(union_t* u);
char* __c_union_get_str(union_t* u);
bool __c_union_get_bool(union_t* u);
void* __c_union_get_bytes(union_t* u);

// 提取 struct 指针
void* __c_union_get_struct(union_t* u);

// 获取 struct 的类型名
const char* __c_union_get_struct_type(union_t* u);

// ============================================================================
// Union 值提取（安全版本，类型不匹配时返回 false）
// ============================================================================

bool __c_union_try_get_int(union_t* u, int32_t* out);
bool __c_union_try_get_float(union_t* u, double* out);
bool __c_union_try_get_str(union_t* u, char** out);
bool __c_union_try_get_bool(union_t* u, bool* out);

// ============================================================================
// Union 内存管理（GC 集成）
// ============================================================================

// 增加 union 引用计数
void __c_union_retain(union_t* u);

// 减少 union 引用计数（可能触发释放）
void __c_union_release(union_t* u);

// 释放 union（会释放字符串内存）
// 注意：这是 union_release 的别名，为了兼容性保留
void __c_union_free(union_t* u);

// 复制 union（深拷贝字符串，新对象引用计数为 1）
union_t* __c_union_clone(union_t* u);

// ============================================================================
// Union 调试
// ============================================================================

// 打印 union 内容（调试用）
void __c_union_print(union_t* u);

// 获取 union 类型名称
const char* __c_union_type_name(union_t* u);

// 打印 union 的实际值（不带类型信息）
void __c_union_print_value(union_t* u);

#endif // DREAM_UNION_H
