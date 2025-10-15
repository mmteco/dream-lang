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
let def class interface implements
if else elif match case for while return
import from as async await
None self super in
and or not
```

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

#### string - 字符串类型
```python
let name = "Alice"      # 类型推导为 string
let msg: string = "Hi"  # 显式类型注解
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

#### 元组 (未完全实现)
```python
let pair: (int, string) = (1, "one")
let triple = (1, 2.0, "three")
```

#### 字典 (未完全实现)
```python
let ages: {string: int} = {"Alice": 30, "Bob": 25}
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
let name: string = "Alice"
let age: int = 30
let scores: [int] = [95, 87, 92]
```

#### 函数类型注解
```python
def greet(name: string) -> string:
    return "Hello, " + name

def calculate(a: int, b: int) -> int:
    return a + b
```

### 多态类型

#### 操作符多态
```python
# + 操作符支持整数和列表
let sum = 1 + 2                # int + int -> int
let combined = [1, 2] + [3, 4] # [int] + [int] -> [int]
```

## 语法结构

### 变量声明

#### let 语句
```python
let x = 42                  # 类型推导
let y: int = 100            # 显式类型
let name: string = "Alice"
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

def greet(name: string):
    print("Hello, " + name)

# 递归函数
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)
```

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
def classify(x: int) -> string:
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

### 内置函数

#### print(value)
打印值到标准输出

```python
print(42)              # 打印整数
print("hello")         # 打印字符串
```

**限制**: 暂不支持打印数组、元组等复合类型

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
let b: string = "hello"
let c = a + b          # Error: 不能将 int 和 string 相加
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
| string    | i32* (指针) |
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
   - 不支持真正的动态大小数组
   - 列表推导式和切片分配固定大小

2. **类型系统限制**
   - 函数参数默认推导为 int
   - 数组参数需要显式类型注解
   - 暂不支持泛型

3. **功能限制**
   - 暂不支持字典、元组
   - 暂不支持类和对象
   - 暂不支持模式匹配
   - 暂不支持异常处理
   - 暂不支持模块导入

4. **内置函数限制**
   - `len()` 只能用于局部数组变量
   - `print()` 不支持复合类型
   - 缺少常用的内置函数

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
