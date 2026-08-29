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

type method_binding = {
  function_name: string;
  signature: function_signature;
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
  mutable interface_boxes: (Dir.value * bool) list;
}

type context = {
  signatures: (string, function_signature) Hashtbl.t;
  method_signatures: (string, method_binding) Hashtbl.t;
  resolve_struct: string -> Dir.ty;
  resolve_enum: string -> Dir.ty;
  resolve_interface: string -> Dir.ty;
  resolve_named: string -> Dir.ty;
  interface_implementations: (string, string list) Hashtbl.t;
  extra_functions: Dir.function_def list ref;
  lambda_counter: int ref;
  global_inits: (string * Ast.expr) list ref;
  globals: (string * Dir.ty) list ref;
  break_labels: (string * (string * Dir.ty) list) list ref;
  continue_labels: (string * (string * Dir.ty) list * int option) list ref;
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
  | TUnion element_types ->
      Union (List.map (type_of_ast resolve_named) element_types)
  | TVar name ->
      (try resolve_named name with Lower_error _ -> I32)
  | TNone -> Unit
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
         | TSelf -> "self"
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
  | EUnOp (Pos, expression, _) -> expression_type_hint expression
  | EUnOp (Invert, _, _) -> Some I32
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
  | ECall (EVar ("argc", _), _, _)
  | ECall (EVar ("__c_process_arg_count", _), _, _) -> Some I32
  | ECall (EVar ("arg", _), _, _)
  | ECall (EVar ("__c_process_arg", _), _, _) -> Some Str
  | ECall (EVar ("read", _), _, _) -> Some Str
  | ECall (EVar ("write_codes", _), _, _) -> Some I32
  | ECall (EVar ("__c_file_read_bytes", _), _, _)
  | ECall (EVar ("__c_bytes_slice", _), _, _)
  | ECall (EVar ("__c_str_to_bytes", _), _, _) -> Some Bytes
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
  | SBreak _ :: rest -> first_return_type rest
  | _ :: rest -> first_return_type rest

let signature_of_def resolve_struct def_info =
  let parameter_types = List.map (fun (name, type_opt, _) ->
    match type_opt with
    | Some type_expression -> type_of_ast resolve_struct type_expression
    | None ->
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

let signature_of_method resolve_struct struct_name method_info =
  let _, _, parameters, return_type_expression, body, _ = method_info in
  let resolve_method_type type_expression =
    match type_expression with
    | Ast.TSelf -> resolve_struct struct_name
    | _ -> type_of_ast resolve_struct type_expression
  in
  let parameter_types = List.mapi (fun index (name, type_expression, _) ->
    match index, name, type_expression with
    | 0, "self", _ -> resolve_struct struct_name
    | _, _, Some type_expression -> resolve_method_type type_expression
    | _, _, None ->
        raise (Lower_error ("missing type annotation for method parameter " ^ name))
  ) parameters in
  let return_type = match return_type_expression with
    | Some type_expression -> resolve_method_type type_expression
    | None ->
        (match first_return_type body with
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
    interface_boxes = [];
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

let escaped_operands = function
  | Dir.Call (_, _, _, _, arguments) -> arguments
  | Dir.CallIndirect (_, _, _, _, arguments) -> arguments
  | Dir.InterfaceCall (_, _, _, _, _, _, _, arguments) -> arguments
  | Dir.MakeClosure (_, _, _, _, captures) -> captures
  | Dir.GlobalStore (_, value) -> [value]
  | _ -> []

let record_interface_box function_builder value =
  function_builder.interface_boxes <- (value, false) :: function_builder.interface_boxes

let mark_interface_box_escaped function_builder = function
  | Value value ->
      function_builder.interface_boxes <- List.map (fun (boxed, escaped) ->
        if boxed = value then (boxed, true) else (boxed, escaped)
      ) function_builder.interface_boxes
  | _ -> ()

let emit function_builder instruction =
  if is_terminated function_builder then
    raise (Lower_error ("instruction emitted after terminator in " ^ function_builder.name));
  let block = current_block function_builder in
  block.instructions <- block.instructions @ [instruction];
  List.iter (mark_interface_box_escaped function_builder) (escaped_operands instruction)

let release_interface_boxes function_builder =
  List.iter (fun (boxed, escaped) ->
    if not escaped then
      emit function_builder (InterfaceRelease (Value boxed))
  ) function_builder.interface_boxes

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
  | Str | Bytes | Dict _ | List _ | Tuple _ | Struct _ | Enum _ | Interface _ | Union _ ->
      raise (Lower_error "DIR subset cannot synthesize a default reference return")

let finish_function function_builder parameters =
  if not (is_terminated function_builder) then
    (match function_builder.return_type with
     | Struct _
     | Enum _
     | Interface _
     | Union _ -> terminate function_builder Unreachable
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

let variable_type context environment name =
  match Hashtbl.find_opt environment name with
  | Some value -> Some value.ty
  | None ->
      (match List.find_opt (fun (global_name, _) -> global_name = name) !(context.globals) with
       | Some (_, global_type) -> Some global_type
       | None -> None)

let load_variable context function_builder environment name =
  match Hashtbl.find_opt environment name with
  | Some value -> value
  | None ->
      (match List.find_opt (fun (global_name, _) -> global_name = name) !(context.globals) with
       | Some (_, global_type) ->
           let value = fresh_value function_builder in
           emit function_builder (GlobalLoad (value, global_type, name));
           { operand = Value value; ty = global_type }
       | None -> failwith ("unknown variable " ^ name))

let string_set_union_list sets =
  List.fold_left StringSet.union StringSet.empty sets

let rec pattern_bindings = function
  | PVar name -> StringSet.singleton name
  | PWildcard
  | PInt _
  | PFloat _ -> StringSet.empty
  | PTuple patterns ->
      string_set_union_list (List.map pattern_bindings patterns)
  | PStruct (_, field_patterns) ->
      string_set_union_list (List.map (fun (_, pattern) -> pattern_bindings pattern) field_patterns)
  | _ -> StringSet.empty

let rec free_expression bound = function
  | EVar (name, _) ->
      if StringSet.mem name bound then StringSet.empty else StringSet.singleton name
  | EInt _ | EFloat _ | EBool _ | EString _ | EByte _ | ERune _ -> StringSet.empty
  | EBinOp (left, _, right, _) ->
      StringSet.union (free_expression bound left) (free_expression bound right)
  | EUnOp (_, expr, _) -> free_expression bound expr
  | ECall (callee, args, _) ->
      List.fold_left StringSet.union (free_expression bound callee)
        (List.map (free_expression bound) args)
  | EList (elements, _) | ETuple (elements, _) ->
      string_set_union_list (List.map (free_expression bound) elements)
  | EDict (pairs, _) ->
      string_set_union_list (List.map (fun (k, v) ->
        StringSet.union (free_expression bound k) (free_expression bound v)) pairs)
  | EIndex (collection, index, _) ->
      StringSet.union (free_expression bound collection) (free_expression bound index)
  | ESlice (collection, start_opt, end_opt, _) ->
      string_set_union_list [
        free_expression bound collection;
        (match start_opt with Some e -> free_expression bound e | None -> StringSet.empty);
        (match end_opt with Some e -> free_expression bound e | None -> StringSet.empty)
      ]
  | EAttr (obj, _, _) -> free_expression bound obj
  | EIf (cond, then_expr, else_opt, _) ->
      string_set_union_list [
        free_expression bound cond;
        free_expression bound then_expr;
        (match else_opt with Some e -> free_expression bound e | None -> StringSet.empty)
      ]
  | ELambda (params, body, _) ->
      let param_names = List.fold_left (fun acc (name, _) -> StringSet.add name acc)
        bound params in
      free_expression param_names body
  | EMatch (scrutinee, cases, _) ->
      let scrutinee_free = free_expression bound scrutinee in
      let cases_free = string_set_union_list (List.map (fun (pattern, guard, body) ->
        let pattern_bound = StringSet.union bound (pattern_bindings pattern) in
        let guard_free = match guard with
          | Some g -> free_expression pattern_bound g
          | None -> StringSet.empty
        in
        let body_free = match body with
          | MExpr expr -> free_expression pattern_bound expr
          | MStmts stmts -> free_statements pattern_bound stmts
        in
        StringSet.union guard_free body_free
      ) cases) in
      StringSet.union scrutinee_free cases_free
  | EListComp (elem, var, iter, cond_opt, _) ->
      let iter_bound = StringSet.add var bound in
      let elem_free = free_expression iter_bound elem in
      let iter_free = free_expression bound iter in
      let cond_free = match cond_opt with
        | Some c -> free_expression iter_bound c
        | None -> StringSet.empty
      in
      string_set_union_list [elem_free; iter_free; cond_free]
  | EEnumVariant (_, _, args, _) ->
      string_set_union_list (List.map (free_expression bound) args)
  | EStructLiteral (_, fields, _) ->
      string_set_union_list (List.map (fun (_, e) -> free_expression bound e) fields)
  | EStructAccess (obj, _, _) -> free_expression bound obj
  | ETernary (cond, then_expr, else_expr, _) ->
      string_set_union_list [
        free_expression bound cond;
        free_expression bound then_expr;
        free_expression bound else_expr
      ]
  | ETry (expr, _) -> free_expression bound expr
  | ETypeOf (expr, _) -> free_expression bound expr

and free_statements bound statements =
  let _, free = List.fold_left (fun (current_bound, acc_free) stmt ->
    match stmt with
    | SExpr (expr, _) ->
        (current_bound, StringSet.union acc_free (free_expression current_bound expr))
    | SLet let_info ->
        let expr_free = free_expression current_bound let_info.let_value in
        (StringSet.add let_info.let_name current_bound, StringSet.union acc_free expr_free)
    | SConst const_info ->
        let expr_free = free_expression current_bound const_info.const_value in
        (StringSet.add const_info.const_name current_bound, StringSet.union acc_free expr_free)
    | SLetPat (pattern, expr, _) ->
        let expr_free = free_expression current_bound expr in
        let pattern_names = pattern_bindings pattern in
        (StringSet.union current_bound pattern_names, StringSet.union acc_free expr_free)
    | SAssign (_, expr, _) ->
        (current_bound, StringSet.union acc_free (free_expression current_bound expr))
    | SReturn (Some expr, _) ->
        (current_bound, StringSet.union acc_free (free_expression current_bound expr))
    | SReturn (None, _) -> (current_bound, acc_free)
    | SIf (cond, then_body, elifs, else_opt, _) ->
        let cond_free = free_expression current_bound cond in
        let then_free = free_statements current_bound then_body in
        let elifs_free = string_set_union_list (List.map (fun (c, b) ->
          StringSet.union (free_expression current_bound c) (free_statements current_bound b)
        ) elifs) in
        let else_free = match else_opt with
          | Some body -> free_statements current_bound body
          | None -> StringSet.empty
        in
        (current_bound, string_set_union_list [acc_free; cond_free; then_free; elifs_free; else_free])
    | SWhile (cond, body, _) ->
        let cond_free = free_expression current_bound cond in
        let body_free = free_statements current_bound body in
        (current_bound, string_set_union_list [acc_free; cond_free; body_free])
    | SFor (pattern, iter, body, _) ->
        let iter_free = free_expression current_bound iter in
        let pattern_names = pattern_bindings pattern in
        let body_bound = StringSet.union current_bound pattern_names in
        let body_free = free_statements body_bound body in
        (current_bound, StringSet.union acc_free (StringSet.union iter_free body_free))
    | SDef def_info ->
        let param_names = List.fold_left (fun acc (name, _, _) -> StringSet.add name acc)
          current_bound def_info.def_params in
        let body_free = free_statements param_names def_info.def_body in
        (StringSet.add def_info.def_name current_bound, StringSet.union acc_free body_free)
    | SBreak _ | SContinue _ | SImport _ | SFromImport _ | SImpl _ | SStruct _ | SInterface _ | SEnum _ ->
        (current_bound, acc_free)
    | SFieldAssign (obj, _, expr, _) ->
        let obj_free = free_expression current_bound obj in
        let expr_free = free_expression current_bound expr in
        (current_bound, string_set_union_list [acc_free; obj_free; expr_free])
    | SIndexAssign (collection, index, expr, _) ->
        let collection_free = free_expression current_bound collection in
        let index_free = free_expression current_bound index in
        let expr_free = free_expression current_bound expr in
        (current_bound, string_set_union_list [acc_free; collection_free; index_free; expr_free])
  ) (bound, StringSet.empty) statements in
  free

let lower_named_function_value context function_builder name =
  match Hashtbl.find_opt context.signatures name with
  | None -> raise (Lower_error ("unknown function: " ^ name))
  | Some signature ->
      let closure_type = Func (signature.parameter_types, signature.return_type) in
      let env_value = fresh_value function_builder in
      emit function_builder (MakeClosure (env_value, closure_type, name, signature.parameter_types, []));
      { operand = Value env_value; ty = closure_type }
