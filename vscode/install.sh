#!/bin/bash

# Dream Language VSCode Extension 安装脚本

set -e

EXTENSION_NAME="dream-language"
VSCODE_EXT_DIR="$HOME/.vscode/extensions"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Dream Language VSCode Extension 安装程序 ==="
echo ""

# 检查 VSCode 扩展目录是否存在
if [ ! -d "$VSCODE_EXT_DIR" ]; then
    echo "错误: VSCode 扩展目录不存在: $VSCODE_EXT_DIR"
    echo "请确保已安装 VSCode"
    exit 1
fi

# 删除旧版本（如果存在）
if [ -d "$VSCODE_EXT_DIR/$EXTENSION_NAME" ] || [ -L "$VSCODE_EXT_DIR/$EXTENSION_NAME" ]; then
    echo "发现旧版本，正在删除..."
    rm -rf "$VSCODE_EXT_DIR/$EXTENSION_NAME"
fi

# 询问安装方式
echo "请选择安装方式:"
echo "  1) 复制文件（推荐）"
echo "  2) 符号链接（开发模式）"
echo ""
read -p "请输入选项 [1/2]: " choice

case $choice in
    1)
        echo ""
        echo "正在复制文件..."
        cp -r "$SOURCE_DIR" "$VSCODE_EXT_DIR/$EXTENSION_NAME"
        echo "✓ 安装完成！"
        ;;
    2)
        echo ""
        echo "正在创建符号链接..."
        ln -s "$SOURCE_DIR" "$VSCODE_EXT_DIR/$EXTENSION_NAME"
        echo "✓ 符号链接创建完成！"
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

echo ""
echo "=== 安装成功 ==="
echo ""
echo "下一步: 重启 VSCode 或运行命令 'Developer: Reload Window'"
echo ""
echo "使用方法:"
echo "  - 打开 .dm 文件即可看到语法高亮"
echo "  - F12: 跳转到定义"
echo "  - Shift+F12: 查找所有引用"
echo ""
