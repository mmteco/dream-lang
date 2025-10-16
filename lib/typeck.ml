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

(* 实例化多态类型：将类型中的 TyVar 替换为新的类型变量 *)
let instantiate ty =
  let var_map = ref [] in
  let rec inst = function
    | TyVar name ->
        (match List.assoc_opt name !var_map with
         | Some new_var -> new_var
         | None ->
             let new_var = fresh_type_var () in
             var_map := (name, new_var) :: !var_map;
             new_var)
    | TyList t -> TyList (inst t)
    | TyDict (k, v) -> TyDict (inst k, inst v)
    | TyTuple ts -> TyTuple (List.map inst ts)
    | TyFunc (params, ret) -> TyFunc (List.map inst params, inst ret)
    | TyUnion ts -> TyUnion (List.map inst ts)
    | TyOption t -> TyOption (inst t)
    | TyResult (ok, err) -> TyResult (inst ok, inst err)
    | t -> t
  in
  inst ty

(* 检查类型是否包含未绑定的类型变量 (多态) *)
let rec is_polymorphic = function
  | TyVar _ -> true
  | TyList t -> is_polymorphic t
  | TyDict (k, v) -> is_polymorphic k || is_polymorphic v
  | TyTuple ts -> List.exists is_polymorphic ts
  | TyFunc (params, ret) -> List.exists is_polymorphic params || is_polymorphic ret
  | TyUnion ts -> List.exists is_polymorphic ts
  | TyOption t -> is_polymorphic t
  | TyResult (ok, err) -> is_polymorphic ok || is_polymorphic err
  | _ -> false

(* 当前正在编译的文件路径 *)
let current_file = ref ""

let set_current_file file =
  current_file := file

let is_stdlib_file () =
  (* 检查当前文件是否在 stdlib/ 目录下 *)
  let file = !current_file in
  String.length file >= 7 && String.sub file 0 7 = "stdlib/"

