#ifndef DREAM_DYNARRAY_H
#define DREAM_DYNARRAY_H

#include <stdint.h>

// 动态数组结构（i32 版本）
typedef struct {
    int capacity;
    int length;
    int* data;
} dynarray_i32;

// 动态数组结构（ptr 版本 - 用于存储指针，自动适配32/64位）
typedef struct {
    int capacity;
    int length;
    intptr_t* data;  // 使用 intptr_t 自动适配系统位数
} dynarray_ptr;

// 创建和销毁
dynarray_i32* create_dynarray_i32(int initial_capacity);
void free_dynarray_i32(dynarray_i32* arr);
void retain_dynarray_i32(dynarray_i32* arr);

// 基本操作
void append_i32(dynarray_i32* arr, int value);
int get_dynarray_i32(dynarray_i32* arr, int index);
void set_dynarray_i32(dynarray_i32* arr, int index, int value);
int len_dynarray_i32(dynarray_i32* arr);
int capacity_dynarray_i32(dynarray_i32* arr);

// 高级操作
void clear_dynarray_i32(dynarray_i32* arr);
int reserve_dynarray_i32(dynarray_i32* arr, int new_capacity);
dynarray_i32* copy_dynarray_i32(dynarray_i32* src);
dynarray_i32* slice_dynarray_i32(dynarray_i32* arr, int start, int end);
dynarray_i32* concat_dynarray_i32(dynarray_i32* arr1, dynarray_i32* arr2);

// 调试
void print_dynarray_i32(dynarray_i32* arr);

// dynarray_ptr 函数 (用于存储指针)
dynarray_ptr* create_dynarray_ptr(int initial_capacity);
void free_dynarray_ptr(dynarray_ptr* arr);
void append_ptr(dynarray_ptr* arr, intptr_t value);
intptr_t get_dynarray_ptr(dynarray_ptr* arr, int index);
int len_dynarray_ptr(dynarray_ptr* arr);

#endif // DREAM_DYNARRAY_H
