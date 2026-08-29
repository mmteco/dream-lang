open Types
open Ast

module StringMap = Map.Make(String)
module StringSet = Set.Make(String)

(* 接口定义 *)
type interface_def = {
  iface_name: string;
  iface_type_params: string list;
  iface_members: interface_member list;
}

(* impl块定义 *)
type impl_def = {
  impl_interface_name: string;
  impl_target_type: ty;
  impl_methods: ty StringMap.t;  (* 方法名 -> 方法类型 *)
}

(* 结构体定义 *)
type struct_def = {
  struct_name: string;
  struct_type_params: string list;
  struct_fields: ty StringMap.t;  (* 字段名 -> 字段类型 *)
  struct_methods: ty StringMap.t;  (* 方法名 -> 方法类型 *)
}

type env = {
  bindings: ty StringMap.t;
  parent: env option;
  locked: StringSet.t;
  interfaces: interface_def StringMap.t;  (* 接口名 -> 接口定义 *)
  impls: impl_def list StringMap.t;  (* 接口名 -> impl块列表 *)
  structs: struct_def StringMap.t;  (* 结构体名 -> 结构体定义 *)
  enums: enum_def StringMap.t;  (* 枚举名 -> 枚举定义 *)
  default_params: expr option list StringMap.t;  (* 函数名 -> 默认参数列表 *)
}

let empty_env = {
  bindings = StringMap.empty;
  parent = None;
  locked = StringSet.empty;
  interfaces = StringMap.empty;
  impls = StringMap.empty;
  structs = StringMap.empty;
  enums = StringMap.empty;
  default_params = StringMap.empty;
}

let create_child_env parent = {
  bindings = StringMap.empty;
  parent = Some parent;
  locked = StringSet.empty;
  interfaces = parent.interfaces;  (* 继承父环境的接口定义 *)
  impls = parent.impls;  (* 继承父环境的impl块 *)
  structs = parent.structs;  (* 继承父环境的结构体定义 *)
  enums = parent.enums;  (* 继承父环境的枚举定义 *)
  default_params = parent.default_params;  (* 继承父环境的默认参数 *)
}

let add_binding name ty env =
  { env with bindings = StringMap.add name ty env.bindings }

let add_function_with_defaults name ty defaults env =
  let env' = add_binding name ty env in
  { env' with default_params = StringMap.add name defaults env'.default_params }

let get_function_defaults name env =
  let rec lookup env =
    match StringMap.find_opt name env.default_params with
    | Some defaults -> Some defaults
    | None ->
        match env.parent with
        | Some parent -> lookup parent
        | None -> None
  in
  lookup env

let lock_binding name env =
  { env with locked = StringSet.add name env.locked }

let is_locked name env =
  StringSet.mem name env.locked

let rec find_binding name env =
  match StringMap.find_opt name env.bindings with
  | Some ty -> Some ty
  | None ->
      match env.parent with
      | Some parent -> find_binding name parent
      | None -> None

let find_binding_in_scope name env =
  StringMap.find_opt name env.bindings

let mem_binding name env =
  match find_binding name env with
  | Some _ -> true
  | None -> false

let update_binding name new_ty env =
  if is_locked name env then
    failwith (Printf.sprintf "Cannot change type of locked variable '%s'" name)
  else
    { env with bindings = StringMap.add name new_ty env.bindings }

let get_bindings env =
  StringMap.bindings env.bindings

let merge_env env1 env2 =
  {
    bindings = StringMap.union (fun _ v1 _ -> Some v1) env1.bindings env2.bindings;
    parent = env1.parent;
    locked = StringSet.union env1.locked env2.locked;
    interfaces = env1.interfaces;
    impls = env1.impls;
    structs = env1.structs;
    enums = StringMap.union (fun _ v1 _ -> Some v1) env1.enums env2.enums;
    default_params = StringMap.union (fun _ v1 _ -> Some v1) env1.default_params env2.default_params;
  }

(* 添加接口定义到环境 *)
let add_interface name iface env =
  { env with interfaces = StringMap.add name iface env.interfaces }

(* 查找接口定义 *)
let rec find_interface name env =
  match StringMap.find_opt name env.interfaces with
  | Some iface -> Some iface
  | None ->
      match env.parent with
      | Some parent -> find_interface name parent
      | None -> None

