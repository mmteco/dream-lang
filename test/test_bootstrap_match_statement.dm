def main():
    let some_value = Some(42)
    let no_value = None
    match some_value:
        Some(value):
            print(value)
        None:
            print(-1)
    match no_value:
        Some(value):
            print(value)
        None:
            print(-1)

    let success_result = Ok(7)
    let failure_result = Err(9)
    match success_result:
        Ok(value):
            print(value)
        Err(error):
            print(error)
    match failure_result:
        Ok(value):
            print(value)
        Err(error):
            print(error)
