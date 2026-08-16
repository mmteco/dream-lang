#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "file.h"
#include "dynarray.h"

char* __c_file_read(const char* path) {
    if (path == NULL) {
        return NULL;
    }

    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return NULL;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }

    long file_size = ftell(file);
    if (file_size < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }

    char* buffer = (char*)malloc((size_t)file_size + 1);
    if (buffer == NULL) {
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, (size_t)file_size, file);
    if (ferror(file)) {
        free(buffer);
        fclose(file);
        return NULL;
    }

    buffer[bytes_read] = '\0';

    if (fclose(file) != 0) {
        free(buffer);
        return NULL;
    }

    return buffer;
}

int __c_file_write(const char* path, const char* content) {
    if (path == NULL || content == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "w");
    if (file == NULL) {
        return -1;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    if (written > INT_MAX || ferror(file) || fclose(file) != 0) {
        return -1;
    }

    return (int)written;
}

bool __c_file_exists(const char* path) {
    if (path == NULL) {
        return false;
    }

    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return false;
    }
    fclose(file);
    return true;
}

int __c_file_append(const char* path, const char* content) {
    if (path == NULL || content == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "a");
    if (file == NULL) {
        return -1;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    if (written > INT_MAX || ferror(file) || fclose(file) != 0) {
        return -1;
    }

    return (int)written;
}

bool __c_file_delete(const char* path) {
    if (path == NULL) {
        return false;
    }

    return !remove(path);
}

dynarray_i32* __c_file_read_bytes(const char* path) {
    if (path == NULL) {
        return NULL;
    }

    FILE* file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }

    long file_size = ftell(file);
    if (file_size < 0 || file_size > INT_MAX || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }

    dynarray_i32* arr = create_dynarray_i32(file_size);
    if (arr == NULL) {
        fclose(file);
        return NULL;
    }

    if (file_size > 0) {
        unsigned char* buffer = (unsigned char*)malloc((size_t)file_size);
        if (buffer == NULL) {
            free_dynarray_i32(arr);
            fclose(file);
            return NULL;
        }

        size_t bytes_read = fread(buffer, 1, (size_t)file_size, file);
        if (ferror(file)) {
            free(buffer);
            free_dynarray_i32(arr);
            fclose(file);
            return NULL;
        }

        for (size_t i = 0; i < bytes_read; i++) {
            arr->data[i] = (int)buffer[i];
        }
        arr->length = (int)bytes_read;
        free(buffer);
    }

    if (fclose(file) != 0) {
        free_dynarray_i32(arr);
        return NULL;
    }

    return arr;
}

int __c_file_write_bytes(const char* path, dynarray_i32* data) {
    if (path == NULL || data == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "wb");
    if (file == NULL) {
        return -1;
    }

    int len = len_dynarray_i32(data);
    unsigned char* buffer = NULL;
    if (len > 0) {
        buffer = (unsigned char*)malloc((size_t)len);
        if (buffer == NULL) {
            fclose(file);
            return -1;
        }
    }

    for (int i = 0; i < len; i++) {
        int byte_val = get_dynarray_i32(data, i);
        buffer[i] = (unsigned char)(byte_val & 0xFF);
    }

    size_t written = len > 0 ? fwrite(buffer, 1, (size_t)len, file) : 0;
    int close_result = fclose(file);

    free(buffer);
    if (written > INT_MAX || close_result != 0) {
        return -1;
    }

    return (int)written;
}

int __c_file_append_bytes(const char* path, dynarray_i32* data) {
    if (path == NULL || data == NULL) {
        return -1;
    }

    FILE* file = fopen(path, "ab");
    if (file == NULL) {
        return -1;
    }

    int len = len_dynarray_i32(data);
    unsigned char* buffer = NULL;
    if (len > 0) {
        buffer = (unsigned char*)malloc((size_t)len);
        if (buffer == NULL) {
            fclose(file);
            return -1;
        }
    }

    for (int i = 0; i < len; i++) {
        int byte_val = get_dynarray_i32(data, i);
        buffer[i] = (unsigned char)(byte_val & 0xFF);
    }

    size_t written = len > 0 ? fwrite(buffer, 1, (size_t)len, file) : 0;
    int close_result = fclose(file);

    free(buffer);
    if (written > INT_MAX || close_result != 0) {
        return -1;
    }

    return (int)written;
}
