#include "io.h"
#include <stdio.h>

void __c_io_write(int stream, const char* text, const char* end) {
    FILE* output = stream == 0 ? stdout : stderr;
    fputs(text == NULL ? "" : text, output);
    fputs(end == NULL ? "" : end, output);
}
