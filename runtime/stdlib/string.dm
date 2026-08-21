# Dream Standard Library - String Module
# 字符串操作相关函数

# TODO: 实现字符串操作

def int_to_str(value: int) -> str:
    '''将整数转换为十进制字符串'''
    if value == 0:
        return "0"

    let is_negative = value < 0
    if is_negative:
        value = 0 - value

    let digits: list[str] = []
    while value > 0:
        let digit_text = match value % 10:
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
        append(digits, digit_text)
        value = value / 10

    let result = ""
    if is_negative:
        result = "-"

    let index = len(digits) - 1
    while index >= 0:
        result = result + digits[index]
        index = index - 1
    return result

def upper(s: str) -> str:
    '''转换为大写'''
    pass

def lower(s: str) -> str:
    '''转换为小写'''
    pass

def split(s: str, separator: str) -> list[str]:
    '''分割字符串'''
    pass

def join(items: list[str], separator: str) -> str:
    '''连接字符串列表'''
    pass

def trim(s: str) -> str:
    '''去除首尾空白'''
    pass

def starts_with(s: str, prefix: str) -> bool:
    '''检查是否以指定前缀开头'''
    pass

def ends_with(s: str, suffix: str) -> bool:
    '''检查是否以指定后缀结尾'''
    pass

def replace(s: str, old: str, new: str) -> str:
    '''替换字符串'''
    pass

def substring(s: str, start: int, end: int) -> str:
    '''获取子字符串'''
    pass
