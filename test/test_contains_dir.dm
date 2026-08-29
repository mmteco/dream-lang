# dream-test: dir

from ops import Contains

struct Bag:
    value: int

impl Contains[int] for Bag:
    def contains(self, value: int) -> bool:
        return self.value == value

def main():
    let bag = Bag{value: 7}
    print(7 in bag)
    print(3 in bag)
