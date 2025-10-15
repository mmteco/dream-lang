# Union 类型测试

# 测试1: 简单union类型注解
let x: int | string = 42
print(x)

# 测试2: union类型注解与字符串值
let y: int | string = "hello"
print(100)

# 测试3: 多类型union
let z: int | string | bool = True
print(200)

# 测试4: 函数参数使用union类型
def process(value: int | string) -> int:
    # 简化处理：总是返回固定值
    return 999

let result1 = process(42)
print(result1)

let result2 = process("test")
print(result2)

print(888)
