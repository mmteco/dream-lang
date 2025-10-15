# Dream 运行时库

Dream 语言的运行时库，提供类似 Go 的自动内存管理和动态数据结构支持。

## 目录结构

```
runtime/
├── memory.c          # 内存管理核心（GC、内存池）
├── memory.h          # 内存管理 API
├── dynarray.c        # 动态数组实现
├── dynarray.h        # 动态数组 API
├── runtime.c         # 其他运行时函数（print 等）
├── test_memory.c     # 单元测试
├── Makefile          # 构建配置
└── README.md         # 本文档
```

## 核心特性

### 1. 自动内存管理

- **引用计数**: 自动跟踪对象引用，即时释放
- **内存池**: 8 个大小类别的内存池，优化小对象分配
- **标记-清除 GC**: 作为引用计数的补充，处理边缘情况
- **对象跟踪**: 全局链表跟踪所有堆对象

### 2. 动态数组

完整的动态数组实现，支持：
- 自动扩容（容量翻倍策略）
- 元素访问和修改
- 切片（创建子数组）
- 拼接（合并两个数组）
- 复制（深拷贝）
- 引用计数管理

### 3. 性能优化

- **内存池**: 批量分配 64 个对象，减少系统调用
- **智能扩容**: 从 4 开始，每次翻倍
- **O(1) 引用计数**: 常数时间增减引用

## 快速开始

### 编译

```bash
cd runtime
make
```

### 运行测试

```bash
make test

# 输出：
# ✓ All tests passed!
# Total allocations: 1014
# Total frees: 1009
```

### 运行示例

```bash
make example

# 输出包括：
# - 基本数组操作
# - 切片和拼接
# - 引用计数演示
# - 数组复制
# - 动态增长
```

## 使用示例

### 创建和使用数组

```c
#include "dynarray.h"

// 创建数组
dynarray_i32* arr = create_dynarray_i32(10);

// 添加元素
append_i32(arr, 42);
append_i32(arr, 100);

// 访问元素
int value = get_dynarray_i32(arr, 0);  // 42

// 修改元素
set_dynarray_i32(arr, 1, 200);

// 释放
free_dynarray_i32(arr);
```

### 切片和拼接

```c
// 切片 [start:end)
dynarray_i32* slice = slice_dynarray_i32(arr, 1, 4);

// 拼接
dynarray_i32* combined = concat_dynarray_i32(arr1, arr2);
```

### 引用计数

```c
dynarray_i32* arr1 = create_dynarray_i32(5);  // ref_count = 1

// 共享引用
dynarray_i32* arr2 = arr1;
retain_dynarray_i32(arr2);  // ref_count = 2

// 释放
free_dynarray_i32(arr1);  // ref_count = 1
free_dynarray_i32(arr2);  // ref_count = 0, 对象被释放
```

## 内存管理 API

### 分配和释放

```c
void* gc_alloc(size_t size, ObjectType type);
void gc_retain(void* object);
void gc_release(void* object);
uint32_t gc_get_ref_count(void* object);
```

### 垃圾回收

```c
void gc_collect();        // 强制 GC
void gc_print_stats();    // 打印统计
void gc_cleanup();        // 清理所有对象
```

## 动态数组 API

### 创建和销毁

```c
dynarray_i32* create_dynarray_i32(int initial_capacity);
void free_dynarray_i32(dynarray_i32* arr);
void retain_dynarray_i32(dynarray_i32* arr);
```

### 基本操作

```c
void append_i32(dynarray_i32* arr, int value);
int get_dynarray_i32(dynarray_i32* arr, int index);
void set_dynarray_i32(dynarray_i32* arr, int index, int value);
int len_dynarray_i32(dynarray_i32* arr);
int capacity_dynarray_i32(dynarray_i32* arr);
```

### 高级操作

```c
void clear_dynarray_i32(dynarray_i32* arr);
int reserve_dynarray_i32(dynarray_i32* arr, int new_capacity);
dynarray_i32* copy_dynarray_i32(dynarray_i32* src);
dynarray_i32* slice_dynarray_i32(dynarray_i32* arr, int start, int end);
dynarray_i32* concat_dynarray_i32(dynarray_i32* arr1, dynarray_i32* arr2);
void print_dynarray_i32(dynarray_i32* arr);
```

## 内存池配置

8 个大小类别（字节）：
- 16, 32, 64, 128, 256, 512, 1024, 2048

超过 2048 字节的对象直接从系统分配。

## 性能指标

基于 `test_memory` 的压力测试结果（1000 个数组）：

- **总分配**: 1014 次
- **总释放**: 1009 次
- **分配字节**: 40560
- **释放字节**: 40360
- **GC 运行**: 1 次
- **平均对象大小**: ~40 字节

## 内存安全

### 已实现

- ✅ 自动引用计数
- ✅ 双重释放检测（断言）
- ✅ 边界检查（数组访问）
- ✅ 内存泄漏检测
- ✅ 对象类型标记

### 未来计划

- [ ] 弱引用（解决循环引用）
- [ ] 线程安全（原子引用计数）
- [ ] 边界保护（溢出检测）
- [ ] 地址消毒器集成

## 调试

### 打印统计信息

```c
gc_print_stats();

// 输出：
// === GC Statistics ===
// Total allocations: 100
// Total frees: 95
// Bytes allocated: 4000
// Bytes freed: 3800
// GC runs: 2
// Objects collected: 5
// Live objects: 5
// ====================
```

### 内存泄漏检测

程序退出时调用 `gc_cleanup()`，会报告泄漏的对象数量：

```
Warning: 5 objects leaked
```

### 引用计数调试

```c
uint32_t ref_count = gc_get_ref_count(obj);
printf("Ref count: %u\n", ref_count);
```

## 与 Go 内存管理的对比

| 特性 | Dream | Go |
|-----|-------|-----|
| 分配器 | 内存池 + malloc | mcache + mcentral + mheap |
| GC 算法 | 引用计数 + 标记清除 | 三色标记 + 并发清除 |
| 并发支持 | 单线程 | 并发 GC |
| 对象头 | 20 字节 | 16 字节 |
| 写屏障 | 无 | 有 |
| 适用场景 | 嵌入式、脚本 | 服务器、高并发 |

## 设计文档

详细的设计说明请参考 `MEMORY_MANAGEMENT.md`。

## 许可证

MIT License
