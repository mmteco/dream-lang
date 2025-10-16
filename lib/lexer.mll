{
  open Ast
  open Parser

  exception LexError of string

  let line_num = ref 1
  let col_num = ref 0
  let byte_offset = ref 0        (* 累计字节偏移 *)
  let line_start_offset = ref 0  (* 当前行开始的字节偏移 *)
  let indent_stack = ref [0]

  let get_pos () = { line = !line_num; column = !col_num }

  let make_lexing_pos () =
    {
      Lexing.pos_fname = "";
      pos_lnum = !line_num;
      pos_bol = !line_start_offset;
      pos_cnum = !byte_offset;
    }

  let update_pos lexbuf =
    let len = Lexing.lexeme_end lexbuf - Lexing.lexeme_start lexbuf in
    col_num := !col_num + len;
    byte_offset := !byte_offset + len

  let newline _lexbuf =
    line_num := !line_num + 1;
    col_num := 0;
    byte_offset := !byte_offset + 1;  (* 换行符占 1 字节 *)
    line_start_offset := !byte_offset

  let keyword_table = Hashtbl.create 40
  let () =
    List.iter (fun (kwd, tok) -> Hashtbl.add keyword_table kwd tok)
      [ ("let", LET);
        ("def", DEF);
        ("struct", STRUCT);
        ("interface", INTERFACE);
        ("implements", IMPLEMENTS);
        ("impl", IMPL);
        ("type", TYPE);
        ("const", CONST);
        ("enum", ENUM);
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
        ("of", OF);
        ("async", ASYNC);
        ("await", AWAIT);
        ("True", BOOL true);
        ("true", BOOL true);
        ("False", BOOL false);
        ("false", BOOL false);
        ("and", AND);
        ("or", OR);
        ("not", NOT);
        ("self", SELF);
        ("super", SUPER);
        ("in", IN);
        ("Some", SOME);
        ("None", NONE);
        ("Ok", OK);
        ("Err", ERR);
        ("Option", OPTION);
        ("Result", RESULT);
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
  | newline {
      let start_pos = make_lexing_pos () in
      newline lexbuf;
      let end_pos = make_lexing_pos () in
      (NEWLINE, start_pos, end_pos)
    }
  | '#' { line_comment lexbuf }
  | integer as i {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (INT (int_of_string i), start_pos, end_pos)
    }
  | float as f {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (FLOAT (float_of_string f), start_pos, end_pos)
    }
  | "'''" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let str_tok = read_triple_single_string (Buffer.create 16) lexbuf in
      let end_pos = make_lexing_pos () in
      (str_tok, start_pos, end_pos)
    }
  | '"' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let str_tok = read_string (Buffer.create 16) lexbuf in
      let end_pos = make_lexing_pos () in
      (str_tok, start_pos, end_pos)
    }
  | "'" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let str_tok = read_single_string (Buffer.create 16) lexbuf in
      let end_pos = make_lexing_pos () in
      (str_tok, start_pos, end_pos)
    }
  | '_' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (UNDERSCORE, start_pos, end_pos)
    }
  | ident as id {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      let tok = try Hashtbl.find keyword_table id
                with Not_found -> IDENT id in
      (tok, start_pos, end_pos)
    }
  | "->" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (ARROW, start_pos, end_pos)
    }
  | '+' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (PLUS, start_pos, end_pos)
    }
  | '-' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (MINUS, start_pos, end_pos)
    }
  | '*' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (TIMES, start_pos, end_pos)
    }
  | '/' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (DIV, start_pos, end_pos)
    }
  | '%' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (MOD, start_pos, end_pos)
    }
  | "==" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (EQ, start_pos, end_pos)
    }
  | "!=" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (NEQ, start_pos, end_pos)
    }
  | "<=" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (LTE, start_pos, end_pos)
    }
  | ">=" {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (GTE, start_pos, end_pos)
    }
  | '<' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (LT, start_pos, end_pos)
    }
  | '>' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (GT, start_pos, end_pos)
    }
  | '=' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (ASSIGN, start_pos, end_pos)
    }
  | '|' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (PIPE, start_pos, end_pos)
    }
  | '(' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (LPAREN, start_pos, end_pos)
    }
  | ')' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (RPAREN, start_pos, end_pos)
    }
  | '[' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (LBRACKET, start_pos, end_pos)
    }
  | ']' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (RBRACKET, start_pos, end_pos)
    }
  | '{' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (LBRACE, start_pos, end_pos)
    }
  | '}' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (RBRACE, start_pos, end_pos)
    }
  | ',' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (COMMA, start_pos, end_pos)
    }
  | ':' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (COLON, start_pos, end_pos)
    }
  | ';' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (SEMICOLON, start_pos, end_pos)
    }
  | '.' {
      let start_pos = make_lexing_pos () in
      update_pos lexbuf;
      let end_pos = make_lexing_pos () in
      (DOT, start_pos, end_pos)
    }
  | eof {
      let pos = make_lexing_pos () in
      (EOF, pos, pos)
    }
  | _ as c {
      update_pos lexbuf;
      raise (LexError (Printf.sprintf "Unexpected character: %c" c))
    }

