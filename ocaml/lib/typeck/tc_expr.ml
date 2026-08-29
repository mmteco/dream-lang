open Ast
open Types
open Env
open Error
open Tc_utils
open Tc_generics

let rec take n lst = match n, lst with
  | 0, _ | _, [] -> []
  | n, x :: xs -> x :: take (n - 1) xs

let rec drop n lst = match n, lst with
  | 0, _ -> lst
  | _, [] -> []
  | n, _ :: xs -> drop (n - 1) xs

let has_prefix s prefix =
  let len_s = String.length s in
  let len_p = String.length prefix in
  len_s >= len_p && String.sub s 0 len_p = prefix

let generic_type_arguments function_type substitution =
  let rec collect seen = function
    | TyVar name when not (List.mem name seen) -> name :: seen
    | TyList element_type -> collect seen element_type
    | TyDict (key_type, value_type) -> collect (collect seen key_type) value_type
    | TyTuple element_types
    | TyUnion element_types -> List.fold_left collect seen element_types
    | TyFunc (parameter_types, return_type) ->
        collect (List.fold_left collect seen parameter_types) return_type
    | TyOption element_type -> collect seen element_type
    | TyResult (ok_type, error_type) -> collect (collect seen ok_type) error_type
    | _ -> seen
  in
  let variables = match function_type with
    | TyFunc (parameter_types, return_type) ->
        collect (List.fold_left collect [] parameter_types) return_type
    | _ -> []
  in
  List.rev_map (fun name -> apply_subst substitution (TyVar name)) variables

let find_method_type env struct_name method_name struct_def =
  match Env.StringMap.find_opt method_name struct_def.struct_methods with
  | Some method_type -> Some method_type
  | None -> Env.find_impl_method_for_type (TyStruct (struct_name, [])) method_name env

let find_interface_method_type env interface_name interface_params method_name =
  match Env.find_interface interface_name env with
  | None -> None
  | Some interface_def ->
      let substitution =
        if List.length interface_def.iface_type_params = List.length interface_params then
          List.fold_left2 (fun substitution name value ->
            Subst.add name value substitution
          ) Subst.empty interface_def.iface_type_params interface_params
        else
          Subst.empty
      in
      let resolve_type type_expression =
        apply_subst substitution (resolve_type_expr env type_expression)
      in
      List.find_map (function
        | IMethod (name, _, params, return_type, _, _) when name = method_name ->
            let parameter_types = List.filter_map (fun (parameter_name, type_opt, _) ->
              if parameter_name = "self" then None
              else Some (match type_opt with
                | Some type_expr -> resolve_type type_expr
                | None -> fresh_type_var ())) params in
            let result_type = match return_type with
              | Some type_expr -> resolve_type type_expr
              | None -> TyNone
            in
            Some (TyFunc (parameter_types, result_type))
        | _ -> None
      ) interface_def.iface_members

(* 字符串内置方法类型表，EAttr 与 EEnumVariant 共用 *)
let string_method_type method_name =
  match method_name with
  | "length" -> Some (TyFunc ([], TyInt))
  | "upper" | "lower" | "strip" -> Some (TyFunc ([], TyStr))
  | "find" -> Some (TyFunc ([TyStr], TyInt))
  | "startswith" | "endswith" -> Some (TyFunc ([TyStr], TyBool))
  | "replace" -> Some (TyFunc ([TyStr; TyStr], TyStr))
  | "split" -> Some (TyFunc ([TyStr], TyList TyStr))
  | "join" -> Some (TyFunc ([TyList TyStr], TyStr))
  | "isdigit" | "isalpha" | "isspace" -> Some (TyFunc ([TyInt], TyBool))
  | "encode" -> Some (TyFunc ([], TyBytes))
  | _ -> None

let bytes_method_type method_name =
  match method_name with
  | "length" -> Some (TyFunc ([], TyInt))
  | "get" -> Some (TyFunc ([TyInt], TyByte))
  | "slice" -> Some (TyFunc ([TyInt; TyInt], TyBytes))
  | "decode" -> Some (TyFunc ([], TyStr))
  | _ -> None

