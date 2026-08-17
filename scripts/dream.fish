#!/usr/bin/env fish

if test (count $argv) -ne 2
    echo '用法: scripts/dream.fish build|run <file.dm>' >&2
    exit 2
end

set command_name $argv[1]
set source_file $argv[2]
set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set compiler "$root_dir/_build/default/bin/main.exe"

if not test -x "$compiler"
    echo '错误: 编译器不存在，请先执行 dune build' >&2
    exit 1
end

set compiler_arguments build
set -a compiler_arguments "$source_file"

cd "$root_dir"
$compiler $compiler_arguments
or exit 1

switch $command_name
    case build
    case run
        set executable (string replace -r '\.dm$' '' "$source_file")
        "./$executable"
    case '*'
        echo "错误: 未知命令 $command_name" >&2
        exit 2
end
