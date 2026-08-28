# Dream 运算符重载示例
# 展示如何为自定义类型实现运算符

# 从标准库导入运算符接口
from ops import Add, Sub, Mul, Eq, Ord, Neg


# ===== 示例：二维向量类型 =====

struct Vec2:
    x: int
    y: int

# 实现加法运算符
impl Add[Vec2, Vec2] for Vec2:
    def add(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x + other.x, y: self.y + other.y}

# 实现减法运算符
impl Sub[Vec2, Vec2] for Vec2:
    def sub(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x - other.x, y: self.y - other.y}

# 实现标量乘法
impl Mul[int, Vec2] for Vec2:
    def mul(self, scalar: int) -> Vec2:
        return Vec2{x: self.x * scalar, y: self.y * scalar}

# 实现相等性比较
impl Eq[Vec2] for Vec2:
    def eq(self, other: Vec2) -> bool:
        return self.x == other.x and self.y == other.y

# 实现负号
impl Neg[Vec2] for Vec2:
    def neg(self) -> Vec2:
        return Vec2{x: -self.x, y: -self.y}


# ===== 使用示例 =====

def main():
    let v1 = Vec2{x: 10, y: 20}
    let v2 = Vec2{x: 5, y: 15}

    # 运算符自动调用接口方法
    let v3 = v1 + v2      # 等价于 v1.add(v2)
    print(v3.x)           # 15
    print(v3.y)           # 35

    let v4 = v1 - v2      # 等价于 v1.sub(v2)
    print(v4.x)           # 5
    print(v4.y)           # 5

    let v5 = v1 * 3       # 等价于 v1.mul(3)
    print(v5.x)           # 30
    print(v5.y)           # 60

    let v6 = -v1          # 等价于 v1.neg()
    print(v6.x)           # -10
    print(v6.y)           # -20

    # 比较运算符
    if v1 == v2:          # 等价于 v1.eq(v2)
        print("Equal")
    else:
        print("Not equal")  # 输出这个

main()
