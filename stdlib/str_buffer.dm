'''
StrBuffer - 可变字符串缓冲区
用于高效构建字符串，避免频繁的字符串拼接

示例:
  let buf = StrBuffer.new()
  buf.append("Hello")
  buf.append(" ")
  buf.append("World")
  print(buf.to_str())  # "Hello World"
'''

struct StrBuffer:
    parts: list[str]

    def new() -> StrBuffer:
        '''创建新的 StrBuffer'''
        return StrBuffer{parts: []}

    def from_str(s: str) -> StrBuffer:
        '''从字符串创建 StrBuffer'''
        return StrBuffer{parts: [s]}

    def append(self, s: str):
        '''追加字符串'''
        append(self.parts, s)

    def append_rune(self, r: rune):
        '''追加单个字符（rune），自动 UTF-8 编码'''
        let encoded = __c_utf8_encode_rune(r)
        let s = __c_bytes_to_str(encoded)
        append(self.parts, s)

    def append_int(self, n: int):
        '''追加整数的字符串表示'''
        if n == 0:
            append(self.parts, "0")
        elif n < 0:
            append(self.parts, "-")
            self.append_int(0 - n)
        else:
            let digits: list[str] = []
            let num = n
            while num > 0:
                let digit = num % 10
                let digit_char = match digit:
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
                append(digits, digit_char)
                num = num / 10

            # 反转数字列表
            let i = len(digits) - 1
            while i >= 0:
                append(self.parts, digits[i])
                i = i - 1

    def append_bool(self, b: bool):
        '''追加布尔值的字符串表示'''
        if b:
            append(self.parts, "true")
        else:
            append(self.parts, "false")

    def append_line(self, s: str):
        '''追加字符串并添加换行符'''
        append(self.parts, s)
        append(self.parts, "\n")

    def to_str(self) -> str:
        '''转换为不可变字符串'''
        return join_strs(self.parts, "")

    def len(self) -> int:
        '''获取已追加的片段数量（不是字符数）'''
        return len(self.parts)

    def clear(self):
        '''清空缓冲区'''
        self.parts = []

    def is_empty(self) -> bool:
        '''检查缓冲区是否为空'''
        return len(self.parts) == 0

# 便捷函数

def join_strs(parts: list[str], separator: str) -> str:
    '''
    用分隔符连接多个字符串

    示例:
      let words = ["Hello", "World"]
      let result = join_strs(words, " ")
    '''
    if len(parts) == 0:
        return ""

    # 使用字节缓冲区实现
    let buffer: list[byte] = []
    let i = 0
    let count = len(parts)
    while i < count:
        # 追加当前字符串
        let s_bytes = __c_str_to_bytes(parts[i])
        let j = 0
        let s_len = __c_bytes_length(s_bytes)
        while j < s_len:
            append(buffer, __c_bytes_get(s_bytes, j))
            j = j + 1

        # 追加分隔符（如果不是最后一个）
        if i < count - 1:
            let sep_bytes = __c_str_to_bytes(separator)
            let k = 0
            let sep_len = __c_bytes_length(sep_bytes)
            while k < sep_len:
                append(buffer, __c_bytes_get(sep_bytes, k))
                k = k + 1

        i = i + 1

    # 转换回字符串
    let result_bytes = __c_bytes_from_array(buffer)
    return __c_bytes_to_str(result_bytes)

def concat_strs(parts: list[str]) -> str:
    '''连接多个字符串（无分隔符）'''
    return join_strs(parts, "")

def repeat_str(s: str, count: int) -> str:
    '''重复字符串 n 次'''
    let buf = StrBuffer.new()
    let i = 0
    while i < count:
        buf.append(s)
        i = i + 1
    return buf.to_str()
