open Types
open Env

(* 类型变量生成器 *)
let type_counter = ref 0

let fresh_type_var () =
  type_counter := !type_counter + 1;
  TyVar (Printf.sprintf "T%d" !type_counter)

(* 实例化多态类型：将类型中的 TyVar 替换为新的类型变量 *)
let instantiate ty =
  let var_map = ref [] in
  let rec inst = function
    | TyVar name ->
        (match List.assoc_opt name !var_map with
         | Some new_var -> new_var
         | None ->
             let new_var = fresh_type_var () in
             var_map := (name, new_var) :: !var_map;
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
  String.length file >= 7 && String.sub file 0 7 = "stdlib/"

(* 将替换应用到环境中，保持多态函数类型不变 *)
let apply_subst_to_env subst env =
  {env with bindings = Env.StringMap.map (fun ty ->
    if is_polymorphic ty then ty else apply_subst subst ty
  ) env.bindings}
