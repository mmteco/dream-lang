#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

set stage0_compiler ocaml/_build/default/bin/main.exe
set bootstrap_dir bootstrap
set runtime_dir runtime/c
set llvm_flags -Wno-override-module
set stage1_binary tmp/stage1
set runtime_sources (find "$runtime_dir/core" "$runtime_dir/wrappers" -type f -name '*.c' ! -path "$runtime_dir/core/bytes.c" | sort)
set compiler_source "$bootstrap_dir/compiler.dm"
set include_stage3 true
if test (count $argv) -gt 0
    if test "$argv[1]" = '--skip-stage3'
        set include_stage3 false
    else
        echo '用法: scripts/bootstrap.fish [--skip-stage3]' >&2
        exit 2
    end
end
set request_source_file tmp/dream_bootstrap_source
set request_output_file tmp/dream_bootstrap_output
set cli_output_file tmp/dream_bootstrap_cli_stage2.ll
set cli_binary_file tmp/dream_bootstrap_stage1_cli_binary
set cli_dir_host_file tmp/dream_bootstrap_host.dir
set cli_dir_stage1_file tmp/dream_bootstrap_stage1.dir
set cli_dir_stage2_file tmp/dream_bootstrap_stage2.dir
set cli_dir_stage3_file tmp/dream_bootstrap_stage3.dir
set ast_output_file tmp/dream_bootstrap_ast.ast

mkdir -p tmp
printf '' > "$request_source_file"
printf '' > "$request_output_file"

function cleanup_bootstrap_request --on-event fish_exit
    rm -f "$request_source_file" "$request_output_file" "$cli_output_file" "$cli_binary_file" "$cli_dir_host_file" "$cli_dir_stage1_file" "$cli_dir_stage2_file" "$cli_dir_stage3_file" "$ast_output_file"
end

function compile_llvm
    set output_file $argv[1]
    set llvm_file $argv[2]
    if not clang $llvm_flags -O2 -flto=thin -o "$output_file" "$llvm_file" $runtime_sources -I "$runtime_dir/core" -I "$runtime_dir/wrappers"
        echo '警告: clang -O2 + ThinLTO 失败' >&2
        return 1
    end
end

function verify_bootstrap_llvm
    set llvm_files "tmp/stage2.ll"
    if test (count $argv) -gt 0; and test "$argv[1]" = '--with-stage3'
        set -a llvm_files "tmp/stage3.ll"
    end
    fish --no-config scripts/verify_llvm.fish $llvm_files
end

function check_lir_lowering
    set stage_name $argv[1]
    set llvm_file "tmp/$stage_name.ll"
    set lowering_matches (rg '^; Dream LIR to LLVM IR$' "$llvm_file")
    set failure_markers (rg '^; LLVM lowering failed' "$llvm_file")
    if test (count $lowering_matches) -eq 0; or test (count $failure_markers) -ne 0
        echo "错误: $stage_name 未成功完成 LIR lowering" >&2
        exit 1
    end
end

function check_bootstrapped_ast
    set source_file $argv[1]
    set compiler $stage1_binary
    "$compiler" ast "$source_file" -o "$ast_output_file" >/dev/null
    or exit 1
    if rg -q 'AST validation failed|unknown kind' "$ast_output_file"
        echo "错误: AST validation failed: $source_file" >&2
        exit 1
    end
    for expected_kind in $argv[2..-1]
        if not rg -q " $expected_kind " "$ast_output_file"
            echo "错误: AST 缺少节点类型 $expected_kind: $source_file" >&2
            exit 1
        end
    end
end

function check_bool_abi
    set stage_name $argv[1]
    set llvm_file "tmp/$stage_name.ll"
    set bool_functions (rg '^define i1 @' "$llvm_file")
    set bool_returns (rg '^  ret i1 ' "$llvm_file")
    if test (count $bool_functions) -lt 5; or test (count $bool_returns) -eq 0
        echo "错误: $stage_name 未生成稳定的 bool i1 ABI" >&2
        exit 1
    end
