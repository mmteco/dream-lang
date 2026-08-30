#include "crypto.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static uint32_t sha256_rotate_right(uint32_t value, uint32_t count) {
    return (value >> count) | (value << (32 - count));
}

static void sha256_transform(uint32_t state[8], const unsigned char block[64]) {
    static const uint32_t round_constants[64] = {
        0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u,
        0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
        0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
        0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
        0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
        0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
        0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
        0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
        0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
        0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
        0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u,
        0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
        0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u,
        0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
        0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
        0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
    };
    uint32_t words[64];
    for (int index = 0; index < 16; index++) {
        int offset = index * 4;
        words[index] = ((uint32_t)block[offset] << 24) |
            ((uint32_t)block[offset + 1] << 16) |
            ((uint32_t)block[offset + 2] << 8) |
            (uint32_t)block[offset + 3];
    }
    for (int index = 16; index < 64; index++) {
        uint32_t small_sigma0 = sha256_rotate_right(words[index - 15], 7) ^
            sha256_rotate_right(words[index - 15], 18) ^ (words[index - 15] >> 3);
        uint32_t small_sigma1 = sha256_rotate_right(words[index - 2], 17) ^
            sha256_rotate_right(words[index - 2], 19) ^ (words[index - 2] >> 10);
        words[index] = words[index - 16] + small_sigma0 + words[index - 7] + small_sigma1;
    }

    uint32_t a = state[0];
    uint32_t b = state[1];
    uint32_t c = state[2];
    uint32_t d = state[3];
    uint32_t e = state[4];
    uint32_t f = state[5];
    uint32_t g = state[6];
    uint32_t h = state[7];
    for (int index = 0; index < 64; index++) {
        uint32_t big_sigma1 = sha256_rotate_right(e, 6) ^ sha256_rotate_right(e, 11) ^
            sha256_rotate_right(e, 25);
        uint32_t choose = (e & f) ^ ((~e) & g);
        uint32_t temp1 = h + big_sigma1 + choose + round_constants[index] + words[index];
        uint32_t big_sigma0 = sha256_rotate_right(a, 2) ^ sha256_rotate_right(a, 13) ^
            sha256_rotate_right(a, 22);
        uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
        uint32_t temp2 = big_sigma0 + majority;
        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

static char* sha256_digest(const unsigned char* data, size_t length) {
    static const char hex_digits[] = "0123456789abcdef";
    uint32_t state[8] = {
        0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
        0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
    };
    size_t full_length = length - (length % 64);
    for (size_t offset = 0; offset < full_length; offset += 64) {
        sha256_transform(state, data + offset);
    }

    unsigned char block[128] = {0};
    size_t remainder = length - full_length;
    if (remainder > 0) {
        memcpy(block, data + full_length, remainder);
    }
    block[remainder] = 0x80;
    size_t block_length = remainder < 56 ? 64 : 128;
    uint64_t bit_length = (uint64_t)length * 8;
    for (int index = 0; index < 8; index++) {
        block[block_length - 8 + index] = (unsigned char)(bit_length >> (56 - index * 8));
    }
    sha256_transform(state, block);
    if (block_length == 128) {
        sha256_transform(state, block + 64);
    }

    char* result = (char*)malloc(65);
    if (result == NULL) {
        return NULL;
    }
    for (int index = 0; index < 8; index++) {
        result[index * 8] = hex_digits[(state[index] >> 28) & 0x0f];
        result[index * 8 + 1] = hex_digits[(state[index] >> 24) & 0x0f];
        result[index * 8 + 2] = hex_digits[(state[index] >> 20) & 0x0f];
        result[index * 8 + 3] = hex_digits[(state[index] >> 16) & 0x0f];
        result[index * 8 + 4] = hex_digits[(state[index] >> 12) & 0x0f];
        result[index * 8 + 5] = hex_digits[(state[index] >> 8) & 0x0f];
        result[index * 8 + 6] = hex_digits[(state[index] >> 4) & 0x0f];
        result[index * 8 + 7] = hex_digits[state[index] & 0x0f];
    }
    result[64] = '\0';
    return result;
}

char* __c_crypto_sha256(const char* value) {
    if (value == NULL) {
        return NULL;
    }
    return sha256_digest((const unsigned char*)value, strlen(value));
}

char* __c_crypto_sha256_bytes(const bytes_t* value) {
    if (value == NULL || value->length < 0 ||
        (value->length > 0 && value->data == NULL)) {
        return NULL;
    }
    size_t length = (size_t)value->length;
    unsigned char* data = NULL;
    if (length > 0) {
        data = (unsigned char*)malloc(length);
        if (data == NULL) {
            return NULL;
        }
        for (size_t index = 0; index < length; index++) {
            data[index] = (unsigned char)(value->data[index] & 0xff);
        }
    }
    char* result = sha256_digest(data, length);
    free(data);
    return result;
}
