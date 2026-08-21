# Dream 标准运算符重载接口
#
# 提供常用的运算符重载接口定义，用户可以为自定义类型实现这些接口
# 从而支持使用对应的运算符语法

# ===== 算术运算符 =====

# 加法运算符 +
# T: 参数类型, R: 返回类型
interface Add[T]:
    def add(self, other: T) -> Self

# 减法运算符 -
# T: 参数类型, R: 返回类型
interface Sub[T]:
    def sub(self, other: T) -> Self

# 乘法运算符 *
# T: 参数类型, R: 返回类型
interface Mul[T]:
    def mul(self, other: T) -> Self

# 除法运算符 /
# T: 参数类型, R: 返回类型
interface Div[T]:
    def div(self, other: T) -> Self

# 整除运算符 //
# T: 参数类型, R: 返回类型
interface FloorDiv[T]:
    def floordiv(self, other: T) -> Self

# 取模运算符 %
# T: 参数类型, R: 返回类型
interface Mod[T]:
    def mod(self, other: T) -> Self

# 幂运算符 **
# T: 参数类型, R: 返回类型
interface Pow[T]:
    def pow(self, other: T) -> Self


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
# 返回类型 Self 表示实现该接口的具体类型
interface Neg:
    def neg(self) -> Self

# 取正运算符 + (一元)
interface Pos:
    def pos(self) -> Self

# 取反运算符 not
# 注意：由于 not 是关键字，方法名使用 not_
interface Not:
    def not_(self) -> bool


# ===== 位运算符 =====

# 按位与 &
interface BitAnd[T]:
    def bitand(self, other: T) -> Self

# 按位或 |
interface BitOr[T]:
    def bitor(self, other: T) -> Self

# 按位异或 ^
interface BitXor[T]:
    def bitxor(self, other: T) -> Self

# 按位取反 ~
interface BitNot:
    def bitnot(self) -> Self

# 左移 <<
interface Shl[T, U]:
    def shl(self, n: U) -> Self

# 右移 >>
interface Shr[T, U]:
    def shr(self, n: U) -> Self


# ===== 索引运算符 =====

# 索引访问 []
interface Index[K, V]:
    def index(self, key: K) -> V


# ===== 字符串转换 =====

# 转换为字符串
interface Display:
    def to_string(self) -> str


# ===== 长度 =====

# 获取长度
interface Len:
    def length(self) -> int
