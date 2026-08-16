def read_text_file(path: str) -> str:
    return __c_file_read(path)

def write_text_file(path: str, content: str) -> int:
    return __c_file_write(path, content)

def text_char_code(content: str, index: int) -> int:
    return __c_utf8_byte_at(content, index)

def text_length(content: str) -> int:
    return __c_utf8_rune_count(content)

def write_text_codes(path: str, codes: list[int]) -> int:
    return __c_file_write_bytes(path, codes)
