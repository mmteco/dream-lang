# 结构体示例

# 定义一个Point结构体
struct Point:
    x: int
    y: int

# 定义一个Rectangle结构体
struct Rectangle:
    width: int
    height: int

# 创建Point实例
let p1 = Point{x: 10, y: 20}
let p2 = Point{x: 30, y: 40}

print(p1.x)
print(p1.y)
print(p2.x)
print(p2.y)

# 创建Rectangle实例
let rect = Rectangle{width: 100, height: 50}
print(rect.width)
print(rect.height)

# 计算矩形面积（使用字段值）
def area(r: Rectangle) -> int:
    return r.width * r.height

# 这个函数需要在有了乘法运算后才能工作
# let a = area(rect)
# print(a)
