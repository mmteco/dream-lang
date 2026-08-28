# list[str] ABI 测试：指针元素列表统一为 dynarray_ptr 变体
# 覆盖：空列表 append、字面量、len、索引读/写、C 侧数组（split）、join

from string import split, join

def main():
    let items: list[str] = []
    append(items, "a")
    append(items, "b")
    print(len(items))
    print(items[1])
    items[1] = "c"
    print(items[1])

    let lit = ["x", "y"]
    print(len(lit))
    print(lit[0])

    let parts = split("a,b,c", ",")
    print(len(parts))
    print(parts[0])

    print(join(lit, "-"))

main()
