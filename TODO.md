# Dream 语言开发任务列表

## 当前优先级

### 🚀 高优先级

#### P0 - 核心功能缺失
- [x] 动态大小数组/列表 
  - [x] 实现堆内存分配 (malloc/free)
  - [x] 运行时内存管理
  - [x] 引用计数垃圾回收机制
  - [x] 内存池优化
  - [x] 标记-清除 GC（补充机制）
  - [x] 完整的测试套件
  - [x] 集成到编译器 LLVM 生成器 

- [x] 泛型系统  **基础功能完成**
  - [x] 类型参数语法解析 `func[T](x: T) -> T`
  - [x] 类型参数化 AST 节点
  - [x] 单态化(monomorphization)实现
  - [ ] 泛型约束和高级特性（待扩展）

#### P1 - 重要改进
- [x] 字符串类型完善  **核心功能完成**
  - [x] **string → str 重命名** - 类型名称统一
  - [ ] 字符串拼接 (待添加)
  - [x] 字符串索引和切片
    - [x] 字符串索引 `str[i]` 返回字符的 ASCII 码
    - [x] 字符串切片 `str[start:end]` 返回子字符串
    - [x] LLVM 代码生成支持
    - [x] 类型检查支持
    - [x] print(string) 支持
  - [x] 字符串方法
    - [x] `length()` - 字符串长度
    - [x] `find(substr)` - 查找子字符串位置
    - [x] `replace(old, new)` - 替换子字符串
    - [x] `strip()` - 去除首尾空白
    - [x] `upper()` / `lower()` - 大小写转换
    - [x] `starts_with(prefix)` / `ends_with(suffix)` - 前后缀检查
    - [x] `split(delimiter)`, `join(array, separator)` - 分割和连接字符串数组
  - [x] 字符串比较操作符
    - [x] `==`, `!=` - 相等性比较
    - [x] `<`, `>`, `<=`, `>=` - 字典序比较
  - [x] 字符级别方法
    - [x] `is_digit(index)` - 检查指定位置字符是否为数字
    - [x] `is_alpha(index)` - 检查指定位置字符是否为字母
    - [x] `is_whitespace(index)` - 检查指定位置字符是否为空白

- [x] 文件 I/O **完整功能完成**
  - [x] `file_read(path)` - 读取文件为字符串
  - [x] `file_write(path, content)` - 写入字符串到文件
  - [x] `file_exists(path)` - 检查文件是否存在
  - [x] `file_append(path, content)` - 追加内容到文件
  - [x] `file_delete(path)` - 删除文件
  - [x] `file_read_bytes(path)` - 读取文件为字节数组
  - [x] `file_write_bytes(path, bytes)` - 写入字节数组
  - [x] `file_append_bytes(path, bytes)` - 追加字节数组
  - [x] 标准库 `stdlib/file.dm` - 统一接口
  - [x] Union 类型集成 - `str | bytes` 参数
  - [x] **Bytes 类型完整支持**
    - [x] UNION_BYTES runtime 实现
    - [x] union_create_bytes/is_bytes/get_bytes
    - [x] 类型模式匹配支持
    - [x] 装箱/拆箱代码生成
    - [x] 完整测试套件（test_file_io.dm）

- [ ] 错误处理改进
  - [ ] 更好的错误消息
  - [ ] 源码位置追踪
  - [ ] 编译时错误恢复

### 🔧 中优先级

#### P2 - 语言特性扩展
- [x] 字典类型  **完全泛型化完成**
  - [x] 字典字面量 `{1: 10, 2: 20}` (整数键值对)
  - [x] 字典字面量 `{"name": 100, "age": 25}` (字符串键) 
  - [x] 字典字面量 `{1: "Alice", 2: "Bob"}` (字符串值) 
  - [x] 字典字面量 `{"name": "Alice", "city": "Beijing"}` (字符串键值对) 
  - [x] 字典索引访问 `dict[key]` (读取操作)
  - [x] 字典赋值 `dict[key] = value` (写入操作) 
  - [x] 哈希表底层实现 (FNV-1a 哈希)
  - [x] LLVM 代码生成支持 (llvmgen.ml)
  - [x] 类型检查支持 (typeck.ml)
  - [x] 字典方法 `dict_keys()`, `dict_values()`, `dict_items()`
  - [x] 字典迭代 `for (k, v) in dict_items(d)` 
  - [x] 字符串键支持 dict[string, int] 
  - [x] 泛型值类型支持 dict[int, string], dict[string, string] 
  - [x] **统一泛型实现** - 单一 dict_t 结构，无重复特化代码 
  - [x] **Runtime 层完全泛型化** - 参考 Golang 设计，使用 void* + 类型元数据 
  - [x] **LLVM 代码生成器重构** - 使用统一的类型特化函数 

