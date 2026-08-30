# Dream 语言自举路线图

## 目标
用 Dream 语言重新实现 Dream 编译器，实现自举（self-hosting）。

## 自举阶段定义

项目采用标准的 Stage 0 → Stage 1 → Stage 2 → Stage 3 编号。编号表示“使用哪个编译器编译下一个编译器”，样例程序不属于自举阶段。

| 阶段 | 编译器 | 输入 | 产物与职责 |
| --- | --- | --- | --- |
| Stage 0 | `ocaml/_build/default/bin/main.exe`（宿主 OCaml 编译器） | `bootstrap/compiler.dm` | 生成并链接 `tmp/stage1` |
| Stage 1 | `tmp/stage1`（Stage 0 生成） | `bootstrap/compiler.dm` | 通过通用 `compile` CLI 生成 `stage2.ll` |
| Stage 2 | `tmp/stage2`（Stage 1 生成） | `bootstrap/compiler.dm` | 在完整模式下生成 `stage3.ll`；也是 `bootstrap-build` 使用的编译器 |
| Stage 3 | `tmp/stage3`（Stage 2 生成） | `bootstrap/compiler.dm` | 编译并执行通用 CLI，确认 Stage 2/3 固定点 |

执行顺序如下（所有 stage 产物在 `tmp/`，源码在 `bootstrap/`）：

```text
Stage 0: OCaml compiler
    └─ compiler.dm → stage1.ll → tmp/stage1
        └─ compiler.dm → stage2.ll → tmp/stage2
            └─ compiler.dm → stage3.ll → tmp/stage3
                └─ compiler.dm → stage2.ll / stage3.ll（必须达到固定点）
```

`tmp/sample_functions` 只是由 Stage 1 编译出的功能回归样例，不是 Stage 1 编译器。`compiler.ll` 也不再作为阶段产物保留；Stage 0 生成的编译器统一命名为 `stage1.ll` 和 `stage1`。

## 当前自举进度

### 新管线（AST → lower → DIR → LLVM）自举里程碑

编译器主链已统一为新管线：`lex → collect → AST 节点池 → lower 顶向下遍历 → 结构化 DIR records → dir_render_records → LLVM`（`DEBUG` 与否均走新管线；旧 HIR/DM_DIR/emit 管线代码保留但不再执行，待 P5 清理）。已完成完整自举验证：

- Stage 1（新管线）编译 `compiler.dm` 成功生成 Stage 2，链接无 LLVM 错误；
- Stage 2（新管线）编译 `compiler.dm` 成功生成 Stage 3；
- Stage 3 编译并运行程序（hello 输出 `hello`）验证功能；
- 测试套件（含 `def main` 的用例）15 通过 / 7 待实现（enum/match/lambda lower）；
- `make bootstrap-build` 产物（无 DEBUG）与 `DEBUG=1` 行为一致，均走新管线。
- 标准库网络基础已接入：`runtime/stdlib/net.dm` 的 `Connection` 支持阻塞式 TCP 连接、`write`、`read`、`read_n` 和 `close`，Stage 2 可直接编译运行。
- `runtime/stdlib/http.dm` 已接入基于 libcurl 的 HTTP/HTTPS GET/POST、状态码、headers 和 body 解析；运行时支持超时、重定向、压缩和自定义请求头，回归测试使用不联网的错误路径。

本次自举打通修复的关键问题：

