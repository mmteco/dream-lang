# dream-test: dir

interface CounterOps:
    def add(self, amount: int) -> int
    def enabled(self, value: bool) -> bool

struct Counter:
    base: int

impl CounterOps for Counter:
    def add(self, amount: int) -> int:
        return self.base + amount

    def enabled(self, value: bool) -> bool:
        return value

def main():
    let counter: CounterOps = Counter{base: 10}
    print(counter.add(5))
    print(counter.enabled(true))
    print(counter.enabled(false))

main()
