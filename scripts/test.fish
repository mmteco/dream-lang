#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set compiler "$root_dir/ocaml/_build/default/bin/main.exe"
cd "$root_dir"
set -lx DREAM_MODULE_PATH "$root_dir/test/fixtures"

function build_source
    set source_file $argv[1]
    $compiler build "$source_file"
end

function run_source
    set source_file $argv[1]
    set executable (string replace -r '\.dm$' '' "$source_file")
    "./$executable"
end

function run_examples
    set mode $argv[1]
    for source_file in (find examples -maxdepth 1 -type f -name '*.dm' | sort)
        set example_kind ""
        if rg -q '^# dream-test: smoke$' "$source_file"
            set example_kind smoke
        else if rg -q '^# dream-test: dir$' "$source_file"
            set example_kind dir
        else
            continue
        end

        if test "$mode" = examples; and test "$example_kind" != smoke
            continue
        end

        printf '\n=== 测试 %s ===\n' "$source_file"
        build_source "$source_file"
        or return 1
        if test "$mode" = all
            run_source "$source_file"
        end
    end
end

function run_dir_tests
    for source_file in (find test -maxdepth 1 -type f -name '*.dm' | sort)
        if not string match -q '*_dir.dm' "$source_file"
            if not rg -q '^# dream-test: dir$' "$source_file"
                continue
            end
        end
        printf '\n=== 测试 %s ===\n' "$source_file"
        build_source "$source_file"
        or return 1
        run_source "$source_file"
    end
end

set mode all
if test (count $argv) -gt 0
    set mode $argv[1]
end

switch $mode
    case examples
        run_examples examples
        or exit 1
    case all
        run_examples all
        or exit 1
        run_dir_tests
        or exit 1
    case '*'
        echo '用法: scripts/test.fish examples|all' >&2
        exit 2
end
