#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

set source_file examples/lang_full_dream.dm
set output_dir tmp/bootstrap_output
set levels ast hir mir lir llvm
set stages stage1 stage2
set include_stage3 false

function print_usage
    echo "用法: fish scripts/bootstrap_output_test.fish [选项]"
    echo ""
    echo "选项:"
    echo "  --levels LIST  只分析指定层级，逗号分隔"
    echo "  --with-stage3  同时分析 Stage 3"
end

function fail_test --description '打印错误并退出'
    echo "错误: $argv[1]" >&2
    exit 1
end

function match_count --description '统计匹配行数'
    set count (rg -c "$argv[1]" "$argv[2]" 2>/dev/null; or echo 0)
    echo $count
end

function analyze_ast --description '分析 AST 节点池'
    set output_file $argv[1]
    set header (head -2 "$output_file" | tail -1)
    set function_count (match_count '^func [0-9]+ ' "$output_file")
    set node_count (match_count '^  n[0-9]+ ' "$output_file")
    set unknown_count (match_count '^  n[0-9]+ unknown' "$output_file")
    set membership_count (match_count '^  n[0-9]+ expr_binary s6: 51 ' "$output_file")
    echo "  $header"
    echo "  functions=$function_count nodes=$node_count unknown=$unknown_count in_nodes=$membership_count"
    if test $unknown_count -ne 0
        return 1
    end
end

function analyze_hir --description '分析 HIR 记录与引用'
    set output_file $argv[1]
    set header (head -1 "$output_file")
    set record_count (match_count '^record id=' "$output_file")
    set module_count (match_count '^record id=.* kind=1 ' "$output_file")
    set function_count (match_count '^record id=.* kind=5 ' "$output_file")
    set block_count (match_count '^record id=.* kind=6 ' "$output_file")
    set expression_count (match_count '^record id=.* kind=9 ' "$output_file")
    set membership_count (match_count '^record id=.* kind=9 opcode=12 type=16 range=0..0 payload=3 \\[1:17,' "$output_file")
    echo "  $header"
    echo "  records=$record_count module=$module_count functions=$function_count blocks=$block_count expressions=$expression_count in_ops=$membership_count"
end

function analyze_mir --description '分析 MIR 控制流与指令'
    set output_file $argv[1]
    set header (head -1 "$output_file")
    set function_count (match_count '^record id=.* kind=5 ' "$output_file")
    set block_count (match_count '^record id=.* kind=6 ' "$output_file")
    set instruction_count (match_count '^record id=.* kind=8 ' "$output_file")
    set terminator_count (match_count '^record id=.* kind=9 ' "$output_file")
    set runtime_count (match_count 'opcode=20 ' "$output_file")
    set membership_count (match_count '^record id=.* kind=8 .* opcode=3 type=2 .* operands=3 \\[2:17,' "$output_file")
    echo "  $header"
    echo "  functions=$function_count blocks=$block_count instructions=$instruction_count terminators=$terminator_count runtime=$runtime_count in_ops=$membership_count"
end

function analyze_lir --description '分析 LIR 类型与布局'
    set output_file $argv[1]
    set header (head -1 "$output_file")
    set function_count (match_count '^record id=.* kind=5 ' "$output_file")
    set block_count (match_count '^record id=.* kind=6 ' "$output_file")
    set instruction_count (match_count '^record id=.* kind=8 ' "$output_file")
    set terminator_count (match_count '^record id=.* kind=9 ' "$output_file")
    set layout_count (string match -r 'layouts=[0-9]+' "$header")
    set membership_count (match_count '^record id=.* kind=8 .* opcode=3 type=2 .* operands=3 \[2:17,' "$output_file")
    echo "  $header"
    echo "  $layout_count functions=$function_count blocks=$block_count instructions=$instruction_count terminators=$terminator_count in_ops=$membership_count"
end

