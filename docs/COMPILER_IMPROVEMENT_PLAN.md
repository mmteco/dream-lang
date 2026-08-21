# Dream 编译器改进计划

## 目标

逐步提升 Dream 编译器的表达能力，优先完善 AST->DIR->LLVM 流程的基础设施，使被注释的测试能够逐步通过。

## 当前状态

### 已通过的测试（10/11）：
- ✅ test_scalar_match_dir.dm - 标量模式匹配（int, float, bool, string, rune）
- ✅ test_enum_payload_dir.dm - 单载荷枚举模式匹配（包括 float, bool, string 载荷）
- ✅ test_struct_dir.dm - 结构体模式匹配
- ✅ test_enum_multi_dir.dm - 多载荷枚举模式匹配
- ✅ test_try_dir.dm - ? 操作符和 Result 类型
- ✅ test_generic_dir.dm - 泛型函数
- ✅ test_lambda_dir.dm - lambda 捕获
- ✅ test_struct_method_dir.dm - 结构体方法
- ✅ test_interface_dir.dm - 接口
- ✅ test_interface_args_dir.dm - 带参数的接口

### 待修复的测试（1/11）：
1. ❌ test_bootstrap_nested_lambda.dm - 嵌套 lambda 闭包（Dream 编译器的闭包实现有 bug）

## 已完成的改进

### 阶段 1：Match 表达式类型推断 ✅

**问题**：match 表达式总是分配 i32 结果槽，但 body 可能返回 float/其他类型

**实现内容**：
1. 添加 `lower_infer_expr_type` 函数：轻量级类型推断，不生成 IR
   - 支持字面量（int, float, bool, string, rune）
   - 支持变量引用（查找变量类型）
   - 支持二元表达式（根据操作数类型推断结果类型）
   - 支持一元表达式

2. 添加 `lower_infer_match_result_type` 函数：推断 match 表达式的结果类型
   - 分析第一个 case 的模式和 body
   - 对于结构体模式：提取字段类型并绑定到临时变量
   - 对于枚举模式：提取载荷类型并绑定到临时变量
   - 使用临时变量上下文推断 body 类型

3. 修改 `lower_expr_match` 和 `lower_stmt_match`：
   - 在分配结果槽之前推断结果类型
   - 根据推断的类型分配结果槽（i32, f64, pointer 等）
   - 使用正确的类型进行 store 和 load 操作
   - 返回正确的 VALUE_TYPE

4. 改进枚举载荷提取：
   - 使用 `enum_variant_payload_type` 确定载荷类型
   - 对于 float 载荷：调用 `get_f64` 获取 double
   - 对于 string 载荷：调用 `get_pointer` 获取指针
   - 对于 bool 载荷：作为 i32 获取（存储时已零扩展）
   - 为不同载荷类型分配正确类型的变量槽

**影响**：
- test_enum_payload_dir.dm 通过（包括 float, bool, string 载荷）
- test_struct_dir.dm 通过
- test_enum_multi_dir.dm 通过

**技术细节**：
- Float 在 dynarray 中存储为两个 i32（64 位双精度浮点数的低位和高位）
- 使用 `append_f64` 存储，`get_f64` 读取
- Bool 零扩展为 i32 存储，读取时作为 i32 使用
- String 作为指针存储和读取

## 待完成的改进

### 阶段 6：闭包和嵌套 Lambda

**问题**：Dream 编译器缺少完整的闭包实现，导致嵌套 lambda 无法捕获外层变量

**现状**：
- ✅ OCaml 编译器（stage0）可以正确编译嵌套 lambda
- ❌ Dream 编译器（stage1/stage2）编译嵌套 lambda 时生成错误的 LLVM IR
- 错误：使用未定义的变量（`%t0`）

**影响测试**：test_bootstrap_nested_lambda.dm

**根本原因**：
Dream 编译器的 `lower_lambda_helper` 函数（compiler_lower.dm:1770）在编译 lambda body 时使用空的变量列表，无法访问外层作用域的变量。

```dream
# 当前实现（错误）
let lambda_var_starts = []
let lambda_var_ends = []
let lambda_var_types = []
# Lambda body 无法引用外层变量
```

**OCaml 编译器的实现**：
```llvm
define %dir_closure* @__dir_lambda_0(i8* %v1, i32 %v2) {
  ; 从环境中提取捕获的变量
  %dir_environment_get_3 = bitcast i8* %v1 to {i32}*
  %v3 = load i32, i32* %dir_environment_get_3  ; base
  
  ; 创建新环境捕获变量
  %dir_environment_4 = call i8* @dream_closure_alloc(i64 8)
  store i32 %v2, i32* ...  ; base
  store i32 %v3, i32* ...  ; offset
  
  ; 创建闭包
  %v4 = call %dir_closure* @dream_closure_create(...)
  ret %dir_closure* %v4
}
```

**需要实现的改动**：

#### 1. 自由变量分析
```dream
def lower_analyze_free_variables(context, ast, lambda_node, outer_vars) -> list[str]:
    # 分析 lambda body 中引用的所有自由变量
    # 自由变量 = 在 body 中使用但不在 lambda 参数中定义的变量
    let body_node = ast_node_arg(ast, lambda_node, 2)
    let params = extract_lambda_params(lambda_node)
    let used_vars = scan_used_variables(body_node)
    let free_vars = []
    for var in used_vars:
        if var not in params and var in outer_vars:
            append(free_vars, var)
    return free_vars
```

