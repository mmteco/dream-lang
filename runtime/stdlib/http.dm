# HTTP/1.1 客户端标准库

from str import from_int

struct Response:
    status: int
    headers: list[str]
    body: str
    error: str

    def ok(self) -> bool:
        return self.error == "" and self.status >= 200 and self.status < 300

    def header(self, name: str) -> str:
        let index = 0
        while index + 1 < len(self.headers):
            if self.headers[index] == name:
                return self.headers[index + 1]
            index = index + 2
        return ""

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

def response_error(message: str) -> Response:
    let headers: list[str] = []
    return Response{status: 0, headers: headers, body: "", error: message}

def header_text(headers: list[str]) -> str:
    let result = ""
    let index = 0
    while index + 1 < len(headers):
        result = result + headers[index] + ": " + headers[index + 1] + "\r\n"
        index = index + 2
    return result

def request_headers(headers: list[str], body: str) -> str:
    let result = header_text(headers)
    if body != "":
        result = result + "Content-Length: " + from_int(len(__c_str_to_bytes(body))) + "\r\n"
    return result

def parse_status(line: str) -> int:
    let first_space = string_find(line, " ")
    if first_space < 0:
        return 0
    let remainder = line[first_space + 1:]
    let second_space = string_find(remainder, " ")
    if second_space < 0:
        return decimal(remainder)
    return decimal(remainder[:second_space])

def parse_headers(header_text: str) -> list[str]:
    let lines = string_split(header_text, "\r\n")
    let result: list[str] = []
    let index = 1
    while index < len(lines):
        let line = lines[index]
        let separator = string_find(line, ":")
        if separator > 0:
            append(result, line[:separator])
            append(result, string_strip(line[separator + 1:]))
        index = index + 1
    return result

def parse_response(raw: str) -> Response:
    let header_end = string_find(raw, "\r\n\r\n")
    if header_end < 0:
        return response_error("malformed HTTP response")
    let status_end = string_find(raw, "\r\n")
    if status_end < 0 or status_end > header_end:
        return response_error("missing HTTP status line")
    let status = parse_status(raw[:status_end])
    if status == 0:
        return response_error("invalid HTTP status line")
    let header_text = raw[:header_end]
    let body = raw[header_end + 4:]
    return Response{status: status, headers: parse_headers(header_text), body: body, error: ""}

def is_supported_url(value: str) -> bool:
    let scheme_end = string_find(value, "://")
    if scheme_end < 0:
        return true
    let scheme = value[:scheme_end]
    return scheme == "http" or scheme == "https"

def request(method: str, value: str, headers: list[str], body: str) -> Response:
    if not is_supported_url(value):
        return response_error("only HTTP and HTTPS URLs are supported")
    let raw = __c_http_request(method, value, request_headers(headers, body), body)
    if raw == "":
        return response_error("failed to execute HTTP request")
    let response = parse_response(raw)
    if response.status == 599:
        return response_error(response.body)
    return response

def get(value: str) -> Response:
    let headers: list[str] = []
    return request("GET", value, headers, "")

def post(value: str, body: str) -> Response:
    let headers: list[str] = []
    return request("POST", value, headers, body)
