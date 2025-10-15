def map[T, U](items: list[T], f: (T) -> U) -> list[U]:
    """对列表中的每个元素应用函数"""
    pass

def filter[T](items: list[T], predicate: (T) -> bool) -> list[T]:
    """过滤列表元素"""
    pass

def reduce[T, U](items: list[T], initial: U, f: (U, T) -> U) -> U:
    """将列表归约为单个值"""
    pass

def zip[T, U](left: list[T], right: list[U]) -> list[(T, U)]:
    """将两个列表合并成元组列表"""
    pass

def enumerate[T](items: list[T]) -> list[(int, T)]:
    """返回索引和元素的元组列表"""
    pass

def reverse[T](items: list[T]) -> list[T]:
    """反转列表"""
    pass

def sort[T](items: list[T]) -> list[T]:
    """排序列表"""
    pass
