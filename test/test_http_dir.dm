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

    let parsed = parse_response("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-Test: yes\r\n\r\nhello")
    print(parsed.status)
    print(len(parsed.headers))
    print(parsed.headers[0])
    print(parsed.headers[1])
    print(parsed.headers[2])
    print(parsed.headers[3])
    print(parsed.header("Content-Type"))
    print(parsed.body)
    print(parsed.ok())
