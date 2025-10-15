open Ast
open Buffer

let indent_level = ref 0

let add_indent buf =
  for _ = 1 to !indent_level do
    add_string buf "    "
  done

let with_indent f buf =
  indent_level := !indent_level + 1;
  f buf;
  indent_level := !indent_level - 1

let mangle_name name =
  String.map (fun c -> if c = '_' then '_' else c) name

let gen_binop = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"
  | Eq -> "=="
  | Neq -> "!="
  | Lt -> "<"
  | Gt -> ">"
  | Lte -> "<="
  | Gte -> ">="
  | And -> "&&"
  | Or -> "||"

let gen_unop = function
  | Neg -> "-"
  | Not -> "!"

let rec gen_expr buf = function
  | EInt (n, _) ->
      add_string buf (string_of_int n)

  | EFloat (f, _) ->
      add_string buf (string_of_float f)

  | EString (s, _) ->
      add_string buf "\"";
      add_string buf (String.escaped s);
      add_string buf "\""

  | EBool (b, _) ->
      add_string buf (if b then "1" else "0")

  | ENone _ ->
      add_string buf "NULL"

  | EVar (name, _) ->
      add_string buf (mangle_name name)

  | EBinOp (e1, op, e2, _) ->
      add_string buf "(";
      gen_expr buf e1;
      add_string buf " ";
      add_string buf (gen_binop op);
      add_string buf " ";
      gen_expr buf e2;
      add_string buf ")"

  | EUnOp (op, e, _) ->
      add_string buf "(";
      add_string buf (gen_unop op);
      gen_expr buf e;
      add_string buf ")"

  | ECall (EVar ("print", _), args, _) ->
      add_string buf "printf(";
      (match args with
       | [EString (s, _)] ->
           add_string buf "\"";
           add_string buf (String.escaped s);
           add_string buf "\\n\""
       | [e] ->
           add_string buf "\"%d\\n\", ";
           gen_expr buf e
       | _ ->
           add_string buf "\"TODO: multiple args\\n\"");
      add_string buf ")"

  | ECall (EVar ("len", _), [arg], _) ->
      add_string buf "array_length(";
      gen_expr buf arg;
      add_string buf ")"

  | ECall (func, args, _) ->
      gen_expr buf func;
      add_string buf "(";
      let rec gen_args = function
        | [] -> ()
        | [e] -> gen_expr buf e
        | e :: es ->
            gen_expr buf e;
            add_string buf ", ";
            gen_args es
      in
      gen_args args;
      add_string buf ")"

  | EList (elems, _) ->
      add_string buf "{";
      let rec gen_elems = function
        | [] -> ()
        | [e] -> gen_expr buf e
        | e :: es ->
            gen_expr buf e;
            add_string buf ", ";
            gen_elems es
      in
      gen_elems elems;
      add_string buf "}"

  | EDict (_, _) ->
      add_string buf "/* dict not implemented */"

  | ETuple (elems, _) ->
      add_string buf "{";
      let rec gen_elems = function
        | [] -> ()
        | [e] -> gen_expr buf e
        | e :: es ->
            gen_expr buf e;
            add_string buf ", ";
            gen_elems es
      in
      gen_elems elems;
      add_string buf "}"

  | EIndex (arr, idx, _) ->
      gen_expr buf arr;
      add_string buf "[";
      gen_expr buf idx;
      add_string buf "]"

  | EAttr (_, _, _) ->
      add_string buf "/* attr access not implemented */"

  | ELambda (_, _, _) ->
      add_string buf "/* lambda not implemented */"

  | EIf (cond, then_expr, Some else_expr, _) ->
      add_string buf "(";
      gen_expr buf cond;
      add_string buf " ? ";
      gen_expr buf then_expr;
      add_string buf " : ";
      gen_expr buf else_expr;
      add_string buf ")"

  | EIf (_, _, None, _) ->
      add_string buf "/* if without else not supported in expr */"

  | EMatch (_, _, _) ->
      add_string buf "/* match not implemented */"

  | EListComp (_, _, _, _, _) ->
      add_string buf "/* list comprehension not implemented */"

