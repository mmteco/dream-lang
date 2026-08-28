from bytes import encode, decode, from_list, to_list

let bytes = encode("abc")
let first = bytes[1]
let part = bytes[1:3]
let text = decode(part)
print(first)
print(len(part))
print(text)

let values = [b'x', b'y']
let rebuilt = from_list(values)
let restored = to_list(rebuilt)
print(restored[0])
print(len(restored))
