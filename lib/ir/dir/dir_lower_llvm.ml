open Dir

let rec llvm_ty = function
  | Unit -> "void"
  | Bool -> "i1"
  | I32 -> "i32"
  | F64 -> "double"
  | Str -> "i8*"
  | Bytes -> "%dynarray_i32*"
  | Dict _ -> "%dict_t*"
  | List I32 -> "%dynarray_i32*"
  | Tuple _ -> "%dynarray_i32*"
  | Struct (_, fields) ->
      "{" ^ String.concat ", " (List.map (fun (_, field_type) -> llvm_ty field_type) fields) ^ "}"
  | Enum (_, variants) when List.exists (fun (_, payload_types) -> payload_types <> []) variants ->
      "%enum_t*"
  | Enum _ -> "i32"
  | ClosureEnv _ -> "i8*"
  | Func _ -> "%dir_closure*"
  | List _ -> failwith "DIR LLVM lowering only supports list<i32>"

and llvm_function_ty parameter_types return_type =
  Printf.sprintf "%s (%s)" (llvm_ty return_type)
    (String.concat ", " ("i8*" :: List.map llvm_ty parameter_types))

let llvm_env_value_ty field_types =
  "{" ^ String.concat ", " (List.map llvm_ty field_types) ^ "}"

let align_to alignment size =
  ((size + alignment - 1) / alignment) * alignment

let rec llvm_size (type_value : ty) = match type_value with
  | Bool -> 1
  | I32 -> 4
  | F64 -> 8
  | Unit -> 0
  | Str | Bytes | Dict _ | List _ | Tuple _ | Enum _ | ClosureEnv _ | Func _ -> 8
  | Struct (_, fields) ->
      let _, size = List.fold_left (fun (offset, maximum) (_, field_type) ->
        let field_size = llvm_size field_type in
        let field_alignment = min 8 (max 1 field_size) in
        let aligned_offset = align_to field_alignment offset in
        aligned_offset + field_size, max maximum field_alignment
      ) (0, 1) fields in
      align_to size (List.fold_left (fun offset (_, field_type) ->
        offset + llvm_size field_type
      ) 0 fields)

let llvm_env_size field_types =
  llvm_size (Struct ("closure_env", List.mapi (fun index field_type ->
    Printf.sprintf "field_%d" index, field_type
  ) field_types))

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
  | Float value -> Printf.sprintf "0x%016LX" (Int64.bits_of_float value)
  | Bool true -> "1"
  | Bool false -> "0"
  | String value ->
      let global_name = List.assoc value string_literals in
      let length = String.length value + 1 in
      Printf.sprintf "getelementptr inbounds ([%d x i8], [%d x i8]* %s, i32 0, i32 0)"
        length length global_name
  | FunctionRef name -> "@" ^ name

let render_binop result_type = function
  | Add -> if equal_ty result_type F64 then "fadd" else "add"
  | Sub -> if equal_ty result_type F64 then "fsub" else "sub"
  | Mul -> if equal_ty result_type F64 then "fmul" else "mul"
  | Div -> if equal_ty result_type F64 then "fdiv" else "sdiv"
  | Mod -> if equal_ty result_type F64 then "frem" else "srem"
  | And -> "and"
  | Or -> "or"

let render_cmp = function
  | Eq -> "eq"
  | Ne -> "ne"
  | Lt -> "slt"
  | Gt -> "sgt"
  | Le -> "sle"
  | Ge -> "sge"

let render_float_cmp = function
  | Eq -> "oeq"
  | Ne -> "one"
  | Lt -> "olt"
  | Gt -> "ogt"
  | Le -> "ole"
  | Ge -> "oge"

let operand_type value_types = function
  | Value value -> Hashtbl.find value_types value
  | Int _ -> I32
  | Float _ -> F64
  | Bool _ -> Bool
  | String _ -> Str
  | FunctionRef _ -> failwith "function references are not comparable"

