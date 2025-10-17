# Dream 语言规范

## 语言概述

Dream 是一门面向 AI 应用开发的现代编译型语言，结合了 Python 的简洁语法和静态类型系统的安全性。

### 设计目标
- Python 风格的简洁语法
- 静态类型推导
- 编译为高性能机器码
- 专注 AI 应用层开发

## 词法规则

### 关键字
```
let def struct interface implements impl type const enum
if else elif match case for while return
import from as async await
True False None
true false none  # 小写形式
self super in
and or not
```

注意：
- `Some`、`Ok`、`Err` 不再是关键字，现在通过标准枚举实现 Option 和 Result 类型
- `impl` 用于为类型实现接口
- `type` 用于关联类型声明
- `const` 用于关联常量声明

### 标识符
- 以字母或下划线开头
- 包含字母、数字、下划线
- 区分大小写
- 示例: `x`, `my_var`, `MyClass`, `_private`

### 字面量

#### 整数
```python
42          # 十进制
0x2A        # 十六进制 (未实现)
0o52        # 八进制 (未实现)
0b101010    # 二进制 (未实现)
```

#### 浮点数
```python
3.14        # 标准形式
.5          # 省略整数部分 (未实现)
2.          # 省略小数部分 (未实现)
1e-10       # 科学计数法 (未实现)
```

#### 字符串
```python
"hello"             # 双引号字符串
'world'             # 单引号字符串 (未实现)
"""multiline"""     # 多行字符串 (未实现)
f"x = {x}"          # 格式化字符串 (未实现)
```

#### 布尔值
```python
True   # 或 true（支持小写）
False  # 或 false（支持小写）
```

#### None
```python
None   # 或 none（支持小写）
```

### 运算符

#### 算术运算符
```python
+    # 加法 (整数/列表拼接)
-    # 减法
*    # 乘法
/    # 除法
%    # 取模
```

#### 比较运算符
```python
==   # 等于
!=   # 不等于
<    # 小于
>    # 大于
<=   # 小于等于
>=   # 大于等于
```

#### 逻辑运算符
```python
and  # 逻辑与
or   # 逻辑或
not  # 逻辑非
```

#### 赋值运算符
```python
=    # 赋值
```

#### 三元运算符 ✅
```python
condition ? true_val : false_val
```

三元运算符用于内联条件表达式：

```python
let x = 10
let result = x > 5 ? 1 : 0  # result = 1

# 嵌套使用
let grade = score > 90 ? "A" : score > 80 ? "B" : "C"

# 与其他表达式结合
let max = a > b ? a : b
```

**特性**：
- condition 必须是布尔类型
- true_val 和 false_val 的类型必须相同
- 可以嵌套使用
- 优先级最低（低于所有二元运算符）

#### 错误传播运算符 ✅
```python
expr?    # 错误传播（后缀运算符）
```

错误传播运算符 `?` 用于简化 Result 类型的错误处理：

```python
def divide(a: int, b: int) -> Result[int, str]:
    return match b:
        0: Err("division by zero")
        _: Ok(a / b)

def safe_divide(a: int, b: int) -> int:
    # 如果 divide 返回 Err，会提前返回错误
    let result = divide(a, b)?
    return result

# 与 match 对比
def manual_error_handling(a: int, b: int) -> int:
    return match divide(a, b):
        Ok(v): v
        Err(_): 0  # 错误情况返回 0
```

**特性**：
- 只能用于 Result 类型的表达式
- 如果是 Ok(value)，提取并返回 value
- 如果是 Err(error)，**立即返回包含该错误的 Result 给调用者**
- 完全实现了 Rust 的 `?` 运算符语义

**错误传播行为**：
```python
# 如果函数返回 Result 类型，错误会被传播
def calculate(x: int, y: int, z: int) -> Result[int, str]:
    let step1 = divide(x, y)?  # 如果出错，立即 return Err(...)
    let step2 = divide(step1, z)?  # 如果出错，立即 return Err(...)
    return Ok(step2)

# 如果函数返回其他类型，会提取错误值返回
def safe_divide(a: int, b: int) -> int:
    let result = divide(a, b)?  # 如果出错，提取 Err 值并返回
    return result
```

**实现细节**：
- 检查当前函数的返回类型
- 如果返回 Result (EnumPtr)，直接返回原 Result
- 如果返回 int，提取 Err 中的 int 值并返回
- 错误发生时会**提前返回整个函数**，不是表达式级别的返回

