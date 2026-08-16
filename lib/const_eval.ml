open Ast

type value =
  | Int of int
  | Bool of bool
  | Byte of int
  | Rune of int
  | Float of float
  | String of string

let collect (program : program) : (string * value) list =
  let definitions = Hashtbl.create 16 in
  List.iter (function
    | SConst const_info ->
        Hashtbl.replace definitions const_info.const_name const_info.const_value
    | _ -> ()) program;
  let resolved = Hashtbl.create 16 in
  let rec resolve_name name resolving =
    match Hashtbl.find_opt resolved name with
    | Some value -> Some value
    | None ->
        if List.mem name resolving then
          None
        else
          match Hashtbl.find_opt definitions name with
          | None -> None
          | Some expression ->
              (match resolve_expression (name :: resolving) expression with
               | None -> None
               | Some value ->
                   Hashtbl.replace resolved name value;
                   Some value)
  and resolve_expression resolving = function
    | EInt (value, _) -> Some (Int value)
    | EBool (value, _) -> Some (Bool value)
    | EByte (value, _) -> Some (Byte value)
    | ERune (value, _) -> Some (Rune value)
    | EFloat (value, _) -> Some (Float value)
    | EString (value, _) -> Some (String value)
    | EVar (name, _) -> resolve_name name resolving
    | _ -> None
  in
  List.filter_map (function
    | SConst const_info ->
        (match resolve_name const_info.const_name [] with
         | Some value -> Some (const_info.const_name, value)
         | None -> None)
    | _ -> None) program
