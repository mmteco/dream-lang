#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
cd "$root_dir"

cd ocaml && dune clean
cd "$root_dir"
find examples -maxdepth 1 -type f ! -name '*.dm' -delete
find bootstrap -maxdepth 1 -type f ! -name '*.dm' ! -name 'README.md' -delete
find test -maxdepth 1 -type f -name 'test_*' ! -name '*.dm' -delete
make -C runtime/c clean
find tmp -maxdepth 1 -type f -delete
