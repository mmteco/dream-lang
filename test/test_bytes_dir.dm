from bytes import str_to_bytes, bytes_to_str, bytes_from_list, bytes_to_list

let bytes = str_to_bytes("abc")
let first = bytes[1]
let part = bytes[1:3]
let text = bytes_to_str(part)
print(first)
print(len(part))
print(text)

let values = [b'x', b'y']
let rebuilt = bytes_from_list(values)
let restored = bytes_to_list(rebuilt)
print(restored[0])
print(len(restored))
