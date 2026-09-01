#ifndef DREAM_STRING_OPS_H
#define DREAM_STRING_OPS_H

#include <stdbool.h>
#include <stdint.h>
#include "dynarray.h"

// UTF-8 aware string operations
// str 是 UTF-8 编码，length 和索引基于 rune (Unicode codepoint)
int __c_str_len(const char* str);           // 返回 rune 数量（不是字节数）
uint32_t __c_str_char_at(const char* str, int index);  // 返回第 n 个 rune (U32)
char* __c_str_concat(const char* s1, const char* s2);
char* __c_str_substring(const char* str, int start, int end);  // 基于 rune 索引
int __c_str_find(const char* str, const char* sub);
int __c_str_compare(const char* s1, const char* s2);
char* __c_str_upper(const char* str);
char* __c_str_lower(const char* str);
char* __c_str_strip(const char* str);
char* __c_str_lstrip(const char* str);
char* __c_str_rstrip(const char* str);
int32_t __c_str_count(const char* str, const char* sub);
bool __c_str_starts_with(const char* str, const char* prefix);
bool __c_str_ends_with(const char* str, const char* suffix);
char* __c_str_replace(const char* str, const char* old, const char* new_str);
bool __c_str_is_digit(char c);
bool __c_str_is_alpha(char c);
bool __c_str_is_whitespace(char c);

// split 和 join 函数
dynarray_ptr* __c_str_split(const char* str, const char* delimiter);
char* __c_str_join(dynarray_ptr* arr, const char* separator);

// 范围比较与哈希(供编译器内部优化):按 rune 语义,单次扫描
bool __c_range_equal(const char* str, int first_start, int first_end, int second_start, int second_end);
uint32_t __c_fnv_hash_range(const char* str, int start, int end);

#endif
