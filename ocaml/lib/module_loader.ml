open Ast

(* 模块路径解析 *)
let entry_file = ref ""

let set_entry_file path =
  entry_file := path

let get_entry_file () =
  !entry_file

let configured_module_paths () =
  match Sys.getenv_opt "DREAM_MODULE_PATH" with
  | None -> []
  | Some paths ->
      paths
      |> String.split_on_char ':'
      |> List.filter (fun path -> path <> "")

let split_import_path module_path =
  let rec split_relative_prefix depth = function
    | "" :: rest -> split_relative_prefix (depth + 1) rest
    | components -> depth, components
  in
  split_relative_prefix 0 module_path

let parent_directory path depth =
  let directory = ref (Filename.dirname path) in
  for _ = 2 to depth do
    directory := Filename.dirname !directory
  done;
  !directory

let module_relative_path components =
  String.concat Filename.dir_sep components ^ ".dm"

let resolve_module_path ?importer_file module_path =
  (* 空字符串前缀表示相对导入，例如 [""; "util"] 是 from .util。 *)
  let relative_depth, components = split_import_path module_path in
  let relative_path = module_relative_path components in
  let importer = Option.value importer_file ~default:!entry_file in
  if relative_depth > 0 then begin
    let directory = parent_directory importer relative_depth in
    let path = Filename.concat directory relative_path in
    if Sys.file_exists path then Some path else None
  end else begin
    let module_name = String.concat "." components in
    if module_name = "prelude" then
      Some "runtime/stdlib/prelude.dm"
    else if module_name = "compiler" then
      Some "runtime/stdlib/compiler.dm"
    else begin
      let standard_paths = [
        "runtime/stdlib";
        "bootstrap";
        "."
      ] in
      let entry_directory = Filename.dirname importer in
      let search_paths = entry_directory :: configured_module_paths () @ standard_paths in
      let rec find_path = function
        | [] -> None
        | directory :: rest ->
            let path = Filename.concat directory relative_path in
            if Sys.file_exists path then Some path else find_path rest
      in
      find_path search_paths
    end
  end

(* 读取文件内容 *)
let read_file filename =
  let ic = open_in filename in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

(* 共享的词法适配器：将源码解析为 AST *)
let parse_source ?(file_path="") source =
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
  try
    Parser.program next_token lexbuf
  with Parser.Error ->
    let pos_info =
      if !token_pos > 0 && !token_pos <= Array.length token_array then
        let (_, p, _) = token_array.(!token_pos - 1) in
        Printf.sprintf "line %d, column %d" p.Lexing.pos_lnum (p.Lexing.pos_cnum - p.Lexing.pos_bol)
      else "unknown position"
    in
    let file_info = if file_path <> "" then file_path ^ ":" else "" in
    failwith (Printf.sprintf "Parse error at %s%s" file_info pos_info)

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
        let ast = parse_source ~file_path source in
        Ok (file_path, ast)
      with
      | Lexer.LexError msg ->
          Error (Printf.sprintf "Lexical error in module: %s" msg)
      | Failure msg ->
          Error msg
      | Parser.Error ->
          Error (Printf.sprintf "Parse error in module %s" file_path)
      | Sys_error msg ->
          Error (Printf.sprintf "System error: %s" msg)

(* 缓存已加载的模块，避免重复解析 *)
let module_cache : (string, program) Hashtbl.t = Hashtbl.create 16

(* 加载模块（带缓存） *)
let load_module ?importer_file module_path =
  match resolve_module_path ?importer_file module_path with
  | None ->
      let module_name = String.concat "." module_path in
      Error (Printf.sprintf "Module not found: %s" module_name)
  | Some file_path ->
  match Hashtbl.find_opt module_cache file_path with
  | Some ast -> Ok (file_path, ast)
  | None ->
      (try
        let source = read_file file_path in
        let ast = parse_source ~file_path source in
        Hashtbl.add module_cache file_path ast;
        Ok (file_path, ast)
      with
      | Lexer.LexError msg -> Error (Printf.sprintf "Lexical error in module: %s" msg)
      | Failure msg -> Error msg
      | Parser.Error -> Error (Printf.sprintf "Parse error in module %s" file_path)
      | Sys_error msg -> Error (Printf.sprintf "System error: %s" msg))

