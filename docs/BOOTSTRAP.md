# Dream 语言自举路线图

## 目标
用 Dream 语言重新实现 Dream 编译器，实现自举（self-hosting）。

## 自举阶段定义

项目采用标准的 Stage 0 → Stage 1 → Stage 2 → Stage 3 编号。编号表示“使用哪个编译器编译下一个编译器”，样例程序不属于自举阶段。

| 阶段 | 编译器 | 输入 | 产物与职责 |
| --- | --- | --- | --- |
| Stage 0 | `_build/default/bin/main.exe`（宿主 OCaml 编译器） | `bootstrap/compiler.dm` | 生成并链接 `bootstrap/stage1` |
| Stage 1 | `bootstrap/stage1`（Stage 0 生成） | `bootstrap/compiler.dm` | 通过通用 `compile` CLI 生成 `stage2.ll` |
| Stage 2 | `bootstrap/stage2`（Stage 1 生成） | `bootstrap/compiler.dm` | 在完整模式下生成 `stage3.ll`；也是 `bootstrap-build` 使用的编译器 |
| Stage 3 | `bootstrap/stage3`（Stage 2 生成） | `bootstrap/compiler.dm` | 编译并执行通用 CLI，确认 Stage 2/3 固定点 |

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

### 新管线（AST → lower → DIR → LLVM）自举里程碑

编译器主链已统一为新管线：`lex → collect → AST 节点池 → lower 顶向下遍历 → 结构化 DIR records → dir_render_records → LLVM`（`DEBUG` 与否均走新管线；旧 HIR/DM_DIR/emit 管线代码保留但不再执行，待 P5 清理）。已完成完整自举验证：

- Stage 1（新管线）编译 `compiler.dm` 成功生成 Stage 2，链接无 LLVM 错误；
- Stage 2（新管线）编译 `compiler.dm` 成功生成 Stage 3；
- Stage 3 编译并运行程序（hello 输出 `hello`）验证功能；
- 测试套件（含 `def main` 的用例）15 通过 / 7 待实现（enum/match/lambda lower）；
- `./bootstrap/compiler build`（无 DEBUG）与 `DEBUG=1` 行为一致，均走新管线。

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

Stage 1 和 Stage 2 的首要目标是编译 `bootstrap/compiler.dm` 自身；完整语言能力按可独立验证的语法块逐步迁移。因此自举验收使用 `make bootstrap` 以及 `scripts/bootstrap.fish` 中登记的回归，`examples/lang_full_dream.dm` 已作为 Stage2/Stage3 的综合 build/run 回归，但不要求 Stage 1 直接支持它。

以下能力属于完整语言路线，但不是当前自举前置条件：

- bytes 的完整高级语义；当前 bootstrap 已覆盖 bytes 基础构造、索引、切片、转换和列表互转；
- 更丰富的捕获变量闭包语义（嵌套捕获、可变共享捕获和动态对象）；当前已覆盖字符串、布尔、浮点和列表等基础捕获类型；
- 完整类型推导和泛型实例化；
- 为覆盖示例而增加的临时 LLVM 文本生成分支。

这些能力仍由宿主 DIR 编译器和 `lang_full_dream.dm` 验证，待 DM 编译器完成 AST、类型检查和 DreamIR 管线后再迁移。当前 bootstrap 编译器的 lexer、表达式/语句解析仍是过渡实现；其发射器已直接构建结构化 DIR records，与 OCaml 版本保持同一流水线方向（`token/HIR → 结构化 DIR records → DIR verifier → DIR LLVM lowering → LLVM IR`），不再存在「先生成 LLVM 文本、再反解析为 DIR」的反向路径。

