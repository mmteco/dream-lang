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
  | List (Str | Tuple _) -> "%dynarray_ptr*"
  | Tuple _ -> "%dynarray_ptr*"
  | Struct (_, fields) ->
      "{" ^ String.concat ", " (List.map (fun (_, field_type) -> llvm_ty field_type) fields) ^ "}"
  | Enum (_, variants) when List.exists (fun (_, payload_types) -> payload_types <> []) variants ->
      "%enum_t*"
  | Enum _ -> "i32"
  | Interface _ -> "%dir_interface"
  | Union _ -> "%union_t*"
  | ClosureEnv _ -> "i8*"
  | Func _ -> "%dir_closure*"
  | List _ -> failwith "DIR LLVM lowering only supports list<i32>, list<str> and list<tuple>"

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
  | Str | Bytes | Dict _ | List _ | Tuple _ | Enum _ | Union _ | ClosureEnv _ | Func _ -> 8
  | Interface _ -> 24
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

let llvm_interface_function_ty parameter_types return_type =
  Printf.sprintf "%s (%s)" (llvm_ty return_type)
    (String.concat ", " ("i8*" :: List.map llvm_ty parameter_types))

let interface_symbol_part name =
  let buffer = Buffer.create (String.length name) in
  String.iter (fun character ->
    if (character >= 'a' && character <= 'z') ||
       (character >= 'A' && character <= 'Z') ||
       (character >= '0' && character <= '9') || character = '_' then
      Buffer.add_char buffer character
    else
      Buffer.add_char buffer '_'
  ) name;
  Buffer.contents buffer

let interface_concrete_name = function
  | Struct (concrete_name, _) | Enum (concrete_name, _) -> concrete_name
  | actual_type -> failwith (Printf.sprintf
      "DIR interface values require a struct or enum concrete type, got %s"
      (ty_to_string actual_type))

let interface_vtable_name interface_name concrete_type =
  let concrete_name = interface_concrete_name concrete_type in
  Printf.sprintf "@__dir_vtable_%s_%s"
    (interface_symbol_part interface_name) (interface_symbol_part concrete_name)

let interface_adapter_name interface_name concrete_type method_index =
  let concrete_name = interface_concrete_name concrete_type in
  Printf.sprintf "__dir_interface_adapter_%s_%s_%d"
    (interface_symbol_part interface_name) (interface_symbol_part concrete_name)
    method_index


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
  | BitAnd -> "and"
  | BitOr -> "or"
  | BitXor -> "xor"
  | Shl -> "shl"
  | Shr -> "ashr"
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

(* 将元组元素按位编码为 i64 存入 intptr_t 槽位 *)
let tuple_element_store buffer temp_name element_type element =
  match element_type with
  | I32 ->
      Printf.bprintf buffer "  %s = sext i32 %s to i64\n" temp_name element
  | Bool ->
      Printf.bprintf buffer "  %s = zext i1 %s to i64\n" temp_name element
  | F64 ->
      Printf.bprintf buffer "  %s = bitcast double %s to i64\n" temp_name element
  | Struct _ | Interface _ ->
      (* 聚合类型装箱为堆对象，仅存指针 *)
      let box_name = temp_name ^ "_box" in
      let typed_name = temp_name ^ "_typed" in
      Printf.bprintf buffer "  %s = call i8* @dream_closure_alloc(i64 %d)\n"
        box_name (llvm_size element_type);
      Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
        typed_name box_name (llvm_ty element_type);
      Printf.bprintf buffer "  store %s %s, %s* %s\n"
        (llvm_ty element_type) element (llvm_ty element_type) typed_name;
      Printf.bprintf buffer "  %s = ptrtoint %s* %s to i64\n"
        temp_name (llvm_ty element_type) typed_name
  | Unit -> failwith "DIR tuple element cannot be unit"
  | _ ->
      Printf.bprintf buffer "  %s = ptrtoint %s %s to i64\n"
        temp_name (llvm_ty element_type) element