#### 2. 修改 Lambda 函数签名
```dream
# 当前：define i32 @lambda.0(i32 %value.param)
# 改为：define i32 @lambda.0(i8* %env.param, i32 %value.param)

append_text(header_buffer, "define i32 @lambda.")
append_integer(header_buffer, lambda_number)
append_text(header_buffer, "(i8* %env.param, i32 %value.param) {\nentry:\n")
```

#### 3. 环境结构定义
```dream
# 为每个 lambda 生成环境结构类型
# 例如：捕获 base 和 offset
%lambda.0.env = type { i32, i32 }  ; base, offset
```

#### 4. 从环境恢复变量
```dream
# 在 lambda body 开始时，从环境提取捕获的变量
let env_typed = bitcast i8* %env.param to %lambda.0.env*
let base_ptr = getelementptr %lambda.0.env, %lambda.0.env* %env_typed, i32 0, i32 0
let base = load i32, i32* %base_ptr
let offset_ptr = getelementptr %lambda.0.env, %lambda.0.env* %env_typed, i32 0, i32 1
let offset = load i32, i32* %offset_ptr

# 将提取的变量添加到 lambda 的变量列表
append(lambda_var_starts, base_start)
append(lambda_var_ends, base_end)
append(lambda_var_types, VALUE_TYPE_INT)
```

#### 5. Lambda 创建时捕获变量
```dream
# 当遇到 lambda 表达式时：
# 1. 分配环境
let env = call i8* @dream_closure_alloc(i64 16)  ; 2 个 i32 = 8 字节
let env_typed = bitcast i8* %env to { i32, i32 }*

# 2. 存储捕获的变量
store i32 %base, i32* getelementptr(..., i32 0, i32 0)
store i32 %offset, i32* getelementptr(..., i32 0, i32 1)

# 3. 创建闭包
let closure = call %dir_closure* @dream_closure_create(
    i8* bitcast (i32 (i8*, i32)* @lambda.0 to i8*),
    i8* %env
)
```

#### 6. Lambda 调用约定
```dream
# 调用闭包时：
# 1. 提取函数指针和环境
let func_ptr = load i8*, i8** getelementptr(%dir_closure, %dir_closure* %closure, i32 0, i32 0)
let env = load i8*, i8** getelementptr(%dir_closure, %dir_closure* %closure, i32 0, i32 1)

# 2. 调用函数，传递环境和参数
let result = call i32 %func_ptr(i8* %env, i32 %arg)
```

#### 7. 嵌套 Lambda 处理
```dream
# 对于嵌套 lambda，内层 lambda 需要：
# 1. 从外层 lambda 的环境中提取变量
# 2. 创建新环境，包含外层环境 + 外层参数
# 3. 返回闭包

# 例如：lambda (base: int) -> lambda (value: int) -> value + base + offset
# 外层 lambda：
#   - 参数：base
#   - 捕获：offset（从 main 函数）
#   - 环境：{ offset: i32 }
#   - 返回：闭包（内层 lambda + 新环境 { base: i32, offset: i32 }）

# 内层 lambda：
#   - 参数：value
#   - 捕获：base, offset（从外层环境）
#   - 环境：{ base: i32, offset: i32 }
```

**实现优先级**：
1. 先实现简单闭包（单层 lambda，捕获外层变量）
2. 再实现嵌套闭包（多层 lambda，逐层捕获）
3. 最后优化环境分配（避免不必要的复制）

**技术挑战**：
- 需要修改 lambda 的函数签名和调用约定
- 需要实现自由变量分析算法
- 需要处理环境的内存管理和生命周期
- 需要支持不同类型变量的捕获（int, float, string, list 等）
- 需要处理递归 lambda（Y combinator 或直接引用）

**预计工作量**：3-5 天

**替代方案**：
如果完整闭包实现过于复杂，可以考虑：
1. 限制 lambda 只能捕获简单类型（int, bool）
2. 使用全局变量代替闭包（有限制）
3. 在文档中说明 lambda 的限制

**注意**：这是一个独立的特性，与 match 类型推断无关。需要单独规划和实现。

## 实施策略

1. **逐步迭代**：每个阶段完成后运行测试，确保不破坏现有功能 ✅
2. **优先基础**：先完善 match 表达式和模式匹配，再处理高级特性 ✅
3. **参考 OCaml**：对于复杂特性，参考 stage0 编译器的实现
4. **保持简洁**：使用 Dream 语言的高级语法实现，避免过度复杂的底层操作 ✅

## 成果总结

通过阶段 1 的实现，成功修复了 10 个测试用例，显著提升了 Dream 编译器的表达能力：

- **模式匹配**：支持标量、结构体、枚举（包括多载荷和不同类型载荷）
- **高级特性**：泛型、? 操作符、lambda、结构体方法、接口等都已正常工作
- **Bootstrap**：编译器可以自举，stage2 和 stage3 生成相同的代码（固定点验证通过）

唯一剩余的问题是嵌套 lambda 的闭包实现，这需要进一步调试 Dream 编译器的闭包系统。

## 下一步

1. 调查并修复 Dream 编译器的闭包 bug
2. 完善其他可能的基础设施问题
3. 继续实现计划中的其他阶段（如需要）
