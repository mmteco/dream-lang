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
if set -q DREAM_BOOTSTRAP_COMPILER
    set bootstrapped_compiler "$DREAM_BOOTSTRAP_COMPILER"
end
set prepared_source_file "$root_dir/tmp/dream_bootstrap_input.dm"
function cleanup_request_files --on-event fish_exit
    rm -f "$prepared_source_file"
end

if not test -x "$bootstrapped_compiler"
    echo '未找到 Stage 2 bootstrapped 编译器，先执行自举验证...' >&2
    fish --no-config scripts/bootstrap.fish
    or exit 1
end

mkdir -p "$root_dir/tmp"
rm -f "$output_file"
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
                if string match -q -r '^(if|match|switch|while|for)([[:space:](]|$)' -- "$stripped_line"; or string match -q '* match *' -- "$stripped_line"
                    set copies_top_level_block 1
                end
            end
        else if test $copies_top_level_block -eq 1
            printf '    %s\n' "$source_line" >> "$prepared_source_file"
        end
    end
    printf '\n' >> "$prepared_source_file"
    sed '/^let[[:space:]]/d' "$source_path" >> "$prepared_source_file"
    set request_input_path "$prepared_source_file"
end

"$bootstrapped_compiler" build "$request_input_path" -o "$output_file"
or exit 1

if not test -x "$output_file"
    echo '错误: bootstrapped 编译器没有生成可执行文件' >&2
    exit 1
end

switch $command_name
    case build
    case run
        "$output_file"
    case '*'
        echo "错误: 未知命令 $command_name" >&2
        exit 2
end