end

function check_fixed_point
    set stage2_file "tmp/stage2.ll"
    set stage3_file "tmp/stage3.ll"
    cmp "$stage2_file" "$stage3_file"
    or exit 1
    set stage2_hash (shasum -a 256 "$stage2_file" | awk '{print $1}')
    set stage3_hash (shasum -a 256 "$stage3_file" | awk '{print $1}')
    if test -z "$stage2_hash"; or test "$stage2_hash" != "$stage3_hash"
        echo '错误: Stage2/Stage3 SHA-256 不一致' >&2
        exit 1
    end
    echo "fixed-point sha256: $stage2_hash"
    for stage_name in stage2 stage3
        set stage_file "tmp/$stage_name.ll"
        set record_stats (rg '^; DIR records=' "$stage_file" | tail -n 1)
        if test -z "$record_stats"
            echo "错误: $stage_name 缺少 DIR record 统计" >&2
            exit 1
        end
        echo "$stage_name $record_stats"
    end
end

function check_bootstrapped_example
    set source_file $argv[1]
    set output_file $argv[2]
    set expected_lines $argv[3..-1]
    set compilers "tmp/stage2"
    if test "$include_stage3" = true
        set -a compilers "tmp/stage3"
    end
    set compiler_index 1
    for compiler in $compilers
        set stage_output_file "$output_file.stage$compiler_index"
        set output_lines (env DREAM_BOOTSTRAP_COMPILER="$compiler" fish --no-config scripts/bootstrap_build.fish run "$source_file" "$stage_output_file" | string split \n)
        if test (count $output_lines) -ne (count $expected_lines)
            echo "错误: Stage $compiler_index 通用 bootstrap build 输出行数错误: $source_file" >&2
            exit 1
        end
        set line_index 1
        while test $line_index -le (count $expected_lines)
            if test "$output_lines[$line_index]" != "$expected_lines[$line_index]"
                echo "错误: Stage $compiler_index 通用 bootstrap build 输出错误: $source_file" >&2
                exit 1
            end
            set line_index (math $line_index + 1)
        end
        rm -f "$stage_output_file"
        set compiler_index (math $compiler_index + 1)
    end
end

