# dream-test: dir
# 测试类似 Python 风格的标准库与面向对象 Path、Set 以及内置类型原生 .method()

from path import Path
from collections import Set, OrderedSet, set, ordered_set

def main():
    # 1. 字符串内置原生方法（无需导入，直接 .method()）
    let text = "  hello world  "
    print(text.lstrip())
    print(text.rstrip())
    print(text.strip())
    print(text.upper())
    print(text.lower())
    print("banana".count("an"))
    print("banana".count("z"))
    print("banana".startswith("ban"))
    print("banana".endswith("na"))
    print("banana".find("nan"))
    print("a-b-c".split("-").len())
    print(", ".join(["x", "y", "z"]))

    # 2. bytes 内置原生方法（无需导入，直接 .method()）
    let raw = "abc".encode()
    print(raw.hex())
    print(raw.len())
    print(raw.decode())

    # 3. dict 内置原生方法（无需导入，直接 .method()）
    let d: dict[str, int] = {}
    d.set("key", 100)
    print(d.get("key"))
    print(d.contains("key"))
    print(d.contains("missing"))
    print("key" in d)
    print(d.len())

    # 4. list 内置原生方法（无需导入，直接 .method()）
    let items: list[str] = []
    items.append("apple")
    items.append("banana")
    print(items.len())

    # 5. Path 面向对象 Pythonic 体验
    let p = Path("tmp/sample_pythonic.txt")
    print(p.name())
    print(p.stem())
    print(p.suffix())
    print(p.is_absolute())

    let parent_dir = Path("tmp")
    let child = parent_dir / "sample_child.txt"
    print(child.name())

    p.write_text("Dream Pythonic stdlib")
    print(p.exists())
    print(p.read_text())
    p.unlink()
    print(p.exists())

    # 6. Set / OrderedSet 工厂函数与方法
    let s1 = set(["apple", "banana", "cherry"])
    let s2 = set(["banana", "cherry"])
    print(s1.len())
    print(s2.issubset(s1))
    print(s1.issuperset(s2))
    print(s2.isdisjoint(set(["date"])))

    let os = ordered_set(["x", "y", "z"])
    print(os.first())
    print(len(os.to_list()))

main()

