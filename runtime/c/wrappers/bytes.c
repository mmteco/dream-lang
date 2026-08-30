#include "bytes.h"
#include "memory.h"
#include "dynarray.h"
#include <string.h>
#include <stdlib.h>
#include <limits.h>

/**
 * bytes 函数的 Dream 类型包装器
 *
 * Dream 类型映射:
 * - bytes: { i32, i32, i8* }* (dynarray_i32 in C)
 * - byte: i8 (int32_t in Dream, truncated to uint8_t)
 * - str: i8* (null-terminated C string)
 */

/**
 * __c_bytes_len: 获取 bytes 长度
 * Dream 签名: bytes -> int
 * LLVM 签名: { i32, i32, i8* }* -> i32
 */
int32_t __c_bytes_len(dynarray_i32* bytes_arr) {
    if (bytes_arr == NULL) return 0;
    return bytes_arr->length;
}

/**
 * __c_bytes_get: 获取第 i 个字节
 * Dream 签名: (bytes, index) -> byte
 * LLVM 签名: ({ i32, i32, i8* }*, i32) -> i32
 */
int32_t __c_bytes_get(dynarray_i32* bytes_arr, int32_t index) {
    if (bytes_arr == NULL || bytes_arr->data == NULL || index < 0 || index >= bytes_arr->length) {
        return -1;
    }
    // dynarray_i32 中存储的是 i32，但实际上是 byte (0-255)
    return bytes_arr->data[index] & 0xFF;
}

/**
 * __c_bytes_slice: bytes 切片
 * Dream 签名: (bytes, start, end) -> bytes
 * LLVM 签名: ({ i32, i32, i8* }*, i32, i32) -> { i32, i32, i8* }*
 */
dynarray_i32* __c_bytes_slice(dynarray_i32* bytes_arr, int32_t start, int32_t end) {
    if (bytes_arr == NULL) return __c_create_dynarray_i32(0);
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (start > bytes_arr->length) start = bytes_arr->length;
    if (end > bytes_arr->length) end = bytes_arr->length;
    if (start > end) start = end;

    int32_t new_length = end - start;
    dynarray_i32* result = __c_create_dynarray_i32(new_length);
    if (result == NULL) return NULL;

    if (new_length > 0 && bytes_arr->data != NULL) {
        memcpy(result->data, bytes_arr->data + start,
               (size_t)new_length * sizeof(int));
        result->length = new_length;
    }

    return result;
}

/**
 * __c_bytes_from_array: 从 list[byte] 创建 bytes
 * Dream 签名: list[byte] -> bytes
 * LLVM 签名: { i32, i32, i8* }* -> { i32, i32, i8* }*
 *
 * 注意: Dream 中 list[byte] 和 bytes 底层都是 dynarray_i32
 * 这个函数只是做一个浅拷贝
 */
dynarray_i32* __c_bytes_from_array(dynarray_i32* byte_list) {
    if (byte_list == NULL) {
        return __c_create_dynarray_i32(0);
    }

    // 创建新的 dynarray 并复制数据
    dynarray_i32* result = __c_create_dynarray_i32(byte_list->length);
    if (result == NULL) return NULL;
    if (byte_list->length > 0 && byte_list->data == NULL) {
        __c_free_dynarray_i32(result);
        return NULL;
    }
    for (int32_t i = 0; i < byte_list->length; i++) {
        result->data[i] = byte_list->data[i] & 0xFF;
    }
    result->length = byte_list->length;

    return result;
}

/**
 * __c_str_to_bytes: str 转 bytes
 * Dream 签名: str -> bytes
 * LLVM 签名: i8* -> { i32, i32, i8* }*
 */
dynarray_i32* __c_str_to_bytes(const char* str) {
    if (str == NULL) {
        return __c_create_dynarray_i32(0);
    }

    size_t string_length = strlen(str);
    if (string_length > INT32_MAX) return NULL;
    int32_t length = (int32_t)string_length;
    dynarray_i32* result = __c_create_dynarray_i32(length);
    if (result == NULL) return NULL;

    for (int32_t i = 0; i < length; i++) {
        result->data[i] = (uint8_t)str[i];
    }
    result->length = length;

    return result;
}

/**
 * __c_bytes_to_str: bytes 转 str
 * Dream 签名: bytes -> str
 * LLVM 签名: { i32, i32, i8* }* -> i8*
 */
char* __c_bytes_to_str(dynarray_i32* bytes_arr) {
    if (bytes_arr == NULL || bytes_arr->length == 0 || bytes_arr->data == NULL) {
        char* empty = (char*)gc_alloc(1, OBJ_STRING);
        if (empty == NULL) return NULL;
        empty[0] = '\0';
        return empty;
    }

    // 分配字符串内存 (+1 for null terminator)
    char* result = (char*)gc_alloc((size_t)bytes_arr->length + 1, OBJ_STRING);
    if (result == NULL) return NULL;

    // 复制字节数据
    for (int32_t i = 0; i < bytes_arr->length; i++) {
        result[i] = (char)(bytes_arr->data[i] & 0xFF);
    }
    result[bytes_arr->length] = '\0';

    return result;
}
