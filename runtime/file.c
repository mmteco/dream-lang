#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "file.h"
#include "dynarray.h"

char* __c_file_read(const char* path) {
    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = (char*)malloc(file_size + 1);
    if (buffer == NULL) {
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, file_size, file);
    buffer[bytes_read] = '\0';

    fclose(file);
    return buffer;
}

int __c_file_write(const char* path, const char* content) {
    FILE* file = fopen(path, "w");
    if (file == NULL) {
        return -1;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return (int)written;
}

int __c_file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return 0;
    }
    fclose(file);
    return 1;
}

int __c_file_append(const char* path, const char* content) {
    FILE* file = fopen(path, "a");
    if (file == NULL) {
        return -1;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return (int)written;
}

int __c_file_delete(const char* path) {
    return remove(path) == 0 ? 1 : 0;
}

dynarray_i32* __c_file_read_bytes(const char* path) {
    FILE* file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    dynarray_i32* arr = create_dynarray_i32(file_size);
    if (arr == NULL) {
        fclose(file);
        return NULL;
    }

    unsigned char* buffer = (unsigned char*)malloc(file_size);
    if (buffer == NULL) {
        free_dynarray_i32(arr);
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, file_size, file);
    for (size_t i = 0; i < bytes_read; i++) {
        append_i32(arr, (int)buffer[i]);
    }

    free(buffer);
    fclose(file);
    return arr;
}

int __c_file_write_bytes(const char* path, dynarray_i32* data) {
    if (data == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "wb");
    if (file == NULL) {
        return -1;
    }

    int len = len_dynarray_i32(data);
    unsigned char* buffer = (unsigned char*)malloc(len);
    if (buffer == NULL) {
        fclose(file);
        return -1;
    }

    for (int i = 0; i < len; i++) {
        int byte_val = get_dynarray_i32(data, i);
        buffer[i] = (unsigned char)(byte_val & 0xFF);
    }

    size_t written = fwrite(buffer, 1, len, file);

    free(buffer);
    fclose(file);
    return (int)written;
}

int __c_file_append_bytes(const char* path, dynarray_i32* data) {
    if (data == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "ab");
    if (file == NULL) {
        return -1;
    }

    int len = len_dynarray_i32(data);
    unsigned char* buffer = (unsigned char*)malloc(len);
    if (buffer == NULL) {
        fclose(file);
        return -1;
    }

    for (int i = 0; i < len; i++) {
        int byte_val = get_dynarray_i32(data, i);
        buffer[i] = (unsigned char)(byte_val & 0xFF);
    }

    size_t written = fwrite(buffer, 1, len, file);

    free(buffer);
    fclose(file);
    return (int)written;
}