- [x] Stage 1 支持整数、变量、四则运算、`let`、函数声明、参数、`return`、调用、`print`、字符串、列表、循环和 `switch/case/default`。
- [x] Stage 0 生成并运行 Stage 1；Fish 通过通用 `compile` CLI 依次生成并链接 Stage 2、Stage 3。
- [x] Stage 2、Stage 3 可以运行并生成字节一致的 LLVM 固定点。
- [x] Stage 1/2/3 已使用 DM DIR function records 驱动函数 lowering，并通过 `compiler_dir.dm` 生成并验证 DM 侧 DIR 内存记录，再通过 `dir_render_records` 结构化 DIR 路径；Stage2/Stage3 已达到固定点。
- [x] Stage 1 和 Stage 2 支持 `build <input.dm> -o <output>` 直接生成可执行文件；`llvm <input.dm> -o <output.ll>` 输出 LLVM IR（`compile` 为兼容别名）；`dir <input.dm> -o <output.dir>` 输出正式 DreamIR。主路径显式执行“DIR source → typed DIR records → DIR renderer → LLVM”，所有 Stage 编排由 Fish 完成，DM 编译器不包含阶段专用参数。
- [x] 宿主 OCaml 编译器和 bootstrap 编译器统一提供 `dir <input.dm> -o <output.dir>`；唯一公共格式是正式 DreamIR 文本，低层 typed record 只作为内部 DIR 序列化 ABI，不作为第二种输出格式。DM 端已接入 `dir_render_formal_records`，并将 LLVM 分支转换为正式 `jump`/`branch`；整数/浮点 SSA 比较和浮点二元运算已在可保真场景使用结构化 native record，暂未映射到高层 DIR 的指令以正式 `native llvm` 记录保留，后续逐条替换为 DreamIR 指令。
- [x] DM 编译器主链已改为与 OCaml 版本一致的流水线：发射器直接构建结构化 DIR records（逐行转换 + native record），经 `dir_validate_records` 验证后由 `dir_render_records` 降级为 LLVM IR；`dir_build_source_records`（LLVM 文本反解析）已从主链移除，`dir` 命令的正式 DreamIR 由 `dir_render_formal_records` 直接从 records 渲染。
- [x] 宿主 OCaml 编译器支持任意混合类型元组（DIR 元组 LLVM 表示从 `%dynarray_i32*` 改为 `%dynarray_ptr*`，intptr_t 槽位按元素类型编码/解码：i32/bool 位扩展截断、f64 位变换、指针类型 ptrtoint/inttoptr、struct/interface 聚合经 `dream_closure_alloc` 装箱）；`dir_lower.ml` ETuple 不再强制元素为 i32，`dir_verify.ml` 按元素类型逐项验证；混合元组用例已并入 `examples/lang_full_ocaml.dm`（字面量、索引、解包、`(int, str)` 函数返回、嵌套元组）。顺带修复顶层 `let f = func` 的 Func 类型全局变量调用（ECall 守卫识别 Func 全局并先 GlobalLoad 再间接调用），`test/test_function_value_dir.dm` 回归通过（输出 `42`）。
- [x] 宿主 OCaml 编译器补齐混合类型容器：`list[str]` 与 `list[tuple]`（LLVM 表示 `%dynarray_ptr*`，ListGet/Create/Slice/Concat/Length 按元素类型分派 i32/ptr 变体，runtime 新增 `slice_dynarray_ptr`/`concat_dynarray_ptr`）；`str.split`/`str.join`（runtime `string_split`/`string_join`）、`dict_items`（新增 runtime `dict_items_tuples` 返回通用元组元素，支持 `for (k, v) in dict_items(d)` 元组解包）；tuple 作为 match scrutinee（常量元素链式比较 + 变量/通配符/嵌套元组模式绑定，穷尽性检查 `is_covered` 修复失败不回退通配符的 bug）。顺带修复 `IDENT.IDENT` 形式在全局变量上的方法调用（EEnumVariant 分支支持全局 Str/Struct/Interface 接收者）、无参方法链式调用（typecheck 返回调用结果）、`verify_call` 注册指令实际返回类型（泛型调用）；`test_function_value_dir.dm`、`test_struct_dir.dm` 回归通过。覆盖用例并入 `examples/lang_full_ocaml.dm`（split/join/is_digit/is_alpha/is_whitespace/strip、dict_items、tuple match、ord、全局变量读写）。
- [x] 宿主 OCaml 编译器接口值支持 enum 具体类型（不再限于 struct）：`types.ml` unify 补 TyEnum 分支（此前 enum 类型 unify 会 occurs check 误报）、`tc_stmt` impl target 类型解析识别枚举名、`tc_expr` 无参接口方法调用推断修正；DIR `method_definitions`/`interface_implementations` 收集 enum 的 impl、`coerce_value` 无载荷 enum 先 `EnumCreateSimple` 装箱为 `%enum_t*`（接口对象槽统一存指针，struct 仍为堆拷贝）；LLVM `interface_vtable_name`/adapter/`MakeInterface` 支持 Enum 具体类型，`EnumCreateSimple` 返回类型固定 `%enum_t*`。覆盖用例并入 `examples/lang_full_ocaml.dm`（无载荷 enum 实现接口）。
- [x] 宿主 OCaml 编译器接口装箱对象改为引用计数托管（修复泄漏）：runtime 新增 `OBJ_INTERFACE` 对象类型与 `dream_interface_alloc`/`dream_interface_release`（`gc_alloc`/`gc_release` 封装）；DIR 新增 `InterfaceBox`（struct 装箱）与 `InterfaceRelease` 指令，`function_builder` 记录装箱对象，`emit` 时按「参数交给其他函数/全局/闭包捕获」统一标记逃逸，函数返回前（SReturn 与默认返回路径）释放未逃逸对象；无载荷 enum 装箱（`EnumCreateSimple`）同样纳入托管。百万次接口构造循环峰值内存 ~0.8MB（修复前每次泄漏一份 struct 拷贝）。
- [x] 宿主 OCaml 编译器接口值携带类型 tag（有状态 ABI）：`%dir_interface` 从 `{i8*, i8*}` 扩展为 `{i8*, i8*, i32}`（tag 为具体类型名 FNV-1a 哈希，`Dir.concrete_type_tag` 统一），新增 `InterfaceTypeTag` 指令提取；`match type of` 支持接口值按具体类型分发（case 名为 struct/enum 类型名），穷尽性检查对 `TyTypeInfo (TyInterface)` 无法静态枚举、通配符始终可达；顺带修复接口类型注解绑定（SLet/函数参数 `resolve_type_expr` 解析为 `TyInterface` 而非类型变量）、`unify` 补 `TyInterface` 分支、`ty_to_string`/`occurs` 等配套。覆盖用例并入 `examples/lang_full_ocaml.dm`（`match type of` 按 Traffic/Rect 分发）。
- [x] 宿主 OCaml 编译器补齐 str 内置方法 lowering（length/find/upper/lower/strip/starts_with/ends_with/replace/is_digit/is_alpha/is_whitespace）、列表推导式元素表达式类型实例化、泛型函数调用单态化（`rewrite_statement` 递归进入函数体）、union 类型变量的 DIR lowering（装箱 `union_create_*`、match 值模式拆箱 `union_is_*/union_get_*`、`union_print_value` 打印，穷尽性检查对 union 跳过），并修复 switch/if 全分支 return 时 join 块的默认返回合成；补齐 Python 运算符全集（`//` 整除、`**` 幂、`& | ^ ~ << >>` 位运算、一元 `+`）及对应重载（`floordiv/pow/bitand/bitor/bitxor/bitnot/shl/shr/pos`，runtime 新增 `math.c`）；新增 `Self` 类型（接口/impl 方法返回自身类型，`stdlib/operators.dm` 重载接口已用 Self 简化）；`examples/lang_full_ocaml.dm` 作为覆盖用例纳入宿主回归。补齐 `match type of`（ETypeOf 按类型分发 + case 内变量窄化）、struct/列表模式匹配（含常量字段测试）、默认参数（`default_args.ml` 填充 pass）、文件 I/O 与 `stdlib/file.dm` 分支修复；`lang_full_ocaml.dm` 已覆盖 interface/impl、运算符重载、match type of、列表/struct 模式、枚举多载荷、dict 字符串键、列表拼接、嵌套 match、默认参数、文件 I/O、接口值。已知缺口：`str.split`（str 列表的 DIR 容器操作）与 tuple 模式匹配（DIR scrutinee 不支持 tuple）尚未实现。dict 字面量支持多行（换行分隔 pair）与 const 引用的键/值（`parse_integer_dict_literal` 推断将 `VALUE_TYPE_INT` 与立即数同等视为整数，编译器源码内 `keyword_kind` 已恢复为 `dict[str, int]` 实现，缺失键回退 `TOKEN_IDENTIFIER`；宿主 lexer 增加括号深度跟踪，括号内换行不产生 INDENT/DEDENT，宿主 parser 的 dict pair 列表接受换行）；keyword_kind 的 dict 化同时使自举编译加快约 5.8 倍（哈希查找优于 18 次字符串比较，stage1 编译 compiler.dm 由 271s 降至 47s）。新增回归 `test/test_bootstrap_dict_multiline.dm`。支持全局 `let` 语句（顶层声明，任意表达式初始化，main 入口执行一次）：宿主端 DIR 新增 `GlobalLoad`/`GlobalStore` 指令与 `module_.globals`（`@name = global <ty> zeroinitializer`），顶层 SLet 从 top-level 代码分离为全局声明，main（用户或合成）最先 lower 并注入初始化；bootstrap 端 `collect_global_lets` 收集顶层 let（含类型注解或推断 pass），emit 输出全局声明、main 内初始化 store，变量表以 `VALUE_TYPE_GLOBAL_*` 类型注册（`find_variable` 后注册优先保证局部遮蔽），`parse_assignment`/`parse_primary`/`parse_argument_atom`/闭包捕获均支持全局读写；函数内 `let` 可重新赋值（类型不变），赋值自动解析到已有绑定（局部优先，无需 global 关键字）。`bootstrap_build.fish` 预处理尾部追加时过滤顶层 let 行。新增回归 `test/test_global_let.dm`。
- [x] `scripts/bootstrap_build.fish` 通过 Stage 2 的 `build` CLI 构建当前自举语法子集；DM runtime linker 动态扫描 `runtime/` 下的 C 源文件并在成功链接后删除中间 LLVM 文件。
- [x] Stage 2 已支持整数列表字面量、列表索引读取和列表元素赋值；`hello.dm`、`factorial.dm`、`dynarray_full.dm` 已纳入 `make bootstrap` 回归。
- [x] Stage 2 已支持 `for value in list[int]`，并通过 `test_for_dir.dm` 的 `60` 输出回归。
- [x] DM DIR 的记录构造已使用 `DmDirRecord` 结构体字面量；`list[int]` 只保留为固定 12 个 `i32` 字段的序列化 ABI 边界。
- [ ] `list[DmDirRecord]` 尚未接入：当前 Stage 2/runtime 的列表 ABI 是 `dynarray_i32`，直接把结构体放进列表会丢失元素布局；待通用 boxed/generic list ABI 稳定后再实现。
- [x] Stage 2 已支持 typed list、整数列表推导式、整数 tuple 字面量、tuple 解包和一元负号；`test_bootstrap_collections.dm` 固定回归输出 `3`、`2`、`30`、`1`。
- [x] Stage 2 已支持整数结构体构造、声明顺序字段布局、乱序命名字段初始化和字段访问；`test_bootstrap_struct.dm` 回归输出 `7`。
- [x] Stage 2 已支持整数结构体作为函数参数和返回值，并支持整数结构体模式匹配字段绑定；`test_bootstrap_struct_function.dm` 和 `test_bootstrap_struct_match.dm` 已纳入自举回归。
- [x] Stage 2 已支持 bytes 基础 ABI：`str_to_bytes`、`bytes_to_str`、`bytes_from_list`、`bytes_to_list`、索引和切片；`test_bytes_dir.dm` 已纳入自举回归，固定输出 `98`、`2`、`bc`、`120`、`2`。bootstrap 链接使用 `bytes_wrapper.c` 的 `__c_*` ABI，避免与标准库包装函数重复导出。
- [x] Stage 2/3 的 `switch/case/default` 已支持 `int`、`bool`、`float`、`str`；整数/布尔使用 `icmp`，浮点使用 `fcmp oeq double`，字符串通过 `string_compare`，`test_bootstrap_switch_basic.dm` 回归输出 `20`、`1`、`25`、`1`。
- [x] 宿主 DIR 和 Stage 1/2 都支持 `str + str`，统一 lowering 到 `string_concat`；`test_string_add_dir.dm` 覆盖字面量、变量和链式拼接。
- [x] bootstrap 函数收集器会从声明提取 ABI 返回类型，并贯通表达式/语句解析；`test_bootstrap_result.dm` 和 `test_bootstrap_return_metadata.dm` 使用任意函数名验证，不依赖业务函数名硬编码。
- [x] DreamIR 的结构化 `Switch` 已支持 `int`、`float`、`bool`、`str`；整数使用 LLVM 原生 `switch`，其余标量渲染为比较链，并由 verifier 检查 case 类型一致性。
- [x] Stage 2 已支持整数 `match`、通配符和整数载荷 enum 的基础表达式分支；`test_bootstrap_match.dm` 回归输出 `100`。
- [x] Stage 2 已复用 `[tag, payload]` 表示支持用户 enum 和 `Some/None`、`Ok/Err` 的基础 `match`；表达式和独立语句都按对应的缩进块解析，`test_bootstrap_match_enum.dm`、`test_bootstrap_match_builtin.dm` 和 `test_bootstrap_match_statement.dm` 已纳入自举回归。
- [x] Stage 2/3 已完成当前编译器源码的字节固定点自举，且 Stage 3 能独立执行 `dir`/`build` 回归；`lang_full_dream.dm` 和 23 个 `*_dir.dm` 示例均已通过宿主编译器，`lang_full_dream.dm`、`quicksort.dm`、rune Unicode code point 索引、基础类型捕获 lambda 和登记的 DIR 示例也已纳入 Stage2/Stage3 build/run 回归。动态对象、复杂泛型容器和更丰富闭包语义仍属于后续语言扩展，不是当前自举固定点的隐含承诺。

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

