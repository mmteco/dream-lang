# dream-test: dir

interface Readable:
    def read(self) -> int

struct Box:
    value: int

struct Pair:
    left: int
    right: int

impl Readable for Box:
    def read(self) -> int:
        return self.value

impl Readable for Pair:
    def read(self) -> int:
        return self.left + self.right

def read_value(reader: Readable) -> int:
    return reader.read()

def main():
    let first: Readable = Box{value: 11}
    let second: Readable = Pair{left: 2, right: 5}
    print(read_value(first))
    print(read_value(second))

main()
