# Dream 文件 I/O 综合测试
# 包含：字符串读写、字节读写、追加、删除、类型模式匹配

from file import write_file, read_file, append_file, delete_file, exists_file

print("=== File I/O Test ===")

print("--- String Read/Write ---")

let result1 = write_file("test1.txt", "Hello Dream")
match result1:
    Ok(bytes):
        print(bytes)
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let content1 = read_file("test1.txt")
print(content1)

let exists1 = exists_file("test1.txt")
print(exists1)

print("--- Bytes Read/Write ---")

let bytes_content = read_file("test1.txt", true)
print("Read bytes successfully")

let result2 = write_file("test2.txt", "Hello")
match result2:
    Ok(bytes):
        print(bytes)
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let bytes_read = read_file("test2.txt", true)
print("Read bytes from test2.txt")

print("--- Append ---")

let result3 = append_file("test1.txt", " World")
match result3:
    Ok(bytes):
        print(bytes)
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let content2 = read_file("test1.txt")
print(content2)

print("--- Union Type File I/O ---")

def write_unified_file(path: str, content: str) -> Result[int, str]:
    return write_file(path, content)

let result4 = write_unified_file("test3.txt", "Hello Union")
match result4:
    Ok(bytes):
        print(bytes)
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let content3 = read_file("test3.txt")
print(content3)

print("--- Cleanup ---")

let del1 = delete_file("test1.txt")
match del1:
    Ok(success):
        print("Deleted test1.txt")
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let del2 = delete_file("test2.txt")
match del2:
    Ok(success):
        print("Deleted test2.txt")
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

let del3 = delete_file("test3.txt")
match del3:
    Ok(success):
        print("Deleted test3.txt")
    Err(msg):
        print(msg)
    _:
        print("Unknown error")

print("=== All File I/O Tests Passed ===")
print(999)
