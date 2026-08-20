#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"
mkdir -p tmp

set llvm_files $argv
if test (count $llvm_files) -eq 0
    set llvm_files (find tmp -maxdepth 1 -type f -name '*.ll' | sort)
end

if test (count $llvm_files) -eq 0
    echo '错误: 没有找到待验证的 LLVM 文件' >&2
    exit 1
end

for llvm_file in $llvm_files
    set log_file "tmp/"(basename "$llvm_file")'.verify.log'
    if not test -f "$llvm_file"
        echo "错误: 缺少 $llvm_file" >&2
        exit 1
    end
    if not clang -Wno-override-module -c -o /dev/null -x ir "$llvm_file" >"$log_file" 2>&1
        echo "错误: LLVM 验证失败: $llvm_file" >&2
        cat "$log_file" >&2
        exit 1
    end
    rm -f "$log_file"
end
