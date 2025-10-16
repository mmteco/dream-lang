open Types

module StringMap = Map.Make(String)

type env = {
  bindings: ty StringMap.t;
  parent: env option;
  locked: string list;
}

let empty_env = {
  bindings = StringMap.empty;
  parent = None;
  locked = [];
}

let create_child_env parent = {
  bindings = StringMap.empty;
  parent = Some parent;
  locked = [];
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
  }

let builtin_env =
  let env = empty_env in
  let env = add_binding "print" (TyFunc ([TyVar "T"], TyNone)) env in
  let env = add_binding "len" (TyFunc ([TyList (TyVar "T")], TyInt)) env in
  let env = add_binding "append" (TyFunc ([TyList (TyVar "T"); TyVar "T"], TyNone)) env in
  let env = add_binding "range" (TyFunc ([TyInt], TyList TyInt)) env in
  let env = add_binding "dict_keys" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "K"))) env in
  let env = add_binding "dict_values" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "V"))) env in
  let env = add_binding "dict_items" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyTuple [TyVar "K"; TyVar "V"]))) env in
  (* 预定义内置枚举类型 *)
  let env = add_binding "Option" (TyEnum ("Option", [])) env in
  let env = add_binding "Result" (TyEnum ("Result", [])) env in
  env
