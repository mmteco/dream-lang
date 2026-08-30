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

    let headers: dict[str, str] = {"Accept": "application/json"}
    print(get("ftp://example.com", headers).ok())
    print(post("ftp://example.com", "payload", headers).ok())
    let timeout_error = get("http://example.com", headers, 0)
    print(timeout_error.error)

    let parsed = parse_response("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-Test: yes\r\n\r\nhello")
    print(parsed.status)
    print(len(parsed.headers))
    print(len(parsed.headers["content-type"].values))
    print(parsed.headers["content-type"].values[0])
    print(parsed.headers["x-test"].values[0])
    print(parsed.header("Content-Type"))
    print(parsed.body)
    print(parsed.ok())
