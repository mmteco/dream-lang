const ASCII_PLUS: int = 43
const ASCII_MINUS: int = 45
const ASCII_STAR: int = 42
const ASCII_COLON: int = 58
const K_PLUS: int = 5
const K_MINUS: int = 6
const K_STAR: int = 7
const K_COLON: int = 15

def classify(code: int) -> int:
    let result = 0
    switch code:
        case ASCII_PLUS:
            result = K_PLUS
        case ASCII_MINUS:
            result = K_MINUS
        case ASCII_STAR:
            result = K_STAR
        case ASCII_COLON:
            result = K_COLON
        default:
            result = 99
    return result

def main() -> int:
    print(classify(43))
    print(classify(45))
    print(classify(42))
    print(classify(58))
    print(classify(100))
    return 0
