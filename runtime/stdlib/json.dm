# JSON 值、解析和序列化

enum Json:
    Null
    Bool(bool)
    Number(str)
    String(str)
    Array(list[Json])
    Object(list[Json])
    Error(str)

let JSON_SOURCE = ""
let JSON_INDEX = 0
let JSON_ERROR = ""

def json_error(message: str) -> Json:
    JSON_ERROR = message
    JSON_INDEX = -1
    return Json.Error(message)

def json_skip_space():
    let length = len(JSON_SOURCE)
    while JSON_INDEX < length:
        let current = JSON_SOURCE[JSON_INDEX]
        if current == ' ' or current == '\n' or current == '\r' or current == '\t':
            JSON_INDEX = JSON_INDEX + 1
        else:
            return

def json_is_digit(value: rune) -> bool:
    let code = ord(value)
    return code >= ord('0') and code <= ord('9')

def json_hex_digit(value: rune) -> int:
    let code = ord(value)
    if code >= ord('0') and code <= ord('9'):
        return code - ord('0')
    if code >= ord('a') and code <= ord('f'):
        return code - ord('a') + 10
    if code >= ord('A') and code <= ord('F'):
        return code - ord('A') + 10
    return -1

def json_read_unicode_escape() -> str:
    let length = len(JSON_SOURCE)
    let codepoint = 0
    let digit_index = 0
    while digit_index < 4:
        if JSON_INDEX >= length:
            json_error("unterminated unicode escape")
            return ""
        let digit = json_hex_digit(JSON_SOURCE[JSON_INDEX])
        if digit < 0:
            json_error("invalid unicode escape")
            return ""
        codepoint = codepoint * 16 + digit
        JSON_INDEX = JSON_INDEX + 1
        digit_index = digit_index + 1

    if codepoint >= 0xD800 and codepoint <= 0xDBFF:
        if JSON_INDEX + 5 >= length or JSON_SOURCE[JSON_INDEX] != '\\' or JSON_SOURCE[JSON_INDEX + 1] != 'u':
            json_error("missing unicode surrogate pair")
            return ""
        JSON_INDEX = JSON_INDEX + 2
        let low = 0
        let low_index = 0
        while low_index < 4:
            if JSON_INDEX >= length:
                json_error("unterminated unicode surrogate pair")
                return ""
            let digit = json_hex_digit(JSON_SOURCE[JSON_INDEX])
            if digit < 0:
                json_error("invalid unicode surrogate pair")
                return ""
            low = low * 16 + digit
            JSON_INDEX = JSON_INDEX + 1
            low_index = low_index + 1
        if low < 0xDC00 or low > 0xDFFF:
            json_error("invalid unicode surrogate pair")
            return ""
        codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
    elif codepoint >= 0xDC00 and codepoint <= 0xDFFF:
        json_error("unexpected unicode low surrogate")
        return ""

    return __c_bytes_to_str(__c_utf8_encode_rune(codepoint))

def json_parse_string() -> str:
    let result = ""
    let length = len(JSON_SOURCE)
    JSON_INDEX = JSON_INDEX + 1
    while JSON_INDEX < length:
        let current = JSON_SOURCE[JSON_INDEX]
        if current == '"':
            JSON_INDEX = JSON_INDEX + 1
            return result
        if ord(current) < 32:
            json_error("control character in string")
            return ""
        if current != '\\':
            result = result + JSON_SOURCE[JSON_INDEX:JSON_INDEX + 1]
            JSON_INDEX = JSON_INDEX + 1
            continue

        if JSON_INDEX + 1 >= length:
            json_error("unterminated escape")
            return ""
        let escaped = JSON_SOURCE[JSON_INDEX + 1]
        if escaped == '"':
            result = result + "\""
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == '\\':
            result = result + "\\"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == '/':
            result = result + "/"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 'b':
            result = result + "\b"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 'f':
            result = result + "\f"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 'n':
            result = result + "\n"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 'r':
            result = result + "\r"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 't':
            result = result + "\t"
            JSON_INDEX = JSON_INDEX + 2
        elif escaped == 'u':
            JSON_INDEX = JSON_INDEX + 2
            let unicode_text = json_read_unicode_escape()
            if JSON_INDEX < 0:
                return ""
            result = result + unicode_text
        else:
            json_error("invalid string escape")
            return ""
    json_error("unterminated string")
    return ""

