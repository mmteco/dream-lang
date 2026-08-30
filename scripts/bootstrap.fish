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
set full_examples examples/lang_full_*.dm
set full_dream_example examples/lang_full_dream.dm
set full_ocaml_example examples/lang_full_ocaml.dm
set host_output_file tmp/lang_full_host_output
set ocaml_output_file tmp/lang_full_ocaml_output
if test (count $argv) -gt 0
    if test "$argv[1]" = '--skip-stage3'
        set include_stage3 false
    else
        echo '用法: scripts/bootstrap.fish [--skip-stage3]' >&2
        exit 2
    end
end
set ast_output_file tmp/dream_bootstrap_ast.ast

mkdir -p tmp

function cleanup_bootstrap_request --on-event fish_exit
    rm -f "$host_output_file" "$ocaml_output_file" "$ast_output_file"
end

function compile_llvm
    set output_file $argv[1]
    set llvm_file $argv[2]
    if not clang $llvm_flags -O2 -flto=thin -o "$output_file" "$llvm_file" $runtime_sources -I "$runtime_dir/core" -I "$runtime_dir/wrappers" -lcurl
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
    set expected_file $argv[3]
    set expected_lines (string split \n -- (string collect < "$expected_file"))
    set compilers "tmp/stage2"
    if test "$include_stage3" = true
        set -a compilers "tmp/stage3"
    end
    set compiler_index 1
    for compiler in $compilers
        set stage_output_file "$output_file.stage$compiler_index"
        env DREAM_BOOTSTRAP_COMPILER="$compiler" fish --no-config scripts/bootstrap_build.fish run "$source_file" "$stage_output_file" > "$stage_output_file.output"
        set run_status $status
        if test $run_status -ne 0
            echo "错误: Stage $compiler_index 运行失败: $source_file" >&2
            rm -f "$stage_output_file" "$stage_output_file.output"
            exit 1
        end
        set output_lines (string split \n -- (string collect < "$stage_output_file.output"))
        if test (count $output_lines) -ne (count $expected_lines)
            echo "错误: Stage $compiler_index 输出行数错误: $source_file" >&2
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
        rm -f "$stage_output_file" "$stage_output_file.output"
        set compiler_index (math $compiler_index + 1)
    end
end

function check_host_example
    set source_file $argv[1]
    set output_file $argv[2]
    set binary_file "$output_file.binary"
    "$stage0_compiler" build "$source_file" -o "$binary_file" >/dev/null
    or exit 1
    "$binary_file" > "$output_file"
    set run_status $status
    rm -f "$binary_file"
    if test $run_status -ne 0
        echo "错误: 宿主编译器运行失败: $source_file" >&2
        exit 1
    end
end

if test (count $full_examples) -ne 2
    echo '错误: examples/lang_full_*.dm 必须恰好包含 2 个文件' >&2
    exit 1
end

check_host_example "$full_ocaml_example" "$ocaml_output_file"
check_host_example "$full_dream_example" "$host_output_file"

$stage0_compiler build "$compiler_source" -o "$stage1_binary" >/dev/null
or exit 1
check_bootstrapped_ast "$full_dream_example" expr_unary expr_logical expr_cond expr_call expr_index
rg -q 'stmt_return s6: [1-9][0-9]* ' "$ast_output_file"
or exit 1
check_bootstrapped_ast "$full_dream_example" expr_attr expr_binary expr_bool expr_builtin_enum expr_call expr_cond expr_dict expr_float expr_index expr_lambda expr_list expr_list_comp expr_logical expr_match expr_method_call expr_rune expr_slice expr_string expr_struct expr_tuple expr_unary expr_var pat_bool pat_builtin pat_cons pat_enum pat_float pat_int pat_list pat_rune pat_string pat_struct pat_var pat_wildcard m_case stmt_assign stmt_break stmt_case stmt_elif stmt_expr stmt_for stmt_if stmt_let stmt_let_tuple stmt_return stmt_switch stmt_while
"$stage1_binary" llvm "$compiler_source" -o "tmp/stage2.ll"
or exit 1
verify_bootstrap_llvm
or exit 1

compile_llvm "tmp/stage2" "tmp/stage2.ll"
or exit 1

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
check_bootstrapped_example "$full_dream_example" tmp/lang_full_dream "$host_output_file"
