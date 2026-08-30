#include <stdint.h>
#include <stdlib.h>

typedef struct {
    void* invoke;
    void* environment;
} dream_closure;

void* __c_closure_alloc(int64_t size) {
    if (size < 0) {
        return NULL;
    }
    return calloc(1, (size_t)size);
}

dream_closure* __c_closure_create(void* invoke, void* environment) {
    dream_closure* closure = (dream_closure*)malloc(sizeof(dream_closure));
    if (closure == NULL) {
        return NULL;
    }
    closure->invoke = invoke;
    closure->environment = environment;
    return closure;
}
