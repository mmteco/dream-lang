let numbers = [10, 20]
let exact_result = match numbers:
    [first, second]: first + second
    _: 0
print(exact_result)

let empty_result = match numbers:
    []: 1
    _: 0
print(empty_result)

let cons_result = match numbers:
    head :: tail: head + len(tail)
    _: 0
print(cons_result)
