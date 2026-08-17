#define _POSIX_C_SOURCE 200809L

#include "compiler.h"

#include <dirent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static bool has_suffix(const char* value, const char* suffix) {
    size_t value_length = strlen(value);
    size_t suffix_length = strlen(suffix);
    return value_length >= suffix_length &&
        strcmp(value + value_length - suffix_length, suffix) == 0;
}

static bool is_runtime_source(const char* name) {
    return has_suffix(name, ".c") &&
        strncmp(name, "test_", 5) != 0 &&
        strcmp(name, "bytes.c") != 0;
}

static int compare_names(const void* left, const void* right) {
    const char* left_name = *(const char* const*)left;
    const char* right_name = *(const char* const*)right;
    return strcmp(left_name, right_name);
}

static void free_names(char** names, size_t count) {
    for (size_t index = 0; index < count; index++) {
        free(names[index]);
    }
    free(names);
}

static char* join_path(const char* directory, const char* name) {
    size_t directory_length = strlen(directory);
    size_t name_length = strlen(name);
    bool has_separator = directory_length > 0 && directory[directory_length - 1] == '/';
    size_t path_length = directory_length + name_length + (has_separator ? 1 : 2);
    char* path = malloc(path_length);
    if (path == NULL) {
        return NULL;
    }
    snprintf(path, path_length, "%s%s%s", directory, has_separator ? "" : "/", name);
    return path;
}

static bool collect_runtime_sources(const char* runtime_directory, char*** names_out, size_t* count_out) {
    DIR* directory = opendir(runtime_directory);
    if (directory == NULL) {
        return false;
    }

    char** names = NULL;
    size_t count = 0;
    size_t capacity = 0;
    struct dirent* entry;
    while ((entry = readdir(directory)) != NULL) {
        if (!is_runtime_source(entry->d_name)) {
            continue;
        }
        if (count == capacity) {
            size_t next_capacity = capacity == 0 ? 8 : capacity * 2;
            char** next_names = realloc(names, next_capacity * sizeof(char*));
            if (next_names == NULL) {
                closedir(directory);
                free_names(names, count);
                return false;
            }
            names = next_names;
            capacity = next_capacity;
        }
        names[count] = strdup(entry->d_name);
        if (names[count] == NULL) {
            closedir(directory);
            free_names(names, count);
            return false;
        }
        count++;
    }
    closedir(directory);

    qsort(names, count, sizeof(char*), compare_names);
    *names_out = names;
    *count_out = count;
    return true;
}

int __c_build_llvm(const char* llvm_path, const char* output_path) {
    if (llvm_path == NULL || output_path == NULL) {
        return 0;
    }

    const char* runtime_directory = getenv("DREAM_RUNTIME_DIR");
    if (runtime_directory == NULL || runtime_directory[0] == '\0') {
        runtime_directory = "runtime";
    }

    char** runtime_names = NULL;
    size_t runtime_count = 0;
    if (!collect_runtime_sources(runtime_directory, &runtime_names, &runtime_count)) {
        return 0;
    }

    size_t argument_count = 11 + runtime_count;
    char** arguments = calloc(argument_count, sizeof(char*));
    if (arguments == NULL) {
        free_names(runtime_names, runtime_count);
        return 0;
    }

    size_t argument_index = 0;
    arguments[argument_index++] = "clang";
    arguments[argument_index++] = "-Wno-unused-command-line-argument";
    arguments[argument_index++] = "-Wno-override-module";
    arguments[argument_index++] = "-O2";
    arguments[argument_index++] = "-flto=thin";
    arguments[argument_index++] = "-o";
    arguments[argument_index++] = (char*)output_path;
    arguments[argument_index++] = (char*)llvm_path;

    char** runtime_paths = calloc(runtime_count, sizeof(char*));
    if (runtime_paths == NULL) {
        free(arguments);
        free_names(runtime_names, runtime_count);
        return false;
    }
    for (size_t index = 0; index < runtime_count; index++) {
        runtime_paths[index] = join_path(runtime_directory, runtime_names[index]);
        if (runtime_paths[index] == NULL) {
            for (size_t path_index = 0; path_index < index; path_index++) {
                free(runtime_paths[path_index]);
            }
            free(runtime_paths);
            free(arguments);
            free_names(runtime_names, runtime_count);
            return 0;
        }
        arguments[argument_index++] = runtime_paths[index];
    }
    arguments[argument_index++] = "-I";
    arguments[argument_index++] = (char*)runtime_directory;
    arguments[argument_index] = NULL;

    pid_t child_process = fork();
    if (child_process == 0) {
        execvp(arguments[0], arguments);
        _exit(127);
    }
    if (child_process < 0) {
        for (size_t index = 0; index < runtime_count; index++) {
            free(runtime_paths[index]);
        }
        free(runtime_paths);
        free(arguments);
        free_names(runtime_names, runtime_count);
        return 0;
    }

    int child_status = 0;
    bool wait_succeeded = waitpid(child_process, &child_status, 0) == child_process;
    for (size_t index = 0; index < runtime_count; index++) {
        free(runtime_paths[index]);
    }
    free(runtime_paths);
    free(arguments);
    free_names(runtime_names, runtime_count);

    if (!wait_succeeded || !WIFEXITED(child_status) || WEXITSTATUS(child_status) != 0) {
        return 0;
    }
    return remove(llvm_path) == 0 ? 1 : 0;
}

#include <time.h>
#include <stdlib.h>

int __c_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int)(ts.tv_sec * 1000LL + ts.tv_nsec / 1000000);
}

int __c_debug_on(void) {
    return getenv("DEBUG") != NULL;
}

void __c_eprint_text(const char* text) {
    fprintf(stderr, "%s", text);
}

void __c_eprint_int(int value) {
    fprintf(stderr, "%d", value);
}
