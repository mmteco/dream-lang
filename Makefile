.PHONY: build clean run test examples runtime-check check bootstrap bootstrap-verify help

# 默认目标
help:
	@echo "Dream 语言编译器 - 可用命令:"
	@echo ""
	@echo "  make build       - 构建编译器"
	@echo "  make clean       - 清理构建产物"
	@echo "  make test        - 运行所有示例测试"
	@echo "  make examples    - 编译所有示例程序"
	@echo "  make runtime     - 构建运行时库"
	@echo "  make runtime-check - 运行 runtime 常规测试和 UBSan 测试"
	@echo "  make check       - 运行完整构建、测试和自举验证"
	@echo "  make hello       - 编译并运行 hello.dm"
	@echo "  make factorial   - 编译并运行 factorial.dm"
	@echo "  make quicksort   - 编译并运行 quicksort.dm"
	@echo "  make dynarray    - 编译并运行 dynarray_full.dm"
	@echo "  make bootstrap   - 执行 Stage 0 → Stage 1 自举切片"
	@echo "  make bootstrap-verify - 验证已生成的自举 LLVM 文件"
	@echo ""

# 构建编译器
build:
	dune build

# 清理所有构建产物
clean:
	dune clean
	rm -f examples/*.ll examples/hello examples/factorial examples/quicksort examples/dynarray_full test/test_elif_switch
	cd runtime && make clean

# 构建运行时库
runtime:
	cd runtime && make

# 运行时常规测试和未定义行为检查。
runtime-check:
	$(MAKE) -C runtime clean
	$(MAKE) -C runtime test
	$(MAKE) -C runtime clean
	$(MAKE) -C runtime CFLAGS='-Wall -Wextra -g -O1 -std=c11 -fsanitize=undefined' LDFLAGS='-fsanitize=undefined' test
	$(MAKE) -C runtime clean

# 单一入口：前端、示例、runtime、UBSan 和 DIR 自举全部通过才算检查通过。
check: build
	dune test
	$(MAKE) test
	$(MAKE) runtime-check
	$(MAKE) bootstrap

# 编译所有示例程序
examples: build
	@echo "编译示例程序..."
	@_build/default/bin/main.exe build examples/hello.dm
	@_build/default/bin/main.exe build examples/factorial.dm
	@_build/default/bin/main.exe build examples/quicksort.dm
	@_build/default/bin/main.exe build examples/dynarray_full.dm

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
	@echo "\n=== 测试 elif/switch ==="
	@_build/default/bin/main.exe build test/test_elif_switch.dm
	@./test/test_elif_switch

# 单独运行各个示例
hello: build
	_build/default/bin/main.exe build examples/hello.dm && ./examples/hello

factorial: build
	_build/default/bin/main.exe build examples/factorial.dm && ./examples/factorial

quicksort: build
	_build/default/bin/main.exe build examples/quicksort.dm && ./examples/quicksort

dynarray: build
	_build/default/bin/main.exe build examples/dynarray_full.dm && ./examples/dynarray_full

# 执行自举：Stage 0 使用 DIR 编译编译器，后续阶段继续由生成的编译器完成
bootstrap: build
	_build/default/bin/main.exe build --backend=dir bootstrap/compiler.dm
	clang -Wno-override-module -o bootstrap/compiler bootstrap/compiler.ll runtime/io.c runtime/memory.c runtime/dynarray.c runtime/utf8.c runtime/bytes.c runtime/utf8_wrapper.c runtime/bytes_wrapper.c runtime/str.c runtime/file.c runtime/dict.c runtime/tuple.c runtime/union.c runtime/enum.c -I runtime
	./bootstrap/compiler
	$(MAKE) bootstrap-verify
	clang -Wno-override-module -o bootstrap/stage1 bootstrap/stage1.ll runtime/io.c runtime/memory.c runtime/dynarray.c runtime/utf8.c runtime/bytes.c runtime/utf8_wrapper.c runtime/bytes_wrapper.c runtime/str.c runtime/file.c runtime/dict.c runtime/tuple.c runtime/union.c runtime/enum.c -I runtime
	clang -Wno-override-module -o bootstrap/stage2 bootstrap/stage2.ll runtime/io.c runtime/memory.c runtime/dynarray.c runtime/utf8.c runtime/bytes.c runtime/utf8_wrapper.c runtime/bytes_wrapper.c runtime/str.c runtime/file.c runtime/dict.c runtime/tuple.c runtime/union.c runtime/enum.c -I runtime
	clang -Wno-override-module -o bootstrap/stage3 bootstrap/stage3.ll runtime/io.c runtime/memory.c runtime/dynarray.c runtime/utf8.c runtime/bytes.c runtime/utf8_wrapper.c runtime/bytes_wrapper.c runtime/str.c runtime/file.c runtime/dict.c runtime/tuple.c runtime/union.c runtime/enum.c -I runtime
	stage1_output=$$(./bootstrap/stage1); test "$$stage1_output" = "$$(printf '48\nstage2')"; echo "$$stage1_output"
	./bootstrap/stage2
	$(MAKE) bootstrap-verify
	cmp bootstrap/stage2.ll bootstrap/stage3.ll
	./bootstrap/stage3
	$(MAKE) bootstrap-verify
	cmp bootstrap/stage2.ll bootstrap/stage3.ll

# 验证自举各阶段生成的 LLVM 文本，并保留失败上下文。
bootstrap-verify:
	@mkdir -p tmp
	@for llvm_file in bootstrap/compiler.ll bootstrap/stage1.ll bootstrap/stage2.ll bootstrap/stage3.ll; do \
		log_file="tmp/$$(basename "$$llvm_file").verify.log"; \
		if [ ! -f "$$llvm_file" ]; then \
			echo "错误: 缺少 $$llvm_file，请先运行 Stage 0 自举"; \
			exit 1; \
		fi; \
		if ! clang -Wno-override-module -c -o /dev/null -x ir "$$llvm_file" >"$$log_file" 2>&1; then \
			echo "错误: LLVM 验证失败: $$llvm_file"; \
			cat "$$log_file"; \
			exit 1; \
		fi; \
		rm -f "$$log_file"; \
	done

# 编译自定义文件 (使用方法: make compile FILE=path/to/file.dm)
compile: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make compile FILE=examples/hello.dm"; \
		exit 1; \
	fi
	_build/default/bin/main.exe build $(FILE)

# 编译并运行自定义文件 (使用方法: make run FILE=path/to/file.dm)
run: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make run FILE=examples/hello.dm"; \
		exit 1; \
	fi
	_build/default/bin/main.exe build $(FILE) && ./$(basename $(FILE))
