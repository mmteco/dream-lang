# 回归 fixture:while 内 if/elif/else 多变量重绑定(phi 接线/回边来路)
# 预期输出:9
# 背景: docs/STRUCT_FIELD_PIPELINE.md "重绑定丢失"
def main() -> int:
    let v = 0
    while v < 9:
        if v < 3:
            v = v + 2
        elif v < 6:
            v = v + 3
        else:
            v = v + 1
    print(v)
    return 0
