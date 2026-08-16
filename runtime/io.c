#include <stdio.h>
#include "io.h"

void dream_print_int(int value) {
    printf("%d\n", value);
}

void dream_print_float(double value) {
    printf("%g\n", value);
}

void dream_print_bool(bool value) {
    printf("%s\n", value ? "true" : "false");
}

void dream_print_string(const char* str) {
    printf("%s\n", str == NULL ? "" : str);
}

void dream_print_rune(uint32_t rune) {
    printf("%u\n", rune);
}
