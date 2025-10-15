# Union GC 测试
# 验证 union 对象被正确跟踪和释放

# 测试1: 简单的 union 创建和使用
let x: int | string = 42
print(x)  # 输出 42

let y: int | string = "hello"
print(y)  # 输出 hello

# 测试2: Union 在函数中创建和返回
def create_union(flag: int) -> int | string:
    match flag:
        1:
            return 100
        _:
            return "world"

let r1: int | string = create_union(1)
print(r1)  # 输出 100

let r2: int | string = create_union(2)
print(r2)  # 输出 world

# 测试3: Union 在循环中创建
let i: int = 0
while i < 5:
    let tmp: int | string = i
    print(tmp)
    i = i + 1

# 测试4: Union 赋值覆盖
let v: int | string = "test1"
print(v)  # 输出 test1

v = 999
print(v)  # 输出 999

v = "test2"
print(v)  # 输出 test2