- **AST 节点容量溢出**：`ARGS_STRUCT` 18→26（ParseContext 15 字段）、`ARGS_DICT` 25→41（KEYWORD_DICTIONARY 18 对）、call 节点 20 实参槽；溢出导致节点槽读到相邻节点数据（`kind=0 at node=26` / `bad node=token_start` 现象）。
- **alloca 提升**：`append_hoisted_function` 把条件分支内的 alloca 提升到函数头。新管线 FUNCTION 记录含 `entry:` 文本、旧管线 entry: 是独立 BLOCK，按 FUNCTION 后首条记录是否为 BLOCK 区分，提升位置分别落在 entry 指令前 / entry: 后。
- **struct 字段存储/读取**：字面量 append 按元素类型分派（`lower_append_collection_value`，指针 2 槽）；attr 读取指针字段用 `get_pointer` + bitcast（原 `get` 只读低 32 位）；struct 声明名哈希预收集（`STRUCT_DECLARATION_HASHES`），字段查找从全 token 扫描改为 O(1) 定位。
- **全局 let**：lower_program 生成 `@name = global <ty> zeroinitializer` 定义段，main 入口评估初始化表达式并 store（含 dict 字面量的 key/value 类型分派）。
- **list[str] 类型**：新增 `VALUE_TYPE_LIST_STRING`，参数类型收集与注解解析识别 `list[str]`，索引用 `get_pointer`（槽偏移 ×2）；旧管线在非新管线入口把该类型归一化为 `VALUE_TYPE_LIST`。
- **tuple 解包**：按被调函数返回类型注解（`-> (...)`）判断元素是否指针，指针元素用 `get_pointer` 并累计槽偏移。
- **ord**：身份函数透传（rune 与 int 底层同 i32），避免生成未声明的 `@ord` 调用。
- **KEYWORD_DICTIONARY 初始化**：全局 dict 由 main 入口按字面量求值填充，修复 `def` 等关键字被识别为 IDENTIFIER。
- **范围比较与哈希提速**：runtime 新增 `__c_range_equal`（按 rune 定位后 memcmp）与 `__c_fnv_hash_range`（一次扫描 FNV-1a 变体），`source_ranges_equal` 从「切片+字符串比较」（两次分配+全量扫描）改为单次定位+memcmp；两者在 OCaml 编译器（`env.ml` 类型、`dir_lower.ml` runtime_externs）与新管线 extern 声明中注册。

性能（-O2 生产配置，stage1 编译 compiler.dm）：

- 优化前 lower ~8.1s；优化后 **lower ~2.7s**（约 3 倍提速），单次编译 ~3.0s；
- 明细：lex ~50ms / collect ~115ms / ast ~105ms / lower ~2.7s（占 90%）；
- 完整自举链（stage0 → stage1 → stage2 → stage3）约 28s。

剩余热点：`lower_expr` 内字符串切片（变量名/函数名提取）仍走 utf8 缓存路径；进一步优化方向为 token 字节偏移表（编译期一次预计算 rune→字节映射，切片/比较全走 memcmp）。

待实现（P3）：enum/match/lambda 的 lower 处理（`AST_EXPR_ENUM`/`AST_EXPR_BUILTIN_ENUM`/`AST_EXPR_MATCH`/`AST_EXPR_LAMBDA` 落入 default 返回常量），对应 7 个测试用例。

### Stage 1/2 的边界

Stage 1 和 Stage 2 的首要目标是编译 `bootstrap/compiler.dm` 自身；完整语言能力按可独立验证的语法块逐步迁移。`make bootstrap` 只验证 `examples/lang_full_dream.dm` 和 `examples/lang_full_ocaml.dm` 两个完整语言样例：前者作为 Stage 2/Stage 3 的综合 build/run 回归，后者由宿主编译器验证宿主语言覆盖。单项语法和运行时回归使用 `make test` 或针对性的 `make bootstrap-build FILE=...`。

以下能力属于完整语言路线，但不是当前自举前置条件：

- bytes 的完整高级语义；当前 bootstrap 已覆盖 bytes 基础构造、索引、切片、转换和列表互转；
- 更丰富的捕获变量闭包语义（嵌套捕获、可变共享捕获和动态对象）；当前已覆盖字符串、布尔、浮点和列表等基础捕获类型；
- 完整类型推导和泛型实例化；
- 为覆盖示例而增加的临时 LLVM 文本生成分支。

这些能力仍由宿主 DIR 编译器和 `lang_full_dream.dm` 验证，待 DM 编译器完成 AST、类型检查和 DreamIR 管线后再迁移。当前 bootstrap 编译器的 lexer、表达式/语句解析仍是过渡实现；其发射器已直接构建结构化 DIR records，与 OCaml 版本保持同一流水线方向（`token/HIR → 结构化 DIR records → DIR verifier → DIR LLVM lowering → LLVM IR`），不再存在「先生成 LLVM 文本、再反解析为 DIR」的反向路径。

**Stage 1/2 已支持能力**（综合回归见 `make bootstrap`，单项回归见 `make test` 或 `make bootstrap-build FILE=...`）：

