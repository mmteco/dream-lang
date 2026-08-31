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
#include "net.h"
#include "str.h"
#include "tuple.h"
#include "union.h"

#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

static void test_dynarray_and_bytes(void) {
    dynarray_i32* values = __c_create_dynarray_i32(1);
    assert(values != NULL);
    for (int value = 0; value < 100; value++) {
        __c_append_i32(values, value);
    }
    assert(__c_len_dynarray_i32(values) == 100);

    dynarray_i32* slice = __c_slice_dynarray_i32(values, -10, 3);
    assert(slice != NULL && __c_len_dynarray_i32(slice) == 3);
    assert(__c_get_dynarray_i32(slice, 2) == 2);

    dynarray_i32* empty_slice = __c_slice_dynarray_i32(values, 20, -1);
    assert(empty_slice != NULL && __c_len_dynarray_i32(empty_slice) == 0);

    uint8_t raw_bytes[] = {0, 1, 127, 255};
    bytes_t* bytes = bytes_from_array(raw_bytes, 4);
    assert(bytes != NULL && bytes_length(bytes) == 4);
    assert(bytes_get(bytes, 3) == 255);
    assert(bytes_get(bytes, 4) == -1);

    char* text = bytes_to_str(bytes);
    assert(text != NULL);
    assert((unsigned char)text[3] == 255);
    free(text);

    __c_free_dynarray_i32(empty_slice);
    __c_free_dynarray_i32(slice);
    __c_free_dynarray_i32(values);
    __c_free_dynarray_i32(bytes);
}

static void test_utf8_and_strings(void) {
    const char* text = "你好，世界";
    assert(__c_str_len(text) == 5);
    assert(__c_str_char_at(text, 0) == 0x4f60);
    assert(__c_str_char_at(text, 4) == 0x754c);
    assert(__c_str_find(text, "世界") == 3);

    char* substring = __c_str_substring(text, 1, 3);
    assert(substring != NULL && strcmp(substring, "好，") == 0);
    free(substring);

    char* replaced = __c_str_replace("prefix-suffix", "suffix", "done");
    assert(replaced != NULL && strcmp(replaced, "prefix-done") == 0);
    free(replaced);

    char* invalid_old = __c_str_replace("abc", "", "x");
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

    dynarray_i32* bytes = __c_create_dynarray_i32(0);
    assert(bytes != NULL);
    assert(__c_file_write_bytes(path, bytes) == 0);
    dynarray_i32* read_bytes = __c_file_read_bytes(path);
    assert(read_bytes != NULL && __c_len_dynarray_i32(read_bytes) == 0);

    __c_free_dynarray_i32(read_bytes);
    __c_free_dynarray_i32(bytes);
    assert(__c_file_delete(path));
}

static void test_net_io(void) {
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    assert(listener >= 0);

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    assert(bind(listener, (struct sockaddr*)&address, sizeof(address)) == 0);
    assert(listen(listener, 1) == 0);

    socklen_t address_length = sizeof(address);
    assert(getsockname(listener, (struct sockaddr*)&address, &address_length) == 0);
    int port = ntohs(address.sin_port);

    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        int client = accept(listener, NULL, NULL);
        if (client < 0) _exit(1);

        char request[4];
        ssize_t received = recv(client, request, sizeof(request), MSG_WAITALL);
        if (received != 4 || memcmp(request, "ping", 4) != 0) _exit(1);
        if (send(client, "pong", 4, 0) != 4) _exit(1);
        close(client);
        close(listener);
        _exit(0);
    }

    int32_t connection = __c_net_connect("127.0.0.1", port);
    assert(connection >= 0);
    assert(__c_net_write(connection, "ping") == 4);

    char* response = __c_net_read(connection, 4);
    assert(response != NULL && strcmp(response, "pong") == 0);
    assert(__c_net_close(connection));

    int child_status = 0;
    assert(waitpid(child, &child_status, 0) == child);
    assert(WIFEXITED(child_status) && WEXITSTATUS(child_status) == 0);
    close(listener);
}

static void test_dict_and_tuple(void) {
    dict_t* dict = dict_create(DICT_KEY_INT, DICT_VAL_INT, 2);
    assert(dict != NULL);
    for (int key = 0; key < 100; key++) {
        __c_dict_set_int_int(dict, key, key * 2);
    }
    assert(dict_size(dict) == 100);
    assert(dict->capacity >= 128);

    bool found = false;
    assert(dict_get_int_int(dict, 42, &found) == 84 && found);
    assert(dict_get_int_int(dict, 1000, &found) == 0 && !found);

    dynarray_ptr* items = dict_items(dict);
    assert(items != NULL && __c_len_dynarray_ptr(items) == 100);
    for (int index = 0; index < __c_len_dynarray_ptr(items); index++) {
        tuple2_ptr* pair = (tuple2_ptr*)__c_get_dynarray_ptr(items, index);
        assert(pair != NULL);
        assert((int)tuple2_ptr_get(pair, 0) == index);
        assert((int)tuple2_ptr_get(pair, 1) == index * 2);
        tuple2_ptr_free(pair);
    }
    __c_free_dynarray_ptr(items);

    dict_t* string_dict = dict_create(DICT_KEY_STRING, DICT_VAL_STRING, 2);
    assert(string_dict != NULL);
    __c_dict_set_str_str(string_dict, "key", "value");
    assert(strcmp(dict_get_str_str(string_dict, "key", NULL), "value") == 0);
    dynarray_ptr* generic_items = dict_items(string_dict);
    assert(generic_items != NULL && __c_len_dynarray_ptr(generic_items) == 1);
    tuple2_ptr* generic_pair = (tuple2_ptr*)__c_get_dynarray_ptr(generic_items, 0);
    assert(generic_pair != NULL);
    assert(strcmp((const char*)tuple2_ptr_get(generic_pair, 0), "key") == 0);
    assert(strcmp((const char*)tuple2_ptr_get(generic_pair, 1), "value") == 0);
    tuple2_ptr_free(generic_pair);
    __c_free_dynarray_ptr(generic_items);

    dict_free(string_dict);
    dict_free(dict);

    dict_t* cycle = dict_create(DICT_KEY_INT, DICT_VAL_PTR, 1);
    assert(cycle != NULL);
    __c_dict_set_int_ptr(cycle, 1, cycle);
    dict_free(cycle);
    gc_collect();
    assert(!gc_is_managed(cycle));
}

static void test_union_null_safety(void) {
    union_t* string_union = __c_union_create_str(NULL);
    assert(string_union != NULL && strcmp(__c_union_get_str(string_union), "") == 0);
    assert(!__c_union_try_get_int(string_union, NULL));

    union_t* struct_union = __c_union_create_struct(NULL, NULL);
    assert(struct_union != NULL);
    assert(strcmp(__c_union_get_struct_type(struct_union), "struct") == 0);

    __c_union_release(string_union);
    __c_union_release(struct_union);
}

int main(void) {
    test_dynarray_and_bytes();
    test_utf8_and_strings();
    test_file_io();
    test_net_io();
    test_dict_and_tuple();
    test_union_null_safety();
    gc_cleanup();
    puts("runtime safety tests passed");
    return 0;
}
