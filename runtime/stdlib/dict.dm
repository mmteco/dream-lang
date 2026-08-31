# Dictionary helpers.

def dict_get[V](values: dict[str, V], key: str, fallback: V) -> V:
    if key in values:
        return values[key]
    return fallback

def set[V](values: dict[str, V], key: str, value: V) -> dict[str, V]:
    values[key] = value
    return values
