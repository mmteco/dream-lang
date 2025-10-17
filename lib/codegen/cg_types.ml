(* LLVM 类型定义 *)

(* Debug 输出辅助函数 - 运行时检查环境变量 DEBUG=true *)
let debug_print format =
  let debug_enabled =
    try Sys.getenv "DEBUG" = "true"
    with Not_found -> false
  in
  if debug_enabled then
    Printf.eprintf format
  else
    Printf.ifprintf stderr format

type llvm_type =
  | I32
  | U32  (* unsigned 32-bit *)
  | I64
  | I8
  | U8   (* unsigned 8-bit *)
  | I1
  | Void
  | Ptr of llvm_type
  | Array of int * llvm_type  (* 固定长度数组: [n x elem_t] *)
  | ImmutableArray of llvm_type  (* 不可变数组: {length, data*} *)
  | DynArray of llvm_type  (* 动态数组(可变): {capacity, length, data*} *)
  | DynArrayPtr  (* 指针数组: {capacity, length, intptr_t*} - 用于存储指针 *)
  | StrType    (* str: UTF-8 编码的不可变字符串，底层是 ImmutableArray U8 *)
  | BytesType  (* bytes: 不可变字节序列，底层是 ImmutableArray U8 *)
  | TuplePtr  (* 元组指针 *)
  | DictPtr   (* 字典指针 dict[int,int] *)
  | DictStrPtr (* 字符串键字典指针 dict[string,int] *)
  | UnionPtr   (* Union 类型指针 *)
  | EnumPtr    (* Enum 类型指针 *)
  | StructPtr of string  (* 结构体指针，保存结构体名称 *)

type llvm_value = string

(* 枚举定义注册表 *)
type enum_variant_info = {
  variant_name: string;
  tag: int;
  has_data: bool;
}

type enum_definition = {
  enum_name: string;
  variants: enum_variant_info list;
}

let enum_registry : (string, enum_definition) Hashtbl.t = Hashtbl.create 16

(* 结构体定义注册表 *)
type struct_field_info = {
  field_name: string;
  field_index: int;
  field_llvm_type: llvm_type;
}

type struct_definition = {
  struct_name: string;
  fields: struct_field_info list;
}

let struct_registry : (string, struct_definition) Hashtbl.t = Hashtbl.create 16

(* 方法注册表: method_name -> struct_name *)
let struct_method_registry : (string, string) Hashtbl.t = Hashtbl.create 16

(* impl 方法注册表: (target_type, interface, method) -> mangled_name *)
(* 例如: ("Vec2", "Add", "add") -> "Add_add_for_Vec2" *)
let impl_method_registry : ((string * string * string), string) Hashtbl.t = Hashtbl.create 16

(* impl 方法参数类型注册表: mangled_name -> param_types *)
(* 用于存储每个 impl 方法的参数类型列表 *)
let impl_method_param_types : (string, llvm_type list) Hashtbl.t = Hashtbl.create 16

(* impl 方法返回类型注册表: mangled_name -> return_type *)
(* 用于存储每个 impl 方法的返回类型 *)
let impl_method_return_types : (string, llvm_type) Hashtbl.t = Hashtbl.create 16

(* Context 上下文 *)
type context = {
  mutable variables: (string * llvm_type) list;
  mutable function_type: llvm_type option;
  mutable string_literals: (string * string * int) list;
  (* 变量名重映射表: 原始名 -> LLVM变量名(不含%) *)
  mutable var_renames: (string * string) list;
  (* 跟踪动态分配的对象,需要在作用域结束时释放 *)
  (* 存储 (变量名, LLVM临时变量名) *)
  mutable dynarray_vars: (string * string) list;
  (* 跟踪 GC 分配的对象（union 等），需要在作用域结束时释放 *)
  mutable gc_objects: string list;  (* 存储临时变量名 *)
  (* 函数签名表: 函数名 -> 返回类型 *)
  mutable function_signatures: (string * llvm_type) list;
  (* 函数参数类型表: 函数名 -> 参数类型列表 *)
  mutable function_param_types: (string * llvm_type list) list;
  (* 变量对应的结构体类型: 变量名 -> 结构体名 *)
  mutable var_struct_types: (string * string) list;
}

let create_context () = {
  variables = [];
  function_type = None;
  string_literals = [];
  var_renames = [];
  dynarray_vars = [];
  gc_objects = [];
  function_signatures = [];
  function_param_types = [];
  var_struct_types = [];
}

let add_variable ctx name ty =
  ctx.variables <- (name, ty) :: ctx.variables

let add_variable_with_rename ctx orig_name llvm_name ty =
  ctx.variables <- (orig_name, ty) :: ctx.variables;
  ctx.var_renames <- (orig_name, llvm_name) :: ctx.var_renames

let find_variable ctx name =
  try Some (List.assoc name ctx.variables)
  with Not_found -> None

let find_llvm_name ctx name =
  try Some (List.assoc name ctx.var_renames)
  with Not_found -> None