- [x] 元组类型  **完整功能完成**
  - [x] 元组结构实现 `tuple2_i32` 和 `tuple_t`
  - [x] 元组解包 `let (a, b) = tuple`
  - [x] 元组解包在 for 循环中 `for (k, v) in dict_items(d)`
  - [x] 元组字面量 `(1, 2, 3)` 
  - [x] 元组索引 `tuple[0]` 
  - [x] 任意长度元组支持 

- [x] Match 表达式  **完整功能完成**
  - [x] 模式匹配语法解析（case 关键字可选）
  - [x] 通配符模式 `_`
  - [x] 类型检查实现
  - [x] LLVM 代码生成（整数、字符串、通配符、变量绑定）
  - [x] **统一的 match 表达式（EMatch）**
    - [x] 单行表达式分支 `pattern: expr`
    - [x] 多行表达式分支 `pattern:\n    expr`
    - [x] 多行语句块分支 `pattern:\n    stmt1\n    stmt2`
    - [x] 桥接块机制（解决嵌套 match 的 phi 节点问题）
    - [x] 不可达块检测（所有分支 return 时添加 unreachable）
  - [x] 枚举变体精确匹配（tagged union实现）
  - [x] **枚举变体带数据的模式匹配**
    - [x] 单参数变体：`Circle(r)` → 提取并绑定 r
    - [x] 多参数变体：`Rectangle(w, h)` → 提取并绑定 w, h
  - [x] **守卫条件 `if` 子句**
    - [x] 解析器支持 `pattern if guard_expr:` 语法
    - [x] AST 扩展支持可选守卫条件（`expr option`）
    - [x] 类型检查器验证守卫表达式为布尔类型
    - [x] LLVM 代码生成（守卫失败跳转到下一个 case）
    - [x] match 语句和表达式均支持守卫条件
  - [x] **穷尽性检查**
    - [x] 缺失模式分支检测（如缺少 None、Err 等）
    - [x] 不可达模式检测（重复或完全覆盖的分支）
    - [x] 通配符模式正确处理
    - [x] Bool 类型穷尽性检查（true/false）
    - [x] Enum 类型穷尽性检查（所有变体）
  - [x] **类型模式匹配（match type of）**
    - [x] 表达式上下文支持 `match type of`
    - [x] 单行和多行语法支持
    - [x] 与 Union 类型集成
  - [x] **嵌套 match 表达式**
    - [x] 单行嵌套 `match x: 1: match y: ...`
    - [x] 多行嵌套支持
    - [x] 完整测试套件（test_match_comprehensive.dm - 20个测试用例）
  - [x] **Match 表达式语义验证**
    - [x] 检测并禁止在 match 表达式分支中使用 return
    - [x] 类型检查器报错："Cannot use 'return' in match expression branches. Use 'return match ...' instead."
    - [x] 测试验证（test_match_return.dm）

- [x] Enum 类型  **完整功能完成**
  - [x] 枚举定义语法解析 `enum Color: Red, Green, Blue`
  - [x] 枚举构造器 `Color.Red`, `Shape.Circle(5)`, `Shape.Rectangle(10, 20)`
  - [x] **Runtime 层 Tagged Union 实现（enum.c/enum.h）** 
    - [x] enum_create_simple/int/string/bool 函数
    - [x] enum_create_tuple_ptr 函数（多参数变体）
    - [x] enum_get_tag/int/string/bool/data 函数
  - [x] **LLVM 代码生成器集成** 
    - [x] 单参数变体代码生成
    - [x] 多参数变体代码生成（使用元组存储）
    - [x] 枚举注册表（enum_registry）
  - [x] **Match 表达式与 enum 集成** 
    - [x] 简单枚举变体匹配（无数据）
    - [x] 枚举 tag 比较和分支跳转
    - [x] **单参数变体数据提取和绑定** 
    - [x] **多参数变体数据提取和绑定** 
    - [x] 变量重命名机制（避免 LLVM IR 中的名称冲突）
  - [x] **GC 集成** 
    - [x] OBJ_ENUM 类型添加到 GC 系统
    - [x] enum_create_xxx 使用 gc_alloc 分配
    - [x] 自动引用计数管理
    - [x] 内存清理（enum_release 时释放数据指针）
  - [ ] 枚举方法支持（待扩展）

  **当前状态**：枚举类型完全可用，包括带数据的变体 ✅

