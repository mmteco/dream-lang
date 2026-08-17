def read_text_file(path: str) -> str:
    return __c_file_read(path)

def write_text_file(path: str, content: str) -> int:
    return __c_file_write(path, content)

def text_length(content: str) -> int:
    return __c_utf8_rune_count(content)

def process_arg_count() -> int:
    return __c_process_arg_count()

def process_arg(index: int) -> str:
    return __c_process_arg(index)

def build_llvm(llvm_path: str, output_path: str) -> bool:
    let status = __c_build_llvm(llvm_path, output_path)
    if status == 0:
        return false
    return true

def write_text_codes(path: str, codes: list[int]) -> int:
    return __c_file_write_bytes(path, codes)
