# BytesBuffer - 可变字节缓冲区
# 用于高效构建 bytes 序列

struct BytesBuffer:
    data: list[byte]

    def new() -> BytesBuffer:
        """
        创建新的 BytesBuffer

        返回: 空的 BytesBuffer

        示例:
          let buf = BytesBuffer.new()
        """
        return BytesBuffer{data: []}

    def from_bytes(b: bytes) -> BytesBuffer:
        """
        从 bytes 创建 BytesBuffer

        参数:
          b - 初始 bytes 数据

        返回: 包含 b 的 BytesBuffer

        示例:
          let b = str_to_bytes("Hello")
          let buf = BytesBuffer.from_bytes(b)
        """
        let buffer = BytesBuffer{data: []}
        buffer.append_bytes(b)
        return buffer

    def append_byte(self, b: byte):
        """
        追加单个字节

        参数:
          b - 字节值 (0-255)

        示例:
          buf.append_byte(b'A')
        """
        append(self.data, b)

    def append_bytes(self, bs: bytes):
        """
        追加 bytes

        参数:
          bs - 要追加的 bytes

        示例:
          buf.append_bytes(str_to_bytes("Hello"))
        """
        let i = 0
        let length = __c_bytes_length(bs)
        while i < length:
            append(self.data, __c_bytes_get(bs, i))
            i = i + 1

    def append_rune(self, r: rune):
        """
        追加 rune（自动 UTF-8 编码）

        参数:
          r - Unicode codepoint

        示例:
          buf.append_rune('世')
        """
        let encoded = __c_utf8_encode_rune(r)
        self.append_bytes(encoded)

    def append_str(self, s: str):
        """
        追加字符串（UTF-8）

        参数:
          s - 字符串

        示例:
          buf.append_str("Hello")
        """
        let bs = __c_str_to_bytes(s)
        self.append_bytes(bs)

    def append_int(self, n: int):
        """
        追加整数的字符串表示

        参数:
          n - 整数

        注意: 需要实现 int_to_str 函数

        示例:
          buf.append_int(42)
        """
        # TODO: 实现 int_to_str
        # let s = int_to_str(n)
        # self.append_str(s)
        pass

    def to_bytes(self) -> bytes:
        """
        转换为不可变 bytes

        返回: bytes 对象

        示例:
          let result = buf.to_bytes()
        """
        return __c_bytes_from_array(self.data)

    def to_str(self) -> str:
        """
        转换为 str（UTF-8）

        返回: 字符串

        示例:
          let text = buf.to_str()
        """
        let b = self.to_bytes()
        return __c_bytes_to_str(b)

    def len(self) -> int:
        """
        获取字节数

        返回: 当前缓冲区的字节数

        示例:
          print(buf.len())
        """
        return len(self.data)

    def clear(self):
        """
        清空缓冲区

        示例:
          buf.clear()
        """
        self.data = []

    def is_empty(self) -> bool:
        """
        检查缓冲区是否为空

        返回: true 如果为空

        示例:
          if buf.is_empty():
              print("empty")
        """
        return len(self.data) == 0

# 便捷函数

def concat_bytes(parts: list[bytes]) -> bytes:
    """
    拼接多个 bytes

    参数:
      parts - bytes 列表

    返回: 拼接后的 bytes

    示例:
      let b1 = str_to_bytes("Hello")
      let b2 = str_to_bytes(" ")
      let b3 = str_to_bytes("World")
      let result = concat_bytes([b1, b2, b3])
    """
    let buf = BytesBuffer.new()
    let i = 0
    while i < len(parts):
        buf.append_bytes(parts[i])
        i = i + 1
    return buf.to_bytes()

def concat_strs(parts: list[str], separator: str) -> str:
    """
    用分隔符连接多个字符串

    参数:
      parts - 字符串列表
      separator - 分隔符

    返回: 连接后的字符串

    示例:
      let words = ["Hello", "World"]
      let result = concat_strs(words, " ")
      # "Hello World"
    """
    let buf = BytesBuffer.new()
    let i = 0
    let count = len(parts)
    while i < count:
        buf.append_str(parts[i])
        if i < count - 1:
            buf.append_str(separator)
        i = i + 1
    return buf.to_str()