let render_indirect_call string_literals buffer result_value result_type
    parameter_types callee arguments =
  let operand = render_operand string_literals in
  let call_id = match result_value with
    | Some value -> value
    | None -> abs (Hashtbl.hash (callee, arguments))
  in
  let invoke_slot = Printf.sprintf "%%dir_invoke_slot_%d" call_id in
  let invoke_raw = Printf.sprintf "%%dir_invoke_raw_%d" call_id in
  let invoke = Printf.sprintf "%%dir_invoke_%d" call_id in
  let environment_slot = Printf.sprintf "%%dir_environment_slot_%d" call_id in
  let environment = Printf.sprintf "%%dir_environment_%d" call_id in
  let invoke_type = llvm_function_ty parameter_types result_type in
  Printf.bprintf buffer "  %s = getelementptr %%dir_closure, %%dir_closure* %s, i32 0, i32 0\n"
    invoke_slot (operand callee);
  Printf.bprintf buffer "  %s = load i8*, i8** %s\n" invoke_raw invoke_slot;
  Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n" invoke invoke_raw invoke_type;
  Printf.bprintf buffer "  %s = getelementptr %%dir_closure, %%dir_closure* %s, i32 0, i32 1\n"
    environment_slot (operand callee);
  Printf.bprintf buffer "  %s = load i8*, i8** %s\n" environment environment_slot;
  let rendered_arguments = String.concat ", " (List.map2 (fun argument_type argument ->
    Printf.sprintf "%s %s" (llvm_ty argument_type) (operand argument)
  ) parameter_types arguments) in
  let call_arguments = if rendered_arguments = "" then
    "i8* " ^ environment
  else
    "i8* " ^ environment ^ ", " ^ rendered_arguments
  in
  match result_value with
  | Some value ->
      Printf.bprintf buffer "  %s = call %s %s(%s)\n"
        (value_name value) (llvm_ty result_type) invoke call_arguments
  | None ->
      Printf.bprintf buffer "  call %s %s(%s)\n"
        (llvm_ty result_type) invoke call_arguments

