# Dream 文件 I/O 综合测试
# 包含：字符串读写、字节读写、追加、删除、类型模式匹配

print("=== File I/O Test ===")

# ========================================
# 基础字符串读写
# ========================================
print("--- String Read/Write ---")

let result1 = file_write("test1.txt", "Hello Dream")
print(result1)  # 1

let content1 = file_read("test1.txt")
print(content1)  # "Hello Dream"

let exists1 = file_exists("test1.txt")
print(exists1)  # 1

# ========================================
# 字节模式读写
# ========================================
print("--- Bytes Read/Write ---")

let bytes_content = file_read_bytes("test1.txt")
print(bytes_content[0])  # 72 (H)
print(bytes_content[1])  # 101 (e)

let byte_array = [72, 101, 108, 108, 111]  # "Hello"
let result2 = file_write_bytes("test2.txt", byte_array)
print(result2)  # 1

let bytes_read = file_read_bytes("test2.txt")
print(bytes_read[0])  # 72 (H)

# ========================================
# 追加内容
# ========================================
print("--- Append ---")

let result3 = file_append("test1.txt", " World")
print(result3)  # 1

let content2 = file_read("test1.txt")
print(content2)  # "Hello Dream World"

# ========================================
# Union 类型 + 类型模式匹配
# ========================================
print("--- Union Type File I/O ---")

def file_write_unified(path: str, content: str | bytes) -> int:
    match content:
        data: str:
            return file_write(path, data)
        data: bytes:
            return file_write_bytes(path, data)
        _:
            return 0

let result4 = file_write_unified("test3.txt", "Hello Union")
print(result4)  # 1

let content3 = file_read("test3.txt")
print(content3)  # "Hello Union"

# ========================================
# 清理测试文件
# ========================================
print("--- Cleanup ---")

file_delete("test1.txt")
file_delete("test2.txt")
file_delete("test3.txt")

print("=== All File I/O Tests Passed ===")
print(999)
