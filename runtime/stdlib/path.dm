# Object-oriented and functional Path standard library for Dream.

from ops import Display, Div
from str import len, startswith


# --- 顶级路径处理函数 ---

def is_abs(value: str) -> bool:
    return startswith(value, "/")

def last_separator(value: str) -> int:
    let separator_index = -1
    let cursor = 0
    let total_length = len(value)
    while cursor < total_length:
        if value[cursor] == '/':
            separator_index = cursor
        cursor += 1
    return separator_index

def last_dot_index(name: str) -> int:
    let dot_index = -1
    let cursor = 0
    let total_length = len(name)
    while cursor < total_length:
        if name[cursor] == '.':
            dot_index = cursor
        cursor += 1
    return dot_index

def normalize(value: str) -> str:
    let absolute = is_abs(value)
    let normalized_result = ""
    let segment_start = 0
    let cursor = 0
    let total_length = len(value)

    while cursor <= total_length:
        if cursor == total_length or value[cursor] == '/':
            let segment = value[segment_start:cursor]
            if segment == "..":
                let separator_index = last_separator(normalized_result)
                if separator_index >= 0:
                    normalized_result = normalized_result[:separator_index]
                elif normalized_result != "":
                    normalized_result = ""
                elif not absolute:
                    normalized_result = ".."
            elif segment != "" and segment != ".":
                if normalized_result == "":
                    normalized_result = segment
                else:
                    normalized_result = normalized_result + "/" + segment
            segment_start = cursor + 1
        cursor += 1

    if absolute:
        if normalized_result == "":
            return "/"
        return "/" + normalized_result
    if normalized_result == "":
        return "."
    return normalized_result

def basename(value: str) -> str:
    let normalized_path = normalize(value)
    if normalized_path == "/" or normalized_path == ".":
        return normalized_path
    let separator_index = last_separator(normalized_path)
    if separator_index < 0:
        return normalized_path
    return normalized_path[separator_index + 1:]

def dirname(value: str) -> str:
    let normalized_path = normalize(value)
    if normalized_path == "/" or normalized_path == ".":
        return normalized_path
    let separator_index = last_separator(normalized_path)
    if separator_index < 0:
        return "."
    if separator_index == 0:
        return "/"
    return normalized_path[:separator_index]

def ext(value: str) -> str:
    let base_filename = basename(value)
    let dot_index = last_dot_index(base_filename)
    if dot_index <= 0:
        return ""
    return base_filename[dot_index:]

def stem(value: str) -> str:
    let base_filename = basename(value)
    let extension = ext(value)
    if extension == "":
        return base_filename
    return base_filename[:len(base_filename) - len(extension)]

def join_path(a: str, b: str) -> str:
    if a == "":
        return b
    if b == "":
        return a
    if is_abs(b):
        return b
    return a + "/" + b

def join_path3(a: str, b: str, c: str) -> str:
    return join_path(join_path(a, b), c)


# --- 面向对象 Path 结构体 ---

struct Path:
    raw: str

    # --- 构造函数与静态工厂方法 ---

    def __init__(raw: str) -> Path:
        return Path{
            raw: normalize(raw)
        }

    def cwd() -> Path:
        let current_directory = __c_env("PWD")
        if current_directory == "":
            return Path(".")
        return Path(current_directory)

    def home() -> Path:
        let home_directory = __c_env("HOME")
        if home_directory == "":
            return Path("/")
        return Path(home_directory)

    def temp_dir() -> Path:
        let temporary_directory = __c_env("TMPDIR")
        if temporary_directory == "":
            return Path("/tmp")
        return Path(temporary_directory)

    # --- 静态方法（Static Methods） ---

    def is_abs(value: str) -> bool:
        return is_abs(value)

    def normalize(value: str) -> str:
        return normalize(value)

    def basename(value: str) -> str:
        return basename(value)

    def dirname(value: str) -> str:
        return dirname(value)

    def ext(value: str) -> str:
        return ext(value)

    def stem_of(value: str) -> str:
        return stem(value)

    def join(a: str, b: str) -> Path:
        return Path(join_path(a, b))

    def join3(a: str, b: str, c: str) -> Path:
        return Path(join_path3(a, b, c))

    # --- 实例属性与状态查询 ---

    def to_string(self) -> str:
        return self.raw

    def to_str(self) -> str:
        return self.raw

    def is_absolute(self) -> bool:
        return is_abs(self.raw)

    def is_relative(self) -> bool:
        return not is_abs(self.raw)

    def name(self) -> str:
        return basename(self.raw)

    def stem(self) -> str:
        return stem(self.raw)

    def suffix(self) -> str:
        return ext(self.raw)

    def parent(self) -> Path:
        return Path(dirname(self.raw))

    # --- 路径衍生与修改 ---

    def joinpath(self, child: str) -> Path:
        return Path(join_path(self.raw, child))

    def with_name(self, name: str) -> Path:
        let parent_directory = self.parent()
        if parent_directory.to_string() == ".":
            return Path(name)
        return parent_directory.joinpath(name)

    def with_suffix(self, suffix: str) -> Path:
        let base_stem = self.stem()
        let parent_directory = self.parent()
        let new_filename = base_stem + suffix
        if parent_directory.to_string() == ".":
            return Path(new_filename)
        return parent_directory.joinpath(new_filename)

    def with_stem(self, new_stem: str) -> Path:
        let current_suffix = self.suffix()
        return self.with_name(new_stem + current_suffix)

    # --- 文件系统 I/O 与元数据操作 ---

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
        let written_bytes = __c_file_write(self.raw, content)
        if written_bytes == -1:
            return Err("failed to write file")
        return Ok(written_bytes)

    def write_bytes(self, content: bytes) -> Result[int, str]:
        let written_bytes = __c_file_write_bytes(self.raw, content)
        if written_bytes == -1:
            return Err("failed to write bytes")
        return Ok(written_bytes)

    def append_text(self, content: str) -> Result[int, str]:
        let written_bytes = __c_file_append(self.raw, content)
        if written_bytes == -1:
            return Err("failed to append file")
        return Ok(written_bytes)

    def append_bytes(self, content: bytes) -> Result[int, str]:
        let written_bytes = __c_file_append_bytes(self.raw, content)
        if written_bytes == -1:
            return Err("failed to append bytes")
        return Ok(written_bytes)

    def rename(self, target: str) -> bool:
        return __c_file_rename(self.raw, target)

    def unlink(self) -> bool:
        return __c_file_delete(self.raw)

    def mkdir(self) -> bool:
        return __c_file_mkdir(self.raw)


# --- 接口实现 ---

impl Display for Path:
    def to_string(self) -> str:
        return self.raw

impl Div[str] for Path:
    def div(self, other: str) -> Path:
        return self.joinpath(other)
