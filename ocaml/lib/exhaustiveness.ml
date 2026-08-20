open Ast
open Types

(* 模式穷尽性检查 *)

(* 表示一个抽象的模式空间 *)
type pattern_space =
  | PAny                                    (* 通配符 _ *)
  | PConst of pattern                       (* 常量模式 *)
  | PTup of pattern_space list              (* 元组模式 *)
  | PListSpace of pattern_space list        (* 精确长度列表模式 *)
  | PConsSpace of pattern_space * pattern_space (* 非空列表模式 *)
  | PStructSpace of string                  (* 结构体模式 *)
  | PVariant of string * string * pattern_space list  (* 枚举变体 enum_name * variant_name * args *)
  | POr of pattern_space list               (* 或模式 *)

(* 从 AST 模式转换为模式空间 *)
let rec pattern_to_space = function
  | PWildcard -> PAny
  | PVar _ -> PAny
  | PInt n -> PConst (PInt n)
  | PFloat f -> PConst (PFloat f)
  | PString s -> PConst (PString s)
  | PRune c -> PConst (PRune c)
  | PByte b -> PConst (PByte b)
  | PBool b -> PConst (PBool b)
  | PTuple pats -> PTup (List.map pattern_to_space pats)
  | PList pats -> PListSpace (List.map pattern_to_space pats)
  | PCons (head, tail) -> PConsSpace (pattern_to_space head, pattern_to_space tail)
  | PType (_, _) -> PAny  (* 类型模式暂时当作通配符处理 *)
  | PEnumVariant (enum_name, variant_name, pats) ->
      PVariant (enum_name, variant_name, List.map pattern_to_space pats)
  | PStruct (name, _) -> PStructSpace name

(* 检查 match 是否全是类型模式 *)
let all_type_patterns patterns =
  List.for_all (fun (pat, _, _) ->
    match pat with
    | PType (_, _) -> true
    | PWildcard -> true
    | _ -> false
  ) patterns

(* match type of 的类型名模式（PString "int" 等）或通配符 *)
let all_type_name_patterns patterns =
  List.for_all (fun (pat, _, _) ->
    match pat with
    | PString _ -> true
    | PWildcard -> true
    | _ -> false
  ) patterns

(* 从模式中提取类型 *)
let extract_type_from_pattern = function
  | PType (_, type_expr) -> Some type_expr
  | PString type_name ->
      Some (match type_name with
        | "int" -> TInt
        | "float" -> TFloat
        | "str" -> TStr
        | "bool" -> TBool
        | "bytes" -> TBytes
        | "rune" -> TRune
        | "byte" -> TByte
        | _ -> TVar type_name)
  | _ -> None

