# Byte sequence utilities with a Python-like surface.

from utf8 import encode_rune

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
    extend(target, encode_rune(value))

def hex(value: bytes) -> str:
    let hex_chars = "0123456789abcdef"
    let result = ""
    let index = 0
    while index < len(value):
        let b = value[index]
        let high = (b / 16) % 16
        let low = b % 16
        result = result + hex_chars[high:high + 1] + hex_chars[low:low + 1]
        index = index + 1
    return result
