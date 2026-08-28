# dream-test: smoke
# 语法综合导览：覆盖 Dream 语言的主要语法特性，作为宿主与自举回归的覆盖用例。
from bytes import str_to_bytes, bytes_to_str
from file import read_text, write_text

interface Shape:
    def area(self) -> int

struct Rect:
    width: int
    height: int

impl Shape for Rect:
    def area(self) -> int:
        return self.width * self.height

struct Vec2:
    x: int
    y: int

interface Add:
    def add(self, other: Vec2) -> Self

impl Add for Vec2:
    def add(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x + other.x, y: self.y + other.y}

enum Shape2:
    Circle(int, int)
    Rect2(int, int)

interface Describe:
    def describe(self) -> int

enum Traffic:
    Stop
    Go

impl Describe for Traffic:
    def describe(self) -> int:
        return 7

struct Point2:
    x: int
    y: int

def match_type_value(value: int | str) -> int:
    let result = match type of value:
        int: 1
        str: 2
    return result

def list_pattern_sum(values: list[int]) -> int:
    let result = match values:
        [first, second]: first + second
        _: 0
    return result

def struct_pattern_match(p: Point2) -> int:
    let result = match p:
        Point2{x: 1, y: value}: value
        Point2{x: 3, y: value}: value + 10
        _: 0
    return result

def add_default(value: int, extra: int = 5) -> int:
    return value + extra

const BASE: int = 3
const DOUBLE_BASE = 6

let global_counter = 0
let global_message = "shared"

struct Point:
    x: int
    y: int

enum Status:
    Ready(int)
    Failed(str)

enum Simple:
    Red
    Green
    Blue

def identity[T](value: T) -> T:
    return value

def recursive_sum(limit: int) -> int:
    if limit <= 0:
        return 0
    return limit + recursive_sum(limit - 1)

def classify(value: int) -> int:
    if value < 0:
        return -1
    elif value == 0:
        return 0
    else:
        return 1

def divide(left: int, right: int) -> Result[int, str]:
    if right == 0:
        return Err("division by zero")
    return Ok(left / right)

def safe_divide(left: int, right: int) -> Result[int, str]:
    let value = divide(left, right)?
    return Ok(value + 1)

def pair_up(value: int, name: str) -> (int, str):
    return (value * 2, name + "!")

