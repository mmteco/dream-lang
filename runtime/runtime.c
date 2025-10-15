#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void print_int(int value) {
    printf("%d\n", value);
}

int string_length(const char* str) {
    return strlen(str);
}

char string_char_at(const char* str, int index) {
    return str[index];
}

char* string_concat(const char* s1, const char* s2) {
    int len1 = strlen(s1);
    int len2 = strlen(s2);
    char* result = (char*)malloc(len1 + len2 + 1);
    if (result == NULL) return NULL;
    strcpy(result, s1);
    strcat(result, s2);
    return result;
}

char* string_substring(const char* str, int start, int end) {
    int len = end - start;
    if (len < 0) len = 0;
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return NULL;
    strncpy(result, str + start, len);
    result[len] = '\0';
    return result;
}

int string_find(const char* str, const char* sub) {
    const char* pos = strstr(str, sub);
    if (pos == NULL) return -1;
    return pos - str;
}

int string_compare(const char* s1, const char* s2) {
    return strcmp(s1, s2);
}

char* string_upper(const char* str) {
    int len = strlen(str);
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return NULL;
    for (int i = 0; i < len; i++) {
        result[i] = toupper(str[i]);
    }
    result[len] = '\0';
    return result;
}

char* string_lower(const char* str) {
    int len = strlen(str);
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return NULL;
    for (int i = 0; i < len; i++) {
        result[i] = tolower(str[i]);
    }
    result[len] = '\0';
    return result;
}

char* string_strip(const char* str) {
    if (str == NULL || *str == '\0') {
        char* result = (char*)malloc(1);
        result[0] = '\0';
        return result;
    }

    const char* start = str;
    while (isspace(*start)) start++;

    if (*start == '\0') {
        char* result = (char*)malloc(1);
        result[0] = '\0';
        return result;
    }

    const char* end = str + strlen(str) - 1;
    while (end > start && isspace(*end)) end--;

    int len = end - start + 1;
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return NULL;
    strncpy(result, start, len);
    result[len] = '\0';
    return result;
}

int string_starts_with(const char* str, const char* prefix) {
    int len = strlen(prefix);
    return strncmp(str, prefix, len) == 0 ? 1 : 0;
}

int string_ends_with(const char* str, const char* suffix) {
    int str_len = strlen(str);
    int suffix_len = strlen(suffix);
    if (suffix_len > str_len) return 0;
    return strcmp(str + str_len - suffix_len, suffix) == 0 ? 1 : 0;
}

char* string_replace(const char* str, const char* old, const char* new_str) {
    if (str == NULL || old == NULL || new_str == NULL) return NULL;
    if (*old == '\0') {
        char* result = (char*)malloc(strlen(str) + 1);
        strcpy(result, str);
        return result;
    }

    int old_len = strlen(old);
    int new_len = strlen(new_str);
    int count = 0;

    const char* p = str;
    while ((p = strstr(p, old)) != NULL) {
        count++;
        p += old_len;
    }

    if (count == 0) {
        char* result = (char*)malloc(strlen(str) + 1);
        strcpy(result, str);
        return result;
    }

    int result_len = strlen(str) + count * (new_len - old_len);
    char* result = (char*)malloc(result_len + 1);
    if (result == NULL) return NULL;

    char* dst = result;
    p = str;
    while (*p) {
        const char* q = strstr(p, old);
        if (q == NULL) {
            strcpy(dst, p);
            break;
        }

        strncpy(dst, p, q - p);
        dst += (q - p);

        strcpy(dst, new_str);
        dst += new_len;

        p = q + old_len;
    }

    return result;
}

int string_is_digit(char c) {
    return isdigit(c) ? 1 : 0;
}

int string_is_alpha(char c) {
    return isalpha(c) ? 1 : 0;
}

int string_is_whitespace(char c) {
    return isspace(c) ? 1 : 0;
}

char* file_read(const char* path) {
    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = (char*)malloc(file_size + 1);
    if (buffer == NULL) {
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, file_size, file);
    buffer[bytes_read] = '\0';

    fclose(file);
    return buffer;
}

int file_write(const char* path, const char* content) {
    FILE* file = fopen(path, "w");
    if (file == NULL) {
        return 0;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return written == len ? 1 : 0;
}

int file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file == NULL) {
        return 0;
    }
    fclose(file);
    return 1;
}

int file_append(const char* path, const char* content) {
    FILE* file = fopen(path, "a");
    if (file == NULL) {
        return 0;
    }

    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, file);

    fclose(file);
    return written == len ? 1 : 0;
}

int file_delete(const char* path) {
    return remove(path) == 0 ? 1 : 0;
}
