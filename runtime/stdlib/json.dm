# JSON values, parsing, and serialization

from ops import Display
from utf8 import ord

enum Json:
    Null
    Bool(bool)
    Number(str)
    String(str)
    Array(list[Json])
    Object(dict[str, Json])
    Error(str)

interface JsonValue:
    def get(self, key: str) -> Json
    def at(self, index: int) -> Json
    def size(self) -> int
    def put(self, key: str, value: Json) -> Json
    def is_error(self) -> bool
    def error(self) -> str
    def is_null(self) -> bool
    def as_str(self) -> str
    def as_num(self) -> str
    def as_bool(self) -> bool
    def dump(self) -> str

struct JsonParser:
    source: str
    index: int
    error: str

    def fail(self, message: str):
        self.error = message
        self.index = -1

    def skip_space(self):
        let length = self.source.len()
        while self.index < length:
            let current = self.source[self.index]
            if current in [' ', '\n', '\r', '\t']:
                self.index = self.index + 1
            else:
                return

    def is_digit(self, value: rune) -> bool:
        let code = ord(value)
        return code >= ord('0') and code <= ord('9')

    def hex_digit(self, value: rune) -> int:
        let code = ord(value)
        if code >= ord('0') and code <= ord('9'):
            return code - ord('0')
        if code >= ord('a') and code <= ord('f'):
            return code - ord('a') + 10
        if code >= ord('A') and code <= ord('F'):
            return code - ord('A') + 10
        return -1

    def read_unicode_escape(self) -> str:
        let length = self.source.len()
        let codepoint = 0
        let digit_index = 0
        while digit_index < 4:
            if self.index >= length:
                self.fail("unterminated unicode escape")
                return ""
            let digit = self.hex_digit(self.source[self.index])
            if digit < 0:
                self.fail("invalid unicode escape")
                return ""
            codepoint = codepoint * 16 + digit
            self.index = self.index + 1
            digit_index += 1

        if codepoint >= 0xD800 and codepoint <= 0xDBFF:
            let escape_prefix = self.source[self.index:self.index + 2]
            if self.index + 5 >= length:
                self.fail("missing unicode surrogate pair")
                return ""
            if escape_prefix != "\\u":
                self.fail("missing unicode surrogate pair")
                return ""
            self.index = self.index + 2
            let low = 0
            let low_index = 0
            while low_index < 4:
                if self.index >= length:
                    self.fail("unterminated unicode surrogate pair")
                    return ""
                let digit = self.hex_digit(self.source[self.index])
                if digit < 0:
                    self.fail("invalid unicode surrogate pair")
                    return ""
                low = low * 16 + digit
                self.index = self.index + 1
                low_index += 1
            if low < 0xDC00 or low > 0xDFFF:
                self.fail("invalid unicode surrogate pair")
                return ""
            codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
        elif codepoint >= 0xDC00 and codepoint <= 0xDFFF:
            self.fail("unexpected unicode low surrogate")
            return ""

        return __c_utf8_encode_rune(codepoint).decode()

    def parse_string(self) -> str:
        let result = ""
        let length = self.source.len()
        self.index = self.index + 1
        while self.index < length:
            let current = self.source[self.index]
            if current == '"':
                self.index = self.index + 1
                return result
            if ord(current) < 32:
                self.fail("control character in string")
                return ""
            if current != '\\':
                result += self.source[self.index:self.index + 1]
                self.index = self.index + 1
                continue

            if self.index + 1 >= length:
                self.fail("unterminated escape")
                return ""
            let escaped = self.source[self.index + 1]
            if escaped == '"':
                result += "\""
                self.index = self.index + 2
            elif escaped == '\\':
                result += "\\"
                self.index = self.index + 2
            elif escaped == '/':
                result += "/"
                self.index = self.index + 2
            elif escaped == 'b':
                result += "\b"
                self.index = self.index + 2
            elif escaped == 'f':
                result += "\f"
                self.index = self.index + 2
            elif escaped == 'n':
                result += "\n"
                self.index = self.index + 2
            elif escaped == 'r':
                result += "\r"
                self.index = self.index + 2
            elif escaped == 't':
                result += "\t"
                self.index = self.index + 2
            elif escaped == 'u':
                self.index = self.index + 2
                let unicode_text = self.read_unicode_escape()
                if self.index < 0:
                    return ""
                result += unicode_text
            else:
                self.fail("invalid string escape")
                return ""
        self.fail("unterminated string")
        return ""

    def parse_number(self) -> Json:
        let start = self.index
        let length = self.source.len()
        if self.source[self.index] == '-':
            self.index = self.index + 1
        if self.index >= length:
            self.fail("invalid number")
            return Json.Error(self.error)

        if self.source[self.index] == '0':
            self.index = self.index + 1
            if self.index < length and self.is_digit(self.source[self.index]):
                self.fail("leading zero in number")
                return Json.Error(self.error)
        else:
            let integer_start = self.index
            while self.index < length and self.is_digit(self.source[self.index]):
                self.index = self.index + 1
            if self.index == integer_start:
                self.fail("invalid number")
                return Json.Error(self.error)

        if self.index < length and self.source[self.index] == '.':
            self.index = self.index + 1
            let fraction_start = self.index
            while self.index < length and self.is_digit(self.source[self.index]):
                self.index = self.index + 1
            if self.index == fraction_start:
                self.fail("invalid number fraction")
                return Json.Error(self.error)

        if self.index < length and self.source[self.index] in ['e', 'E']:
            self.index = self.index + 1
            if self.index < length and self.source[self.index] in ['+', '-']:
                self.index = self.index + 1
            let exponent_start = self.index
            while self.index < length and self.is_digit(self.source[self.index]):
                self.index = self.index + 1
            if self.index == exponent_start:
                self.fail("invalid number exponent")
                return Json.Error(self.error)

        return Json.Number(self.source[start:self.index])

    def parse_value(self) -> Json:
        self.skip_space()
        let length = self.source.len()
        if self.index < 0 or self.index >= length:
            self.fail("unexpected end of JSON")
            return Json.Error(self.error)

        let current = self.source[self.index]
        if current == '"':
            let text = self.parse_string()
            if self.index < 0:
                return Json.Error(self.error)
            return Json.String(text)
        if current == '[':
            return self.parse_array()
        if current == '{':
            return self.parse_object()
        if current == '-' or self.is_digit(current):
            return self.parse_number()
        if self.index + 4 <= length and self.source[self.index:self.index + 4] == "true":
            self.index = self.index + 4
            return Json.Bool(true)
        if self.index + 5 <= length and self.source[self.index:self.index + 5] == "false":
            self.index = self.index + 5
            return Json.Bool(false)
        if self.index + 4 <= length and self.source[self.index:self.index + 4] == "null":
            self.index = self.index + 4
            return Json.Null
        self.fail("unexpected JSON value")
        return Json.Error(self.error)

    def parse_array(self) -> Json:
        self.index = self.index + 1
        self.skip_space()
        let values: list[Json] = []
        let length = self.source.len()
        if self.index < length and self.source[self.index] == ']':
            self.index = self.index + 1
            return Json.Array(values)

        while self.index < length:
            let value = self.parse_value()
            if self.index < 0:
                return Json.Error(self.error)
            append(values, value)
            self.skip_space()
            if self.index >= length:
                self.fail("unterminated array")
                return Json.Error(self.error)
            if self.source[self.index] == ']':
                self.index = self.index + 1
                return Json.Array(values)
            if self.source[self.index] != ',':
                self.fail("expected comma in array")
                return Json.Error(self.error)
            self.index = self.index + 1
            self.skip_space()
            if self.index >= length or self.source[self.index] == ']':
                self.fail("trailing comma in array")
                return Json.Error(self.error)
        self.fail("unterminated array")
        return Json.Error(self.error)

    def parse_object(self) -> Json:
        self.index = self.index + 1
        self.skip_space()
        let entries: dict[str, Json] = {}
        let length = self.source.len()
        if self.index < length and self.source[self.index] == '}':
            self.index = self.index + 1
            return Json.Object(entries)

        while self.index < length:
            if self.source[self.index] != '"':
                self.fail("object key must be a string")
                return Json.Error(self.error)
            let key = self.parse_string()
            if self.index < 0:
                return Json.Error(self.error)
            self.skip_space()
            if self.index >= length or self.source[self.index] != ':':
                self.fail("expected colon in object")
                return Json.Error(self.error)
            self.index = self.index + 1
            let value = self.parse_value()
            if self.index < 0:
                return Json.Error(self.error)
            entries[key] = value
            self.skip_space()
            if self.index >= length:
                self.fail("unterminated object")
                return Json.Error(self.error)
            if self.source[self.index] == '}':
                self.index = self.index + 1
                return Json.Object(entries)
            if self.source[self.index] != ',':
                self.fail("expected comma in object")
                return Json.Error(self.error)
            self.index = self.index + 1
            self.skip_space()
            if self.index >= length or self.source[self.index] == '}':
                self.fail("trailing comma in object")
                return Json.Error(self.error)
        self.fail("unterminated object")
        return Json.Error(self.error)