### 分隔符
```python
( )  # 圆括号 - 函数调用、表达式分组、元组
[ ]  # 方括号 - 列表、索引、切片
{ }  # 花括号 - 字典
,    # 逗号 - 分隔符
:    # 冒号 - 类型注解、语句块
->   # 箭头 - 返回类型
.    # 点号 - 属性访问
```

### 缩进
- 使用缩进表示代码块
- 推荐使用 4 个空格
- 不支持 tab 和空格混用

## 类型系统

### 基本类型

#### int - 整数类型
```python
let x = 42              # 类型推导为 int
let y: int = 100        # 显式类型注解
```

#### float - 浮点数类型
```python
let pi = 3.14           # 类型推导为 float
let e: float = 2.718    # 显式类型注解
```

#### bool - 布尔类型
```python
let flag = True         # 类型推导为 bool（也可以用 true）
let ready: bool = false # 显式类型注解（也可以用 False）
```

#### str - 字符串类型
```python
let name = "Alice"      # 类型推导为 str
let msg: str = "Hi"  # 显式类型注解
```

### 复合类型

#### 列表 (固定大小数组)
```python
let numbers: [int] = [1, 2, 3, 4, 5]
let empty: [int] = []

# 类型推导
let inferred = [1, 2, 3]    # 推导为 [int]
```

**限制**: 当前实现中，数组大小必须在编译时确定

#### 元组 ✅
```python
let pair: (int, str) = (1, "one")
let triple = (1, 2.0, "three")
let coords = (10, 20, 30)

# 元组解包
let (x, y, z) = coords
let (a, b) = pair

# 元组索引
let first = pair[0]    # 1
let second = pair[1]   # "one"

# for循环中的元组解包
for (k, v) in dict_items(d):
    print(k)
    print(v)
```

#### 字典 ✅
```python
# 整数键值对
let ages: dict[str, int] = {"Alice": 30, "Bob": 25}
let scores = {1: 100, 2: 95, 3: 88}

# 字符串键值对
let config = {"host": "localhost", "port": "8080"}

# 混合类型
let data: dict[int, str] = {1: "one", 2: "two"}

# 字典操作
let age = ages["Alice"]         # 读取
ages["Charlie"] = 35            # 写入
let keys = dict_keys(ages)      # 获取所有键
let values = dict_values(ages)  # 获取所有值
let items = dict_items(ages)    # 获取键值对列表

# 字典迭代
for (k, v) in dict_items(ages):
    print(k)
    print(v)
```

### 函数类型
```python
def add(a: int, b: int) -> int:
    return a + b

# 类型: (int, int) -> int
```

### 类型推导

Dream 使用 Hindley-Milner 类型推导算法：

```python
# 自动推导变量类型
let x = 42              # x: int
let y = x + 10          # y: int
let z = [1, 2, 3]       # z: [int]

# 自动推导函数返回类型
def double(x: int):
    return x * 2        # 返回类型推导为 int
```

### 类型注解

#### 变量类型注解
```python
let name: str = "Alice"
let age: int = 30
let scores: [int] = [95, 87, 92]
```

#### 函数类型注解
```python
def greet(name: str) -> str:
    return "Hello, " + name

def calculate(a: int, b: int) -> int:
    return a + b
```

### 高级类型

#### Union 类型 ✅

Union 类型允许一个值拥有多个可能的类型：

```python
# 基本 Union 类型
let x: int | str = 42
let y: int | str = "hello"

# 函数参数 Union 类型
def process(v: int | bool) -> int:
    match v:
        42: return 10
        true: return 20
        _: return 0

print(process(42))      # 输出 10
print(process(true))    # 输出 20

# 函数返回值 Union 类型
def get_value(flag: int) -> int | str:
    if flag == 1:
        return 42
    else:
        return "hello"

let result = get_value(1)  # result: int | str
print(result)              # 输出 42

# Bytes 类型支持
def read_file(path: str) -> str | bytes:
    return file_read_bytes(path)

let content = read_file("data.bin")
match type of content:
    bytes:
        print("Binary file")
    str:
        print("Text file")
```

**特性**：
- 自动装箱：当类型注解为 Union 时自动装箱
- 自动拆箱：Match 表达式自动拆箱并类型检查
- 支持 print：union_print_value 自动识别类型并打印
- 完整的 GC 支持：自动内存管理
- **支持类型**：int, str, bool, bytes

