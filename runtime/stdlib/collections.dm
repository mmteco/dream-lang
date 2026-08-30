# Set and ordered set collections

struct Set:
    values: list[str]

    def __init__() -> Set:
        return Set{values: []}

    def contains(self, value: str) -> bool:
        return value in self.values

    def len(self) -> int:
        return len(self.values)

    def add(self, value: str) -> Set:
        if not self.contains(value):
            append(self.values, value)
        return self

    def remove(self, value: str) -> Set:
        let result: list[str] = []
        for current in self.values:
            if current != value:
                append(result, current)
        return Set{values: result}

struct OrderedSet:
    values: list[str]

    def __init__() -> OrderedSet:
        return OrderedSet{values: []}

    def contains(self, value: str) -> bool:
        return value in self.values

    def len(self) -> int:
        return len(self.values)

    def add(self, value: str) -> OrderedSet:
        if not self.contains(value):
            append(self.values, value)
        return self

    def remove(self, value: str) -> OrderedSet:
        let result: list[str] = []
        for current in self.values:
            if current != value:
                append(result, current)
        return OrderedSet{values: result}
