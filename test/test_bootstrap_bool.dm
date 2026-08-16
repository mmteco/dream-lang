def identity(value: bool) -> bool:
    return value

def negate(value: bool) -> bool:
    return not value

def main():
    let flag = identity(true)
    print(flag)
    print(not flag)
    print(negate(flag))
    print(not negate(flag))

main()
