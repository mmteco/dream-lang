# Path utilities and object-oriented Path representation

from ops import Display, Div


def is_abs(value: str) -> bool:
    return value.startswith("/")

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

struct Path:
    raw: str

    def __init__(raw: str) -> Path:
        return Path{raw: normalize(raw)}

    def to_string(self) -> str:
        return self.raw

    def is_absolute(self) -> bool:
        return is_abs(self.raw)

    def name(self) -> str:
        return basename(self.raw)

    def stem(self) -> str:
        return stem(self.raw)

    def suffix(self) -> str:
        return ext(self.raw)

    def parent(self) -> Path:
        return Path(dirname(self.raw))

    def joinpath(self, child: str) -> Path:
        return Path(join(self.raw, child))

    def exists(self) -> bool:
        return __c_file_exists(self.raw)

    def is_dir(self) -> bool:
        return __c_file_is_dir(self.raw)

    def is_file(self) -> bool:
        return __c_file_exists(self.raw) and not __c_file_is_dir(self.raw)

    def size(self) -> int:
        return __c_file_size(self.raw)

    def read_text(self) -> str:
        return __c_file_read(self.raw)

    def read_bytes(self) -> bytes:
        return __c_file_read_bytes(self.raw)

    def write_text(self, content: str) -> Result[int, str]:
        let written = __c_file_write(self.raw, content)
        if written == -1:
            return Err("failed to write file")
        return Ok(written)

    def write_bytes(self, content: bytes) -> Result[int, str]:
        let written = __c_file_write_bytes(self.raw, content)
        if written == -1:
            return Err("failed to write bytes")
        return Ok(written)

    def append_text(self, content: str) -> Result[int, str]:
        let written = __c_file_append(self.raw, content)
        if written == -1:
            return Err("failed to append file")
        return Ok(written)

    def append_bytes(self, content: bytes) -> Result[int, str]:
        let written = __c_file_append_bytes(self.raw, content)
        if written == -1:
            return Err("failed to append bytes")
        return Ok(written)

    def rename(self, target: str) -> bool:
        return __c_file_rename(self.raw, target)

    def with_name(self, name: str) -> Path:
        return Path(join(dirname(self.raw), name))

    def with_suffix(self, suffix: str) -> Path:
        let cur_stem = stem(self.raw)
        let parent_dir = dirname(self.raw)
        let new_name = cur_stem + suffix
        if parent_dir == ".":
            return Path(new_name)
        return Path(join(parent_dir, new_name))

    def unlink(self) -> bool:
        return __c_file_delete(self.raw)

    def mkdir(self) -> bool:
        return __c_file_mkdir(self.raw)

impl Display for Path:
    def to_string(self) -> str:
        return self.raw

impl Div[str] for Path:
    def div(self, other: str) -> Path:
        return self.joinpath(other)

