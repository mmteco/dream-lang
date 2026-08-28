# bytes 字节序列操作标准库
# 提供不可变字节序列的基础操作

def bytes_len(b: bytes) -> int:
    return __c_bytes_length(b)

def bytes_get(b: bytes, index: int) -> byte:
    return __c_bytes_get(b, index)

def bytes_slice(b: bytes, start: int, end: int) -> bytes:
    return __c_bytes_slice(b, start, end)

def bytes_from_list(lst: list[byte]) -> bytes:
    return __c_bytes_from_array(lst)

def bytes_to_list(b: bytes) -> list[byte]:
    let result: list[byte] = []
    let i = 0
    let length = bytes_len(b)
    while i < length:
        append(result, bytes_get(b, i))
        i = i + 1
    return result

def str_to_bytes(s: str) -> bytes:
    return __c_str_to_bytes(s)

def bytes_to_str(b: bytes) -> str:
    return __c_bytes_to_str(b)

def append_bytes(buf: list[byte], b: bytes):
    let i = 0
    let length = bytes_len(b)
    while i < length:
        append(buf, bytes_get(b, i))
        i = i + 1

def append_rune(buf: list[byte], r: rune):
    let encoded = __c_utf8_encode_rune(r)
    append_bytes(buf, encoded)
