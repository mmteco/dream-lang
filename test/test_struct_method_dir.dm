# dream-test: dir

struct Point:
    x: int

    def value(self) -> int:
        return self.x

    def add(self, amount: int) -> int:
        return self.x + amount

    def increment(self):
        self.x = self.x + 1

interface Readable:
    def read(self) -> int
    def update(self)

struct Box:
    value: int
    label: str
    ratio: float

impl Readable for Box:
    def read(self) -> int:
        return self.value

    def update(self):
        self.label = "updated"
        self.ratio = 2.5

def main():
    let point = Point{x: 7}
    print(point.value())
    print(point.add(5))
    point.increment()
    print(point.x)

    let box = Box{value: 11, label: "initial", ratio: 1.5}
    print(box.read())
    box.update()
    print(box.label)
    print(box.ratio)

main()
