enum Pair:
    Values(int, int)
    Empty

let pair = Pair.Values(20, 22)
let total = match pair:
    Pair.Values(first, second): first + second
    Pair.Empty: 0
print(total)
