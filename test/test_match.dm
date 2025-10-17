# Match 表达式、三元运算符和错误传播 - 综合测试

print("=== Match, Ternary and Error Propagation Tests ===")

# ============================================
# 第一部分: Match 表达式基础测试
# ============================================

print("\n--- Part 1: Basic Match ---")

# 测试1: 守卫条件
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

# 测试2: Option 穷尽性检查
let opt1 = Some(42)
match opt1:
    Some(v):
        print(v)
    None:
        print(-1)

# 测试3: Result 穷尽性检查
let res1 = Ok(200)
match res1:
    Ok(v):
        print(v)
    Err(e):
        print(e)

# 测试4: 布尔值穷尽性检查
let b = true
match b:
    true:
        print(1)
    false:
        print(0)

# ============================================
# 第二部分: Match 表达式高级特性
# ============================================

print("\n--- Part 2: Advanced Match ---")

# 测试5: 单行表达式
let x1: int = 2
let result1 = match x1:
    1: 10
    2: 20
    _: 30
print(result1)

# 测试6: 多行表达式
let x2: int = 1
let result2 = match x2:
    1:
        42
    2:
        84
    _:
        0
print(result2)

# 测试7: 嵌套 match
let x3: int = 2
let y3: int = 1
let result3 = match x3:
    1: 10
    2: match y3:
        1: 21
        2: 22
        _: 20
    _: 30
print(result3)

# 测试8: 表达式作为 scrutinee
let x4: int = 5
let result4 = match x4 + 5:
    5: 50
    10: 100
    _: 0
print(result4)

# ============================================
# 第三部分: 三元运算符测试
# ============================================

print("\n--- Part 3: Ternary Operator ---")

# 测试9: 基本三元运算符
let t1: int = 10
let tr1: int = t1 > 5 ? 100 : 200
print(tr1)

# 测试10: 嵌套三元运算符
let t2: int = 85
let temp: int = t2 > 80 ? 2 : t2 > 70 ? 3 : 4
let tr2: int = t2 > 90 ? 1 : temp
print(tr2)

# 测试11: 三元运算符作为函数参数
def max_val(a: int, b: int) -> int:
    return a > b ? a : b

print(max_val(15, 30))

# 测试12: 三元运算符在 match 中使用
let t3 = Ok(3)
let tr3 = match t3:
    Ok(v): v > 2 ? v * 10 : v * 20
    Err(_): -1
print(tr3)

# ============================================
# 第四部分: 错误传播运算符测试
# ============================================

print("\n--- Part 4: Error Propagation ---")

def divide(a: int, b: int) -> Result[int, str]:
    return match b:
        0: Err("division by zero")
        _: Ok(a / b)

# 测试13: 基本错误传播 - 成功情况
def safe_div1(a: int, b: int) -> int:
    let result: int = divide(a, b)?
    return result

print(safe_div1(100, 10))

# 测试14: 基本错误传播 - 失败情况（提前返回）
# 注意：当函数返回 int 时，错误传播会尝试提取 Err 中的值
# 但 Err 包含字符串，所以这里改为返回 Result 类型
def safe_div2(a: int, b: int) -> Result[int, str]:
    let result: int = divide(a, b)?
    return Ok(result + 100)

match safe_div2(100, 0):
    Ok(v):
        print(v)
    Err(_):
        print(-99)

# 测试15: 链式错误传播
def calculate(x: int, y: int, z: int) -> Result[int, str]:
    let step1: int = divide(x, y)?
    let step2: int = divide(step1, z)?
    return Ok(step2)

let chain1 = calculate(100, 10, 2)
match chain1:
    Ok(v):
        print(v)
    Err(_):
        print(-1)

# 测试16: 链式错误传播 - 第一步失败
let chain2 = calculate(100, 0, 2)
match chain2:
    Ok(v):
        print(v)
    Err(_):
        print(-2)

# 测试17: 链式错误传播 - 第二步失败
let chain3 = calculate(100, 10, 0)
match chain3:
    Ok(v):
        print(v)
    Err(_):
        print(-3)

# ============================================
# 第五部分: 组合使用测试
# ============================================

print("\n--- Part 5: Combined Usage ---")

# 测试18: 三元运算符 + 错误传播
def compute1(x: int, y: int) -> int:
    let result: int = divide(x, y)?
    return result > 5 ? result * 2 : result * 3

print(compute1(100, 10))

# 测试19: Match + 三元运算符 + 错误传播
def compute2(flag: int, x: int, y: int) -> int:
    let base: int = divide(x, y)?
    return match flag:
        1: base > 10 ? base * 2 : base * 3
        2: base > 5 ? base + 100 : base + 200
        _: base

print(compute2(1, 100, 10))

# 测试20: 嵌套 match + 三元运算符
def compute3(a: int, b: int) -> int:
    return match a:
        1: match b:
            1: b > 0 ? 10 : 20
            _: 30
        2: b > 5 ? 40 : 50
        _: 60

print(compute3(2, 10))

# 测试21: 错误传播后使用三元运算符
def compute4(x: int, y: int) -> int:
    let step1: int = divide(x, y)?
    let step2: int = divide(step1, 2)?
    return step2 > 10 ? step2 : 10

print(compute4(100, 5))

# 测试22: Match 选择不同的错误传播路径
def compute5(choice: int) -> int:
    return match choice:
        1: divide(100, 10)?
        2: divide(50, 5)?
        _: 0

print(compute5(1))

# ============================================
# 第六部分: 边界情况测试
# ============================================

print("\n--- Part 6: Edge Cases ---")

# 测试23: 复杂嵌套表达式
def complex_expr(x: int, y: int, z: int) -> int:
    let r1 = match x:
        1: divide(100, y)?
        2: divide(200, y)?
        _: 0
    let r2: int = r1 > 5 ? r1 * 2 : r1 * 3
    return match z:
        1: r2 + 10
        2: r2 + 20
        _: r2

print(complex_expr(1, 10, 2))

# 测试24: 三元运算符在错误传播之前
def with_condition(flag: bool, x: int, y: int) -> int:
    let divisor: int = flag ? y : 1
    let result: int = divide(x, divisor)?
    return result

print(with_condition(true, 100, 10))

# 测试25: Match 返回 Result，使用错误传播
def get_result(x: int) -> Result[int, str]:
    return match x:
        0: Err("zero not allowed")
        _: Ok(x * 10)

def use_result(x: int) -> int:
    let val: int = get_result(x)?
    return val + 5

print(use_result(5))

print("\n=== All Tests Passed ===")
