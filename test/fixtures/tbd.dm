# 回归 fixture:导入 Buffer + 结构体字面量 + 接口 append + len 字段
# 曾致 stage1 hir 模式确定性 SIGTRAP/SEGV(mfm_alloc 元数据损坏)
# 预期输出:2
# 背景: docs/STRUCT_FIELD_PIPELINE.md 第 6 条
from buffer import Buffer

def main() -> int:
    let buf = Buffer{data: []}
    append(buf, "hi")
    print(len(buf.data))
    return 0
