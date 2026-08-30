#ifndef DREAM_IO_H
#define DREAM_IO_H

#include <stdint.h>
#include <stdbool.h>

// Dream 调用的稳定 C 输出 ABI。
void __c_print_int(int value);
void __c_print_float(double value);
void __c_print_bool(bool value);
void __c_print_str(const char* str);
void __c_print_rune(uint32_t rune);

void __c_eprint_int(int value);
void __c_eprint_float(double value);
void __c_eprint_bool(bool value);
void __c_eprint_str(const char* str);
void __c_eprint_rune(uint32_t rune);

#endif
