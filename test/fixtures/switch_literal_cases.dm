def classify(code: int) -> int:
    let result = 0
    switch code:
        case 43:
            result = 1
        case 45:
            result = 2
        case 40:
            result = 3
        case 41:
            result = 4
        case 58:
            result = 5
        default:
            result = 6
    return result

def main() -> int:
    print(classify(43))
    print(classify(45))
    print(classify(40))
    print(classify(41))
    print(classify(58))
    print(classify(99))
    return 0
