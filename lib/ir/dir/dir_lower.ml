open Ast
open Dir

type typed_operand = {
  operand: Dir.operand;
  ty: Dir.ty;
}

type function_signature = {
  parameter_types: Dir.ty list;
  return_type: Dir.ty;
}

type block_builder = {
  label: string;
  mutable params: (Dir.value * Dir.ty) list;
  mutable instructions: Dir.instruction list;
  mutable terminator: Dir.terminator option;
}

type function_builder = {
  name: string;
  return_type: Dir.ty;
  mutable next_value: int;
  mutable next_label: int;
  blocks: (string, block_builder) Hashtbl.t;
  mutable block_order: string list;
  mutable current_label: string;
}

type context = {
  signatures: (string, function_signature) Hashtbl.t;
}

exception Lower_error of string

let position_text position =
  Printf.sprintf "line %d, column %d" position.line position.column

let fail_at position message =
  raise (Lower_error (Printf.sprintf "%s (%s)" message (position_text position)))

let rec type_of_ast = function
  | TInt -> I32
  | TBool -> Bool
  | TStr -> Str
  | TList element_type -> List (type_of_ast element_type)
  | TTuple element_types -> Tuple (List.map type_of_ast element_types)
  | TNone -> Unit
  | TVar _ -> I32
  | type_expression ->
      raise (Lower_error (Printf.sprintf "DIR subset does not support type %s"
        (match type_expression with
         | TFloat -> "float"
         | TRune -> "rune"
         | TByte -> "byte"
         | TBytes -> "bytes"
         | TDict _ -> "dict"
         | TTuple _ -> "tuple"
         | TFunc _ -> "function"
         | TUnion _ -> "union"
         | TVar name -> name
         | TGeneric (name, _) -> name
         | TOption _ -> "option"
         | TResult _ -> "result"
         | TEnum (name, _) -> name
         | TStruct (name, _) -> name
         | TInt | TBool | TStr | TList _ | TNone -> "unknown")))

let rec expression_type_hint = function
  | EInt _ -> Some I32
  | EBool _ -> Some Bool
  | EString _ -> Some Str
  | EList (elements, _) ->
      if List.for_all (fun element -> expression_type_hint element = Some I32) elements then
        Some (List I32)
      else
        None
  | ETuple (elements, _) ->
      let element_types = List.map expression_type_hint elements in
      if List.for_all Option.is_some element_types then
        Some (Tuple (List.map Option.get element_types))
      else
        None
  | EBinOp (left, operation, _, _) ->
      (match operation, expression_type_hint left with
       | (Eq | Neq | Lt | Gt | Lte | Gte | And | Or), _ -> Some Bool
       | (Add | Sub | Mul | Div | Mod), Some I32 -> Some I32
       | Add, Some (List I32) -> Some (List I32)
       | _ -> None)
  | EUnOp (Neg, _, _) -> Some I32
  | EUnOp (Not, _, _) -> Some Bool
  | EIndex _ -> Some I32
  | ESlice (collection, _, _, _) ->
      (match expression_type_hint collection with
       | Some (List I32) -> Some (List I32)
       | Some Str -> Some Str
       | _ -> None)
  | ECall (EVar ("len", _), _, _)
  | ECall (EVar ("text_char_code", _), _, _) -> Some I32
  | ECall (EVar ("text_length", _), _, _) -> Some I32
  | ECall (EVar ("read_text_file", _), _, _) -> Some Str
  | ECall (EVar ("write_text_codes", _), _, _) -> Some I32
  | ECall _ -> Some I32
  | EVar _
  | EIf _
  | EMatch _
  | EDict _
  | EAttr _
  | ELambda _
  | EListComp _
  | EEnumVariant _
  | EStructLiteral _
  | EStructAccess _
  | ETernary _
  | ETry _
  | ETypeOf _
  | EFloat _
  | ERune _
  | EByte _ -> None

