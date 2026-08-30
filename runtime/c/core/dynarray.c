#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <execinfo.h>
#include "dynarray.h"
#include "memory.h"

static void debug_out_of_bounds(int index, int length) {
    fprintf(stderr, "Error: index %d out of bounds [0, %d)\n", index, length);
    void* frames[12];
    int frame_count = backtrace(frames, 12);
    char** symbols = backtrace_symbols(frames, frame_count);
    for (int i = 1; i < frame_count; i++) {
        fprintf(stderr, "  at %s\n", symbols[i]);
    }
    free(symbols);
}

// 创建新的动态数组（使用 GC 分配）
dynarray_i32* __c_create_dynarray_i32(int initial_capacity) {
    if (initial_capacity < 0 || initial_capacity > INT_MAX / (int)sizeof(int)) {
        initial_capacity = 0;
    }

    // 使用 GC 分配器分配动态数组结构
    dynarray_i32* arr = (dynarray_i32*)gc_alloc(sizeof(dynarray_i32), OBJ_DYNARRAY);
    if (arr == NULL) {
        return NULL;
    }

    arr->capacity = initial_capacity;
    arr->length = 0;

    if (initial_capacity > 0) {
        arr->data = (int*)malloc(initial_capacity * sizeof(int));
        if (arr->data == NULL) {
            gc_release(arr);
            return NULL;
        }
    } else {
        arr->data = NULL;
    }

    return arr;
}

// 释放动态数组（使用引用计数）
void __c_free_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return;

    // 减少引用计数，可能触发释放
    gc_release(arr);
}

// 保留动态数组引用
void __c_retain_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return;
    gc_retain(arr);
}

// 扩容动态数组内部存储
static int grow_dynarray_i32(dynarray_i32* arr, int new_capacity) {
    if (arr == NULL || new_capacity > INT_MAX / (int)sizeof(int)) {
        return 0;
    }

    if (new_capacity <= arr->capacity) {
        return 1; // 无需扩容
    }

    int* new_data = (int*)malloc(new_capacity * sizeof(int));
    if (new_data == NULL) {
        return 0; // 分配失败
    }

    // 复制旧数据
    if (arr->data != NULL && arr->length > 0) {
        memcpy(new_data, arr->data, arr->length * sizeof(int));
        free(arr->data);
    }

    arr->data = new_data;
    arr->capacity = new_capacity;
    return 1;
}

// 追加元素到动态数组
void __c_append_i32(dynarray_i32* arr, int value) {
    if (arr == NULL) {
        fprintf(stderr, "Error: append to NULL array\n");
        return;
    }

    // 检查是否需要扩容
    if (arr->length >= arr->capacity) {
        // 扩容为原来的 2 倍，最小为 4
        int new_capacity;
        if (arr->capacity == 0) {
            new_capacity = 4;
        } else if (arr->capacity > INT_MAX / 2) {
            new_capacity = INT_MAX / (int)sizeof(int);
        } else {
            new_capacity = arr->capacity * 2;
        }

        if (!grow_dynarray_i32(arr, new_capacity)) {
            fprintf(stderr, "Error: failed to grow array\n");
            return;
        }
    }

    if (arr->length == INT_MAX) {
        fprintf(stderr, "Error: array length overflow\n");
        return;
    }

    // 添加新元素
    arr->data[arr->length] = value;
    arr->length++;
}

void __c_append_f64(dynarray_i32* arr, double value) {
    uint64_t bits = 0;
    memcpy(&bits, &value, sizeof(bits));
    __c_append_i32(arr, (int)(bits & UINT32_MAX));
    __c_append_i32(arr, (int)(bits >> 32));
}

void __c_append_pointer(dynarray_i32* arr, const void* value) {
    uintptr_t bits = (uintptr_t)value;
    __c_append_i32(arr, (int)(bits & UINT32_MAX));
    __c_append_i32(arr, (int)(bits >> 32));
}

// 获取数组元素
int __c_get_dynarray_i32(dynarray_i32* arr, int index) {
    if (arr == NULL) {
        fprintf(stderr, "Error: access NULL array\n");
        return 0;
    }

    if (index < 0 || index >= arr->length) {
        debug_out_of_bounds(index, arr->length);
        return 0;
    }

    return arr->data[index];
}

int __c_contains_dynarray_i32(dynarray_i32* arr, int value) {
    if (arr == NULL) return 0;

    for (int index = 0; index < arr->length; index++) {
        if (arr->data[index] == value) return 1;
    }
    return 0;
}

