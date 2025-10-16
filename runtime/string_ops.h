#ifndef DREAM_STRING_OPS_H
#define DREAM_STRING_OPS_H

int string_length(const char* str);
char string_char_at(const char* str, int index);
char* string_concat(const char* s1, const char* s2);
char* string_substring(const char* str, int start, int end);
int string_find(const char* str, const char* sub);
int string_compare(const char* s1, const char* s2);
char* string_upper(const char* str);
char* string_lower(const char* str);
char* string_strip(const char* str);
int string_starts_with(const char* str, const char* prefix);
int string_ends_with(const char* str, const char* suffix);
char* string_replace(const char* str, const char* old, const char* new_str);
int string_is_digit(char c);
int string_is_alpha(char c);
int string_is_whitespace(char c);

// 前向声明动态数组类型
struct dynarray_ptr;

// split 和 join 函数
struct dynarray_ptr* string_split(const char* str, const char* delimiter);
char* string_join(struct dynarray_ptr* arr, const char* separator);

#endif
