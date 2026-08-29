# dream-test: dir
# time 标准库测试

from time import monotonic_ms, elapsed_ms

def main():
    let start_ms = monotonic_ms()
    let end_ms = monotonic_ms()
    print(end_ms >= start_ms)
    print(elapsed_ms(start_ms) >= 0)

main()
