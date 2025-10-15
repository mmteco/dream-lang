#!/bin/bash

echo "=== Dream 编程语言 - 环境设置 ==="
echo ""

# 检查 OPAM 是否安装
if ! command -v opam &> /dev/null; then
    echo "❌ OPAM 未安装"
    echo ""
    echo "请先安装 OPAM:"
    echo ""
    echo "macOS:"
    echo "  brew install opam"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  sudo apt install opam"
    echo ""
    exit 1
fi

echo "✅ OPAM 已安装"

# 初始化 OPAM (如果还没初始化)
if [ ! -d "$HOME/.opam" ]; then
    echo "正在初始化 OPAM..."
    opam init -y
    eval $(opam env)
fi

echo "✅ OPAM 已初始化"

# 安装依赖包
echo "正在安装依赖包..."
opam install -y dune menhir ocamlformat ocaml-lsp-server

if [ $? -eq 0 ]; then
    echo "✅ 依赖包安装成功"
else
    echo "❌ 依赖包安装失败"
    exit 1
fi

# 构建编译器
echo ""
echo "正在构建 Dream 编译器..."
dune build

if [ $? -eq 0 ]; then
    echo "✅ Dream 编译器构建成功"
else
    echo "❌ Dream 编译器构建失败"
    exit 1
fi

echo ""
echo "=== 设置完成! ==="
echo ""
echo "你现在可以使用 Dream 编译器:"
echo ""
echo "  dune exec dream examples/hello.dm"
echo ""
echo "或者安装到系统:"
echo ""
echo "  dune install"
echo "  dream examples/hello.dm"
echo ""
