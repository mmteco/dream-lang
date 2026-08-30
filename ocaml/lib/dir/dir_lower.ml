open Ast
open Dir
open Dir_lower_types

let lower_named_function_value context enclosing_builder name signature =
  let adapter_number = !(context.lambda_counter) in
  context.lambda_counter := adapter_number + 1;
  let adapter_name = Printf.sprintf "__dir_function_adapter_%d" adapter_number in
  let parameter_types = signature.parameter_types in
  let environment_type = ClosureEnv [] in
  let adapter_builder = new_function adapter_name signature.return_type
    (environment_type :: parameter_types) in
  let arguments = List.mapi (fun index parameter_type ->
    let value = index + 2 in
    Value value, parameter_type
  ) parameter_types in
  let argument_operands = List.map fst arguments in
  let argument_types = List.map snd arguments in
  let result_value = match signature.return_type with
    | Unit -> None
    | _ -> Some (fresh_value adapter_builder)
  in
  emit adapter_builder (Call (result_value, signature.return_type, name,
    argument_types, argument_operands));
  let return_operand = match result_value with
    | Some value -> Some (Value value)
    | None -> None
  in
  terminate adapter_builder (Return return_operand);
  let adapter_parameters = { Dir.value = 1; name = "__closure_environment";
                              ty = environment_type } ::
    List.mapi (fun index (parameter_name, parameter_type) ->
      { Dir.value = index + 2; name = parameter_name; ty = parameter_type }
    ) (List.mapi (fun index parameter_type ->
      Printf.sprintf "argument_%d" index, parameter_type
    ) parameter_types)
  in
  let adapter = finish_function adapter_builder adapter_parameters in
  context.extra_functions := adapter :: !(context.extra_functions);
  let closure_type = Func (parameter_types, signature.return_type) in
  let closure_value = fresh_value enclosing_builder in
  emit enclosing_builder (MakeClosure (closure_value, closure_type, adapter_name, [], []));
  { operand = Value closure_value; ty = closure_type }

let binop_of_ast position = function
  | Ast.Add -> Dir.Add
  | Ast.Sub -> Dir.Sub
  | Ast.Mul -> Dir.Mul
  | Ast.Div -> Dir.Div
  | Ast.Mod -> Dir.Mod
  | Ast.BitAnd -> Dir.BitAnd
  | Ast.BitOr -> Dir.BitOr
  | Ast.BitXor -> Dir.BitXor
  | Ast.Shl -> Dir.Shl
  | Ast.Shr -> Dir.Shr
  | Ast.And -> Dir.And
  | Ast.Or -> Dir.Or
  | Ast.FloorDiv | Ast.Pow | Ast.Eq | Ast.Neq | Ast.Lt | Ast.Gt | Ast.Lte | Ast.Gte | Ast.In ->
      fail_at position "operation is not an LLVM binary instruction"

let compare_of_ast = function
  | Ast.Eq -> Dir.Eq
  | Ast.Neq -> Dir.Ne
  | Ast.Lt -> Dir.Lt
  | Ast.Gt -> Dir.Gt
  | Ast.Lte -> Dir.Le
  | Ast.Gte -> Dir.Ge
  | Ast.Add | Ast.Sub | Ast.Mul | Ast.Div | Ast.FloorDiv | Ast.Mod | Ast.Pow
  | Ast.BitAnd | Ast.BitOr | Ast.BitXor | Ast.Shl | Ast.Shr
  | Ast.And | Ast.Or | Ast.In -> assert false

let lower_empty_list function_builder expected_type =
  let element_type = match expected_type with
    | Some (List element_type) -> element_type
    | _ -> I32
  in
  let value = fresh_value function_builder in
  emit function_builder (ListCreate (value, element_type, []));
  { operand = Value value; ty = List element_type }

let rec lower_method_call context function_builder environment object_value method_name
    arguments position =
  let struct_name = match object_value.ty with
    | Struct (name, _) -> name
    | Enum (name, _) -> name
    | _ -> fail_at position "method call requires a struct value"
  in
  let method_key = struct_name ^ "." ^ method_name in
  let lowered_arguments = List.map
    (lower_expr context function_builder environment) arguments in
  let method_binding = match Hashtbl.find_all context.method_signatures method_key with
    | [] -> fail_at position ("unknown struct method " ^ method_key)
    | bindings ->
        let is_matching binding =
          match binding.signature.parameter_types with
          | _ :: parameter_types ->
              List.length parameter_types = List.length lowered_arguments &&
              List.for_all2 (fun expected actual -> Dir.equal_ty expected actual.ty)
                parameter_types lowered_arguments
          | [] -> false
        in
        (match List.find_opt is_matching bindings with
         | Some binding -> binding
         | None -> fail_at position ("no matching overload for method " ^ method_key))
  in
  let expected_argument_types = match method_binding.signature.parameter_types with
    | _ :: parameter_types -> parameter_types
    | [] -> fail_at position ("method " ^ method_key ^ " has no self parameter")
  in
  let coerced_arguments = List.map2 (fun actual expected ->
    coerce_value context function_builder position expected actual
  ) lowered_arguments expected_argument_types in
  let argument_types = object_value.ty ::
    List.map (fun argument -> argument.ty) coerced_arguments in
  let argument_operands = object_value.operand ::
    List.map (fun argument -> argument.operand) coerced_arguments in
  let result_value = match method_binding.signature.return_type with
    | Unit -> None
    | _ -> Some (fresh_value function_builder)
  in
  emit function_builder (Call (result_value, method_binding.signature.return_type,
    method_binding.function_name, argument_types, argument_operands));
  let operand = match result_value with
    | Some value -> Value value
    | None -> Int 0
  in
  { operand; ty = method_binding.signature.return_type }

and lower_string_method context function_builder environment object_value method_name
    arguments position =
  let lowered_arguments = List.map
    (lower_expr context function_builder environment) arguments in
  let unary_str_call function_name return_type =
    let value = fresh_value function_builder in
    emit function_builder (Call (Some value, return_type, function_name,
      [Str], [object_value.operand]));
    { operand = Value value; ty = return_type }
  in
  let binary_str_call function_name return_type =
    match lowered_arguments with
    | [argument] ->
        expect_type position Str argument.ty (method_name ^ " argument");
        let value = fresh_value function_builder in
        emit function_builder (Call (Some value, return_type, function_name,
          [Str; Str], [object_value.operand; argument.operand]));
        { operand = Value value; ty = return_type }
    | _ -> fail_at position (method_name ^ " expects one argument")
  in
  let char_test_call function_name =
    match lowered_arguments with
    | [index] ->
        expect_type position I32 index.ty (method_name ^ " index");
        let rune = fresh_value function_builder in
        emit function_builder (Call (Some rune, I32, "__c_utf8_rune_at",
          [Str; I32], [object_value.operand; index.operand]));
        let value = fresh_value function_builder in
        emit function_builder (Call (Some value, Bool, function_name,
          [I32], [Value rune]));
        { operand = Value value; ty = Bool }
    | _ -> fail_at position (method_name ^ " expects one argument")
  in
  match method_name with
  | "length" -> unary_str_call "string_length" I32
  | "upper" -> unary_str_call "string_upper" Str
  | "lower" -> unary_str_call "string_lower" Str
  | "strip" -> unary_str_call "string_strip" Str
  | "find" -> binary_str_call "string_find" I32
  | "startswith" -> binary_str_call "string_starts_with" Bool
  | "endswith" -> binary_str_call "string_ends_with" Bool
  | "isdigit" -> char_test_call "string_is_digit"
  | "isalpha" -> char_test_call "string_is_alpha"
  | "isspace" -> char_test_call "string_is_whitespace"
  | "encode" -> unary_str_call "__c_str_to_bytes" Bytes
  | "replace" ->
      (match lowered_arguments with
       | [old_text; new_text] ->
           expect_type position Str old_text.ty "replace old";
           expect_type position Str new_text.ty "replace new";
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, Str, "string_replace",
             [Str; Str; Str],
             [object_value.operand; old_text.operand; new_text.operand]));
           { operand = Value value; ty = Str }
       | _ -> fail_at position "replace expects two arguments")
  | "split" ->
      (match lowered_arguments with
       | [separator] ->
           expect_type position Str separator.ty "split separator";
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, List Str, "string_split",
             [Str; Str], [object_value.operand; separator.operand]));
           { operand = Value value; ty = List Str }
       | _ -> fail_at position "split expects one argument")
  | "join" ->
      (match lowered_arguments with
       | [items] ->
           expect_type position (List Str) items.ty "join items";
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, Str, "string_join",
             [List Str; Str], [items.operand; object_value.operand]));
           { operand = Value value; ty = Str }
       | _ -> fail_at position "join expects one argument")
  | _ -> fail_at position ("unsupported string method " ^ method_name)

and lower_bytes_method context function_builder environment object_value method_name
    arguments position =
  let lowered_arguments = List.map
    (lower_expr context function_builder environment) arguments in
  match method_name, lowered_arguments with
  | "length", [] ->
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_bytes_length",
        [Bytes], [object_value.operand]));
      { operand = Value value; ty = I32 }
  | "get", [index] ->
      expect_type position I32 index.ty "bytes.get index";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_bytes_get",
        [Bytes; I32], [object_value.operand; index.operand]));
      { operand = Value value; ty = I32 }
  | "slice", [start; end_] ->
      expect_type position I32 start.ty "bytes.slice start";
      expect_type position I32 end_.ty "bytes.slice end";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_bytes_slice",
        [Bytes; I32; I32], [object_value.operand; start.operand; end_.operand]));
      { operand = Value value; ty = Bytes }
  | "decode", [] ->
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_bytes_to_str",
        [Bytes], [object_value.operand]));
      { operand = Value value; ty = Str }
  | _ -> fail_at position ("unsupported bytes method " ^ method_name)

and lower_interface_call context function_builder environment object_value method_name
    arguments position =
  let interface_type, methods = match object_value.ty with
    | Interface (interface_name, methods) ->
        Interface (interface_name, methods), methods
    | actual_type -> fail_at position (Printf.sprintf
        "interface method call requires an interface value, got %s"
        (Dir.ty_to_string actual_type))
  in
  let method_index, parameter_types, return_type = match List.find_index
      (fun (candidate_name, _, _) -> candidate_name = method_name) methods with
    | None -> fail_at position (Printf.sprintf "interface has no method %s" method_name)
    | Some method_index ->
        let (_, parameter_types, return_type) = List.nth methods method_index in
        method_index, parameter_types, return_type
  in
  if List.length arguments <> List.length parameter_types then
    fail_at position (Printf.sprintf "interface method %s expects %d arguments, got %d"
      method_name (List.length parameter_types) (List.length arguments));
  let lowered_arguments = List.map2 (fun argument expected_type ->
    let value = lower_expr context function_builder environment argument in
    coerce_value context function_builder position expected_type value
  ) arguments parameter_types in
  let result_value = match return_type with
    | Unit -> None
    | _ -> Some (fresh_value function_builder)
  in
  emit function_builder (InterfaceCall (result_value, return_type, interface_type,
    object_value.operand, method_name, method_index, parameter_types,
    List.map (fun value -> value.operand) lowered_arguments));
  let operand = match result_value with
    | Some value -> Value value
    | None -> Int 0
  in
  { operand; ty = return_type }

and coerce_value context function_builder position expected_type value =
  if Dir.equal_ty expected_type value.ty then
    value
  else
    match expected_type, value.ty with
    | Union element_types, actual_type ->
        if not (List.exists (Dir.equal_ty actual_type) element_types) then
          fail_at position (Printf.sprintf
            "type %s is not a member of union %s"
            (Dir.ty_to_string actual_type) (Dir.ty_to_string expected_type));
        let union_value = fresh_value function_builder in
        let create_name, argument_types = match actual_type with
          | I32 -> "union_create_int", [I32]
          | F64 -> "union_create_float", [F64]
          | Str -> "union_create_string", [Str]
          | Bool -> "union_create_bool", [Bool]
          | Bytes -> "union_create_bytes", [Bytes]
          | _ -> fail_at position (Printf.sprintf
              "union boxing supports int, float, str, bool and bytes, got %s"
              (Dir.ty_to_string actual_type))
        in
        emit function_builder (Call (Some union_value, expected_type, create_name,
          argument_types, [value.operand]));
        { operand = Value union_value; ty = expected_type }
    | Interface (interface_name, _), (Struct (struct_name, _) | Enum (struct_name, _)) ->
        let method_names = match Hashtbl.find_opt context.interface_implementations
            (interface_name ^ "::" ^ struct_name) with
          | Some method_names -> method_names
          | None -> fail_at position (Printf.sprintf
              "type %s does not implement interface %s"
              struct_name interface_name)
        in
        let object_operand = match value.ty with
          | Enum (_, variants) when List.for_all (fun (_, payload_types) -> payload_types = []) variants ->
              (* 无载荷枚举是 i32 tag，装箱为 %enum_t* 再构造接口值 *)
              let tag = match value.operand with
                | Int tag -> tag
                | _ -> fail_at position "simple enum interface value requires an integer tag"
              in
              let boxed = fresh_value function_builder in
              emit function_builder (EnumCreateSimple (boxed, value.ty, tag));
              record_interface_box function_builder boxed;
              Value boxed
          | Struct _ ->
              (* 结构体装箱为引用计数管理的堆拷贝 *)
              let boxed = fresh_value function_builder in
              emit function_builder (InterfaceBox (boxed, value.ty, value.operand));
              record_interface_box function_builder boxed;
              Value boxed
          | _ -> value.operand
        in
        let interface_value = fresh_value function_builder in
        emit function_builder (MakeInterface (interface_value, expected_type,
          value.ty, object_operand, method_names));
        { operand = Value interface_value; ty = expected_type }
    | _ ->
        expect_type position expected_type value.ty "value conversion";
        value

and lower_list_contains function_builder collection needle element_type position =
  let compare_item item =
    match element_type with
    | I32 | Bool ->
        let result = fresh_value function_builder in
        emit function_builder (Compare (result, Eq, Value item, needle.operand));
        result
    | Str ->
        let comparison = fresh_value function_builder in
        emit function_builder (StringCompare (comparison, Value item, needle.operand));
        let result = fresh_value function_builder in
        emit function_builder (Compare (result, Eq, Value comparison, Int 0));
        result
    | _ -> fail_at position (Printf.sprintf
        "in does not support list elements of type %s" (Dir.ty_to_string element_type))
  in
  let condition_label = fresh_label function_builder "contains_condition" in
  let body_label = fresh_label function_builder "contains_body" in
  let step_label = fresh_label function_builder "contains_step" in
  let exit_label = fresh_label function_builder "contains_exit" in
  List.iter (create_block function_builder)
    [condition_label; body_label; step_label; exit_label];
  terminate function_builder (Jump (condition_label, [Int 0]));
  switch_to function_builder condition_label;
  let condition_index = fresh_value function_builder in
  set_block_params function_builder condition_label [(condition_index, I32)];
  let length = fresh_value function_builder in
  emit function_builder (ListLength (length, collection.operand));
  let has_more = fresh_value function_builder in
  emit function_builder (Compare (has_more, Lt, Value condition_index, Value length));
  terminate function_builder (Branch (Value has_more,
    (body_label, [Value condition_index]), (exit_label, [Bool false])));
  switch_to function_builder body_label;
  let body_index = fresh_value function_builder in
  set_block_params function_builder body_label [(body_index, I32)];
  let item = fresh_value function_builder in
  emit function_builder (ListGet (item, collection.operand, Value body_index));
  let matches = compare_item item in
  terminate function_builder (Branch (Value matches,
    (exit_label, [Bool true]), (step_label, [Value body_index])));
  switch_to function_builder step_label;
  let step_index = fresh_value function_builder in
  set_block_params function_builder step_label [(step_index, I32)];
  let next_index = fresh_value function_builder in
  emit function_builder (Binop (next_index, I32, Add, Value step_index, Int 1));
  terminate function_builder (Jump (condition_label, [Value next_index]));
  switch_to function_builder exit_label;
  let result = fresh_value function_builder in
  set_block_params function_builder exit_label [(result, Bool)];
  { operand = Value result; ty = Bool }

