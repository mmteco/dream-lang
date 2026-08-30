#ifndef DREAM_CRYPTO_H
#define DREAM_CRYPTO_H

#include "bytes.h"

char* __c_crypto_sha256(const char* value);
char* __c_crypto_sha256_bytes(const bytes_t* value);

#endif
