# dream-test: dir
# Dream 文件 I/O 综合测试（bootstrap 子集）
# 包含：文本读写、字节读写、追加、删除、错误处理

from file import read_text, read_bytes, write_text, write_bytes, append_text, delete_file, exists_file
from bytes import str_to_bytes

def report_result(r: Result[int, str]) -> int:
    return match r:
        Ok(bytes): bytes
        Err(msg): -1

def main():
    print("=== File I/O Test ===")

    print("--- Text Write/Read ---")

    let result1 = write_text("test1.txt", "Hello Dream")
    print(report_result(result1))

    let content1 = read_text("test1.txt")
    print(content1)

    let exists1 = exists_file("test1.txt")
    print(exists1)

    print("--- Bytes Write/Read ---")

    let result2 = write_bytes("test2.txt", str_to_bytes("Hello"))
    print(report_result(result2))

    let bytes_read = read_bytes("test2.txt")
    print(len(bytes_read))

    print("--- Append ---")

    let result3 = append_text("test1.txt", " World")
    print(report_result(result3))

    let content2 = read_text("test1.txt")
    print(content2)

    print("--- Error Case ---")

    let result4 = write_text("/nonexistent_dir/test.txt", "fail")
    print(report_result(result4))

    print("--- Cleanup ---")

    let del1 = delete_file("test1.txt")
    print(del1)

    let del2 = delete_file("test2.txt")
    print(del2)

    print("=== All File I/O Tests Passed ===")
    print(999)

main()
