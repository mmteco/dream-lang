open Ast
open Dir

module StringSet = Set.Make(String)

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
  mutable return_type: Dir.ty;
  mutable next_value: int;
  mutable next_label: int;
  blocks: (string, block_builder) Hashtbl.t;
  mutable block_order: string list;
  mutable current_label: string;
}

type context = {
  signatures: (string, function_signature) Hashtbl.t;
  resolve_struct: string -> Dir.ty;
  resolve_enum: string -> Dir.ty;
  resolve_named: string -> Dir.ty;
  extra_functions: Dir.function_def list ref;
  lambda_counter: int ref;
}

exception Lower_error of string

let position_text position =
  Printf.sprintf "line %d, column %d" position.line position.column

let fail_at position message =
  raise (Lower_error (Printf.sprintf "%s (%s)" message (position_text position)))

let rec type_of_ast resolve_named = function
  | TInt -> I32
  | TBool -> Bool
  | TFloat -> F64
  | TStr -> Str
  | TByte | TRune -> I32
  | TBytes -> Bytes
  | TDict (key_type, value_type) ->
      Dict (type_of_ast resolve_named key_type, type_of_ast resolve_named value_type)
  | TList element_type -> List (type_of_ast resolve_named element_type)
  | TTuple element_types -> Tuple (List.map (type_of_ast resolve_named) element_types)
  | TStruct (name, _) -> resolve_named name
  | TEnum (name, _) -> resolve_named name
  | TOption element_type ->
      Enum ("Option", [("Some", [type_of_ast resolve_named element_type]); ("None", [])])
  | TResult (ok_type, error_type) ->
      Enum ("Result", [("Ok", [type_of_ast resolve_named ok_type]);
                       ("Err", [type_of_ast resolve_named error_type])])
  | TFunc (parameter_types, return_type) ->
      Func (List.map (type_of_ast resolve_named) parameter_types,
        type_of_ast resolve_named return_type)
  | TNone -> Unit
  | TVar name ->
      (try resolve_named name with Lower_error _ -> I32)
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
  | EFloat _ -> Some F64
  | EBool _ -> Some Bool
  | EString _ -> Some Str
  | ERune _
  | EByte _ -> Some I32
  | EList (elements, _) ->
      if List.for_all (fun element -> expression_type_hint element = Some I32) elements then
        Some (List I32)
      else
        None
  | EDict (pairs, _) ->
      (match pairs with
       | [] -> None
       | (first_key, first_value) :: rest ->
           (match expression_type_hint first_key, expression_type_hint first_value with
            | Some key_type, Some value_type
              when List.for_all (fun (key, value) ->
                expression_type_hint key = Some key_type &&
                expression_type_hint value = Some value_type) rest ->
                Some (Dict (key_type, value_type))
            | _ -> None))
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
       | (Add | Sub | Mul | Div | Mod), Some F64 -> Some F64
       | Add, Some (List I32) -> Some (List I32)
       | _ -> None)
  | EUnOp (Neg, expression, _) ->
      (match expression_type_hint expression with
       | Some I32 -> Some I32
       | Some F64 -> Some F64
       | _ -> None)
  | EUnOp (Not, _, _) -> Some Bool
  | EIndex (collection, index, _) ->
      (match expression_type_hint collection with
       | Some (Dict (_, value_type)) -> Some value_type
       | Some (List _)
       | Some Bytes
       | Some Str -> Some I32
       | Some (Tuple element_types) ->
           (match index with
            | EInt (index_value, _) when index_value >= 0 &&
                index_value < List.length element_types -> Some (List.nth element_types index_value)
            | _ -> None)
       | _ -> None)
  | ESlice (collection, _, _, _) ->
      (match expression_type_hint collection with
       | Some (List I32) -> Some (List I32)
       | Some Str -> Some Str
       | Some Bytes -> Some Bytes
       | _ -> None)
  | ECall (EVar ("len", _), _, _)
  | ECall (EVar ("ord", _), _, _) -> Some I32
  | ECall (EVar ("text_length", _), _, _) -> Some I32
  | ECall (EVar ("read_text_file", _), _, _) -> Some Str
  | ECall (EVar ("write_text_codes", _), _, _) -> Some I32
  | ECall (EVar ("__c_file_read_bytes", _), _, _)
  | ECall (EVar ("__c_bytes_slice", _), _, _)
  | ECall (EVar ("str_to_bytes", _), _, _)
  | ECall (EVar ("__c_str_to_bytes", _), _, _) -> Some Bytes
  | ECall (EVar ("bytes_to_str", _), _, _)
  | ECall (EVar ("__c_bytes_to_str", _), _, _) -> Some Str
  | ECall (EVar ("__c_bytes_length", _), _, _)
  | ECall (EVar ("__c_bytes_get", _), _, _)
  | ECall (EVar ("__c_file_write_bytes", _), _, _) -> Some I32
  | ECall _ -> Some I32
  | EVar _
  | EIf _
  | EMatch _
  | EAttr _
  | ELambda _
  | EListComp _
  | EEnumVariant _
  | EStructLiteral _
  | EStructAccess _
  | ETernary _
  | ETry _
  | ETypeOf _ -> None

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

