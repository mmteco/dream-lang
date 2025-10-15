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

let compile_file input_file =
  try
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

    let c_code = Codegen.gen_program ast in

    let output_c = Filename.remove_extension input_file ^ ".c" in
    write_file output_c c_code;
    Printf.printf "Generated C code: %s\n" output_c;

    let output_exe = Filename.remove_extension input_file in
    let compile_cmd = Printf.sprintf "gcc -o %s %s" output_exe output_c in
    let exit_code = Sys.command compile_cmd in
    if exit_code = 0 then begin
      Printf.printf "Compiled successfully: %s\n" output_exe;
      Printf.printf "Run with: ./%s\n" output_exe
    end else begin
      Printf.eprintf "Compilation failed\n";
      exit 1
    end

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

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.printf "Usage: %s <input.dm>\n" Sys.argv.(0);
    exit 1
  end;

  let input_file = Sys.argv.(1) in
  if not (Filename.check_suffix input_file ".dm") then begin
    Printf.eprintf "Error: Input file must have .dm extension\n";
    exit 1
  end;

  compile_file input_file