#### 泛型 ✅

支持函数泛型，允许编写类型参数化的函数：

```python
# 基本泛型函数
def identity[T](x: T) -> T:
    return x

let a = identity(42)       # T = int
let b = identity("hello")  # T = str

# 泛型列表操作
def first[T](arr: [T]) -> T:
    return arr[0]

let num = first([1, 2, 3])      # T = int, 返回 1
let str = first(["a", "b"])     # T = str, 返回 "a"
```

**实现方式**：单态化（Monomorphization）
- 编译时为每个具体类型生成专门的函数版本
- 零运行时开销
- 与 Rust/C++ 类似

#### Option 和 Result 枚举类型 ✅

Option 和 Result 现在通过标准枚举类型实现，不再是内置关键字：

```python
# Option 类型 - 表示可能有值或没有值
enum Option:
    Some(int)   # 包含一个值
    Nothing     # 没有值（避免与 None 关键字冲突）

let some_value = Option.Some(42)
let no_value = Option.Nothing

match some_value:
    Option.Some(x):
        print(x)        # 输出 42
    Option.Nothing:
        print(-1)

# 带守卫条件的 Option 匹配
match some_value:
    Option.Some(x) if x > 10:
        print(100)      # x > 10 时执行
    Option.Some(x):
        print(10)       # 其他有值情况
    Option.Nothing:
        print(0)

# Result 类型 - 表示操作结果（成功或失败）
enum Result:
    Success(int)  # 成功，包含结果值
    Failure(int)  # 失败，包含错误码

let success_result = Result.Success(42)
let failure_result = Result.Failure(404)

match success_result:
    Result.Success(value):
        print(value)    # 输出 42
    Result.Failure(error):
        print(error)

# 带守卫条件的 Result 匹配
match failure_result:
    Result.Success(code) if code == 200:
        print(1)
    Result.Success(code):
        print(2)
    Result.Failure(code) if code >= 500:
        print(3)        # code >= 500 时执行
    Result.Failure(code):
        print(4)
```

**特性**：
- Option 和 Result 是普通枚举类型，没有特殊对待
- 完全支持模式匹配和守卫条件
- 可以定义自己的类似类型（如 `Maybe`、`Either` 等）
- 与 Rust 的 Option/Result 类似，但通过通用枚举机制实现

#### Match 表达式 ✅

模式匹配支持：

```python
# Match 表达式（可用于赋值或返回）
let result = match value:
    42: 10
    100: 20
    _: 0

# 正确：使用 return match 形式
def classify(x: int) -> str:
    return match x:
        0: "zero"
        1: "one"
        _: "other"

# 错误：不能在 match 表达式分支中使用 return
def wrong_classify(x: int) -> str:
    match x:
        0: return "zero"   # ❌ 编译错误
        1: return "one"    # ❌ 编译错误
        _: return "other"  # ❌ 编译错误

# Union 类型匹配
def process(v: int | str) -> int:
    return match v:
        42: 10
        "test": 20
        _: 0

# 类型模式匹配（match type of）
def handle_content(data: str | bytes) -> int:
    return match type of data:
        str: text.length()
        bytes: len(binary)

# 变量绑定模式
match x:
    n:
        print(n)  # n 绑定到 x 的值
```

**支持的模式**：
- 整数字面量：`42`, `100`
- 字符串字面量：`"test"`, `"hello"`
- 布尔值：`true`, `false`
- None：`none`
- 变量绑定：`n`, `x`
- 通配符：`_`
- 类型模式：`variable: type`（用于 Union 类型拆箱）

**重要限制**：
- Match 表达式分支不能包含 return 语句
- 正确形式：`return match ...` 或 `let x = match ...`
- 这确保 match 作为表达式的语义一致性

### 多态类型

#### 操作符多态
```python
# + 操作符支持整数和列表
let sum = 1 + 2                # int + int -> int
let combined = [1, 2] + [3, 4] # [int] + [int] -> [int]
```

### 接口系统 🚧

Dream 语言支持类似 Rust trait 和 Go interface 的接口系统，允许为类型定义和实现共同的行为。

#### 接口定义

