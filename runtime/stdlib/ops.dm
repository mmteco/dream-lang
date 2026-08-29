# Dream 标准运算符重载接口

interface Add[T]:
    def add(self, other: T) -> Self

interface Sub[T]:
    def sub(self, other: T) -> Self

interface Mul[T]:
    def mul(self, other: T) -> Self

interface Div[T]:
    def div(self, other: T) -> Self

interface FloorDiv[T]:
    def floordiv(self, other: T) -> Self

interface Mod[T]:
    def mod(self, other: T) -> Self

interface Pow[T]:
    def pow(self, other: T) -> Self

interface Eq[T]:
    def eq(self, other: T) -> bool

    def neq(self, other: T) -> bool:
        return not self.eq(other)

interface Ord[T]:
    def lt(self, other: T) -> bool
    def gt(self, other: T) -> bool
    def eq(self, other: T) -> bool

    def lte(self, other: T) -> bool:
        return self.lt(other) or self.eq(other)

    def gte(self, other: T) -> bool:
        return self.gt(other) or self.eq(other)

interface Neg:
    def neg(self) -> Self

interface Pos:
    def pos(self) -> Self

interface Not:
    def not_(self) -> bool

interface BitAnd[T]:
    def bitand(self, other: T) -> Self

interface BitOr[T]:
    def bitor(self, other: T) -> Self

interface BitXor[T]:
    def bitxor(self, other: T) -> Self

interface BitNot:
    def bitnot(self) -> Self

interface Shl[T, U]:
    def shl(self, n: U) -> Self

interface Shr[T, U]:
    def shr(self, n: U) -> Self

interface Index[K, V]:
    def index(self, key: K) -> V

interface Append[T]:
    def append(self, value: T)

interface Display:
    def to_string(self) -> str

interface Len:
    def length(self) -> int

interface Contains[T]:
    def contains(self, value: T) -> bool
