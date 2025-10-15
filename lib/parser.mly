%{
  open Ast

  let get_expr_pos = function
    | EInt (_, p) | EFloat (_, p) | EString (_, p) | EBool (_, p)
    | ENone p | EVar (_, p) | EBinOp (_, _, _, p) | EUnOp (_, _, p)
    | ECall (_, _, p) | EList (_, p) | EDict (_, p) | ETuple (_, p)
    | EIndex (_, _, p) | ESlice (_, _, _, p) | EAttr (_, _, p) | ELambda (_, _, p)
    | EIf (_, _, _, p) | EMatch (_, _, p) | EListComp (_, _, _, _, p)
    | ESome (_, p) | EOk (_, p) | EErr (_, p) -> p
%}

%token <int> INT
%token <float> FLOAT
%token <string> STRING
%token <bool> BOOL
%token <string> IDENT
%token LET DEF CLASS INTERFACE IMPLEMENTS
%token IF ELSE ELIF MATCH CASE FOR WHILE RETURN
%token IMPORT FROM AS ASYNC AWAIT NONE SOME OK ERR SELF SUPER IN
%token PLUS MINUS TIMES DIV MOD
%token EQ NEQ LT GT LTE GTE
%token AND OR NOT
%token ASSIGN ARROW PIPE
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE
%token COMMA COLON SEMICOLON DOT
%token INDENT DEDENT NEWLINE
%token EOF

%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left TIMES DIV MOD
%right NOT
%left DOT
%left LPAREN LBRACKET

%start <Ast.program> program

%%

program:
  | stmts = statement_list EOF { stmts }

statement_list:
  | newline_sep { [] }
  | newline_sep s = statement newline_sep ss = statement_list { s :: ss }

newline_sep:
  | { () }
  | NEWLINE newline_sep { () }

