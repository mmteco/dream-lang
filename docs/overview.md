# Dream 编译器顶层运行逻辑

## 项目概述

Dream 是一门现代编译型语言，设计目标是结合 Python 的简洁语法和静态类型系统的安全性，使用 LLVM 作为编译后端。

## 编译器入口

**主入口文件**：`bin/main.ml`

编译器支持三个子命令：
- `build <file.dm>` - 编译源文件生成可执行文件
- `run <file.dm>` - 编译并运行源文件（自动清理中间文件）
- `lsp <file.dm>` - 输出符号分析结果（用于 LSP 支持）

## 核心编译流程

### 1. 命令行处理

```
main.ml:270-325
- 解析命令行参数
- 验证文件扩展名 (.dm)
- 分发到对应的命令处理函数
```

### 2. Build 命令流程

**函数**: `build_command` (main.ml:136-150)

```
输入：.dm 源文件
  ↓
compile_to_llvm    # 编译为 LLVM IR
  ↓
compile_to_exe     # 编译为可执行文件
  ↓
输出：可执行文件
```

### 3. 编译为 LLVM IR

**函数**: `compile_to_llvm` (main.ml:15-105)

#### 3.1 文件读取
```ocaml
read_file input_file  (* 读取源代码 *)
```

#### 3.2 词法分析 (Lexing)
```
lib/lexer.mll → Lexer 模块
- 将源代码字符串转换为 token 流
- 处理缩进敏感语法（INDENT/DEDENT）
- 识别关键字、标识符、字面量、运算符
- 记录每个 token 的位置信息（行号、列号）
```

**实现细节**：
- 使用 ocamllex 生成
- 返回 `(token, start_pos, end_pos)` 三元组列表
- 支持 Python 风格的缩进语法

#### 3.3 语法分析 (Parsing)
```
lib/parser.mly → Parser 模块
- 将 token 流解析为抽象语法树（AST）
- 处理表达式优先级和结合性
- 检测语法错误并提供错误位置
```

**实现细节**：
- 使用 menhir 解析器生成器
- 输出 AST（定义在 `lib/ast.ml`）
- 错误恢复机制

#### 3.4 内置类型注入
```ocaml
(* 在用户代码前插入内置枚举定义 *)
let builtin_enums = [
  Option;  (* Some(T) | Nothing *)
  Result;  (* Ok(T) | Err(E) *)
]
```

#### 3.5 类型检查 (Type Checking)
```
lib/typeck/ → Typeck 模块
- tc_expr.ml   # 表达式类型检查
- tc_stmt.ml   # 语句类型检查
- tc_generics.ml # 泛型类型处理
- tc_utils.ml  # 类型检查工具函数
- tc_defaults.ml # 默认类型推导
```

**核心功能**：
- Hindley-Milner 类型推导
- 类型统一算法（Unification）
- 泛型类型收集
- 模式匹配穷尽性检查（lib/exhaustiveness.ml）
- 错误和警告收集（lib/error.ml）

**主要步骤**：
1. 环境初始化（lib/env.ml）
2. 自顶向下遍历 AST
3. 为每个表达式推导类型
4. 检查类型一致性
5. 收集泛型实例化信息

#### 3.6 单态化 (Monomorphization)
```
lib/monomorphize.ml → Monomorphize 模块
- 将泛型函数实例化为具体类型版本
- 为每个具体类型生成专门的函数
- 类似 Rust/C++ 的单态化策略
```

**示例**：
```dream
def identity[T](x: T) -> T:
    return x

identity(42)       # 生成 identity_int 版本
identity("hello")  # 生成 identity_str 版本
```

#### 3.7 LLVM IR 代码生成
```
lib/codegen/ → Llvmgen 模块
- llvmgen.ml      # 主入口和程序级代码生成
- cg_expr.ml      # 表达式代码生成
- cg_stmt.ml      # 语句代码生成
- cg_toplevel.ml  # 顶层定义代码生成
- cg_types.ml     # 类型映射
- cg_utils.ml     # 工具函数
- cg_shared.ml    # 共享上下文和数据结构
```