(* 从 intptr_t 槽位解码元组元素 *)
let tuple_element_load buffer result_name element_type raw_name =
  match element_type with
  | I32 ->
      Printf.bprintf buffer "  %s = trunc i64 %s to i32\n" result_name raw_name
  | Bool ->
      Printf.bprintf buffer "  %s = trunc i64 %s to i1\n" result_name raw_name
  | F64 ->
      Printf.bprintf buffer "  %s = bitcast i64 %s to double\n" result_name raw_name
  | Struct _ | Interface _ ->
      let ptr_name = raw_name ^ "_ptr" in
      Printf.bprintf buffer "  %s = inttoptr i64 %s to %s*\n"
        ptr_name raw_name (llvm_ty element_type);
      Printf.bprintf buffer "  %s = load %s, %s* %s\n"
        result_name (llvm_ty element_type) (llvm_ty element_type) ptr_name
  | _ ->
      Printf.bprintf buffer "  %s = inttoptr i64 %s to %s\n"
        result_name raw_name (llvm_ty element_type)

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
   | InterfaceBox (value, concrete_type, object_value) ->
       (* 聚合类型装箱为堆拷贝（引用计数管理，函数返回前由编译器释放） *)
       let typed_object = Printf.sprintf "%%dir_interface_box_typed_%d" value in
       let concrete_llvm_type = llvm_ty concrete_type in
       Printf.bprintf buffer "  %s = call i8* @dream_interface_alloc(i64 %d)\n"
         (value_name value) (llvm_size concrete_type);
       Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
         typed_object (value_name value) concrete_llvm_type;
       Printf.bprintf buffer "  store %s %s, %s* %s\n"
         concrete_llvm_type (operand object_value) concrete_llvm_type typed_object
   | MakeInterface (value, Interface (interface_name, methods), concrete_type,
                    object_value, method_names) ->
       (* 对象已装箱（InterfaceBox / EnumCreateSimple / 借用的枚举对象），直接存指针 *)
       let object_storage = Printf.sprintf "%%dir_interface_object_%d" value in
       let method_count = List.length methods in
       let vtable_name = interface_vtable_name interface_name concrete_type in
       (match concrete_type with
        | Struct _ ->
            Printf.bprintf buffer "  %s = bitcast i8* %s to i8*\n"
              object_storage (operand object_value)
        | Enum _ ->
            Printf.bprintf buffer "  %s = bitcast %%enum_t* %s to i8*\n"
              object_storage (operand object_value)
        | _ -> failwith "DIR interface values require a struct or enum concrete type");
       let object_field = Printf.sprintf "%%dir_interface_value_%d" value in
       let table_field = Printf.sprintf "%%dir_interface_table_%d" value in
       let concrete_name = interface_concrete_name concrete_type in
       Printf.bprintf buffer "  %s = insertvalue %%dir_interface undef, i8* %s, 0\n"
         object_field object_storage;
       Printf.bprintf buffer "  %s = insertvalue %%dir_interface %s, i8* bitcast ([%d x i8*]* %s to i8*), 1\n"
         table_field object_field method_count vtable_name;
       Printf.bprintf buffer "  %s = insertvalue %%dir_interface %s, i32 %d, 2\n"
         (value_name value) table_field (Dir.concrete_type_tag concrete_name);
       ignore method_names
   | InterfaceTypeTag (value, interface_value) ->
       Printf.bprintf buffer "  %s = extractvalue %%dir_interface %s, 2\n"
         (value_name value) (operand interface_value)
   | InterfaceRelease box_value ->
       (* 箱对象为 i8*（struct 箱）或 %enum_t*（无载荷 enum 箱），统一转 i8* 后释放 *)
       (match box_value with
        | Value value ->
            (match Hashtbl.find_opt value_types value with
             | Some (Enum _) ->
                 Printf.bprintf buffer "  %%dir_release_raw_%d = bitcast %%enum_t* %s to i8*\n"
                   value (operand box_value);
                 Printf.bprintf buffer "  call void @dream_interface_release(i8* %%dir_release_raw_%d)\n"
                   value
             | _ ->
                 Printf.bprintf buffer "  call void @dream_interface_release(i8* %s)\n"
                   (operand box_value))
        | _ -> failwith "DIR interface_release requires an SSA box value")
   | MakeInterface _ -> failwith "invalid DIR interface type"
   | InterfaceCall (result_value, result_type, Interface (_interface_name, methods),
                   interface_value, _method_name, method_index, parameter_types, arguments) ->
       let call_id = match result_value with
         | Some value -> value
         | None -> abs (Hashtbl.hash (interface_value, method_index, arguments))
       in
       let interface_data = Printf.sprintf "%%dir_interface_data_%d" call_id in
       let interface_table = Printf.sprintf "%%dir_interface_table_%d" call_id in
       let table_type = Printf.sprintf "[%d x i8*]" (List.length methods) in
       let table_pointer = Printf.sprintf "%%dir_interface_table_ptr_%d" call_id in
       let slot_pointer = Printf.sprintf "%%dir_interface_slot_%d" call_id in
       let raw_function = Printf.sprintf "%%dir_interface_raw_%d" call_id in
       let typed_function = Printf.sprintf "%%dir_interface_function_%d" call_id in
       let function_type = llvm_interface_function_ty parameter_types result_type in
       Printf.bprintf buffer "  %s = extractvalue %%dir_interface %s, 0\n"
         interface_data (operand interface_value);
       Printf.bprintf buffer "  %s = extractvalue %%dir_interface %s, 1\n"
         interface_table (operand interface_value);
       Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
         table_pointer interface_table table_type;
       Printf.bprintf buffer "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
         slot_pointer table_type table_type table_pointer method_index;
       Printf.bprintf buffer "  %s = load i8*, i8** %s\n"
         raw_function slot_pointer;
       Printf.bprintf buffer "  %s = bitcast i8* %s to %s*\n"
         typed_function raw_function function_type;
       let rendered_arguments = String.concat ", " (List.map2 (fun argument_type argument ->
         Printf.sprintf "%s %s" (llvm_ty argument_type) (operand argument)
       ) parameter_types arguments) in
       let call_arguments = if rendered_arguments = "" then
         "i8* " ^ interface_data
       else
         "i8* " ^ interface_data ^ ", " ^ rendered_arguments
       in
       (match result_value with
        | Some value ->
            Printf.bprintf buffer "  %s = call %s %s(%s)\n"
              (value_name value) (llvm_ty result_type) typed_function call_arguments
        | None ->
            Printf.bprintf buffer "  call %s %s(%s)\n"
              (llvm_ty result_type) typed_function call_arguments)
   | InterfaceCall _ -> failwith "invalid DIR interface call"
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
       (match operand_type value_types collection with
        | List I32 ->
            Printf.bprintf buffer "  %s = call i32 @len_dynarray_i32(%%dynarray_i32* %s)\n"
              (value_name value) (operand collection)
        | List _ ->
            Printf.bprintf buffer "  %s = call i32 @len_dynarray_ptr(%%dynarray_ptr* %s)\n"
              (value_name value) (operand collection)
        | _ -> failwith "DIR list_length requires a list collection")
   | ListGet (value, collection, index) ->
       (match operand_type value_types collection with
        | List I32 ->
            Printf.bprintf buffer "  %s = call i32 @get_dynarray_i32(%%dynarray_i32* %s, i32 %s)\n"
              (value_name value) (operand collection) (operand index)
        | List element_type ->
            let raw_name = Printf.sprintf "%%dir_list_raw_%d" value in
            Printf.bprintf buffer "  %s = call i64 @get_dynarray_ptr(%%dynarray_ptr* %s, i32 %s)\n"
              raw_name (operand collection) (operand index);
            tuple_element_load buffer (value_name value) element_type raw_name;
            Hashtbl.replace value_types value element_type
        | _ -> failwith "DIR list_get requires a list collection")
   | ListCreate (value, element_type, values) ->
       (match element_type with
        | I32 ->
            Printf.bprintf buffer "  %s = call %%dynarray_i32* @create_dynarray_i32(i32 %d)\n"
              (value_name value) (List.length values);
            List.iter (fun item ->
              Printf.bprintf buffer "  call void @append_i32(%%dynarray_i32* %s, i32 %s)\n"
                (value_name value) (operand item)
            ) values
        | Str | Tuple _ ->
            Printf.bprintf buffer "  %s = call %%dynarray_ptr* @create_dynarray_ptr(i32 %d)\n"
              (value_name value) (List.length values);
            List.iteri (fun index item ->
              let temp_name = Printf.sprintf "%%dir_list_elem_%d_%d" value index in
              tuple_element_store buffer temp_name element_type (operand item);
              Printf.bprintf buffer "  call void @append_ptr(%%dynarray_ptr* %s, i64 %s)\n"
                (value_name value) temp_name
            ) values
        | _ -> failwith "DIR list_create supports only i32, str and tuple elements")
   | ListSlice (value, collection, start, end_) ->
       (match operand_type value_types collection with
        | List I32 ->
            Printf.bprintf buffer "  %s = call %%dynarray_i32* @slice_dynarray_i32(%%dynarray_i32* %s, i32 %s, i32 %s)\n"
              (value_name value) (operand collection) (operand start) (operand end_)
        | List element_type ->
            Printf.bprintf buffer "  %s = call %%dynarray_ptr* @slice_dynarray_ptr(%%dynarray_ptr* %s, i32 %s, i32 %s)\n"
              (value_name value) (operand collection) (operand start) (operand end_);
            Hashtbl.replace value_types value (List element_type)
        | _ -> failwith "DIR list_slice requires a list collection")
   | ListConcat (value, left, right) ->
       (match operand_type value_types left, operand_type value_types right with
        | List I32, List I32 ->
            Printf.bprintf buffer "  %s = call %%dynarray_i32* @concat_dynarray_i32(%%dynarray_i32* %s, %%dynarray_i32* %s)\n"
              (value_name value) (operand left) (operand right)
        | List element_type, List _ ->
            Printf.bprintf buffer "  %s = call %%dynarray_ptr* @concat_dynarray_ptr(%%dynarray_ptr* %s, %%dynarray_ptr* %s)\n"
              (value_name value) (operand left) (operand right);
            Hashtbl.replace value_types value (List element_type)
        | _ -> failwith "DIR list_concat requires list collections of the same element type")
   | TupleCreate (value, element_types, values) ->
       Printf.bprintf buffer "  %s = call %%dynarray_ptr* @create_dynarray_ptr(i32 %d)\n"
         (value_name value) (List.length values);
       List.iteri (fun index item ->
         let temp_name = Printf.sprintf "%%dir_tuple_elem_%d_%d" value index in
         let element_type = List.nth element_types index in
         tuple_element_store buffer temp_name element_type (operand item);
         Printf.bprintf buffer "  call void @append_ptr(%%dynarray_ptr* %s, i64 %s)\n"
           (value_name value) temp_name
       ) values
   | TupleGet (value, element_type, tuple_value, index) ->
       let raw_name = Printf.sprintf "%%dir_tuple_raw_%d" value in
       Printf.bprintf buffer "  %s = call i64 @get_dynarray_ptr(%%dynarray_ptr* %s, i32 %d)\n"
         raw_name (operand tuple_value) index;
       tuple_element_load buffer (value_name value) element_type raw_name
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
   | EnumCreateSimple (value, _enum_type, tag) ->
       (* 总是创建 %enum_t* 堆对象，与无载荷 enum 的 i32 表示无关 *)
       Printf.bprintf buffer "  %s = call %%enum_t* @enum_create_simple(i32 %d)\n"
         (value_name value) tag
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
         (operand collection) (operand index) (operand value)
   | GlobalLoad (value, ty, name) ->
       Printf.bprintf buffer "  %s = load %s, %s* @%s\n"
         (value_name value) (llvm_ty ty) (llvm_ty ty) name
   | GlobalStore (name, value) ->
       Printf.bprintf buffer "  store %s %s, %s* @%s\n"
         (llvm_ty (operand_type value_types value)) (operand value)
         (llvm_ty (operand_type value_types value)) name);
  match instruction_result instruction with
  | Some (value, result_type) ->
      (* ListGet/ListSlice/ListConcat 的结果类型按元素类型分派，已在分支内记录 *)
      if not (Hashtbl.mem value_types value) then
        Hashtbl.replace value_types value result_type
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
  let is_process_entry = function_def.name = "main" && function_def.parameters = [] in
  let parameters = String.concat ", " (List.map (fun parameter ->
    Hashtbl.add value_types parameter.value parameter.ty;
    Printf.sprintf "%s %s" (llvm_ty parameter.ty) (value_name parameter.value)
  ) function_def.parameters @ if is_process_entry then
    ["i32 %dream_argc.param"; "i8** %dream_argv.param"]
  else []) in
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
    if is_process_entry && block.label = "entry" then
      Buffer.add_string buffer
        "  call void @__c_process_set_args(i32 %dream_argc.param, i8** %dream_argv.param)\n";
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

