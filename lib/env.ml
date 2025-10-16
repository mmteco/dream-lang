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
}

let empty_env = {
  bindings = StringMap.empty;
  parent = None;
  locked = [];
  interfaces = StringMap.empty;
  impls = [];
  structs = StringMap.empty;
}

let create_child_env parent = {
  bindings = StringMap.empty;
  parent = Some parent;
  locked = [];
  interfaces = parent.interfaces;  (* 继承父环境的接口定义 *)
  impls = parent.impls;  (* 继承父环境的impl块 *)
  structs = parent.structs;  (* 继承父环境的结构体定义 *)
}

let add_binding name ty env =
  { env with bindings = StringMap.add name ty env.bindings }

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

let builtin_env =
  let env = empty_env in
  let env = add_binding "print" (TyFunc ([TyVar "T"], TyNone)) env in
  let env = add_binding "len" (TyFunc ([TyList (TyVar "T")], TyInt)) env in
  let env = add_binding "append" (TyFunc ([TyList (TyVar "T"); TyVar "T"], TyNone)) env in
  let env = add_binding "range" (TyFunc ([TyInt], TyList TyInt)) env in
  let env = add_binding "dict_keys" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "K"))) env in
  let env = add_binding "dict_values" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "V"))) env in
  let env = add_binding "dict_items" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyTuple [TyVar "K"; TyVar "V"]))) env in
  let env = add_binding "join" (TyFunc ([TyList TyString; TyString], TyString)) env in
  (* 预定义内置枚举类型 *)
  let env = add_binding "Option" (TyEnum ("Option", [])) env in
  let env = add_binding "Result" (TyEnum ("Result", [])) env in
  env
