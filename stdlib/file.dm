def read_file(path: str, as_bytes: bool = false) -> str | bytes:
    '''
    读取文件
    根据 as_bytes 参数决定返回类型
    参数:
      path - 文件路径
      as_bytes - 0=读取为字符串, 1=读取为字节数组
    返回: 文件内容（string 或 bytes）
    '''
    match as_bytes:
        false:
            return __c_file_read(path)
        true:
            return __c_file_read_bytes(path)


def write_file(path: str, content: str | bytes) -> Result[int, str]:
    '''
    写入文件
    参数:
      path - 文件路径
      content - 文件内容（字符串或字节数组）
    返回: Result[int, str] - 成功时返回 Ok(字节数)，失败时返回 Err(错误信息)
    '''
    let bytes_written: int = 0
    match type of content:
        str:
            bytes_written = __c_file_write(path, content)
        bytes:
            bytes_written = __c_file_write_bytes(path, content)

    if bytes_written == -1:
        return Err("Failed to write file")
    else:
        return Ok(bytes_written)


def append_file(path: str, content: str | bytes) -> Result[int, str]:
    '''
    追加内容到文件
    参数:
      path - 文件路径
      content - 追加的内容（字符串或字节数组）
    返回: Result[int, str] - 成功时返回 Ok(字节数)，失败时返回 Err(错误信息)
    '''
    let bytes_written: int = 0
    match type of content:
        str:
            bytes_written = __c_file_append(path, content)
        bytes:
            bytes_written = __c_file_append_bytes(path, content)

    if bytes_written == -1:
        return Err("Failed to append to file")
    else:
        return Ok(bytes_written)


def delete_file(path: str) -> Result[bool, str]:
    '''
    删除文件
    参数:
      path - 文件路径
    返回: Result[bool, str] - 成功时返回 Ok(true)，失败时返回 Err(错误信息)
    '''
    if __c_file_delete(path) == 1:
        return Ok(true)
    else:
        return Err("Failed to delete file")


def exists_file(path: str) -> bool:
    match __c_file_exists(path):
        1:
            return true
        _:
            return false
