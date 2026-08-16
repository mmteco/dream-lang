open Dir

let ty = ty_to_string

let operand = function
  | Value value -> Printf.sprintf "%%v%d" value
  | Int value -> string_of_int value
  | Bool true -> "true"
  | Bool false -> "false"
  | String value -> Printf.sprintf "%S" value

let binop = function
  | Add -> "add"
  | Sub -> "sub"
  | Mul -> "mul"
  | Div -> "div"
  | Mod -> "mod"
  | And -> "and"
  | Or -> "or"

let cmp = function
  | Eq -> "eq"
  | Ne -> "ne"
  | Lt -> "lt"
  | Gt -> "gt"
  | Le -> "le"
  | Ge -> "ge"

let instruction = function
  | Binop (value, result_type, operation, left, right) ->
      Printf.sprintf "%%v%d = %s %s %s, %s"
        value (binop operation) (ty result_type) (operand left) (operand right)
  | Compare (value, operation, left, right) ->
      Printf.sprintf "%%v%d = icmp %s %s, %s"
        value (cmp operation) (operand left) (operand right)
  | Call (Some value, result_type, name, argument_types, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) argument_types arguments in
      Printf.sprintf "%%v%d = call %s @%s(%s)"
        value (ty result_type) name (String.concat ", " rendered_arguments)
  | Call (None, result_type, name, argument_types, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) argument_types arguments in
      Printf.sprintf "call %s @%s(%s)"
        (ty result_type) name (String.concat ", " rendered_arguments)
  | StringLength (value, string_value) ->
      Printf.sprintf "%%v%d = string_length %s" value (operand string_value)
  | StringCompare (value, left, right) ->
      Printf.sprintf "%%v%d = string_compare %s, %s" value (operand left) (operand right)
  | StringSlice (value, string_value, start, end_) ->
      Printf.sprintf "%%v%d = string_slice %s, %s, %s" value
        (operand string_value) (operand start) (operand end_)
  | ListLength (value, collection) ->
      Printf.sprintf "%%v%d = list_length %s" value (operand collection)
  | ListGet (value, collection, index) ->
      Printf.sprintf "%%v%d = list_get %s, %s" value (operand collection) (operand index)
  | ListCreate (value, element_type, values) ->
      Printf.sprintf "%%v%d = list_create %s [%s]" value (ty element_type)
        (String.concat ", " (List.map operand values))
  | ListSlice (value, collection, start, end_) ->
      Printf.sprintf "%%v%d = list_slice %s, %s, %s" value
        (operand collection) (operand start) (operand end_)
  | ListConcat (value, left, right) ->
      Printf.sprintf "%%v%d = list_concat %s, %s" value (operand left) (operand right)
  | TupleCreate (value, element_types, values) ->
      Printf.sprintf "%%v%d = tuple_create (%s) [%s]" value
        (String.concat ", " (List.map ty element_types))
        (String.concat ", " (List.map operand values))
  | TupleGet (value, element_type, tuple_value, index) ->
      Printf.sprintf "%%v%d = tuple_get %s %d %s" value
        (ty element_type) index (operand tuple_value)
  | ListAppend (collection, value) ->
      Printf.sprintf "list_append %s, %s" (operand collection) (operand value)
  | ListSet (collection, index, value) ->
      Printf.sprintf "list_set %s, %s, %s" (operand collection)
        (operand index) (operand value)

let terminator = function
  | Jump (label, arguments) ->
      Printf.sprintf "jump %s(%s)" label (String.concat ", " (List.map operand arguments))
  | Branch (condition, (then_label, then_arguments), (else_label, else_arguments)) ->
      Printf.sprintf "branch %s, %s(%s), %s(%s)"
        (operand condition)
        then_label (String.concat ", " (List.map operand then_arguments))
        else_label (String.concat ", " (List.map operand else_arguments))
  | Switch (value, cases, (default_label, default_arguments)) ->
      let render_case (case_value, label, arguments) =
        Printf.sprintf "%s -> %s(%s)" (operand case_value) label
          (String.concat ", " (List.map operand arguments))
      in
      Printf.sprintf "switch %s {%s; default -> %s(%s)}"
        (operand value)
        (String.concat "; " (List.map render_case cases))
        default_label (String.concat ", " (List.map operand default_arguments))
  | Return None -> "return"
  | Return (Some value) -> "return " ^ operand value
  | Unreachable -> "unreachable"

let render_function (function_def : Dir.function_def) =
  let parameters = List.map (fun parameter ->
    Printf.sprintf "%%v%d %s" parameter.value (ty parameter.ty)
  ) function_def.parameters in
  let buffer = Buffer.create 512 in
  Printf.bprintf buffer "func @%s(%s) -> %s {\n"
    function_def.name (String.concat ", " parameters) (ty function_def.return_type);
  List.iter (fun block ->
    let parameters = List.map (fun (value, parameter_type) ->
      Printf.sprintf "%%v%d %s" value (ty parameter_type)
    ) block.params in
    Printf.bprintf buffer "  %s(%s):\n" block.label (String.concat ", " parameters);
    List.iter (fun item -> Printf.bprintf buffer "    %s\n" (instruction item)) block.instructions;
    Printf.bprintf buffer "    %s\n" (terminator block.terminator)
  ) function_def.blocks;
  Buffer.add_string buffer "}\n";
  Buffer.contents buffer

let render module_ =
  let buffer = Buffer.create 1024 in
  Printf.bprintf buffer "module %s\n\n" module_.name;
  List.iter (fun (declaration : Dir.extern) ->
    Printf.bprintf buffer "extern @%s(%s) -> %s\n"
      declaration.name
      (String.concat ", " (List.map ty declaration.parameters))
      (ty declaration.return_type)
  ) module_.externs;
  if module_.externs <> [] then Buffer.add_char buffer '\n';
  List.iter (fun function_def ->
    Buffer.add_string buffer (render_function function_def);
    Buffer.add_char buffer '\n'
  ) module_.functions;
  Buffer.contents buffer
