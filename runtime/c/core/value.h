#ifndef DREAM_VALUE_H
#define DREAM_VALUE_H

#include <stdbool.h>

char* __c_value_to_str(int kind, int int_value, bool bool_value,
                       double float_value, const char* pointer_value);

#endif