- [x] Union 类型  **完整功能完成**
  - [x] 使用 `|` 语法：`int | str | bool`
  - [x] 多类型union支持（自动扁平化嵌套）
  - [x] 类型统一算法（子类型兼容性）
  - [x] 函数参数union类型（编译时类型检查）
  - [x] 变量声明union类型（编译时类型检查）
  - [x] **Runtime 层 Tagged Union 实现（union.c/union.h）**
  - [x] **LLVM 代码生成器集成（装箱/拆箱）**
  - [x] 自动装箱：类型注解为 union 时自动装箱
  - [x] 完整的单元测试（test_union.c）
  - [x] **Match 表达式与 union 集成**
    - [x] 整数、字符串、布尔值模式匹配
    - [x] 自动拆箱并类型检查（union_is_xxx + union_get_xxx）
    - [x] 通配符模式支持
  - [x] **类型模式匹配 (Type Pattern Matching)**
    - [x] 语法支持：`variable: type` 模式
    - [x] Union 类型拆箱和类型检查
    - [x] 自动类型窄化（type narrowing）
    - [x] 支持类型：int, str, bool, bytes
    - [x] Parser 实现（PType 模式节点）
    - [x] 类型检查器实现（bind_pattern）
    - [x] LLVM 代码生成（union_is_* 和 union_get_*）
    - [x] 完整测试套件（test_type_pattern.dm）
    - [x] 文档：docs/type_pattern_matching.md
  - [x] **Print 支持 union 类型**
    - [x] union_print_value 运行时函数
    - [x] 自动根据 tag 输出正确值
    - [x] 输出格式统一（所有值带换行符）
  - [x] **函数参数 union 装箱**
    - [x] 函数参数类型表（function_param_types）
    - [x] 调用时自动检测并装箱
    - [x] 避免重复装箱（已是 union 直接传递）
    - [x] 多参数 union 支持
  - [x] **函数返回值 union 装箱**
    - [x] ctx.function_type 跟踪当前函数返回类型
    - [x] SReturn 语句自动检测并装箱
    - [x] Match 语句 return 分支优化
    - [x] 完整测试（test_union_comprehensive.dm）
  - [x] **GC 集成和内存优化**
    - [x] OBJ_UNION 类型添加到 GC 系统
    - [x] union_create_xxx 使用 gc_alloc 分配
    - [x] 自动引用计数管理（union_retain/union_release）
    - [x] 字符串内存自动清理（gc_release 时释放）
    - [x] 内存池优化（64 字节池，批量分配）
    - [x] 完整的单元测试（test_union_gc.c）
    - [x] 零内存泄漏验证
    - [x] union_print_value 支持小写 true/false 输出

  **两种模式**：
  1. **编译时类型特化**（默认）：零运行时开销，性能最优
  2. **运行时多态**（显式类型注解）：支持真正的类型多态，有装箱开销

  **当前状态**：所有核心功能已完成，生产可用 ✅

- [ ] Lambda 表达式
  - [ ] 语法解析
  - [ ] 闭包捕获
  - [ ] 代码生成

#### P3 - 面向对象
- [x] 结构体 **完整功能完成**
  - [x] 结构体定义语法 `struct Name:`
  - [x] 字段类型标注
  - [x] 结构体字面量 `StructName{field1: value1, field2: value2}`
  - [x] 字段访问 `obj.field`
  - [x] 字段赋值 `obj.field = value` (语法解析)
  - [x] AST 节点扩展 (SStruct, EStructLiteral, EStructAccess, SFieldAssign)
  - [x] 词法分析器支持 (struct 关键字)
  - [x] 语法解析器支持
  - [x] 类型系统扩展 (TyStruct)
  - [x] 环境扩展 (结构体定义存储)
  - [x] 类型检查器实现
    - [x] 结构体定义验证
    - [x] 字段初始化完整性检查
    - [x] 字段类型匹配检查
  - [x] LLVM 代码生成器实现
    - [x] 堆内存分配 (malloc)
    - [x] 结构体注册表 (struct_registry)
    - [x] 字段访问通过 getelementptr
    - [x] 字段赋值代码生成
  - [x] **结构体方法** (Go 风格内部方法定义)
    - [x] 方法定义语法 (struct 内部 def)
    - [x] 方法调用 `obj.method()`
    - [x] 方法名称重整 (StructName_methodname)
    - [x] self 参数自动类型推导
    - [x] self.field 字段访问支持
    - [x] 变量到结构体类型的映射 (var_struct_types)
  - [x] 示例和测试 (examples/struct_demo.dm, test/test_struct_methods_*.dm)
  - [x] 文档更新 (SPEC.md)

