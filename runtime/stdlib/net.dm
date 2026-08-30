# TCP networking utilities

struct Connection:
    fd: int

    def is_open(self) -> bool:
        return self.fd >= 0

    def write(self, content: str) -> int:
        if not self.is_open():
            return -1
        return __c_net_write(self.fd, content)

    def read(self) -> str:
        if not self.is_open():
            return ""
        return __c_net_read(self.fd, 4096)

    def read_n(self, size: int) -> str:
        if not self.is_open():
            return ""
        return __c_net_read(self.fd, size)

    def close(self) -> bool:
        if not self.is_open():
            return false
        let closed = __c_net_close(self.fd)
        if closed:
            self.fd = -1
        return closed

def connect(host: str, port: int) -> Connection:
    return Connection{fd: __c_net_connect(host, port)}
