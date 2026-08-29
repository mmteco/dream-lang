#!/usr/bin/env fish
# 差分定位:同一输入分别经 stage1/stage2 编译器逐级 dump IR(ast/hir/mir/lir/llvm),
# 报告首个分歧层级与差异片段,把误编译问题定位到具体管线阶段。
# 用法示例: fish scripts/repro_diff.fish tmp/tbd.dm --levels mir,lir

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

set known_levels ast hir mir lir llvm
set levels $known_levels
set out_dir tmp/repro_diff
set compiler_a tmp/stage1
set compiler_b tmp/stage2
set source_file ""
set timeout_seconds 300

function print_usage
    echo "用法: fish scripts/repro_diff.fish FILE.dm [选项]"
    echo ""
    echo "选项:"
    echo "  --levels LIST  参与差分的层级,逗号分隔 (默认 ast,hir,mir,lir,llvm)"
    echo "  --out DIR      dump 输出目录 (默认 tmp/repro_diff)"
    echo "  --s1 BIN       对照编译器 A (默认 tmp/stage1)"
    echo "  --s2 BIN       被测编译器 B (默认 tmp/stage2,缺失时从 tmp/stage2.ll 链接)"
    echo "  --timeout SEC  单次编译超时秒数 (默认 300,防 llvm 模式挂死)"
end

function fail_usage --description '打印用法并退出'
    echo "错误: $argv[1]" >&2
    print_usage >&2
    exit 2
end

function run_with_timeout --description '带超时运行命令,无 timeout 工具时直接运行'
    set duration $argv[1]
    set -e argv[1]
    if command -v timeout >/dev/null
        timeout $duration $argv
    else if command -v gtimeout >/dev/null
        gtimeout $duration $argv
    else
        $argv
    end
end

function file_size --description '输出文件字节数,缺文件时返回 -'
    if test -f "$argv[1]"
        wc -c <"$argv[1]" | string trim
    else
        echo -
    end
end

# 解析参数
set arg_index 1
while test $arg_index -le (count $argv)
    switch $argv[$arg_index]
        case --levels
            set arg_index (math $arg_index + 1)
            test $arg_index -gt (count $argv); and fail_usage "--levels 缺少参数"
            set levels (string split , $argv[$arg_index])
        case --out
            set arg_index (math $arg_index + 1)
            test $arg_index -gt (count $argv); and fail_usage "--out 缺少参数"
            set out_dir $argv[$arg_index]
        case --s1
            set arg_index (math $arg_index + 1)
            test $arg_index -gt (count $argv); and fail_usage "--s1 缺少参数"
            set compiler_a $argv[$arg_index]
        case --s2
            set arg_index (math $arg_index + 1)
            test $arg_index -gt (count $argv); and fail_usage "--s2 缺少参数"
            set compiler_b $argv[$arg_index]
        case --timeout
            set arg_index (math $arg_index + 1)
            test $arg_index -gt (count $argv); and fail_usage "--timeout 缺少参数"
            set timeout_seconds $argv[$arg_index]
        case -h --help
            print_usage
            exit 0
        case '*'
            test -n "$source_file"; and fail_usage "多余参数 '$argv[$arg_index]'"
            set source_file $argv[$arg_index]
    end
    set arg_index (math $arg_index + 1)
end

test -n "$source_file"; or fail_usage "缺少输入文件"
test -f "$source_file"; or begin echo "错误: 输入文件不存在: $source_file" >&2; exit 2; end
for level in $levels
    contains $level $known_levels; or fail_usage "未知层级 '$level'(可选: $known_levels)"
end

# 对照编译器必须存在
if not test -x "$compiler_a"
    echo "错误: 找不到对照编译器 $compiler_a" >&2
    echo "请先运行 make bootstrap(或 ocaml/_build/default/bin/main.exe build bootstrap/compiler.dm -o tmp/stage1)" >&2
    exit 1
end

# 被测编译器缺失时尝试从 stage2.ll 现场链接,保证 bootstrap 半途而废也能差分
if not test -x "$compiler_b"
    if test -f tmp/stage2.ll
        echo "提示: $compiler_b 不存在,正在从 tmp/stage2.ll 链接 ..."
        set runtime_sources (find runtime/c/core runtime/c/wrappers -type f -name '*.c' ! -path 'runtime/c/core/bytes.c' | sort)
        if not clang -Wno-override-module -O2 -flto=thin -o "$compiler_b" tmp/stage2.ll $runtime_sources -I runtime/c/core -I runtime/c/wrappers -lcurl
            echo "错误: 从 tmp/stage2.ll 链接被测编译器失败" >&2
            exit 1
        end
    else
        echo "错误: 找不到被测编译器 $compiler_b(也没有 tmp/stage2.ll 可链接)" >&2
        echo "请先运行 make bootstrap 生成自举产物" >&2
        exit 1
    end
end

echo "输入: $source_file"
echo "对照 A: $compiler_a   被测 B: $compiler_b"
echo ""

mkdir -p "$out_dir"
set divergent_levels
set broken_levels
set is_clean true

for level in $levels
    set dump_a "$out_dir/$level.a"
    set dump_b "$out_dir/$level.b"
    run_with_timeout $timeout_seconds "$compiler_a" $level "$source_file" -o "$dump_a" >"$out_dir/$level.a.log" 2>&1
    set status_a $status
    run_with_timeout $timeout_seconds "$compiler_b" $level "$source_file" -o "$dump_b" >"$out_dir/$level.b.log" 2>&1
    set status_b $status

    set verdict
    if test $status_a -eq 124; or test $status_b -eq 124
        set verdict 挂死
        set is_clean false
        set broken_levels $broken_levels $level
    else if test $status_a -ne 0; or test $status_b -ne 0
        set verdict 运行失败
        set is_clean false
        set broken_levels $broken_levels $level
    else if not test -f "$dump_a"; or not test -f "$dump_b"
        set verdict 缺输出
        set is_clean false
        set broken_levels $broken_levels $level
    else if cmp -s "$dump_a" "$dump_b"
        set verdict 一致
    else
        set verdict 分歧
        set is_clean false
        set divergent_levels $divergent_levels $level
    end
    printf '%-6s A[%s %7s B] [%s %7s B]\n' \
        $level \
        (test $status_a -eq 0; and echo ok; or echo "exit$status_a") (file_size "$dump_a") \
        (test $status_b -eq 0; and echo ok; or echo "exit$status_b") (file_size "$dump_b")
end

echo ""
if test (count $divergent_levels) -gt 0
    set first $divergent_levels[1]
    echo "===> 首个分歧层级: $first"
    cmp "$out_dir/$first.a" "$out_dir/$first.b"
    diff -u -a "$out_dir/$first.a" "$out_dir/$first.b" | head -40
else if test (count $broken_levels) -eq 0
    echo "===> 全部层级一致"
end

if test (count $broken_levels) -gt 0
    echo "异常层级(详见 $out_dir/<层级>.{a,b}.log): $broken_levels"
end
echo "产物目录: $out_dir/"

test "$is_clean" = true; and exit 0
exit 1
