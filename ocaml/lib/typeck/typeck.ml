open Env

(* 导出类型 *)
type generic_instance = Tc_generics.generic_instance

(* 导出工具函数 *)
module Utils = Tc_utils
module Generics = Tc_generics

(* 设置 tc_stmt 的 infer_expr 引用 *)
let () = Tc_stmt.set_infer_expr Tc_expr.infer_expr

(* 导出主要函数 *)
let set_current_file = Tc_utils.set_current_file
let get_generic_instances = Tc_generics.get_generic_instances
let clear_generic_instances = Tc_generics.clear_generic_instances
let infer_expr = Tc_expr.infer_expr
let check_statement = Tc_stmt.check_statement
let check_statements = Tc_stmt.check_statements

(* 主类型检查入口 *)
let typecheck program =
  let (final_env, _) = check_statements builtin_env program in
  let transformed_program = List.map (Tc_defaults.fill_default_params_stmt final_env) program in
  transformed_program
