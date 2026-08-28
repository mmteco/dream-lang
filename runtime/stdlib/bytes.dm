def from_list(values: list[byte]) -> bytes:
    return __c_bytes_from_array(values)

def to_list(value: bytes) -> list[byte]:
    let result: list[byte] = []
    let index = 0
    while index < len(value):
        append(result, value[index])
        index = index + 1
    return result

def encode(text: str) -> bytes:
    return __c_str_to_bytes(text)

def decode(value: bytes) -> str:
    return __c_bytes_to_str(value)

def extend(target: list[byte], value: bytes):
    let index = 0
    while index < len(value):
        append(target, value[index])
        index = index + 1

def append_rune(target: list[byte], value: rune):
    extend(target, __c_utf8_encode_rune(value))
