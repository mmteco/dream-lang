# Dream 语言自举路线图

## 目标
用 Dream 语言重新实现 Dream 编译器，实现自举（self-hosting）。

## 自举阶段定义

项目采用标准的 Stage 0 → Stage 1 → Stage 2 → Stage 3 编号。编号表示“使用哪个编译器编译下一个编译器”，样例程序不属于自举阶段。

| 阶段 | 编译器 | 输入 | 产物与职责 |
| --- | --- | --- | --- |
| Stage 0 | `_build/default/bin/main.exe`（宿主 OCaml 编译器） | `bootstrap/compiler.dm` | 生成并链接 `bootstrap/stage1` |
| Stage 1 | `bootstrap/stage1`（Stage 0 生成） | `bootstrap/compiler.dm` | 生成 `stage2.ll`、`stage3.ll`，并编译 `sample_functions.ll` 作为样例回归 |
| Stage 2 | `bootstrap/stage2`（Stage 1 生成） | `bootstrap/compiler.dm` | 再次生成 Stage 2/3，验证自举固定点；也是 `bootstrap-build` 使用的编译器 |
| Stage 3 | `bootstrap/stage3`（Stage 2 生成） | `bootstrap/compiler.dm` | 再运行一轮，确认输出与 Stage 2 一致 |

执行顺序如下：

```text
Stage 0: OCaml compiler
    └─ compiler.dm → stage1.ll → bootstrap/stage1
        └─ compiler.dm → stage2.ll → bootstrap/stage2
            └─ compiler.dm → stage3.ll → bootstrap/stage3
                └─ compiler.dm → stage2.ll / stage3.ll（必须达到固定点）
```

`bootstrap/sample_functions` 只是由 Stage 1 编译出的功能回归样例，不是 Stage 1 编译器。`compiler.ll` 也不再作为阶段产物保留；Stage 0 生成的编译器统一命名为 `stage1.ll` 和 `stage1`。

## 当前自举进度

- [x] Stage 1 支持整数、变量、四则运算、`let`、函数声明、参数、`return`、调用、`print`、字符串、列表、循环和 `switch/case/default`。
- [x] Stage 0 生成并运行 Stage 1；Stage 1 生成并链接 Stage 2 和 Stage 3。
- [x] Stage 2、Stage 3 可以运行并生成字节一致的 LLVM 固定点。
- [x] `scripts/bootstrap_build.fish` 可以使用 Stage 2 bootstrapped 编译器构建当前自举语法子集，并由 Clang/runtime 链接为可执行文件。
- [x] Stage 2 已支持整数列表字面量、列表索引读取和列表元素赋值；`hello.dm`、`factorial.dm`、`dynarray_full.dm` 已纳入 `make bootstrap` 回归。
- [x] Stage 2 已支持 `for value in list[int]`，并通过 `test_for_dir.dm` 的 `60` 输出回归。
- [x] Stage 2 已支持 typed list、整数列表推导式、整数 tuple 字面量、tuple 解包和一元负号；`test_bootstrap_collections.dm` 固定回归输出 `3`、`2`、`30`、`1`。
- [x] Stage 2 已支持整数结构体构造、声明顺序字段布局、乱序命名字段初始化和字段访问；`test_bootstrap_struct.dm` 回归输出 `7`。
- [x] Stage 2/3 的 `switch/case/default` 已支持 `int`、`bool`、`float`、`str`；整数/布尔使用 `icmp`，浮点使用 `fcmp oeq double`，字符串通过 `string_compare`，`test_bootstrap_switch_basic.dm` 回归输出 `20`、`1`、`25`、`1`。
- [x] bootstrap 函数收集器会从声明提取 ABI 返回类型，并贯通表达式/语句解析；`test_bootstrap_result.dm` 和 `test_bootstrap_return_metadata.dm` 使用任意函数名验证，不依赖业务函数名硬编码。
- [x] DreamIR 的结构化 `Switch` 已支持 `int`、`float`、`bool`、`str`；整数使用 LLVM 原生 `switch`，其余标量渲染为比较链，并由 verifier 检查 case 类型一致性。
- [x] Stage 2 已支持整数 `match`、通配符和整数载荷 enum 的基础表达式分支；`test_bootstrap_match.dm` 回归输出 `100`。
- [x] Stage 2 已复用 `[tag, payload]` 表示支持用户 enum 和 `Some/None`、`Ok/Err` 的基础 `match`；`test_bootstrap_match_enum.dm` 与 `test_bootstrap_match_builtin.dm` 已纳入自举回归。
- [ ] 完整语言编译器仍未完成自举；bootstrap 已迁移基础 float 字面量、参数、返回值、switch、命名函数值和无捕获 lambda，但 bytes、捕获变量及完整类型推导仍未完成，`language_tour.dm` 等高级语法仍需宿主 `dream`。