**类型映射**：
| Dream 类型 | LLVM 类型 | 说明 |
|-----------|----------|------|
| int       | i32      | 32位整数 |
| bool      | i1       | 布尔值 |
| float     | float    | 浮点数 |
| str       | i8*      | UTF-8字符串指针 |
| [T]       | %dynarray_ptr | 动态数组 |
| (T1, T2)  | %tuple_t* | 元组 |
| dict[K,V] | %dict_t* | 字典 |
| enum      | %enum_t* | 枚举（Tagged Union）|
| union     | %union_t* | Union类型 |
| struct    | %struct_name | 结构体 |

**输出**：
- 生成 `.ll` 文件（LLVM IR 文本格式）
- 包含所有函数、全局变量、类型定义

### 4. 编译为可执行文件

**函数**: `compile_to_exe` (main.ml:107-134)

```bash
clang -o output_exe \
    output.ll \
    runtime/runtime.c \
    runtime/memory.c \
    runtime/dynarray.c \
    runtime/utf8.c \
    runtime/bytes.c \
    runtime/utf8_wrapper.c \
    runtime/bytes_wrapper.c \
    runtime/str.c \
    runtime/file.c \
    runtime/dict.c \
    runtime/tuple.c \
    runtime/union.c \
    runtime/enum.c \
    -I runtime
```

**Runtime 模块**：
- `runtime.c` - 运行时初始化和公共函数
- `memory.c` - 内存管理（引用计数 + 分代 GC）
- `dynarray.c` - 动态数组实现
- `utf8.c` / `str.c` - UTF-8 字符串处理
- `bytes.c` - 字节数组处理
- `file.c` - 文件 I/O
- `dict.c` - 字典（哈希表）实现
- `tuple.c` - 元组实现
- `union.c` - Union 类型（运行时多态）
- `enum.c` - 枚举类型（Tagged Union）

### 5. Run 命令流程

**函数**: `run_command` (main.ml:152-215)

特殊处理：
1. 在 `~/.dream/cache/<program_name>/` 目录编译
2. 将可执行文件放到 `~/.dream/bin/`
3. 运行程序
4. 自动清理生成的文件（.ll 和可执行文件）

这样可以避免污染源代码目录。

### 6. LSP 命令流程

**函数**: `lsp_command` (main.ml:217-255)

用于编辑器集成：
1. 词法分析 + 语法分析
2. 符号分析（`lib/symbol_analyzer.ml`）
3. 输出 JSON 格式的符号信息

## 项目目录结构

```
dream/
├── bin/               # 编译器入口
│   ├── main.ml        # 主程序
│   └── debug_tokens.ml # Token 调试工具
│
├── lib/               # 编译器核心库
│   ├── ast.ml         # AST 定义
│   ├── types.ml       # 类型系统
│   ├── env.ml         # 环境/符号表
│   ├── error.ml       # 错误处理
│   ├── lexer.mll      # 词法分析器
│   ├── parser.mly     # 语法分析器
│   ├── symbol_analyzer.ml # 符号分析（LSP）
│   ├── exhaustiveness.ml  # 穷尽性检查
│   ├── monomorphize.ml    # 单态化
│   ├── module_loader.ml   # 模块加载
│   │
│   ├── typeck/        # 类型检查模块
│   │   ├── typeck.ml
│   │   ├── tc_expr.ml
│   │   ├── tc_stmt.ml
│   │   ├── tc_generics.ml
│   │   ├── tc_defaults.ml
│   │   └── tc_utils.ml
│   │
│   └── codegen/       # 代码生成模块
│       ├── llvmgen.ml
│       ├── cg_expr.ml
│       ├── cg_stmt.ml
│       ├── cg_toplevel.ml
│       ├── cg_types.ml
│       ├── cg_utils.ml
│       └── cg_shared.ml
│
├── runtime/           # C 运行时库
│   ├── runtime.c      # 运行时初始化
│   ├── memory.c       # GC 内存管理
│   ├── dynarray.c     # 动态数组
│   ├── str.c          # 字符串操作
│   ├── bytes.c        # 字节数组
│   ├── file.c         # 文件 I/O
│   ├── dict.c         # 字典
│   ├── tuple.c        # 元组
│   ├── union.c        # Union 类型
│   └── enum.c         # 枚举类型
│
├── examples/          # 示例代码
├── test/              # 测试文件
├── docs/              # 文档
│   ├── overview.md    # 本文档
│   └── ...
│
├── SPEC.md            # 语言规范
├── TODO.md            # 开发任务
├── BOOTSTRAP.md       # 自举路线图
└── README.md          # 项目说明
```

