# 接口示例：展示 Dream 语言的接口系统

# 1. 定义一个简单的接口
interface Printable:
    def show() -> string

# 2. 定义带泛型和关联类型的接口
interface Container[T]:
    type Item
    const MAX_SIZE: int = 100

    def size() -> int
    def get(index: int) -> T

    # 默认实现
    def is_empty() -> bool:
        return self.size() == 0

# 3. 定义运算符重载接口
interface Add[T]:
    def add(other: T) -> T

# 4. 为内置类型 int 实现 Add 接口
impl Add[int] for int:
    def add(other: int) -> int:
        return self + other

# 5. 定义自定义类型
enum Option[T]:
    Some(T)
    Nothing

# 6. 为 Option 实现 Printable 接口（显式实现）
impl Printable for Option[int]:
    def show() -> string:
        match self:
            Option.Some(x):
                return "Some(" + string(x) + ")"
            Option.Nothing:
                return "Nothing"

# 7. 定义 Point 类型（用枚举模拟结构体）
enum Point:
    P(int, int)

# 8. 为 Point 实现 Add 接口
impl Add[Point] for Point:
    def add(other: Point) -> Point:
        match self:
            Point.P(x1, y1):
                match other:
                    Point.P(x2, y2):
                        return Point.P(x1 + x2, y1 + y2)

# 9. 隐式实现检查
def print_any[T: Printable](item: T):
    print(item.show())

# 使用示例
def main():
    # 使用 Option
    let opt1 = Option.Some(42)
    let opt2 = Option.Nothing

    # 如果实现了接口，可以这样调用
    # print_any(opt1)

    # 使用 Point
    let p1 = Point.P(10, 20)
    let p2 = Point.P(5, 15)

    # 如果实现了运算符重载，可以这样
    # let p3 = p1.add(p2)

    print(100)

main()
