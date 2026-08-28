# 字符串操作标准库

def from_int(value: int) -> str:
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

def split(value: str, separator: str) -> list[str]:
    return string_split(value, separator)

def join(values: list[str], separator: str) -> str:
    return string_join(values, separator)
