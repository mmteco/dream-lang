(* 具体类型名的稳定 tag（FNV-1a 32 位），接口值类型断言与 match type of 共用 *)
let concrete_type_tag name =
  let hash = ref 0x811c9dc5l in
  String.iter (fun character ->
    hash := Int32.logxor !hash (Int32.of_int (Char.code character));
    hash := Int32.mul !hash 0x01000193l
  ) name;
  Int32.to_int !hash

type ty =
  | Unit
  | Bool
  | I32
  | F64
  | Str
  | Bytes
  | Dict of ty * ty
  | List of ty
  | Tuple of ty list
  | Struct of string * (string * ty) list
  | Ref of ty
  | Enum of string * (string * ty list) list
  | Interface of string * (string * ty list * ty) list
  | Union of ty list
  | ClosureEnv of ty list
  | Func of ty list * ty

type value = int

type operand =
  | Value of value
  | Int of int
  | Float of float
  | Bool of bool
  | String of string
  | FunctionRef of string

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | BitAnd
  | BitOr
  | BitXor
  | Shl
  | Shr
  | And
  | Or

type cmp =
  | Eq
  | Ne
  | Lt
  | Gt
  | Le
  | Ge

type instruction =
  | Binop of value * ty * binop * operand * operand
  | Compare of value * cmp * operand * operand
  | Call of value option * ty * string * ty list * operand list
  | CallIndirect of value option * ty * ty list * operand * operand list
  | MakeClosure of value * ty * string * ty list * operand list
  | ClosureGet of value * ty * ty list * operand * int
  | InterfaceBox of value * ty * operand
  | MakeInterface of value * ty * ty * operand * string list
  | InterfaceCall of value option * ty * ty * operand * string * int * ty list * operand list
  | InterfaceRelease of operand
  | InterfaceTypeTag of value * operand
  | StringLength of value * operand
  | StringCompare of value * operand * operand
  | StringSlice of value * operand * operand * operand
  | ListLength of value * operand
  | ListGet of value * operand * operand
  | ListCreate of value * ty * operand list
  | ListSlice of value * operand * operand * operand
  | ListConcat of value * operand * operand
  | TupleCreate of value * ty list * operand list
  | TupleGet of value * ty * operand * int
  | StructCreate of value * string * (string * ty) list * operand list
  | StructGet of value * ty * operand * int
  | StructSet of value * operand * ty * int * operand
  | Alloca of value * ty
  | Load of value * ty * operand
  | Store of ty * operand * operand
  | EnumCreate of value * ty * int * ty * operand
  | EnumCreateMulti of value * ty * int * ty list * operand list
  | EnumCreateSimple of value * ty * int
  | EnumTag of value * operand
  | EnumGet of value * ty * operand * int
  | EnumGetMulti of value * ty * ty list * operand * int * int
  | ListAppend of operand * operand * ty
  | ListSet of operand * operand * operand
  | GlobalLoad of value * ty * string
  | GlobalStore of string * operand

type terminator =
  | Jump of string * operand list
  | Branch of operand * (string * operand list) * (string * operand list)
  | Switch of operand * (operand * string * operand list) list * (string * operand list)
  | Return of operand option
  | Unreachable

type block = {
  label: string;
  params: (value * ty) list;
  instructions: instruction list;
  terminator: terminator;
}

type parameter = {
  value: value;
  name: string;
  ty: ty;
}

type function_def = {
  name: string;
  parameters: parameter list;
  return_type: ty;
  blocks: block list;
}

type extern = {
  name: string;
  parameters: ty list;
  return_type: ty;
}

type module_ = {
  name: string;
  externs: extern list;
  globals: (string * ty) list;
  functions: function_def list;
}

