open Ast
open Types

(* 泛型函数实例 *)
type instance = {
  func_name: string;
  type_params: string list;
  type_args: ty list;
  mangled_name: string;
}

(* 单态化上下文 *)
type mono_context = {
  mutable instances: instance list;
  mutable generic_funcs: (string * statement) list;
}

let create_mono_context () = {
  instances = [];
  generic_funcs = [];
}

(* 类型到字符串的简化版本，用于名称重整 *)
let rec ty_to_mangle_string = function
  | TyInt -> "i32"
  | TyFloat -> "f32"
  | TyStr -> "str"
  | TyRune -> "rune"
  | TyByte -> "byte"
  | TyBytes -> "bytes"
  | TyBool -> "bool"
  | TyNone -> "none"
  | TyVar name -> name
  | TyList t -> "list_" ^ ty_to_mangle_string t
  | TyDict (k, v) -> "dict_" ^ ty_to_mangle_string k ^ "_" ^ ty_to_mangle_string v
  | TyTuple ts -> "tuple_" ^ String.concat "_" (List.map ty_to_mangle_string ts)
  | TyFunc _ -> "func"
  | TyUnion _ -> "union"
  | TyGeneric (name, t) -> name ^ "_" ^ ty_to_mangle_string t
  | TyOption t -> "opt_" ^ ty_to_mangle_string t
  | TyResult (ok, err) -> "res_" ^ ty_to_mangle_string ok ^ "_" ^ ty_to_mangle_string err
  | TyEnum (name, []) -> name
  | TyEnum (name, params) -> name ^ "_" ^ String.concat "_" (List.map ty_to_mangle_string params)
  | TyInterface (name, []) -> "iface_" ^ name
  | TyInterface (name, params) -> "iface_" ^ name ^ "_" ^ String.concat "_" (List.map ty_to_mangle_string params)
  | TyStruct (name, []) -> "struct_" ^ name
  | TyStruct (name, params) -> "struct_" ^ name ^ "_" ^ String.concat "_" (List.map ty_to_mangle_string params)
  | TyTypeInfo t -> "typeinfo_" ^ ty_to_mangle_string t
  | TyUnknown -> "unknown"

(* 生成重整后的函数名 *)
let mangle_func_name func_name type_args =
  if List.length type_args = 0 then
    func_name
  else
    func_name ^ "_" ^ String.concat "_" (List.map ty_to_mangle_string type_args)

(* 检查实例是否已存在 *)
let instance_exists ctx func_name type_args =
  List.exists (fun inst ->
    inst.func_name = func_name &&
    List.length inst.type_args = List.length type_args &&
    List.for_all2 (fun t1 t2 -> t1 = t2) inst.type_args type_args
  ) ctx.instances

(* 添加新实例 *)
let add_instance ctx func_name type_params type_args =
  if not (instance_exists ctx func_name type_args) then begin
    let mangled = mangle_func_name func_name type_args in
    let inst = {
      func_name;
      type_params;
      type_args;
      mangled_name = mangled;
    } in
    ctx.instances <- inst :: ctx.instances;
    inst
  end else
    List.find (fun inst ->
      inst.func_name = func_name &&
      List.for_all2 (fun t1 t2 -> t1 = t2) inst.type_args type_args
    ) ctx.instances

(* 在类型中替换类型参数 *)
let rec substitute_type_params type_params type_args ty =
  match ty with
  | TyVar name ->
      (try
        let idx = List.find_index ((=) name) type_params in
        match idx with
        | Some i -> List.nth type_args i
        | None -> ty
       with _ -> ty)
  | TyList t -> TyList (substitute_type_params type_params type_args t)
  | TyDict (k, v) ->
      TyDict (
        substitute_type_params type_params type_args k,
        substitute_type_params type_params type_args v
      )
  | TyTuple ts ->
      TyTuple (List.map (substitute_type_params type_params type_args) ts)
  | TyFunc (params, ret) ->
      TyFunc (
        List.map (substitute_type_params type_params type_args) params,
        substitute_type_params type_params type_args ret
      )
  | TyOption t -> TyOption (substitute_type_params type_params type_args t)
  | TyResult (ok, err) ->
      TyResult (
        substitute_type_params type_params type_args ok,
        substitute_type_params type_params type_args err
      )
  | TyGeneric (name, parameter) ->
      TyGeneric (name, substitute_type_params type_params type_args parameter)
  | TyEnum (name, params) ->
      TyEnum (name, List.map (substitute_type_params type_params type_args) params)
  | TyInterface (name, params) ->
      TyInterface (name, List.map (substitute_type_params type_params type_args) params)
  | _ -> ty

