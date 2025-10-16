#ifndef DREAM_ENUM_H
#define DREAM_ENUM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// 枚举值的 tagged union 表示
// 设计：tag（变体索引）+ 数据区域（最大变体的大小）
typedef struct {
    int32_t tag;           // 变体标识符（索引）
    void* data;            // 变体数据（如果有）
} enum_t;

// ============================================================================
// 枚举创建函数
// ============================================================================

// 创建简单枚举（无数据）
enum_t* enum_create_simple(int32_t tag);

// 创建包含单个 int 值的枚举
enum_t* enum_create_int(int32_t tag, int32_t value);

// 创建包含单个 string 值的枚举
enum_t* enum_create_string(int32_t tag, const char* value);

// 创建包含单个 bool 值的枚举
enum_t* enum_create_bool(int32_t tag, bool value);

// 创建包含元组数据的枚举（通用）
enum_t* enum_create_tuple(int32_t tag, void* data, size_t data_size);

// 创建包含元组指针的枚举（直接存储指针，不复制）
enum_t* enum_create_tuple_ptr(int32_t tag, void* tuple_ptr);

// ============================================================================
// 枚举类型检查
// ============================================================================

// 检查枚举变体
bool enum_is_variant(enum_t* e, int32_t tag);

// 获取枚举 tag
int32_t enum_get_tag(enum_t* e);

// ============================================================================
// 枚举值提取
// ============================================================================

// 从枚举中提取 int 值
int32_t enum_get_int(enum_t* e);

// 从枚举中提取 string 值
char* enum_get_string(enum_t* e);

// 从枚举中提取 bool 值
bool enum_get_bool(enum_t* e);

// 从枚举中提取元组数据指针
void* enum_get_data(enum_t* e);

// ============================================================================
// 枚举内存管理
// ============================================================================

// 增加引用计数
void enum_retain(enum_t* e);

// 减少引用计数
void enum_release(enum_t* e);

// 释放枚举（别名）
void enum_free(enum_t* e);

// 克隆枚举
enum_t* enum_clone(enum_t* e);

// ============================================================================
// 枚举调试
// ============================================================================

// 打印枚举（调试用）
void enum_print(enum_t* e);

// 打印枚举值（不带类型信息）
void enum_print_value(enum_t* e);

#endif // DREAM_ENUM_H
