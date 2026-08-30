# dream-test: dir
# Dream 文件 I/O 综合测试

from io import open
from fs import exists, delete
from bytes import encode

def report_result(r: Result[int, str]) -> int:
    return match r:
        Ok(bytes): bytes
        Err(msg): -1

def main():
    print("=== File I/O Test ===")

    print("--- Text Write/Read ---")

    let writer = open("test1.txt", "w")
    let result1 = writer.write("Hello Dream")
    print(report_result(result1))

    let reader = open("test1.txt", "r")
    let content1 = reader.read()
    print(content1)

    let exists1 = exists("test1.txt")
    print(exists1)

    print("--- Bytes Write/Read ---")

    let bytes_writer = open("test2.txt", "wb")
    let result2 = bytes_writer.write_bytes(encode("Hello"))
    print(report_result(result2))

    let bytes_read = open("test2.txt", "rb").read_bytes()
    print(len(bytes_read))

    print("--- Append ---")

    let append_writer = open("test1.txt", "a")
    let result3 = append_writer.write(" World")
    print(report_result(result3))

    let content2 = reader.read()
    print(content2)

    print("--- Error Case ---")

    let result4 = open("/nonexistent_dir/test.txt", "w").write("fail")
    print(report_result(result4))

    print("--- Cleanup ---")

    let del1 = delete("test1.txt")
    print(del1)

    let del2 = delete("test2.txt")
    print(del2)

    print("=== All File I/O Tests Passed ===")
    print(999)

main()
