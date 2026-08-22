# dream-test: dir
# while 与 for 循环的 continue:跳过当次迭代,进入下一轮

def sum_odds(limit: int) -> int:
    let total = 0
    let i = 0
    while i < limit:
        i = i + 1
        if i % 2 == 0:
            continue
        total = total + i
    return total

def main() -> int:
    print(sum_odds(10))
    for x in [1, 2, 3, 4, 5]:
        if x == 3:
            continue
        print(x)
    let kept = 0
    for v in [6, 7, 8]:
        if v == 7:
            continue
        kept = kept + v
    print(kept)
    return 0