- [ ] 类和对象
  - [ ] 类定义
  - [ ] 实例化
  - [ ] 方法调用
  - [ ] 继承

- [x] 接口系统 **代码生成完成**
  - [x] 接口定义语法 `interface Name[T]:`
  - [x] 接口成员：方法声明、默认实现、关联类型、关联常量
  - [x] impl 块语法 `impl Interface for Type:` 和 `impl Interface[T] for Type:`
  - [x] 泛型接口支持
  - [x] AST 节点扩展（interface_member, impl_block）
  - [x] 词法分析器支持（impl, type, const 关键字）
  - [x] 语法解析器支持
  - [x] 示例代码（examples/interface_demo.dm）
  - [x] SPEC.md 文档更新
  - [x] 类型系统扩展（TyInterface 类型）
  - [x] 环境扩展（接口和impl块存储）
  - [x] 类型检查器实现
    - [x] 接口定义验证（成员签名检查）
    - [x] impl块完整性检查（必需方法检测）
    - [x] impl块多余方法检测
    - [x] 默认实现支持
    - [x] 关联类型和常量验证
  - [x] LLVM 代码生成器实现
    - [x] impl块方法生成（静态分发）
    - [x] 方法名重整（Interface_method_for_Type）
  - [ ] 运算符重载支持（需要语法扩展）
  - [ ] 接口约束的泛型函数（需要语法扩展）
  - [ ] 隐式实现检查（Go风格duck typing）
  - [ ] 动态方法调用（需要 vtable）

### 📚 低优先级

#### P4 - 标准库
- [ ] 内置函数扩展
  - [ ] `map()`, `filter()`, `reduce()`
  - [ ] `range()`, `enumerate()`, `zip()`
  - [ ] `min()`, `max()`, `sum()`

- [ ] I/O 模块
  - [ ] 文件读写
  - [ ] 标准输入

- [ ] 字符串模块
  - [ ] 正则表达式
  - [ ] 格式化

#### P5 - 工具链
- [ ] REPL
  - [ ] 交互式解释器
  - [ ] 历史记录
  - [ ] 自动补全

- [ ] LSP 服务器
  - [ ] 语法高亮
  - [ ] 自动补全
  - [ ] 跳转定义
  - [ ] 错误提示

- [ ] 调试器
  - [ ] 断点支持
  - [ ] 变量查看
  - [ ] 单步执行

#### P6 - 高级特性
- [ ] 异步支持
  - [ ] async/await 语法
  - [ ] 异步运行时

- [ ] 模块系统
  - [ ] import/from import
  - [ ] 包管理器

- [ ] 宏系统
  - [ ] 编译期代码生成

## 已完成 ✅

### 编译器基础
- [x] 词法分析器 (缩进敏感)
- [x] 语法分析器 (Python 风格)
- [x] 类型检查器 (Hindley-Milner)
- [x] LLVM IR 代码生成器
- [x] 运行时库

### 控制流
- [x] if/else/elif 语句
- [x] while 循环
- [x] for 循环
- [x] 嵌套控制流
- [x] return 语句

### 数据类型
- [x] 基本类型 (int, bool, str)
- [x] 固定大小数组
- [x] 数组字面量 `[1, 2, 3]`
- [x] 数组索引 `arr[i]`
- [x] 数组索引赋值 `arr[i] = value`
- [x] 字典类型 (核心功能)
  - [x] 字典字面量 `{1: 10, 2: 20}`
  - [x] 字典索引访问 `dict[key]`
  - [x] 字典索引赋值 `dict[key] = value`
  - [x] 哈希表实现 (链地址法)
  - [x] 字典方法 `dict_keys()`, `dict_values()`, `dict_items()`
  - [x] 字典迭代 `for (k, v) in dict_items(d)`