let rec first_return_type statements =
  match statements with
  | [] -> None
  | SReturn (Some expression, _) :: _ -> expression_type_hint expression
  | SReturn (None, _) :: _ -> Some Unit
  | SIf (_, then_body, elifs, else_body, _) :: rest ->
      (match first_return_type then_body with
       | Some _ as result -> result
       | None ->
           (match List.find_map (fun (_, body) -> first_return_type body) elifs with
            | Some _ as result -> result
            | None ->
                (match else_body with
                 | Some body ->
                     (match first_return_type body with
                      | Some _ as result -> result
                      | None -> first_return_type rest)
                 | None -> first_return_type rest)))
  | SWhile (_, body, _) :: rest ->
      (match first_return_type body with
       | Some _ as result -> result
       | None -> first_return_type rest)
  | _ :: rest -> first_return_type rest

let signature_of_def def_info =
  let parameter_types = List.map (fun (name, type_opt, default_opt) ->
    match type_opt, default_opt with
    | Some type_expression, None -> type_of_ast type_expression
    | Some _, Some _ ->
        raise (Lower_error ("DIR subset does not support default parameter " ^ name))
    | None, _ ->
        raise (Lower_error ("missing type annotation for parameter " ^ name))
  ) def_info.def_params in
  let return_type = match def_info.def_return_type with
    | Some type_expression -> type_of_ast type_expression
    | None when def_info.def_name = "main" -> I32
    | None ->
        (match first_return_type def_info.def_body with
         | Some return_type -> return_type
         | None -> Unit)
  in
  { parameter_types; return_type }

let add_signature signatures name signature =
  if Hashtbl.mem signatures name then
    raise (Lower_error ("duplicate function " ^ name))
  else
    Hashtbl.add signatures name signature

let new_function name return_type parameter_types =
  let blocks = Hashtbl.create 16 in
  let entry = {
    label = "entry";
    params = [];
    instructions = [];
    terminator = None;
  } in
  Hashtbl.add blocks entry.label entry;
  {
    name;
    return_type;
    next_value = List.length parameter_types + 1;
    next_label = 0;
    blocks;
    block_order = [entry.label];
    current_label = entry.label;
  }

let current_block function_builder =
  Hashtbl.find function_builder.blocks function_builder.current_label

let fresh_value function_builder =
  let value = function_builder.next_value in
  function_builder.next_value <- value + 1;
  value

let fresh_label function_builder prefix =
  let label = Printf.sprintf "%s_%d" prefix function_builder.next_label in
  function_builder.next_label <- function_builder.next_label + 1;
  label

let create_block function_builder label =
  if Hashtbl.mem function_builder.blocks label then
    raise (Lower_error ("duplicate DIR block " ^ label));
  let block = {
    label;
    params = [];
    instructions = [];
    terminator = None;
  } in
  Hashtbl.add function_builder.blocks label block;
  function_builder.block_order <- function_builder.block_order @ [label];
  ()

let switch_to function_builder label =
  if not (Hashtbl.mem function_builder.blocks label) then
    raise (Lower_error ("unknown DIR block " ^ label));
  function_builder.current_label <- label

let is_terminated function_builder =
  (current_block function_builder).terminator <> None

let emit function_builder instruction =
  if is_terminated function_builder then
    raise (Lower_error ("instruction emitted after terminator in " ^ function_builder.name));
  let block = current_block function_builder in
  block.instructions <- block.instructions @ [instruction]

let terminate function_builder terminator =
  let block = current_block function_builder in
  match block.terminator with
  | Some _ ->
      raise (Lower_error ("block already terminated: " ^ block.label))
  | None -> block.terminator <- Some terminator

let set_block_params function_builder label params =
  let block = Hashtbl.find function_builder.blocks label in
  block.params <- params

let default_return return_type =
  match return_type with
  | Unit -> Return None
  | I32 -> Return (Some (Int 0))
  | Bool -> Return (Some (Bool false))
  | Str | List _ | Tuple _ ->
      raise (Lower_error "DIR subset cannot synthesize a default reference return")

