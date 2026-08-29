# URL 解析与构建标准库

from str import from_int

struct Url:
    scheme: str
    host: str
    port: int
    path: str
    query: str
    fragment: str

def port_number(value: str) -> int:
    if value == "":
        return 0

    let result = 0
    let index = 0
    while index < len(value):
        let code = value[index]
        if code < 48 or code > 57:
            return 0
        result = result * 10 + code - 48
        index = index + 1
    return result

def parse(value: str) -> Url:
    let scheme = ""
    let rest = value
    let scheme_end = string_find(value, "://")
    if scheme_end >= 0:
        scheme = value[:scheme_end]
        rest = value[scheme_end + 3:]

    let fragment = ""
    let fragment_start = string_find(rest, "#")
    if fragment_start >= 0:
        fragment = rest[fragment_start + 1:]
        rest = rest[:fragment_start]

    let query = ""
    let query_start = string_find(rest, "?")
    if query_start >= 0:
        query = rest[query_start + 1:]
        rest = rest[:query_start]

    let authority = rest
    let path = "/"
    let path_start = string_find(rest, "/")
    if path_start >= 0:
        authority = rest[:path_start]
        path = rest[path_start:]

    let host = authority
    let port = 0
    let port_separator = string_find(authority, ":")
    if port_separator >= 0:
        host = authority[:port_separator]
        port = port_number(authority[port_separator + 1:])

    return Url{scheme: scheme, host: host, port: port, path: path, query: query, fragment: fragment}

def build(value: Url) -> str:
    let result = ""
    if value.scheme != "":
        result = value.scheme + "://"
    result = result + value.host
    if value.port > 0:
        result = result + ":" + from_int(value.port)
    if value.path != "":
        if value.path[0] == '/':
            result = result + value.path
        else:
            result = result + "/" + value.path
    if value.query != "":
        result = result + "?" + value.query
    if value.fragment != "":
        result = result + "#" + value.fragment
    return result

def is_unreserved(value: int) -> bool:
    return (value >= 48 and value <= 57) or (value >= 65 and value <= 90) or (value >= 97 and value <= 122) or value == 45 or value == 46 or value == 95 or value == 126

def hex_digit(value: int) -> str:
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

def quote(value: str) -> str:
    let result = ""
    let index = 0
    while index < len(value):
        let current = value[index]
        if is_unreserved(current):
            result = result + value[index:index + 1]
        elif current < 128:
            result = result + "%" + hex_digit(current / 16) + hex_digit(current % 16)
        else:
            result = result + value[index:index + 1]
        index = index + 1
    return result
