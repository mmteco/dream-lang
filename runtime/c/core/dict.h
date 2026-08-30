#ifndef DREAM_DICT_H
#define DREAM_DICT_H

#include <stdbool.h>
#include "dynarray.h"

typedef enum {
    DICT_KEY_INT,
    DICT_KEY_STRING
} dict_key_type;

typedef enum {
    DICT_VAL_INT,
    DICT_VAL_STRING,
    DICT_VAL_PTR
} dict_val_type;

typedef struct dict_entry {
    void* key;
    void* value;
    struct dict_entry* next;
} dict_entry_t;

typedef struct {
    dict_key_type key_type;
    dict_val_type val_type;
    int capacity;
    int size;
    dict_entry_t** buckets;
} dict_t;

dict_t* dict_create(dict_key_type key_type, dict_val_type val_type, int initial_capacity);

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
bool __c_dict_has_str(dict_t* dict, const char* key);

void dict_remove_int(dict_t* dict, int key);
void dict_remove_str(dict_t* dict, const char* key);

int dict_size(dict_t* dict);
void dict_free(dict_t* dict);

// 释放字典内部资源；由 GC 在对象生命周期结束时调用。
void dict_destroy_contents(dict_t* dict);
void dict_release_contents(dict_t* dict);

int dict_hash_int(int key, int capacity);
int dict_hash_string(const char* key, int capacity);

#endif
