#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set compiler "$root_dir/ocaml/_build/default/bin/main.exe"
cd "$root_dir"

function build_source
    set source_file $argv[1]
    $compiler build "$source_file"
end

function run_source
    set source_file $argv[1]
    set executable (string replace -r '\.dm$' '' "$source_file")
    "./$executable"
end

function smoke_examples
    for source_file in (find examples -maxdepth 1 -type f -name '*.dm' | sort)
        if rg -q '^# dream-test: smoke$' "$source_file"
            build_source "$source_file"
            or return 1
        end
    end
end

function run_smoke_examples
    for source_file in (find examples -maxdepth 1 -type f -name '*.dm' | sort)
        if rg -q '^# dream-test: smoke$' "$source_file"
            printf '\n=== 测试 %s ===\n' "$source_file"
            run_source "$source_file"
        end
    end
end

function run_marked_dir_examples
    for source_file in (find examples -maxdepth 1 -type f -name '*.dm' | sort)
        if rg -q '^# dream-test: dir$' "$source_file"
            printf '\n=== 测试 %s [dir] ===\n' "$source_file"
            build_source "$source_file"
            or return 1
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
        smoke_examples
        or exit 1
    case all
        smoke_examples
        or exit 1
        run_smoke_examples
        run_marked_dir_examples
        or exit 1
        run_dir_tests
        or exit 1
    case '*'
        echo '用法: scripts/test.fish examples|all' >&2
        exit 2
end
