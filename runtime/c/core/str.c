#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "str.h"
#include "dynarray.h"
#include "memory.h"
#include "utf8.h"

static char* allocate_empty_string(void) {
    char* result = (char*)malloc(1);
    if (result != NULL) result[0] = '\0';
    return result;
}

static uint32_t unicode_to_upper(uint32_t rune) {
    if (rune >= 'a' && rune <= 'z') return rune - ('a' - 'A');
    if ((rune >= 0xE0 && rune <= 0xF6) || (rune >= 0xF8 && rune <= 0xFE)) {
        return rune - 0x20;
    }
    if (rune == 0xFF) return 0x178;
    if (rune >= 0x3B1 && rune <= 0x3C1) return rune - 0x20;
    if (rune == 0x3C2) return 0x3A3;
    if (rune >= 0x3C3 && rune <= 0x3CB) return rune - 0x20;
    if (rune == 0x3AC) return 0x386;
    if (rune == 0x3AD) return 0x388;
    if (rune == 0x3AE) return 0x389;
    if (rune == 0x3AF) return 0x38A;
    if (rune == 0x3CC) return 0x38C;
    if (rune == 0x3CD) return 0x38E;
    if (rune == 0x3CE) return 0x38F;
    if (rune >= 0x430 && rune <= 0x44F) return rune - 0x20;
    if (rune >= 0x561 && rune <= 0x586) return rune - 0x30;
    if ((rune >= 0x100 && rune <= 0x12F) ||
        (rune >= 0x14A && rune <= 0x177)) {
        return (rune & 1) == 1 ? rune - 1 : rune;
    }
    return rune;
}

static uint32_t unicode_to_lower(uint32_t rune) {
    if (rune >= 'A' && rune <= 'Z') return rune + ('a' - 'A');
    if ((rune >= 0xC0 && rune <= 0xD6) || (rune >= 0xD8 && rune <= 0xDE)) {
        return rune + 0x20;
    }
    if (rune == 0x178) return 0xFF;
    if ((rune >= 0x391 && rune <= 0x3A1) || (rune >= 0x3A3 && rune <= 0x3AB)) {
        return rune + 0x20;
    }
    if (rune == 0x386) return 0x3AC;
    if (rune == 0x388) return 0x3AD;
    if (rune == 0x389) return 0x3AE;
    if (rune == 0x38A) return 0x3AF;
    if (rune == 0x38C) return 0x3CC;
    if (rune == 0x38E) return 0x3CD;
    if (rune == 0x38F) return 0x3CE;
    if (rune >= 0x410 && rune <= 0x42F) return rune + 0x20;
    if (rune >= 0x531 && rune <= 0x556) return rune + 0x30;
    if ((rune >= 0x100 && rune <= 0x12F) ||
        (rune >= 0x14A && rune <= 0x177)) {
        return (rune & 1) == 0 ? rune + 1 : rune;
    }
    return rune;
}

static char* string_case_map(const char* str, int is_upper) {
    if (str == NULL) return allocate_empty_string();

    size_t input_length = utf8_byte_length(str);
    if (input_length > (SIZE_MAX - 1) / 3) return NULL;

    char* result = (char*)malloc(input_length * 3 + 1);
    if (result == NULL) return NULL;

    size_t input_offset = 0;
    size_t output_offset = 0;
    while (input_offset < input_length) {
        int bytes_read = 0;
        uint32_t rune = utf8_decode_rune(
            (const uint8_t*)str, input_length, input_offset, &bytes_read);
        if (bytes_read <= 0) break;

        uint32_t mapped_rune = is_upper ? unicode_to_upper(rune) : unicode_to_lower(rune);
        uint8_t encoded_rune[4];
        int encoded_length = utf8_encode_rune(mapped_rune, encoded_rune);
        if (encoded_length <= 0) {
            free(result);
            return NULL;
        }

        memcpy(result + output_offset, encoded_rune, (size_t)encoded_length);
        output_offset += (size_t)encoded_length;
        input_offset += (size_t)bytes_read;
    }

    result[output_offset] = '\0';
    return result;
}

/**
 * string_length: 返回 rune 数量（不是字节数）
 *
 * 示例:
 *   "Hello" -> 5
 *   "Hello世界" -> 7 (5个ASCII + 2个中文)
 */
int string_length(const char* str) {
    if (str == NULL) return 0;
    return utf8_rune_count(str);
}

