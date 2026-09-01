#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#include "dict.h"
#include "memory.h"

static unsigned int hash_bytes_fnv1a(const void* data, size_t len) {
    const unsigned char* bytes = (const unsigned char*)data;
    unsigned int hash = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        hash ^= bytes[i];
        hash *= 16777619u;
    }
    return hash;
}

int dict_hash_int(int key, int capacity) {
    if (capacity <= 0) return 0;
    unsigned int hash = hash_bytes_fnv1a(&key, sizeof(int));
    return (int)(hash % (unsigned int)capacity);
}

int dict_hash_string(const char* key, int capacity) {
    if (key == NULL || capacity <= 0) return 0;
    unsigned int hash = hash_bytes_fnv1a(key, strlen(key));
    return (int)(hash % (unsigned int)capacity);
}

static uint32_t op_hash_int(const void* key, int capacity) {
    return (uint32_t)dict_hash_int((int)(intptr_t)key, capacity);
}

static bool op_eq_int(const void* k1, const void* k2) {
    return (intptr_t)k1 == (intptr_t)k2;
}

static void* op_copy_direct(const void* data) {
    return (void*)data;
}

static void op_free_noop(void* data) {
    (void)data;
}

static uint32_t op_hash_str(const void* key, int capacity) {
    return (uint32_t)dict_hash_string((const char*)key, capacity);
}

static bool op_eq_str(const void* k1, const void* k2) {
    return k1 != NULL && k2 != NULL && strcmp((const char*)k1, (const char*)k2) == 0;
}

static void* op_copy_str(const void* data) {
    return data == NULL ? strdup("") : strdup((const char*)data);
}

static void op_free_str(void* data) {
    if (data != NULL) free(data);
}

static void* op_copy_str_key(const void* data) {
    return data == NULL ? NULL : strdup((const char*)data);
}

static void op_free_ptr_val(void* data) {
    gc_release_if_managed(data);
}

static const dict_type_ops_t G_OPS_INT_INT = {
    .hash = op_hash_int, .key_eq = op_eq_int, .key_copy = op_copy_direct,
    .key_free = op_free_noop, .val_copy = op_copy_direct, .val_free = op_free_noop,
    .val_is_managed = false
};

static const dict_type_ops_t G_OPS_INT_STR = {
    .hash = op_hash_int, .key_eq = op_eq_int, .key_copy = op_copy_direct,
    .key_free = op_free_noop, .val_copy = op_copy_str, .val_free = op_free_str,
    .val_is_managed = false
};

static const dict_type_ops_t G_OPS_INT_PTR = {
    .hash = op_hash_int, .key_eq = op_eq_int, .key_copy = op_copy_direct,
    .key_free = op_free_noop, .val_copy = op_copy_direct, .val_free = op_free_ptr_val,
    .val_is_managed = true
};

static const dict_type_ops_t G_OPS_STR_INT = {
    .hash = op_hash_str, .key_eq = op_eq_str, .key_copy = op_copy_str_key,
    .key_free = op_free_str, .val_copy = op_copy_direct, .val_free = op_free_noop,
    .val_is_managed = false
};

static const dict_type_ops_t G_OPS_STR_STR = {
    .hash = op_hash_str, .key_eq = op_eq_str, .key_copy = op_copy_str_key,
    .key_free = op_free_str, .val_copy = op_copy_str, .val_free = op_free_str,
    .val_is_managed = false
};

static const dict_type_ops_t G_OPS_STR_PTR = {
    .hash = op_hash_str, .key_eq = op_eq_str, .key_copy = op_copy_str_key,
    .key_free = op_free_str, .val_copy = op_copy_direct, .val_free = op_free_ptr_val,
    .val_is_managed = true
};

static const dict_type_ops_t* get_default_ops(dict_key_type key_type, dict_val_type val_type) {
    if (key_type == DICT_KEY_INT) {
        if (val_type == DICT_VAL_STRING) return &G_OPS_INT_STR;
        if (val_type == DICT_VAL_PTR) return &G_OPS_INT_PTR;
        return &G_OPS_INT_INT;
    }
    if (val_type == DICT_VAL_INT) return &G_OPS_STR_INT;
    if (val_type == DICT_VAL_STRING) return &G_OPS_STR_STR;
    return &G_OPS_STR_PTR;
}