let interface_artifacts module_ =
  let add_artifact artifacts artifact =
    let interface_name, _, concrete_type, _ = artifact in
    let key = interface_vtable_name interface_name concrete_type in
    if List.exists (fun (existing_name, _, existing_type, _) ->
        interface_vtable_name existing_name existing_type = key) artifacts then
      artifacts
    else
      artifacts @ [artifact]
  in
  List.fold_left (fun artifacts function_def ->
    List.fold_left (fun artifacts block ->
      List.fold_left (fun artifacts instruction ->
        match instruction with
        | MakeInterface (_, Interface (interface_name, methods), concrete_type,
                         _, method_names) ->
            add_artifact artifacts (interface_name, methods, concrete_type, method_names)
        | _ -> artifacts
      ) artifacts block.instructions
    ) artifacts function_def.blocks
  ) [] module_.functions

let render_interface_artifact (interface_name, methods, concrete_type, method_names) =
  let buffer = Buffer.create 512 in
  let vtable_name = interface_vtable_name interface_name concrete_type in
  let entries = List.mapi (fun method_index (_, parameter_types, return_type) ->
    let adapter_name = interface_adapter_name interface_name concrete_type method_index in
    Printf.sprintf "i8* bitcast (%s* @%s to i8*)"
      (llvm_interface_function_ty parameter_types return_type) adapter_name
  ) methods in
  Printf.bprintf buffer "%s = private constant [%d x i8*] [%s]\n\n"
    vtable_name (List.length methods) (String.concat ", " entries);
  List.iteri (fun method_index (_, parameter_types, return_type) ->
    let adapter_name = interface_adapter_name interface_name concrete_type method_index in
    let function_name = List.nth method_names method_index in
    let concrete_llvm_type = llvm_ty concrete_type in
    let parameters = List.mapi (fun index parameter_type ->
      Printf.sprintf "%s %%dir_interface_argument_%d" (llvm_ty parameter_type) index
    ) parameter_types in
    Printf.bprintf buffer "define %s @%s(i8* %%dir_interface_object%s) {\n"
      (llvm_ty return_type) adapter_name
      (if parameters = [] then "" else ", " ^ String.concat ", " parameters);
    Printf.bprintf buffer "entry:\n  %%dir_interface_typed_object = bitcast i8* %%dir_interface_object to %s*\n"
      concrete_llvm_type;
    (* 枚举解引用得到 %enum_t*，结构体解引用得到聚合值 *)
    Printf.bprintf buffer "  %%dir_interface_receiver = load %s, %s* %%dir_interface_typed_object\n"
      concrete_llvm_type concrete_llvm_type;
    let rendered_arguments = String.concat ", " (
      (Printf.sprintf "%s %%dir_interface_receiver" concrete_llvm_type) ::
      List.mapi (fun index parameter_type ->
        Printf.sprintf "%s %%dir_interface_argument_%d" (llvm_ty parameter_type) index
      ) parameter_types) in
    if return_type = Unit then begin
      Printf.bprintf buffer "  call void @%s(%s)\n" function_name rendered_arguments;
      Buffer.add_string buffer "  ret void\n"
    end else begin
      Printf.bprintf buffer "  %%dir_interface_result = call %s @%s(%s)\n"
        (llvm_ty return_type) function_name rendered_arguments;
      Printf.bprintf buffer "  ret %s %%dir_interface_result\n" (llvm_ty return_type)
    end;
    Buffer.add_string buffer "}\n\n"
  ) methods;
  Buffer.contents buffer