### 使用 bootstrapped 编译器

先生成并验证 Stage 2：

```fish
make bootstrap
```

构建当前自举子集中的源文件：

```fish
fish scripts/bootstrap_build.fish run bootstrap/sample_functions.dm
```

或者：

```fish
make bootstrap-build FILE=bootstrap/sample_functions.dm
```

这条路径使用 `bootstrap/stage2`，不会调用 `_build/default/bin/main.exe` 编译目标文件。当前自举编译器仍是编译器子集，超出其语法和代码生成能力的源文件会在 LLVM 验证或链接阶段失败，而不会被标记为完整语言支持。

没有显式 `def main()` 的示例会由 `bootstrap_build.fish` 在 `tmp/` 中生成临时入口，将顶层可执行语句放入 `main` 后再交给 Stage 2；临时文件会在脚本退出时清理。

---

## 已完成基础 ✅

- [x] 基础类型系统（int, float, string, bool）
- [x] 函数定义、调用、递归
- [x] 控制流（if/else, while, for）
- [x] 数组操作（索引、切片、拼接、列表推导式）
- [x] 动态内存管理（引用计数 + 分代GC）
- [x] LLVM IR 代码生成
- [x] 字典类型（int->int，FNV-1a 哈希）
- [x] 元组解包（let、for 循环）
- [x] Runtime 模块化（str, file, dict, tuple, dynarray, memory）
- [x] 小写布尔和None关键字（true/false/none 支持）
- [x] print(bool) 函数支持（输出小写 true/false）
- [x] 字符串索引和切片（`str[i]`, `str[start:end]`）
- [x] print(string) 函数支持
- [x] string 类型重命名为 str
- [x] print() 泛型类型检查优化（接受任意类型） 

---

## 第一阶段：核心数据结构 (P0)

### 1. 字符串增强 ✅ **完成**

- [x] 字符串索引 `s[i]` - 返回字符的 ASCII 码
- [x] 字符串切片 `s[start:end]` - 返回子字符串
- [x] print(string) 支持
- [x] `length()` - 字符串长度
- [x] `find(substr)` - 查找子字符串位置（返回 -1 如果未找到）
- [x] `replace(old, new)` - 替换所有匹配的子字符串
- [x] `strip()` - 去除首尾空白字符
- [x] `upper()` - 转换为大写
- [x] `lower()` - 转换为小写
- [x] `starts_with(prefix)` - 检查是否以指定前缀开始
- [x] `ends_with(suffix)` - 检查是否以指定后缀结束
- [x] `==`, `!=` - 相等性比较
- [x] `<`, `>`, `<=`, `>=` - 字典序比较
- [x] `is_digit(index)` - 检查指定位置字符是否为数字
- [x] `is_alpha(index)` - 检查指定位置字符是否为字母
- [x] `is_whitespace(index)` - 检查指定位置字符是否为空白
- [x] `split(delimiter)` - 分割字符串返回字符串数组
- [x] `join(array, separator)` - 连接字符串数组

### 2. 文件 I/O ✅ **完成**
**已实现功能**：
- [x] `file_read(path)` - 读取文件为字符串
- [x] `file_write(path, content)` - 写入字符串到文件
- [x] `file_exists(path)` - 检查文件是否存在
- [x] `file_append(path, content)` - 追加内容到文件
- [x] `file_delete(path)` - 删除文件
- [x] `file_read_bytes(path)` - 读取文件为字节数组
- [x] `file_write_bytes(path, bytes)` - 写入字节数组到文件
- [x] `file_append_bytes(path, bytes)` - 追加字节数组到文件
- [x] 标准库 `stdlib/file.dm` - 统一的文件 I/O 接口
- [x] Union 类型集成 - `str | bytes` 参数支持
- [x] **Bytes 类型完整支持**
  - [x] Union bytes 类型（UNION_BYTES）
  - [x] Runtime 实现（union_create_bytes, union_is_bytes, union_get_bytes）
  - [x] 类型模式匹配（match type of 支持 bytes）
  - [x] 装箱/拆箱（Ptr (DynArray I32) ↔ union_t*）
  - [x] LLVM 代码生成完整支持

