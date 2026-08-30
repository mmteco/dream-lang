#ifndef DREAM_HTTP_OPS_H
#define DREAM_HTTP_OPS_H

#include "../core/dict.h"

char* __c_http_request(const char* method, const char* url,
    dict_t* headers, const char* body, int timeout);

#endif