let finish_function function_builder parameters =
  if not (is_terminated function_builder) then
    terminate function_builder (default_return function_builder.return_type);
  let blocks : Dir.block list = List.map (fun label ->
    let block = Hashtbl.find function_builder.blocks label in
    let terminator = match block.terminator with
      | Some value -> value
      | None -> Unreachable
    in
    ({
      Dir.label = block.label;
      params = block.params;
      instructions = block.instructions;
      terminator;
    } : Dir.block)
  ) function_builder.block_order in
  {
    name = function_builder.name;
    parameters;
    return_type = function_builder.return_type;
    blocks;
  }

let expect_type position expected actual description =
  if not (Dir.equal_ty expected actual) then
    fail_at position (Printf.sprintf "%s: expected %s, got %s"
      description (Dir.ty_to_string expected) (Dir.ty_to_string actual))

let lookup_value position environment name =
  match Hashtbl.find_opt environment name with
  | Some value -> value
  | None -> fail_at position ("unknown variable " ^ name)

let binop_of_ast position = function
  | Ast.Add -> Dir.Add
  | Ast.Sub -> Dir.Sub
  | Ast.Mul -> Dir.Mul
  | Ast.Div -> Dir.Div
  | Ast.Mod -> Dir.Mod
  | Ast.And -> Dir.And
  | Ast.Or -> Dir.Or
  | Ast.Eq | Ast.Neq | Ast.Lt | Ast.Gt | Ast.Lte | Ast.Gte ->
      fail_at position "comparison is not an arithmetic operation"

let compare_of_ast = function
  | Ast.Eq -> Dir.Eq
  | Ast.Neq -> Dir.Ne
  | Ast.Lt -> Dir.Lt
  | Ast.Gt -> Dir.Gt
  | Ast.Lte -> Dir.Le
  | Ast.Gte -> Dir.Ge
  | Ast.Add | Ast.Sub | Ast.Mul | Ast.Div | Ast.Mod | Ast.And | Ast.Or -> assert false

