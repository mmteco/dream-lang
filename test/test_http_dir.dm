# dream-test: dir

from http import get, post, parse_response

def main():
    let invalid = get("")
    print(invalid.status)
    print(invalid.error)
    print(invalid.ok())

    let unsupported = post("ftp://example.com", "payload")
    print(unsupported.status)
    print(unsupported.error)

    let relative = get("example.com")
    print(relative.status)
    print(relative.error)

    let headers: dict[str, str] = {"Accept": "application/json"}
    print(get("ftp://example.com", headers).ok())
    print(post("ftp://example.com", "payload", headers).ok())
    let timeout_error = get("http://example.com", headers, 0)
    print(timeout_error.error)

    let parsed = parse_response("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-Test: yes\r\nX-Test: again\r\n\r\nhello")
    print(parsed.status)
    print(parsed.headers.len())
    print(parsed.headers["content-type"].len())
    print(parsed.headers["content-type"].first())
    print(parsed.headers["x-test"].len())
    print(parsed.headers["x-test"].first())
    print(parsed.header("Content-Type"))
    print(parsed.body)
    print(parsed.ok())

    let malformed = parse_response("NOT-HTTP 200 OK\r\n\r\n")
    print(malformed.status)
    print(malformed.error)