let rec equal_ty left right =
  match left, right with
  | Unit, Unit
  | Bool, Bool
  | I32, I32
  | F64, F64
  | Str, Str
  | Bytes, Bytes -> true
  | Dict (left_key, left_value), Dict (right_key, right_value) ->
      equal_ty left_key right_key &&
      (match left_value, right_value with
       | ClosureEnv [], _
       | _, ClosureEnv [] -> true
       | _ -> equal_ty left_value right_value)
  | Enum (left_name, _), Enum (right_name, _) -> left_name = right_name
  | List left_element, List right_element -> equal_ty left_element right_element
  | Tuple left_elements, Tuple right_elements ->
      List.length left_elements = List.length right_elements &&
      List.for_all2 equal_ty left_elements right_elements
  | Struct (left_name, left_fields), Struct (right_name, right_fields) ->
      left_name = right_name &&
      List.length left_fields = List.length right_fields &&
      List.for_all2 (fun (left_field, left_type) (right_field, right_type) ->
        left_field = right_field && equal_ty left_type right_type
      ) left_fields right_fields
  | Ref left_type, Ref right_type -> equal_ty left_type right_type
  | Union left_elements, Union right_elements ->
      List.length left_elements = List.length right_elements &&
      List.for_all2 equal_ty left_elements right_elements
  | Interface (left_name, left_methods), Interface (right_name, right_methods) ->
      left_name = right_name &&
      List.length left_methods = List.length right_methods &&
      List.for_all2 (fun (left_method, left_parameters, left_return)
          (right_method, right_parameters, right_return) ->
        left_method = right_method &&
        List.length left_parameters = List.length right_parameters &&
        List.for_all2 equal_ty left_parameters right_parameters &&
        equal_ty left_return right_return
      ) left_methods right_methods
  | ClosureEnv left_fields, ClosureEnv right_fields ->
      List.length left_fields = List.length right_fields &&
      List.for_all2 equal_ty left_fields right_fields
  | Func (left_parameters, left_return), Func (right_parameters, right_return) ->
      List.length left_parameters = List.length right_parameters &&
      List.for_all2 equal_ty left_parameters right_parameters &&
      equal_ty left_return right_return
  | _ -> false

let rec ty_to_string = function
  | Unit -> "unit"
  | Bool -> "bool"
  | I32 -> "i32"
  | F64 -> "f64"
  | Str -> "str"
  | Bytes -> "bytes"
  | Dict (key, value) -> "dict<" ^ ty_to_string key ^ ", " ^ ty_to_string value ^ ">"
  | List element -> "list<" ^ ty_to_string element ^ ">"
  | Tuple elements ->
      "(" ^ String.concat ", " (List.map ty_to_string elements) ^ ")"
  | Struct (name, _) -> name
  | Ref type_value -> "ref<" ^ ty_to_string type_value ^ ">"
  | Enum (name, _) -> name
  | Interface (name, _) -> "interface " ^ name
  | Union elements ->
      String.concat " | " (List.map ty_to_string elements)
  | ClosureEnv fields ->
      "closure_env{" ^ String.concat ", " (List.map ty_to_string fields) ^ "}"
  | Func (parameters, return_type) ->
      "(" ^ String.concat ", " (List.map ty_to_string parameters) ^ ") -> " ^
      ty_to_string return_type

let operand_value = function
  | Value value -> Some value
  | Int _ | Float _ | Bool _ | String _ | FunctionRef _ -> None

