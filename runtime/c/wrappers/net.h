#ifndef DREAM_NET_OPS_H
#define DREAM_NET_OPS_H

#include <stdbool.h>
#include <stdint.h>

int32_t __c_net_connect(const char* host, int32_t port);
int32_t __c_net_write(int32_t fd, const char* content);
char* __c_net_read(int32_t fd, int32_t size);
bool __c_net_close(int32_t fd);

#endif
