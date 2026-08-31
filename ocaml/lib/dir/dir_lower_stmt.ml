open Ast
open Dir_lower_types

let lower_expr_ref = ref (fun _ _ _ _ -> { operand = Dir.Int 0; ty = Dir.Unit })
let lower_expr_expected_ref = ref (fun _ _ _ _ _ -> { operand = Dir.Int 0; ty = Dir.Unit })
let coerce_value_ref = ref (fun _ _ _ _ _ -> { operand = Dir.Int 0; ty = Dir.Unit })

let set_lower_expr f = lower_expr_ref := f
let set_lower_expr_expected f = lower_expr_expected_ref := f
let set_coerce_value f = coerce_value_ref := f

let lower_expr context function_builder environment expression =
  !lower_expr_ref context function_builder environment expression

let lower_expr_expected context function_builder environment expected_type expression =
  !lower_expr_expected_ref context function_builder environment expected_type expression

let coerce_value context function_builder position expected_type value =
  !coerce_value_ref context function_builder position expected_type value

let rec lower_statements context function_builder environment statements =
  List.iter (fun statement ->
    if not (is_terminated function_builder) then
      lower_statement context function_builder environment statement
  ) statements

and lower_if context function_builder environment condition then_body elifs else_body position =
  let condition_value = lower_expr context function_builder environment condition in
  expect_type position Bool condition_value.ty "if condition";
  let join_label = fresh_label function_builder "if_join" in
  create_block function_builder join_label;
  let join_bindings = Hashtbl.fold (fun name value bindings ->
    (name, value.ty) :: bindings
  ) environment [] |> List.sort (fun (left, _) (right, _) -> compare left right) in
  let join_parameters = List.map (fun (name, ty) ->
    (name, fresh_value function_builder, ty)
  ) join_bindings in
  let join_arguments branch_environment =
    List.map (fun (name, _, _) ->
      (lookup_value position branch_environment name).operand
    ) join_parameters
  in
  let join_reached = ref false in
  let jump_to_join branch_environment =
    join_reached := true;
    terminate function_builder (Jump (join_label, join_arguments branch_environment))
  in
  let rec lower_branch current_condition current_body remaining_elifs =
    let then_label = fresh_label function_builder "if_then" in
    let next_label = fresh_label function_builder "if_next" in
    create_block function_builder then_label;
    create_block function_builder next_label;
    terminate function_builder (Branch (current_condition,
      (then_label, []), (next_label, [])));
    switch_to function_builder then_label;
    let then_environment = Hashtbl.copy environment in
    lower_statements context function_builder then_environment current_body;
    if not (is_terminated function_builder) then
      jump_to_join then_environment;
    switch_to function_builder next_label;
    match remaining_elifs with
    | (elif_condition, elif_body) :: rest ->
        let lowered_condition = lower_expr context function_builder environment elif_condition in
        expect_type position Bool lowered_condition.ty "elif condition";
        lower_branch lowered_condition.operand elif_body rest
    | [] ->
        (match else_body with
         | Some body ->
             let else_environment = Hashtbl.copy environment in
             lower_statements context function_builder else_environment body;
             if not (is_terminated function_builder) then
               jump_to_join else_environment
         | None -> jump_to_join environment);
  in
  lower_branch condition_value.operand then_body elifs;
  switch_to function_builder join_label;
  if !join_reached then begin
    set_block_params function_builder join_label
      (List.map (fun (_, value, ty) -> (value, ty)) join_parameters);
    Hashtbl.clear environment;
    List.iter (fun (name, value, ty) ->
      Hashtbl.replace environment name { operand = Dir.Value value; ty }
    ) join_parameters
  end else
    terminate function_builder Unreachable

