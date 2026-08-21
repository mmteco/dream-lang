open Dream_lib

open Dir_compiler

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

let generate_llvm program =
  let artifact = Dir_compiler.generate program in
  (artifact.llvm_ir, artifact.dir_text)

let compile_program_to_ir input_file =
  (* 重置错误计数器 *)
  Error.reset_counters ();
  Typeck.clear_generic_instances ();

  let source = read_file input_file in
  let ast =
    try
      Module_loader.parse_source source
    with Parser.Error ->
      Printf.eprintf "Parse error\n";
      exit 1
  in

  let full_ast = Module_loader.builtin_enums @ ast in

  (* 设置当前文件路径，用于类型检查中判断是否为标准库 *)
  Typeck.set_current_file input_file;
  let transformed_ast = Typeck.typecheck full_ast in

  (* 检测函数内未使用变量 *)
  Unused_vars.detect transformed_ast;

  (* 打印错误和警告摘要 *)
  Error.print_summary ();

  (* 如果有错误，终止编译 *)
  if Error.has_errors () then begin
    exit 1
  end;

  (* 获取收集到的泛型实例 *)
  let generic_instances = Typeck.get_generic_instances () in

  (* 执行单态化 *)
  let mono_ast = Monomorphize.monomorphize transformed_ast generic_instances in
  let mono_ast = Default_args.fill_default_arguments mono_ast in

  generate_llvm mono_ast

let compile_to_llvm ?(silent=false) input_file =
  let llvm_ir, dir_text = compile_program_to_ir input_file in

  let output_ll = Filename.remove_extension input_file ^ ".ll" in
  write_file output_ll llvm_ir;
  (match dir_text with
   | Some text -> write_file (Filename.remove_extension input_file ^ ".dir") text
   | None -> ());
  if not silent then Printf.printf "Generated LLVM IR: %s\n" output_ll;
  output_ll

let compile_to_dir input_file output_file =
  let _, dir_text = compile_program_to_ir input_file in
  match dir_text with
  | Some text ->
      write_file output_file text;
      Printf.printf "Generated DreamIR: %s\n" output_file
  | None ->
      failwith "DIR compiler did not produce DreamIR text"

let compile_to_exe output_ll =
  let output_exe = Filename.remove_extension output_ll in
  let runtime_files = [
    "runtime/c/core/memory.c";
    "runtime/c/core/dynarray.c";
    "runtime/c/core/utf8.c";
    "runtime/c/core/str.c";
    "runtime/c/core/bytes.c";
    "runtime/c/core/dict.c";
    "runtime/c/core/tuple.c";
    "runtime/c/core/union.c";
    "runtime/c/core/enum.c";
    "runtime/c/core/io.c";
    "runtime/c/core/math.c";
    "runtime/c/core/closure.c";
    "runtime/c/wrappers/utf8.c";
    "runtime/c/wrappers/str.c";
    "runtime/c/wrappers/bytes.c";
    "runtime/c/wrappers/file.c";
    "runtime/c/wrappers/process.c";
    "runtime/c/wrappers/compiler.c"
  ] in
  let runtime_args = String.concat " " runtime_files in
  let compile_cmd = Printf.sprintf
    "clang -Wno-unused-command-line-argument -Wno-override-module -o %s %s %s -I runtime/c/core -I runtime/c/wrappers"
    (Filename.quote output_exe) (Filename.quote output_ll) runtime_args in
  let exit_code = Sys.command compile_cmd in
  if exit_code = 0 then begin
    output_exe
  end else begin
    Printf.eprintf "Compile failed\n";
    exit 1
  end

let build_command input_file =
  try
    let output_ll = compile_to_llvm input_file in
    let output_exe = compile_to_exe output_ll in
    Printf.printf "Build complete: %s\n" output_exe
  with
  | Sys_error msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1
  | Lexer.LexError msg ->
      Printf.eprintf "Lexical error: %s\n" msg;
      exit 1
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1

