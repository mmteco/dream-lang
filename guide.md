# Dream 编程语言 - 开发文档

## 项目概述

**Dream** 是一门面向 AI 应用开发的现代编译型语言。

**设计目标：**
- Python 风格的简洁语法（缩进敏感）
- TypeScript 风格的类型系统（类型推导 + 联合类型 + 泛型）
- 类型不可变（赋值后类型锁定）
- 编译成高性能二进制（通过 LLVM 或转译到 C）
- 专注 AI 应用层：RAG、推理、数据处理

**实现语言：** OCaml + OCamllex + Menhir

**目标时间：** 6-8 周达到可用版本（MVP）

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
let user = {"name": "Bob", "age": 25}  # dict[string, int | string]
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

### 5. 类和接口

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

### 6. 模式匹配

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

# 类型匹配
match value:
    case x: int:
        print(f"Integer: {x}")
    case s: str:
        print(f"String: {s}")
    case _:
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

### 7. AI 专用特性（Phase 2）

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

## 项目结构

```
dream/
├── dune-project              # Dune 项目配置
├── dune                      # 构建配置
├── README.md                 # 项目说明
├── bin/
│   ├── dune                  # 可执行文件配置
│   └── main.ml               # 编译器入口
├── lib/
│   ├── dune                  # 库配置
│   ├── ast.ml                # AST 数据结构定义
│   ├── lexer.mll             # 词法分析器（OCamllex）
│   ├── parser.mly            # 语法分析器（Menhir）
│   ├── types.ml              # 类型系统定义
│   ├── typeck.ml             # 类型检查器
│   ├── env.ml                # 环境管理（符号表）
│   ├── ir.ml                 # 中间表示（可选）
│   ├── codegen.ml            # 代码生成器
│   └── error.ml              # 错误处理
├── test/
│   ├── dune                  # 测试配置
│   ├── test_lexer.ml         # 词法分析器测试
│   ├── test_parser.ml        # 语法分析器测试
│   └── test_typeck.ml        # 类型检查器测试
├── examples/
│   ├── hello.dm              # Hello World
│   ├── factorial.dm          # 阶乘示例
│   ├── quicksort.dm          # 快速排序
│   └── classes.dm            # 类和接口示例
└── stdlib/
    ├── io.dm                 # I/O 标准库
    ├── collections.dm        # 集合类型
    └── string.dm             # 字符串操作
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

## 技术细节

### 1. 缩进处理策略

Dream 使用 Python 风格的缩进，需要在词法分析阶段生成 INDENT/DEDENT token。

**方法：**

```ocaml
(* lexer.mll 中维护缩进栈 *)
{
  let indent_stack = ref [0]  (* 缩进层级栈 *)
  
  (* 计算行首空格数 *)
  let count_spaces s =
    let rec loop i =
      if i >= String.length s then i
      else match s.[i] with
      | ' ' -> loop (i + 1)
      | '\t' -> loop (i + 8)  (* tab = 8 spaces *)
      | _ -> i
    in loop 0
  
  (* 生成 INDENT/DEDENT tokens *)
  let handle_indentation spaces =
    let current = List.hd !indent_stack in
    if spaces > current then begin
      indent_stack := spaces :: !indent_stack;
      [INDENT]
    end else if spaces < current then begin
      let rec pop acc =
        match !indent_stack with
        | [] -> acc
        | x :: xs ->
            if x > spaces then begin
              indent_stack := xs;
              pop (DEDENT :: acc)
            end else acc
      in pop []
    end else []
}
```

### 2. 类型推导算法

使用 **Hindley-Milner** 类型推导算法的简化版本。

**核心思想：**
1. 为每个表达式分配类型变量
2. 根据语法规则生成类型约束
3. 求解约束（统一化）
4. 替换类型变量得到具体类型

**示例：**

```ocaml
(* typeck.ml *)
let rec infer env = function
  | EInt _ -> TInt
  | EVar name -> Env.find name env
  | EBinOp (left, Add, right) ->
      let left_ty = infer env left in
      let right_ty = infer env right in
      unify left_ty TInt;
      unify right_ty TInt;
      TInt
  | ELet (name, None, value, body) ->
      let value_ty = infer env value in
      let new_env = Env.add name value_ty env in
      infer new_env body
  | ELet (name, Some ty_annot, value, body) ->
      let value_ty = infer env value in
      unify value_ty ty_annot;
      let new_env = Env.add name ty_annot env in
      infer new_env body
