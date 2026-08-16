#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

dune clean
find examples -maxdepth 1 -type f ! -name '*.dm' -delete
find bootstrap -maxdepth 1 -type f ! -name '*.dm' -delete
find test -maxdepth 1 -type f -name 'test_*' ! -name '*.dm' -delete
make -C runtime clean
find tmp -maxdepth 1 -type f \( \
    -name 'dream_bootstrap_*' \
    -o -name 'bootstrap_*' \
    -o -name 'dynarray_bootstrap_bin' \
    -o -name 'comment.ll' \
    -o -name 'dynarray_bootstrap.out' \
    -o -name 'factorial_bootstrap.out' \
    -o -name 'for_bootstrap.out' \
    -o -name 'for_struct_bin' \
    -o -name 'for_struct.dm' \
    -o -name 'hello_bootstrap.out' \
    -o -name 'manual_bootstrap.ll' \
    -o -name 'simple.ll' \
    -o -name 'stage2_debug.out' \
    -o -name 'struct_bin' \
    -o -name 'token_debug' \
    -o -name 'token_debug.dm' \
\) -delete
