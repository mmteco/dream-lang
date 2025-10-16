(* 符号分析器：以作用域为界限建立母子层级关系 *)

open Ast

type symbol_kind =
  | Variable
  | Function
  | Struct
  | Interface
  | Enum
  | Field
  | Method
  | Parameter

(* 位置信息 *)
type location = {
  line: int;
  column: int;
}

type range = {
  start: location;
  end_: location;
}

(* 符号定义 ID *)
type symbol_id = int

(* 符号引用 - 指向某个定义 *)
type symbol_ref = {
  range: range;
  target_id: symbol_id;  (* 指向的定义 ID *)
}

(* 符号定义 - 包含其作用域内的子定义和引用 *)
type symbol_def = {
  id: symbol_id;
  name: string;
  kind: symbol_kind;
  range: range;
  children: symbol_def list;  (* 子定义（嵌套作用域） *)
  references: symbol_ref list;  (* 指向此定义的引用 *)
}

(* 分析结果 *)
type analysis_result = {
  definitions: symbol_def list;  (* 顶层定义列表 *)
}

let kind_to_string = function
  | Variable -> "variable"
  | Function -> "function"
  | Struct -> "struct"
  | Interface -> "interface"
  | Enum -> "enum"
  | Field -> "field"
  | Method -> "method"
  | Parameter -> "parameter"

let escape_json_string s =
  let b = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | _ -> Buffer.add_char b c
  ) s;
  Buffer.contents b

let location_to_json loc =
  Printf.sprintf {|{"line":%d,"column":%d}|} loc.line loc.column

let range_to_json range =
  Printf.sprintf {|{"start":%s,"end":%s}|}
    (location_to_json range.start)
    (location_to_json range.end_)

let ref_to_json (r : symbol_ref) =
  Printf.sprintf
    {|{"range":%s,"targetId":%d}|}
    (range_to_json r.range)
    r.target_id

(* 递归输出定义的 JSON *)
let rec def_to_json def =
  let children_json = String.concat "," (List.map def_to_json def.children) in
  let refs_json = String.concat "," (List.map ref_to_json def.references) in
  Printf.sprintf
    {|{"id":%d,"name":"%s","kind":"%s","range":%s,"children":[%s],"references":[%s]}|}
    def.id
    (escape_json_string def.name)
    (kind_to_string def.kind)
    (range_to_json def.range)
    children_json
    refs_json

let result_to_json result =
  let defs_json = String.concat "," (List.map def_to_json result.definitions) in
  Printf.sprintf {|{"definitions":[%s]}|} defs_json

(* 分析上下文 *)
type context = {
  mutable next_id: symbol_id;
  (* 作用域栈：每层保存 (名称 -> 定义ID) 映射 *)
  mutable scope_stack: (string, symbol_id) Hashtbl.t list;
  (* 所有定义的全局表 *)
  definitions_table: (symbol_id, symbol_def ref) Hashtbl.t;
}

let create_context () = {
  next_id = 0;
  scope_stack = [Hashtbl.create 50];  (* 全局作用域 *)
  definitions_table = Hashtbl.create 100;
}

(* 进入新作用域 *)
let enter_scope ctx =
  let new_scope = Hashtbl.create 20 in
  ctx.scope_stack <- new_scope :: ctx.scope_stack

(* 离开作用域 *)
let exit_scope ctx =
  match ctx.scope_stack with
  | _ :: rest -> ctx.scope_stack <- rest
  | [] -> failwith "Cannot exit global scope"

(* 在当前作用域查找符号 *)
let rec lookup_in_scopes scopes name =
  match scopes with
  | [] -> None
  | scope :: rest ->
      match Hashtbl.find_opt scope name with
      | Some id -> Some id
      | None -> lookup_in_scopes rest name

(* 添加定义到当前作用域 *)
let add_definition ctx name kind (pos : Ast.position) =
  let def_id = ctx.next_id in
  ctx.next_id <- ctx.next_id + 1;

  let def_ref = ref {
    id = def_id;
    name;
    kind;
    range = {
      start = { line = pos.line; column = pos.column };
      end_ = { line = pos.line; column = pos.column + String.length name };
    };
    children = [];
    references = [];
  } in

  Hashtbl.add ctx.definitions_table def_id def_ref;

  (* 在当前作用域注册 *)
  (match ctx.scope_stack with
   | current :: _ -> Hashtbl.replace current name def_id
   | [] -> failwith "No scope");

  def_id

(* 添加引用 *)
let add_reference ctx name (pos : Ast.position) =
  match lookup_in_scopes ctx.scope_stack name with
  | Some target_id ->
      let ref_data = {
        range = {
          start = { line = pos.line; column = pos.column };
          end_ = { line = pos.line; column = pos.column + String.length name };
        };
        target_id;
      } in
      (* 将引用添加到目标定义 *)
      let def_ref = Hashtbl.find ctx.definitions_table target_id in
      def_ref := { !def_ref with references = ref_data :: (!def_ref).references }
  | None -> ()  (* 未找到定义，忽略（可能是未定义的变量） *)

