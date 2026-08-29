#include "http.h"

#include "memory.h"

#include <curl/curl.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char* data;
    size_t length;
    size_t capacity;
} HttpBuffer;

static pthread_once_t curl_once = PTHREAD_ONCE_INIT;
static CURLcode curl_init_result = CURLE_FAILED_INIT;

static void initialize_curl(void) {
    curl_init_result = curl_global_init(CURL_GLOBAL_DEFAULT);
}

static bool buffer_reserve(HttpBuffer* buffer, size_t additional) {
    if (additional > SIZE_MAX - buffer->length - 1) {
        return false;
    }

    size_t required = buffer->length + additional + 1;
    if (required <= buffer->capacity) {
        return true;
    }

    size_t capacity = buffer->capacity == 0 ? 4096 : buffer->capacity;
    while (capacity < required) {
        if (capacity > SIZE_MAX / 2) {
            capacity = required;
            break;
        }
        capacity *= 2;
    }

    char* data = realloc(buffer->data, capacity);
    if (data == NULL) {
        return false;
    }
    buffer->data = data;
    buffer->capacity = capacity;
    return true;
}

static bool buffer_append(HttpBuffer* buffer, const char* data, size_t length) {
    if (!buffer_reserve(buffer, length)) {
        return false;
    }
    memcpy(buffer->data + buffer->length, data, length);
    buffer->length += length;
    buffer->data[buffer->length] = '\0';
    return true;
}

static size_t write_body(char* data, size_t size, size_t count, void* user_data) {
    HttpBuffer* buffer = user_data;
    size_t length = size * count;
    return buffer_append(buffer, data, length) ? length : 0;
}

static size_t write_headers(char* data, size_t size, size_t count, void* user_data) {
    HttpBuffer* buffer = user_data;
    size_t length = size * count;
    if (length >= 5 && memcmp(data, "HTTP/", 5) == 0) {
        buffer->length = 0;
        if (buffer->data != NULL) {
            buffer->data[0] = '\0';
        }
    }
    for (size_t index = 0; index < length; index++) {
        if (data[index] == '\n' &&
            (index == 0 || data[index - 1] != '\r') &&
            (buffer->length == 0 || buffer->data[buffer->length - 1] != '\r')) {
            char carriage_return = '\r';
            if (!buffer_append(buffer, &carriage_return, 1)) {
                return 0;
            }
        }
        if (!buffer_append(buffer, data + index, 1)) {
            return 0;
        }
    }
    return length;
}

static struct curl_slist* parse_headers(const char* headers) {
    struct curl_slist* result = NULL;
    if (headers == NULL) {
        return NULL;
    }

    const char* line_start = headers;
    while (*line_start != '\0') {
        const char* line_end = strstr(line_start, "\r\n");
        size_t line_length = line_end == NULL
            ? strlen(line_start)
            : (size_t)(line_end - line_start);
        if (line_length > 0) {
            char* line = malloc(line_length + 1);
            if (line == NULL) {
                curl_slist_free_all(result);
                return NULL;
            }
            memcpy(line, line_start, line_length);
            line[line_length] = '\0';
            struct curl_slist* next = curl_slist_append(result, line);
            free(line);
            if (next == NULL) {
                curl_slist_free_all(result);
                return NULL;
            }
            result = next;
        }
        if (line_end == NULL) {
            break;
        }
        line_start = line_end + 2;
    }
    return result;
}

static char* managed_string(const char* data, size_t length) {
    char* result = gc_alloc(length + 1, OBJ_STRING);
    if (result == NULL) {
        return NULL;
    }
    memcpy(result, data, length);
    result[length] = '\0';
    return result;
}

static char* error_response(const char* message) {
    const char* prefix = "HTTP/1.1 599 Curl Error\r\n\r\n";
    size_t prefix_length = strlen(prefix);
    size_t message_length = strlen(message);
    char* result = malloc(prefix_length + message_length + 1);
    if (result == NULL) {
        return NULL;
    }
    memcpy(result, prefix, prefix_length);
    memcpy(result + prefix_length, message, message_length + 1);
    char* managed = managed_string(result, prefix_length + message_length);
    free(result);
    return managed;
}

char* __c_http_request(const char* method, const char* url,
    const char* headers, const char* body) {
    if (method == NULL || url == NULL || method[0] == '\0' || url[0] == '\0') {
        return error_response("invalid HTTP method or URL");
    }

    pthread_once(&curl_once, initialize_curl);
    if (curl_init_result != CURLE_OK) {
        return error_response(curl_easy_strerror(curl_init_result));
    }

    CURL* curl = curl_easy_init();
    if (curl == NULL) {
        return error_response("failed to initialize curl");
    }

    HttpBuffer header_buffer = {0};
    HttpBuffer body_buffer = {0};
    struct curl_slist* request_headers = parse_headers(headers);
    if (headers != NULL && headers[0] != '\0' && request_headers == NULL) {
        curl_easy_cleanup(curl);
        return error_response("failed to allocate HTTP headers");
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 10L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, 10000L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, 30000L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "dream-http/1.0");
    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, write_headers);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &header_buffer);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_body);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body_buffer);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, request_headers);

    if (strcmp(method, "POST") == 0 || strcmp(method, "PUT") == 0 ||
        strcmp(method, "PATCH") == 0) {
        const char* request_body = body == NULL ? "" : body;
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, request_body);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(request_body));
    }

    CURLcode result = curl_easy_perform(curl);
    char* response = NULL;
    if (result != CURLE_OK) {
        response = error_response(curl_easy_strerror(result));
    } else if (header_buffer.data == NULL || header_buffer.length == 0) {
        response = error_response("HTTP response did not contain headers");
    } else if (buffer_reserve(&header_buffer, body_buffer.length + 1) &&
        buffer_append(&header_buffer, body_buffer.data == NULL ? "" : body_buffer.data,
            body_buffer.length)) {
        response = managed_string(header_buffer.data, header_buffer.length);
    } else {
        response = error_response("failed to allocate HTTP response");
    }

    free(header_buffer.data);
    free(body_buffer.data);
    curl_slist_free_all(request_headers);
    curl_easy_cleanup(curl);
    return response;
}
