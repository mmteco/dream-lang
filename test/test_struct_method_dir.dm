# dream-test: dir

struct Point:
    x: int

    def value(self) -> int:
        return self.x

    def add(self, amount: int) -> int:
        return self.x + amount

interface Readable:
    def read(self) -> int

struct Box:
    value: int

impl Readable for Box:
    def read(self) -> int:
        return self.value

def main():
    let point = Point{x: 7}
    print(point.value())
    print(point.add(5))

    let box = Box{value: 11}
    print(box.read())

main()
