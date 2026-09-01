#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set compiler "$root_dir/ocaml/_build/default/bin/main.exe"
set source_file "$root_dir/test/module_path_main.dm"
set output_file "$root_dir/tmp/module_path_test"

cd "$root_dir"
env -u DREAM_MODULE_PATH "$compiler" build "$source_file" -o "$output_file"
or exit 1

set actual (env -u DREAM_MODULE_PATH "$output_file")
if test (count $actual) -ne 2; or test "$actual[1]" != 7; or test "$actual[2]" != 35
    echo "模块路径回归失败"
    echo "期望:"
    echo '7'
    echo '35'
    echo "实际:"
    string escape -- $actual
    exit 1
end

echo "模块路径回归通过: 入口目录搜索和相对导入"
