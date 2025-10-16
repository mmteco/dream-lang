# 字符串基础用法示例

# 字符串声明
let greeting: string = "Hello, Dream!"
print(greeting)

# 字符串方法
print(greeting.length())           # 14
print(greeting.upper())            # HELLO, DREAM!
print(greeting.lower())            # hello, dream!

# 字符串查找和替换
let text: string = "Dream Language"
print(text.find("Language"))       # 6
print(text.replace("Language", "Compiler"))  # Dream Compiler

# 字符串前后缀检查
print(text.starts_with("Dream"))   # true
print(text.ends_with("Language"))  # true

# 字符串比较
let name1: string = "Alice"
let name2: string = "Bob"

print(name1 == name2)              # false
print(name1 != name2)              # true
print(name1 < name2)               # true (字典序)
print(name2 > name1)               # true

# 字符串切片
let msg: string = "Hello World"
print(msg[0])                      # 72 (ASCII码)
print(msg[0:5])                    # Hello

# 去除空白
let padded: string = "  trimmed  "
print(padded.strip())              # trimmed

# 字符串分割和连接
let csv: string = "apple,banana,orange"
let fruits = csv.split(",")
let result = join(fruits, " | ")
print(result)                      # apple | banana | orange

# 字符级别方法
let sample: string = "A1 B2"
print(sample.is_alpha(0))          # true (A)
print(sample.is_digit(1))          # true (1)
print(sample.is_whitespace(2))     # true (空格)
