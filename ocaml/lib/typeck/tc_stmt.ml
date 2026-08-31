open Ast
open Types
open Env
open Error
open Tc_utils

(* 前向声明：表达式类型推导函数 *)
let infer_expr = ref (fun _ _ -> (TyUnknown, empty_subst))

let set_infer_expr f = infer_expr := f

let imported_const_type env const_info =
  match const_info.const_type with
  | Some type_expression -> type_expr_to_ty type_expression
  | None ->
      (match const_info.const_value with
       | EInt _ -> TyInt
       | EBool _ -> TyBool
       | EByte _ -> TyByte
       | ERune _ -> TyRune
       | EFloat _ -> TyFloat
       | EString _ -> TyStr
       | EVar (name, _) ->
           (match find_binding name env with
            | Some ty -> ty
            | None -> TyUnknown)
       | _ -> TyUnknown)

let add_imported_impl env impl_info =
  match impl_info.impl_interface with
  | None -> env
  | Some interface_name ->
      let target_type = resolve_type_expr env impl_info.impl_target in
      let method_type = function
        | ImplMethod (method_name, _, parameters, return_type, _, _) ->
            let parameter_types = List.mapi (fun index (parameter_name, type_expression, _) ->
              if index = 0 && parameter_name = "self" then
                target_type
              else
                match type_expression with
                | Some type_expression -> resolve_type_expr env type_expression
                | None -> fresh_type_var ()) parameters in
            let result_type = match return_type with
              | Some type_expression -> resolve_type_expr env type_expression
              | None -> TyNone
            in
            Some (method_name, TyFunc (parameter_types, result_type))
        | ImplAssocType _
        | ImplAssocConst _ -> None
      in
      let methods = List.filter_map method_type impl_info.impl_members in
      let impl_def = {
        Env.impl_interface_name = interface_name;
        Env.impl_target_type = target_type;
        Env.impl_methods = List.fold_left (fun methods (name, method_type) ->
          Env.StringMap.add name method_type methods
        ) Env.StringMap.empty methods;
      } in
      Env.add_impl impl_def env

let add_module_namespace env module_name imports =
  let function_type acc_env def_info =
    let parameter_types = List.map (fun (_, ty_opt, _) ->
      match ty_opt with
      | Some type_expression -> resolve_type_expr acc_env type_expression
      | None -> fresh_type_var ()) def_info.def_params in
    let return_type = match def_info.def_return_type with
      | Some type_expression -> resolve_type_expr acc_env type_expression
      | None -> fresh_type_var ()
    in
    TyFunc (parameter_types, return_type)
  in
  let methods = List.fold_left (fun methods (_, symbol) ->
    match symbol with
    | Module_loader.ExportedFunc (name, def_info) ->
        Env.StringMap.add name (function_type env def_info) methods
    | _ -> methods
  ) Env.StringMap.empty imports in
  let module_def = {
    Env.struct_name = module_name;
    Env.struct_type_params = [];
    Env.struct_fields = Env.StringMap.empty;
    Env.struct_methods = methods;
  } in
  let env_with_struct = Env.add_struct module_name module_def env in
  add_binding module_name (TyStruct (module_name, [])) env_with_struct

