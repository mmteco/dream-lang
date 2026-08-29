#include "net.h"

#include "memory.h"

#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

static char* net_empty_string(void) {
    char* result = (char*)gc_alloc(1, OBJ_STRING);
    if (result != NULL) {
        result[0] = '\0';
    }
    return result;
}

int32_t __c_net_connect(const char* host, int32_t port) {
    if (host == NULL || host[0] == '\0' || port <= 0 || port > 65535) {
        return -1;
    }

    char port_text[6];
    int port_length = snprintf(port_text, sizeof(port_text), "%d", port);
    if (port_length <= 0 || port_length >= (int)sizeof(port_text)) {
        return -1;
    }

    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_family = AF_UNSPEC;

    struct addrinfo* addresses = NULL;
    if (getaddrinfo(host, port_text, &hints, &addresses) != 0) {
        return -1;
    }

    int32_t connected_fd = -1;
    for (struct addrinfo* address = addresses; address != NULL; address = address->ai_next) {
        int fd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (fd < 0) {
            continue;
        }

#ifdef SO_NOSIGPIPE
        int no_sigpipe = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &no_sigpipe, sizeof(no_sigpipe));
#endif

        if (connect(fd, address->ai_addr, address->ai_addrlen) == 0) {
            connected_fd = fd;
            break;
        }

        close(fd);
    }

    freeaddrinfo(addresses);
    return connected_fd;
}

int32_t __c_net_write(int32_t fd, const char* content) {
    if (fd < 0 || content == NULL) {
        return -1;
    }

    size_t content_length = strlen(content);
    if (content_length > INT_MAX) {
        return -1;
    }

    size_t sent_length = 0;
    while (sent_length < content_length) {
        int flags = 0;
#ifdef MSG_NOSIGNAL
        flags |= MSG_NOSIGNAL;
#endif
        ssize_t sent = send(fd, content + sent_length, content_length - sent_length, flags);
        if (sent <= 0) {
            return -1;
        }
        sent_length += (size_t)sent;
    }

    return (int32_t)sent_length;
}

char* __c_net_read(int32_t fd, int32_t size) {
    if (fd < 0 || size <= 0) {
        return net_empty_string();
    }

    char* buffer = (char*)malloc((size_t)size);
    if (buffer == NULL) {
        return NULL;
    }

    ssize_t received = recv(fd, buffer, (size_t)size, 0);
    if (received < 0) {
        free(buffer);
        return NULL;
    }
    if (received == 0) {
        free(buffer);
        return net_empty_string();
    }

    char* result = (char*)gc_alloc((size_t)received + 1, OBJ_STRING);
    if (result == NULL) {
        free(buffer);
        return NULL;
    }

    memcpy(result, buffer, (size_t)received);
    result[received] = '\0';
    free(buffer);
    return result;
}

bool __c_net_close(int32_t fd) {
    if (fd < 0) {
        return false;
    }
    return close(fd) == 0;
}
