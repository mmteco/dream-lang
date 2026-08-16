#!/usr/bin/env fish

if test (count $argv) -lt 2; or test (count $argv) -gt 3
    echo '用法: scripts/bootstrap_build.fish build|run <file.dm> [output]' >&2
    exit 2
end

set command_name $argv[1]
set source_file $argv[2]
set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

if not test -f "$source_file"
    echo "错误: 源文件不存在: $source_file" >&2
    exit 1
end

set source_path (realpath "$source_file")
set output_file (string replace -r '\.dm$' '' "$source_path")
if test (count $argv) -eq 3; and test -n "$argv[3]"
    set output_file "$argv[3]"
    if not string match -q '/*' "$output_file"
        set output_file "$root_dir/$output_file"
    end
end

set bootstrapped_compiler "$root_dir/bootstrap/stage2"
set request_source_file "$root_dir/tmp/dream_bootstrap_source"
set request_output_file "$root_dir/tmp/dream_bootstrap_output"
set prepared_source_file "$root_dir/tmp/dream_bootstrap_input.dm"
set llvm_output "$root_dir/tmp/dream_bootstrap_output.ll"
set runtime_sources (find "$root_dir/runtime" -maxdepth 1 -type f -name '*.c' ! -name 'test_*.c' | sort)

function cleanup_request_files --on-event fish_exit
    rm -f "$request_source_file" "$request_output_file" "$prepared_source_file"
end

if not test -x "$bootstrapped_compiler"
    echo '未找到 Stage 2 bootstrapped 编译器，先执行自举验证...' >&2
    fish scripts/bootstrap.fish
    or exit 1
end

mkdir -p "$root_dir/tmp"
set request_input_path "$source_path"
if not rg -q '^def[[:space:]]+main[[:space:]]*\(' "$source_path"
    printf 'def main():\n' > "$prepared_source_file"
    set copies_top_level_block 0
    set source_lines (string split \n -- (string collect < "$source_path"))
    for source_line in $source_lines
        set leading_spaces (string match -r '^[ ]*' -- "$source_line")
        set indentation (string length -- "$leading_spaces")
        set stripped_line (string replace -r '^[[:space:]]*' '' -- "$source_line")
        set is_empty (test -z "$stripped_line"; and echo 1; or echo 0)
        set is_comment (string match -q '#*' -- "$stripped_line"; and echo 1; or echo 0)
        if test $indentation -eq 0
            set copies_top_level_block 0
            if test $is_empty -eq 0; and test $is_comment -eq 0; and not string match -q -r '^(def|from|import|const|struct|enum|class|interface|impl|type)([[:space:](]|$)' -- "$stripped_line"
                printf '    %s\n' "$source_line" >> "$prepared_source_file"
                if string match -q -r '^(if|match|switch|while|for)([[:space:](]|$)' -- "$stripped_line"
                    set copies_top_level_block 1
                end
            end
        else if test $copies_top_level_block -eq 1
            printf '    %s\n' "$source_line" >> "$prepared_source_file"
        end
    end
    printf '\n' >> "$prepared_source_file"
    string collect < "$source_path" >> "$prepared_source_file"
    set request_input_path "$prepared_source_file"
end

printf '%s' "$request_input_path" > "$request_source_file"
printf '%s' "$llvm_output" > "$request_output_file"

"$bootstrapped_compiler"
or exit 1

if not test -s "$llvm_output"
    echo '错误: bootstrapped 编译器没有生成 LLVM 输出' >&2
    exit 1
end

if rg -q '^; DIR validation failed' "$llvm_output"
    echo '错误: bootstrapped 编译器生成的 DIR 未通过验证' >&2
    exit 1
end

clang -Wno-override-module -O2 -flto=thin -o "$output_file" "$llvm_output" $runtime_sources -I "$root_dir/runtime"
or exit 1

rm -f "$request_source_file" "$request_output_file"

switch $command_name
    case build
    case run
        "$output_file"
    case '*'
        echo "错误: 未知命令 $command_name" >&2
        exit 2
end