statement:
  | e = expr { SExpr (e, get_expr_pos e) }
  | LET name = IDENT ASSIGN value = expr
      { SLet (name, None, value, get_expr_pos value) }
  | LET name = IDENT COLON ty = type_expr ASSIGN value = expr
      { SLet (name, Some ty, value, get_expr_pos value) }
  | LET pat = pattern ASSIGN value = expr
      { SLetPat (pat, value, get_expr_pos value) }
  | arr = expr LBRACKET idx = expr RBRACKET ASSIGN value = expr
      { SIndexAssign (arr, idx, value, get_expr_pos arr) }
  | name = IDENT ASSIGN value = expr
      { SAssign (name, value, get_expr_pos value) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { SDef (name, [], params, None, body, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { SDef (name, [], params, Some ret, body, { line = 0; column = 0 }) }
  | DEF name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { SDef (name, type_params, params, None, body, { line = 0; column = 0 }) }
  | DEF name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { SDef (name, type_params, params, Some ret, body, { line = 0; column = 0 }) }
  | RETURN
      { SReturn (None, { line = 0; column = 0 }) }
  | RETURN e = expr
      { SReturn (Some e, get_expr_pos e) }
  | IF cond = expr COLON newline_sep INDENT then_body = statement_list DEDENT newline_sep elifs = elif_list else_part = else_opt
      { SIf (cond, then_body, elifs, else_part, get_expr_pos cond) }
  | WHILE cond = expr COLON newline_sep INDENT body = statement_list DEDENT
      { SWhile (cond, body, get_expr_pos cond) }
  | FOR pat = for_pattern IN iter = expr COLON newline_sep INDENT body = statement_list DEDENT
      { SFor (pat, iter, body, get_expr_pos iter) }
  | MATCH e = expr COLON newline_sep INDENT cases = case_list DEDENT
      { SMatch (e, cases, get_expr_pos e) }
  | CLASS name = IDENT COLON newline_sep INDENT members = class_member_list DEDENT
      { SClass (name, None, [], members, { line = 0; column = 0 }) }
  | CLASS name = IDENT LPAREN base = IDENT RPAREN COLON newline_sep INDENT members = class_member_list DEDENT
      { SClass (name, Some base, [], members, { line = 0; column = 0 }) }
  | CLASS name = IDENT IMPLEMENTS interfaces = separated_list(COMMA, IDENT) COLON newline_sep INDENT members = class_member_list DEDENT
      { SClass (name, None, interfaces, members, { line = 0; column = 0 }) }
  | INTERFACE name = IDENT COLON newline_sep INDENT members = interface_member_list DEDENT
      { SInterface (name, members, { line = 0; column = 0 }) }
  | IMPORT modules = separated_list(DOT, IDENT)
      { SImport (modules, { line = 0; column = 0 }) }
  | FROM module_name = IDENT IMPORT names = separated_list(COMMA, IDENT)
      { SFromImport (module_name, names, { line = 0; column = 0 }) }

elif_list:
  | { [] }
  | ELIF cond = expr COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = elif_list
      { (cond, body) :: rest }

else_opt:
  | { None }
  | ELSE COLON newline_sep INDENT body = statement_list DEDENT
      { Some body }

case_list:
  | { [] }
  | CASE p = pattern COLON newline_sep INDENT body = statement_list DEDENT rest = case_list
      { (p, body) :: rest }

class_member_list:
  | { [] }
  | m = class_member NEWLINE* ms = class_member_list { m :: ms }

class_member:
  | name = IDENT COLON ty = type_expr
      { CField (name, ty, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { CMethod (name, [], params, None, body, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { CMethod (name, [], params, Some ret, body, { line = 0; column = 0 }) }

interface_member_list:
  | { [] }
  | m = interface_member NEWLINE* ms = interface_member_list { m :: ms }

interface_member:
  | name = IDENT COLON ty = type_expr
      { IField (name, ty, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr
      { IMethod (name, [], params, Some ret, { line = 0; column = 0 }) }

param:
  | name = IDENT { (name, None) }
  | name = IDENT COLON ty = type_expr { (name, Some ty) }

pattern:
  | n = INT { PInt n }
  | f = FLOAT { PFloat f }
  | s = STRING { PString s }
  | b = BOOL { PBool b }
  | NONE { PNone }
  | name = IDENT { PVar name }
  | LPAREN patterns = separated_list(COMMA, pattern) RPAREN { PTuple patterns }
  | LBRACKET patterns = separated_list(COMMA, pattern) RBRACKET { PList patterns }
  | name = IDENT COLON ty = type_expr { PType (name, ty) }
  | SOME LPAREN p = pattern RPAREN { PSome p }
  | OK LPAREN p = pattern RPAREN { POk p }
  | ERR LPAREN p = pattern RPAREN { PErr p }

for_pattern:
  | name = IDENT { PVar name }
  | LPAREN patterns = separated_list(COMMA, for_pattern) RPAREN { PTuple patterns }

type_expr:
  | name = IDENT LBRACKET ty = type_expr RBRACKET {
      (* 支持 list[T] 语法 *)
      match name with
      | "list" -> TList ty
      | _ -> TVar name  (* 暂时忽略泛型参数 *)
    }
  | IDENT { match $1 with
      | "int" -> TInt
      | "float" -> TFloat
      | "string" -> TString
      | "bool" -> TBool
      | name -> TVar name
    }
  | LBRACKET ty = type_expr RBRACKET { TList ty }
  | LPAREN tys = separated_list(COMMA, type_expr) RPAREN { TTuple tys }
  | ty1 = type_expr PIPE ty2 = type_expr { TUnion [ty1; ty2] }

expr:
  | n = INT { EInt (n, { line = 0; column = 0 }) }
  | f = FLOAT { EFloat (f, { line = 0; column = 0 }) }
  | s = STRING { EString (s, { line = 0; column = 0 }) }
  | b = BOOL { EBool (b, { line = 0; column = 0 }) }
  | NONE { ENone { line = 0; column = 0 } }
  | name = IDENT { EVar (name, { line = 0; column = 0 }) }
  | e1 = expr PLUS e2 = expr { EBinOp (e1, Add, e2, { line = 0; column = 0 }) }
  | e1 = expr MINUS e2 = expr { EBinOp (e1, Sub, e2, { line = 0; column = 0 }) }
  | e1 = expr TIMES e2 = expr { EBinOp (e1, Mul, e2, { line = 0; column = 0 }) }
  | e1 = expr DIV e2 = expr { EBinOp (e1, Div, e2, { line = 0; column = 0 }) }
  | e1 = expr MOD e2 = expr { EBinOp (e1, Mod, e2, { line = 0; column = 0 }) }
  | e1 = expr EQ e2 = expr { EBinOp (e1, Eq, e2, { line = 0; column = 0 }) }
  | e1 = expr NEQ e2 = expr { EBinOp (e1, Neq, e2, { line = 0; column = 0 }) }
  | e1 = expr LT e2 = expr { EBinOp (e1, Lt, e2, { line = 0; column = 0 }) }
  | e1 = expr GT e2 = expr { EBinOp (e1, Gt, e2, { line = 0; column = 0 }) }
  | e1 = expr LTE e2 = expr { EBinOp (e1, Lte, e2, { line = 0; column = 0 }) }
  | e1 = expr GTE e2 = expr { EBinOp (e1, Gte, e2, { line = 0; column = 0 }) }
  | e1 = expr AND e2 = expr { EBinOp (e1, And, e2, { line = 0; column = 0 }) }
  | e1 = expr OR e2 = expr { EBinOp (e1, Or, e2, { line = 0; column = 0 }) }
  | NOT e = expr { EUnOp (Not, e, { line = 0; column = 0 }) }
  | MINUS e = expr { EUnOp (Neg, e, { line = 0; column = 0 }) }
  | func = expr LPAREN args = separated_list(COMMA, expr) RPAREN
      { ECall (func, args, get_expr_pos func) }
  | obj = expr DOT attr = IDENT
      { EAttr (obj, attr, get_expr_pos obj) }
  | arr = expr LBRACKET idx = expr RBRACKET
      { EIndex (arr, idx, get_expr_pos arr) }
  | arr = expr LBRACKET start = slice_start COLON end_opt = slice_end RBRACKET
      { ESlice (arr, start, end_opt, get_expr_pos arr) }
  | LBRACKET elems = separated_list(COMMA, expr) RBRACKET
      { EList (elems, { line = 0; column = 0 }) }
  | LBRACE pairs = separated_list(COMMA, dict_pair) RBRACE
      { EDict (pairs, { line = 0; column = 0 }) }
  | LPAREN elems = separated_list(COMMA, expr) RPAREN
      { match elems with
        | [] -> ETuple ([], { line = 0; column = 0 })
        | [e] -> e
        | _ -> ETuple (elems, { line = 0; column = 0 })
      }
  | IF cond = expr COLON then_expr = expr ELSE COLON else_expr = expr
      { EIf (cond, then_expr, Some else_expr, get_expr_pos cond) }
  | LBRACKET elem = expr FOR var = IDENT IN iter = expr RBRACKET
      { EListComp (elem, var, iter, None, { line = 0; column = 0 }) }
  | LBRACKET elem = expr FOR var = IDENT IN iter = expr IF cond = expr RBRACKET
      { EListComp (elem, var, iter, Some cond, { line = 0; column = 0 }) }
  | SOME LPAREN e = expr RPAREN
      { ESome (e, { line = 0; column = 0 }) }
  | OK LPAREN e = expr RPAREN
      { EOk (e, { line = 0; column = 0 }) }
  | ERR LPAREN e = expr RPAREN
      { EErr (e, { line = 0; column = 0 }) }

dict_pair:
  | key = expr COLON value = expr { (key, value) }

slice_start:
  | { None }
  | e = expr { Some e }

slice_end:
  | { None }
  | e = expr { Some e }