function analyze_llvm --description '分析 LLVM 运行时调用与潜在 trap'
    set output_file $argv[1]
    set function_count (match_count '^define ' "$output_file")
    set trap_count (match_count 'call void @llvm.trap' "$output_file")
    set membership_count (match_count 'call i32 @__c_contains_dynarray_(i32|f64|str)' "$output_file")
    set global_load_count (match_count ' = load ' "$output_file")
    echo "  functions=$function_count globals_loads=$global_load_count membership_calls=$membership_count traps=$trap_count"
    if test $trap_count -ne 0
        echo "  警告: LLVM 含有潜在 trap，需结合函数上下文继续定位"
        awk '/^define / {current_function=$3; sub(/\(.*/, "", current_function)} /call void @llvm.trap/ {print "    trap=" current_function}' "$output_file" | sort -u
    end
end

function dump_stage --description '生成单个阶段输出并分析'
    set stage $argv[1]
    set level $argv[2]
    set output_file "$output_dir/$stage/$level.txt"
    set log_file "$output_dir/$stage/$level.log"
    mkdir -p (dirname "$output_file")

    set namespace "bootstrap-output-$stage"
    env DREAM_COMPILER_CACHE_NAMESPACE="$namespace" "tmp/$stage" "$level" "$source_file" -o "$output_file" \
        >"$log_file" 2>&1
    set compile_status $status
    if test $compile_status -ne 0
        echo "错误: $stage $level 输出失败，日志: $log_file" >&2
        cat "$log_file" >&2
        return 1
    end
    if not test -s "$output_file"
        echo "错误: $stage $level 没有生成输出: $output_file" >&2
        return 1
    end

    echo "[$stage/$level] bytes="(wc -c < "$output_file")" lines="(wc -l < "$output_file")
    switch $level
        case ast
            analyze_ast "$output_file"
        case hir
            analyze_hir "$output_file"
        case mir
            analyze_mir "$output_file"
        case lir
            analyze_lir "$output_file"
        case llvm
            fish --no-config scripts/verify_llvm.fish "$output_file" \
                >"$output_dir/$stage/$level.verify.log" 2>&1
            if test $status -ne 0
                echo "错误: $stage LLVM 输出验证失败" >&2
                cat "$output_dir/$stage/$level.verify.log" >&2
                return 1
            end
            analyze_llvm "$output_file"
    end
end

set arg_index 1
while test $arg_index -le (count $argv)
    switch $argv[$arg_index]
        case --levels
            set arg_index (math $arg_index + 1)
            if test $arg_index -gt (count $argv)
                echo "错误: --levels 缺少参数" >&2
                exit 2
            end
            set levels (string split , $argv[$arg_index])
        case --with-stage3
            set include_stage3 true
        case -h --help
            print_usage
            exit 0
        case '*'
            echo "错误: 未知参数 '$argv[$arg_index]'" >&2
            print_usage >&2
            exit 2
    end
    set arg_index (math $arg_index + 1)
end

for level in $levels
    contains $level ast hir mir lir llvm
    or begin
        echo "错误: 未知层级 '$level'，可选: ast, hir, mir, lir, llvm" >&2
        exit 2
    end
end

if not test -f "$source_file"
    fail_test "输入文件不存在: $source_file"
end

for stage in $stages
    if not test -x "tmp/$stage"
        fail_test "找不到 tmp/$stage，请先运行 make bootstrap"
    end
end

if test "$include_stage3" = true
    if not test -x tmp/stage3
        fail_test "找不到 tmp/stage3，请运行 make bootstrap STAGE3=1"
    end
    set -a stages stage3
end

if test -d "$output_dir"
    rm -r "$output_dir"
end
mkdir -p "$output_dir"

echo "分析输入: $source_file"
echo "输出目录: $output_dir"
for level in $levels
    echo "=== $level ==="
    for stage in $stages
        dump_stage "$stage" "$level"
        or exit 1
    end
end
echo "bootstrap 阶段输出分析完成: $source_file"
