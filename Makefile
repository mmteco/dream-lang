EXAMPLE_SOURCES := $(wildcard examples/*.dm)
EXAMPLE_TARGETS := $(patsubst examples/%.dm,%,$(EXAMPLE_SOURCES))
FISH ?= fish
RUNTIME_DIR ?= runtime
STAGE3 ?= 0

.PHONY: build clean run test examples runtime-check check bootstrap bootstrap-verify bootstrap-build compile dynarray help $(EXAMPLE_TARGETS)

# 默认目标
help:
	@echo "Dream 语言编译器 - 可用命令:"
	@echo ""
	@echo "  make build       - 构建编译器"
	@echo "  make clean       - 清理构建产物"
	@echo "  make test        - 运行 smoke 和 DIR 回归测试"
	@echo "  make examples    - 编译标记为 smoke 的示例程序"
	@echo "  make runtime     - 构建运行时库"
	@echo "  make runtime-check - 运行 runtime 常规测试和 UBSan 测试"
	@echo "  make check       - 运行完整构建、测试和自举验证"
	@echo "  make <example>   - 编译并运行 examples/<example>.dm"
	@echo "  make bootstrap   - 快速执行 Stage 0 → Stage 1 → Stage 2 验证"
	@echo "  make bootstrap STAGE3=1 - 执行 Stage 2 → Stage 3 固定点验证"
	@echo "  make bootstrap-build FILE=path/to/file.dm - 使用 Stage 2 bootstrapped 编译器构建"
	@echo "  make bootstrap-verify - 验证已生成的自举 LLVM 文件"
	@echo ""

# 构建编译器
build:
	dune build

# 清理所有构建产物
clean:
	$(FISH) scripts/clean.fish

# 构建运行时库
runtime:
	$(MAKE) -C $(RUNTIME_DIR)

# 运行时常规测试和未定义行为检查。
runtime-check:
	$(MAKE) -C $(RUNTIME_DIR) clean
	$(MAKE) -C $(RUNTIME_DIR) test
	$(MAKE) -C $(RUNTIME_DIR) clean
	$(MAKE) -C $(RUNTIME_DIR) CFLAGS='-Wall -Wextra -g -O1 -std=c11 -fsanitize=undefined' LDFLAGS='-fsanitize=undefined' test
	$(MAKE) -C $(RUNTIME_DIR) clean

# 单一入口：前端、示例、runtime、UBSan 和 DIR 自举全部通过才算检查通过。
check: build
	dune test
	$(MAKE) test
	$(MAKE) runtime-check
	$(MAKE) bootstrap

# 编译所有示例程序
examples: build
	$(FISH) scripts/test.fish examples

# 运行所有示例测试
test: build
	$(FISH) scripts/test.fish all

# 单独运行任意示例
$(EXAMPLE_TARGETS): build
	$(FISH) scripts/dream.fish run examples/$@.dm

dynarray: dynarray_full

# 执行自举：Stage 0 生成 Stage 1，后续阶段继续编译自身并验证固定点。
bootstrap: build
	$(FISH) scripts/bootstrap.fish $(if $(filter 0 false no,$(STAGE3)),--skip-stage3,)

# 验证自举各阶段生成的 LLVM 文本，并保留失败上下文。
bootstrap-verify:
	$(FISH) scripts/verify_llvm.fish

# 使用已自举的 Stage 2 编译器构建当前 bootstrap 语法子集。
bootstrap-build:
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make bootstrap-build FILE=bootstrap/sample_functions.dm"; \
		exit 1; \
	fi
	$(FISH) scripts/bootstrap_build.fish build "$(FILE)" $(if $(OUTPUT),"$(OUTPUT)")

# 编译自定义文件 (使用方法: make compile FILE=path/to/file.dm)
compile: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make compile FILE=examples/hello.dm"; \
		exit 1; \
	fi
	$(FISH) scripts/dream.fish build "$(FILE)"

# 编译并运行自定义文件 (使用方法: make run FILE=path/to/file.dm)
run: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make run FILE=examples/hello.dm"; \
		exit 1; \
	fi
	$(FISH) scripts/dream.fish run "$(FILE)"
