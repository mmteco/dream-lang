open Ast
open Types
open Env
open Error

let type_counter = ref 0

let fresh_type_var () =
  type_counter := !type_counter + 1;
  TyVar (Printf.sprintf "T%d" !type_counter)

let rec infer_expr env = function
  | EInt (_, _) -> (TyInt, empty_subst)
  | EFloat (_, _) -> (TyFloat, empty_subst)
  | EString (_, _) -> (TyString, empty_subst)
  | EBool (_, _) -> (TyBool, empty_subst)
  | ENone _ -> (TyNone, empty_subst)

  | EVar (name, pos) ->
      (match find_binding name env with
       | Some ty -> (ty, empty_subst)
       | None ->
           let err = make_error (NameError name) pos
             (Printf.sprintf "Undefined variable '%s'" name) in
           report_error err;
           (TyUnknown, empty_subst))

  | EBinOp (e1, op, e2, pos) ->
      let (t1, s1) = infer_expr env e1 in
      let (t2, s2) = infer_expr (apply_subst_to_env s1 env) e2 in
      let s3 = compose_subst s2 s1 in
      (match op with
       | Add | Sub | Mul | Div | Mod ->
           (try
              let s4 = unify (apply_subst s3 t1) TyInt in
              let s5 = unify (apply_subst s4 t2) TyInt in
              let final_subst = compose_subst s5 (compose_subst s4 s3) in
              (TyInt, final_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in arithmetic operation: %s" msg) in
              report_error err;
              (TyUnknown, s3))
       | Eq | Neq | Lt | Gt | Lte | Gte ->
           (try
              let s4 = unify (apply_subst s3 t1) (apply_subst s3 t2) in
              (TyBool, compose_subst s4 s3)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in comparison: %s" msg) in
              report_error err;
              (TyBool, s3))
       | And | Or ->
           (try
              let s4 = unify (apply_subst s3 t1) TyBool in
              let s5 = unify (apply_subst s4 t2) TyBool in
              (TyBool, compose_subst s5 (compose_subst s4 s3))
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in logical operation: %s" msg) in
              report_error err;
              (TyBool, s3)))

  | EUnOp (op, e, pos) ->
      let (t, s) = infer_expr env e in
      (match op with
       | Neg ->
           (try
              let s2 = unify (apply_subst s t) TyInt in
              (TyInt, compose_subst s2 s)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in negation: %s" msg) in
              report_error err;
              (TyUnknown, s))
       | Not ->
           (try
              let s2 = unify (apply_subst s t) TyBool in
              (TyBool, compose_subst s2 s)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in logical not: %s" msg) in
              report_error err;
              (TyBool, s)))

  | EList (elems, pos) ->
      if elems = [] then
        (TyList (fresh_type_var ()), empty_subst)
      else
        let (elem_types, substs) = List.split (List.map (infer_expr env) elems) in
        let combined_subst = List.fold_left compose_subst empty_subst substs in
        let first_type = List.hd elem_types in
        (try
           let final_subst = List.fold_left
             (fun s t ->
               let s2 = unify (apply_subst s first_type) (apply_subst s t) in
               compose_subst s2 s)
             combined_subst elem_types
           in
           (TyList (apply_subst final_subst first_type), final_subst)
         with Failure msg ->
           let err = make_error (TypeError msg) pos
             (Printf.sprintf "List elements have inconsistent types: %s" msg) in
           report_error err;
           (TyList TyUnknown, combined_subst))

  | ETuple (elems, _) ->
      let (elem_types, substs) = List.split (List.map (infer_expr env) elems) in
      let combined_subst = List.fold_left compose_subst empty_subst substs in
      (TyTuple elem_types, combined_subst)

  | EDict (pairs, _) ->
      if pairs = [] then
        (TyDict (fresh_type_var (), fresh_type_var ()), empty_subst)
      else
        let infer_pair (k, v) =
          let (kt, ks) = infer_expr env k in
          let (vt, vs) = infer_expr env v in
          ((kt, vt), compose_subst vs ks)
        in
        let (pair_types, substs) = List.split (List.map infer_pair pairs) in
        let combined_subst = List.fold_left compose_subst empty_subst substs in
        let (first_kt, first_vt) = List.hd pair_types in
        (TyDict (first_kt, first_vt), combined_subst)

  | ECall (func, args, pos) ->
      let (func_type, func_subst) = infer_expr env func in
      let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
      let combined_subst = List.fold_left compose_subst func_subst arg_substs in
      let ret_type = fresh_type_var () in
      let expected_func_type = TyFunc (arg_types, ret_type) in
      (try
         let final_subst = unify (apply_subst combined_subst func_type) expected_func_type in
         (apply_subst final_subst ret_type, compose_subst final_subst combined_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "Function call type error: %s" msg) in
         report_error err;
         (TyUnknown, combined_subst))

  | EIndex (arr, idx, pos) ->
      let (arr_type, arr_subst) = infer_expr env arr in
      let (idx_type, idx_subst) = infer_expr env idx in
      let combined_subst = compose_subst idx_subst arr_subst in
      (match apply_subst combined_subst arr_type with
       | TyList elem_type -> (elem_type, combined_subst)
       | TyDict (key_type, val_type) ->
           (try
              let key_subst = unify (apply_subst combined_subst idx_type) key_type in
              (val_type, compose_subst key_subst combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Dictionary key type mismatch: %s" msg) in
              report_error err;
              (TyUnknown, combined_subst))
       | _ ->
           let err = make_error (TypeError "Not indexable") pos
             "Cannot index non-list/dict type" in
           report_error err;
           (TyUnknown, combined_subst))

  | EAttr (obj, _attr, pos) ->
      let (_obj_type, obj_subst) = infer_expr env obj in
      let err = make_error (TypeError "Attributes not implemented") pos
        "Attribute access not yet implemented" in
      report_error err;
      (TyUnknown, obj_subst)

  | ELambda (params, body, _) ->
      let param_env = List.fold_left
        (fun e (name, ty_opt) ->
          let ty = match ty_opt with
            | Some t -> type_expr_to_ty t
            | None -> fresh_type_var ()
          in
          add_binding name ty e)
        env params
      in
      let (body_type, body_subst) = infer_expr param_env body in
      let param_types = List.map
        (fun (name, _) ->
          match find_binding name param_env with
          | Some t -> apply_subst body_subst t
          | None -> TyUnknown)
        params
      in
      (TyFunc (param_types, body_type), body_subst)

  | EIf (cond, then_expr, else_opt, pos) ->
      let (cond_type, cond_subst) = infer_expr env cond in
      (try
         let bool_subst = unify (apply_subst cond_subst cond_type) TyBool in
         let env' = apply_subst_to_env bool_subst env in
         let (then_type, then_subst) = infer_expr env' then_expr in
         match else_opt with
         | None -> (then_type, compose_subst then_subst (compose_subst bool_subst cond_subst))
         | Some else_expr ->
             let (else_type, else_subst) = infer_expr env' else_expr in
             let combined = compose_subst else_subst (compose_subst then_subst (compose_subst bool_subst cond_subst)) in
             (try
                let unify_subst = unify (apply_subst combined then_type) (apply_subst combined else_type) in
                (apply_subst unify_subst then_type, compose_subst unify_subst combined)
              with Failure msg ->
                let err = make_error (TypeError msg) pos
                  (Printf.sprintf "If branches have different types: %s" msg) in
                report_error err;
                (then_type, combined))
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "Condition must be bool: %s" msg) in
         report_error err;
         (TyUnknown, cond_subst))

  | EMatch (_, _, pos) ->
      let err = make_error (TypeError "Match not implemented") pos
        "Match expressions not yet implemented" in
      report_error err;
      (TyUnknown, empty_subst)

  | EListComp (elem, var, iter, _cond_opt, pos) ->
      let (iter_type, iter_subst) = infer_expr env iter in
      let elem_type = fresh_type_var () in
      (try
         let list_subst = unify (apply_subst iter_subst iter_type) (TyList elem_type) in
         let env' = add_binding var elem_type (apply_subst_to_env list_subst env) in
         let (result_elem_type, elem_subst) = infer_expr env' elem in
         (TyList result_elem_type, compose_subst elem_subst (compose_subst list_subst iter_subst))
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "List comprehension iterator must be a list: %s" msg) in
         report_error err;
         (TyList TyUnknown, iter_subst))

