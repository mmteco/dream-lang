#ifndef DREAM_IO_H
#define DREAM_IO_H

#include <stdint.h>
#include <stdbool.h>

// Dream 调用的稳定 C 输出 ABI。
void __c_io_write(int stream, const char* text, const char* end);

#endif
