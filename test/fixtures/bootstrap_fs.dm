from fs import is_dir, mkdir, rename, size

def main():
    let directory = "tmp/bootstrap_fs_dir"
    let source = directory + "/source.txt"
    let target = directory + "/target.txt"

    print(mkdir(directory))
    print(is_dir(directory))
    print(__c_file_write(source, "hello"))
    print(size(source))
    print(rename(source, target))
    print(size(target))
    print(__c_file_delete(target))
    print(__c_file_delete(directory))

main()
