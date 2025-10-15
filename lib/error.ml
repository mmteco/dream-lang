open Ast

type error_kind =
  | LexError of string
  | ParseError of string
  | TypeError of string
  | NameError of string
  | ValueError of string

type error = {
  kind: error_kind;
  position: position;
  message: string;
}

let make_error kind pos msg = {
  kind = kind;
  position = pos;
  message = msg;
}

let error_kind_to_string = function
  | LexError _ -> "Lexical Error"
  | ParseError _ -> "Parse Error"
  | TypeError _ -> "Type Error"
  | NameError _ -> "Name Error"
  | ValueError _ -> "Value Error"

let format_error err =
  Printf.sprintf "%s at line %d, column %d: %s"
    (error_kind_to_string err.kind)
    err.position.line
    err.position.column
    err.message

let report_error err =
  Printf.eprintf "%s\n" (format_error err);
  flush stderr

let report_errors errors =
  List.iter report_error errors
