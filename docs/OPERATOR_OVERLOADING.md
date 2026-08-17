# Dream 语言运算符重载设计

## 一、设计理念

Dream 的运算符重载采用**接口驱动**的方式，类似 Rust 的 trait 系统，既保证类型安全，又提供灵活性。

### 核心原则

1. **显式优于隐式**：必须通过 impl 实现接口才能重载运算符
2. **类型安全**：编译期检查运算符接口实现的正确性
3. **零开销抽象**：运算符调用直接编译为静态方法调用
4. **可扩展性**：支持为内置类型和自定义类型实现运算符

## 二、标准运算符接口

### 2.1 算术运算符接口

```python
# 加法运算符 +
interface Add[T]:
    def add(self, other: T) -> T

# 减法运算符 -
interface Sub[T]:
    def sub(self, other: T) -> T

# 乘法运算符 *
interface Mul[T]:
    def mul(self, other: T) -> T

# 除法运算符 /
interface Div[T]:
    def div(self, other: T) -> T

# 取模运算符 %
interface Mod[T]:
    def mod(self, other: T) -> T

# 负号运算符 -x
interface Neg:
    def neg(self) -> Self
```

### 2.2 比较运算符接口

```python
# 相等性比较
interface Eq[T]:
    def eq(self, other: T) -> bool

    # 默认实现
    def neq(self, other: T) -> bool:
        return not self.eq(other)

# 顺序比较（要求先实现 Eq）
interface Ord[T]:
    implements Eq[T]

    def lt(self, other: T) -> bool
    def gt(self, other: T) -> bool

    # 默认实现
    def lte(self, other: T) -> bool:
        return self.lt(other) or self.eq(other)

    def gte(self, other: T) -> bool:
        return self.gt(other) or self.eq(other)
```

### 2.3 逻辑运算符接口

```python
# 逻辑非 not
interface Not:
    def not_op(self) -> bool
```

### 2.4 索引运算符接口

```python
# 索引访问和赋值
interface Index[K, V]:
    def index_get(self, key: K) -> V
    def index_set(self, key: K, value: V)
```

### 2.5 运算符到方法的映射表

| 运算符表达式 | 脱糖后的方法调用 | 接口约束 |
|------------|----------------|---------|
| `a + b` | `a.add(b)` | `Add[T]` |
| `a - b` | `a.sub(b)` | `Sub[T]` |
| `a * b` | `a.mul(b)` | `Mul[T]` |
| `a / b` | `a.div(b)` | `Div[T]` |
| `a % b` | `a.mod(b)` | `Mod[T]` |
| `-a` | `a.neg()` | `Neg` |
| `a == b` | `a.eq(b)` | `Eq[T]` |
| `a != b` | `a.neq(b)` | `Eq[T]` |
| `a < b` | `a.lt(b)` | `Ord[T]` |
| `a > b` | `a.gt(b)` | `Ord[T]` |
| `a <= b` | `a.lte(b)` | `Ord[T]` |
| `a >= b` | `a.gte(b)` | `Ord[T]` |
| `not a` | `a.not_op()` | `Not` |
| `a[k]` | `a.index_get(k)` | `Index[K,V]` |
| `a[k] = v` | `a.index_set(k, v)` | `Index[K,V]` |

## 三、实现示例

### 3.1 为自定义结构体实现运算符

#### 示例：二维向量类型

```python
struct Vec2:
    x: int
    y: int

# 实现加法运算符
impl Add[Vec2] for Vec2:
    def add(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x + other.x, y: self.y + other.y}

# 实现减法运算符
impl Sub[Vec2] for Vec2:
    def sub(self, other: Vec2) -> Vec2:
        return Vec2{x: self.x - other.x, y: self.y - other.y}

# 实现标量乘法
impl Mul[int] for Vec2:
    def mul(self, scalar: int) -> Vec2:
        return Vec2{x: self.x * scalar, y: self.y * scalar}

# 实现相等性比较
impl Eq[Vec2] for Vec2:
    def eq(self, other: Vec2) -> bool:
        return self.x == other.x and self.y == other.y

# 使用示例
def main():
    let v1 = Vec2{x: 10, y: 20}
    let v2 = Vec2{x: 5, y: 15}

    # 运算符自动调用接口方法
    let v3 = v1 + v2      # 等价于 v1.add(v2)
    let v4 = v1 - v2      # 等价于 v1.sub(v2)
    let v5 = v1 * 3       # 等价于 v1.mul(3)

    if v1 == v2:          # 等价于 v1.eq(v2)
        print("Equal")
```

