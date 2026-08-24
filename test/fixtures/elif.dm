# 回归 fixture:if/elif/else 最终 else 体曾被 MIR 互斥降级丢弃(已修复,防复发)
# 预期输出:3
# 背景: docs/STRUCT_FIELD_PIPELINE.md 第 1 条
def main() -> int:
    let v = 10
    if v < 3:
        print(1)
    elif v < 6:
        print(2)
    else:
        print(3)
    return 0
