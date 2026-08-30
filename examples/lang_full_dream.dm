# dream-test: dir
# Dream 语言导览：覆盖自举编译器当前支持的表达式、语句和模式语法。
from bytes import encode, decode
from io import open
from fs import exists, remove_file
from path import join, normalize, basename, dirname, ext, stem
from time import monotonic_ms, elapsed_ms
from http import parse_response
from utf8 import chr, ord
import json

const BASE: int = 3
const DOUBLE_BASE = 6

struct Point:
    x: int
    y: int

enum Status:
    Ready(int)
    Failed(str)
    Idle

let shared_counter = 0
let shared_label = "shared"

def increment(value: int) -> int:
    return value + 1

def identity[T](value: T) -> T:
    return value

def add_default(value: int, extra: int = 5) -> int:
    return value + extra

def pair_values(value: int) -> (int, int):
    return (value, value + 1)

def debug_value(value: int) -> int:
    eprintln(value)
    return value

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
    # 标量、布尔、逻辑、比较、优先级与一元运算
    let bool_value = true
    let false_value = false
    let remainder = 17 % 5
    let positive_remainder = +remainder
    let inverted = not false_value
    let logical_value = bool_value and not false_value or false
    let comparison_value = remainder != 0 and remainder <= 4

    let numbers: list[int] = [1, 2, 3, 4]
    let empty_numbers = []
    let middle_numbers = numbers[1:3]
    let prefix_numbers = numbers[:2]
    let suffix_numbers = numbers[2:]
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
    let named_values = {"one": 1, "two": 2}
    let named_value = named_values["one"]

    let pair = (BASE, DOUBLE_BASE)
    let (left, right) = pair
    print(left + right)

    let p: Point = Point{x: 2, y: 5}
    print(p.x + p.y)
    print(p.x)

    # Match：标量、字符串、布尔、列表、结构体、守卫与通配符
    let integer_match = match remainder:
        2: 1
        _: 0
    let variable_match = match remainder:
        current: current
    let text_match = match "ready":
        "ready": 1
        _: 0
    let bool_match = match bool_value:
        true: 1
        false: 0
    let float_match = match 1.5:
        1.5: 1
        _: 0
    let rune_match = match 'A':
        'A': 1
        _: 0
    let list_match = match numbers:
        [first, second, third, fourth]: first + fourth
        _: 0
    let cons_match = match numbers:
        head :: tail: head + len(tail)
        _: 0
    let struct_match = match p:
        Point{x: left, y: right}: left + right
        _: 0

    let status = Status.Ready(42)
    let status_value = match status:
        Status.Ready(value) if value > 40: value
        Status.Ready(value): value + 1
        Status.Failed(_): -1
        Status.Idle: 0
    print(status_value)
    let idle_status = Status.Idle

    # 全局变量、泛型、默认参数、函数值与元组返回
    shared_counter = shared_counter + 1
    let shared_snapshot = shared_label
    let generic_value = identity(7)
    let default_value = add_default(10)
    let explicit_default_value = add_default(10, 20)
    let returned_pair = pair_values(3)
    let function_value = increment

    # 覆盖项参与语义检查，但不改变示例输出。
    identity(positive_remainder)
    identity(inverted)
    identity(logical_value)
    identity(comparison_value)
    identity(empty_numbers)
    identity(middle_numbers)
    identity(prefix_numbers)
    identity(suffix_numbers)
    identity(named_value)
    identity(integer_match)
    identity(variable_match)
    identity(text_match)
    identity(bool_match)
    identity(float_match)
    identity(rune_match)
    identity(list_match)
    identity(cons_match)
    identity(struct_match)
    identity(idle_status)
    identity(shared_snapshot)
    identity(generic_value)
    identity(default_value)
    identity(explicit_default_value)
    identity(returned_pair)

    let optional = Some(7)
    let no_optional = None
    identity(no_optional)
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
    let closure = lambda (value: int) -> value + 1
    print(function_value(41))
    print(closure(1))

    let encoded = encode("abc")
    print(encoded[1])
    print(decode(encoded[0:2]))
    let total = 1.5 + 2.0
    print(total)
    print(total >= 3.5)
    print('A')
    print(chr(ord('A')))
    print(b'B')

    # 复合赋值
    let compound = 10
    compound += 5
    compound -= 2
    compound *= 3
    compound /= 2
    compound %= 4
    compound //= 2
    compound **= 2
    compound &= 7
    compound |= 8
    compound ^= 3
    compound <<= 1
    compound >>= 2
    print(compound)

    let break_sum = 0
    let break_i = 0
    while break_i < 10:
        if break_i == 4:
            break
        break_sum = break_sum + break_i
        break_i = break_i + 1
    print(break_sum)
    let break_found = 0
    for break_n in [1, 2, 3, 4, 5]:
        if break_n == 3:
            break
        break_found = break_found + break_n
    print(break_found)

    # in、continue 与文件 I/O
    print(2 in numbers)
    print(99 in numbers)
    print("dream" in "dream language")
    print(b'b' in "abc".encode())

    let odd_sum = 0
    for odd_value in [1, 2, 3, 4, 5]:
        if odd_value % 2 == 0:
            continue
        odd_sum = odd_sum + odd_value
    print(odd_sum)

    let io_path = "/tmp/dream_lang_full_io.txt"
    let io_writer = open(io_path, "w")
    let io_write_result = io_writer.write("full dream")
    let io_write_status = match io_write_result:
        Ok(value): value
        Err(_): -1
    print(io_write_status)
    io_writer.close()
    let io_reader = open(io_path)
    print(io_reader.read())
    io_reader.close()
    print(exists(io_path))
    print(remove_file(io_path))

    # 路径、时间、JSON 与 HTTP 响应解析
    print(normalize("a/./b/../c.txt"))
    print(join("/tmp/data", "item.json"))
    print(basename("/tmp/data/item.json"))
    print(dirname("/tmp/data/item.json"))
    print(ext("/tmp/data/item.json"))
    print(stem("/tmp/data/item.json"))

    let start_ms = monotonic_ms()
    print(elapsed_ms(start_ms) >= 0)

    let json_value = json.loads('''{"name":"Dream","items":[1,true,null]}''')
    print(json.dumps(json_value))

    let response = parse_response("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nhello")
    print(response.status)
    print(response.header("Content-Type"))
    print(response.body)

main()
