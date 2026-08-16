type ty =
  | Unit
  | Bool
  | I32
  | Str
  | List of ty
  | Tuple of ty list

type value = int

type operand =
  | Value of value
  | Int of int
  | Bool of bool
  | String of string

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
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
  | ListAppend of operand * operand
  | ListSet of operand * operand * operand

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
  functions: function_def list;
}

let rec equal_ty left right =
  match left, right with
  | Unit, Unit
  | Bool, Bool
  | I32, I32
  | Str, Str -> true
  | List left_element, List right_element -> equal_ty left_element right_element
  | Tuple left_elements, Tuple right_elements ->
      List.length left_elements = List.length right_elements &&
      List.for_all2 equal_ty left_elements right_elements
  | _ -> false

let rec ty_to_string = function
  | Unit -> "unit"
  | Bool -> "bool"
  | I32 -> "i32"
  | Str -> "str"
  | List element -> "list<" ^ ty_to_string element ^ ">"
  | Tuple elements ->
      "(" ^ String.concat ", " (List.map ty_to_string elements) ^ ")"

let operand_value = function
  | Value value -> Some value
  | Int _ | Bool _ | String _ -> None

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
  | Compare (value, _, _, _) -> Some (value, Bool)
  | Call (Some value, ty, _, _, _) -> Some (value, ty)
  | Call (None, _, _, _, _)
  | ListAppend _
  | ListSet _ -> None

let instruction_operands = function
  | Binop (_, _, _, left, right)
  | Compare (_, _, left, right)
  | StringCompare (_, left, right) -> [left; right]
  | Call (_, _, _, _, arguments) -> arguments
  | StringLength (_, value)
  | ListLength (_, value) -> [value]
  | StringSlice (_, string_value, start, end_) -> [string_value; start; end_]
  | ListGet (_, collection, index) -> [collection; index]
  | ListCreate (_, _, values) -> values
  | ListSlice (_, collection, start, end_) -> [collection; start; end_]
  | ListConcat (_, left, right) -> [left; right]
  | TupleCreate (_, _, values) -> values
  | TupleGet (_, _, tuple_value, _) -> [tuple_value]
  | ListAppend (collection, value) -> [collection; value]
  | ListSet (collection, index, value) -> [collection; index; value]

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
