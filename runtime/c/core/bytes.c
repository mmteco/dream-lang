#include "bytes.h"
#include <limits.h>
#include <stdlib.h>
#include <string.h>

int32_t bytes_length(bytes_t* bytes) {
    return bytes == NULL ? 0 : bytes->length;
}

int32_t bytes_get(bytes_t* bytes, int32_t index) {
    if (bytes == NULL || bytes->data == NULL || index < 0 || index >= bytes->length) return -1;
    return bytes->data[index] & 0xFF;
}

bytes_t* bytes_slice(bytes_t* bytes, int32_t start, int32_t end) {
    if (bytes == NULL) return __c_create_dynarray_i32(0);
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (start > bytes->length) start = bytes->length;
    if (end > bytes->length) end = bytes->length;
    if (start > end) start = end;

    int32_t length = end - start;
    bytes_t* result = __c_create_dynarray_i32(length);
    if (result == NULL) return NULL;
    if (length > 0 && bytes->data != NULL) {
        memcpy(result->data, bytes->data + start, (size_t)length * sizeof(int));
        result->length = length;
    }
    return result;
}

bytes_t* bytes_from_array(uint8_t* data, int32_t length) {
    if (data == NULL || length <= 0) return __c_create_dynarray_i32(0);

    bytes_t* result = __c_create_dynarray_i32(length);
    if (result == NULL) return NULL;
    for (int32_t index = 0; index < length; index++) {
        result->data[index] = data[index];
    }
    result->length = length;
    return result;
}

bytes_t* str_to_bytes(const char* str) {
    if (str == NULL) return __c_create_dynarray_i32(0);

    size_t string_length = strlen(str);
    if (string_length > INT_MAX) return NULL;
    bytes_t* result = __c_create_dynarray_i32((int)string_length);
    if (result == NULL) return NULL;
    for (size_t index = 0; index < string_length; index++) {
        result->data[index] = (unsigned char)str[index];
    }
    result->length = (int)string_length;
    return result;
}

char* bytes_to_str(bytes_t* bytes) {
    if (bytes == NULL || bytes->length <= 0 || bytes->data == NULL) {
        char* empty = (char*)malloc(1);
        if (empty != NULL) empty[0] = '\0';
        return empty;
    }

    char* result = (char*)malloc((size_t)bytes->length + 1);
    if (result == NULL) return NULL;
    for (int32_t index = 0; index < bytes->length; index++) {
        result[index] = (char)(bytes->data[index] & 0xFF);
    }
    result[bytes->length] = '\0';
    return result;
}
