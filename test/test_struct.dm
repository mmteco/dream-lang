# 结构体综合测试

# ===== 测试1: 简单方法（无参数，返回常量）=====
print(1)

struct Simple:
    value: int

    def get_constant() -> int:
        return 999

# 创建实例并调用方法
let obj = Simple{value: 10}
let val = obj.get_constant()
print(val)


# ===== 测试2: 方法返回整数（不使用 self）=====
print(2)

struct Counter:
    value: int

    def get() -> int:
        return 42

# 创建实例并调用方法
let counter = Counter{value: 10}
let result = counter.get()
print(result)


# ===== 测试3: 使用 self 参数访问字段 =====
print(3)

struct Point:
    x: int
    y: int

    def get_x(self) -> int:
        return self.x

    def get_y(self) -> int:
        return self.y

# 创建实例并调用方法
let p = Point{x: 100, y: 200}
let px = p.get_x()
let py = p.get_y()
print(px)
print(py)
