# Dream 实现全流程最佳实践

本文中的 `DIR` 是 Dream Intermediate Representation（Dream 中间表示）的正式缩写；`DreamIR` 是项目对该语言特定中间表示的名称。命令行参数、目录和模块文件名中的 `dir` 保持小写。

本文是 Dream 当前代码库的实现路线和工程约束。目标不是尽快增加语法，而是建立一条可验证、可调试、可自举、可长期演进的编译器链路。

## 零、针对 Dream 的技术取舍

Gemini 给出的路线有参考价值，但其中“绝对不要”“业界标准”和“缩减 80% 工作量”等表述不能直接作为工程决策。Dream 的目标是稳定自举，因此采用以下取舍：

| 建议 | Dream 决策 | 原因 |
| --- | --- | --- |
| RFC、可执行规范、分层测试 | 采纳 | 先固定语义和边界条件，减少自举期间的隐性变化 |
| Tree-sitter 替换现有 Parser | 暂不采纳 | Tree-sitter 擅长编辑器增量解析并生成 CST；Dream 当前 Menhir 前端已可用，替换会扩大自举和语义迁移范围 |
| HIR/MIR 思路 | 采纳，合并为渐进路线 | 当前类型检查后的 AST 可先承担 HIR 角色；DreamIR v1 承担类型化 CFG/SSA 和语言运行时操作，避免一次性维护三套完整表示 |
| MLIR 方言 | 暂不采纳 | MLIR 适合多层方言、张量/异构/DSL 等场景；Dream 当前瓶颈是自举正确性和 LLVM 边界，不是缺少通用 IR 基础设施 |
| LLVM 后端 | 采纳 | 已有运行时、代码生成和自举切片，迁移成本最低；先保留文本 LLVM，验证稳定后再考虑 API/bitcode |
| Cranelift | 暂不采纳 | 它适合快速编译、JIT 或 Wasm 等目标，但不能解决当前 Stage2 生成非法 LLVM 的问题 |
| 三阶段自举 | 采纳 | 但验收以规范化 DIR、LLVM 验证和行为测试为主，字节级一致性作为可选增强 |
| AI Agent Skills/MCP | 作为生态附加项 | 可帮助文档、LSP 和工具使用，但不是编译器自举的正确性基础 |

Tree-sitter 的官方定位是增量解析器和具体语法树（CST）工具，而不是带类型和语义的编译器 AST；MLIR 的价值在于可扩展方言和跨层转换框架。两者都很有用，但都不能替代 Dream 当前需要的类型检查、DIR verifier 和自举固定点测试。

因此 Dream 的实际架构是：

```text
AST/typed AST（逐步明确 HIR 边界）
  → DreamIR（MIR 风格的类型化 CFG/SSA）
  → DIR verifier / passes
  → LLVM 文本 lowering
  → LLVM verifier
  → clang + runtime
```

## 一、当前真实状态

当前正式编译链路是：

```text
.dm
  → Lexer
  → Parser
  → AST
  → Typeck
  → Monomorphize
  → LLVM 文本生成
  → clang
  → runtime/
```

对应入口和模块：

| 阶段 | 当前实现 |
| --- | --- |
| 词法分析 | `lib/lexer.mll` |
| 语法分析 | `lib/parser.mly`、`lib/ast.ml` |
| 类型检查 | `lib/typeck/`、`lib/types.ml` |
| 泛型单态化 | `lib/monomorphize.ml` |
| DIR lowering 与 LLVM 渲染 | `lib/ir/dir/` |
| 编译入口 | `bin/main.ml` |
| 运行时 | `runtime/` |
| 自举切片 | `bootstrap/compiler.dm`、`bootstrap/stage1.ll` |

仓库已经有一个可工作的直接 LLVM 自举切片：Stage 0 生成 Stage 1，Stage 1 生成 Stage 2 和 Stage 3，Stage 1 还会编译样例程序并运行回归。Stage 2 自运行后生成的 LLVM 仍需要单独经过 LLVM 验证；“Stage2 进程正常退出”不能等同于“Stage3 已经完成”。

当前 DIR 文件已经形成唯一的端到端后端，并已有单元和示例回归测试：

```text
lib/ir/dir/
lib/compiler/dir_compiler.ml
```

