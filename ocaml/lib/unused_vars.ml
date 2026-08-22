open Ast

module StringSet = Set.Make(String)

(* 未使用变量检测：对每个函数体收集 let 声明与变量引用，未引用的声明报 warning *)

let rec pattern_bindings = function
  | PVar name -> StringSet.singleton name
  | PWildcard
  | PInt _
  | PFloat _
  | PString _
  | PRune _
  | PByte _
  | PBool _ -> StringSet.empty
  | PTuple patterns | PList patterns ->
      List.fold_left (fun acc p -> StringSet.union acc (pattern_bindings p))
        StringSet.empty patterns
  | PCons (head, tail) ->
      StringSet.union (pattern_bindings head) (pattern_bindings tail)
  | PType (_, _) -> StringSet.empty
  | PEnumVariant (_, _, patterns) ->
      List.fold_left (fun acc p -> StringSet.union acc (pattern_bindings p))
        StringSet.empty patterns
  | PStruct (_, fields) ->
      List.fold_left (fun acc (_, p) -> StringSet.union acc (pattern_bindings p))
        StringSet.empty fields

let rec expr_vars acc = function
  | EInt _
  | EFloat _
  | EString _
  | ERune _
  | EByte _
  | EBool _ -> acc
  | EVar (name, _) -> StringSet.add name acc
  | EBinOp (left, _, right, _) -> expr_vars (expr_vars acc left) right
  | EUnOp (_, expression, _) -> expr_vars acc expression
  | ECall (func, args, _) ->
      List.fold_left expr_vars (expr_vars acc func) args
  | EList (items, _) -> List.fold_left expr_vars acc items
  | EDict (pairs, _) ->
      List.fold_left (fun a (key, value) -> expr_vars (expr_vars a key) value) acc pairs
  | ETuple (items, _) -> List.fold_left expr_vars acc items
  | EIndex (collection, index, _) -> expr_vars (expr_vars acc collection) index
  | ESlice (collection, start, end_, _) ->
      let acc = expr_vars acc collection in
      let acc = match start with Some e -> expr_vars acc e | None -> acc in
      (match end_ with Some e -> expr_vars acc e | None -> acc)
  | EAttr (obj, _, _) -> expr_vars acc obj
  | ELambda (_, body, _) -> expr_vars acc body
  | EIf (cond, then_expression, else_expression, _) ->
      let acc = expr_vars acc cond in
      let acc = expr_vars acc then_expression in
      (match else_expression with Some e -> expr_vars acc e | None -> acc)
  | EMatch (scrutinee, cases, _) ->
      List.fold_left (fun a (_, guard, body) ->
        let a = match guard with Some g -> expr_vars a g | None -> a in
        match body with
        | MExpr e -> expr_vars a e
        | MStmts stmts -> List.fold_left stmt_vars a stmts
      ) (expr_vars acc scrutinee) cases
  | EListComp (element, _, iterable, condition, _) ->
      let acc = expr_vars acc element in
      let acc = expr_vars acc iterable in
      (match condition with Some c -> expr_vars acc c | None -> acc)
  | EEnumVariant (_, _, args, _) -> List.fold_left expr_vars acc args
  | EStructLiteral (_, fields, _) ->
      List.fold_left (fun a (_, e) -> expr_vars a e) acc fields
  | EStructAccess (obj, _, _) -> expr_vars acc obj
  | ETernary (cond, true_expression, false_expression, _) ->
      expr_vars (expr_vars (expr_vars acc cond) true_expression) false_expression
  | ETry (expression, _) -> expr_vars acc expression
  | ETypeOf (expression, _) -> expr_vars acc expression

and stmt_vars acc = function
  | SExpr (e, _) -> expr_vars acc e
  | SLet let_info -> expr_vars acc let_info.let_value
  | SConst const_info -> expr_vars acc const_info.const_value
  | SLetPat (_, value, _) -> expr_vars acc value
  | SReturn (Some e, _) -> expr_vars acc e
  | SReturn (None, _) -> acc
  | SIf (cond, then_body, elifs, else_opt, _) ->
      let acc = expr_vars acc cond in
      let acc = List.fold_left stmt_vars acc then_body in
      let acc = List.fold_left (fun a (c, b) ->
        List.fold_left stmt_vars (expr_vars a c) b) acc elifs in
      (match else_opt with Some b -> List.fold_left stmt_vars acc b | None -> acc)
  | SWhile (cond, body, _) ->
      List.fold_left stmt_vars (expr_vars acc cond) body
  | SBreak _ -> acc
  | SContinue _ -> acc
  | SFor (_, iterable, body, _) ->
      List.fold_left stmt_vars (expr_vars acc iterable) body
  | SAssign (_, value, _) -> expr_vars acc value
  | SIndexAssign (collection, index, value, _) ->
      expr_vars (expr_vars (expr_vars acc collection) index) value
  | SFieldAssign (collection, _, value, _) ->
      expr_vars (expr_vars acc collection) value
  | SDef _
  | SStruct _
  | SInterface _
  | SImport _
  | SFromImport _
  | SEnum _
  | SImpl _ -> acc

(* 收集块内所有 let 声明（含嵌套块的近似：函数级检测） *)
let rec collect_let_bindings acc = function
  | SLet let_info ->
      if String.length let_info.let_name > 0 &&
         let_info.let_name.[0] <> '_' then
        (let_info.let_name, let_info.let_pos) :: acc
      else acc
  | SLetPat (pattern, _, _) ->
      StringSet.fold (fun name bindings ->
        if String.length name > 0 && name.[0] <> '_' then
          (name, { line = 0; column = 0 }) :: bindings
        else bindings
      ) (pattern_bindings pattern) acc
  | SIf (_, then_body, elifs, else_opt, _) ->
      let acc = List.fold_left collect_let_bindings acc then_body in
      let acc = List.fold_left (fun a (_, b) ->
        List.fold_left collect_let_bindings a b) acc elifs in
      (match else_opt with Some b -> List.fold_left collect_let_bindings acc b | None -> acc)
  | SWhile (_, body, _) -> List.fold_left collect_let_bindings acc body
  | SBreak _ -> acc
  | SContinue _ -> acc
  | SFor (_, _, body, _) -> List.fold_left collect_let_bindings acc body
  | _ -> acc

let check_function def_info =
  let bindings = List.fold_left collect_let_bindings [] def_info.def_body in
  let used = List.fold_left stmt_vars StringSet.empty def_info.def_body in
  List.iter (fun (name, pos) ->
    if not (StringSet.mem name used) then
      Error.report_error (Error.make_warning (Error.NameError name) pos
        (Printf.sprintf "unused variable '%s'" name))
  ) bindings

let detect (program : program) =
  List.iter (function
    | SDef def_info -> check_function def_info
    | _ -> ()) program
