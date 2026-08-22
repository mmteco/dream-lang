# Dream 实现注意点

编译器和运行时实现中沉淀的性能优化与 ABI 注意点,供后续实现/优化参考(尤其 bootstrap 自举编译器)。来源:2026-08 文档清理时从自举历史记录中提取。

## 性能优化注意点

1. **哈希查找优于字符串比较链**:keyword 查找从 18 次字符串比较改为 dict 哈希,stage1 编译 compiler.dm 271s → 47s(5.8 倍)。原则:高频符号查找(关键字、struct/函数声明名)编译期预收集成哈希表。
2. **容器操作按元素类型特化**:`list[i32]` 用 `dynarray_i32`、`list[str]`/`list[tuple]` 用 `dynarray_ptr`;ListGet/Create/Slice/Concat/Length 分派 i32/ptr 变体(runtime 提供 `slice_dynarray_ptr`/`concat_dynarray_ptr`)。不为通用性引入装箱开销。
3. **元组槽统一 intptr_t 位编码**:i32/bool 位扩展截断、f64 位变换、指针 ptrtoint/inttoptr;仅 struct/interface 聚合经 `dream_closure_alloc` 堆装箱。标量不堆分配。
4. **接口装箱对象引用计数托管 + 编译期逃逸标记**:`function_builder` 记录装箱对象,emit 时按「参数交给其他函数/全局/闭包捕获」标记逃逸,函数返回前(SReturn 与默认路径)释放未逃逸对象。修复前每次循环泄漏一份 struct 拷贝(百万次峰值内存 ~0.8MB)。
5. **字符串相等性比较避免 utf8-aware 慢路径**:DM `ord()` 逐字符极慢;`source_ranges_equal` 用长度预检查 + 字节比较,后演进出 `__c_range_equal`(memcmp)。
6. **switch 代码生成按类型选指令**:int/bool 用 `icmp`、float 用 `fcmp oeq`、str 用 `string_compare`;整数用 LLVM 原生 `switch`,其余标量渲染为比较链。

## 实现注意点(ABI/布局)

1. **bytes 链接 ABI**:bootstrap 用 `wrappers/bytes.c` 的 `__c_*` ABI,避免与标准库包装函数重复导出(符号冲突)。
2. **list[int] 仅作为固定 12 槽序列化 ABI 边界**:DIR records 用 `DmDirRecord` 结构体字面量构造;`list[DmDirRecord]` 暂不接入(列表 ABI 是 dynarray_i32,放结构体丢元素布局),待通用 boxed/generic list ABI。
3. **函数收集器从声明提取 ABI 返回类型**:回归测试用任意函数名验证,不硬编码业务函数名。
4. **未映射指令以 `native llvm` 记录保留**:LLVM 分支已转正式 `jump`/`branch`,暂无法表达的低层指令保留原始信息,后续逐条替换为 DreamIR 指令。
5. **全局 let 局部遮蔽**:变量表以 `VALUE_TYPE_GLOBAL_*` 注册,`find_variable` 后注册优先保证局部优先;函数内 let 可重赋值,无需 global 关键字。
6. **dict 多行字面量**:宿主 lexer 跟踪括号深度,括号内换行不产生 INDENT/DEDENT。
7. **接口值类型 tag**:`concrete_type_tag` 用 FNV-1a 哈希,`match type of` 按具体类型分发;穷尽性检查对 `TyTypeInfo (TyInterface)` 无法静态枚举,通配符始终可达。
8. **穷尽性检查 bug**:`is_covered` 失败时不能回退到通配符分支(否则丢失未覆盖告警)。
9. **元组解包按被调函数返回类型注解判断元素是否指针**(`-> (...)`),指针元素用 `get_pointer` 并累计槽偏移;list[str] 索引同样 ×2 槽偏移。
10. **DM 无 XOR 运算符**:FNV 哈希用 `hash * 16777619 + code` 乘法形式,与 C 侧 `hash * 16777619u + (uint32_t)rune` 保持一致。

## 自举修复记录（2026-08 差分流程）

1. **命名常量 case 标签恒走首分支**:`mir_expand_pattern` 的 HIR_OP_LOCAL 分支先查常量池（mir_find_constant_index），命中且整型才生成 CONST+相等比较，否则按绑定模式。
2. **LIR 块参数推断覆写丢 store（stage2 特有自举误译）**:`program.records[offset+4] = inferred_type`（struct 字段链列表元素赋值）在 stage2 静默丢失，改局部别名 `let record_values = program.records` 后赋值。
3. **VOID 混入块参数**:void 调用结果作循环携带符号 → `phi void` 非法。merge 跳过 VOID、block_parameter_type VOID→I32、coerce/cast 两端统一发零占位。
4. **全局缓存列表 `= []` 重绑定丢 store（stage2）**:`state.field = []` 重绑定在自举编译时丢失 store，改别名+元素重置（value_types 置 DYNAMIC、声明置 -1，越界读取语义等价）。
5. **runtime id 撞号**:dict 字面量与 list append 共用 aux id=7，emit 按结果类型分派（DICT → dict_create）。
6. **HIR/MIR 类型码空间混淆**:HIR_TYPE_DYNAMIC=16 而 MIR_TYPE_DYNAMIC=17，凡读 HIR type_tag 与 MIR 常量比较处先经 `mir_type_from_hir` 转换（lambda 返回类型、list 元素推断）。
7. **? 操作符 Err 不短路**:SELECT 取 payload 继续执行导致 `Ok(0+1)` 误传播；改块级条件分支，Err 时直接 RETURN 原 Result 盒。
8. **bytes 索引类型**:str_to_bytes 结果类型 BYTES 未识别，`encoded[1]` 发射成 get_pointer+print_string；mir_index_result_type 加 BYTES 分支。
9. **for 循环 break 缺 mir_push_loop**:break 被编译成 UNREACHABLE→ret 0 提前退出 main。
10. **float 字面量越界读取**:HIR 构建 `ast_node_arg(node,0)` 对无参节点越界读下一节点 kind（1.5→2、2.0→10）；LLVM 发射 F64 CONST 从源码取文本 `fadd double 1.5, 0.0`。
11. **嵌套索引类型推断**:`list[list[int]][i][j]` base 是 INDEX 节点未推断；mir_index_result_type 加 INDEX 分支 + mir_list_element_type 穿透。
12. **str→bytes 参数转换**:方法调用 `buf.append_bytes("hi")` 签名参数 bytes 实参 str 无转换→垃圾指针崩溃；MirLowerState 加函数参数类型表，CALL 分支签名 bytes 实参 str 时插 `__c_str_to_bytes`。
13. **外部函数统一编号**:RUNTIME_EXTERN_NAMES 行号 + 特判函数（enum/utf8）统一连续编号，`EXTERNAL_ID_BASE=1000`、`EXTERNAL_COUNT=98`；特判函数全部入表，零特判分支；查表换算 `id-BASE`。
14. **AST 列表字面量 13 元素限制**:AST_EXPR_LIST 节点固定 17 槽→动态大小（3+1+count），ast_node_size 特判 + 构建/验证同步改。
15. **性能优化**：ast_node_size 50+case switch→查表（kind→size）；重复函数检查 fnv_hash 预计算（O(n²)→O(n)）；参数/签名比较去 slice（__c_range_equal/fnv_hash/range_equals_cstr ASCII 快路径，注意 start 前非 ASCII 字符的字节偏移）。
