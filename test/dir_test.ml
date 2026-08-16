open Dream_lib

let assert_true condition message =
  if not condition then failwith message

let contains text fragment =
  let text_length = String.length text in
  let fragment_length = String.length fragment in
  let rec search index =
    if index + fragment_length > text_length then false
    else if String.sub text index fragment_length = fragment then true
    else search (index + 1)
  in
  if fragment_length = 0 then true else search 0

let select_function =
  let entry = {
    Dir.label = "entry";
    params = [];
    instructions = [Dir.Compare (3, Dir.Gt, Dir.Value 1, Dir.Value 2)];
    terminator = Dir.Branch (
      Dir.Value 3,
      ("left", [Dir.Value 1]),
      ("right", [Dir.Value 2])
    );
  } in
  let left = {
    Dir.label = "left";
    params = [(4, Dir.I32)];
    instructions = [];
    terminator = Dir.Jump ("merge", [Dir.Value 4]);
  } in
  let right = {
    Dir.label = "right";
    params = [(5, Dir.I32)];
    instructions = [];
    terminator = Dir.Jump ("merge", [Dir.Value 5]);
  } in
  let merge = {
    Dir.label = "merge";
    params = [(6, Dir.I32)];
    instructions = [];
    terminator = Dir.Return (Some (Dir.Value 6));
  } in
  {
    Dir.name = "select";
    parameters = [
      {Dir.value = 1; name = "left"; ty = Dir.I32};
      {Dir.value = 2; name = "right"; ty = Dir.I32};
    ];
    return_type = Dir.I32;
    blocks = [entry; left; right; merge];
  }

let list_function =
  let entry = {
    Dir.label = "entry";
    params = [];
    instructions = [
      Dir.ListCreate (1, Dir.I32, [Dir.Int 10; Dir.Int 20]);
      Dir.ListLength (2, Dir.Value 1);
      Dir.ListGet (3, Dir.Value 1, Dir.Int 0);
      Dir.ListSet (Dir.Value 1, Dir.Int 1, Dir.Int 99);
      Dir.ListAppend (Dir.Value 1, Dir.Int 30);
    ];
    terminator = Dir.Return (Some (Dir.Value 3));
  } in
  {
    Dir.name = "list_ops";
    parameters = [];
    return_type = Dir.I32;
    blocks = [entry];
  }

let branch_merge_program =
  let position = {Ast.line = 1; column = 1} in
  let integer value = Ast.EInt (value, position) in
  let variable name = Ast.EVar (name, position) in
  let definition = {
    Ast.def_name = "main";
    def_name_pos = position;
    def_type_params = [];
    def_params = [];
    def_return_type = Some Ast.TInt;
    def_body = [
      Ast.SLet {
        let_name = "value";
        let_name_pos = position;
        let_type = Some Ast.TInt;
        let_value = integer 0;
        let_pos = position;
      };
      Ast.SIf (
        Ast.EBool (true, position),
        [Ast.SAssign ("value", integer 1, position)],
        [],
        None,
        position
      );
      Ast.SReturn (Some (variable "value"), position);
    ];
    def_pos = position;
  } in
  [Ast.SDef definition]

let scalar_switch_function name switch_value first_case_value second_case_value =
  let entry = {
    Dir.label = "entry";
    params = [];
    instructions = [];
    terminator = Dir.Switch (
      switch_value,
      [
        (first_case_value, "case", []);
        (second_case_value, "second_case", []);
      ],
      ("default", [])
    );
  } in
  let case_block = {
    Dir.label = "case";
    params = [];
    instructions = [];
    terminator = Dir.Return (Some (Dir.Int 1));
  } in
  let second_case_block = {
    Dir.label = "second_case";
    params = [];
    instructions = [];
    terminator = Dir.Return (Some (Dir.Int 2));
  } in
  let default_block = {
    Dir.label = "default";
    params = [];
    instructions = [];
    terminator = Dir.Return (Some (Dir.Int 0));
  } in
  {
    Dir.name = name;
    parameters = [];
    return_type = Dir.I32;
    blocks = [entry; case_block; second_case_block; default_block];
  }