(* 在类型表达式中替换类型参数 *)
let rec substitute_type_expr type_params type_args = function
  | TVar name ->
      (try
        let idx = List.find_index ((=) name) type_params in
        match idx with
        | Some i ->
            let ty = List.nth type_args i in
            type_expr_of_ty ty
        | None -> TVar name
       with _ -> TVar name)
  | TList t -> TList (substitute_type_expr type_params type_args t)
  | TDict (k, v) ->
      TDict (
        substitute_type_expr type_params type_args k,
        substitute_type_expr type_params type_args v
      )
  | TTuple ts ->
      TTuple (List.map (substitute_type_expr type_params type_args) ts)
  | TFunc (params, ret) ->
      TFunc (
        List.map (substitute_type_expr type_params type_args) params,
        substitute_type_expr type_params type_args ret
      )
  | TUnion types ->
      TUnion (List.map (substitute_type_expr type_params type_args) types)
  | TOption element_type ->
      TOption (substitute_type_expr type_params type_args element_type)
  | TResult (ok_type, error_type) ->
      TResult (
        substitute_type_expr type_params type_args ok_type,
        substitute_type_expr type_params type_args error_type
      )
  | TGeneric (name, parameter) ->
      TGeneric (name, substitute_type_expr type_params type_args parameter)
  | TEnum (name, parameters) ->
      TEnum (name, List.map (substitute_type_expr type_params type_args) parameters)
  | TStruct (name, parameters) ->
      TStruct (name, List.map (substitute_type_expr type_params type_args) parameters)
  | t -> t

and type_expr_of_ty = function
  | TyInt -> TInt
  | TyFloat -> TFloat
  | TyStr -> TStr
  | TyRune -> TRune
  | TyByte -> TByte
  | TyBytes -> TBytes
  | TyBool -> TBool
  | TyNone -> TNone
  | TyVar name -> TVar name
  | TyList t -> TList (type_expr_of_ty t)
  | TyDict (k, v) -> TDict (type_expr_of_ty k, type_expr_of_ty v)
  | TyTuple ts -> TTuple (List.map type_expr_of_ty ts)
  | TyUnion types -> TUnion (List.map type_expr_of_ty types)
  | TyFunc (params, ret) -> TFunc (List.map type_expr_of_ty params, type_expr_of_ty ret)
  | TyOption t -> TOption (type_expr_of_ty t)
  | TyResult (ok, err) -> TResult (type_expr_of_ty ok, type_expr_of_ty err)
  | TyGeneric (name, parameter) -> TGeneric (name, type_expr_of_ty parameter)
  | TyEnum (name, params) -> TEnum (name, List.map type_expr_of_ty params)
  | TyStruct (name, params) -> TStruct (name, List.map type_expr_of_ty params)
  | TyInterface (_, _) -> TNone  (* 接口类型暂时没有对应的 type_expr *)
  | _ -> TNone

(* 在表达式中替换类型参数并重命名泛型函数调用 *)
let rec substitute_expr ctx type_params type_args expr =
  match expr with
  | ECall (EVar (func_name, p), args, pos) ->
      (* 检查是否是泛型函数调用 *)
      let new_args = List.map (substitute_expr ctx type_params type_args) args in
      (try
        match List.find (fun (name, _) -> name = func_name) ctx.generic_funcs with
        | (_, SDef def_info) ->
            if List.length def_info.def_type_params > 0 then
              (* 这是泛型函数调用，需要推断类型参数 *)
              ECall (EVar (func_name, p), new_args, pos)
            else
              ECall (EVar (func_name, p), new_args, pos)
        | _ -> ECall (EVar (func_name, p), new_args, pos)
       with Not_found ->
         ECall (EVar (func_name, p), new_args, pos))
  | ECall (func, args, pos) ->
      ECall (
        substitute_expr ctx type_params type_args func,
        List.map (substitute_expr ctx type_params type_args) args,
        pos
      )
  | EBinOp (e1, op, e2, pos) ->
      EBinOp (
        substitute_expr ctx type_params type_args e1,
        op,
        substitute_expr ctx type_params type_args e2,
        pos
      )
  | EUnOp (op, e, pos) ->
      EUnOp (op, substitute_expr ctx type_params type_args e, pos)
  | EList (elems, pos) ->
      EList (List.map (substitute_expr ctx type_params type_args) elems, pos)
  | ETuple (elems, pos) ->
      ETuple (List.map (substitute_expr ctx type_params type_args) elems, pos)
  | EIndex (arr, idx, pos) ->
      EIndex (
        substitute_expr ctx type_params type_args arr,
        substitute_expr ctx type_params type_args idx,
        pos
      )
  | _ -> expr

