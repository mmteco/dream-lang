# 接口系统综合测试

# ===== 测试1: 基本接口定义 =====
print(1)

# 定义一个简单的接口
interface Printable:
    def show() -> string

# 定义一个泛型接口
interface Add[T]:
    def add(other: T) -> T

# 为 int 实现 Add 接口
impl Add[int] for int:
    def add(other: int) -> int:
        return 1 + other

print(42)


# ===== 测试2: impl 块代码生成 =====
print(2)

# 定义接口
interface Multiply[T]:
    def mul(other: T) -> T

# 为 int 实现 Multiply 接口
impl Multiply[int] for int:
    def mul(other: int) -> int:
        return 2 + other

print(43)


# ===== 测试3: 隐式接口实现（Go 风格 duck typing）=====
print(3)

# 定义一个接口
interface Greeter:
    def greet() -> string

# 定义一个类型（通过函数定义方法）
# 注意：这里没有显式的 impl 声明
def person_greet() -> string:
    return "Hello from Person"

# 定义另一个类型
def robot_greet() -> string:
    return "Beep boop from Robot"

# TODO: 这个例子需要我们先实现类/结构体和方法绑定
# 目前的 Dream 语言还没有类的完整实现
# 先用更简单的方式测试：函数是否满足接口

# 简化版测试：接受 Greeter 接口的函数
# def test_greeter(g: Greeter):
#     print(g.greet())

print(44)


# ===== 测试4: 不完整的 impl 块检测 =====
print(4)

interface FullPrintable:
    def show() -> string
    def debug() -> string

# 不完整的实现 - 缺少 debug 方法
impl FullPrintable for int:
    def show() -> string:
        return "test"

print(45)
