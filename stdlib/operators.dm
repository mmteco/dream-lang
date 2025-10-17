# Dream 标准运算符重载接口
#
# 提供常用的运算符重载接口定义，用户可以为自定义类型实现这些接口
# 从而支持使用对应的运算符语法

# ===== 算术运算符 =====

# 加法运算符 +
# T: 参数类型, R: 返回类型
interface Add[T, R]:
    def add(self, other: T) -> R

# 减法运算符 -
# T: 参数类型, R: 返回类型
interface Sub[T, R]:
    def sub(self, other: T) -> R

# 乘法运算符 *
# T: 参数类型, R: 返回类型
interface Mul[T, R]:
    def mul(self, other: T) -> R

# 除法运算符 /
# T: 参数类型, R: 返回类型
interface Div[T, R]:
    def div(self, other: T) -> R

# 取模运算符 %
# T: 参数类型, R: 返回类型
interface Mod[T, R]:
    def mod(self, other: T) -> R


# ===== 比较运算符 =====

# 相等性比较 == 和 !=
interface Eq[T]:
    def eq(self, other: T) -> bool

    # 默认实现：不等于
    def neq(self, other: T) -> bool:
        return not self.eq(other)

# 顺序比较 <, >, <=, >=
# 注意：实现此接口时建议同时实现 Eq 接口
interface Ord[T]:
    def lt(self, other: T) -> bool
    def gt(self, other: T) -> bool

    # 相等性判断（也在 Eq 接口中）
    def eq(self, other: T) -> bool

    # 默认实现：小于等于
    def lte(self, other: T) -> bool:
        return self.lt(other) or self.eq(other)

    # 默认实现：大于等于
    def gte(self, other: T) -> bool:
        return self.gt(other) or self.eq(other)


# ===== 一元运算符 =====

# 取负运算符 - (一元)
# 注意：由于当前不支持 Self 类型，返回类型需要在实现时明确指定
interface Neg[T]:
    def neg(self) -> T

# 取反运算符 not
# 注意：由于 not 是关键字，方法名使用 not_
interface Not:
    def not_(self) -> bool


# ===== 位运算符 =====

# 按位与 &
interface BitAnd[T]:
    def bitand(self, other: T) -> T

# 按位或 |
interface BitOr[T]:
    def bitor(self, other: T) -> T

# 按位异或 ^
interface BitXor[T]:
    def bitxor(self, other: T) -> T

# 按位取反 ~
# 注意：由于当前不支持 Self 类型，返回类型需要在实现时明确指定
interface BitNot[T]:
    def bitnot(self) -> T

# 左移 <<
# 注意：由于当前不支持 Self 类型，返回类型需要在实现时明确指定
interface Shl[T, U]:
    def shl(self, n: U) -> T

# 右移 >>
# 注意：由于当前不支持 Self 类型，返回类型需要在实现时明确指定
interface Shr[T, U]:
    def shr(self, n: U) -> T


# ===== 索引运算符 =====

# 索引访问 []
interface Index[K, V]:
    def index(self, key: K) -> V


# ===== 字符串转换 =====

# 转换为字符串
interface Display:
    def to_string(self) -> str
