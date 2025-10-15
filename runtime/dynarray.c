#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// 对象类型定义（与 memory.c 保持一致）
typedef enum {
    OBJ_DYNARRAY,
    OBJ_STRING,
    OBJ_DICT,
    OBJ_TUPLE,
} ObjectType;

// 声明 GC 函数（在 memory.c 中实现）
extern void* gc_alloc(size_t size, ObjectType type);
extern void gc_retain(void* object);
extern void gc_release(void* object);

// 动态数组结构
typedef struct {
    int capacity;
    int length;
    int* data;
} dynarray_i32;

// 创建新的动态数组（使用 GC 分配）
dynarray_i32* create_dynarray_i32(int initial_capacity) {
    if (initial_capacity < 0) {
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
        int new_capacity = arr->capacity == 0 ? 4 : arr->capacity * 2;

        if (!grow_dynarray_i32(arr, new_capacity)) {
            fprintf(stderr, "Error: failed to grow array\n");
            return;
        }
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
    if (end > arr->length) end = arr->length;
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