let render module_ =
  let literals = List.mapi (fun index value ->
    (value, Printf.sprintf "@.dir_str%d" index)
  ) (string_operands module_) in
  let buffer = Buffer.create 2048 in
  Buffer.add_string buffer "; DreamIR lowered LLVM\n";
  Buffer.add_string buffer "%dynarray_i32 = type { i32, i32, i32* }\n";
  Buffer.add_string buffer "%dynarray_ptr = type { i32, i32, i64* }\n";
  Buffer.add_string buffer "%dict_t = type opaque\n";
  Buffer.add_string buffer "%enum_t = type opaque\n";
  Buffer.add_string buffer "%union_t = type opaque\n";
  Buffer.add_string buffer "%dir_closure = type { i8*, i8* }\n";
  Buffer.add_string buffer "%dir_interface = type { i8*, i8*, i32 }\n";
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
  List.iter (fun (name, ty) ->
    Printf.bprintf buffer "@%s = global %s zeroinitializer\n" name (llvm_ty ty)
  ) module_.globals;
  if module_.globals <> [] then Buffer.add_char buffer '\n';
  Buffer.add_string buffer "declare %dynarray_i32* @create_dynarray_i32(i32)\n";
  Buffer.add_string buffer "declare void @append_i32(%dynarray_i32*, i32)\n";
  Buffer.add_string buffer "declare void @set_dynarray_i32(%dynarray_i32*, i32, i32)\n";
  Buffer.add_string buffer "declare i32 @len_dynarray_i32(%dynarray_i32*)\n";
  Buffer.add_string buffer "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n";
  Buffer.add_string buffer "declare %dynarray_i32* @slice_dynarray_i32(%dynarray_i32*, i32, i32)\n";
  Buffer.add_string buffer "declare %dynarray_i32* @concat_dynarray_i32(%dynarray_i32*, %dynarray_i32*)\n";
  Buffer.add_string buffer "declare %dynarray_ptr* @create_dynarray_ptr(i32)\n";
  Buffer.add_string buffer "declare void @append_ptr(%dynarray_ptr*, i64)\n";
  Buffer.add_string buffer "declare i64 @get_dynarray_ptr(%dynarray_ptr*, i32)\n";
  Buffer.add_string buffer "declare i32 @len_dynarray_ptr(%dynarray_ptr*)\n";
  Buffer.add_string buffer "declare %dynarray_ptr* @slice_dynarray_ptr(%dynarray_ptr*, i32, i32)\n";
  Buffer.add_string buffer "declare %dynarray_ptr* @concat_dynarray_ptr(%dynarray_ptr*, %dynarray_ptr*)\n\n";
  Buffer.add_string buffer "declare i8* @string_substring(i8*, i32, i32)\n";
  Buffer.add_string buffer "declare i32 @string_compare(i8*, i8*)\n";
  Buffer.add_string buffer "declare void @__c_process_set_args(i32, i8**)\n";
  Buffer.add_string buffer "declare i8* @dream_closure_alloc(i64)\n";
  Buffer.add_string buffer "declare i8* @dream_interface_alloc(i64)\n";
  Buffer.add_string buffer "declare void @dream_interface_release(i8*)\n";
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
  List.iter (fun artifact ->
    Buffer.add_string buffer (render_interface_artifact artifact)
  ) (interface_artifacts module_);
  List.iter (fun function_def ->
    Buffer.add_string buffer (render_function literals function_def);
    Buffer.add_char buffer '\n'
  ) module_.functions;
  Buffer.contents buffer