def main():
    # 标量类型与运算
    let integer = 42
    let float_value = 1.5
    let bool_value = true
    let string_value = "hello"
    let rune_value = 'A'
    let byte_value = b'B'
    print(integer)
    print(integer + 8)
    print(integer - 2)
    print(integer * 2)
    print(integer / 2)
    print(integer % 5)
    print(float_value + 2.0)
    print(float_value * 2.0)
    print(integer > 10)
    print(integer <= 42)
    print(bool_value and false)
    print(bool_value or false)
    print(not bool_value)
    print(-integer)
    print(rune_value)
    print(byte_value)
    print(ord(rune_value))
    print(ord('中'))

    # 常量与类型注解
    print(BASE)
    print(DOUBLE_BASE)
    let annotated: int = 7
    print(annotated)

    # 全局变量：函数内读写
    print(global_counter)
    global_counter = global_counter + 1
    print(global_counter)
    print(global_message)

    # 函数与递归
    print(recursive_sum(5))
    print(classify(-5))
    print(classify(0))
    print(classify(5))
    print(identity(100))
    print(identity("generic"))

    # 三元与 if 表达式
    let ternary = integer > 10 ? 1 : 0
    print(ternary)
    let if_expression = if integer > 10: 2 else: 3
    print(if_expression)

    # 控制流
    let total = 0
    let index = 0
    while index < 4:
        total = total + index
        index = index + 1
    print(total)

    let numbers: list[int] = [1, 2, 3, 4, 5]
    let loop_sum = 0
    for value in numbers:
        loop_sum = loop_sum + value
    print(loop_sum)

    switch integer:
        case 1:
            print(10)
        case 42:
            print(20)
        default:
            print(30)

    switch "world":
        case "hello":
            print(1)
        case "world":
            print(2)
        default:
            print(3)

    let switch_bool = false
    switch switch_bool:
        case true:
            print(1)
        case false:
            print(2)
        default:
            print(3)

    # match：整数、字符串、布尔、守卫、通配符
    let matched = match integer:
        42: 100
        _: 0
    print(matched)

    let string_match = match string_value:
        "hello": 1
        _: 0
    print(string_match)

    let bool_match = match bool_value:
        true: 1
        false: 0
    print(bool_match)

    let guarded = match integer:
        value if value > 50: 1
        value if value > 40: 2
        _: 3
    print(guarded)

    # 列表：推导式、切片、索引赋值
    let squared = [value * value for value in numbers if value > 2]
    print(len(squared))
    print(squared[0])
    print(squared[1])
    let slice = numbers[1:3]
    print(len(slice))
    print(slice[0])
    numbers[0] = 10
    print(numbers[0])

    # 元组
    let pair = (BASE, DOUBLE_BASE)
    let (left, right) = pair
    print(left)
    print(right)
    print(pair[0])
    print(pair[1])

    # 字典
    let dictionary = {1: 10, 2: 20}
    dictionary[3] = 30
    print(dictionary[1])
    print(dictionary[3])
    print(len(dictionary))

    # dict_items：list[tuple] 与 for 元组解包
    let entries = dict_items(dictionary)
    print(len(entries))
    for (key, value) in dict_items(dictionary):
        print(key + value)

    # 结构体
    let point: Point = Point{x: 2, y: 5}
    print(point.x)
    print(point.y)

    # 枚举
    let status = Status.Ready(42)
    let status_value = match status:
        Status.Ready(value) if value > 40: value
        Status.Ready(value): value + 1
        Status.Failed(_): -1
    print(status_value)

    let failed_status = Status.Failed("boom")
    let failed_value = match failed_status:
        Status.Ready(value): value
        Status.Failed(message): 0
    print(failed_value)

    let color = Simple.Green
    let color_value = match color:
        Simple.Red: 1
        Simple.Green: 2
        Simple.Blue: 3
    print(color_value)

    # Option 与 Result
    let optional = Some(7)
    let optional_value = match optional:
        Some(value): value
        None: 0
    print(optional_value)

    let none_value = match None:
        Some(value): value
        None: 0
    print(none_value)

    let ok = safe_divide(20, 4)
    let ok_value = match ok:
        Ok(value): value
        Err(_): -1
    print(ok_value)

    let err = safe_divide(20, 0)
    let err_value = match err:
        Ok(value): value
        Err(_): -1
    print(err_value)

    # 字符串操作
    let text = "Hello World"
    print(text.length())
    print(text[0])
    print(text[0:5])
    print(text.lower())
    print(text.upper())
    print(text.find("World"))
    print(text.replace("World", "Dream"))
    print(text.starts_with("Hello"))
    print(text.ends_with("World"))
    let joined = string_value + " world"
    print(joined)
    print("a" == "a")
    print("a" < "b")
    print(text.strip())
    print(text.strip().length())
    print(text.is_digit(0))
    print(text.is_alpha(0))
    print(text.is_whitespace(0))
    let pieces = text.split(" ")
    print(len(pieces))
    print(pieces[0])
    print(pieces[1])
    print("-".join(pieces))

    # bytes
    let encoded = str_to_bytes("abc")
    print(encoded[0])
    print(encoded[1])
    print(bytes_to_str(encoded[0:2]))

    # lambda 与闭包
    let closure = lambda (value: int) -> value + 1
    print(closure(1))
    let captured = 5
    let capture_closure = lambda (value: int) -> value + captured
    print(capture_closure(1))

    # 函数值
    let function_value = classify
    print(function_value(10))

    # 混合类型元组：字面量、索引、解包、函数返回、嵌套
    let mixed = (1, "hello", 2.5, true)
    print(mixed[0])
    print(mixed[1])
    print(mixed[2])
    print(mixed[3])
    let (number, text, ratio, flag) = mixed
    print(number + 1)
    print(text)
    print(ratio)
    print(flag)
    print(pair_up(21, "hi")[0])
    print(pair_up(21, "hi")[1])
    let nested = ((1, "a"), (2.5, false))
    print(nested[0][1])
    print(nested[1][0])

    # tuple 作为 match scrutinee（常量元素与变量绑定）
    let tuple_match = match mixed:
        (1, "hello", 2.5, true): 100
        (0, other, 1.0, false): 200
        _: 0
    print(tuple_match)
    let tuple_bind = match nested:
        ((1, "a"), (2.5, false)): 2
        _: 0
    print(tuple_bind)

    # union 类型
    let union_value: int | str = 42
    let union_string: int | str = "text"
    let union_result = match union_value:
        42: 1
        _: 0
    print(union_result)
    let union_string_result = match union_string:
        "text": 2
        _: 0
    print(union_string_result)
    let union_float_value: int | float = 3.5
    let union_float_result = match union_float_value:
        3.5: 3
        _: 0
    print(union_float_result)
    let union_bool_value: bool | int = true
    let union_bool_result = match union_bool_value:
        true: 4
        false: 0
    print(union_bool_result)

    # Python 运算符：整除/幂/位运算/一元
    print(7 // 2)
    print(-7 // 2)
    print(2 ** 5)
    print(2.5 ** 2.0)
    print(7.0 // 2.0)
    print(5 & 3)
    print(5 | 3)
    print(5 ^ 3)
    print(~5)
    print(1 << 4)
    print(64 >> 3)
    print(+5)

    # interface/impl、运算符重载、match type of、模式匹配、文件 I/O、默认参数、嵌套 match、dict 字符串键
    let rect = Rect{width: 3, height: 4}
    print(rect.area())
    let vec1 = Vec2{x: 1, y: 2}
    let vec2 = Vec2{x: 3, y: 4}
    print((vec1 + vec2).x)
    print(match_type_value(42))
    print(match_type_value("text"))
    print(list_pattern_sum([10, 20]))
    print(list_pattern_sum([1]))
    print(struct_pattern_match(Point2{x: 1, y: 7}))
    print(struct_pattern_match(Point2{x: 3, y: 4}))
    let circle = Shape2.Circle(1, 2)
    let circle_area = match circle:
        Shape2.Circle(radius, center): radius + center
        Shape2.Rect2(w, h): w * h
    print(circle_area)
    let concat_list = [1, 2] + [3, 4]
    print(len(concat_list))
    print(concat_list[0])
    let name_dict: dict[str, int] = {"one": 1, "two": 2}
    print(name_dict["one"])
    print(name_dict["two"])
    let nested_value = 5
    let nested_result = match nested_value:
        5: match nested_value:
            5: 100
            _: 0
        _: 0
    print(nested_result)
    print(add_default(10))
    print(add_default(10, 20))
    write_text("/tmp/dream_tour_io.txt", "tour io")
    print(read_text("/tmp/dream_tour_io.txt"))
    let shape_value: Shape = Rect{width: 5, height: 6}
    print(shape_value.area())

    # enum 实现接口（无载荷枚举作为接口具体类型）
    let traffic: Describe = Traffic.Go
    print(traffic.describe())

    # 接口值类型 tag：match type of 按具体类型分发
    let traffic_kind = match type of traffic:
        Traffic: 1
        _: 0
    print(traffic_kind)
    let shape_kind = match type of shape_value:
        Rect: 2
        _: 0
    print(shape_kind)

main()
