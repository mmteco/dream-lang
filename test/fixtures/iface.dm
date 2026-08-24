# 回归 fixture:接口 append 写入 list[byte] 字段(跨层槽宽/分发审计用例)
# 预期输出:1
# 背景: docs/STRUCT_FIELD_PIPELINE.md 接口分发定性
struct Box:
    data: list[byte]

impl Append[int] for Box:
    def append(self, value: int):
        append(self.data, value)

def main() -> int:
    let box = Box{data: []}
    append(box, 65)
    print(len(box.data))
    return 0
