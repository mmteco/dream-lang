#ifndef DREAM_STRING_OPS_H
#define DREAM_STRING_OPS_H

#include <stdbool.h>
#include <stdint.h>
#include "dynarray.h"

// UTF-8 aware string operations
// str 是 UTF-8 编码，length 和索引基于 rune (Unicode codepoint)
int string_length(const char* str);           // 返回 rune 数量（不是字节数）
uint32_t string_char_at(const char* str, int index);  // 返回第 n 个 rune (U32)
char* string_concat(const char* s1, const char* s2);
char* string_substring(const char* str, int start, int end);  // 基于 rune 索引
int string_find(const char* str, const char* sub);
int string_compare(const char* s1, const char* s2);
char* string_upper(const char* str);
char* string_lower(const char* str);
char* string_strip(const char* str);
bool string_starts_with(const char* str, const char* prefix);
bool string_ends_with(const char* str, const char* suffix);
char* string_replace(const char* str, const char* old, const char* new_str);
bool string_is_digit(char c);
bool string_is_alpha(char c);
bool string_is_whitespace(char c);

// split 和 join 函数
dynarray_ptr* string_split(const char* str, const char* delimiter);
char* string_join(dynarray_ptr* arr, const char* separator);

// 范围比较与哈希(供编译器内部优化):按 rune 语义,单次扫描
bool __c_range_equal(const char* str, int first_start, int first_end, int second_start, int second_end);
uint32_t __c_fnv_hash_range(const char* str, int start, int end);

#endif