and lower_bytes_contains function_builder collection needle position =
  expect_type position I32 needle.ty "bytes membership value";
  let condition_label = fresh_label function_builder "contains_condition" in
  let body_label = fresh_label function_builder "contains_body" in
  let step_label = fresh_label function_builder "contains_step" in
  let exit_label = fresh_label function_builder "contains_exit" in
  List.iter (create_block function_builder)
    [condition_label; body_label; step_label; exit_label];
  terminate function_builder (Jump (condition_label, [Int 0]));
  switch_to function_builder condition_label;
  let condition_index = fresh_value function_builder in
  set_block_params function_builder condition_label [(condition_index, I32)];
  let length = fresh_value function_builder in
  emit function_builder (Call (Some length, I32, "__c_bytes_length",
    [Bytes], [collection.operand]));
  let has_more = fresh_value function_builder in
  emit function_builder (Compare (has_more, Lt, Value condition_index, Value length));
  terminate function_builder (Branch (Value has_more,
    (body_label, [Value condition_index]), (exit_label, [Bool false])));
  switch_to function_builder body_label;
  let body_index = fresh_value function_builder in
  set_block_params function_builder body_label [(body_index, I32)];
  let item = fresh_value function_builder in
  emit function_builder (Call (Some item, I32, "__c_bytes_get",
    [Bytes; I32], [collection.operand; Value body_index]));
  let matches = fresh_value function_builder in
  emit function_builder (Compare (matches, Eq, Value item, needle.operand));
  terminate function_builder (Branch (Value matches,
    (exit_label, [Bool true]), (step_label, [Value body_index])));
  switch_to function_builder step_label;
  let step_index = fresh_value function_builder in
  set_block_params function_builder step_label [(step_index, I32)];
  let next_index = fresh_value function_builder in
  emit function_builder (Binop (next_index, I32, Add, Value step_index, Int 1));
  terminate function_builder (Jump (condition_label, [Value next_index]));
  switch_to function_builder exit_label;
  let result = fresh_value function_builder in
  set_block_params function_builder exit_label [(result, Bool)];
  { operand = Value result; ty = Bool }

and lower_iterator_contains context function_builder environment iterable needle element_type position =
  let iterator = match iterable.ty with
    | Interface ("Iterator", _) -> iterable
    | Interface ("Iterable", _) ->
        lower_interface_call context function_builder environment iterable "iter" [] position
    | Struct (struct_name, _) when Hashtbl.mem context.method_signatures
        (struct_name ^ ".iter") ->
        lower_method_call context function_builder environment iterable "iter" [] position
    | Struct (struct_name, _) when Hashtbl.mem context.method_signatures
        (struct_name ^ ".has_next") && Hashtbl.mem context.method_signatures
        (struct_name ^ ".next") -> iterable
    | actual_type -> fail_at position (Printf.sprintf
        "in requires Iterator or Iterable, got %s" (Dir.ty_to_string actual_type))
  in
  let compare_item item =
    match element_type with
    | I32 | Bool | F64 ->
        let result = fresh_value function_builder in
        emit function_builder (Compare (result, Eq, item, needle.operand));
        result
    | Str ->
        let comparison = fresh_value function_builder in
        emit function_builder (StringCompare (comparison, item, needle.operand));
        let result = fresh_value function_builder in
        emit function_builder (Compare (result, Eq, Value comparison, Int 0));
        result
    | _ -> fail_at position (Printf.sprintf
        "in does not support Iterator elements of type %s" (Dir.ty_to_string element_type))
  in
  let call_iterator_method method_name =
    match iterator.ty with
    | Interface _ ->
        lower_interface_call context function_builder environment iterator method_name [] position
    | Struct _ ->
        lower_method_call context function_builder environment iterator method_name [] position
    | _ -> fail_at position "invalid iterator value"
  in
  let condition_label = fresh_label function_builder "contains_condition" in
  let body_label = fresh_label function_builder "contains_body" in
  let step_label = fresh_label function_builder "contains_step" in
  let exit_label = fresh_label function_builder "contains_exit" in
  List.iter (create_block function_builder)
    [condition_label; body_label; step_label; exit_label];
  terminate function_builder (Jump (condition_label, []));
  switch_to function_builder condition_label;
  let has_next = call_iterator_method "has_next" in
  expect_type position Bool has_next.ty "Iterator.has_next";
  terminate function_builder (Branch (has_next.operand,
    (body_label, []), (exit_label, [Bool false])));
  switch_to function_builder body_label;
  let item = call_iterator_method "next" in
  let matches = compare_item item.operand in
  terminate function_builder (Branch (Value matches,
    (exit_label, [Bool true]), (step_label, [])));
  switch_to function_builder step_label;
  terminate function_builder (Jump (condition_label, []));
  switch_to function_builder exit_label;
  let result = fresh_value function_builder in
  set_block_params function_builder exit_label [(result, Bool)];
  { operand = Value result; ty = Bool }

