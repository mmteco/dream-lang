# File system utilities

def exists(path: str) -> bool:
    return __c_file_exists(path)

def remove_file(path: str) -> bool:
    return __c_file_delete(path)

def is_dir(path: str) -> bool:
    return __c_file_is_dir(path)

def mkdir(path: str) -> bool:
    return __c_file_mkdir(path)

def rename(old_path: str, new_path: str) -> bool:
    return __c_file_rename(old_path, new_path)

def size(path: str) -> int:
    return __c_file_size(path)