(* 添加impl块到环境，按接口名索引 *)
let add_impl impl env =
  let iface_name = impl.impl_interface_name in
  let existing = match StringMap.find_opt iface_name env.impls with
    | Some impls -> impls
    | None -> []
  in
  { env with impls = StringMap.add iface_name (impl :: existing) env.impls }

(* 查找类型的impl块，按接口名索引 *)
let find_impl_for_type target_type interface_name env =
  match StringMap.find_opt interface_name env.impls with
  | None -> None
  | Some impls ->
      List.find_opt (fun impl ->
        is_compatible impl.impl_target_type target_type
      ) impls

(* 查找同时匹配目标类型和方法参数的接口实现。*)
let find_impl_for_method target_type interface_name method_name argument_types env =
  let matches_impl impl =
    is_compatible impl.impl_target_type target_type &&
    match StringMap.find_opt method_name impl.impl_methods with
    | Some (TyFunc (parameter_types, _)) ->
        (match parameter_types with
         | _ :: method_argument_types
           when List.length method_argument_types = List.length argument_types ->
             List.for_all2 is_compatible method_argument_types argument_types
         | _ -> false)
    | _ -> false
  in
  let rec find env =
    match StringMap.find_opt interface_name env.impls with
    | Some impls ->
        (match List.find_opt matches_impl impls with
         | Some impl -> Some impl
         | None ->
             match env.parent with
             | Some parent -> find parent
             | None -> None)
    | None ->
        match env.parent with
        | Some parent -> find parent
        | None -> None
  in
  find env

(* 查找具体类型上的静态 impl 方法。*)
let rec find_impl_method_for_type target_type method_name env =
  match StringMap.fold (fun _iface_name impls acc ->
    match acc with
    | Some _ -> acc
    | None ->
        List.find_map (fun impl ->
          match StringMap.find_opt method_name impl.impl_methods with
          | Some method_type when is_compatible impl.impl_target_type target_type ->
              Some method_type
          | _ -> None
        ) impls
  ) env.impls None with
  | Some method_type -> Some method_type
  | None ->
      match env.parent with
      | Some parent -> find_impl_method_for_type target_type method_name parent
      | None -> None

(* 添加结构体定义到环境 *)
let add_struct name struct_def env =
  { env with structs = StringMap.add name struct_def env.structs }

(* 查找结构体定义 *)
let rec find_struct name env =
  match StringMap.find_opt name env.structs with
  | Some struct_def -> Some struct_def
  | None ->
        match env.parent with
        | Some parent -> find_struct name parent
        | None -> None

(* 添加枚举定义到环境。*)
let add_enum name enum_def env =
  { env with enums = StringMap.add name enum_def env.enums }

(* 查找枚举定义。*)
let rec find_enum name env =
  match StringMap.find_opt name env.enums with
  | Some enum_def -> Some enum_def
  | None ->
      match env.parent with
      | Some parent -> find_enum name parent
      | None -> None

