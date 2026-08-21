open Ast

(* 模块路径解析 *)
let resolve_module_path module_path =
  (* module_path 是 string list，例如 ["file"] 或 ["os", "path"] *)
  let module_name = String.concat "." module_path in

  (* 尝试在 stdlib 目录查找 *)
  let stdlib_path = "runtime/stdlib/" ^ module_name ^ ".dm" in
  if Sys.file_exists stdlib_path then
    Some stdlib_path
  else
    (* 尝试在 bootstrap 目录查找 *)
    let bootstrap_path = "bootstrap/" ^ module_name ^ ".dm" in
    if Sys.file_exists bootstrap_path then
      Some bootstrap_path
    else
      (* 尝试在当前目录查找 *)
      let local_path = module_name ^ ".dm" in
      if Sys.file_exists local_path then
        Some local_path
      else
        None

(* 读取文件内容 *)
let read_file filename =
  let ic = open_in filename in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

(* 共享的词法适配器：将源码解析为 AST *)
let parse_source source =
  let tokens_with_pos = Lexer.tokenize_string_with_pos source in
  let token_array = Array.of_list tokens_with_pos in
  let token_pos = ref 0 in
  let next_token lexbuf =
    if !token_pos < Array.length token_array then begin
      let (tok, start_pos, end_pos) = token_array.(!token_pos) in
      incr token_pos;
      lexbuf.Lexing.lex_start_p <- start_pos;
      lexbuf.Lexing.lex_curr_p <- end_pos;
      tok
    end else
      Parser.EOF
  in
  let lexbuf = Lexing.from_string source in
  Parser.program next_token lexbuf

(* 内置枚举定义：Option 和 Result *)
let builtin_enums = [
  SEnum {
    enum_name = "Option";
    enum_name_pos = {line = 0; column = 0};
    enum_type_params = [];
    enum_variants = [
      VTuple ("Some", [TInt], {line = 0; column = 0});
      VSimple ("None", {line = 0; column = 0})
    ];
    enum_pos = {line = 0; column = 0};
  };
  SEnum {
    enum_name = "Result";
    enum_name_pos = {line = 0; column = 0};
    enum_type_params = [];
    enum_variants = [
      VTuple ("Ok", [TInt], {line = 0; column = 0});
      VTuple ("Err", [TInt], {line = 0; column = 0})
    ];
    enum_pos = {line = 0; column = 0};
  }
]

(* 解析模块文件 *)
let parse_module module_path =
  match resolve_module_path module_path with
  | None ->
      let module_name = String.concat "." module_path in
      Error (Printf.sprintf "Module not found: %s" module_name)
  | Some file_path ->
      try
        let source = read_file file_path in
        let ast = parse_source source in
        Ok (file_path, ast)
      with
      | Lexer.LexError msg ->
          Error (Printf.sprintf "Lexical error in module: %s" msg)
      | Parser.Error ->
          Error (Printf.sprintf "Parse error in module")
      | Sys_error msg ->
          Error (Printf.sprintf "System error: %s" msg)

(* 缓存已加载的模块，避免重复解析 *)
let module_cache : (string list, program) Hashtbl.t = Hashtbl.create 16

(* 加载模块（带缓存） *)
let load_module module_path =
  match Hashtbl.find_opt module_cache module_path with
  | Some ast -> Ok ("(cached)", ast)
  | None ->
      match parse_module module_path with
      | Ok (file_path, ast) ->
          Hashtbl.add module_cache module_path ast;
          Ok (file_path, ast)
      | Error msg -> Error msg

(* 导出的符号类型 *)
type exported_symbol =
  | ExportedFunc of string * def_stmt  (* 函数名 * 函数定义 *)
  | ExportedConst of string * const_stmt  (* 常量名 * 常量定义 *)
  | ExportedLet of string * let_stmt  (* 全局变量名 * 定义 *)
  | ExportedStruct of string * struct_def  (* 结构体名 * 定义 *)
  | ExportedInterface of string * interface_def  (* 接口名 * 定义 *)
  | ExportedEnum of string * enum_def  (* 枚举名 * 定义 *)

(* 从 AST 中提取所有顶层导出的符号 *)
let extract_exports (ast : program) : exported_symbol list =
  let extract_from_stmt stmt =
    match stmt with
    | SDef def_info -> [ExportedFunc (def_info.def_name, def_info)]
    | SConst const_info -> [ExportedConst (const_info.const_name, const_info)]
    | SLet let_info -> [ExportedLet (let_info.let_name, let_info)]
    | SStruct struct_info -> [ExportedStruct (struct_info.struct_name, struct_info)]
    | SInterface interface_info -> [ExportedInterface (interface_info.interface_name, interface_info)]
    | SEnum enum_info -> [ExportedEnum (enum_info.enum_name, enum_info)]
    | _ -> []
  in
  List.concat_map extract_from_stmt ast

(* 获取符号的名称 *)
let get_symbol_name = function
  | ExportedFunc (name, _) -> name
  | ExportedConst (name, _) -> name
  | ExportedLet (name, _) -> name
  | ExportedStruct (name, _) -> name
  | ExportedInterface (name, _) -> name
  | ExportedEnum (name, _) -> name

(* 导入符号到环境 *)
(* 返回 (name_in_scope, symbol) 对，其中 name_in_scope 是导入后在当前作用域中的名称 *)
let import_symbol (symbol : exported_symbol) (alias : string option) : (string * exported_symbol) =
  let original_name = get_symbol_name symbol in
  let imported_name = match alias with
    | Some a -> a
    | None -> original_name
  in
  (imported_name, symbol)

(* 从模块导入所有符号 *)
let import_all_from_module module_path alias =
  match load_module module_path with
  | Error msg -> Error msg
  | Ok (_, ast) ->
      let exports = extract_exports ast in
      (* 如果有别名，所有符号都使用 "alias.name" 的形式 *)
      let imports = match alias with
        | None -> List.map (fun sym -> import_symbol sym None) exports
        | Some _ ->
            (* 有别名时，只导入模块本身，不导入具体符号 *)
            (* 这里暂时简化处理，返回空列表 *)
            []
      in
      Ok imports

(* 从模块导入指定符号 *)
let import_selected_from_module module_path selections =
  match load_module module_path with
  | Error msg -> Error msg
  | Ok (_, ast) ->
      let exports = extract_exports ast in
      (* 为每个选择查找对应的符号 *)
      let rec find_and_import selections acc =
        match selections with
        | [] -> Ok (List.rev acc)
        | (name, alias) :: rest ->
            match List.find_opt (fun sym -> get_symbol_name sym = name) exports with
            | None ->
                Error (Printf.sprintf "Symbol '%s' not found in module" name)
            | Some symbol ->
                let imported = import_symbol symbol alias in
                find_and_import rest (imported :: acc)
      in
      (match find_and_import selections [] with
       | Error msg -> Error msg
       | Ok selected_imports ->
           let constant_imports = List.filter_map (function
             | ExportedConst _ as symbol -> Some (import_symbol symbol None)
             | _ -> None
           ) exports in
           Ok (selected_imports @ constant_imports))
