def choose_integer(value: int) -> int:
    switch value:
        case 1:
            return 10
        case 2:
            return 20
        default:
            return 30

def choose_text(value: str) -> int:
    switch value:
        case "ready":
            return 1
        case "failed":
            return 2
        default:
            return 3

def choose_float(value: float) -> int:
    switch value:
        case 2.5:
            return 25
        default:
            return 30

def main():
    print(choose_integer(2))
    print(choose_text("ready"))
    print(choose_float(2.5))
    let flag = true
    switch flag:
        case true:
            print(1)
        default:
            print(0)
