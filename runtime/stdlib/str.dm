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
