def identity[T](value: T) -> T:
    return value

print(identity(41))

def first[T](items: list[T]) -> T:
    return items[0]

print(first([42]))

def apply[T](function: (T) -> T, value: T) -> T:
    return function(value)

let increment = lambda (value: int) -> value + 1
print(apply(increment, 41))

def lookup[T](items: dict[int, T], key: int) -> T:
    return items[key]

print(lookup({1: 42}, 1))