let render_instruction string_literals value_types buffer instruction =
  let operand = render_operand string_literals in
  (match instruction with
   | Binop (value, result_type, operation, left, right) ->
       Printf.bprintf buffer "  %s = %s %s %s, %s\n"
         (value_name value) (render_binop result_type operation) (llvm_ty result_type)
         (operand left) (operand right)
   | Compare (value, operation, left, right) ->
       let operand_type = operand_type value_types left in
       let comparison_instruction, comparison_name =
         if equal_ty operand_type F64 then "fcmp", render_float_cmp operation
         else "icmp", render_cmp operation
       in
       Printf.bprintf buffer "  %s = %s %s %s %s, %s\n"
         (value_name value) comparison_instruction comparison_name
         (llvm_ty operand_type) (operand left) (operand right)
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
   | CallIndirect (result_value, result_type, parameter_types, callee, arguments) ->
       render_indirect_call string_literals buffer result_value result_type
         parameter_types callee arguments
   | MakeClosure (value, Func (parameter_types, return_type), name, capture_types, captures) ->
       let environment_type = llvm_env_value_ty capture_types in
       let environment = Printf.sprintf "%%dir_environment_%d" value in
       if capture_types = [] then
         Printf.bprintf buffer "  %s = call %%dir_closure* @dream_closure_create(i8* bitcast (%s* @%s to i8*), i8* null)\n"
           (value_name value) (llvm_function_ty parameter_types return_type) name
       else begin
         Printf.bprintf buffer "  %s = call i8* @dream_closure_alloc(i64 %d)\n"
           environment (llvm_env_size capture_types);
         let typed_environment = environment ^ "_typed" in
         Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
           typed_environment environment environment_type;
         List.iteri (fun index (capture_type, capture) ->
           let field_pointer = Printf.sprintf "%%dir_capture_slot_%d_%d" value index in
           Printf.bprintf buffer "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
             field_pointer environment_type environment_type typed_environment index;
           Printf.bprintf buffer "  store %s %s, %s* %s\n"
             (llvm_ty capture_type) (operand capture) (llvm_ty capture_type) field_pointer
         ) (List.combine capture_types captures);
         Printf.bprintf buffer "  %s = call %%dir_closure* @dream_closure_create(i8* bitcast (%s* @%s to i8*), i8* %s)\n"
           (value_name value) (llvm_function_ty parameter_types return_type) name environment
       end
   | MakeClosure _ -> failwith "invalid DIR closure type"
   | ClosureGet (value, field_type, environment_types, environment_operand, index) ->
       let environment_type = llvm_env_value_ty environment_types in
       let typed_environment = Printf.sprintf "%%dir_environment_get_%d" value in
       let field_pointer = Printf.sprintf "%%dir_environment_field_%d" value in
       Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
         typed_environment (operand environment_operand) environment_type;
       Printf.bprintf buffer "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
         field_pointer environment_type environment_type typed_environment index;
       Printf.bprintf buffer "  %s = load %s, %s* %s\n"
         (value_name value) (llvm_ty field_type) (llvm_ty field_type) field_pointer
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
   | StructCreate (value, name, fields, values) ->
       (match fields, values with
        | [], _ -> failwith ("DIR cannot lower empty struct " ^ name)
        | (_, first_type) :: _, first_value :: rest_values ->
            let struct_type = Struct (name, fields) in
            let temporary_name index = Printf.sprintf "%%dir_struct_%d_%d" value index in
            let first_result = if rest_values = [] then value_name value else temporary_name 0 in
            Printf.bprintf buffer "  %s = insertvalue %s undef, %s %s, 0\n"
              first_result (llvm_ty struct_type) (llvm_ty first_type)
              (operand first_value);
            List.iteri (fun index item ->
              let field_type = snd (List.nth fields (index + 1)) in
              let result_name = if index + 1 = List.length fields - 1 then
                value_name value else temporary_name (index + 1) in
              let aggregate_name = if index = 0 then first_result
                else temporary_name index in
              Printf.bprintf buffer "  %s = insertvalue %s %s, %s %s, %d\n"
                result_name (llvm_ty struct_type) aggregate_name
                (llvm_ty field_type) (operand item) (index + 1)
            ) rest_values
        | _ -> failwith "DIR struct field count does not match value count")
   | StructGet (value, _, struct_value, index) ->
       let struct_type = operand_type value_types struct_value in
       Printf.bprintf buffer "  %s = extractvalue %s %s, %d\n"
         (value_name value) (llvm_ty struct_type) (operand struct_value) index
   | EnumCreate (value, enum_type, tag, payload_type, payload) ->
       let create_name = match payload_type with
         | I32 -> "enum_create_int"
         | F64 -> "enum_create_float"
         | Str -> "enum_create_string"
         | Bool -> "enum_create_bool"
         | _ -> failwith "DIR enum payload type is not supported"
       in
       Printf.bprintf buffer "  %s = call %s @%s(i32 %d, %s %s)\n"
         (value_name value) (llvm_ty enum_type) create_name tag
         (llvm_ty payload_type) (operand payload)
   | EnumCreateMulti (value, _enum_type, tag, payload_types, payloads) ->
       let payload_type = llvm_env_value_ty payload_types in
       let payload_pointer = Printf.sprintf "%%dir_enum_payload_%d" value in
       Printf.bprintf buffer "  %s = alloca %s\n" payload_pointer payload_type;
       List.iteri (fun index (field_type, payload) ->
         let field_pointer = Printf.sprintf "%%dir_enum_field_%d_%d" value index in
         Printf.bprintf buffer "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
           field_pointer payload_type payload_type payload_pointer index;
         Printf.bprintf buffer "  store %s %s, %s* %s\n"
           (llvm_ty field_type) (operand payload) (llvm_ty field_type) field_pointer
       ) (List.combine payload_types payloads);
       let payload_bytes = Printf.sprintf "%%dir_enum_payload_bytes_%d" value in
       Printf.bprintf buffer "  %s = bitcast %s* %s to i8*\n"
         payload_bytes payload_type payload_pointer;
       Printf.bprintf buffer "  %s = call %%enum_t* @enum_create_tuple(i32 %d, i8* %s, i64 %d)\n"
         (value_name value) tag payload_bytes (llvm_env_size payload_types)
   | EnumCreateSimple (value, enum_type, tag) ->
       Printf.bprintf buffer "  %s = call %s @enum_create_simple(i32 %d)\n"
         (value_name value) (llvm_ty enum_type) tag
   | EnumTag (value, enum_value) ->
       Printf.bprintf buffer "  %s = call i32 @enum_get_tag(%%enum_t* %s)\n"
         (value_name value) (operand enum_value)
   | EnumGet (value, field_type, enum_value, _) ->
       let getter_name = match field_type with
         | I32 -> "enum_get_int"
         | F64 -> "enum_get_float"
         | Str -> "enum_get_string"
         | Bool -> "enum_get_bool"
         | _ -> failwith "DIR enum payload type is not supported"
       in
       Printf.bprintf buffer "  %s = call %s @%s(%%enum_t* %s)\n"
         (value_name value) (llvm_ty field_type) getter_name (operand enum_value)
   | EnumGetMulti (value, field_type, payload_types, enum_value, _, index) ->
       let payload_type = llvm_env_value_ty payload_types in
       let data_pointer = Printf.sprintf "%%dir_enum_data_%d" value in
       let typed_data = Printf.sprintf "%%dir_enum_typed_data_%d" value in
       let field_pointer = Printf.sprintf "%%dir_enum_field_get_%d" value in
       Printf.bprintf buffer "  %s = call i8* @enum_get_data(%%enum_t* %s)\n"
         data_pointer (operand enum_value);
       Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
         typed_data data_pointer payload_type;
       Printf.bprintf buffer "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
         field_pointer payload_type payload_type typed_data index;
       Printf.bprintf buffer "  %s = load %s, %s* %s\n"
         (value_name value) (llvm_ty field_type) (llvm_ty field_type) field_pointer
   | ListAppend (collection, value) ->
       Printf.bprintf buffer "  call void @append_i32(%%dynarray_i32* %s, i32 %s)\n"
         (operand collection) (operand value)
   | ListSet (collection, index, value) ->
       Printf.bprintf buffer "  call void @set_dynarray_i32(%%dynarray_i32* %s, i32 %s, i32 %s)\n"
         (operand collection) (operand index) (operand value));
  match instruction_result instruction with
  | Some (value, result_type) -> Hashtbl.replace value_types value result_type
  | None -> ()

