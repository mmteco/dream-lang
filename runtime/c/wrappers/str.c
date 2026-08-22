#include "str.h"
#include "utf8.h"
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

/**
 * Dream 语言字符串包装函数
 *
 * 这些函数提供 Dream 语言特定的字符串操作接口
 */

static bool is_ascii_range(const char* str, int start, int end) {
    for (int i = start; i < end; i++) {
        if ((unsigned char)str[i] >= 0x80) return false;
    }
    return true;
}

bool __c_range_equal(const char* str, int first_start, int first_end, int second_start, int second_end) {
    if (str == NULL) return false;
    if (first_end - first_start != second_end - second_start) return false;
    int length = first_end - first_start;
    if (length <= 0) return true;
    // ASCII 快路径：区间无高位字节时 rune 索引即字节索引，直接 memcmp
    if (is_ascii_range(str, first_start, first_end) && is_ascii_range(str, second_start, second_end)) {
        int first_byte_start = utf8_byte_offset(str, first_start);
        int second_byte_start = utf8_byte_offset(str, second_start);
        if (first_byte_start < 0 || second_byte_start < 0) return false;
        return memcmp(str + first_byte_start, str + second_byte_start, (size_t)length) == 0;
    }
    int first_byte_start = utf8_byte_offset(str, first_start);
    int second_byte_start = utf8_byte_offset(str, second_start);
    if (first_byte_start < 0 || second_byte_start < 0) return false;
    int first_byte_end = utf8_byte_offset(str, first_end);
    int second_byte_end = utf8_byte_offset(str, second_end);
    if (first_byte_end < 0 || second_byte_end < 0) return false;
    if (first_byte_end - first_byte_start != second_byte_end - second_byte_start) return false;
    return memcmp(str + first_byte_start, str + second_byte_start, (size_t)(first_byte_end - first_byte_start)) == 0;
}

bool __c_range_equals_cstr(const char* str, int start, int end, const char* cstr) {
    if (str == NULL || cstr == NULL || start < 0 || end < start) return false;
    int length = end - start;
    int cstr_length = (int)strlen(cstr);
    if (length != cstr_length) return false;
    if (is_ascii_range(str, start, end)) {
        int byte_start = utf8_byte_offset(str, start);
        if (byte_start < 0) return false;
        return memcmp(str + byte_start, cstr, (size_t)length) == 0;
    }
    int byte_start = utf8_byte_offset(str, start);
    int byte_end = utf8_byte_offset(str, end);
    if (byte_start < 0 || byte_end < byte_start) return false;
    return memcmp(str + byte_start, cstr, (size_t)(byte_end - byte_start)) == 0;
}

uint32_t __c_fnv_hash_range(const char* str, int start, int end) {
    uint32_t hash = 2166136261u;
    if (str == NULL || start < 0 || end < start) return hash;
    // ASCII 快路径：rune 索引即字节索引
    if (is_ascii_range(str, start, end)) {
        int byte_start = utf8_byte_offset(str, start);
        if (byte_start < 0) return hash;
        for (int i = 0; i < end - start; i++) {
            hash = hash * 16777619u + (uint32_t)(unsigned char)str[byte_start + i];
        }
        return hash;
    }
    int byte_start = utf8_byte_offset(str, start);
    int byte_end = utf8_byte_offset(str, end);
    if (byte_start < 0 || byte_end < byte_start) return hash;
    int byte_index = byte_start;
    while (byte_index < byte_end) {
        int bytes_read = 0;
        uint32_t rune = utf8_decode_rune((const uint8_t*)str, (size_t)byte_end, (size_t)byte_index, &bytes_read);
        if (bytes_read <= 0) {
            bytes_read = 1;
        }
        hash = hash * 16777619u + (uint32_t)rune;
        byte_index += bytes_read;
    }
    return hash;
}