and line_comment = parse
  | newline {
      let start_pos = make_lexing_pos () in
      newline lexbuf;
      let end_pos = make_lexing_pos () in
      (NEWLINE, start_pos, end_pos)
    }
  | eof {
      let pos = make_lexing_pos () in
      (EOF, pos, pos)
    }
  | _ { line_comment lexbuf }

and read_string buf = parse
  | '"' {
      update_pos lexbuf;
      STRING (Buffer.contents buf)
    }
  | '\\' 'n' { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 't' { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' '"' { Buffer.add_char buf '"'; read_string buf lexbuf }
  | newline { newline lexbuf; Buffer.add_char buf '\n'; read_string buf lexbuf }
  | eof { raise (LexError "Unterminated string") }
  | _ as c { Buffer.add_char buf c; read_string buf lexbuf }

and read_single_string buf = parse
  | "'" {
      update_pos lexbuf;
      STRING (Buffer.contents buf)
    }
  | '\\' 'n' { Buffer.add_char buf '\n'; read_single_string buf lexbuf }
  | '\\' 't' { Buffer.add_char buf '\t'; read_single_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_single_string buf lexbuf }
  | '\\' "'" { Buffer.add_char buf '\''; read_single_string buf lexbuf }
  | newline { newline lexbuf; Buffer.add_char buf '\n'; read_single_string buf lexbuf }
  | eof { raise (LexError "Unterminated string") }
  | _ as c { Buffer.add_char buf c; read_single_string buf lexbuf }

and read_triple_single_string buf = parse
  | "'''" {
      update_pos lexbuf;
      STRING (Buffer.contents buf)
    }
  | newline { newline lexbuf; Buffer.add_char buf '\n'; read_triple_single_string buf lexbuf }
  | eof { raise (LexError "Unterminated triple-quoted string") }
  | _ as c {
      update_pos lexbuf;
      Buffer.add_char buf c;
      read_triple_single_string buf lexbuf
    }

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
      ([INDENT], false)
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
      (dedents, true)
    end else ([], false)

  (* 返回带位置信息的 token 列表: (token, start_pos, end_pos) list *)
  let tokenize_string_with_pos source =
    line_num := 1;
    col_num := 0;
    byte_offset := 0;
    line_start_offset := 0;
    indent_stack := [0];
    let lexbuf = Lexing.from_string source in
    let rec next_tokens acc at_line_start =
      if at_line_start then begin
        let rec count_spaces acc =
          match peek_char lexbuf with
          | Some ' ' ->
              junk_char lexbuf;
              byte_offset := !byte_offset + 1;
              count_spaces (acc + 1)
          | Some '\t' ->
              junk_char lexbuf;
              byte_offset := !byte_offset + 1;
              count_spaces (acc + 8)
          | _ -> acc
        in
        let indent_level = count_spaces 0 in
        col_num := indent_level;

        match peek_char lexbuf with
        | Some '\n' | Some '\r' | Some '#' | None ->
            let (tok, start_pos, end_pos) = token lexbuf in
            if tok = EOF then begin
              let (final_dedents, _) = handle_indent 0 in
              let eof_pos = make_lexing_pos () in
              let dedents_with_pos = List.map (fun t -> (t, start_pos, end_pos)) final_dedents in
              let final_with_pos = (EOF, eof_pos, eof_pos) :: dedents_with_pos in
              List.rev (final_with_pos @ acc)
            end else
              next_tokens ((tok, start_pos, end_pos) :: acc) true
        | _ ->
            let pos = make_lexing_pos () in
            let (indent_tokens, has_dedent) = handle_indent indent_level in
            let tokens_to_add = if has_dedent then [NEWLINE] @ indent_tokens else indent_tokens in
            let tokens_with_pos = List.map (fun t -> (t, pos, pos)) tokens_to_add in
            let acc_with_indents = List.fold_right (fun t a -> t :: a) tokens_with_pos acc in
            let (tok, start_pos, end_pos) = token lexbuf in
            next_tokens ((tok, start_pos, end_pos) :: acc_with_indents) (tok = NEWLINE)
      end else begin
        let (tok, start_pos, end_pos) = token lexbuf in
        if tok = EOF then begin
          let (final_dedents, _) = handle_indent 0 in
          let eof_pos = make_lexing_pos () in
          let dedents_with_pos = List.map (fun t -> (t, start_pos, end_pos)) final_dedents in
          let final_with_pos = (EOF, eof_pos, eof_pos) :: dedents_with_pos in
          List.rev (final_with_pos @ acc)
        end else
          next_tokens ((tok, start_pos, end_pos) :: acc) (tok = NEWLINE)
      end
    in
    next_tokens [] true

  (* 保留旧的接口用于向后兼容 *)
  let tokenize_string source =
    List.map (fun (tok, _, _) -> tok) (tokenize_string_with_pos source)
}
