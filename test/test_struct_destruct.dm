# 结构体解构测试

print("=== Struct Destructuring Tests ===")

# 1. 基本结构体解构
struct Point:
    x: int
    y: int

let p = Point{x: 10, y: 20}
let Point{x: px, y: py} = p
print(px)  # 10
print(py)  # 20

# 2. 嵌套结构体解构
struct Line:
    start: Point
    end: Point

let line = Line{start: Point{x: 0, y: 0}, end: Point{x: 100, y: 100}}
let Line{start: Point{x: x1, y: y1}, end: Point{x: x2, y: y2}} = line
print(x1)  # 0
print(y1)  # 0
print(x2)  # 100
print(y2)  # 100

# 3. 部分字段解构
let Point{x: only_x, y: _} = p
print(only_x)  # 10

# 4. 在函数参数中使用结构体（虽然不是直接解构，但可以测试传递）
def distance(p1: Point, p2: Point) -> int:
    let Point{x: x1, y: y1} = p1
    let Point{x: x2, y: y2} = p2
    let dx = x2 - x1
    let dy = y2 - y1
    return dx * dx + dy * dy

let d = distance(Point{x: 0, y: 0}, Point{x: 3, y: 4})
print(d)  # 25 (3^2 + 4^2)

# 5. 结构体解构在循环中
struct Person:
    name: str
    age: int

# 注意：这需要列表支持，暂时用单个测试
let alice = Person{name: "Alice", age: 30}
let Person{name: n, age: a} = alice
print(a)  # 30

print("=== All Tests Passed ===")
print(999)
