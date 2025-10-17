#include "bytes.h"
#include "memory.h"
#include <stdlib.h>
#include <string.h>

/**
 * 获取 bytes 的长度
 */
int32_t bytes_length(bytes_t* bytes) {
    if (bytes == NULL) return 0;
    return bytes->length;
}

/**
 * 获取 bytes 的第 i 个字节
 */
int32_t bytes_get(bytes_t* bytes, int32_t index) {
    if (bytes == NULL || index < 0 || index >= bytes->length) {
        return -1;
    }
    return (int32_t)bytes->data[index];
}

/**
 * bytes 切片
 */
bytes_t* bytes_slice(bytes_t* bytes, int32_t start, int32_t end) {
    if (bytes == NULL || start < 0 || end > bytes->length || start > end) {
        // 返回空 bytes
        bytes_t* empty = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
        empty->length = 0;
        empty->data = (uint8_t*)gc_alloc(1, OBJ_STRING);
        empty->data[0] = '\0';
        return empty;
    }

    int32_t new_length = end - start;

    // 分配新的 bytes 结构
    bytes_t* result = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
    result->length = new_length;

    // 分配并复制数据
    result->data = (uint8_t*)gc_alloc(new_length + 1, OBJ_STRING);
    memcpy(result->data, bytes->data + start, new_length);
    result->data[new_length] = '\0';  // 方便调试和与 str 兼容

    return result;
}

/**
 * 从 byte 数组创建 bytes
 */
bytes_t* bytes_from_array(uint8_t* data, int32_t length) {
    if (data == NULL || length < 0) {
        bytes_t* empty = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
        empty->length = 0;
        empty->data = (uint8_t*)gc_alloc(1, OBJ_STRING);
        empty->data[0] = '\0';
        return empty;
    }

    // 分配 bytes 结构
    bytes_t* result = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
    result->length = length;

    // 分配并复制数据
    result->data = (uint8_t*)gc_alloc(length + 1, OBJ_STRING);
    memcpy(result->data, data, length);
    result->data[length] = '\0';

    return result;
}

/**
 * str 转 bytes（类型转换）
 *
 * 在 Dream 中，str 和 bytes 在 LLVM IR 层面都是 { i32 length, i8* data }
 * 但在 C 中 str 是 char*，我们需要创建完整的结构
 */
bytes_t* str_to_bytes(const char* str) {
    if (str == NULL) {
        bytes_t* empty = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
        empty->length = 0;
        empty->data = (uint8_t*)gc_alloc(1, OBJ_STRING);
        empty->data[0] = '\0';
        return empty;
    }

    int32_t length = strlen(str);

    // 创建 bytes 结构
    bytes_t* result = (bytes_t*)gc_alloc(sizeof(bytes_t), OBJ_STRING);
    result->length = length;

    // 直接使用 str 的数据（假设 str 已经是 GC 管理的）
    // 如果 str 不是 GC 管理的，需要复制
    result->data = (uint8_t*)str;

    return result;
}

/**
 * bytes 转 str（类型转换）
 */
char* bytes_to_str(bytes_t* bytes) {
    if (bytes == NULL || bytes->data == NULL) {
        char* empty = (char*)gc_alloc(1, OBJ_STRING);
        empty[0] = '\0';
        return empty;
    }

    // 确保以 null 结尾（如果还没有）
    if (bytes->data[bytes->length] != '\0') {
        char* result = (char*)gc_alloc(bytes->length + 1, OBJ_STRING);
        memcpy(result, bytes->data, bytes->length);
        result[bytes->length] = '\0';
        return result;
    }

    // 直接返回数据指针
    return (char*)bytes->data;
}