### 3.2 为枚举类型实现运算符

```python
enum Option[T]:
    Some(T)
    Nothing

# 为 Option[int] 实现加法（将两个 Some 值相加）
impl Add[Option[int]] for Option[int]:
    def add(self, other: Option[int]) -> Option[int]:
        return match self:
            Option.Some(a):
                match other:
                    Option.Some(b):
                        Option.Some(a + b)
                    Option.Nothing:
                        Option.Nothing
            Option.Nothing:
                Option.Nothing

# 使用示例
def main():
    let opt1 = Option.Some(10)
    let opt2 = Option.Some(20)
    let result = opt1 + opt2    # Option.Some(30)
```

### 3.3 为内置类型扩展运算符

```python
# 为字符串实现乘法（重复字符串）
impl Mul[int] for str:
    def mul(self, n: int) -> str:
        let result = StrBuffer()
        let i = 0
        while i < n:
            result.append(self)
            i = i + 1
        return result.to_str()

# 使用示例
let repeated = "abc" * 3    # "abcabcabc"
```

### 3.4 多态运算符（不同类型间的运算）

```python
struct Matrix:
    data: [int]
    rows: int
    cols: int

# 矩阵与标量相乘
impl Mul[int] for Matrix:
    def mul(self, scalar: int) -> Matrix:
        let new_data = [x * scalar for x in self.data]
        return Matrix{data: new_data, rows: self.rows, cols: self.cols}

# 矩阵与矩阵相乘（需要不同的类型参数）
impl Mul[Matrix] for Matrix:
    def mul(self, other: Matrix) -> Matrix:
        # 矩阵乘法实现
        ...
```

## 四、实现细节

### 4.1 编译器流程

#### 步骤 1：类型检查阶段（lib/typeck/tc_expr.ml）

当遇到二元运算符表达式 `a + b` 时：

1. **检查是否为内置类型的运算**
   - 如果 a 和 b 都是 int，直接允许（内置支持）
   - 如果 a 和 b 都是 str，检查是否为字符串拼接（内置支持）
   - 如果 a 和 b 都是 list，检查是否为列表拼接（内置支持）

2. **检查接口实现**
   - 查找类型 a 是否实现了 `Add[typeof(b)]` 接口
   - 验证方法签名是否匹配
   - 记录需要调用的方法名（例如 `Vec2_add_for_Vec2`）

3. **类型推导**
   - 返回类型为接口方法的返回类型

#### 步骤 2：DIR lowering 阶段（lib/ir/dir/dir_lower.ml）

1. **运算符脱糖**
   - `a + b` → `a.add(b)`

2. **方法名重整**
   - 根据 impl 块生成的方法名：`TypeName_methodname_for_TargetType`
   - 例如：`Vec2_add_for_Vec2`

3. **生成 LLVM IR**
   ```llvm
   ; a + b 生成为
   %result = call %Vec2 @Vec2_add_for_Vec2(%Vec2* %a, %Vec2 %b)
   ```

### 4.2 impl 块方法名生成规则

格式：`{InterfaceName}_{method}_for_{TargetType}`

示例：
```python
impl Add[Vec2] for Vec2:
    def add(self, other: Vec2) -> Vec2:
        ...
```

生成的 LLVM 函数名：
```llvm
define %Vec2 @Add_add_for_Vec2(%Vec2* %self, %Vec2 %other) {
    ...
}
```

### 4.3 运算符查找优先级

1. **内置运算符**（优先级最高）
   - int + int → 内置整数加法
   - str + str → 内置字符串拼接
   - [T] + [T] → 内置列表拼接

2. **接口实现的运算符**
   - 查找对应的 impl 块
   - 生成方法调用

