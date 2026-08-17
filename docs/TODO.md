# Dream 语言开发任务列表

## 当前优先级

### 🚧 自举与 DIR 完整化主线

- [x] 稳定当前 bootstrap/compiler.dm 自举切片，并通过 Stage 0 → Stage 1 → Stage 2 → Stage 3 回归
- [x] DM 编译器主链改为与 OCaml 版本一致的流水线：发射器直接构建结构化 DIR records → DIR verifier → DIR LLVM lowering → LLVM IR（移除 LLVM 文本反解析）
- [x] 新管线（AST 节点池 → lower 顶向下遍历 → 结构化 DIR records → LLVM）实现完整自举：stage1 编译 compiler.dm → stage2 → stage3，三级编译器均能编译运行程序（hello 输出验证）
  - [x] 默认管线切换：`DEBUG` 与否均走新管线（旧 HIR/DM_DIR/emit 保留但不再执行，待 P5 清理）
  - [x] switch/case/default lowering（lower_stmt_switch + lower_switch_comparison）
  - [x] 全局 let 定义段与 main 入口表达式初始化（含 dict 字面量）
  - [x] struct 字面量扩容（15+ 字段）、dict 字面量扩容（20 对）与 key/value 类型分派
  - [x] 循环内 alloca 提升修复（append_hoisted_function 提升到函数头，兼容新旧管线布局）
  - [x] list[str] 类型支持（get_pointer + 槽偏移）、tuple 解包指针元素（返回类型注解解析）
  - [x] ord 身份函数、字符串索引/比较、bool 与 int 混合比较
  - [x] 性能优化：`__c_range_equal`（范围 memcmp 比较）、struct 声明哈希定位、`__c_fnv_hash_range` 预收集；lower 8.1s → 2.7s（约 3 倍提速）
- [ ] 冻结 bootstrap 语法子集，增加语法边界和行为回归协议
- [ ] 用 Dream 重写完整 lexer、parser、typechecker 和 DIR compiler
- [ ] 完成真正的完整编译器自举，而不只验证 bootstrap/compiler.dm 切片
- [ ] 设计并实现函数类型和函数值
  - [x] 确定 lambda 语法和函数类型标注语法
  - [x] 无捕获 lambda 的函数提升和间接调用
  - [x] 基础闭包捕获环境和闭包 runtime ABI
  - [ ] 可变共享捕获和完整闭包生命周期规则
- [ ] 完善泛型和单态化
  - [ ] 泛型容器（list、dict、tuple、struct、enum）
  - [ ] 高阶泛型函数和泛型约束
- [ ] 完善 enum 和错误处理
  - [ ] 多载荷 enum
  - [ ] Option/Result 的完整类型参数传播
  - [ ] 可转换错误类型的 `?` 错误传播
- [ ] 完成动态对象和接口派发
  - [x] 结构体方法的静态 DIR lowering 与直接调用
  - [ ] 动态对象表示和生命周期规则
  - [ ] interface/impl 的 DIR lowering
    - [x] 具体结构体上的静态 impl 方法 lowering
    - [x] 宿主 DIR interface value、vtable 和间接调用 ABI
    - [x] Stage2/Stage3 interface value、vtable 和间接调用
  - [x] vtable 和动态方法调用（当前为无状态接口对象 ABI）
- [ ] 补齐标准库实现，移除 `pass` 占位模块
- [ ] 完整自举验收
  - [ ] Stage 2 → Stage 3 使用完整 Dream 编译器
  - [ ] DIR verifier、LLVM verifier 和行为测试全部通过
  - [ ] 规范化 DIR 达到固定点

### 🚀 高优先级

#### P0 - 核心功能缺失

- [x] 动态大小数组/列表 
- [x] 泛型系统
  - [ ] 泛型约束和高级特性（待扩展）

#### P1 - 重要改进

- [x] 表达式运算符
- [x] 字符串类型
- [x] 文件 I/O
- [ ] 错误处理
  - [x] 源码位置追踪
  - [ ] 更好的错误消息
  - [ ] 编译时错误恢复

### 🔧 中优先级

#### P2 - 语言特性扩展

- [x] 字典类型
- [x] 元组类型
- [x] Match 表达式
- [x] Enum 类型
- [x] Union 类型
- [ ] Lambda 表达式
  - [x] 语法解析
  - [x] 基础闭包捕获
  - [x] 代码生成
  - [ ] 可变共享捕获

#### P3 - 面向对象

- [x] 结构体
- [x] 接口系统
  - [x] 运算符重载支持
    - [x] 环境模块：运算符查找函数
    - [x] 类型检查器：接口实现验证
    - [x] 代码生成器：运算符脱糖到方法调用
    - [x] Union 类型参数支持（自动装箱/拆箱）
    - [x] match type of 中的变量重新绑定
    - [x] 标准库运算符接口（stdlib/operators.dm）
    - [x] 返回类型注册表和正确的类型推断
  - [ ] 接口约束的泛型函数（需要语法扩展）
  - [x] 隐式实现检查（Go风格duck typing）
  - [ ] 动态方法调用（需要 vtable）

### 📚 低优先级

#### P4 - 标准库
- [x] 字符串缓冲区
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

- [x] LSP 服务器
  - [x] 语法高亮
  - [ ] 自动补全
  - [x] 跳转定义
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
  - [x] import/from import
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
- [x] 基本类型 (int, bool, str, rune, byte)
- [x] 固定大小数组
- [x] 数组字面量 `[1, 2, 3]`
- [x] 数组索引 `arr[i]`
- [x] 数组索引赋值 `arr[i] = value`
- [x] array(list) 函数 - 从 list 创建固定大小数组
- [x] array_new(n) 函数 - 创建指定长度的数组
- [x] 字典类型 (核心功能)
- [x] 元组解包
- [x] 测试文件整理

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
- [x] bootstrap 编译器性能优化（source_type_is_interface 预收集声明表：emit 38s → 11.3s；lex 魔法数字常量）

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
