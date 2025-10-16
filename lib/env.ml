open Types
open Ast

module StringMap = Map.Make(String)

(* 接口定义 *)
type interface_def = {
  iface_name: string;
  iface_type_params: string list;
  iface_members: interface_member list;
}

(* impl块定义 *)
type impl_def = {
  impl_interface_name: string;
  impl_target_type: ty;
  impl_methods: ty StringMap.t;  (* 方法名 -> 方法类型 *)
}

(* 结构体定义 *)
type struct_def = {
  struct_name: string;
  struct_type_params: string list;
  struct_fields: (string * ty) list;  (* 字段名 -> 字段类型 *)
  struct_methods: ty StringMap.t;  (* 方法名 -> 方法类型 *)
}

type env = {
  bindings: ty StringMap.t;
  parent: env option;
  locked: string list;
  interfaces: interface_def StringMap.t;  (* 接口名 -> 接口定义 *)
  impls: impl_def list;  (* 所有impl块 *)
  structs: struct_def StringMap.t;  (* 结构体名 -> 结构体定义 *)
  default_params: expr option list StringMap.t;  (* 函数名 -> 默认参数列表 *)
}

let empty_env = {
  bindings = StringMap.empty;
  parent = None;
  locked = [];
  interfaces = StringMap.empty;
  impls = [];
  structs = StringMap.empty;
  default_params = StringMap.empty;
}

let create_child_env parent = {
  bindings = StringMap.empty;
  parent = Some parent;
  locked = [];
  interfaces = parent.interfaces;  (* 继承父环境的接口定义 *)
  impls = parent.impls;  (* 继承父环境的impl块 *)
  structs = parent.structs;  (* 继承父环境的结构体定义 *)
  default_params = parent.default_params;  (* 继承父环境的默认参数 *)
}

let add_binding name ty env =
  { env with bindings = StringMap.add name ty env.bindings }

let add_function_with_defaults name ty defaults env =
  let env' = add_binding name ty env in
  { env' with default_params = StringMap.add name defaults env'.default_params }

let get_function_defaults name env =
  let rec lookup env =
    match StringMap.find_opt name env.default_params with
    | Some defaults -> Some defaults
    | None ->
        match env.parent with
        | Some parent -> lookup parent
        | None -> None
  in
  lookup env

let lock_binding name env =
  { env with locked = name :: env.locked }

let is_locked name env =
  List.mem name env.locked

let rec find_binding name env =
  match StringMap.find_opt name env.bindings with
  | Some ty -> Some ty
  | None ->
      match env.parent with
      | Some parent -> find_binding name parent
      | None -> None

let find_binding_in_scope name env =
  StringMap.find_opt name env.bindings

let mem_binding name env =
  match find_binding name env with
  | Some _ -> true
  | None -> false

let update_binding name new_ty env =
  if is_locked name env then
    failwith (Printf.sprintf "Cannot change type of locked variable '%s'" name)
  else
    { env with bindings = StringMap.add name new_ty env.bindings }

let get_bindings env =
  StringMap.bindings env.bindings

let merge_env env1 env2 =
  {
    bindings = StringMap.union (fun _ v1 _ -> Some v1) env1.bindings env2.bindings;
    parent = env1.parent;
    locked = env1.locked @ env2.locked;
    interfaces = env1.interfaces;
    impls = env1.impls;
    structs = env1.structs;
    default_params = StringMap.union (fun _ v1 _ -> Some v1) env1.default_params env2.default_params;
  }

(* 添加接口定义到环境 *)
let add_interface name iface env =
  { env with interfaces = StringMap.add name iface env.interfaces }

(* 查找接口定义 *)
let rec find_interface name env =
  match StringMap.find_opt name env.interfaces with
  | Some iface -> Some iface
  | None ->
      match env.parent with
      | Some parent -> find_interface name parent
      | None -> None

(* 添加impl块到环境 *)
let add_impl impl env =
  { env with impls = impl :: env.impls }

(* 查找类型的impl块 *)
let find_impl_for_type target_type interface_name env =
  List.find_opt (fun impl ->
    impl.impl_interface_name = interface_name &&
    is_compatible impl.impl_target_type target_type
  ) env.impls

