#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bytes.h"
#include "dict.h"
#include "file.h"
#include "memory.h"
#include "str.h"
#include "tuple.h"
#include "union.h"

static void test_dynarray_and_bytes(void) {
    dynarray_i32* values = create_dynarray_i32(1);
    assert(values != NULL);
    for (int value = 0; value < 100; value++) {
        append_i32(values, value);
    }
    assert(len_dynarray_i32(values) == 100);

    dynarray_i32* slice = slice_dynarray_i32(values, -10, 3);
    assert(slice != NULL && len_dynarray_i32(slice) == 3);
    assert(get_dynarray_i32(slice, 2) == 2);

    dynarray_i32* empty_slice = slice_dynarray_i32(values, 20, -1);
    assert(empty_slice != NULL && len_dynarray_i32(empty_slice) == 0);

    uint8_t raw_bytes[] = {0, 1, 127, 255};
    bytes_t* bytes = bytes_from_array(raw_bytes, 4);
    assert(bytes != NULL && bytes_length(bytes) == 4);
    assert(bytes_get(bytes, 3) == 255);
    assert(bytes_get(bytes, 4) == -1);

    char* text = bytes_to_str(bytes);
    assert(text != NULL);
    assert((unsigned char)text[3] == 255);
    free(text);

    free_dynarray_i32(empty_slice);
    free_dynarray_i32(slice);
    free_dynarray_i32(values);
    free_dynarray_i32(bytes);
}

static void test_utf8_and_strings(void) {
    const char* text = "你好，世界";
    assert(string_length(text) == 5);
    assert(string_char_at(text, 0) == 0x4f60);
    assert(string_char_at(text, 4) == 0x754c);
    assert(string_find(text, "世界") == 3);

    char* substring = string_substring(text, 1, 3);
    assert(substring != NULL && strcmp(substring, "好，") == 0);
    free(substring);

    char* replaced = string_replace("prefix-suffix", "suffix", "done");
    assert(replaced != NULL && strcmp(replaced, "prefix-done") == 0);
    free(replaced);

    char* invalid_old = string_replace("abc", "", "x");
    assert(invalid_old != NULL && strcmp(invalid_old, "abc") == 0);
    free(invalid_old);
}

static void test_file_io(void) {
    const char* path = "../../tmp/runtime_safety_test.bin";
    assert(__c_file_write(path, "") == 0);
    assert(__c_file_exists(path));

    char* content = __c_file_read(path);
    assert(content != NULL && strcmp(content, "") == 0);
    free(content);

    dynarray_i32* bytes = create_dynarray_i32(0);
    assert(bytes != NULL);
    assert(__c_file_write_bytes(path, bytes) == 0);
    dynarray_i32* read_bytes = __c_file_read_bytes(path);
    assert(read_bytes != NULL && len_dynarray_i32(read_bytes) == 0);

    free_dynarray_i32(read_bytes);
    free_dynarray_i32(bytes);
    assert(__c_file_delete(path));
}

static void test_dict_and_tuple(void) {
    dict_t* dict = dict_create(DICT_KEY_INT, DICT_VAL_INT, 2);
    assert(dict != NULL);
    for (int key = 0; key < 100; key++) {
        dict_set_int_int(dict, key, key * 2);
    }
    assert(dict_size(dict) == 100);
    assert(dict->capacity >= 128);

    bool found = false;
    assert(dict_get_int_int(dict, 42, &found) == 84 && found);
    assert(dict_get_int_int(dict, 1000, &found) == 0 && !found);

    dynarray_ptr* items = dict_items(dict);
    assert(items != NULL && len_dynarray_ptr(items) == 100);
    for (int index = 0; index < len_dynarray_ptr(items); index++) {
        tuple2_ptr* pair = (tuple2_ptr*)get_dynarray_ptr(items, index);
        assert(pair != NULL);
        if (index == 0) {
            assert((int)tuple2_ptr_get(pair, 0) >= 0);
        }
        tuple2_ptr_free(pair);
    }
    free_dynarray_ptr(items);

    dict_t* string_dict = dict_create(DICT_KEY_STRING, DICT_VAL_STRING, 2);
    assert(string_dict != NULL);
    dict_set_str_str(string_dict, "key", "value");
    assert(strcmp(dict_get_str_str(string_dict, "key", NULL), "value") == 0);
    dynarray_ptr* generic_items = dict_items(string_dict);
    assert(generic_items != NULL && len_dynarray_ptr(generic_items) == 1);
    tuple2_ptr* generic_pair = (tuple2_ptr*)get_dynarray_ptr(generic_items, 0);
    assert(generic_pair != NULL);
    assert(strcmp((const char*)tuple2_ptr_get(generic_pair, 0), "key") == 0);
    assert(strcmp((const char*)tuple2_ptr_get(generic_pair, 1), "value") == 0);
    tuple2_ptr_free(generic_pair);
    free_dynarray_ptr(generic_items);

    dict_free(string_dict);
    dict_free(dict);

    dict_t* cycle = dict_create(DICT_KEY_INT, DICT_VAL_PTR, 1);
    assert(cycle != NULL);
    dict_set_int_ptr(cycle, 1, cycle);
    dict_free(cycle);
    gc_collect();
    assert(!gc_is_managed(cycle));
}

static void test_union_null_safety(void) {
    union_t* string_union = union_create_string(NULL);
    assert(string_union != NULL && strcmp(union_get_string(string_union), "") == 0);
    assert(!union_try_get_int(string_union, NULL));

    union_t* struct_union = union_create_struct(NULL, NULL);
    assert(struct_union != NULL);
    assert(strcmp(union_get_struct_type(struct_union), "struct") == 0);

    union_release(string_union);
    union_release(struct_union);
}

int main(void) {
    test_dynarray_and_bytes();
    test_utf8_and_strings();
    test_file_io();
    test_dict_and_tuple();
    test_union_null_safety();
    gc_cleanup();
    puts("runtime safety tests passed");
    return 0;
}
