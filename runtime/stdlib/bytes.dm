# bytes 字节序列操作标准库
# 提供不可变字节序列的基础操作

def bytes_len(b: bytes) -> int:
    '''
    获取 bytes 的长度（字节数）

    参数:
      b - bytes 对象

    返回: 字节数

    示例:
      let b: bytes = str_to_bytes("Hello")
      print(bytes_len(b))  # 5
    '''
    return __c_bytes_length(b)

def bytes_get(b: bytes, index: int) -> byte:
    '''
    获取第 i 个字节

    参数:
      b - bytes 对象
      index - 字节索引（从 0 开始）

    返回: byte (0-255)

    示例:
      let b: bytes = str_to_bytes("Hi")
      print(bytes_get(b, 0))  # 72 ('H')
    '''
    return __c_bytes_get(b, index)

def bytes_slice(b: bytes, start: int, end: int) -> bytes:
    '''
    bytes 切片（不包含 end）

    参数:
      b - 源 bytes
      start - 起始索引（包含）
      end - 结束索引（不包含）

    返回: 新的 bytes 对象

    示例:
      let b: bytes = str_to_bytes("Hello")
      let sub = bytes_slice(b, 1, 4)  # "ell"
    '''
    return __c_bytes_slice(b, start, end)

def bytes_from_list(lst: list[byte]) -> bytes:
    '''
    从 list[byte] 创建不可变 bytes

    参数:
      lst - byte 列表

    返回: bytes 对象

    示例:
      let buf: list[byte] = [b'H', b'i']
      let b = bytes_from_list(buf)
    '''
    return __c_bytes_from_array(lst)

def bytes_to_list(b: bytes) -> list[byte]:
    '''
    将 bytes 转换为 list[byte]

    参数:
      b - bytes 对象

    返回: 可变的 list[byte]

    示例:
      let b: bytes = str_to_bytes("Hi")
      let lst = bytes_to_list(b)
      print(len(lst))  # 2
    '''
    let result: list[byte] = []
    let i = 0
    let length = bytes_len(b)
    while i < length:
        append(result, bytes_get(b, i))
        i = i + 1
    return result

def str_to_bytes(s: str) -> bytes:
    '''
    str 转 bytes（UTF-8 编码）

    参数:
      s - UTF-8 字符串

    返回: UTF-8 字节序列

    示例:
      let s: str = "Hello世界"
      let b = str_to_bytes(s)
      print(bytes_len(b))  # 11 (5 + 6字节)
    '''
    return __c_str_to_bytes(s)

def bytes_to_str(b: bytes) -> str:
    '''
    bytes 转 str（UTF-8 解码）

    注意：不验证 UTF-8 有效性

    参数:
      b - UTF-8 编码的字节序列

    返回: 字符串

    示例:
      let b: bytes = str_to_bytes("Hello")
      let s = bytes_to_str(b)
      print(s)  # "Hello"
    '''
    return __c_bytes_to_str(b)

def append_bytes(buf: list[byte], b: bytes):
    '''
    将 bytes 追加到 list[byte]

    参数:
      buf - 可变字节缓冲区
      b - 要追加的 bytes

    示例:
      let buf: list[byte] = []
      append_bytes(buf, str_to_bytes("Hello"))
      print(len(buf))  # 5
    '''
    let i = 0
    let length = bytes_len(b)
    while i < length:
        append(buf, bytes_get(b, i))
        i = i + 1

def append_rune(buf: list[byte], r: rune):
    '''
    将 rune 编码并追加到 list[byte]

    参数:
      buf - 可变字节缓冲区
      r - Unicode codepoint

    示例:
      let buf: list[byte] = []
      append_rune(buf, 'H')
      append_rune(buf, '世')
      print(len(buf))  # 4 (1 + 3字节)
    '''
    let encoded = __c_utf8_encode_rune(r)
    append_bytes(buf, encoded)
