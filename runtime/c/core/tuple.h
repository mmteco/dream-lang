#ifndef DREAM_TUPLE_H
#define DREAM_TUPLE_H

#include "dynarray.h"
#include "dict.h"

typedef struct {
    intptr_t elem0;
    intptr_t elem1;
} tuple2_ptr;

typedef struct {
    int size;
    int* elements;
} tuple_t;

void* create_tuple2_ptr(intptr_t e0, intptr_t e1);
intptr_t tuple2_ptr_get(void* tuple, int index);
void tuple2_ptr_free(void* tuple);

void* tuple_create(int size);
void tuple_set(void* tuple, int index, int value);
int tuple_get(void* tuple, int index);
int tuple_size(void* tuple);
void tuple_free(void* tuple);

// 通用字典项：tuple2_ptr 中的两个值均为借用指针/整数值。
dynarray_ptr* dict_items(dict_t* dict);

// 字典项转为编译器通用元组表示（元素为 dynarray_ptr 的 intptr_t 数组）
dynarray_ptr* __c_dict_items_tuples(dict_t* dict);

#endif