dict_t* dict_create(dict_key_type key_type, dict_val_type val_type, int initial_capacity) {
    dict_t* dict = (dict_t*)gc_alloc(sizeof(dict_t), OBJ_DICT);
    if (!dict) return NULL;

    dict->key_type = key_type;
    dict->val_type = val_type;
    dict->ops = get_default_ops(key_type, val_type);
    dict->capacity = initial_capacity > 0 ? initial_capacity : 16;
    dict->size = 0;
    dict->order_head = NULL;
    dict->order_tail = NULL;
    dict->buckets = (dict_entry_t**)calloc((size_t)dict->capacity, sizeof(dict_entry_t*));
    if (!dict->buckets) {
        gc_release(dict);
        return NULL;
    }
    return dict;
}

dict_t* dict_create_custom(const dict_type_ops_t* ops, int initial_capacity) {
    dict_t* dict = (dict_t*)gc_alloc(sizeof(dict_t), OBJ_DICT);
    if (!dict) return NULL;

    dict->key_type = DICT_KEY_PTR;
    dict->val_type = DICT_VAL_PTR;
    dict->ops = ops ? ops : &G_OPS_STR_PTR;
    dict->capacity = initial_capacity > 0 ? initial_capacity : 16;
    dict->size = 0;
    dict->order_head = NULL;
    dict->order_tail = NULL;
    dict->buckets = (dict_entry_t**)calloc((size_t)dict->capacity, sizeof(dict_entry_t*));
    if (!dict->buckets) {
        gc_release(dict);
        return NULL;
    }
    return dict;
}

static void dict_unlink_order(dict_t* dict, dict_entry_t* target) {
    if (!dict || !target) return;
    dict_entry_t* previous = NULL;
    dict_entry_t* entry = dict->order_head;
    while (entry != NULL && entry != target) {
        previous = entry;
        entry = entry->order_next;
    }
    if (entry == NULL) return;

    if (previous == NULL) {
        dict->order_head = entry->order_next;
    } else {
        previous->order_next = entry->order_next;
    }
    if (dict->order_tail == entry) {
        dict->order_tail = previous;
    }
    entry->order_next = NULL;
}

static bool dict_rehash(dict_t* dict, int new_capacity) {
    if (!dict || new_capacity <= dict->capacity || (size_t)new_capacity > SIZE_MAX / sizeof(dict_entry_t*)) {
        return false;
    }
    dict_entry_t** new_buckets = (dict_entry_t**)calloc((size_t)new_capacity, sizeof(dict_entry_t*));
    if (!new_buckets) return false;

    for (int i = 0; i < dict->capacity; i++) {
        dict_entry_t* entry = dict->buckets[i];
        while (entry != NULL) {
            dict_entry_t* next = entry->next;
            int new_index = (int)(dict->ops->hash(entry->key, new_capacity));
            entry->next = new_buckets[new_index];
            new_buckets[new_index] = entry;
            entry = next;
        }
    }

    free(dict->buckets);
    dict->buckets = new_buckets;
    dict->capacity = new_capacity;
    return true;
}

void dict_set_value(dict_t* dict, void* key, void* value) {
    if (!dict || !dict->buckets || !dict->ops) return;
    if (dict->key_type == DICT_KEY_STRING && key == NULL) return;

    if (dict->size >= dict->capacity - dict->capacity / 4) {
        int new_capacity = dict->capacity > INT_MAX / 2 ? INT_MAX : dict->capacity * 2;
        dict_rehash(dict, new_capacity);
    }

    int index = (int)(dict->ops->hash(key, dict->capacity));
    dict_entry_t* entry = dict->buckets[index];

    while (entry) {
        if (dict->ops->key_eq(entry->key, key)) {
            void* copied_value = dict->ops->val_copy(value);
            if (dict->val_type == DICT_VAL_STRING && copied_value == NULL) return;
            dict->ops->val_free(entry->value);
            entry->value = copied_value;
            if (dict->ops->val_is_managed) {
                gc_retain_if_managed(entry->value);
            }
            return;
        }
        entry = entry->next;
    }

    dict_entry_t* new_entry = (dict_entry_t*)malloc(sizeof(dict_entry_t));
    if (!new_entry) return;

    new_entry->key = dict->ops->key_copy(key);
    new_entry->value = dict->ops->val_copy(value);
    if ((dict->key_type == DICT_KEY_STRING && new_entry->key == NULL) ||
        (dict->val_type == DICT_VAL_STRING && new_entry->value == NULL)) {
        dict->ops->key_free(new_entry->key);
        dict->ops->val_free(new_entry->value);
        free(new_entry);
        return;
    }
    if (dict->ops->val_is_managed) {
        gc_retain_if_managed(new_entry->value);
    }
    new_entry->next = dict->buckets[index];
    new_entry->order_next = NULL;
    dict->buckets[index] = new_entry;
    if (dict->order_tail == NULL) {
        dict->order_head = new_entry;
    } else {
        dict->order_tail->order_next = new_entry;
    }
    dict->order_tail = new_entry;
    dict->size++;
}