(* 表达式类型推导 *)
let rec infer_expr env = function
  | EInt (_, _) -> (TyInt, empty_subst)
  | EFloat (_, _) -> (TyFloat, empty_subst)
  | EString (_, _) -> (TyStr, empty_subst)
  | ERune (_, _) -> (TyRune, empty_subst)
  | EByte (_, _) -> (TyByte, empty_subst)
  | EBool (_, _) -> (TyBool, empty_subst)

  | EVar (name, pos) ->
      (match find_binding name env with
       | Some ty ->
           if is_polymorphic ty then
             (instantiate ty, empty_subst)
           else
             (ty, empty_subst)
       | None ->
           let err = make_error (NameError name) pos
             (Printf.sprintf "Undefined variable '%s'" name) in
           report_error err;
           (TyUnknown, empty_subst))

  | EBinOp (e1, op, e2, pos) ->
      let (t1, s1) = infer_expr env e1 in
      let (t2, s2) = infer_expr (apply_subst_to_env s1 env) e2 in
      let s3 = compose_subst s2 s1 in
      let t1' = apply_subst s3 t1 in
      let t2' = apply_subst s3 t2 in

      (* 检查内置运算符 *)
      let builtin_result = match op with
       | Add ->
           (match t1', t2' with
            | TyList elem_t1, TyList elem_t2 ->
                Some (try
                   let s4 = unify elem_t1 elem_t2 in
                   (TyList (apply_subst s4 elem_t1), compose_subst s4 s3)
                 with Failure msg ->
                   let err = make_error (TypeError msg) pos
                     (Printf.sprintf "List concatenation requires same element types: %s" msg) in
                   report_error err;
                   (TyList elem_t1, s3))
            | TyInt, TyInt -> Some (TyInt, s3)
            | TyFloat, TyFloat -> Some (TyFloat, s3)
            | TyStr, TyStr -> Some (TyStr, s3)  (* 字符串拼接 *)
            | _, _ -> None)  (* 尝试运算符重载 *)
       | Sub | Mul | Div | Mod ->
           (match t1', t2' with
            | TyInt, TyInt -> Some (TyInt, s3)
            | TyFloat, TyFloat -> Some (TyFloat, s3)
            | _, _ -> None)  (* 尝试运算符重载 *)
       | FloorDiv | Pow ->
           (match t1', t2' with
            | TyInt, TyInt -> Some (TyInt, s3)
            | TyFloat, TyFloat -> Some (TyFloat, s3)
            | _, _ -> None)  (* 尝试运算符重载 *)
       | BitAnd | BitOr | BitXor | Shl | Shr ->
           (match t1', t2' with
            | TyInt, TyInt -> Some (TyInt, s3)
            | _, _ -> None)  (* 尝试运算符重载 *)
       | In ->
           (match t1', t2' with
            | TyStr, TyStr -> Some (TyBool, s3)
            | actual_type, TyList element_type ->
                (try
                   let s4 = unify actual_type element_type in
                   Some (TyBool, compose_subst s4 s3)
                 with Failure _ -> None)
            | TyByte, TyBytes
            | TyInt, TyBytes -> Some (TyBool, s3)
            | needle_type, container_type ->
                (match Env.find_impl_for_method container_type "Contains" "contains"
                    [needle_type] env with
                 | Some impl ->
                     (match Env.StringMap.find_opt "contains" impl.impl_methods with
                      | Some (TyFunc (_, TyBool)) -> Some (TyBool, s3)
                      | _ -> None)
                 | None -> None))  (* 尝试 Contains 接口 *)
       | Eq | Neq | Lt | Gt | Lte | Gte ->
           (* 比较运算符：先尝试内置 *)
           (try
              let s4 = unify t1' t2' in
              Some (TyBool, compose_subst s4 s3)
            with Failure _ ->
              if t1' = TyUnknown || t2' = TyUnknown then
                Some (TyBool, s3)
              else
                None)  (* 尝试运算符重载 *)
       | And | Or ->
           (* 逻辑运算符不可重载 *)
           (try
              let s4 = unify t1' TyBool in
              let s5 = unify (apply_subst s4 t2') TyBool in
              Some (TyBool, compose_subst s5 (compose_subst s4 s3))
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Type error in logical operation: %s" msg) in
              report_error err;
              Some (TyBool, s3))
      in

      (* 如果内置运算符不适用，尝试运算符重载 *)
      (match builtin_result with
       | Some result -> result
       | None ->
           (* 查找接口实现 *)
           (match Env.find_binop_impl t1' op t2' env with
            | Some impl_def ->
                let method_name = Env.binop_to_method_name op in
                (match Env.get_operator_method_type impl_def method_name with
                 | Some (TyFunc (param_types, ret_type)) ->
                     (* 验证参数类型 *)
                     (match param_types with
                      | [self_ty; other_ty] ->
                          (try
                             let s4 = unify t1' self_ty in
                             let s5 = unify (apply_subst s4 t2') (apply_subst s4 other_ty) in
                             let final_subst = compose_subst s5 (compose_subst s4 s3) in
                             (apply_subst final_subst ret_type, final_subst)
                           with Failure msg ->
                             let err = make_error (TypeError msg) pos
                               (Printf.sprintf "Operator method type mismatch: %s" msg) in
                             report_error err;
                             (TyUnknown, s3))
                      | _ ->
                          let err = make_error (TypeError "Invalid operator method signature") pos
                            "Operator method must have exactly two parameters" in
                          report_error err;
                          (TyUnknown, s3))
                 | _ ->
                     let err = make_error (TypeError "Method not found") pos
                       (Printf.sprintf "Operator method '%s' not found in implementation" method_name) in
                     report_error err;
                     (TyUnknown, s3))
            | None ->
                (* 没有找到接口实现，报告错误 *)
                let err = make_error (TypeError "Operator not supported") pos
                  (Printf.sprintf "Operator %s not supported for types %s and %s"
                    (match op with
                     | Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/" | FloorDiv -> "//"
                     | Mod -> "%" | Pow -> "**"
                     | BitAnd -> "&" | BitOr -> "|" | BitXor -> "^" | Shl -> "<<" | Shr -> ">>"
                     | Eq -> "==" | Neq -> "!=" | Lt -> "<" | Gt -> ">"
                     | Lte -> "<=" | Gte -> ">=" | And -> "and" | Or -> "or"
                     | In -> "in")
                    (ty_to_string t1') (ty_to_string t2')) in
                report_error err;
                (TyUnknown, s3)))

  | EUnOp (op, e, pos) ->
      let (t, s) = infer_expr env e in
      let t' = apply_subst s t in

      (* 检查内置一元运算符 *)
      let builtin_result = match op with
       | Neg ->
           (match t' with
            | TyInt -> Some (TyInt, s)
            | TyFloat -> Some (TyFloat, s)
            | _ -> None)  (* 尝试运算符重载 *)
       | Pos ->
           (match t' with
            | TyInt -> Some (TyInt, s)
            | TyFloat -> Some (TyFloat, s)
            | _ -> None)  (* 尝试运算符重载 *)
       | Invert ->
           (match t' with
            | TyInt -> Some (TyInt, s)
            | _ -> None)  (* 尝试运算符重载 *)
       | Not ->
           (try
              let s2 = unify t' TyBool in
              Some (TyBool, compose_subst s2 s)
            with Failure _ -> None)  (* 尝试运算符重载 *)
      in

      (* 如果内置运算符不适用，尝试运算符重载 *)
      (match builtin_result with
       | Some result -> result
       | None ->
           (* 查找接口实现 *)
           (match Env.find_unop_impl t' op env with
            | Some impl_def ->
                let method_name = Env.unop_to_method_name op in
                (match Env.get_operator_method_type impl_def method_name with
                 | Some (TyFunc (param_types, ret_type)) ->
                     (* 验证参数类型（一元运算符只有 self 参数） *)
                     (match param_types with
                      | [self_ty] ->
                          (try
                             let s2 = unify t' self_ty in
                             let final_subst = compose_subst s2 s in
                             (apply_subst final_subst ret_type, final_subst)
                           with Failure msg ->
                             let err = make_error (TypeError msg) pos
                               (Printf.sprintf "Operator method type mismatch: %s" msg) in
                             report_error err;
                             (TyUnknown, s))
                      | _ ->
                          let err = make_error (TypeError "Invalid operator method signature") pos
                            "Unary operator method must have exactly one parameter (self)" in
                          report_error err;
                          (TyUnknown, s))
                 | _ ->
                     let err = make_error (TypeError "Method not found") pos
                       (Printf.sprintf "Operator method '%s' not found in implementation" method_name) in
                     report_error err;
                     (TyUnknown, s))
            | None ->
                (* 没有找到接口实现，报告错误 *)
                let err = make_error (TypeError "Operator not supported") pos
                  (Printf.sprintf "Unary operator %s not supported for type %s"
                    (match op with
                     | Neg -> "-" | Pos -> "+" | Invert -> "~" | Not -> "not")
                    (ty_to_string t')) in
                report_error err;
                (TyUnknown, s)))

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
      (match func with
       | EAttr (_obj, attr, _)
       | EStructAccess (_obj, attr, _) ->
           let (attr_type, attr_subst) = infer_expr env func in
           let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
           let combined_subst = List.fold_left compose_subst attr_subst arg_substs in
           (match apply_subst combined_subst attr_type with
            | TyFunc (expected_arg_types, ret_type) ->
                if List.length arg_types <> List.length expected_arg_types then begin
                  let err = make_error (TypeError "Argument count mismatch") pos
                    (Printf.sprintf "Method '%s' expects %d arguments but got %d"
                      attr (List.length expected_arg_types) (List.length arg_types)) in
                  report_error err;
                  (TyUnknown, combined_subst)
                end else begin
                  try
                    let arg_substs = List.map2 (fun expected actual ->
                      unify (apply_subst combined_subst expected) (apply_subst combined_subst actual)
                    ) expected_arg_types arg_types in
                    let final_subst = List.fold_left compose_subst combined_subst arg_substs in
                    (apply_subst final_subst ret_type, final_subst)
                  with Failure msg ->
                    let err = make_error (TypeError msg) pos
                      (Printf.sprintf "Method argument type mismatch: %s" msg) in
                    report_error err;
                    (TyUnknown, combined_subst)
                end
            | TyInt | TyStr ->
                if List.length args = 0 then
                  (attr_type, combined_subst)
                else begin
                  let err = make_error (TypeError "Not a method") pos
                    (Printf.sprintf "Cannot call attribute '%s' (not a method)" attr) in
                  report_error err;
                  (TyUnknown, combined_subst)
                end
            | _ ->
                let err = make_error (TypeError "Invalid method call") pos
                  "Cannot call this attribute" in
                report_error err;
                (TyUnknown, combined_subst))
       | EVar (func_name, func_pos) ->
           if Env.is_c_runtime_function func_name && not (is_stdlib_file ()) then begin
             let err = make_error (NameError func_name) func_pos
               (Printf.sprintf "Cannot call internal C function '%s' directly. Use the Dream API instead." func_name) in
             report_error err;
             (TyUnknown, empty_subst)
           end else if (func_name = "print" || func_name = "eprint") && List.length args = 1 then begin
             let (arg_type, arg_subst) = infer_expr env (List.hd args) in
             add_generic_instance func_name [apply_subst arg_subst arg_type] pos;
             (TyNone, arg_subst)
           end else if func_name = "len" && List.length args = 1 then begin
             let (arg_type, arg_subst) = infer_expr env (List.hd args) in
             (match apply_subst arg_subst arg_type with
              | TyStr | TyBytes | TyList _ | TyDict _ -> (TyInt, arg_subst)
              | actual_type ->
                  let err = make_error (TypeError "Invalid len argument") func_pos
                    (Printf.sprintf "len expects a string, bytes, dict or list, got %s"
                      (ty_to_string actual_type)) in
                  report_error err;
                  (TyUnknown, arg_subst))
           end else if func_name = "append" && List.length args = 2 then begin
             let (collection_type, collection_subst) = infer_expr env (List.nth args 0) in
             let value_env = apply_subst_to_env collection_subst env in
             let (value_type, value_subst) = infer_expr value_env (List.nth args 1) in
             let combined_subst = compose_subst value_subst collection_subst in
             let collection_type = apply_subst combined_subst collection_type in
             let value_type = apply_subst combined_subst value_type in
             (match collection_type with
              | TyList element_type ->
                  (try
                     let element_subst = unify element_type value_type in
                     (TyNone, compose_subst element_subst combined_subst)
                   with Failure msg ->
                     let err = make_error (TypeError msg) pos
                       (Printf.sprintf "append value type mismatch: %s" msg) in
                     report_error err;
                     (TyUnknown, combined_subst))
              | target_type ->
                  (match Env.find_impl_for_method target_type "Append" "append"
                           [value_type] env with
                   | Some _ -> (TyNone, combined_subst)
                   | None ->
                       let err = make_error (TypeError "Append implementation not found") pos
                         (Printf.sprintf "append does not support %s with value %s"
                           (ty_to_string target_type) (ty_to_string value_type)) in
                       report_error err;
                       (TyUnknown, combined_subst)))
           end else begin
             let (func_type, func_subst) = infer_expr env func in
             let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
             let combined_subst = List.fold_left compose_subst func_subst arg_substs in
             let ret_type = fresh_type_var () in

             let (use_default_params, actual_return_type) = match apply_subst combined_subst func_type with
               | TyFunc (expected_params, actual_ret_type) when List.length arg_types < List.length expected_params ->
                   (match Env.get_function_defaults func_name env with
                    | Some defaults ->
                        let num_provided = List.length arg_types in
                        let missing_defaults = drop num_provided defaults in
                        let has_all_defaults = List.for_all (fun default_opt -> default_opt <> None) missing_defaults in
                        if has_all_defaults then begin
                          let provided_params = take num_provided expected_params in
                          (try
                             let _ = List.map2 (fun expected actual ->
                               unify (apply_subst combined_subst expected) (apply_subst combined_subst actual)
                             ) provided_params arg_types in
                             (true, actual_ret_type)
                           with _ -> (false, ret_type))
                        end else
                          (false, ret_type)
                    | None -> (false, ret_type))
               | _ -> (false, ret_type)
             in

             if use_default_params then begin
               add_generic_instance func_name [] pos;
               (actual_return_type, combined_subst)
             end else begin
               let expected_func_type = TyFunc (arg_types, ret_type) in
               (try
                  let final_subst = unify (apply_subst combined_subst func_type) expected_func_type in
                  let all_subst = compose_subst final_subst combined_subst in
                  let type_args = generic_type_arguments
                    (apply_subst combined_subst func_type) all_subst in
                  add_generic_instance func_name type_args pos;
                  (apply_subst all_subst ret_type, all_subst)
              with Failure msg ->
                if has_prefix msg "Occurs check failed" then begin
                  add_generic_instance func_name [] pos;
                  (ret_type, combined_subst)
                end else begin
                  let err = make_error (TypeError msg) pos
                    (Printf.sprintf "Function call type error: %s" msg) in
                  report_error err;
                  (TyUnknown, combined_subst)
                end)
             end
           end
       | _ ->
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
       | TyStr ->
           (try
              let idx_s = unify (apply_subst combined_subst idx_type) TyInt in
              (TyRune, compose_subst idx_s combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "String index must be int: %s" msg) in
              report_error err;
              (TyUnknown, combined_subst))
       | TyBytes ->
           (try
              let idx_s = unify (apply_subst combined_subst idx_type) TyInt in
              (TyByte, compose_subst idx_s combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "Bytes index must be int: %s" msg) in
              report_error err;
              (TyUnknown, combined_subst))
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
             "Cannot index non-list/dict/tuple/string/bytes type" in
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
       | TyStr | TyBytes -> (apply_subst !combined_subst arr_type, !combined_subst)
       | _ ->
           let err = make_error (TypeError "Not sliceable") pos
             "Cannot slice non-list/string type" in
           report_error err;
           (TyUnknown, !combined_subst))

  | EAttr (obj, attr, pos) ->
      let (obj_type, obj_subst) = infer_expr env obj in
      (match apply_subst obj_subst obj_type with
       | TyStr ->
           (match string_method_type attr with
            | Some method_type -> (method_type, obj_subst)
            | None ->
                let err = make_error (TypeError "Unknown string method") pos
                  (Printf.sprintf "String type has no method '%s'" attr) in
                report_error err;
                (TyUnknown, obj_subst))
       | TyBytes ->
           (match bytes_method_type attr with
            | Some method_type -> (method_type, obj_subst)
            | None ->
                let err = make_error (TypeError "Unknown bytes method") pos
                  (Printf.sprintf "Bytes type has no method '%s'" attr) in
                report_error err;
                (TyUnknown, obj_subst))
       | TyStruct (struct_name, _) ->
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (TyUnknown, obj_subst)
            | Some struct_def ->
                (match Env.StringMap.find_opt attr struct_def.struct_fields with
                 | Some field_type ->
                     (field_type, obj_subst)
                 | None ->
                     (match find_method_type env struct_name attr struct_def with
                      | Some method_type ->
                          (method_type, obj_subst)
                      | None ->
                          let embedded_fields = Env.StringMap.fold (fun field_name field_ty acc ->
                            match field_ty with
                            | TyStruct (embedded_struct_name, _) when field_name = embedded_struct_name ->
                                (field_name, field_ty) :: acc
                            | _ -> acc
                          ) struct_def.struct_fields [] in

                          let found_in_embedded = List.filter_map (fun (_, field_ty) ->
                            match field_ty with
                            | TyStruct (embedded_struct_name, _) ->
                                (match Env.find_struct embedded_struct_name env with
                                 | None -> None
                                 | Some embedded_def ->
                                     (match Env.StringMap.find_opt attr embedded_def.struct_fields with
                                      | Some embedded_field_type ->
                                          Some (embedded_struct_name, embedded_field_type)
                                      | None ->
                                          (match Env.StringMap.find_opt attr embedded_def.struct_methods with
                                           | Some embedded_method_type ->
                                               Some (embedded_struct_name, embedded_method_type)
                                           | None -> None)))
                            | _ -> None
                          ) embedded_fields in

                          (match found_in_embedded with
                           | [] ->
                               let err = make_error (TypeError "Unknown field or method") pos
                                 (Printf.sprintf "Struct '%s' has no field or method '%s'" struct_name attr) in
                               report_error err;
                               (TyUnknown, obj_subst)
                           | [(_, promoted_type)] ->
                               (promoted_type, obj_subst)
                           | multiple ->
                               let struct_names = String.concat ", " (List.map fst multiple) in
                               let err = make_error (TypeError "Ambiguous field or method") pos
                                 (Printf.sprintf "Field or method '%s' is ambiguous (found in embedded structs: %s)" attr struct_names) in
                               report_error err;
                               (TyUnknown, obj_subst)))))
       | TyInterface (interface_name, interface_params) ->
           (match find_interface_method_type env interface_name interface_params attr with
            | Some method_type -> (method_type, obj_subst)
            | None ->
                let err = make_error (TypeError "Unknown interface method") pos
                  (Printf.sprintf "Interface '%s' has no method '%s'"
                    interface_name attr) in
                report_error err;
                (TyUnknown, obj_subst))
       | _ ->
           let err = make_error (TypeError "Attributes not implemented") pos
             "Attribute access not yet implemented for this type" in
           report_error err;
           (TyUnknown, obj_subst))

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

      let result_type = fresh_type_var () in
      let rec check_cases combined_subst = function
        | [] -> (result_type, combined_subst)
        | (pat, guard_opt, body) :: rest ->
            let rec bind_pattern env pat expected_type =
              match pat with
              | PVar name -> add_binding name expected_type env
              | PInt _ | PFloat _ | PString _ | PRune _ | PByte _ | PBool _ | PWildcard -> env
              | PTuple pats ->
                  (match expected_type with
                   | TyTuple elem_types when List.length pats = List.length elem_types ->
                       List.fold_left2 bind_pattern env pats elem_types
                   | _ -> env)
              | PList pats ->
                  (match expected_type with
                   | TyList elem_type ->
                       List.fold_left (fun env pat -> bind_pattern env pat elem_type) env pats
                   | _ -> env)
              | PCons (head_pat, tail_pat) ->
                  (* head :: tail: head是元素类型,tail是列表类型 *)
                  (match expected_type with
                   | TyList elem_type ->
                       let env1 = bind_pattern env head_pat elem_type in
                       bind_pattern env1 tail_pat expected_type  (* tail也是列表类型 *)
                   | _ -> env)
              | PType (var_name, type_pattern) ->
                  let target_type = type_expr_to_ty type_pattern in
                  (match expected_type with
                   | TyUnion type_list ->
                       if List.mem target_type type_list then
                         add_binding var_name target_type env
                       else
                         env
                   | _ ->
                       (try
                          let _ = unify expected_type target_type in
                          add_binding var_name target_type env
                        with Failure _ -> env))
              | PEnumVariant (pattern_enum_name, variant_name, pats) ->
                  let enum_name = match pattern_enum_name, expected_type with
                    | "", TyEnum (name, _) -> name
                    | name, _ -> name
                  in
                  let payload_types = match enum_name, variant_name with
                    | "Option", "Some" ->
                        (match expected_type with
                         | TyOption element_type -> [element_type]
                         | _ -> [])
                    | "Option", "None" -> []
                    | "Result", "Ok" ->
                        (match expected_type with
                         | TyResult (ok_type, _) -> [ok_type]
                         | _ -> [])
                    | "Result", "Err" ->
                        (match expected_type with
                         | TyResult (_, error_type) -> [error_type]
                         | _ -> [])
                    | _ ->
                        (match Env.find_enum enum_name env with
                         | Some enum_def ->
                             (match List.find_opt (function
                                | VSimple (name, _) -> name = variant_name
                                | VTuple (name, _, _) -> name = variant_name
                              ) enum_def.enum_variants with
                              | Some (VSimple _) -> []
                              | Some (VTuple (_, types, _)) -> List.map type_expr_to_ty types
                              | None -> [])
                         | None -> [])
                  in
                  if List.length payload_types = List.length pats then
                    List.fold_left2 bind_pattern env pats payload_types
                  else
                    env
              | PStruct (struct_name, field_pats) ->
                  (* 结构体解构：如果struct_name为空字符串，从expected_type推断 *)
                  let actual_struct_name =
                    if struct_name = "" then
                      (* 从expected_type推断结构体名称 *)
                      match expected_type with
                      | TyStruct (name, _) -> name
                      | _ -> ""  (* 无法推断 *)
                    else
                      struct_name
                  in
                  (match expected_type with
                   | TyStruct (type_struct_name, _) when type_struct_name = actual_struct_name ->
                       (match Env.find_struct actual_struct_name env with
                        | Some struct_def ->
                            List.fold_left (fun env_acc (field_name, field_pat) ->
                              match Env.StringMap.find_opt field_name struct_def.struct_fields with
                              | Some field_type -> bind_pattern env_acc field_pat field_type
                              | None -> env_acc  (* 字段不存在，跳过 *)
                            ) env field_pats
                        | None -> env)
                   | _ -> env)
            in
            let case_env = bind_pattern env' pat (apply_subst combined_subst scrut_type) in
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
            let (case_type, case_subst) = match body with
              | MExpr expr ->
                  infer_expr guard_env expr
              | MStmts stmts ->
                  let has_return = List.exists (function
                    | SReturn _ -> true
                    | _ -> false
                  ) stmts in
                  if has_return then begin
                    let err = make_error (TypeError "Invalid return in match expression") pos
                      "Cannot use 'return' in match expression branches. Use 'return match ...' instead." in
                    report_error err
                  end;
                  let (_, stmt_subst) = Tc_stmt.check_statements guard_env stmts in
                  let branch_type = match List.rev stmts with
                    | [] -> TyNone
                    | last_stmt :: _ ->
                        (match last_stmt with
                         | SExpr (expr, _) ->
                             let (expr_type, _) = infer_expr guard_env expr in
                             expr_type
                         | SReturn (Some expr, _) ->
                             let (expr_type, _) = infer_expr guard_env expr in
                             expr_type
                         | SReturn (None, _) -> TyNone
                         | _ -> TyNone)
                  in
                  (branch_type, stmt_subst)
            in
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

      (match Exhaustiveness.check_exhaustiveness env' (apply_subst scrut_subst scrut_type) cases pos with
       | Some (pos, missing) ->
           let missing_str = String.concat ", " missing in
           let err = make_error (TypeError "Non-exhaustive match") pos
             (Printf.sprintf "Match is not exhaustive. Missing cases: %s" missing_str) in
           report_error err
       | None -> ());

      let unreachable_indices = Exhaustiveness.check_reachability env' (apply_subst scrut_subst scrut_type) cases in
      List.iter (fun idx ->
        let (pat, _, _) = List.nth cases idx in
        let pat_str = match pat with
          | PEnumVariant (_, v, _) -> v
          | PInt n -> string_of_int n
          | PBool b -> string_of_bool b
          | PWildcard -> "_"
          | _ -> "_"
        in
        let err = make_error (TypeError "Unreachable pattern") pos
          (Printf.sprintf "Pattern '%s' is unreachable (branch #%d in the match expression)" pat_str (idx + 1)) in
        report_error err
      ) unreachable_indices;

      result

  | EListComp (elem, var, iter, _cond_opt, pos) ->
      let (iter_type, iter_subst) = infer_expr env iter in
      let elem_type = fresh_type_var () in
      (try
         let list_subst = unify (apply_subst iter_subst iter_type) (TyList elem_type) in
         let env' = add_binding var (apply_subst list_subst elem_type)
             (apply_subst_to_env list_subst env) in
         let (result_elem_type, elem_subst) = infer_expr env' elem in
         (TyList result_elem_type, compose_subst elem_subst (compose_subst list_subst iter_subst))
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "List comprehension iterator must be a list: %s" msg) in
         report_error err;
         (TyList TyUnknown, iter_subst))

  | EEnumVariant (enum_name, variant_name, [], pos) ->
      (match Env.find_binding enum_name env with
       | Some (TyStruct (struct_name, _)) ->
           (match Env.find_struct struct_name env with
            | Some struct_def ->
                (match Env.StringMap.find_opt variant_name struct_def.struct_fields with
                 | Some field_type -> field_type, empty_subst
                 | None ->
                     (match find_method_type env struct_name variant_name struct_def with
                      | Some (TyFunc ([], return_type)) -> return_type, empty_subst
                      | Some method_type -> method_type, empty_subst
                      | None ->
                          let err = make_error (TypeError "Unknown field or method") pos
                            (Printf.sprintf "Struct '%s' has no field or method '%s'"
                              struct_name variant_name) in
                          report_error err;
                          TyUnknown, empty_subst))
            | None -> TyUnknown, empty_subst)
       | Some TyStr ->
           (match string_method_type variant_name with
            | Some (TyFunc ([], return_type)) -> return_type, empty_subst
            | Some method_type -> method_type, empty_subst
            | None -> TyEnum (enum_name, []), empty_subst)
       | Some TyBytes ->
           (match bytes_method_type variant_name with
            | Some (TyFunc ([], return_type)) -> return_type, empty_subst
            | Some method_type -> method_type, empty_subst
            | None -> TyEnum (enum_name, []), empty_subst)
       | Some (TyInterface (interface_name, interface_params)) ->
           (match find_interface_method_type env interface_name interface_params variant_name with
            | Some (TyFunc ([], return_type)) -> return_type, empty_subst
            | Some method_type -> method_type, empty_subst
            | None -> TyEnum (enum_name, []), empty_subst)
       | _ ->
           (match enum_name, variant_name with
            | "Option", "None" -> TyOption (fresh_type_var ()), empty_subst
            | _ -> TyEnum (enum_name, []), empty_subst))
  | EEnumVariant (enum_name, variant_name, args, _pos) ->
      let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
      let combined_subst = List.fold_left compose_subst empty_subst arg_substs in
      let resolved_arg_types = List.map (apply_subst combined_subst) arg_types in
      (match Env.find_binding enum_name env with
       | Some (TyStruct (struct_name, _)) ->
           (match Env.find_struct struct_name env with
            | Some struct_def ->
                (match find_method_type env struct_name variant_name struct_def with
                 | Some (TyFunc (parameter_types, return_type)) ->
                     (match parameter_types with
                      | expected_arguments
                        when List.length expected_arguments = List.length resolved_arg_types ->
                          List.iter2 (fun expected actual ->
                            try ignore (unify expected actual)
                            with Failure msg ->
                              let err = make_error (TypeError msg) _pos
                                "Method argument type mismatch" in
                              report_error err
                          ) expected_arguments resolved_arg_types;
                          return_type, combined_subst
                      | _ ->
                          let err = make_error (TypeError "Argument count mismatch") _pos
                            (Printf.sprintf "Method '%s' argument count does not match"
                              variant_name) in
                          report_error err;
                          TyUnknown, combined_subst)
                 | _ -> TyUnknown, combined_subst)
            | None -> TyUnknown, combined_subst)
       | Some (TyInterface (interface_name, interface_params)) ->
           (match find_interface_method_type env interface_name interface_params variant_name with
            | Some (TyFunc (expected_argument_types, return_type))
              when List.length expected_argument_types = List.length resolved_arg_types ->
                List.iter2 (fun expected actual ->
                  try ignore (unify expected actual)
                  with Failure msg ->
                    let err = make_error (TypeError msg) _pos
                      "Interface method argument type mismatch" in
                    report_error err
                ) expected_argument_types resolved_arg_types;
                return_type, combined_subst
            | Some (TyFunc (expected_argument_types, _)) ->
                let err = make_error (TypeError "Argument count mismatch") _pos
                  (Printf.sprintf "Interface method '%s' expects %d arguments but got %d"
                    variant_name (List.length expected_argument_types)
                    (List.length resolved_arg_types)) in
                report_error err;
                TyUnknown, combined_subst
            | _ -> TyUnknown, combined_subst)
       | Some TyStr ->
           (match string_method_type variant_name with
            | Some (TyFunc (expected_argument_types, return_type))
              when List.length expected_argument_types = List.length resolved_arg_types ->
                List.iter2 (fun expected actual ->
                  try ignore (unify expected actual)
                  with Failure msg ->
                    let err = make_error (TypeError msg) _pos
                      "String method argument type mismatch" in
                    report_error err
                ) expected_argument_types resolved_arg_types;
                return_type, combined_subst
            | Some (TyFunc (expected_argument_types, _)) ->
                let err = make_error (TypeError "Argument count mismatch") _pos
                  (Printf.sprintf "String method '%s' expects %d arguments but got %d"
                    variant_name (List.length expected_argument_types)
                    (List.length resolved_arg_types)) in
                report_error err;
                TyUnknown, combined_subst
            | _ -> TyUnknown, combined_subst)
       | Some TyBytes ->
           (match bytes_method_type variant_name with
            | Some (TyFunc (expected_argument_types, return_type))
              when List.length expected_argument_types = List.length resolved_arg_types ->
                List.iter2 (fun expected actual ->
                  try ignore (unify expected actual)
                  with Failure msg ->
                    let err = make_error (TypeError msg) _pos
                      "Bytes method argument type mismatch" in
                    report_error err
                ) expected_argument_types resolved_arg_types;
                return_type, combined_subst
            | Some (TyFunc (expected_argument_types, _)) ->
                let err = make_error (TypeError "Argument count mismatch") _pos
                  (Printf.sprintf "Bytes method '%s' expects %d arguments but got %d"
                    variant_name (List.length expected_argument_types)
                    (List.length resolved_arg_types)) in
                report_error err;
                TyUnknown, combined_subst
            | _ -> TyUnknown, combined_subst)
       | _ ->
           (match enum_name, variant_name, resolved_arg_types with
            | "Option", "Some", [value_type] -> TyOption value_type, combined_subst
            | "Result", "Ok", [value_type] -> TyResult (value_type, fresh_type_var ()), combined_subst
            | "Result", "Err", [value_type] -> TyResult (fresh_type_var (), value_type), combined_subst
            | _ -> TyEnum (enum_name, []), combined_subst))

  | EStructLiteral (struct_name, field_inits, pos) ->
      (match Env.find_struct struct_name env with
       | None ->
           let err = make_error (NameError struct_name) pos
             (Printf.sprintf "Struct '%s' is not defined" struct_name) in
           report_error err;
           (TyUnknown, empty_subst)
       | Some struct_def ->
           let (field_types, field_substs) = List.split (List.map (fun (_, expr) ->
             infer_expr env expr
           ) field_inits) in
           let combined_subst = List.fold_left compose_subst empty_subst field_substs in

           let init_field_names = List.map fst field_inits in
           let struct_field_names = List.map fst (Env.StringMap.bindings struct_def.struct_fields) in

           let missing_fields = List.filter (fun name ->
             not (List.mem name init_field_names)
           ) struct_field_names in

           if missing_fields <> [] then begin
             let err = make_error (TypeError "Missing fields") pos
               (Printf.sprintf "Struct '%s' is missing fields: %s"
                 struct_name (String.concat ", " missing_fields)) in
             report_error err
           end;

           let extra_fields = List.filter (fun name ->
             not (List.mem name struct_field_names)
           ) init_field_names in

           if extra_fields <> [] then begin
             let err = make_error (TypeError "Unknown fields") pos
               (Printf.sprintf "Struct '%s' has no fields: %s"
                 struct_name (String.concat ", " extra_fields)) in
             report_error err
           end;

           List.iter2 (fun (field_name, _) field_type ->
             match Env.StringMap.find_opt field_name struct_def.struct_fields with
             | None -> ()
             | Some expected_type ->
                 (try
                    let _ = unify (apply_subst combined_subst field_type) expected_type in ()
                  with Failure msg ->
                    let err = make_error (TypeError msg) pos
                      (Printf.sprintf "Field '%s' type mismatch: %s" field_name msg) in
                    report_error err)
           ) field_inits field_types;

           (TyStruct (struct_name, []), combined_subst))

  | EStructAccess (obj, field, pos) ->
      let (obj_type, obj_subst) = infer_expr env obj in
      (match apply_subst obj_subst obj_type with
       | TyStruct (struct_name, _) ->
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (TyUnknown, obj_subst)
            | Some struct_def ->
                (match Env.StringMap.find_opt field struct_def.struct_fields with
                 | Some field_type ->
                     (field_type, obj_subst)
                 | None ->
                     (match find_method_type env struct_name field struct_def with
                      | Some method_type -> (method_type, obj_subst)
                      | None ->
                          let err = make_error (TypeError "Unknown field or method") pos
                            (Printf.sprintf "Struct '%s' has no field or method '%s'"
                              struct_name field) in
                          report_error err;
                          (TyUnknown, obj_subst))))
       | _ ->
           let err = make_error (TypeError "Not a struct") pos
             "Cannot access field of non-struct type" in
           report_error err;
           (TyUnknown, obj_subst))

  | ETernary (cond, true_expr, false_expr, pos) ->
      let (cond_type, cond_subst) = infer_expr env cond in
      (try
         let bool_subst = unify (apply_subst cond_subst cond_type) TyBool in
         let env' = apply_subst_to_env bool_subst env in
         let (true_type, true_subst) = infer_expr env' true_expr in
         let (false_type, false_subst) = infer_expr env' false_expr in
         let combined = compose_subst false_subst (compose_subst true_subst (compose_subst bool_subst cond_subst)) in
         (try
            let unify_subst = unify (apply_subst combined true_type) (apply_subst combined false_type) in
            (apply_subst unify_subst true_type, compose_subst unify_subst combined)
          with Failure msg ->
            let err = make_error (TypeError msg) pos
              (Printf.sprintf "Ternary operator branches have different types: %s" msg) in
            report_error err;
            (true_type, combined))
       with Failure msg ->
         let err = make_error (TypeError msg) pos
           (Printf.sprintf "Ternary condition must be bool: %s" msg) in
         report_error err;
         (TyUnknown, cond_subst))

  | ETry (expr, pos) ->
      let (expr_type, expr_subst) = infer_expr env expr in
      (match apply_subst expr_subst expr_type with
       | TyResult (ok_type, _err_type) ->
           (ok_type, expr_subst)
       | _ ->
           let err = make_error (TypeError "Invalid try operator") pos
             "The '?' operator can only be used on Result types" in
           report_error err;
           (TyUnknown, expr_subst))

  | ETypeOf (expr, _pos) ->
      let (expr_type, expr_subst) = infer_expr env expr in
      let actual_type = apply_subst expr_subst expr_type in
      (TyTypeInfo actual_type, expr_subst)
