# 泛型系统综合测试

# 基础泛型identity函数
def identity[T](x: T) -> T:
    return x

# 泛型add函数
def add[T](a: T, b: T) -> T:
    return a + b

# 泛型sub函数
def sub[T](a: T, b: T) -> T:
    return a - b

# 泛型mul函数
def mul[T](a: T, b: T) -> T:
    return a * b

# 测试1: 基础identity函数 - 多次实例化
let a1 = identity(10)
let a2 = identity(20)
let a3 = identity(30)

print(a1)
print(a2)
print(a3)

# 测试2: 泛型add函数
let b1 = add(5, 10)
let b2 = add(100, 200)

print(b1)
print(b2)

# 测试3: 泛型sub函数
let c1 = sub(100, 30)
let c2 = sub(500, 200)

print(c1)
print(c2)

# 测试4: 泛型mul函数
let d1 = mul(6, 7)
let d2 = mul(10, 20)

print(d1)
print(d2)

# 测试5: 混合使用多个泛型函数
let e1 = identity(42)
let e2 = add(e1, 8)
let e3 = mul(e2, 2)

print(e1)
print(e2)
print(e3)
