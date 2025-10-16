# Dream 文件 I/O 综合测试
# 包含：字符串读写、字节读写、追加、删除、类型模式匹配

print("=== File I/O Test ===")

# ========================================
# 基础字符串读写
# ========================================
print("--- String Read/Write ---")

let result1 = write_file("test1.txt", "Hello Dream")
print(result1)  # 1

let content1 = read_file("test1.txt")
print(content1)  # "Hello Dream"

let exists1 = exists_file("test1.txt")
print(exists1)  # 1

# ========================================
# 字节模式读写
# ========================================
print("--- Bytes Read/Write ---")

let bytes_content = read_bytes_file("test1.txt")
print(bytes_content[0])  # 72 (H)
print(bytes_content[1])  # 101 (e)

let byte_array = [72, 101, 108, 108, 111]  # "Hello"
let result2 = write_bytes_file("test2.txt", byte_array)
print(result2)  # 1

let bytes_read = read_bytes_file("test2.txt")
print(bytes_read[0])  # 72 (H)

# ========================================
# 追加内容
# ========================================
print("--- Append ---")

let result3 = append_file("test1.txt", " World")
print(result3)  # 1

let content2 = read_file("test1.txt")
print(content2)  # "Hello Dream World"

# ========================================
# Union 类型 + 类型模式匹配
# ========================================
print("--- Union Type File I/O ---")

def write_unified_file(path: str, content: str | bytes) -> int:
    match type of content:
        str:
            return write_file(path, data)
        bytes:
            return write_bytes_file(path, data)
        _:
            return 0

let result4 = write_unified_file("test3.txt", "Hello Union")
print(result4)  # 1

let content3 = read_file("test3.txt")
print(content3)  # "Hello Union"

# ========================================
# 清理测试文件
# ========================================
print("--- Cleanup ---")

delete_file("test1.txt")
delete_file("test2.txt")
delete_file("test3.txt")

print("=== All File I/O Tests Passed ===")
print(999)
