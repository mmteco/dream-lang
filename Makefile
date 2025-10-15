.PHONY: build clean run test examples help

# 默认目标
help:
	@echo "Dream 语言编译器 - 可用命令:"
	@echo ""
	@echo "  make build       - 构建编译器"
	@echo "  make clean       - 清理构建产物"
	@echo "  make test        - 运行所有示例测试"
	@echo "  make examples    - 编译所有示例程序"
	@echo "  make runtime     - 构建运行时库"
	@echo "  make hello       - 编译并运行 hello.dm"
	@echo "  make factorial   - 编译并运行 factorial.dm"
	@echo "  make quicksort   - 编译并运行 quicksort.dm"
	@echo "  make dynarray    - 编译并运行 dynarray_full.dm"
	@echo ""

# 构建编译器
build:
	dune build

# 清理所有构建产物
clean:
	dune clean
	rm -f examples/*.ll examples/hello examples/factorial examples/quicksort examples/dynarray_full
	cd runtime && make clean

# 构建运行时库
runtime:
	cd runtime && make

# 编译所有示例程序
examples: build
	@echo "编译示例程序..."
	@_build/default/bin/main.exe examples/hello.dm
	@_build/default/bin/main.exe examples/factorial.dm
	@_build/default/bin/main.exe examples/quicksort.dm
	@_build/default/bin/main.exe examples/dynarray_full.dm

# 运行所有示例测试
test: examples
	@echo "\n=== 测试 hello.dm ==="
	@./examples/hello
	@echo "\n=== 测试 factorial.dm ==="
	@./examples/factorial
	@echo "\n=== 测试 quicksort.dm ==="
	@./examples/quicksort
	@echo "\n=== 测试 dynarray_full.dm ==="
	@./examples/dynarray_full

# 单独运行各个示例
hello: build
	_build/default/bin/main.exe examples/hello.dm && ./examples/hello

factorial: build
	_build/default/bin/main.exe examples/factorial.dm && ./examples/factorial

quicksort: build
	_build/default/bin/main.exe examples/quicksort.dm && ./examples/quicksort

dynarray: build
	_build/default/bin/main.exe examples/dynarray_full.dm && ./examples/dynarray_full

# 编译自定义文件 (使用方法: make compile FILE=path/to/file.dm)
compile: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make compile FILE=examples/hello.dm"; \
		exit 1; \
	fi
	_build/default/bin/main.exe $(FILE)

# 编译并运行自定义文件 (使用方法: make run FILE=path/to/file.dm)
run: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make run FILE=examples/hello.dm"; \
		exit 1; \
	fi
	_build/default/bin/main.exe $(FILE) && ./$(basename $(FILE))