let signature_of_def resolve_struct def_info =
  let parameter_types = List.map (fun (name, type_opt, default_opt) ->
    match type_opt, default_opt with
    | Some type_expression, None -> type_of_ast resolve_struct type_expression
    | Some _, Some _ ->
        raise (Lower_error ("DIR subset does not support default parameter " ^ name))
    | None, _ ->
        raise (Lower_error ("missing type annotation for parameter " ^ name))
  ) def_info.def_params in
  let return_type = match def_info.def_return_type with
    | Some type_expression -> type_of_ast resolve_struct type_expression
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
  | F64 -> Return (Some (Float 0.0))
  | Bool -> Return (Some (Bool false))
  | ClosureEnv _ -> raise (Lower_error "closure environments require an explicit return")
  | Func _ -> raise (Lower_error "DIR function values require an explicit return")
  | Str | Bytes | Dict _ | List _ | Tuple _ | Struct _ | Enum _ ->
      raise (Lower_error "DIR subset cannot synthesize a default reference return")

let finish_function function_builder parameters =
  if not (is_terminated function_builder) then
    (match function_builder.return_type with
     | Struct _
     | Enum _ -> terminate function_builder Unreachable
     | _ -> terminate function_builder (default_return function_builder.return_type));
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

let string_set_union_list sets =
  List.fold_left StringSet.union StringSet.empty sets

let rec pattern_bindings = function
  | PVar name -> StringSet.singleton name
  | PWildcard
  | PInt _
  | PFloat _
  | PString _
  | PByte _
  | PRune _
  | PBool _
  | PType _ -> StringSet.empty
  | PTuple patterns
  | PList patterns -> string_set_union_list (List.map pattern_bindings patterns)
  | PCons (head_pattern, tail_pattern) ->
      StringSet.union (pattern_bindings head_pattern) (pattern_bindings tail_pattern)
  | PEnumVariant (_, _, patterns) ->
      string_set_union_list (List.map pattern_bindings patterns)
  | PStruct (_, fields) ->
      string_set_union_list (List.map (fun (_, pattern) -> pattern_bindings pattern) fields)

