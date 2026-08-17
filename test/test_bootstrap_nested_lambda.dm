# dream-test: dir

def main():
    let offset = 2
    let make = lambda (base: int) -> lambda (value: int) -> value + base + offset
    let add = make(3)
    print(add(4))

main()
