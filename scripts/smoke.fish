#!/usr/bin/env fish
# 快速冒烟:小改动时验证新编译器代码可编译 + 新流水线可跑,跳过全量回归。
# 用法: fish scripts/smoke.fish [test1.dm test2.dm ...]
# 默认测试 test/test_bootstrap_bool.dm 和 test/test_bootstrap_elif_tail.dm

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

set stage0_compiler ocaml/_build/default/bin/main.exe
set llvm_flags -Wno-override-module
set link_flags -O0
set runtime_sources (find runtime/c -maxdepth 1 -type f -name '*.c' ! -name 'test_*.c' ! -name 'bytes.c' | sort)

if test (count $argv) -eq 0
    set test_files test/test_bootstrap_bool.dm test/test_bootstrap_elif_tail.dm examples/lang_full_dream.dm
else
    set test_files $argv
end

# 1. stage0 编译新 compiler.dm(验证语法/类型)
echo '== stage0 compile'
"$stage0_compiler" build bootstrap/compiler.dm
or exit 1
mv bootstrap/compiler.ll tmp/stage1.ll
or exit 1

# 2. 链接新 stage1(-O0 加速冒烟;全量验证用 make bootstrap 的 -O2)
echo '== link stage1'
clang $llvm_flags $link_flags -o tmp/stage1 tmp/stage1.ll $runtime_sources -I runtime/c
or exit 1

# 3. 用新 stage1 的新流水线(DEBUG)编译目标测试
for source_file in $test_files
    echo "== $source_file"
    env DEBUG=true tmp/stage1 llvm "$source_file" -o tmp/smoke.ll
    or exit 1
    head -1 tmp/smoke.ll
end
rm -f tmp/smoke.ll
echo '== smoke OK'
