def main():
    let optional = Some(7)
    let optional_value = match optional:
        Some(value): value
        None: 0
    let result = Ok(9)
    let result_value = match result:
        Ok(value): value
        Err(_): -1
    print(optional_value)
    print(result_value)
