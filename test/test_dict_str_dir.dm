# dream-test: dir

from str import upper, lower, strip, find, replace, startswith, endswith, split, join
from dict import get, set
from ops import Display

struct Label:
    value: str

impl Display for Label:
    def to_string(self) -> str:
        return self.value

def main():
    let values: dict[str, int] = {}
    set(values, "answer", 42)
    let chained = values.set("bonus", 8)
    chained.set("answer", 42)
    print("answer" in values)
    print(get(values, "missing", 7))
    values["answer"] = 42
    print(values["answer"])
    print(len(values))
    print(values.len())
    print(values.get("bonus"))

    let numbers: dict[int, str] = {}
    numbers[1] = "one"
    print(numbers[1])

    let text = "  Dream  "
    print(upper(text))
    print(lower(text))
    print(strip(text))
    print(text.len())
    print(find(text, "ea"))
    print(replace(text, "Dream", "DM"))
    print(startswith(strip(text), "D"))
    print(endswith(strip(text), "m"))
    print(join(split("a,b", ","), "-"))
    print(str(42))
    print(str(3.5))
    print(str("text".encode()))
    print(str(Label{value: "label"}))

main()