function check_bootstrapped_build
    rm -f "$cli_dir_host_file" "$cli_dir_stage1_file" "$cli_dir_stage2_file" "$cli_dir_stage3_file"
    "$stage0_compiler" dir test/test_const_dir.dm -o "$cli_dir_host_file" >/dev/null
    or exit 1
    DEBUG=1 "$stage1_binary" lir test/test_const_dir.dm -o "$cli_dir_stage1_file"
    or exit 1
    DEBUG=1 "tmp/stage2" lir test/test_const_dir.dm -o "$cli_dir_stage2_file"
    or exit 1
    cmp "$cli_dir_stage1_file" "$cli_dir_stage2_file"
    or exit 1
    set dir_files "$cli_dir_stage1_file" "$cli_dir_stage2_file"
    if test "$include_stage3" = true
        DEBUG=1 "tmp/stage3" lir test/test_const_dir.dm -o "$cli_dir_stage3_file"
        or exit 1
        cmp "$cli_dir_stage2_file" "$cli_dir_stage3_file"
        or exit 1
        set -a dir_files "$cli_dir_stage3_file"
    end
    for dir_file in $dir_files
        if not rg -q '^LIR version=' "$dir_file"; or rg -q 'LIR validation failed' "$dir_file"; or rg -q 'raw-llvm' "$dir_file"
            echo "错误: $dir_file 未输出统一正式 LIR" >&2
            exit 1
        end
    end
    rm -f "$cli_binary_file"
    DEBUG=1 "$stage1_binary" build test/test_string_add_dir.dm -o "$cli_binary_file"
    or exit 1
    set cli_output ("$cli_binary_file" | string split \n)
    if test (count $cli_output) -ne 3; or test "$cli_output[1]" != 'dream language'; or test "$cli_output[2]" != 'hello world'; or test "$cli_output[3]" != '[hello]'
        echo '错误: Stage 1 build CLI 输出错误' >&2
        exit 1
    end
    rm -f "$cli_binary_file"
    check_bootstrapped_example bootstrap/sample_functions.dm tmp/dream_bootstrap_sample 48 stage2
    check_bootstrapped_example examples/hello.dm tmp/dream_bootstrap_hello 'Hello, Dream!'
    check_bootstrapped_example examples/factorial.dm tmp/dream_bootstrap_factorial 120
    check_bootstrapped_example examples/dynarray_full.dm tmp/dream_bootstrap_dynarray 3 10 20 30 5 40 50 99
    check_bootstrapped_example examples/quicksort.dm tmp/dream_bootstrap_quicksort 1 2 3 5 7 9
    check_bootstrapped_example test/test_for_dir.dm tmp/dream_bootstrap_for 60
    check_bootstrapped_example test/test_bootstrap_collections.dm tmp/dream_bootstrap_collections 3 2 30 1
    check_bootstrapped_example examples/lang_full_dream.dm tmp/lang_full_dream 3 2 10 6 10 25 2 9 7 2 42 7 6 -1 20 10 2 3 4 6 100 -1 10 42 2 98 ab 3.5 true 65 66 6 3
    check_bootstrapped_example test/test_rune_index_dir.dm tmp/dream_bootstrap_rune_index true 20320 65536
    check_bootstrapped_example test/test_bootstrap_struct.dm tmp/dream_bootstrap_struct 7
    check_bootstrapped_example test/test_bootstrap_struct_function.dm tmp/dream_bootstrap_struct_function 7
    check_bootstrapped_example test/test_bootstrap_struct_match.dm tmp/dream_bootstrap_struct_match 3
    check_bootstrapped_example test/test_bootstrap_enum.dm tmp/dream_bootstrap_enum 0 42 2
    check_bootstrapped_example test/test_bootstrap_switch_basic.dm tmp/dream_bootstrap_switch_basic 20 1 25 1
    check_bootstrapped_example test/test_bootstrap_match.dm tmp/dream_bootstrap_match 100
    check_bootstrapped_example test/test_bootstrap_match_guard.dm tmp/dream_bootstrap_match_guard 2
    check_bootstrapped_example test/test_bootstrap_list_match.dm tmp/dream_bootstrap_list_match 30 0 11
    check_bootstrapped_example test/test_bootstrap_match_enum.dm tmp/dream_bootstrap_match_enum 42
    check_bootstrapped_example test/test_bootstrap_match_builtin.dm tmp/dream_bootstrap_match_builtin 7 9
    check_bootstrapped_example test/test_bootstrap_list_str.dm tmp/dream_bootstrap_list_str 2 b c 2 x 3 a x-y
    check_bootstrapped_example test/test_bootstrap_match_statement.dm tmp/dream_bootstrap_match_statement 42 -1 7 9
    check_bootstrapped_example test/test_bootstrap_dict.dm tmp/dream_bootstrap_dict 10 25 2
    check_bootstrapped_example test/test_bootstrap_dict_string.dm tmp/dream_bootstrap_dict_string two 2
    check_bootstrapped_example test/test_bootstrap_dict_multiline.dm tmp/dream_bootstrap_dict_multiline 1 2 7 10 20
    check_bootstrapped_example test/test_global_let.dm tmp/dream_bootstrap_global_let 42 hello 80 1 2 7 42 2
    check_bootstrapped_example test/test_default_args_bootstrap.dm tmp/dream_bootstrap_default_args 15 10 31 23 6 'item: x!' '> y!'
    check_bootstrapped_example test/test_list_comp_bootstrap.dm tmp/dream_bootstrap_list_comp 4 2 8 2 3 4
    check_bootstrapped_example test/test_bootstrap_result.dm tmp/dream_bootstrap_result 4
    check_bootstrapped_example test/test_bootstrap_return_metadata.dm tmp/dream_bootstrap_return_metadata metadata true
    check_bootstrapped_example test/test_bootstrap_bool.dm tmp/dream_bootstrap_bool true false false true
    check_bootstrapped_example test/test_bootstrap_elif_tail.dm tmp/dream_bootstrap_elif_tail 20
    check_bootstrapped_example test/test_string_add_dir.dm tmp/dream_bootstrap_string_add 'dream language' 'hello world' '[hello]'
    check_bootstrapped_example test/test_bootstrap_subset_dir.dm tmp/dream_bootstrap_subset 48 bootstrap
    check_bootstrapped_example test/test_const_dir.dm tmp/dream_bootstrap_const 42
    check_bootstrapped_example test/test_dict_dir.dm tmp/dream_bootstrap_dict_dir 10 25 2 two
    check_bootstrapped_example test/test_enum_dir.dm tmp/dream_bootstrap_enum_dir 2
    check_bootstrapped_example test/test_expr_dir.dm tmp/dream_bootstrap_expr 10 32 32 65 66
    check_bootstrapped_example test/test_float_dir.dm tmp/dream_bootstrap_float 5.5 true
    check_bootstrapped_example test/test_bootstrap_function_value.dm tmp/dream_bootstrap_function_value 42
    check_bootstrapped_example test/test_function_value_dir.dm tmp/dream_bootstrap_function_value_dir 42
    check_bootstrapped_example test/test_bootstrap_lambda.dm tmp/dream_bootstrap_lambda 42
    # TODO: 嵌套 lambda 闭包需要完整的闭包实现（自由变量分析、环境结构、变量捕获等）
    # 这是一个独立的大型特性，预计需要 3-5 天工作量
    # 详细方案见 docs/COMPILER_IMPROVEMENT_PLAN.md
    # check_bootstrapped_example test/test_bootstrap_nested_lambda.dm tmp/dream_bootstrap_nested_lambda 9
    check_bootstrapped_example test/test_list_match_dir.dm tmp/dream_bootstrap_list_match_dir 30 0 11
    check_bootstrapped_example test/test_match_dir.dm tmp/dream_bootstrap_match_dir 100
    check_bootstrapped_example test/test_match_guard_dir.dm tmp/dream_bootstrap_match_guard_dir 2
    check_bootstrapped_example test/test_bytes_dir.dm tmp/dream_bootstrap_bytes 98 2 bc 120 2
    check_bootstrapped_example test/test_scalar_match_dir.dm tmp/dream_bootstrap_scalar_match 20 1 2 3
    check_bootstrapped_example test/test_switch_basic_types_dir.dm tmp/dream_bootstrap_switch_basic_types 25 1 1
    check_bootstrapped_example test/test_switch_multi_case.dm tmp/dream_bootstrap_switch_multi_case 10 10 20 0
    # TODO: ? 操作符在 Dream 编译器中生成的 IR 有 return 后还有代码的问题
    # 需要修复 ? 操作符的控制流生成
    # check_bootstrapped_example test/test_try_dir.dm tmp/dream_bootstrap_try 42 -1
    # TODO: 多载荷枚举匹配在 Dream 编译器中有未定义变量问题
    # check_bootstrapped_example test/test_enum_multi_dir.dm tmp/dream_bootstrap_enum_multi 42
    # TODO: match case 作用域隔离问题 - 多个 case 绑定同名变量时，后续 case 会跳过 alloca
    # 需要实现完整的 match case 作用域隔离机制（保存/恢复变量列表或使用唯一槽位名）
    # check_bootstrapped_example test/test_enum_payload_dir.dm tmp/dream_bootstrap_enum_payload 42 2.5 2 1
    check_bootstrapped_example test/test_generic_dir.dm tmp/dream_bootstrap_generic 41 42 42 42
    check_bootstrapped_example test/test_lambda_dir.dm tmp/dream_bootstrap_lambda_capture 42 42 ok! 7 3.5 3 param?
    check_bootstrapped_example test/test_struct_dir.dm tmp/dream_bootstrap_struct_dir 2 5.5 5.5
    check_bootstrapped_example test/test_struct_import_dir.dm tmp/dream_bootstrap_struct_import 7
    check_bootstrapped_example test/test_generic_import_dir.dm tmp/dream_bootstrap_generic_import 7
    check_bootstrapped_example test/test_struct_method_dir.dm tmp/dream_bootstrap_struct_method 7 12 11
    check_bootstrapped_example test/test_interface_dir.dm tmp/dream_bootstrap_interface 11 7
    check_bootstrapped_example test/test_interface_args_dir.dm tmp/dream_bootstrap_interface_args 15 true false
    if test "$include_stage3" = true
        rm -f "$cli_binary_file"
        DEBUG=1 "tmp/stage3" build test/test_string_add_dir.dm -o "$cli_binary_file"
        or exit 1
        set stage3_output ("$cli_binary_file" | string split \n)
        if test (count $stage3_output) -ne 3; or test "$stage3_output[1]" != 'dream language'; or test "$stage3_output[2]" != 'hello world'; or test "$stage3_output[3]" != '[hello]'
            echo '错误: Stage 3 build CLI 输出错误' >&2
            exit 1
        end
        rm -f "$cli_binary_file"
    end
