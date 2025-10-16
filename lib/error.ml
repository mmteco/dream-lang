open Ast

(* 错误级别 *)
type severity =
  | Error   (* 错误：会终止编译 *)
  | Warning (* 警告：不影响编译 *)

type error_kind =
  | LexError of string
  | ParseError of string
  | TypeError of string
  | NameError of string
  | ValueError of string

type error = {
  kind: error_kind;
  severity: severity;
  position: position;
  message: string;
}

(* 全局错误和警告计数器 *)
let error_count = ref 0
let warning_count = ref 0

let reset_counters () =
  error_count := 0;
  warning_count := 0

let get_error_count () = !error_count
let get_warning_count () = !warning_count
let has_errors () = !error_count > 0

let make_error kind pos msg = {
  kind = kind;
  severity = Error;
  position = pos;
  message = msg;
}

let make_warning kind pos msg = {
  kind = kind;
  severity = Warning;
  position = pos;
  message = msg;
}

let error_kind_to_string = function
  | LexError _ -> "Lexical Error"
  | ParseError _ -> "Parse Error"
  | TypeError _ -> "Type Error"
  | NameError _ -> "Name Error"
  | ValueError _ -> "Value Error"

let severity_to_string = function
  | Error -> "Error"
  | Warning -> "Warning"

let format_error err =
  Printf.sprintf "%s: %s at line %d, column %d: %s"
    (severity_to_string err.severity)
    (error_kind_to_string err.kind)
    (err.position.line + 1)  (* 内部使用 0-based 行号，输出时转换为 1-based *)
    err.position.column
    err.message

let report_error err =
  (match err.severity with
   | Error -> incr error_count
   | Warning -> incr warning_count);
  Printf.eprintf "%s\n" (format_error err);
  flush stderr

let report_errors errors =
  List.iter report_error errors

let print_summary () =
  if !error_count > 0 || !warning_count > 0 then begin
    Printf.eprintf "\nCompilation summary:\n\n";
    if !error_count > 0 then
      Printf.eprintf "  %d error(s)\n" !error_count;
    if !warning_count > 0 then
      Printf.eprintf "  %d warning(s)\n" !warning_count;
    flush stderr
  end
