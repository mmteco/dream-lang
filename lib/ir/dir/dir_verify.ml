open Dir

type error = string

let verify module_ =
  let errors = ref [] in
  let add_error message = errors := message :: !errors in
  let function_signatures = Hashtbl.create 16 in
  let add_signature name parameters return_type =
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
    | Bool _ when equal_ty expected_type Bool -> ()
    | String _ when equal_ty expected_type Str -> ()
    | Value value ->
        (match Hashtbl.find_opt value_types value with
         | Some actual_type when equal_ty actual_type expected_type -> ()
         | Some actual_type ->
             add_error (Printf.sprintf "%s: expected %s, got %s"
               context (ty_to_string expected_type) (ty_to_string actual_type))
         | None ->
             add_error (Printf.sprintf "%s: undefined value %%v%d" context value))
    | Int _ | Bool _ | String _ ->
        add_error (Printf.sprintf "%s: expected %s" context (ty_to_string expected_type))
  in

  let verify_call value_types result_value result_type name argument_types arguments =
    match Hashtbl.find_opt function_signatures name with
    | None -> add_error ("unknown function: " ^ name)
    | Some (parameter_types, declared_return_type) ->
        if not (equal_ty result_type declared_return_type) then
          add_error (Printf.sprintf "call %s: result type %s does not match declaration %s"
            name (ty_to_string result_type) (ty_to_string declared_return_type));
        if List.length parameter_types <> List.length arguments then
          add_error (Printf.sprintf "call %s: expected %d arguments, got %d"
            name (List.length parameter_types) (List.length arguments))
        else if List.length argument_types <> List.length arguments then
          add_error (Printf.sprintf "call %s: expected %d argument types, got %d"
            name (List.length arguments) (List.length argument_types))
        else
          List.iter (fun ((expected_type, declared_type), argument) ->
            if not (equal_ty expected_type declared_type) then
              add_error (Printf.sprintf "call %s: argument type %s does not match declaration %s"
                name (ty_to_string declared_type) (ty_to_string expected_type));
            verify_operand value_types argument expected_type ("call " ^ name)
          ) (List.combine (List.combine parameter_types argument_types) arguments);
        (match result_value with
         | Some value ->
             if Hashtbl.mem value_types value then
               add_error (Printf.sprintf "duplicate value %%v%d" value)
             else
               Hashtbl.add value_types value declared_return_type
         | None -> ())
  in

  let verify_instruction value_types instruction =
    (match instruction with
     | Binop (value, result_type, operation, left, right) ->
         let expected_result_type : ty = if operation = And || operation = Or then (Bool : ty) else I32 in
         if not (equal_ty result_type expected_result_type) then
           add_error (Printf.sprintf "binary operation must return %s"
             (ty_to_string expected_result_type));
         if operation = And || operation = Or then begin
           verify_operand value_types left Bool "boolean binary operation";
           verify_operand value_types right Bool "boolean binary operation"
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
           | Bool _ -> Bool
           | String _ -> Str
           | Value left_value ->
               (match Hashtbl.find_opt value_types left_value with
                | Some ty -> ty
                | None -> I32)
         in
         verify_operand value_types left expected_type "comparison left operand";
         verify_operand value_types right expected_type "comparison right operand";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value Bool
     | Call (result_value, result_type, name, argument_types, arguments) ->
         verify_call value_types result_value result_type name argument_types arguments
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
         verify_operand value_types collection (List I32) "list_length";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | ListGet (value, collection, index) ->
         verify_operand value_types collection (List I32) "list_get collection";
         verify_operand value_types index I32 "list_get index";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value I32
     | ListCreate (value, element_type, values) ->
         if not (equal_ty element_type I32) then
           add_error "list_create currently supports only i32 elements";
         List.iter (fun item ->
           verify_operand value_types item element_type "list_create element"
         ) values;
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (List element_type)
     | ListSlice (value, collection, start, end_) ->
         verify_operand value_types collection (List I32) "list_slice collection";
         verify_operand value_types start I32 "list_slice start";
         verify_operand value_types end_ I32 "list_slice end";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (List I32)
     | ListConcat (value, left, right) ->
         verify_operand value_types left (List I32) "list_concat left";
         verify_operand value_types right (List I32) "list_concat right";
         if Hashtbl.mem value_types value then
           add_error (Printf.sprintf "duplicate value %%v%d" value)
         else
           Hashtbl.add value_types value (List I32)
     | TupleCreate (value, element_types, values) ->
         if List.length element_types <> List.length values then
           add_error "tuple_create element count does not match type count";
         if List.length element_types = List.length values then
           List.iter2 (fun element_type item ->
             if not (equal_ty element_type I32) then
               add_error "tuple_create currently supports only i32 elements";
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
     | ListAppend (collection, value) ->
         verify_operand value_types collection (List I32) "list_append collection";
         verify_operand value_types value I32 "list_append value"
     | ListSet (collection, index, value) ->
         verify_operand value_types collection (List I32) "list_set collection";
         verify_operand value_types index I32 "list_set index";
         verify_operand value_types value I32 "list_set value");
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
    let value_types = Hashtbl.create 64 in
    List.iter (fun parameter ->
      if Hashtbl.mem value_types parameter.value then
        add_error (Printf.sprintf "duplicate parameter %%v%d" parameter.value)
      else
        Hashtbl.add value_types parameter.value parameter.ty
    ) function_def.parameters;
    List.iter (fun block ->
      List.iter (fun (value, ty) ->
        if Hashtbl.mem value_types value then
          add_error (Printf.sprintf "duplicate block parameter %%v%d" value)
        else
          Hashtbl.add value_types value ty
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
      List.iter (verify_instruction value_types) block.instructions;
      match block.terminator with
      | Jump (label, arguments) -> verify_target label arguments
      | Branch (condition, (then_label, then_arguments), (else_label, else_arguments)) ->
          verify_operand value_types condition Bool "branch condition";
          verify_target then_label then_arguments;
          verify_target else_label else_arguments
      | Switch (value, cases, (default_label, default_arguments)) ->
          verify_operand value_types value I32 "switch value";
          List.iter (fun (case_value, label, arguments) ->
            verify_operand value_types case_value I32 "switch case";
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