def json_parse_number() -> Json:
    let start = JSON_INDEX
    let length = len(JSON_SOURCE)
    if JSON_SOURCE[JSON_INDEX] == '-':
        JSON_INDEX = JSON_INDEX + 1
    if JSON_INDEX >= length:
        return json_error("invalid number")

    if JSON_SOURCE[JSON_INDEX] == '0':
        JSON_INDEX = JSON_INDEX + 1
        if JSON_INDEX < length and json_is_digit(JSON_SOURCE[JSON_INDEX]):
            return json_error("leading zero in number")
    else:
        let integer_start = JSON_INDEX
        while JSON_INDEX < length and json_is_digit(JSON_SOURCE[JSON_INDEX]):
            JSON_INDEX = JSON_INDEX + 1
        if JSON_INDEX == integer_start:
            return json_error("invalid number")

    if JSON_INDEX < length and JSON_SOURCE[JSON_INDEX] == '.':
        JSON_INDEX = JSON_INDEX + 1
        let fraction_start = JSON_INDEX
        while JSON_INDEX < length and json_is_digit(JSON_SOURCE[JSON_INDEX]):
            JSON_INDEX = JSON_INDEX + 1
        if JSON_INDEX == fraction_start:
            return json_error("invalid number fraction")

    if JSON_INDEX < length and (JSON_SOURCE[JSON_INDEX] == 'e' or JSON_SOURCE[JSON_INDEX] == 'E'):
        JSON_INDEX = JSON_INDEX + 1
        if JSON_INDEX < length and (JSON_SOURCE[JSON_INDEX] == '+' or JSON_SOURCE[JSON_INDEX] == '-'):
            JSON_INDEX = JSON_INDEX + 1
        let exponent_start = JSON_INDEX
        while JSON_INDEX < length and json_is_digit(JSON_SOURCE[JSON_INDEX]):
            JSON_INDEX = JSON_INDEX + 1
        if JSON_INDEX == exponent_start:
            return json_error("invalid number exponent")
    return Json.Number(JSON_SOURCE[start:JSON_INDEX])

def json_parse_value() -> Json:
    json_skip_space()
    let length = len(JSON_SOURCE)
    if JSON_INDEX < 0 or JSON_INDEX >= length:
        return json_error("unexpected end of JSON")

    let current = JSON_SOURCE[JSON_INDEX]
    if current == '"':
        let text = json_parse_string()
        if JSON_INDEX < 0:
            return Json.Error(JSON_ERROR)
        return Json.String(text)
    if current == '[':
        return json_parse_array()
    if current == '{':
        return json_parse_object()
    if current == '-' or json_is_digit(current):
        return json_parse_number()
    if JSON_INDEX + 4 <= length and JSON_SOURCE[JSON_INDEX:JSON_INDEX + 4] == "true":
        JSON_INDEX = JSON_INDEX + 4
        return Json.Bool(true)
    if JSON_INDEX + 5 <= length and JSON_SOURCE[JSON_INDEX:JSON_INDEX + 5] == "false":
        JSON_INDEX = JSON_INDEX + 5
        return Json.Bool(false)
    if JSON_INDEX + 4 <= length and JSON_SOURCE[JSON_INDEX:JSON_INDEX + 4] == "null":
        JSON_INDEX = JSON_INDEX + 4
        return Json.Null
    return json_error("unexpected JSON value")

def json_parse_array() -> Json:
    JSON_INDEX = JSON_INDEX + 1
    json_skip_space()
    let values: list[Json] = []
    let length = len(JSON_SOURCE)
    if JSON_INDEX < length and JSON_SOURCE[JSON_INDEX] == ']':
        JSON_INDEX = JSON_INDEX + 1
        return Json.Array(values)

    while JSON_INDEX < length:
        let value = json_parse_value()
        if JSON_INDEX < 0:
            return Json.Error(JSON_ERROR)
        append(values, value)
        json_skip_space()
        if JSON_INDEX >= length:
            return json_error("unterminated array")
        if JSON_SOURCE[JSON_INDEX] == ']':
            JSON_INDEX = JSON_INDEX + 1
            return Json.Array(values)
        if JSON_SOURCE[JSON_INDEX] != ',':
            return json_error("expected comma in array")
        JSON_INDEX = JSON_INDEX + 1
        json_skip_space()
        if JSON_INDEX >= length or JSON_SOURCE[JSON_INDEX] == ']':
            return json_error("trailing comma in array")
    return json_error("unterminated array")

def json_parse_object() -> Json:
    JSON_INDEX = JSON_INDEX + 1
    json_skip_space()
    let entries: list[Json] = []
    let length = len(JSON_SOURCE)
    if JSON_INDEX < length and JSON_SOURCE[JSON_INDEX] == '}':
        JSON_INDEX = JSON_INDEX + 1
        return Json.Object(entries)

    while JSON_INDEX < length:
        if JSON_SOURCE[JSON_INDEX] != '"':
            return json_error("object key must be a string")
        let key = json_parse_string()
        if JSON_INDEX < 0:
            return Json.Error(JSON_ERROR)
        json_skip_space()
        if JSON_INDEX >= length or JSON_SOURCE[JSON_INDEX] != ':':
            return json_error("expected colon in object")
        JSON_INDEX = JSON_INDEX + 1
        let value = json_parse_value()
        if JSON_INDEX < 0:
            return Json.Error(JSON_ERROR)
        append(entries, Json.String(key))
        append(entries, value)
        json_skip_space()
        if JSON_INDEX >= length:
            return json_error("unterminated object")
        if JSON_SOURCE[JSON_INDEX] == '}':
            JSON_INDEX = JSON_INDEX + 1
            return Json.Object(entries)
        if JSON_SOURCE[JSON_INDEX] != ',':
            return json_error("expected comma in object")
        JSON_INDEX = JSON_INDEX + 1
        json_skip_space()
        if JSON_INDEX >= length or JSON_SOURCE[JSON_INDEX] == '}':
            return json_error("trailing comma in object")
    return json_error("unterminated object")