```python
# 基本接口
interface Printable:
    def show() -> str

# 带泛型参数的接口
interface Container[T]:
    def size() -> int
    def get(index: int) -> T

    # 默认实现
    def is_empty() -> bool:
        return self.size() == 0

# 带关联类型和常量的接口
interface Collection[T]:
    type Item                 # 关联类型
    const MAX_SIZE: int = 100 # 关联常量

    def add(item: T) -> bool
    def remove(index: int) -> T
```

**接口成员**：
- 方法声明（必须实现）
- 方法默认实现（可选重写）
- 关联类型（`type Name`）
- 关联常量（`const NAME: type = value`）

#### 接口实现

##### 显式实现（impl 块）

使用 `impl` 关键字为类型实现接口：

```python
# 为枚举类型实现接口
enum Option[T]:
    Some(T)
    Nothing

impl Printable for Option[int]:
    def show() -> str:
        match self:
            Option.Some(x):
                return "Some(" + str(x) + ")"
            Option.Nothing:
                return "Nothing"

# 为内置类型实现接口（运算符重载）
interface Add[T]:
    def add(other: T) -> T

impl Add[int] for int:
    def add(other: int) -> int:
        return self + other

# 带泛型参数的实现
impl[T] Container[T] for [T]:
    def size() -> int:
        return len(self)

    def get(index: int) -> T:
        return self[index]
```

##### 隐式实现

Go 风格的隐式实现（编译时检查）：

```python
# 定义接口
interface Drawable:
    def draw() -> str

# 定义类型（无需显式声明实现接口）
enum Shape:
    Circle(int)
    Rectangle(int, int)

# 只要实现了所需方法，就隐式满足接口
def draw(self: Shape) -> str:
    match self:
        Shape.Circle(r):
            return "Circle"
        Shape.Rectangle(w, h):
            return "Rectangle"

# 接口约束的泛型函数
def render[T: Drawable](obj: T):
    print(obj.draw())

# 自动检查 Shape 是否实现了 Drawable
render(Shape.Circle(5))  # 编译时验证
```

#### 运算符重载

通过接口实现运算符重载：

```python
# 算术运算符
interface Add[T]:
    def add(other: T) -> T

interface Mul[T]:
    def mul(other: T) -> T

# 为自定义类型实现
enum Point:
    P(int, int)

impl Add[Point] for Point:
    def add(other: Point) -> Point:
        match self:
            Point.P(x1, y1):
                match other:
                    Point.P(x2, y2):
                        return Point.P(x1 + x2, y1 + y2)

# 使用
let p1 = Point.P(10, 20)
let p2 = Point.P(5, 15)
let p3 = p1.add(p2)  # Point.P(15, 35)
```

#### 接口约束

泛型函数可以添加接口约束：

```python
# 单个约束
def print_any[T: Printable](item: T):
    print(item.show())

# 多个约束
def compare_and_print[T: Comparable + Printable](a: T, b: T):
    if a.compare(b) > 0:
        print(a.show())
    else:
        print(b.show())
```

#### 关联类型示例

```python
interface Iterator:
    type Item

    def next() -> Option[Item]
    def has_next() -> bool

# 实现
enum Range:
    R(int, int, int)  # start, end, current

impl Iterator for Range:
    type Item = int

    def next() -> Option[int]:
        match self:
            Range.R(start, end, current):
                if current < end:
                    return Option.Some(current)
                return Option.Nothing

    def has_next() -> bool:
        match self:
            Range.R(start, end, current):
                return current < end
```

#### 接口继承

```python
# 接口可以要求实现其他接口
interface PrintableComparable[T]:
    implements Printable
    implements Comparable[T]

    def format() -> str:
        return self.show()
```

**实现状态**：
- ✅ AST 和语法解析完成
- ✅ 词法分析支持 `impl`, `type`, `const` 关键字
- ✅ 类型系统扩展（TyInterface 类型）
- ✅ 类型检查器接口验证
  - ✅ 接口定义验证（成员签名检查）
  - ✅ impl块完整性检查（必需方法检测）
  - ✅ impl块多余方法检测
  - ✅ 默认实现支持
  - ✅ 关联类型和常量验证
- ✅ LLVM 代码生成（静态分发）
  - ✅ impl块方法生成
  - ✅ 方法名重整（Interface_method_for_Type格式）
  - ✅ 程序级别impl块处理
