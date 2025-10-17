open Ast
open Types
open Env
open Error
open Tc_utils

(* 前向声明：表达式类型推导函数 *)
let infer_expr = ref (fun _ _ -> (TyUnknown, empty_subst))

let set_infer_expr f = infer_expr := f

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
            | (TVar interface_name, TyStruct (struct_name, _)) ->
                (match Env.find_interface interface_name env' with
                 | Some iface_def ->
                     (match Env.find_struct struct_name env' with
                      | Some struct_def ->
                          if Env.struct_implements_interface struct_def iface_def then
                            let new_env = add_binding name expected_type env' in
                            let locked_env = lock_binding name new_env in
                            (locked_env, value_subst)
                          else
                            let err = make_error (TypeError "Interface not implemented") pos
                              (Printf.sprintf "Struct '%s' does not implement interface '%s'" struct_name interface_name) in
                            report_error err;
                            let new_env = add_binding name expected_type env' in
                            (new_env, value_subst)
                      | None ->
                          let err = make_error (NameError struct_name) pos
                            (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                          report_error err;
                          let new_env = add_binding name expected_type env' in
                          (new_env, value_subst))
                 | None ->
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
                        match List.assoc_opt field_name struct_def.struct_fields with
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
            | Some t -> type_expr_to_ty t
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
        | Some t -> type_expr_to_ty t
        | None -> TyNone
      in
      let func_type = TyFunc (param_types, ret_type) in
      let default_values = List.map (fun (_, _, default_opt) -> default_opt) params in
      let new_env = Env.add_function_with_defaults name func_type default_values env in
      (new_env, empty_subst)

  | SReturn (_, _) -> (env, empty_subst)

  | SIf (cond, then_body, _elifs, _else_opt, pos) ->
      let (cond_type, cond_subst) = !infer_expr env cond in
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
      let elem_type = fresh_type_var () in
      (try
         let list_subst = unify (apply_subst iter_subst iter_type) (TyList elem_type) in
         let env' = apply_subst_to_env list_subst env in
         let final_elem_type = apply_subst list_subst elem_type in

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
      let target_ty = type_expr_to_ty impl_block.impl_target in

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
           let required_methods = List.filter_map (function
             | IMethod (name, _, params, ret_ty_opt, default_impl_opt, _) ->
                 if default_impl_opt = None then
                   let param_types = List.map (fun (_, ty_opt, _) ->
                     match ty_opt with
                     | Some ty -> type_expr_to_ty ty
                     | None -> fresh_type_var ()
                   ) params in
                   let ret_type = match ret_ty_opt with
                     | Some ty -> type_expr_to_ty ty
                     | None -> TyNone
                   in
                   Some (name, TyFunc (param_types, ret_type))
                 else
                   None
             | _ -> None
           ) iface_def.iface_members in

           let impl_methods = List.filter_map (function
             | ImplMethod (name, _, params, ret_ty_opt, body, _) ->
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 ) params in
                 let ret_type = match ret_ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> TyNone
                 in

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

                 Some (name, TyFunc (param_types, ret_type))
             | _ -> None
           ) impl_block.impl_members in

           let missing_methods = List.filter (fun (req_name, req_ty) ->
             not (List.exists (fun (impl_name, impl_ty) ->
               impl_name = req_name &&
               (try
                  let _ = unify impl_ty req_ty in true
                with Failure _ -> false)
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
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 ) def_info.def_params in
                 let ret_type = match def_info.def_return_type with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 in
                 let func_type = TyFunc (param_types, ret_type) in
                 let default_values = List.map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
                 Env.add_function_with_defaults name func_type default_values acc_env
             | _ ->
                 acc_env
           ) env imports in
           (new_env, empty_subst))

  | SFromImport (module_name, selections, _pos) ->
      let module_path = [module_name] in
      (match Module_loader.import_selected_from_module module_path selections with
       | Error msg ->
           Printf.eprintf "Import error: %s\n" msg;
           (env, empty_subst)
       | Ok imports ->
           let new_env = List.fold_left (fun acc_env (name, symbol) ->
             match symbol with
             | Module_loader.ExportedFunc (_original_name, def_info) ->
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 ) def_info.def_params in
                 let ret_type = match def_info.def_return_type with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 in
                 let func_type = TyFunc (param_types, ret_type) in
                 let default_values = List.map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
                 Env.add_function_with_defaults name func_type default_values acc_env
             | _ ->
                 acc_env
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

           let struct_fields = List.map (fun field ->
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
             (field_name, type_expr_to_ty field.field_type)
           ) field_list in

           let struct_methods = List.fold_left (fun methods_map (method_name, _type_params, params, ret_ty_opt, body) ->
             let method_env =
               let base_env = create_child_env env in
               let (_, final_env) = List.fold_left
                 (fun (is_first, e) (pname, pty_opt, _) ->
                   let pty =
                     if is_first && pname = "self" then
                       TyStruct (name, [])
                     else
                       match pty_opt with
                       | Some t -> type_expr_to_ty t
                       | None -> fresh_type_var ()
                   in
                   (false, add_binding pname pty e))
                 (true, base_env) params
               in
               final_env
             in

             let (_, _) = check_statements method_env body in

             let param_types =
               let (_, types) = List.fold_left
                 (fun (is_first, acc) (pname, pty_opt, _) ->
                   let pty =
                     if is_first && pname = "self" then
                       TyStruct (name, [])
                     else
                       match pty_opt with
                       | Some t -> type_expr_to_ty t
                       | None -> fresh_type_var ()
                   in
                   (false, acc @ [pty]))
                 (true, []) params
               in
               types
             in

             let ret_type = match ret_ty_opt with
               | Some t -> type_expr_to_ty t
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
      let new_env = add_binding name enum_type env in
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
                (match List.assoc_opt field struct_def.struct_fields with
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