int __c_contains_dynarray_f64(dynarray_i32* arr, double value) {
    if (arr == NULL || arr->length % 2 != 0) return 0;

    for (int index = 0; index < arr->length / 2; index++) {
        if (__c_get_f64(arr, index) == value) return 1;
    }
    return 0;
}

double __c_get_f64(dynarray_i32* arr, int index) {
    uint64_t low = (uint32_t)__c_get_dynarray_i32(arr, index);
    uint64_t high = (uint32_t)__c_get_dynarray_i32(arr, index + 1);
    uint64_t bits = low | (high << 32);
    double value = 0.0;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

const void* __c_get_pointer(dynarray_i32* arr, int index) {
    uintptr_t low = (uint32_t)__c_get_dynarray_i32(arr, index);
    uintptr_t high = (uint32_t)__c_get_dynarray_i32(arr, index + 1);
    return (const void*)(low | (high << 32));
}

// 设置数组元素
void __c_set_dynarray_i32(dynarray_i32* arr, int index, int value) {
    if (arr == NULL) {
        fprintf(stderr, "Error: access NULL array\n");
        return;
    }

    if (index < 0 || index >= arr->length) {
        debug_out_of_bounds(index, arr->length);
        return;
    }

    arr->data[index] = value;
}

// 获取数组长度
int __c_len_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return 0;
    return arr->length;
}

// 获取数组容量
int __c_capacity_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return 0;
    return arr->capacity;
}

// 清空数组（保留容量）
void __c_clear_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return;
    arr->length = 0;
}

// 预分配容量
int __c_reserve_dynarray_i32(dynarray_i32* arr, int new_capacity) {
    if (arr == NULL) return 0;
    if (new_capacity <= arr->capacity) return 1;

    return grow_dynarray_i32(arr, new_capacity);
}

// 复制动态数组
dynarray_i32* __c_copy_dynarray_i32(dynarray_i32* src) {
    if (src == NULL) return NULL;

    dynarray_i32* dst = __c_create_dynarray_i32(src->length);
    if (dst == NULL) return NULL;

    if (src->length > 0 && src->data != NULL) {
        memcpy(dst->data, src->data, src->length * sizeof(int));
        dst->length = src->length;
    }

    return dst;
}

// 数组切片（创建新数组）
dynarray_i32* __c_slice_dynarray_i32(dynarray_i32* arr, int start, int end) {
    if (arr == NULL) return NULL;

    // 边界检查
    if (start < 0) start = 0;
    if (start > arr->length) start = arr->length;
    if (end < 0) end = 0;
    if (end > arr->length) end = arr->length;
    if (start > end) start = end;
    if (start >= end) {
        return __c_create_dynarray_i32(0);
    }

    int slice_len = end - start;
    dynarray_i32* result = __c_create_dynarray_i32(slice_len);
    if (result == NULL) return NULL;

    if (arr->data != NULL) {
        memcpy(result->data, arr->data + start, slice_len * sizeof(int));
        result->length = slice_len;
    }

    return result;
}

// 连接两个数组（创建新数组）
dynarray_i32* __c_concat_dynarray_i32(dynarray_i32* arr1, dynarray_i32* arr2) {
    if (arr1 == NULL || arr2 == NULL) return NULL;

    if (arr1->length > INT_MAX - arr2->length) {
        return NULL;
    }

    int total_len = arr1->length + arr2->length;
    dynarray_i32* result = __c_create_dynarray_i32(total_len);
    if (result == NULL) return NULL;

    // 复制第一个数组
    if (arr1->length > 0 && arr1->data != NULL) {
        memcpy(result->data, arr1->data, arr1->length * sizeof(int));
    }

    // 复制第二个数组
    if (arr2->length > 0 && arr2->data != NULL) {
        memcpy(result->data + arr1->length, arr2->data, arr2->length * sizeof(int));
    }

    result->length = total_len;
    return result;
}

// 打印数组（用于调试）
void print_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) {
        printf("NULL\n");
        return;
    }

    printf("[");
    for (int i = 0; i < arr->length; i++) {
        if (i > 0) printf(", ");
        printf("%d", arr->data[i]);
    }
    printf("]\n");
}

// ============================================================================
// dynarray_ptr 实现 (用于存储指针，自动适配32/64位)
// ============================================================================

