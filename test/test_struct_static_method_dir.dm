# dream-test: dir
struct Point:
    x: int
    y: int

    def origin() -> Point:
        return Point{x: 0, y: 0}

    def from_xy(x: int, y: int) -> Point:
        return Point{x: x, y: y}

    def translate(self, dx: int, dy: int) -> Point:
        return Point.from_xy(self.x + dx, self.y + dy)

    def sum(self) -> int:
        return self.x + self.y

struct MathHelper:
    dummy: int

    def square(n: int) -> int:
        return n * n

    def add(a: int, b: int) -> int:
        return a + b

struct FirstOwner:
    value: int

    def identify(value: int) -> int:
        return value + 1

struct SecondOwner:
    value: int

    def identify(value: int) -> int:
        return value + 2

def identify(value: int) -> int:
    return value + 3

def main():
    let p0 = Point.origin()
    print(p0.x)
    print(p0.y)

    let p1 = Point.from_xy(10, 20)
    print(p1.x)
    print(p1.y)

    let p2 = p1.translate(5, 7)
    print(p2.x)
    print(p2.y)
    print(p2.sum())

    let sq = MathHelper.square(6)
    print(sq)

    let sum = MathHelper.add(100, 23)
    print(sum)

    print(FirstOwner.identify(10))
    print(SecondOwner.identify(10))
    print(identify(10))
