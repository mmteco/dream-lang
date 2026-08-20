#ifndef DREAM_FILE_OPS_H
#define DREAM_FILE_OPS_H

#include <stdbool.h>
#include "dynarray.h"

// C 运行时文件 I/O 函数，使用 __c_ 命名空间避免与 Dream 层函数冲突
char* __c_file_read(const char* path);
int __c_file_write(const char* path, const char* content);
bool __c_file_exists(const char* path);
int __c_file_append(const char* path, const char* content);
bool __c_file_delete(const char* path);

dynarray_i32* __c_file_read_bytes(const char* path);
int __c_file_write_bytes(const char* path, dynarray_i32* data);
int __c_file_append_bytes(const char* path, dynarray_i32* data);

#endif
