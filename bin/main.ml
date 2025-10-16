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

let compile_to_llvm ?(silent=false) input_file =
  (* 重置错误计数器 *)
  Error.reset_counters ();

  let source = read_file input_file in

  let tokens_with_pos = Lexer.tokenize_string_with_pos source in

  let token_array = Array.of_list tokens_with_pos in
  let token_pos = ref 0 in
  let next_token lexbuf =
    if !token_pos < Array.length token_array then begin
      let (tok, start_pos, end_pos) = token_array.(!token_pos) in
      incr token_pos;
      (* 更新 lexbuf 的位置，使 parser 的 $startpos 和 $endpos 能获取正确位置 *)
      lexbuf.Lexing.lex_start_p <- start_pos;
      lexbuf.Lexing.lex_curr_p <- end_pos;
      tok
    end else
      Parser.EOF
  in

  let lexbuf = Lexing.from_string source in
  let ast = Parser.program next_token lexbuf in

  (* 在用户代码前插入内置枚举定义 *)
  (* 暂时使用 int 类型，避免泛型复杂性 *)
  let builtin_enums = [
    Ast.SEnum {
      enum_name = "Option";
      enum_name_pos = {line = 0; column = 0};
      enum_type_params = [];
      enum_variants = [
        Ast.VTuple ("Some", [Ast.TInt], {line = 0; column = 0});
        Ast.VSimple ("None", {line = 0; column = 0})
      ];
      enum_pos = {line = 0; column = 0};
    };
    Ast.SEnum {
      enum_name = "Result";
      enum_name_pos = {line = 0; column = 0};
      enum_type_params = [];
      enum_variants = [
        Ast.VTuple ("Ok", [Ast.TInt], {line = 0; column = 0});
        Ast.VTuple ("Err", [Ast.TInt], {line = 0; column = 0})
      ];
      enum_pos = {line = 0; column = 0};
    }
  ] in
  let full_ast = builtin_enums @ ast in

  Typeck.typecheck full_ast;

  (* 打印错误和警告摘要 *)
  Error.print_summary ();

  (* 如果有错误，终止编译 *)
  if Error.has_errors () then begin
    exit 1
  end;

  (* 获取收集到的泛型实例 *)
  let generic_instances = Typeck.get_generic_instances () in

  (* 执行单态化 *)
  let mono_ast = Monomorphize.monomorphize full_ast generic_instances in

  let llvm_ir = Llvmgen.gen_program mono_ast in

  let output_ll = Filename.remove_extension input_file ^ ".ll" in
  write_file output_ll llvm_ir;
  if not silent then Printf.printf "Generated LLVM IR: %s\n" output_ll;
  output_ll

let compile_to_exe ?(silent=false) output_ll =
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
    if not silent then Printf.printf "Compiled successfully: %s\n" output_exe;
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
    let temp_exe = compile_to_exe ~silent:true temp_ll in

    (* 移动文件到 .dream 目录 *)
    let final_ll = Filename.concat program_cache_dir (basename ^ ".ll") in
    let final_exe = Filename.concat bin_dir basename in

    (* 移动 .ll 文件到 cache/<程序名>/ 目录 *)
    (try
      let ic = open_in temp_ll in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      let oc = open_out final_ll in
      output_string oc content;
      close_out oc;
      Sys.remove temp_ll
    with _ -> ());

    (* 移动可执行文件到 bin/ 目录 *)
    (try
      let copy_cmd = Printf.sprintf "cp %s %s && chmod +x %s" temp_exe final_exe final_exe in
      ignore (Sys.command copy_cmd);
      Sys.remove temp_exe
    with _ -> ());

    (* 运行程序 *)
    let exit_code = Sys.command final_exe in

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

let lsp_command input_file =
  try
    (* LSP 分析使用带位置信息的 tokenize，确保位置信息准确 *)
    let source = read_file input_file in
    let tokens_with_pos = Lexer.tokenize_string_with_pos source in

    let token_array = Array.of_list tokens_with_pos in
    let token_pos = ref 0 in
    let next_token lexbuf =
      if !token_pos < Array.length token_array then begin
        let (tok, start_pos, end_pos) = token_array.(!token_pos) in
        incr token_pos;
        (* 更新 lexbuf 的位置，使 parser 的 $startpos 和 $endpos 能获取正确位置 *)
        (* Menhir 使用 lex_start_p 作为 token 的起始位置, lex_curr_p 作为结束位置 *)
        lexbuf.Lexing.lex_start_p <- start_pos;
        lexbuf.Lexing.lex_curr_p <- end_pos;
        tok
      end else
        Parser.EOF
    in
    let lexbuf = Lexing.from_string source in
    let ast = Parser.program next_token lexbuf in
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
  Printf.printf "\n";
  Printf.printf "Commands:\n";
  Printf.printf "  build    Compile the source file to executable\n";
  Printf.printf "  run      Compile and run the source file\n";
  Printf.printf "  lsp      Analyze symbols and output JSON for LSP\n";
  Printf.printf "\n";
  Printf.printf "Examples:\n";
  Printf.printf "  dream build examples/test.dm\n";
  Printf.printf "  dream run examples/test.dm\n";
  Printf.printf "  dream lsp examples/test.dm\n"

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