end

$stage0_compiler build "$compiler_source" -o "$stage1_binary" >/dev/null
or exit 1
check_bootstrapped_ast test/test_pratt_ast_dir.dm expr_unary expr_logical expr_cond expr_call expr_index
rg -q 'stmt_return s6: [1-9][0-9]* ' "$ast_output_file"
or exit 1
check_bootstrapped_ast examples/lang_full_dream.dm expr_attr expr_binary expr_bool expr_builtin_enum expr_call expr_cond expr_dict expr_float expr_index expr_lambda expr_list expr_list_comp expr_logical expr_match expr_method_call expr_print expr_rune expr_slice expr_string expr_struct expr_tuple expr_unary expr_var pat_bool pat_builtin pat_cons pat_enum pat_float pat_int pat_list pat_rune pat_string pat_struct pat_var pat_wildcard m_case stmt_assign stmt_break stmt_case stmt_elif stmt_expr stmt_for stmt_if stmt_let stmt_let_tuple stmt_return stmt_switch stmt_while
rg -q 'expr_print s5: [0-9]+ 1$' "$ast_output_file"
or exit 1
"$stage1_binary" llvm "$compiler_source" -o "tmp/stage2.ll"
or exit 1
verify_bootstrap_llvm
or exit 1

compile_llvm "tmp/stage2" "tmp/stage2.ll"
or exit 1

"$stage1_binary" llvm bootstrap/sample_functions.dm -o "tmp/sample_functions.ll"
or exit 1

compile_llvm "tmp/sample_functions" "tmp/sample_functions.ll"
or exit 1
set sample_output ("tmp/sample_functions" | string split \n)
if test (count $sample_output) -ne 2; or test "$sample_output[1]" != 48; or test "$sample_output[2]" != stage2
    echo '错误: sample_functions 输出不符合预期' >&2
    exit 1
end
printf '%s\n' $sample_output

"tmp/stage2" help >/dev/null
or exit 1

if test "$include_stage3" = true
    "tmp/stage2" llvm "$compiler_source" -o "tmp/stage3.ll"
    or exit 1
    verify_bootstrap_llvm --with-stage3
    or exit 1
    compile_llvm "tmp/stage3" "tmp/stage3.ll"
    or exit 1
    "tmp/stage3" help >/dev/null
    or exit 1
    check_lir_lowering stage2
    check_lir_lowering stage3
    check_bool_abi stage2
    check_bool_abi stage3
    check_fixed_point
else
    check_lir_lowering stage2
    check_bool_abi stage2
end
check_bootstrapped_build

rm -f "$request_source_file" "$request_output_file"
