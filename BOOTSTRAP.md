# Dream 语言自举路线图

## 目标
用 Dream 语言重新实现 Dream 编译器，实现自举（self-hosting）。

---

## 已完成基础 ✅

- [x] 基础类型系统（int, float, string, bool）
- [x] 函数定义、调用、递归
- [x] 控制流（if/else, while, for）
- [x] 数组操作（索引、切片、拼接、列表推导式）
- [x] 动态内存管理（引用计数 + 分代GC）
- [x] LLVM IR 代码生成
- [x] 字典类型（int->int，FNV-1a 哈希）✅ (2025-10)
- [x] 元组解包（let、for 循环）✅ (2025-10)
- [x] Runtime 模块化（string_ops, file_ops, dict, tuple, dynarray, memory）✅ (2025-10)

---

## 第一阶段：核心数据结构 (P0)

### 1. 字符串增强 🔴 **高优先级**
**Runtime 已实现** (`runtime/string_ops.c`)，需添加语言层绑定：
- [ ] 字符串索引 `s[i]`、切片 `s[start:end]`
- [ ] `split()`, `join()`, `find()`, `replace()`
- [ ] `strip()`, `upper()`, `lower()`
- [ ] `starts_with()`, `ends_with()`
- [ ] `is_digit()`, `is_alpha()`, `is_whitespace()`

### 2. 文件 I/O 🔴 **高优先级**
**Runtime 已实现** (`runtime/file_ops.c`)，需添加语言层绑定：
- [ ] `file_read(path)`, `file_write(path, content)`
- [ ] `file_exists(path)`, `file_append(path, content)`
- [ ] `file_delete(path)`

### 3. 错误处理
- [ ] Result 类型 `Result[T, E] = Ok(T) | Err(E)`
- [ ] Option 类型 `Option[T] = Some(T) | None`
- [ ] 错误传播语法 `?`

### 4. 字典类型 ✅ **完全泛型化完成**
**已实现功能**：
- [x] 字典字面量 `{1: 10, 2: 20}` (整数键)
- [x] 字典字面量 `{"name": 100, "age": 25}` (字符串键) ✅ (2025-10)
- [x] 字典字面量 `{1: "Alice", 2: "Bob"}` (字符串值) ✅ (2025-10)
- [x] 字典字面量 `{"name": "Alice"}` (字符串键值对) ✅ (2025-10)
- [x] 字典索引 `dict[key]`、赋值 `dict[key] = value`
- [x] `dict_keys()`, `dict_values()`, `dict_items()`
- [x] `for (k, v) in dict_items(d)` 迭代
- [x] FNV-1a 哈希算法
- [x] 64位指针安全（dynarray_ptr 使用 intptr_t）
- [x] 泛型值类型 `dict[int, string]`, `dict[string, string]` ✅ (2025-10)
- [x] **统一泛型实现** - 单一 dict_t 结构，参考 Golang 设计 ✅ (2025-10)
- [x] **Runtime 层完全泛型化** - void* + 类型元数据，消除重复代码 ✅ (2025-10)
- [x] **LLVM 代码生成器重构** - 统一 API (dict_set_int_int, dict_set_str_str 等) ✅ (2025-10)

### 5. 元组类型 ✅ **完整功能完成**
**已实现功能**：
- [x] 元组结构 `tuple2_i32` 和通用 `tuple_t`
- [x] `let (a, b) = tuple` 解包
- [x] `for (k, v) in items` 解包
- [x] `dict_items()` 返回元组数组
- [x] 元组字面量 `(1, 2, 3)` ✅ (2025-10)
- [x] 元组索引 `tuple[0]` ✅ (2025-10)
- [x] 任意长度元组支持 (基于 void* + size 的通用结构) ✅ (2025-10)

---

## 第二阶段：语言特性 (P1)

### 6. 枚举类型 🔴 **编译器核心依赖**
Token、AST 节点必需：
- [ ] `enum Token { INT(int), STRING(string), PLUS, ... }`
- [ ] 枚举构造器、模式匹配
- [ ] 递归枚举（AST）

### 7. 模式匹配
- [ ] match 表达式基础语法
- [ ] 值匹配、元组解构、列表解构
- [ ] 守卫条件 `case x if x > 0:`
- [ ] 穷尽性检查

### 8. 结构体
- [ ] `struct Position { line: int, column: int }`
- [ ] 结构体字面量、字段访问

### 9. 泛型系统 ✅ **基础功能完成** (2025-10)
**已实现功能**：
- [x] 函数泛型 `def identity[T](x: T) -> T`
- [x] 类型参数语法解析
- [x] 单态化代码生成
- [x] 泛型函数实例化

**待完成功能**：
- [ ] 类型参数约束
- [ ] 高阶泛型 `def map[T, U](...)`
- [ ] 泛型结构体和枚举

---

## 第三阶段：编译器重写 (P2)

### 10. Lexer（词法分析器）
依赖：枚举、字符串、结构体
- [ ] Token 枚举定义
- [ ] 缩进处理（INDENT/DEDENT）
- [ ] 字符串/数字字面量解析

### 11. Parser（语法分析器）
依赖：枚举、递归类型、模式匹配
- [ ] AST 节点定义
- [ ] 递归下降解析器
- [ ] 错误恢复

### 12. Type Checker（类型检查）
依赖：枚举、字典、泛型
- [ ] Hindley-Milner 类型推导
- [ ] 类型统一算法

### 13. LLVM IR Generator
依赖：字符串构建器、字典、模式匹配
- [ ] IR 字符串生成
- [ ] AST → LLVM 映射

---

## 第四阶段：自举验证 (P3)

### 14. 自举编译
- [ ] OCaml 编译器 → Dream 编译器 v1
- [ ] v1 → v2 → v3
- [ ] v2 == v3（bit-for-bit）

---

## 实现优先级

### 立即开始（P0）
1. ✅ ~~字典类型~~ (已完成)
2. ✅ ~~元组解包~~ (已完成)
3. 🔴 **字符串操作** - Runtime 已有，添加语言绑定
4. 🔴 **文件 I/O** - Runtime 已有，添加语言绑定
5. 🔴 **枚举类型** - 编译器核心依赖

### 短期目标（P1）
6. 模式匹配
7. 结构体
8. 泛型系统

### 中期目标（P2）
9. Lexer 重写
10. Parser 重写
11. Type Checker 重写
12. LLVM IR Generator 重写

### 长期目标（P3）
13. 自举编译
14. 性能优化

---

## 技术挑战与解决方案

1. **循环依赖**: 字典→泛型→编译器→字典
   - 解决：先用固定类型字典 ✅，后期泛型化

2. **内存管理**: 编译器产生大量临时对象
   - 解决：依赖现有 GC ✅，考虑 Arena 分配器

3. **FFI**: 调用 C 库（文件 I/O）
   - 解决：LLVM IR 直接调用 libc，Runtime 已实现 ✅

---

## 时间估算

**最小化路径**（跳过高级特性）：
- 阶段一：3-4 周
- 阶段二：4-5 周
- 阶段三：6-8 周
- 阶段四：1-2 周

**总计：14-19 周（约 3.5-5 个月）**

---

## 下一步行动

**立即开始**：
```
字符串操作 → 文件 I/O → 枚举类型 →
模式匹配 → 结构体 → Lexer 重写
```

**进度追踪**: 见 TODO.md

---

## 成功标准

1. ✅ Dream 编译器完全用 Dream 编写
2. ✅ v2 和 v3 二进制完全一致
3. ✅ 通过所有测试用例
4. ✅ 性能与 OCaml 版本相当
