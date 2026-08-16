#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include "dynarray.h"
#include "memory.h"

// 创建新的动态数组（使用 GC 分配）
dynarray_i32* create_dynarray_i32(int initial_capacity) {
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
void free_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return;

    // 减少引用计数，可能触发释放
    gc_release(arr);
}

// 保留动态数组引用
void retain_dynarray_i32(dynarray_i32* arr) {
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
void append_i32(dynarray_i32* arr, int value) {
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

// 获取数组元素
int get_dynarray_i32(dynarray_i32* arr, int index) {
    if (arr == NULL) {
        fprintf(stderr, "Error: access NULL array\n");
        return 0;
    }

    if (index < 0 || index >= arr->length) {
        fprintf(stderr, "Error: index %d out of bounds [0, %d)\n", index, arr->length);
        return 0;
    }

    return arr->data[index];
}

// 设置数组元素
void set_dynarray_i32(dynarray_i32* arr, int index, int value) {
    if (arr == NULL) {
        fprintf(stderr, "Error: access NULL array\n");
        return;
    }

    if (index < 0 || index >= arr->length) {
        fprintf(stderr, "Error: index %d out of bounds [0, %d)\n", index, arr->length);
        return;
    }

    arr->data[index] = value;
}

// 获取数组长度
int len_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return 0;
    return arr->length;
}

// 获取数组容量
int capacity_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return 0;
    return arr->capacity;
}

// 清空数组（保留容量）
void clear_dynarray_i32(dynarray_i32* arr) {
    if (arr == NULL) return;
    arr->length = 0;
}

// 预分配容量
int reserve_dynarray_i32(dynarray_i32* arr, int new_capacity) {
    if (arr == NULL) return 0;
    if (new_capacity <= arr->capacity) return 1;

    return grow_dynarray_i32(arr, new_capacity);
}

// 复制动态数组
dynarray_i32* copy_dynarray_i32(dynarray_i32* src) {
    if (src == NULL) return NULL;

    dynarray_i32* dst = create_dynarray_i32(src->length);
    if (dst == NULL) return NULL;

    if (src->length > 0 && src->data != NULL) {
        memcpy(dst->data, src->data, src->length * sizeof(int));
        dst->length = src->length;
    }

    return dst;
}

// 数组切片（创建新数组）
dynarray_i32* slice_dynarray_i32(dynarray_i32* arr, int start, int end) {
    if (arr == NULL) return NULL;

    // 边界检查
    if (start < 0) start = 0;
    if (start > arr->length) start = arr->length;
    if (end < 0) end = 0;
    if (end > arr->length) end = arr->length;
    if (start > end) start = end;
    if (start >= end) {
        return create_dynarray_i32(0);
    }

    int slice_len = end - start;
    dynarray_i32* result = create_dynarray_i32(slice_len);
    if (result == NULL) return NULL;

    if (arr->data != NULL) {
        memcpy(result->data, arr->data + start, slice_len * sizeof(int));
        result->length = slice_len;
    }

    return result;
}

// 连接两个数组（创建新数组）
dynarray_i32* concat_dynarray_i32(dynarray_i32* arr1, dynarray_i32* arr2) {
    if (arr1 == NULL || arr2 == NULL) return NULL;

    if (arr1->length > INT_MAX - arr2->length) {
        return NULL;
    }

    int total_len = arr1->length + arr2->length;
    dynarray_i32* result = create_dynarray_i32(total_len);
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

dynarray_ptr* create_dynarray_ptr(int initial_capacity) {
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

void free_dynarray_ptr(dynarray_ptr* arr) {
    if (arr == NULL) return;
    if (gc_is_managed(arr)) {
        gc_release(arr);
        return;
    }
    free(arr->data);
    free(arr);
}

void append_ptr(dynarray_ptr* arr, intptr_t value) {
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

intptr_t get_dynarray_ptr(dynarray_ptr* arr, int index) {
    if (!arr || index < 0 || index >= arr->length) {
        return 0;
    }
    return arr->data[index];
}

int len_dynarray_ptr(dynarray_ptr* arr) {
    return arr ? arr->length : 0;
}
