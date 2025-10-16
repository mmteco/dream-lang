#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "string_ops.h"
#include "dynarray.h"
#include "memory.h"

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

dynarray_ptr* string_split(const char* str, const char* delimiter) {
    if (str == NULL || delimiter == NULL) return NULL;

    dynarray_ptr* result = create_dynarray_ptr(10);

    if (*delimiter == '\0') {
        int len = strlen(str);
        for (int i = 0; i < len; i++) {
            char* single_char = (char*)gc_alloc(2, OBJ_STRING);
            single_char[0] = str[i];
            single_char[1] = '\0';
            append_ptr(result, (intptr_t)single_char);
        }
        return result;
    }

    int delim_len = strlen(delimiter);
    const char* current = str;
    const char* next;

    while ((next = strstr(current, delimiter)) != NULL) {
        int segment_len = next - current;
        char* segment = (char*)gc_alloc(segment_len + 1, OBJ_STRING);
        if (segment == NULL) {
            free_dynarray_ptr(result);
            return NULL;
        }
        strncpy(segment, current, segment_len);
        segment[segment_len] = '\0';
        append_ptr(result, (intptr_t)segment);
        current = next + delim_len;
    }

    int remaining_len = strlen(current);
    char* last_segment = (char*)gc_alloc(remaining_len + 1, OBJ_STRING);
    if (last_segment == NULL) {
        free_dynarray_ptr(result);
        return NULL;
    }
    strcpy(last_segment, current);
    append_ptr(result, (intptr_t)last_segment);

    return result;
}

char* string_join(dynarray_ptr* arr, const char* separator) {
    if (arr == NULL || separator == NULL) return NULL;

    int arr_len = len_dynarray_ptr(arr);
    if (arr_len == 0) {
        char* empty = (char*)gc_alloc(1, OBJ_STRING);
        empty[0] = '\0';
        return empty;
    }

    int sep_len = strlen(separator);
    int total_len = 0;

    for (int i = 0; i < arr_len; i++) {
        const char* str = (const char*)get_dynarray_ptr(arr, i);
        if (str != NULL) {
            total_len += strlen(str);
        }
    }

    total_len += sep_len * (arr_len - 1);

    char* result = (char*)gc_alloc(total_len + 1, OBJ_STRING);
    if (result == NULL) return NULL;

    result[0] = '\0';
    for (int i = 0; i < arr_len; i++) {
        const char* str = (const char*)get_dynarray_ptr(arr, i);
        if (str != NULL) {
            strcat(result, str);
        }
        if (i < arr_len - 1) {
            strcat(result, separator);
        }
    }

    return result;
}
