#include <stdlib.h>
#include <stdint.h>
#include "tuple.h"
#include "dynarray.h"
#include "dict.h"

tuple2_i32* create_tuple2_i32(int e0, int e1) {
    tuple2_i32* tuple = (tuple2_i32*)malloc(sizeof(tuple2_i32));
    if (!tuple) return NULL;
    tuple->elem0 = e0;
    tuple->elem1 = e1;
    return tuple;
}

int tuple2_i32_get(tuple2_i32* tuple, int index) {
    if (!tuple) return 0;
    if (index == 0) return tuple->elem0;
    if (index == 1) return tuple->elem1;
    return 0;
}

void tuple2_i32_free(tuple2_i32* tuple) {
    if (tuple) free(tuple);
}

dynarray_ptr* dict_items(dict_t* dict) {
    if (!dict) return NULL;

    dynarray_ptr* items = create_dynarray_ptr(dict->size);
    if (!items) return NULL;

    for (int i = 0; i < dict->capacity; i++) {
        dict_entry_t* entry = dict->buckets[i];
        while (entry) {
            int key_int = (int)(intptr_t)entry->key;
            int val_int = (int)(intptr_t)entry->value;
            tuple2_i32* pair = create_tuple2_i32(key_int, val_int);
            if (pair) {
                append_ptr(items, (intptr_t)pair);
            }
            entry = entry->next;
        }
    }

    return items;
}
