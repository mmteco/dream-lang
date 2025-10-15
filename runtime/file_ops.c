#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "file_ops.h"

char* file_read(const char* path) {
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

int file_write(const char* path, const char* content) {
    FILE* file = fopen(path, "w");
    if (file == NULL) {
        return 0;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return written == len ? 1 : 0;
}

int file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return 0;
    }
    fclose(file);
    return 1;
}

int file_append(const char* path, const char* content) {
    FILE* file = fopen(path, "a");
    if (file == NULL) {
        return 0;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return written == len ? 1 : 0;
}

int file_delete(const char* path) {
    return remove(path) == 0 ? 1 : 0;
}
