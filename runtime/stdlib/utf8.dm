# UTF-8 encoding and rune utilities
# Convert between Unicode codepoints and UTF-8 bytes.

def chr(value: int) -> rune:
    return value

def ord(r: rune) -> int:
    return __c_rune_to_int(r)

def byte_offset(s: str, rune_index: int) -> int:
    return __c_utf8_byte_offset(s, rune_index)

def encode_rune(r: rune) -> bytes:
    return __c_utf8_encode_rune(r)

def decode_rune(b: bytes, offset: int) -> (rune, int):
    let first = __c_bytes_get(b, offset)
    if first < 0x80:
        return (first, 1)
    if first < 0xC0:
        return (0, 1)
    let length = 0
    let lead_base = 0
    if first < 0xE0:
        length = 2
        lead_base = 0xC0
    elif first < 0xF0:
        length = 3
        lead_base = 0xE0
    elif first < 0xF8:
        length = 4
        lead_base = 0xF0
    else:
        return (0, 1)
    if offset + length > __c_bytes_len(b):
        return (0, 1)
    let rune_value = first - lead_base
    let index = 1
    while index < length:
        let current = __c_bytes_get(b, offset + index)
        if current < 0x80 or current >= 0xC0:
            return (0, index)
        rune_value = rune_value * 64 + (current - 0x80)
        index = index + 1
    return (rune_value, length)