def loads(source: str) -> Json:
    let parser = JsonParser{source: source, index: 0, error: ""}
    parser.skip_space()
    if parser.index >= source.len():
        parser.fail("empty JSON input")
        return Json.Error(parser.error)
    let value = parser.parse_value()
    if parser.index < 0:
        return Json.Error(parser.error)
    parser.skip_space()
    if parser.index != source.len():
        parser.fail("trailing JSON data")
        return Json.Error(parser.error)
    return value

def empty_array() -> Json:
    let values: list[Json] = []
    return Json.Array(values)

def empty_object() -> Json:
    let entries: dict[str, Json] = {}
    return Json.Object(entries)

def escape_hex_digit(value: int) -> str:
    if value < 0 or value > 15:
        return "0"
    return "0123456789ABCDEF"[value:value + 1]

def escape(value: str) -> str:
    let result = ""
    let index = 0
    while index < value.len():
        let current = value[index]
        let code = ord(current)
        if current == '"':
            result += "\\\""
        elif current == '\\':
            result += "\\\\"
        elif code == 8:
            result += "\\b"
        elif code == 12:
            result += "\\f"
        elif current == '\n':
            result += "\\n"
        elif current == '\r':
            result += "\\r"
        elif current == '\t':
            result += "\\t"
        elif code < 32:
            result += "\\u00"
            result += escape_hex_digit(code / 16)
            result += escape_hex_digit(code % 16)
        else:
            result += value[index:index + 1]
        index += 1
    return result

