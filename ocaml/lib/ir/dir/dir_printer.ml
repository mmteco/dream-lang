open Dir

let ty = ty_to_string

let operand = function
  | Value value -> Printf.sprintf "%%v%d" value
  | Int value -> string_of_int value
  | Float value -> string_of_float value
  | Bool true -> "true"
  | Bool false -> "false"
  | String value -> Printf.sprintf "%S" value
  | FunctionRef name -> "@" ^ name

let binop = function
  | Add -> "add"
  | Sub -> "sub"
  | Mul -> "mul"
  | Div -> "div"
  | Mod -> "mod"
  | BitAnd -> "bitand"
  | BitOr -> "bitor"
  | BitXor -> "bitxor"
  | Shl -> "shl"
  | Shr -> "shr"
  | And -> "and"
  | Or -> "or"

let cmp = function
  | Eq -> "eq"
  | Ne -> "ne"
  | Lt -> "lt"
  | Gt -> "gt"
  | Le -> "le"
  | Ge -> "ge"

let operand_type value_types = function
  | Value value -> (try Hashtbl.find value_types value with Not_found -> "unknown")
  | Int _ -> "i32"
  | Float _ -> "f64"
  | Bool _ -> "bool"
  | String _ -> "str"
  | FunctionRef _ -> "function"

