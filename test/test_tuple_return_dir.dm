# dream-test: dir
def expr_fn(k: int, i: int, xs: list[int]) -> (int, int):
    let a = i + 1
    let b = i * 2 + k
    return (a, b)

def main() -> int:
    let ends = []
    append(ends, 5)
    append(ends, 89)
    let index = 30
    let (ni, vn) = expr_fn(1, index, ends)
    print(ni)
    print(ni - 1)
    print(vn)
    return 0