let rec gen_statement buf = function
  | SExpr (e, _) ->
      add_indent buf;
      gen_expr buf e;
      add_string buf ";\n"

  | SLet (name, _, value, _) ->
      add_indent buf;
      add_string buf "int ";
      add_string buf (mangle_name name);
      add_string buf " = ";
      gen_expr buf value;
      add_string buf ";\n"

  | SAssign (name, value, _) ->
      add_indent buf;
      add_string buf (mangle_name name);
      add_string buf " = ";
      gen_expr buf value;
      add_string buf ";\n"

  | SDef (name, params, ret_ty, body, _) ->
      add_indent buf;
      let ret_type_str = match ret_ty with
        | Some TInt -> "int"
        | Some TFloat -> "double"
        | Some TString -> "char*"
        | Some TBool -> "int"
        | _ -> "void"
      in
      add_string buf ret_type_str;
      add_string buf " ";
      add_string buf (mangle_name name);
      add_string buf "(";

      let rec gen_params = function
        | [] -> ()
        | [(pname, pty)] ->
            let param_type = match pty with
              | Some TInt -> "int"
              | Some TFloat -> "double"
              | Some TString -> "char*"
              | Some TBool -> "int"
              | _ -> "int"
            in
            add_string buf param_type;
            add_string buf " ";
            add_string buf (mangle_name pname)
        | (pname, pty) :: rest ->
            let param_type = match pty with
              | Some TInt -> "int"
              | Some TFloat -> "double"
              | Some TString -> "char*"
              | Some TBool -> "int"
              | _ -> "int"
            in
            add_string buf param_type;
            add_string buf " ";
            add_string buf (mangle_name pname);
            add_string buf ", ";
            gen_params rest
      in
      gen_params params;
      add_string buf ") {\n";
      with_indent (fun buf -> List.iter (gen_statement buf) body) buf;
      add_indent buf;
      add_string buf "}\n\n"

  | SReturn (None, _) ->
      add_indent buf;
      add_string buf "return;\n"

  | SReturn (Some e, _) ->
      add_indent buf;
      add_string buf "return ";
      gen_expr buf e;
      add_string buf ";\n"

  | SIf (cond, then_body, elifs, else_opt, _) ->
      add_indent buf;
      add_string buf "if (";
      gen_expr buf cond;
      add_string buf ") {\n";
      with_indent (fun buf -> List.iter (gen_statement buf) then_body) buf;
      add_indent buf;
      add_string buf "}";

      List.iter (fun (elif_cond, elif_body) ->
        add_string buf " else if (";
        gen_expr buf elif_cond;
        add_string buf ") {\n";
        with_indent (fun buf -> List.iter (gen_statement buf) elif_body) buf;
        add_indent buf;
        add_string buf "}"
      ) elifs;

      (match else_opt with
       | Some else_body ->
           add_string buf " else {\n";
           with_indent (fun buf -> List.iter (gen_statement buf) else_body) buf;
           add_indent buf;
           add_string buf "}"
       | None -> ());
      add_string buf "\n"

  | SWhile (cond, body, _) ->
      add_indent buf;
      add_string buf "while (";
      gen_expr buf cond;
      add_string buf ") {\n";
      with_indent (fun buf -> List.iter (gen_statement buf) body) buf;
      add_indent buf;
      add_string buf "}\n"

  | SFor (var, _iter, body, _) ->
      add_indent buf;
      add_string buf "/* for loop: simplified */\n";
      add_indent buf;
      add_string buf "for (int i = 0; i < 10; i++) {\n";
      add_indent buf;
      add_string buf "    int ";
      add_string buf (mangle_name var);
      add_string buf " = i;\n";
      with_indent (fun buf -> List.iter (gen_statement buf) body) buf;
      add_indent buf;
      add_string buf "}\n"

  | SMatch (_, _, _) ->
      add_indent buf;
      add_string buf "/* match not implemented */\n"

  | SClass (_, _, _, _, _) ->
      add_indent buf;
      add_string buf "/* class not implemented */\n"

  | SInterface (_, _, _) ->
      add_indent buf;
      add_string buf "/* interface not implemented */\n"

  | SImport (_, _) | SFromImport (_, _, _) ->
      ()

let gen_program program =
  let buf = create 4096 in

  add_string buf "#include <stdio.h>\n";
  add_string buf "#include <stdlib.h>\n";
  add_string buf "#include <string.h>\n\n";

  let has_main = List.exists (function
    | SDef ("main", _, _, _, _) -> true
    | _ -> false) program
  in

  if has_main then begin
    List.iter (gen_statement buf) program
  end else begin
    List.iter (fun stmt ->
      match stmt with
      | SDef _ -> gen_statement buf stmt
      | _ -> ()
    ) program;

    add_string buf "int main() {\n";
    indent_level := 1;
    List.iter (fun stmt ->
      match stmt with
      | SDef _ -> ()
      | _ -> gen_statement buf stmt
    ) program;
    indent_level := 0;
    add_string buf "    return 0;\n";
    add_string buf "}\n"
  end;

  contents buf
