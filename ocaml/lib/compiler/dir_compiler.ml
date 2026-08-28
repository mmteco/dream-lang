type artifact = {
  llvm_ir: string;
  dir_text: string option;
}

module StringSet = Set.Make(String)

let rec called_names_expr expr =
  let union_all expressions =
    List.fold_left (fun names expression ->
      StringSet.union names (called_names_expr expression)
    ) StringSet.empty expressions
  in
  match expr with
  | Ast.ECall (Ast.EVar (name, _), arguments, _) ->
      StringSet.add name (union_all arguments)
  | Ast.ECall (function_expr, arguments, _) ->
      StringSet.union (called_names_expr function_expr) (union_all arguments)
  | Ast.EBinOp (left, _, right, _) ->
      StringSet.union (called_names_expr left) (called_names_expr right)
  | Ast.EUnOp (_, operand, _) -> called_names_expr operand
  | Ast.EList (elements, _) -> union_all elements
  | Ast.ETuple (elements, _) -> union_all elements
  | Ast.EDict (pairs, _) ->
      List.fold_left (fun names (key, value) ->
        StringSet.union names
          (StringSet.union (called_names_expr key) (called_names_expr value))
      ) StringSet.empty pairs
  | Ast.EIndex (collection, index, _) ->
      StringSet.union (called_names_expr collection) (called_names_expr index)
  | Ast.ESlice (collection, start, end_, _) ->
      let names = called_names_expr collection in
      let names = match start with Some expression -> StringSet.union names (called_names_expr expression) | None -> names in
      (match end_ with Some expression -> StringSet.union names (called_names_expr expression) | None -> names)
  | Ast.EAttr (object_expr, _, _) -> called_names_expr object_expr
  | Ast.EIf (condition, then_expr, else_expr, _) ->
      let names = StringSet.union (called_names_expr condition) (called_names_expr then_expr) in
      (match else_expr with Some expression -> StringSet.union names (called_names_expr expression) | None -> names)
  | Ast.EMatch (scrutinee, cases, _) ->
      List.fold_left (fun names (_, guard, body) ->
        let names = StringSet.union names (called_names_expr scrutinee) in
        let names = match guard with Some expression -> StringSet.union names (called_names_expr expression) | None -> names in
        let body_names = match body with
          | Ast.MExpr expression -> called_names_expr expression
          | Ast.MStmts statements -> called_names_statements statements
        in
        StringSet.union names body_names
      ) StringSet.empty cases
  | Ast.ELambda (_, body, _) -> called_names_expr body
  | Ast.EListComp (element, _, iterable, condition, _) ->
      let names = StringSet.union (called_names_expr element) (called_names_expr iterable) in
      (match condition with Some expression -> StringSet.union names (called_names_expr expression) | None -> names)
  | Ast.EEnumVariant (_, _, arguments, _) -> union_all arguments
  | Ast.EStructLiteral (_, fields, _) ->
      union_all (List.map snd fields)
  | Ast.EStructAccess (object_expr, _, _) -> called_names_expr object_expr
  | Ast.ETernary (condition, true_expr, false_expr, _) ->
      union_all [condition; true_expr; false_expr]
  | Ast.ETry (operand, _) -> called_names_expr operand
  | Ast.ETypeOf (operand, _) -> called_names_expr operand
  | Ast.EInt _ | Ast.EFloat _ | Ast.EString _ | Ast.ERune _ | Ast.EByte _
  | Ast.EBool _ | Ast.EVar _ -> StringSet.empty

and called_names_statement statement =
  match statement with
  | Ast.SExpr (expression, _) | Ast.SReturn (Some expression, _) -> called_names_expr expression
  | Ast.SReturn (None, _) -> StringSet.empty
  | Ast.SLet let_info -> called_names_expr let_info.Ast.let_value
  | Ast.SConst const_info -> called_names_expr const_info.Ast.const_value
  | Ast.SLetPat (_, expression, _) -> called_names_expr expression
  | Ast.SDef definition -> called_names_definition definition
  | Ast.SIf (condition, then_body, elif_branches, else_body, _) ->
      let names = StringSet.union (called_names_expr condition) (called_names_statements then_body) in
      let names = List.fold_left (fun names (branch_condition, branch_body) ->
        StringSet.union names (StringSet.union (called_names_expr branch_condition) (called_names_statements branch_body))
      ) names elif_branches in
      (match else_body with Some body -> StringSet.union names (called_names_statements body) | None -> names)
  | Ast.SWhile (condition, body, _) ->
      StringSet.union (called_names_expr condition) (called_names_statements body)
  | Ast.SBreak _ -> StringSet.empty
  | Ast.SContinue _ -> StringSet.empty
  | Ast.SFor (_, iterable, body, _) ->
      StringSet.union (called_names_expr iterable) (called_names_statements body)
  | Ast.SAssign (_, expression, _) -> called_names_expr expression
  | Ast.SIndexAssign (collection, index, value, _) ->
      StringSet.union (called_names_expr collection)
        (StringSet.union (called_names_expr index) (called_names_expr value))
  | Ast.SFieldAssign (object_expr, _, value, _) ->
      StringSet.union (called_names_expr object_expr) (called_names_expr value)
  | Ast.SImpl _ | Ast.SImport _ | Ast.SFromImport _ | Ast.SStruct _
  | Ast.SInterface _ | Ast.SEnum _ -> StringSet.empty