dynarray_ptr* __c_create_dynarray_ptr(int initial_capacity) {
    dynarray_ptr* arr = (dynarray_ptr*)gc_alloc(sizeof(dynarray_ptr), OBJ_DYNARRAY_PTR);
    if (!arr) return NULL;

    if (initial_capacity < 4) initial_capacity = 4;
    if (initial_capacity > INT_MAX / (int)sizeof(intptr_t)) {
        gc_release(arr);
        return NULL;
    }

    arr->capacity = initial_capacity;
    arr->length = 0;
    arr->data = (intptr_t*)malloc(sizeof(intptr_t) * initial_capacity);

    if (!arr->data) {
        gc_release(arr);
        return NULL;
    }

    return arr;
}

void __c_free_dynarray_ptr(dynarray_ptr* arr) {
    if (arr == NULL) return;
    if (gc_is_managed(arr)) {
        gc_release(arr);
        return;
    }
    free(arr->data);
    free(arr);
}

void __c_append_ptr(dynarray_ptr* arr, intptr_t value) {
    if (!arr) return;

    // 扩容
    if (arr->length >= arr->capacity) {
        if (arr->length == INT_MAX || arr->capacity > INT_MAX / 2) {
            return;
        }

        int new_capacity = arr->capacity * 2;
        if (new_capacity > INT_MAX / (int)sizeof(intptr_t)) {
            return;
        }
        intptr_t* new_data = (intptr_t*)realloc(arr->data, sizeof(intptr_t) * new_capacity);
        if (!new_data) return;
        arr->data = new_data;
        arr->capacity = new_capacity;
    }

    arr->data[arr->length++] = value;
    gc_retain_if_managed((void*)value);
}

intptr_t __c_get_dynarray_ptr(dynarray_ptr* arr, int index) {
    if (!arr || index < 0 || index >= arr->length) {
        return 0;
    }
    return arr->data[index];
}

int __c_contains_dynarray_str(dynarray_ptr* arr, const char* value) {
    if (arr == NULL) return 0;

    const char* needle = value == NULL ? "" : value;
    for (int index = 0; index < arr->length; index++) {
        const char* item = (const char*)arr->data[index];
        if (strcmp(item == NULL ? "" : item, needle) == 0) return 1;
    }
    return 0;
}

void __c_set_dynarray_ptr(dynarray_ptr* arr, int index, const void* value) {
    if (!arr || index < 0 || index >= arr->length) {
        return;
    }
    arr->data[index] = (intptr_t)value;
}

int __c_len_dynarray_ptr(dynarray_ptr* arr) {
    return arr ? arr->length : 0;
}

// 数组切片（创建新数组）
dynarray_ptr* __c_slice_dynarray_ptr(dynarray_ptr* arr, int start, int end) {
    if (arr == NULL) return NULL;

    if (start < 0) start = 0;
    if (start > arr->length) start = arr->length;
    if (end < 0) end = 0;
    if (end > arr->length) end = arr->length;
    if (start > end) start = end;
    if (start >= end) {
        return __c_create_dynarray_ptr(0);
    }

    int slice_len = end - start;
    dynarray_ptr* result = __c_create_dynarray_ptr(slice_len);
    if (result == NULL) return NULL;

    if (arr->data != NULL) {
        memcpy(result->data, arr->data + start, slice_len * sizeof(intptr_t));
        result->length = slice_len;
        for (int i = 0; i < slice_len; i++) {
            gc_retain_if_managed((void*)result->data[i]);
        }
    }

    return result;
}

// 连接两个数组（创建新数组）
dynarray_ptr* __c_concat_dynarray_ptr(dynarray_ptr* arr1, dynarray_ptr* arr2) {
    if (arr1 == NULL || arr2 == NULL) return NULL;

    if (arr1->length > INT_MAX - arr2->length) {
        return NULL;
    }

    int total_len = arr1->length + arr2->length;
    dynarray_ptr* result = __c_create_dynarray_ptr(total_len);
    if (result == NULL) return NULL;

    if (arr1->length > 0 && arr1->data != NULL) {
        memcpy(result->data, arr1->data, arr1->length * sizeof(intptr_t));
        for (int i = 0; i < arr1->length; i++) {
            gc_retain_if_managed((void*)result->data[i]);
        }
    }

    if (arr2->length > 0 && arr2->data != NULL) {
        memcpy(result->data + arr1->length, arr2->data, arr2->length * sizeof(intptr_t));
        for (int i = 0; i < arr2->length; i++) {
            gc_retain_if_managed((void*)result->data[i + arr1->length]);
        }
    }

    result->length = total_len;
    return result;
}
