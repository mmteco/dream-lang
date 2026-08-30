# HTTP client utilities

from collections import OrderedSet

struct Response:
    status: int
    headers: dict[str, OrderedSet]
    body: str
    error: str

    def ok(self) -> bool:
        return self.error == "" and self.status >= 200 and self.status < 300

    def header(self, name: str) -> str:
        let key = __c_str_lower(name)
        if not __c_dict_has_str(self.headers, key):
            return ""
        let values = self.headers[key]
        if len(values.values) == 0:
            return ""
        return values.values[0]

def decimal(value: str) -> int:
    if value == "":
        return 0
    let result = 0
    let index = 0
    while index < len(value):
        let digit = value[index]
        if digit < 48 or digit > 57:
            return 0
        result = result * 10 + digit - 48
        index = index + 1
    return result

def empty_headers() -> dict[str, OrderedSet]:
    return __c_dict_create_str_ptr(8)

def response_error(message: str) -> Response:
    let headers: dict[str, OrderedSet] = empty_headers()
    return Response{status: 0, headers: headers, body: "", error: message}

def parse_status(line: str) -> int:
    let first_space = __c_str_find(line, " ")
    if first_space < 0:
        return 0
    let remainder = line[first_space + 1:]
    let second_space = __c_str_find(remainder, " ")
    if second_space < 0:
        return decimal(remainder)
    return decimal(remainder[:second_space])

def parse_headers(header_text: str) -> dict[str, OrderedSet]:
    let lines = __c_str_split(header_text, "\r\n")
    let result: dict[str, OrderedSet] = empty_headers()
    let index = 1
    while index < len(lines):
        let line = lines[index]
        let separator = __c_str_find(line, ":")
        if separator > 0:
            let name = __c_str_lower(__c_str_strip(line[:separator]))
            let value = __c_str_strip(line[separator + 1:])
            if __c_dict_has_str(result, name):
                result[name].add(value)
            else:
                result[name] = OrderedSet{values: [value]}
        index = index + 1
    return result

def parse_response(raw: str) -> Response:
    let header_end = __c_str_find(raw, "\r\n\r\n")
    if header_end < 0:
        return response_error("malformed HTTP response")
    let status_end = __c_str_find(raw, "\r\n")
    if status_end < 0 or status_end > header_end:
        return response_error("missing HTTP status line")
    let status = parse_status(raw[:status_end])
    if status == 0:
        return response_error("invalid HTTP status line")
    let header_text = raw[:header_end]
    let body = raw[header_end + 4:]
    return Response{status: status, headers: parse_headers(header_text), body: body, error: ""}

def is_supported_url(url: str) -> bool:
    let scheme_end = __c_str_find(url, "://")
    if scheme_end < 0:
        return true
    let scheme = url[:scheme_end]
    return scheme == "http" or scheme == "https"

def request(method: str, url: str, headers: dict[str, str] = {}, body: str = "", timeout: int = 30) -> Response:
    if not is_supported_url(url):
        return response_error("only HTTP and HTTPS URLs are supported")
    let raw = __c_http_request(method, url, headers, body, timeout)
    if raw == "":
        return response_error("failed to execute HTTP request")
    let response = parse_response(raw)
    if response.status == 599:
        return response_error(response.body)
    return response

def get(url: str, headers: dict[str, str] = {}, timeout: int = 30) -> Response:
    return request("GET", url, headers, "", timeout)

def post(url: str, body: str = "", headers: dict[str, str] = {}, timeout: int = 30) -> Response:
    return request("POST", url, headers, body, timeout)