let rec free_expression bound = function
  | EInt _ | EFloat _ | EString _ | ERune _ | EByte _ | EBool _ -> StringSet.empty
  | EVar (name, _) ->
      if StringSet.mem name bound then StringSet.empty else StringSet.singleton name
  | EBinOp (left, _, right, _)
  | EIndex (left, right, _) ->
      StringSet.union (free_expression bound left) (free_expression bound right)
  | EUnOp (_, expression, _)
  | ETypeOf (expression, _)
  | ETry (expression, _) -> free_expression bound expression
  | ECall (callee, arguments, _) ->
      string_set_union_list
        (free_expression bound callee :: List.map (free_expression bound) arguments)
  | EList (elements, _)
  | ETuple (elements, _) ->
      string_set_union_list (List.map (free_expression bound) elements)
  | EDict (pairs, _) ->
      string_set_union_list (List.map (fun (key, value) ->
        StringSet.union (free_expression bound key) (free_expression bound value)
      ) pairs)
  | ESlice (collection, start, end_, _) ->
      string_set_union_list (
        free_expression bound collection ::
        List.filter_map (Option.map (free_expression bound)) [start; end_])
  | EAttr (object_expression, _, _)
  | EStructAccess (object_expression, _, _) ->
      free_expression bound object_expression
  | ELambda (parameters, body, _) ->
      let nested_bound = List.fold_left (fun names (name, _) ->
        StringSet.add name names
      ) bound parameters in
      free_expression nested_bound body
  | EIf (condition, then_expression, else_expression, _) ->
      let else_names = match else_expression with
        | Some expression -> free_expression bound expression
        | None -> StringSet.empty
      in
      string_set_union_list [
        free_expression bound condition;
        free_expression bound then_expression;
        else_names;
      ]
  | ETernary (condition, then_expression, else_expression, _) ->
      string_set_union_list [
        free_expression bound condition;
        free_expression bound then_expression;
        free_expression bound else_expression;
      ]
  | EMatch (scrutinee, cases, _) ->
      StringSet.union (free_expression bound scrutinee)
        (string_set_union_list (List.map (fun (pattern, guard, body) ->
          let case_bound = StringSet.union bound (pattern_bindings pattern) in
          let guard_names = match guard with
            | Some expression -> free_expression case_bound expression
            | None -> StringSet.empty
          in
          let body_names = match body with
            | MExpr expression -> free_expression case_bound expression
            | MStmts statements -> free_statements case_bound statements
          in
          StringSet.union guard_names body_names
        ) cases))
  | EListComp (element, variable, iterable, condition, _) ->
      let iterable_names = free_expression bound iterable in
      let body_bound = StringSet.add variable bound in
      let condition_names = match condition with
        | Some expression -> free_expression body_bound expression
        | None -> StringSet.empty
      in
      StringSet.union iterable_names
        (StringSet.union (free_expression body_bound element) condition_names)
  | EEnumVariant (_, _, arguments, _) ->
      string_set_union_list (List.map (free_expression bound) arguments)
  | EStructLiteral (_, fields, _) ->
      string_set_union_list (List.map (fun (_, expression) ->
        free_expression bound expression
      ) fields)

