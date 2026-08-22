#ifndef DREAM_COMPILER_H
#define DREAM_COMPILER_H

#include <stdbool.h>

int __c_build_llvm(const char* llvm_path, const char* output_path, bool optimized);

#endif
