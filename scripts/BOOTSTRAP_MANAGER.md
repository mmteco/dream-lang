# Bootstrap 版本管理流程

## 概述

Bootstrap 版本管理系统用于跟踪 Dream 编译器的自举历史。

**重要**：OCaml 编译器（stage0）已冻结，后续开发只修改 Dream 源代码（`bootstrap/*.dm`）。

## 架构

```
OCaml 编译器 (stage0) [已冻结]
    ↓ 编译
Dream 源代码 (bootstrap/*.dm)
    ↓ 生成
Stage1 (Dream 编译器，由 OCaml 编译)
    ↓ 自举编译
Stage2 (Dream 编译器，由 Dream 编译)
    ↓ 保存
~/.dream/versions/dream_<version>
```

## 工作流程

### 1. 初始 Bootstrap

OCaml 编译器编译 Dream 源代码生成 stage1，stage1 自举编译生成 stage2。

```fish
fish scripts/bootstrap_manager.fish bootstrap
```

### 2. 保存工作版本

Bootstrap 成功后自动保存 stage2 到 `~/.dream/versions/`：

```fish
# 自动保存（时间戳命名）
fish scripts/bootstrap_manager.fish bootstrap

# 手动保存（语义化命名）
fish scripts/bootstrap_manager.fish save v1.0
fish scripts/bootstrap_manager.fish save before-closures
```

### 3. 添加新特性

只修改 Dream 源代码，不修改 OCaml：

```fish
# 1. 保存当前版本
fish scripts/bootstrap_manager.fish save before-new-feature

# 2. 修改 Dream 编译器源代码
vim bootstrap/compiler_lower.dm

# 3. 运行 bootstrap 验证
fish scripts/bootstrap_manager.fish bootstrap

# 4. 如果成功，保存新版本
fish scripts/bootstrap_manager.fish save with-new-feature
```

### 4. 使用历史版本

```fish
# 查看可用版本
fish scripts/bootstrap_manager.fish list

# 切换到指定版本
fish scripts/bootstrap_manager.fish use v1.0

# 使用当前版本编译
fish scripts/bootstrap_manager.fish compile test/example.dm
```

## 命令参考

### `save <version>`
保存当前 stage2 为指定版本
```fish
fish scripts/bootstrap_manager.fish save v1.0
```

### `use <version>`
切换到指定版本作为当前 stage2
```fish
fish scripts/bootstrap_manager.fish use v1.0
```

### `list`
列出所有保存的版本
```fish
fish scripts/bootstrap_manager.fish list
```

### `current`
显示当前使用的版本
```fish
fish scripts/bootstrap_manager.fish current
```

### `bootstrap`
运行完整 bootstrap 并自动保存
```fish
fish scripts/bootstrap_manager.fish bootstrap
```

### `compile <input>`
使用当前 stage2 编译文件
```fish
fish scripts/bootstrap_manager.fish compile test/example.dm
```

## 版本命名建议

- **时间戳**：`20260821_074713`（自动生成）
- **语义版本**：`v1.0`, `v1.1`, `v2.0`
- **特性标记**：`before-closures`, `with-generics`, `stable`

## 保存位置

- **历史版本**：`~/.dream/versions/dream_<version>`
- **当前链接**：`~/.dream/bin/dream` → 指向当前版本

历史版本保存在 `~/.dream/versions/` 目录。

## 回滚流程

如果新版本出现问题：

```fish
# 查看历史版本
fish scripts/bootstrap_manager.fish list

# 切换到稳定版本
fish scripts/bootstrap_manager.fish use v1.0

# 重新编译
fish scripts/bootstrap_manager.fish compile bootstrap/compiler.dm
```

## 注意事项

1. **OCaml 已冻结**：不再修改 OCaml 编译器代码
2. **只改 Dream**：所有新特性在 `bootstrap/*.dm` 中实现
3. **自举验证**：修改后必须运行 bootstrap 验证
4. **增量升级**：每次只添加少量特性，便于定位问题
5. **备份重要版本**：关键版本手动标记保存

## 示例：添加闭包捕获

```fish
# 1. 保存当前稳定版本
fish scripts/bootstrap_manager.fish save before-closures

# 2. 在 Dream 编译器中实现闭包捕获
vim bootstrap/compiler_lower.dm

# 3. 运行 bootstrap 验证
fish scripts/bootstrap_manager.fish bootstrap

# 4. 如果成功，保存新版本
fish scripts/bootstrap_manager.fish save with-closures
```
