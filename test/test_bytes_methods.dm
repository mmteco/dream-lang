# dream-test: dir
# bytes 的方法式 API 测试

from bytes import encode

let value = encode("abc")
print(value.length())
print(value.get(1))
print(value.slice(1, 3).decode())