(* 添加结构体定义到环境 *)
let add_struct name struct_def env =
  { env with structs = StringMap.add name struct_def env.structs }

(* 查找结构体定义 *)
let rec find_struct name env =
  match StringMap.find_opt name env.structs with
  | Some struct_def -> Some struct_def
  | None ->
      match env.parent with
      | Some parent -> find_struct name parent
      | None -> None

(* 检查结构体是否隐式实现了接口 (Duck Typing) *)
let struct_implements_interface struct_def iface_def =
  (* 提取接口要求的方法 *)
  let required_methods = List.filter_map (function
    | IMethod (name, _, params, ret_ty_opt, default_impl_opt, _) ->
        (* 如果有默认实现，则不是必需的 *)
        if default_impl_opt = None then
          let param_types = List.map (fun (_, ty_opt, _) ->
            match ty_opt with
            | Some ty -> type_expr_to_ty ty
            | None -> TyVar "T"  (* 参数类型未指定，使用泛型 *)
          ) params in
          let ret_type = match ret_ty_opt with
            | Some ty -> type_expr_to_ty ty
            | None -> TyNone
          in
          Some (name, TyFunc (param_types, ret_type))
        else
          None
    | _ -> None
  ) iface_def.iface_members in

  (* 检查结构体是否有所有必需的方法 *)
  List.for_all (fun (method_name, expected_type) ->
    match StringMap.find_opt method_name struct_def.struct_methods with
    | None -> false
    | Some actual_type ->
        (* 检查方法签名是否兼容 *)
        (try
           let _ = unify actual_type expected_type in
           true
         with Failure _ -> false)
  ) required_methods

(* 查找类型隐式实现的所有接口 *)
let find_implicit_interfaces_for_struct struct_name env =
  match find_struct struct_name env with
  | None -> []
  | Some struct_def ->
      (* 遍历所有接口，检查结构体是否隐式实现 *)
      StringMap.fold (fun iface_name iface_def acc ->
        if struct_implements_interface struct_def iface_def then
          iface_name :: acc
        else
          acc
      ) env.interfaces []

(* C Runtime 函数列表 - 统一管理所有 __c_ 函数 *)
let c_runtime_functions = [
  ("__c_file_read", TyFunc ([TyStr], TyStr));
  ("__c_file_write", TyFunc ([TyStr; TyStr], TyInt));
  ("__c_file_exists", TyFunc ([TyStr], TyInt));
  ("__c_file_append", TyFunc ([TyStr; TyStr], TyInt));
  ("__c_file_delete", TyFunc ([TyStr], TyInt));
  ("__c_file_read_bytes", TyFunc ([TyStr], TyBytes));
  ("__c_file_write_bytes", TyFunc ([TyStr; TyBytes], TyInt));
  ("__c_file_append_bytes", TyFunc ([TyStr; TyBytes], TyInt));
]

(* 检查函数是否是 C Runtime 函数 *)
let is_c_runtime_function name =
  List.exists (fun (fn, _) -> fn = name) c_runtime_functions

let builtin_env =
  let env = empty_env in
  let env = add_binding "print" (TyFunc ([TyVar "T"], TyNone)) env in
  let env = add_binding "len" (TyFunc ([TyList (TyVar "T")], TyInt)) env in
  let env = add_binding "append" (TyFunc ([TyList (TyVar "T"); TyVar "T"], TyNone)) env in
  let env = add_binding "range" (TyFunc ([TyInt], TyList TyInt)) env in
  let env = add_binding "dict_keys" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "K"))) env in
  let env = add_binding "dict_values" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "V"))) env in
  let env = add_binding "dict_items" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyTuple [TyVar "K"; TyVar "V"]))) env in
  let env = add_binding "join" (TyFunc ([TyList TyStr; TyStr], TyStr)) env in
  (* 将所有 C Runtime 函数添加到环境中 *)
  let env = List.fold_left (fun e (name, ty) -> add_binding name ty e) env c_runtime_functions in
  (* 预定义内置枚举类型 *)
  let env = add_binding "Option" (TyEnum ("Option", [])) env in
  let env = add_binding "Result" (TyEnum ("Result", [])) env in
  env
