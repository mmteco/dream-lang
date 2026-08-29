# dream-test: dir

from iter import Iterator, Iterable

struct Counter:
    current: list[int]
    end: int

struct Source:
    start: int
    end: int

impl Iterator[int] for Counter:
    def has_next(self) -> bool:
        return self.current[0] < self.end

    def next(self) -> int:
        let value = self.current[0]
        self.current[0] = self.current[0] + 1
        return value

impl Iterable[int] for Source:
    def iter(self) -> Iterator[int]:
        return Counter{current: [self.start], end: self.end}

def main():
    let source = Source{start: 2, end: 5}
    print(3 in source)
    print(8 in source)
    for value in source:
        print(value)

    let counter = Counter{current: [7], end: 9}
    print(8 in counter)
    print(6 in counter)
    for value in counter:
        print(value)
