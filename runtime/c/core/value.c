#include "value.h"
#include "memory.h"
#include "union.h"

#include <stdio.h>

static char* value_text_from_int(int value) {
    char* result = (char*)gc_alloc(64, OBJ_STRING);
    if (result == NULL) return NULL;
    snprintf(result, 64, "%d", value);
    return result;
}

static char* value_text_from_float(double value) {
    char* result = (char*)gc_alloc(64, OBJ_STRING);
    if (result == NULL) return NULL;
    snprintf(result, 64, "%g", value);
    return result;
}

char* __c_value_to_str(int kind, int int_value, bool bool_value,
                       double float_value, const char* pointer_value) {
    switch (kind) {
        case 1:
        case 5:
            return value_text_from_int(int_value);
        case 2:
            return value_text_from_float(float_value);
        case 3:
            return (char*)(bool_value ? "true" : "false");
        case 4:
            return (char*)(pointer_value == NULL ? "" : pointer_value);
        case 6:
            return __c_union_to_str((union_t*)pointer_value);
        default:
            return "(null)";
    }
}