and lower_while context function_builder environment condition body position =
  let condition_label = fresh_label function_builder "while_condition" in
  let body_label = fresh_label function_builder "while_body" in
  let exit_label = fresh_label function_builder "while_exit" in
  let loop_bindings = Hashtbl.fold (fun name value bindings ->
    (name, value) :: bindings
  ) environment [] |> List.sort (fun (left, _) (right, _) -> compare left right) in
  let condition_params = List.map (fun (name, value) ->
    (name, fresh_value function_builder, value.ty)
  ) loop_bindings in
  let body_params = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_params in
  let exit_params = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_params in
  create_block function_builder condition_label;
  create_block function_builder body_label;
  create_block function_builder exit_label;
  terminate function_builder (Jump (condition_label,
    List.map (fun (_, value) -> value.operand) loop_bindings));
  switch_to function_builder condition_label;
  set_block_params function_builder condition_label
    (List.map (fun (_, value, ty) -> (value, ty)) condition_params);
  let condition_environment = Hashtbl.copy environment in
  List.iter2 (fun (name, _) (_, value, ty) ->
    Hashtbl.replace condition_environment name { operand = Dir.Value value; ty }
  ) loop_bindings condition_params;
  let condition_value = lower_expr context function_builder condition_environment condition in
  expect_type position Bool condition_value.ty "while condition";
  let condition_arguments = List.map (fun (_, value, _) -> Dir.Value value) condition_params in
  terminate function_builder (Branch (condition_value.operand,
    (body_label, condition_arguments), (exit_label, condition_arguments)));
  switch_to function_builder body_label;
  set_block_params function_builder body_label
    (List.map (fun (_, value, ty) -> (value, ty)) body_params);
  let body_environment = Hashtbl.copy environment in
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace body_environment name { operand = Dir.Value value; ty }
  ) body_params;
  let previous_break_stack = !(context.break_labels) in
  context.break_labels :=
    (exit_label, List.map (fun (name, _, ty) -> (name, ty)) body_params) :: previous_break_stack;
  let previous_continue_stack = !(context.continue_labels) in
  context.continue_labels :=
    (condition_label, List.map (fun (name, _, ty) -> (name, ty)) condition_params, None)
      :: previous_continue_stack;
  lower_statements context function_builder body_environment body;
  context.break_labels := previous_break_stack;
  context.continue_labels := previous_continue_stack;
  if not (is_terminated function_builder) then
    terminate function_builder (Jump (condition_label,
      List.map (fun (name, _, _) ->
        (Hashtbl.find body_environment name).operand
      ) condition_params));
  switch_to function_builder exit_label;
  set_block_params function_builder exit_label
    (List.map (fun (_, value, ty) -> (value, ty)) exit_params);
  Hashtbl.clear environment;
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace environment name { operand = Dir.Value value; ty }
  ) exit_params

