# Dream 编程语言 - 开发文档

## 项目概述

**Dream** 是一门面向 AI 应用开发的现代编译型语言。

**设计目标：**
- Python 风格的简洁语法（缩进敏感）
- TypeScript 风格的类型系统（类型推导 + 联合类型 + 泛型）
- 类型不可变（赋值后类型锁定）
- 编译成高性能二进制（通过 LLVM）
- 专注 AI 应用层：RAG、推理、数据处理

**实现语言：** OCaml + OCamllex + Menhir

**当前状态：** MVP 基本完成，核心功能可用

**重要更新**：
- ✅ `string` 类型已重命名为 `str`
- ✅ 文件 I/O 完整实现（字符串和字节）
- ✅ 类型模式匹配支持 Union 类型拆箱
- ✅ 测试套件整合优化（4个全面测试文件）

---

## 语言特性设计

### 1. 基础类型

```python
# 基本类型
let x = 42              # int
let y = 3.14            # float
let name = "Alice"      # string
let flag = true         # bool

# 容器类型
let nums = [1, 2, 3]           # list[int]
let mixed = [1, "two", 3.0]    # 编译错误！类型不一致
let scores: list[int] = []     # 空列表需要类型注解

# 字典
let user = {"name": "Bob", "age": 25}  # dict[str, int | str]
```

### 2. 类型推导与不可变性

```python
let x = 42          # 推导为 int
x = "hello"         # 编译错误！x 的类型已锁定为 int

let y = 10
y = 20              # OK，值可以改变，但类型不能变
```

### 3. 函数

```python
# 类型推导
def add(a: int, b: int):
    return a + b    # 返回类型自动推导为 int

# 显式返回类型
def multiply(a: int, b: int) -> int:
    return a * b

# 泛型函数
def first[T](items: list[T]) -> T | None:
    if len(items) > 0:
        return items[0]
    return None

# Lambda
let square = (x: int) => x * x
let add_lambda = (a: int, b: int) => a + b
```

### 4. 联合类型

```python
# 可选类型
def find_user(id: int) -> User | None:
    # ...

# 多类型联合
let result: int | str | Error = compute()

# 类型检查
match result:
    case x: int:
        print(x * 2)
    case s: str:
        print(s.upper())
    case e: Error:
        print(f"Error: {e}")
```

### 5. 结构体

Dream 支持结构体作为自定义数据类型：

```python
# 定义结构体
struct Point:
    x: int
    y: int

# 创建实例
let p = Point{x: 10, y: 20}

# 访问字段
print(p.x)  # 输出: 10
print(p.y)  # 输出: 20

# 修改字段(如果支持)
p.x = 30

# 带有更多字段的结构体
struct Person:
    name: str
    age: int
    email: str

let alice = Person{name: "Alice", age: 25, email: "alice@example.com"}
```

结构体特点：
- 字段需要类型标注
- 使用花括号语法创建实例
- 使用点号访问字段
- 所有字段必须在创建时初始化

### 6. 类和接口

实现接口类型，类似rust的 trait，可以

1. 定义接口
2. 可以有关联类型，常量
3. 可以有默认实现
4. 给任何类型实现，包括内置类型
5. 用接口实现运算符重载
6. ✅ 支持像go一样的隐式实现(编译时检查)，或显式实现

#### 隐式接口实现（Duck Typing）

Dream 支持 Go 风格的隐式接口实现。如果一个结构体实现了接口要求的所有方法(方法名和签名都匹配),则该结构体自动满足该接口,无需显式声明。

**特性:**
- 编译时检查方法签名兼容性
- 不需要显式的 `implements` 或 `impl` 声明
- 支持方法签名的类型统一检查
- 允许一个结构体同时隐式实现多个接口

**实现细节:**
- `env.ml` 中的 `struct_implements_interface` 函数检查结构体是否满足接口
- 使用 `unify` 函数进行方法签名的类型兼容性检查
- 有默认实现的接口方法不是必需的
- 代码生成器使用 `StructPtr` 类型保留结构体类型信息,确保方法调度正确