(* 语句类型检查 *)
let rec check_statement env = function
  | SExpr (e, _) ->
      let (_, subst) = !infer_expr env e in
      (apply_subst_to_env subst env, subst)

  | SLet let_info ->
      let name = let_info.let_name in
      let ty_opt = let_info.let_type in
      let value = let_info.let_value in
      let pos = let_info.let_name_pos in
      let (value_type, value_subst) = !infer_expr env value in
      let env' = apply_subst_to_env value_subst env in
      (match ty_opt with
       | None ->
           let final_type = apply_subst value_subst value_type in
           let new_env = add_binding name final_type env' in
           let locked_env = lock_binding name new_env in
           (locked_env, value_subst)
       | Some ty_annot ->
           let expected_type = type_expr_to_ty ty_annot in

           (match (ty_annot, apply_subst value_subst value_type) with
            | (TVar interface_name, concrete_type)
              when Env.find_interface interface_name env' <> None ->
                let iface_def = Option.get (Env.find_interface interface_name env') in
                let interface_type = TyInterface (interface_name, []) in
                (match concrete_type with
                 | TyStruct (struct_name, _) ->
                     (match Env.find_struct struct_name env' with
                      | Some struct_def ->
                          let has_explicit_impl =
                            match Env.find_impl_for_type
                              (TyStruct (struct_name, [])) interface_name env' with
                            | Some _ -> true
                            | None -> false
                          in
                          if Env.struct_implements_interface struct_def iface_def ||
                             has_explicit_impl then
                            let new_env = add_binding name interface_type env' in
                            let locked_env = lock_binding name new_env in
                            (locked_env, value_subst)
                          else
                            let err = make_error (TypeError "Interface not implemented") pos
                              (Printf.sprintf "Struct '%s' does not implement interface '%s'" struct_name interface_name) in
                            report_error err;
                            let new_env = add_binding name interface_type env' in
                            (new_env, value_subst)
                      | None ->
                          let err = make_error (NameError struct_name) pos
                            (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                          report_error err;
                          let new_env = add_binding name interface_type env' in
                          (new_env, value_subst))
                 | TyEnum (enum_name, _) ->
                     if Env.find_impl_for_type (TyEnum (enum_name, [])) interface_name env' <> None then
                       let new_env = add_binding name interface_type env' in
                       let locked_env = lock_binding name new_env in
                       (locked_env, value_subst)
                     else
                       let err = make_error (TypeError "Interface not implemented") pos
                         (Printf.sprintf "Enum '%s' does not implement interface '%s'" enum_name interface_name) in
                       report_error err;
                       let new_env = add_binding name interface_type env' in
                       (new_env, value_subst)
                 | _ ->
                     let new_env = add_binding name interface_type env' in
                     let locked_env = lock_binding name new_env in
                     (locked_env, value_subst))
            | (TVar interface_name, _) when Env.find_interface interface_name env' = None ->
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
                   (new_env, value_subst))
            | _ ->
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
                   (new_env, value_subst))))

  | SConst const_info ->
      let name = const_info.const_name in
      let value = const_info.const_value in
      let pos = const_info.const_name_pos in
      let (value_type, value_subst) = !infer_expr env value in
      let resolved_value_type = apply_subst value_subst value_type in
      let env' = apply_subst_to_env value_subst env in
      (match const_info.const_type with
       | None ->
           let new_env = add_binding name resolved_value_type env' in
           (lock_binding name new_env, value_subst)
       | Some type_annotation ->
           let expected_type = type_expr_to_ty type_annotation in
           (try
              let unify_subst = unify resolved_value_type expected_type in
              let final_subst = compose_subst unify_subst value_subst in
              let final_type = apply_subst final_subst expected_type in
              let new_env = add_binding name final_type (apply_subst_to_env final_subst env') in
              (lock_binding name new_env, final_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Constant type mismatch for '%s': %s" name msg) in
              report_error err;
              let new_env = add_binding name expected_type env' in
              (lock_binding name new_env, value_subst)))

  | SLetPat (pat, value, pos) ->
      let (value_type, value_subst) = !infer_expr env value in
      let env' = apply_subst_to_env value_subst env in
      (* 确保value_type被完全应用替换 *)
      let resolved_value_type = apply_subst value_subst value_type in
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
        | PList pats ->
            (match expected_type with
             | TyList elem_type ->
                 List.fold_left (fun env pat -> check_pattern env pat elem_type) env pats
             | _ ->
                 let err = make_error (TypeError "Pattern mismatch") pos
                   (Printf.sprintf "Cannot unpack value into list pattern, expected list type but got %s"
                     (Types.ty_to_string expected_type)) in
                 report_error err;
                 env)
        | PCons (head_pat, tail_pat) ->
            (* head :: tail: head是元素类型,tail是列表类型 *)
            (match expected_type with
             | TyList elem_type ->
                 let env1 = check_pattern env head_pat elem_type in
                 check_pattern env1 tail_pat expected_type  (* tail也是列表类型 *)
             | _ ->
                 let err = make_error (TypeError "Pattern mismatch") pos
                   (Printf.sprintf "Cannot unpack value into cons pattern, expected list type but got %s"
                     (Types.ty_to_string expected_type)) in
                 report_error err;
                 env)
        | PStruct (struct_name, field_pats) ->
            (* 结构体解构：如果struct_name为空字符串，从expected_type推断 *)
            let actual_struct_name =
              if struct_name = "" then
                (* 从expected_type推断结构体名称 *)
                match expected_type with
                | TyStruct (name, _) -> name
                | _ -> ""  (* 无法推断，后续会报错 *)
              else
                struct_name
            in
            (match expected_type with
             | TyStruct (type_struct_name, _) when type_struct_name = actual_struct_name ->
                 (match Env.find_struct actual_struct_name env with
                  | Some struct_def ->
                      List.fold_left (fun env_acc (field_name, field_pat) ->
                        match Env.StringMap.find_opt field_name struct_def.struct_fields with
                        | Some field_type -> check_pattern env_acc field_pat field_type
                        | None ->
                            let err = make_error (TypeError "Unknown field") pos
                              (Printf.sprintf "Struct '%s' has no field '%s'" actual_struct_name field_name) in
                            report_error err;
                            env_acc
                      ) env field_pats
                  | None ->
                      let err = make_error (NameError actual_struct_name) pos
                        (Printf.sprintf "Struct '%s' is not defined" actual_struct_name) in
                      report_error err;
                      env)
             | _ ->
                 let err = make_error (TypeError "Pattern mismatch") pos
                   (Printf.sprintf "Cannot unpack value into struct pattern, expected struct but got %s"
                     (Types.ty_to_string expected_type)) in
                 report_error err;
                 env)
        | _ ->
            let err = make_error (TypeError "Unsupported pattern") pos
              "Only variable, tuple, list, cons, and struct patterns are supported in let bindings" in
            report_error err;
            env
      in
      let final_env = check_pattern env' pat resolved_value_type in
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
             let (value_type, value_subst) = !infer_expr env value in
             (try
                let _ = unify (apply_subst value_subst value_type) (apply_subst value_subst var_type) in
                (apply_subst_to_env value_subst env, value_subst)
              with Failure msg ->
                let err = make_error (TypeError msg) pos
                  (Printf.sprintf "Cannot change type of '%s': %s" name msg) in
                report_error err;
                (env, empty_subst))
           else
             let (value_type, value_subst) = !infer_expr env value in
             let new_env = update_binding name (apply_subst value_subst value_type) (apply_subst_to_env value_subst env) in
             (new_env, value_subst))

  | SDef def_info ->
      let name = def_info.def_name in
      let params = def_info.def_params in
      let ret_opt = def_info.def_return_type in
      let body = def_info.def_body in
      let param_env = List.fold_left
        (fun e (pname, pty_opt, _default) ->
          let pty = match pty_opt with
            | Some t -> resolve_type_expr env t
            | None -> fresh_type_var ()
          in
          add_binding pname pty e)
        (create_child_env env) params
      in
      let (_, _) = check_statements param_env body in
      let param_types = List.map
        (fun (pname, _, _) ->
          match find_binding pname param_env with
          | Some t -> t
          | None -> TyUnknown)
        params
      in
      let ret_type = match ret_opt with
        | Some t -> resolve_type_expr env t
        | None -> TyNone
      in
      let func_type = TyFunc (param_types, ret_type) in
      let default_values = List.map (fun (_, _, default_opt) -> default_opt) params in
      let new_env = Env.add_function_with_defaults name func_type default_values env in
      (new_env, empty_subst)

  | SReturn (_, _) -> (env, empty_subst)

  | SIf (cond, then_body, elifs, else_opt, pos) ->
      let (cond_type, cond_subst) = !infer_expr env cond in
      (try
         let _ = unify (apply_subst cond_subst cond_type) TyBool in
         let branch_env = apply_subst_to_env cond_subst env in
         let (_, _) = check_statements branch_env then_body in
         List.iter (fun (elif_cond, elif_body) ->
           let (elif_type, elif_subst) = !infer_expr branch_env elif_cond in
           let _ = unify (apply_subst elif_subst elif_type) TyBool in
           let (_, _) = check_statements (apply_subst_to_env elif_subst branch_env) elif_body in
           ()) elifs;
         (match else_opt with
          | Some else_body ->
              let (_, _) = check_statements branch_env else_body in
              ()
          | None -> ());
         (env, cond_subst)
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "Condition must be bool: %s" msg) in
         report_error err;
         (env, empty_subst))

  | SBreak _ -> (env, empty_subst)
  | SContinue _ -> (env, empty_subst)
  | SWhile (cond, body, pos) ->
      let (cond_type, cond_subst) = !infer_expr env cond in
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
      let (iter_type, iter_subst) = !infer_expr env iter in
      let iter_type = apply_subst iter_subst iter_type in
      let element_type = match iter_type with
        | TyList element_type
        | TyInterface ("Iterator", [element_type])
        | TyInterface ("Iterable", [element_type]) -> Some element_type
        | TyStr -> Some TyRune
        | TyBytes -> Some TyByte
        | concrete_type ->
            (match Env.find_impl_for_type concrete_type "Iterator" env with
             | Some impl ->
                 (match Env.StringMap.find_opt "next" impl.impl_methods with
                  | Some (TyFunc (_, element_type)) -> Some element_type
                  | _ -> None)
             | None ->
                 (match Env.find_impl_method_for_type concrete_type "iter" env with
                  | Some (TyFunc (_, TyInterface ("Iterator", [element_type]))) -> Some element_type
                  | _ -> None))
      in
      (match element_type with
       | Some final_elem_type ->
           let env' = apply_subst_to_env iter_subst env in

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
                        "Cannot unpack iterator elements into tuple pattern" in
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
           (env, iter_subst)
       | None ->
           let err = make_error (TypeError "Not iterable") pos
             "for requires a list, string, bytes, Iterator or Iterable" in
           report_error err;
           (env, empty_subst))


  | SInterface interface_info ->
      let name = interface_info.interface_name in
      let type_params = interface_info.interface_type_params in
      let members = interface_info.interface_members in
      let pos = interface_info.interface_pos in
      (match Env.find_interface name env with
       | Some _ ->
           let err = make_error (TypeError "Interface already defined") pos
             (Printf.sprintf "Interface '%s' is already defined" name) in
           report_error err;
           (env, empty_subst)
       | None ->
           let check_interface_member = function
             | IMethod (_, _, params, ret_ty_opt, default_impl_opt, _) ->
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 ) params in
                 let ret_type = match ret_ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> TyNone
                 in
                 (match default_impl_opt with
                  | Some body ->
                      let method_env = List.fold_left
                        (fun e (pname, pty_opt, _) ->
                          let pty = match pty_opt with
                            | Some t -> type_expr_to_ty t
                            | None -> fresh_type_var ()
                          in
                          Env.add_binding pname pty e)
                        (Env.create_child_env env) params
                      in
                      let (_, _) = check_statements method_env body in
                      ()
                  | None -> ());
                 TyFunc (param_types, ret_type)

             | IAssocType (_, default_ty_opt, _) ->
                 (match default_ty_opt with
                  | Some ty -> type_expr_to_ty ty
                  | None -> fresh_type_var ())

             | IAssocConst (const_name, const_ty, const_val, c_pos) ->
                 let expected_ty = type_expr_to_ty const_ty in
                 let (actual_ty, val_subst) = !infer_expr env const_val in
                 (try
                    let _ = unify (apply_subst val_subst actual_ty) expected_ty in
                    expected_ty
                  with Failure msg ->
                    let err = make_error (TypeError msg) c_pos
                      (Printf.sprintf "Constant '%s' type mismatch: %s" const_name msg) in
                    report_error err;
                    expected_ty)

             | _ -> TyUnknown
           in

           List.iter (fun member ->
             let _ = check_interface_member member in ()
           ) members;

           let iface_def = {
             Env.iface_name = name;
             Env.iface_type_params = type_params;
             Env.iface_members = members;
           } in
           let new_env = Env.add_interface name iface_def env in
           (new_env, empty_subst))

  | SImpl (impl_block, pos) ->
      (* 辅助函数：将类型表达式转换为类型，自动识别结构体和枚举 *)
      let type_expr_to_ty_with_struct ty_expr =
        match ty_expr with
        | TVar name ->
            (* 检查是否是已定义的结构体或枚举 *)
            (match Env.find_struct name env with
             | Some _ -> TyStruct (name, [])
             | None ->
                 (match Env.find_enum name env with
                  | Some _ -> TyEnum (name, [])
                  | None -> resolve_type_expr env ty_expr))
        | _ -> resolve_type_expr env ty_expr
      in

      (* 将 target 转换为类型，如果是结构体名称则转换为 TyStruct *)
      let target_ty = type_expr_to_ty_with_struct impl_block.impl_target in

      (* Self 类型解析为 impl 的目标类型 *)
      let resolve_self_type ty_expr =
        match ty_expr with
        | TSelf -> target_ty
        | _ -> type_expr_to_ty_with_struct ty_expr
      in

      (match impl_block.impl_interface with
       | None ->
           (env, empty_subst)
       | Some interface_name ->
           (match Env.find_interface interface_name env with
            | None ->
                let err = make_error (TypeError "Interface not found") pos
                  (Printf.sprintf "Interface '%s' is not defined" interface_name) in
                report_error err;
                (env, empty_subst)
            | Some iface_def ->
           (* 创建类型参数替换映射：interface type params -> impl type params *)
           (* 例如：impl Add[Vec2] for Vec2，则 T -> Vec2 *)
           let type_param_map =
             try
               List.combine iface_def.iface_type_params impl_block.impl_type_params
             with Invalid_argument _ ->
               (* 类型参数数量不匹配，报错但继续 *)
               if List.length impl_block.impl_type_params > 0 then begin
                 let err = make_error (TypeError "Type parameter mismatch") pos
                   (Printf.sprintf "Interface '%s' expects %d type parameters but got %d"
                     interface_name
                     (List.length iface_def.iface_type_params)
                     (List.length impl_block.impl_type_params)) in
                 report_error err
               end;
               []
           in

           (* 类型替换函数：将类型表达式中的类型变量替换为具体类型 *)
           let rec substitute_type_expr type_map ty_expr =
             match ty_expr with
             | TVar name ->
                 (try
                    let replacement = List.assoc name type_map in
                    (* 将字符串转换回 type_expr *)
                    TVar replacement
                  with Not_found -> ty_expr)
             | TList elem_ty -> TList (substitute_type_expr type_map elem_ty)
             | TTuple tys -> TTuple (List.map (substitute_type_expr type_map) tys)
             | TOption ty -> TOption (substitute_type_expr type_map ty)
             | TResult (ok_ty, err_ty) ->
                 TResult (substitute_type_expr type_map ok_ty, substitute_type_expr type_map err_ty)
             | TDict (k, v) ->
                 TDict (substitute_type_expr type_map k, substitute_type_expr type_map v)
             | TFunc (params, ret) ->
                 TFunc (List.map (substitute_type_expr type_map) params,
                        substitute_type_expr type_map ret)
             | TUnion tys -> TUnion (List.map (substitute_type_expr type_map) tys)
             | TStruct (name, tys) ->
                 TStruct (name, List.map (substitute_type_expr type_map) tys)
             | TEnum (name, tys) ->
                 TEnum (name, List.map (substitute_type_expr type_map) tys)
             | TGeneric (name, ty) ->
                 TGeneric (name, substitute_type_expr type_map ty)
             | _ -> ty_expr
           in

           let required_methods = List.filter_map (function
             | IMethod (name, _, params, ret_ty_opt, default_impl_opt, _) ->
                 if default_impl_opt = None then
                   (* 应用类型参数替换，同时处理 self 参数 *)
                   let param_types = List.mapi (fun i (pname, ty_opt, _) ->
                     if i = 0 && pname = "self" then
                       (* self 参数的类型是 impl 的目标类型 *)
                       target_ty
                     else
                       match ty_opt with
                       | Some ty ->
                           let substituted_ty = substitute_type_expr type_param_map ty in
                           resolve_self_type substituted_ty
                       | None -> fresh_type_var ()
                   ) params in
                   let ret_type = match ret_ty_opt with
                     | Some ty ->
                         let substituted_ty = substitute_type_expr type_param_map ty in
                         resolve_self_type substituted_ty
                     | None -> TyNone
                   in
                   Some (name, TyFunc (param_types, ret_type))
                 else
                   None
             | _ -> None
           ) iface_def.iface_members in

           let impl_methods = List.filter_map (function
             | ImplMethod (name, _, params, ret_ty_opt, body, _) ->
                 (* 第一个参数如果是 self，类型应该是目标类型 *)
                 let param_types = List.mapi (fun i (pname, ty_opt, _) ->
                   if i = 0 && pname = "self" then
                     (* self 参数的类型是 impl 的目标类型 *)
                     target_ty
                   else
                     match ty_opt with
                     | Some ty -> resolve_self_type ty
                     | None -> fresh_type_var ()
                 ) params in
                 let ret_type = match ret_ty_opt with
                   | Some ty -> resolve_self_type ty
                   | None -> TyNone
                 in

                 let method_env = List.fold_left2
                   (fun e (pname, pty_opt, _) inferred_ty ->
                     let pty = if pname = "self" then
                       (* self 使用推断的目标类型 *)
                       inferred_ty
                     else
                       match pty_opt with
                       | Some t -> resolve_self_type t
                       | None -> inferred_ty
                     in
                     Env.add_binding pname pty e)
                   (Env.create_child_env env) params param_types
                 in
                 let (_, _) = check_statements method_env body in

                 Some (name, TyFunc (param_types, ret_type))
             | _ -> None
           ) impl_block.impl_members in

           let missing_methods = List.filter (fun (req_name, req_ty) ->
             not (List.exists (fun (impl_name, impl_ty) ->
               impl_name = req_name &&
               (try
                  let _ = unify impl_ty req_ty in
                  true
                with Failure msg ->
                  (* 调试：打印类型不匹配信息 *)
                  Printf.eprintf "Method '%s' type mismatch:\n" req_name;
                  Printf.eprintf "  Required: %s\n" (Types.ty_to_string req_ty);
                  Printf.eprintf "  Impl:     %s\n" (Types.ty_to_string impl_ty);
                  Printf.eprintf "  Error: %s\n" msg;
                  false)
             ) impl_methods)
           ) required_methods in

           if missing_methods <> [] then begin
             let missing_names = String.concat ", " (List.map fst missing_methods) in
             let err = make_error (TypeError "Incomplete implementation") pos
               (Printf.sprintf "Impl block for '%s' is missing required methods: %s"
                 interface_name missing_names) in
             report_error err
           end;

           let all_interface_methods = List.filter_map (function
             | IMethod (name, _, _, _, _, _) -> Some name
             | _ -> None
           ) iface_def.iface_members in

           List.iter (fun (impl_method_name, _) ->
             if not (List.mem impl_method_name all_interface_methods) then
               let err = make_error (TypeError "Unknown method") pos
                 (Printf.sprintf "Method '%s' is not defined in interface '%s'"
                   impl_method_name interface_name) in
               report_error err
           ) impl_methods;

           let impl_methods_map = List.fold_left (fun map (name, ty) ->
             Env.StringMap.add name ty map
           ) Env.StringMap.empty impl_methods in

           let impl_def = {
             Env.impl_interface_name = interface_name;
             Env.impl_target_type = target_ty;
             Env.impl_methods = impl_methods_map;
           } in
           let new_env = Env.add_impl impl_def env in
           (new_env, empty_subst)))

  | SImport (module_path, alias, _pos) ->
      (match Module_loader.import_all_from_module module_path alias with
       | Error msg ->
           Printf.eprintf "Import error: %s\n" msg;
           (env, empty_subst)
       | Ok imports ->
           let new_env = List.fold_left (fun acc_env (name, symbol) ->
             match symbol with
             | Module_loader.ExportedFunc (_original_name, def_info) ->
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> resolve_type_expr acc_env ty
                   | None -> fresh_type_var ()
                 ) def_info.def_params in
                 let ret_type = match def_info.def_return_type with
                   | Some ty -> resolve_type_expr acc_env ty
                   | None -> fresh_type_var ()
                 in
                 let func_type = TyFunc (param_types, ret_type) in
                 let default_values = List.map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
                 Env.add_function_with_defaults name func_type default_values acc_env
             | Module_loader.ExportedConst (_original_name, const_info) ->
                 add_binding name (imported_const_type acc_env const_info) acc_env
             | Module_loader.ExportedLet (_original_name, let_info) ->
                 add_binding name (imported_const_type acc_env {
                   const_name = let_info.let_name;
                   const_name_pos = let_info.let_pos;
                   const_type = let_info.let_type;
                   const_value = let_info.let_value;
                   const_pos = let_info.let_pos;
                 }) acc_env
             | Module_loader.ExportedInterface (_original_name, interface_info) ->
                 let iface_def = {
                   Env.iface_name = interface_info.interface_name;
                   Env.iface_type_params = interface_info.interface_type_params;
                   Env.iface_members = interface_info.interface_members;
                 } in
                 Env.add_interface name iface_def acc_env
             | Module_loader.ExportedStruct (_original_name, struct_info) ->
                 let resolve_imported_type type_expression =
                   match type_expression with
                   | TVar type_name when type_name = struct_info.struct_name ->
                       TyStruct (struct_info.struct_name, [])
                   | _ -> resolve_type_expr acc_env type_expression
                 in
                 let field_list = List.filter_map (function
                   | SField field -> Some field
                   | SMethod _ -> None
                 ) struct_info.struct_members in

                 let struct_fields_list = List.map (fun field ->
                   let field_name = match field.field_name with
                     | Some name -> name
                     | None ->
                         (match field.field_type with
                          | TVar type_name -> type_name
                          | _ -> "_invalid_")
                   in
                   (field_name, resolve_imported_type field.field_type)
                 ) field_list in

                 let struct_fields = List.fold_left (fun acc (name, ty) ->
                   Env.StringMap.add name ty acc
                 ) Env.StringMap.empty struct_fields_list in

                 let method_list = List.filter_map (function
                   | SField _ -> None
                   | SMethod (method_name, type_params, params, ret_ty_opt, _body, _) ->
                       Some (method_name, type_params, params, ret_ty_opt)
                 ) struct_info.struct_members in

                 let struct_methods = List.fold_left (fun methods_map (method_name, _type_params, params, ret_ty_opt) ->
                   let param_types = List.filter_map (fun (i, (pname, pty_opt, _)) ->
                     if i = 0 && pname = "self" then None
                     else Some (match pty_opt with
                       | Some t -> resolve_imported_type t
                       | None -> fresh_type_var ())
                   ) (List.mapi (fun i param -> i, param) params) in
                   let ret_type = match ret_ty_opt with
                     | Some t -> resolve_imported_type t
                     | None -> TyNone
                   in
                   let method_type = TyFunc (param_types, ret_type) in
                   Env.StringMap.add method_name method_type methods_map
                 ) Env.StringMap.empty method_list in

                 let struct_def = {
                   Env.struct_name = struct_info.struct_name;
                   Env.struct_type_params = struct_info.struct_type_params;
                   Env.struct_fields = struct_fields;
                   Env.struct_methods = struct_methods;
                 } in
                 let acc_env_with_struct = Env.add_struct name struct_def acc_env in
                 let struct_type = TyStruct (name, []) in
                 add_binding name struct_type acc_env_with_struct
             | Module_loader.ExportedImpl (impl_info, _) ->
                 add_imported_impl acc_env impl_info
             | Module_loader.ExportedEnum (_original_name, enum_info) ->
                 let enum_type = TyEnum (enum_info.enum_name, []) in
                 add_binding name enum_type (Env.add_enum name enum_info acc_env)
           ) env imports in
           let module_name = match alias with
             | Some name -> name
             | None -> List.hd (List.rev module_path)
           in
           let new_env = add_module_namespace new_env module_name imports in
           (new_env, empty_subst))

  | SFromImport (module_name, selections, _pos) ->
      (match Module_loader.import_selected_from_module module_name selections with
       | Error msg ->
           Printf.eprintf "Import error: %s\n" msg;
           (env, empty_subst)
       | Ok imports ->
           let new_env = List.fold_left (fun acc_env (name, symbol) ->
             match symbol with
             | Module_loader.ExportedFunc (_original_name, def_info) ->
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> resolve_type_expr acc_env ty
                   | None -> fresh_type_var ()
                 ) def_info.def_params in
                 let ret_type = match def_info.def_return_type with
                   | Some ty -> resolve_type_expr acc_env ty
                   | None -> fresh_type_var ()
                 in
                 let func_type = TyFunc (param_types, ret_type) in
                 let default_values = List.map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
                 Env.add_function_with_defaults name func_type default_values acc_env
             | Module_loader.ExportedConst (_original_name, const_info) ->
                 add_binding name (imported_const_type acc_env const_info) acc_env
             | Module_loader.ExportedLet (_original_name, let_info) ->
                 add_binding name (imported_const_type acc_env {
                   const_name = let_info.let_name;
                   const_name_pos = let_info.let_pos;
                   const_type = let_info.let_type;
                   const_value = let_info.let_value;
                   const_pos = let_info.let_pos;
                 }) acc_env
             | Module_loader.ExportedInterface (_original_name, interface_info) ->
                 let iface_def = {
                   Env.iface_name = interface_info.interface_name;
                   Env.iface_type_params = interface_info.interface_type_params;
                   Env.iface_members = interface_info.interface_members;
                 } in
                 Env.add_interface name iface_def acc_env
             | Module_loader.ExportedStruct (_original_name, struct_info) ->
                 let resolve_imported_type type_expression =
                   match type_expression with
                   | TVar type_name when type_name = struct_info.struct_name ->
                       TyStruct (struct_info.struct_name, [])
                   | _ -> resolve_type_expr acc_env type_expression
                 in
                 let field_list = List.filter_map (function
                   | SField field -> Some field
                   | SMethod _ -> None
                 ) struct_info.struct_members in

                 let struct_fields_list = List.map (fun field ->
                   let field_name = match field.field_name with
                     | Some name -> name
                     | None ->
                         (match field.field_type with
                          | TVar type_name -> type_name
                          | _ -> "_invalid_")
                   in
                   (field_name, resolve_imported_type field.field_type)
                 ) field_list in

                 let struct_fields = List.fold_left (fun acc (name, ty) ->
                   Env.StringMap.add name ty acc
                 ) Env.StringMap.empty struct_fields_list in

                 let method_list = List.filter_map (function
                   | SField _ -> None
                   | SMethod (method_name, type_params, params, ret_ty_opt, _body, _) ->
                       Some (method_name, type_params, params, ret_ty_opt)
                 ) struct_info.struct_members in

                 let struct_methods = List.fold_left (fun methods_map (method_name, _type_params, params, ret_ty_opt) ->
                   let param_types = List.filter_map (fun (i, (pname, pty_opt, _)) ->
                     if i = 0 && pname = "self" then None
                     else Some (match pty_opt with
                       | Some t -> resolve_imported_type t
                       | None -> fresh_type_var ())
                   ) (List.mapi (fun i param -> i, param) params) in
                   let ret_type = match ret_ty_opt with
                     | Some t -> resolve_imported_type t
                     | None -> TyNone
                   in
                   let method_type = TyFunc (param_types, ret_type) in
                   Env.StringMap.add method_name method_type methods_map
                 ) Env.StringMap.empty method_list in

                 let struct_def = {
                   Env.struct_name = struct_info.struct_name;
                   Env.struct_type_params = struct_info.struct_type_params;
                   Env.struct_fields = struct_fields;
                   Env.struct_methods = struct_methods;
                 } in
                 let acc_env_with_struct = Env.add_struct name struct_def acc_env in
                 let struct_type = TyStruct (name, []) in
                 add_binding name struct_type acc_env_with_struct
             | Module_loader.ExportedImpl (impl_info, _) ->
                 add_imported_impl acc_env impl_info
             | Module_loader.ExportedEnum (_original_name, enum_info) ->
                 let enum_type = TyEnum (enum_info.enum_name, []) in
                 add_binding name enum_type (Env.add_enum name enum_info acc_env)
           ) env imports in
           (new_env, empty_subst))

  | SStruct struct_info ->
      let name = struct_info.struct_name in
      let type_params = struct_info.struct_type_params in
      let members = struct_info.struct_members in
      let pos = struct_info.struct_pos in
      (match Env.find_struct name env with
       | Some _ ->
           let err = make_error (TypeError "Struct already defined") pos
             (Printf.sprintf "Struct '%s' is already defined" name) in
           report_error err;
           (env, empty_subst)
       | None ->
           let field_list = List.filter_map (function
             | SField field -> Some field
             | SMethod _ -> None
           ) members in

           let method_list = List.filter_map (function
             | SField _ -> None
             | SMethod (method_name, type_params, params, ret_ty_opt, body, _) ->
                 Some (method_name, type_params, params, ret_ty_opt, body)
           ) members in

           let struct_fields_list = List.map (fun field ->
             let field_name = match field.field_name with
               | Some name -> name
               | None ->
                   (match field.field_type with
                    | TVar type_name -> type_name
                    | _ ->
                        let err = make_error (TypeError "Invalid embedded field") field.field_pos
                          "Embedded field must be a named type" in
                        report_error err;
                        "_invalid_")
             in
             (field_name, resolve_type_expr env field.field_type)
           ) field_list in

           let struct_fields = List.fold_left (fun acc (name, ty) ->
             Env.StringMap.add name ty acc
           ) Env.StringMap.empty struct_fields_list in

           let method_env_base = Env.add_struct name {
             Env.struct_name = name;
             Env.struct_type_params = type_params;
             Env.struct_fields;
             Env.struct_methods = Env.StringMap.empty;
           } env in

           let struct_methods = List.fold_left (fun methods_map (method_name, _type_params, params, ret_ty_opt, body) ->
             let method_env =
               let base_env = create_child_env method_env_base in
               let (_, final_env) = List.fold_left
                 (fun (is_first, e) (pname, pty_opt, _) ->
                   let pty =
                     if is_first && pname = "self" then
                       TyStruct (name, [])
                     else
                       match pty_opt with
                       | Some t -> resolve_type_expr method_env_base t
                       | None -> fresh_type_var ()
                   in
                   (false, add_binding pname pty e))
                 (true, base_env) params
               in
               final_env
             in

             let (_, _) = check_statements method_env body in

             let param_types = List.filter_map (fun (is_first, (pname, pty_opt, _)) ->
               if is_first && pname = "self" then None
               else Some (match pty_opt with
                 | Some t -> resolve_type_expr method_env t
                 | None -> fresh_type_var ())
             ) (List.mapi (fun index param -> index = 0, param) params) in

             let ret_type = match ret_ty_opt with
               | Some t -> resolve_type_expr method_env t
               | None -> TyNone
             in

             let method_type = TyFunc (param_types, ret_type) in
             Env.StringMap.add method_name method_type methods_map
           ) Env.StringMap.empty method_list in

           let struct_def = {
             Env.struct_name = name;
             Env.struct_type_params = type_params;
             Env.struct_fields = struct_fields;
             Env.struct_methods = struct_methods;
           } in

           let new_env = Env.add_struct name struct_def env in
           let struct_type = TyStruct (name, []) in
           let new_env = add_binding name struct_type new_env in

           let implemented_interfaces = Env.find_implicit_interfaces_for_struct name new_env in
           if List.length implemented_interfaces > 0 then begin
             ()
           end;

           (new_env, empty_subst))

  | SEnum enum_info ->
      let name = enum_info.enum_name in
      let enum_type = TyEnum (name, []) in
      let new_env = Env.add_enum name enum_info env in
      let new_env = add_binding name enum_type new_env in
      (new_env, empty_subst)

  | SFieldAssign (obj, field, value, pos) ->
      let (obj_type, obj_subst) = !infer_expr env obj in
      let (value_type, value_subst) = !infer_expr env value in
      let combined_subst = compose_subst value_subst obj_subst in
      (match apply_subst combined_subst obj_type with
       | TyStruct (struct_name, _) ->
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (env, empty_subst)
            | Some struct_def ->
                (match Env.StringMap.find_opt field struct_def.struct_fields with
                 | None ->
                     let err = make_error (TypeError "Unknown field") pos
                       (Printf.sprintf "Struct '%s' has no field '%s'" struct_name field) in
                     report_error err;
                     (env, empty_subst)
                 | Some field_type ->
                     (try
                        let _ = unify (apply_subst combined_subst value_type) field_type in
                        (apply_subst_to_env combined_subst env, combined_subst)
                      with Failure msg ->
                        let err = make_error (TypeError msg) pos
                          (Printf.sprintf "Field '%s' type mismatch: %s" field msg) in
                        report_error err;
                        (env, empty_subst))))
       | _ ->
           let err = make_error (TypeError "Not a struct") pos
             "Cannot assign field of non-struct type" in
           report_error err;
           (env, empty_subst))

  | SIndexAssign (arr, idx, value, pos) ->
      let (arr_type, arr_subst) = !infer_expr env arr in
      let (idx_type, idx_subst) = !infer_expr env idx in
      let (value_type, value_subst) = !infer_expr env value in
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
