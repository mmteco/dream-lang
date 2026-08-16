# dream-test: dir
# Dream 语言导览：覆盖当前可运行的主要语法。
from bytes import str_to_bytes, bytes_to_str

const BASE: int = 3
const DOUBLE_BASE = 6

struct Point:
    x: int
    y: int

enum Status:
    Ready(int)
    Failed(str)

def increment(value: int) -> int:
    return value + 1

def classify(value: int) -> int:
    if value < 0:
        return -1
    elif value == 0:
        return 0
    else:
        return 1

def sum_until(limit: int) -> int:
    let total = 0
    let index = 0
    while index < limit:
        total = total + index
        index = index + 1
    return total

def divide(left: int, right: int) -> Result[int, str]:
    if right == 0:
        return Err("division by zero")
    return Ok(left / right)

def safe_divide(left: int, right: int) -> Result[int, str]:
    let value = divide(left, right)?
    return Ok(value + 1)

def main():
    let numbers: list[int] = [1, 2, 3, 4]
    let selected = [value for value in numbers if value > 1]
    print(len(selected))
    print(selected[0])

    numbers[0] = 10
    append(numbers, DOUBLE_BASE)
    print(numbers[0])
    print(numbers[4])

    let values = {1: 10, 2: 20}
    values[2] = 25
    print(values[1])
    print(values[2])
    print(len(values))

    let pair = (BASE, DOUBLE_BASE)
    let (left, right) = pair
    print(left + right)

    let p: Point = Point{x: 2, y: 5}
    print(p.x + p.y)
    print(p.x)

    let status = Status.Ready(42)
    let status_value = match status:
        Status.Ready(value) if value > 40: value
        Status.Ready(value): value + 1
        Status.Failed(_): -1
    print(status_value)

    let optional = Some(7)
    let optional_value = match optional:
        Some(value): value
        None: 0
    print(optional_value)

    let result = safe_divide(20, 4)
    let result_value = match result:
        Ok(value): value
        Err(_): -1
    print(result_value)

    let failed = safe_divide(20, 0)
    let failed_value = match failed:
        Ok(value): value
        Err(_): -1
    print(failed_value)

    let switch_value = 2
    switch switch_value:
        case 1:
            print(10)
        case 2:
            print(20)
        default:
            print(30)

    for value in numbers:
        print(value)

    let conditional = p.x > 0 ? 100 : 200
    let selected_by_if = if conditional > 50: conditional else: 0
    print(selected_by_if)
    print(classify(-1))
    print(sum_until(5))
    let function_value = increment
    let closure = lambda (value: int) -> value + 1
    print(function_value(41))
    print(closure(1))

    let encoded = str_to_bytes("abc")
    print(encoded[1])
    print(bytes_to_str(encoded[0:2]))
    let total = 1.5 + 2.0
    print(total)
    print(total >= 3.5)
    print('A')
    print(b'B')

main()
