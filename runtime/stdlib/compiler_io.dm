def read(path: str) -> str:
    return __c_file_read(path)

def write(path: str, content: str) -> int:
    return __c_file_write(path, content)

def text_len(content: str) -> int:
    return __c_utf8_rune_count(content)

def argc() -> int:
    return __c_process_arg_count()

def arg(index: int) -> str:
    return __c_process_arg(index)

def env(name: str) -> str:
    return __c_env(name)

def exists(path: str) -> bool:
    return __c_file_exists(path)

def build(llvm_path: str, output_path: str, optimized: bool = true) -> bool:
    let status = __c_build_llvm(llvm_path, output_path, optimized)
    if status == 0:
        return false
    return true

def write_codes(path: str, codes: list[int]) -> int:
    return __c_file_write_bytes(path, codes)
