# Set and ordered set collections with Python-like interface

from ops import BitAnd, BitOr, Sub, Display


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

    def isdisjoint(self, other: Set) -> bool:
        return self.is_disjoint(other)

    def issubset(self, other: Set) -> bool:
        return self.is_subset(other)

    def issuperset(self, other: Set) -> bool:
        return other.is_subset(self)

    def is_superset(self, other: Set) -> bool:
        return other.is_subset(self)

    def to_list(self) -> list[str]:
        let result: list[str] = []
        for v in self.values:
            append(result, v)
        return result

    def clear(self) -> Set:
        self.values = []
        self.index = {}
        return self

    def pop(self) -> str:
        if len(self.values) == 0:
            return ""
        let last_idx = len(self.values) - 1
        let val = self.values[last_idx]
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        let idx = 0
        while idx < last_idx:
            let item = self.values[idx]
            append(new_values, item)
            new_index[item] = 1
            idx = idx + 1
        self.values = new_values
        self.index = new_index
        return val

    def update(self, other: Set) -> Set:
        for value in other.values:
            self.add(value)
        return self

    def intersection_update(self, other: Set) -> Set:
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        for value in self.values:
            if value in other.index:
                append(new_values, value)
                new_index[value] = 1
        self.values = new_values
        self.index = new_index
        return self

    def difference_update(self, other: Set) -> Set:
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        for value in self.values:
            if value not in other.index:
                append(new_values, value)
                new_index[value] = 1
        self.values = new_values
        self.index = new_index
        return self

    def copy(self) -> Set:
        let result = Set()
        for v in self.values:
            result.add(v)
        return result


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

    def isdisjoint(self, other: OrderedSet) -> bool:
        return self.is_disjoint(other)

    def issubset(self, other: OrderedSet) -> bool:
        return self.is_subset(other)

    def issuperset(self, other: OrderedSet) -> bool:
        return other.is_subset(self)

    def is_superset(self, other: OrderedSet) -> bool:
        return other.is_subset(self)

    def to_list(self) -> list[str]:
        let result: list[str] = []
        for v in self.values:
            append(result, v)
        return result

    def clear(self) -> OrderedSet:
        self.values = []
        self.index = {}
        return self

    def pop(self) -> str:
        if len(self.values) == 0:
            return ""
        let last_idx = len(self.values) - 1
        let val = self.values[last_idx]
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        let idx = 0
        while idx < last_idx:
            let item = self.values[idx]
            append(new_values, item)
            new_index[item] = 1
            idx = idx + 1
        self.values = new_values
        self.index = new_index
        return val

    def update(self, other: OrderedSet) -> OrderedSet:
        for value in other.values:
            self.add(value)
        return self

    def intersection_update(self, other: OrderedSet) -> OrderedSet:
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        for value in self.values:
            if value in other.index:
                append(new_values, value)
                new_index[value] = 1
        self.values = new_values
        self.index = new_index
        return self

    def difference_update(self, other: OrderedSet) -> OrderedSet:
        let new_values: list[str] = []
        let new_index: dict[str, int] = {}
        for value in self.values:
            if value not in other.index:
                append(new_values, value)
                new_index[value] = 1
        self.values = new_values
        self.index = new_index
        return self

    def copy(self) -> OrderedSet:
        let result = OrderedSet()
        for v in self.values:
            result.add(v)
        return result


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

def set(items: list[str] = []) -> Set:
    let result = Set()
    for item in items:
        result.add(item)
    return result

def ordered_set(items: list[str] = []) -> OrderedSet:
    let result = OrderedSet()
    for item in items:
        result.add(item)
    return result


struct Counter:
    counts: dict[str, int]
    keys: list[str]
    _total: int

    def __init__() -> Counter:
        return Counter{counts: {}, keys: [], _total: 0}

    def get(self, key: str) -> int:
        if key in self.counts:
            return self.counts[key]
        return 0

    def add(self, key: str, count: int = 1) -> Counter:
        if key not in self.counts:
            append(self.keys, key)
            self.counts[key] = count
        else:
            self.counts[key] = self.counts[key] + count
        self._total = self._total + count
        return self

    def total(self) -> int:
        return self._total

    def len(self) -> int:
        return len(self.keys)

    def contains(self, key: str) -> bool:
        return key in self.counts

    def update(self, items: list[str]) -> Counter:
        for item in items:
            self.add(item, 1)
        return self

    def most_common_key(self) -> str:
        let best_k = ""
        let best_v = -1
        for k in self.keys:
            let v = self.counts[k]
            if v > best_v:
                best_v = v
                best_k = k
        return best_k

    def most_common_count(self) -> int:
        let best_v = 0
        for k in self.keys:
            let v = self.counts[k]
            if v > best_v:
                best_v = v
        return best_v

def counter(items: list[str] = []) -> Counter:
    let result = Counter()
    result.update(items)
    return result


