# Union 类型综合测试
# 涵盖：装箱、拆箱、match 匹配、print 输出、函数参数装箱

# 1. 整数和字符串 union
let x: int | string = 42
let y: int | string = "hello"

# 2. match 匹配测试
match x:
    42:
        print(1)  # 输出 1
    "world":
        print(2)
    _:
        print(0)

match y:
    100:
        print(0)
    "hello":
        print(3)  # 输出 3
    _:
        print(0)

# 3. 布尔值 union
let b1: int | bool = True
let b2: int | bool = False

match b1:
    True:
        print(4)  # 输出 4
    False:
        print(5)
    _:
        print(0)

match b2:
    True:
        print(0)
    False:
        print(6)  # 输出 6
    _:
        print(0)

# 4. 通配符匹配
let w: int | string = 999
match w:
    42:
        print(0)
    "test":
        print(0)
    _:
        print(7)  # 输出 7

# 5. print 输出 union 值
print(x)   # 输出 42
print(y)   # 输出 hello
print(b1)  # 输出 True
print(b2)  # 输出 False
print(w)   # 输出 999

# 6. 函数参数自动装箱
def process(v: int | string) -> int:
    match v:
        42:
            return 10
        "test":
            return 20
        _:
            return 0

print(process(42))      # 输出 10 (自动装箱)
print(process("test"))  # 输出 20 (自动装箱)
print(process(x))       # 输出 10 (已是 union,不装箱)
print(process(999))     # 输出 0

# 7. 多个 union 参数
def compare(a: int | string, b: int | bool) -> int:
    match a:
        100:
            return 30
        200:
            return 40
        _:
            return 0

print(compare(100, True))   # 输出 30
print(compare(200, False))  # 输出 40
print(compare(300, True))   # 输出 0

# 8. Union 返回值自动装箱
def get_value(flag: int) -> int | string:
    match flag:
        1:
            return 42
        2:
            return "world"
        _:
            return 888

let r1: int | string = get_value(1)
print(r1)  # 输出 42

let r2: int | string = get_value(2)
print(r2)  # 输出 world

# 在 match 中使用返回的 union
match get_value(1):
    42:
        print(50)  # 输出 50
    _:
        print(0)
