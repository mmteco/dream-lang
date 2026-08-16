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

let () =
  let module_ = {
    Dir.name = "dir_test";
    externs = [];
    functions = [select_function; list_function];
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
  print_endline "DIR pipeline test passed"
