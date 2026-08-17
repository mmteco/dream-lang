let answer = 42
let greeting = "hello"
let config = {"host": "localhost", "port": "80"}
let counter = 0

def increment() -> int:
    counter = counter + 1
    return counter

def get_answer() -> int:
    return answer

def shadow_test() -> int:
    let answer = 7
    return answer

def main():
    print(get_answer())
    print(greeting)
    print(config["port"])
    print(increment())
    print(increment())
    print(shadow_test())
    print(get_answer())
    let local_value = 1
    local_value = 2
    print(local_value)
