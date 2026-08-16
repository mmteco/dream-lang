enum Status:
    Ready(int)
    Failed(int)
    Empty

def main():
    let status = Status.Ready(42)
    let result = match status:
        Status.Ready(value): value
        Status.Failed(_): -1
        Status.Empty: 0
    print(result)
