(* LLVM IR Code Generator - Main Interface *)

(* 重新导出模块 *)
module Types = Cg_types
module Utils = Cg_utils
module Expr = Cg_expr
module Stmt = Cg_stmt
module Toplevel = Cg_toplevel

(* 对外暴露主要接口 *)
let gen_program = Cg_toplevel.gen_program
let generate = gen_program