/**
 * string_char_at: 返回第 n 个 rune (Unicode codepoint)
 *
 * 示例:
 *   "Hello世界"[0] -> 'H' (U+0048)
 *   "Hello世界"[5] -> '世' (U+4E16)
 */
uint32_t string_char_at(const char* str, int index) {
    if (str == NULL || index < 0) return 0;
    return utf8_rune_at(str, index);
}

char* string_concat(const char* s1, const char* s2) {
    if (s1 == NULL) s1 = "";
    if (s2 == NULL) s2 = "";
    size_t len1 = strlen(s1);
    size_t len2 = strlen(s2);
    if (len1 > SIZE_MAX - len2 - 1) return NULL;
    char* result = (char*)malloc(len1 + len2 + 1);
    if (result == NULL) return NULL;
    memcpy(result, s1, len1);
    memcpy(result + len1, s2, len2 + 1);
    return result;
}

/**
 * string_substring: 基于 rune 索引的切片
 *
 * 参数:
 *   str - UTF-8 字符串
 *   start - 起始 rune 索引（包含）
 *   end - 结束 rune 索引（不包含）
 *
 * 示例:
 *   "Hello世界".substring(0, 5) -> "Hello"
 *   "Hello世界".substring(5, 7) -> "世界"
 */
char* string_substring(const char* str, int start, int end) {
    if (str == NULL || start < 0 || end < start) {
        return allocate_empty_string();
    }

    int rune_count = utf8_rune_count(str);
    if (start > rune_count) start = rune_count;
    if (end > rune_count) end = rune_count;
    if (start >= end) return allocate_empty_string();

    int byte_start = utf8_byte_offset(str, start);
    int byte_end = utf8_byte_offset(str, end);
    if (byte_start < 0 || byte_end < byte_start) return allocate_empty_string();

    size_t byte_length = (size_t)(byte_end - byte_start);
    char* result = (char*)malloc(byte_length + 1);
    if (result == NULL) return NULL;

    memcpy(result, str + byte_start, byte_length);
    result[byte_length] = '\0';
    return result;
}

int string_find(const char* str, const char* sub) {
    if (str == NULL || sub == NULL) return -1;
    const char* pos = strstr(str, sub);
    if (pos == NULL) return -1;
    return utf8_rune_count_prefix(str, (size_t)(pos - str));
}

int string_compare(const char* s1, const char* s2) {
    if (s1 == NULL) s1 = "";
    if (s2 == NULL) s2 = "";
    return strcmp(s1, s2);
}

char* string_upper(const char* str) {
    return string_case_map(str, 1);
}

char* string_lower(const char* str) {
    return string_case_map(str, 0);
}

char* string_strip(const char* str) {
    if (str == NULL || *str == '\0') {
        return allocate_empty_string();
    }

    const char* start = str;
    while (isspace((unsigned char)*start)) start++;

    if (*start == '\0') {
        return allocate_empty_string();
    }

    const char* end = str + strlen(str) - 1;
    while (end > start && isspace((unsigned char)*end)) end--;

    size_t len = (size_t)(end - start + 1);
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return NULL;
    strncpy(result, start, len);
    result[len] = '\0';
    return result;
}

bool string_starts_with(const char* str, const char* prefix) {
    if (str == NULL || prefix == NULL) return false;
    size_t len = strlen(prefix);
    return strncmp(str, prefix, len) == 0;
}

bool string_ends_with(const char* str, const char* suffix) {
    if (str == NULL || suffix == NULL) return false;
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > str_len) return false;
    return strcmp(str + str_len - suffix_len, suffix) == 0;
}

char* string_replace(const char* str, const char* old, const char* new_str) {
    if (str == NULL || old == NULL || new_str == NULL) return NULL;
    if (*old == '\0') {
        char* result = (char*)malloc(strlen(str) + 1);
        if (result == NULL) return NULL;
        strcpy(result, str);
        return result;
    }

    size_t old_len = strlen(old);
    size_t new_len = strlen(new_str);
    size_t count = 0;

    const char* p = str;
    while ((p = strstr(p, old)) != NULL) {
        count++;
        p += old_len;
    }

    if (count == 0) {
        char* result = (char*)malloc(strlen(str) + 1);
        if (result == NULL) return NULL;
        strcpy(result, str);
        return result;
    }

    size_t source_len = strlen(str);
    if (new_len > old_len &&
        count > (SIZE_MAX - source_len) / (new_len - old_len)) {
        return NULL;
    }
    size_t result_len = source_len;
    if (new_len >= old_len) {
        result_len += count * (new_len - old_len);
    } else {
        if (count > source_len / (old_len - new_len)) return NULL;
        result_len -= count * (old_len - new_len);
    }
    if (result_len == SIZE_MAX) return NULL;
    char* result = (char*)malloc(result_len + 1);
    if (result == NULL) return NULL;

    char* dst = result;
    p = str;
    while (*p) {
        const char* q = strstr(p, old);
        if (q == NULL) {
            strcpy(dst, p);
            break;
        }

        size_t prefix_length = (size_t)(q - p);
        memcpy(dst, p, prefix_length);
        dst += prefix_length;

        strcpy(dst, new_str);
        dst += new_len;

        p = q + old_len;
    }

    *dst = '\0';
    return result;
}

