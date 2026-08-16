open Dir

let llvm_ty = function
  | Unit -> "void"
  | Bool -> "i1"
  | I32 -> "i32"
  | Str -> "i8*"
  | List I32 -> "%dynarray_i32*"
  | Tuple _ -> "%dynarray_i32*"
  | List _ -> failwith "DIR LLVM lowering only supports list<i32>"

let value_name value = Printf.sprintf "%%v%d" value

let escape_string value =
  let buffer = Buffer.create (String.length value * 2) in
  String.iter (fun character ->
    let code = Char.code character in
    if code >= 32 && code <= 126 && character <> '"' && character <> '\\' then
      Buffer.add_char buffer character
    else
      Printf.bprintf buffer "\\%02X" code
  ) value;
  Buffer.contents buffer

let render_operand string_literals = function
  | Value value -> value_name value
  | Int value -> string_of_int value
  | Bool true -> "1"
  | Bool false -> "0"
  | String value ->
      let global_name = List.assoc value string_literals in
      let length = String.length value + 1 in
      Printf.sprintf "getelementptr inbounds ([%d x i8], [%d x i8]* %s, i32 0, i32 0)"
        length length global_name

let render_binop = function
  | Add -> "add"
  | Sub -> "sub"
  | Mul -> "mul"
  | Div -> "sdiv"
  | Mod -> "srem"
  | And -> "and"
  | Or -> "or"

let render_cmp = function
  | Eq -> "eq"
  | Ne -> "ne"
  | Lt -> "slt"
  | Gt -> "sgt"
  | Le -> "sle"
  | Ge -> "sge"

let operand_type value_types = function
  | Value value -> Hashtbl.find value_types value
  | Int _ -> I32
  | Bool _ -> Bool
  | String _ -> Str

let render_instruction string_literals value_types buffer instruction =
  let operand = render_operand string_literals in
  (match instruction with
   | Binop (value, result_type, operation, left, right) ->
       Printf.bprintf buffer "  %s = %s %s %s, %s\n"
         (value_name value) (render_binop operation) (llvm_ty result_type)
         (operand left) (operand right)
   | Compare (value, operation, left, right) ->
       let comparison_type = llvm_ty (operand_type value_types left) in
       Printf.bprintf buffer "  %s = icmp %s %s %s, %s\n"
         (value_name value) (render_cmp operation) comparison_type
         (operand left) (operand right)
   | Call (Some value, result_type, name, argument_types, arguments) ->
       let rendered_arguments = String.concat ", " (List.map2 (fun argument_type argument ->
         Printf.sprintf "%s %s" (llvm_ty argument_type) (operand argument)
       ) argument_types arguments) in
       Printf.bprintf buffer "  %s = call %s @%s(%s)\n"
         (value_name value) (llvm_ty result_type) name rendered_arguments
   | Call (None, result_type, name, argument_types, arguments) ->
       let rendered_arguments = String.concat ", " (List.map2 (fun argument_type argument ->
         Printf.sprintf "%s %s" (llvm_ty argument_type) (operand argument)
       ) argument_types arguments) in
       Printf.bprintf buffer "  call %s @%s(%s)\n"
         (llvm_ty result_type) name rendered_arguments
   | StringLength (value, string_value) ->
       Printf.bprintf buffer "  %s = call i32 @string_length(i8* %s)\n"
         (value_name value) (operand string_value)
   | StringCompare (value, left, right) ->
       Printf.bprintf buffer "  %s = call i32 @string_compare(i8* %s, i8* %s)\n"
         (value_name value) (operand left) (operand right)
   | StringSlice (value, string_value, start, end_) ->
       Printf.bprintf buffer "  %s = call i8* @string_substring(i8* %s, i32 %s, i32 %s)\n"
         (value_name value) (operand string_value) (operand start) (operand end_)
   | ListLength (value, collection) ->
       Printf.bprintf buffer "  %s = call i32 @len_dynarray_i32(%%dynarray_i32* %s)\n"
         (value_name value) (operand collection)
   | ListGet (value, collection, index) ->
       Printf.bprintf buffer "  %s = call i32 @get_dynarray_i32(%%dynarray_i32* %s, i32 %s)\n"
         (value_name value) (operand collection) (operand index)
   | ListCreate (value, _, values) ->
       Printf.bprintf buffer "  %s = call %%dynarray_i32* @create_dynarray_i32(i32 %d)\n"
         (value_name value) (List.length values);
       List.iter (fun item ->
         Printf.bprintf buffer "  call void @append_i32(%%dynarray_i32* %s, i32 %s)\n"
           (value_name value) (operand item)
       ) values
   | ListSlice (value, collection, start, end_) ->
       Printf.bprintf buffer "  %s = call %%dynarray_i32* @slice_dynarray_i32(%%dynarray_i32* %s, i32 %s, i32 %s)\n"
         (value_name value) (operand collection) (operand start) (operand end_)
   | ListConcat (value, left, right) ->
       Printf.bprintf buffer "  %s = call %%dynarray_i32* @concat_dynarray_i32(%%dynarray_i32* %s, %%dynarray_i32* %s)\n"
         (value_name value) (operand left) (operand right)
   | TupleCreate (value, _, values) ->
       Printf.bprintf buffer "  %s = call %%dynarray_i32* @create_dynarray_i32(i32 %d)\n"
         (value_name value) (List.length values);
       List.iter (fun item ->
         Printf.bprintf buffer "  call void @append_i32(%%dynarray_i32* %s, i32 %s)\n"
           (value_name value) (operand item)
       ) values
   | TupleGet (value, _, tuple_value, index) ->
       Printf.bprintf buffer "  %s = call i32 @get_dynarray_i32(%%dynarray_i32* %s, i32 %d)\n"
         (value_name value) (operand tuple_value) index
   | ListAppend (collection, value) ->
       Printf.bprintf buffer "  call void @append_i32(%%dynarray_i32* %s, i32 %s)\n"
         (operand collection) (operand value)
   | ListSet (collection, index, value) ->
       Printf.bprintf buffer "  call void @set_dynarray_i32(%%dynarray_i32* %s, i32 %s, i32 %s)\n"
         (operand collection) (operand index) (operand value));
  match instruction_result instruction with
  | Some (value, result_type) -> Hashtbl.replace value_types value result_type
  | None -> ()

