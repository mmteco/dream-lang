from ops import Append

struct Buffer:
    data: list[byte]

    def __init__() -> Buffer:
        return Buffer{data: []}

    def new() -> Buffer:
        return Buffer{data: []}

    def to_str(self) -> str:
        let bytes = __c_bytes_from_array(self.data)
        return __c_bytes_to_str(bytes)

    def len(self) -> int:
        return len(self.data)

    def clear(self):
        self.data = []

    def append_bytes(self, value: bytes) -> Buffer:
        let index = 0
        let length = len(value)
        while index < length:
            append(self.data, value[index])
            index = index + 1
        return self

impl Append[str] for Buffer:
    def append(self, value: str):
        self.append_bytes(__c_str_to_bytes(value))

impl Append[bytes] for Buffer:
    def append(self, value: bytes):
        self.append_bytes(value)

impl Append[byte] for Buffer:
    def append(self, value: byte):
        append(self.data, value)

impl Append[int] for Buffer:
    def append(self, value: int):
        if value == 0:
            append(self.data, b'0')
            return

        let is_negative = value < 0
        if is_negative:
            append(self.data, b'-')
            value = 0 - value

        let digits: list[byte] = []
        while value > 0:
            let digit = match value % 10:
                0: b'0'
                1: b'1'
                2: b'2'
                3: b'3'
                4: b'4'
                5: b'5'
                6: b'6'
                7: b'7'
                8: b'8'
                9: b'9'
                _: b'0'
            append(digits, digit)
            value = value / 10

        let index = len(digits) - 1
        while index >= 0:
            append(self.data, digits[index])
            index = index - 1
