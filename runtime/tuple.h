#ifndef DREAM_TUPLE_H
#define DREAM_TUPLE_H

#include "dynarray.h"
#include "dict.h"

typedef struct {
    int elem0;
    int elem1;
} tuple2_i32;

typedef struct {
    intptr_t elem0;
    intptr_t elem1;
} tuple2_ptr;

typedef struct {
    int size;
    int* elements;
} tuple_t;

void* create_tuple2_i32(int e0, int e1);
int tuple2_i32_get(void* tuple, int index);
void tuple2_i32_free(void* tuple);

void* create_tuple2_ptr(intptr_t e0, intptr_t e1);
intptr_t tuple2_ptr_get(void* tuple, int index);
void tuple2_ptr_free(void* tuple);

void* tuple_create(int size);
void tuple_set(void* tuple, int index, int value);
int tuple_get(void* tuple, int index);
int tuple_size(void* tuple);
void tuple_free(void* tuple);

// 兼容 legacy backend 的 int -> int 字典 ABI。
dynarray_ptr* dict_items_i32(dict_t* dict);

// 通用字典项：tuple2_ptr 中的两个值均为借用指针/整数值。
dynarray_ptr* dict_items(dict_t* dict);

#endif
