def test_empty_list_let():
    let nums = []
    let [] = nums
    print(1)

def test_exact_list_let():
    let nums = [10, 20, 30]
    let [a, b, c] = nums
    print(a)
    print(b)
    print(c)

def test_cons_let():
    let nums = [10, 20, 30]
    let head :: tail = nums
    print(head)
    print(5)

def test_nested_cons_let():
    let nums = [10, 20, 30, 40]
    let a :: b :: rest = nums
    print(a)
    print(b)
    print(8)

def test_empty_list_match():
    let nums = []
    match nums:
        case []:
            print(10)

def test_single_element_match():
    let nums = [100]
    match nums:
        case head :: tail:
            print(head)
            print(12)

def test_exact_list_match():
    let nums = [10, 20]
    match nums:
        case [x, y]:
            print(x)
            print(y)
            print(14)

def test_cons_match():
    let nums = [10, 20, 30]
    match nums:
        case head :: tail:
            print(head)
            print(16)

def test_nested_cons_match():
    let nums = [10, 20, 30, 40]
    match nums:
        case a :: b :: rest:
            print(a)
            print(b)
            print(18)

def test_three_element_exact():
    let nums = [5, 15, 25]
    let [x, y, z] = nums
    print(x)
    print(y)
    print(z)

def main():
    print(100)

    test_empty_list_let()

    print(200)
    test_exact_list_let()

    print(300)
    test_cons_let()

    print(400)
    test_nested_cons_let()

    print(500)
    test_empty_list_match()

    print(600)
    test_single_element_match()

    print(700)
    test_exact_list_match()

    print(800)
    test_cons_match()

    print(900)
    test_nested_cons_match()

    print(1000)
    test_three_element_exact()

    print(9999)

main()
