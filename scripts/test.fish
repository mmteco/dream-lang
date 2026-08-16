#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set compiler "$root_dir/_build/default/bin/main.exe"
cd "$root_dir"

function build_source
    set source_file $argv[1]
    set backend $argv[2]
    if test "$backend" = dir
        $compiler build --backend=dir "$source_file"
    else
        $compiler build "$source_file"
    end
end

function run_source
    set source_file $argv[1]
    set executable (string replace -r '\.dm$' '' "$source_file")
    "./$executable"
end

function smoke_examples
    for source_file in (find examples -maxdepth 1 -type f -name '*.dm' | sort)
        if rg -q '^# dream-test: smoke$' "$source_file"
            build_source "$source_file" legacy
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
            build_source "$source_file" dir
            or return 1
            run_source "$source_file"
        end
    end
end

function run_marked_legacy_tests
    for source_file in (find test -maxdepth 1 -type f -name '*.dm' | sort)
        if rg -q '^# dream-test: legacy$' "$source_file"
            printf '\n=== 测试 %s ===\n' "$source_file"
            build_source "$source_file" legacy
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
        build_source "$source_file" dir
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
        run_marked_legacy_tests
        or exit 1
        run_dir_tests
        or exit 1
    case '*'
        echo '用法: scripts/test.fish examples|all' >&2
        exit 2
end
