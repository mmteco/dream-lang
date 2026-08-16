def produce_value(left: int, right: int) -> Result[int, str]:
    if right == 0:
        return Err("division by zero")
    return Ok(left / right)

def adjust_value(left: int, right: int) -> Result[int, str]:
    let value = produce_value(left, right)?
    return Ok(value + 1)

def main():
    let result = adjust_value(6, 2)
    let value = match result:
        Ok(number): number
        Err(_): -1
    print(value)
