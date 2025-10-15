#ifndef DREAM_TUPLE_H
#define DREAM_TUPLE_H

#include "dynarray.h"
#include "dict.h"

typedef struct {
    int elem0;
    int elem1;
} tuple2_i32;

tuple2_i32* create_tuple2_i32(int e0, int e1);
int tuple2_i32_get(tuple2_i32* tuple, int index);
void tuple2_i32_free(tuple2_i32* tuple);
dynarray_ptr* dict_items(dict_t* dict);

#endif
