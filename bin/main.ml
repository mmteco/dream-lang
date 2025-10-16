open Dream_lib

let read_file filename =
  let ic = open_in filename in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let write_file filename content =
  let oc = open_out filename in
  output_string oc content;
  close_out oc

let compile_to_llvm input_file =
  let source = read_file input_file in

  let tokens = Lexer.tokenize_string source in

  let token_array = Array.of_list tokens in
  let token_pos = ref 0 in
  let next_token _lexbuf =
    if !token_pos < Array.length token_array then begin
      let tok = token_array.(!token_pos) in
      incr token_pos;
      tok
    end else
      Parser.EOF
  in

  let lexbuf = Lexing.from_string source in
  let ast = Parser.program next_token lexbuf in

  Typeck.typecheck ast;

  (* 获取收集到的泛型实例 *)
  let generic_instances = Typeck.get_generic_instances () in

  (* 执行单态化 *)
  let mono_ast = Monomorphize.monomorphize ast generic_instances in

  let llvm_ir = Llvmgen.gen_program mono_ast in

  let output_ll = Filename.remove_extension input_file ^ ".ll" in
  write_file output_ll llvm_ir;
  Printf.printf "Generated LLVM IR: %s\n" output_ll;
  output_ll

let compile_to_exe output_ll =
  let output_exe = Filename.remove_extension output_ll in
  let runtime_files = [
    "runtime/runtime.c";
    "runtime/memory.c";
    "runtime/dynarray.c";
    "runtime/string_ops.c";
    "runtime/file_ops.c";
    "runtime/dict.c";
    "runtime/tuple.c";
    "runtime/union.c";
    "runtime/enum.c"
  ] in
  let runtime_args = String.concat " " runtime_files in
  let compile_cmd = Printf.sprintf
    "clang -Wno-unused-command-line-argument -Wno-override-module -o %s %s %s -I runtime 2>&1 | grep -v \"search path\" || true"
    output_exe output_ll runtime_args in
  let exit_code = Sys.command compile_cmd in
  if exit_code = 0 then begin
    Printf.printf "Compiled successfully: %s\n" output_exe;
    output_exe
  end else begin
    Printf.eprintf "Compilation failed\n";
    exit 1
  end

let build_command input_file =
  try
    let output_ll = compile_to_llvm input_file in
    let output_exe = compile_to_exe output_ll in
    Printf.printf "Build complete: %s\n" output_exe;
    Printf.printf "Run with: ./%s\n" output_exe
  with
  | Sys_error msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1
  | Lexer.LexError msg ->
      Printf.eprintf "Lexical error: %s\n" msg;
      exit 1
  | Parser.Error ->
      Printf.eprintf "Parse error\n";
      exit 1
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1

let run_command input_file =
  try
    let output_ll = compile_to_llvm input_file in
    let output_exe = compile_to_exe output_ll in
    Printf.printf "\n--- Running %s ---\n" output_exe;
    let run_cmd =
      if Filename.is_relative output_exe then
        Printf.sprintf "./%s" output_exe
      else
        output_exe
    in
    let exit_code = Sys.command run_cmd in
    exit exit_code
  with
  | Sys_error msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1
  | Lexer.LexError msg ->
      Printf.eprintf "Lexical error: %s\n" msg;
      exit 1
  | Parser.Error ->
      Printf.eprintf "Parse error\n";
      exit 1
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1

let print_usage () =
  Printf.printf "Usage: dream <command> <input.dm>\n";
  Printf.printf "\n";
  Printf.printf "Commands:\n";
  Printf.printf "  build    Compile the source file to executable\n";
  Printf.printf "  run      Compile and run the source file\n";
  Printf.printf "\n";
  Printf.printf "Examples:\n";
  Printf.printf "  dream build examples/test.dm\n";
  Printf.printf "  dream run examples/test.dm\n"

let () =
  if Array.length Sys.argv < 2 then begin
    print_usage ();
    exit 1
  end;

  let command = Sys.argv.(1) in

  match command with
  | "build" ->
      if Array.length Sys.argv < 3 then begin
        Printf.eprintf "Error: Missing input file\n\n";
        print_usage ();
        exit 1
      end;
      let input_file = Sys.argv.(2) in
      if not (Filename.check_suffix input_file ".dm") then begin
        Printf.eprintf "Error: Input file must have .dm extension\n";
        exit 1
      end;
      build_command input_file

  | "run" ->
      if Array.length Sys.argv < 3 then begin
        Printf.eprintf "Error: Missing input file\n\n";
        print_usage ();
        exit 1
      end;
      let input_file = Sys.argv.(2) in
      if not (Filename.check_suffix input_file ".dm") then begin
        Printf.eprintf "Error: Input file must have .dm extension\n";
        exit 1
      end;
      run_command input_file

  | "-h" | "--help" | "help" ->
      print_usage ();
      exit 0

  | _ ->
      Printf.eprintf "Error: Unknown command '%s'\n\n" command;
      print_usage ();
      exit 1
