open Ast

(* 收集带默认参数的函数：函数名 -> (总参数数, 尾部默认值列表) *)
let collect_defaults program =
  List.fold_left (fun map stmt ->
    match stmt with
    | SDef def_info ->
        let defaults = List.filter_map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
        if defaults <> [] then
          Env.StringMap.add def_info.def_name
            (List.length def_info.def_params, defaults) map
        else map
    | _ -> map
  ) Env.StringMap.empty program

let rec fill_expr defaults = function
  | ECall ((EVar (name, _) as func), args, pos) ->
      let new_args = List.map (fill_expr defaults) args in
      (match Env.StringMap.find_opt name defaults with
       | Some (total_params, default_exprs) when List.length new_args < total_params ->
           let missing = total_params - List.length new_args in
           let fill_count = min missing (List.length default_exprs) in
           let filled = List.map (fill_expr defaults)
             (List.rev (List.take fill_count (List.rev default_exprs))) in
           ECall (func, new_args @ filled, pos)
       | _ -> ECall (func, new_args, pos))
  | ECall (func, args, pos) ->
      ECall (fill_expr defaults func, List.map (fill_expr defaults) args, pos)
  | EBinOp (left, op, right, pos) ->
      EBinOp (fill_expr defaults left, op, fill_expr defaults right, pos)
  | EUnOp (op, expr, pos) ->
      EUnOp (op, fill_expr defaults expr, pos)
  | EList (elements, pos) ->
      EList (List.map (fill_expr defaults) elements, pos)
  | EDict (pairs, pos) ->
      EDict (List.map (fun (key, value) ->
        (fill_expr defaults key, fill_expr defaults value)) pairs, pos)
  | ETuple (elements, pos) ->
      ETuple (List.map (fill_expr defaults) elements, pos)
  | EIndex (collection, index, pos) ->
      EIndex (fill_expr defaults collection, fill_expr defaults index, pos)
  | ESlice (collection, start, finish, pos) ->
      ESlice (fill_expr defaults collection,
        Option.map (fill_expr defaults) start,
        Option.map (fill_expr defaults) finish, pos)
  | EAttr (obj, attr, pos) ->
      EAttr (fill_expr defaults obj, attr, pos)
  | ELambda (parameters, body, pos) ->
      ELambda (parameters, fill_expr defaults body, pos)
  | EIf (condition, then_expr, else_opt, pos) ->
      EIf (fill_expr defaults condition, fill_expr defaults then_expr,
        Option.map (fill_expr defaults) else_opt, pos)
  | EMatch (scrutinee, cases, pos) ->
      EMatch (fill_expr defaults scrutinee,
        List.map (fun (pattern, guard, body) ->
          (pattern, Option.map (fill_expr defaults) guard,
           match body with
           | MExpr expr -> MExpr (fill_expr defaults expr)
           | MStmts statements -> MStmts (List.map (fill_statement defaults) statements))
        ) cases, pos)
  | EListComp (element, var, iterable, condition_opt, pos) ->
      EListComp (fill_expr defaults element, var,
        fill_expr defaults iterable,
        Option.map (fill_expr defaults) condition_opt, pos)
  | EEnumVariant (enum_name, variant_name, args, pos) ->
      EEnumVariant (enum_name, variant_name,
        List.map (fill_expr defaults) args, pos)
  | EStructLiteral (struct_name, fields, pos) ->
      EStructLiteral (struct_name,
        List.map (fun (field_name, value) ->
          (field_name, fill_expr defaults value)) fields, pos)
  | EStructAccess (obj, field, pos) ->
      EStructAccess (fill_expr defaults obj, field, pos)
  | ETernary (condition, then_expr, else_expr, pos) ->
      ETernary (fill_expr defaults condition,
        fill_expr defaults then_expr, fill_expr defaults else_expr, pos)
  | ETry (expr, pos) ->
      ETry (fill_expr defaults expr, pos)
  | ETypeOf (expr, pos) ->
      ETypeOf (fill_expr defaults expr, pos)
  | expr -> expr

and fill_statement defaults stmt =
  match stmt with
  | SExpr (expr, pos) -> SExpr (fill_expr defaults expr, pos)
  | SLet let_info ->
      SLet { let_info with let_value = fill_expr defaults let_info.let_value }
  | SConst const_info ->
      SConst { const_info with const_value = fill_expr defaults const_info.const_value }
  | SLetPat (pattern, expr, pos) ->
      SLetPat (pattern, fill_expr defaults expr, pos)
  | SReturn (Some expr, pos) ->
      SReturn (Some (fill_expr defaults expr), pos)
  | SIf (condition, then_body, elifs, else_opt, pos) ->
      SIf (fill_expr defaults condition,
        List.map (fill_statement defaults) then_body,
        List.map (fun (cond, body) ->
          (fill_expr defaults cond, List.map (fill_statement defaults) body)) elifs,
        Option.map (List.map (fill_statement defaults)) else_opt, pos)
  | SWhile (condition, body, pos) ->
      SWhile (fill_expr defaults condition,
        List.map (fill_statement defaults) body, pos)
  | SBreak pos -> SBreak pos
  | SFor (pattern, iterable, body, pos) ->
      SFor (pattern, fill_expr defaults iterable,
        List.map (fill_statement defaults) body, pos)
  | SDef def_info ->
      SDef { def_info with
             def_body = List.map (fill_statement defaults) def_info.def_body }
  | stmt -> stmt

let fill_default_arguments program =
  let defaults = collect_defaults program in
  if Env.StringMap.is_empty defaults then program
  else List.map (fill_statement defaults) program