它们提供类型化 CFG/SSA 的数据结构、验证器、文本打印器、列表/字符串/bytes/tuple lowering 和 LLVM lowering；`dream build file.dm` 使用 DIR 后端并生成 `.dir`、`.ll`。DIR 当前已覆盖整数、浮点数、布尔值、字符串、bytes、`list<i32>`、有限字段结构体、单载荷 enum（int/float/bool/str）、i32 tuple、字典（int/str 键值）、列表/字典索引与赋值、列表索引/切片/拼接、bytes 索引/切片、`append`、列表推导式、`if/elif`、while、for、条件/三元表达式、标量/列表/结构体/enum match、match guard、函数调用、`Result` 的同类型 `?` 传播和导入的标准库包装。多载荷 enum、闭包/函数值、动态对象和泛型容器仍需后续 DIR 表示设计，不能假装已经支持。

当前自举 Makefile 已增加 LLVM 预验证：Stage 0 生成 `stage1.ll`，Stage 1 生成 `stage2.ll` 和 `stage3.ll`，所有文件必须先通过 `clang -c -o /dev/null -x ir`，失败日志暂存到 `tmp/`。这只能证明 LLVM 文件合法，不能证明 Stage2→Stage3 已闭环。

Makefile 只保留任务依赖，具体流程集中在 `scripts/*.fish`：测试脚本自动发现带有
`# dream-test: smoke` 标记的示例和 `test/*_dir.dm`，bootstrap 脚本共享 runtime 文件集合、LLVM 参数和 Stage 列表；新增同类文件时无需继续扩展长命令。

## 二、目标架构

正式链路应演进为：

```text
.dm
  → Lexer
  → Parser
  → AST
  → Typeck
  → Monomorphize
  → DreamIR
  → DIR verifier
  → DIR passes
  → LLVM lowering
  → LLVM verifier
  → clang
  → runtime/
```

DreamIR 是 Dream 的语言特定中间表示，不是 LLVM 的别名。它应表达 Dream 的类型和运行时语义，而不是提前暴露 LLVM 指针、基本块标签和 ABI 细节。

职责边界如下：

| 层 | 应该负责 | 不应该负责 |
| --- | --- | --- |
| AST | 保留源代码结构、位置和语法语义 | 生成 LLVM 标签和临时变量 |
| Typeck | 类型推导、统一、泛型和模式检查 | 决定 LLVM 指针布局 |
| Monomorphize | 生成具体泛型实例 | 拼接 LLVM 文本 |
| DIR | 类型化控制流、语言操作和 SSA 值 | 目标机 ABI 细节 |
| DIR passes | 简化控制流、常量折叠、消除无用值 | 重新进行源代码类型推导 |
| LLVM lowering | 将 DIR 指令机械映射到 LLVM | 修复 DIR 类型错误 |
| runtime | 内存、字符串、列表、文件和平台服务 | 解释 Dream 语法 |

## 三、DreamIR v1 设计

### 3.1 类型

第一版只支持稳定且高频的类型：

```text
unit
bool
i32
f64
str
bytes
list<i32>
tuple<i32...>
struct<Name>
enum<Name>
result<T, E>（当前 `?` 要求传播结果类型相同）
```

后续按需求增加：

```text
tuple<T...>（当前仅 i32 元素）
function<T...>
option<T>
多载荷 enum
泛型容器
```

DIR 类型不能直接使用 `i8*`、`%dynarray_i32*` 作为语言类型。它们只能出现在 LLVM lowering 层。

### 3.2 值和指令

DIR 中的 SSA 值使用稳定的整数 ID，打印时显示为 `%v1`、`%v2`。稳定 ID 有利于：

- 固定点比较；
- 可复现构建；
- verifier 错误定位；
- CodeGraph 和调试工具分析。

第一版核心指令：

```text
const
copy
add / sub / mul / div / mod
and / or
icmp
call
string_length
string_compare
list_length
list_get
list_create
list_slice
list_concat
list_append
list_set
```

字符串和列表操作必须以高层指令存在于 DIR 中，例如：

```text
%length = string_length %text
%item = list_get %items, %index
list_append %items, %value
```

不要在前端直接拼接：

```llvm
%t = call i32 @get_dynarray_i32(...)
```

这类 ABI 细节由一个独立 lowering 函数集中处理。