3. **编译错误**（未找到实现）
   - 报错：类型 T 未实现 Add[U] 接口

### 4.4 类型检查器修改点

#### 文件：lib/typeck/tc_expr.ml

在 `check_expr` 函数中的 `EBinOp` 分支：

```ocaml
| EBinOp (left, op, right, pos) ->
    let (left_ty, left_subst) = check_expr env left subst in
    let (right_ty, right_subst) = check_expr env right left_subst in

    (* 先检查内置运算符 *)
    match (left_ty, op, right_ty) with
    | (TyInt, Add, TyInt)
    | (TyInt, Sub, TyInt)
    | (TyInt, Mul, TyInt)
    | (TyInt, Div, TyInt)
    | (TyInt, Mod, TyInt) ->
        (TyInt, right_subst)

    | (TyList t1, Add, TyList t2) ->
        let unify_subst = unify t1 t2 in
        (TyList t1, compose_subst unify_subst right_subst)

    (* 检查接口实现 *)
    | _ ->
        let interface_name = binop_to_interface op in
        match lookup_impl env left_ty interface_name right_ty with
        | Some method_info ->
            (method_info.return_type, right_subst)
        | None ->
            report_error (make_error
              (TypeError "Operator not implemented") pos
              (Printf.sprintf "Type %s does not implement %s[%s]"
                (ty_to_string left_ty)
                interface_name
                (ty_to_string right_ty)));
            (TyUnknown, right_subst)
```

辅助函数：
```ocaml
let binop_to_interface = function
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Mod -> "Mod"
  | Eq -> "Eq"
  | Neq -> "Eq"
  | Lt -> "Ord"
  | Gt -> "Ord"
  | Lte -> "Ord"
  | Gte -> "Ord"
  | And | Or -> failwith "And/Or are not overloadable"
```

#### 文件：lib/env.ml

添加接口实现查找函数：

```ocaml
(* 查找类型是否实现了某个接口 *)
let lookup_impl env target_type interface_name param_type =
  (* 在环境中查找 impl 块信息 *)
  (* 返回 Some method_info 或 None *)
  ...
```

### 4.5 代码生成器修改点

#### 文件：lib/ir/dir/dir_lower.ml

```ocaml
| EBinOp (left, op, right, pos) ->
    (* 检查是否使用了接口实现 *)
    match get_impl_method_for_binop env left_ty op right_ty with
    | Some method_name ->
        (* 生成方法调用 *)
        let left_val = codegen_expr ctx env left in
        let right_val = codegen_expr ctx env right in
        L.build_call method_func [| left_val; right_val |] "op_result" builder

    | None ->
        (* 使用内置运算符 *)
        codegen_builtin_binop ctx left op right
```

## 五、标准库实现

### 5.1 内置类型的运算符实现

Dream 的内置类型默认实现常用运算符接口：

```python
# 在标准库预定义文件中 (stdlib/operators.dm)

# int 实现算术运算符（编译器内置）
impl Add[int] for int:
    def add(self, other: int) -> int:
        builtin_int_add(self, other)

impl Sub[int] for int:
    def sub(self, other: int) -> int:
        builtin_int_sub(self, other)

# ... 其他运算符

# str 实现加法（拼接）
impl Add[str] for str:
    def add(self, other: str) -> str:
        builtin_str_concat(self, other)

# list 实现加法（拼接）
impl[T] Add[[T]] for [T]:
    def add(self, other: [T]) -> [T]:
        builtin_list_concat(self, other)
```

### 5.2 通用泛型实现

```python
# 为所有实现 Ord 的类型提供 max 函数
def max[T: Ord[T]](a: T, b: T) -> T:
    return a > b ? a : b

# 为所有实现 Add 的类型提供求和函数
def sum[T: Add[T]](items: [T], zero: T) -> T:
    let result = zero
    for item in items:
        result = result + item
    return result
```

## 六、限制和注意事项

### 6.1 当前限制

1. **逻辑运算符 and/or 不可重载**
   - 原因：需要短路求值语义
   - 解决方案：保持内置实现