let instruction value_types = function
  | Binop (value, result_type, operation, left, right) ->
      Printf.sprintf "%%v%d = %s %s %s, %s"
        value (binop operation) (ty result_type) (operand left) (operand right)
  | Compare (value, operation, left, right) ->
      let comparison_type = operand_type value_types left in
      let comparison_instruction = if comparison_type = "f64" then "fcmp" else "icmp" in
      Printf.sprintf "%%v%d = %s %s %s %s, %s"
        value comparison_instruction (cmp operation) comparison_type
        (operand left) (operand right)
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
  | CallIndirect (Some value, result_type, parameter_types, callee, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) parameter_types arguments in
      Printf.sprintf "%%v%d = call_indirect %s %s(%s)"
        value (ty result_type) (operand callee) (String.concat ", " rendered_arguments)
  | CallIndirect (None, result_type, parameter_types, callee, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) parameter_types arguments in
      Printf.sprintf "call_indirect %s %s(%s)"
        (ty result_type) (operand callee) (String.concat ", " rendered_arguments)
  | MakeClosure (value, closure_type, name, capture_types, captures) ->
      let rendered_captures = List.map2 (fun capture_type capture ->
        ty capture_type ^ " " ^ operand capture
      ) capture_types captures in
      Printf.sprintf "%%v%d = make_closure %s @%s(%s)"
        value (ty closure_type) name (String.concat ", " rendered_captures)
  | ClosureGet (value, field_type, environment_type, environment, index) ->
      Printf.sprintf "%%v%d = closure_get %s %s %s %d"
        value (ty field_type) (ty (ClosureEnv environment_type))
        (operand environment) index
  | InterfaceBox (value, concrete_type, object_value) ->
      Printf.sprintf "%%v%d = interface_box %s %s" value (ty concrete_type)
        (operand object_value)
  | InterfaceRelease box_value ->
      Printf.sprintf "interface_release %s" (operand box_value)
  | InterfaceTypeTag (value, interface_value) ->
      Printf.sprintf "%%v%d = interface_type_tag %s" value (operand interface_value)
  | MakeInterface (value, interface_type, concrete_type, object_value, method_names) ->
      Printf.sprintf "%%v%d = make_interface %s %s %s {%s}"
        value (ty interface_type) (ty concrete_type) (operand object_value)
        (String.concat ", " (List.map (fun name -> "@" ^ name) method_names))
  | InterfaceCall (Some value, result_type, interface_type, interface_value,
                   method_name, method_index, parameter_types, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) parameter_types arguments in
      Printf.sprintf "%%v%d = interface_call %s %s %s @%s %d(%s)"
        value (ty result_type) (ty interface_type) (operand interface_value)
        method_name method_index (String.concat ", " rendered_arguments)
  | InterfaceCall (None, result_type, interface_type, interface_value,
                   method_name, method_index, parameter_types, arguments) ->
      let rendered_arguments = List.map2 (fun argument_type argument ->
        ty argument_type ^ " " ^ operand argument
      ) parameter_types arguments in
      Printf.sprintf "interface_call %s %s %s @%s %d(%s)"
        (ty result_type) (ty interface_type) (operand interface_value)
        method_name method_index (String.concat ", " rendered_arguments)
  | EnumCreateMulti (value, enum_type, tag, payload_types, payloads) ->
      let rendered_payloads = List.map2 (fun payload_type payload ->
        ty payload_type ^ " " ^ operand payload
      ) payload_types payloads in
      Printf.sprintf "%%v%d = enum_create_multi %s %d (%s)"
        value (ty enum_type) tag (String.concat ", " rendered_payloads)
  | EnumGetMulti (value, field_type, payload_types, enum_value, tag, index) ->
      Printf.sprintf "%%v%d = enum_get_multi %s (%s) %s %d %d"
        value (ty field_type) (String.concat ", " (List.map ty payload_types))
        (operand enum_value) tag index
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
  | StructCreate (value, name, fields, values) ->
      Printf.sprintf "%%v%d = struct_create %s {%s} [%s]" value name
        (String.concat ", " (List.map (fun (field_name, field_type) ->
          field_name ^ ": " ^ ty field_type) fields))
        (String.concat ", " (List.map operand values))
  | StructGet (value, field_type, struct_value, index) ->
      Printf.sprintf "%%v%d = struct_get %s %d %s" value
        (ty field_type) index (operand struct_value)
  | EnumCreate (value, enum_type, tag, payload_type, payload) ->
      Printf.sprintf "%%v%d = enum_create %s %d %s %s" value
        (ty enum_type) tag (ty payload_type) (operand payload)
  | EnumCreateSimple (value, enum_type, tag) ->
      Printf.sprintf "%%v%d = enum_create_simple %s %d" value (ty enum_type) tag
  | EnumTag (value, enum_value) ->
      Printf.sprintf "%%v%d = enum_tag %s" value (operand enum_value)
  | EnumGet (value, field_type, enum_value, tag) ->
      Printf.sprintf "%%v%d = enum_get %s %d %s" value
        (ty field_type) tag (operand enum_value)
  | ListAppend (collection, value) ->
      Printf.sprintf "list_append %s, %s" (operand collection) (operand value)
  | ListSet (collection, index, value) ->
      Printf.sprintf "list_set %s, %s, %s" (operand collection)
        (operand index) (operand value)
  | GlobalLoad (value, result_type, name) ->
      Printf.sprintf "%%v%d = global_load %s @%s" value (ty result_type) name
  | GlobalStore (name, value) ->
      Printf.sprintf "global_store @%s, %s" name (operand value)

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
  let value_types = Hashtbl.create 32 in
  List.iter (fun parameter -> Hashtbl.replace value_types parameter.value (ty parameter.ty))
    function_def.parameters;
  List.iter (fun block ->
    List.iter (fun (value, parameter_type) ->
      Hashtbl.replace value_types value (ty parameter_type)
    ) block.params;
    List.iter (fun item ->
      match instruction_result item with
      | Some (value, result_type) -> Hashtbl.replace value_types value (ty result_type)
      | None -> ()
    ) block.instructions
  ) function_def.blocks;
  Printf.bprintf buffer "func @%s(%s) -> %s {\n"
    function_def.name (String.concat ", " parameters) (ty function_def.return_type);
  List.iter (fun block ->
    let parameters = List.map (fun (value, parameter_type) ->
      Printf.sprintf "%%v%d %s" value (ty parameter_type)
    ) block.params in
    Printf.bprintf buffer "  %s(%s):\n" block.label (String.concat ", " parameters);
    List.iter (fun item -> Printf.bprintf buffer "    %s\n" (instruction value_types item)) block.instructions;
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
