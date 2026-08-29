open Ast
open Types
open Env

(* 类型变量生成器，缓存常用名称避免重复分配 *)
let type_counter = ref 0

let cached_type_var_names =
  let arr = Array.init 64 (fun i -> Printf.sprintf "T%d" (i + 1)) in
  arr

let fresh_type_var () =
  type_counter := !type_counter + 1;
  let n = !type_counter in
  let name = if n <= 64 then cached_type_var_names.(n - 1)
             else Printf.sprintf "T%d" n in
  TyVar name

(* 实例化多态类型：将类型中的 TyVar 替换为新的类型变量 *)
let instantiate ty =
  let var_map = ref Env.StringMap.empty in
  let rec inst = function
    | TyVar name ->
        (match Env.StringMap.find_opt name !var_map with
         | Some new_var -> new_var
         | None ->
             let new_var = fresh_type_var () in
             var_map := Env.StringMap.add name new_var !var_map;
             new_var)
    | TyList t -> TyList (inst t)
    | TyDict (k, v) -> TyDict (inst k, inst v)
    | TyTuple ts -> TyTuple (List.map inst ts)
    | TyFunc (params, ret) -> TyFunc (List.map inst params, inst ret)
    | TyUnion ts -> TyUnion (List.map inst ts)
    | TyOption t -> TyOption (inst t)
    | TyResult (ok, err) -> TyResult (inst ok, inst err)
    | t -> t
  in
  inst ty

(* 检查类型是否包含未绑定的类型变量 (多态) *)
let rec is_polymorphic = function
  | TyVar _ -> true
  | TyList t -> is_polymorphic t
  | TyDict (k, v) -> is_polymorphic k || is_polymorphic v
  | TyTuple ts -> List.exists is_polymorphic ts
  | TyFunc (params, ret) -> List.exists is_polymorphic params || is_polymorphic ret
  | TyUnion ts -> List.exists is_polymorphic ts
  | TyOption t -> is_polymorphic t
  | TyResult (ok, err) -> is_polymorphic ok || is_polymorphic err
  | _ -> false

(* 当前正在编译的文件路径 *)
let current_file = ref ""

let set_current_file file =
  current_file := file

let is_stdlib_file () =
  let file = !current_file in
  let prefix = "runtime/stdlib/" in
  let len = String.length prefix in
  String.length file >= len && String.sub file 0 len = prefix

let rec resolve_type_expr env = function
  | TInt -> TyInt
  | TFloat -> TyFloat
  | TStr -> TyStr
  | TRune -> TyRune
  | TByte -> TyByte
  | TBytes -> TyBytes
  | TBool -> TyBool
  | TNone -> TyNone
  | TVar name ->
      (match Env.find_struct name env with
       | Some _ -> TyStruct (name, [])
       | None ->
           (match Env.find_enum name env with
            | Some _ -> TyEnum (name, [])
            | None ->
                (match Env.find_interface name env with
                 | Some _ -> TyInterface (name, [])
                 | None -> TyVar name)))
  | TList element_type -> TyList (resolve_type_expr env element_type)
  | TDict (key_type, value_type) ->
      TyDict (resolve_type_expr env key_type, resolve_type_expr env value_type)
  | TTuple element_types ->
      TyTuple (List.map (resolve_type_expr env) element_types)
  | TFunc (parameter_types, return_type) ->
      TyFunc (List.map (resolve_type_expr env) parameter_types,
        resolve_type_expr env return_type)
  | TUnion types -> TyUnion (List.map (resolve_type_expr env) types)
  | TGeneric (name, element_type) ->
      let resolved_element = resolve_type_expr env element_type in
      (match Env.find_interface name env with
       | Some _ -> TyInterface (name, [resolved_element])
       | None -> TyGeneric (name, resolved_element))
  | TOption element_type -> TyOption (resolve_type_expr env element_type)
  | TResult (ok_type, error_type) ->
      TyResult (resolve_type_expr env ok_type, resolve_type_expr env error_type)
  | TEnum (name, parameters) ->
      TyEnum (name, List.map (resolve_type_expr env) parameters)
  | TStruct (name, parameters) ->
      TyStruct (name, List.map (resolve_type_expr env) parameters)
  | TSelf -> TyVar "Self"

(* 将替换应用到环境中，保持多态函数类型不变 *)
let apply_subst_to_env subst env =
  if Types.Subst.is_empty subst then env
  else {env with bindings = Env.StringMap.map (fun ty ->
    if is_polymorphic ty then ty else apply_subst subst ty
  ) env.bindings}
