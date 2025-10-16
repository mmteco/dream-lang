# Match 表达式全面测试
# 覆盖: 单行/多行 × 有赋值/无赋值 × 有返回/无返回 × 嵌套/函数调用
# 共 24 个测试用例

print("=== Match Comprehensive Test ===")

# ============================================
# 一、单行表达式 (Single-line Expression)
# ============================================

print("\n--- 1. 单行表达式: 无赋值, 有返回值 ---")
let x1: int = 2
let result1 = match x1:
    1: 10
    2: 20
    _: 30

print(result1)  # 应输出 20

print("\n--- 2. 单行表达式: 有赋值, 无返回值 (void) ---")
let x2: int = 1
let var2: int = 0
match x2:
    1: var2 = 100
    2: var2 = 200
    _: var2 = 300

print(var2)  # 应输出 100

print("\n--- 3. 单行表达式: 计算表达式 ---")
let x3: int = 3
let result3 = match x3:
    1: 5 + 5
    2: 10 + 10
    3: 15 + 15
    _: 0

print(result3)  # 应输出 30

print("\n--- 4. 单行表达式: 函数调用 (返回 void) ---")
let x4: int = 2
match x4:
    1: print("one")
    2: print("two")
    _: print("other")

# 应输出 "two"

# ============================================
# 二、多行语句块: 单个表达式
# ============================================

print("\n--- 5. 多行单表达式: 有返回值 ---")
let x5: int = 1
let result5 = match x5:
    1:
        42
    2:
        84
    _:
        0

print(result5)  # 应输出 42

print("\n--- 6. 多行单表达式: 计算 ---")
let x6: int = 2
let result6 = match x6:
    1:
        10 + 20
    2:
        30 + 40
    _:
        0

print(result6)  # 应输出 70

# ============================================
# 三、多行语句块: 单个赋值
# ============================================

print("\n--- 7. 多行单赋值: 有赋值, 无返回值 ---")
let x7: int = 3
let var7: int = 0
match x7:
    1:
        var7 = 111
    2:
        var7 = 222
    _:
        var7 = 333

print(var7)  # 应输出 333

print("\n--- 8. 多行单赋值: 赋值计算结果 ---")
let x8: int = 1
let var8: int = 0
match x8:
    1:
        var8 = 50 + 50
    2:
        var8 = 100 + 100
    _:
        var8 = 999

print(var8)  # 应输出 100

# ============================================
# 四、枚举类型测试
# ============================================

print("\n--- 9. 枚举匹配: 单行表达式 ---")
let res9 = Ok(42)
let result9 = match res9:
    Ok(v): v + 10
    Err(e): 0

print(result9)  # 应输出 52

print("\n--- 10. 枚举匹配: 单行赋值 ---")
let res10 = Err(404)
let var10: int = 0
match res10:
    Ok(v): var10 = v
    Err(e): var10 = 999

print(var10)  # 应输出 999

print("\n--- 11. 枚举匹配: 多行表达式 ---")
let res11 = Ok(100)
let result11 = match res11:
    Ok(v):
        v * 2
    Err(e):
        0

print(result11)  # 应输出 200

print("\n--- 12. 枚举匹配: 多行赋值 ---")
let res12 = Ok(50)
let var12: int = 0
match res12:
    Ok(v):
        var12 = v + 50
    Err(e):
        var12 = 0

print(var12)  # 应输出 100

# ============================================
# 五、混合情况: 不同分支不同类型
# ============================================

print("\n--- 13. 混合: 有的分支赋值, 有的分支返回表达式 ---")
# 注意: 所有分支应该是一致的类型, 这里测试赋值语句
let x13: int = 2
let var13a: int = 0
let var13b: int = 0
match x13:
    1:
        var13a = 10
    2:
        var13b = 20
    _:
        var13a = 30

print(var13a)  # 应输出 0
print(var13b)  # 应输出 20

print("\n--- 14. 混合: 单行和多行混合 (都是赋值) ---")
let x14: int = 3
let var14: int = 0
match x14:
    1: var14 = 100
    2:
        var14 = 200
    _: var14 = 300

print(var14)  # 应输出 300

# ============================================
# 六、嵌套 match
# ============================================

print("\n--- 15. 嵌套 match: 单行返回值 ---")
let x15: int = 2
let y15: int = 1
let result15 = match x15:
    1: 10
    2: match y15:
        1: 21
        2: 22
        _: 20
    _: 30

print(result15)  # 应输出 21

print("\n--- 16. 嵌套 match: 多行返回值 ---")
let x16: int = 1
let y16: int = 2
let result16 = match x16:
    1:
        match y16:
            1: 100
            2: 200
            _: 300
    2: 400
    _: 500

print(result16)  # 应输出 200

# ============================================
# 七、边界情况
# ============================================

print("\n--- 17. 所有分支返回 void (print) ---")
let x17: int = 3
match x17:
    1: print("first")
    2: print("second")
    _: print("default")

# 应输出 "default"

print("\n--- 18. 表达式作为 scrutinee ---")
let x18: int = 5
let result18 = match x18 + 5:
    5: 50
    10: 100
    _: 0

print(result18)  # 应输出 100

print("\n--- 19. 复杂表达式作为分支值 ---")
let x19: int = 1
let a: int = 10
let b: int = 20
let result19 = match x19:
    1: a + b * 2
    2: a * b
    _: 0

print(result19)  # 应输出 50

print("\n--- 20. 通配符 match 赋值 ---")
let x20: int = 999
let var20: int = 0
match x20:
    _: var20 = 777

print(var20)  # 应输出 777

# ============================================
# 八、嵌套 match 与函数调用
# ============================================

def get_value(x: int) -> int:
    return x * 10

def compute(a: int, b: int) -> int:
    return a + b

print("\n--- 21. 嵌套 match: 函数调用返回值 (单行) ---")
let x21: int = 1
let y21: int = 2
let result21 = match x21:
    1: match y21:
        1: get_value(5)
        2: get_value(10)
        _: get_value(0)
    2: get_value(20)
    _: get_value(99)

print(result21)  # 应输出 100

print("\n--- 22. 嵌套 match: 函数调用返回值 (多行) ---")
let x22: int = 2
let y22: int = 1
let result22 = match x22:
    1:
        get_value(1)
    2:
        match y22:
            1: compute(30, 12)
            2: compute(50, 50)
            _: compute(0, 0)
    _:
        get_value(999)

print(result22)  # 应输出 42

print("\n--- 23. 嵌套 match: 三层嵌套函数调用 ---")
let x23: int = 1
let y23: int = 2
let z23: int = 3
let result23 = match x23:
    1:
        match y23:
            1: get_value(1)
            2:
                match z23:
                    1: compute(10, 10)
                    2: compute(20, 20)
                    3: compute(15, 15)
                    _: 0
            _: get_value(9)
    2: get_value(50)
    _: 0

print(result23)  # 应输出 30

print("\n--- 24. 嵌套 match: 混合函数调用和表达式 ---")
let x24: int = 2
let y24: int = 1
let result24 = match x24:
    1: 10 + 20
    2: match y24:
        1: get_value(5) + compute(10, 5)
        2: 100
        _: 0
    _: get_value(0)

print(result24)  # 应输出 65

print("\n=== All Match Tests Passed ===")