- 基础：整数、变量、四则运算、`let`、函数声明/参数/`return`/调用、`print`、字符串、列表、循环、`switch/case/default`
- 集合：整数列表字面量/索引/赋值/推导式、`for value in list[int]`、整数 tuple 字面量/解包、一元负号
- 结构体：整数结构体构造/乱序初始化/字段访问、作为函数参数和返回值、模式匹配字段绑定
- bytes 基础 ABI：`encode`/`decode`/`from_list`/`to_list`、索引、切片（链接用 `wrappers/bytes.c` 的 `__c_*` ABI）
- 网络基础 ABI：`net.connect` 返回 `Connection`，支持 `connection.write(text)`、`connection.read()`、`connection.read_n(size)` 和 `connection.close()`；C 实现位于 `wrappers/net.c`，测试使用本地 loopback，不依赖公网
- HTTP 基础：`http.get`、`http.post` 和 `http.request` 通过 libcurl 发送 HTTP/HTTPS 请求，返回 `Response{status, headers, body, error}`；headers 使用名称和值交替的 `list[str]`
- match：`switch/case/default` 支持 int/bool/float/str；整数 `match`、通配符、`[tag, payload]` 基础 enum match（用户 enum + Some/None + Ok/Err）
- 其他：`str + str` 统一 lowering 到 `string_concat`；DIR records 用 `DmDirRecord` 结构体字面量构造，`list[int]` 仅作为固定 12 槽序列化 ABI；`bootstrap_build.fish` 通过 Stage 2 `build` CLI 构建子集，runtime linker 动态扫描 `runtime/c/core/*.c` 和 `runtime/c/wrappers/*.c`
- CLI 与格式：Stage 1/2 提供 `build`/`llvm`/`dir` CLI；宿主与 DM 统一输出正式 DreamIR 文本，typed record 仅为内部序列化 ABI，未映射指令以 `native llvm` 记录保留
- 固定点：Stage 0 → 1 → 2 → 3 字节一致固定点，Stage 3 独立执行 `lang_full_dream.dm` 综合 `dir`/`build` 回归；其他 DIR 和语法样例不在自举主流程中重复执行。

**待接入**：

- `list[DmDirRecord]`：当前 Stage 2/runtime 列表 ABI 是 `dynarray_i32`，直接放结构体会丢失元素布局，待通用 boxed/generic list ABI 稳定

宿主 OCaml 编译器的能力历史（混合类型元组/容器、接口/impl、运算符重载、`match type of`、默认参数、全局 `let` 等）见「已完成里程碑 ✅」。

### 使用 bootstrapped 编译器

先生成并验证 Stage 2：

```fish
make bootstrap
```

构建当前自举子集中的源文件：

```fish
fish scripts/bootstrap_build.fish run test/fixtures/bootstrap_sample_functions.dm
```

或者：

```fish
make bootstrap-build FILE=test/fixtures/bootstrap_sample_functions.dm
```

这条路径使用 `tmp/stage2`，不会调用 `ocaml/_build/default/bin/main.exe` 编译目标文件。当前自举编译器已经稳定覆盖编译器自身和登记的 DIR 回归子集；超出该集合的语法仍会在 DIR/LLVM 验证或链接阶段报告失败，而不会被标记为完整语言支持。

直接让某个自举阶段输出 LLVM：

```fish
tmp/stage1 llvm bootstrap/compiler.dm -o tmp/stage2-from-stage1.ll
tmp/stage2 llvm bootstrap/compiler.dm -o tmp/stage3-from-stage2.ll
```

输出应分别与 `tmp/stage2.ll`、`tmp/stage3.ll` 一致；输出文件属于临时产物，应放在 `tmp/`。

没有显式 `def main()` 的示例会由 `bootstrap_build.fish` 在 `tmp/` 中生成临时入口，将顶层可执行语句放入 `main` 后再交给 Stage 2；临时文件会在脚本退出时清理。

---

## 技术取舍

Dream 的目标是稳定自举，关键取舍（结论来自对业界建议的评估）：

| 建议 | Dream 决策 | 原因 |
| --- | --- | --- |
| RFC、可执行规范、分层测试 | 采纳 | 先固定语义和边界条件，减少自举期间的隐性变化 |
| Tree-sitter 替换 Parser | 不采纳 | Tree-sitter 是编辑器增量解析工具；现有 Menhir 前端已可用，替换会扩大迁移范围 |
| HIR/MIR | 合并为渐进路线 | 类型检查后的 AST 承担 HIR 角色；DreamIR v1 承担类型化 CFG/SSA，避免同时维护三套表示 |
| MLIR 方言 | 不采纳 | 当前瓶颈是自举正确性和 LLVM 边界，不是缺少通用 IR 基础设施 |
| LLVM 后端 | 采纳 | 先保留文本 LLVM，验证稳定后再考虑 API/bitcode |
| Cranelift | 不采纳 | 适合 JIT/Wasm，不能解决 Stage2 生成非法 LLVM 的问题 |
| 三阶段自举 | 采纳 | 验收以规范化 DIR、LLVM 验证和行为测试为主，字节级一致性是可选增强 |

