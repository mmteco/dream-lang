(* 共享的生成函数引用 - 用于打破循环依赖 *)

open Ast
open Cg_types

(* 生成函数的类型签名 *)
type gen_expr_fn = Buffer.t -> context -> expr -> (llvm_value * llvm_type)
type gen_statement_fn = Buffer.t -> context -> statement -> unit

(* 可变引用，在模块初始化时设置 *)
let gen_expr_ref : gen_expr_fn option ref = ref None
let gen_statement_ref : gen_statement_fn option ref = ref None

(* 获取生成函数 *)
let get_gen_expr () =
  match !gen_expr_ref with
  | Some f -> f
  | None -> failwith "gen_expr not initialized"

let get_gen_statement () =
  match !gen_statement_ref with
  | Some f -> f
  | None -> failwith "gen_statement not initialized"

(* 设置生成函数 *)
let set_gen_expr f = gen_expr_ref := Some f
let set_gen_statement f = gen_statement_ref := Some f
