#include <stdio.h>
#include <stdbool.h>
#include "runtime.h"

void print_int(int value) {
    printf("%d\n", value);
}

void print_bool(bool value) {
    printf("%s\n", value ? "true" : "false");
}
