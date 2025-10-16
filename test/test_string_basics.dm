# 字符串基础功能测试

# === 字符串方法测试 ===

let s: string = "Hello World"

# 测试 length 方法
print(s.length())  # 11

# 测试 upper/lower 方法
print(s.upper())  # HELLO WORLD
print(s.lower())  # hello world

# 测试 strip 方法
let s2: string = "  hello  "
print(s2.strip())  # hello

# 测试 find 方法
print(s.find("World"))  # 6
print(s.find("xyz"))    # -1

# 测试 starts_with/ends_with 方法
print(s.starts_with("Hello"))  # true
print(s.starts_with("World"))  # false
print(s.ends_with("World"))    # true
print(s.ends_with("Hello"))    # false

# 测试 replace 方法
print(s.replace("World", "Dream"))  # Hello Dream
print(s.replace("xyz", "abc"))      # Hello World


# === 字符串比较操作符测试 ===

let apple: string = "apple"
let banana: string = "banana"
let apple2: string = "apple"

# 测试 == 操作符
print(apple == apple2)  # true
print(apple == banana)  # false

# 测试 != 操作符
print(apple != banana)  # true
print(apple != apple2)  # false

# 测试 < 操作符
print(apple < banana)   # true (apple < banana)
print(banana < apple)   # false
print(apple < apple2)   # false (相等)

# 测试 > 操作符
print(banana > apple)   # true (banana > apple)
print(apple > banana)   # false
print(apple > apple2)   # false (相等)

# 测试 <= 操作符
print(apple <= banana)  # true
print(apple <= apple2)  # true (相等)
print(banana <= apple)  # false

# 测试 >= 操作符
print(banana >= apple)  # true
print(apple >= apple2)  # true (相等)
print(apple >= banana)  # false

# 测试字符串字面量直接比较
print("hello" == "hello")  # true
print("hello" == "world")  # false
print("abc" < "def")       # true
print("xyz" > "abc")       # true


# === 字符级别方法测试 ===

let test: string = "A1 B2"

# 测试 is_alpha
print(test.is_alpha(0))  # true (A)
print(test.is_alpha(3))  # true (B)
print(test.is_alpha(1))  # false (1)

# 测试 is_digit
print(test.is_digit(1))  # true (1)
print(test.is_digit(4))  # true (2)
print(test.is_digit(0))  # false (A)

# 测试 is_whitespace
print(test.is_whitespace(2))  # true (空格)
print(test.is_whitespace(0))  # false (A)


# === 字符串 split 和 join 测试 ===

let text: string = "apple,banana,orange"
let parts = text.split(",")

# 测试 join
let result = join(parts, " - ")
print(result)  # apple - banana - orange
