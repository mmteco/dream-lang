#include "process.h"
#include <stddef.h>
#include <stdlib.h>

static int32_t dream_process_argument_count = 0;
static char** dream_process_argument_values = NULL;

void __c_process_set_args(int32_t argument_count, char** argument_values) {
    dream_process_argument_count = argument_count;
    dream_process_argument_values = argument_values;
}

int32_t __c_process_arg_count(void) {
    return dream_process_argument_count;
}

const char* __c_process_arg(int32_t index) {
    if (dream_process_argument_values == NULL) {
        return "";
    }
    if (index < 0 || index >= dream_process_argument_count) {
        return "";
    }
    if (dream_process_argument_values[index] == NULL) {
        return "";
    }
    return dream_process_argument_values[index];
}

const char* __c_env(const char* name) {
    if (name == NULL) {
        return "";
    }

    const char* value = getenv(name);
    return value == NULL ? "" : value;
}