(* 检查结构体是否隐式实现了接口 (Duck Typing) *)
let struct_implements_interface struct_def iface_def =
  (* 提取接口要求的方法 *)
  let required_methods = List.filter_map (function
    | IMethod (name, _, params, ret_ty_opt, default_impl_opt, _) ->
        (* 如果有默认实现，则不是必需的 *)
        if default_impl_opt = None then
          let param_types = List.map (fun (_, ty_opt, _) ->
            match ty_opt with
            | Some ty -> type_expr_to_ty ty
            | None -> TyVar "T"  (* 参数类型未指定，使用泛型 *)
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

  (* 检查结构体是否有所有必需的方法 *)
  List.for_all (fun (method_name, expected_type) ->
    match StringMap.find_opt method_name struct_def.struct_methods with
    | None -> false
    | Some actual_type ->
        (* 检查方法签名是否兼容 *)
        (try
           let _ = unify actual_type expected_type in
           true
         with Failure _ -> false)
  ) required_methods

(* 查找类型隐式实现的所有接口 *)
let find_implicit_interfaces_for_struct struct_name env =
  match find_struct struct_name env with
  | None -> []
  | Some struct_def ->
      (* 遍历所有接口，检查结构体是否隐式实现 *)
      StringMap.fold (fun iface_name iface_def acc ->
        if struct_implements_interface struct_def iface_def then
          iface_name :: acc
        else
          acc
      ) env.interfaces []

(* C Runtime 函数列表 - 使用 Hashtbl 实现 O(1) 查找 *)
let c_runtime_functions_table =
  let tbl = Hashtbl.create 32 in
  let funcs = [
    (* 进程参数 *)
    ("__c_process_arg_count", TyFunc ([], TyInt));
    ("__c_process_arg", TyFunc ([TyInt], TyStr));
    ("__c_env", TyFunc ([TyStr], TyStr));
    ("__c_build_llvm", TyFunc ([TyStr; TyStr; TyBool], TyInt));
    (* 文件 I/O *)
    ("__c_file_read", TyFunc ([TyStr], TyStr));
    ("__c_file_write", TyFunc ([TyStr; TyStr], TyInt));
    ("__c_file_exists", TyFunc ([TyStr], TyBool));
    ("__c_file_append", TyFunc ([TyStr; TyStr], TyInt));
    ("__c_file_delete", TyFunc ([TyStr], TyBool));
    ("__c_file_read_bytes", TyFunc ([TyStr], TyBytes));
    ("__c_file_write_bytes", TyFunc ([TyStr; TyBytes], TyInt));
    ("__c_file_append_bytes", TyFunc ([TyStr; TyBytes], TyInt));

    (* 网络 I/O *)
    ("__c_net_connect", TyFunc ([TyStr; TyInt], TyInt));
    ("__c_net_write", TyFunc ([TyInt; TyStr], TyInt));
    ("__c_net_read", TyFunc ([TyInt; TyInt], TyStr));
    ("__c_net_close", TyFunc ([TyInt], TyBool));
    ("__c_http_request", TyFunc ([TyStr; TyStr; TyStr; TyStr], TyStr));

    (* UTF-8 编解码 *)
    ("__c_utf8_decode_rune", TyFunc ([TyBytes; TyInt], TyTuple [TyRune; TyInt]));
    ("__c_utf8_encode_rune", TyFunc ([TyRune], TyBytes));
    ("__c_utf8_rune_count", TyFunc ([TyStr], TyInt));
    ("__c_utf8_rune_at", TyFunc ([TyStr; TyInt], TyRune));
    ("__c_rune_to_int", TyFunc ([TyRune], TyInt));
    ("__c_utf8_byte_at", TyFunc ([TyStr; TyInt], TyInt));
    ("__c_utf8_byte_offset", TyFunc ([TyStr; TyInt], TyInt));
    ("__c_range_equal", TyFunc ([TyStr; TyInt; TyInt; TyInt; TyInt], TyBool));
    ("__c_fnv_hash_range", TyFunc ([TyStr; TyInt; TyInt], TyInt));
    ("__c_range_equals_cstr", TyFunc ([TyStr; TyInt; TyInt; TyStr], TyBool));

    (* bytes 操作 *)
    ("__c_bytes_length", TyFunc ([TyBytes], TyInt));
    ("__c_bytes_get", TyFunc ([TyBytes; TyInt], TyByte));
    ("__c_bytes_slice", TyFunc ([TyBytes; TyInt; TyInt], TyBytes));
    ("__c_bytes_from_array", TyFunc ([TyList TyByte], TyBytes));
    ("__c_str_to_bytes", TyFunc ([TyStr], TyBytes));
    ("__c_bytes_to_str", TyFunc ([TyBytes], TyStr));
  ] in
  List.iter (fun (name, ty) -> Hashtbl.add tbl name ty) funcs;
  tbl

let c_runtime_functions =
  Hashtbl.fold (fun name ty acc -> (name, ty) :: acc) c_runtime_functions_table []

(* 检查函数是否是 C Runtime 函数 *)
let is_c_runtime_function name =
  Hashtbl.mem c_runtime_functions_table name

(* === 运算符重载支持 === *)

(* 二元运算符到接口名的映射 *)
let binop_to_interface_name = function
  | Add -> Some "Add"
  | Sub -> Some "Sub"
  | Mul -> Some "Mul"
  | Div -> Some "Div"
  | FloorDiv -> Some "FloorDiv"
  | Mod -> Some "Mod"
  | Pow -> Some "Pow"
  | BitAnd -> Some "BitAnd"
  | BitOr -> Some "BitOr"
  | BitXor -> Some "BitXor"
  | Shl -> Some "Shl"
  | Shr -> Some "Shr"
  | Eq -> Some "Eq"
  | Neq -> Some "Eq"  (* != 使用 Eq 接口的 neq 方法 *)
  | Lt -> Some "Ord"
  | Gt -> Some "Ord"
  | Lte -> Some "Ord"
  | Gte -> Some "Ord"
  | And | Or | In -> None  (* 逻辑和成员运算符不可重载 *)

(* 二元运算符到方法名的映射 *)
let binop_to_method_name = function
  | Add -> "add"
  | Sub -> "sub"
  | Mul -> "mul"
  | Div -> "div"
  | FloorDiv -> "floordiv"
  | Mod -> "mod"
  | Pow -> "pow"
  | BitAnd -> "bitand"
  | BitOr -> "bitor"
  | BitXor -> "bitxor"
  | Shl -> "shl"
  | Shr -> "shr"
  | Eq -> "eq"
  | Neq -> "neq"
  | Lt -> "lt"
  | Gt -> "gt"
  | Lte -> "lte"
  | Gte -> "gte"
  | And | Or | In -> failwith "logical and membership operators cannot be overloaded"

(* 一元运算符到接口名的映射 *)
let unop_to_interface_name = function
  | Neg -> Some "Neg"
  | Pos -> Some "Pos"
  | Invert -> Some "BitNot"
  | Not -> Some "Not"

(* 一元运算符到方法名的映射 *)
let unop_to_method_name = function
  | Neg -> "neg"
  | Pos -> "pos"
  | Invert -> "bitnot"
  | Not -> "not_op"

(* 查找二元运算符的接口实现 *)
let find_binop_impl left_ty binop _right_ty env =
  (* TODO: 未来可以验证右操作数类型是否与接口参数匹配 *)
  match binop_to_interface_name binop with
  | None -> None  (* 不可重载的运算符 *)
  | Some interface_name ->
      match StringMap.find_opt interface_name env.impls with
      | None -> None
      | Some impls ->
          List.find_opt (fun impl ->
            is_compatible impl.impl_target_type left_ty
          ) impls

(* 查找一元运算符的接口实现 *)
let find_unop_impl operand_ty unop env =
  match unop_to_interface_name unop with
  | None -> None
  | Some interface_name ->
      match StringMap.find_opt interface_name env.impls with
      | None -> None
      | Some impls ->
          List.find_opt (fun impl ->
            is_compatible impl.impl_target_type operand_ty
          ) impls

(* 获取运算符接口实现的方法类型 *)
let get_operator_method_type impl_def method_name =
  StringMap.find_opt method_name impl_def.impl_methods

(* === 运算符重载支持结束 === *)

let builtin_env =
  let env = empty_env in
  let env = add_binding "print" (TyFunc ([TyVar "T"], TyNone)) env in
  let env = add_binding "eprint" (TyFunc ([TyVar "T"], TyNone)) env in
  let env = add_binding "len" (TyFunc ([TyList (TyVar "T")], TyInt)) env in
  let env = add_binding "append" (TyFunc ([TyList (TyVar "T"); TyVar "T"], TyNone)) env in
  let env = add_binding "range" (TyFunc ([TyInt], TyList TyInt)) env in
  let env = add_binding "dict_keys" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "K"))) env in
  let env = add_binding "dict_values" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyVar "V"))) env in
  let env = add_binding "dict_items" (TyFunc ([TyDict (TyVar "K", TyVar "V")], TyList (TyTuple [TyVar "K"; TyVar "V"]))) env in
  let env = add_binding "join" (TyFunc ([TyList TyStr; TyStr], TyStr)) env in
  let env = add_binding "string_concat" (TyFunc ([TyStr; TyStr], TyStr)) env in
  let env = add_binding "chr" (TyFunc ([TyInt], TyRune)) env in
  let env = add_binding "ord" (TyFunc ([TyRune], TyInt)) env in
  let env = add_binding "array" (TyFunc ([TyList (TyVar "T")], TyList (TyVar "T"))) env in
  let env = add_binding "array_new" (TyFunc ([TyInt], TyList (TyVar "T"))) env in
  (* 将所有 C Runtime 函数添加到环境中 *)
  let env = List.fold_left (fun e (name, ty) -> add_binding name ty e) env c_runtime_functions in
  (* 预定义内置枚举类型 *)
  let env = add_binding "Option" (TyEnum ("Option", [])) env in
  let env = add_binding "Result" (TyEnum ("Result", [])) env in
  env