void* dict_lookup(dict_t* dict, void* key, bool* found) {
    bool local_found;
    if (!found) found = &local_found;

    if (!dict || !dict->buckets || !dict->ops || (dict->key_type == DICT_KEY_STRING && key == NULL)) {
        *found = false;
        return NULL;
    }

    int index = (int)(dict->ops->hash(key, dict->capacity));
    dict_entry_t* entry = dict->buckets[index];

    while (entry) {
        if (dict->ops->key_eq(entry->key, key)) {
            *found = true;
            return entry->value;
        }
        entry = entry->next;
    }

    *found = false;
    return NULL;
}

bool dict_contains(dict_t* dict, void* key) {
    bool found = false;
    dict_lookup(dict, key, &found);
    return found;
}

void dict_delete(dict_t* dict, void* key) {
    if (!dict || !dict->buckets || !dict->ops || (dict->key_type == DICT_KEY_STRING && key == NULL)) {
        return;
    }

    int index = (int)(dict->ops->hash(key, dict->capacity));
    dict_entry_t* entry = dict->buckets[index];
    dict_entry_t* prev = NULL;

    while (entry) {
        if (dict->ops->key_eq(entry->key, key)) {
            if (prev) {
                prev->next = entry->next;
            } else {
                dict->buckets[index] = entry->next;
            }
            dict_unlink_order(dict, entry);
            dict->ops->key_free(entry->key);
            dict->ops->val_free(entry->value);
            free(entry);
            dict->size--;
            return;
        }
        prev = entry;
        entry = entry->next;
    }
}

int dict_size(dict_t* dict) {
    return dict ? dict->size : 0;
}

static void dict_destroy_contents_internal(dict_t* dict, int release_references) {
    if (!dict || !dict->buckets || !dict->ops) return;

    for (int i = 0; i < dict->capacity; i++) {
        dict_entry_t* entry = dict->buckets[i];
        while (entry != NULL) {
            dict_entry_t* next = entry->next;
            dict->ops->key_free(entry->key);
            if (release_references) {
                dict->ops->val_free(entry->value);
            } else if (dict->val_type == DICT_VAL_STRING) {
                free(entry->value);
            }
            free(entry);
            entry = next;
        }
        dict->buckets[i] = NULL;
    }

    free(dict->buckets);
    dict->buckets = NULL;
    dict->size = 0;
    dict->capacity = 0;
    dict->order_head = NULL;
    dict->order_tail = NULL;
}

void dict_destroy_contents(dict_t* dict) {
    dict_destroy_contents_internal(dict, 0);
}

void dict_release_contents(dict_t* dict) {
    dict_destroy_contents_internal(dict, 1);
}

void dict_free(dict_t* dict) {
    if (!dict) return;
    dict_release_contents(dict);
    gc_release(dict);
}

// 通用导出 API
dict_t* __c_dict_create(int key_type, int val_type, int initial_capacity) {
    return dict_create((dict_key_type)key_type, (dict_val_type)val_type, initial_capacity);
}

void __c_dict_set(dict_t* dict, void* key, void* value) {
    dict_set_value(dict, key, value);
}

void* __c_dict_get(dict_t* dict, void* key) {
    return dict_lookup(dict, key, NULL);
}

bool __c_dict_has(dict_t* dict, void* key) {
    return dict_contains(dict, key);
}

int __c_dict_size(dict_t* dict) {
    return dict_size(dict);
}

void __c_dict_remove(dict_t* dict, void* key) {
    dict_delete(dict, key);
}

// 兼容单态 API 委托实现
dict_t* __c_dict_create_int_int(int initial_capacity) {
    return dict_create(DICT_KEY_INT, DICT_VAL_INT, initial_capacity);
}
dict_t* __c_dict_create_int_str(int initial_capacity) {
    return dict_create(DICT_KEY_INT, DICT_VAL_STRING, initial_capacity);
}
dict_t* __c_dict_create_str_int(int initial_capacity) {
    return dict_create(DICT_KEY_STRING, DICT_VAL_INT, initial_capacity);
}
dict_t* __c_dict_create_str_str(int initial_capacity) {
    return dict_create(DICT_KEY_STRING, DICT_VAL_STRING, initial_capacity);
}
dict_t* __c_dict_create_int_ptr(int initial_capacity) {
    return dict_create(DICT_KEY_INT, DICT_VAL_PTR, initial_capacity);
}
dict_t* __c_dict_create_str_ptr(int initial_capacity) {
    return dict_create(DICT_KEY_STRING, DICT_VAL_PTR, initial_capacity);
}

