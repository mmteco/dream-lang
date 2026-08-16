#ifndef DREAM_IO_H
#define DREAM_IO_H

#include <stdint.h>
#include <stdbool.h>

// DIR/新 runtime 使用的稳定输出 ABI。
void dream_print_int(int value);
void dream_print_float(double value);
void dream_print_bool(bool value);
void dream_print_string(const char* str);
void dream_print_rune(uint32_t rune);

#endif
