{
  open Ast
  open Parser

  exception LexError of string

  let line_num = ref 1
  let col_num = ref 0
  let indent_stack = ref [0]

  let get_pos () = { line = !line_num; column = !col_num }

  let update_pos lexbuf =
    col_num := !col_num + Lexing.lexeme_end lexbuf - Lexing.lexeme_start lexbuf

  let newline _lexbuf =
    line_num := !line_num + 1;
    col_num := 0

  let keyword_table = Hashtbl.create 32
  let () =
    List.iter (fun (kwd, tok) -> Hashtbl.add keyword_table kwd tok)
      [ ("let", LET);
        ("def", DEF);
        ("class", CLASS);
        ("interface", INTERFACE);
        ("implements", IMPLEMENTS);
        ("if", IF);
        ("else", ELSE);
        ("elif", ELIF);
        ("match", MATCH);
        ("case", CASE);
        ("for", FOR);
        ("while", WHILE);
        ("return", RETURN);
        ("import", IMPORT);
        ("from", FROM);
        ("as", AS);
        ("async", ASYNC);
        ("await", AWAIT);
        ("None", NONE);
        ("True", BOOL true);
        ("False", BOOL false);
        ("and", AND);
        ("or", OR);
        ("not", NOT);
        ("self", SELF);
        ("super", SUPER);
        ("in", IN);
      ]
}

let whitespace = [' ' '\t']
let newline = '\n' | '\r' | "\r\n"
let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z']
let ident = (letter | '_') (letter | digit | '_')*
let integer = digit+
let float = digit+ '.' digit*

rule token = parse
  | whitespace+ { update_pos lexbuf; token lexbuf }
  | newline { newline lexbuf; NEWLINE }
  | '#' { line_comment lexbuf }
  | integer as i { update_pos lexbuf; INT (int_of_string i) }
  | float as f { update_pos lexbuf; FLOAT (float_of_string f) }
  | '"' { update_pos lexbuf; read_string (Buffer.create 16) lexbuf }
  | "'" { update_pos lexbuf; read_single_string (Buffer.create 16) lexbuf }
  | ident as id {
      update_pos lexbuf;
      try Hashtbl.find keyword_table id
      with Not_found -> IDENT id
    }
  | "->" { update_pos lexbuf; ARROW }
  | '+' { update_pos lexbuf; PLUS }
  | '-' { update_pos lexbuf; MINUS }
  | '*' { update_pos lexbuf; TIMES }
  | '/' { update_pos lexbuf; DIV }
  | '%' { update_pos lexbuf; MOD }
  | "==" { update_pos lexbuf; EQ }
  | "!=" { update_pos lexbuf; NEQ }
  | "<=" { update_pos lexbuf; LTE }
  | ">=" { update_pos lexbuf; GTE }
  | '<' { update_pos lexbuf; LT }
  | '>' { update_pos lexbuf; GT }
  | '=' { update_pos lexbuf; ASSIGN }
  | '|' { update_pos lexbuf; PIPE }
  | '(' { update_pos lexbuf; LPAREN }
  | ')' { update_pos lexbuf; RPAREN }
  | '[' { update_pos lexbuf; LBRACKET }
  | ']' { update_pos lexbuf; RBRACKET }
  | '{' { update_pos lexbuf; LBRACE }
  | '}' { update_pos lexbuf; RBRACE }
  | ',' { update_pos lexbuf; COMMA }
  | ':' { update_pos lexbuf; COLON }
  | ';' { update_pos lexbuf; SEMICOLON }
  | '.' { update_pos lexbuf; DOT }
  | eof { EOF }
  | _ as c {
      update_pos lexbuf;
      raise (LexError (Printf.sprintf "Unexpected character: %c" c))
    }

and line_comment = parse
  | newline { newline lexbuf; NEWLINE }
  | eof { EOF }
  | _ { line_comment lexbuf }

and read_string buf = parse
  | '"' { update_pos lexbuf; STRING (Buffer.contents buf) }
  | '\\' 'n' { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 't' { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' '"' { Buffer.add_char buf '"'; read_string buf lexbuf }
  | newline { newline lexbuf; Buffer.add_char buf '\n'; read_string buf lexbuf }
  | eof { raise (LexError "Unterminated string") }
  | _ as c { Buffer.add_char buf c; read_string buf lexbuf }

and read_single_string buf = parse
  | "'" { update_pos lexbuf; STRING (Buffer.contents buf) }
  | '\\' 'n' { Buffer.add_char buf '\n'; read_single_string buf lexbuf }
  | '\\' 't' { Buffer.add_char buf '\t'; read_single_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_single_string buf lexbuf }
  | '\\' "'" { Buffer.add_char buf '\''; read_single_string buf lexbuf }
  | newline { newline lexbuf; Buffer.add_char buf '\n'; read_single_string buf lexbuf }
  | eof { raise (LexError "Unterminated string") }
  | _ as c { Buffer.add_char buf c; read_single_string buf lexbuf }

{
  let peek_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len then
      None
    else
      Some (Bytes.get lexbuf.Lexing.lex_buffer lexbuf.Lexing.lex_curr_pos)

  let junk_char lexbuf =
    lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_curr_pos + 1

  let count_indent str =
    let rec loop i count =
      if i >= String.length str then count
      else match str.[i] with
        | ' ' -> loop (i + 1) (count + 1)
        | '\t' -> loop (i + 1) (count + 8)
        | _ -> count
    in
    loop 0 0

  let handle_indent spaces =
    let current = List.hd !indent_stack in
    if spaces > current then begin
      indent_stack := spaces :: !indent_stack;
      [INDENT]
    end else if spaces < current then begin
      let rec generate_dedents acc stack =
        match stack with
        | [] -> (acc, stack)
        | x :: xs ->
            if x > spaces then
              generate_dedents (DEDENT :: acc) xs
            else if x = spaces then
              (acc, stack)
            else
              raise (LexError "Indentation error")
      in
      let (dedents, new_stack) = generate_dedents [] !indent_stack in
      indent_stack := new_stack;
      dedents
    end else []

  let tokenize_string source =
    line_num := 1;
    col_num := 0;
    indent_stack := [0];
    let lexbuf = Lexing.from_string source in
    let rec next_tokens acc at_line_start =
      if at_line_start then begin
        let rec count_spaces acc =
          match peek_char lexbuf with
          | Some ' ' ->
              junk_char lexbuf;
              count_spaces (acc + 1)
          | Some '\t' ->
              junk_char lexbuf;
              count_spaces (acc + 8)
          | _ -> acc
        in
        let indent_level = count_spaces 0 in
        col_num := indent_level;

        match peek_char lexbuf with
        | Some '\n' | Some '\r' | Some '#' | None ->
            let tok = token lexbuf in
            if tok = EOF then List.rev (EOF :: acc)
            else next_tokens (tok :: acc) true
        | _ ->
            let indent_tokens = handle_indent indent_level in
            let acc_with_indents = List.fold_right (fun t a -> t :: a) indent_tokens acc in
            let tok = token lexbuf in
            next_tokens (tok :: acc_with_indents) (tok = NEWLINE)
      end else begin
        let tok = token lexbuf in
        if tok = EOF then begin
          let final_dedents = handle_indent 0 in
          List.rev (EOF :: final_dedents @ acc)
        end else
          next_tokens (tok :: acc) (tok = NEWLINE)
      end
    in
    next_tokens [] true
}
