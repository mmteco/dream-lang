#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

set stage0_compiler _build/default/bin/main.exe
set bootstrap_dir bootstrap
set runtime_dir runtime
set llvm_flags -Wno-override-module
set runtime_sources (find "$runtime_dir" -maxdepth 1 -type f -name '*.c' ! -name 'test_*.c' | sort)
set compiler_source "$bootstrap_dir/compiler.dm"
set stage1_llvm "$bootstrap_dir/stage1.ll"
set stage_names stage2 stage3
set request_source_file tmp/dream_bootstrap_source
set request_output_file tmp/dream_bootstrap_output

mkdir -p tmp
printf '' > "$request_source_file"
printf '' > "$request_output_file"

function cleanup_bootstrap_request --on-event fish_exit
    rm -f "$request_source_file" "$request_output_file"
end

function compile_llvm
    set output_file $argv[1]
    set llvm_file $argv[2]
    clang $llvm_flags -O2 -flto=thin -o "$output_file" "$llvm_file" $runtime_sources -I "$runtime_dir"
end

function check_dir_lowering
    set stage_name $argv[1]
    set llvm_file "$bootstrap_dir/$stage_name.ll"
    set lowering_matches (rg '^define i1 @dir_lower_buffer' "$llvm_file")
    set failure_markers (rg '^; DIR validation failed' "$llvm_file")
    if test (count $lowering_matches) -eq 0; or test (count $failure_markers) -ne 0
        echo "错误: $stage_name 未成功生成独立 DIR lowering" >&2
        exit 1
    end
end

function check_bool_abi
    set stage_name $argv[1]
    set llvm_file "$bootstrap_dir/$stage_name.ll"
    set bool_functions (rg '^define i1 @(is_digit|is_identifier_start|is_identifier_continue|source_equals|source_ranges_equal)\(' "$llvm_file")
    set bool_returns (rg '^ret i1 ' "$llvm_file")
    if test (count $bool_functions) -lt 5; or test (count $bool_returns) -eq 0
        echo "错误: $stage_name 未生成稳定的 bool i1 ABI" >&2
        exit 1
    end
end

function check_fixed_point
    set stage2_file "$bootstrap_dir/stage2.ll"
    set stage3_file "$bootstrap_dir/stage3.ll"
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
        set stage_file "$bootstrap_dir/$stage_name.ll"
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
    set output_lines (fish scripts/bootstrap_build.fish run "$source_file" "$output_file" | string split \n)
    if test (count $output_lines) -ne (count $expected_lines)
        echo "错误: Stage 2 通用 bootstrap build 输出行数错误: $source_file" >&2
        exit 1
    end
    set line_index 1
    while test $line_index -le (count $expected_lines)
        if test "$output_lines[$line_index]" != "$expected_lines[$line_index]"
            echo "错误: Stage 2 通用 bootstrap build 输出错误: $source_file" >&2
            exit 1
        end
        set line_index (math $line_index + 1)
    end
    rm -f "$output_file"
end

function check_bootstrapped_build
    check_bootstrapped_example bootstrap/sample_functions.dm tmp/dream_bootstrap_sample 48 stage2
    check_bootstrapped_example examples/hello.dm tmp/dream_bootstrap_hello 'Hello, Dream!'
    check_bootstrapped_example examples/factorial.dm tmp/dream_bootstrap_factorial 120
    check_bootstrapped_example examples/dynarray_full.dm tmp/dream_bootstrap_dynarray 3 10 20 30 5 40 50 99
    check_bootstrapped_example test/test_for_dir.dm tmp/dream_bootstrap_for 60
    check_bootstrapped_example test/test_bootstrap_collections.dm tmp/dream_bootstrap_collections 3 2 30 1
    check_bootstrapped_example test/test_bootstrap_struct.dm tmp/dream_bootstrap_struct 7
    check_bootstrapped_example test/test_bootstrap_enum.dm tmp/dream_bootstrap_enum 0 42 2
    check_bootstrapped_example test/test_bootstrap_switch_basic.dm tmp/dream_bootstrap_switch_basic 20 1 25 1
    check_bootstrapped_example test/test_bootstrap_match.dm tmp/dream_bootstrap_match 100
    check_bootstrapped_example test/test_bootstrap_match_guard.dm tmp/dream_bootstrap_match_guard 2
    check_bootstrapped_example test/test_bootstrap_list_match.dm tmp/dream_bootstrap_list_match 30 0 11
    check_bootstrapped_example test/test_bootstrap_match_enum.dm tmp/dream_bootstrap_match_enum 42
    check_bootstrapped_example test/test_bootstrap_match_builtin.dm tmp/dream_bootstrap_match_builtin 7 9
    check_bootstrapped_example test/test_bootstrap_dict.dm tmp/dream_bootstrap_dict 10 25 2
    check_bootstrapped_example test/test_bootstrap_dict_string.dm tmp/dream_bootstrap_dict_string two 2
    check_bootstrapped_example test/test_bootstrap_result.dm tmp/dream_bootstrap_result 4
    check_bootstrapped_example test/test_bootstrap_return_metadata.dm tmp/dream_bootstrap_return_metadata metadata true
    check_bootstrapped_example test/test_bootstrap_bool.dm tmp/dream_bootstrap_bool true false false true
    check_bootstrapped_example test/test_bootstrap_function_value.dm tmp/dream_bootstrap_function_value 42
    check_bootstrapped_example test/test_bootstrap_lambda.dm tmp/dream_bootstrap_lambda 42
end

$stage0_compiler build "$compiler_source" >/dev/null
or exit 1
mv "$bootstrap_dir/compiler.ll" "$stage1_llvm"
or exit 1
mv "$bootstrap_dir/compiler" "$bootstrap_dir/stage1"
or exit 1
compile_llvm "$bootstrap_dir/stage1" "$stage1_llvm"
or exit 1
"$bootstrap_dir/stage1"
or exit 1
fish scripts/verify_llvm.fish
or exit 1

for stage_name in $stage_names
    compile_llvm "$bootstrap_dir/$stage_name" "$bootstrap_dir/$stage_name.ll"
    or exit 1
end

compile_llvm "$bootstrap_dir/sample_functions" "$bootstrap_dir/sample_functions.ll"
or exit 1
set sample_output ("$bootstrap_dir/sample_functions" | string split \n)
if test (count $sample_output) -ne 2; or test "$sample_output[1]" != 48; or test "$sample_output[2]" != stage2
    echo '错误: sample_functions 输出不符合预期' >&2
    exit 1
end
printf '%s\n' $sample_output

"$bootstrap_dir/stage2"
or exit 1
fish scripts/verify_llvm.fish
or exit 1
check_dir_lowering stage2
check_dir_lowering stage3
check_bool_abi stage2
check_bool_abi stage3
check_fixed_point

"$bootstrap_dir/stage3"
or exit 1
fish scripts/verify_llvm.fish
or exit 1
check_dir_lowering stage2
check_dir_lowering stage3
check_bool_abi stage2
check_bool_abi stage3
check_fixed_point
check_bootstrapped_build

rm -f "$request_source_file" "$request_output_file"
