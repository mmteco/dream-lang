# dream-test: dir

from ops import RAdd

struct Token:
    value: str

impl RAdd[str, str] for Token:
    def radd(self, other: str) -> str:
        return other + self.value

def main():
    let token = Token{value: "dream"}
    let result = "hello "
    result += token
    result += "!"
    print(result)

main()
