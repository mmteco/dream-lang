# 时间标准库

def monotonic_ms() -> int:
    return __c_time_ms()

def elapsed_ms(start_ms: int) -> int:
    return monotonic_ms() - start_ms