## 编译流程图

```
┌─────────────────┐
│  .dm 源文件     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Lexer          │  lib/lexer.mll
│  词法分析       │  token 流 + 位置信息
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Parser         │  lib/parser.mly
│  语法分析       │  AST (lib/ast.ml)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  内置类型注入   │  Option, Result
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Type Checker   │  lib/typeck/
│  类型检查       │  - 类型推导
│                 │  - 类型统一
│                 │  - 泛型收集
│                 │  - 穷尽性检查
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Monomorphize   │  lib/monomorphize.ml
│  单态化         │  泛型实例化
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  LLVM Codegen   │  lib/codegen/
│  代码生成       │  .ll 文件
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Clang          │  runtime/*.c + .ll
│  编译链接       │  可执行文件
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  可执行文件     │
└─────────────────┘
```

## 内存管理

Dream 使用自动内存管理，结合了引用计数和分代垃圾回收：

### GC 策略
- **引用计数**：主要机制，即时释放无引用对象
- **分代 GC**：处理循环引用
  - 年轻代（频繁检查）
  - 老年代（较少检查）
- **内存池**：针对小对象优化分配

### 对象类型
```c
typedef enum {
    OBJ_STRING,
    OBJ_DYNARRAY,
    OBJ_DICT,
    OBJ_TUPLE,
    OBJ_UNION,
    OBJ_ENUM
} gc_obj_type_t;
```

### 主要函数
- `gc_alloc()` - 分配 GC 管理的内存
- `gc_retain()` - 增加引用计数
- `gc_release()` - 减少引用计数，可能释放对象
- `gc_collect()` - 触发垃圾回收

## 错误处理

编译器使用集中的错误处理机制（lib/error.ml）：

### 错误级别
- **Error**：编译失败
- **Warning**：潜在问题但不终止编译

### 错误报告
- 位置信息（文件、行、列）
- 错误类型和描述
- 上下文代码显示
- 错误计数和摘要

## 标准库位置

标准库 Runtime 函数直接链接到可执行文件中，用户代码可直接调用：
- 字符串操作：`str_length()`, `str_concat()`, `str_split()` 等
- 数组操作：`dynarray_new()`, `dynarray_push()` 等
- 字典操作：`dict_new()`, `dict_set()`, `dict_get()` 等
- 文件 I/O：`file_read()`, `file_write()` 等
- 打印函数：`print_int()`, `print_string()`, `print_bool()` 等

## 性能特点

### 编译期优化
- **类型擦除**：泛型通过单态化实现，零运行时开销
- **内联**：小函数自动内联
- **死代码消除**：未使用的代码不会生成

### 运行时优化
- **内存池**：小对象快速分配
- **引用计数**：即时内存回收
- **字符串池**：字符串去重
- **LLVM 优化**：后端自动优化（建议使用 -O2/-O3）

## 未来规划

参见 [BOOTSTRAP.md](../BOOTSTRAP.md) 和 [TODO.md](../TODO.md)：
- 完善标准库
- 模块系统
- 包管理器
- 自举编译（用 Dream 重写编译器）
- LSP 完整支持
- REPL
- 调试器

## 相关文档

- [SPEC.md](SPEC.md) - Dream 语言规范
- [BOOTSTRAP.md](BOOTSTRAP.md) - 自举路线图
- [TODO.md](TODO.md) - 开发任务
