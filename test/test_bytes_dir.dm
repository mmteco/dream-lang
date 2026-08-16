from bytes import str_to_bytes, bytes_to_str

let bytes = str_to_bytes("abc")
let first = bytes[1]
let part = bytes[1:3]
let text = bytes_to_str(part)
print(first)
print(len(part))
print(text)