```

### 3. 代码生成策略

#### 方案 A：转译到 C（推荐）

**优势：**
- 实现简单
- 可移植性好
- 利用 GCC/Clang 优化

**示例：**

```ocaml
(* codegen.ml *)
let rec gen_expr = function
  | EInt n -> string_of_int n
  | EVar name -> name
  | EBinOp (left, Add, right) ->
      Printf.sprintf "(%s + %s)" (gen_expr left) (gen_expr right)
  | ECall (func, args) ->
      let args_str = String.concat ", " (List.map gen_expr args) in
      Printf.sprintf "%s(%s)" (gen_expr func) args_str

let gen_program stmts =
  let c_code = Buffer.create 1024 in
  Buffer.add_string c_code "#include <stdio.h>\n\n";
  List.iter (fun stmt ->
    Buffer.add_string c_code (gen_stmt stmt);
    Buffer.add_string c_code "\n"
  ) stmts;
  Buffer.contents c_code
```

#### 方案 B：LLVM IR

**优势：**
- 性能最优
- 跨平台支持好

**工具：** `llvm` OCaml 包

**示例：**

```ocaml
open Llvm

let codegen_expr builder = function
  | EInt n -> const_int (i32_type context) n
  | EBinOp (left, Add, right) ->
      let lhs = codegen_expr builder left in
      let rhs = codegen_expr builder right in
      build_add lhs rhs "addtmp" builder
```

---

## 错误处理

### 错误类型

```ocaml
(* error.ml *)
type error =
  | LexError of string * int * int
  | ParseError of string * int * int
  | TypeError of string * int * int
  | NameError of string * int * int

type position = {
  line: int;
  column: int;
}

let format_error err =
  match err with
  | LexError (msg, line, col) ->
      Printf.sprintf "Lexical error at %d:%d: %s" line col msg
  | ParseError (msg, line, col) ->
      Printf.sprintf "Parse error at %d:%d: %s" line col msg
  | TypeError (msg, line, col) ->
      Printf.sprintf "Type error at %d:%d: %s" line col msg
  | NameError (msg, line, col) ->
      Printf.sprintf "Name error at %d:%d: %s" line col msg
```

### 友好的错误提示

```
Error: Type mismatch at line 5, column 10
  5 | let x = 42
  6 | x = "hello"
        ^^^^^^^ Expected type 'int', got 'string'
  
  Note: Variable 'x' was bound to type 'int' at line 5
        Once bound, types cannot be changed in Dream
```

---

## 测试策略

### 单元测试

```ocaml
(* test/test_lexer.ml *)
open OUnit2
open Dream.Lexer

let test_lex_integer _ =
  let tokens = lex_string "42" in
  assert_equal [INT 42; EOF] tokens

let test_lex_identifier _ =
  let tokens = lex_string "hello" in
  assert_equal [IDENT "hello"; EOF] tokens

let suite = "Lexer Tests" >::: [
  "integer" >:: test_lex_integer;
  "identifier" >:: test_lex_identifier;
]

let () = run_test_tt_main suite
```

### 集成测试

```ocaml
(* test/test_integration.ml *)
let compile_and_run source expected =
  let ast = parse (lex source) in
  let typed = type_check ast in
  let code = codegen typed in
  let output = execute code in
  assert_equal expected output

let test_hello_world _ =
  compile_and_run 
    "print(\"Hello, World!\")" 
    "Hello, World!\n"

let test_factorial _ =
  compile_and_run
    "def fact(n: int) -> int:
       if n == 0:
         return 1
       return n * fact(n - 1)
     print(fact(5))"
    "120\n"
```

---

## 示例程序

### Hello World

```python
# hello.dm
def main():
    print("Hello, Dream!")

main()
```

### 阶乘

```python
# factorial.dm
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

let result = factorial(5)
print(f"5! = {result}")
```

### 快速排序

```python
# quicksort.dm
def quicksort[T](arr: list[T]) -> list[T]:
    if len(arr) <= 1:
        return arr
    
    let pivot = arr[0]
    let less = [x for x in arr[1:] if x < pivot]
    let greater = [x for x in arr[1:] if x >= pivot]
    
    return quicksort(less) + [pivot] + quicksort(greater)

let nums = [3, 7, 1, 9, 2, 5]
let sorted = quicksort(nums)
print(sorted)  # [1, 2, 3, 5, 7, 9]
```

### 类和接口

```python
# animals.dm
interface Animal:
    name: str
    def speak(self) -> str

class Dog implements Animal:
    name: str
    breed: str
    
    def __init__(self, name: str, breed: str):
        self.name = name
        self.breed = breed
    
    def speak(self) -> str:
        return f"{self.name} says: Woof!"

