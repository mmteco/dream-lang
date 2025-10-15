# 测试小写关键字：true, false, none

# 测试1: 小写 true 和 false
let x: bool = true
let y: bool = false

print(x)  # 输出 True
print(y)  # 输出 False

# 测试2: 大写 True 和 False（兼容性）
let a: bool = True
let b: bool = False

print(a)  # 输出 True
print(b)  # 输出 False

# 测试3: 小写 none（目前可能没有类型支持，但应该能解析）
# let n = none

# 测试4: 在表达式中使用
let result: bool = true and false
print(result)  # 输出 False

let result2: bool = true or false
print(result2)  # 输出 True

# 测试5: 在 if 条件中使用
if true:
    print(1)

if false:
    print(2)
else:
    print(3)

# 测试6: 在 match 中使用
match true:
    true:
        print(4)
    false:
        print(5)

match false:
    true:
        print(6)
    false:
        print(7)

# 测试7: Union 类型
let u1: int | bool = true
print(u1)

let u2: int | bool = false
print(u2)

# 测试8: 函数参数
def test_bool(flag: bool) -> int:
    match flag:
        true:
            return 10
        false:
            return 20

print(test_bool(true))   # 输出 10
print(test_bool(false))  # 输出 20