(* 在语句中替换类型参数 *)
let rec substitute_statement ctx type_params type_args stmt =
  match stmt with
  | SLet let_info ->
      let new_ty = match let_info.let_type with
        | Some ty -> Some (substitute_type_expr type_params type_args ty)
        | None -> None
      in
      SLet {
        let_info with
        let_type = new_ty;
        let_value = substitute_expr ctx type_params type_args let_info.let_value
      }
  | SConst const_info ->
      let new_ty = match const_info.const_type with
        | Some ty -> Some (substitute_type_expr type_params type_args ty)
        | None -> None
      in
      SConst {
        const_info with
        const_type = new_ty;
        const_value = substitute_expr ctx type_params type_args const_info.const_value
      }
  | SExpr (e, pos) ->
      SExpr (substitute_expr ctx type_params type_args e, pos)
  | SReturn (Some e, pos) ->
      SReturn (Some (substitute_expr ctx type_params type_args e), pos)
  | SIf (cond, then_body, elifs, else_opt, pos) ->
      SIf (
        substitute_expr ctx type_params type_args cond,
        List.map (substitute_statement ctx type_params type_args) then_body,
        List.map (fun (c, b) ->
          (substitute_expr ctx type_params type_args c,
           List.map (substitute_statement ctx type_params type_args) b)
        ) elifs,
        Option.map (List.map (substitute_statement ctx type_params type_args)) else_opt,
        pos
      )
  | SBreak pos -> SBreak pos
  | SContinue pos -> SContinue pos
  | SWhile (cond, body, pos) ->
      SWhile (
        substitute_expr ctx type_params type_args cond,
        List.map (substitute_statement ctx type_params type_args) body,
        pos
      )
  | _ -> stmt

(* 生成单态化的函数定义 *)
let monomorphize_function ctx _func_name type_params params ret_ty body inst =
  let new_params = List.map (fun (pname, pty_opt, default_val) ->
    match pty_opt with
    | Some ty -> (pname, Some (substitute_type_expr type_params inst.type_args ty), default_val)
    | None -> (pname, None, default_val)
  ) params in

  let new_ret_ty = match ret_ty with
    | Some ty -> Some (substitute_type_expr type_params inst.type_args ty)
    | None -> None
  in

  let new_body = List.map (substitute_statement ctx type_params inst.type_args) body in

  SDef {
    def_name = inst.mangled_name;
    def_name_pos = { line = 0; column = 0 };
    def_type_params = [];
    def_params = new_params;
    def_return_type = new_ret_ty;
    def_body = new_body;
    def_pos = { line = 0; column = 0 };
  }

(* 收集程序中的泛型函数 *)
let collect_generic_functions program =
  List.filter_map (function
    | SDef def_info as def when List.length def_info.def_type_params > 0 ->
        Some (def_info.def_name, def)
    | _ -> None
  ) program

(* 重写表达式中的泛型函数调用 *)
let rec rewrite_generic_calls generic_instances generic_funcs expr =
  match expr with
  | ECall (EVar (func_name, p), args, pos) ->
      let new_args = List.map (rewrite_generic_calls generic_instances generic_funcs) args in
      (* 检查是否是泛型函数 *)
      if List.mem_assoc func_name generic_funcs then
        (* 查找匹配的实例 *)
        (try
          let inst = List.find (fun (inst : Typeck.generic_instance) ->
            inst.func_name = func_name && inst.call_pos = pos
          ) generic_instances in
          let mangled_name = mangle_func_name func_name inst.type_args in
          ECall (EVar (mangled_name, p), new_args, pos)
         with Not_found -> ECall (EVar (func_name, p), new_args, pos))
      else
        ECall (EVar (func_name, p), new_args, pos)
  | ECall (func, args, pos) ->
      ECall (
        rewrite_generic_calls generic_instances generic_funcs func,
        List.map (rewrite_generic_calls generic_instances generic_funcs) args,
        pos
      )
  | EBinOp (e1, op, e2, pos) ->
      EBinOp (
        rewrite_generic_calls generic_instances generic_funcs e1,
        op,
        rewrite_generic_calls generic_instances generic_funcs e2,
        pos
      )
  | EUnOp (op, e, pos) ->
      EUnOp (op, rewrite_generic_calls generic_instances generic_funcs e, pos)
  | EList (elems, pos) ->
      EList (List.map (rewrite_generic_calls generic_instances generic_funcs) elems, pos)
  | ETuple (elems, pos) ->
      ETuple (List.map (rewrite_generic_calls generic_instances generic_funcs) elems, pos)
  | EIndex (arr, idx, pos) ->
      EIndex (
        rewrite_generic_calls generic_instances generic_funcs arr,
        rewrite_generic_calls generic_instances generic_funcs idx,
        pos
      )
  | _ -> expr

