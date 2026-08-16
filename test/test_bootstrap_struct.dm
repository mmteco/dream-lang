struct Point:
    x: int
    y: int

def main():
    let point: Point = Point{y: 5, x: 2}
    print(point.x + point.y)
