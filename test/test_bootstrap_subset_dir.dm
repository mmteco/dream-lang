def add(first: int, second: int) -> int:
    return first + second

def clamp(value: int) -> int:
    if value < 2:
        return 1
    elif value < 10:
        return 2
    else:
        return 3

def sum_to(limit: int) -> int:
    let index = 0
    let total = 0
    while index < limit:
        total = total + index
        index = index + 1
    return total

def choose(value: int) -> int:
    switch value:
        case 1:
            return 10
        case 2:
            return 20
        default:
            return 30

def show_text(text: str) -> int:
    print(text)
    return 0

def list_total(values: list[int]) -> int:
    append(values, 4)
    let first_index = 0
    let length = len(values)
    return values[first_index] + length

def main():
    let clamped = clamp(1)
    let total = sum_to(4)
    let selected = choose(2)
    let partial = add(clamped, total)
    let combined = add(partial, selected)
    let arithmetic = add(1 + 2, 3 * 4)
    let nested_call = add(add(1, 2), 3)
    let with_arithmetic = add(combined, arithmetic)
    print(add(with_arithmetic, nested_call))
    let message = "bootstrap"
    let ignored = show_text(message)
    let numbers = []
    append(numbers, 7)
    let ignored_length = list_total(numbers)
