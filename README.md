# Dream 编程语言

Dream 是一门语法类似Python，包含丰富的类型，支持模式匹配的现代编译型语言。

## 特性

- **Python 风格语法** - 缩进敏感，简洁易读
- **静态类型系统** - 类型推导
- **LLVM 后端** - 编译为高性能机器码

- [项目总览](docs/overview.md)

## OCaml 正式编译器的流程

```plain
.dm 源码
  ↓
Lexer.tokenize_string_with_pos
  ↓
Parser.program
  ↓
AST
  ↓
Typeck.typecheck
  ↓
类型检查后的 AST
  ↓
Monomorphize.monomorphize
  ↓
泛型单态化 AST
  ↓
Dir_lower.lower_program
  ↓
结构化 DreamIR
  ↓
Dir_verify.verify
  ↓
Dir_lower_llvm.render
  ↓
LLVM IR 文本
  ↓
Clang + runtime
  ↓
可执行文件
```

## 许可证

MIT License
