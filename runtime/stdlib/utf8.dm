# UTF-8 字符串操作标准库
# 提供基于 rune (Unicode codepoint) 的字符串操作

def ord(r: rune) -> int:
    return __c_rune_to_int(r)

def rune_at(s: str, index: int) -> rune:
    '''
    获取字符串中第 index 个 rune (Unicode codepoint)

    参数:
      s - UTF-8 编码的字符串
      index - rune 索引（从 0 开始）

    返回: rune (32-bit Unicode codepoint)

    示例:
      let s: str = "Hello世界"
      let r1 = rune_at(s, 0)    # 'H' = U+0048
      let r2 = rune_at(s, 5)    # '世' = U+4E16
    '''
    return __c_utf8_rune_at(s, index)

def rune_count(s: str) -> int:
    '''
    获取字符串中的 rune 数量（不是字节数）

    参数:
      s - UTF-8 编码的字符串

    返回: rune 数量

    示例:
      let s: str = "Hello世界"
      print(rune_count(s))  # 7 (5个ASCII + 2个中文)
    '''
    return __c_utf8_rune_count(s)

def byte_offset(s: str, rune_index: int) -> int:
    '''
    获取第 n 个 rune 的字节偏移

    参数:
      s - UTF-8 编码的字符串
      rune_index - rune 索引（从 0 开始）

    返回: 字节偏移，-1 如果索引越界

    示例:
      let s: str = "Hello世"
      print(byte_offset(s, 5))  # 5 (第6个rune从第5个字节开始)
      print(byte_offset(s, 6))  # 8 ('世'是3字节UTF-8)
    '''
    return __c_utf8_byte_offset(s, rune_index)

def encode_rune(r: rune) -> bytes:
    '''
    将 rune 编码为 UTF-8 字节序列

    参数:
      r - Unicode codepoint (rune)

    返回: UTF-8 编码的 bytes (1-4 字节)

    示例:
      let r: rune = '世'
      let b = encode_rune(r)
      # b 包含 3 个字节: E4 B8 96
    '''
    return __c_utf8_encode_rune(r)

def decode_rune(b: bytes, offset: int) -> (rune, int):
    '''
    从 bytes 解码一个 rune

    参数:
      b - 字节序列
      offset - 起始字节偏移

    返回: (rune, bytes_read) 元组
      rune - 解码的 Unicode codepoint
      bytes_read - 消耗的字节数 (1-4)

    示例:
      let b: bytes = str_to_bytes("Hello")
      let (r, n) = decode_rune(b, 0)
      # r = 'H', n = 1
    '''
    let first = __c_bytes_get(b, offset)
    if first < 0x80:
        return (first, 1)
    if first < 0xC0:
        return (0, 1)
    let length = 0
    let lead_base = 0
    if first < 0xE0:
        length = 2
        lead_base = 0xC0
    elif first < 0xF0:
        length = 3
        lead_base = 0xE0
    elif first < 0xF8:
        length = 4
        lead_base = 0xF0
    else:
        return (0, 1)
    if offset + length > __c_bytes_length(b):
        return (0, 1)
    let rune_value = first - lead_base
    let index = 1
    while index < length:
        let current = __c_bytes_get(b, offset + index)
        if current < 0x80 or current >= 0xC0:
            return (0, index)
        rune_value = rune_value * 64 + (current - 0x80)
        index = index + 1
    return (rune_value, length)