(* 分析表达式 *)
let rec analyze_expr ctx expr =
  match expr with
  | EVar (name, pos) ->
      add_reference ctx name pos

  | ECall (func, args, _) ->
      analyze_expr ctx func;
      List.iter (analyze_expr ctx) args

  | EBinOp (e1, _, e2, _) ->
      analyze_expr ctx e1;
      analyze_expr ctx e2

  | EUnOp (_, e, _) ->
      analyze_expr ctx e

  | EList (elems, _) ->
      List.iter (analyze_expr ctx) elems

  | ETuple (elems, _) ->
      List.iter (analyze_expr ctx) elems

  | EDict (pairs, _) ->
      List.iter (fun (k, v) -> analyze_expr ctx k; analyze_expr ctx v) pairs

  | EIndex (arr, idx, _) ->
      analyze_expr ctx arr;
      analyze_expr ctx idx

  | ESlice (arr, start_opt, end_opt, _) ->
      analyze_expr ctx arr;
      (match start_opt with Some e -> analyze_expr ctx e | None -> ());
      (match end_opt with Some e -> analyze_expr ctx e | None -> ())

  | EAttr (obj, _attr, _pos) ->
      analyze_expr ctx obj

  | EIf (cond, then_expr, else_opt, _) ->
      analyze_expr ctx cond;
      analyze_expr ctx then_expr;
      (match else_opt with Some e -> analyze_expr ctx e | None -> ())

  | EMatch (scrut, cases, _) ->
      analyze_expr ctx scrut;
      List.iter (fun (_, guard_opt, body) ->
        (match guard_opt with Some g -> analyze_expr ctx g | None -> ());
        analyze_expr ctx body
      ) cases

  | ELambda (params, body, _) ->
      enter_scope ctx;
      List.iter (fun (name, _) ->
        let _ = add_definition ctx name Parameter {line = 0; column = 0} in ()
      ) params;
      analyze_expr ctx body;
      exit_scope ctx

  | EListComp (elem, _var, iter, cond_opt, _) ->
      analyze_expr ctx elem;
      analyze_expr ctx iter;
      (match cond_opt with Some c -> analyze_expr ctx c | None -> ())

  | EEnumVariant (enum_name, _variant, args, pos) ->
      add_reference ctx enum_name pos;
      List.iter (analyze_expr ctx) args

  | EStructLiteral (struct_name, fields, pos) ->
      add_reference ctx struct_name pos;
      List.iter (fun (_, expr) -> analyze_expr ctx expr) fields

  | EStructAccess (obj, _field, _) ->
      analyze_expr ctx obj

  | EInt _ | EFloat _ | EString _ | EBool _ -> ()

