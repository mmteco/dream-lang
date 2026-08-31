# Dictionary construction and common generic helpers.

def dict() -> dict[str, int]:
    return {}

def has[V](values: dict[str, V], key: str) -> bool:
    return __c_dict_has_str(values, key)

def get[V](values: dict[str, V], key: str, fallback: V) -> V:
    if has(values, key):
        return values[key]
    return fallback

def set[V](values: dict[str, V], key: str, value: V) -> dict[str, V]:
    values[key] = value
    return values