let incoming_for target_label blocks =
  List.concat_map (fun block ->
    match block.terminator with
    | Jump (label, arguments) when label = target_label ->
        [(block.label, arguments)]
    | Branch (_, (then_label, then_arguments), (else_label, else_arguments)) ->
        let then_incoming = if then_label = target_label then
          [(block.label, then_arguments)] else [] in
        let else_incoming = if else_label = target_label then
          [(block.label, else_arguments)] else [] in
        then_incoming @ else_incoming
    | Switch (_, cases, (default_label, default_arguments)) ->
        let case_incoming = List.filter_map (fun (_, label, arguments) ->
          if label = target_label then Some (block.label, arguments) else None
        ) cases in
        let default_incoming = if default_label = target_label then
          [(block.label, default_arguments)] else [] in
        case_incoming @ default_incoming
    | Jump _
    | Return _
    | Unreachable -> []
  ) blocks

let render_terminator string_literals return_type buffer = function
  | Jump (label, _) -> Printf.bprintf buffer "  br label %%%s\n" label
  | Branch (condition, (then_label, _), (else_label, _)) ->
      Printf.bprintf buffer "  br i1 %s, label %%%s, label %%%s\n"
        (render_operand string_literals condition) then_label else_label
  | Switch (value, cases, (default_label, _)) ->
      Printf.bprintf buffer "  switch i32 %s, label %%%s [\n"
        (render_operand string_literals value) default_label;
      List.iter (fun (case_value, label, _) ->
        Printf.bprintf buffer "    i32 %s, label %%%s\n"
          (render_operand string_literals case_value) label
      ) cases;
      Buffer.add_string buffer "  ]\n"
  | Return None -> Buffer.add_string buffer "  ret void\n"
  | Return (Some value) ->
      Printf.bprintf buffer "  ret %s %s\n"
        (llvm_ty return_type) (render_operand string_literals value)
  | Unreachable -> Buffer.add_string buffer "  unreachable\n"