let rec lower_expr context function_builder environment expression =
  match expression with
  | EInt (value, _) -> { operand = Int value; ty = I32 }
  | EBool (value, _) -> { operand = Bool value; ty = Bool }
  | EString (value, _) -> { operand = String value; ty = Str }
  | EVar (name, position) -> lookup_value position environment name
  | EBinOp (left_expression, operation, right_expression, position) ->
      let left = lower_expr context function_builder environment left_expression in
      let right = lower_expr context function_builder environment right_expression in
      expect_type position left.ty right.ty "binary operands";
      (match operation with
       | Add | Sub | Mul | Div | Mod ->
           (match left.ty with
            | List I32 when operation = Add ->
                let value = fresh_value function_builder in
                emit function_builder (ListConcat (value, left.operand, right.operand));
                { operand = Value value; ty = List I32 }
            | _ ->
                expect_type position I32 left.ty "arithmetic operand";
                let value = fresh_value function_builder in
                emit function_builder (Binop (value, I32, binop_of_ast position operation,
                  left.operand, right.operand));
                { operand = Value value; ty = I32 })
       | And | Or ->
           expect_type position Bool left.ty "boolean operand";
           let value = fresh_value function_builder in
           emit function_builder (Binop (value, Bool, binop_of_ast position operation,
             left.operand, right.operand));
           { operand = Value value; ty = Bool }
       | Eq | Neq | Lt | Gt | Lte | Gte ->
           (match left.ty with
            | I32 | Bool ->
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
            | _ -> fail_at position "DIR subset only compares int, bool and str"))
  | EUnOp (Neg, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      expect_type position I32 value.ty "negation operand";
      let result = fresh_value function_builder in
      emit function_builder (Binop (result, I32, Sub, Int 0, value.operand));
      { operand = Value result; ty = I32 }
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
       | List I32 ->
           let value = fresh_value function_builder in
           emit function_builder (ListLength (value, lowered_argument.operand));
           { operand = Value value; ty = I32 }
       | _ -> fail_at position "len expects a string or list<i32>")
  | ECall (EVar ("append", _), [collection; item], position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let lowered_item = lower_expr context function_builder environment item in
      expect_type position (List I32) lowered_collection.ty "append collection";
      expect_type position I32 lowered_item.ty "append value";
      emit function_builder (ListAppend (lowered_collection.operand, lowered_item.operand));
      { operand = Int 0; ty = Unit }
  | ECall (EVar ("text_length", _), [argument], position) ->
      let lowered_argument = lower_expr context function_builder environment argument in
      expect_type position Str lowered_argument.ty "text_length argument";
      let value = fresh_value function_builder in
      emit function_builder (StringLength (value, lowered_argument.operand));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("text_char_code", _), [text; index], position) ->
      let lowered_text = lower_expr context function_builder environment text in
      let lowered_index = lower_expr context function_builder environment index in
      expect_type position Str lowered_text.ty "text_char_code text";
      expect_type position I32 lowered_index.ty "text_char_code index";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_utf8_byte_at",
        [Str; I32], [lowered_text.operand; lowered_index.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar ("read_text_file", _), [path], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      expect_type position Str lowered_path.ty "read_text_file path";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_file_read",
        [Str], [lowered_path.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar ("write_text_codes", _), [path; codes], position) ->
      let lowered_path = lower_expr context function_builder environment path in
      let lowered_codes = lower_expr context function_builder environment codes in
      expect_type position Str lowered_path.ty "write_text_codes path";
      expect_type position (List I32) lowered_codes.ty "write_text_codes codes";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_file_write_bytes",
        [Str; List I32], [lowered_path.operand; lowered_codes.operand]));
      { operand = Value value; ty = I32 }
  | ECall (EVar (name, _), arguments, position) ->
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      let actual_name, signature =
        if name = "print" then
          match lowered_arguments with
          | [argument] ->
              let print_name = match argument.ty with
                | I32 -> "print_int"
                | Bool -> "print_bool"
                | Str -> "print_string"
                | _ -> fail_at position "print supports int, bool and str in DIR subset"
              in
              (print_name, { parameter_types = [argument.ty]; return_type = Unit })
          | _ -> fail_at position "print expects exactly one argument"
        else
          match Hashtbl.find_opt context.signatures name with
          | Some signature -> (name, signature)
          | None -> fail_at position ("unknown function " ^ name)
      in
      if List.length lowered_arguments <> List.length signature.parameter_types then
        fail_at position (Printf.sprintf "function %s expects %d arguments, got %d"
          actual_name (List.length signature.parameter_types) (List.length lowered_arguments));
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
  | EList (elements, position) ->
      let lowered_elements = List.map
        (lower_expr context function_builder environment) elements in
      List.iter (fun element ->
        expect_type position I32 element.ty "list element"
      ) lowered_elements;
      let value = fresh_value function_builder in
      emit function_builder (ListCreate (value, I32,
        List.map (fun element -> element.operand) lowered_elements));
      { operand = Value value; ty = List I32 }
  | ETuple (elements, position) ->
      let lowered_elements = List.map
        (lower_expr context function_builder environment) elements in
      List.iter (fun element ->
        expect_type position I32 element.ty "tuple element"
      ) lowered_elements;
      let value = fresh_value function_builder in
      emit function_builder (TupleCreate (value,
        List.map (fun _ -> I32) lowered_elements,
        List.map (fun element -> element.operand) lowered_elements));
      { operand = Value value; ty = Tuple (List.map (fun _ -> I32) lowered_elements) }
  | EIndex (collection, index, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let lowered_index = lower_expr context function_builder environment index in
      expect_type position (List I32) lowered_collection.ty "index collection";
      expect_type position I32 lowered_index.ty "index expression";
      let value = fresh_value function_builder in
      emit function_builder (ListGet (value, lowered_collection.operand, lowered_index.operand));
      { operand = Value value; ty = I32 }
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
             | _ -> fail_at position "slice collection must be a string or list<i32>");
            Value value
      in
      let value = fresh_value function_builder in
      (match lowered_collection.ty with
       | List I32 ->
           emit function_builder (ListSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = List I32 }
       | Str ->
           emit function_builder (StringSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = Str }
       | _ -> fail_at position "slice collection must be a string or list<i32>")
  | EListComp (element_expression, variable_name, iterable_expression,
               condition_expression, position) ->
      lower_list_comp context function_builder environment element_expression
        variable_name iterable_expression condition_expression position
  | ECall (_, _, position) -> fail_at position "DIR subset only supports named function calls"
  | EIf (_, _, _, position)
  | EMatch (_, _, position)
  | EDict (_, position)
  | EAttr (_, _, position)
  | ELambda (_, _, position)
  | EEnumVariant (_, _, _, position)
  | EStructLiteral (_, _, position)
  | EStructAccess (_, _, position)
  | ETernary (_, _, _, position)
  | ETry (_, position)
  | ETypeOf (_, position)
  | EFloat (_, position)
  | ERune (_, position)
  | EByte (_, position) ->
      fail_at position "expression is outside the initial DIR subset"

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
  emit function_builder (ListAppend (Value result, element.operand));
  terminate function_builder (Jump (next_label, [Value body_index]));
  switch_to function_builder next_label;
  let next_index = fresh_value function_builder in
  emit function_builder (Binop (next_index, I32, Add, Value next_input, Int 1));
  terminate function_builder (Jump (condition_label, [Value next_index]));
  switch_to function_builder exit_label;
  { operand = Value result; ty = List I32 }

