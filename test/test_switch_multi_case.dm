# dream-test: dir

def choose(value: int) -> int:
    switch value:
        case 1, 2, 3:
            return 10
        case 4, 5:
            return 20
        default:
            return 0

def main():
    print(choose(1))
    print(choose(3))
    print(choose(5))
    print(choose(9))
