open Dream_lib

let tok_to_string = function
  | Parser.INT n -> Printf.sprintf "INT(%d)" n
  | Parser.FLOAT f -> Printf.sprintf "FLOAT(%f)" f
  | Parser.STRING s -> Printf.sprintf "STRING(\"%s\")" s
  | Parser.BOOL b -> Printf.sprintf "BOOL(%b)" b
  | Parser.IDENT s -> Printf.sprintf "IDENT(%s)" s
  | Parser.LET -> "LET"
  | Parser.DEF -> "DEF"
  | Parser.INTERFACE -> "INTERFACE"
  | Parser.IMPLEMENTS -> "IMPLEMENTS"
  | Parser.IMPL -> "IMPL"
  | Parser.TYPE -> "TYPE"
  | Parser.CONST -> "CONST"
  | Parser.ENUM -> "ENUM"
  | Parser.STRUCT -> "STRUCT"
  | Parser.IF -> "IF"
  | Parser.ELSE -> "ELSE"
  | Parser.ELIF -> "ELIF"
  | Parser.FOR -> "FOR"
  | Parser.WHILE -> "WHILE"
  | Parser.RETURN -> "RETURN"
  | Parser.IN -> "IN"
  | Parser.COLON -> "COLON"
  | Parser.NEWLINE -> "NEWLINE"
  | Parser.INDENT -> "INDENT"
  | Parser.DEDENT -> "DEDENT"
  | Parser.EOF -> "EOF"
  | Parser.LPAREN -> "LPAREN"
  | Parser.RPAREN -> "RPAREN"
  | Parser.LBRACKET -> "LBRACKET"
  | Parser.RBRACKET -> "RBRACKET"
  | Parser.LBRACE -> "LBRACE"
  | Parser.RBRACE -> "RBRACE"
  | Parser.ASSIGN -> "ASSIGN"
  | Parser.LT -> "LT"
  | Parser.GT -> "GT"
  | Parser.LTE -> "LTE"
  | Parser.GTE -> "GTE"
  | Parser.EQ -> "EQ"
  | Parser.NEQ -> "NEQ"
  | Parser.PLUS -> "PLUS"
  | Parser.MINUS -> "MINUS"
  | Parser.TIMES -> "TIMES"
  | Parser.DIV -> "DIV"
  | Parser.MOD -> "MOD"
  | Parser.AND -> "AND"
  | Parser.OR -> "OR"
  | Parser.NOT -> "NOT"
  | Parser.COMMA -> "COMMA"
  | Parser.DOT -> "DOT"
  | Parser.ARROW -> "ARROW"
  | Parser.PIPE -> "PIPE"
  | Parser.MATCH -> "MATCH"
  | Parser.CASE -> "CASE"
  | Parser.IMPORT -> "IMPORT"
  | Parser.FROM -> "FROM"
  | Parser.AS -> "AS"
  | Parser.OF -> "OF"
  | Parser.ASYNC -> "ASYNC"
  | Parser.AWAIT -> "AWAIT"
  | Parser.SELF -> "SELF"
  | Parser.SUPER -> "SUPER"
  | Parser.SEMICOLON -> "SEMICOLON"
  | Parser.UNDERSCORE -> "UNDERSCORE"
  | Parser.SOME -> "SOME"
  | Parser.NONE -> "NONE"
  | Parser.OK -> "OK"
  | Parser.ERR -> "ERR"
  | Parser.OPTION -> "OPTION"
  | Parser.RESULT -> "RESULT"
  | Parser.QUESTION -> "QUESTION"

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.printf "Usage: %s <file.dm>\n" Sys.argv.(0);
    exit 1
  end;

  let ic = open_in Sys.argv.(1) in
  let source = really_input_string ic (in_channel_length ic) in
  close_in ic;

  let tokens = Lexer.tokenize_string source in

  Printf.printf "Token sequence:\n";
  List.iteri (fun i tok ->
    Printf.printf "%3d: %s\n" i (tok_to_string tok)
  ) tokens