**示例:** 见 `test/test_implicit_interface.dm`

```python
# 接口定义
interface Animal:
    name: str
    def speak(self) -> str

# 类实现
class Dog implements Animal:
    name: str
    breed: str
    
    def __init__(self, name: str, breed: str):
        self.name = name
        self.breed = breed
    
    def speak(self) -> str:
        return "Woof!"

# 继承
class Puppy(Dog):
    age: int
    
    def __init__(self, name: str, breed: str, age: int):
        super().__init__(name, breed)
        self.age = age
```

### 7. 模式匹配

Dream 支持强大的模式匹配功能，包括值匹配、类型匹配和解构匹配。

```python
# 值匹配
match x:
    case 0:
        print("zero")
    case 1:
        print("one")
    case n if n > 10:
        print("big")
    case _:
        print("other")

# 类型模式匹配（✅ 已实现）
match value:
    x: int:
        print(f"Integer: {x}")
    s: str:
        print(f"String: {s}")
    _:
        print("Unknown")

# 解构匹配
match point:
    case (0, 0):
        print("origin")
    case (x, 0):
        print(f"on x-axis: {x}")
    case (0, y):
        print(f"on y-axis: {y}")
    case (x, y):
        print(f"point: ({x}, {y})")
```

#### 类型模式匹配（Type Pattern Matching）

类型模式匹配允许在 match 表达式中根据 Union 类型的实际类型进行分支：

**语法格式：** `变量名: 类型名`

**特性：**
- 自动进行运行时类型检查（使用 union_is_* 函数）
- 自动拆箱到具体类型（使用 union_get_* 函数）
- 类型安全：拆箱后的变量具有正确的类型
- 支持 int, string, bool 类型

**示例应用：统一的文件 I/O 接口**

```python
def file_write_unified(path: str, content: str | bytes) -> int:
    """根据 content 的实际类型自动选择底层函数"""
    match content:
        data: str:
            return file_write(path, data)
        data: bytes:
            return file_write_bytes(path, data)
        _:
            return 0

# 使用示例
file_write_unified("test.txt", "Hello")  # 调用 file_write
file_write_unified("test.bin", byte_data)  # 调用 file_write_bytes
```

**实现细节：**
- Parser: 支持 `name: type` 语法，生成 `PType(name, type_expr)` AST 节点
- 类型检查: 验证类型与 Union 兼容性，绑定正确的具体类型
- 代码生成: 生成 LLVM IR 类型检查和拆箱代码

详见：[docs/type_pattern_matching.md](./type_pattern_matching.md)

### 8. AI 专用特性（Phase 2）

```python
# Vector 类型
let embedding: Vector[1536] = model.encode("hello")

# Tensor 类型
let input: Tensor[1, 3, 224, 224] = load_image("cat.jpg")

# ONNX 模型推理
let model = load_onnx("model.onnx")
let output = model.infer(input)

# RAG 系统
class RAGSystem:
    db: VectorDB
    llm: LLM
    
    async def query(self, question: str) -> str | Error:
        docs = await self.db.search(question, top_k=5)
        context = docs.map(d => d.content).join("\n")
        return await self.llm.chat(f"{context}\n\n{question}")
```

---

## 开发路线图

### Phase 1: 核心编译器（Week 1-6）

#### Week 1: 词法分析
- [x] 项目搭建（Dune 配置）
- [ ] Token 定义（ast.ml）
- [ ] 词法分析器（lexer.mll）
  - 关键字：let, def, class, if, else, match, case, return, import
  - 标识符和字面量
  - 运算符和分隔符
  - 缩进处理（INDENT/DEDENT token）
- [ ] 词法分析器测试

#### Week 2: 语法分析
- [ ] AST 定义（ast.ml）
  - 表达式（expr）
  - 语句（statement）
  - 类型注解（type_annotation）
  - 模块（program）