- 🚧 动态方法调用（需要vtable，待实现）
- 🚧 隐式实现检查（Go风格duck typing，待实现）
- 🚧 运算符重载语法支持（待实现）
- 🚧 接口约束泛型函数（待实现）

**与其他语言对比**：

| 特性 | Dream | Rust | Go | Swift |
|------|-------|------|-------|-------|
| 显式实现 | ✅ `impl` | ✅ `impl` | ❌ | ✅ `extension` |
| 隐式实现 | ✅ | ❌ | ✅ | ❌ |
| 关联类型 | ✅ `type` | ✅ `type` | ❌ | ✅ `associatedtype` |
| 默认实现 | ✅ | ✅ | ❌ | ✅ |
| 运算符重载 | ✅ | ✅ | ❌ | ✅ |
| 内置类型扩展 | ✅ | ✅ | ❌ | ✅ |

## 语法结构

### 变量声明

#### let 语句
```python
let x = 42                  # 类型推导
let y: int = 100            # 显式类型
let name: str = "Alice"
let numbers = [1, 2, 3, 4, 5]
```

**类型不可变**: 一旦变量类型确定，不能改变其类型：
```python
let x = 42
x = 100      # ✅ OK - 相同类型
x = "hello"  # ❌ Error - 类型不匹配
```

### 赋值语句
```python
name = "Bob"           # 变量赋值
arr[0] = 100          # 数组元素赋值
```

### 函数定义

#### 基本函数
```python
def function_name(param1: type1, param2: type2) -> return_type:
    # 函数体
    return value
```

#### 示例
```python
def add(a: int, b: int) -> int:
    return a + b

def greet(name: str):
    print("Hello, " + name)

# 递归函数
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)
```

### 结构体 ✅

#### 结构体定义

```python
struct Point:
    x: int
    y: int

struct Rectangle:
    width: int
    height: int
```

#### 结构体字面量

```python
let p = Point{x: 10, y: 20}
let rect = Rectangle{width: 100, height: 50}
```

#### 字段访问

```python
print(p.x)      # 10
print(p.y)      # 20
```

#### 字段赋值

```python
p.x = 15
p.y = 25
```

#### 结构体方法 (Go 风格)

结构体可以在内部定义方法，支持 `self` 参数：

```python
struct Counter:
    value: int

    def get(self) -> int:
        return self.value

    def increment(self):
        self.value = self.value + 1

# 使用
let counter = Counter{value: 100}
let v = counter.get()      # 调用方法，返回 100
counter.increment()        # 修改字段
```

**特性**：
- 方法定义在 struct 内部 (类似 Go)
- 第一个参数名为 `self` 时自动推导为结构体类型
- `self.field` 访问结构体字段
- 方法调用使用点号语法 `obj.method()`
- 编译时方法名重整为 `StructName_methodname`
- 完整的类型检查和代码生成支持

### 控制流

#### if 语句
```python
if condition:
    # 代码块
elif another_condition:
    # 代码块
else:
    # 代码块
```

示例:
```python
def classify(x: int) -> str:
    if x > 0:
        return "positive"
    elif x < 0:
        return "negative"
    else:
        return "zero"
```

#### while 循环
```python
while condition:
    # 循环体
```

示例:
```python
def countdown(n: int):
    while n > 0:
        print(n)
        n = n - 1
```

#### for 循环
```python
for variable in iterable:
    # 循环体
```

示例:
```python
def sum_array(arr: [int]) -> int:
    let total = 0
    for x in arr:
        total = total + x
    return total
```

### 数组操作

#### 数组字面量
```python
let empty = []
let numbers = [1, 2, 3, 4, 5]
let mixed = [1, 2, 3]    # 所有元素必须同类型
```

#### 数组索引
```python
let arr = [10, 20, 30, 40, 50]
let first = arr[0]       # 10
let last = arr[4]        # 50
arr[1] = 25              # 修改元素
```

#### 数组切片
```python
let arr = [1, 2, 3, 4, 5]

let all = arr[:]         # [1, 2, 3, 4, 5] - 完整复制
let sub = arr[1:4]       # [2, 3, 4] - 索引 1 到 3
let head = arr[:3]       # [1, 2, 3] - 开头到索引 2
let tail = arr[2:]       # [3, 4, 5] - 索引 2 到结尾
```

**语义**:
- `arr[start:end]` - 包含 start，不包含 end
- 负索引暂不支持
- 越界访问行为未定义

