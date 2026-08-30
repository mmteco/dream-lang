# Path utilities

def is_abs(value: str) -> bool:
    return __c_str_starts_with(value, "/")

def last_separator(value: str) -> int:
    let result = -1
    let index = 0
    while index < len(value):
        if value[index] == '/':
            result = index
        index = index + 1
    return result

def normalize(value: str) -> str:
    let absolute = is_abs(value)
    let result = ""
    let segment_start = 0
    let index = 0
    while index <= len(value):
        if index == len(value) or value[index] == '/':
            let part = value[segment_start:index]
            if part == "..":
                let separator = last_separator(result)
                if separator >= 0:
                    result = result[:separator]
                elif result != "":
                    result = ""
                elif not absolute:
                    result = ".."
            elif part != "" and part != ".":
                if result == "":
                    result = part
                else:
                    result = result + "/" + part
            segment_start = index + 1
        index = index + 1

    let normalized = result
    if absolute:
        if normalized == "":
            return "/"
        return "/" + normalized
    if normalized == "":
        return "."
    return normalized

def join(base: str, child: str) -> str:
    if base == "":
        return normalize(child)
    if child == "":
        return normalize(base)
    if is_abs(child):
        return normalize(child)
    return normalize(base + "/" + child)

def basename(value: str) -> str:
    let normalized = normalize(value)
    if normalized == "/" or normalized == ".":
        return normalized

    return normalized[last_separator(normalized) + 1:]

def dirname(value: str) -> str:
    let normalized = normalize(value)
    if normalized == "/" or normalized == ".":
        return normalized

    let separator = last_separator(normalized)
    if separator < 0:
        return "."
    if separator == 0:
        return "/"
    return normalized[:separator]

def ext(value: str) -> str:
    let name = basename(value)
    let last_dot = -1
    let index = 0
    while index < len(name):
        if name[index] == '.':
            last_dot = index
        index = index + 1

    if last_dot <= 0:
        return ""
    return name[last_dot:]

def stem(value: str) -> str:
    let name = basename(value)
    let suffix = ext(name)
    if suffix == "":
        return name
    return name[:len(name) - len(suffix)]
