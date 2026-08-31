# HTTP client utilities

from collections import OrderedSet
from utf8 import ord

struct Response:
    status: int
    headers: dict[str, OrderedSet]
    body: str
    error: str

    def ok(self) -> bool:
        return self.error == "" and self.status >= 200 and self.status < 300

    def header(self, name: str) -> str:
        let key = name.lower()
        if key not in self.headers:
            return ""
        let values = self.headers[key]
        if values.len() == 0:
            return ""
        return values.first()

def decimal(value: str) -> int:
    if value == "":
        return 0
    let result = 0
    let index = 0
    while index < value.len():
        let digit = ord(value[index])
        if digit < 48 or digit > 57:
            return 0
        result = result * 10 + digit - 48
        index += 1
    return result

def response_error(message: str) -> Response:
    return Response{status: 0, headers: {}, body: "", error: message}

def parse_status(line: str) -> int:
    if line.len() < 5 or line[:5] != "HTTP/":
        return 0
    let first_space = line.find(" ")
    if first_space < 0 or first_space <= 5:
        return 0
    let remainder = line[first_space + 1:]
    let second_space = remainder.find(" ")
    let status_text = if second_space < 0: remainder else: remainder[:second_space]
    if status_text.len() != 3:
        return 0
    return decimal(status_text)

def parse_headers(header_text: str) -> dict[str, OrderedSet]:
    let lines = header_text.split("\r\n")
    let result: dict[str, OrderedSet] = {}
    let index = 1
    while index < len(lines):
        let line = lines[index]
        let separator = line.find(":")
        if separator > 0:
            let name = line[:separator].strip().lower()
            let value = line[separator + 1:].strip()
            if name in result:
                result[name].add(value)
            else:
                result[name] = OrderedSet().add(value)
        index += 1
    return result

def parse_response(raw: str) -> Response:
    let header_end = raw.find("\r\n\r\n")
    if header_end < 0:
        return response_error("malformed HTTP response")
    let status_end = raw.find("\r\n")
    if status_end < 0 or status_end > header_end:
        return response_error("missing HTTP status line")
    let status = parse_status(raw[:status_end])
    if status == 0:
        return response_error("invalid HTTP status line")
    let header_text = raw[:header_end]
    let body = raw[header_end + 4:]
    return Response{status: status, headers: parse_headers(header_text), body: body, error: ""}

def is_supported_url(url: str) -> bool:
    let scheme_end = url.find("://")
    if scheme_end <= 0:
        return false
    let scheme = url[:scheme_end]
    return scheme == "http" or scheme == "https"

def request(method: str, url: str, headers: dict[str, str] = {}, body: str = "", timeout: int = 30) -> Response:
    if method == "" or url == "":
        return response_error("invalid HTTP method or URL")
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
