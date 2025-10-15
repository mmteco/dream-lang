# Dream 编程语言

Dream 是一门面向 AI 应用开发的现代编译型语言。

## 特性

- **Python 风格的简洁语法**：缩进敏感的语法设计
- **TypeScript 风格的类型系统**：类型推导 + 联合类型
- **类型不可变**：变量赋值后类型锁定
- **编译成高性能二进制**：通过转译到 C 实现
- **专注 AI 应用层**：RAG、推理、数据处理

## 安装依赖

### macOS

```bash
# 安装 OPAM (OCaml 包管理器)
brew install opam

# 初始化 OPAM
opam init
eval $(opam env)

# 安装必需的包
opam install dune menhir ocamlformat ocaml-lsp-server
```

### Ubuntu/Debian

```bash
# 安装 OPAM
sudo apt install opam

# 初始化 OPAM
opam init
eval $(opam env)

# 安装必需的包
opam install dune menhir ocamlformat ocaml-lsp-server
```

## 构建

```bash
# 构建编译器
dune build

# 安装到系统
dune install
```

## 使用

### 编译 Dream 程序

```bash
# 使用编译器
dune exec dream examples/hello.dm

# 或者安装后直接使用
dream examples/hello.dm
```

### Hello World 示例

创建文件 `hello.dm`:

```python
print("Hello, Dream!")
```

运行:

```bash
dream hello.dm
./hello
```

### 更多示例

#### 变量和类型推导

```python
let x = 42              # int
let y = 3.14            # float
let name = "Alice"      # string
let flag = True         # bool
```

#### 函数定义

```python
def add(a: int, b: int) -> int:
    return a + b

let result = add(10, 20)
print(result)  # 输出: 30
```

#### 阶乘示例

```python
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

let result = factorial(5)
print(result)  # 输出: 120
```

## 项目结构

```
dream/
├── dune-project              # Dune 项目配置
├── README.md                 # 项目说明
├── guide.md                  # 开发指南
├── bin/
│   ├── dune                  # 可执行文件配置
│   └── main.ml               # 编译器入口
├── lib/
│   ├── dune                  # 库配置
│   ├── ast.ml                # AST 数据结构定义
│   ├── error.ml              # 错误处理
│   ├── lexer.mll             # 词法分析器
│   ├── parser.mly            # 语法分析器
│   ├── types.ml              # 类型系统定义
│   ├── env.ml                # 环境管理
│   ├── typeck.ml             # 类型检查器
│   └── codegen.ml            # 代码生成器
├── examples/
│   ├── hello.dm              # Hello World
│   ├── simple.dm             # 简单示例
│   └── factorial.dm          # 阶乘示例
└── test/                     # 测试文件
```

## 当前状态

这是 Dream 语言的 MVP (最小可用版本),实现了以下功能:

✅ 已实现:
- 词法分析器 (支持缩进敏感语法)
- 语法分析器 (支持基本语法结构)
- 类型系统 (基础类型推导和统一化算法)
- 类型检查器 (Hindley-Milner 风格)
- 代码生成器 (转译到 C)
- 基本语句: let, def, if, while, for, return
- 基本表达式: 算术运算, 比较, 逻辑运算
- 函数定义和调用

🚧 进行中:
- 列表和字典完整支持
- 类和接口
- 模式匹配
- Lambda 表达式
- 列表推导式

📋 计划中:
- 标准库
- 异步支持 (async/await)
- Vector 和 Tensor 类型
- ONNX 模型支持
- REPL
- LSP 服务器

## 开发

### 运行测试

```bash
dune test
```

### 格式化代码

```bash
dune build @fmt --auto-promote
```

### 清理构建

```bash
dune clean
```

## 贡献

欢迎贡献代码、报告问题或提出建议!

## 许可证

MIT License

## 文档

详细的开发文档请参考 [guide.md](guide.md)
