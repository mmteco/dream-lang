# dream-test: dir

def choose_float(value: float) -> int:
    switch value:
        case 2.5:
            return 25
        default:
            return 0

def choose_bool(value: bool) -> int:
    switch value:
        case true:
            return 1
        default:
            return 0

def choose_text(value: str) -> int:
    switch value:
        case "ready":
            return 1
        default:
            return 0

def main():
    print(choose_float(2.5))
    print(choose_bool(true))
    print(choose_text("ready"))
