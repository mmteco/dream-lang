# Set and ordered set collections

from ops import BitAnd, BitOr, Sub

struct Set:
    values: list[str]
    index: dict[str, int]

    def __init__() -> Set:
        return Set{values: [], index: {}}

    def contains(self, value: str) -> bool:
        return value in self.index

    def len(self) -> int:
        return len(self.values)

    def add(self, value: str) -> Set:
        if value not in self.index:
            append(self.values, value)
            self.index[value] = 1
        return self

    def remove(self, value: str) -> Set:
        let result = Set()
        for current in self.values:
            if current != value:
                result.add(current)
        return result

    def union(self, other: Set) -> Set:
        let result = Set()
        for value in self.values:
            result.add(value)
        for value in other.values:
            result.add(value)
        return result

    def intersection(self, other: Set) -> Set:
        let result = Set()
        for value in self.values:
            if value in other.index:
                result.add(value)
        return result

    def difference(self, other: Set) -> Set:
        let result = Set()
        for value in self.values:
            if value not in other.index:
                result.add(value)
        return result

    def is_subset(self, other: Set) -> bool:
        for value in self.values:
            if value not in other.index:
                return false
        return true

    def is_disjoint(self, other: Set) -> bool:
        for value in self.values:
            if value in other.index:
                return false
        return true

struct OrderedSet:
    values: list[str]
    index: dict[str, int]

    def __init__() -> OrderedSet:
        return OrderedSet{values: [], index: {}}

    def contains(self, value: str) -> bool:
        return value in self.index

    def len(self) -> int:
        return len(self.values)

    def first(self) -> str:
        if len(self.values) == 0:
            return ""
        return self.values[0]

    def add(self, value: str) -> OrderedSet:
        if value not in self.index:
            append(self.values, value)
            self.index[value] = 1
        return self

    def remove(self, value: str) -> OrderedSet:
        let result = OrderedSet()
        for current in self.values:
            if current != value:
                result.add(current)
        return result

    def union(self, other: OrderedSet) -> OrderedSet:
        let result = OrderedSet()
        for value in self.values:
            result.add(value)
        for value in other.values:
            result.add(value)
        return result

    def intersection(self, other: OrderedSet) -> OrderedSet:
        let result = OrderedSet()
        for value in self.values:
            if value in other.index:
                result.add(value)
        return result

    def difference(self, other: OrderedSet) -> OrderedSet:
        let result = OrderedSet()
        for value in self.values:
            if value not in other.index:
                result.add(value)
        return result

    def is_subset(self, other: OrderedSet) -> bool:
        for value in self.values:
            if value not in other.index:
                return false
        return true

    def is_disjoint(self, other: OrderedSet) -> bool:
        for value in self.values:
            if value in other.index:
                return false
        return true

impl BitOr[Set] for Set:
    def bitor(self, other: Set) -> Set:
        return self.union(other)

impl BitAnd[Set] for Set:
    def bitand(self, other: Set) -> Set:
        return self.intersection(other)

impl Sub[Set] for Set:
    def sub(self, other: Set) -> Set:
        return self.difference(other)

impl BitOr[OrderedSet] for OrderedSet:
    def bitor(self, other: OrderedSet) -> OrderedSet:
        return self.union(other)

impl BitAnd[OrderedSet] for OrderedSet:
    def bitand(self, other: OrderedSet) -> OrderedSet:
        return self.intersection(other)

impl Sub[OrderedSet] for OrderedSet:
    def sub(self, other: OrderedSet) -> OrderedSet:
        return self.difference(other)
