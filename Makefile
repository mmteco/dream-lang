OCAML_COMPILER := ocaml/_build/default/bin/main.exe
FISH ?= fish
RUNTIME_DIR ?= runtime/c
STAGE3 ?= 0

.DEFAULT_GOAL := build
.PHONY: build clean run test runtime-check check bootstrap bootstrap-output bootstrap-verify bootstrap-build compile repro-diff help

help:
	@echo "Dream 语言编译器 - 可用命令:"
	@echo ""
	@echo "  make build       - 构建编译器"
	@echo "  make clean       - 清理构建产物"
	@echo "  make test        - 运行完整语言和 DIR 回归测试"
	@echo "  make runtime-check - 运行 runtime 常规测试和 UBSan 测试"
	@echo "  make check       - 运行完整构建、测试和自举验证"
	@echo "  make bootstrap   - 执行 Stage 0 → Stage 1 → Stage 2 验证"
	@echo "  make bootstrap-output - 分析 lang_full_dream 各阶段输出"
	@echo "  make bootstrap-output LEVELS=hir,lir - 只分析指定阶段"
	@echo "  make bootstrap STAGE3=1 - 额外执行 Stage 2 → Stage 3 固定点验证"
	@echo "  make bootstrap-build FILE=path/to/file.dm - 使用 Stage 2 bootstrapped 编译器构建"
	@echo "  make bootstrap-verify - 验证已生成的自举 LLVM 文件"
	@echo "  make repro-diff FILE=path/to/file.dm - stage1/stage2 逐级 IR 差分定位"
	@echo ""

# 构建编译器
build:
	cd ocaml && dune build

# 清理所有构建产物
clean:
	$(FISH) scripts/clean.fish

# 运行时常规测试和未定义行为检查。
runtime-check:
	$(MAKE) -C $(RUNTIME_DIR) clean
	$(MAKE) -C $(RUNTIME_DIR) test
	$(MAKE) -C $(RUNTIME_DIR) clean
	$(MAKE) -C $(RUNTIME_DIR) CFLAGS='-Wall -Wextra -g -O1 -std=c11 -fsanitize=undefined' LDFLAGS='-fsanitize=undefined' test
	$(MAKE) -C $(RUNTIME_DIR) clean

# 单一入口：前端、示例、runtime、UBSan 和 DIR 自举全部通过才算检查通过。
check: build
	cd ocaml && dune test
	$(MAKE) test
	$(MAKE) runtime-check
	$(MAKE) bootstrap
	$(MAKE) bootstrap-output

# 运行所有示例测试
test: build
	$(FISH) scripts/test.fish all

# 执行自举：Stage 0 生成 Stage 1，后续阶段继续编译自身并验证固定点。
bootstrap: build
	$(FISH) scripts/bootstrap.fish $(if $(filter 0 false no,$(STAGE3)),--skip-stage3,)

# 使用 lang_full_dream.dm 验证 AST/HIR/MIR/LIR/LLVM 的稳定输出。
bootstrap-output: build
	$(FISH) scripts/bootstrap_output_test.fish $(if $(LEVELS),--levels $(LEVELS),) $(if $(filter 0 false no,$(STAGE3)),,--with-stage3)

# 验证自举各阶段生成的 LLVM 文本，并保留失败上下文。
bootstrap-verify:
	$(FISH) scripts/verify_llvm.fish

# 使用已自举的 Stage 2 编译器构建当前 bootstrap 语法子集。
bootstrap-build:
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make bootstrap-build FILE=test/fixtures/bootstrap_sample_functions.dm"; \
		exit 1; \
	fi
	$(FISH) scripts/bootstrap_build.fish build "$(FILE)" $(if $(OUTPUT),"$(OUTPUT)")

# 编译自定义文件 (使用方法: make compile FILE=path/to/file.dm)
compile: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make compile FILE=examples/hello.dm"; \
		exit 1; \
	fi
	$(OCAML_COMPILER) build "$(FILE)"

# 编译并运行自定义文件 (使用方法: make run FILE=path/to/file.dm)
run: build
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make run FILE=examples/hello.dm"; \
		exit 1; \
	fi
	$(OCAML_COMPILER) run "$(FILE)"

# 自举差分定位:同一输入经 stage1/stage2 逐级 dump IR 并报告首个分歧层级
repro-diff:
	@if [ -z "$(FILE)" ]; then \
		echo "错误: 请指定文件路径，例如: make repro-diff FILE=test/fixtures/iface.dm"; \
		exit 1; \
	fi
	$(FISH) scripts/repro_diff.fish "$(FILE)" $(if $(LEVELS),--levels $(LEVELS))
