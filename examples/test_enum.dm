# 测试枚举类型

# 简单枚举
enum Color:
    Red
    Green
    Blue

# 带数据的枚举
enum Shape:
    Circle(int)
    Rectangle(int, int)

# 泛型枚举
enum Option[T]:
    Some(T)
    None

# 测试简单枚举
let c1 = Color.Red
let c2 = Color.Green
let c3 = Color.Blue

print(100)

# 测试带数据的枚举
let s1 = Shape.Circle(5)
let s2 = Shape.Rectangle(10, 20)

print(200)

# 测试泛型枚举
let opt1 = Option.Some(42)
let opt2 = Option.None

print(300)
