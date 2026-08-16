let float_result = match 2.5:
    1.5: 10
    2.5: 20
    _: 0
print(float_result)

let bool_result = match true:
    false: 0
    true: 1
print(bool_result)

let string_result = match "dream":
    "other": 0
    "dream": 2
    _: -1
print(string_result)

let byte_result = match b'A':
    b'B': 0
    b'A': 3
    _: -1
print(byte_result)