let switch_chain_label block_label case_index =
  Printf.sprintf "dir_switch_next_%s_%d" block_label case_index

let switch_uses_chain value_types value =
  match operand_type value_types value with
  | I32 -> false
  | Bool | F64 | Str -> true
  | _ -> failwith "DIR switch supports only int, float, bool and str"

let incoming_for value_types target_label blocks =
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
    | Switch (value, cases, (default_label, default_arguments)) ->
        let uses_chain = switch_uses_chain value_types value in
        let case_incoming = List.mapi (fun index (_, label, arguments) ->
          let predecessor = if uses_chain && index > 0 then
            switch_chain_label block.label index
          else block.label in
          if label = target_label then Some (predecessor, arguments) else None
        ) cases |> List.filter_map (fun incoming -> incoming) in
        let default_predecessor = if uses_chain && List.length cases > 1 then
          switch_chain_label block.label (List.length cases - 1)
        else block.label in
        let default_incoming = if default_label = target_label then
          [(default_predecessor, default_arguments)] else [] in
        case_incoming @ default_incoming
    | Jump _
    | Return _
    | Unreachable -> []
  ) blocks

let render_terminator string_literals value_types current_label return_type buffer = function
  | Jump (label, _) -> Printf.bprintf buffer "  br label %%%s\n" label
  | Branch (condition, (then_label, _), (else_label, _)) ->
      Printf.bprintf buffer "  br i1 %s, label %%%s, label %%%s\n"
        (render_operand string_literals condition) then_label else_label
  | Switch (value, cases, (default_label, _)) ->
      (match operand_type value_types value with
       | I32 ->
           Printf.bprintf buffer "  switch i32 %s, label %%%s [\n"
             (render_operand string_literals value) default_label;
           List.iter (fun (case_value, label, _) ->
             Printf.bprintf buffer "    i32 %s, label %%%s\n"
               (render_operand string_literals case_value) label
           ) cases;
           Buffer.add_string buffer "  ]\n"
       | Bool | F64 | Str ->
           let render_condition case_value case_index =
             let condition_name = Printf.sprintf "%%dir_switch_condition_%s_%d"
               current_label case_index in
             let () = match operand_type value_types value with
               | Bool ->
                   Printf.bprintf buffer "  %s = icmp eq i1 %s, %s\n"
                     condition_name (render_operand string_literals value)
                     (render_operand string_literals case_value)
               | F64 ->
                   Printf.bprintf buffer "  %s = fcmp oeq double %s, %s\n"
                     condition_name (render_operand string_literals value)
                     (render_operand string_literals case_value)
               | Str ->
                   let comparison_name = Printf.sprintf
                     "%%dir_switch_string_compare_%s_%d" current_label case_index in
                   Printf.bprintf buffer
                     "  %s = call i32 @string_compare(i8* %s, i8* %s)\n"
                     comparison_name (render_operand string_literals value)
                     (render_operand string_literals case_value);
                   Printf.bprintf buffer "  %s = icmp eq i32 %s, 0\n"
                     condition_name comparison_name
               | _ -> failwith "DIR switch supports only int, float, bool and str" in
             condition_name
           in
           let rec render_cases case_index = function
             | [] -> Printf.bprintf buffer "  br label %%%s\n" default_label
             | (case_value, label, _) :: remaining_cases ->
                 let condition_name = render_condition case_value case_index in
                 let false_label = match remaining_cases with
                   | [] -> default_label
                   | _ -> switch_chain_label current_label (case_index + 1) in
                 Printf.bprintf buffer
                   "  br i1 %s, label %%%s, label %%%s\n"
                   condition_name label false_label;
                 (match remaining_cases with
                  | [] -> ()
                  | _ ->
                      Printf.bprintf buffer "%s:\n" false_label;
                      render_cases (case_index + 1) remaining_cases)
           in
           render_cases 0 cases
       | _ -> failwith "DIR switch supports only int, float, bool and str")
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
  List.iter (fun block ->
    List.iter (fun instruction ->
      match instruction_result instruction with
      | Some (value, value_type) -> Hashtbl.replace value_types value value_type
      | None -> ()
    ) block.instructions
  ) function_def.blocks;
  let buffer = Buffer.create 512 in
  Printf.bprintf buffer "define %s @%s(%s) {\n"
    (llvm_ty function_def.return_type) function_def.name parameters;
  List.iter (fun block ->
    Printf.bprintf buffer "%s:\n" block.label;
    let incoming = incoming_for value_types block.label function_def.blocks in
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
    render_terminator string_literals value_types block.label function_def.return_type buffer block.terminator
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
  Buffer.add_string buffer "%dict_t = type opaque\n";
  Buffer.add_string buffer "%enum_t = type opaque\n";
  Buffer.add_string buffer "%dir_closure = type { i8*, i8* }\n";
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
  Buffer.add_string buffer "declare i8* @dream_closure_alloc(i64)\n";
  Buffer.add_string buffer "declare %dir_closure* @dream_closure_create(i8*, i8*)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_simple(i32)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_int(i32, i32)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_float(i32, double)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_string(i32, i8*)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_bool(i32, i1)\n";
  Buffer.add_string buffer "declare i32 @enum_get_tag(%enum_t*)\n";
  Buffer.add_string buffer "declare i32 @enum_get_int(%enum_t*)\n";
  Buffer.add_string buffer "declare double @enum_get_float(%enum_t*)\n";
  Buffer.add_string buffer "declare i8* @enum_get_string(%enum_t*)\n";
  Buffer.add_string buffer "declare i1 @enum_get_bool(%enum_t*)\n";
  Buffer.add_string buffer "declare %enum_t* @enum_create_tuple(i32, i8*, i64)\n";
  Buffer.add_string buffer "declare i8* @enum_get_data(%enum_t*)\n";
  List.iter (fun function_def ->
    Buffer.add_string buffer (render_function literals function_def);
    Buffer.add_char buffer '\n'
  ) module_.functions;
  Buffer.contents buffer
