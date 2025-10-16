open Ast
open Types

(* 模式穷尽性检查 *)

(* 表示一个抽象的模式空间 *)
type pattern_space =
  | PAny                                    (* 通配符 _ *)
  | PConst of pattern                       (* 常量模式 *)
  | PTup of pattern_space list              (* 元组模式 *)
  | PVariant of string * string * pattern_space list  (* 枚举变体 enum_name * variant_name * args *)
  | POr of pattern_space list               (* 或模式 *)

(* 从 AST 模式转换为模式空间 *)
let rec pattern_to_space = function
  | PWildcard -> PAny
  | PVar _ -> PAny
  | PInt n -> PConst (PInt n)
  | PFloat f -> PConst (PFloat f)
  | PString s -> PConst (PString s)
  | PBool b -> PConst (PBool b)
  | PTuple pats -> PTup (List.map pattern_to_space pats)
  | PList _ -> PAny  (* 暂时简化处理列表 *)
  | PType (_, _) -> PAny
  | PEnumVariant (enum_name, variant_name, pats) ->
      PVariant (enum_name, variant_name, List.map pattern_to_space pats)

(* 获取枚举的所有变体 *)
let get_enum_variants _env enum_name =
  (* 对于内置的 Option 和 Result，返回硬编码的变体 *)
  match enum_name with
  | "Option" -> [("Some", 1); ("None", 0)]
  | "Result" -> [("Ok", 1); ("Err", 1)]
  | _ -> []  (* TODO: 从环境中查找用户定义的枚举 *)

(* 检查一个模式空间是否被模式列表覆盖 *)
let rec is_covered space patterns =
  match space, patterns with
  | _, [] -> false
  | PAny, _ :: _ -> true
  | PConst c1, p :: rest ->
      (match p with
       | PAny -> true
       | PConst c2 when c1 = c2 -> true
       | _ -> is_covered space rest)
  | PTup spaces, p :: rest ->
      (match p with
       | PAny -> true
       | PTup pats when List.length spaces = List.length pats ->
           List.for_all2 (fun s p -> is_covered s [p]) spaces pats
       | _ -> is_covered space rest)
  | PVariant (enum1, var1, args1), p :: rest ->
      (match p with
       | PAny -> true
       | PVariant (enum2, var2, args2) when enum1 = enum2 && var1 = var2 ->
           List.length args1 = List.length args2 &&
           List.for_all2 (fun s p -> is_covered s [p]) args1 args2
       | _ -> is_covered space rest)
  | POr spaces, patterns ->
      List.for_all (fun s -> is_covered s patterns) spaces

(* 生成一个枚举类型的所有可能的模式空间 *)
let generate_enum_space env enum_name =
  let variants = get_enum_variants env enum_name in
  List.map (fun (variant_name, arity) ->
    let args = List.init arity (fun _ -> PAny) in
    PVariant (enum_name, variant_name, args)
  ) variants

(* 检查模式列表的穷尽性 *)
let check_exhaustiveness env scrutinee_type patterns pos =
  let pattern_spaces = List.map (fun (pat, _, _) -> pattern_to_space pat) patterns in

  (* 根据 scrutinee 的类型生成需要覆盖的空间 *)
  let required_space = match scrutinee_type with
    | TyBool -> POr [PConst (PBool true); PConst (PBool false)]
    | TyEnum (enum_name, _) ->
        POr (generate_enum_space env enum_name)
    | TyTuple tys ->
        PTup (List.map (fun _ -> PAny) tys)
    | _ -> PAny
  in

  (* 检查是否所有情况都被覆盖 *)
  match required_space with
  | POr spaces ->
      let uncovered = List.filter (fun space ->
        not (is_covered space pattern_spaces)
      ) spaces in
      if uncovered <> [] then
        let missing_patterns = List.map (fun space ->
          match space with
          | PConst (PBool true) -> "true"
          | PConst (PBool false) -> "false"
          | PVariant (_, variant_name, _) -> variant_name
          | _ -> "_"
        ) uncovered in
        Some (pos, missing_patterns)
      else
        None
  | PAny ->
      (* 对于任意类型，检查是否有通配符 *)
      if List.exists (fun p -> p = PAny) pattern_spaces then
        None
      else
        Some (pos, ["_"])
  | _ ->
      if is_covered required_space pattern_spaces then
        None
      else
        Some (pos, ["_"])

(* 检查是否有不可达的模式 *)
let check_reachability patterns =
  let rec check_from_index idx patterns acc_patterns =
    match patterns with
    | [] -> []
    | (pat, guard, _) :: rest ->
        let current_space = pattern_to_space pat in
        (* 如果有 guard，认为模式是可达的 *)
        (* 只有当前模式完全被之前的模式覆盖时，才是不可达的 *)
        let has_guard = match guard with | Some _ -> true | None -> false in
        let is_fully_covered = match current_space with
          | PAny ->
              (* 通配符只有在所有情况都被覆盖时才不可达 *)
              (* 这很难检查，暂时认为通配符总是可达的 *)
              false
          | _ -> is_covered current_space acc_patterns
        in
        let is_reachable = has_guard || not is_fully_covered in
        let unreachable = if is_reachable then [] else [idx] in
        (* 只有无守卫的模式才会完全覆盖模式空间，有守卫的模式可能不匹配 *)
        let new_acc = if has_guard then acc_patterns else acc_patterns @ [current_space] in
        unreachable @ check_from_index (idx + 1) rest new_acc
  in
  check_from_index 0 patterns []
