# 可迭代协议

interface Iterator[T]:
    def has_next(self) -> bool
    def next(self) -> T

interface Iterable[T]:
    def iter(self) -> Iterator[T]
