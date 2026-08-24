# 回归 fixture:本地(同文件)interface + impl + 接口调用,作为 iface.dm 的对照组
# 预期输出:2 / 42 / 7
# 背景: docs/STRUCT_FIELD_PIPELINE.md "本地 impl 正常,跨模块分发失效"
interface Append[T]:
    def append(self, value: T)

struct Box:
    data: list[int]

impl Append[int] for Box:
    def append(self, value: int):
        append(self.data, value)

def main() -> int:
    let box = Box{data: []}
    append(box, 42)
    append(box, 7)
    print(len(box.data))
    print(box.data[0])
    print(box.data[1])
    return 0
