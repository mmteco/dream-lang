# File I/O utilities

const STDOUT: int = 0
const STDERR: int = 1

def print(value: str, file: int = STDOUT, end: str = "\n"):
    __c_io_write(file, value, end)

def eprintln(value: str):
    print(value, STDERR, "\n")

def eprint(value: str):
    print(value, STDERR, "")

def read(path: str) -> str:
    return __c_file_read(path)

struct File:
    path: str
    mode: str

    def read(self) -> str:
        return __c_file_read(self.path)

    def read_bytes(self) -> bytes:
        return __c_file_read_bytes(self.path)

    def write(self, content: str) -> Result[int, str]:
        if self.mode == "a":
            let written = __c_file_append(self.path, content)
            if written == -1:
                return Err("failed to write file")
            return Ok(written)
        let written = __c_file_write(self.path, content)
        if written == -1:
            return Err("failed to write file")
        return Ok(written)

    def write_bytes(self, content: bytes) -> Result[int, str]:
        if self.mode == "ab":
            let written = __c_file_append_bytes(self.path, content)
            if written == -1:
                return Err("failed to write bytes")
            return Ok(written)
        let written = __c_file_write_bytes(self.path, content)
        if written == -1:
            return Err("failed to write bytes")
        return Ok(written)

    def append(self, content: str) -> Result[int, str]:
        let written = __c_file_append(self.path, content)
        if written == -1:
            return Err("failed to append file")
        return Ok(written)

    def append_bytes(self, content: bytes) -> Result[int, str]:
        let written = __c_file_append_bytes(self.path, content)
        if written == -1:
            return Err("failed to append bytes")
        return Ok(written)

    def close(self):
        return

def open(path: str, mode: str = "r") -> File:
    return File{path: path, mode: mode}

def read_bytes(path: str) -> bytes:
    return open(path, "rb").read_bytes()

def write(path: str, content: str) -> Result[int, str]:
    return open(path, "w").write(content)

def write_bytes(path: str, content: bytes) -> Result[int, str]:
    return open(path, "wb").write_bytes(content)