- [x] 元组解包
  - [x] let 语句中的元组解包 `let (a, b) = tuple`
  - [x] for 循环中的元组解包 `for (k, v) in items`
  - [x] dict_items() 返回元组数组
  - [x] 64位指针安全 (dynarray_ptr 使用 intptr_t)

- [x] 测试文件整理
  - [x] 从16个测试文件整合为5个
  - [x] test/test_core.dm - 字符串和泛型
  - [x] test/test_types.dm - Union、结构体、接口
  - [x] test/test_file_io.dm - 文件 I/O
  - [x] test/test_match.dm - 守卫条件和穷尽性检查
  - [x] test/test_match_comprehensive.dm - match 表达式全面测试（20个测试用例）

### 高级数组操作
- [x] 数组拼接 `arr1 + arr2`
- [x] 数组切片 `arr[start:end]`, `arr[:]`, `arr[start:]`, `arr[:end]`
- [x] 列表推导式 `[expr for var in arr if cond]`
- [x] 变量重命名机制避免冲突

### 函数
- [x] 函数定义和调用
- [x] 类型注解
- [x] 递归函数
- [x] 数组作为参数

### 内置函数
- [x] `print(int)`
- [x] `print(str)`
- [x] `print(bool)`
- [x] `print()` 泛型优化 - 接受任意类型，无类型错误
- [x] `len(array)`

### 类型系统改进
- [x] 多态 Add 操作符 (int + int, list + list)
- [x] 列表类型推导和统一
- [x] 泛型系统基础实现 
  - [x] 类型参数语法 `func[T](x: T) -> T`
  - [x] 单态化代码生成
  - [x] 泛型函数实例化

### 内存管理系统
- [x] 对象头设计（类型、大小、引用计数、标记位）
- [x] 内存池分配器（小对象优化）
- [x] 引用计数自动管理
- [x] 标记-清除垃圾回收
- [x] 动态数组完整实现（创建、追加、切片、拼接）
- [x] 内存统计和调试工具
- [x] 完整的单元测试
- [x] **Dream GC 管理系统**
  - [x] 双模式引用计数（局部对象 + 共享对象）
  - [x] Python 风格循环引用检测（引用计数差值法）
  - [x] 三代分代 GC 机制（年轻代/中年代/老年代）
  - [x] 对象提升机制（局部 -> 共享）
  - [x] 完整的并发支持（原子操作 + 互斥锁）
  - [x] 内存池优化（8 个大小类别，每个池独立锁）
  - [x] 完整的测试套件（6 个测试，包括多线程）
  - [x] 详细的实现文档

## 已知问题和限制

### 设计限制
1. 数组大小必须在编译时确定
   - 列表推导式返回固定最大容量的数组
   - 数组切片返回最大可能大小的数组

2. 列表推导式的实际长度信息丢失
   - `len()` 只能用于局部数组变量
   - 表达式结果无法查询长度

3. 类型推断限制
   - 函数参数默认推断为 `int`
   - 数组参数需要显式类型注解

### 技术债务
1. 性能优化
   - 数组操作涉及大量复制
   - 未使用 SIMD 或向量化
   - 栈分配可能浪费空间

2. 错误处理
   - 部分类型检查错误信息不够清晰
   - 缺少源码位置信息
   - 某些情况下继续编译导致误导性错误

3. 测试覆盖
   - 缺少系统化的测试框架
   - 边界情况测试不足

## 性能优化计划

### 短期
- [ ] 减少不必要的数组复制
- [ ] 优化列表推导式的内存分配
- [ ] 启用 LLVM 优化 pass (-O2, -O3)

### 长期
- [ ] 实现写时复制 (COW)
- [ ] 向量化循环操作
- [ ] 内联优化
- [ ] 逃逸分析

## 测试计划

### 单元测试
- [ ] 词法分析器测试
- [ ] 语法分析器测试
- [ ] 类型检查器测试
- [ ] 代码生成器测试

### 集成测试
- [ ] 端到端编译测试
- [ ] 运行时行为测试
- [ ] 性能基准测试

### 回归测试
- [ ] 已知 bug 测试用例
- [ ] 边界情况测试
- [ ] 压力测试
