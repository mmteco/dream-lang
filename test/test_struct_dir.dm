struct Point:
    x: float
    y: float

def score(point: Point) -> float:
    return point.x + point.y

let point = Point{x: 2.0, y: 3.5}
print(point.x)
print(score(point))

let unpacked = match point:
    Point{x: left, y: right}: left + right
    _: 0.0
print(unpacked)
