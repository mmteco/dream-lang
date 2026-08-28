# Dream 编译器顶层运行逻辑

## 项目概述

Dream 是一门现代编译型语言，设计目标是结合 Python 的简洁语法和静态类型系统的安全性，使用 LLVM 作为编译后端。编译器存在两个实现：

- **宿主 OCaml 编译器**（`ocaml/bin/main.ml` + `ocaml/lib/`）：完整语言能力，正式发布路径；
- **bootstrap 自举编译器**（`bootstrap/compiler.dm`，Dream 语言编写）：用于自举验证，当前通过 Stage 0 → 1 → 2 → 3 链编译自身并达到固定点。

两者共享同一管线方向：`lex → AST → lower → 结构化 DIR records → DIR verifier → LLVM`，并统一提供 `dir` 命令输出正式 DreamIR 文本。

## 编译器入口

**宿主入口**：`ocaml/bin/main.ml`，支持子命令：

- `build <file.dm>` - 编译源文件生成可执行文件
- `run <file.dm>` - 编译并运行源文件（自动清理中间文件）
- `lsp <file.dm>` - 输出符号分析结果（用于 LSP 支持）

**自举入口**：`bootstrap/compiler.dm` 生成的 Stage 1/2/3 提供通用 CLI：

- `build <input.dm> -o <output>` - 生成可执行文件
- `compile <input.dm> -o <output.ll>` - 输出 LLVM IR（`llvm` 为等价命令）
- `dir <input.dm> -o <output.dir>` - 输出正式 DreamIR 文本

## 核心编译流程

### 宿主 OCaml 编译器

```
.dm 源码
  ↓
ocaml/lib/lexer.mll         词法分析（token 流 + 位置信息，缩进敏感）
  ↓
ocaml/lib/parser.mly        语法分析（menhir，输出 AST）
  ↓
内置类型注入          Option/Result 枚举定义
  ↓
ocaml/lib/typeck/           类型检查（HM 推导、统一、泛型收集、穷尽性检查）
  ↓
ocaml/lib/monomorphize.ml   泛型单态化（为每个具体类型生成专门函数）
  ↓
ocaml/lib/ir/dir/           DreamIR 后端（唯一正式后端）
  │  dir_lower.ml     类型检查后 AST → 结构化 DIR
  │  dir_verify.ml    DIR 验证
  │  dir_lower_llvm.ml DIR → LLVM 文本
  ↓
clang + runtime/c/core + runtime/c/wrappers      链接生成可执行文件
```

DreamIR 是类型化 CFG/SSA 中间表示：SSA 值使用稳定 ID（`%v1`），block 参数表达合流（LLVM lowering 转 `phi`），字符串/列表等以高层指令存在（`string_length`、`list_get` 等），ABI 细节由 `dir_lower_llvm.ml` 集中处理。所有 runtime 函数签名只有一个来源（`ocaml/lib/ir/dir/dir_lower.ml` 的 runtime 注册表）。

### bootstrap 自举编译器

```
compiler.dm（源码）
  ↓
compiler_lex.dm       lex + collect（token 流、声明表预收集：struct/函数/全局 let）
  ↓
compiler_ast.dm       AST 节点池（扁平 list[int]，节点 = [kind, token_start, token_end, arg0...]）
  ↓
compiler_lower.dm     lower 顶向下遍历 → 结构化 DIR records（FUNCTION/BLOCK/指令记录）
  ↓
compiler_dir.dm       dir_validate_records 验证 → dir_render_records 渲染 LLVM IR
  ↓
clang + runtime/c/core + runtime/c/wrappers      链接生成可执行文件（runtime linker 动态扫描 runtime/c/core/*.c 和 runtime/c/wrappers/*.c）
```

自举编译器的 lexer/表达式/语句解析仍是过渡实现（服务于 `compiler.dm` 自身的语法子集），但发射器已直接构建结构化 DIR records，与 OCaml 版本保持同一流水线方向，不再存在「先生成 LLVM 文本、再反解析为 DIR」的反向路径。新旧管线的详细进度见 [BOOTSTRAP.md](BOOTSTRAP.md)。

## 项目目录结构

```
dream/
├── ocaml/             # 宿主编译器（独立 dune 工程）
│   ├── dune-project
│   ├── bin/           # 入口（main.ml、debug_tokens.ml）
│   ├── lib/           # 核心库
│   │   ├── ast.ml / types.ml / env.ml / error.ml / lexer.mll / parser.mly
│   │   ├── symbol_analyzer.ml / exhaustiveness.ml / monomorphize.ml / module_loader.ml
│   │   ├── typeck/    # 类型检查（typeck.ml、tc_expr.ml、tc_stmt.ml、tc_generics.ml、tc_defaults.ml、tc_utils.ml）
│   │   ├── ir/dir/    # DreamIR 后端（dir.ml、dir_lower.ml、dir_verify.ml、dir_printer.ml、dir_lower_llvm.ml）
│   │   └── compiler/  # 编译管线（dir_compiler.ml）
│   └── test/          # OCaml 单元测试（dir_test.ml）
├── bootstrap/         # 自举编译器源码（Dream 语言编写，compiler*.dm）
├── runtime/           # 运行时标准库
│   ├── c/             # C 运行时（io.c / memory.c / dynarray.c / str.c / bytes.c / file.c
│   │                  #  dict.c / tuple.c / union.c / enum.c / utf8.c / math.c 等）
│   └── stdlib/        # Dream 标准库（compiler_io.dm、ops.dm、io.dm 等）
├── scripts/           # Fish 脚本（自举编排、测试、构建）
├── examples/          # 示例代码
├── test/              # .dm 语言测试（大而全的覆盖测试）
├── docs/              # 文档
├── tmp/               # 构建产物（stage 二进制、*.ll，gitignored）
├── SPEC.md            # 语言规范
└── README.md          # 项目说明
```

## 内存管理

Dream 使用自动内存管理，结合引用计数和分代垃圾回收：

- **引用计数**：主要机制，即时释放无引用对象；
- **分代 GC**：处理循环引用（年轻代频繁检查，老年代较少检查）；
- **内存池**：针对小对象优化分配。

对象类型：`OBJ_STRING / OBJ_DYNARRAY / OBJ_DICT / OBJ_TUPLE / OBJ_UNION / OBJ_ENUM / OBJ_INTERFACE`（接口装箱对象，引用计数托管）。主要函数：`gc_alloc / gc_retain / gc_release / gc_collect`。

## 错误处理

编译器使用集中的错误处理机制（ocaml/lib/error.ml）：

- **Error**：编译失败；**Warning**：潜在问题但不终止编译；
- 错误报告含位置信息（文件、行、列）、错误类型和描述、上下文代码显示、错误计数和摘要。

## 标准库位置

标准库 Runtime 函数直接链接到可执行文件中（`str_length`、`dynarray_push`、`dict_set`、`file_read`、`print_*` 等），另有 Dream 源码标准库 `runtime/stdlib/`（`ops.dm` 运算符重载接口、`io.dm` 文件 I/O 包装等）。

## 相关文档

- [BOOTSTRAP.md](BOOTSTRAP.md) - 自举路线图（阶段定义、当前进度、架构原则、验证协议）
- [TODO.md](TODO.md) - 开发任务列表
- [SPEC.md](../SPEC.md) - 语言规范
- [OPERATOR_OVERLOADING.md](OPERATOR_OVERLOADING.md) / [GC_IMPLEMENTATION.md](GC_IMPLEMENTATION.md) / [HASH_ALGORITHMS.md](HASH_ALGORITHMS.md) - 专题文档