and apply_subst_to_env subst env =
  {env with bindings = Env.StringMap.map (apply_subst subst) env.bindings}

let rec check_statement env = function
  | SExpr (e, _) ->
      let (_, subst) = infer_expr env e in
      (apply_subst_to_env subst env, subst)

  | SLet (name, ty_opt, value, pos) ->
      let (value_type, value_subst) = infer_expr env value in
      let env' = apply_subst_to_env value_subst env in
      (match ty_opt with
       | None ->
           let final_type = apply_subst value_subst value_type in
           let new_env = add_binding name final_type env' in
           let locked_env = lock_binding name new_env in
           (locked_env, value_subst)
       | Some ty_annot ->
           let expected_type = type_expr_to_ty ty_annot in
           (try
              let unify_subst = unify (apply_subst value_subst value_type) expected_type in
              let final_subst = compose_subst unify_subst value_subst in
              let new_env = add_binding name (apply_subst final_subst expected_type) (apply_subst_to_env final_subst env') in
              let locked_env = lock_binding name new_env in
              (locked_env, final_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type annotation mismatch for '%s': %s" name msg) in
              report_error err;
              let new_env = add_binding name expected_type env' in
              (new_env, value_subst)))

  | SAssign (name, value, pos) ->
      (match find_binding name env with
       | None ->
           let err = make_error (NameError name) pos
             (Printf.sprintf "Variable '%s' not defined" name) in
           report_error err;
           (env, empty_subst)
       | Some var_type ->
           if is_locked name env then
             let (value_type, value_subst) = infer_expr env value in
             (try
                let _ = unify (apply_subst value_subst value_type) (apply_subst value_subst var_type) in
                (apply_subst_to_env value_subst env, value_subst)
              with Failure msg ->
                let err = make_error (TypeError msg) pos
                  (Printf.sprintf "Cannot change type of '%s': %s" name msg) in
                report_error err;
                (env, empty_subst))
           else
             let (value_type, value_subst) = infer_expr env value in
             let new_env = update_binding name (apply_subst value_subst value_type) (apply_subst_to_env value_subst env) in
             (new_env, value_subst))

  | SDef (name, params, ret_opt, body, _) ->
      let param_env = List.fold_left
        (fun e (pname, pty_opt) ->
          let pty = match pty_opt with
            | Some t -> type_expr_to_ty t
            | None -> fresh_type_var ()
          in
          add_binding pname pty e)
        (create_child_env env) params
      in
      let (_, _) = check_statements param_env body in
      let param_types = List.map
        (fun (pname, _) ->
          match find_binding pname param_env with
          | Some t -> t
          | None -> TyUnknown)
        params
      in
      let ret_type = match ret_opt with
        | Some t -> type_expr_to_ty t
        | None -> TyNone
      in
      let func_type = TyFunc (param_types, ret_type) in
      let new_env = add_binding name func_type env in
      (new_env, empty_subst)

  | SReturn (_, _) -> (env, empty_subst)

  | SIf (cond, then_body, _elifs, _else_opt, pos) ->
      let (cond_type, cond_subst) = infer_expr env cond in
      (try
         let _ = unify (apply_subst cond_subst cond_type) TyBool in
         let (_, _) = check_statements (apply_subst_to_env cond_subst env) then_body in
         (env, cond_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "Condition must be bool: %s" msg) in
         report_error err;
         (env, empty_subst))

  | SWhile (cond, body, pos) ->
      let (cond_type, cond_subst) = infer_expr env cond in
      (try
         let _ = unify (apply_subst cond_subst cond_type) TyBool in
         let (_, _) = check_statements (apply_subst_to_env cond_subst env) body in
         (env, cond_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "While condition must be bool: %s" msg) in
         report_error err;
         (env, empty_subst))

  | SFor (var, iter, body, pos) ->
      let (iter_type, iter_subst) = infer_expr env iter in
      let elem_type = fresh_type_var () in
      (try
         let list_subst = unify (apply_subst iter_subst iter_type) (TyList elem_type) in
         let loop_env = add_binding var (apply_subst list_subst elem_type) (apply_subst_to_env list_subst env) in
         let (_, _) = check_statements loop_env body in
         (env, compose_subst list_subst iter_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "For loop iterator must be a list: %s" msg) in
         report_error err;
         (env, empty_subst))

  | SMatch (_, _, pos) ->
      let err = make_error (TypeError "Match not implemented") pos
        "Match statements not yet implemented" in
      report_error err;
      (env, empty_subst)

  | SClass (_, _, _, _, pos) ->
      let err = make_error (TypeError "Classes not implemented") pos
        "Classes not yet implemented" in
      report_error err;
      (env, empty_subst)

  | SInterface (_, _, pos) ->
      let err = make_error (TypeError "Interfaces not implemented") pos
        "Interfaces not yet implemented" in
      report_error err;
      (env, empty_subst)

  | SImport (_, _) | SFromImport (_, _, _) -> (env, empty_subst)

and check_statements env stmts =
  List.fold_left
    (fun (e, _) stmt -> check_statement e stmt)
    (env, empty_subst) stmts

let typecheck program =
  let (_, _) = check_statements builtin_env program in
  ()