let rec infer_expr env = function
  | EInt (_, _) -> (TyInt, empty_subst)
  | EFloat (_, _) -> (TyFloat, empty_subst)
  | EString (_, _) -> (TyStr, empty_subst)
  | EBool (_, _) -> (TyBool, empty_subst)

  | EVar (name, pos) ->
      (match find_binding name env with
       | Some ty ->
           (* 如果类型是多态的,为其创建新的实例 *)
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
      (* 检查是否是方法调用 (EAttr) *)
      (match func with
       | EAttr (_obj, attr, _) ->
           (* 方法调用：先推导对象和属性类型，然后检查参数 *)
           let (attr_type, attr_subst) = infer_expr env func in
           let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
           let combined_subst = List.fold_left compose_subst attr_subst arg_substs in
           (match apply_subst combined_subst attr_type with
            | TyFunc (expected_arg_types, ret_type) ->
                (* 检查参数类型是否匹配 *)
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
                (* 属性访问（非函数），例如 s.length，不需要参数 *)
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
           (* 普通函数调用 *)
           (* 禁止用户代码直接调用 C runtime 函数，但允许标准库调用 *)
           if Env.is_c_runtime_function func_name && not (is_stdlib_file ()) then begin
             let err = make_error (NameError func_name) func_pos
               (Printf.sprintf "Cannot call internal C function '%s' directly. Use the Dream API instead." func_name) in
             report_error err;
             (TyUnknown, empty_subst)
           end else if func_name = "print" && List.length args = 1 then begin
             (* 特殊处理 print 函数，它接受任何类型的参数 *)
             let (arg_type, arg_subst) = infer_expr env (List.hd args) in
             add_generic_instance func_name [apply_subst arg_subst arg_type] pos;
             (TyNone, arg_subst)
           end else begin
             let (func_type, func_subst) = infer_expr env func in
             let (arg_types, arg_substs) = List.split (List.map (infer_expr env) args) in
             let combined_subst = List.fold_left compose_subst func_subst arg_substs in
             let concrete_arg_types = List.map (apply_subst combined_subst) arg_types in
             let ret_type = fresh_type_var () in

             (* 检查是否省略了有默认值的参数 *)
             let rec take n lst = match n, lst with
               | 0, _ | _, [] -> []
               | n, x :: xs -> x :: take (n - 1) xs
             in
             let rec drop n lst = match n, lst with
               | 0, _ -> lst
               | _, [] -> []
               | n, _ :: xs -> drop (n - 1) xs
             in

             let (use_default_params, actual_return_type) = match apply_subst combined_subst func_type with
               | TyFunc (expected_params, actual_ret_type) when List.length arg_types < List.length expected_params ->
                   (* 参数不足，检查是否有默认值 *)
                   (match Env.get_function_defaults func_name env with
                    | Some defaults ->
                        let num_provided = List.length arg_types in
                        let missing_defaults = drop num_provided defaults in
                        let has_all_defaults = List.for_all (fun default_opt -> default_opt <> None) missing_defaults in
                        if has_all_defaults then begin
                          (* 所有缺失参数都有默认值，允许调用 *)
                          (* 检查提供的参数类型是否匹配 *)
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
               (* 使用默认参数，直接返回 *)
               add_generic_instance func_name concrete_arg_types pos;
               (actual_return_type, combined_subst)
             end else begin
               (* 正常的函数调用类型检查 *)
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
             end
           end
       | _ ->
           (* 其他函数调用 *)
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
           (* 字符串索引返回整数 (char code) *)
           (try
              let idx_s = unify (apply_subst combined_subst idx_type) TyInt in
              (TyInt, compose_subst idx_s combined_subst)
            with Failure msg ->
              let err = make_error (TypeError msg) pos
                (Printf.sprintf "String index must be int: %s" msg) in
              report_error err;
              (TyUnknown, combined_subst))
       | TyBytes ->
           (* 字节数组索引返回整数 (byte value 0-255) *)
           (try
              let idx_s = unify (apply_subst combined_subst idx_type) TyInt in
              (TyInt, compose_subst idx_s combined_subst)
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
       | TyStr -> (TyStr, !combined_subst)
       | _ ->
           let err = make_error (TypeError "Not sliceable") pos
             "Cannot slice non-list/string type" in
           report_error err;
           (TyUnknown, !combined_subst))

  | EAttr (obj, attr, pos) ->
      let (obj_type, obj_subst) = infer_expr env obj in
      (match apply_subst obj_subst obj_type with
       | TyStr ->
           (* 字符串方法 *)
           (match attr with
            | "length" -> (TyFunc ([], TyInt), obj_subst)
            | "upper" | "lower" | "strip" -> (TyFunc ([], TyStr), obj_subst)
            | "find" -> (TyFunc ([TyStr], TyInt), obj_subst)
            | "starts_with" | "ends_with" -> (TyFunc ([TyStr], TyBool), obj_subst)
            | "replace" -> (TyFunc ([TyStr; TyStr], TyStr), obj_subst)
            | "split" -> (TyFunc ([TyStr], TyList TyStr), obj_subst)
            | "is_digit" | "is_alpha" | "is_whitespace" -> (TyFunc ([TyInt], TyBool), obj_subst)
            | _ ->
                let err = make_error (TypeError "Unknown string method") pos
                  (Printf.sprintf "String type has no method '%s'" attr) in
                report_error err;
                (TyUnknown, obj_subst))
       | TyStruct (struct_name, _) ->
           (* 结构体字段或方法 *)
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (TyUnknown, obj_subst)
            | Some struct_def ->
                (* 先查找字段 *)
                (match List.assoc_opt attr struct_def.struct_fields with
                 | Some field_type ->
                     (* 字段访问 *)
                     (field_type, obj_subst)
                 | None ->
                     (* 再查找方法 *)
                     (match Env.StringMap.find_opt attr struct_def.struct_methods with
                      | Some method_type ->
                          (* 方法访问 *)
                          (method_type, obj_subst)
                      | None ->
                          (* 最后查找嵌入字段中的字段和方法(字段提升) *)
                          (* 查找所有嵌入字段:字段名与类型名相同的字段 *)
                          let embedded_fields = List.filter (fun (field_name, field_ty) ->
                            match field_ty with
                            | TyStruct (embedded_struct_name, _) when field_name = embedded_struct_name ->
                                true
                            | _ -> false
                          ) struct_def.struct_fields in

                          (* 在每个嵌入字段中查找属性 *)
                          let found_in_embedded = List.filter_map (fun (_, field_ty) ->
                            match field_ty with
                            | TyStruct (embedded_struct_name, _) ->
                                (match Env.find_struct embedded_struct_name env with
                                 | None -> None
                                 | Some embedded_def ->
                                     (* 查找字段 *)
                                     (match List.assoc_opt attr embedded_def.struct_fields with
                                      | Some embedded_field_type ->
                                          Some (embedded_struct_name, embedded_field_type)
                                      | None ->
                                          (* 查找方法 *)
                                          (match Env.StringMap.find_opt attr embedded_def.struct_methods with
                                           | Some embedded_method_type ->
                                               Some (embedded_struct_name, embedded_method_type)
                                           | None -> None)))
                            | _ -> None
                          ) embedded_fields in

                          (match found_in_embedded with
                           | [] ->
                               (* 没有找到,报错 *)
                               let err = make_error (TypeError "Unknown field or method") pos
                                 (Printf.sprintf "Struct '%s' has no field or method '%s'" struct_name attr) in
                               report_error err;
                               (TyUnknown, obj_subst)
                           | [(_, promoted_type)] ->
                               (* 唯一匹配,返回提升的类型 *)
                               (promoted_type, obj_subst)
                           | multiple ->
                               (* 多个匹配,报错 *)
                               let struct_names = String.concat ", " (List.map fst multiple) in
                               let err = make_error (TypeError "Ambiguous field or method") pos
                                 (Printf.sprintf "Field or method '%s' is ambiguous (found in embedded structs: %s)" attr struct_names) in
                               report_error err;
                               (TyUnknown, obj_subst)))))
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
              | PType (var_name, type_pattern) ->
                  (* 类型模式：检查 expected_type 是否兼容 type_pattern，然后绑定变量 *)
                  let target_type = type_expr_to_ty type_pattern in
                  (match expected_type with
                   | TyUnion type_list ->
                       (* 如果 expected_type 是 Union，检查 target_type 是否是其成员之一 *)
                       if List.mem target_type type_list then
                         add_binding var_name target_type env
                       else
                         env
                   | _ ->
                       (* 如果不是 Union，检查类型是否直接匹配 *)
                       (try
                          let _ = unify expected_type target_type in
                          add_binding var_name target_type env
                        with Failure _ -> env))
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

  | EStructLiteral (struct_name, field_inits, pos) ->
      (* 查找结构体定义 *)
      (match Env.find_struct struct_name env with
       | None ->
           let err = make_error (NameError struct_name) pos
             (Printf.sprintf "Struct '%s' is not defined" struct_name) in
           report_error err;
           (TyUnknown, empty_subst)
       | Some struct_def ->
           (* 检查字段初始化 *)
           let (field_types, field_substs) = List.split (List.map (fun (_, expr) ->
             infer_expr env expr
           ) field_inits) in
           let combined_subst = List.fold_left compose_subst empty_subst field_substs in

           (* 验证所有字段都已初始化且类型正确 *)
           let init_field_names = List.map fst field_inits in
           let struct_field_names = List.map fst struct_def.struct_fields in

           (* 检查是否有缺失的字段 *)
           let missing_fields = List.filter (fun name ->
             not (List.mem name init_field_names)
           ) struct_field_names in

           if missing_fields <> [] then begin
             let err = make_error (TypeError "Missing fields") pos
               (Printf.sprintf "Struct '%s' is missing fields: %s"
                 struct_name (String.concat ", " missing_fields)) in
             report_error err
           end;

           (* 检查是否有多余的字段 *)
           let extra_fields = List.filter (fun name ->
             not (List.mem name struct_field_names)
           ) init_field_names in

           if extra_fields <> [] then begin
             let err = make_error (TypeError "Unknown fields") pos
               (Printf.sprintf "Struct '%s' has no fields: %s"
                 struct_name (String.concat ", " extra_fields)) in
             report_error err
           end;

           (* 检查字段类型是否匹配 *)
           List.iter2 (fun (field_name, _) field_type ->
             match List.assoc_opt field_name struct_def.struct_fields with
             | None -> ()  (* 已经在上面检查过 *)
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
           (* 查找结构体定义 *)
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (TyUnknown, obj_subst)
            | Some struct_def ->
                (* 查找字段类型 *)
                (match List.assoc_opt field struct_def.struct_fields with
                 | None ->
                     let err = make_error (TypeError "Unknown field") pos
                       (Printf.sprintf "Struct '%s' has no field '%s'" struct_name field) in
                     report_error err;
                     (TyUnknown, obj_subst)
                 | Some field_type ->
                     (field_type, obj_subst)))
       | _ ->
           let err = make_error (TypeError "Not a struct") pos
             "Cannot access field of non-struct type" in
           report_error err;
           (TyUnknown, obj_subst))

and apply_subst_to_env subst env =
  (* 只对非多态类型应用替换,保持多态函数类型不变 *)
  {env with bindings = Env.StringMap.map (fun ty ->
    if is_polymorphic ty then ty else apply_subst subst ty
  ) env.bindings}

let rec check_statement env = function
  | SExpr (e, _) ->
      let (_, subst) = infer_expr env e in
      (apply_subst_to_env subst env, subst)

  | SLet let_info ->
      let name = let_info.let_name in
      let ty_opt = let_info.let_type in
      let value = let_info.let_value in
      let pos = let_info.let_name_pos in
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

           (* 特殊处理接口类型: 检查结构体是否实现了接口 *)
           (match (ty_annot, apply_subst value_subst value_type) with
            | (TVar interface_name, TyStruct (struct_name, _)) ->
                (* 检查是否是接口 *)
                (match Env.find_interface interface_name env' with
                 | Some iface_def ->
                     (* 这是一个接口类型，检查结构体是否实现了它 *)
                     (match Env.find_struct struct_name env' with
                      | Some struct_def ->
                          if Env.struct_implements_interface struct_def iface_def then
                            (* 结构体实现了接口，允许赋值 *)
                            let new_env = add_binding name expected_type env' in
                            let locked_env = lock_binding name new_env in
                            (locked_env, value_subst)
                          else
                            (* 结构体没有实现接口，报错 *)
                            let err = make_error (TypeError "Interface not implemented") pos
                              (Printf.sprintf "Struct '%s' does not implement interface '%s'" struct_name interface_name) in
                            report_error err;
                            let new_env = add_binding name expected_type env' in
                            (new_env, value_subst)
                      | None ->
                          (* 找不到结构体定义，报错 *)
                          let err = make_error (NameError struct_name) pos
                            (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                          report_error err;
                          let new_env = add_binding name expected_type env' in
                          (new_env, value_subst))
                 | None ->
                     (* 不是接口，使用默认的类型统一检查 *)
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
                (* 默认的类型统一检查 *)
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
      (* 提取默认参数值 *)
      let default_values = List.map (fun (_, _, default_opt) -> default_opt) params in
      let new_env = Env.add_function_with_defaults name func_type default_values env in
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
              | PType (var_name, type_pattern) ->
                  (* 类型模式：检查 expected_type 是否兼容 type_pattern，然后绑定变量 *)
                  let target_type = type_expr_to_ty type_pattern in
                  (match expected_type with
                   | TyUnion type_list ->
                       (* 如果 expected_type 是 Union，检查 target_type 是否是其成员之一 *)
                       if List.mem target_type type_list then
                         add_binding var_name target_type env
                       else
                         env
                   | _ ->
                       (* 如果不是 Union，检查类型是否直接匹配 *)
                       (try
                          let _ = unify expected_type target_type in
                          add_binding var_name target_type env
                        with Failure _ -> env))
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
        let err = make_error (TypeError "Unreachable pattern") _pos
          (Printf.sprintf "Pattern '%s' is unreachable (branch #%d in the match expression)" pat_str (idx + 1)) in
        report_error err
      ) unreachable_indices;

      (env, final_subst)

  | SInterface interface_info ->
      let name = interface_info.interface_name in
      let type_params = interface_info.interface_type_params in
      let members = interface_info.interface_members in
      let pos = interface_info.interface_pos in
      (* 检查接口是否已定义 *)
      (match Env.find_interface name env with
       | Some _ ->
           let err = make_error (TypeError "Interface already defined") pos
             (Printf.sprintf "Interface '%s' is already defined" name) in
           report_error err;
           (env, empty_subst)
       | None ->
           (* 验证接口成员 *)
           let check_interface_member = function
             | IMethod (_, _, params, ret_ty_opt, default_impl_opt, _) ->
                 (* 检查方法签名 *)
                 let param_types = List.map (fun (_, ty_opt, _) ->
                   match ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> fresh_type_var ()
                 ) params in
                 let ret_type = match ret_ty_opt with
                   | Some ty -> type_expr_to_ty ty
                   | None -> TyNone
                 in
                 (* 如果有默认实现,检查其类型 *)
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
                 (* 关联类型,如果有默认值则转换 *)
                 (match default_ty_opt with
                  | Some ty -> type_expr_to_ty ty
                  | None -> fresh_type_var ())

             | IAssocConst (const_name, const_ty, const_val, c_pos) ->
                 (* 检查常量类型和值的类型是否匹配 *)
                 let expected_ty = type_expr_to_ty const_ty in
                 let (actual_ty, val_subst) = infer_expr env const_val in
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

           (* 检查所有成员 *)
           List.iter (fun member ->
             let _ = check_interface_member member in ()
           ) members;

           (* 将接口定义添加到环境 *)
           let iface_def = {
             Env.iface_name = name;
             Env.iface_type_params = type_params;
             Env.iface_members = members;
           } in
           let new_env = Env.add_interface name iface_def env in
           (new_env, empty_subst))

  | SImpl (impl_block, pos) ->
      let target_ty = type_expr_to_ty impl_block.impl_target in

      (* 检查接口是否指定 *)
      (match impl_block.impl_interface with
       | None ->
           (* 没有指定接口，只是为类型定义方法 *)
           (* TODO: 存储这些方法到环境中 *)
           (env, empty_subst)
       | Some interface_name ->
           (* 检查接口是否存在 *)
           (match Env.find_interface interface_name env with
            | None ->
                let err = make_error (TypeError "Interface not found") pos
                  (Printf.sprintf "Interface '%s' is not defined" interface_name) in
                report_error err;
                (env, empty_subst)
            | Some iface_def ->
           (* 提取接口要求的方法 *)
           let required_methods = List.filter_map (function
             | IMethod (name, _, params, ret_ty_opt, default_impl_opt, _) ->
                 (* 如果有默认实现,则不是必需的 *)
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

           (* 检查impl中实现的方法 *)
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

                 (* 检查方法体 *)
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

           (* 检查是否所有必需的方法都已实现 *)
           let missing_methods = List.filter (fun (req_name, req_ty) ->
             not (List.exists (fun (impl_name, impl_ty) ->
               impl_name = req_name &&
               (* 检查类型是否兼容 *)
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

           (* 检查是否有多余的方法(不在接口定义中) *)
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

           (* 创建impl定义并添加到环境 *)
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
      (* 导入整个模块 *)
      (match Module_loader.import_all_from_module module_path alias with
       | Error msg ->
           (* 报告错误但不终止编译 *)
           Printf.eprintf "Import error: %s\n" msg;
           (env, empty_subst)
       | Ok imports ->
           (* 将导入的符号添加到环境 *)
           let new_env = List.fold_left (fun acc_env (name, symbol) ->
             match symbol with
             | Module_loader.ExportedFunc (_original_name, def_info) ->
                 (* 构造函数类型 *)
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
                 (* 提取默认参数 *)
                 let default_values = List.map (fun (_, _, default_opt) -> default_opt) def_info.def_params in
                 Env.add_function_with_defaults name func_type default_values acc_env
             | _ ->
                 (* 暂时只支持导入函数 *)
                 acc_env
           ) env imports in
           (new_env, empty_subst))

  | SFromImport (module_name, selections, _pos) ->
      (* 从模块导入指定符号 *)
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
                 (* 提取默认参数 *)
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
      (* 检查结构体是否已定义 *)
      (match Env.find_struct name env with
       | Some _ ->
           let err = make_error (TypeError "Struct already defined") pos
             (Printf.sprintf "Struct '%s' is already defined" name) in
           report_error err;
           (env, empty_subst)
       | None ->
           (* 分离字段和方法 *)
           let field_list = List.filter_map (function
             | SField field -> Some field
             | SMethod _ -> None
           ) members in

           let method_list = List.filter_map (function
             | SField _ -> None
             | SMethod (method_name, type_params, params, ret_ty_opt, body, _) ->
                 Some (method_name, type_params, params, ret_ty_opt, body)
           ) members in

           (* 转换字段类型 *)
           (* 对于匿名嵌入（field_name = None），使用类型名作为字段名 *)
           let struct_fields = List.map (fun field ->
             let field_name = match field.field_name with
               | Some name -> name
               | None ->
                   (* 匿名嵌入：从类型表达式提取类型名 *)
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

           (* 处理方法：检查方法体并生成方法类型 *)
           let struct_methods = List.fold_left (fun methods_map (method_name, _type_params, params, ret_ty_opt, body) ->
             (* 创建方法环境 *)
             let method_env =
               let base_env = create_child_env env in
               let (_, final_env) = List.fold_left
                 (fun (is_first, e) (pname, pty_opt, _) ->
                   let pty =
                     (* 如果是第一个参数且名为 self，则给它结构体类型 *)
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

             (* 检查方法体 *)
             let (_, _) = check_statements method_env body in

             (* 生成方法类型 *)
             let param_types =
               let (_, types) = List.fold_left
                 (fun (is_first, acc) (pname, pty_opt, _) ->
                   let pty =
                     (* 如果是第一个参数且名为 self，则给它结构体类型 *)
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

           (* 创建结构体定义 *)
           let struct_def = {
             Env.struct_name = name;
             Env.struct_type_params = type_params;
             Env.struct_fields = struct_fields;
             Env.struct_methods = struct_methods;
           } in

           (* 添加到环境 *)
           let new_env = Env.add_struct name struct_def env in
           (* 同时将结构体类型添加到绑定中，这样可以用作类型名 *)
           let struct_type = TyStruct (name, []) in
           let new_env = add_binding name struct_type new_env in

           (* 检查是否隐式实现了接口 *)
           let implemented_interfaces = Env.find_implicit_interfaces_for_struct name new_env in
           if List.length implemented_interfaces > 0 then begin
             (* 可选：记录或进行额外处理，这里只是静默检查 *)
             ()
           end;

           (new_env, empty_subst))

  | SEnum enum_info ->
      let name = enum_info.enum_name in
      let enum_type = TyEnum (name, []) in
      let new_env = add_binding name enum_type env in
      (new_env, empty_subst)

  | SFieldAssign (obj, field, value, pos) ->
      let (obj_type, obj_subst) = infer_expr env obj in
      let (value_type, value_subst) = infer_expr env value in
      let combined_subst = compose_subst value_subst obj_subst in
      (match apply_subst combined_subst obj_type with
       | TyStruct (struct_name, _) ->
           (* 查找结构体定义 *)
           (match Env.find_struct struct_name env with
            | None ->
                let err = make_error (NameError struct_name) pos
                  (Printf.sprintf "Struct '%s' is not defined" struct_name) in
                report_error err;
                (env, empty_subst)
            | Some struct_def ->
                (* 检查字段是否存在 *)
                (match List.assoc_opt field struct_def.struct_fields with
                 | None ->
                     let err = make_error (TypeError "Unknown field") pos
                       (Printf.sprintf "Struct '%s' has no field '%s'" struct_name field) in
                     report_error err;
                     (env, empty_subst)
                 | Some field_type ->
                     (* 检查类型是否匹配 *)
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

(* AST转换：填充默认参数 *)
let rec fill_default_params env expr =
  match expr with
  | ECall (EVar (func_name, func_pos), args, pos) ->
      (* 检查是否需要填充默认参数 *)
      (match Env.get_function_defaults func_name env with
       | Some defaults when List.length args < List.length defaults ->
           (* 需要填充默认参数 *)
           let num_provided = List.length args in
           (* 获取缺失的默认参数（从 num_provided 位置开始） *)
           let rec drop n lst = match n, lst with
             | 0, _ -> lst
             | _, [] -> []
             | n, _ :: xs -> drop (n - 1) xs
           in
           let missing_defaults = drop num_provided defaults in
           let default_args = List.filter_map (fun default_opt -> default_opt) missing_defaults in
           (* 递归处理已提供的参数 *)
           let new_args = List.map (fill_default_params env) args in
           (* 添加默认参数 *)
           let full_args = new_args @ default_args in
           ECall (EVar (func_name, func_pos), full_args, pos)
       | _ ->
           (* 不需要填充，只递归处理参数 *)
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
      let new_cases = List.map (fun (pat, guard_opt, expr) ->
        (pat, Option.map (fill_default_params env) guard_opt, fill_default_params env expr)
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
  | _ -> expr

let rec fill_default_params_stmt env stmt =
  match stmt with
  | SExpr (e, pos) -> SExpr (fill_default_params env e, pos)
  | SLet let_info ->
      SLet { let_info with let_value = fill_default_params env let_info.let_value }
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
  | SFor (pat, iter, body, pos) ->
      SFor (pat, fill_default_params env iter, List.map (fill_default_params_stmt env) body, pos)
  | SMatch (scrut, cases, pos) ->
      let new_cases = List.map (fun (pat, guard_opt, body) ->
        (pat, Option.map (fill_default_params env) guard_opt,
         List.map (fill_default_params_stmt env) body)
      ) cases in
      SMatch (fill_default_params env scrut, new_cases, pos)
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

let typecheck program =
  let (final_env, _) = check_statements builtin_env program in
  (* 填充默认参数 *)
  let transformed_program = List.map (fill_default_params_stmt final_env) program in
  (* 返回转换后的程序 *)
  transformed_program
