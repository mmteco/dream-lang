enum Status:
    Ready(int)
    Failed(int)
    Empty

def main():
    let status = Status.Ready(42)
    print(status[0])
    print(status[1])
    let empty = Status.Empty
    print(empty[0])