class Cat implements Animal:
    name: str
    
    def __init__(self, name: str):
        self.name = name
    
    def speak(self) -> str:
        return f"{self.name} says: Meow!"

def make_animals_speak(animals: list[Animal]):
    for animal in animals:
        print(animal.speak())

let pets: list[Animal] = [
    Dog("Buddy", "Golden Retriever"),
    Cat("Whiskers")
]

make_animals_speak(pets)
```

---

## 构建和运行

### 安装依赖

```bash
# 安装 OCaml 和 OPAM
brew install opam  # macOS
# 或
apt install opam   # Ubuntu

# 初始化 OPAM
opam init
eval $(opam env)

# 安装依赖
opam install dune menhir ocaml-lsp-server ocamlformat
```

### 构建项目

```bash
# 构建
dune build

# 运行测试
dune test

# 运行编译器
dune exec dream -- examples/hello.dm

# 安装
dune install
```

### Dune 配置文件

#### `dune-project`

```lisp
(lang dune 3.0)
(name dream)
(version 0.1.0)

(generate_opam_files true)

(package
 (name dream)
 (synopsis "Dream programming language compiler")
 (description "A modern compiled language for AI applications")
 (depends
  (ocaml (>= 4.14))
  dune
  menhir
  (llvm (>= 14.0))))
```

#### `lib/dune`

```lisp
(library
 (name dream_lib)
 (modules ast lexer parser types typeck env codegen error)
 (libraries llvm))

(menhir
 (modules parser))

(ocamllex
 (modules lexer))
```

#### `bin/dune`

```lisp
(executable
 (name main)
 (public_name dream)
 (libraries dream_lib))
```

---

## 开发工作流

### 每日开发流程

1. **编写代码**
   ```bash
   vim lib/lexer.mll  # 或你喜欢的编辑器
   ```

2. **构建**
   ```bash
   dune build
   ```

3. **测试**
   ```bash
   dune test
   ```

4. **运行**
   ```bash
   dune exec dream -- examples/test.dm
   ```

5. **提交**
   ```bash
   git add .
   git commit -m "feat: add lexer support for floats"
   ```

### 调试技巧

```ocaml
(* 在关键位置添加调试输出 *)
let debug_expr expr =
  Printf.eprintf "DEBUG: expr = %s\n" (show_expr expr);
  expr

(* 使用 ocamldebug *)
ocamldebug _build/default/bin/main.exe

(* 使用 utop 交互式测试 *)
utop
# #require "dream_lib";;
# open Dream_lib.Ast;;
# let tokens = Lexer.lex_string "let x = 42";;
```

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

---

## 下一步行动

### 立即开始
1. 创建项目结构
2. 配置 Dune
3. 实现第一个 Token 识别
4. 写第一个测试

### Week 1 目标
- 完整的词法分析器
- 能识别所有关键字和基本 token
- 处理缩进
- 测试通过

---

## 附录：完整的 Token 定义

```ocaml
(* ast.ml - Token 定义 *)
type token =
  (* 字面量 *)
  | INT of int
  | FLOAT of float
  | STRING of string
  | BOOL of bool
  
  (* 标识符 *)
  | IDENT of string
  
  (* 关键字 *)
  | LET
  | DEF
  | CLASS
  | INTERFACE
  | IMPLEMENTS
  | IF
  | ELSE
  | ELIF
  | MATCH
  | CASE
  | FOR
  | WHILE
  | RETURN
  | IMPORT
  | FROM
  | AS
  | ASYNC
  | AWAIT
  
  (* 运算符 *)
  | PLUS       (* + *)
  | MINUS      (* - *)
  | TIMES      (* * *)
  | DIV        (* / *)
  | MOD        (* % *)
  | EQ         (* == *)
  | NEQ        (* != *)
  | LT         (* < *)
  | GT         (* > *)
  | LTE        (* <= *)
  | GTE        (* >= *)
  | AND        (* and *)
  | OR         (* or *)
  | NOT        (* not *)
  | ASSIGN     (* = *)
  | ARROW      (* => *)
  | PIPE       (* | *)
  
  (* 分隔符 *)
  | LPAREN     (* ( *)
  | RPAREN     (* ) *)
  | LBRACKET   (* [ *)
  | RBRACKET   (* ] *)
  | LBRACE     (* { *)
  | RBRACE     (* } *)
  | COMMA      (* , *)
  | COLON      (* : *)
  | SEMICOLON  (* ; *)
  | DOT        (* . *)
  
  (* 缩进 *)
  | INDENT
  | DEDENT
  | NEWLINE
  
  (* 特殊 *)
  | EOF
```