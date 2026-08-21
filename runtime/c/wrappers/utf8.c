#include "utf8.h"
#include "bytes.h"
#include "memory.h"
#include "dynarray.h"
#include <string.h>

/**
 * UTF-8 函数的 Dream 类型包装器
 *
 * Dream 类型映射:
 * - rune: i32 (u32 in C)
 * - bytes: { i32, i32, i8* }* (DynArray in Dream)
 * - str: i8* (null-terminated C string)
 * - tuple: { i32, i32 } 结构体（用于返回多个值）
 */

// 返回元组的结构
typedef struct {
    int32_t first;
    int32_t second;
} tuple2_i32_t;

/**
 * __c_utf8_decode_rune: 从 bytes 解码一个 rune
 * Dream 签名: (bytes, offset) -> (rune, bytes_read)
 * LLVM 签名: ({ i32, i32, i8* }*, i32) -> { i32, i32 }
 */
tuple2_i32_t __c_utf8_decode_rune(dynarray_i32* bytes_arr, int32_t offset) {
    tuple2_i32_t result = {0, 0};

    if (bytes_arr == NULL || bytes_arr->data == NULL || offset < 0 || offset >= bytes_arr->length) {
        return result;
    }

    // 从 dynarray 获取字节数据
    uint8_t* data = (uint8_t*)bytes_arr->data;
    int bytes_read = 0;

    uint32_t rune = utf8_decode_rune(data, (size_t)bytes_arr->length,
                                     (size_t)offset, &bytes_read);

    result.first = (int32_t)rune;
    result.second = bytes_read;
    return result;
}

/**
 * __c_utf8_encode_rune: 将 rune 编码为 UTF-8 bytes
 * Dream 签名: rune -> bytes
 * LLVM 签名: i32 -> { i32, i32, i8* }*
 */
dynarray_i32* __c_utf8_encode_rune(int32_t rune) {
    uint8_t buffer[4];
    int bytes_written = utf8_encode_rune((uint32_t)rune, buffer);

    if (bytes_written == 0) {
        // 无效 rune，返回空 bytes
        return create_dynarray_i32(0);
    }

    // 创建 dynarray 并复制数据
    dynarray_i32* result = create_dynarray_i32(bytes_written);
    if (result == NULL) return NULL;
    for (int i = 0; i < bytes_written; i++) {
        append_i32(result, buffer[i]);
    }

    return result;
}

/**
 * __c_utf8_rune_count: 获取 str 的 rune 数量
 * Dream 签名: str -> int
 * LLVM 签名: i8* -> i32
 */
int32_t __c_utf8_rune_count(const char* utf8_str) {
    if (utf8_str == NULL) return 0;
    return utf8_rune_count(utf8_str);
}

/**
 * __c_utf8_rune_at: 获取第 n 个 rune
 * Dream 签名: (str, index) -> rune
 * LLVM 签名: (i8*, i32) -> i32
 */
int32_t __c_utf8_rune_at(const char* utf8_str, int32_t rune_index) {
    if (utf8_str == NULL || rune_index < 0) return 0;
    return (int32_t)utf8_rune_at(utf8_str, rune_index);
}

/**
 * __c_rune_to_int: 将 rune 显式转换为 int
 * Dream 签名: rune -> int
 * LLVM 签名: i32 -> i32
 */
int32_t __c_rune_to_int(int32_t rune) {
    return rune;
}

/**
 * __c_utf8_byte_at: 获取指定字节
 * Dream 签名: (str, index) -> int
 * LLVM 签名: (i8*, i32) -> i32
 */
int32_t __c_utf8_byte_at(const char* utf8_str, int32_t byte_index) {
    if (utf8_str == NULL || byte_index < 0) return 0;
    if ((size_t)byte_index >= utf8_byte_length(utf8_str)) return 0;
    const unsigned char* bytes = (const unsigned char*)utf8_str;
    return (int32_t)bytes[byte_index];
}

/**
 * __c_utf8_byte_offset: 获取第 n 个 rune 的字节偏移
 * Dream 签名: (str, rune_index) -> int
 * LLVM 签名: (i8*, i32) -> i32
 */
int32_t __c_utf8_byte_offset(const char* utf8_str, int32_t rune_index) {
    if (utf8_str == NULL || rune_index < 0) return -1;
    return utf8_byte_offset(utf8_str, rune_index);
}
