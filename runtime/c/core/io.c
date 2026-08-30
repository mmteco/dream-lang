#include <stdio.h>
#include "io.h"

void __c_print_int(int value) {
    printf("%d\n", value);
}

void __c_print_float(double value) {
    printf("%g\n", value);
}

void __c_print_bool(bool value) {
    printf("%s\n", value ? "true" : "false");
}

void __c_print_str(const char* str) {
    printf("%s\n", str == NULL ? "" : str);
}

void __c_print_rune(uint32_t rune) {
    printf("%u\n", rune);
}

void __c_eprint_int(int value) {
    fprintf(stderr, "%d\n", value);
}

void __c_eprint_float(double value) {
    fprintf(stderr, "%g\n", value);
}

void __c_eprint_bool(bool value) {
    fprintf(stderr, "%s\n", value ? "true" : "false");
}

void __c_eprint_str(const char* str) {
    fprintf(stderr, "%s\n", str == NULL ? "" : str);
}

void __c_eprint_rune(uint32_t rune) {
    fprintf(stderr, "%u\n", rune);
}
