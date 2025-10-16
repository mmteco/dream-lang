# Dream 类型系统综合测试
# 包含：Union 类型、类型模式匹配、接口、结构体

print("=== Type System Test ===")

# ========================================
# Union 类型
# ========================================
print("--- Union Type Tests ---")

# 基础 Union 类型
let x: int | str = 42
print(x)  # 42

let y: int | str = "hello"
print(y)  # "hello"

# Union 类型函数参数
def process_value(val: int | str) -> int:
    match val:
        n: int:
            return n * 2
        s: str:
            return s.length()
        _:
            return 0

print(process_value(21))      # 42
print(process_value("test"))  # 4

# ========================================
# 类型模式匹配
# ========================================
print("--- Type Pattern Matching ---")

def test_type_match(value: str | int) -> int:
    match value:
        s: str:
            return 1
        n: int:
            return 2
        _:
            return 0

print(test_type_match("hello"))  # 1
print(test_type_match(42))       # 2

# ========================================
# 结构体
# ========================================
print("--- Struct Tests ---")

struct Point:
    x: int
    y: int

    def get_x(self) -> int:
        return self.x

    def get_y(self) -> int:
        return self.y

let p = Point{x: 10, y: 20}
print(p.x)          # 10
print(p.y)          # 20
print(p.get_x())    # 10
print(p.get_y())    # 20

# ========================================
# 接口
# ========================================
print("--- Interface Tests ---")

interface Drawable:
    def draw(self) -> int

struct Circle:
    radius: int

    def draw(self) -> int:
        return self.radius

impl Drawable for Circle:
    def draw(self) -> int:
        return self.radius * 2

let c = Circle{radius: 5}
print(c.draw())  # 5

print("=== All Type Tests Passed ===")
print(999)