这条路径使用 `bootstrap/stage2`，不会调用 `_build/default/bin/main.exe` 编译目标文件。当前自举编译器已经稳定覆盖编译器自身和登记的 DIR 回归子集；超出该集合的语法仍会在 DIR/LLVM 验证或链接阶段报告失败，而不会被标记为完整语言支持。

直接让某个自举阶段输出 LLVM：

```fish
bootstrap/stage1 llvm bootstrap/compiler.dm -o tmp/stage2-from-stage1.ll
bootstrap/stage2 llvm bootstrap/compiler.dm -o tmp/stage3-from-stage2.ll
```

输出应分别与 `bootstrap/stage2.ll`、`bootstrap/stage3.ll` 一致；输出文件属于临时产物，应放在 `tmp/`。

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

**bootstrap 编译器性能**（DEBUG=true 分段计时：lex/collect/hir+dir/emit/render）：
- [x] **source_type_is_interface 预收集**：`collect_declared_types` 编译期一次性收集 struct/interface 声明名到全局数组，类型判断从全量 token 扫描（O(tokens)/调用）降为查声明表（O(#声明)）；emit 阶段 38s → 11.3s（约 3.5 倍）
- [x] **全局 let 数组索引修复**：parse_primary/parse_argument_atom/parse_nested_call 的全局 let 分支缺 list 索引处理，`GLOBAL_ARR[i]` 被拆成"数组变量 + [i] 字面量"两个参数（generate 错误 LLVM 运行时崩溃）；已修复 4 处
- [x] **collect 顺序修复**：`collect_declared_types` 必须在 `collect_functions` 之前（参数类型推断的 struct 判断依赖声明表）；否则 ParseContext 等 struct 参数被推断为 int 导致内存错乱
- [x] **source_equals/source_ranges_equal 字节化**：DM `ord()` 为 utf8-aware（`__c_utf8_rune_at`），逐字符比较极慢；改为长度预检查 + 字节 slice 比较
- [x] **非短路 and/or 修复**：`and`/`or` 编译为 LLVM `and i1`/`or i1`（操作数全部求值），`x >= 0 and arr[x]` 在 x 为 -1 时必然越界；已修复 parse_argument_atom 等 3 处
- [x] **lex 魔法数字常量**：switch code 的 19 处魔法数字替换为 ASCII_* 常量
- [x] **DEBUG 分段计时插桩**：`__c_debug_on`/`__c_time_ms`/`__c_eprint_text`/`__c_eprint_int` runtime helpers

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