and lower_list_for context function_builder environment pattern lowered_iterable body position =
  let element_type = match lowered_iterable.ty with
    | List element_type -> element_type
    | actual_type -> fail_at position (Printf.sprintf
        "for loop iterable: expected list, got %s" (Dir.ty_to_string actual_type))
  in
  let loop_bindings = Hashtbl.fold (fun name value bindings ->
    (name, value) :: bindings
  ) environment [] |> List.sort (fun (left, _) (right, _) -> compare left right) in
  let condition_label = fresh_label function_builder "for_condition" in
  let body_label = fresh_label function_builder "for_body" in
  let exit_label = fresh_label function_builder "for_exit" in
  let condition_bindings = List.map (fun (name, value) ->
    (name, fresh_value function_builder, value.ty)
  ) loop_bindings in
  let body_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  let exit_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  let condition_index = fresh_value function_builder in
  let body_index = fresh_value function_builder in
  let step_label = fresh_label function_builder "for_step" in
  List.iter (create_block function_builder) [condition_label; body_label; exit_label; step_label];
  let initial_arguments = List.map (fun (_, value) -> value.operand) loop_bindings in
  terminate function_builder (Jump (condition_label, initial_arguments @ [Dir.Int 0]));
  switch_to function_builder condition_label;
  set_block_params function_builder condition_label
    (List.map (fun (_, value, ty) -> (value, ty)) condition_bindings @
     [(condition_index, Dir.I32)]);
  let length = fresh_value function_builder in
  emit function_builder (Dir.ListLength (length, lowered_iterable.operand));
  let has_more = fresh_value function_builder in
  emit function_builder (Dir.Compare (has_more, Dir.Lt, Dir.Value condition_index, Dir.Value length));
  let condition_values = List.map (fun (_, value, _) -> Dir.Value value) condition_bindings in
  terminate function_builder (Branch (Value has_more,
    (body_label, condition_values @ [Value condition_index]),
    (exit_label, condition_values)));
  switch_to function_builder body_label;
  set_block_params function_builder body_label
    (List.map (fun (_, value, ty) -> (value, ty)) body_bindings @
     [(body_index, Dir.I32)]);
  let body_environment = Hashtbl.copy environment in
  List.iter2 (fun (name, _) (_, value, ty) ->
    Hashtbl.replace body_environment name { operand = Dir.Value value; ty }
  ) loop_bindings body_bindings;
  let item = fresh_value function_builder in
  emit function_builder (Dir.ListGet (item, lowered_iterable.operand, Dir.Value body_index));
  (match pattern with
   | PVar name ->
       Hashtbl.replace body_environment name { operand = Dir.Value item; ty = element_type }
   | PWildcard -> ()
   | PTuple patterns ->
       let element_types = match element_type with
         | Tuple element_types -> element_types
         | actual_type -> fail_at position (Printf.sprintf
             "tuple pattern requires a tuple element, got %s"
             (Dir.ty_to_string actual_type))
       in
       if List.length patterns <> List.length element_types then
         fail_at position "tuple pattern length does not match element";
       List.iteri (fun index sub_pattern ->
         match sub_pattern with
         | PVar name ->
             let value = fresh_value function_builder in
             emit function_builder (Dir.TupleGet (value, List.nth element_types index,
               Value item, index));
             Hashtbl.replace body_environment name
               { operand = Dir.Value value; ty = List.nth element_types index }
         | PWildcard -> ()
         | _ -> fail_at position "DIR for tuple patterns only support variables and wildcards"
       ) patterns
   | _ -> fail_at position "DIR for loops only support variable, wildcard and tuple patterns");
  let previous_break_stack = !(context.break_labels) in
  context.break_labels :=
    (exit_label, List.map (fun (name, _, ty) -> (name, ty)) body_bindings) :: previous_break_stack;
  let previous_continue_stack = !(context.continue_labels) in
  context.continue_labels :=
    (step_label, List.map (fun (name, _, ty) -> (name, ty)) condition_bindings, Some body_index)
      :: previous_continue_stack;
  lower_statements context function_builder body_environment body;
  context.break_labels := previous_break_stack;
  context.continue_labels := previous_continue_stack;
  if not (is_terminated function_builder) then begin
    let back_values = List.map (fun (name, _, _) ->
      (Hashtbl.find body_environment name).operand
    ) body_bindings in
    terminate function_builder (Jump (step_label, back_values @ [Dir.Value body_index]))
  end;
  switch_to function_builder step_label;
  let step_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  let step_index = fresh_value function_builder in
  set_block_params function_builder step_label
    (List.map (fun (_, value, ty) -> (value, ty)) step_bindings @
     [(step_index, Dir.I32)]);
  let step_next = fresh_value function_builder in
  emit function_builder (Dir.Binop (step_next, Dir.I32, Dir.Add,
    Dir.Value step_index, Dir.Int 1));
  let step_named_values = List.map (fun (_, value, _) -> Dir.Value value) step_bindings in
  terminate function_builder (Jump (condition_label, step_named_values @ [Dir.Value step_next]));
  switch_to function_builder exit_label;
  set_block_params function_builder exit_label
    (List.map (fun (_, value, ty) -> (value, ty)) exit_bindings);
  Hashtbl.clear environment;
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace environment name { operand = Dir.Value value; ty }
  ) exit_bindings

