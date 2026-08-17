open Dir

type error = string

let verify module_ =
  let errors = ref [] in
  let add_error message = errors := message :: !errors in
  let is_symbol_name name =
    let length = String.length name in
    let is_first_character character =
      (character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      character = '_' || character = '$' || character = '.'
    in
    let is_body_character character =
      is_first_character character || (character >= '0' && character <= '9')
    in
    if length = 0 || not (is_first_character name.[0]) then false
    else
      let rec check index =
        if index >= length then true
        else is_body_character name.[index] && check (index + 1)
      in
      check 1
  in
  let ty_compatible left right =
    match left, right with
    | Union left_members, Union right_members ->
        List.exists (fun member ->
          List.exists (equal_ty member) right_members
        ) left_members
    | Dict (_, _), Dict (_, _) -> true
    | List (Tuple _), List (Tuple _) -> true
    | List _, List _ -> true
    | _ -> equal_ty left right
  in
  let function_signatures = Hashtbl.create 16 in
  let add_signature name parameters return_type =
    if not (is_symbol_name name) then
      add_error ("invalid symbol name: " ^ name);
    if Hashtbl.mem function_signatures name then
      add_error ("duplicate function declaration: " ^ name)
    else
      Hashtbl.add function_signatures name (parameters, return_type)
  in
  List.iter (fun (declaration : Dir.extern) ->
    add_signature declaration.name declaration.parameters declaration.return_type
  ) module_.externs;
  List.iter (fun (function_def : Dir.function_def) ->
    add_signature function_def.name
      (List.map (fun parameter -> parameter.ty) function_def.parameters)
      function_def.return_type
  ) module_.functions;

  let verify_operand value_types value expected_type context =
    match value with
    | Int _ when equal_ty expected_type I32 -> ()
    | Int _ when (match expected_type with Enum _ -> true | _ -> false) -> ()
    | Float _ when equal_ty expected_type F64 -> ()
    | Bool _ when equal_ty expected_type Bool -> ()
    | String _ when equal_ty expected_type Str -> ()
    | FunctionRef name ->
        (match expected_type, Hashtbl.find_opt function_signatures name with
         | Func (parameter_types, return_type), Some (declared_parameters, declared_return)
           when List.length parameter_types = List.length declared_parameters &&
                List.for_all2 equal_ty parameter_types declared_parameters &&
                equal_ty return_type declared_return -> ()
         | Func _, None -> add_error (Printf.sprintf "%s: unknown function %s" context name)
         | Func _, Some _ -> add_error (Printf.sprintf
             "%s: function %s has an incompatible signature" context name)
         | _ -> add_error (Printf.sprintf "%s: expected %s" context (ty_to_string expected_type)))
    | Value value ->
        (match Hashtbl.find_opt value_types value with
         | Some actual_type when ty_compatible actual_type expected_type -> ()
         | Some actual_type ->
             add_error (Printf.sprintf "%s: expected %s, got %s"
               context (ty_to_string expected_type) (ty_to_string actual_type))
         | None ->
             add_error (Printf.sprintf "%s: undefined value %%v%d" context value))
    | Int _ | Float _ | Bool _ | String _ ->
        add_error (Printf.sprintf "%s: expected %s" context (ty_to_string expected_type))
  in

  let operand_type value_types = function
    | Int _ -> Some I32
    | Float _ -> Some F64
    | Bool _ -> Some Bool
    | String _ -> Some Str
    | FunctionRef _ -> None
    | Value value -> Hashtbl.find_opt value_types value
  in

  let list_element_type value_types operand context =
    match operand_type value_types operand with
    | Some (List element_type) -> Some element_type
    | Some actual_type ->
        add_error (Printf.sprintf "%s: expected list, got %s"
          context (ty_to_string actual_type));
        None
    | None -> None
  in

  let is_switch_type = function
    | I32 | F64 | Bool | Str -> true
    | _ -> false
  in

  let verify_call value_types result_value result_type name argument_types arguments =
    match Hashtbl.find_opt function_signatures name with
    | None -> add_error ("unknown function: " ^ name)
    | Some (parameter_types, declared_return_type) ->
        if not (is_symbol_name name) then
          add_error ("call " ^ name ^ ": invalid symbol name");
        if not (ty_compatible result_type declared_return_type) then
          add_error (Printf.sprintf "call %s: result type %s does not match declaration %s"
            name (ty_to_string result_type) (ty_to_string declared_return_type));
        (match result_value, declared_return_type with
         | None, Unit -> ()
         | None, _ -> add_error ("call " ^ name ^ ": non-unit result must be bound")
         | Some _, Unit -> add_error ("call " ^ name ^ ": unit result cannot be bound")
         | Some _, _ -> ());
        if List.length parameter_types <> List.length arguments then
          add_error (Printf.sprintf "call %s: expected %d arguments, got %d"
            name (List.length parameter_types) (List.length arguments))
        else if List.length argument_types <> List.length arguments then
          add_error (Printf.sprintf "call %s: expected %d argument types, got %d"
            name (List.length arguments) (List.length argument_types))
        else
          List.iter (fun ((expected_type, declared_type), argument) ->
            if not (ty_compatible expected_type declared_type) then
              add_error (Printf.sprintf "call %s: argument type %s does not match declaration %s"
                name (ty_to_string declared_type) (ty_to_string expected_type));
            verify_operand value_types argument expected_type ("call " ^ name)
          ) (List.combine (List.combine parameter_types argument_types) arguments);
        (match result_value with
         | Some value ->
             if Hashtbl.mem value_types value then
               add_error (Printf.sprintf "duplicate value %%v%d" value)
             else
               (* 注册指令实际返回类型（泛型调用如 dict_items_tuples 与声明类型不同） *)
               Hashtbl.add value_types value result_type
         | None -> ())
  in

  let verify_enum_value value_types value context =
    match value with
    | Value value_id ->
        (match Hashtbl.find_opt value_types value_id with
         | Some (Enum _) -> ()
         | Some actual_type ->
             add_error (Printf.sprintf "%s: expected enum, got %s"
               context (ty_to_string actual_type))
         | None -> add_error (Printf.sprintf "%s: undefined enum value %%v%d" context value_id))
    | _ -> add_error (context ^ ": expected an SSA enum value")
  in

  let verify_instruction value_types instruction =
    (match instruction with
     | Binop (value, result_type, operation, left, right) ->
         let expected_result_type : ty =
           if operation = And || operation = Or then (Bool : ty)
           else match left with
             | Float _ -> F64
             | Value left_value ->
                 (match Hashtbl.find_opt value_types left_value with
                  | Some F64 -> F64
                  | _ -> I32)
             | Int _ | Bool _ | String _ -> I32
             | FunctionRef _ -> I32
         in
         if not (equal_ty result_type expected_result_type) then
           add_error (Printf.sprintf "binary operation must return %s"
             (ty_to_string expected_result_type));
         if operation = And || operation = Or then begin
           verify_operand value_types left Bool "boolean binary operation";
           verify_operand value_types right Bool "boolean binary operation"
         end else if equal_ty expected_result_type F64 then begin
           verify_operand value_types left F64 "float binary operation";
           verify_operand value_types right F64 "float binary operation"
         end else begin
           verify_operand value_types left I32 "integer binary operation";
           verify_operand value_types right I32 "integer binary operation"
         end;
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value result_type
     | Compare (value, _, left, right) ->
         let expected_type = match left with
           | Int _ -> I32
           | Float _ -> F64
           | Bool _ -> Bool
           | String _ -> Str
           | Value left_value ->
               (match Hashtbl.find_opt value_types left_value with
                | Some ty -> ty
                | None -> I32)
           | FunctionRef _ -> I32
         in
         verify_operand value_types left expected_type "comparison left operand";
         verify_operand value_types right expected_type "comparison right operand";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value Bool
     | Call (result_value, result_type, name, argument_types, arguments) ->
         verify_call value_types result_value result_type name argument_types arguments
     | CallIndirect (result_value, result_type, parameter_types, callee, arguments) ->
         if List.length parameter_types <> List.length arguments then
           add_error "call_indirect argument count does not match function type"
         else begin
           verify_operand value_types callee
             (Func (parameter_types, result_type)) "call_indirect callee";
           List.iter2 (fun parameter_type argument ->
             verify_operand value_types argument parameter_type "call_indirect argument"
           ) parameter_types arguments
         end;
         (match result_value with
          | Some value ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value result_type
         | None -> ())
     | MakeClosure (value, closure_type, name, capture_types, captures) ->
         (match closure_type, Hashtbl.find_opt function_signatures name with
          | Func (parameter_types, return_type), Some (declared_parameters, declared_return) ->
              (match declared_parameters with
               | ClosureEnv _declared_environment :: declared_parameters
                 when List.length parameter_types = List.length declared_parameters &&
                      List.for_all2 equal_ty parameter_types declared_parameters &&
                      equal_ty return_type declared_return -> ()
               | _ -> add_error (Printf.sprintf
                   "make_closure target %s has an incompatible signature" name))
          | Func _, None -> add_error (Printf.sprintf "make_closure target %s is undefined" name)
          | _ -> add_error "make_closure result must be a function type");
         if List.length capture_types <> List.length captures then
           add_error "make_closure capture count does not match environment type";
         if List.length capture_types = List.length captures then
           List.iter2 (fun capture_type capture ->
             verify_operand value_types capture capture_type "make_closure capture"
           ) capture_types captures;
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value closure_type
     | ClosureGet (value, field_type, environment_types, environment, index) ->
         verify_operand value_types environment (ClosureEnv environment_types)
           "closure_get environment";
         if index < 0 || index >= List.length environment_types then
           add_error "closure_get field index is out of bounds"
         else if not (equal_ty field_type (List.nth environment_types index)) then
           add_error "closure_get field type does not match environment";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value field_type
     | InterfaceBox (value, concrete_type, object_value) ->
         verify_operand value_types object_value concrete_type "interface_box object";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value concrete_type
     | InterfaceRelease box_value ->
         (match box_value with
          | Value value_id ->
              if not (Hashtbl.mem value_types value_id) then
                add_error (Printf.sprintf "interface_release uses an undefined value %%v%d" value_id)
          | _ -> add_error "interface_release requires an SSA box value")
     | InterfaceTypeTag (value, interface_value) ->
         (match interface_value with
          | Value interface_id ->
              if not (Hashtbl.mem value_types interface_id) then
                add_error (Printf.sprintf
                  "interface_type_tag uses an undefined value %%v%d" interface_id)
          | _ -> add_error "interface_type_tag requires an SSA interface value");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | MakeInterface (value, interface_type, concrete_type, object_value, method_names) ->
         verify_operand value_types object_value concrete_type "make_interface object";
         (match interface_type with
          | Interface (_, methods) ->
              if List.length methods <> List.length method_names then
                add_error "make_interface method count does not match interface";
              if List.length methods = List.length method_names then
                List.iter2 (fun (_, parameter_types, return_type) function_name ->
                  match Hashtbl.find_opt function_signatures function_name with
                  | None -> add_error (Printf.sprintf
                      "make_interface target %s is undefined" function_name)
                  | Some (declared_parameters, declared_return) ->
                      let expected_parameters = concrete_type :: parameter_types in
                      if List.length declared_parameters <> List.length expected_parameters ||
                         not (List.for_all2 equal_ty declared_parameters expected_parameters) ||
                         not (equal_ty declared_return return_type) then
                        add_error (Printf.sprintf
                          "make_interface target %s has an incompatible signature"
                          function_name)
                ) methods method_names
          | _ -> add_error "make_interface result must be an interface type");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value interface_type
     | InterfaceCall (result_value, result_type, interface_type, interface_value,
                      method_name, method_index, parameter_types, arguments) ->
         verify_operand value_types interface_value interface_type "interface_call receiver";
         (match interface_type with
          | Interface (_, methods) ->
              if method_index < 0 || method_index >= List.length methods then
                add_error "interface_call method index is out of bounds"
              else
                let (expected_name, expected_parameters, expected_return) =
                  List.nth methods method_index in
                if expected_name <> method_name then
                  add_error "interface_call method name does not match index";
                if not (equal_ty expected_return result_type) then
                  add_error "interface_call result type does not match method";
                if List.length expected_parameters <> List.length parameter_types ||
                   not (List.for_all2 equal_ty expected_parameters parameter_types) then
                  add_error "interface_call parameter types do not match method"
          | _ -> add_error "interface_call receiver must be an interface type");
         if List.length parameter_types <> List.length arguments then
           add_error "interface_call argument count does not match method";
         if List.length parameter_types = List.length arguments then
           List.iter2 (fun parameter_type argument ->
             verify_operand value_types argument parameter_type "interface_call argument"
           ) parameter_types arguments;
         (match result_value with
          | Some value ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
              else
                Hashtbl.add value_types value result_type
          | None -> ())
     | StringLength (value, string_value) ->
         verify_operand value_types string_value Str "string_length";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | StringCompare (value, left, right) ->
         verify_operand value_types left Str "string_compare left operand";
         verify_operand value_types right Str "string_compare right operand";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | StringSlice (value, string_value, start, end_) ->
         verify_operand value_types string_value Str "string_slice string";
         verify_operand value_types start I32 "string_slice start";
         verify_operand value_types end_ I32 "string_slice end";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value Str
     | ListLength (value, collection) ->
         (match list_element_type value_types collection "list_length" with
          | Some _ ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
              else
                Hashtbl.add value_types value I32
          | None -> ())
     | ListGet (value, collection, index) ->
         verify_operand value_types index I32 "list_get index";
         (match list_element_type value_types collection "list_get collection" with
          | Some element_type ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
              else
                Hashtbl.add value_types value element_type
          | None -> ())
     | ListCreate (value, element_type, values) ->
         (match element_type with
          | I32 | Str | Tuple _ ->
              List.iter (fun item ->
                verify_operand value_types item element_type "list_create element"
              ) values
          | _ -> add_error "list_create supports only i32, str and tuple elements");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (List element_type)
     | ListSlice (value, collection, start, end_) ->
         verify_operand value_types start I32 "list_slice start";
         verify_operand value_types end_ I32 "list_slice end";
         (match list_element_type value_types collection "list_slice collection" with
          | Some element_type ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
              else
                Hashtbl.add value_types value (List element_type)
          | None -> ())
     | ListConcat (value, left, right) ->
         (match list_element_type value_types left "list_concat left",
                list_element_type value_types right "list_concat right" with
          | Some element_type, Some _ ->
              if Hashtbl.mem value_types value then
                add_error (Printf.sprintf "duplicate value %%v%d" value)
              else
                Hashtbl.add value_types value (List element_type)
          | _ -> ())
     | TupleCreate (value, element_types, values) ->
         if List.length element_types <> List.length values then
           add_error "tuple_create element count does not match type count";
         if List.length element_types = List.length values then
           List.iter2 (fun element_type item ->
             verify_operand value_types item element_type "tuple_create element"
           ) element_types values;
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (Tuple element_types)
     | TupleGet (value, element_type, tuple_value, index) ->
         (match tuple_value with
          | Value tuple_value_id ->
              (match Hashtbl.find_opt value_types tuple_value_id with
               | Some (Tuple element_types) when index >= 0 && index < List.length element_types ->
                   let actual_type = List.nth element_types index in
                   if not (equal_ty actual_type element_type) then
                     add_error "tuple_get result type does not match tuple element"
               | Some (Tuple _) -> add_error "tuple_get index is out of bounds"
               | Some _ -> add_error "tuple_get requires a tuple value"
               | None -> add_error "tuple_get uses an undefined tuple value")
          | _ -> add_error "tuple_get requires an SSA tuple value");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
           else
             Hashtbl.add value_types value element_type
     | StructCreate (value, struct_name, fields, values) ->
         if List.length fields <> List.length values then
           add_error ("struct " ^ struct_name ^ ": field count does not match value count")
         else
           List.iter2 (fun (_, field_type) item ->
             verify_operand value_types item field_type "struct field"
           ) fields values;
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (Struct (struct_name, fields))
     | StructGet (value, field_type, struct_value, index) ->
         (match struct_value with
          | Value struct_value_id ->
              (match Hashtbl.find_opt value_types struct_value_id with
               | Some (Struct (_, fields)) when index >= 0 && index < List.length fields ->
                   let actual_type = snd (List.nth fields index) in
                   if not (equal_ty actual_type field_type) then
                     add_error "struct_get result type does not match struct field"
               | Some (Struct _) -> add_error "struct_get index is out of bounds"
               | Some _ -> add_error "struct_get requires a struct value"
               | None -> add_error "struct_get uses an undefined struct value")
          | _ -> add_error "struct_get requires an SSA struct value");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value field_type
     | EnumCreate (value, enum_type, tag, payload_type, payload) ->
         (match enum_type with
          | Enum (_, variants) when tag >= 0 && tag < List.length variants ->
              let _, expected_payload = List.nth variants tag in
              (match expected_payload with
               | [expected_type] ->
                   if not (equal_ty expected_type payload_type) then
                     add_error "enum_create payload type does not match variant";
                   verify_operand value_types payload expected_type "enum payload"
               | [] -> add_error "enum_create cannot add a payload to a simple variant"
               | _ -> add_error "enum_create supports only one payload")
          | Enum _ -> add_error "enum_create tag is out of bounds"
          | _ -> add_error "enum_create requires an enum result type");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value enum_type
     | EnumCreateMulti (value, enum_type, tag, payload_types, payloads) ->
         (match enum_type with
          | Enum (_, variants) when tag >= 0 && tag < List.length variants ->
              let _, expected_payload = List.nth variants tag in
              if List.length expected_payload <> List.length payload_types ||
                 List.length payload_types <> List.length payloads then
                add_error "enum_create_multi payload count does not match variant"
              else begin
                List.iter2 (fun expected actual ->
                  if not (equal_ty expected actual) then
                    add_error "enum_create_multi payload type does not match variant"
                ) expected_payload payload_types;
                List.iter2 (fun payload_type payload ->
                  verify_operand value_types payload payload_type "enum payload"
                ) payload_types payloads
              end
          | Enum _ -> add_error "enum_create_multi tag is out of bounds"
          | _ -> add_error "enum_create_multi requires an enum result type");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value enum_type
     | EnumCreateSimple (value, enum_type, tag) ->
         (match enum_type with
          | Enum (_, variants) when tag >= 0 && tag < List.length variants ->
              if snd (List.nth variants tag) <> [] then
                add_error "enum_create_simple requires a payload-free variant"
          | Enum _ -> add_error "enum_create_simple tag is out of bounds"
          | _ -> add_error "enum_create_simple requires an enum result type");
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value enum_type
     | EnumTag (value, enum_value) ->
         verify_enum_value value_types enum_value "enum_tag";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | EnumGet (value, field_type, enum_value, tag) ->
         verify_enum_value value_types enum_value "enum_get";
         (match enum_value with
          | Value enum_value_id ->
              (match Hashtbl.find_opt value_types enum_value_id with
               | Some (Enum (_, variants)) when tag >= 0 && tag < List.length variants ->
                   (match snd (List.nth variants tag) with
                    | [expected_type] when equal_ty expected_type field_type -> ()
                    | [_] -> add_error "enum_get result type does not match variant payload"
                    | [] -> add_error "enum_get cannot extract from a simple variant"
                    | _ -> add_error "enum_get supports only one payload")
               | Some (Enum _) -> add_error "enum_get tag is out of bounds"
               | _ -> ())
          | _ -> ());
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value field_type
     | EnumGetMulti (value, field_type, payload_types, enum_value, tag, index) ->
         verify_enum_value value_types enum_value "enum_get_multi";
         (match enum_value with
          | Value enum_value_id ->
              (match Hashtbl.find_opt value_types enum_value_id with
               | Some (Enum (_, variants)) when tag >= 0 && tag < List.length variants ->
                   let expected_payload = snd (List.nth variants tag) in
                   if index < 0 || index >= List.length expected_payload ||
                      List.length expected_payload <> List.length payload_types then
                     add_error "enum_get_multi payload index or type list is invalid"
                   else if not (equal_ty field_type (List.nth expected_payload index)) then
                     add_error "enum_get_multi result type does not match variant payload"
               | Some (Enum _) -> add_error "enum_get_multi tag is out of bounds"
               | _ -> ())
          | _ -> ());
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value field_type
     | ListAppend (collection, value) ->
         verify_operand value_types collection (List I32) "list_append collection";
         verify_operand value_types value I32 "list_append value"
     | ListSet (collection, index, value) ->
         verify_operand value_types collection (List I32) "list_set collection";
         verify_operand value_types index I32 "list_set index";
         verify_operand value_types value I32 "list_set value"
     | GlobalLoad (value, result_type, _) ->
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value result_type
     | GlobalStore (_, value) ->
         (match operand_type value_types value with
          | Some actual_type ->
              verify_operand value_types value actual_type "global_store value"
          | None ->
              add_error "global_store value has no type"));
    ()
  in

  let verify_function function_def =
    let block_labels = Hashtbl.create 16 in
    List.iter (fun block ->
      if Hashtbl.mem block_labels block.label then
        add_error ("duplicate block: " ^ block.label)
      else
        Hashtbl.add block_labels block.label block
    ) function_def.blocks;
    let seen_values = Hashtbl.create 64 in
    let value_types = Hashtbl.create 64 in
    List.iter (fun parameter ->
      if Hashtbl.mem seen_values parameter.value then
        add_error (Printf.sprintf "duplicate parameter %%v%d" parameter.value)
      else begin
        Hashtbl.add seen_values parameter.value ();
        Hashtbl.add value_types parameter.value parameter.ty
      end
    ) function_def.parameters;
    List.iter (fun block ->
      List.iter (fun (value, _ty) ->
        if Hashtbl.mem seen_values value then
          add_error (Printf.sprintf "duplicate block parameter %%v%d" value)
        else
          Hashtbl.add seen_values value ()
      ) block.params
    ) function_def.blocks;
    let verify_target label arguments =
      match Hashtbl.find_opt block_labels label with
      | None -> add_error ("unknown block: " ^ label)
      | Some target ->
          if List.length target.params <> List.length arguments then
            add_error (Printf.sprintf "block %s: expected %d arguments, got %d"
              label (List.length target.params) (List.length arguments))
          else
            List.iter2 (fun (_, expected_type) argument ->
              verify_operand value_types argument expected_type ("branch to " ^ label)
            ) target.params arguments
    in
    List.iter (fun block ->
      List.iter (fun (value, ty) ->
        if not (Hashtbl.mem value_types value) then
          Hashtbl.add value_types value ty
      ) block.params;
      List.iter (verify_instruction value_types) block.instructions;
      match block.terminator with
      | Jump (label, arguments) -> verify_target label arguments
      | Branch (condition, (then_label, then_arguments), (else_label, else_arguments)) ->
          verify_operand value_types condition Bool "branch condition";
          verify_target then_label then_arguments;
          verify_target else_label else_arguments
      | Switch (value, cases, (default_label, default_arguments)) ->
          let switch_type = operand_type value_types value in
          (match switch_type with
           | Some type_value when is_switch_type type_value ->
               verify_operand value_types value type_value "switch value"
           | Some type_value ->
               add_error (Printf.sprintf "switch does not support %s values"
                 (ty_to_string type_value))
           | None ->
               add_error "switch value has no scalar type");
          List.iter (fun (case_value, label, arguments) ->
            (match switch_type, operand_type value_types case_value with
             | Some expected_type, Some actual_type
               when equal_ty expected_type actual_type ->
                 verify_operand value_types case_value expected_type "switch case"
             | Some expected_type, Some actual_type ->
                 add_error (Printf.sprintf
                   "switch case type %s does not match switch value type %s"
                   (ty_to_string actual_type) (ty_to_string expected_type))
             | _ ->
                 add_error "switch case has no type");
            verify_target label arguments
          ) cases;
          verify_target default_label default_arguments
      | Return None ->
          if not (equal_ty function_def.return_type Unit) then
            add_error ("function " ^ function_def.name ^ " must return a value")
      | Return (Some value) ->
          verify_operand value_types value function_def.return_type "return value"
      | Unreachable -> ()
    ) function_def.blocks
  in
  List.iter verify_function module_.functions;
  List.rev !errors
