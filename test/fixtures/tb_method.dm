# 回归 fixture:点号方法调用语法 buf.append_bytes(...)(曾与接口分发一同丢失)
# 预期输出:hi
# 背景: docs/STRUCT_FIELD_PIPELINE.md 修复工作项 c)
from text_buffer import TextBuffer

def main() -> int:
    let buf = TextBuffer{data: []}
    buf.append_bytes("hi")
    print(buf.to_str())
    return 0
