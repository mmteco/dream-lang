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
- [x] 小写布尔和None关键字（true/false/none 支持）✅ (2025-10)
- [x] print(bool) 函数支持（输出小写 true/false）✅ (2025-10)

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

### 3. 错误处理 ✅ **枚举实现完成** (2025-10)
- [x] Option 类型 `Option[T] = Some(T) | Nothing` (使用标准枚举)
- [x] Result 类型 `Result[T, E] = Success(T) | Failure(E)` (使用标准枚举)
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

### 6. 枚举类型 ✅ **完整功能完成** (2025-10)
**已实现功能**：
- [x] 枚举定义语法 `enum Color { Red, Green, Blue }`
- [x] 带数据的枚举 `enum Shape { Circle(int), Rectangle(int, int) }`
- [x] 泛型枚举 `enum Maybe[T] { Just(T), Nothing }`（语法解析）
- [x] 枚举构造器 `Color.Red`, `Shape.Circle(5)`, `Shape.Rectangle(10, 20)`
- [x] 模式匹配语法和类型检查
- [x] **Runtime 层 Tagged Union 实现** ✅
  - [x] enum.h/enum.c（enum_t 结构）
  - [x] enum_create_simple/int/string/bool 函数
  - [x] enum_create_tuple_ptr 函数（多参数变体）
  - [x] enum_get_tag/int/string/bool/data 函数
  - [x] enum_is_variant 类型检查函数
  - [x] enum_print_value 输出函数
- [x] **LLVM 代码生成器集成** ✅
  - [x] 枚举注册表（enum_registry）
  - [x] 单参数变体代码生成
  - [x] 多参数变体代码生成（使用元组存储）
  - [x] 枚举构造器代码生成（EEnumVariant）
  - [x] 枚举模式匹配代码生成（PEnumVariant）
  - [x] %enum_t 类型定义
  - [x] enum runtime 函数声明
  - [x] 链接 enum.c 到可执行文件
- [x] **模式匹配数据提取** ✅ (2025-10)
  - [x] 单参数变体数据提取：`Circle(r)` → 绑定 r
  - [x] 多参数变体数据提取：`Rectangle(w, h)` → 绑定 w, h
  - [x] 变量重命名机制（避免 LLVM IR 名称冲突）
  - [x] gen_pattern_bindings 函数集成
- [x] **GC 集成** ✅
  - [x] OBJ_ENUM 类型添加到 GC 系统
  - [x] enum_create_xxx 使用 gc_alloc
  - [x] 自动引用计数管理
  - [x] 内存清理（enum_release 时释放数据指针）

**待完成功能**：
- [ ] 递归枚举（AST 节点类型）
- [ ] 穷尽性检查
- [ ] 枚举方法支持

### 7. 模式匹配 ✅ **核心功能完成** (2025-10)
**已实现功能**：
- [x] match 语句和表达式语法
- [x] case 关键字现在可选
- [x] 整数、字符串、布尔值匹配
- [x] 元组解构
- [x] 枚举变体匹配 `Color.Red`
- [x] **枚举变体带数据的模式匹配** ✅ (2025-10)
  - [x] 单参数变体：`Circle(r)` → 提取 r 并绑定
  - [x] 多参数变体：`Rectangle(w, h)` → 提取 w, h 并绑定
- [x] 通配符模式 `_`
- [x] 变量模式绑定 `PVar`
- [x] 类型检查和环境绑定
- [x] **LLVM 代码生成** ✅
  - [x] SMatch 语句生成（基本块 + 条件跳转）
  - [x] EMatch 表达式生成（phi 节点）
  - [x] gen_pattern_test（模式测试条件生成）
  - [x] gen_pattern_bindings（模式变量绑定，包括枚举数据提取）
- [x] **守卫条件 `if` 子句** ✅ (2025-10)
  - [x] 解析器支持 `pattern if guard_expr:` 语法
  - [x] AST 扩展（EMatch 和 SMatch 的 case 支持可选守卫）
  - [x] 类型检查器验证守卫表达式为布尔类型
  - [x] LLVM 代码生成（守卫失败跳转到下一个 case）
  - [x] 完整的测试用例（test_match_guard.dm）

**待完成功能**：
- [ ] 列表解构
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

### 10. Union 类型 ✅ **完整功能完成** (2025-10)

**设计方案**：支持两种模式
1. **编译时类型特化**（默认）：零运行时开销
2. **运行时多态**（显式类型注解）：真正的类型多态

**已实现功能**：
- [x] Union 类型语法 `int | string | bool`
- [x] 自动扁平化嵌套 union
- [x] 类型统一算法（子类型兼容性）
- [x] 函数参数 union 类型支持 ✅
- [x] 变量声明 union 类型支持 ✅
- [x] 完整的编译时类型检查 ✅
- [x] **Runtime 层 Tagged Union 实现** ✅
  - [x] union.h/union.c（union_t 结构）
  - [x] union_create_int/float/string/bool/none
  - [x] union_is_xxx 类型检查函数
  - [x] union_get_xxx 值提取函数
  - [x] union_print_value 输出函数 ✅
  - [x] 完整的单元测试（test_union.c）✅
  - [x] 设计文档（UNION_DESIGN.md）✅
- [x] **LLVM 代码生成器集成（装箱/拆箱）** ✅
  - [x] box_to_union 和 unbox_from_union 函数
  - [x] 自动装箱：类型注解为 union 时
  - [x] %union_t 类型定义
  - [x] union runtime 函数声明
  - [x] 链接 union.c 到可执行文件