(* 检查类型模式是否覆盖了 Union 类型的所有成员 *)
let check_union_coverage union_types patterns =
  (* 从模式中提取所有匹配的类型 *)
  let pattern_types = List.filter_map (fun (pat, _, _) ->
    extract_type_from_pattern pat
  ) patterns in

  (* 检查是否有通配符 *)
  let has_wildcard = List.exists (fun (pat, _, _) ->
    match pat with PWildcard -> true | _ -> false
  ) patterns in

  if has_wildcard then
    None  (* 有通配符，肯定是穷尽的 *)
  else
    (* 检查 Union 中的每个类型是否都被覆盖 *)
    let uncovered = List.filter (fun union_ty ->
      not (List.exists (fun pattern_ty ->
        (* 简单比较类型是否相同 *)
        Types.type_expr_to_ty pattern_ty = union_ty
      ) pattern_types)
    ) union_types in

    if uncovered = [] then
      None  (* 全部覆盖 *)
    else
      (* 生成缺失类型的名称 *)
      let missing_names = List.map Types.ty_to_string uncovered in
      Some missing_names

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
  | PAny, p :: rest ->
      (match p with
       | PAny -> true
       | _ -> is_covered space rest)
  | PConst c1, p :: rest ->
      (match p with
       | PAny -> true
       | PConst c2 when c1 = c2 -> true
       | _ -> is_covered space rest)
  | PTup spaces, p :: rest ->
      (match p with
       | PAny -> true
       | PTup pats when List.length spaces = List.length pats ->
           if List.for_all2 (fun s p -> is_covered s [p]) spaces pats then true
           else is_covered space rest
       | _ -> is_covered space rest)
  | PListSpace spaces, p :: rest ->
      (match p with
       | PAny -> true
       | PListSpace patterns when List.length spaces = List.length patterns ->
           if List.for_all2 (fun space pattern -> is_covered space [pattern]) spaces patterns
           then true
           else is_covered space rest
       | _ -> is_covered space rest)
  | PConsSpace (head_space, tail_space), p :: rest ->
      (match p with
       | PAny -> true
       | PConsSpace (head_pattern, tail_pattern) ->
           if is_covered head_space [head_pattern] && is_covered tail_space [tail_pattern]
           then true
           else is_covered space rest
       | _ -> is_covered space rest)
  | PStructSpace name, p :: rest ->
      (match p with
       | PAny -> true
       | PStructSpace other_name when name = other_name -> true
       | _ -> is_covered space rest)
  | PVariant (enum1, var1, args1), p :: rest ->
      (match p with
       | PAny -> true
       | PVariant (enum2, var2, args2) when enum1 = enum2 && var1 = var2 ->
           if List.length args1 = List.length args2 &&
              List.for_all2 (fun s p -> is_covered s [p]) args1 args2
           then true
           else is_covered space rest
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
  (* 特殊处理：检查是否是类型模式匹配 Union 类型 *)
  match scrutinee_type with
  | TyTypeInfo (TyInterface _) ->
      (* 接口值的具体类型无法静态枚举，由通配符兜底 *)
      None
  | TyUnion union_types when all_type_patterns patterns ->
      (* 这是 match type of 匹配 Union 类型 *)
      (match check_union_coverage union_types patterns with
       | Some missing_names ->
           Some (pos, missing_names)
       | None -> None)
  | TyTypeInfo (TyUnion union_types) when all_type_name_patterns patterns ->
      (* match type of 匹配 Union 类型 *)
      (match check_union_coverage union_types patterns with
       | Some missing_names ->
           Some (pos, missing_names)
       | None -> None)
  | TyTypeInfo _ when all_type_name_patterns patterns ->
      (* match type of 匹配具体类型（非 union），任何类型模式都视为穷尽 *)
      None
  | _ ->
      (* 常规模式匹配检查 *)
      let pattern_spaces = List.map (fun (pat, _, _) -> pattern_to_space pat) patterns in

      (* 根据 scrutinee 的类型生成需要覆盖的空间 *)
      let required_space = match scrutinee_type with
        | TyBool -> POr [PConst (PBool true); PConst (PBool false)]
        | TyEnum (enum_name, _) ->
            POr (generate_enum_space env enum_name)
        | TyResult (_, _) ->
            (* Result 类型有两个变体：Ok 和 Err，各带一个参数 *)
            POr [PVariant ("Result", "Ok", [PAny]); PVariant ("Result", "Err", [PAny])]
        | TyOption _ ->
            (* Option 类型有两个变体：Some 和 None *)
            POr [PVariant ("Option", "Some", [PAny]); PVariant ("Option", "None", [])]
        | TyTuple tys ->
            PTup (List.map (fun _ -> PAny) tys)
        | TyStruct _ ->
            (* struct 模式的字段值穷尽性无法静态证明，由通配符兜底 *)
            POr []
        | TyUnion _ ->
            (* union 匹配在运行时做类型检查，穷尽性无法静态证明 *)
            POr []
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
let check_reachability env scrutinee_type patterns =
  let rec check_from_index idx patterns acc_patterns_with_metadata =
    match patterns with
    | [] -> []
    | (pat, guard, _) :: rest ->
        let current_space = pattern_to_space pat in
        (* 如果有 guard，认为模式是可达的 *)
        (* 只有当前模式完全被之前的模式覆盖时，才是不可达的 *)
        let has_guard = match guard with | Some _ -> true | None -> false in
        let is_fully_covered = match current_space with
          | PAny ->
              (* 通配符：检查之前的模式是否已经穷尽所有情况 *)
              (* 如果已经穷尽，则通配符不可达 *)
              (match scrutinee_type with
               | TyUnion _ -> false  (* union 匹配在运行时检查类型，通配符始终可达 *)
               | TyStruct _ -> false  (* struct 模式字段值无法静态证明，通配符始终可达 *)
               | TyTypeInfo (TyInterface _) -> false  (* 接口具体类型无法静态枚举，通配符始终可达 *)
               | _ ->
                   (match check_exhaustiveness env scrutinee_type acc_patterns_with_metadata {line=0; column=0} with
                    | None -> true  (* 之前的模式已穷尽，通配符不可达 *)
                    | Some _ -> false))  (* 之前的模式未穷尽，通配符可达 *)
          | _ ->
              (match scrutinee_type with
               | TyUnion _ | TyStruct _ -> false  (* union/struct 模式无法静态判定冗余 *)
               | _ ->
                   let acc_pattern_spaces = List.map (fun (p, _, _) -> pattern_to_space p) acc_patterns_with_metadata in
                   is_covered current_space acc_pattern_spaces)
        in
        let is_reachable = has_guard || not is_fully_covered in
        let unreachable = if is_reachable then [] else [idx] in
        (* 只有无守卫的模式才会完全覆盖模式空间，有守卫的模式可能不匹配 *)
        let new_acc = if has_guard then acc_patterns_with_metadata else acc_patterns_with_metadata @ [(pat, guard, ())] in
        unreachable @ check_from_index (idx + 1) rest new_acc
  in
  check_from_index 0 patterns []