目标架构为单一直线链路，不保留两套后端：

```text
AST → 类型检查后 AST → 单态化 → DreamIR（类型化 CFG/SSA）→ DIR verifier → DIR passes → LLVM lowering → LLVM verifier → clang + runtime
```

## 职责边界

| 层 | 应该负责 | 不应该负责 |
| --- | --- | --- |
| AST | 保留源代码结构、位置和语法语义 | 生成 LLVM 标签和临时变量 |
| Typeck | 类型推导、统一、泛型和模式检查 | 决定 LLVM 指针布局 |
| Monomorphize | 生成具体泛型实例 | 拼接 LLVM 文本 |
| DIR | 类型化控制流、语言操作和 SSA 值 | 目标机 ABI 细节 |
| DIR passes | 简化控制流、常量折叠、消除无用值 | 重新进行源代码类型推导 |
| LLVM lowering | 将 DIR 指令机械映射到 LLVM | 修复 DIR 类型错误 |
| runtime | 内存、字符串、列表、文件和平台服务 | 解释 Dream 语法 |

### DreamIR 设计要点

- **类型**：v1 支持 `unit/bool/i32/f64/str/bytes/list<i32>/tuple<i32...>/struct<Name>/enum<Name>/result<T,E>`；`tuple<T...>`、`function<T...>`、`option<T>`、多载荷 enum、泛型容器按需扩展。DIR 类型不能直接使用 `i8*`、`%dynarray_i32*`，它们只能出现在 LLVM lowering 层。
- **SSA 值**：使用稳定的整数 ID，打印为 `%v1`、`%v2`，利于固定点比较、可复现构建、verifier 错误定位。
- **高层指令**：字符串/列表操作必须以高层指令存在（`string_length`、`list_get`、`list_append` 等），ABI 细节由独立的 lowering 函数集中处理，禁止前端直接拼接 `call i32 @get_dynarray_i32(...)`。
- **控制流**：显式 CFG + block 参数表达 SSA 合流；LLVM lowering 阶段再转 `phi`。终结指令只有 `jump/branch/switch/return/unreachable`，每个 block 恰好一个。`if/elif/while/switch` 统一表示为 CFG，不在 LLVM 文本层处理语法分支。
- **调用**：DIR 调用使用逻辑函数签名，runtime 注册表描述签名（如 `string_substring: (str, i32, i32) -> str`），LLVM lowering 再映射 ABI。**所有 runtime 函数签名必须只有一个来源**，不能在 `dir_lower.ml`、LLVM renderer 和 bootstrap 编译器分别维护字符串常量。

## 工程约束

- **DIR verifier**：LLVM 生成前必须验证 DIR（函数/block 名不重复、SSA 只定义一次、使用值已定义、输入输出类型匹配、调用签名匹配、`branch` 条件是 bool、`switch` case 类型一致、block 参数与跳转实参数量一致、每个 block 有终结指令、`return` 类型一致、目标 block 存在）。错误信息必须包含模块、函数、block、指令和期望/实际类型；禁止让问题一路传到 clang 才失败。
- **LLVM verifier**：每次生成 LLVM 后必须验证（自举时逐级验证 Stage 1/2/3 产出的 LLVM），通过后再链接 runtime。
- **确定性输出**：函数/block/value ID/字符串常量编号/runtime 声明排序稳定，不依赖哈希表遍历顺序。固定点比较应比较规范化后的 DIR（去除路径、时间戳、随机命名和目标机 metadata；不能去除影响语义的类型、控制流、调用签名或常量）。
- **不做什么**：不在 AST 层拼 LLVM 文本；不让 LLVM 类型反向污染类型检查器；不把 `i8*` 当作 Dream 的 `str`；不在多个模块复制 runtime 函数签名；不在 verifier 之前用 clang 当类型检查器；不依赖无限制输出数组；不跳过 DIR 最小闭环；不把生成的 `.ll`、二进制和诊断文件混入源码提交。

