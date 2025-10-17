# 运算符重载测试
#
# 本测试展示：
# 1. 为自定义类型实现运算符重载（加法、取负）
# 2. 泛型接口的定义和实现
#
# 注意：match type of 在泛型函数中的支持目前有限制：
# - 代码生成器会为每个使用的类型生成单独的函数
# - 但泛型函数调用的单态化还未完全实现
# - 在 match type of 分支中访问字段时可能出现类型错误

struct Vec2:
    x: int
    y: int

struct Vec3:
    x: int
    y: int
    z: int

# 定义标准运算符接口（泛型）
interface Add[T]:
    def add(self, other: T) -> T

interface Neg:
    def neg(self) -> Vec2

# 为 Vec2 实现加法运算符
impl Add[Vec2] for Vec2:
    def add(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x + other.x, y: self.y + other.y}

impl Add for Vec3:
    def add(self, other: Vec3 | str) -> Vec3:
        return match type of other:
            Vec3: Vec3{x: self.x + other.x, y: self.y + other.y, z: self.z + other.z}
            str: Vec3{x: 1, y: 2, z: 3}

# 为 Vec2 实现取负运算符
impl Neg for Vec2:
    def neg(self) -> Vec2:
        return Vec2{x: -self.x, y: -self.y}


def main():
    print("=== 运算符重载测试 ===")

    # 测试 Vec2 加法
    print("Vec2 加法:")
    let v1 = Vec2{x: 10, y: 20}
    let v2 = Vec2{x: 5, y: 15}
    let v3 = v1 + v2
    print("(10, 20) + (5, 15) = ")
    print(v3.x)
    print(v3.y)

    # 测试 Vec2 取负
    print("")
    print("Vec2 取负:")
    let v4 = -v1
    print("-(10, 20) = ")
    print(v4.x)
    print(v4.y)

    # 测试 Vec3 加法
    print("")
    print("Vec3 加法:")
    let v5 = Vec3{x: 1, y: 2, z: 3}
    let v6 = Vec3{x: 4, y: 5, z: 6}
    let v7 = v5 + v6
    let v8 = v5 + "hello"
    print("(1, 2, 3) + (4, 5, 6) = ")
    print(v7.x)
    print(v7.y)
    print(v7.z)

    print("(1, 2, 3) + 'hello' = ")
    print(v8.x)
    print(v8.y)
    print(v8.z)

main()
