const CONST_VALUE: int = 7

def main():
    let keywords = {
        "a": 1,
        "b": 2,
        "c": CONST_VALUE,
    }
    print(keywords["a"])
    print(keywords["b"])
    print(keywords["c"])
    let numbers = {
        1: 10,
        2: 20,
    }
    print(numbers[1])
    print(numbers[2])