and lower_statements context function_builder environment statements =
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
  let jump_to_join branch_environment =
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
  set_block_params function_builder join_label
    (List.map (fun (_, value, ty) -> (value, ty)) join_parameters);
  Hashtbl.clear environment;
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace environment name { operand = Value value; ty }
  ) join_parameters

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
    Hashtbl.replace condition_environment name { operand = Value value; ty }
  ) loop_bindings condition_params;
  let condition_value = lower_expr context function_builder condition_environment condition in
  expect_type position Bool condition_value.ty "while condition";
  let condition_arguments = List.map (fun (_, value, _) -> Value value) condition_params in
  terminate function_builder (Branch (condition_value.operand,
    (body_label, condition_arguments), (exit_label, condition_arguments)));
  switch_to function_builder body_label;
  set_block_params function_builder body_label
    (List.map (fun (_, value, ty) -> (value, ty)) body_params);
  let body_environment = Hashtbl.copy environment in
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace body_environment name { operand = Value value; ty }
  ) body_params;
  lower_statements context function_builder body_environment body;
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
    Hashtbl.replace environment name { operand = Value value; ty }
  ) exit_params

and lower_statement context function_builder environment statement =
  match statement with
  | SExpr (expression, _) -> ignore (lower_expr context function_builder environment expression)
  | SLet let_info ->
      let value = lower_expr context function_builder environment let_info.let_value in
      (match let_info.let_type with
       | Some type_expression ->
           expect_type let_info.let_pos (type_of_ast type_expression) value.ty "let binding"
       | None -> ());
      Hashtbl.replace environment let_info.let_name value
  | SLetPat (PTuple patterns, expression, position) ->
      let value = lower_expr context function_builder environment expression in
      (match value.ty with
       | Tuple element_types when List.length element_types = List.length patterns ->
           List.iteri (fun index pattern ->
             let element_type = List.nth element_types index in
             let element_value = fresh_value function_builder in
             emit function_builder (TupleGet (
               element_value, element_type, value.operand, index));
             (match pattern with
              | PVar name ->
                  Hashtbl.replace environment name {
                    operand = Value element_value;
                    ty = element_type;
                  }
              | PWildcard -> ()
              | _ -> fail_at position "DIR tuple patterns only support variables"
             )
           ) patterns
       | _ -> fail_at position "tuple pattern requires a tuple value")
  | SReturn (expression, position) ->
      (match expression with
       | None ->
           if not (Dir.equal_ty function_builder.return_type Unit) &&
              not (Dir.equal_ty function_builder.return_type I32) then
             fail_at position "return without a value requires unit or main return type"
           else
             terminate function_builder (default_return function_builder.return_type)
       | Some value_expression ->
           let value = lower_expr context function_builder environment value_expression in
           expect_type position function_builder.return_type value.ty "return value";
           terminate function_builder (Return (Some value.operand)))
  | SIf (condition, then_body, elifs, else_body, position) ->
      lower_if context function_builder environment condition then_body elifs else_body position
  | SWhile (condition, body, position) ->
      lower_while context function_builder environment condition body position
  | SAssign (name, expression, position) ->
      let previous_value = lookup_value position environment name in
      let value = lower_expr context function_builder environment expression in
      expect_type position previous_value.ty value.ty ("assignment to " ^ name);
      Hashtbl.replace environment name value
  | SIndexAssign (collection, index, expression, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let lowered_index = lower_expr context function_builder environment index in
      let lowered_value = lower_expr context function_builder environment expression in
      expect_type position (List I32) lowered_collection.ty "index assignment collection";
      expect_type position I32 lowered_index.ty "index assignment index";
      expect_type position I32 lowered_value.ty "index assignment value";
      emit function_builder (ListSet (
        lowered_collection.operand, lowered_index.operand, lowered_value.operand))
  | SImport _
  | SFromImport _ ->
      ()
  | SDef _ -> fail_at { line = 0; column = 0 } "nested function definitions are unsupported"
  | SLetPat (_, _, position)
  | SFor (_, _, _, position)
  | SFieldAssign (_, _, _, position)
  | SImpl (_, position) ->
      fail_at position "statement is outside the initial DIR subset"
  | SStruct struct_info ->
      fail_at struct_info.struct_pos "statement is outside the initial DIR subset"
  | SInterface interface_info ->
      fail_at interface_info.interface_pos "statement is outside the initial DIR subset"
  | SEnum enum_info ->
      fail_at enum_info.enum_pos "statement is outside the initial DIR subset"

let lower_function context def_info =
  let signature = Hashtbl.find context.signatures def_info.def_name in
  let function_builder = new_function def_info.def_name signature.return_type signature.parameter_types in
  let environment = Hashtbl.create 16 in
  let parameters = List.mapi (fun index (name, _, _) ->
    let value = index + 1 in
    let parameter_type = List.nth signature.parameter_types index in
    let parameter = { Dir.value; name; ty = parameter_type } in
    Hashtbl.add environment name { operand = Value value; ty = parameter_type };
    parameter
  ) def_info.def_params in
  lower_statements context function_builder environment def_info.def_body;
  finish_function function_builder parameters

let is_builtin_enum = function
  | SEnum enum_info -> enum_info.enum_name = "Option" || enum_info.enum_name = "Result"
  | _ -> false

let runtime_externs = [
  { name = "print_int"; parameters = [I32]; return_type = Unit };
  { name = "print_bool"; parameters = [Bool]; return_type = Unit };
  { name = "print_string"; parameters = [Str]; return_type = Unit };
  { name = "__c_file_read"; parameters = [Str]; return_type = Str };
  { name = "__c_file_write_bytes"; parameters = [Str; List I32]; return_type = I32 };
  { name = "__c_utf8_byte_at"; parameters = [Str; I32]; return_type = I32 };
]

let lower_program program =
  try
    let signatures = Hashtbl.create 32 in
    let function_definitions = List.filter_map (function
      | SDef def_info -> Some def_info
      | _ -> None
    ) program in
    List.iter (fun def_info ->
      add_signature signatures def_info.def_name (signature_of_def def_info)
    ) function_definitions;
    let context = { signatures } in
    let top_level = List.filter (function
      | SDef _ -> false
      | statement when is_builtin_enum statement -> false
      | SEnum _ -> true
      | _ -> true
    ) program in
    let has_top_level = top_level <> [] in
    let has_main = Hashtbl.mem signatures "main" in
    let functions = List.map (lower_function context) function_definitions in
    let functions = if has_top_level && not has_main then
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
      functions @ [lower_function context main_def]
    else
      functions
    in
    if not has_top_level && not has_main then
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
      let functions = functions @ [lower_function context main_def] in
      Ok {
        Dir.name = "dream";
        externs = runtime_externs;
        functions;
      }
    else
      Ok {
        Dir.name = "dream";
        externs = runtime_externs;
        functions;
      }
  with
  | Lower_error message -> Error message
