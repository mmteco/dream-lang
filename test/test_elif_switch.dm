# dream-test: legacy
def classify(value: int) -> int:
    if value < 0:
        return 1
    elif value < 10:
        return 2
    else:
        return 3

def switch_value(value: int) -> int:
    switch value:
        case 1:
            return 10
        case 2:
            return 20
        default:
            return 30

def main():
    print(classify(5))
    print(switch_value(2))
