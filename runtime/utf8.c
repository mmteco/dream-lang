#include "utf8.h"
#include <string.h>

#define UTF8_ASCII_CACHE_SIZE 8
#define UTF8_ASCII_CACHE_THRESHOLD 4096

static _Thread_local const char* cached_ascii_strings[UTF8_ASCII_CACHE_SIZE];
static _Thread_local int cached_ascii_results[UTF8_ASCII_CACHE_SIZE];
static _Thread_local size_t cached_ascii_lengths[UTF8_ASCII_CACHE_SIZE];
static _Thread_local int active_ascii_cache_index = -1;

int utf8_is_ascii(const char* utf8_str) {
    if (utf8_str == NULL) return 0;

    for (int cache_index = 0; cache_index < UTF8_ASCII_CACHE_SIZE; cache_index++) {
        if (cached_ascii_strings[cache_index] == utf8_str) {
            active_ascii_cache_index = cache_index;
            return cached_ascii_results[cache_index];
        }
    }

    const unsigned char* bytes = (const unsigned char*)utf8_str;
    size_t length = 0;
    while (*bytes != '\0') {
        if (*bytes >= 0x80) {
            active_ascii_cache_index = -1;
            return 0;
        }
        bytes++;
        length++;
    }

    active_ascii_cache_index = -1;
    if (length >= UTF8_ASCII_CACHE_THRESHOLD) {
        int replacement_index = 0;
        for (int cache_index = 0; cache_index < UTF8_ASCII_CACHE_SIZE; cache_index++) {
            if (cached_ascii_strings[cache_index] == NULL || cached_ascii_lengths[cache_index] < cached_ascii_lengths[replacement_index]) {
                replacement_index = cache_index;
            }
        }
        cached_ascii_strings[replacement_index] = utf8_str;
        cached_ascii_results[replacement_index] = 1;
        cached_ascii_lengths[replacement_index] = length;
        active_ascii_cache_index = replacement_index;
    }
    return 1;
}

// UTF-8 非法字符替换字符
#define UTF8_REPLACEMENT_CHAR 0xFFFD

/**
 * 从 UTF-8 字节序列解码单个 rune
 */
uint32_t utf8_decode_rune(const uint8_t* utf8_bytes, int offset, int* bytes_read) {
    if (utf8_bytes == NULL || bytes_read == NULL) {
        *bytes_read = 0;
        return 0;
    }

    const uint8_t* p = utf8_bytes + offset;
    uint8_t first = *p;

    // 1 字节：0xxxxxxx (ASCII)
    if ((first & 0x80) == 0) {
        *bytes_read = 1;
        return first;
    }

    // 2 字节：110xxxxx 10xxxxxx
    if ((first & 0xE0) == 0xC0) {
        if ((p[1] & 0xC0) != 0x80) {
            *bytes_read = 1;
            return UTF8_REPLACEMENT_CHAR;
        }
        *bytes_read = 2;
        return ((first & 0x1F) << 6) | (p[1] & 0x3F);
    }

    // 3 字节：1110xxxx 10xxxxxx 10xxxxxx
    if ((first & 0xF0) == 0xE0) {
        if ((p[1] & 0xC0) != 0x80 || (p[2] & 0xC0) != 0x80) {
            *bytes_read = 1;
            return UTF8_REPLACEMENT_CHAR;
        }
        *bytes_read = 3;
        return ((first & 0x0F) << 12) | ((p[1] & 0x3F) << 6) | (p[2] & 0x3F);
    }

    // 4 字节：11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    if ((first & 0xF8) == 0xF0) {
        if ((p[1] & 0xC0) != 0x80 || (p[2] & 0xC0) != 0x80 || (p[3] & 0xC0) != 0x80) {
            *bytes_read = 1;
            return UTF8_REPLACEMENT_CHAR;
        }
        uint32_t codepoint = ((first & 0x07) << 18) | ((p[1] & 0x3F) << 12) |
                             ((p[2] & 0x3F) << 6) | (p[3] & 0x3F);

        // 检查是否在有效 Unicode 范围内 (U+0000 to U+10FFFF)
        if (codepoint > 0x10FFFF) {
            *bytes_read = 1;
            return UTF8_REPLACEMENT_CHAR;
        }

        *bytes_read = 4;
        return codepoint;
    }

    // 非法起始字节
    *bytes_read = 1;
    return UTF8_REPLACEMENT_CHAR;
}

