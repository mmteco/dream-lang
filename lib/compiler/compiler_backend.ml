type backend =
  | Legacy
  | Dir

type artifact = {
  llvm_ir: string;
  dir_text: string option;
}

let generate backend program =
  match backend with
  | Legacy ->
      { llvm_ir = Llvmgen.gen_program program; dir_text = None }
  | Dir ->
      (match Dir_lower.lower_program program with
       | Error message -> failwith ("DIR lowering failed: " ^ message)
       | Ok module_ ->
           let verification_errors = Dir_verify.verify module_ in
           if verification_errors <> [] then
             failwith ("DIR verification failed:\n" ^
               String.concat "\n" verification_errors);
           {
             llvm_ir = Dir_lower_llvm.render module_;
             dir_text = Some (Dir_printer.render module_);
           })