let instruction_result = function
  | Binop (value, ty, _, _, _) -> Some (value, ty)
  | StringLength (value, _) -> Some (value, I32)
  | StringCompare (value, _, _) -> Some (value, I32)
  | StringSlice (value, _, _, _) -> Some (value, Str)
  | ListLength (value, _) -> Some (value, I32)
  | ListGet (value, _, _) -> Some (value, I32)
  | ListCreate (value, element_type, _) -> Some (value, List element_type)
  | ListSlice (value, _, _, _) -> Some (value, List I32)
  | ListConcat (value, _, _) -> Some (value, List I32)
  | TupleCreate (value, element_types, _) -> Some (value, Tuple element_types)
  | TupleGet (value, element_type, _, _) -> Some (value, element_type)
  | StructCreate (value, name, fields, _) -> Some (value, Struct (name, fields))
  | StructGet (value, field_type, _, _) -> Some (value, field_type)
  | Alloca (value, type_value) -> Some (value, Ref type_value)
  | Load (value, type_value, _) -> Some (value, type_value)
  | EnumCreate (value, enum_type, _, _, _) -> Some (value, enum_type)
  | EnumCreateMulti (value, enum_type, _, _, _) -> Some (value, enum_type)
  | EnumCreateSimple (value, enum_type, _) -> Some (value, enum_type)
  | EnumTag (value, _) -> Some (value, I32)
  | EnumGet (value, field_type, _, _) -> Some (value, field_type)
  | EnumGetMulti (value, field_type, _, _, _, _) -> Some (value, field_type)
  | MakeClosure (value, closure_type, _, _, _) -> Some (value, closure_type)
  | ClosureGet (value, field_type, _, _, _) -> Some (value, field_type)
  | InterfaceBox (value, concrete_type, _) -> Some (value, concrete_type)
  | MakeInterface (value, interface_type, _, _, _) -> Some (value, interface_type)
  | InterfaceCall (Some value, result_type, _, _, _, _, _, _) -> Some (value, result_type)
  | InterfaceTypeTag (value, _) -> Some (value, I32)
  | Compare (value, _, _, _) -> Some (value, Bool)
  | Call (Some value, ty, _, _, _) -> Some (value, ty)
  | CallIndirect (Some value, ty, _, _, _) -> Some (value, ty)
  | GlobalLoad (value, ty, _) -> Some (value, ty)
  | Call (None, _, _, _, _)
  | CallIndirect (None, _, _, _, _)
  | InterfaceCall (None, _, _, _, _, _, _, _)
  | InterfaceRelease _
  | StructSet _
  | Store _
  | ListAppend _
  | ListSet _
  | GlobalStore _ -> None

let instruction_operands = function
  | Binop (_, _, _, left, right)
  | Compare (_, _, left, right)
  | StringCompare (_, left, right) -> [left; right]
  | Call (_, _, _, _, arguments) -> arguments
  | CallIndirect (_, _, _, callee, arguments) -> callee :: arguments
  | MakeClosure (_, _, _, _, captures) -> captures
  | ClosureGet (_, _, _, environment, _) -> [environment]
  | InterfaceBox (_, _, object_value) -> [object_value]
  | MakeInterface (_, _, _, object_value, _) -> [object_value]
  | InterfaceRelease box_value -> [box_value]
  | InterfaceTypeTag (_, interface_value) -> [interface_value]
  | InterfaceCall (_, _, _, interface_value, _, _, _, arguments) ->
      interface_value :: arguments
  | StringLength (_, value)
  | ListLength (_, value) -> [value]
  | StringSlice (_, string_value, start, end_) -> [string_value; start; end_]
  | ListGet (_, collection, index) -> [collection; index]
  | ListCreate (_, _, values) -> values
  | ListSlice (_, collection, start, end_) -> [collection; start; end_]
  | ListConcat (_, left, right) -> [left; right]
  | TupleCreate (_, _, values) -> values
  | TupleGet (_, _, tuple_value, _) -> [tuple_value]
  | StructCreate (_, _, _, values) -> values
  | StructGet (_, _, struct_value, _) -> [struct_value]
  | StructSet (_, struct_value, _, _, field_value) -> [struct_value; field_value]
  | Alloca _ -> []
  | Load (_, _, pointer) -> [pointer]
  | Store (_, stored_value, pointer) -> [stored_value; pointer]
  | EnumCreate (_, _, _, _, payload) -> [payload]
  | EnumCreateMulti (_, _, _, _, payloads) -> payloads
  | EnumCreateSimple _ -> []
  | EnumTag (_, enum_value) -> [enum_value]
  | EnumGet (_, _, enum_value, _) -> [enum_value]
  | EnumGetMulti (_, _, _, enum_value, _, _) -> [enum_value]
  | ListAppend (collection, value, _) -> [collection; value]
  | ListSet (collection, index, value) -> [collection; index; value]
  | GlobalLoad (_, _, _) -> []
  | GlobalStore (_, value) -> [value]

let terminator_operands = function
  | Jump (_, arguments) -> arguments
  | Branch (condition, (_, then_arguments), (_, else_arguments)) ->
      condition :: then_arguments @ else_arguments
  | Switch (value, cases, default_case) ->
      value :: (List.concat_map (fun (case_value, _, arguments) -> case_value :: arguments) cases)
      @ snd default_case
  | Return (Some value) -> [value]
  | Return None
  | Unreachable -> []
