# Dictionary helpers with a Python-like surface.

def get[V](values: dict[str, V], key: str, fallback: V) -> V:
    if key in values:
        return values[key]
    return fallback

def set[V](values: dict[str, V], key: str, value: V) -> dict[str, V]:
    values[key] = value
    return values

def contains[V](values: dict[str, V], key: str) -> bool:
    return key in values



