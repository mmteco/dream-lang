def produce(should_succeed: bool) -> Result[int, int]:
    if should_succeed:
        return Ok(41)
    else:
        return Err(7)

def consume(should_succeed: bool) -> Result[int, int]:
    let value = produce(should_succeed)?
    return Ok(value + 1)

let result = consume(true)
let output = match result:
    Ok(value): value
    Err(_): -1
print(output)
let failed = consume(false)
let failed_output = match failed:
    Ok(value): value
    Err(_): -1
print(failed_output)
