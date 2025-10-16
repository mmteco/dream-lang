# 模式匹配穷尽性检查测试套件

# ===== 测试1: 完整的 Option 匹配 =====
print(1)  # 标记测试1开始
let x1 = Some(42)
match x1:
    Some(v):
        print(v)
    None:
        print(-1)

# ===== 测试2: 使用通配符的 Option 匹配 =====
print(2)  # 标记测试2开始
let x2 = Some(100)
match x2:
    Some(v):
        print(v)
    _:
        print(-1)

# ===== 测试3: 完整的 Result 匹配 =====
print(3)  # 标记测试3开始
let x3 = Ok(200)
match x3:
    Ok(v):
        print(v)
    Err(e):
        print(e)

# ===== 测试4: 布尔值完整匹配 =====
print(4)  # 标记测试4开始
let b = true
match b:
    true:
        print(1)
    false:
        print(0)

# ===== 测试5: 带守卫的匹配（从 test_match_guard.dm）=====
print(5)  # 标记测试5开始
let y = Some(50)
match y:
    Some(v) if v > 40:
        print(v)
    Some(v):
        print(-2)
    None:
        print(-1)