and lower_expr context function_builder environment expression =
  match expression with
  | EInt (value, _) -> { operand = Int value; ty = I32 }
  | EFloat (value, _) -> { operand = Float value; ty = F64 }
  | EBool (value, _) -> { operand = Bool value; ty = Bool }
  | EString (value, _) -> { operand = String value; ty = Str }
  | ERune (value, _) -> { operand = Int value; ty = I32 }
  | EByte (value, _) -> { operand = Int value; ty = I32 }
  | EVar (name, position) ->
      (match Hashtbl.find_opt environment name with
       | Some value -> value
       | None ->
           (match List.find_opt (fun (global_name, _) -> global_name = name)
              !(context.globals) with
            | Some (_, global_type) ->
                let value = fresh_value function_builder in
                emit function_builder (GlobalLoad (value, global_type, name));
                { operand = Value value; ty = global_type }
            | None ->
                (match Hashtbl.find_opt context.signatures name with
                 | Some signature -> lower_named_function_value context function_builder
                     name signature
                 | None -> fail_at position ("unknown variable " ^ name))))
  | EBinOp (left_expression, operation, right_expression, position) ->
      let left = lower_expr context function_builder environment left_expression in
      let right = lower_expr context function_builder environment right_expression in
      let reflected_method_name = match operation with
        | Add -> "radd"
        | Sub -> "rsub"
        | Mul -> "rmul"
        | Div -> "rdiv"
        | FloorDiv -> "rfloordiv"
        | Mod -> "rmod"
        | Pow -> "rpow"
        | BitAnd -> "rbitand"
        | BitOr -> "rbitor"
        | BitXor -> "rbitxor"
        | Shl -> "rshl"
        | Shr -> "rshr"
        | _ -> ""
      in
      let has_reflected_method = match right.ty with
        | Struct (name, _) | Enum (name, _) ->
            Hashtbl.mem context.method_signatures (name ^ "." ^ reflected_method_name)
        | Interface (_, methods) ->
            List.exists (fun (name, _, _) -> name = reflected_method_name) methods
        | _ -> false
      in
      let lower_reflected () = match right.ty with
        | Interface _ ->
            lower_interface_call context function_builder environment right
              reflected_method_name [left_expression] position
        | Struct _ | Enum _ ->
            lower_method_call context function_builder environment right
              reflected_method_name [left_expression] position
        | _ -> fail_at position "right operator requires an overloadable value"
      in
      (match operation with
       | Add | Sub | Mul | Div | FloorDiv | Mod | Pow
       | BitAnd | BitOr | BitXor | Shl | Shr ->
           (match left.ty with
            | _ when has_reflected_method &&
                not (match left.ty with
                     | Struct (name, _) | Enum (name, _) ->
                         Hashtbl.mem context.method_signatures
                           (name ^ "." ^ Env.binop_to_method_name operation)
                     | _ -> false) ->
                lower_reflected ()
            | Str when operation = Add ->
                let right = match right.ty with
                  | Str -> right
                  | Interface _ ->
                      lower_interface_call context function_builder environment right "to_string" [] position
                  | Struct _ | Enum _ ->
                      lower_method_call context function_builder environment right "to_string" [] position
                  | _ -> fail_at position "string concatenation requires a string or Display value"
                in
                let value = fresh_value function_builder in
                emit function_builder (Call (Some value, Str, "string_concat",
                  [Str; Str], [left.operand; right.operand]));
                { operand = Value value; ty = Str }
            | List I32 when operation = Add ->
                let value = fresh_value function_builder in
                emit function_builder (ListConcat (value, left.operand, right.operand));
                { operand = Value value; ty = List I32 }
            | I32 | F64 ->
                expect_type position left.ty right.ty "binary operands";
                (match operation with
                 | FloorDiv ->
                     let function_name = if Dir.equal_ty left.ty F64
                       then "float_floordiv" else "int_floordiv" in
                     let value = fresh_value function_builder in
                     emit function_builder (Call (Some value, left.ty, function_name,
                       [left.ty; left.ty], [left.operand; right.operand]));
                     { operand = Value value; ty = left.ty }
                 | Pow ->
                     let function_name = if Dir.equal_ty left.ty F64
                       then "float_pow" else "int_pow" in
                     let value = fresh_value function_builder in
                     emit function_builder (Call (Some value, left.ty, function_name,
                       [left.ty; left.ty], [left.operand; right.operand]));
                     { operand = Value value; ty = left.ty }
                 | _ ->
                     let value = fresh_value function_builder in
                     emit function_builder (Binop (value, left.ty,
                       binop_of_ast position operation, left.operand, right.operand));
                     { operand = Value value; ty = left.ty })
            | Struct _ | Enum _ ->
                let method_name = Env.binop_to_method_name operation in
                lower_method_call context function_builder environment left method_name
                  [right_expression] position
            | _ -> fail_at position "arithmetic operand must be numeric")
       | And | Or ->
           expect_type position Bool left.ty "boolean operand";
           let value = fresh_value function_builder in
           emit function_builder (Binop (value, Bool, binop_of_ast position operation,
             left.operand, right.operand));
           { operand = Value value; ty = Bool }
       | In ->
           (match left.ty, right.ty with
            | Str, Str ->
                let value = fresh_value function_builder in
                emit function_builder (Call (Some value, I32, "string_find",
                  [Str; Str], [right.operand; left.operand]));
                let result = fresh_value function_builder in
                emit function_builder (Compare (result, Ge, Value value, Int 0));
                { operand = Value result; ty = Bool }
            | _, List element_type ->
                lower_list_contains function_builder right left element_type position
            | (I32 | Bool), Bytes ->
                lower_bytes_contains function_builder right left position
            | _, Interface ("Iterator", methods) ->
                let element_type = match List.find_opt
                    (fun (name, _, _) -> name = "next") methods with
                  | Some (_, _, return_type) -> return_type
                  | None -> fail_at position "Iterator.next method is missing"
                in
                lower_iterator_contains context function_builder environment right left
                  element_type position
            | _, Interface ("Iterable", methods) ->
                let iterator_type = match List.find_opt
                    (fun (name, _, _) -> name = "iter") methods with
                  | Some (_, _, return_type) -> return_type
                  | None -> fail_at position "Iterable.iter method is missing"
                in
                let element_type = match iterator_type with
                  | Interface (_, iterator_methods) ->
                      (match List.find_opt
                         (fun (name, _, _) -> name = "next") iterator_methods with
                       | Some (_, _, return_type) -> return_type
                       | None -> fail_at position "Iterator.next method is missing")
                  | _ -> fail_at position "Iterable.iter must return Iterator"
                in
                lower_iterator_contains context function_builder environment right left
                  element_type position
            | _, Struct (struct_name, _) when Hashtbl.mem context.method_signatures
                (struct_name ^ ".iter") || Hashtbl.mem context.method_signatures
                (struct_name ^ ".has_next") && Hashtbl.mem context.method_signatures
                (struct_name ^ ".next") ->
                let element_type = match right.ty with
                  | Struct (name, _) ->
                      (match Hashtbl.find_all context.method_signatures (name ^ ".next") with
                       | binding :: _ -> binding.signature.return_type
                       | [] ->
                           (match Hashtbl.find_all context.method_signatures (name ^ ".iter") with
                            | binding :: _ ->
                                (match binding.signature.return_type with
                                 | Interface (_, methods) ->
                                     (match List.find_opt
                                        (fun (method_name, _, _) -> method_name = "next") methods with
                                      | Some (_, _, return_type) -> return_type
                                      | None -> fail_at position "Iterator.next method is missing")
                                 | _ -> fail_at position "Iterable.iter must return Iterator")
                            | [] -> fail_at position "Iterator.next method is missing"))
                  | _ -> fail_at position "invalid iterator type"
                in
                lower_iterator_contains context function_builder environment right left
                  element_type position
            | _, Struct _ ->
                lower_method_call context function_builder environment right "contains"
                  [left_expression] position
            | _ -> fail_at position "in supports str, list, bytes or a Contains implementation")
       | Eq | Neq | Lt | Gt | Lte | Gte ->
           (match left.ty with
            | I32 | F64 | Bool ->
                let value = fresh_value function_builder in
                emit function_builder (Compare (value, compare_of_ast operation,
                  left.operand, right.operand));
                { operand = Value value; ty = Bool }
            | Str ->
                let comparison = fresh_value function_builder in
                emit function_builder (StringCompare (comparison,
                  left.operand, right.operand));
                let value = fresh_value function_builder in
                emit function_builder (Compare (value, compare_of_ast operation,
                  Value comparison, Int 0));
                { operand = Value value; ty = Bool }
            | _ -> fail_at position "DIR comparisons support int, float, bool and str"))
  | EUnOp (Neg, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      (match value.ty with
       | I32 | F64 ->
           let result = fresh_value function_builder in
           let zero = if Dir.equal_ty value.ty F64 then Float 0.0 else Int 0 in
           emit function_builder (Binop (result, value.ty, Sub, zero, value.operand));
           { operand = Value result; ty = value.ty }
       | Struct _ ->
           lower_method_call context function_builder environment value "neg"
             [] position
       | _ -> fail_at position "negation operand must be int or float")
  | EUnOp (Pos, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      (match value.ty with
       | I32 | F64 -> value
       | Struct _ ->
           lower_method_call context function_builder environment value "pos"
             [] position
       | _ -> fail_at position "unary plus operand must be int or float")
  | EUnOp (Invert, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      (match value.ty with
       | I32 ->
           let result = fresh_value function_builder in
           emit function_builder (Binop (result, I32, BitXor,
             value.operand, Int (-1)));
           { operand = Value result; ty = I32 }
       | Struct _ ->
           lower_method_call context function_builder environment value "bitnot"
             [] position
       | _ -> fail_at position "bitwise not operand must be int")
  | EUnOp (Not, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      expect_type position Bool value.ty "not operand";
      let result = fresh_value function_builder in
      emit function_builder (Compare (result, Eq, value.operand, Bool false));
      { operand = Value result; ty = Bool }
  | ECall (EVar ("len", _), [argument], position) ->
      let lowered_argument = lower_expr context function_builder environment argument in
      (match lowered_argument.ty with
       | Str ->
           let value = fresh_value function_builder in
           emit function_builder (StringLength (value, lowered_argument.operand));
           { operand = Value value; ty = I32 }
       | List _ ->
           let value = fresh_value function_builder in
           emit function_builder (ListLength (value, lowered_argument.operand));
           { operand = Value value; ty = I32 }
       | Bytes ->
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, I32, "__c_bytes_length",
             [Bytes], [lowered_argument.operand]));
           { operand = Value value; ty = I32 }
       | Dict (_, _) ->
           let value = fresh_value function_builder in
           let size_name = match lowered_argument.ty with
             | Dict (I32, I32) -> "dream_dict_size_int_int"
             | Dict (I32, Str) -> "dream_dict_size_int_str"
             | Dict (Str, I32) -> "dream_dict_size_str_int"
             | Dict (Str, Str) -> "dream_dict_size_str_str"
             | _ -> fail_at position "DIR dict supports only int and str keys/values"
           in
           emit function_builder (Call (Some value, I32, size_name,
             [lowered_argument.ty], [lowered_argument.operand]));
           { operand = Value value; ty = I32 }
       | _ -> fail_at position "len expects a string, bytes, dict or list")
  | ECall (EVar ("dict_items", _), [argument], position) ->
      let lowered_argument = lower_expr context function_builder environment argument in
      let key_type, value_type = match lowered_argument.ty with
        | Dict (key_type, value_type) -> key_type, value_type
        | actual_type -> fail_at position (Printf.sprintf
            "dict_items expects a dict, got %s" (Dir.ty_to_string actual_type))
      in
      let element_type = Tuple [key_type; value_type] in
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, List element_type, "dict_items_tuples",
        [lowered_argument.ty], [lowered_argument.operand]));
      { operand = Value value; ty = List element_type }
  | ECall (EVar ("append", _), [collection; item], position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let element_type = match lowered_collection.ty with
        | List element_type -> element_type
        | _ -> I32
      in
      (match lowered_collection.ty with
       | List _ ->
           let lowered_item = lower_expr context function_builder environment item in
           expect_type position element_type lowered_item.ty "append value";
           emit function_builder (ListAppend (lowered_collection.operand, lowered_item.operand, element_type));
           { operand = Int 0; ty = Unit }
       | Struct _ ->
           lower_method_call context function_builder environment lowered_collection
             "append" [item] position
       | Interface _ ->
           lower_interface_call context function_builder environment lowered_collection
             "append" [item] position
       | actual_type -> fail_at position (Printf.sprintf
           "append collection: expected list or Append implementation, got %s"
           (Dir.ty_to_string actual_type)))
  | ECall (EVar ("argc", _), [], _)
  | ECall (EVar ("__c_process_arg_count", _), [], _) ->
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_process_arg_count", [], []));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("arg", _), [index], position)
  | ECall (EVar ("__c_process_arg", _), [index], position) ->
      let lowered_index = lower_expr context function_builder environment index in
      expect_type position I32 lowered_index.ty "__c_process_arg index";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_process_arg",
        [I32], [lowered_index.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar ("build", _), [llvm_path; output_path; optimized], position)
  | ECall (EVar ("__c_build_llvm", _), [llvm_path; output_path; optimized], position) ->
      let lowered_llvm_path = lower_expr context function_builder environment llvm_path in
      let lowered_output_path = lower_expr context function_builder environment output_path in
      let lowered_optimized = lower_expr context function_builder environment optimized in
      expect_type position Str lowered_llvm_path.ty "__c_build_llvm LLVM path";
      expect_type position Str lowered_output_path.ty "__c_build_llvm output path";
      expect_type position Bool lowered_optimized.ty "__c_build_llvm optimized flag";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_build_llvm",
        [Str; Str; Bool], [lowered_llvm_path.operand; lowered_output_path.operand; lowered_optimized.operand]));
      if match expression with ECall (EVar ("build", _), _, _) -> true | _ -> false then
        let status = fresh_value function_builder in
        emit function_builder (Compare (status, Ne, Value value, Int 0));
        { operand = Value status; ty = Bool }
      else
        { operand = Value value; ty = I32 }
  | ECall (EVar ("ord", _), [rune], position) ->
      let lowered_rune = lower_expr context function_builder environment rune in
      expect_type position I32 lowered_rune.ty "ord argument";
      lowered_rune
  | ECall (EVar ("__c_rune_to_int", _), [rune], position) ->
      let lowered_rune = lower_expr context function_builder environment rune in
      expect_type position I32 lowered_rune.ty "__c_rune_to_int argument";
      lowered_rune
  | ECall (EVar ("read", _), [path], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      expect_type position Str lowered_path.ty "read path";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_file_read",
        [Str], [lowered_path.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar ("__c_net_connect", _), [host; port], position) ->
      let lowered_host = lower_expr context function_builder environment host in
      let lowered_port = lower_expr context function_builder environment port in
      expect_type position Str lowered_host.ty "__c_net_connect host";
      expect_type position I32 lowered_port.ty "__c_net_connect port";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_net_connect",
        [Str; I32], [lowered_host.operand; lowered_port.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("__c_net_write", _), [fd; content], position) ->
      let lowered_fd = lower_expr context function_builder environment fd in
      let lowered_content = lower_expr context function_builder environment content in
      expect_type position I32 lowered_fd.ty "__c_net_write fd";
      expect_type position Str lowered_content.ty "__c_net_write content";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_net_write",
        [I32; Str], [lowered_fd.operand; lowered_content.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("__c_net_read", _), [fd; size], position) ->
      let lowered_fd = lower_expr context function_builder environment fd in
      let lowered_size = lower_expr context function_builder environment size in
      expect_type position I32 lowered_fd.ty "__c_net_read fd";
      expect_type position I32 lowered_size.ty "__c_net_read size";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_net_read",
        [I32; I32], [lowered_fd.operand; lowered_size.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar ("__c_net_close", _), [fd], position) ->
      let lowered_fd = lower_expr context function_builder environment fd in
      expect_type position I32 lowered_fd.ty "__c_net_close fd";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bool, "__c_net_close",
        [I32], [lowered_fd.operand]));
      { operand = Value value; ty = Bool }
  | ECall (EVar ("__c_http_request", _), [method_; url; headers; body], position) ->
      let lowered_method = lower_expr context function_builder environment method_ in
      let lowered_url = lower_expr context function_builder environment url in
      let lowered_headers = lower_expr context function_builder environment headers in
      let lowered_body = lower_expr context function_builder environment body in
      expect_type position Str lowered_method.ty "__c_http_request method";
      expect_type position Str lowered_url.ty "__c_http_request URL";
      expect_type position Str lowered_headers.ty "__c_http_request headers";
      expect_type position Str lowered_body.ty "__c_http_request body";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_http_request",
        [Str; Str; Str; Str], [lowered_method.operand; lowered_url.operand;
          lowered_headers.operand; lowered_body.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar ("__c_file_read_bytes", _), [path], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      expect_type position Str lowered_path.ty "__c_file_read_bytes path";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_file_read_bytes",
        [Str], [lowered_path.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar ("__c_file_write_bytes", _), [path; bytes], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      let lowered_bytes = lower_expr context function_builder environment bytes in
      expect_type position Str lowered_path.ty "__c_file_write_bytes path";
      let bytes_operand = match lowered_bytes.ty with
        | Bytes -> lowered_bytes.operand
        | List I32 ->
            let converted = fresh_value function_builder in
            emit function_builder (Call (Some converted, Bytes, "__c_bytes_from_array",
              [List I32], [lowered_bytes.operand]));
            Value converted
        | _ -> fail_at position "__c_file_write_bytes bytes must be bytes or list<i32>"
      in
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_file_write_bytes",
        [Str; Bytes], [lowered_path.operand; bytes_operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("__c_bytes_length", _), [bytes], position) ->
      let lowered_bytes = lower_expr context function_builder environment bytes in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_length bytes";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_bytes_length",
        [Bytes], [lowered_bytes.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("__c_bytes_get", _), [bytes; index], position) ->
      let lowered_bytes = lower_expr context function_builder environment bytes in
      let lowered_index = lower_expr context function_builder environment index in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_get bytes";
      expect_type position I32 lowered_index.ty "__c_bytes_get index";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_bytes_get",
        [Bytes; I32], [lowered_bytes.operand; lowered_index.operand]));
      { operand = Value value; ty = I32 }
  | EStructLiteral (struct_name, field_initializers, position) ->
      let struct_type = context.resolve_struct struct_name in
      let fields = match struct_type with
        | Struct (_, fields) -> fields
        | _ -> fail_at position ("unknown struct " ^ struct_name)
      in
      let lowered_fields = List.map (fun (field_name, field_type) ->
        match List.assoc_opt field_name field_initializers with
        | None -> fail_at position ("missing field " ^ field_name ^ " in " ^ struct_name)
        | Some expression ->
            let value = lower_expr context function_builder environment expression in
            expect_type position field_type value.ty ("struct field " ^ field_name);
            value.operand
      ) fields in
      let value = fresh_value function_builder in
      emit function_builder (StructCreate (value, struct_name, fields, lowered_fields));
      { operand = Value value; ty = struct_type }
  | EAttr (object_expression, field_name, position)
  | EStructAccess (object_expression, field_name, position) ->
      let object_value = lower_expr context function_builder environment object_expression in
      let fields = match object_value.ty with
        | Struct (_, fields) -> fields
        | _ -> fail_at position "field access requires a struct value"
      in
      let field_index, field_type = match List.find_index
          (fun (name, _) -> name = field_name) fields with
        | None -> fail_at position ("unknown struct field " ^ field_name)
        | Some index -> index, snd (List.nth fields index)
      in
      let value = fresh_value function_builder in
      emit function_builder (StructGet (value, field_type, object_value.operand, field_index));
      { operand = Value value; ty = field_type }
  | ECall (EVar ("__c_bytes_slice", _), [bytes; start; end_], position) ->
      let lowered_bytes = lower_expr context function_builder environment bytes in
      let lowered_start = lower_expr context function_builder environment start in
      let lowered_end = lower_expr context function_builder environment end_ in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_slice bytes";
      expect_type position I32 lowered_start.ty "__c_bytes_slice start";
      expect_type position I32 lowered_end.ty "__c_bytes_slice end";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_bytes_slice",
        [Bytes; I32; I32], [lowered_bytes.operand; lowered_start.operand;
          lowered_end.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar ("__c_str_to_bytes", _), [text], position) ->
      let lowered_text = lower_expr context function_builder environment text in
      expect_type position Str lowered_text.ty "__c_str_to_bytes text";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_str_to_bytes",
        [Str], [lowered_text.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar ("__c_bytes_to_str", _), [bytes], position) ->
      let lowered_bytes = lower_expr context function_builder environment bytes in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_to_str bytes";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_bytes_to_str",
        [Bytes], [lowered_bytes.operand]));
      { operand = Value value; ty = Str }
  | ECall (EAttr (EVar (module_name, _), function_name, _), arguments, position)
      when StringSet.mem module_name context.module_aliases ->
      let signature = match Hashtbl.find_opt context.signatures function_name with
        | Some signature -> signature
        | None -> fail_at position ("unknown function " ^ module_name ^ "." ^ function_name)
      in
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      if List.length lowered_arguments <> List.length signature.parameter_types then
        fail_at position (Printf.sprintf "function %s.%s expects %d arguments, got %d"
          module_name function_name (List.length signature.parameter_types)
          (List.length lowered_arguments));
      let lowered_arguments = List.map2 (fun argument expected_type ->
        coerce_value context function_builder position expected_type argument
      ) lowered_arguments signature.parameter_types in
      let result_value = match signature.return_type with
        | Unit -> None
        | _ -> Some (fresh_value function_builder)
      in
      emit function_builder (Call (result_value, signature.return_type, function_name,
        signature.parameter_types, List.map (fun argument -> argument.operand) lowered_arguments));
      let operand = match result_value with
        | Some value -> Value value
        | None -> Int 0
      in
      { operand; ty = signature.return_type }
  | ECall (EVar ("__c_utf8_encode_rune", _), [rune], position) ->
      let lowered_rune = lower_expr context function_builder environment rune in
      expect_type position I32 lowered_rune.ty "__c_utf8_encode_rune rune";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_utf8_encode_rune",
        [I32], [lowered_rune.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar ("bytes_get", _), [buf; idx], position) ->
      let lowered_bytes = lower_expr context function_builder environment buf in
      let lowered_index = lower_expr context function_builder environment idx in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_get bytes";
      expect_type position I32 lowered_index.ty "__c_bytes_get index";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_bytes_get",
        [Bytes; I32], [lowered_bytes.operand; lowered_index.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("bytes_slice", _), [buf; from_idx; to_idx], position) ->
      let lowered_bytes = lower_expr context function_builder environment buf in
      let lowered_start = lower_expr context function_builder environment from_idx in
      let lowered_finish = lower_expr context function_builder environment to_idx in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_slice bytes";
      expect_type position I32 lowered_start.ty "__c_bytes_slice start";
      expect_type position I32 lowered_finish.ty "__c_bytes_slice end";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_bytes_slice",
        [Bytes; I32; I32],
        [lowered_bytes.operand; lowered_start.operand; lowered_finish.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar ("open", _), [path], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      expect_type position Str lowered_path.ty "open path";
      let return_type = match Hashtbl.find_opt context.signatures "open" with
        | Some signature -> signature.return_type
        | None -> fail_at position "open is not available"
      in
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, return_type, "open",
        [Str; Str], [lowered_path.operand; String "r"]));
      { operand = Value value; ty = return_type }
  | ECall (EVar (name, _), arguments, position)
    when (match Hashtbl.find_opt environment name with
          | Some { ty = Func _; _ } -> true
          | _ ->
              match List.find_opt (fun (global_name, _) -> global_name = name) !(context.globals) with
              | Some (_, (Func _ as global_type)) ->
                  (* 顶层 let f = func 生成 Func 类型全局变量，调用前先加载 *)
                  let callee = fresh_value function_builder in
                  emit function_builder (GlobalLoad (callee, global_type, name));
                  Hashtbl.replace environment name { operand = Value callee; ty = global_type };
                  true
              | _ -> false) ->
      let callee = lookup_value position environment name in
      lower_call_indirect context function_builder environment callee arguments position
  | ECall (EVar (name, _), arguments, position) ->
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      let actual_name, signature =
        if name = "print" || name = "eprint" then
          let prefix = if name = "eprint" then "dream_eprint" else "dream_print" in
          match lowered_arguments with
          | [argument] ->
              let print_name = match argument.ty with
                | I32 -> prefix ^ "_int"
                | F64 -> prefix ^ "_float"
                | Bool -> prefix ^ "_bool"
                | Str -> prefix ^ "_string"
                | Union _ when name = "print" -> "union_print_value"
                | _ -> fail_at position (name ^ " supports int, float, bool and str in DIR subset")
              in
              (print_name, { parameter_types = [argument.ty]; return_type = Unit })
          | _ -> fail_at position (name ^ " expects exactly one argument")
        else
          match Hashtbl.find_opt context.signatures name with
          | Some signature -> (name, signature)
          | None -> fail_at position ("unknown function " ^ name)
      in
      if List.length lowered_arguments <> List.length signature.parameter_types then
        fail_at position (Printf.sprintf "function %s expects %d arguments, got %d"
          actual_name (List.length signature.parameter_types) (List.length lowered_arguments));
      let lowered_arguments = List.map2 (fun argument expected_type ->
        coerce_value context function_builder position expected_type argument
      ) lowered_arguments signature.parameter_types in
      List.iter2 (fun actual expected ->
        expect_type position expected actual.ty ("argument to " ^ actual_name)
      ) lowered_arguments signature.parameter_types;
      let argument_types = List.map (fun argument -> argument.ty) lowered_arguments in
      let arguments = List.map (fun argument -> argument.operand) lowered_arguments in
      let result_value = match signature.return_type with
        | Unit -> None
        | _ -> Some (fresh_value function_builder)
      in
      emit function_builder (Call (result_value, signature.return_type, actual_name,
        argument_types, arguments));
      let operand = match result_value with
        | Some value -> Value value
        | None -> Int 0
      in
      { operand; ty = signature.return_type }
  | ECall ((EAttr (object_expression, method_name, _)
           | EStructAccess (object_expression, method_name, _)), arguments, position) ->
      let object_value = lower_expr context function_builder environment object_expression in
      (match object_value.ty with
       | Interface _ ->
           lower_interface_call context function_builder environment object_value
             method_name arguments position
       | Struct _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Enum _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Str ->
           lower_string_method context function_builder environment object_value
             method_name arguments position
       | Bytes ->
           lower_bytes_method context function_builder environment object_value
             method_name arguments position
       | actual_type -> fail_at position (Printf.sprintf
           "method call requires a struct, interface, string or bytes value, got %s"
           (Dir.ty_to_string actual_type)))
  | EList (elements, position) ->
      (match elements with
       | [] ->
           lower_empty_list function_builder None
       | _ ->
           let lowered_elements = List.map
             (lower_expr context function_builder environment) elements in
           let element_type = (List.hd lowered_elements).ty in
           List.iter (fun element ->
             expect_type position element_type element.ty "list element"
           ) lowered_elements;
           let value = fresh_value function_builder in
           emit function_builder (ListCreate (value, element_type,
             List.map (fun element -> element.operand) lowered_elements));
           { operand = Value value; ty = List element_type })
  | ETuple (elements, _position) ->
      let lowered_elements = List.map
        (lower_expr context function_builder environment) elements in
      let element_types = List.map (fun element -> element.ty) lowered_elements in
      let value = fresh_value function_builder in
      emit function_builder (TupleCreate (value, element_types,
        List.map (fun element -> element.operand) lowered_elements));
      { operand = Value value; ty = Tuple element_types }
  | EIndex (collection, index, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      (match lowered_collection.ty with
       | List element_type ->
           let lowered_index = lower_expr context function_builder environment index in
           expect_type position I32 lowered_index.ty "index expression";
           let value = fresh_value function_builder in
           emit function_builder (ListGet (value, lowered_collection.operand, lowered_index.operand));
           let element_type = match element_type with
             | Enum (name, []) -> context.resolve_enum name
             | element_type -> element_type
           in
           { operand = Value value; ty = element_type }
       | Str ->
           let lowered_index = lower_expr context function_builder environment index in
           expect_type position I32 lowered_index.ty "string index expression";
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, I32, "__c_utf8_rune_at",
             [Str; I32], [lowered_collection.operand; lowered_index.operand]));
           { operand = Value value; ty = I32 }
       | Bytes ->
           let lowered_index = lower_expr context function_builder environment index in
           expect_type position I32 lowered_index.ty "bytes index expression";
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, I32, "__c_bytes_get",
             [Bytes; I32], [lowered_collection.operand; lowered_index.operand]));
           { operand = Value value; ty = I32 }
       | Dict (key_type, value_type) ->
           let lowered_index = lower_expr context function_builder environment index in
           expect_type position key_type lowered_index.ty "dict index expression";
           let getter_name = match key_type, value_type with
             | I32, I32 -> "dream_dict_get_int_int"
             | I32, Str -> "dream_dict_get_int_str"
             | Str, I32 -> "dream_dict_get_str_int"
             | Str, Str -> "dream_dict_get_str_str"
             | _ -> fail_at position "DIR dict supports only int and str keys/values"
           in
           let value = fresh_value function_builder in
           emit function_builder (Call (Some value, value_type, getter_name,
             [Dict (key_type, value_type); key_type],
             [lowered_collection.operand; lowered_index.operand]));
           { operand = Value value; ty = value_type }
       | Tuple element_types ->
           (match index with
            | EInt (index_value, _) when index_value >= 0 && index_value < List.length element_types ->
                let element_type = List.nth element_types index_value in
                let value = fresh_value function_builder in
                emit function_builder (TupleGet (value, element_type,
                  lowered_collection.operand, index_value));
                { operand = Value value; ty = element_type }
            | EInt (index_value, _) ->
                fail_at position (Printf.sprintf "tuple index %d is out of bounds" index_value)
            | _ -> fail_at position "tuple index must be an integer constant")
       | _ -> fail_at position "index collection must be a list<i32>, dict or tuple")
  | ESlice (collection, start, end_, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let start_value = match start with
        | Some expression ->
            let value = lower_expr context function_builder environment expression in
            expect_type position I32 value.ty "slice start";
            value.operand
        | None -> Int 0
      in
      let end_value = match end_ with
        | Some expression ->
            let value = lower_expr context function_builder environment expression in
            expect_type position I32 value.ty "slice end";
            value.operand
        | None ->
            let value = fresh_value function_builder in
            (match lowered_collection.ty with
             | List I32 ->
                 emit function_builder (ListLength (value, lowered_collection.operand))
             | Str ->
                 emit function_builder (StringLength (value, lowered_collection.operand))
             | Bytes ->
                 emit function_builder (Call (Some value, I32, "__c_bytes_length",
                   [Bytes], [lowered_collection.operand]))
             | _ -> fail_at position "slice collection must be a string, bytes or list<i32>");
            Value value
      in
      let value = fresh_value function_builder in
      (match lowered_collection.ty with
       | List element_type ->
           emit function_builder (ListSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = List element_type }
       | Str ->
           emit function_builder (StringSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = Str }
       | Bytes ->
           emit function_builder (Call (Some value, Bytes, "__c_bytes_slice",
             [Bytes; I32; I32], [lowered_collection.operand; start_value; end_value]));
           { operand = Value value; ty = Bytes }
       | _ -> fail_at position "slice collection must be a string, bytes or list")
  | EListComp (element_expression, variable_name, iterable_expression,
               condition_expression, position) ->
      lower_list_comp context function_builder environment element_expression
        variable_name iterable_expression condition_expression position
  | EDict (pairs, position) ->
      let lowered_pairs = List.map (fun (key, value) ->
        lower_expr context function_builder environment key,
        lower_expr context function_builder environment value) pairs in
      let key_type, value_type = match lowered_pairs with
        | [] -> fail_at position "DIR cannot infer the type of an empty dict"
        | (key, value) :: rest ->
            List.iter (fun (other_key, other_value) ->
              expect_type position key.ty other_key.ty "dict key";
              expect_type position value.ty other_value.ty "dict value"
            ) rest;
            key.ty, value.ty
      in
      let dict_type = Dict (key_type, value_type) in
      let create_name = match key_type, value_type with
        | I32, I32 -> "dream_dict_create_int_int"
        | I32, Str -> "dream_dict_create_int_str"
        | Str, I32 -> "dream_dict_create_str_int"
        | Str, Str -> "dream_dict_create_str_str"
        | _ -> fail_at position "DIR dict supports only int and str keys/values"
      in
      let dictionary = fresh_value function_builder in
      emit function_builder (Call (Some dictionary, dict_type, create_name,
        [I32], [Int 8]));
      let setter_name = match key_type, value_type with
        | I32, I32 -> "dict_set_int_int"
        | I32, Str -> "dict_set_int_str"
        | Str, I32 -> "dict_set_str_int"
        | Str, Str -> "dict_set_str_str"
        | _ -> fail_at position "DIR dict supports only int and str keys/values"
      in
      List.iter (fun (key, value) ->
        emit function_builder (Call (None, Unit, setter_name,
          [dict_type; key_type; value_type],
          [Value dictionary; key.operand; value.operand]))
      ) lowered_pairs;
      { operand = Value dictionary; ty = dict_type }
  | EMatch (scrutinee, cases, position) ->
      lower_match_expression context function_builder environment scrutinee cases position
  | EIf (condition, then_expression, Some else_expression, position) ->
      lower_conditional_expression context function_builder environment
        condition then_expression else_expression position
  | EIf (_, _, None, position) ->
      fail_at position "DIR conditional expressions require an else branch"
  | ETernary (condition, true_expression, false_expression, position) ->
      lower_conditional_expression context function_builder environment
        condition true_expression false_expression position
  | ECall (EEnumVariant (variable_name, method_name, [], _), arguments, position)
    when (match variable_type context environment variable_name with
          | Some (Struct (struct_name, _)) ->
              Hashtbl.mem context.method_signatures (struct_name ^ "." ^ method_name)
          | Some (Enum (enum_name, _)) ->
              Hashtbl.mem context.method_signatures (enum_name ^ "." ^ method_name)
          | Some (Interface _) -> true
          | Some Str -> true
          | Some Bytes -> true
          | _ -> false) ->
      let object_value = load_variable context function_builder environment variable_name in
      (match object_value.ty with
       | Interface _ ->
           lower_interface_call context function_builder environment object_value
             method_name arguments position
       | Struct _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Enum _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Str ->
           lower_string_method context function_builder environment object_value
             method_name arguments position
       | Bytes ->
           lower_bytes_method context function_builder environment object_value
             method_name arguments position
       | _ -> fail_at position "invalid method receiver")
  | ECall (callee, arguments, position) ->
      let lowered_callee = lower_expr context function_builder environment callee in
      lower_call_indirect context function_builder environment lowered_callee arguments position
  | ELambda (parameters, body, position) ->
      lower_lambda context function_builder environment parameters body position
  | EEnumVariant (variable_name, field_name, [], position) ->
      (match variable_type context environment variable_name with
       | Some _ ->
           let object_value = load_variable context function_builder environment variable_name in
           (match object_value.ty with
            | Struct (_, fields) ->
                let struct_name = match object_value.ty with
                  | Struct (name, _) -> name
                  | _ -> assert false
                in
                let method_key = struct_name ^ "." ^ field_name in
                (match Hashtbl.find_opt context.method_signatures method_key with
                 | Some _ ->
                     lower_method_call context function_builder environment object_value
                       field_name [] position
                 | None ->
                     let field_index, field_type = match List.find_index
                         (fun (name, _) -> name = field_name) fields with
                       | None -> fail_at position ("unknown struct field " ^ field_name)
                       | Some index -> index, snd (List.nth fields index)
                     in
                     let value = fresh_value function_builder in
                     emit function_builder (StructGet (value, field_type,
                       object_value.operand, field_index));
                     { operand = Value value; ty = field_type })
            | Enum _ ->
                lower_method_call context function_builder environment object_value
                  field_name [] position
            | Interface _ ->
                lower_interface_call context function_builder environment object_value
                  field_name [] position
            | Str ->
                lower_string_method context function_builder environment object_value
                  field_name [] position
            | Bytes ->
                lower_bytes_method context function_builder environment object_value
                  field_name [] position
            | actual_type -> fail_at position (Printf.sprintf
                "DIR does not support enum variant %s.%s on %s"
                variable_name field_name (Dir.ty_to_string actual_type)))
       | None ->
           let enum_type = context.resolve_enum variable_name in
           let variants = match enum_type with
             | Enum (_, variants) -> variants
             | _ -> fail_at position "invalid DIR enum type"
           in
           let tag, payload_types = match List.find_index
               (fun (name, _) -> name = field_name) variants with
             | None -> fail_at position ("unknown enum variant " ^ field_name)
             | Some tag -> tag, snd (List.nth variants tag)
           in
           (match payload_types with
            | [] when List.exists (fun (_, types) -> types <> []) variants ->
                let value = fresh_value function_builder in
                emit function_builder (EnumCreateSimple (value, enum_type, tag));
                { operand = Value value; ty = enum_type }
            | [] -> { operand = Int tag; ty = enum_type }
            | _ -> fail_at position "enum variant requires a payload") )
  | EEnumVariant (module_name, function_name, arguments, position)
      when StringSet.mem module_name context.module_aliases ->
      let signature = match Hashtbl.find_opt context.signatures function_name with
        | Some signature -> signature
        | None -> fail_at position ("unknown function " ^ module_name ^ "." ^ function_name)
      in
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      if List.length lowered_arguments <> List.length signature.parameter_types then
        fail_at position (Printf.sprintf "function %s.%s expects %d arguments, got %d"
          module_name function_name (List.length signature.parameter_types)
          (List.length lowered_arguments));
      let lowered_arguments = List.map2 (fun argument expected_type ->
        coerce_value context function_builder position expected_type argument
      ) lowered_arguments signature.parameter_types in
      let result_value = match signature.return_type with
        | Unit -> None
        | _ -> Some (fresh_value function_builder)
      in
      emit function_builder (Call (result_value, signature.return_type, function_name,
        signature.parameter_types, List.map (fun argument -> argument.operand) lowered_arguments));
      let operand = match result_value with
        | Some value -> Value value
        | None -> Int 0
      in
      { operand; ty = signature.return_type }
  | EEnumVariant (variable_name, method_name, arguments, position)
    when (match Hashtbl.find_opt environment variable_name with
          | Some { ty = Struct (struct_name, _); _ } ->
              Hashtbl.mem context.method_signatures (struct_name ^ "." ^ method_name)
          | Some { ty = Enum (enum_name, _); _ } ->
              Hashtbl.mem context.method_signatures (enum_name ^ "." ^ method_name)
          | Some { ty = Interface (_, _); _ } -> true
          | Some { ty = Str; _ } -> true
          | Some { ty = Bytes; _ } -> true
          | _ -> false) ->
      let object_value = Hashtbl.find environment variable_name in
      (match object_value.ty with
       | Interface _ ->
           lower_interface_call context function_builder environment object_value
             method_name arguments position
       | Struct _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Enum _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Str ->
           lower_string_method context function_builder environment object_value
             method_name arguments position
       | Bytes ->
           lower_bytes_method context function_builder environment object_value
             method_name arguments position
       | _ -> fail_at position "invalid method receiver")
  | EEnumVariant (variable_name, method_name, arguments, position)
    when (match variable_type context environment variable_name with
          | Some (Struct (struct_name, _)) ->
              Hashtbl.mem context.method_signatures (struct_name ^ "." ^ method_name)
          | Some (Enum (enum_name, _)) ->
              Hashtbl.mem context.method_signatures (enum_name ^ "." ^ method_name)
          | Some (Interface _) -> true
          | Some Str -> true
          | Some Bytes -> true
          | _ -> false) ->
      let object_value = load_variable context function_builder environment variable_name in
      (match object_value.ty with
       | Interface _ ->
           lower_interface_call context function_builder environment object_value
             method_name arguments position
       | Struct _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Enum _ ->
           lower_method_call context function_builder environment object_value method_name
             arguments position
       | Str ->
           lower_string_method context function_builder environment object_value
             method_name arguments position
       | Bytes ->
           lower_bytes_method context function_builder environment object_value
             method_name arguments position
       | _ -> fail_at position "invalid method receiver")
  | EEnumVariant (enum_name, variant_name, arguments, position) ->
      let resolved_enum_type = context.resolve_enum enum_name in
      let variants = match resolved_enum_type with
        | Enum (_, variants) -> variants
        | _ -> fail_at position "invalid DIR enum type"
      in
      let tag, payload_types = match List.find_index
          (fun (name, _) -> name = variant_name) variants with
        | None -> fail_at position ("unknown enum variant " ^ variant_name)
        | Some tag -> tag, snd (List.nth variants tag)
      in
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      (match payload_types, lowered_arguments with
       | [], [] -> { operand = Int tag; ty = resolved_enum_type }
       | [payload_type], [payload] ->
           let payload_type = if enum_name = "Option" || enum_name = "Result" then
             payload.ty else payload_type in
           expect_type position payload_type payload.ty "enum payload";
           let value = fresh_value function_builder in
           (match payload_type with
            | I32 | F64 | Str | Bool ->
                let enum_type = match resolved_enum_type with
                  | Enum (name, variants) ->
                      Enum (name, List.mapi (fun index (name, types) ->
                        if index = tag then name, [payload_type] else name, types) variants)
                  | _ -> assert false
                in
                emit function_builder (EnumCreate (value, enum_type, tag,
                  payload_type, payload.operand));
                { operand = Value value; ty = enum_type }
            | _ ->
                emit function_builder (EnumCreateMulti (value, resolved_enum_type, tag,
                  [payload_type], [payload.operand]));
                { operand = Value value; ty = resolved_enum_type })
       | payload_types, payloads
         when payload_types <> [] && List.length payload_types = List.length payloads ->
           let lowered_payload_types = List.map (fun payload -> payload.ty) lowered_arguments in
           List.iter2 (fun expected actual ->
             expect_type position expected actual "enum payload"
           ) payload_types lowered_payload_types;
           let value = fresh_value function_builder in
           emit function_builder (EnumCreateMulti (value, resolved_enum_type, tag,
             payload_types, List.map (fun payload -> payload.operand) lowered_arguments));
           { operand = Value value; ty = resolved_enum_type }
       | [], _ -> fail_at position "simple enum variant does not accept a payload"
       | _, _ -> fail_at position "enum variant payload count does not match declaration")
  | ETry (expression, position) ->
      let lowered_result = lower_expr context function_builder environment expression in
      let variants = match lowered_result.ty with
        | Enum (_, variants) -> variants
        | _ -> fail_at position "the '?' operator requires a Result value"
      in
      let ok_tag, ok_type = match List.find_index
          (fun (name, _) -> name = "Ok") variants with
        | None -> fail_at position "the '?' operator requires a Result.Ok variant"
        | Some tag ->
            (match snd (List.nth variants tag) with
             | [payload_type] -> tag, payload_type
             | _ -> fail_at position "Result.Ok must contain one payload")
      in
      (match List.find_index
          (fun (name, _) -> name = "Err") variants with
        | None -> fail_at position "the '?' operator requires a Result.Err variant"
        | Some _ -> ());
      expect_type position function_builder.return_type lowered_result.ty
        "propagated Result type";
      let tag_value = fresh_value function_builder in
      emit function_builder (EnumTag (tag_value, lowered_result.operand));
      let is_ok = fresh_value function_builder in
      emit function_builder (Compare (is_ok, Eq, Value tag_value, Int ok_tag));
      let ok_label = fresh_label function_builder "try_ok" in
      let err_label = fresh_label function_builder "try_err" in
      let join_label = fresh_label function_builder "try_join" in
      List.iter (create_block function_builder) [ok_label; err_label; join_label];
      terminate function_builder (Branch (Value is_ok,
        (ok_label, []), (err_label, [])));
      switch_to function_builder err_label;
      terminate function_builder (Return (Some lowered_result.operand));
      switch_to function_builder ok_label;
      let value = fresh_value function_builder in
      emit function_builder (EnumGet (value, ok_type, lowered_result.operand, ok_tag));
      terminate function_builder (Jump (join_label, [Value value]));
      switch_to function_builder join_label;
      let result_value = fresh_value function_builder in
      set_block_params function_builder join_label [(result_value, ok_type)];
      { operand = Value result_value; ty = ok_type }
  | ETypeOf (expression, position) ->
      let value = lower_expr context function_builder environment expression in
      (match value.ty with
       | Interface _ -> value
       | Union _ -> value
       | I32 | F64 | Str | Bool | Bytes ->
           coerce_value context function_builder position (Union [value.ty]) value
       | _ -> fail_at position "type-of requires a scalar, union or interface value")

and lower_expr_expected context function_builder environment expected_type expression =
  match expression with
  | EList ([], _) -> lower_empty_list function_builder expected_type
  | _ -> lower_expr context function_builder environment expression

and lower_lambda context enclosing_builder outer_environment parameters body position =
  let parameter_types = List.map (fun (name, type_expression) ->
    match type_expression with
    | Some type_expression -> type_of_ast context.resolve_named type_expression
    | None -> fail_at position ("lambda parameter " ^ name ^ " requires a type annotation")
  ) parameters in
  let lambda_number = !(context.lambda_counter) in
  context.lambda_counter := lambda_number + 1;
  let name = Printf.sprintf "__dir_lambda_%d" lambda_number in
  let parameter_names = List.fold_left (fun names (parameter_name, _) ->
    StringSet.add parameter_name names
  ) StringSet.empty parameters in
  let captured_names = free_expression parameter_names body
    |> StringSet.elements
    |> List.filter (fun captured_name ->
      Hashtbl.mem outer_environment captured_name)
  in
  let capture_values = List.map (fun captured_name ->
    captured_name, Hashtbl.find outer_environment captured_name
  ) captured_names in
  let capture_types = List.map (fun (_, value) -> value.ty) capture_values in
  let environment_type = ClosureEnv capture_types in
  let function_builder = new_function name Unit (environment_type :: parameter_types) in
  let environment = Hashtbl.create (List.length parameters + List.length capture_values) in
  let captured_environment = Value 1 in
  List.iteri (fun index (captured_name, captured_value) ->
    let value = fresh_value function_builder in
    emit function_builder (ClosureGet (value, captured_value.ty, capture_types,
      captured_environment, index));
    Hashtbl.add environment captured_name { operand = Value value; ty = captured_value.ty }
  ) capture_values;
  let function_parameters = List.mapi (fun index (parameter_name, _) ->
    let value = index + 2 in
    let parameter_type = List.nth parameter_types index in
    Hashtbl.add environment parameter_name { operand = Value value; ty = parameter_type };
    { Dir.value; name = parameter_name; ty = parameter_type }
  ) parameters in
  let function_parameters =
    { Dir.value = 1; name = "__closure_environment"; ty = environment_type } ::
    function_parameters
  in
  let lowered_body = lower_expr context function_builder environment body in
  function_builder.return_type <- lowered_body.ty;
  if not (is_terminated function_builder) then
    terminate function_builder (Return (Some lowered_body.operand));
  let function_def = finish_function function_builder function_parameters in
  context.extra_functions := function_def :: !(context.extra_functions);
  let closure_type = Func (parameter_types, lowered_body.ty) in
  let closure_value = fresh_value enclosing_builder in
  emit enclosing_builder (MakeClosure (closure_value, closure_type, name,
    capture_types, List.map (fun (_, value) -> value.operand) capture_values));
  { operand = Value closure_value; ty = closure_type }

and lower_call_indirect context function_builder environment callee arguments position =
  let parameter_types, return_type = match callee.ty with
    | Func (parameter_types, return_type) -> parameter_types, return_type
    | actual_type -> fail_at position (Printf.sprintf
        "value is not callable: %s" (Dir.ty_to_string actual_type))
  in
  if List.length parameter_types <> List.length arguments then
    fail_at position (Printf.sprintf "function expects %d arguments, got %d"
      (List.length parameter_types) (List.length arguments));
  let lowered_arguments = List.map
    (lower_expr context function_builder environment) arguments in
  let lowered_arguments = List.map2 (fun expected actual ->
    coerce_value context function_builder position expected actual
  ) parameter_types lowered_arguments in
  let result_value = match return_type with
    | Unit -> None
    | _ -> Some (fresh_value function_builder)
  in
  emit function_builder (CallIndirect (result_value, return_type, parameter_types,
    callee.operand, List.map (fun argument -> argument.operand) lowered_arguments));
  let operand = match result_value with
    | Some value -> Value value
    | None -> Int 0
  in
  { operand; ty = return_type }

and lower_match_expression context function_builder environment scrutinee cases position =
  let is_type_match = match scrutinee with
    | ETypeOf _ -> true
    | _ -> false
  in
  let lowered_scrutinee = lower_expr context function_builder environment scrutinee in
  (match lowered_scrutinee.ty with
   | I32 | F64 | Bool | Str | List _ | Tuple _ | Struct _ | Enum _ | Union _
   | Interface _ -> ()
   | _ -> fail_at position "DIR match scrutinee must be a scalar, struct, tuple, enum, union or interface");
  if cases = [] then
    fail_at position "DIR match requires at least one case";
  let join_label = fresh_label function_builder "match_join" in
  let test_labels = List.mapi (fun index _ ->
    fresh_label function_builder (Printf.sprintf "match_test_%d" index)) cases in
  let body_labels = List.mapi (fun index _ ->
    fresh_label function_builder (Printf.sprintf "match_body_%d" index)) cases in
  let guard_labels = List.map (function
    | (_, Some _, _) -> Some (fresh_label function_builder "match_guard")
    | _ -> None) cases in
  let unmatched_label = fresh_label function_builder "match_unmatched" in
  List.iter (create_block function_builder)
    (test_labels @ List.filter_map (fun label -> label) guard_labels @
     body_labels @ [unmatched_label; join_label]);
  let next_label index = match List.nth_opt test_labels (index + 1) with
    | Some label -> label
    | None -> unmatched_label
  in
  terminate function_builder (Jump (List.hd test_labels, []));
  let case_data = List.mapi (fun index case_info ->
    (index, List.nth test_labels index, List.nth guard_labels index,
     List.nth body_labels index, case_info)) cases in
  let enum_variant_info pattern = match pattern with
    | PEnumVariant (_, variant_name, patterns) ->
        let variants = match lowered_scrutinee.ty with
          | Enum (_, variants) when variants <> [] -> variants
          | Enum (name, []) ->
              (match context.resolve_enum name with
               | Enum (_, variants) -> variants
               | _ -> fail_at position "enum pattern requires an enum match scrutinee")
          | _ -> fail_at position "enum pattern requires an enum match scrutinee"
        in
        let tag, payload_types = match List.find_index
            (fun (name, _) -> name = variant_name) variants with
          | None -> fail_at position ("unknown enum variant " ^ variant_name)
          | Some tag -> tag, snd (List.nth variants tag)
        in
        tag, payload_types, patterns
    | _ -> fail_at position "not an enum pattern"
  in
  let struct_pattern_info pattern =
    let struct_name, field_patterns = match pattern with
      | PStruct (name, fields) -> name, fields
      | _ -> fail_at position "not a struct pattern"
    in
    let actual_name, fields = match lowered_scrutinee.ty with
      | Struct (name, fields) -> name, fields
      | _ -> fail_at position "struct pattern requires a struct match scrutinee"
    in
    if struct_name <> "" && struct_name <> actual_name then
      fail_at position "struct pattern name does not match match scrutinee";
    List.map (fun (field_name, field_pattern) ->
      let field_index, field_type = match List.find_index
          (fun (name, _) -> name = field_name) fields with
        | None -> fail_at position ("unknown struct field " ^ field_name)
        | Some index -> index, snd (List.nth fields index)
      in
      field_name, field_index, field_type, field_pattern
    ) field_patterns
  in
  let validate_struct_pattern pattern =
    List.iter (fun (_, _, _, field_pattern) ->
      match field_pattern with
      | PVar _ | PWildcard | PInt _ | PFloat _ | PString _ | PBool _
      | PRune _ | PByte _ -> ()
      | _ -> fail_at position "DIR struct match fields only support variables and constants"
    ) (struct_pattern_info pattern)
  in
  let bind_struct_pattern case_environment pattern =
    List.iter (fun (_, field_index, field_type, field_pattern) ->
      match field_pattern with
      | PWildcard -> ()
      | PInt _ | PFloat _ | PString _ | PBool _ | PRune _ | PByte _ -> ()
      | PVar name ->
          let value = fresh_value function_builder in
          emit function_builder (StructGet (value, field_type,
            lowered_scrutinee.operand, field_index));
          Hashtbl.replace case_environment name { operand = Value value; ty = field_type }
      | _ -> fail_at position "DIR struct match fields only support variables"
    ) (struct_pattern_info pattern)
  in
  let list_pattern_parts pattern = match pattern with
    | PList patterns -> patterns, None
    | PCons (head_pattern, tail_pattern) -> [head_pattern], Some tail_pattern
    | _ -> fail_at position "not a list pattern"
  in
  let validate_list_pattern pattern =
    let element_patterns, tail_pattern = list_pattern_parts pattern in
    let validate_element = function
      | PVar _ | PWildcard | PInt _ | PByte _ | PRune _ -> ()
      | _ -> fail_at position "DIR list match elements only support integer literals and variables"
    in
    List.iter validate_element element_patterns;
    match tail_pattern with
    | None -> ()
    | Some (PVar _ | PWildcard) -> ()
    | Some _ -> fail_at position "DIR cons patterns only support a variable or wildcard tail"
  in
  let bind_list_pattern case_environment pattern =
    validate_list_pattern pattern;
    let element_patterns, tail_pattern = list_pattern_parts pattern in
    List.iteri (fun index element_pattern ->
      match element_pattern with
      | PVar name ->
          let value = fresh_value function_builder in
          emit function_builder (ListGet (value, lowered_scrutinee.operand, Int index));
          Hashtbl.replace case_environment name { operand = Value value; ty = I32 }
      | PWildcard | PInt _ | PByte _ | PRune _ -> ()
      | _ -> assert false
    ) element_patterns;
    match tail_pattern with
    | None -> ()
    | Some PWildcard -> ()
    | Some (PVar name) ->
        let length = fresh_value function_builder in
        emit function_builder (ListLength (length, lowered_scrutinee.operand));
        let tail = fresh_value function_builder in
        emit function_builder (ListSlice (tail, lowered_scrutinee.operand,
          Int 1, Value length));
        Hashtbl.replace case_environment name { operand = Value tail; ty = List I32 }
    | Some _ -> assert false
  in
  let rec bind_tuple_pattern_value case_environment pattern operand operand_ty =
    match pattern with
    | PVar name ->
        Hashtbl.replace case_environment name { operand; ty = operand_ty }
    | PWildcard -> ()
    | PTuple patterns ->
        (match operand_ty with
         | Tuple element_types ->
             if List.length patterns <> List.length element_types then
               fail_at position "tuple pattern length does not match scrutinee";
             List.iteri (fun index sub_pattern ->
               let element_type = List.nth element_types index in
               let value = fresh_value function_builder in
               emit function_builder (TupleGet (value, element_type,
                 operand, index));
               bind_tuple_pattern_value case_environment sub_pattern
                 (Value value) element_type
             ) patterns
         | actual_type -> fail_at position (Printf.sprintf
             "tuple pattern requires a tuple scrutinee, got %s"
             (Dir.ty_to_string actual_type)))
    | PInt _ | PFloat _ | PString _ | PBool _ | PRune _ | PByte _ -> ()
    | _ -> fail_at position "DIR tuple match elements only support variables, wildcards and constants"
  in
  let bind_tuple_pattern case_environment pattern =
    bind_tuple_pattern_value case_environment pattern
      lowered_scrutinee.operand lowered_scrutinee.ty
  in
  let lower_list_test pattern pattern_target failure_label =
    validate_list_pattern pattern;
    let element_patterns, tail_pattern = list_pattern_parts pattern in
    let required_length = List.length element_patterns in
    let length = fresh_value function_builder in
    emit function_builder (ListLength (length, lowered_scrutinee.operand));
    let length_matches = fresh_value function_builder in
    (match tail_pattern with
     | None ->
         emit function_builder (Compare (length_matches, Eq, Value length,
           Int required_length))
     | Some _ ->
         emit function_builder (Compare (length_matches, Gt, Value length, Int 0)));
    let element_labels = List.mapi (fun index _ ->
      fresh_label function_builder (Printf.sprintf "list_pattern_%d" index)) element_patterns in
    List.iter (create_block function_builder) element_labels;
    (match element_labels with
     | [] -> terminate function_builder (Branch (Value length_matches,
         (pattern_target, []), (failure_label, [])))
     | first_label :: _ ->
         terminate function_builder (Branch (Value length_matches,
           (first_label, []), (failure_label, []))));
    List.iteri (fun index element_pattern ->
      let element_label = List.nth element_labels index in
      switch_to function_builder element_label;
      let element = fresh_value function_builder in
      emit function_builder (ListGet (element, lowered_scrutinee.operand, Int index));
      let success_label = match List.nth_opt element_labels (index + 1) with
        | Some next_element_label -> next_element_label
        | None -> pattern_target
      in
      match element_pattern with
      | PVar _ | PWildcard -> terminate function_builder (Jump (success_label, []))
      | PInt value | PByte value ->
          let matches = fresh_value function_builder in
          emit function_builder (Compare (matches, Eq, Value element, Int value));
          terminate function_builder (Branch (Value matches,
            (success_label, []), (failure_label, [])))
      | PRune value ->
          let matches = fresh_value function_builder in
          emit function_builder (Compare (matches, Eq, Value element,
            Int value));
          terminate function_builder (Branch (Value matches,
            (success_label, []), (failure_label, [])))
      | _ -> assert false
    ) element_patterns
  in
  let bind_enum_payload case_environment pattern =
    match pattern with
    | PEnumVariant (_, _, []) -> ()
    | PEnumVariant (_, _, patterns) ->
        let tag, payload_types, _ = enum_variant_info pattern in
        if List.length payload_types <> List.length patterns then
          fail_at position "DIR enum payload pattern count does not match variant"
        else
          List.iteri (fun index pattern ->
            match pattern with
            | PWildcard -> ()
            | PVar name ->
                let payload_type = List.nth payload_types index in
                let value = fresh_value function_builder in
                if List.length payload_types = 1 &&
                   (match payload_type with
                    | I32 | F64 | Str | Bool -> true
                    | _ -> false) then
                  emit function_builder (EnumGet (value, payload_type,
                    lowered_scrutinee.operand, tag))
                else
                  emit function_builder (EnumGetMulti (value, payload_type,
                    payload_types, lowered_scrutinee.operand, tag, index));
                Hashtbl.replace case_environment name { operand = Value value; ty = payload_type }
            | _ -> fail_at position "DIR enum payload patterns only support variables"
          ) patterns
    | _ -> ()
  in
  let enum_has_payload = match lowered_scrutinee.ty with
    | Enum (name, []) ->
        (match context.resolve_enum name with
         | Enum (_, variants) -> List.exists (fun (_, payload_types) -> payload_types <> []) variants
         | _ -> false)
    | Enum (_, variants) -> List.exists (fun (_, payload_types) -> payload_types <> []) variants
    | _ -> false
  in
  let lower_test (index, test_label, guard_label, body_label, (pattern, guard, _)) =
    switch_to function_builder test_label;
    let case_environment = Hashtbl.copy environment in
    (match pattern with
     | PVar name -> Hashtbl.replace case_environment name lowered_scrutinee
     | PWildcard | PInt _ | PFloat _ | PString _ | PByte _ | PRune _ | PBool _
     | PList _ | PCons _ | PStruct _ | PEnumVariant _ | PTuple _ -> ()
     | _ -> fail_at position "DIR match only supports scalar, list, tuple, struct and enum patterns");
    let pattern_target = Option.value guard_label ~default:body_label in
    let union_test is_name get_name member_type expected_value =
      let is_member = fresh_value function_builder in
      emit function_builder (Call (Some is_member, Bool, is_name,
        [lowered_scrutinee.ty], [lowered_scrutinee.operand]));
      let member_value = fresh_value function_builder in
      emit function_builder (Call (Some member_value, member_type, get_name,
        [lowered_scrutinee.ty], [lowered_scrutinee.operand]));
      let value_matches = fresh_value function_builder in
      (match member_type with
       | Str ->
           let comparison = fresh_value function_builder in
           emit function_builder (StringCompare (comparison,
             Value member_value, expected_value));
           emit function_builder (Compare (value_matches, Eq, Value comparison, Int 0))
       | _ ->
           emit function_builder (Compare (value_matches, Eq,
             Value member_value, expected_value)));
      let matches = fresh_value function_builder in
      emit function_builder (Binop (matches, Bool, And,
        Value is_member, Value value_matches));
      terminate function_builder (Branch (Value matches,
        (pattern_target, []), (next_label index, [])))
    in
    (match pattern with
     | PInt value ->
         (match lowered_scrutinee.ty with
          | Union _ -> union_test "union_is_int" "union_get_int" I32 (Int value)
          | actual_type ->
              if not (Dir.equal_ty actual_type I32) then
                fail_at position "integer pattern requires an integer match scrutinee";
              let matches = fresh_value function_builder in
              emit function_builder (Compare (matches, Eq,
                lowered_scrutinee.operand, Int value));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, []))))
     | PFloat value ->
         (match lowered_scrutinee.ty with
          | Union _ -> union_test "union_is_float" "union_get_float" F64 (Float value)
          | actual_type ->
              if not (Dir.equal_ty actual_type F64) then
                fail_at position "float pattern requires a float match scrutinee";
              let matches = fresh_value function_builder in
              emit function_builder (Compare (matches, Eq,
                lowered_scrutinee.operand, Float value));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, []))))
     | PBool value ->
         (match lowered_scrutinee.ty with
          | Union _ -> union_test "union_is_bool" "union_get_bool" Bool (Bool value)
          | actual_type ->
              if not (Dir.equal_ty actual_type Bool) then
                fail_at position "boolean pattern requires a boolean match scrutinee";
              let matches = fresh_value function_builder in
              emit function_builder (Compare (matches, Eq,
                lowered_scrutinee.operand, Bool value));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, []))))
     | PByte value ->
         if not (Dir.equal_ty lowered_scrutinee.ty I32) then
           fail_at position "byte/rune pattern requires an integer match scrutinee";
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           lowered_scrutinee.operand, Int value));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
     | PRune value ->
         if not (Dir.equal_ty lowered_scrutinee.ty I32) then
           fail_at position "byte/rune pattern requires an integer match scrutinee";
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           lowered_scrutinee.operand, Int value));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
     | PString value when is_type_match ->
         (match lowered_scrutinee.ty with
          | Interface _ ->
              (* 接口值：按具体类型 tag 分发（case 名为 struct/enum 类型名） *)
              let tag_value = fresh_value function_builder in
              emit function_builder (InterfaceTypeTag (tag_value,
                lowered_scrutinee.operand));
              let matches = fresh_value function_builder in
              emit function_builder (Compare (matches, Eq,
                Value tag_value, Int (Dir.concrete_type_tag value)));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, [])))
          | _ ->
              (* match type of：按类型名分发，只做 is 检查 *)
              let is_name = match value with
                | "int" -> "union_is_int"
                | "float" -> "union_is_float"
                | "str" -> "union_is_string"
                | "bool" -> "union_is_bool"
                | "bytes" -> "union_is_bytes"
                | _ -> fail_at position ("unknown type name " ^ value)
              in
              let matches = fresh_value function_builder in
              emit function_builder (Call (Some matches, Bool, is_name,
                [lowered_scrutinee.ty], [lowered_scrutinee.operand]));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, []))))
     | PString value ->
         (match lowered_scrutinee.ty with
          | Union _ ->
              union_test "union_is_string" "union_get_string" Str (String value)
          | actual_type ->
              if not (Dir.equal_ty actual_type Str) then
                fail_at position "string pattern requires a string match scrutinee";
              let comparison = fresh_value function_builder in
              emit function_builder (StringCompare (comparison,
                lowered_scrutinee.operand, String value));
              let matches = fresh_value function_builder in
              emit function_builder (Compare (matches, Eq, Value comparison, Int 0));
              terminate function_builder (Branch (Value matches,
                (pattern_target, []), (next_label index, []))))
     | PEnumVariant _ ->
         let tag, payload_types, patterns = enum_variant_info pattern in
         if payload_types = [] && patterns <> [] then
           fail_at position "simple enum variant does not accept a payload pattern";
         if payload_types <> [] &&
            (List.length patterns <> List.length payload_types ||
             not (List.for_all (function PVar _ | PWildcard -> true | _ -> false) patterns)) then
           fail_at position "DIR enum payload pattern count or shape is invalid";
         let comparison_operand = if enum_has_payload then begin
           let enum_tag = fresh_value function_builder in
           emit function_builder (EnumTag (enum_tag, lowered_scrutinee.operand));
           Value enum_tag
         end else lowered_scrutinee.operand in
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           comparison_operand, Int tag));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
     | PStruct _ ->
         validate_struct_pattern pattern;
         let constant_fields = List.filter (fun (_, _, _, field_pattern) ->
           match field_pattern with PVar _ | PWildcard -> false | _ -> true
         ) (struct_pattern_info pattern) in
         (match constant_fields with
          | [] -> terminate function_builder (Jump (pattern_target, []))
          | _ ->
              let test_labels = List.mapi (fun index _ ->
                fresh_label function_builder (Printf.sprintf "struct_field_%d" index))
                constant_fields in
              List.iter (create_block function_builder) test_labels;
              (match test_labels with
               | first_label :: _ ->
                   terminate function_builder (Jump (first_label, []))
               | [] -> assert false);
              List.iteri (fun index (_, field_index, field_type, field_pattern) ->
                switch_to function_builder (List.nth test_labels index);
                let field_value = fresh_value function_builder in
                emit function_builder (StructGet (field_value, field_type,
                  lowered_scrutinee.operand, field_index));
                let matches = fresh_value function_builder in
                let success_label = match List.nth_opt test_labels (index + 1) with
                  | Some next_label -> next_label
                  | None -> pattern_target
                in
                (match field_pattern with
                 | PInt value ->
                     emit function_builder (Compare (matches, Eq,
                       Value field_value, Int value))
                 | PFloat value ->
                     emit function_builder (Compare (matches, Eq,
                       Value field_value, Float value))
                 | PBool value ->
                     emit function_builder (Compare (matches, Eq,
                       Value field_value, Bool value))
                 | PRune value | PByte value ->
                     emit function_builder (Compare (matches, Eq,
                       Value field_value, Int value))
                 | PString value ->
                     let comparison = fresh_value function_builder in
                     emit function_builder (StringCompare (comparison,
                       Value field_value, String value));
                     emit function_builder (Compare (matches, Eq,
                       Value comparison, Int 0))
                 | _ -> assert false);
                terminate function_builder (Branch (Value matches,
                  (success_label, []), (next_label index, [])))
              ) constant_fields)
     | PList _ | PCons _ ->
         if not (Dir.equal_ty lowered_scrutinee.ty (List I32)) then
           fail_at position "list pattern requires a list<i32> match scrutinee";
         lower_list_test pattern pattern_target (next_label index)
     | PTuple patterns ->
         let element_types = match lowered_scrutinee.ty with
           | Tuple element_types -> element_types
           | actual_type -> fail_at position (Printf.sprintf
               "tuple pattern requires a tuple scrutinee, got %s"
               (Dir.ty_to_string actual_type))
         in
         if List.length patterns <> List.length element_types then
           fail_at position "tuple pattern length does not match scrutinee";
         (* 递归收集常量元素测试：(值, 模式)，变量/通配符跳过 *)
         let rec tuple_constant_tests operand operand_ty pattern =
           match pattern with
           | PInt _ | PFloat _ | PString _ | PBool _ | PRune _ | PByte _ ->
               [(operand, pattern)]
           | PTuple sub_patterns ->
               (match operand_ty with
                | Tuple sub_types ->
                    if List.length sub_patterns <> List.length sub_types then
                      fail_at position "tuple pattern length does not match scrutinee";
                    List.flatten (List.mapi (fun index sub_pattern ->
                      let element_type = List.nth sub_types index in
                      let value = fresh_value function_builder in
                      emit function_builder (TupleGet (value, element_type,
                        operand, index));
                      tuple_constant_tests (Value value) element_type sub_pattern
                    ) sub_patterns)
                | _ -> fail_at position "tuple pattern requires a tuple scrutinee")
           | PVar _ | PWildcard -> []
           | _ -> fail_at position "DIR tuple match elements only support variables, wildcards and constants"
         in
         let constant_tests = List.flatten (List.mapi (fun index sub_pattern ->
           let element_type = List.nth element_types index in
           let value = fresh_value function_builder in
           emit function_builder (TupleGet (value, element_type,
             lowered_scrutinee.operand, index));
           tuple_constant_tests (Value value) element_type sub_pattern
         ) patterns) in
         (match constant_tests with
          | [] -> terminate function_builder (Jump (pattern_target, []))
          | _ ->
              let test_labels = List.mapi (fun index _ ->
                fresh_label function_builder (Printf.sprintf "tuple_elem_%d" index))
                constant_tests in
              List.iter (create_block function_builder) test_labels;
              (match test_labels with
               | first_label :: _ ->
                   terminate function_builder (Jump (first_label, []))
               | [] -> assert false);
              List.iteri (fun test_index (element_value, sub_pattern) ->
                switch_to function_builder (List.nth test_labels test_index);
                let matches = fresh_value function_builder in
                let success_label = match List.nth_opt test_labels (test_index + 1) with
                  | Some next_label -> next_label
                  | None -> pattern_target
                in
                (match sub_pattern with
                 | PInt value ->
                     emit function_builder (Compare (matches, Eq,
                       element_value, Int value))
                 | PFloat value ->
                     emit function_builder (Compare (matches, Eq,
                       element_value, Float value))
                 | PBool value ->
                     emit function_builder (Compare (matches, Eq,
                       element_value, Bool value))
                 | PRune value | PByte value ->
                     emit function_builder (Compare (matches, Eq,
                       element_value, Int value))
                 | PString value ->
                     let comparison = fresh_value function_builder in
                     emit function_builder (StringCompare (comparison,
                       element_value, String value));
                     emit function_builder (Compare (matches, Eq,
                       Value comparison, Int 0))
                 | _ -> assert false);
                terminate function_builder (Branch (Value matches,
                  (success_label, []), (next_label index, [])))
              ) constant_tests)
     | PWildcard | PVar _ ->
         terminate function_builder (Jump (pattern_target, []))
     | _ -> fail_at position "DIR match only supports scalar, list, tuple, struct and enum patterns");
    (match guard, guard_label with
     | Some guard_expression, Some guard_label ->
         switch_to function_builder guard_label;
         (match pattern with
          | PStruct _ -> bind_struct_pattern case_environment pattern
          | PList _ | PCons _ -> bind_list_pattern case_environment pattern
          | _ -> bind_enum_payload case_environment pattern);
         let lowered_guard = lower_expr context function_builder case_environment guard_expression in
         expect_type position Bool lowered_guard.ty "match guard";
         terminate function_builder (Branch (lowered_guard.operand,
           (body_label, []), (next_label index, [])))
     | None, None -> ()
     | _ -> fail_at position "invalid DIR match guard")
  in
  List.iter lower_test case_data;
  switch_to function_builder unmatched_label;
  terminate function_builder Unreachable;
  let result_type = ref None in
  let lower_case (_, _, _, body_label, (pattern, _, body)) =
    switch_to function_builder body_label;
    let case_environment = Hashtbl.copy environment in
    (* match type of：把 scrutinee 变量窄化为匹配的类型（接口值不窄化，按 tag 分发） *)
    (if is_type_match then
      match pattern, scrutinee, lowered_scrutinee.ty with
      | PString type_name, ETypeOf (EVar (variable_name, _), _),
        (Union _ | I32 | F64 | Str | Bool | Bytes) ->
          let get_name, member_type = match type_name with
            | "int" -> "union_get_int", I32
            | "float" -> "union_get_float", F64
            | "str" -> "union_get_string", Str
            | "bool" -> "union_get_bool", Bool
            | "bytes" -> "union_get_bytes", Bytes
            | _ -> fail_at position ("unknown type name " ^ type_name)
          in
          let narrowed_value = fresh_value function_builder in
          emit function_builder (Call (Some narrowed_value, member_type, get_name,
            [lowered_scrutinee.ty], [lowered_scrutinee.operand]));
          Hashtbl.replace case_environment variable_name
            { operand = Value narrowed_value; ty = member_type }
      | _ -> ());
    (match pattern with
     | PVar name -> Hashtbl.replace case_environment name lowered_scrutinee
     | PWildcard | PInt _ | PFloat _ | PString _ | PByte _ | PRune _ | PBool _ -> ()
     | PEnumVariant _ -> bind_enum_payload case_environment pattern
     | PStruct _ -> bind_struct_pattern case_environment pattern
     | PList _ | PCons _ -> bind_list_pattern case_environment pattern
     | PTuple _ -> bind_tuple_pattern case_environment pattern
     | _ -> fail_at position "DIR match only supports scalar, list, tuple, struct and enum patterns");
    let lowered_body = match body with
      | MExpr expression -> lower_expr context function_builder case_environment expression
      | MStmts statements ->
          (match List.rev statements with
           | SExpr (expression, _) :: reversed_prefix ->
               Dir_lower_stmt.lower_statements context function_builder case_environment
                 (List.rev reversed_prefix);
               lower_expr context function_builder case_environment expression
           | _ -> fail_at position "DIR match statement cases must end with an expression")
    in
    if Dir.equal_ty lowered_body.ty Unit then
      fail_at position "DIR match expressions cannot return unit";
    (match !result_type with
     | None -> result_type := Some lowered_body.ty
     | Some expected -> expect_type position expected lowered_body.ty "match case result");
    if not (is_terminated function_builder) then
      terminate function_builder (Jump (join_label, [lowered_body.operand]))
  in
  List.iter lower_case case_data;
  switch_to function_builder join_label;
  let result_type = match !result_type with
    | Some result_type -> result_type
    | None -> fail_at position "DIR match has no cases"
  in
  let result_value = fresh_value function_builder in
  set_block_params function_builder join_label [(result_value, result_type)];
  { operand = Value result_value; ty = result_type }

