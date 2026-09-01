# String helpers with a small, Python-like surface.

def len(value: str) -> int:
    return __c_str_len(value)

def char_at(value: str, index: int) -> rune:
    return __c_utf8_rune_at(value, index)

def upper(value: str) -> str:
    return __c_str_upper(value)

def lower(value: str) -> str:
    return __c_str_lower(value)

def strip(value: str) -> str:
    return __c_str_strip(value)

def lstrip(value: str) -> str:
    let index = 0
    while index < len(value) and (value[index] == ' ' or value[index] == '\t' or value[index] == '\n' or value[index] == '\r'):
        index = index + 1
    return value[index:]

def rstrip(value: str) -> str:
    let index = len(value) - 1
    while index >= 0 and (value[index] == ' ' or value[index] == '\t' or value[index] == '\n' or value[index] == '\r'):
        index = index - 1
    return value[:index + 1]

def find(value: str, sub: str) -> int:
    return __c_str_find(value, sub)

def startswith(value: str, prefix: str) -> bool:
    return __c_str_starts_with(value, prefix)

def endswith(value: str, suffix: str) -> bool:
    return __c_str_ends_with(value, suffix)

def replace(value: str, old: str, new: str) -> str:
    return __c_str_replace(value, old, new)

def to_bytes(value: str) -> bytes:
    return __c_str_to_bytes(value)

def encode(value: str) -> bytes:
    return __c_str_to_bytes(value)

def count(value: str, sub: str) -> int:
    if len(sub) == 0:
        return len(value) + 1
    let result = 0
    let index = 0
    while index <= len(value) - len(sub):
        if value[index:index + len(sub)] == sub:
            result = result + 1
            index = index + len(sub)
        else:
            index = index + 1
    return result

def rune_at(value: str, index: int) -> rune:
    return char_at(value, index)

def rune_count(value: str) -> int:
    return __c_utf8_rune_count(value)

def split(value: str, separator: str) -> list[str]:
    return __c_str_split(value, separator)

def join(values: list[str], separator: str) -> str:
    return __c_str_join(values, separator)

def splitlines(value: str) -> list[str]:
    let result: list[str] = []
    let length = len(value)
    let start = 0
    let index = 0
    while index < length:
        if value[index] == '\r':
            append(result, value[start:index])
            if index + 1 < length and value[index + 1] == '\n':
                index = index + 1
            start = index + 1
        elif value[index] == '\n':
            append(result, value[start:index])
            start = index + 1
        index = index + 1
    if start < length:
        append(result, value[start:length])
    return result

def zfill(value: str, width: int) -> str:
    let length = len(value)
    if length >= width:
        return value
    let pad_len = width - length
    let pad = ""
    let i = 0
    while i < pad_len:
        pad += "0"
        i += 1
    return pad + value

def ljust(value: str, width: int, fill: str = " ") -> str:
    let length = len(value)
    if length >= width:
        return value
    let pad_len = width - length
    let pad = ""
    let i = 0
    while i < pad_len:
        pad += fill
        i += 1
    return value + pad

def rjust(value: str, width: int, fill: str = " ") -> str:
    let length = len(value)
    if length >= width:
        return value
    let pad_len = width - length
    let pad = ""
    let i = 0
    while i < pad_len:
        pad += fill
        i += 1
    return pad + value

def center(value: str, width: int, fill: str = " ") -> str:
    let length = len(value)
    if length >= width:
        return value
    let total_pad = width - length
    let left_pad_len = total_pad / 2
    let right_pad_len = total_pad - left_pad_len
    let left_pad = ""
    let right_pad = ""
    let i = 0
    while i < left_pad_len:
        left_pad += fill
        i += 1
    i = 0
    while i < right_pad_len:
        right_pad += fill
        i += 1
    return left_pad + value + right_pad

def partition(value: str, sep: str) -> (str, str, str):
    let idx = find(value, sep)
    if idx < 0:
        return (value, "", "")
    return (value[:idx], sep, value[idx + len(sep):])

