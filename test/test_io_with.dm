# dream-test: dir
# io.open 与 with 上下文管理测试

from io import open
from fs import remove_file

def result_value(value: Result[int, str]) -> int:
    return match value:
        Ok(written): written
        Err(_): -1

def main():
    with open("test_with.txt", "w") as writer:
        print(result_value(writer.write("hello")))

    with open("test_with.txt") as reader:
        print(reader.read())

    print(remove_file("test_with.txt"))

main()