def encode_array(values: list[Json]) -> str:
    let result = "["
    let index = 0
    while index < len(values):
        if index > 0:
            result += ","
        result += dumps(values[index])
        index += 1
    return result + "]"

def encode_object(entries: dict[str, Json]) -> str:
    let result = "{"
    let items = dict_items(entries)
    let index = 0
    while index < len(items):
        if index > 0:
            result += ","
        let pair = items[index]
        result += "\""
        result += escape(pair[0])
        result += "\":"
        result += dumps(pair[1])
        index += 1
    return result + "}"

def dumps(value: Json) -> str:
    return match value:
        Json.Null: "null"
        Json.Bool(flag): str(flag)
        Json.Number(number): number
        Json.String(text): "\"" + escape(text) + "\""
        Json.Array(values): encode_array(values)
        Json.Object(entries): encode_object(entries)
        Json.Error(_): "null"

def parse(text: str) -> Json:
    return loads(text)

def load_file(path: str) -> Json:
    if not __c_file_exists(path):
        return Json.Error("file not found: " + path)
    let text = __c_file_read(path)
    return loads(text)

def dump_file(path: str, value: Json) -> bool:
    let text = dumps(value)
    let written = __c_file_write(path, text)
    return written >= 0


impl JsonValue for Json:
    def get(self, key: str) -> Json:
        return match self:
            Json.Object(entries):
                if key in entries: entries[key] else: Json.Null
            _: Json.Null

    def at(self, index: int) -> Json:
        return match self:
            Json.Array(values):
                if index < 0 or index >= len(values): Json.Null else: values[index]
            _: Json.Null

    def size(self) -> int:
        return match self:
            Json.Array(values): len(values)
            Json.Object(entries): entries.len()
            _: 0

    def put(self, key: str, value: Json) -> Json:
        return match self:
            Json.Object(entries): Json.Object(entries.set(key, value))
            _: Json.Error("object expected")

    def is_error(self) -> bool:
        return match self:
            Json.Error(_): true
            _: false

    def error(self) -> str:
        return match self:
            Json.Error(message): message
            _: ""

    def is_null(self) -> bool:
        return match self:
            Json.Null: true
            _: false

    def as_str(self) -> str:
        return match self:
            Json.String(text): text
            _: ""

    def as_num(self) -> str:
        return match self:
            Json.Number(number): number
            _: ""

    def as_bool(self) -> bool:
        return match self:
            Json.Bool(flag): flag
            _: false

    def dump(self) -> str:
        return dumps(self)

impl Display for Json:
    def to_string(self) -> str:
        return match self:
            Json.Null: "null"
            Json.Bool(flag): str(flag)
            Json.Number(number): number
            Json.String(text): text
            Json.Array(values): encode_array(values)
            Json.Object(entries): encode_object(entries)
            Json.Error(message): message
