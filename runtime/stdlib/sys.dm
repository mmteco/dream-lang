def argc() -> int:
    return __c_process_arg_count()

def arg(index: int) -> str:
    return __c_process_arg(index)

def env(name: str) -> str:
    return __c_env(name)

def build(llvm_path: str, output_path: str, optimized: bool = true) -> bool:
    let status = __c_build_llvm(llvm_path, output_path, optimized)
    if status == 0:
        return false
    return true
