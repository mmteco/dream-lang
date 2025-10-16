# 模式匹配错误检测测试
# 这些用例应该触发编译错误

# ===== 错误1: 缺少 None 分支 =====
# 预期错误: Match is not exhaustive. Missing cases: None
let x1 = Some(42)
match x1:
    Some(v):
        print(v)

# ===== 错误2: 缺少 Err 分支 =====
# 预期错误: Match is not exhaustive. Missing cases: Err
let x2 = Ok(100)
match x2:
    Ok(v):
        print(v)

# ===== 错误3: 不可达的模式 =====
# 预期错误: Pattern 'Some' (case 3) is unreachable
let x3 = Some(42)
match x3:
    Some(v):
        print(v)
    None:
        print(-1)
    Some(y):
        print(y)

# ===== 错误4: 缺少 false 分支 =====
# 预期错误: Match is not exhaustive. Missing cases: false
let b = true
match b:
    true:
        print(1)
