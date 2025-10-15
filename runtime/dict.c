#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "dict.h"

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
    unsigned int hash = hash_bytes_fnv1a(&key, sizeof(int));
    return hash % capacity;
}

int dict_hash_string(const char* key, int capacity) {
    if (key == NULL) return 0;
    unsigned int hash = hash_bytes_fnv1a(key, strlen(key));
    return hash % capacity;
}

dict_t* dict_create(dict_key_type key_type, dict_val_type val_type, int initial_capacity) {
    dict_t* dict = (dict_t*)malloc(sizeof(dict_t));
    if (!dict) return NULL;

    dict->key_type = key_type;
    dict->val_type = val_type;
    dict->capacity = initial_capacity > 0 ? initial_capacity : 16;
    dict->size = 0;
    dict->buckets = (dict_entry_t**)calloc(dict->capacity, sizeof(dict_entry_t*));

    if (!dict->buckets) {
        free(dict);
        return NULL;
    }

    return dict;
}

static int keys_equal(dict_t* dict, void* k1, void* k2) {
    if (dict->key_type == DICT_KEY_INT) {
        return (intptr_t)k1 == (intptr_t)k2;
    } else {
        return strcmp((char*)k1, (char*)k2) == 0;
    }
}

static void* copy_key(dict_t* dict, void* key) {
    if (dict->key_type == DICT_KEY_INT) {
        return key;
    } else {
        return strdup((char*)key);
    }
}

static void* copy_value(dict_t* dict, void* value) {
    if (dict->val_type == DICT_VAL_INT || dict->val_type == DICT_VAL_PTR) {
        return value;
    } else {
        return strdup((char*)value);
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
    }
}

static void dict_set_internal(dict_t* dict, void* key, void* value) {
    if (!dict) return;

    int index;
    if (dict->key_type == DICT_KEY_INT) {
        index = dict_hash_int((int)(intptr_t)key, dict->capacity);
    } else {
        index = dict_hash_string((char*)key, dict->capacity);
    }

    dict_entry_t* entry = dict->buckets[index];

    while (entry) {
        if (keys_equal(dict, entry->key, key)) {
            free_value(dict, entry->value);
            entry->value = copy_value(dict, value);
            return;
        }
        entry = entry->next;
    }

    dict_entry_t* new_entry = (dict_entry_t*)malloc(sizeof(dict_entry_t));
    if (!new_entry) return;

    new_entry->key = copy_key(dict, key);
    new_entry->value = copy_value(dict, value);
    new_entry->next = dict->buckets[index];
    dict->buckets[index] = new_entry;
    dict->size++;
}

static void* dict_get_internal(dict_t* dict, void* key, int* found) {
    if (!dict) {
        *found = 0;
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
            *found = 1;
            return entry->value;
        }
        entry = entry->next;
    }

    *found = 0;
    return NULL;
}

void dict_set_int_int(dict_t* dict, int key, int value) {
    dict_set_internal(dict, (void*)(intptr_t)key, (void*)(intptr_t)value);
}

void dict_set_int_str(dict_t* dict, int key, const char* value) {
    dict_set_internal(dict, (void*)(intptr_t)key, (void*)value);
}

void dict_set_int_ptr(dict_t* dict, int key, void* value) {
    dict_set_internal(dict, (void*)(intptr_t)key, value);
}

void dict_set_str_int(dict_t* dict, const char* key, int value) {
    dict_set_internal(dict, (void*)key, (void*)(intptr_t)value);
}

void dict_set_str_str(dict_t* dict, const char* key, const char* value) {
    dict_set_internal(dict, (void*)key, (void*)value);
}

void dict_set_str_ptr(dict_t* dict, const char* key, void* value) {
    dict_set_internal(dict, (void*)key, value);
}

int dict_get_int_int(dict_t* dict, int key, int* found) {
    void* value = dict_get_internal(dict, (void*)(intptr_t)key, found);
    return *found ? (int)(intptr_t)value : 0;
}

char* dict_get_int_str(dict_t* dict, int key, int* found) {
    void* value = dict_get_internal(dict, (void*)(intptr_t)key, found);
    return *found ? (char*)value : NULL;
}

void* dict_get_int_ptr(dict_t* dict, int key, int* found) {
    return dict_get_internal(dict, (void*)(intptr_t)key, found);
}

int dict_get_str_int(dict_t* dict, const char* key, int* found) {
    void* value = dict_get_internal(dict, (void*)key, found);
    return *found ? (int)(intptr_t)value : 0;
}

char* dict_get_str_str(dict_t* dict, const char* key, int* found) {
    void* value = dict_get_internal(dict, (void*)key, found);
    return *found ? (char*)value : NULL;
}

void* dict_get_str_ptr(dict_t* dict, const char* key, int* found) {
    return dict_get_internal(dict, (void*)key, found);
}

int dict_has_int(dict_t* dict, int key) {
    int found;
    dict_get_internal(dict, (void*)(intptr_t)key, &found);
    return found;
}

int dict_has_str(dict_t* dict, const char* key) {
    int found;
    dict_get_internal(dict, (void*)key, &found);
    return found;
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
    if (!dict) return;

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

void dict_free(dict_t* dict) {
    if (!dict) return;

    for (int i = 0; i < dict->capacity; i++) {
        dict_entry_t* entry = dict->buckets[i];
        while (entry) {
            dict_entry_t* next = entry->next;
            free_key(dict, entry->key);
            free_value(dict, entry->value);
            free(entry);
            entry = next;
        }
    }

    free(dict->buckets);
    free(dict);
}