and lower_conditional_expression context function_builder environment condition
    then_expression else_expression position =
  let lowered_condition = lower_expr context function_builder environment condition in
  expect_type position Bool lowered_condition.ty "conditional expression condition";
  let then_label = fresh_label function_builder "expr_then" in
  let else_label = fresh_label function_builder "expr_else" in
  let join_label = fresh_label function_builder "expr_join" in
  List.iter (create_block function_builder) [then_label; else_label; join_label];
  terminate function_builder (Branch (lowered_condition.operand,
    (then_label, []), (else_label, [])));
  switch_to function_builder then_label;
  let then_value = lower_expr context function_builder (Hashtbl.copy environment)
    then_expression in
  if not (is_terminated function_builder) then
    terminate function_builder (Jump (join_label, [then_value.operand]));
  switch_to function_builder else_label;
  let else_value = lower_expr context function_builder (Hashtbl.copy environment)
    else_expression in
  expect_type position then_value.ty else_value.ty "conditional expression branches";
  if Dir.equal_ty then_value.ty Unit then
    fail_at position "DIR conditional expressions cannot return unit";
  if not (is_terminated function_builder) then
    terminate function_builder (Jump (join_label, [else_value.operand]));
  switch_to function_builder join_label;
  let result_value = fresh_value function_builder in
  set_block_params function_builder join_label [(result_value, then_value.ty)];
  { operand = Value result_value; ty = then_value.ty }

