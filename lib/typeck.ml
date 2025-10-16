open Ast
open Types
open Env
open Error

let type_counter = ref 0

let fresh_type_var () =
  type_counter := !type_counter + 1;
  TyVar (Printf.sprintf "T%d" !type_counter)

(* 泛型实例收集器 *)
type generic_instance = {
  func_name: string;
  type_args: ty list;
  call_pos: position;
}

let generic_instances = ref []

let add_generic_instance func_name type_args pos =
  generic_instances := { func_name; type_args; call_pos = pos } :: !generic_instances

let get_generic_instances () = !generic_instances

let clear_generic_instances () = generic_instances := []

let rec infer_expr env = function
  | EInt (_, _) -> (TyInt, empty_subst)
  | EFloat (_, _) -> (TyFloat, empty_subst)
  | EString (_, _) -> (TyString, empty_subst)
  | EBool (_, _) -> (TyBool, empty_subst)

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
       | Add ->
           (* 特殊处理:Add 可以是整数相加或列表拼接 *)
           let t1' = apply_subst s3 t1 in
           let t2' = apply_subst s3 t2 in
           (match t1', t2' with
            | TyList elem_t1, TyList elem_t2 ->
                (* 列表拼接 *)
                (try
                   let s4 = unify elem_t1 elem_t2 in
                   (TyList (apply_subst s4 elem_t1), compose_subst s4 s3)
                 with Failure msg ->
                   let err = make_error (TypeError msg) pos
                     (Printf.sprintf "List concatenation requires same element types: %s" msg) in
                   report_error err;
                   (TyList elem_t1, s3))
            | TyInt, TyInt ->
                (* 整数相加 *)
                (TyInt, s3)
            | _, _ ->
                (* 尝试统一为整数 *)
                (try
                   let s4 = unify t1' TyInt in
                   let s5 = unify (apply_subst s4 t2') TyInt in
                   (TyInt, compose_subst s5 (compose_subst s4 s3))
                 with Failure msg ->
                   let err = make_error (TypeError msg) pos
                     (Printf.sprintf "Type error in arithmetic operation: %s" msg) in
                   report_error err;
                   (TyUnknown, s3)))
       | Sub | Mul | Div | Mod ->
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
              (* 如果涉及未知类型（来自泛型），允许比较但不报错 *)
              let t1' = apply_subst s3 t1 in
              let t2' = apply_subst s3 t2 in
              if t1' = TyUnknown || t2' = TyUnknown then
                (TyBool, s3)
              else begin
                let err = make_error (TypeError msg) pos
                  (Printf.sprintf "Type error in comparison: %s" msg) in
                report_error err;
                (TyBool, s3)
              end)
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
      (* 检查是否是泛型函数调用 *)
      (match func with
       | EVar (func_name, _) ->
           (* 尝试查找函数类型 *)
           let (func_type, func_subst) = infer_expr env func in
           let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
           let combined_subst = List.fold_left compose_subst func_subst arg_substs in
           let concrete_arg_types = List.map (apply_subst combined_subst) arg_types in
           let ret_type = fresh_type_var () in
           let expected_func_type = TyFunc (arg_types, ret_type) in
           (try
              let final_subst = unify (apply_subst combined_subst func_type) expected_func_type in
              (* 成功统一，可能是泛型函数 - 记录实例 *)
              add_generic_instance func_name concrete_arg_types pos;
              (apply_subst final_subst ret_type, compose_subst final_subst combined_subst)
            with Failure msg ->
              (* 对于泛型函数调用，occurs check 失败是预期的，不报告为错误 *)
              let has_prefix s prefix =
                let len_s = String.length s in
                let len_p = String.length prefix in
                len_s >= len_p && String.sub s 0 len_p = prefix
              in
              if has_prefix msg "Occurs check failed" then begin
                (* 泛型函数，记录实例并返回 *)
                add_generic_instance func_name concrete_arg_types pos;
                (ret_type, combined_subst)
              end else begin
                let err = make_error (TypeError msg) pos
                  (Printf.sprintf "Function call type error: %s" msg) in
                report_error err;
                (TyUnknown, combined_subst)
              end)
       | _ ->
           (* 非直接函数调用 *)
           let (func_type, func_subst) = infer_expr env func in
           let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
           let combined_subst = List.fold_left compose_subst func_subst arg_substs in
           let ret_type = fresh_type_var () in
           let expected_func_type = TyFunc (arg_types, ret_type) in
           (try
              let final_subst = unify (apply_subst combined_subst func_type) expected_func_type in
              (apply_subst final_subst ret_type, compose_subst final_subst combined_subst)
            with Failure _ ->
              (TyUnknown, combined_subst)))

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
       | TyTuple elem_types ->
           (* 元组索引必须是整数常量 *)
           (match idx with
            | EInt (n, _) when n >= 0 && n < List.length elem_types ->
                (List.nth elem_types n, combined_subst)
            | EInt (n, _) ->
                let err = make_error (TypeError "Index out of bounds") pos
                  (Printf.sprintf "Tuple index %d out of range (tuple has %d elements)"
                    n (List.length elem_types)) in
                report_error err;
                (TyUnknown, combined_subst)
            | _ ->
                let err = make_error (TypeError "Invalid tuple index") pos
                  "Tuple index must be an integer constant" in
                report_error err;
                (TyUnknown, combined_subst))
       | _ ->
           let err = make_error (TypeError "Not indexable") pos
             "Cannot index non-list/dict/tuple type" in
           report_error err;
           (TyUnknown, combined_subst))

  | ESlice (arr, start_opt, end_opt, pos) ->
      let (arr_type, arr_subst) = infer_expr env arr in
      let combined_subst = ref arr_subst in
      (match start_opt with
       | Some start_expr ->
           let (start_type, start_subst) = infer_expr env start_expr in
           combined_subst := compose_subst start_subst !combined_subst;
           (try
              let _ = unify (apply_subst !combined_subst start_type) TyInt in ()
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Slice start must be int: %s" msg) in
              report_error err)
       | None -> ());
      (match end_opt with
       | Some end_expr ->
           let (end_type, end_subst) = infer_expr env end_expr in
           combined_subst := compose_subst end_subst !combined_subst;
           (try
              let _ = unify (apply_subst !combined_subst end_type) TyInt in ()
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Slice end must be int: %s" msg) in
              report_error err)
       | None -> ());
      (match apply_subst !combined_subst arr_type with
       | TyList elem_type -> (TyList elem_type, !combined_subst)
       | _ ->
           let err = make_error (TypeError "Not sliceable") pos
             "Cannot slice non-list type" in
           report_error err;
           (TyUnknown, !combined_subst))

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

  | EMatch (scrut, cases, pos) ->
      let (scrut_type, scrut_subst) = infer_expr env scrut in
      let env' = apply_subst_to_env scrut_subst env in

      (* 检查每个case分支 *)
      let result_type = fresh_type_var () in
      let rec check_cases combined_subst = function
        | [] -> (result_type, combined_subst)
        | (pat, guard_opt, expr) :: rest ->
            (* 创建模式绑定的新环境 *)
            let rec bind_pattern env pat expected_type =
              match pat with
              | PVar name -> add_binding name expected_type env
              | PInt _ | PFloat _ | PString _ | PBool _ | PWildcard -> env
              | PTuple pats ->
                  (match expected_type with
                   | TyTuple elem_types when List.length pats = List.length elem_types ->
                       List.fold_left2 bind_pattern env pats elem_types
                   | _ -> env)
              | PList _ -> env  (* TODO: 实现列表模式 *)
              | PType (_, _) -> env  (* TODO: 实现类型模式 *)
              | PEnumVariant (_, _, pats) ->
                  (* 枚举模式暂时不检查内部参数类型 *)
                  List.fold_left (fun e p -> bind_pattern e p (fresh_type_var ())) env pats
            in
            let case_env = bind_pattern env' pat (apply_subst combined_subst scrut_type) in
            (* 检查守卫条件类型 *)
            let (guard_env, guard_subst) = match guard_opt with
              | None -> (case_env, combined_subst)
              | Some guard_expr ->
                  let (guard_type, g_subst) = infer_expr case_env guard_expr in
                  let combined_g = compose_subst g_subst combined_subst in
                  (try
                     let bool_subst = unify (apply_subst combined_g guard_type) TyBool in
                     (case_env, compose_subst bool_subst combined_g)
                   with Failure msg ->
                     let err = make_error (TypeError msg) pos
                       (Printf.sprintf "Guard condition must be bool: %s" msg) in
                     report_error err;
                     (case_env, combined_g))
            in
            let (case_type, case_subst) = infer_expr guard_env expr in
            let combined = compose_subst case_subst guard_subst in
            (try
               let unify_subst = unify (apply_subst combined result_type) (apply_subst combined case_type) in
               check_cases (compose_subst unify_subst combined) rest
             with Failure msg ->
               let err = make_error (TypeError msg) pos
                 (Printf.sprintf "Match case has incompatible type: %s" msg) in
               report_error err;
               check_cases combined rest)
      in
      let result = check_cases scrut_subst cases in

      (* 穷尽性检查 *)
      (match Exhaustiveness.check_exhaustiveness env' (apply_subst scrut_subst scrut_type) cases pos with
       | Some (pos, missing) ->
           let missing_str = String.concat ", " missing in
           let err = make_error (TypeError "Non-exhaustive match") pos
             (Printf.sprintf "Match is not exhaustive. Missing cases: %s" missing_str) in
           report_error err
       | None -> ());

      (* 不可达模式检查 *)
      let unreachable_indices = Exhaustiveness.check_reachability cases in
      List.iter (fun idx ->
        let (pat, _, _) = List.nth cases idx in
        let pat_str = match pat with
          | PEnumVariant (_, v, _) -> v
          | PInt n -> string_of_int n
          | PBool b -> string_of_bool b
          | _ -> "_"
        in
        let err = make_error (TypeError "Unreachable pattern") pos
          (Printf.sprintf "Pattern '%s' (case %d) is unreachable" pat_str (idx + 1)) in
        report_error err
      ) unreachable_indices;

      result

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

  | EEnumVariant (enum_name, _variant_name, args, _pos) ->
      let (_arg_types, _arg_substs) = List.split (List.map (infer_expr env) args) in
      let combined_subst = List.fold_left compose_subst empty_subst _arg_substs in
      (TyEnum (enum_name, []), combined_subst)

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

  | SLetPat (pat, value, pos) ->
      let (value_type, value_subst) = infer_expr env value in
      let env' = apply_subst_to_env value_subst env in
      (* 从模式中提取变量绑定并检查类型匹配 *)
      let rec check_pattern env pat expected_type =
        match pat with
        | PVar name ->
            let new_env = add_binding name expected_type env in
            let locked_env = lock_binding name new_env in
            locked_env
        | PTuple pats ->
            (match expected_type with
             | TyTuple elem_types when List.length pats = List.length elem_types ->
                 List.fold_left2 check_pattern env pats elem_types
             | _ ->
                 let err = make_error (TypeError "Pattern mismatch") pos
                   (Printf.sprintf "Cannot unpack value into tuple pattern") in
                 report_error err;
                 env)
        | _ ->
            let err = make_error (TypeError "Unsupported pattern") pos
              "Only variable and tuple patterns are supported in let bindings" in
            report_error err;
            env
      in
      let final_env = check_pattern env' pat (apply_subst value_subst value_type) in
      (final_env, value_subst)

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

  | SDef (name, _type_params, params, ret_opt, body, _) ->
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

  | SFor (pat, iter, body, pos) ->
      let (iter_type, iter_subst) = infer_expr env iter in
      let elem_type = fresh_type_var () in
      (try
         let list_subst = unify (apply_subst iter_subst iter_type) (TyList elem_type) in
         let env' = apply_subst_to_env list_subst env in
         let final_elem_type = apply_subst list_subst elem_type in

         (* 从模式中提取变量绑定并检查类型匹配 *)
         let rec check_pattern_for env pat expected_type =
           match pat with
           | PVar name ->
               add_binding name expected_type env
           | PTuple pats ->
               (match expected_type with
                | TyTuple elem_types when List.length pats = List.length elem_types ->
                    List.fold_left2 check_pattern_for env pats elem_types
                | _ ->
                    let err = make_error (TypeError "Pattern mismatch") pos
                      (Printf.sprintf "Cannot unpack iterator elements into tuple pattern") in
                    report_error err;
                    env)
           | _ ->
               let err = make_error (TypeError "Unsupported pattern") pos
                 "Only variable and tuple patterns are supported in for loops" in
               report_error err;
               env
         in
         let loop_env = check_pattern_for env' pat final_elem_type in
         let (_, _) = check_statements loop_env body in
         (env, compose_subst list_subst iter_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "For loop iterator must be a list: %s" msg) in
         report_error err;
         (env, empty_subst))

  | SMatch (scrut, cases, _pos) ->
      let (scrut_type, scrut_subst) = infer_expr env scrut in
      let env' = apply_subst_to_env scrut_subst env in

      (* 检查每个case分支 *)
      let rec check_cases combined_subst = function
        | [] -> combined_subst
        | (pat, guard_opt, body) :: rest ->
            (* 创建模式绑定的新环境 *)
            let rec bind_pattern env pat expected_type =
              match pat with
              | PVar name -> add_binding name expected_type env
              | PInt _ | PFloat _ | PString _ | PBool _ | PWildcard -> env
              | PTuple pats ->
                  (match expected_type with
                   | TyTuple elem_types when List.length pats = List.length elem_types ->
                       List.fold_left2 bind_pattern env pats elem_types
                   | _ -> env)
              | PList _ -> env  (* TODO: 实现列表模式 *)
              | PType (_, _) -> env  (* TODO: 实现类型模式 *)
              | PEnumVariant (_, _, pats) ->
                  (* 枚举模式暂时不检查内部参数类型 *)
                  List.fold_left (fun e p -> bind_pattern e p (fresh_type_var ())) env pats
            in
            let case_env = bind_pattern env' pat (apply_subst combined_subst scrut_type) in
            (* 检查守卫条件类型 *)
            let (guard_env, guard_subst) = match guard_opt with
              | None -> (case_env, combined_subst)
              | Some guard_expr ->
                  let (guard_type, g_subst) = infer_expr case_env guard_expr in
                  let combined_g = compose_subst g_subst combined_subst in
                  (try
                     let bool_subst = unify (apply_subst combined_g guard_type) TyBool in
                     (case_env, compose_subst bool_subst combined_g)
                   with Failure msg ->
                     let err = make_error (TypeError msg) _pos
                       (Printf.sprintf "Guard condition must be bool: %s" msg) in
                     report_error err;
                     (case_env, combined_g))
            in
            let (_, case_subst) = check_statements guard_env body in
            let combined = compose_subst case_subst guard_subst in
            check_cases combined rest
      in
      let final_subst = check_cases scrut_subst cases in

      (* 穷尽性检查 *)
      (match Exhaustiveness.check_exhaustiveness env' (apply_subst scrut_subst scrut_type) cases _pos with
       | Some (pos, missing) ->
           let missing_str = String.concat ", " missing in
           let err = make_error (TypeError "Non-exhaustive match") pos
             (Printf.sprintf "Match is not exhaustive. Missing cases: %s" missing_str) in
           report_error err
       | None -> ());

      (* 不可达模式检查 *)
      let unreachable_indices = Exhaustiveness.check_reachability cases in
      List.iter (fun idx ->
        let (pat, _, _) = List.nth cases idx in
        let pat_str = match pat with
          | PEnumVariant (_, v, _) -> v
          | PInt n -> string_of_int n
          | PBool b -> string_of_bool b
          | _ -> "_"
        in
        let err = make_error (TypeError "Unreachable pattern") _pos
          (Printf.sprintf "Pattern '%s' (case %d) is unreachable" pat_str (idx + 1)) in
        report_error err
      ) unreachable_indices;

      (env, final_subst)

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

  | SEnum (name, _type_params, _variants, _) ->
      let enum_type = TyEnum (name, []) in
      let new_env = add_binding name enum_type env in
      (new_env, empty_subst)

  | SIndexAssign (arr, idx, value, pos) ->
      let (arr_type, arr_subst) = infer_expr env arr in
      let (idx_type, idx_subst) = infer_expr env idx in
      let (value_type, value_subst) = infer_expr env value in
      let combined_subst = compose_subst value_subst (compose_subst idx_subst arr_subst) in
      (match apply_subst combined_subst arr_type with
       | TyList elem_type ->
           (try
              let _ = unify (apply_subst combined_subst idx_type) TyInt in
              let _ = unify (apply_subst combined_subst value_type) elem_type in
              (apply_subst_to_env combined_subst env, combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Index assignment type error: %s" msg) in
              report_error err;
              (env, empty_subst))
       | TyDict (key_type, val_type) ->
           (try
              let _ = unify (apply_subst combined_subst idx_type) key_type in
              let _ = unify (apply_subst combined_subst value_type) val_type in
              (apply_subst_to_env combined_subst env, combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Dictionary assignment type error: %s" msg) in
              report_error err;
              (env, empty_subst))
       | _ ->
           let err = make_error (TypeError "Not indexable") pos
             "Cannot index-assign to non-list/dict type" in
           report_error err;
           (env, empty_subst))

and check_statements env stmts =
  List.fold_left
    (fun (e, _) stmt -> check_statement e stmt)
    (env, empty_subst) stmts

let typecheck program =
  let (_, _) = check_statements builtin_env program in
  ()