let render_function string_literals (function_def : Dir.function_def) =
  let value_types = Hashtbl.create 64 in
  let parameters = String.concat ", " (List.map (fun parameter ->
    Hashtbl.add value_types parameter.value parameter.ty;
    Printf.sprintf "%s %s" (llvm_ty parameter.ty) (value_name parameter.value)
  ) function_def.parameters) in
  List.iter (fun block ->
    List.iter (fun (value, parameter_type) ->
      Hashtbl.replace value_types value parameter_type
    ) block.params
  ) function_def.blocks;
  let buffer = Buffer.create 512 in
  Printf.bprintf buffer "define %s @%s(%s) {\n"
    (llvm_ty function_def.return_type) function_def.name parameters;
  List.iter (fun block ->
    Printf.bprintf buffer "%s:\n" block.label;
    let incoming = incoming_for block.label function_def.blocks in
    List.iter (fun (value, parameter_type) ->
      let incoming_values = List.map (fun (predecessor, arguments) ->
        let index = List.find_index (fun (candidate, _) -> candidate = value) block.params in
        let argument = match index with
          | Some index -> List.nth arguments index
          | None -> failwith "DIR block parameter is missing"
        in
        Printf.sprintf "[ %s, %%%s ]"
          (render_operand string_literals argument) predecessor
      ) incoming in
      if incoming_values <> [] then
        Printf.bprintf buffer "  %s = phi %s %s\n"
          (value_name value) (llvm_ty parameter_type)
          (String.concat ", " incoming_values)
    ) block.params;
    List.iter (render_instruction string_literals value_types buffer) block.instructions;
    render_terminator string_literals function_def.return_type buffer block.terminator
  ) function_def.blocks;
  Buffer.add_string buffer "}\n";
  Buffer.contents buffer

let string_operands module_ =
  let add_operand strings = function
    | String value when not (List.mem value strings) -> strings @ [value]
    | _ -> strings
  in
  let add_instruction strings instruction =
    List.fold_left add_operand strings (instruction_operands instruction)
  in
  let add_block strings block =
    let strings = List.fold_left add_instruction strings block.instructions in
    List.fold_left add_operand strings (terminator_operands block.terminator)
  in
  List.fold_left (fun strings function_def ->
    List.fold_left add_block strings function_def.blocks
  ) [] module_.functions

let render_string_literal (value, global_name) =
  let length = String.length value + 1 in
  Printf.sprintf "%s = private unnamed_addr constant [%d x i8] c\"%s\\00\"\n"
    global_name length (escape_string value)

let render module_ =
  let literals = List.mapi (fun index value ->
    (value, Printf.sprintf "@.dir_str%d" index)
  ) (string_operands module_) in
  let buffer = Buffer.create 2048 in
  Buffer.add_string buffer "; DreamIR lowered LLVM\n";
  Buffer.add_string buffer "%dynarray_i32 = type { i32, i32, i32* }\n";
  List.iter (fun literal ->
    Buffer.add_string buffer (render_string_literal literal)
  ) literals;
  if literals <> [] then Buffer.add_char buffer '\n';
  List.iter (fun declaration ->
    Printf.bprintf buffer "declare %s @%s(%s)\n"
      (llvm_ty declaration.return_type) declaration.name
      (String.concat ", " (List.map llvm_ty declaration.parameters))
  ) module_.externs;
  if module_.externs <> [] then Buffer.add_char buffer '\n';
  Buffer.add_string buffer "declare %dynarray_i32* @create_dynarray_i32(i32)\n";
  Buffer.add_string buffer "declare void @append_i32(%dynarray_i32*, i32)\n";
  Buffer.add_string buffer "declare void @set_dynarray_i32(%dynarray_i32*, i32, i32)\n";
  Buffer.add_string buffer "declare i32 @len_dynarray_i32(%dynarray_i32*)\n";
  Buffer.add_string buffer "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n";
  Buffer.add_string buffer "declare %dynarray_i32* @slice_dynarray_i32(%dynarray_i32*, i32, i32)\n";
  Buffer.add_string buffer "declare %dynarray_i32* @concat_dynarray_i32(%dynarray_i32*, %dynarray_i32*)\n\n";
  Buffer.add_string buffer "declare i8* @string_substring(i8*, i32, i32)\n";
  Buffer.add_string buffer "declare i32 @string_length(i8*)\n";
  Buffer.add_string buffer "declare i32 @string_compare(i8*, i8*)\n";
  List.iter (fun function_def ->
    Buffer.add_string buffer (render_function literals function_def);
    Buffer.add_char buffer '\n'
  ) module_.functions;
  Buffer.contents buffer