and called_names_statements statements =
  List.fold_left (fun names statement ->
    StringSet.union names (called_names_statement statement)
  ) StringSet.empty statements

and called_names_definition definition =
  let body_names = called_names_statements definition.Ast.def_body in
  List.fold_left (fun names (_, _, default_value) ->
    match default_value with
    | Some expression -> StringSet.union names (called_names_expr expression)
    | None -> names
  ) body_names definition.Ast.def_params

let dependency_closed_names module_program selected_names =
  let module_definitions = Hashtbl.create 32 in
  List.iter (function
    | Ast.SDef definition -> Hashtbl.replace module_definitions definition.Ast.def_name definition
    | _ -> ()) module_program;
  let needed = ref (List.fold_left (fun names name -> StringSet.add name names) StringSet.empty selected_names) in
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter (function
      | Ast.SDef definition when StringSet.mem definition.Ast.def_name !needed ->
          StringSet.iter (fun dependency_name ->
            if Hashtbl.mem module_definitions dependency_name &&
               not (StringSet.mem dependency_name !needed) then begin
              needed := StringSet.add dependency_name !needed;
              changed := true
            end
          ) (called_names_definition definition)
      | _ -> ()) module_program
  done;
  !needed

let imported_definitions program =
  let definition_names = Hashtbl.create 32 in
  let type_definition_names = Hashtbl.create 32 in
  let visited_modules = Hashtbl.create 16 in
  let add_definition definitions definition =
    if Hashtbl.mem definition_names definition.Ast.def_name then
      definitions
    else begin
      Hashtbl.add definition_names definition.Ast.def_name ();
      Ast.SDef definition :: definitions
    end
  in
  let rec add_module definitions module_path selected_names =
    let module_key = String.concat "." module_path in
    if Hashtbl.mem visited_modules module_key then
      definitions
    else begin
      Hashtbl.add visited_modules module_key ();
    match Module_loader.load_module module_path with
    | Error _ -> definitions
    | Ok (_, module_program) ->
        let selected_name_set = match selected_names with
          | None -> None
          | Some names -> Some (dependency_closed_names module_program names)
        in
        let definitions = List.fold_left (fun definitions statement ->
          match statement with
          | Ast.SDef definition ->
              let is_selected = match selected_name_set with
                | None -> true
                | Some names -> StringSet.mem definition.Ast.def_name names
              in
              if is_selected then add_definition definitions definition else definitions
          | Ast.SConst const_info ->
              if Hashtbl.mem definition_names const_info.Ast.const_name then definitions
              else begin
                Hashtbl.add definition_names const_info.Ast.const_name ();
                Ast.SConst const_info :: definitions
              end
          | Ast.SLet let_info ->
              if Hashtbl.mem definition_names let_info.Ast.let_name then definitions
              else begin
                Hashtbl.add definition_names let_info.Ast.let_name ();
                Ast.SLet let_info :: definitions
              end
          | Ast.SStruct struct_info ->
              if Hashtbl.mem type_definition_names struct_info.Ast.struct_name then definitions
              else begin
                Hashtbl.add type_definition_names struct_info.Ast.struct_name ();
                Ast.SStruct struct_info :: definitions
              end
          | Ast.SEnum enum_info ->
              if Hashtbl.mem type_definition_names enum_info.Ast.enum_name then definitions
              else begin
                Hashtbl.add type_definition_names enum_info.Ast.enum_name ();
                Ast.SEnum enum_info :: definitions
              end
          | Ast.SInterface interface_info ->
              if Hashtbl.mem type_definition_names interface_info.Ast.interface_name then definitions
              else begin
                Hashtbl.add type_definition_names interface_info.Ast.interface_name ();
                Ast.SInterface interface_info :: definitions
              end
          | Ast.SImpl (impl_info, position) ->
              Ast.SImpl (impl_info, position) :: definitions
          | Ast.SImport (dependency_path, _, _) ->
              add_module definitions dependency_path None
          | Ast.SFromImport (dependency_name, _, _) ->
              add_module definitions [dependency_name] None
          | _ -> definitions
        ) definitions module_program in
        definitions
    end
  in
  let imported = List.fold_left (fun definitions statement ->
    match statement with
    | Ast.SImport (module_path, _, _) ->
        add_module definitions module_path None
    | Ast.SFromImport (module_name, selections, _) ->
        let selected_names = Some (List.map fst selections) in
        add_module definitions [module_name] selected_names
    | _ -> definitions
  ) [] program in
  program @ List.rev imported

let generate program =
  match Dir_lower.lower_program (imported_definitions program) with
  | Error message -> failwith ("DIR lowering failed: " ^ message)
  | Ok module_ ->
      let verification_errors = Dir_verify.verify module_ in
      if verification_errors <> [] then
        failwith ("DIR verification failed:\n" ^
          String.concat "\n" verification_errors);
      {
        llvm_ir = Dir_lower_llvm.render module_;
        dir_text = Some (Dir_printer.render module_);
      }
