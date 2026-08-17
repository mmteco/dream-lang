def scale(value: int, multiplier: int = 3) -> int:
    return value * multiplier

def describe(name: str, prefix: str = "item: ", suffix: str = "!") -> str:
    return string_concat(string_concat(prefix, name), suffix)

def combine(first: int, second: int = 10, third: int = 20) -> int:
    return first + second + third

def main():
    print(scale(5))
    print(scale(5, 2))
    print(combine(1))
    print(combine(1, 2))
    print(combine(1, 2, 3))
    print(describe("x"))
    print(describe("y", "> "))
