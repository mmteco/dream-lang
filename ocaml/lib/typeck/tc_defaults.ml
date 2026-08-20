open Ast

(* 填充默认参数 *)
let rec fill_default_params env expr =
  match expr with
  | ECall (EVar (func_name, func_pos), args, pos) ->
      (match Env.get_function_defaults func_name env with
       | Some defaults when List.length args < List.length defaults ->
           let num_provided = List.length args in
           let rec drop n lst = match n, lst with
             | 0, _ -> lst
             | _, [] -> []
             | n, _ :: xs -> drop (n - 1) xs
           in
           let missing_defaults = drop num_provided defaults in
           let default_args = List.filter_map (fun default_opt -> default_opt) missing_defaults in
           let new_args = List.map (fill_default_params env) args in
           let full_args = new_args @ default_args in
           ECall (EVar (func_name, func_pos), full_args, pos)
       | _ ->
           let new_args = List.map (fill_default_params env) args in
           ECall (EVar (func_name, func_pos), new_args, pos))
  | ECall (func, args, pos) ->
      ECall (fill_default_params env func, List.map (fill_default_params env) args, pos)
  | EBinOp (e1, op, e2, pos) ->
      EBinOp (fill_default_params env e1, op, fill_default_params env e2, pos)
  | EUnOp (op, e, pos) ->
      EUnOp (op, fill_default_params env e, pos)
  | EList (elems, pos) ->
      EList (List.map (fill_default_params env) elems, pos)
  | ETuple (elems, pos) ->
      ETuple (List.map (fill_default_params env) elems, pos)
  | EDict (pairs, pos) ->
      EDict (List.map (fun (k, v) -> (fill_default_params env k, fill_default_params env v)) pairs, pos)
  | EIndex (arr, idx, pos) ->
      EIndex (fill_default_params env arr, fill_default_params env idx, pos)
  | ESlice (arr, start_opt, end_opt, pos) ->
      ESlice (fill_default_params env arr,
              Option.map (fill_default_params env) start_opt,
              Option.map (fill_default_params env) end_opt, pos)
  | EAttr (obj, attr, pos) ->
      EAttr (fill_default_params env obj, attr, pos)
  | ELambda (params, body, pos) ->
      ELambda (params, fill_default_params env body, pos)
  | EIf (cond, then_expr, else_opt, pos) ->
      EIf (fill_default_params env cond, fill_default_params env then_expr,
           Option.map (fill_default_params env) else_opt, pos)
  | EMatch (scrut, cases, pos) ->
      let new_cases = List.map (fun (pat, guard_opt, body) ->
        let new_body = match body with
          | MExpr expr -> MExpr (fill_default_params env expr)
          | MStmts stmts -> MStmts (List.map (fill_default_params_stmt env) stmts)
        in
        (pat, Option.map (fill_default_params env) guard_opt, new_body)
      ) cases in
      EMatch (fill_default_params env scrut, new_cases, pos)
  | EListComp (elem, var, iter, cond_opt, pos) ->
      EListComp (fill_default_params env elem, var, fill_default_params env iter,
                 Option.map (fill_default_params env) cond_opt, pos)
  | EEnumVariant (enum_name, variant_name, args, pos) ->
      EEnumVariant (enum_name, variant_name, List.map (fill_default_params env) args, pos)
  | EStructLiteral (struct_name, field_inits, pos) ->
      EStructLiteral (struct_name,
                      List.map (fun (name, expr) -> (name, fill_default_params env expr)) field_inits,
                      pos)
  | EStructAccess (obj, field, pos) ->
      EStructAccess (fill_default_params env obj, field, pos)
  | ETernary (cond, true_expr, false_expr, pos) ->
      ETernary (fill_default_params env cond, fill_default_params env true_expr,
                fill_default_params env false_expr, pos)
  | ETry (expr, pos) ->
      ETry (fill_default_params env expr, pos)
  | _ -> expr

and fill_default_params_stmt env stmt =
  match stmt with
  | SExpr (e, pos) -> SExpr (fill_default_params env e, pos)
  | SLet let_info ->
      SLet { let_info with let_value = fill_default_params env let_info.let_value }
  | SConst const_info ->
      SConst { const_info with const_value = fill_default_params env const_info.const_value }
  | SLetPat (pat, value, pos) ->
      SLetPat (pat, fill_default_params env value, pos)
  | SAssign (name, value, pos) ->
      SAssign (name, fill_default_params env value, pos)
  | SDef def_info ->
      let new_body = List.map (fill_default_params_stmt env) def_info.def_body in
      SDef { def_info with def_body = new_body }
  | SReturn (expr_opt, pos) ->
      SReturn (Option.map (fill_default_params env) expr_opt, pos)
  | SIf (cond, then_body, elifs, else_opt, pos) ->
      let new_then = List.map (fill_default_params_stmt env) then_body in
      let new_elifs = List.map (fun (c, b) ->
        (fill_default_params env c, List.map (fill_default_params_stmt env) b)
      ) elifs in
      let new_else = Option.map (List.map (fill_default_params_stmt env)) else_opt in
      SIf (fill_default_params env cond, new_then, new_elifs, new_else, pos)
  | SWhile (cond, body, pos) ->
      SWhile (fill_default_params env cond, List.map (fill_default_params_stmt env) body, pos)
  | SBreak pos -> SBreak pos
  | SFor (pat, iter, body, pos) ->
      SFor (pat, fill_default_params env iter, List.map (fill_default_params_stmt env) body, pos)
  | SImpl (impl_block, pos) ->
      let new_members = List.map (function
        | ImplMethod (name, type_params, params, ret_ty_opt, body, mpos) ->
            ImplMethod (name, type_params, params, ret_ty_opt,
                       List.map (fill_default_params_stmt env) body, mpos)
        | other -> other
      ) impl_block.impl_members in
      SImpl ({ impl_block with impl_members = new_members }, pos)
  | SStruct struct_info ->
      let new_members = List.map (function
        | SMethod (name, type_params, params, ret_ty_opt, body, mpos) ->
            SMethod (name, type_params, params, ret_ty_opt,
                    List.map (fill_default_params_stmt env) body, mpos)
        | other -> other
      ) struct_info.struct_members in
      SStruct { struct_info with struct_members = new_members }
  | SFieldAssign (obj, field, value, pos) ->
      SFieldAssign (fill_default_params env obj, field, fill_default_params env value, pos)
  | SIndexAssign (arr, idx, value, pos) ->
      SIndexAssign (fill_default_params env arr, fill_default_params env idx,
                   fill_default_params env value, pos)
  | _ -> stmt
