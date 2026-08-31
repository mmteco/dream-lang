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

def find(value: str, sub: str) -> int:
    return __c_str_find(value, sub)

def startswith(value: str, prefix: str) -> bool:
    return __c_str_starts_with(value, prefix)

def endswith(value: str, suffix: str) -> bool:
    return __c_str_ends_with(value, suffix)

def replace(value: str, old: str, new: str) -> str:
    return __c_str_replace(value, old, new)

def encode(value: str) -> bytes:
    return __c_str_to_bytes(value)

def rune_at(value: str, index: int) -> rune:
    return char_at(value, index)

def rune_count(value: str) -> int:
    return __c_utf8_rune_count(value)

def split(value: str, separator: str) -> list[str]:
    return __c_str_split(value, separator)

def join(values: list[str], separator: str) -> str:
    return __c_str_join(values, separator)
