# Dream 编程语言 - 快速开始

## 1. 环境准备

Dream 编译器使用 OCaml 编写,需要先安装 OCaml 工具链。

### 自动安装 (推荐)

```bash
./setup.sh
```

### 手动安装

#### macOS

```bash
brew install opam
opam init
eval $(opam env)
opam install dune menhir
```

#### Ubuntu/Debian

```bash
sudo apt install opam
opam init
eval $(opam env)
opam install dune menhir
```

## 2. 构建编译器

```bash
dune build
```

## 3. 运行第一个程序

### Hello World

创建文件 `test.dm`:

```python
print("Hello, Dream!")
```

编译并运行:

```bash
dune exec dream test.dm
./test
```

### 更多示例

#### 简单计算

```python
let x = 42
let y = 58
let z = x + y
print(z)  # 输出: 100
```

#### 函数定义

```python
def add(a: int, b: int) -> int:
    return a + b

let result = add(10, 20)
print(result)  # 输出: 30
```

#### 阶乘函数

```python
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))  # 输出: 120
```

#### 条件语句

```python
let age = 18

if age >= 18:
    print("成年人")
else:
    print("未成年")
```

#### 循环

```python
let i = 0
while i < 5:
    print(i)
    i = i + 1
```

## 4. 项目示例

项目中包含了一些示例程序:

```bash
# Hello World
dune exec dream examples/hello.dm
./examples/hello

# 简单算术
dune exec dream examples/simple.dm
./examples/simple

# 阶乘计算
dune exec dream examples/factorial.dm
./examples/factorial
```

## 5. 编译器工作流程

Dream 编译器的工作流程:

```
.dm 源文件
    ↓
词法分析 (Lexer)
    ↓
语法分析 (Parser)
    ↓
类型检查 (Type Checker)
    ↓
代码生成 (Code Generator)
    ↓
.c 文件
    ↓
GCC/Clang 编译
    ↓
可执行文件
```

## 6. 语言特性

### 支持的特性

✅ 基础类型: int, float, string, bool
✅ 变量声明: let
✅ 函数定义: def
✅ 类型推导
✅ 类型注解
✅ 条件语句: if/elif/else
✅ 循环: while, for
✅ 函数调用
✅ 递归
✅ 算术运算: +, -, *, /, %
✅ 比较运算: ==, !=, <, >, <=, >=
✅ 逻辑运算: and, or, not

### 进行中的特性

🚧 列表: list[T]
🚧 字典: dict[K, V]
🚧 元组: (T1, T2, ...)
🚧 类: class
🚧 接口: interface
🚧 模式匹配: match/case
🚧 Lambda 表达式
🚧 列表推导式

## 7. 常见问题

### Q: 如何查看生成的 C 代码?

A: 编译后会生成同名的 `.c` 文件:

```bash
dune exec dream test.dm
cat test.c  # 查看生成的 C 代码
```

### Q: 如何调试程序?

A: 可以查看生成的 C 代码或使用 gdb:

```bash
dune exec dream test.dm
gcc -g test.c -o test
gdb ./test
```

### Q: 编译器报错怎么办?

A: Dream 编译器会提供详细的错误信息,包括行号和列号。常见错误:

- **Lexical error**: 词法错误,检查是否有非法字符
- **Parse error**: 语法错误,检查语法是否正确
- **Type error**: 类型错误,检查类型是否匹配
- **Name error**: 变量未定义

### Q: 如何贡献代码?

A: 参考 `guide.md` 中的开发文档,然后提交 Pull Request。

## 8. 下一步

- 阅读 [完整文档](guide.md)
- 查看 [示例程序](examples/)
- 尝试编写自己的 Dream 程序
- 参与项目开发

## 9. 获取帮助

如果遇到问题:

1. 查看 `guide.md` 开发文档
2. 查看 `README.md` 项目说明
3. 提交 Issue

祝你使用 Dream 编程愉快! 🎉