and lower_protocol_for context function_builder environment pattern iterator body position =
  let iterator_name = "__dir_iterator" in
  let iterator_environment = Hashtbl.copy environment in
  Hashtbl.replace iterator_environment iterator_name iterator;
  let loop_bindings = Hashtbl.fold (fun name value bindings ->
    (name, value) :: bindings
  ) environment [] |> List.sort (fun (left, _) (right, _) -> compare left right) in
  let condition_label = fresh_label function_builder "for_condition" in
  let body_label = fresh_label function_builder "for_body" in
  let exit_label = fresh_label function_builder "for_exit" in
  let step_label = fresh_label function_builder "for_step" in
  let condition_bindings = List.map (fun (name, value) ->
    (name, fresh_value function_builder, value.ty)
  ) loop_bindings in
  let body_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  let exit_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  List.iter (create_block function_builder)
    [condition_label; body_label; step_label; exit_label];
  let initial_arguments = List.map (fun (_, value) -> value.operand) loop_bindings in
  terminate function_builder (Jump (condition_label, initial_arguments));
  switch_to function_builder condition_label;
  set_block_params function_builder condition_label
    (List.map (fun (_, value, ty) -> (value, ty)) condition_bindings);
  let has_next_expression = ECall (
    EEnumVariant (iterator_name, "has_next", [], position), [], position) in
  let has_next = lower_expr context function_builder iterator_environment has_next_expression in
  expect_type position Dir.Bool has_next.ty "Iterator.has_next";
  let condition_values = List.map (fun (_, value, _) -> Dir.Value value) condition_bindings in
  terminate function_builder (Branch (has_next.operand,
    (body_label, condition_values), (exit_label, condition_values)));
  switch_to function_builder body_label;
  set_block_params function_builder body_label
    (List.map (fun (_, value, ty) -> (value, ty)) body_bindings);
  let body_environment = Hashtbl.copy iterator_environment in
  List.iter2 (fun (name, _) (_, value, ty) ->
    Hashtbl.replace body_environment name { operand = Dir.Value value; ty }
  ) loop_bindings body_bindings;
  let next_expression = ECall (
    EEnumVariant (iterator_name, "next", [], position), [], position) in
  let item = lower_expr context function_builder body_environment next_expression in
  let element_type = item.ty in
  let bind_pattern = function
    | PVar name ->
        Hashtbl.replace body_environment name item
    | PWildcard -> ()
    | PTuple patterns ->
        let element_types = match element_type with
          | Dir.Tuple element_types -> element_types
          | actual_type -> fail_at position (Printf.sprintf
              "tuple pattern requires a tuple element, got %s"
              (Dir.ty_to_string actual_type))
        in
        if List.length patterns <> List.length element_types then
          fail_at position "tuple pattern length does not match element";
        List.iteri (fun index sub_pattern ->
          match sub_pattern with
          | PVar name ->
              let value = fresh_value function_builder in
              emit function_builder (Dir.TupleGet (value, List.nth element_types index,
                item.operand, index));
              Hashtbl.replace body_environment name
                { operand = Dir.Value value; ty = List.nth element_types index }
          | PWildcard -> ()
          | _ -> fail_at position "DIR for tuple patterns only support variables and wildcards"
        ) patterns
    | _ -> fail_at position "DIR for loops only support variable, wildcard and tuple patterns"
  in
  bind_pattern pattern;
  let previous_break_stack = !(context.break_labels) in
  context.break_labels :=
    (exit_label, List.map (fun (name, _, ty) -> (name, ty)) body_bindings) :: previous_break_stack;
  let previous_continue_stack = !(context.continue_labels) in
  context.continue_labels :=
    (step_label, List.map (fun (name, _, ty) -> (name, ty)) condition_bindings, None)
    :: previous_continue_stack;
  lower_statements context function_builder body_environment body;
  context.break_labels := previous_break_stack;
  context.continue_labels := previous_continue_stack;
  if not (is_terminated function_builder) then begin
    let back_values = List.map (fun (name, _, _) ->
      (Hashtbl.find body_environment name).operand
    ) body_bindings in
    terminate function_builder (Jump (step_label, back_values))
  end;
  switch_to function_builder step_label;
  let step_bindings = List.map (fun (name, _, ty) ->
    (name, fresh_value function_builder, ty)
  ) condition_bindings in
  set_block_params function_builder step_label
    (List.map (fun (_, value, ty) -> (value, ty)) step_bindings);
  let step_values = List.map (fun (_, value, _) -> Dir.Value value) step_bindings in
  terminate function_builder (Jump (condition_label, step_values));
  switch_to function_builder exit_label;
  set_block_params function_builder exit_label
    (List.map (fun (_, value, ty) -> (value, ty)) exit_bindings);
  Hashtbl.clear environment;
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace environment name { operand = Dir.Value value; ty }
  ) exit_bindings