### 3. 错误处理 ✅ **完整功能完成**
**已实现功能**：
- [x] Option 类型 `Option[T] = Some(T) | Nothing` (使用标准枚举)
- [x] Result 类型 `Result[T, E] = Ok(T) | Err(E)` (使用标准枚举)
- [x] **三元运算符** `condition ? true_val : false_val`
  - [x] 词法分析：`?` token 识别
  - [x] 语法解析：ETernary 表达式节点
  - [x] 类型检查：条件为 bool，两分支类型相同
  - [x] LLVM 代码生成：phi 节点实现
  - [x] 支持嵌套使用
- [x] **错误传播运算符** `expr?`
  - [x] 词法分析：后缀 `?` 识别
  - [x] 语法解析：ETry 表达式节点
  - [x] 类型检查：Result 类型验证
  - [x] LLVM 代码生成：enum_get_tag/enum_get_int 调用
  - [x] 完全实现 Rust 的 `?` 运算符语义
  - [x] 提前返回机制（early return）
  - [x] 根据函数返回类型智能处理
  - [x] 支持链式错误传播
- [x] **Result 类型穷尽性检查**
  - [x] Ok(v) 和 Err(_) 两个分支正确覆盖 Result 类型
  - [x] 不再误报"缺少 _ 分支"错误
  - [x] exhaustiveness.ml 支持 TyResult 类型

### 4. 字典类型 ✅ **完全泛型化完成**
**已实现功能**：
- [x] 字典字面量 `{1: 10, 2: 20}` (整数键)
- [x] 字典字面量 `{"name": 100, "age": 25}` (字符串键) 
- [x] 字典字面量 `{1: "Alice", 2: "Bob"}` (字符串值) 
- [x] 字典字面量 `{"name": "Alice"}` (字符串键值对) 
- [x] 字典索引 `dict[key]`、赋值 `dict[key] = value`
- [x] `dict_keys()`, `dict_values()`, `dict_items()`
- [x] `for (k, v) in dict_items(d)` 迭代
- [x] FNV-1a 哈希算法
- [x] 64位指针安全（dynarray_ptr 使用 intptr_t）
- [x] 泛型值类型 `dict[int, string]`, `dict[string, string]` 
- [x] **统一泛型实现** - 单一 dict_t 结构，参考 Golang 设计 
- [x] **Runtime 层完全泛型化** - void* + 类型元数据，消除重复代码 
- [x] **LLVM 代码生成器重构** - 统一 API (dict_set_int_int, dict_set_str_str 等) 

### 5. 元组类型 ✅ **完整功能完成**
**已实现功能**：
- [x] 元组结构 `tuple2_i32` 和通用 `tuple_t`
- [x] `let (a, b) = tuple` 解包
- [x] `for (k, v) in items` 解包
- [x] `dict_items()` 返回元组数组
- [x] 元组字面量 `(1, 2, 3)` 
- [x] 元组索引 `tuple[0]` 
- [x] 任意长度元组支持 (基于 void* + size 的通用结构) 

---

## 第二阶段：语言特性 (P1)

### 6. 枚举类型 ✅ **完整功能完成**
**已实现功能**：
- [x] 枚举定义语法 `enum Color { Red, Green, Blue }`
- [x] 带数据的枚举 `enum Shape { Circle(int), Rectangle(int, int) }`
- [x] 泛型枚举 `enum Maybe[T] { Just(T), Nothing }`（语法解析）
- [x] 枚举构造器 `Color.Red`, `Shape.Circle(5)`, `Shape.Rectangle(10, 20)`
- [x] 模式匹配语法和类型检查
- [x] **Runtime 层 Tagged Union 实现** 
  - [x] enum.h/enum.c（enum_t 结构）
  - [x] enum_create_simple/int/string/bool 函数
  - [x] enum_create_tuple_ptr 函数（多参数变体）
  - [x] enum_get_tag/int/string/bool/data 函数
  - [x] enum_is_variant 类型检查函数
  - [x] enum_print_value 输出函数
