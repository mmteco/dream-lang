#ifndef DREAM_TUPLE_H
#define DREAM_TUPLE_H

#include "dynarray.h"
#include "dict.h"

typedef struct {
    int elem0;
    int elem1;
} tuple2_i32;

typedef struct {
    int size;
    int* elements;
} tuple_t;

void* create_tuple2_i32(int e0, int e1);
int tuple2_i32_get(void* tuple, int index);
void tuple2_i32_free(void* tuple);

void* tuple_create(int size);
void tuple_set(void* tuple, int index, int value);
int tuple_get(void* tuple, int index);
int tuple_size(void* tuple);
void tuple_free(void* tuple);

dynarray_ptr* dict_items(dict_t* dict);

#endif