#### 数组拼接
```python
let arr1 = [1, 2, 3]
let arr2 = [4, 5]
let combined = arr1 + arr2    # [1, 2, 3, 4, 5]
```

**要求**:
- 两个数组元素类型必须相同
- 生成新数组，不修改原数组

#### 列表推导式
```python
# 基本形式: [表达式 for 变量 in 可迭代对象]
let doubled = [x * 2 for x in numbers]

# 带条件过滤: [表达式 for 变量 in 可迭代对象 if 条件]
let evens = [x for x in numbers if x % 2 == 0]

# 复杂表达式
let squares = [x * x for x in range if x > 0]
```

**示例**:
```python
def main():
    let numbers = [1, 2, 3, 4, 5]

    # 映射: 每个元素乘以 2
    let doubled = [x * 2 for x in numbers]
    # [2, 4, 6, 8, 10]

    # 过滤: 只保留偶数
    let evens = [x for x in numbers if x % 2 == 0]
    # [2, 4]

    # 组合: 先过滤再转换
    let result = [x * 3 for x in numbers if x > 2]
    # [9, 12, 15]
```

**限制**:
- 结果数组的实际长度信息在表达式返回后丢失
- 分配的是最大可能大小的数组

### 字符串操作 ✅

#### 字符串索引
```python
let s: str = "Hello"
let char_code = s[0]  # 72 ('H' 的 ASCII 码)
let c2 = s[1]         # 101 ('e' 的 ASCII 码)
```

**说明**:
- 字符串索引返回整数类型 (ASCII 码)
- 支持运行时动态索引
- 越界访问行为未定义

#### 字符串切片
```python
let s: str = "World"

let sub1 = s[0:3]   # "Wor" - 索引 0 到 2
let sub2 = s[1:]    # "orld" - 索引 1 到结尾
let sub3 = s[:4]    # "Worl" - 开头到索引 3
let sub4 = s[:]     # "World" - 完整复制
```

**语义**:
- `str[start:end]` - 包含 start，不包含 end
- 负索引暂不支持
- 底层调用 `str_sub()` 运行时函数

#### 字符串分割和连接 ✅
```python
# 字符串分割
let text: str = "apple,banana,orange"
let parts = text.split(",")  # 返回字符串数组

# 字符串连接
let result = join(parts, " - ")  # "apple - banana - orange"
print(result)
```

**说明**:
- `split(delimiter)` - 按分隔符分割字符串，返回字符串数组
- `join(array, separator)` - 用分隔符连接字符串数组，返回字符串
- 底层使用 `%dynarray_ptr` 类型存储字符串数组
- 完整的 GC 支持

#### 字符级别方法 ✅
```python
let s: str = "A1 B2"

# 检查指定位置的字符类型
print(s.is_alpha(0))       # true (A 是字母)
print(s.is_digit(1))       # true (1 是数字)
print(s.is_whitespace(2))  # true (空格)
```

**说明**:
- `is_alpha(index)` - 检查指定位置字符是否为字母
- `is_digit(index)` - 检查指定位置字符是否为数字
- `is_whitespace(index)` - 检查指定位置字符是否为空白字符
- 所有方法返回布尔值

### 内置函数

#### print(value)
打印值到标准输出

```python
print(42)              # 打印整数
print("hello")         # 打印字符串
print(true)            # 打印布尔值（输出 "true"）
print(False)           # 打印布尔值（输出 "false"）

# Union 类型自动打印 ✅
let x: int | str = 42
print(x)               # 自动识别类型并打印 "42"
```

**限制**: 暂不支持打印数组、元组等复合类型（但支持 Union 类型）

#### len(array)
返回数组长度

```python
let arr = [1, 2, 3, 4, 5]
let length = len(arr)    # 5
```

**限制**: 只能用于局部数组变量，不能用于函数参数或表达式结果

## 类型检查规则

### 类型统一

类型检查器使用统一化算法确保类型一致：

```python
# ✅ OK - 类型匹配
let x: int = 42
let y = x + 10

# ❌ Error - 类型不匹配
let a: int = 42
let b: str = "hello"
let c = a + b          # Error: 不能将 int 和 str 相加
```

### 函数调用检查

```python
def add(a: int, b: int) -> int:
    return a + b

let result = add(10, 20)    # ✅ OK
let wrong = add("10", 20)   # ❌ Error: 参数类型不匹配
```