and lower_for context function_builder environment pattern iterable body position =
  let lowered_iterable = lower_expr context function_builder environment iterable in
  match lowered_iterable.ty with
  | Dir.List _ -> lower_list_for context function_builder environment pattern lowered_iterable body position
  | Dir.Interface ("Iterator", _) ->
      lower_protocol_for context function_builder environment pattern lowered_iterable body position
  | Dir.Interface ("Iterable", _) ->
      let iterable_name = "__dir_iterable" in
      let iterable_environment = Hashtbl.copy environment in
      Hashtbl.replace iterable_environment iterable_name lowered_iterable;
      let iterator_expression = ECall (
        EEnumVariant (iterable_name, "iter", [], position), [], position) in
      let iterator = lower_expr context function_builder iterable_environment iterator_expression in
      (match iterator.ty with
       | Dir.Interface ("Iterator", _) ->
           lower_protocol_for context function_builder environment pattern iterator body position
       | actual_type -> fail_at position (Printf.sprintf
           "Iterable.iter must return Iterator, got %s" (Dir.ty_to_string actual_type)))
  | Dir.Struct (struct_name, _) when Hashtbl.mem context.method_signatures
      (struct_name ^ ".iter") ->
      let iterable_name = "__dir_iterable" in
      let iterable_environment = Hashtbl.copy environment in
      Hashtbl.replace iterable_environment iterable_name lowered_iterable;
      let iterator_expression = ECall (
        EEnumVariant (iterable_name, "iter", [], position), [], position) in
      let iterator = lower_expr context function_builder iterable_environment iterator_expression in
      (match iterator.ty with
       | Dir.Interface ("Iterator", _) ->
           lower_protocol_for context function_builder environment pattern iterator body position
       | actual_type -> fail_at position (Printf.sprintf
           "iter must return Iterator, got %s" (Dir.ty_to_string actual_type)))
  | Dir.Struct (struct_name, _) when Hashtbl.mem context.method_signatures
      (struct_name ^ ".has_next") && Hashtbl.mem context.method_signatures
      (struct_name ^ ".next") ->
      lower_protocol_for context function_builder environment pattern lowered_iterable body position
  | actual_type -> fail_at position (Printf.sprintf
      "for loop iterable requires a list, Iterator or Iterable, got %s"
      (Dir.ty_to_string actual_type))

