(* LLVM 类型定义 *)

type llvm_type =
  | I32
  | I64
  | I1
  | Void
  | Ptr of llvm_type
  | Array of int * llvm_type
  | DynArray of llvm_type  (* 动态数组: {capacity, length, data*} *)
  | DynArrayPtr  (* 指针数组: {capacity, length, intptr_t*} - 用于存储指针 *)
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