(* 导出的符号类型 *)
type exported_symbol =
  | ExportedFunc of string * def_stmt  (* 函数名 * 函数定义 *)
  | ExportedConst of string * const_stmt  (* 常量名 * 常量定义 *)
  | ExportedLet of string * let_stmt  (* 全局变量名 * 定义 *)
  | ExportedStruct of string * struct_def  (* 结构体名 * 定义 *)
  | ExportedInterface of string * interface_def  (* 接口名 * 定义 *)
  | ExportedEnum of string * enum_def  (* 枚举名 * 定义 *)
  | ExportedImpl of impl_block * position

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
    | SImpl (impl_info, position) -> [ExportedImpl (impl_info, position)]
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
  | ExportedImpl _ -> "__impl__"

(* 导入符号到环境 *)
(* 返回 (name_in_scope, symbol) 对，其中 name_in_scope 是导入后在当前作用域中的名称 *)
let import_symbol (symbol : exported_symbol) (alias : string option) : (string * exported_symbol) =
  let original_name = get_symbol_name symbol in
  let imported_name = match alias with
    | Some a -> a
    | None -> original_name
  in
  (imported_name, symbol)

let is_type_symbol = function
  | ExportedStruct _
  | ExportedInterface _
  | ExportedEnum _ -> true
  | _ -> false

let dependency_type_imports importer_file ast =
  let imported_modules = List.filter_map (function
    | SImport (path, _, _)
    | SFromImport (path, _, _) -> Some path
    | _ -> None
  ) ast in
  let rec collect visited parent_file path =
      match load_module ~importer_file:parent_file path with
      | Error _ -> []
      | Ok (file_path, dependency_ast) ->
          if List.mem file_path visited then []
          else begin
            let own_types = extract_exports dependency_ast
              |> List.filter is_type_symbol
              |> List.map (fun symbol -> import_symbol symbol None) in
            let nested_modules = List.filter_map (function
              | SImport (nested_path, _, _)
              | SFromImport (nested_path, _, _) -> Some nested_path
              | _ -> None
            ) dependency_ast in
            let nested_types = List.concat_map (collect (file_path :: visited) file_path) nested_modules in
            own_types @ nested_types
          end
  in
  List.concat_map (collect [importer_file] importer_file) imported_modules

(* 从模块导入所有符号 *)
let import_all_from_module ?importer_file module_path alias =
  match load_module ?importer_file module_path with
  | Error msg -> Error msg
  | Ok (file_path, ast) ->
      let exports = extract_exports ast in
      let dependency_types = dependency_type_imports file_path ast in
      (* 如果有别名，所有符号都使用 "alias.name" 的形式 *)
      let imports = match alias with
        | None -> List.map (fun sym -> import_symbol sym None) exports
        | Some _ -> List.map (fun sym -> import_symbol sym None) exports
      in
      Ok (dependency_types @ imports)

(* 从模块导入指定符号 *)
let import_selected_from_module ?importer_file module_path selections =
  match load_module ?importer_file module_path with
  | Error msg -> Error msg
  | Ok (file_path, ast) ->
      let exports = extract_exports ast in
      let dependency_types = dependency_type_imports file_path ast in
      if List.exists (fun (name, _) -> name = "*") selections then
        Ok (dependency_types @ List.map (fun symbol -> import_symbol symbol None) exports)
      else
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
           let selected_names = List.map fst selections in
           let imported_types = List.filter_map (function
             | ExportedStruct _ as symbol -> Some (import_symbol symbol None)
             | ExportedInterface _ as symbol -> Some (import_symbol symbol None)
             | ExportedEnum _ as symbol -> Some (import_symbol symbol None)
             | _ -> None
           ) exports in
           let target_name = function
             | TVar name
             | TStruct (name, _) -> Some name
             | _ -> None
           in
           let imported_impls = List.filter_map (function
             | ExportedImpl (impl_info, position) ->
                 (match target_name impl_info.impl_target with
                  | Some name when List.mem name selected_names ->
                      Some (ExportedImpl (impl_info, position))
                  | _ -> None)
             | _ -> None
           ) exports in
           let constant_imports = List.filter_map (function
             | ExportedConst _ as symbol -> Some (import_symbol symbol None)
             | _ -> None
           ) exports in
           let imported_impls = List.map (fun symbol -> import_symbol symbol None) imported_impls in
           Ok (dependency_types @ imported_types @ selected_imports @ imported_impls @ constant_imports))
