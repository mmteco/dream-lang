# Process and environment utilities

def argc() -> int:
    return __c_process_arg_count()

def arg(index: int) -> str:
    return __c_process_arg(index)

def env(name: str) -> str:
    return __c_env(name)