- [x] **Match 表达式与 union 集成** ✅ (2025-10)
  - [x] 整数、字符串、布尔值模式匹配
  - [x] 自动拆箱并类型检查（union_is_xxx + union_get_xxx）
  - [x] 通配符模式支持
  - [x] 完整的测试用例（test_union_comprehensive.dm）
- [x] **Print 支持 union 类型** ✅ (2025-10)
  - [x] union_print_value 运行时函数
  - [x] 自动根据 tag 输出正确值
  - [x] 输出格式统一（所有值带换行符）✅

**工作原理**：
```dream
# 模式1：编译时类型特化（默认，无类型注解）
let x = 42              # 直接是 i32，零开销
let y = "hello"         # 直接是 i8*，零开销

# 模式2：运行时多态（显式类型注解）
let x: int | string = 42        # 装箱为 union_t*
let y: int | string = "hello"   # 装箱为 union_t*

# Match 表达式自动拆箱
match x:
    42:         # 自动检查类型并比较值
        print(1)
    "test":
        print(2)
    _:
        print(0)

# 函数参数自动装箱
def process(v: int | string) -> int:
    match v:
        42: return 10
        "test": return 20
        _: return 0

print(process(42))      # 自动装箱: 42 -> union_t*
print(process("test"))  # 自动装箱: "test" -> union_t*
print(process(x))       # 已是 union_t*，不装箱

# 多参数 union
def compare(a: int | string, b: int | bool) -> int:
    match a:
        100:
            match b:
                True: return 1
                _: return 0
        _:
            return 0

print(compare(100, True))   # 两个参数都自动装箱

# 函数返回值自动装箱
def get_value(flag: int) -> int | string:
    match flag:
        1:
            return 42         # 自动装箱为 union_t*
        2:
            return "world"    # 自动装箱为 union_t*
        _:
            return 888

let r1: int | string = get_value(1)
print(r1)  # 输出 42

# 返回值可以直接用于 match
match get_value(1):
    42:
        print(50)  # 输出 50
    _:
        print(0)
```

**性能特点**：
- 模式1：零运行时开销
- 模式2：装箱 ~20 cycles，拆箱 ~10 cycles
- Match 拆箱：类型检查 + 值提取，约 15 cycles

**已完成功能（续）**：
- [x] **函数参数 union 装箱** ✅ (2025-10)
  - [x] 函数参数类型表（function_param_types in context）
  - [x] 调用时自动检测并装箱
  - [x] 避免重复装箱（已是 union 直接传递）
  - [x] 多参数 union 支持
  - [x] 混合参数类型支持（union + 普通类型）
- [x] **函数返回值 union 装箱** ✅ (2025-10)
  - [x] ctx.function_type 跟踪当前函数返回类型
  - [x] SReturn 语句自动检测并装箱
  - [x] Match 语句 return 分支优化
  - [x] 控制流分析（has_return_stmt）
  - [x] 完整测试（test_union_comprehensive.dm）

**已完成功能（续2）**：
- [x] **GC 集成和内存优化** ✅ (2025-10)
  - [x] OBJ_UNION 类型集成到 Dream GC 系统
  - [x] union_create_xxx 使用 gc_alloc（局部分配，快速路径）
  - [x] 自动引用计数（union_retain/union_release）
  - [x] 字符串内存自动清理（gc_release 时自动释放）
  - [x] 内存池优化（sizeof(union_t) = 24 字节，使用 64 字节池）
  - [x] 批量分配（每批 64 个对象）
  - [x] 完整的单元测试（test_union_gc.c）
  - [x] 零内存泄漏（106 alloc / 106 free）
  - [x] union_print_value 支持小写 true/false 输出 ✅

**待完成功能**：
- 无（Union 类型已生产可用）

---

## 第三阶段：编译器重写 (P2)

### 11. Lexer（词法分析器）
依赖：枚举、字符串、结构体
- [ ] Token 枚举定义
- [ ] 缩进处理（INDENT/DEDENT）
- [ ] 字符串/数字字面量解析

### 12. Parser（语法分析器）
依赖：枚举、递归类型、模式匹配
- [ ] AST 节点定义
- [ ] 递归下降解析器
- [ ] 错误恢复

### 13. Type Checker（类型检查）
依赖：枚举、字典、泛型
- [ ] Hindley-Milner 类型推导
- [ ] 类型统一算法

### 14. LLVM IR Generator
依赖：字符串构建器、字典、模式匹配
- [ ] IR 字符串生成
- [ ] AST → LLVM 映射

---

## 第四阶段：自举验证 (P3)

### 15. 自举编译
- [ ] OCaml 编译器 → Dream 编译器 v1
- [ ] v1 → v2 → v3
- [ ] v2 == v3（bit-for-bit）

---

## 实现优先级

### 立即开始（P0）
1. ✅ ~~字典类型~~ (已完成)
2. ✅ ~~元组解包~~ (已完成)
3. ✅ ~~枚举类型~~ (基础完成 - 简单变体) ✅ (2025-10)
4. ✅ ~~模式匹配代码生成~~ (基础完成 - 整数/字符串/通配符/变量/枚举) ✅ (2025-10)
5. 🔴 **字符串操作** - Runtime 已有，添加语言绑定
6. 🔴 **文件 I/O** - Runtime 已有，添加语言绑定

### 短期目标（P1）
7. ✅ ~~枚举变体带数据的模式匹配~~ (已完成) ✅ (2025-10)
8. 结构体
9. 完成泛型系统高级特性

### 中期目标（P2）
11. Lexer 重写
12. Parser 重写
13. Type Checker 重写
14. LLVM IR Generator 重写

### 长期目标（P3）
15. 自举编译
16. 性能优化

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