let run_command input_file =
  try
    (* 获取用户主目录 *)
    let home = try Sys.getenv "HOME" with Not_found -> "." in
    let dream_dir = Filename.concat home ".dream" in
    let cache_dir = Filename.concat dream_dir "cache" in
    let bin_dir = Filename.concat dream_dir "bin" in

    (* 获取基础文件名 *)
    let basename = Filename.basename (Filename.remove_extension input_file) in

    (* 为当前程序创建专属的 cache 目录 *)
    let program_cache_dir = Filename.concat cache_dir basename in

    (* 创建必要的目录 *)
    (try Unix.mkdir dream_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    (try Unix.mkdir cache_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    (try Unix.mkdir program_cache_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    (try Unix.mkdir bin_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());

    (* 生成编译 - 先编译到临时位置 *)
    let temp_ll = compile_to_llvm ~silent:true input_file in
    let temp_exe = compile_to_exe temp_ll in

    (* 移动文件到 .dream 目录 *)
    let final_ll = Filename.concat program_cache_dir (basename ^ ".ll") in
    let final_exe = Filename.concat bin_dir basename in

    (* 移动 .ll 文件到 cache/<程序名>/ 目录 *)
    (try Sys.rename temp_ll final_ll with _ -> ());

    (* 移动可执行文件到 bin/ 目录 *)
    (try
      Sys.rename temp_exe final_exe;
      Unix.chmod final_exe 0o755
    with _ -> ());

    (* 运行程序 *)
    let exit_code = Sys.command final_exe in

    (* 清理生成的文件：删除 bin 文件和 cache 子目录 *)
    (try Sys.remove final_exe with _ -> ());
    (try ignore (Sys.command (Printf.sprintf "rm -rf %s" program_cache_dir)) with _ -> ());

    exit exit_code
  with
  | Sys_error msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1
  | Lexer.LexError msg ->
      Printf.eprintf "Lexical error: %s\n" msg;
      exit 1
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      exit 1

let lsp_command input_file =
  try
    let source = read_file input_file in
    let ast = Module_loader.parse_source source in
    let result = Symbol_analyzer.analyze_program ast source in
    let json = Symbol_analyzer.result_to_json result in
    Printf.printf "%s\n" json;
    exit 0
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
  Printf.printf "Pipeline: DreamIR -> LLVM\n";
  Printf.printf "\n";
  Printf.printf "Commands:\n";
  Printf.printf "  build    Compile the source file to executable\n";
  Printf.printf "  dir      Compile and output canonical DreamIR\n";
  Printf.printf "  run      Compile and run the source file\n";
  Printf.printf "  lsp      Analyze symbols and output JSON for LSP\n";
  Printf.printf "\n";
  Printf.printf "Examples:\n";
  Printf.printf "  dream build examples/test.dm\n";
  Printf.printf "  dream build examples/factorial.dm\n";
  Printf.printf "  dream run examples/test.dm\n";
  Printf.printf "  dream lsp examples/test.dm\n"

let () =
  if Array.length Sys.argv < 2 then begin
    print_usage ();
    exit 1
  end;

  let command = Sys.argv.(1) in

  let parse_input_file first_argument =
    if Array.length Sys.argv <= first_argument then begin
      Printf.eprintf "Error: Missing input file\n\n";
      print_usage ();
      exit 1
    end;
    Sys.argv.(first_argument)
  in

  match command with
  | "build" ->
      let input_file = parse_input_file 2 in
      if not (Filename.check_suffix input_file ".dm") then begin
        Printf.eprintf "Error: Input file must have .dm extension\n";
        exit 1
      end;
      build_command input_file

  | "dir" ->
      let input_file = parse_input_file 2 in
      if Array.length Sys.argv < 5 || Sys.argv.(3) <> "-o" then begin
        Printf.eprintf "Error: dir requires -o <output.dir>\n";
        exit 1
      end;
      let output_file = Sys.argv.(4) in
      if not (Filename.check_suffix input_file ".dm") then begin
        Printf.eprintf "Error: Input file must have .dm extension\n";
        exit 1
      end;
      compile_to_dir input_file output_file

  | "run" ->
      let input_file = parse_input_file 2 in
      if not (Filename.check_suffix input_file ".dm") then begin
        Printf.eprintf "Error: Input file must have .dm extension\n";
        exit 1
      end;
      run_command input_file

  | "lsp" ->
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
      lsp_command input_file

  | "-h" | "--help" | "help" ->
      print_usage ();
      exit 0

  | _ ->
      Printf.eprintf "Error: Unknown command '%s'\n\n" command;
      print_usage ();
      exit 1
