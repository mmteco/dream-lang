struct Point:
    x: int
    y: int

def make_point(x: int, y: int) -> Point:
    return Point{x: x, y: y}

def add_point(point: Point) -> int:
    return point.x + point.y

def main():
    let point: Point = make_point(2, 5)
    print(add_point(point))
