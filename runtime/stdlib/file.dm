# 文件操作标准库（bootstrap 子集）
# 文本与字节读写，函数名按类型区分，返回 Result 便于错误处理

def read_text(path: str) -> str:
    return __c_file_read(path)

def read_bytes(path: str) -> bytes:
    return __c_file_read_bytes(path)

def write_text(path: str, content: str) -> Result[int, str]:
    let written = __c_file_write(path, content)
    if written == -1:
        return Err("failed to write file")
    return Ok(written)

def write_bytes(path: str, content: bytes) -> Result[int, str]:
    let written = __c_file_write_bytes(path, content)
    if written == -1:
        return Err("failed to write bytes")
    return Ok(written)

def append_text(path: str, content: str) -> Result[int, str]:
    let written = __c_file_append(path, content)
    if written == -1:
        return Err("failed to append file")
    return Ok(written)

def append_bytes(path: str, content: bytes) -> Result[int, str]:
    let written = __c_file_append_bytes(path, content)
    if written == -1:
        return Err("failed to append bytes")
    return Ok(written)

def delete_file(path: str) -> bool:
    return __c_file_delete(path)

def exists_file(path: str) -> bool:
    return __c_file_exists(path)
