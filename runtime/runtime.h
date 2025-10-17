#ifndef DREAM_RUNTIME_H
#define DREAM_RUNTIME_H

#include <stdbool.h>
#include <stdint.h>
#include "str.h"
#include "file.h"
#include "dict.h"
#include "tuple.h"
#include "dynarray.h"
#include "union.h"

void print_int(int value);
void print_bool(bool value);
void print_string(const char* str);
void print_rune(uint32_t rune);

#endif
