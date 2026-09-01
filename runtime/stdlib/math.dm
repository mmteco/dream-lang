# Mathematical constants and functions

const PI: float = 3.141592653589793
const E: float = 2.718281828459045
const TAU: float = 6.283185307179586

def abs(x: int) -> int:
    if x < 0:
        return -x
    return x

def fabs(x: float) -> float:
    if x < 0.0:
        return -x
    return x

def min(a: int, b: int) -> int:
    if a < b:
        return a
    return b

def max(a: int, b: int) -> int:
    if a > b:
        return a
    return b

def fmin(a: float, b: float) -> float:
    if a < b:
        return a
    return b

def fmax(a: float, b: float) -> float:
    if a > b:
        return a
    return b

def clamp(val: int, low: int, high: int) -> int:
    if val < low:
        return low
    if val > high:
        return high
    return val

def fclamp(val: float, low: float, high: float) -> float:
    if val < low:
        return low
    if val > high:
        return high
    return val

def sign(x: int) -> int:
    if x > 0:
        return 1
    if x < 0:
        return -1
    return 0

def fsign(x: float) -> int:
    if x > 0.0:
        return 1
    if x < 0.0:
        return -1
    return 0

def floor(x: float) -> float:
    return x // 1.0

def ceil(x: float) -> float:
    return -((-x) // 1.0)

def round(x: float) -> float:
    if x >= 0.0:
        return (x + 0.5) // 1.0
    return (x - 0.5) // 1.0

def is_even(x: int) -> bool:
    return x % 2 == 0

def is_odd(x: int) -> bool:
    return x % 2 != 0

def pow(base: float, exponent: float) -> float:
    return base ** exponent

def powi(base: int, exponent: int) -> int:
    return base ** exponent
