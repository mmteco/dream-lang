#ifndef DREAM_DICT_H
#define DREAM_DICT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "dynarray.h"

typedef enum {
    DICT_KEY_INT = 0,
    DICT_KEY_STRING = 1,
    DICT_KEY_PTR = 2
} dict_key_type;

typedef enum {
    DICT_VAL_INT = 0,
    DICT_VAL_STRING = 1,
    DICT_VAL_PTR = 2
} dict_val_type;

typedef struct dict_entry {
    void* key;
    void* value;
    struct dict_entry* next;
    struct dict_entry* order_next;
} dict_entry_t;

typedef uint32_t (*dict_hash_fn)(const void* key, int capacity);
typedef bool (*dict_eq_fn)(const void* k1, const void* k2);
typedef void* (*dict_copy_fn)(const void* data);
typedef void (*dict_free_fn)(void* data);

typedef struct {
    dict_hash_fn hash;
    dict_eq_fn key_eq;
    dict_copy_fn key_copy;
    dict_free_fn key_free;
    dict_copy_fn val_copy;
    dict_free_fn val_free;
    bool val_is_managed;
} dict_type_ops_t;

typedef struct {
    dict_key_type key_type;
    dict_val_type val_type;
    const dict_type_ops_t* ops;
    int capacity;
    int size;
    dict_entry_t** buckets;
    dict_entry_t* order_head;
    dict_entry_t* order_tail;
} dict_t;

// 通用核心 API
dict_t* dict_create(dict_key_type key_type, dict_val_type val_type, int initial_capacity);
dict_t* dict_create_custom(const dict_type_ops_t* ops, int initial_capacity);
void dict_set_value(dict_t* dict, void* key, void* value);
void* dict_lookup(dict_t* dict, void* key, bool* found);
bool dict_contains(dict_t* dict, void* key);
void dict_delete(dict_t* dict, void* key);
int dict_size(dict_t* dict);
void dict_free(dict_t* dict);

void dict_destroy_contents(dict_t* dict);
void dict_release_contents(dict_t* dict);

int dict_hash_int(int key, int capacity);
int dict_hash_string(const char* key, int capacity);

// 通用导出 API
dict_t* __c_dict_create(int key_type, int val_type, int initial_capacity);
void __c_dict_set(dict_t* dict, void* key, void* value);
void* __c_dict_get(dict_t* dict, void* key);
bool __c_dict_has(dict_t* dict, void* key);
int __c_dict_size(dict_t* dict);
void __c_dict_remove(dict_t* dict, void* key);

// 兼容单态 API（统一委托给通用核心）
dict_t* __c_dict_create_int_int(int initial_capacity);
dict_t* __c_dict_create_int_str(int initial_capacity);
dict_t* __c_dict_create_str_int(int initial_capacity);
dict_t* __c_dict_create_str_str(int initial_capacity);
dict_t* __c_dict_create_int_ptr(int initial_capacity);
dict_t* __c_dict_create_str_ptr(int initial_capacity);

void __c_dict_set_int_int(dict_t* dict, int key, int value);
void __c_dict_set_int_str(dict_t* dict, int key, const char* value);
void __c_dict_set_int_ptr(dict_t* dict, int key, void* value);
void __c_dict_set_str_int(dict_t* dict, const char* key, int value);
void __c_dict_set_str_str(dict_t* dict, const char* key, const char* value);
void __c_dict_set_str_ptr(dict_t* dict, const char* key, void* value);

int dict_get_int_int(dict_t* dict, int key, bool* found);
char* dict_get_int_str(dict_t* dict, int key, bool* found);
void* dict_get_int_ptr(dict_t* dict, int key, bool* found);
int dict_get_str_int(dict_t* dict, const char* key, bool* found);
char* dict_get_str_str(dict_t* dict, const char* key, bool* found);
void* dict_get_str_ptr(dict_t* dict, const char* key, bool* found);

int __c_dict_get_int_int(dict_t* dict, int key);
char* __c_dict_get_int_str(dict_t* dict, int key);
int __c_dict_get_str_int(dict_t* dict, const char* key);
char* __c_dict_get_str_str(dict_t* dict, const char* key);
void* __c_dict_get_int_ptr(dict_t* dict, int key);
void* __c_dict_get_str_ptr(dict_t* dict, const char* key);

int __c_dict_size_int_int(dict_t* dict);
int __c_dict_size_int_str(dict_t* dict);
int __c_dict_size_str_int(dict_t* dict);
int __c_dict_size_str_str(dict_t* dict);
int __c_dict_size_int_ptr(dict_t* dict);
int __c_dict_size_str_ptr(dict_t* dict);

bool dict_has_int(dict_t* dict, int key);
bool dict_has_str(dict_t* dict, const char* key);
bool __c_dict_has_int(dict_t* dict, int key);
bool __c_dict_has_str(dict_t* dict, const char* key);

void dict_remove_int(dict_t* dict, int key);
void dict_remove_str(dict_t* dict, const char* key);

#endif