/**
 * 将 rune 编码为 UTF-8 字节序列
 */
int utf8_encode_rune(uint32_t rune, uint8_t* buffer) {
    if (buffer == NULL) return 0;

    // 检查有效范围
    if (rune > 0x10FFFF) return 0;

    // 1 字节：0xxxxxxx (U+0000 to U+007F)
    if (rune <= 0x7F) {
        buffer[0] = (uint8_t)rune;
        return 1;
    }

    // 2 字节：110xxxxx 10xxxxxx (U+0080 to U+07FF)
    if (rune <= 0x7FF) {
        buffer[0] = 0xC0 | (uint8_t)(rune >> 6);
        buffer[1] = 0x80 | (uint8_t)(rune & 0x3F);
        return 2;
    }

    // 3 字节：1110xxxx 10xxxxxx 10xxxxxx (U+0800 to U+FFFF)
    if (rune <= 0xFFFF) {
        buffer[0] = 0xE0 | (uint8_t)(rune >> 12);
        buffer[1] = 0x80 | (uint8_t)((rune >> 6) & 0x3F);
        buffer[2] = 0x80 | (uint8_t)(rune & 0x3F);
        return 3;
    }

    // 4 字节：11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (U+10000 to U+10FFFF)
    buffer[0] = 0xF0 | (uint8_t)(rune >> 18);
    buffer[1] = 0x80 | (uint8_t)((rune >> 12) & 0x3F);
    buffer[2] = 0x80 | (uint8_t)((rune >> 6) & 0x3F);
    buffer[3] = 0x80 | (uint8_t)(rune & 0x3F);
    return 4;
}

/**
 * 计算 UTF-8 字符串的 rune 数量
 */
int utf8_rune_count(const char* utf8_str) {
    if (utf8_str == NULL) return 0;
    if (utf8_is_ascii(utf8_str)) {
        if (active_ascii_cache_index >= 0) {
            return (int)cached_ascii_lengths[active_ascii_cache_index];
        }
        return (int)strlen(utf8_str);
    }

    int count = 0;
    int offset = 0;
    int len = strlen(utf8_str);

    while (offset < len) {
        int bytes_read = 0;
        utf8_decode_rune((const uint8_t*)utf8_str, offset, &bytes_read);
        if (bytes_read == 0) break;
        offset += bytes_read;
        count++;
    }

    return count;
}

/**
 * 获取第 n 个 rune 的字节偏移
 */
int utf8_byte_offset(const char* utf8_str, int rune_index) {
    if (utf8_str == NULL || rune_index < 0) return -1;
    if (utf8_is_ascii(utf8_str)) {
        if (active_ascii_cache_index >= 0) {
            return (size_t)rune_index <= cached_ascii_lengths[active_ascii_cache_index] ? rune_index : -1;
        }
        return (size_t)rune_index <= strlen(utf8_str) ? rune_index : -1;
    }

    int offset = 0;
    int len = strlen(utf8_str);
    int current_rune = 0;

    while (offset < len && current_rune < rune_index) {
        int bytes_read = 0;
        utf8_decode_rune((const uint8_t*)utf8_str, offset, &bytes_read);
        if (bytes_read == 0) return -1;
        offset += bytes_read;
        current_rune++;
    }

    if (current_rune == rune_index && offset <= len) {
        return offset;
    }

    return -1;  // 索引越界
}

/**
 * 获取第 n 个 rune
 */
uint32_t utf8_rune_at(const char* utf8_str, int rune_index) {
    int offset = utf8_byte_offset(utf8_str, rune_index);
    if (offset < 0) return 0;

    int bytes_read = 0;
    return utf8_decode_rune((const uint8_t*)utf8_str, offset, &bytes_read);
}
