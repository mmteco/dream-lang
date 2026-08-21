# dream-test: dir

def add(left: int, right: int) -> int:
    return left + right

def main():
    let precedence = 1 + 2 * 3
    let grouped = (1 + 2) * 3
    let unary = -precedence + +grouped
    let logical = precedence > 0 and grouped > 0
    let selected = logical ? add(add(1, 2), 3) : 0
    let indexed = [4, 5, 6][1 + 1]
    print(precedence)
    print(grouped)
    print(unary)
    print(selected)
    print(indexed)