# 解析 JSON 文本；错误以 Json.Error 返回，便于直接匹配或调用 is_error。
def loads(source: str) -> Json:
    JSON_SOURCE = source
    JSON_INDEX = 0
    JSON_ERROR = ""
    json_skip_space()
    if JSON_INDEX >= len(JSON_SOURCE):
        return json_error("empty JSON input")
    let value = json_parse_value()
    if JSON_INDEX < 0:
        return Json.Error(JSON_ERROR)
    json_skip_space()
    if JSON_INDEX != len(JSON_SOURCE):
        return Json.Error("trailing JSON data")
    return value

def is_error(value: Json) -> bool:
    return match value:
        Json.Error(_): true
        _: false

def error(value: Json) -> str:
    return match value:
        Json.Error(message): message
        _: ""

def is_null(value: Json) -> bool:
    return match value:
        Json.Null: true
        _: false

def as_string(value: Json) -> str:
    return match value:
        Json.String(text): text
        _: ""

def as_number(value: Json) -> str:
    return match value:
        Json.Number(number): number
        _: ""

def as_bool(value: Json) -> bool:
    return match value:
        Json.Bool(flag): flag
        _: false

def json_object_get(entries: list[Json], key: str) -> Json:
    let result = Json.Null
    let index = 0
    while index + 1 < len(entries):
        if as_string(entries[index]) == key:
            result = entries[index + 1]
        index = index + 2
    return result

def field(value: Json, key: str) -> Json:
    return match value:
        Json.Object(entries): json_object_get(entries, key)
        _: Json.Null

def json_array_at(values: list[Json], index: int) -> Json:
    if index < 0 or index >= len(values):
        return Json.Null
    return values[index]

def at(value: Json, index: int) -> Json:
    return match value:
        Json.Array(values): json_array_at(values, index)
        _: Json.Null

def size(value: Json) -> int:
    return match value:
        Json.Array(values): len(values)
        Json.Object(entries): len(entries) / 2
        _: 0

def empty_array() -> Json:
    let values: list[Json] = []
    return Json.Array(values)

def empty_object() -> Json:
    let entries: list[Json] = []
    return Json.Object(entries)

def json_object_put_entries(entries: list[Json], key: str, item: Json) -> list[Json]:
    let result: list[Json] = []
    let index = 0
    while index + 1 < len(entries):
        if as_string(entries[index]) != key:
            append(result, entries[index])
            append(result, entries[index + 1])
        index = index + 2
    append(result, Json.String(key))
    append(result, item)
    return result

# 返回更新后的对象；同名键按 Python 字典语义覆盖旧值。
def put(value: Json, key: str, item: Json) -> Json:
    return match value:
        Json.Object(entries): Json.Object(json_object_put_entries(entries, key, item))
        _: Json.Error("object expected")

def json_escape_hex_digit(value: int) -> str:
    return match value:
        0: "0"
        1: "1"
        2: "2"
        3: "3"
        4: "4"
        5: "5"
        6: "6"
        7: "7"
        8: "8"
        9: "9"
        10: "A"
        11: "B"
        12: "C"
        13: "D"
        14: "E"
        15: "F"
        _: "0"

def json_escape(value: str) -> str:
    let result = ""
    let index = 0
    while index < len(value):
        let current = value[index]
        let code = ord(current)
        if current == '"':
            result = result + "\\\""
        elif current == '\\':
            result = result + "\\\\"
        elif code == 8:
            result = result + "\\b"
        elif code == 12:
            result = result + "\\f"
        elif current == '\n':
            result = result + "\\n"
        elif current == '\r':
            result = result + "\\r"
        elif current == '\t':
            result = result + "\\t"
        elif code < 32:
            result = result + "\\u00" + json_escape_hex_digit(code / 16) + json_escape_hex_digit(code % 16)
        else:
            result = result + value[index:index + 1]
        index = index + 1
    return result

def json_dumps_array(values: list[Json]) -> str:
    let result = "["
    let index = 0
    while index < len(values):
        if index > 0:
            result = result + ","
        result = result + json_dumps(values[index])
        index = index + 1
    return result + "]"

def json_dumps_object(entries: list[Json]) -> str:
    let result = "{"
    let index = 0
    while index + 1 < len(entries):
        if index > 0:
            result = result + ","
        result = result + "\"" + json_escape(as_string(entries[index])) + "\":"
        result = result + json_dumps(entries[index + 1])
        index = index + 2
    return result + "}"

def json_dumps(value: Json) -> str:
    return match value:
        Json.Null: "null"
        Json.Bool(flag): if flag: "true" else: "false"
        Json.Number(number): number
        Json.String(text): "\"" + json_escape(text) + "\""
        Json.Array(values): json_dumps_array(values)
        Json.Object(entries): json_dumps_object(entries)
        Json.Error(_): "null"

# 将 Json 值序列化为紧凑 JSON 文本。
def dumps(value: Json) -> str:
    return json_dumps(value)