- [x] **LLVM 代码生成器集成** 
  - [x] 枚举注册表（enum_registry）
  - [x] 单参数变体代码生成
  - [x] 多参数变体代码生成（使用元组存储）
  - [x] 枚举构造器代码生成（EEnumVariant）
  - [x] 枚举模式匹配代码生成（PEnumVariant）
  - [x] %enum_t 类型定义
  - [x] enum runtime 函数声明
  - [x] 链接 enum.c 到可执行文件
- [x] **模式匹配数据提取** 
  - [x] 单参数变体数据提取：`Circle(r)` → 绑定 r
  - [x] 多参数变体数据提取：`Rectangle(w, h)` → 绑定 w, h
  - [x] 变量重命名机制（避免 LLVM IR 名称冲突）
  - [x] gen_pattern_bindings 函数集成
- [x] **GC 集成** 
  - [x] OBJ_ENUM 类型添加到 GC 系统
  - [x] enum_create_xxx 使用 gc_alloc
  - [x] 自动引用计数管理
  - [x] 内存清理（enum_release 时释放数据指针）

**待完成功能**：
- [ ] 递归枚举（AST 节点类型）
- [ ] 枚举方法支持

### 7. 模式匹配 ✅ **核心功能完成**
**已实现功能**：
- [x] match 语句和表达式语法
- [x] case 关键字现在可选
- [x] 整数、字符串、布尔值匹配
- [x] 元组解构
- [x] 枚举变体匹配 `Color.Red`
- [x] **枚举变体带数据的模式匹配**
  - [x] 单参数变体：`Circle(r)` → 提取 r 并绑定
  - [x] 多参数变体：`Rectangle(w, h)` → 提取 w, h 并绑定
- [x] 通配符模式 `_`
- [x] 变量模式绑定 `PVar`
- [x] 类型检查和环境绑定
- [x] **LLVM 代码生成**
  - [x] SMatch 语句生成（基本块 + 条件跳转）
  - [x] EMatch 表达式生成（phi 节点）
  - [x] gen_pattern_test（模式测试条件生成）
  - [x] gen_pattern_bindings（模式变量绑定，包括枚举数据提取）
- [x] **守卫条件 `if` 子句**
  - [x] 解析器支持 `pattern if guard_expr:` 语法
  - [x] AST 扩展（EMatch 和 SMatch 的 case 支持可选守卫）
  - [x] 类型检查器验证守卫表达式为布尔类型
  - [x] LLVM 代码生成（守卫失败跳转到下一个 case）
  - [x] 完整的测试用例（test_match_guard.dm）
- [x] **穷尽性检查**
  - [x] 缺失模式分支检测（如缺少 None、Err 等）
  - [x] 不可达模式检测（重复或完全覆盖的分支）
  - [x] 通配符模式正确处理
  - [x] Bool 类型穷尽性检查（true/false）
  - [x] Enum 类型穷尽性检查（所有变体）
  - [x] 完整测试套件（test_*.dm）
- [x] **Match 表达式语义验证**
  - [x] 禁止在 match 表达式分支中使用 return 语句
  - [x] 类型检查器检测并报错
  - [x] 正确形式：`return match ...` 或 `let x = match ...`
- [x] 列表解构

### 8. 结构体

- [x] `struct Position { line: int, column: int }`
- [x] 结构体字面量、字段访问

### 9. 泛型系统 ✅ **基础功能完成**
**已实现功能**：
- [x] 函数泛型 `def identity[T](x: T) -> T`
- [x] 类型参数语法解析
- [x] 单态化代码生成
- [x] 泛型函数实例化

**待完成功能**：
- [ ] 类型参数约束
- [ ] 高阶泛型 `def map[T, U](...)`
- [ ] 泛型结构体和枚举

### 10. Union 类型 ✅ **完整功能完成**

**设计方案**：支持两种模式
1. **编译时类型特化**（默认）：零运行时开销
2. **运行时多态**（显式类型注解）：真正的类型多态

**新增功能**：
- [x] **类型模式匹配 (Type Pattern Matching)**
  - [x] 语法支持：`variable: type` 模式
  - [x] Union 类型拆箱和类型检查
  - [x] 自动类型窄化（type narrowing）
  - [x] 支持类型：int, str, bool, bytes
  - [x] 完整测试套件（test_type_pattern.dm, test_file_io.dm）
  - [x] 文档：docs/type_pattern_matching.md