2. **赋值运算符不可重载**
   - `=` 运算符保持语言内置语义
   - 复合赋值运算符（如 `+=`）暂不支持

3. **优先级固定**
   - 运算符优先级由语言规定，不可自定义

### 6.2 最佳实践

1. **保持语义一致性**
   ```python
   # 好的实践：+ 用于加法/拼接/组合
   impl Add[Vec2] for Vec2:
       def add(self, other: Vec2) -> Vec2:
           # 向量加法

   # 不好的实践：+ 用于完全无关的操作
   impl Add[User] for User:
       def add(self, other: User) -> bool:
           # 比较两个用户是否相同 ❌
   ```

2. **实现相关接口**
   ```python
   # 如果实现了 Eq，通常也应该实现 Ord
   impl Eq[Point] for Point:
       ...

   impl Ord[Point] for Point:
       ...
   ```

3. **遵循数学规则**
   ```python
   # 如果实现 Add，应该满足：
   # - 结合律：(a + b) + c == a + (b + c)
   # - 如果有单位元：a + zero == a
   ```

## 七、实现计划

### 阶段 1：基础设施（当前阶段）

- [x] AST 支持 impl 块
- [x] 接口定义和验证
- [ ] 运算符到接口的映射表
- [ ] 类型检查器支持接口查找

### 阶段 2：核心实现

- [ ] 在 tc_expr.ml 中实现运算符重载检查
- [ ] 在 env.ml 中实现 impl 查找
- [ ] 在 dir_lower.ml 中实现运算符脱糖
- [ ] 测试基本的自定义类型运算符

### 阶段 3：标准库支持

- [ ] 为内置类型添加接口实现声明
- [ ] 实现泛型约束语法（`T: Add[T]`）
- [ ] 编写标准运算符接口文档
- [ ] 添加完整的测试用例

### 阶段 4：高级特性

- [ ] 支持复合赋值运算符（`+=`, `-=` 等）
- [ ] 支持自定义索引运算符
- [ ] 支持链式比较（`a < b < c`）
- [ ] 性能优化（内联小方法）

## 八、示例和测试

### 测试文件：test/test_operator_overload.dm

```python
struct Complex:
    real: int
    imag: int

impl Add[Complex] for Complex:
    def add(self, other: Complex) -> Complex:
        return Complex{
            real: self.real + other.real,
            imag: self.imag + other.imag
        }

impl Mul[Complex] for Complex:
    def mul(self, other: Complex) -> Complex:
        return Complex{
            real: self.real * other.real - self.imag * other.imag,
            imag: self.real * other.imag + self.imag * other.real
        }

impl Eq[Complex] for Complex:
    def eq(self, other: Complex) -> bool:
        return self.real == other.real and self.imag == other.imag

def main():
    let c1 = Complex{real: 3, imag: 4}
    let c2 = Complex{real: 1, imag: 2}

    let c3 = c1 + c2
    print(c3.real)   # 4
    print(c3.imag)   # 6

    let c4 = c1 * c2
    print(c4.real)   # -5
    print(c4.imag)   # 10

    if c1 == c2:
        print("Equal")
    else:
        print("Not equal")  # 输出这个

main()
```

## 九、参考资料

### 其他语言的运算符重载对比

| 语言 | 方式 | 语法 |
|------|------|------|
| Rust | Trait | `impl Add for T { fn add(...) }` |
| C++ | 成员/友元函数 | `T operator+(const T& other)` |
| Python | 魔术方法 | `def __add__(self, other)` |
| Swift | Protocol | `extension T: Add { func +(...) }` |
| Haskell | Type class | `instance Num T where (+) = ...` |
| Dream | Interface | `impl Add[T] for T { def add(...) }` |

### Dream 的设计选择

- **显式接口**：像 Rust/Swift，避免 Python 的魔术方法带来的隐式性
- **静态分发**：零运行时开销，像 Rust
- **默认方法**：支持接口默认实现，减少样板代码
- **类型安全**：编译期检查所有运算符使用

---

**版本**：v0.1
**更新时间**：2025-10-17
**状态**：设计中 🚧