and lower_statement context function_builder environment statement =
  match statement with
  | SExpr (expression, _) -> ignore (lower_expr context function_builder environment expression)
  | SConst const_info ->
      let value = lower_expr context function_builder environment const_info.const_value in
      Hashtbl.replace environment const_info.const_name value
  | SLet let_info ->
      let value, annotated_type = match let_info.let_type with
        | Some type_expression ->
            let annotated_type = type_of_ast context.resolve_named type_expression in
            lower_expr_expected context function_builder environment
              (Some annotated_type) let_info.let_value,
            Some annotated_type
        | None ->
            lower_expr context function_builder environment let_info.let_value,
            None
      in
      let value = match annotated_type with
        | Some annotated_type ->
            coerce_value context function_builder let_info.let_pos annotated_type value
        | None -> value
      in
      Hashtbl.replace environment let_info.let_name value
  | SReturn (expression, position) ->
      (match expression with
       | None ->
           if not (Dir.equal_ty function_builder.return_type Dir.Unit) &&
              not (Dir.equal_ty function_builder.return_type Dir.I32) then
             fail_at position "return without a value requires unit or main return type"
           else
             terminate function_builder (default_return function_builder.return_type)
       | Some value_expression ->
           let value = match value_expression with
             | EDict ([], _) -> lower_expr_expected context function_builder environment
                 (Some function_builder.return_type) value_expression
             | _ -> lower_expr context function_builder environment value_expression
           in
           let value = coerce_value context function_builder position
             function_builder.return_type value in
           mark_interface_box_escaped function_builder value.operand;
           release_interface_boxes function_builder;
           terminate function_builder (Dir.Return (Some value.operand)))
  | SIf (condition, then_body, elifs, else_body, position) ->
      lower_if context function_builder environment condition then_body elifs else_body position
  | SWhile (condition, body, position) ->
      lower_while context function_builder environment condition body position
  | SFor (pattern, iterable, body, position) ->
      lower_for context function_builder environment pattern iterable body position
  | SBreak position ->
      (match !(context.break_labels) with
       | [] -> fail_at position "break outside of loop"
       | (exit_label, param_names) :: _ ->
           let arguments = List.map (fun (name, _) ->
             match Hashtbl.find_opt environment name with
             | Some value -> value.operand
             | None -> fail_at position ("unknown variable " ^ name)
           ) param_names in
           release_interface_boxes function_builder;
           terminate function_builder (Jump (exit_label, arguments)))
  | SContinue position ->
      (match !(context.continue_labels) with
       | [] -> fail_at position "continue outside of loop"
       | (target_label, param_names, index_value) :: _ ->
           let arguments = List.map (fun (name, _) ->
             match Hashtbl.find_opt environment name with
             | Some value -> value.operand
             | None -> fail_at position ("unknown variable " ^ name)
           ) param_names in
           let arguments = match index_value with
             | None -> arguments
             | Some current_index -> arguments @ [Dir.Value current_index]
           in
           release_interface_boxes function_builder;
           terminate function_builder (Jump (target_label, arguments)))
  | SAssign (name, expression, position) ->
      (match Hashtbl.find_opt environment name with
       | Some previous_value ->
           let value = lower_expr context function_builder environment expression in
           let value = coerce_value context function_builder position previous_value.ty value in
           Hashtbl.replace environment name value
       | None ->
           (match List.find_opt (fun (global_name, _) -> global_name = name)
              !(context.globals) with
            | Some (_, global_type) ->
                let value = lower_expr context function_builder environment expression in
                let value = coerce_value context function_builder position global_type value in
                emit function_builder (Dir.GlobalStore (name, value.operand))
            | None -> fail_at position ("unknown variable " ^ name)))
  | SIndexAssign (collection, index, expression, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let lowered_index = lower_expr context function_builder environment index in
      let lowered_value = lower_expr context function_builder environment expression in
      (match lowered_collection.ty with
       | Dir.List Dir.I32 ->
           expect_type position Dir.I32 lowered_index.ty "index assignment index";
           expect_type position Dir.I32 lowered_value.ty "index assignment value";
           emit function_builder (Dir.ListSet (
             lowered_collection.operand, lowered_index.operand, lowered_value.operand))
       | Dir.Dict (key_type, value_type) ->
           expect_type position key_type lowered_index.ty "dict assignment key";
           expect_type position value_type lowered_value.ty "dict assignment value";
           let setter_name = match key_type, value_type with
             | Dir.I32, Dir.I32 -> "__c_dict_set_int_int"
             | Dir.I32, Dir.Str -> "__c_dict_set_int_str"
             | Dir.Str, Dir.I32 -> "__c_dict_set_str_int"
             | Dir.Str, Dir.Str -> "__c_dict_set_str_str"
             | Dir.I32, _ -> "__c_dict_set_int_ptr"
             | Dir.Str, _ -> "__c_dict_set_str_ptr"
             | _ -> fail_at position "DIR dict supports only int and str keys"
           in
           emit function_builder (Dir.Call (None, Dir.Unit, setter_name,
             [lowered_collection.ty; key_type; value_type],
             [lowered_collection.operand; lowered_index.operand; lowered_value.operand]))
       | _ -> fail_at position "index assignment requires a list or dict")
  | SImport _
  | SFromImport _ ->
      ()
  | SDef _ -> fail_at { line = 0; column = 0 } "nested function definitions are unsupported"
  | SLetPat (pattern, expression, position) ->
      let lowered_value = lower_expr context function_builder environment expression in
      let rec bind_pattern pattern value =
        match pattern with
        | PWildcard -> ()
        | PVar name -> Hashtbl.replace environment name value
        | PTuple patterns ->
            (match value.ty with
             | Tuple element_types when List.length patterns = List.length element_types ->
                 List.iteri (fun index pattern ->
                   let element_type = List.nth element_types index in
                   let element_value = fresh_value function_builder in
                   emit function_builder (Dir.TupleGet (element_value, element_type,
                     value.operand, index));
                   bind_pattern pattern { operand = Dir.Value element_value; ty = element_type }
                 ) patterns
             | Tuple _ -> fail_at position "tuple pattern length does not match value"
             | _ -> fail_at position "tuple pattern requires a tuple value")
        | PStruct (struct_name, field_patterns) ->
            (match value.ty with
             | Struct (actual_name, fields) when struct_name = "" || struct_name = actual_name ->
                 List.iter (fun (field_name, field_pattern) ->
                   let field_index, field_type = match List.find_index
                       (fun (name, _) -> name = field_name) fields with
                     | None -> fail_at position ("unknown struct field " ^ field_name)
                     | Some index -> index, snd (List.nth fields index)
                   in
                   let field_value = fresh_value function_builder in
                   emit function_builder (Dir.StructGet (field_value, field_type,
                     value.operand, field_index));
                   bind_pattern field_pattern { operand = Dir.Value field_value; ty = field_type }
                 ) field_patterns
             | Struct _ -> fail_at position "struct pattern name does not match value"
             | _ -> fail_at position "struct pattern requires a struct value")
        | _ -> fail_at position "DIR supports only variable, tuple and struct let patterns"
      in
      bind_pattern pattern lowered_value
  | SFieldAssign (object_expression, field_name, expression, position) ->
      let object_value = lower_expr context function_builder environment object_expression in
      let fields = match object_value.ty with
        | Struct (_, fields)
        | Ref (Struct (_, fields)) -> fields
        | _ -> fail_at position "field assignment requires a struct value"
      in
      let field_index, field_type = match List.find_index
          (fun (name, _) -> name = field_name) fields with
        | None -> fail_at position ("unknown struct field " ^ field_name)
        | Some index -> index, snd (List.nth fields index)
      in
      let lowered_value = lower_expr context function_builder environment expression in
      expect_type position field_type lowered_value.ty ("struct field " ^ field_name);
      (match object_value.ty with
       | Ref (Struct _) ->
           let set_id = fresh_value function_builder in
           emit function_builder (Dir.StructSet (set_id, object_value.operand,
             field_type, field_index, lowered_value.operand))
       | Struct _ ->
           let field_values = List.mapi (fun index (_, current_type) ->
             if index = field_index then lowered_value.operand
             else
               let current = fresh_value function_builder in
               emit function_builder (Dir.StructGet (current, current_type,
                 object_value.operand, index));
               Value current
           ) fields in
           let struct_name = match object_value.ty with
             | Struct (name, _) -> name
             | _ -> assert false
           in
           let updated_value = fresh_value function_builder in
           emit function_builder (Dir.StructCreate (updated_value, struct_name, fields, field_values));
           (match object_expression with
            | EVar (name, _) -> Hashtbl.replace environment name
                { operand = Dir.Value updated_value; ty = object_value.ty }
            | _ -> fail_at position "DIR field assignment requires a local struct variable")
       | _ -> fail_at position "field assignment requires a struct value")
  | SImpl (_, position) ->
      fail_at position "DIR does not support impl statements yet"
  | SStruct struct_info ->
      fail_at struct_info.struct_pos "statement is outside the initial DIR subset"
  | SInterface interface_info ->
      fail_at interface_info.interface_pos "statement is outside the initial DIR subset"
  | SEnum enum_info ->
      fail_at enum_info.enum_pos "statement is outside the initial DIR subset"
