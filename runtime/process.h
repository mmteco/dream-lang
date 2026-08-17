#ifndef DREAM_PROCESS_H
#define DREAM_PROCESS_H

#include <stdint.h>

void __c_process_set_args(int32_t argument_count, char** argument_values);
int32_t __c_process_arg_count(void);
const char* __c_process_arg(int32_t index);

#endif