### 3.3 控制流

DIR 采用显式 CFG，使用 block 参数表达 SSA 合流：

```text
func @select(%condition bool, %left i32, %right i32) -> i32 {
entry:
  branch %condition, then(%left), else(%right)

then(%value i32):
  jump merge(%value)

else(%value i32):
  jump merge(%value)

merge(%result i32):
  return %result
}
```

这样做比前端直接构造 LLVM `phi` 更容易维护。LLVM lowering 阶段再把 block 参数转换为 `phi`。

终结指令只有以下几类：

```text
jump
branch
switch
return
unreachable
```

每个 block 必须恰好有一个终结指令。`if`、`elif`、`while`、`switch` 在 DIR 中统一表示为 CFG，不在 LLVM 文本层处理语法分支。

### 3.4 调用和 runtime

DIR 调用使用逻辑函数签名：

```text
%result = call string_substring(%text, %start, %end)
```

runtime 注册表负责描述：

```text
string_substring: (str, i32, i32) -> str
list_get:          (list<i32>, i32) -> i32
```

LLVM lowering 再映射到：

```llvm
call i8* @string_substring(i8* ..., i32 ..., i32 ...)
call i32 @get_dynarray_i32(%dynarray_i32* ..., i32 ...)
```

所有 runtime 函数签名必须只有一个来源，不能在 `dir_lower.ml`、LLVM renderer 和 bootstrap 编译器中分别维护字符串常量。

## 四、必须先完成的工程基础

### 4.1 DIR verifier

LLVM 生成前必须验证 DIR。至少检查：

- 函数名、外部声明和 block 名不重复；
- SSA 值只定义一次；
- 所有使用的值已经定义；
- 指令输入和输出类型匹配；
- 调用参数数量、参数类型和返回类型匹配；
- `branch` 条件是 `bool`；
- `switch` 值和 case 类型一致；
- block 参数数量和跳转实参数量一致；
- 每个 block 都有终结指令；
- `return` 类型与函数返回类型一致；
- 目标 block 存在。

错误信息必须包含：模块、函数、block、指令和期望/实际类型。例如：

```text
DIR verification failed:
  function @append_text
  block while_body
  instruction %v12 = list_get
  expected list<i32>, got str
```

禁止让这类问题一路传到 clang 才失败。

### 4.2 LLVM verifier

每次生成 LLVM 后必须执行 LLVM 语法和类型验证。最低要求：

```text
生成 .ll
→ llvm-as / clang -fsyntax-only 验证
→ 验证通过后再链接 runtime
```

自举时要分别验证：

1. Stage 0 生成的 Stage 1 LLVM；
2. Stage 1 生成的 Stage 2 LLVM；
3. Stage 1 生成的 Stage 3 LLVM；
4. Stage 3 运行后生成的下一轮 LLVM。

### 4.3 确定性输出

DIR 和 LLVM 生成都必须满足：

- 函数顺序稳定；
- block 顺序稳定；
- value ID 分配稳定；
- 字符串常量编号稳定；
- runtime 声明排序稳定；
- 不依赖哈希表遍历顺序。

固定点比较应比较规范化后的 DIR，而不是直接比较可能包含临时编号、目标信息或 metadata 差异的 LLVM 文本。若最终需要可复现发布，再额外追求相同工具链下的字节级产物一致性；它不是判断编译器语义正确的唯一标准。

## 五、正式迁移顺序

### 阶段 0：固定 DIR 正式后端

正式编译器统一使用：

```text
mono_ast → Dir_lower → Dir_verify → Dir_lower_llvm
```

退出条件：

- `dune build` 通过；
- DIR 单元测试通过；
- 现有 examples 和 runtime 测试不回退。

### 阶段 1：手工构造 DIR 并降低到 LLVM

先让以下程序通过：

- 整数常量；
- `add`；
- 比较和条件分支；
- while CFG；
- 函数调用；
- block 参数和 LLVM `phi`。

此阶段不涉及 AST，目的是证明 DIR 数据结构和 LLVM lowering 本身正确。

### 阶段 2：AST 到 DIR 的整数子集

支持：

- `int`、`bool`；
- 变量；
- 算术和比较；
- `let`、赋值、`return`；
- `if`、`elif`、`while`；
- 普通函数和函数调用。

