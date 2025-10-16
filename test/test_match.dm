# 模式匹配综合测试

# ===== 测试1: 守卫条件基础测试 =====
print(1)

enum MyResult:
    Success(int)
    Failure(int)

let r1 = MyResult.Success(15)

match r1:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)

let r2 = MyResult.Success(5)

match r2:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)

let r3 = MyResult.Failure(404)

match r3:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)


# ===== 测试2: 穷尽性检查 - 完整的 Option 匹配 =====
print(2)

let x1 = Some(42)
match x1:
    Some(v):
        print(v)
    None:
        print(-1)


# ===== 测试3: 穷尽性检查 - 使用通配符的 Option 匹配 =====
print(3)

let x2 = Some(100)
match x2:
    Some(v):
        print(v)
    _:
        print(-1)


# ===== 测试4: 穷尽性检查 - 完整的 Result 匹配 =====
print(4)

let x3 = Ok(200)
match x3:
    Ok(v):
        print(v)
    Err(e):
        print(e)


# ===== 测试5: 穷尽性检查 - 布尔值完整匹配 =====
print(5)

let b = true
match b:
    true:
        print(1)
    false:
        print(0)


# ===== 测试6: 带守卫的 Option 匹配 =====
print(6)

let y = Some(50)
match y:
    Some(v) if v > 40:
        print(v)
    Some(v):
        print(-2)
    None:
        print(-1)