bool string_is_digit(char c) {
    return isdigit((unsigned char)c) != 0;
}

bool string_is_alpha(char c) {
    return isalpha((unsigned char)c) != 0;
}

bool string_is_whitespace(char c) {
    return isspace((unsigned char)c) != 0;
}

dynarray_ptr* string_split(const char* str, const char* delimiter) {
    if (str == NULL || delimiter == NULL) return NULL;

    dynarray_ptr* result = create_dynarray_ptr(10);
    if (result == NULL) return NULL;

    if (*delimiter == '\0') {
        int rune_count = utf8_rune_count(str);
        for (int rune_index = 0; rune_index < rune_count; rune_index++) {
            int byte_start = utf8_byte_offset(str, rune_index);
            int byte_end = utf8_byte_offset(str, rune_index + 1);
            if (byte_start < 0 || byte_end < byte_start) break;
            size_t segment_length = (size_t)(byte_end - byte_start);
            char* single_char = (char*)gc_alloc(segment_length + 1, OBJ_STRING);
            if (single_char == NULL) {
                free_dynarray_ptr(result);
                return NULL;
            }
            memcpy(single_char, str + byte_start, segment_length);
            single_char[segment_length] = '\0';
            append_ptr(result, (intptr_t)single_char);
        }
        return result;
    }

    size_t delimiter_length = strlen(delimiter);
    const char* current = str;
    const char* next;

    while ((next = strstr(current, delimiter)) != NULL) {
        size_t segment_length = (size_t)(next - current);
        char* segment = (char*)gc_alloc(segment_length + 1, OBJ_STRING);
        if (segment == NULL) {
            free_dynarray_ptr(result);
            return NULL;
        }
        memcpy(segment, current, segment_length);
        segment[segment_length] = '\0';
        append_ptr(result, (intptr_t)segment);
        current = next + delimiter_length;
    }

    size_t remaining_length = strlen(current);
    char* last_segment = (char*)gc_alloc(remaining_length + 1, OBJ_STRING);
    if (last_segment == NULL) {
        free_dynarray_ptr(result);
        return NULL;
    }
    memcpy(last_segment, current, remaining_length + 1);
    append_ptr(result, (intptr_t)last_segment);

    return result;
}

char* string_join(dynarray_ptr* arr, const char* separator) {
    if (arr == NULL || separator == NULL) return NULL;

    int arr_len = len_dynarray_ptr(arr);
    if (arr_len == 0) {
        char* empty = (char*)gc_alloc(1, OBJ_STRING);
        if (empty == NULL) return NULL;
        empty[0] = '\0';
        return empty;
    }

    size_t separator_length = strlen(separator);
    size_t total_length = 0;

    for (int i = 0; i < arr_len; i++) {
        const char* str = (const char*)get_dynarray_ptr(arr, i);
        if (str != NULL) {
            size_t string_length = strlen(str);
            if (total_length > SIZE_MAX - string_length) return NULL;
            total_length += string_length;
        }
    }

    if (arr_len > 1 && separator_length > (SIZE_MAX - total_length) / (size_t)(arr_len - 1)) {
        return NULL;
    }
    total_length += separator_length * (size_t)(arr_len - 1);
    if (total_length == SIZE_MAX) return NULL;

    char* result = (char*)gc_alloc(total_length + 1, OBJ_STRING);
    if (result == NULL) return NULL;

    size_t offset = 0;
    for (int i = 0; i < arr_len; i++) {
        const char* str = (const char*)get_dynarray_ptr(arr, i);
        if (str != NULL) {
            size_t string_length = strlen(str);
            memcpy(result + offset, str, string_length);
            offset += string_length;
        }
        if (i < arr_len - 1) {
            memcpy(result + offset, separator, separator_length);
            offset += separator_length;
        }
    }
    result[offset] = '\0';

    return result;
}