and lower_list_comp context function_builder environment element_expression variable_name
    iterable_expression condition_expression position =
  let iterable = lower_expr context function_builder environment iterable_expression in
  expect_type position (List I32) iterable.ty "list comprehension iterable";
  let result = fresh_value function_builder in
  emit function_builder (ListCreate (result, I32, []));
  let condition_label = fresh_label function_builder "listcomp_condition" in
  let body_label = fresh_label function_builder "listcomp_body" in
  let append_label = fresh_label function_builder "listcomp_append" in
  let next_label = fresh_label function_builder "listcomp_next" in
  let exit_label = fresh_label function_builder "listcomp_exit" in
  List.iter (create_block function_builder)
    [condition_label; body_label; append_label; next_label; exit_label];
  terminate function_builder (Jump (condition_label, [Int 0]));
  switch_to function_builder condition_label;
  let condition_index = fresh_value function_builder in
  set_block_params function_builder condition_label [(condition_index, I32)];
  let length = fresh_value function_builder in
  emit function_builder (ListLength (length, iterable.operand));
  let has_more = fresh_value function_builder in
  emit function_builder (Compare (has_more, Lt, Value condition_index, Value length));
  terminate function_builder (Branch (Value has_more,
    (body_label, [Value condition_index]), (exit_label, [])));
  switch_to function_builder body_label;
  let body_index = fresh_value function_builder in
  set_block_params function_builder body_label [(body_index, I32)];
  let next_input = fresh_value function_builder in
  set_block_params function_builder next_label [(next_input, I32)];
  let item = fresh_value function_builder in
  emit function_builder (ListGet (item, iterable.operand, Value body_index));
  let body_environment = Hashtbl.copy environment in
  Hashtbl.replace body_environment variable_name { operand = Value item; ty = I32 };
  (match condition_expression with
   | None -> terminate function_builder (Jump (append_label, []))
   | Some condition ->
       let lowered_condition = lower_expr context function_builder body_environment condition in
       expect_type position Bool lowered_condition.ty "list comprehension condition";
       terminate function_builder (Branch (lowered_condition.operand,
         (append_label, []), (next_label, [Value body_index]))));
  switch_to function_builder append_label;
  let element = lower_expr context function_builder body_environment element_expression in
  expect_type position I32 element.ty "list comprehension element";
  emit function_builder (ListAppend (Value result, element.operand, I32));
  terminate function_builder (Jump (next_label, [Value body_index]));
  switch_to function_builder next_label;
  let next_index = fresh_value function_builder in
  emit function_builder (Binop (next_index, I32, Add, Value next_input, Int 1));
  terminate function_builder (Jump (condition_label, [Value next_index]));
  switch_to function_builder exit_label;
  { operand = Value result; ty = List I32 }


