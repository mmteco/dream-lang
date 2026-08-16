#ifndef BYTES_OPS_H
#define BYTES_OPS_H

#include <stdint.h>
#include "dynarray.h"

/**
 * bytes 底层操作函数
 *
 * Dream 中 bytes 的表示：
 * - 类型：ImmutableArray U8
 * - 结构：{ i32 length, i8* data }
 */

// bytes 与 list[byte] 统一使用动态数组布局。
typedef dynarray_i32 bytes_t;

/**
 * 获取 bytes 的长度
 */
int32_t bytes_length(bytes_t* bytes);

/**
 * 获取 bytes 的第 i 个字节
 *
 * @param bytes bytes 对象
 * @param index 索引（从 0 开始）
 * @return 字节值（0-255），-1 如果越界
 */
int32_t bytes_get(bytes_t* bytes, int32_t index);

/**
 * bytes 切片
 *
 * @param bytes 源 bytes
 * @param start 起始索引（包含）
 * @param end 结束索引（不包含）
 * @return 新的 bytes 对象
 */
bytes_t* bytes_slice(bytes_t* bytes, int32_t start, int32_t end);

/**
 * 从 byte 数组创建 bytes
 *
 * @param data byte 数组指针
 * @param length 数组长度
 * @return 新的 bytes 对象
 */
bytes_t* bytes_from_array(uint8_t* data, int32_t length);

/**
 * str 转 bytes（复制 UTF-8 字节）
 *
 * Dream 中 str 和 bytes 底层都是 { i32 length, i8* data }
 * 这个函数只是类型转换，不复制数据
 */
bytes_t* str_to_bytes(const char* str);

/**
 * bytes 转 str（复制字节并添加 NUL）
 *
 * 注意：不验证 UTF-8 有效性
 */
char* bytes_to_str(bytes_t* bytes);

#endif // BYTES_OPS_H
