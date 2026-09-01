# dream-test: dir

from path import Path
from json import loads, load_file, dump_file, Json
from collections import set, ordered_set, counter, Counter
from math import PI, abs, fabs, min, max, clamp, floor, ceil, round, is_even, is_odd, pow, powi
from str import splitlines, zfill, ljust, rjust, center, partition

def main():
    # 1. math
    print(abs(-42))
    print(min(10, 20))
    print(max(10, 20))
    print(clamp(15, 0, 10))
    print(clamp(5, 0, 10))
    print(floor(3.7))
    print(ceil(3.2))
    print(round(3.6))
    print(is_even(42))
    print(is_odd(42))
    print(powi(2, 3))

    # 2. str
    let lines = splitlines("hello\nworld\r\nagain")
    print(len(lines))
    print(lines[0])
    print(lines[1])
    print(lines[2])
    print(zfill("42", 5))
    print(ljust("hi", 5, "."))
    print(rjust("hi", 5, "."))
    print(center("hi", 6, "-"))
    let (head, sep, tail) = partition("user@example.com", "@")
    print(head)
    print(sep)
    print(tail)

    # 3. collections: Set & Counter
    let s = set(["a", "b", "c"])
    let popped = s.pop()
    print(popped)
    print(s.len())
    s.update(set(["d", "e"]))
    print(s.len())
    s.intersection_update(set(["b", "d"]))
    print(s.len())
    print("b" in s.index)
    s.clear()
    print(s.len())

    let c = counter(["apple", "banana", "apple", "orange", "apple", "banana"])
    print(c.get("apple"))
    print(c.get("banana"))
    print(c.get("orange"))
    print(c.get("pear"))
    print(c.total())
    print(c.most_common_key())
    print(c.most_common_count())

    # 4. Path & Json
    let p = Path("tmp/test_enhanced.json")
    let p_renamed = Path("tmp/test_enhanced_renamed.json")
    if p.exists():
        p.unlink()
    if p_renamed.exists():
        p_renamed.unlink()

    let j = loads("{\"title\":\"dream\",\"version\":1}")
    let dump_ok = dump_file(p.raw, j)
    print(dump_ok)
    print(p.exists())
    let loaded = load_file(p.raw)
    print(loaded.get("title").as_str())

    let new_name = p.with_name("test_enhanced_renamed.json")
    print(new_name.name())
    let renamed = p.rename(new_name.raw)
    print(renamed)
    print(p.exists())
    print(p_renamed.exists())
    p_renamed.unlink()
    print(p_renamed.exists())

main()
