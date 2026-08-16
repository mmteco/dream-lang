#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "runtime.h"

// legacy backend 兼容 ABI；新代码使用 io.c 中的 dream_print_*。
void print_int(int value) {
    printf("%d\n", value);
}

void print_bool(bool value) {
    printf("%s\n", value ? "true" : "false");
}

void print_string(const char* str) {
    printf("%s\n", str == NULL ? "" : str);
}

void print_rune(uint32_t rune) {
    printf("%u\n", rune);
}
