struct Point:
    x: int
    y: int

def make_point(x: int, y: int) -> Point:
    return Point{x: x, y: y}

def main():
    let point: Point = make_point(1, 2)
    let result = match point:
        Point{x: left, y: right}: left + right
        _: 0
    print(result)