let lower_function context constant_bindings def_info =
  let signature = Hashtbl.find context.signatures def_info.def_name in
  let function_builder = new_function def_info.def_name signature.return_type signature.parameter_types in
  let environment = Hashtbl.create 16 in
  List.iter (fun (name, value) -> Hashtbl.add environment name value) constant_bindings;
  let parameters = List.mapi (fun index (name, _, _) ->
    let value = index + 1 in
    let parameter_type = List.nth signature.parameter_types index in
    let parameter = { Dir.value; name; ty = parameter_type } in
    Hashtbl.add environment name { operand = Value value; ty = parameter_type };
    parameter
  ) def_info.def_params in
  if def_info.def_name = "main" then
    List.iter (fun (name, expression) ->
      let value = lower_expr context function_builder environment expression in
      context.globals := !(context.globals) @ [name, value.ty];
      emit function_builder (GlobalStore (name, value.operand))
    ) !(context.global_inits);
  Dir_lower_stmt.lower_statements context function_builder environment def_info.def_body;
  (* 无显式 return 的路径（如 main）在默认返回前释放未逃逸的接口装箱对象 *)
  if not (is_terminated function_builder) then
    release_interface_boxes function_builder;
  finish_function function_builder parameters

let runtime_externs = [
  { name = "dream_print_int"; parameters = [I32]; return_type = Unit };
  { name = "dream_print_float"; parameters = [F64]; return_type = Unit };
  { name = "dream_print_bool"; parameters = [Bool]; return_type = Unit };
  { name = "dream_print_string"; parameters = [Str]; return_type = Unit };
  { name = "dream_eprint_int"; parameters = [I32]; return_type = Unit };
  { name = "dream_eprint_float"; parameters = [F64]; return_type = Unit };
  { name = "dream_eprint_bool"; parameters = [Bool]; return_type = Unit };
  { name = "dream_eprint_string"; parameters = [Str]; return_type = Unit };
  { name = "string_concat"; parameters = [Str; Str]; return_type = Str };
  { name = "string_length"; parameters = [Str]; return_type = I32 };
  { name = "string_find"; parameters = [Str; Str]; return_type = I32 };
  { name = "string_upper"; parameters = [Str]; return_type = Str };
  { name = "string_lower"; parameters = [Str]; return_type = Str };
  { name = "string_strip"; parameters = [Str]; return_type = Str };
  { name = "string_split"; parameters = [Str; Str]; return_type = List Str };
  { name = "string_join"; parameters = [List Str; Str]; return_type = Str };
  { name = "dict_items_tuples"; parameters = [Dict (I32, I32)]; return_type = List (Tuple [I32; I32]) };
  { name = "string_starts_with"; parameters = [Str; Str]; return_type = Bool };
  { name = "string_ends_with"; parameters = [Str; Str]; return_type = Bool };
  { name = "string_replace"; parameters = [Str; Str; Str]; return_type = Str };
  { name = "int_floordiv"; parameters = [I32; I32]; return_type = I32 };
  { name = "float_floordiv"; parameters = [F64; F64]; return_type = F64 };
  { name = "int_pow"; parameters = [I32; I32]; return_type = I32 };
  { name = "float_pow"; parameters = [F64; F64]; return_type = F64 };
  { name = "string_is_digit"; parameters = [I32]; return_type = Bool };
  { name = "string_is_alpha"; parameters = [I32]; return_type = Bool };
  { name = "__c_time_ms"; parameters = []; return_type = I32 };
  { name = "__c_debug_on"; parameters = []; return_type = Bool };
  { name = "__c_eprint_text"; parameters = [Str]; return_type = Unit };
  { name = "__c_eprint_int"; parameters = [I32]; return_type = Unit };
  { name = "__c_range_equal"; parameters = [Str; I32; I32; I32; I32]; return_type = Bool };
  { name = "__c_fnv_hash_range"; parameters = [Str; I32; I32]; return_type = I32 };
  { name = "__c_range_equals_cstr"; parameters = [Str; I32; I32; Str]; return_type = Bool };
  { name = "string_is_whitespace"; parameters = [I32]; return_type = Bool };
  { name = "union_create_int"; parameters = [I32]; return_type = Union [I32] };
  { name = "union_create_float"; parameters = [F64]; return_type = Union [F64] };
  { name = "union_create_string"; parameters = [Str]; return_type = Union [Str] };
  { name = "union_create_bool"; parameters = [Bool]; return_type = Union [Bool] };
  { name = "union_create_bytes"; parameters = [Bytes]; return_type = Union [Bytes] };
  { name = "union_is_int"; parameters = [Union [I32]]; return_type = Bool };
  { name = "union_is_float"; parameters = [Union [F64]]; return_type = Bool };
  { name = "union_is_string"; parameters = [Union [Str]]; return_type = Bool };
  { name = "union_is_bool"; parameters = [Union [Bool]]; return_type = Bool };
  { name = "union_is_bytes"; parameters = [Union [Bytes]]; return_type = Bool };
  { name = "union_get_int"; parameters = [Union [I32]]; return_type = I32 };
  { name = "union_get_float"; parameters = [Union [F64]]; return_type = F64 };
  { name = "union_get_string"; parameters = [Union [Str]]; return_type = Str };
  { name = "union_get_bool"; parameters = [Union [Bool]]; return_type = Bool };
  { name = "union_get_bytes"; parameters = [Union [Bytes]]; return_type = Bytes };
  { name = "union_print_value"; parameters = [Union [I32; F64; Str; Bool; Bytes]]; return_type = Unit };
  { name = "__c_process_arg_count"; parameters = []; return_type = I32 };
  { name = "__c_process_arg"; parameters = [I32]; return_type = Str };
  { name = "__c_env"; parameters = [Str]; return_type = Str };
  { name = "__c_file_read"; parameters = [Str]; return_type = Str };
  { name = "__c_file_write"; parameters = [Str; Str]; return_type = I32 };
  { name = "__c_file_exists"; parameters = [Str]; return_type = Bool };
  { name = "__c_file_delete"; parameters = [Str]; return_type = Bool };
  { name = "__c_net_connect"; parameters = [Str; I32]; return_type = I32 };
  { name = "__c_net_write"; parameters = [I32; Str]; return_type = I32 };
  { name = "__c_net_read"; parameters = [I32; I32]; return_type = Str };
  { name = "__c_net_close"; parameters = [I32]; return_type = Bool };
  { name = "__c_http_request"; parameters = [Str; Str; Str; Str]; return_type = Str };
  { name = "__c_build_llvm"; parameters = [Str; Str; Bool]; return_type = I32 };
  { name = "__c_file_read_bytes"; parameters = [Str]; return_type = Bytes };
  { name = "__c_file_write_bytes"; parameters = [Str; Bytes]; return_type = I32 };
  { name = "__c_file_append"; parameters = [Str; Str]; return_type = I32 };
  { name = "__c_file_append_bytes"; parameters = [Str; Bytes]; return_type = I32 };
  { name = "__c_crypto_sha256"; parameters = [Str]; return_type = Str };
  { name = "__c_crypto_sha256_bytes"; parameters = [Bytes]; return_type = Str };
  { name = "__c_file_is_dir"; parameters = [Str]; return_type = Bool };
  { name = "__c_file_mkdir"; parameters = [Str]; return_type = Bool };
  { name = "__c_file_rename"; parameters = [Str; Str]; return_type = Bool };
  { name = "__c_file_size"; parameters = [Str]; return_type = I32 };
  { name = "__c_bytes_length"; parameters = [Bytes]; return_type = I32 };
  { name = "__c_bytes_get"; parameters = [Bytes; I32]; return_type = I32 };
  { name = "__c_bytes_slice"; parameters = [Bytes; I32; I32]; return_type = Bytes };
  { name = "__c_bytes_from_array"; parameters = [List I32]; return_type = Bytes };
  { name = "__c_str_to_bytes"; parameters = [Str]; return_type = Bytes };
  { name = "__c_bytes_to_str"; parameters = [Bytes]; return_type = Str };
  { name = "dict_set_int_int"; parameters = [Dict (I32, I32); I32; I32]; return_type = Unit };
  { name = "dict_set_int_str"; parameters = [Dict (I32, Str); I32; Str]; return_type = Unit };
  { name = "dict_set_str_int"; parameters = [Dict (Str, I32); Str; I32]; return_type = Unit };
  { name = "dict_set_str_str"; parameters = [Dict (Str, Str); Str; Str]; return_type = Unit };
  { name = "dream_dict_create_int_int"; parameters = [I32]; return_type = Dict (I32, I32) };
  { name = "dream_dict_create_int_str"; parameters = [I32]; return_type = Dict (I32, Str) };
  { name = "dream_dict_create_str_int"; parameters = [I32]; return_type = Dict (Str, I32) };
  { name = "dream_dict_create_str_str"; parameters = [I32]; return_type = Dict (Str, Str) };
  { name = "dream_dict_get_int_int"; parameters = [Dict (I32, I32); I32]; return_type = I32 };
  { name = "dream_dict_get_int_str"; parameters = [Dict (I32, Str); I32]; return_type = Str };
  { name = "dream_dict_get_str_int"; parameters = [Dict (Str, I32); Str]; return_type = I32 };
  { name = "dream_dict_get_str_str"; parameters = [Dict (Str, Str); Str]; return_type = Str };
  { name = "dream_dict_size_int_int"; parameters = [Dict (I32, I32)]; return_type = I32 };
  { name = "dream_dict_size_int_str"; parameters = [Dict (I32, Str)]; return_type = I32 };
  { name = "dream_dict_size_str_int"; parameters = [Dict (Str, I32)]; return_type = I32 };
  { name = "dream_dict_size_str_str"; parameters = [Dict (Str, Str)]; return_type = I32 };
  { name = "__c_utf8_rune_count"; parameters = [Str]; return_type = I32 };
  { name = "__c_utf8_rune_at"; parameters = [Str; I32]; return_type = I32 };
  { name = "__c_utf8_encode_rune"; parameters = [I32]; return_type = Bytes };
]

