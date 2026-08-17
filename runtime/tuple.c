#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#include "tuple.h"
#include "dynarray.h"
#include "dict.h"
#include "memory.h"

void* create_tuple2_ptr(intptr_t e0, intptr_t e1) {
    tuple2_ptr* tuple = (tuple2_ptr*)malloc(sizeof(tuple2_ptr));
    if (tuple == NULL) return NULL;
    tuple->elem0 = e0;
    tuple->elem1 = e1;
    return tuple;
}

intptr_t tuple2_ptr_get(void* ptr, int index) {
    tuple2_ptr* tuple = (tuple2_ptr*)ptr;
    if (tuple == NULL) return 0;
    if (index == 0) return tuple->elem0;
    if (index == 1) return tuple->elem1;
    return 0;
}

void tuple2_ptr_free(void* ptr) {
    free(ptr);
}

void* tuple_create(int size) {
    if (size <= 0 || size > INT_MAX / (int)sizeof(int)) return NULL;

    tuple_t* tuple = (tuple_t*)gc_alloc(sizeof(tuple_t), OBJ_TUPLE);
    if (!tuple) return NULL;

    tuple->size = size;
    tuple->elements = (int*)malloc(sizeof(int) * size);
    if (!tuple->elements) {
        gc_release(tuple);
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
    if (gc_is_managed(tuple)) {
        gc_release(tuple);
        return;
    }
    if (tuple->elements) free(tuple->elements);
    free(tuple);
}

dynarray_ptr* dict_items(dict_t* dict) {
    if (dict == NULL) return NULL;

    dynarray_ptr* items = create_dynarray_ptr(dict->size);
    if (items == NULL) return NULL;

    for (int bucket_index = 0; bucket_index < dict->capacity; bucket_index++) {
        dict_entry_t* entry = dict->buckets[bucket_index];
        while (entry != NULL) {
            intptr_t key = (intptr_t)entry->key;
            intptr_t value = (intptr_t)entry->value;

            tuple2_ptr* pair = (tuple2_ptr*)create_tuple2_ptr(key, value);
            if (pair == NULL) {
                free_dynarray_ptr(items);
                return NULL;
            }
            append_ptr(items, (intptr_t)pair);
            entry = entry->next;
        }
    }

    return items;
}