- [ ] 语法分析器（parser.mly）
  - 表达式解析（优先级处理）
  - 语句解析
  - 缩进敏感语法
- [ ] 语法分析器测试

#### Week 3: 类型系统基础
- [ ] 类型定义（types.ml）
  - 基础类型（int, float, string, bool）
  - 复合类型（list, dict, tuple）
  - 函数类型
- [ ] 环境管理（env.ml）
  - 符号表
  - 作用域管理
- [ ] 基础类型推导（typeck.ml）

#### Week 4: 类型系统完善
- [ ] 泛型支持
- [ ] 联合类型
- [ ] 类型检查完善
  - 函数调用检查
  - 赋值类型检查
  - 不可变性检查
- [ ] 类型错误报告

#### Week 5-6: 代码生成
- [ ] 选择后端：
  - **方案 A：转译到 C**（推荐，简单快速）
  - 方案 B：生成 LLVM IR（复杂但强大）
  - 方案 C：字节码 + 虚拟机（中等复杂度）
- [ ] 代码生成器实现
- [ ] 运行时支持（内存管理、垃圾回收）
- [ ] 测试和调试

### Phase 2: 标准库（Week 7-8）

- [ ] 基础 I/O
- [ ] 字符串操作
- [ ] 集合类型实现
- [ ] 文件操作

### Phase 3: AI 特性（Week 9-12）

- [ ] Vector 类型
- [ ] Tensor 类型
- [ ] ONNX 模型加载
- [ ] 异步支持（async/await）

### Phase 4: 工具链（Week 13+）

- [ ] REPL
- [ ] 包管理器
- [ ] LSP 服务器（IDE 支持）
- [ ] 文档生成器

---

## 里程碑检查点

### Milestone 1: 词法分析器完成（Week 1）
- [ ] 能识别所有 token
- [ ] 处理缩进
- [ ] 测试覆盖率 > 80%
- [ ] 示例：`let x = 42 + 58`

### Milestone 2: 语法分析器完成（Week 2）
- [ ] 能解析表达式和语句
- [ ] 生成正确的 AST
- [ ] 测试覆盖率 > 80%
- [ ] 示例：完整的函数定义

### Milestone 3: 类型检查器完成（Week 4）
- [ ] 基础类型推导
- [ ] 类型错误检测
- [ ] 友好的错误提示
- [ ] 示例：检测类型不匹配

### Milestone 4: Hello World（Week 6）
- [ ] 能编译并运行 `print("Hello, World!")`
- [ ] 生成可执行文件
- [ ] 第一个完整的端到端流程

### Milestone 5: MVP 完成（Week 8）
- [ ] 支持函数、变量、控制流
- [ ] 标准库基础
- [ ] 能写实用的小程序
- [ ] 文档完善

---

## 注意事项

### 1. 缩进处理很关键
Python 风格的缩进是 Dream 的核心特性，词法分析阶段必须正确处理。

### 2. 类型推导需要仔细设计
从简单开始，逐步支持更复杂的类型。先实现基础类型，再加泛型和联合类型。

### 3. 错误提示要友好
编译器的错误提示直接影响用户体验。投入时间做好错误处理是值得的。

### 4. 测试驱动开发
每个功能都先写测试，再实现。这样能保证代码质量和可维护性。

### 5. 小步快跑
不要试图一次实现所有特性。先让最简单的程序跑起来，再逐步添加功能。

---

## 资源和参考

### 学习资源
- **Real World OCaml**：https://dev.realworldocaml.org/
- **OCaml Manual**：https://ocaml.org/manual/
- **Menhir Manual**：http://gallium.inria.fr/~fpottier/menhir/
- **Crafting Interpreters**：https://craftinginterpreters.com/

### 相关项目
- **Rust 编译器早期版本**（OCaml 实现）
- **Flow**（Facebook 的 JS 类型检查器）
- **ReScript**（编译到 JavaScript）

### 社区
- OCaml Discourse: https://discuss.ocaml.org/
- OCaml Discord
- r/ocaml
