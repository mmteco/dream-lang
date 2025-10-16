# Dream Language - VSCode Extension

VSCode 扩展，为 Dream 编程语言提供语法高亮和 LSP 支持。

## 功能特性

- **语法高亮** - 完整的 Dream 语法着色
- **Go to Definition** (F12) - 跳转到符号定义
- **Find All References** (Shift+F12) - 查找所有引用
- **Rename Symbol** (F2) - 重命名符号（变量、函数等）
- **括号匹配** - 自动匹配和高亮显示括号
- **自动补全括号和引号** - 输入时自动闭合
- **注释支持** - 使用 `#` 进行单行注释
- **代码折叠** - 基于缩进的代码折叠

## 快速安装

```bash
# 从 Dream 项目根目录执行
cd /path/to/dream
dune build              # 编译 Dream 编译器
./vscode/install.sh     # 安装 VSCode 扩展
```

然后重启 VSCode，打开任何 `.dm` 文件即可。

## 使用说明

### Go to Definition (跳转到定义)

1. 将光标放在变量、函数或类型名上
2. 按 **F12** 或右键选择 "Go to Definition"
3. 会跳转到该符号的定义位置

**支持的符号：**
- 变量、函数、结构体、接口、枚举
- 字段、方法、参数

### Find All References (查找所有引用)

1. 将光标放在符号上
2. 按 **Shift+F12** 或右键选择 "Find All References"
3. 侧边栏会显示所有使用该符号的位置

### Rename Symbol (重命名符号)

1. 将光标放在要重命名的符号上（变量、函数等）
2. 按 **F2** 或右键选择 "Rename Symbol"
3. 输入新名称，按 Enter
4. 所有定义和引用都会自动更新

**支持的符号：**
- 变量、函数、参数
- 结构体、接口、枚举及其成员

**示例：**
```dream
let oldName = 10
let y = oldName + 5  # 光标放在 oldName 上，按 F2 重命名为 newName
let z = oldName * 2  # 所有出现的地方都会自动更新
```

### 示例

```dream
let x = 10

def add(a: int, b: int) -> int:
    return a + b

struct Point:
    x: int
    y: int

let result = add(x, 5)    # 在 add 上按 F12 → 跳到函数定义
let p = Point{x: 1, y: 2} # 在 Point 上按 Shift+F12 → 显示所有引用
```

## 技术实现

扩展通过调用 Dream 编译器的 `dream lsp` 命令实现语言功能：

```
VSCode Extension (JavaScript)
    ↓ execSync
dream lsp file.dm
    ↓
Lexer → Parser → AST → Symbol Analyzer
    ↓
JSON (definitions + references)
    ↓
VSCode 显示
```

扩展会自动查找 Dream 编译器：
- 优先使用项目根目录的 `_build/default/bin/main.exe`（开发模式）
- 其次使用系统 PATH 中的 `dream` 命令（已安装）

## 故障排查

### Go to Definition 不工作

1. 确保 Dream 编译器已编译：
   ```bash
   cd /path/to/dream
   dune build
   ```

2. 测试 lsp 命令是否正常：
   ```bash
   _build/default/bin/main.exe lsp test/test_lsp.dm
   ```

3. 保存文件后再测试（扩展在保存时更新符号）

### 扩展未激活

- 检查文件扩展名是否为 `.dm`
- 查看 VSCode 右下角语言模式是否显示 "Dream"
- 重新运行 `./vscode/install.sh` 并重启 VSCode

### 符号位置不准确

这是已知限制。Parser 尚未完全实现精确的位置跟踪，某些定义可能显示在行首。

## 其他安装方式

### 手动复制

```bash
# macOS/Linux
cp -r vscode ~/.vscode/extensions/dream-language

# Windows
xcopy vscode %USERPROFILE%\.vscode\extensions\dream-language /E /I
```

### 开发模式（符号链接）

```bash
# macOS/Linux
ln -s /path/to/dream/vscode ~/.vscode/extensions/dream-language
```

### 打包安装

```bash
cd vscode
npm install -g @vscode/vsce
vsce package
# 然后在 VSCode 中安装生成的 .vsix 文件
```

## 支持的语法

### 关键字
`if`, `else`, `elif`, `while`, `for`, `in`, `match`, `case`, `return`, `let`, `def`, `struct`, `interface`, `impl`, `enum`, `and`, `or`, `not`, `self`, `super`

### 类型
`int`, `float`, `str`, `bool`, `bytes`, `list`, `dict`, `tuple`, `Option`, `Some`, `Result`, `Ok`, `Err`, `None`

### 运算符
`+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `->`, `=>`, `|`

## 已知限制

1. **单文件支持** - 目前仅支持单文件内的符号分析
2. **性能** - 每次保存都需要重新解析整个文件（重命名等操作需要先保存）

## 未来改进

- [ ] 跨文件支持（import/module 解析）
- [ ] Hover 提示（显示类型信息）
- [ ] 代码补全（智能提示）
- [ ] 实时错误诊断
- [ ] 增量解析优化

## 问题反馈

如有问题或建议，请在项目仓库提交 Issue。
