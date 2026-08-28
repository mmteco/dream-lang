# 字符串操作标准库（bootstrap 子集）
# int_to_str 为纯 Dream 实现，其余直接映射 C 运行时字符串函数

def int_to_str(value: int) -> str:
    
    if value == 0:
        return "0"

    let is_negative = value < 0
    if is_negative:
        value = 0 - value

    let digits: list[int] = []
    while value > 0:
        append(digits, value % 10)
        value = value / 10

    let result = ""
    if is_negative:
        result = "-"

    let index = len(digits) - 1
    while index >= 0:
        let digit_text = match digits[index]:
            0: "0"
            1: "1"
            2: "2"
            3: "3"
            4: "4"
            5: "5"
            6: "6"
            7: "7"
            8: "8"
            9: "9"
            _: "0"
        result = result + digit_text
        index = index - 1
    return result

def upper(s: str) -> str:
    return string_upper(s)

def lower(s: str) -> str:
    return string_lower(s)

def strip(s: str) -> str:
    return string_strip(s)

def split(s: str, separator: str) -> list[str]:
    return string_split(s, separator)

def join(items: list[str], separator: str) -> str:
    return string_join(items, separator)

def starts_with(s: str, prefix: str) -> bool:
    return string_starts_with(s, prefix)

def ends_with(s: str, suffix: str) -> bool:
    return string_ends_with(s, suffix)

def replace(s: str, old: str, new: str) -> str:
    return string_replace(s, old, new)

def substring(s: str, start: int, end: int) -> str:
    return s[start:end]

def find(s: str, sub: str) -> int:
    return string_find(s, sub)