## 自举验证协议

```text
1. 构建 Stage 0
2. Stage 0 生成 stage1.ll
3. LLVM verifier 验证 stage1.ll
4. 链接并运行 Stage 1
5. Stage 1 生成 stage2.ll、stage3.ll 和样例 LLVM
6. LLVM verifier 验证 Stage 2/3 的 LLVM
7. 链接并运行 Stage 2
8. Stage 2 编译 compiler.dm 自身
9. 链接并运行 Stage 3
10. 比较 Stage 2 与 Stage 3 的规范化 DIR/LLVM
11. 使用 Stage 2 构建自举语法子集的回归样例
```

任一步失败必须保留诊断到 `tmp/`（`tmp/stageN-input.dm`、`tmp/stageN-output.dir`、`tmp/stageN-output.ll`、`tmp/stageN-error.log`、`tmp/bootstrap-manifest.json`），不能散落在仓库根目录或覆盖源文件。

## 调试与测试

- **结构化 trace 而非无界打印**：直接在编译器里 `print` 会改变生成代码并放大输出；用 `DEBUG` 环境变量控制分段计时与关键路径输出。
- **循环 watchdog**：前端循环记录 token/index 是否推进、单函数 DIR 指令数/输出字节数、block 数预算，异常时立即报告上下文。
- **分层缩小失败样本**：源文件 → token dump → AST dump → typed AST dump → 正式 DreamIR dump → verifier error → LLVM dump → clang error → runtime 执行，每层可单独保存和重新输入。
- **测试金字塔**：DIR 单元测试（类型/block 参数/重复 value/return 类型/打印稳定）→ lowering 测试（phi/switch/intrinsic 映射/verifier 通过）→ 编译器测试（AST→DIR 各构造、类型错误不生成 DIR）→ 端到端（`make test`）→ 自举测试（`make bootstrap` 仅验证两个 `examples/lang_full_*.dm` 完整样例、各级生成合法产物、固定点和诊断完整）。

## 已完成里程碑 ✅

宿主 OCaml 编译器的语言特性已全部完成并固化（详见 docs/ 专题文档与 TODO.md「已完成」）。自举按「直接 LLVM 自举切片固定点 → DM DIR records 接入 → 结构化 DIR 主链 → 新管线（AST 节点池 → lower → DIR → LLVM）」推进，旧路线图的阶段 0~3（固定 DIR 后端、手工 DIR lowering、AST 整数子集、字符串/列表/runtime 迁移）与语言特性阶段（字符串/文件 I/O/错误处理/字典/元组/枚举/模式匹配/结构体/泛型/Union）均已完成：

- 基础类型系统、函数与递归、控制流、列表/字典/元组/枚举/模式匹配/Union、字符串方法、文件 I/O、`Option/Result/?`/三元、单态化、混合类型元组/容器（`list[str]`、`list[tuple]`）、接口/impl（引用计数托管、类型 tag、enum 具体类型）、运算符重载全集、`match type of`、默认参数、全局 `let`、DIR 后端全部完成；
- Stage 0 → 1 → 2 → 3 全链固定点达成（字节级一致 + DIR 回归）；
- 新管线自举打通（见「当前自举进度」），Stage 1/2/3 提供 `build`/`compile`/`dir` CLI；
- 性能：`source_type_is_interface` 预收集（emit 38s → 11.3s）、keyword_kind 字典化（271s → 47s）、`__c_range_equal`/struct 哈希（lower 8.1s → 2.7s）。

## 待办

完整任务列表见 [TODO.md](TODO.md)。当前自举相关待办：

- 冻结 bootstrap 语法子集，增加语法边界和行为回归协议；
- enum/match/lambda 的 lower 处理（`AST_EXPR_ENUM`/`AST_EXPR_BUILTIN_ENUM`/`AST_EXPR_MATCH`/`AST_EXPR_LAMBDA` 落入 default，7 个测试待实现）；
- 用 Dream 重写完整 lexer、parser、typechecker 和 DIR compiler，完成真正的完整编译器自举（不止 `bootstrap/compiler.dm` 切片）；
- `list[DmDirRecord]` 通用 boxed/generic list ABI；
- 性能：`lower_expr` 字符串切片改走 token 字节偏移表；
- 宿主已知缺口：`str.split` 的 str 列表容器操作、tuple 模式匹配（DIR scrutinee 不支持 tuple）。