let () =
  let scalar_switch_functions = [
    scalar_switch_function "switch_int" (Dir.Int 2) (Dir.Int 1) (Dir.Int 2);
    scalar_switch_function "switch_bool" (Dir.Bool true) (Dir.Bool false) (Dir.Bool true);
    scalar_switch_function "switch_float" (Dir.Float 2.5) (Dir.Float 1.5) (Dir.Float 2.5);
    scalar_switch_function "switch_str" (Dir.String "ready") (Dir.String "failed") (Dir.String "ready");
  ] in
  let module_ = {
    Dir.name = "dir_test";
    externs = [];
    functions = [select_function; list_function] @ scalar_switch_functions;
  } in
  let errors = Dir_verify.verify module_ in
  assert_true (errors = []) (String.concat "\n" errors);
  let dir_text = Dir_printer.render module_ in
  assert_true (contains dir_text "branch %v3, left(%v1), right(%v2)")
    "DIR printer lost branch arguments";
  assert_true (contains dir_text "merge(%v6 i32)")
    "DIR printer lost block parameters";
  let llvm_text = Dir_lower_llvm.render module_ in
  assert_true (contains llvm_text "br i1 %v3, label %left, label %right")
    "LLVM lowering lost conditional branch";
  assert_true (contains llvm_text "%v6 = phi i32")
    "LLVM lowering did not create phi for block parameter";
  let list_errors = Dir_verify.verify {
    Dir.name = "list_test";
    externs = [];
    functions = [list_function];
  } in
  assert_true (list_errors = []) (String.concat "\n" list_errors);
  let list_llvm_text = Dir_lower_llvm.render {
    Dir.name = "list_test";
    externs = [];
    functions = [list_function];
  } in
  assert_true (contains list_llvm_text "@set_dynarray_i32")
    "LLVM lowering lost list mutation";
  let switch_llvm_text = Dir_lower_llvm.render {
    Dir.name = "switch_test";
    externs = [];
    functions = scalar_switch_functions;
  } in
  assert_true (contains switch_llvm_text "switch i32 2")
    "integer DIR switch did not use LLVM switch";
  assert_true (contains switch_llvm_text "icmp eq i1 1, 1")
    "boolean DIR switch did not lower to an integer comparison";
  assert_true (contains switch_llvm_text "fcmp oeq double")
    "float DIR switch did not lower to a floating-point comparison";
  assert_true (contains switch_llvm_text "call i32 @string_compare")
    "string DIR switch did not lower to string comparison";
  let merged_module = match Dir_lower.lower_program branch_merge_program with
    | Ok module_ -> module_
    | Error message -> failwith message
  in
  let merged_function = List.find (fun (function_def : Dir.function_def) -> function_def.name = "main")
    (merged_module.functions)
  in
  let join_block = List.find (fun (block : Dir.block) ->
    String.length block.label >= 8 && String.sub block.label 0 8 = "if_join_")
    merged_function.blocks
  in
  assert_true (List.length join_block.params = 1)
    "DIR if lowering lost the merged variable";
  assert_true (Dir_verify.verify merged_module = [])
    "DIR if merge failed verification";
  let invalid_scope_function = {
    Dir.name = "invalid_scope";
    parameters = [];
    return_type = Dir.I32;
    blocks = [
      {
        Dir.label = "entry";
        params = [];
        instructions = [Dir.Binop (1, Dir.I32, Dir.Add, Dir.Value 2, Dir.Int 1)];
        terminator = Dir.Return (Some (Dir.Value 1));
      };
      {
        Dir.label = "later";
        params = [(2, Dir.I32)];
        instructions = [];
        terminator = Dir.Return (Some (Dir.Value 2));
      }
    ];
  } in
  let invalid_scope_errors = Dir_verify.verify {
    Dir.name = "invalid_scope";
    externs = [];
    functions = [invalid_scope_function];
  } in
  assert_true (contains (String.concat "\n" invalid_scope_errors) "undefined value %v2")
    "DIR verifier accepted a block parameter outside its block";
  let call_function = {
    Dir.name = "call_test";
    parameters = [];
    return_type = Dir.Unit;
    blocks = [{
      Dir.label = "entry";
      params = [];
      instructions = [Dir.Call (None, Dir.I32, "runtime.add", [Dir.I32], [Dir.Int 1])];
      terminator = Dir.Return None;
    }];
  } in
  let call_errors = Dir_verify.verify {
    Dir.name = "call_test";
    externs = [{Dir.name = "runtime.add"; parameters = [Dir.I32]; return_type = Dir.I32}];
    functions = [call_function];
  } in
  assert_true (contains (String.concat "\n" call_errors) "non-unit result must be bound")
    "DIR verifier accepted an unbound call result";
  let invalid_symbol_errors = Dir_verify.verify {
    Dir.name = "invalid_symbol";
    externs = [{Dir.name = "bad-name"; parameters = []; return_type = Dir.Unit}];
    functions = [];
  } in
  assert_true (contains (String.concat "\n" invalid_symbol_errors) "invalid symbol name")
    "DIR verifier accepted an invalid symbol name";
  print_endline "DIR pipeline test passed"
