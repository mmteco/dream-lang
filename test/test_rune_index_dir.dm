from utf8 import ord

def main():
    let text = "A你𐀀"
    let middle: rune = text[1]
    let last = text[2]

    print(middle == '你')
    print(ord(middle))
    print(last)