and free_statements bound statements =
  match statements with
  | [] -> StringSet.empty
  | SExpr (expression, _) :: rest ->
      StringSet.union (free_expression bound expression) (free_statements bound rest)
  | SLet let_info :: rest ->
      StringSet.union (free_expression bound let_info.let_value)
        (free_statements (StringSet.add let_info.let_name bound) rest)
  | SConst const_info :: rest ->
      StringSet.union (free_expression bound const_info.const_value)
        (free_statements (StringSet.add const_info.const_name bound) rest)
  | SLetPat (pattern, expression, _) :: rest ->
      StringSet.union (free_expression bound expression)
        (free_statements (StringSet.union bound (pattern_bindings pattern)) rest)
  | SReturn (expression, _) :: rest ->
      StringSet.union
        (match expression with
         | Some expression -> free_expression bound expression
         | None -> StringSet.empty)
        (free_statements bound rest)
  | SIf (condition, then_body, elifs, else_body, _) :: rest ->
      let branch_names = string_set_union_list [
        free_expression bound condition;
        free_statements bound then_body;
        string_set_union_list (List.map (fun (elif_condition, elif_body) ->
          StringSet.union (free_expression bound elif_condition)
            (free_statements bound elif_body)
        ) elifs);
        (match else_body with
         | Some body -> free_statements bound body
         | None -> StringSet.empty);
      ] in
      StringSet.union branch_names (free_statements bound rest)
  | SWhile (condition, body, _) :: rest ->
      StringSet.union (free_expression bound condition)
        (StringSet.union (free_statements bound body) (free_statements bound rest))
  | SFor (pattern, iterable, body, _) :: rest ->
      StringSet.union (free_expression bound iterable)
        (StringSet.union
           (free_statements (StringSet.union bound (pattern_bindings pattern)) body)
           (free_statements bound rest))
  | SAssign (name, expression, _) :: rest ->
      let assignment_names = if StringSet.mem name bound then StringSet.empty
        else StringSet.singleton name in
      StringSet.union assignment_names
        (StringSet.union (free_expression bound expression) (free_statements bound rest))
  | SIndexAssign (collection, index, expression, _) :: rest ->
      StringSet.union (free_expression bound collection)
        (StringSet.union (free_expression bound index)
           (StringSet.union (free_expression bound expression)
           (free_statements bound rest)))
  | SFieldAssign (collection, _, expression, _) :: rest ->
      StringSet.union (free_expression bound collection)
        (StringSet.union (free_expression bound expression)
           (free_statements bound rest))
  | SDef _ :: rest
  | SStruct _ :: rest
  | SInterface _ :: rest
  | SImport _ :: rest
  | SFromImport _ :: rest
  | SEnum _ :: rest
  | SImpl _ :: rest -> free_statements bound rest

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
  | EFloat (value, _) -> { operand = Float value; ty = F64 }
  | EBool (value, _) -> { operand = Bool value; ty = Bool }
  | EString (value, _) -> { operand = String value; ty = Str }
  | ERune (value, _) -> { operand = Int value; ty = I32 }
  | EByte (value, _) -> { operand = Int value; ty = I32 }
  | EVar (name, position) ->
      (match Hashtbl.find_opt environment name with
       | Some value -> value
       | None ->
           (match Hashtbl.find_opt context.signatures name with
            | Some signature -> lower_named_function_value context function_builder
                name signature
            | None -> fail_at position ("unknown variable " ^ name)))
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
            | I32 | F64 ->
                let value = fresh_value function_builder in
                emit function_builder (Binop (value, left.ty, binop_of_ast position operation,
                  left.operand, right.operand));
                { operand = Value value; ty = left.ty }
            | _ -> fail_at position "arithmetic operand must be numeric")
       | And | Or ->
           expect_type position Bool left.ty "boolean operand";
           let value = fresh_value function_builder in
           emit function_builder (Binop (value, Bool, binop_of_ast position operation,
             left.operand, right.operand));
           { operand = Value value; ty = Bool }
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
      if not (Dir.equal_ty value.ty I32) && not (Dir.equal_ty value.ty F64) then
        fail_at position "negation operand must be int or float";
      let result = fresh_value function_builder in
      let zero = if Dir.equal_ty value.ty F64 then Float 0.0 else Int 0 in
      emit function_builder (Binop (result, value.ty, Sub, zero, value.operand));
      { operand = Value result; ty = value.ty }
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
       | _ -> fail_at position "len expects a string, bytes, dict or list<i32>")
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
  | ECall (EVar ("ord", _), [rune], position) ->
      let lowered_rune = lower_expr context function_builder environment rune in
      expect_type position I32 lowered_rune.ty "ord argument";
      lowered_rune
  | ECall (EVar ("__c_rune_to_int", _), [rune], position) ->
      let lowered_rune = lower_expr context function_builder environment rune in
      expect_type position I32 lowered_rune.ty "__c_rune_to_int argument";
      lowered_rune
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
      let bytes = fresh_value function_builder in
      emit function_builder (Call (Some bytes, Bytes, "__c_bytes_from_array",
        [List I32], [lowered_codes.operand]));
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, I32, "__c_file_write_bytes",
        [Str; Bytes], [lowered_path.operand; Value bytes]));
      { operand = Value value; ty = I32 }
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
  | ECall (EVar (("str_to_bytes" | "__c_str_to_bytes"), _), [text], position) ->
      let lowered_text = lower_expr context function_builder environment text in
      expect_type position Str lowered_text.ty "__c_str_to_bytes text";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Bytes, "__c_str_to_bytes",
        [Str], [lowered_text.operand]));
      { operand = Value value; ty = Bytes }
  | ECall (EVar (("bytes_to_str" | "__c_bytes_to_str"), _), [bytes], position) ->
      let lowered_bytes = lower_expr context function_builder environment bytes in
      expect_type position Bytes lowered_bytes.ty "__c_bytes_to_str bytes";
      let value = fresh_value function_builder in
      emit function_builder (Call (Some value, Str, "__c_bytes_to_str",
        [Bytes], [lowered_bytes.operand]));
      { operand = Value value; ty = Str }
  | ECall (EVar (name, _), arguments, position)
    when (match Hashtbl.find_opt environment name with
          | Some { ty = Func _; _ } -> true
          | _ -> false) ->
      let callee = lookup_value position environment name in
      lower_call_indirect context function_builder environment callee arguments position
  | ECall (EVar (name, _), arguments, position) ->
      let lowered_arguments = List.map
        (lower_expr context function_builder environment) arguments in
      let actual_name, signature =
        if name = "print" then
          match lowered_arguments with
          | [argument] ->
              let print_name = match argument.ty with
                | I32 -> "dream_print_int"
                | F64 -> "dream_print_float"
                | Bool -> "dream_print_bool"
                | Str -> "dream_print_string"
                | _ -> fail_at position "print supports int, float, bool and str in DIR subset"
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
      (match lowered_collection.ty with
       | List I32 ->
           let lowered_index = lower_expr context function_builder environment index in
           expect_type position I32 lowered_index.ty "index expression";
           let value = fresh_value function_builder in
           emit function_builder (ListGet (value, lowered_collection.operand, lowered_index.operand));
           { operand = Value value; ty = I32 }
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
       | List I32 ->
           emit function_builder (ListSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = List I32 }
       | Str ->
           emit function_builder (StringSlice (value, lowered_collection.operand,
             start_value, end_value));
           { operand = Value value; ty = Str }
       | Bytes ->
           emit function_builder (Call (Some value, Bytes, "__c_bytes_slice",
             [Bytes; I32; I32], [lowered_collection.operand; start_value; end_value]));
           { operand = Value value; ty = Bytes }
       | _ -> fail_at position "slice collection must be a string, bytes or list<i32>")
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
  | ECall (callee, arguments, position) ->
      let lowered_callee = lower_expr context function_builder environment callee in
      lower_call_indirect context function_builder environment lowered_callee arguments position
  | ELambda (parameters, body, position) ->
      lower_lambda context function_builder environment parameters body position
  | EEnumVariant (variable_name, field_name, [], position) ->
      (match Hashtbl.find_opt environment variable_name with
       | Some object_value ->
           (match object_value.ty with
            | Struct (_, fields) ->
                let field_index, field_type = match List.find_index
                    (fun (name, _) -> name = field_name) fields with
                  | None -> fail_at position ("unknown struct field " ^ field_name)
                  | Some index -> index, snd (List.nth fields index)
                in
                let value = fresh_value function_builder in
                emit function_builder (StructGet (value, field_type,
                  object_value.operand, field_index));
                { operand = Value value; ty = field_type }
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
           (match payload_type with
            | I32 | F64 | Str | Bool -> ()
            | _ -> fail_at position "DIR enum payload supports only int, float, bool and str");
           let enum_type = match resolved_enum_type with
             | Enum (name, variants) ->
                 Enum (name, List.mapi (fun index (name, types) ->
                   if index = tag then name, [payload_type] else name, types) variants)
             | _ -> assert false
           in
           let value = fresh_value function_builder in
           emit function_builder (EnumCreate (value, enum_type, tag,
             payload_type, payload.operand));
           { operand = Value value; ty = enum_type }
       | payload_types, payloads
         when payload_types <> [] && List.length payload_types = List.length payloads ->
           let lowered_payload_types = List.map (fun payload -> payload.ty) lowered_arguments in
           List.iter2 (fun expected actual ->
             expect_type position expected actual "enum payload"
           ) payload_types lowered_payload_types;
           List.iter (fun payload_type ->
             match payload_type with
             | I32 | F64 | Str | Bool -> ()
             | _ -> fail_at position "DIR enum payload supports only primitive values"
           ) payload_types;
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
  | ETypeOf (_, position) -> fail_at position "DIR does not support type-of yet"

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
  List.iter2 (fun expected actual ->
    expect_type position expected actual.ty "function argument"
  ) parameter_types lowered_arguments;
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
  let lowered_scrutinee = lower_expr context function_builder environment scrutinee in
  (match lowered_scrutinee.ty with
   | I32 | F64 | Bool | Str | List I32 | Struct _ | Enum _ -> ()
   | _ -> fail_at position "DIR match scrutinee must be a scalar, struct or enum");
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
          | Enum (_, variants) -> variants
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
      | PVar _ | PWildcard -> ()
      | _ -> fail_at position "DIR struct match fields only support variables"
    ) (struct_pattern_info pattern)
  in
  let bind_struct_pattern case_environment pattern =
    List.iter (fun (_, field_index, field_type, field_pattern) ->
      match field_pattern with
      | PWildcard -> ()
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
                if List.length payload_types = 1 then
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
    | Enum (_, variants) -> List.exists (fun (_, payload_types) -> payload_types <> []) variants
    | _ -> false
  in
  let lower_test (index, test_label, guard_label, body_label, (pattern, guard, _)) =
    switch_to function_builder test_label;
    let case_environment = Hashtbl.copy environment in
    (match pattern with
     | PVar name -> Hashtbl.replace case_environment name lowered_scrutinee
     | PWildcard | PInt _ | PFloat _ | PString _ | PByte _ | PRune _ | PBool _
     | PList _ | PCons _ | PStruct _ | PEnumVariant _ -> ()
     | _ -> fail_at position "DIR match only supports scalar, list, struct and enum patterns");
    let pattern_target = Option.value guard_label ~default:body_label in
    (match pattern with
     | PInt value ->
         if not (Dir.equal_ty lowered_scrutinee.ty I32) then
           fail_at position "integer pattern requires an integer match scrutinee";
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           lowered_scrutinee.operand, Int value));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
     | PFloat value ->
         if not (Dir.equal_ty lowered_scrutinee.ty F64) then
           fail_at position "float pattern requires a float match scrutinee";
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           lowered_scrutinee.operand, Float value));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
     | PBool value ->
         if not (Dir.equal_ty lowered_scrutinee.ty Bool) then
           fail_at position "boolean pattern requires a boolean match scrutinee";
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq,
           lowered_scrutinee.operand, Bool value));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
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
     | PString value ->
         if not (Dir.equal_ty lowered_scrutinee.ty Str) then
           fail_at position "string pattern requires a string match scrutinee";
         let comparison = fresh_value function_builder in
         emit function_builder (StringCompare (comparison,
           lowered_scrutinee.operand, String value));
         let matches = fresh_value function_builder in
         emit function_builder (Compare (matches, Eq, Value comparison, Int 0));
         terminate function_builder (Branch (Value matches,
           (pattern_target, []), (next_label index, [])))
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
         terminate function_builder (Jump (pattern_target, []))
     | PList _ | PCons _ ->
         if not (Dir.equal_ty lowered_scrutinee.ty (List I32)) then
           fail_at position "list pattern requires a list<i32> match scrutinee";
         lower_list_test pattern pattern_target (next_label index)
     | PWildcard | PVar _ ->
         terminate function_builder (Jump (pattern_target, []))
     | _ -> fail_at position "DIR match only supports scalar, list, struct and enum patterns");
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
    (match pattern with
     | PVar name -> Hashtbl.replace case_environment name lowered_scrutinee
     | PWildcard | PInt _ | PFloat _ | PString _ | PByte _ | PRune _ | PBool _ -> ()
     | PEnumVariant _ -> bind_enum_payload case_environment pattern
     | PStruct _ -> bind_struct_pattern case_environment pattern
     | PList _ | PCons _ -> bind_list_pattern case_environment pattern
     | _ -> fail_at position "DIR match only supports scalar, list, struct and enum patterns");
    let lowered_body = match body with
      | MExpr expression -> lower_expr context function_builder case_environment expression
      | MStmts statements ->
          (match List.rev statements with
           | SExpr (expression, _) :: reversed_prefix ->
               lower_statements context function_builder case_environment
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

and lower_for context function_builder environment pattern iterable body position =
  let lowered_iterable = lower_expr context function_builder environment iterable in
  expect_type position (List I32) lowered_iterable.ty "for loop iterable";
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
  List.iter (create_block function_builder) [condition_label; body_label; exit_label];
  let initial_arguments = List.map (fun (_, value) -> value.operand) loop_bindings in
  terminate function_builder (Jump (condition_label, initial_arguments @ [Int 0]));
  switch_to function_builder condition_label;
  set_block_params function_builder condition_label
    (List.map (fun (_, value, ty) -> (value, ty)) condition_bindings @
     [(condition_index, I32)]);
  let length = fresh_value function_builder in
  emit function_builder (ListLength (length, lowered_iterable.operand));
  let has_more = fresh_value function_builder in
  emit function_builder (Compare (has_more, Lt, Value condition_index, Value length));
  let condition_values = List.map (fun (_, value, _) -> Value value) condition_bindings in
  terminate function_builder (Branch (Value has_more,
    (body_label, condition_values @ [Value condition_index]),
    (exit_label, condition_values)));
  switch_to function_builder body_label;
  set_block_params function_builder body_label
    (List.map (fun (_, value, ty) -> (value, ty)) body_bindings @
     [(body_index, I32)]);
  let body_environment = Hashtbl.copy environment in
  List.iter2 (fun (name, _) (_, value, ty) ->
    Hashtbl.replace body_environment name { operand = Value value; ty }
  ) loop_bindings body_bindings;
  let item = fresh_value function_builder in
  emit function_builder (ListGet (item, lowered_iterable.operand, Value body_index));
  (match pattern with
   | PVar name ->
       Hashtbl.replace body_environment name { operand = Value item; ty = I32 }
   | PWildcard -> ()
   | _ -> fail_at position "DIR for loops only support variable and wildcard patterns");
  lower_statements context function_builder body_environment body;
  if not (is_terminated function_builder) then begin
    let next_index = fresh_value function_builder in
    emit function_builder (Binop (next_index, I32, Add, Value body_index, Int 1));
    let next_values = List.map (fun (name, _, _) ->
      (Hashtbl.find body_environment name).operand
    ) body_bindings in
    terminate function_builder (Jump (condition_label, next_values @ [Value next_index]))
  end;
  switch_to function_builder exit_label;
  set_block_params function_builder exit_label
    (List.map (fun (_, value, ty) -> (value, ty)) exit_bindings);
  Hashtbl.clear environment;
  List.iter (fun (name, value, ty) ->
    Hashtbl.replace environment name { operand = Value value; ty }
  ) exit_bindings

and lower_statement context function_builder environment statement =
  match statement with
  | SExpr (expression, _) -> ignore (lower_expr context function_builder environment expression)
  | SConst const_info ->
      let value = lower_expr context function_builder environment const_info.const_value in
      Hashtbl.replace environment const_info.const_name value
  | SLet let_info ->
      let value = lower_expr context function_builder environment let_info.let_value in
      (match let_info.let_type with
       | Some type_expression ->
           expect_type let_info.let_pos
             (type_of_ast context.resolve_named type_expression) value.ty "let binding"
       | None -> ());
      Hashtbl.replace environment let_info.let_name value
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
  | SFor (pattern, iterable, body, position) ->
      lower_for context function_builder environment pattern iterable body position
  | SAssign (name, expression, position) ->
      let previous_value = lookup_value position environment name in
      let value = lower_expr context function_builder environment expression in
      expect_type position previous_value.ty value.ty ("assignment to " ^ name);
      Hashtbl.replace environment name value
  | SIndexAssign (collection, index, expression, position) ->
      let lowered_collection = lower_expr context function_builder environment collection in
      let lowered_index = lower_expr context function_builder environment index in
      let lowered_value = lower_expr context function_builder environment expression in
      (match lowered_collection.ty with
       | List I32 ->
           expect_type position I32 lowered_index.ty "index assignment index";
           expect_type position I32 lowered_value.ty "index assignment value";
           emit function_builder (ListSet (
             lowered_collection.operand, lowered_index.operand, lowered_value.operand))
       | Dict (key_type, value_type) ->
           expect_type position key_type lowered_index.ty "dict assignment key";
           expect_type position value_type lowered_value.ty "dict assignment value";
           let setter_name = match key_type, value_type with
             | I32, I32 -> "dict_set_int_int"
             | I32, Str -> "dict_set_int_str"
             | Str, I32 -> "dict_set_str_int"
             | Str, Str -> "dict_set_str_str"
             | _ -> fail_at position "DIR dict supports only int and str keys/values"
           in
           emit function_builder (Call (None, Unit, setter_name,
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
                   emit function_builder (TupleGet (element_value, element_type,
                     value.operand, index));
                   bind_pattern pattern { operand = Value element_value; ty = element_type }
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
                   emit function_builder (StructGet (field_value, field_type,
                     value.operand, field_index));
                   bind_pattern field_pattern { operand = Value field_value; ty = field_type }
                 ) field_patterns
             | Struct _ -> fail_at position "struct pattern name does not match value"
             | _ -> fail_at position "struct pattern requires a struct value")
        | _ -> fail_at position "DIR supports only variable, tuple and struct let patterns"
      in
      bind_pattern pattern lowered_value
  | SFieldAssign (object_expression, field_name, expression, position) ->
      let object_value = lower_expr context function_builder environment object_expression in
      let fields = match object_value.ty with
        | Struct (_, fields) -> fields
        | _ -> fail_at position "field assignment requires a struct value"
      in
      let field_index, field_type = match List.find_index
          (fun (name, _) -> name = field_name) fields with
        | None -> fail_at position ("unknown struct field " ^ field_name)
        | Some index -> index, snd (List.nth fields index)
      in
      let lowered_value = lower_expr context function_builder environment expression in
      expect_type position field_type lowered_value.ty ("struct field " ^ field_name);
      let field_values = List.mapi (fun index (_, current_type) ->
        if index = field_index then lowered_value.operand
        else
          let current = fresh_value function_builder in
          emit function_builder (StructGet (current, current_type,
            object_value.operand, index));
          Value current
      ) fields in
      let struct_name = match object_value.ty with
        | Struct (name, _) -> name
        | _ -> assert false
      in
      let updated_value = fresh_value function_builder in
      emit function_builder (StructCreate (updated_value, struct_name, fields, field_values));
      (match object_expression with
       | EVar (name, _) -> Hashtbl.replace environment name
           { operand = Value updated_value; ty = object_value.ty }
       | _ -> fail_at position "DIR field assignment requires a local struct variable")
  | SImpl (_, position) ->
      fail_at position "DIR does not support impl statements yet"
  | SStruct struct_info ->
      fail_at struct_info.struct_pos "statement is outside the initial DIR subset"
  | SInterface interface_info ->
      fail_at interface_info.interface_pos "statement is outside the initial DIR subset"
  | SEnum enum_info ->
      fail_at enum_info.enum_pos "statement is outside the initial DIR subset"

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
  lower_statements context function_builder environment def_info.def_body;
  finish_function function_builder parameters

let runtime_externs = [
  { name = "dream_print_int"; parameters = [I32]; return_type = Unit };
  { name = "dream_print_float"; parameters = [F64]; return_type = Unit };
  { name = "dream_print_bool"; parameters = [Bool]; return_type = Unit };
  { name = "dream_print_string"; parameters = [Str]; return_type = Unit };
  { name = "string_concat"; parameters = [Str; Str]; return_type = Str };
  { name = "__c_file_read"; parameters = [Str]; return_type = Str };
  { name = "__c_file_write"; parameters = [Str; Str]; return_type = I32 };
  { name = "__c_file_exists"; parameters = [Str]; return_type = Bool };
  { name = "__c_file_delete"; parameters = [Str]; return_type = Bool };
  { name = "__c_file_read_bytes"; parameters = [Str]; return_type = Bytes };
  { name = "__c_file_write_bytes"; parameters = [Str; Bytes]; return_type = I32 };
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
      | TOption element_type ->
          Enum ("Option", [("Some", [resolve_type resolving element_type]); ("None", [])])
      | TResult (ok_type, error_type) ->
          Enum ("Result", [("Ok", [resolve_type resolving ok_type]);
                            ("Err", [resolve_type resolving error_type])])
      | TVar name ->
          (try resolve_struct_type resolving name with Lower_error _ ->
             try resolve_enum_type resolving name with Lower_error _ -> I32)
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
        raise (Lower_error ("recursive enum is not supported in DIR: " ^ name));
      match Hashtbl.find_opt enum_definitions name with
      | None -> raise (Lower_error ("unknown enum " ^ name))
      | Some enum_info ->
          let variants = List.map (function
            | VSimple (variant_name, _) -> variant_name, []
            | VTuple (variant_name, types, _) ->
                variant_name, List.map (resolve_type (name :: resolving)) types
          ) enum_info.enum_variants in
          Enum (name, variants)
    in
    let resolve_struct name = resolve_struct_type [] name in
    let resolve_enum name = resolve_enum_type [] name in
    let resolve_named name =
      try resolve_struct name with Lower_error _ -> resolve_enum name
    in
    let signatures = Hashtbl.create 32 in
    let function_definitions = List.filter_map (function
      | SDef def_info -> Some def_info
      | _ -> None
    ) program in
    List.iter (fun def_info ->
      add_signature signatures def_info.def_name (signature_of_def resolve_named def_info)
    ) function_definitions;
    List.iter (fun (declaration : Dir.extern) ->
      add_signature signatures declaration.name {
        parameter_types = declaration.parameters;
        return_type = declaration.return_type;
      }
    ) runtime_externs;
    let context = {
      signatures;
      resolve_struct;
      resolve_enum;
      resolve_named;
      extra_functions = ref [];
      lambda_counter = ref 0;
    } in
    let top_level = List.filter (function
      | SDef _
      | SStruct _
      | SInterface _
      | SEnum _
      | SImpl _ -> false
      | _ -> true
    ) program in
    let has_top_level = top_level <> [] in
    let has_main = Hashtbl.mem signatures "main" in
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
    let functions = List.map (lower_function context constant_bindings) function_definitions in
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
      functions @ [lower_function context constant_bindings main_def]
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
      let functions = functions @ [lower_function context constant_bindings main_def] in
      let functions = functions @ List.rev !(context.extra_functions) in
      Ok {
        Dir.name = "dream";
        externs = runtime_externs;
        functions;
      }
    else
      let functions = functions @ List.rev !(context.extra_functions) in
      Ok {
        Dir.name = "dream";
        externs = runtime_externs;
        functions;
      }
  with
  | Lower_error message -> Error message
