def print_with_suffix(suffix: str):
    let format = lambda (value: str) -> value + suffix
    print(format("param"))

def main():
    let increment = lambda (value: int) -> value + 1
    let result = increment(41)
    print(result)

    let amount = 41
    let add_amount = lambda (value: int) -> value + amount
    print(add_amount(1))

    let suffix = "!"
    let add_suffix = lambda (value: str) -> value + suffix
    print(add_suffix("ok"))

    let enabled = true
    let choose_value = lambda (value: int) -> if enabled: value else: 0
    print(choose_value(7))

    let scale = 1.5
    let add_scale = lambda (value: float) -> value + scale
    print(add_scale(2.0))

    let values = [1, 2]
    let extend_values = lambda (value: list[int]) -> value + values
    let combined = extend_values([3])
    print(len(combined))

    print_with_suffix("?")

main()