生成器应采用 builder，而不是直接操作 block 列表：

```text
emit_expr
emit_statement
create_block
set_current_block
emit_instruction
terminate
```

builder 负责 value ID 和 block 名，lowering 只读取已经完成的 DIR。

### 阶段 3：字符串、列表和 runtime

把现有 LLVM 后端中所有字符串和动态数组逻辑迁移为 DIR 高层指令。此阶段重点是 ABI 测试：

- 字符串参数和返回值；
- 字符串比较、切片和长度；
- 列表创建、索引、追加和长度；
- tuple、bytes 和文件 I/O 的 runtime 边界。

每个 runtime 操作至少需要一个 DIR 测试和一个链接后运行测试。

### 阶段 4：接入正式编译入口

正式编译入口保持单一 DIR 路径：

```text
dream build file.dm              # DIR 编译管线
dream emit-dir file.dm
dream emit-llvm file.dm
```

`.dir` 用于调试和验证，`.ll` 用于链接生成可执行文件。

### 阶段 5：自举 DIR 编译管线

自举编译器必须实现：

```text
Dream source → DreamIR → LLVM
```

`bootstrap/compiler.dm` 不应再直接拼接 LLVM 指令字符串。当前自举切片仍保留 LLVM 文本生成作为兼容边界，但编译器源码已经按职责拆成：

```text
bootstrap/compiler.dm
bootstrap/compiler_lex.dm
bootstrap/compiler_expr.dm
bootstrap/compiler_stmt.dm
bootstrap/compiler_main.dm
```

仓库中的对应实现是 `bootstrap/compiler.dm` 作为导入入口，配合 `compiler_lex.dm`、`compiler_expr.dm`、`compiler_stmt.dm` 和 `compiler_main.dm`。宿主模块加载器与自举阶段的源码加载器都必须以确定顺序解析这些本地模块，并对重复导入去重。

先用 OCaml 编译器把这些文件编译成 Stage 1，再由 Stage 1 编译自身生成 Stage 2。只有当 Stage 2 能生成合法的下一轮 DIR 和 LLVM，才算完成真正自举。

迁移初期先完成了直接 LLVM 自举切片的 Stage 0 → Stage 1 → Stage 2 → Stage 3 固定点，再逐步把 `bootstrap/compiler.dm` 接入 DIR。这样可以把自举链路问题与中间表示迁移问题分开验证；当前正式编译器已经只保留 DIR 路径。

当前实现状态已经进入迁移后的稳定化阶段：`make bootstrap` 使用 Stage 0 生成 Stage 1，再完成 Stage 0 → Stage 1 → Stage 2 → Stage 3 固定点验证。`bootstrap/compiler.dm` 已经从 `stdlib/dir_bootstrap.dm` 导入 DIR 构建与渲染桥。自举桥采用定长 typed record payload；`ret`、整数算术、`and/or`、整数 `icmp`、`zext i1 -> i32` 和零操作数 `unreachable` 已使用 native record，尚未覆盖的 `call`、指针操作和复杂可变参数指令继续走经过校验的 raw LLVM 兼容路径。后续迁移应按“固定 payload ABI、增加负例测试、验证 Stage2/Stage3 固定点”的顺序逐条推进。

## 六、自举验证协议

自举不能只依赖 `make bootstrap` 的退出码。建议固定为以下协议：

```text
1. 构建 Stage 0
2. Stage 0 生成 `stage1.ll`
3. LLVM verifier 验证 `stage1.ll`
4. 链接并运行 Stage 1
5. Stage 1 生成 `stage2.ll`、`stage3.ll` 和样例 LLVM
6. LLVM verifier 验证 Stage 2/3 的 LLVM
7. 链接并运行 Stage 2
8. Stage 2 编译 `compiler.dm` 自身
9. 链接并运行 Stage 3
10. 比较 Stage 2 与 Stage 3 的规范化 DIR/LLVM
11. 使用 Stage 2 构建自举语法子集的回归样例
```

规范化比较至少应去除构建路径、时间戳、随机命名和目标机 metadata；不能去除会影响语义的类型、控制流、调用签名或常量内容。

任一步失败，都必须保留：

```text
tmp/bootstrap-manifest.json
tmp/stageN-input.dm
tmp/stageN-output.dir
tmp/stageN-output.ll
tmp/stageN-error.log
```

