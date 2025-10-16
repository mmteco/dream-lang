# Dream Standard Library - File Module
# 使用类型模式匹配实现统一的文件 I/O 接口


def write_file(path: str, content: str | bytes) -> int:
    """
    写入文件
    根据 content 的实际类型自动选择底层函数
    参数:
      path - 文件路径
      content - 文件内容，可以是 string 或 bytes
    返回: 1=成功, 0=失败
    """
    match type of content:
        str:
            return __c_file_write(path, content)
        bytes:
            return __c_file_write_bytes(path, content)
        _:
            return 0

def read_file(path: str, as_bytes: int) -> str | bytes:
    """
    读取文件
    根据 as_bytes 参数决定返回类型
    参数:
      path - 文件路径
      as_bytes - 0=读取为字符串, 1=读取为字节数组
    返回: 文件内容（string 或 bytes）
    """
    match as_bytes:
        0:
            return __c_file_read(path)
        _:
            return __c_file_read_bytes(path)

def append_file(path: str, content: str | bytes) -> int:
    """
    追加到文件
    根据 content 的实际类型自动选择底层函数
    参数:
      path - 文件路径
      content - 要追加的内容，可以是 string 或 bytes
    返回: 1=成功, 0=失败
    """
    match type of content:
        str:
            return __c_file_append(path, content)
        bytes:
            return __c_file_append_bytes(path, content)
        _:
            return 0
