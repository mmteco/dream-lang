#ifndef UTF8_H
#define UTF8_H

#include <stdint.h>
#include <stddef.h>

/**
 * UTF-8 编解码核心函数
 *
 * Dream 类型映射：
 * - rune = uint32_t (32-bit Unicode codepoint)
 * - byte = uint8_t (8-bit)
 * - str = UTF-8 编码的字节序列（逻辑上是 rune 序列）
 * - bytes = 原始字节序列
 */

/**
 * 从 UTF-8 字节序列解码单个 rune
 *
 * @param utf8_bytes UTF-8 字节序列
 * @param offset 起始字节偏移
 * @param bytes_read 输出：读取的字节数（1-4）
 * @return 解码的 rune（Unicode codepoint）
 *
 * 返回 0xFFFD (REPLACEMENT CHARACTER) 如果遇到非法 UTF-8 序列
 */
uint32_t utf8_decode_rune(const uint8_t* utf8_bytes, size_t length, size_t offset, int* bytes_read);

/**
 * 将 rune 编码为 UTF-8 字节序列
 *
 * @param rune Unicode codepoint
 * @param buffer 输出缓冲区（至少 4 字节）
 * @return 编码的字节数（1-4）
 *
 * 返回 0 如果 rune 超出有效范围
 */
int utf8_encode_rune(uint32_t rune, uint8_t* buffer);

/**
 * 计算 UTF-8 字符串的 rune 数量
 *
 * @param utf8_str UTF-8 字符串
 * @return rune 数量（不是字节数）
 */
int utf8_rune_count(const char* utf8_str);

/**
 * 计算字符串前缀中的 rune 数量。
 */
int utf8_rune_count_prefix(const char* utf8_str, size_t byte_length);

/**
 * 判断字符串是否只包含 ASCII 字节。
 */
int utf8_is_ascii(const char* utf8_str);

/**
 * 获取以 NUL 结尾字符串的字节长度。
 */
size_t utf8_byte_length(const char* utf8_str);

/**
 * 忘记字符串缓存中的地址，供释放字符串内存的运行时调用。
 */
void utf8_cache_forget(const char* utf8_str);

/**
 * 获取第 n 个 rune 的字节偏移
 *
 * @param utf8_str UTF-8 字符串
 * @param rune_index rune 索引（从 0 开始）
 * @return 字节偏移，-1 如果索引越界
 */
int utf8_byte_offset(const char* utf8_str, int rune_index);

/**
 * 获取第 n 个 rune
 *
 * @param utf8_str UTF-8 字符串
 * @param rune_index rune 索引（从 0 开始）
 * @return rune 值，0 如果索引越界
 */
uint32_t utf8_rune_at(const char* utf8_str, int rune_index);

#endif // UTF8_H