(* 分析语句，返回子定义列表 *)
let rec analyze_stmt ctx stmt : symbol_def list =
  match stmt with
  | SLet let_info ->
      (* 先分析右值 *)
      analyze_expr ctx let_info.let_value;
      (* 定义变量 *)
      let def_id = add_definition ctx let_info.let_name Variable let_info.let_name_pos in
      let def_ref = Hashtbl.find ctx.definitions_table def_id in
      [!def_ref]

  | SLetPat (_, value, _) ->
      analyze_expr ctx value;
      []

  | SAssign (name, value, pos) ->
      add_reference ctx name pos;
      analyze_expr ctx value;
      []

  | SDef def_info ->
      (* 定义函数 *)
      let def_id = add_definition ctx def_info.def_name Function def_info.def_name_pos in
      (* 进入函数作用域 *)
      enter_scope ctx;
      (* 添加参数，记录 ID *)
      let param_ids = List.map (fun (param_name, _) ->
        add_definition ctx param_name Parameter
          {line = def_info.def_name_pos.line + 1; column = 4}
      ) def_info.def_params in
      (* 分析函数体，记录子定义的 ID *)
      let body_defs = List.concat (List.map (analyze_stmt ctx) def_info.def_body) in
      let body_ids = List.map (fun def -> def.id) body_defs in
      exit_scope ctx;
      (* 在函数体分析完成后，获取所有子定义的最新状态 *)
      let param_defs = List.map (fun param_id ->
        let param_ref = Hashtbl.find ctx.definitions_table param_id in
        !param_ref
      ) param_ids in
      let body_defs_updated = List.map (fun body_id ->
        let body_ref = Hashtbl.find ctx.definitions_table body_id in
        !body_ref
      ) body_ids in
      (* 更新函数定义的 children *)
      let def_ref = Hashtbl.find ctx.definitions_table def_id in
      def_ref := { !def_ref with children = param_defs @ body_defs_updated };
      [!def_ref]

  | SStruct struct_info ->
      let def_id = add_definition ctx struct_info.struct_name Struct struct_info.struct_name_pos in
      enter_scope ctx;
      (* 处理成员，记录 ID *)
      let member_defs = List.concat (List.map (function
        | SField field ->
            (match field.field_name with
             | Some name ->
                 let field_id = add_definition ctx name Field field.field_pos in
                 let field_ref = Hashtbl.find ctx.definitions_table field_id in
                 [!field_ref]
             | None ->
                 (* 匿名嵌入字段,不创建定义 *)
                 [])
        | SMethod (method_name, _, params, _, body, method_pos) ->
            let method_id = add_definition ctx method_name Method method_pos in
            enter_scope ctx;
            (* 添加参数，记录 ID *)
            let param_ids = List.map (fun (param_name, _) ->
              add_definition ctx param_name Parameter
                {line = method_pos.line; column = 0}
            ) params in
            (* 分析方法体，记录子定义的 ID *)
            let body_defs = List.concat (List.map (analyze_stmt ctx) body) in
            let body_ids = List.map (fun def -> def.id) body_defs in
            exit_scope ctx;
            (* 在方法体分析完成后，获取所有子定义的最新状态 *)
            let param_defs = List.map (fun param_id ->
              let param_ref = Hashtbl.find ctx.definitions_table param_id in
              !param_ref
            ) param_ids in
            let body_defs_updated = List.map (fun body_id ->
              let body_ref = Hashtbl.find ctx.definitions_table body_id in
              !body_ref
            ) body_ids in
            (* 更新方法定义的 children *)
            let method_ref = Hashtbl.find ctx.definitions_table method_id in
            method_ref := { !method_ref with children = param_defs @ body_defs_updated };
            [!method_ref]
      ) struct_info.struct_members) in
      let member_ids = List.map (fun def -> def.id) member_defs in
      exit_scope ctx;
      (* 获取所有成员的最终状态 *)
      let member_defs_updated = List.map (fun member_id ->
        let member_ref = Hashtbl.find ctx.definitions_table member_id in
        !member_ref
      ) member_ids in
      (* 更新结构体定义的 children *)
      let def_ref = Hashtbl.find ctx.definitions_table def_id in
      def_ref := { !def_ref with children = member_defs_updated };
      [!def_ref]

  | SInterface interface_info ->
      let def_id = add_definition ctx interface_info.interface_name Interface interface_info.interface_name_pos in
      let def_ref = Hashtbl.find ctx.definitions_table def_id in
      [!def_ref]

  | SEnum enum_info ->
      let def_id = add_definition ctx enum_info.enum_name Enum enum_info.enum_name_pos in
      let def_ref = Hashtbl.find ctx.definitions_table def_id in
      [!def_ref]

  | SIf (cond, then_body, elifs, else_opt, _) ->
      analyze_expr ctx cond;
      enter_scope ctx;
      let then_defs = List.concat (List.map (analyze_stmt ctx) then_body) in
      exit_scope ctx;

      let elif_defs = List.concat (List.map (fun (elif_cond, elif_body) ->
        analyze_expr ctx elif_cond;
        enter_scope ctx;
        let defs = List.concat (List.map (analyze_stmt ctx) elif_body) in
        exit_scope ctx;
        defs
      ) elifs) in

      let else_defs = match else_opt with
        | Some else_body ->
            enter_scope ctx;
            let defs = List.concat (List.map (analyze_stmt ctx) else_body) in
            exit_scope ctx;
            defs
        | None -> []
      in
      then_defs @ elif_defs @ else_defs

  | SWhile (cond, body, _) ->
      analyze_expr ctx cond;
      enter_scope ctx;
      let defs = List.concat (List.map (analyze_stmt ctx) body) in
      exit_scope ctx;
      defs

  | SFor (_, iter, body, _) ->
      analyze_expr ctx iter;
      enter_scope ctx;
      let defs = List.concat (List.map (analyze_stmt ctx) body) in
      exit_scope ctx;
      defs

  | SMatch (scrut, cases, _) ->
      analyze_expr ctx scrut;
      List.concat (List.map (fun (_, guard_opt, body) ->
        (match guard_opt with Some g -> analyze_expr ctx g | None -> ());
        enter_scope ctx;
        let defs = List.concat (List.map (analyze_stmt ctx) body) in
        exit_scope ctx;
        defs
      ) cases)

  | SExpr (expr, _) ->
      analyze_expr ctx expr;
      []

  | SReturn (Some expr, _) ->
      analyze_expr ctx expr;
      []

  | SReturn (None, _) -> []

  | SFieldAssign (obj, _, value, _) ->
      analyze_expr ctx obj;
      analyze_expr ctx value;
      []

  | SIndexAssign (arr, idx, value, _) ->
      analyze_expr ctx arr;
      analyze_expr ctx idx;
      analyze_expr ctx value;
      []

  | SImpl _ | SImport _ | SFromImport _ -> []

(* 主分析函数 *)
let analyze_program ast _source =
  let ctx = create_context () in
  (* 分析所有顶层语句，记录 ID *)
  let top_level_defs = List.concat (List.map (analyze_stmt ctx) ast) in
  let top_level_ids = List.map (fun def -> def.id) top_level_defs in
  (* 在所有分析完成后，获取最终状态 *)
  let final_defs = List.map (fun def_id ->
    let def_ref = Hashtbl.find ctx.definitions_table def_id in
    !def_ref
  ) top_level_ids in
  { definitions = final_defs }
