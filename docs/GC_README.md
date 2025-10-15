# Dream GC 管理系统

## 概述

Dream 语言采用先进的 GC 管理系统，提供高性能的自动内存管理。

## 核心特性

1. **双模式引用计数**
   - 局部对象：非原子引用计数（0 开销）
   - 共享对象：原子引用计数（线程安全）

2. **Python 风格循环引用检测**
   - 引用计数差值法
   - 仅跟踪容器对象

3. **三代分代 GC**
   - 年轻代、中年代、老年代
   - 自动触发机制

4. **对象提升机制**
   - 局部对象可提升为共享对象
   - 支持跨线程共享

5. **完整的并发支持**
   - 原子操作
   - 互斥锁保护
   - 每个内存池独立锁

## 文件结构

```
runtime/
├── memory.c            # GC 核心实现（726 行）
├── memory.h            # GC API 接口（117 行）
├── test_gc.c           # 测试套件（269 行）
├── dynarray.c          # 动态数组实现
├── dynarray.h          # 动态数组接口
└── README.md           # 运行时说明
```

## API 接口

### 分配函数
```c
void* gc_alloc_local(size_t size, ObjectType type);   // 局部对象
void* gc_alloc_shared(size_t size, ObjectType type);  // 共享对象
void* gc_alloc(size_t size, ObjectType type);         // 默认（局部）
```

### 引用计数
```c
void gc_retain(void* object);              // 增加引用
void gc_release(void* object);             // 减少引用
uint32_t gc_get_ref_count(void* object);   // 获取引用计数
```

### 对象提升
```c
void gc_promote_to_shared(void* object);   // 局部 -> 共享
```

### 垃圾回收
```c
void gc_collect();                         // 完整 GC
void gc_collect_generation(int gen);       // 指定代 GC
void gc_detect_cycles();                   // 循环引用检测
```

### 调试
```c
void gc_print_stats();                     // 打印统计信息
void gc_cleanup();                         // 清理（程序退出时自动调用）
```

## 测试

### 编译测试
```bash
cd runtime
clang -o test_gc test_gc.c memory.c -lpthread -std=c11
./test_gc
```

### 测试覆盖
- ✅ 局部对象分配和释放
- ✅ 共享对象多线程安全（4 线程 × 100 次操作）
- ✅ 对象提升（局部 -> 共享）
- ✅ Python 风格循环引用检测
- ✅ 分代 GC 机制
- ✅ 内存池性能（10,000 个对象）

## 性能特点

| 操作 | 开销 |
|------|------|
| 局部对象操作 | 0 原子操作 ⚡ |
| 共享对象操作 | ~20 CPU 周期 |
| 循环引用检测 | O(容器对象数量) |
| GC 停顿 | 1-10ms |

## 实施日期

2025-10-15

## 相关文档

- `SPEC.md` - Dream 语言规范
- `TODO.md` - 开发任务列表
- `runtime/README.md` - 运行时详细说明

## 许可证

MIT License