**已实现功能**：
- [x] Union 类型语法 `int | string | bool`
- [x] 自动扁平化嵌套 union
- [x] 类型统一算法（子类型兼容性）
- [x] 函数参数 union 类型支持 
- [x] 变量声明 union 类型支持 
- [x] 完整的编译时类型检查 
- [x] **Runtime 层 Tagged Union 实现** 
  - [x] union.h/union.c（union_t 结构）
  - [x] union_create_int/float/string/bool/none
  - [x] union_is_xxx 类型检查函数
  - [x] union_get_xxx 值提取函数
  - [x] union_print_value 输出函数 
  - [x] 完整的单元测试（test_union.c）
  - [x] 设计文档（UNION_DESIGN.md）
- [x] **LLVM 代码生成器集成（装箱/拆箱）** 
  - [x] box_to_union 和 unbox_from_union 函数
  - [x] 自动装箱：类型注解为 union 时
  - [x] %union_t 类型定义
  - [x] union runtime 函数声明
  - [x] 链接 union.c 到可执行文件
- [x] **Match 表达式与 union 集成** 
  - [x] 整数、字符串、布尔值模式匹配
  - [x] 自动拆箱并类型检查（union_is_xxx + union_get_xxx）
  - [x] 通配符模式支持
  - [x] 完整的测试用例（test_union_comprehensive.dm）
- [x] **Print 支持 union 类型** 
  - [x] union_print_value 运行时函数
  - [x] 自动根据 tag 输出正确值
  - [x] 输出格式统一（所有值带换行符）

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
- [x] **函数参数 union 装箱** 
  - [x] 函数参数类型表（function_param_types in context）
  - [x] 调用时自动检测并装箱
  - [x] 避免重复装箱（已是 union 直接传递）
  - [x] 多参数 union 支持
  - [x] 混合参数类型支持（union + 普通类型）
- [x] **函数返回值 union 装箱** 
  - [x] ctx.function_type 跟踪当前函数返回类型
  - [x] SReturn 语句自动检测并装箱
  - [x] Match 语句 return 分支优化
  - [x] 控制流分析（has_return_stmt）
  - [x] 完整测试（test_union_comprehensive.dm）

**已完成功能（续2）**：
- [x] **GC 集成和内存优化** 
  - [x] OBJ_UNION 类型集成到 Dream GC 系统
  - [x] union_create_xxx 使用 gc_alloc（局部分配，快速路径）
  - [x] 自动引用计数（union_retain/union_release）
  - [x] 字符串内存自动清理（gc_release 时自动释放）
  - [x] 内存池优化（sizeof(union_t) = 24 字节，使用 64 字节池）
  - [x] 批量分配（每批 64 个对象）
  - [x] 完整的单元测试（test_union_gc.c）
  - [x] 零内存泄漏（106 alloc / 106 free）
  - [x] union_print_value 支持小写 true/false 输出 

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
3. ✅ ~~枚举类型~~ (已完成)
4. ✅ ~~模式匹配代码生成~~ (已完成)
5. ✅ ~~字符串索引和切片~~ (已完成)
6. ✅ ~~字符串方法~~ (已完成) - length, find, replace, strip, upper, lower, starts_with, ends_with
7. ✅ ~~字符串比较操作符~~ (已完成) - ==, !=, <, >, <=, >=
8. ✅ ~~字符级别方法~~ (已完成) - is_digit, is_alpha, is_whitespace
9. ✅ ~~文件 I/O~~ (已完成) - 完整的字符串和字节读写功能
10. ✅ ~~split/join~~ (已完成) - Runtime 已实现，类型系统支持完善
11. ✅ ~~类型模式匹配~~ (已完成) - Union 类型拆箱和类型检查
12. ✅ ~~string → str 重命名~~ (已完成) - 全面统一类型名称
13. ✅ ~~测试文件整理~~ (已完成) - 从16个整合为4个全面测试

### 短期目标（P1）
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

## 成功标准

1. ✅ Dream 编译器完全用 Dream 编写
2. ✅ v2 和 v3 二进制完全一致
3. ✅ 通过所有测试用例
4. ✅ 性能与 OCaml 版本相当
