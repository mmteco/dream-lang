#include <stdlib.h>
#include <stdint.h>
#include "tuple.h"
#include "dynarray.h"
#include "dict.h"

void* create_tuple2_i32(int e0, int e1) {
    tuple2_i32* tuple = (tuple2_i32*)malloc(sizeof(tuple2_i32));
    if (!tuple) return NULL;
    tuple->elem0 = e0;
    tuple->elem1 = e1;
    return (void*)tuple;
}

int tuple2_i32_get(void* ptr, int index) {
    tuple2_i32* tuple = (tuple2_i32*)ptr;
    if (!tuple) return 0;
    if (index == 0) return tuple->elem0;
    if (index == 1) return tuple->elem1;
    return 0;
}

void tuple2_i32_free(void* ptr) {
    if (ptr) free(ptr);
}

void* tuple_create(int size) {
    if (size <= 0) return NULL;

    tuple_t* tuple = (tuple_t*)malloc(sizeof(tuple_t));
    if (!tuple) return NULL;

    tuple->size = size;
    tuple->elements = (int*)malloc(sizeof(int) * size);
    if (!tuple->elements) {
        free(tuple);
        return NULL;
    }

    for (int i = 0; i < size; i++) {
        tuple->elements[i] = 0;
    }

    return (void*)tuple;
}

void tuple_set(void* ptr, int index, int value) {
    tuple_t* tuple = (tuple_t*)ptr;
    if (!tuple || index < 0 || index >= tuple->size) return;
    tuple->elements[index] = value;
}

int tuple_get(void* ptr, int index) {
    tuple_t* tuple = (tuple_t*)ptr;
    if (!tuple || index < 0 || index >= tuple->size) return 0;
    return tuple->elements[index];
}

int tuple_size(void* ptr) {
    tuple_t* tuple = (tuple_t*)ptr;
    return tuple ? tuple->size : 0;
}

void tuple_free(void* ptr) {
    tuple_t* tuple = (tuple_t*)ptr;
    if (!tuple) return;
    if (tuple->elements) free(tuple->elements);
    free(tuple);
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