let lower_program program =
  try
    let struct_definitions = Hashtbl.create 16 in
    List.iter (function
      | SStruct struct_info -> Hashtbl.replace struct_definitions
          struct_info.struct_name struct_info
      | _ -> ()) program;
    let enum_definitions = Hashtbl.create 16 in
    List.iter (function
      | SEnum enum_info -> Hashtbl.replace enum_definitions
          enum_info.enum_name enum_info
      | _ -> ()) program;
    let interface_definitions = Hashtbl.create 16 in
    List.iter (function
      | SInterface interface_info -> Hashtbl.replace interface_definitions
          interface_info.interface_name interface_info
      | _ -> ()) program;
    let rec resolve_type resolving = function
      | TInt -> I32
      | TBool -> Bool
      | TFloat -> F64
      | TStr -> Str
      | TByte | TRune -> I32
      | TBytes -> Bytes
      | TList element_type -> List (resolve_type resolving element_type)
      | TTuple element_types -> Tuple (List.map (resolve_type resolving) element_types)
      | TNone -> Unit
      | TStruct (name, _) -> resolve_struct_type resolving name
      | TEnum (name, _) -> resolve_enum_type resolving name
      | TGeneric (name, argument) ->
          let parameters = match argument with
            | TTuple arguments -> List.map (resolve_type resolving) arguments
            | _ -> [resolve_type resolving argument]
          in
          resolve_interface_type name parameters
      | TOption element_type ->
          Enum ("Option", [("Some", [resolve_type resolving element_type]); ("None", [])])
      | TResult (ok_type, error_type) ->
          Enum ("Result", [("Ok", [resolve_type resolving ok_type]);
                            ("Err", [resolve_type resolving error_type])])
      | TVar name ->
          (try resolve_struct_type resolving name with Lower_error _ ->
             try resolve_enum_type resolving name with Lower_error _ ->
               try resolve_interface_type name [] with Lower_error _ -> I32)
      | TSelf -> Struct ("", [])  (* 接口声明中的 Self 占位，impl 时解析为具体类型 *)
      | type_expression ->
          raise (Lower_error (Printf.sprintf "DIR does not support type %s in a struct"
            (match type_expression with
             | TDict _ -> "dict"
             | TFunc _ -> "function"
             | TUnion _ -> "union"
             | TGeneric (name, _) -> name
             | TOption _ -> "option"
             | TResult _ -> "result"
             | TEnum (name, _) -> name
             | TSelf -> "self"
             | TInt | TFloat | TBool | TStr | TByte | TRune | TBytes | TList _
             | TTuple _ | TNone | TStruct _ | TVar _ -> "unknown")))
    and resolve_struct_type resolving name =
      if List.mem name resolving then
        raise (Lower_error ("recursive struct is not supported in DIR: " ^ name));
      match Hashtbl.find_opt struct_definitions name with
      | None -> raise (Lower_error ("unknown struct " ^ name))
      | Some struct_info ->
          let fields = List.filter_map (function
            | SField field ->
                (match field.field_name with
                 | Some field_name -> Some (field_name,
                     resolve_type (name :: resolving) field.field_type)
                 | None -> raise (Lower_error "anonymous struct fields are not supported in DIR"))
            | SMethod _ -> None
          ) struct_info.struct_members in
          Struct (name, fields)
    and resolve_enum_type resolving name =
      if List.mem name resolving then
        Enum (name, [])
      else
        match Hashtbl.find_opt enum_definitions name with
        | None -> raise (Lower_error ("unknown enum " ^ name))
        | Some enum_info ->
            let variants = List.map (function
              | VSimple (variant_name, _) -> variant_name, []
              | VTuple (variant_name, types, _) ->
                  variant_name, List.map (resolve_type (name :: resolving)) types
            ) enum_info.enum_variants in
            Enum (name, variants)
    and resolve_interface_type name parameters =
      match Hashtbl.find_opt interface_definitions name with
      | None -> raise (Lower_error ("unknown interface " ^ name))
      | Some interface_info ->
          let type_substitution =
            try List.combine interface_info.interface_type_params parameters
            with Invalid_argument _ -> []
          in
          let rec resolve_member_type = function
            | TVar type_name ->
                (match List.assoc_opt type_name type_substitution with
                 | Some resolved_type -> resolved_type
                 | None -> resolve_type [] (TVar type_name))
            | TList element_type -> List (resolve_member_type element_type)
            | TTuple element_types -> Tuple (List.map resolve_member_type element_types)
            | TGeneric (generic_name, argument) ->
                let arguments = match argument with
                  | TTuple arguments -> List.map resolve_member_type arguments
                  | _ -> [resolve_member_type argument]
                in
                resolve_interface_type generic_name arguments
            | TOption element_type ->
                Enum ("Option", [
                  ("Some", [resolve_member_type element_type]); ("None", [])
                ])
            | TResult (ok_type, error_type) ->
                Enum ("Result", [
                  ("Ok", [resolve_member_type ok_type]);
                  ("Err", [resolve_member_type error_type])
                ])
            | type_expression -> resolve_type [] type_expression
          in
          let methods = List.filter_map (function
            | IMethod (method_name, _, parameters, return_type, _, _) ->
                let parameter_types = List.filter_map (fun (parameter_name, type_expression, _) ->
                  if parameter_name = "self" then None
                  else Some (match type_expression with
                    | Some type_expression -> resolve_member_type type_expression
                    | None -> I32)
                ) parameters in
                let resolved_return_type = match return_type with
                  | Some type_expression -> resolve_member_type type_expression
                  | None -> Unit
                in
                Some (method_name, parameter_types, resolved_return_type)
            | IField _
            | IAssocType _
            | IAssocConst _ -> None
          ) interface_info.interface_members in
          Interface (name, methods)
    in
    let resolve_struct name = resolve_struct_type [] name in
    let resolve_enum name = resolve_enum_type [] name in
    let resolve_interface name = resolve_interface_type name [] in
    let resolve_named name =
      try resolve_struct name with Lower_error struct_error ->
        try resolve_enum name with Lower_error enum_error ->
          try resolve_interface name with Lower_error interface_error ->
            raise (Lower_error ("unknown named type " ^ name ^
              "; struct=" ^ struct_error ^ "; enum=" ^ enum_error ^
              "; interface=" ^ interface_error))
    in
    let signatures = Hashtbl.create 32 in
    let method_signatures = Hashtbl.create 32 in
    let function_definitions = List.filter_map (function
      | SDef def_info -> Some def_info
      | _ -> None
    ) program in
    let method_definitions = List.concat_map (function
      | SStruct struct_info ->
          List.filter_map (function
            | SMethod (method_name, type_params, parameters, return_type,
                       body, position) ->
                if type_params <> [] then
                  raise (Lower_error ("generic struct method is not supported in DIR: " ^
                    struct_info.struct_name ^ "." ^ method_name));
                let function_name = "__dir_method_" ^ struct_info.struct_name ^
                  "_" ^ method_name in
                Some (struct_info.struct_name, method_name, function_name, {
                  def_name = function_name;
                  def_name_pos = position;
                  def_type_params = [];
                  def_params = parameters;
                  def_return_type = return_type;
                  def_body = body;
                  def_pos = position;
                })
            | SField _ -> None
          ) struct_info.struct_members
      | SImpl (impl_block, _) ->
          let target_name = match impl_block.impl_target with
            | TVar name
            | TStruct (name, _) -> name
            | _ -> ""
          in
          let target_is_defined = Hashtbl.mem struct_definitions target_name ||
            Hashtbl.mem enum_definitions target_name in
          if target_name = "" || not target_is_defined then
            []
          else
            let interface_name = match impl_block.impl_interface with
              | Some name -> name
              | None -> "type"
            in
            List.filter_map (function
              | ImplMethod (method_name, type_params, parameters, return_type,
                           body, position) ->
                  if type_params <> [] then
                    raise (Lower_error ("generic impl method is not supported in DIR: " ^
                      target_name ^ "." ^ method_name));
                  let type_suffix = match impl_block.impl_type_params with
                    | [] -> ""
                    | type_params -> "_" ^ String.concat "_" type_params
                  in
                  let function_name = "__dir_impl_" ^ interface_name ^ "_" ^
                    target_name ^ "_" ^ method_name ^ type_suffix in
                  Some (target_name, method_name, function_name, {
                    def_name = function_name;
                    def_name_pos = position;
                    def_type_params = [];
                    def_params = parameters;
                    def_return_type = return_type;
                    def_body = body;
                    def_pos = position;
                  })
              | ImplAssocType _
              | ImplAssocConst _ -> None
            ) impl_block.impl_members
      | _ -> []
    ) program in
    List.iter (fun def_info ->
      add_signature signatures def_info.def_name (signature_of_def resolve_named def_info)
    ) function_definitions;
    List.iter (fun (struct_name, method_name, function_name, def_info) ->
      let signature = signature_of_method resolve_named struct_name
        (method_name, def_info.def_type_params, def_info.def_params,
         def_info.def_return_type, def_info.def_body, def_info.def_pos) in
      add_signature signatures function_name signature;
      Hashtbl.add method_signatures (struct_name ^ "." ^ method_name)
        { function_name; signature }
    ) method_definitions;
    let interface_implementations = Hashtbl.create 16 in
    List.iter (function
      | SImpl (impl_block, _) ->
          (match impl_block.impl_interface, impl_block.impl_target with
           | Some interface_name, (TVar struct_name | TStruct (struct_name, _))
             when Hashtbl.mem interface_definitions interface_name &&
                  (Hashtbl.mem struct_definitions struct_name ||
                   Hashtbl.mem enum_definitions struct_name) ->
               let interface_type = resolve_interface interface_name in
               let method_names = match interface_type with
                 | Interface (_, methods) -> List.map (fun (method_name, _, _) ->
                     match List.find_opt (fun (target_name, target_method, _, _) ->
                       target_name = struct_name && target_method = method_name
                     ) method_definitions with
                     | Some (_, _, function_name, _) -> function_name
                     | None -> raise (Lower_error (Printf.sprintf
                         "interface %s implementation for %s is missing method %s"
                         interface_name struct_name method_name))
                   ) methods
                 | _ -> raise (Lower_error "invalid DIR interface type")
               in
               Hashtbl.replace interface_implementations
                 (interface_name ^ "::" ^ struct_name) method_names
           | _ -> ())
      | _ -> ()) program;
    List.iter (fun (declaration : Dir.extern) ->
      add_signature signatures declaration.name {
        parameter_types = declaration.parameters;
        return_type = declaration.return_type;
      }
    ) runtime_externs;
    let context = {
      signatures;
      method_signatures;
      module_aliases = List.fold_left (fun aliases statement ->
        match statement with
        | SImport (module_path, alias, _) ->
            let name = match alias with
              | Some name -> name
              | None -> List.hd (List.rev module_path)
            in
            StringSet.add name aliases
        | _ -> aliases
      ) StringSet.empty program;
      resolve_struct;
      resolve_enum;
      resolve_interface;
      resolve_named;
      interface_implementations;
      extra_functions = ref [];
      lambda_counter = ref 0;
      global_inits = ref [];
      globals = ref [];
      break_labels = ref [];
      continue_labels = ref [];
    } in
    let top_level = List.filter (function
      | SDef _
      | SStruct _
      | SInterface _
      | SEnum _
      | SImpl _ -> false
      | SLet let_info ->
          context.global_inits := !(context.global_inits) @
            [let_info.let_name, let_info.let_value];
          false
      | _ -> true
    ) program in
    let has_top_level = top_level <> [] in
    let constant_bindings = List.map (fun (name, value) ->
      let typed_value = match value with
        | Const_eval.Int integer -> { operand = Int integer; ty = I32 }
        | Const_eval.Bool boolean -> { operand = Bool boolean; ty = Bool }
        | Const_eval.Byte byte -> { operand = Int byte; ty = I32 }
        | Const_eval.Rune rune -> { operand = Int rune; ty = I32 }
        | Const_eval.Float float -> { operand = Float float; ty = F64 }
        | Const_eval.String string -> { operand = String string; ty = Str }
      in
      name, typed_value
    ) (Const_eval.collect program) in
    let user_main = List.find_opt (fun definition -> definition.def_name = "main")
      function_definitions in
    let other_definitions = List.filter (fun definition ->
      definition.def_name <> "main") function_definitions in
    let lower_main = match user_main with
      | Some main_def -> Some (lower_function context constant_bindings main_def)
      | None when has_top_level || !(context.global_inits) <> [] ->
          let main_def = {
            def_name = "main";
            def_name_pos = { line = 0; column = 0 };
            def_type_params = [];
            def_params = [];
            def_return_type = Some TInt;
            def_body = top_level;
            def_pos = { line = 0; column = 0 };
          } in
          let main_signature = { parameter_types = []; return_type = I32 } in
          add_signature signatures "main" main_signature;
          Some (lower_function context constant_bindings main_def)
      | None -> None
    in
    let main_functions = match lower_main with
      | Some main_function -> [main_function]
      | None -> [] in
    let other_functions = List.map (lower_function context constant_bindings)
      (other_definitions @ List.map (fun (_, _, _, definition) -> definition)
        method_definitions) in
    let functions = main_functions @ other_functions in
    let functions = match lower_main with
      | Some _ -> functions
      | None ->
          let main_def = {
            def_name = "main";
            def_name_pos = { line = 0; column = 0 };
            def_type_params = [];
            def_params = [];
            def_return_type = Some TInt;
            def_body = [];
            def_pos = { line = 0; column = 0 };
          } in
          let main_signature = { parameter_types = []; return_type = I32 } in
          add_signature signatures "main" main_signature;
          functions @ [lower_function context constant_bindings main_def]
    in
    let functions = functions @ List.rev !(context.extra_functions) in
    Ok {
      Dir.name = "dream";
      externs = runtime_externs;
      globals = !(context.globals);
      functions;
    }
  with
  | Lower_error message -> Error message

(* 初始化函数引用以打破互递归 *)
let () =
  Dir_lower_stmt.set_lower_expr lower_expr;
  Dir_lower_stmt.set_lower_expr_expected lower_expr_expected;
  Dir_lower_stmt.set_coerce_value coerce_value
