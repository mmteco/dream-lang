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
    return hash % capacity;
}

int dict_hash_string(const char* key, int capacity) {
    if (key == NULL || capacity <= 0) return 0;
    unsigned int hash = hash_bytes_fnv1a(key, strlen(key));
    return hash % capacity;
}

dict_t* dict_create(dict_key_type key_type, dict_val_type val_type, int initial_capacity) {
    dict_t* dict = (dict_t*)gc_alloc(sizeof(dict_t), OBJ_DICT);
    if (!dict) return NULL;

    dict->key_type = key_type;
    dict->val_type = val_type;
    dict->capacity = initial_capacity > 0 ? initial_capacity : 16;
    dict->buckets = NULL;
    dict->size = 0;
    if ((size_t)dict->capacity > SIZE_MAX / sizeof(dict_entry_t*)) {
        gc_release(dict);
        return NULL;
    }
    dict->buckets = (dict_entry_t**)calloc(dict->capacity, sizeof(dict_entry_t*));

    if (!dict->buckets) {
        gc_release(dict);
        return NULL;
    }

    return dict;
}

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

static bool keys_equal(dict_t* dict, void* k1, void* k2) {
    if (dict->key_type == DICT_KEY_INT) {
        return (intptr_t)k1 == (intptr_t)k2;
    } else {
        return k1 != NULL && k2 != NULL && strcmp((char*)k1, (char*)k2) == 0;
    }
}

static void* copy_key(dict_t* dict, void* key) {
    if (dict->key_type == DICT_KEY_INT) {
        return key;
    } else {
        return key == NULL ? NULL : strdup((char*)key);
    }
}

static void* copy_value(dict_t* dict, void* value) {
    if (dict->val_type == DICT_VAL_INT || dict->val_type == DICT_VAL_PTR) {
        return value;
    } else {
        return value == NULL ? strdup("") : strdup((char*)value);
    }
}

static void free_key(dict_t* dict, void* key) {
    if (dict->key_type == DICT_KEY_STRING) {
        free(key);
    }
}

static void free_value(dict_t* dict, void* value) {
    if (dict->val_type == DICT_VAL_STRING) {
        free(value);
    } else if (dict->val_type == DICT_VAL_PTR) {
        gc_release_if_managed(value);
    }
}

