# 回归 fixture:元组返回 + 解构 + 列表 append(元组钩子曾被探针清理误删)
# 预期输出:31 / 30 / 61
# 背景: docs/STRUCT_FIELD_PIPELINE.md 第 4 条
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