### 数组类型检查

```python
# ✅ OK - 元素类型一致
let numbers = [1, 2, 3, 4, 5]

# ❌ Error - 元素类型不一致
let mixed = [1, "two", 3]

# ✅ OK - 数组拼接类型匹配
let arr1 = [1, 2]
let arr2 = [3, 4]
let combined = arr1 + arr2

# ❌ Error - 数组拼接类型不匹配
let bad = [1, 2] + ["3", "4"]
```

## LLVM IR 代码生成

### 类型映射

| Dream 类型 | LLVM 类型 |
|-----------|----------|
| int       | i32      |
| bool      | i1       |
| float     | i32 (临时) |
| str       | i32* (指针) |
| [T]       | [n x T]  |

### 数组操作实现

#### 数组拼接
- 编译时展开为元素逐一复制的循环
- 分配新数组容纳两个数组的所有元素

#### 数组切片
- 运行时循环复制
- 分配最大可能大小的数组 (原数组大小)
- 支持动态计算的索引

#### 列表推导式
- 运行时循环
- 为每个变量生成唯一名称避免冲突
- 使用计数器跟踪实际填充的元素数量

## 编译流程

```
.dm 源文件
    ↓
词法分析 (Lexer)
    ↓
Token 流
    ↓
语法分析 (Parser)
    ↓
AST (抽象语法树)
    ↓
类型检查 (Type Checker)
    ↓
带类型的 AST
    ↓
LLVM IR 生成 (LLVM Generator)
    ↓
LLVM IR (.ll 文件)
    ↓
LLVM 编译 (clang)
    ↓
可执行文件
```

## 示例程序

### Hello World
```python
print("Hello, Dream!")
```

### 阶乘
```python
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

def main():
    let result = factorial(5)
    print(result)    # 输出: 120

main()
```

### 数组操作
```python
def main():
    let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    # 切片
    let first_half = numbers[:5]
    let second_half = numbers[5:]

    # 列表推导式
    let evens = [x for x in numbers if x % 2 == 0]
    let doubled = [x * 2 for x in numbers]

    # 拼接
    let combined = first_half + second_half

    # 组合使用
    let result = [x * 2 for x in numbers[:5] if x % 2 == 1]
    # result = [2, 6, 10]  即 [1, 3, 5] 的每个元素乘以 2

main()
```

### 排序算法
```python
def bubble_sort(arr: [int], n: int):
    let i = 0
    while i < n:
        let j = 0
        while j < n - i - 1:
            if arr[j] > arr[j + 1]:
                let temp = arr[j]
                arr[j] = arr[j + 1]
                arr[j + 1] = temp
            j = j + 1
        i = i + 1

def main():
    let numbers = [5, 2, 8, 1, 9]
    bubble_sort(numbers, 5)

    # 打印排序后的数组
    let i = 0
    while i < 5:
        print(numbers[i])
        i = i + 1

main()
```

## 限制和已知问题

### 当前限制

1. **数组大小限制**
   - 数组大小必须在编译时确定
   - 不支持真正的动态大小数组（但有 dynarray 运行时库）
   - 列表推导式和切片分配固定大小

2. **类型系统限制**
   - 函数参数默认推导为 int
   - 数组参数需要显式类型注解

3. **功能限制**
   - 暂不支持类和对象（已有语法但未实现代码生成）
   - 枚举类型（已有语法和类型检查，缺少代码生成）
   - Match 表达式（已有基础实现，缺少枚举精确匹配）
   - 暂不支持异常处理
   - 暂不支持模块导入

4. **内置函数限制**
   - `len()` 只能用于局部数组变量
   - `print()` 不支持打印数组、复合类型（但支持 Union）
   - 缺少常用的内置函数（map, filter, reduce 等）

### 性能考虑

1. **数组操作性能**
   - 切片和拼接涉及元素复制
   - 列表推导式可能分配过大的数组
   - 未进行写时复制优化

2. **编译优化**
   - 可通过 LLVM 优化 pass 改善性能
   - 建议使用 `-O2` 或 `-O3` 优化级别

## 未来规划

参见 [TODO.md](TODO.md) 了解详细的开发计划。

主要方向:
- 动态大小数组/列表
- 泛型系统
- 完整的面向对象支持
- 标准库
- 工具链 (REPL, LSP)
