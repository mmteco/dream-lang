# Dream 标准运算符重载接口

interface Add[T]:
    def add(self, other: T) -> Self

interface RAdd[T, U]:
    def radd(self, other: T) -> U

interface Sub[T]:
    def sub(self, other: T) -> Self

interface RSub[T, U]:
    def rsub(self, other: T) -> U

interface Mul[T]:
    def mul(self, other: T) -> Self

interface RMul[T, U]:
    def rmul(self, other: T) -> U

interface Div[T]:
    def div(self, other: T) -> Self

interface RDiv[T, U]:
    def rdiv(self, other: T) -> U

interface FloorDiv[T]:
    def floordiv(self, other: T) -> Self

interface RFloorDiv[T, U]:
    def rfloordiv(self, other: T) -> U

interface Mod[T]:
    def mod(self, other: T) -> Self

interface RMod[T, U]:
    def rmod(self, other: T) -> U

interface Pow[T]:
    def pow(self, other: T) -> Self

interface RPow[T, U]:
    def rpow(self, other: T) -> U

interface Eq[T]:
    def eq(self, other: T) -> bool

    def neq(self, other: T) -> bool:
        return not self.eq(other)

interface Hash:
    def hash(self) -> int

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

interface RBitAnd[T, U]:
    def rbitand(self, other: T) -> U

interface BitOr[T]:
    def bitor(self, other: T) -> Self

interface RBitOr[T, U]:
    def rbitor(self, other: T) -> U

interface BitXor[T]:
    def bitxor(self, other: T) -> Self

interface RBitXor[T, U]:
    def rbitxor(self, other: T) -> U

interface BitNot:
    def bitnot(self) -> Self

interface Shl[T, U]:
    def shl(self, n: U) -> Self

interface RShl[T, U]:
    def rshl(self, other: T) -> U

interface Shr[T, U]:
    def shr(self, n: U) -> Self

interface RShr[T, U]:
    def rshr(self, other: T) -> U

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
