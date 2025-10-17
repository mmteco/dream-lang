open Ast
open Types

(* 泛型实例收集器 *)
type generic_instance = {
  func_name: string;
  type_args: ty list;
  call_pos: position;
}

let generic_instances = ref []

let add_generic_instance func_name type_args pos =
  generic_instances := { func_name; type_args; call_pos = pos } :: !generic_instances

let get_generic_instances () = !generic_instances

let clear_generic_instances () = generic_instances := []