这些文件必须进入 `tmp/`，不能散落在仓库根目录或覆盖源文件。

## 七、自举调试最佳实践

### 7.1 不使用无界临时打印

直接在 parser 中加入 `print` 会改变生成代码、放大输出，并可能让崩溃位置发生变化。应使用结构化 trace：

```text
--trace=parse,dir,lower
```

每条 trace 至少包含：

```text
stage
function
block
source span
current value
instruction count
output size
```

### 7.2 每个循环都要有 progress watchdog

前端循环必须记录并检查：

- 当前 token/index 是否推进；
- 单个函数生成的 DIR 指令数；
- 单个函数生成的输出字节数；
- block 数是否超过预算。

发生异常时立即报告上下文，而不是让数组扩大到 GiB 后触发内存错误。

### 7.3 分层缩小失败样本

调试顺序应是：

```text
源文件
→ token dump
→ AST dump
→ typed AST dump
→ DIR dump
→ verifier error
→ LLVM dump
→ clang error
→ runtime 执行
```

每一层都要能单独保存和重新输入，避免只能通过完整 bootstrap 重现。

### 7.4 CodeGraph 使用规则

仓库存在 `.codegraph/` 时，先用 CodeGraph 定位符号和调用路径。修改文件后，如果还要继续查询，必须先执行：

```text
codegraph sync
```

DIR 引入后应让 CodeGraph 能分析：

- AST 到 DIR 的调用路径；
- DIR verifier 的错误传播；
- DIR 到 LLVM 的 lowering；
- runtime intrinsic 的注册和使用。

## 八、测试金字塔

### 单元测试

- 类型相等和格式化；
- operand 类型检查；
- block 参数检查；
- 重复 value 检查；
- 未定义 block 和 value；
- return 类型错误；
- DIR 打印稳定性。

### lowering 测试

- DIR 输出包含预期 LLVM 类型；
- block 参数生成 `phi`；
- `switch` 生成 LLVM switch；
- string/list intrinsic 映射正确；
- LLVM verifier 通过。

### 编译器测试

- AST → DIR 的每个语法构造；
- 类型错误不会生成 DIR；
- DIR lowering 和 LLVM renderer 在覆盖范围内行为一致。

### 端到端测试

- examples；
- `test/test_elif_switch.dm`；
- 字符串和列表；
- 文件和 bytes；
- 模式匹配、enum、union、struct；
- 编译器自编译。

### 自举测试

- Stage 0 生成合法 Stage 1；
- Stage 1 生成合法 Stage 2/Stage 3；
- Stage 2 继续生成合法 Stage 3；
- Stage 3 可运行；
- 两轮 DIR 达到固定点；
- 失败时诊断文件完整保留。

`make bootstrap` 现在会在链接 Stage 1/Stage 2/Stage 3 前自动运行 LLVM 验证。单独检查已有产物时可运行：

```text
make bootstrap-verify
```

## 九、暂不应该做的事情

- 不要在 AST 层拼 LLVM 文本；
- 不要让 LLVM 类型反向污染类型检查器；
- 不要把 `i8*` 当作 Dream 的 `str` 类型；
- 不要在多个模块复制 runtime 函数签名；
- 不要在 verifier 之前调用 clang 作为类型检查器；
- 不要在 Stage2 崩溃前依赖无限制输出数组；
- 不要为了追求一次性全功能而跳过 DIR 的最小闭环；
- 不要把生成的 `.ll`、二进制和诊断文件混入源代码提交。

## 十、完成定义

DreamIR 阶段完成的标志不是“新增了几个类型”，而是同时满足：

1. AST 可以生成类型完整的 DIR；
2. DIR verifier 能在 LLVM 前报告错误；
3. DIR lowering 生成 LLVM 并通过 LLVM verifier；
4. 现有 examples 和 runtime 测试无回归；
5. DIR lowering 和 LLVM renderer 在覆盖范围内行为一致；
6. Stage 1 能编译 DIR 管线；
7. Stage 2 能生成合法的下一轮 DIR 和 LLVM；
8. Stage 3 可以运行并达到固定点。

在达到第 8 条之前，项目状态只能描述为“DIR 迁移中，尚未完成真正自举”。