void __c_dict_set_int_int(dict_t* dict, int key, int value) {
    dict_set_value(dict, (void*)(intptr_t)key, (void*)(intptr_t)value);
}
void __c_dict_set_int_str(dict_t* dict, int key, const char* value) {
    dict_set_value(dict, (void*)(intptr_t)key, (void*)value);
}
void __c_dict_set_int_ptr(dict_t* dict, int key, void* value) {
    dict_set_value(dict, (void*)(intptr_t)key, value);
}
void __c_dict_set_str_int(dict_t* dict, const char* key, int value) {
    dict_set_value(dict, (void*)key, (void*)(intptr_t)value);
}
void __c_dict_set_str_str(dict_t* dict, const char* key, const char* value) {
    dict_set_value(dict, (void*)key, (void*)value);
}
void __c_dict_set_str_ptr(dict_t* dict, const char* key, void* value) {
    dict_set_value(dict, (void*)key, value);
}

int dict_get_int_int(dict_t* dict, int key, bool* found) {
    bool f;
    void* v = dict_lookup(dict, (void*)(intptr_t)key, found ? found : &f);
    return (found ? *found : f) ? (int)(intptr_t)v : 0;
}
char* dict_get_int_str(dict_t* dict, int key, bool* found) {
    return (char*)dict_lookup(dict, (void*)(intptr_t)key, found);
}
void* dict_get_int_ptr(dict_t* dict, int key, bool* found) {
    return dict_lookup(dict, (void*)(intptr_t)key, found);
}
int dict_get_str_int(dict_t* dict, const char* key, bool* found) {
    bool f;
    void* v = dict_lookup(dict, (void*)key, found ? found : &f);
    return (found ? *found : f) ? (int)(intptr_t)v : 0;
}
char* dict_get_str_str(dict_t* dict, const char* key, bool* found) {
    return (char*)dict_lookup(dict, (void*)key, found);
}
void* dict_get_str_ptr(dict_t* dict, const char* key, bool* found) {
    return dict_lookup(dict, (void*)key, found);
}

int __c_dict_get_int_int(dict_t* dict, int key) {
    return dict_get_int_int(dict, key, NULL);
}
char* __c_dict_get_int_str(dict_t* dict, int key) {
    return dict_get_int_str(dict, key, NULL);
}
int __c_dict_get_str_int(dict_t* dict, const char* key) {
    return dict_get_str_int(dict, key, NULL);
}
char* __c_dict_get_str_str(dict_t* dict, const char* key) {
    return dict_get_str_str(dict, key, NULL);
}
void* __c_dict_get_int_ptr(dict_t* dict, int key) {
    return dict_get_int_ptr(dict, key, NULL);
}
void* __c_dict_get_str_ptr(dict_t* dict, const char* key) {
    return dict_get_str_ptr(dict, key, NULL);
}

int __c_dict_size_int_int(dict_t* dict) { return dict_size(dict); }
int __c_dict_size_int_str(dict_t* dict) { return dict_size(dict); }
int __c_dict_size_str_int(dict_t* dict) { return dict_size(dict); }
int __c_dict_size_str_str(dict_t* dict) { return dict_size(dict); }
int __c_dict_size_int_ptr(dict_t* dict) { return dict_size(dict); }
int __c_dict_size_str_ptr(dict_t* dict) { return dict_size(dict); }

bool dict_has_int(dict_t* dict, int key) {
    return dict_contains(dict, (void*)(intptr_t)key);
}
bool dict_has_str(dict_t* dict, const char* key) {
    return dict_contains(dict, (void*)key);
}
bool __c_dict_has_int(dict_t* dict, int key) {
    return dict_has_int(dict, key);
}
bool __c_dict_has_str(dict_t* dict, const char* key) {
    return dict_has_str(dict, key);
}

void dict_remove_int(dict_t* dict, int key) {
    dict_delete(dict, (void*)(intptr_t)key);
}
void dict_remove_str(dict_t* dict, const char* key) {
    dict_delete(dict, (void*)key);
}