static bool dict_rehash(dict_t* dict, int new_capacity) {
    if (dict == NULL || new_capacity <= dict->capacity ||
        (size_t)new_capacity > SIZE_MAX / sizeof(dict_entry_t*)) {
        return false;
    }

    dict_entry_t** new_buckets = (dict_entry_t**)calloc(
        (size_t)new_capacity, sizeof(dict_entry_t*));
    if (new_buckets == NULL) {
        return false;
    }

    for (int bucket_index = 0; bucket_index < dict->capacity; bucket_index++) {
        dict_entry_t* entry = dict->buckets[bucket_index];
        while (entry != NULL) {
            dict_entry_t* next = entry->next;
            int new_index;
            if (dict->key_type == DICT_KEY_INT) {
                new_index = dict_hash_int((int)(intptr_t)entry->key, new_capacity);
            } else {
                new_index = dict_hash_string((char*)entry->key, new_capacity);
            }
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

static void dict_set_internal(dict_t* dict, void* key, void* value) {
    if (dict == NULL || dict->buckets == NULL ||
        (dict->key_type == DICT_KEY_STRING && key == NULL)) {
        return;
    }

    if (dict->size >= dict->capacity - dict->capacity / 4) {
        int new_capacity = dict->capacity > INT_MAX / 2 ? INT_MAX : dict->capacity * 2;
        dict_rehash(dict, new_capacity);
    }

    int index;
    if (dict->key_type == DICT_KEY_INT) {
        index = dict_hash_int((int)(intptr_t)key, dict->capacity);
    } else {
        index = dict_hash_string((char*)key, dict->capacity);
    }

    dict_entry_t* entry = dict->buckets[index];

    while (entry) {
        if (keys_equal(dict, entry->key, key)) {
            void* copied_value = copy_value(dict, value);
            if (dict->val_type == DICT_VAL_STRING && copied_value == NULL) {
                return;
            }
            free_value(dict, entry->value);
            entry->value = copied_value;
            if (dict->val_type == DICT_VAL_PTR) {
                gc_retain_if_managed(entry->value);
            }
            return;
        }
        entry = entry->next;
    }

    dict_entry_t* new_entry = (dict_entry_t*)malloc(sizeof(dict_entry_t));
    if (!new_entry) return;

    new_entry->key = copy_key(dict, key);
    new_entry->value = copy_value(dict, value);
    if ((dict->key_type == DICT_KEY_STRING && new_entry->key == NULL) ||
        (dict->val_type == DICT_VAL_STRING && new_entry->value == NULL)) {
        if (dict->key_type == DICT_KEY_STRING) {
            free(new_entry->key);
        }
        if (dict->val_type == DICT_VAL_STRING) {
            free(new_entry->value);
        }
        free(new_entry);
        return;
    }
    if (dict->val_type == DICT_VAL_PTR) {
        gc_retain_if_managed(new_entry->value);
    }
    new_entry->next = dict->buckets[index];
    dict->buckets[index] = new_entry;
    dict->size++;
}

static void* dict_get_internal(dict_t* dict, void* key, bool* found) {
    bool ignored_found;
    if (found == NULL) {
        found = &ignored_found;
    }

    if (dict == NULL || dict->buckets == NULL ||
        (dict->key_type == DICT_KEY_STRING && key == NULL)) {
        *found = false;
        return NULL;
    }

    int index;
    if (dict->key_type == DICT_KEY_INT) {
        index = dict_hash_int((int)(intptr_t)key, dict->capacity);
    } else {
        index = dict_hash_string((char*)key, dict->capacity);
    }

    dict_entry_t* entry = dict->buckets[index];

    while (entry) {
        if (keys_equal(dict, entry->key, key)) {
            *found = true;
            return entry->value;
        }
        entry = entry->next;
    }

    *found = false;
    return NULL;
}

void __c_dict_set_int_int(dict_t* dict, int key, int value) {
    dict_set_internal(dict, (void*)(intptr_t)key, (void*)(intptr_t)value);
}

void __c_dict_set_int_str(dict_t* dict, int key, const char* value) {
    dict_set_internal(dict, (void*)(intptr_t)key, (void*)value);
}

void __c_dict_set_int_ptr(dict_t* dict, int key, void* value) {
    dict_set_internal(dict, (void*)(intptr_t)key, value);
}

void __c_dict_set_str_int(dict_t* dict, const char* key, int value) {
    dict_set_internal(dict, (void*)key, (void*)(intptr_t)value);
}

void __c_dict_set_str_str(dict_t* dict, const char* key, const char* value) {
    dict_set_internal(dict, (void*)key, (void*)value);
}

void __c_dict_set_str_ptr(dict_t* dict, const char* key, void* value) {
    dict_set_internal(dict, (void*)key, value);
}

int dict_get_int_int(dict_t* dict, int key, bool* found) {
    bool local_found;
    bool* result_found = found == NULL ? &local_found : found;
    void* value = dict_get_internal(dict, (void*)(intptr_t)key, result_found);
    return *result_found ? (int)(intptr_t)value : 0;
}

char* dict_get_int_str(dict_t* dict, int key, bool* found) {
    bool local_found;
    bool* result_found = found == NULL ? &local_found : found;
    void* value = dict_get_internal(dict, (void*)(intptr_t)key, result_found);
    return *result_found ? (char*)value : NULL;
}

void* dict_get_int_ptr(dict_t* dict, int key, bool* found) {
    return dict_get_internal(dict, (void*)(intptr_t)key, found);
}

int dict_get_str_int(dict_t* dict, const char* key, bool* found) {
    bool local_found;
    bool* result_found = found == NULL ? &local_found : found;
    void* value = dict_get_internal(dict, (void*)key, result_found);
    return *result_found ? (int)(intptr_t)value : 0;
}

char* dict_get_str_str(dict_t* dict, const char* key, bool* found) {
    bool local_found;
    bool* result_found = found == NULL ? &local_found : found;
    void* value = dict_get_internal(dict, (void*)key, result_found);
    return *result_found ? (char*)value : NULL;
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

int __c_dict_size_int_int(dict_t* dict) {
    return dict_size(dict);
}

int __c_dict_size_int_str(dict_t* dict) {
    return dict_size(dict);
}

int __c_dict_size_str_int(dict_t* dict) {
    return dict_size(dict);
}

int __c_dict_size_str_str(dict_t* dict) {
    return dict_size(dict);
}

int __c_dict_size_int_ptr(dict_t* dict) {
    return dict_size(dict);
}

int __c_dict_size_str_ptr(dict_t* dict) {
    return dict_size(dict);
}

void* dict_get_str_ptr(dict_t* dict, const char* key, bool* found) {
    return dict_get_internal(dict, (void*)key, found);
}

bool dict_has_int(dict_t* dict, int key) {
    bool found;
    dict_get_internal(dict, (void*)(intptr_t)key, &found);
    return found;
}

bool dict_has_str(dict_t* dict, const char* key) {
    bool found;
    dict_get_internal(dict, (void*)key, &found);
    return found;
}

bool __c_dict_has_str(dict_t* dict, const char* key) {
    return dict_has_str(dict, key);
}

void dict_remove_int(dict_t* dict, int key) {
    if (!dict) return;

    int index = dict_hash_int(key, dict->capacity);
    dict_entry_t* entry = dict->buckets[index];
    dict_entry_t* prev = NULL;

    while (entry) {
        if (keys_equal(dict, entry->key, (void*)(intptr_t)key)) {
            if (prev) {
                prev->next = entry->next;
            } else {
                dict->buckets[index] = entry->next;
            }
            free_key(dict, entry->key);
            free_value(dict, entry->value);
            free(entry);
            dict->size--;
            return;
        }
        prev = entry;
        entry = entry->next;
    }
}

void dict_remove_str(dict_t* dict, const char* key) {
    if (!dict || key == NULL) return;

    int index = dict_hash_string(key, dict->capacity);
    dict_entry_t* entry = dict->buckets[index];
    dict_entry_t* prev = NULL;

    while (entry) {
        if (keys_equal(dict, entry->key, (void*)key)) {
            if (prev) {
                prev->next = entry->next;
            } else {
                dict->buckets[index] = entry->next;
            }
            free_key(dict, entry->key);
            free_value(dict, entry->value);
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
    if (dict == NULL || dict->buckets == NULL) return;

    for (int bucket_index = 0; bucket_index < dict->capacity; bucket_index++) {
        dict_entry_t* entry = dict->buckets[bucket_index];
        while (entry != NULL) {
            dict_entry_t* next = entry->next;
            free_key(dict, entry->key);
            if (release_references) {
                free_value(dict, entry->value);
            } else if (dict->val_type == DICT_VAL_STRING) {
                free(entry->value);
            }
            free(entry);
            entry = next;
        }
        dict->buckets[bucket_index] = NULL;
    }

    free(dict->buckets);
    dict->buckets = NULL;
    dict->size = 0;
}

void dict_destroy_contents(dict_t* dict) {
    dict_destroy_contents_internal(dict, 0);
}

void dict_release_contents(dict_t* dict) {
    dict_destroy_contents_internal(dict, 1);
}

void dict_free(dict_t* dict) {
    if (!dict) return;

    if (gc_is_managed(dict)) {
        gc_release(dict);
        return;
    }

    dict_release_contents(dict);
    free(dict);
}