(* 重写语句中的泛型函数调用 *)
let rec rewrite_statement generic_instances generic_funcs stmt =
  match stmt with
  | SLet let_info ->
      SLet {
        let_info with
        let_value = rewrite_generic_calls generic_instances generic_funcs let_info.let_value
      }
  | SConst const_info ->
      SConst {
        const_info with
        const_value = rewrite_generic_calls generic_instances generic_funcs const_info.const_value
      }
  | SExpr (e, pos) ->
      SExpr (rewrite_generic_calls generic_instances generic_funcs e, pos)
  | SReturn (Some e, pos) ->
      SReturn (Some (rewrite_generic_calls generic_instances generic_funcs e), pos)
  | SIf (cond, then_body, elifs, else_opt, pos) ->
      SIf (
        rewrite_generic_calls generic_instances generic_funcs cond,
        List.map (rewrite_statement generic_instances generic_funcs) then_body,
        List.map (fun (c, b) ->
          (rewrite_generic_calls generic_instances generic_funcs c,
           List.map (rewrite_statement generic_instances generic_funcs) b)
        ) elifs,
        Option.map (List.map (rewrite_statement generic_instances generic_funcs)) else_opt,
        pos
      )
  | SBreak pos -> SBreak pos
  | SContinue pos -> SContinue pos
  | SWhile (cond, body, pos) ->
      SWhile (
        rewrite_generic_calls generic_instances generic_funcs cond,
        List.map (rewrite_statement generic_instances generic_funcs) body,
        pos
      )
  | SFor (pat, iter, body, pos) ->
      SFor (
        pat,
        rewrite_generic_calls generic_instances generic_funcs iter,
        List.map (rewrite_statement generic_instances generic_funcs) body,
        pos
      )
  | SDef def_info ->
      SDef {
        def_info with
        def_body = List.map (rewrite_statement generic_instances generic_funcs) def_info.def_body
      }
  | _ -> stmt

(* 主单态化函数 *)
let monomorphize program generic_instances =
  let ctx = create_mono_context () in
  ctx.generic_funcs <- collect_generic_functions program;

  (* 根据收集到的泛型实例生成单态化函数 *)
  List.iter (fun (inst : Typeck.generic_instance) ->
    (* 查找对应的泛型函数定义 *)
    try
      match List.assoc inst.func_name ctx.generic_funcs with
      | SDef def_info ->
          let _ = add_instance ctx inst.func_name def_info.def_type_params inst.type_args in
          ()
      | _ -> ()
    with Not_found -> ()
  ) generic_instances;

  (* 为每个实例生成单态化的函数 *)
  let mono_funcs = List.map (fun inst ->
    match List.assoc inst.func_name ctx.generic_funcs with
    | SDef def_info ->
        monomorphize_function ctx inst.func_name def_info.def_type_params
          def_info.def_params def_info.def_return_type def_info.def_body inst
    | _ -> failwith "Expected function definition"
  ) ctx.instances in

  (* 过滤掉原始的泛型函数，保留非泛型的语句 *)
  let non_generic_stmts = List.filter (function
    | SDef def_info -> List.length def_info.def_type_params = 0
    | _ -> true
  ) program in

  (* 重写非泛型语句中的泛型函数调用 *)
  let rewritten_stmts = List.map (rewrite_statement generic_instances ctx.generic_funcs) non_generic_stmts in

  (* 返回重写后的语句 + 单态化函数 *)
  rewritten_stmts @ mono_funcs
