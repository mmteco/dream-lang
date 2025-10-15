# 枚举和模式匹配综合测试

# 简单枚举
enum Color:
    Red
    Green
    Blue

# 带数据的枚举
enum Shape:
    Circle(int)
    Rectangle(int, int)

# 测试1: 简单枚举构造
let c1 = Color.Red
let c2 = Color.Green

print(100)

# 测试2: 带数据的枚举构造
let s1 = Shape.Circle(5)
let s2 = Shape.Rectangle(10, 20)

print(200)

# 测试3: match语句（case关键字可选）✅
# 不带case关键字
match c1:
    Color.Red:
        print(1)
    Color.Green:
        print(2)
    Color.Blue:
        print(3)

# 带case关键字（向后兼容）
match c2:
    case Color.Red:
        print(10)
    case Color.Green:
        print(20)
    case Color.Blue:
        print(30)

# 测试4: 通配符模式
let c3 = Color.Blue
match c3:
    Color.Red:
        print(100)
    _:
        print(999)

print(300)
