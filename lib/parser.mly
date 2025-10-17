%{
  open Ast

  let get_expr_pos = function
    | EInt (_, p) | EFloat (_, p) | EString (_, p) | EBool (_, p)
    | EVar (_, p) | EBinOp (_, _, _, p) | EUnOp (_, _, p)
    | ECall (_, _, p) | EList (_, p) | EDict (_, p) | ETuple (_, p)
    | EIndex (_, _, p) | ESlice (_, _, _, p) | EAttr (_, _, p) | ELambda (_, _, p)
    | EIf (_, _, _, p) | EMatch (_, _, p) | EListComp (_, _, _, _, p)
    | EEnumVariant (_, _, _, p) | EStructLiteral (_, _, p) | EStructAccess (_, _, p)
    | ETernary (_, _, _, p) | ETry (_, p) -> p

  (* 从 Lexing.position 创建 AST position *)
  (* VSCode 使用 0-based 行号，所以减 1 *)
  let make_position (pos : Lexing.position) =
    { line = pos.pos_lnum - 1; column = pos.pos_cnum - pos.pos_bol }
%}

%token <int> INT
%token <float> FLOAT
%token <string> STRING
%token <bool> BOOL
%token <string> IDENT
%token LET DEF STRUCT INTERFACE IMPLEMENTS IMPL TYPE CONST ENUM
%token IF ELSE ELIF MATCH CASE FOR WHILE RETURN
%token IMPORT FROM AS OF ASYNC AWAIT SELF SUPER IN
%token SOME NONE OK ERR OPTION RESULT
%token PLUS MINUS TIMES DIV MOD
%token EQ NEQ LT GT LTE GTE
%token AND OR NOT
%token ASSIGN ARROW PIPE UNDERSCORE
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE
%token COMMA COLON SEMICOLON DOT QUESTION CONS
%token INDENT DEDENT NEWLINE
%token EOF

%right QUESTION COLON  (* 三元运算符优先级最低 *)
%right CONS  (* :: 右结合,用于列表模式匹配 *)
%left PIPE
%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left TIMES DIV MOD
%right NOT
%left AS
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
      { SLet {
          let_name = name;
          let_name_pos = make_position $startpos(name);
          let_type = None;
          let_value = value;
          let_pos = make_position $startpos;
        } }
  | LET name = IDENT COLON ty = type_expr ASSIGN value = expr
      { SLet {
          let_name = name;
          let_name_pos = make_position $startpos(name);
          let_type = Some ty;
          let_value = value;
          let_pos = make_position $startpos;
        } }
  | LET pat = pattern ASSIGN value = expr
      { SLetPat (pat, value, make_position $startpos) }
  | arr = expr LBRACKET idx = expr RBRACKET ASSIGN value = expr
      { SIndexAssign (arr, idx, value, get_expr_pos arr) }
  | name = IDENT ASSIGN value = expr
      { SAssign (name, value, make_position $startpos(name)) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { SDef {
          def_name = name;
          def_name_pos = make_position $startpos(name);
          def_type_params = [];
          def_params = params;
          def_return_type = None;
          def_body = body;
          def_pos = make_position $startpos;
        } }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { SDef {
          def_name = name;
          def_name_pos = make_position $startpos(name);
          def_type_params = [];
          def_params = params;
          def_return_type = Some ret;
          def_body = body;
          def_pos = make_position $startpos;
        } }
  | DEF name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { SDef {
          def_name = name;
          def_name_pos = make_position $startpos(name);
          def_type_params = type_params;
          def_params = params;
          def_return_type = None;
          def_body = body;
          def_pos = make_position $startpos;
        } }
  | DEF name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { SDef {
          def_name = name;
          def_name_pos = make_position $startpos(name);
          def_type_params = type_params;
          def_params = params;
          def_return_type = Some ret;
          def_body = body;
          def_pos = make_position $startpos;
        } }
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
  | MATCH e = expr COLON newline_sep INDENT cases = expr_case_list DEDENT
      { SExpr (EMatch (e, cases, get_expr_pos e), get_expr_pos e) }
  | MATCH TYPE OF e = expr COLON newline_sep INDENT cases = type_case_list_as_expr DEDENT
      { SExpr (EMatch (e, cases, get_expr_pos e), get_expr_pos e) }
  | INTERFACE name = IDENT COLON newline_sep INDENT members = interface_member_list DEDENT
      { SInterface {
          interface_name = name;
          interface_name_pos = make_position $startpos(name);
          interface_type_params = [];
          interface_members = members;
          interface_pos = make_position $startpos;
        } }
  | INTERFACE name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET COLON newline_sep INDENT members = interface_member_list DEDENT
      { SInterface {
          interface_name = name;
          interface_name_pos = make_position $startpos(name);
          interface_type_params = type_params;
          interface_members = members;
          interface_pos = make_position $startpos;
        } }
  | IMPL interface_name = IDENT FOR target = type_expr COLON newline_sep INDENT members = impl_member_list DEDENT
      { SImpl ({ impl_interface = Some interface_name;
                 impl_type_params = [];
                 impl_target = target;
                 impl_members = members;
                 impl_pos = { line = 0; column = 0 } }, { line = 0; column = 0 }) }
  | IMPL interface_name = IDENT LBRACKET _type_params = separated_list(COMMA, type_expr) RBRACKET FOR target = type_expr COLON newline_sep INDENT members = impl_member_list DEDENT
      { SImpl ({ impl_interface = Some interface_name;
                 impl_type_params = [];  (* 暂时忽略类型参数,后续实现 *)
                 impl_target = target;
                 impl_members = members;
                 impl_pos = { line = 0; column = 0 } }, { line = 0; column = 0 }) }
  | STRUCT name = IDENT COLON newline_sep INDENT members = struct_member_list DEDENT
      { SStruct {
          struct_name = name;
          struct_name_pos = make_position $startpos(name);
          struct_type_params = [];
          struct_members = members;
          struct_pos = make_position $startpos;
        } }
  | STRUCT name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET COLON newline_sep INDENT members = struct_member_list DEDENT
      { SStruct {
          struct_name = name;
          struct_name_pos = make_position $startpos(name);
          struct_type_params = type_params;
          struct_members = members;
          struct_pos = make_position $startpos;
        } }
  | ENUM name = IDENT COLON newline_sep INDENT variants = enum_variant_list DEDENT
      { SEnum {
          enum_name = name;
          enum_name_pos = make_position $startpos(name);
          enum_type_params = [];
          enum_variants = variants;
          enum_pos = make_position $startpos;
        } }
  | ENUM name = IDENT LBRACKET type_params = separated_list(COMMA, IDENT) RBRACKET COLON newline_sep INDENT variants = enum_variant_list DEDENT
      { SEnum {
          enum_name = name;
          enum_name_pos = make_position $startpos(name);
          enum_type_params = type_params;
          enum_variants = variants;
          enum_pos = make_position $startpos;
        } }
  | obj = expr DOT field = IDENT ASSIGN value = expr
      { SFieldAssign (obj, field, value, get_expr_pos obj) }
  | IMPORT modules = separated_list(DOT, IDENT)
      { SImport (modules, None, { line = 0; column = 0 }) }
  | IMPORT modules = separated_list(DOT, IDENT) AS alias = IDENT
      { SImport (modules, Some alias, { line = 0; column = 0 }) }
  | FROM module_name = IDENT IMPORT names = separated_list(COMMA, import_name)
      { SFromImport (module_name, names, { line = 0; column = 0 }) }

import_name:
  | name = IDENT { (name, None) }
  | name = IDENT AS alias = IDENT { (name, Some alias) }

elif_list:
  | { [] }
  | ELIF cond = expr COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = elif_list
      { (cond, body) :: rest }

else_opt:
  | { None }
  | ELSE COLON newline_sep INDENT body = statement_list DEDENT
      { Some body }

type_case_list_as_expr:
  | { [] }
  | ty = type_expr COLON newline_sep body = expr newline_sep rest = type_case_list_as_expr
      { (PType ("_matched_value", ty), None, MExpr body) :: rest }
  | ty = type_expr COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = type_case_list_as_expr
      { (PType ("_matched_value", ty), None, MStmts body) :: rest }
  | UNDERSCORE COLON newline_sep body = expr newline_sep rest = type_case_list_as_expr
      { (PWildcard, None, MExpr body) :: rest }
  | UNDERSCORE COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = type_case_list_as_expr
      { (PWildcard, None, MStmts body) :: rest }

expr_case_list:
  | { [] }
  | CASE p = match_pattern IF guard = expr COLON newline_sep body = expr newline_sep rest = expr_case_list
      { (p, Some guard, MExpr body) :: rest }
  | CASE p = match_pattern COLON newline_sep body = expr newline_sep rest = expr_case_list
      { (p, None, MExpr body) :: rest }
  | CASE p = match_pattern IF guard = expr COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = expr_case_list
      { (p, Some guard, MStmts body) :: rest }
  | CASE p = match_pattern COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = expr_case_list
      { (p, None, MStmts body) :: rest }
  | p = match_pattern IF guard = expr COLON newline_sep body = expr newline_sep rest = expr_case_list
      { (p, Some guard, MExpr body) :: rest }
  | p = match_pattern COLON newline_sep body = expr newline_sep rest = expr_case_list
      { (p, None, MExpr body) :: rest }
  | p = match_pattern IF guard = expr COLON newline_sep name = IDENT ASSIGN value = expr newline_sep rest = expr_case_list
      { (p, Some guard, MStmts [SAssign (name, value, { line = 0; column = 0 })]) :: rest }
  | p = match_pattern COLON newline_sep name = IDENT ASSIGN value = expr newline_sep rest = expr_case_list
      { (p, None, MStmts [SAssign (name, value, { line = 0; column = 0 })]) :: rest }
  | p = match_pattern IF guard = expr COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = expr_case_list
      { (p, Some guard, MStmts body) :: rest }
  | p = match_pattern COLON newline_sep INDENT body = statement_list DEDENT newline_sep rest = expr_case_list
      { (p, None, MStmts body) :: rest }

interface_member_list:
  | { [] }
  | m = interface_member NEWLINE* ms = interface_member_list { m :: ms }

interface_member:
  | name = IDENT COLON ty = type_expr
      { IField (name, ty, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr
      { IMethod (name, [], params, Some ret, None, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { IMethod (name, [], params, Some ret, Some body, { line = 0; column = 0 }) }
  | TYPE assoc_name = IDENT
      { IAssocType (assoc_name, None, { line = 0; column = 0 }) }
  | TYPE assoc_name = IDENT ASSIGN assoc_ty = type_expr
      { IAssocType (assoc_name, Some assoc_ty, { line = 0; column = 0 }) }
  | CONST const_name = IDENT COLON const_ty = type_expr ASSIGN const_val = expr
      { IAssocConst (const_name, const_ty, const_val, { line = 0; column = 0 }) }

impl_member_list:
  | { [] }
  | m = impl_member NEWLINE* ms = impl_member_list { m :: ms }

impl_member:
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { ImplMethod (name, [], params, None, body, { line = 0; column = 0 }) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { ImplMethod (name, [], params, Some ret, body, { line = 0; column = 0 }) }
  | TYPE assoc_name = IDENT ASSIGN assoc_ty = type_expr
      { ImplAssocType (assoc_name, assoc_ty, { line = 0; column = 0 }) }
  | CONST const_name = IDENT ASSIGN const_val = expr
      { ImplAssocConst (const_name, const_val, { line = 0; column = 0 }) }

struct_member_list:
  | { [] }
  | m = struct_member NEWLINE* ms = struct_member_list { m :: ms }

struct_member:
  | name = IDENT COLON ty = type_expr
      { SField { field_name = Some name; field_type = ty; field_pos = make_position $startpos } }
  | ty = type_expr
      { SField { field_name = None; field_type = ty; field_pos = make_position $startpos } }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN COLON newline_sep INDENT body = statement_list DEDENT
      { SMethod (name, [], params, None, body, make_position $startpos) }
  | DEF name = IDENT LPAREN params = separated_list(COMMA, param) RPAREN ARROW ret = type_expr COLON newline_sep INDENT body = statement_list DEDENT
      { SMethod (name, [], params, Some ret, body, make_position $startpos) }

enum_variant_list:
  | { [] }
  | v = enum_variant NEWLINE* vs = enum_variant_list { v :: vs }

variant_name:
  | name = IDENT { name }
  | SOME { "Some" }
  | NONE { "None" }
  | OK { "Ok" }
  | ERR { "Err" }
  | OPTION { "Option" }
  | RESULT { "Result" }

enum_variant:
  | name = variant_name
      { VSimple (name, { line = 0; column = 0 }) }
  | name = variant_name LPAREN types = separated_list(COMMA, type_expr) RPAREN
      { VTuple (name, types, { line = 0; column = 0 }) }

param:
  | name = IDENT { (name, None, None) }
  | name = IDENT COLON ty = type_expr { (name, Some ty, None) }
  | name = IDENT COLON ty = type_expr ASSIGN default_value = expr { (name, Some ty, Some default_value) }
  | SELF { ("self", None, None) }
  | SELF COLON ty = type_expr { ("self", Some ty, None) }

pattern:
  | n = INT { PInt n }
  | f = FLOAT { PFloat f }
  | s = STRING { PString s }
  | b = BOOL { PBool b }
  | UNDERSCORE { PWildcard }
  | LPAREN patterns = separated_list(COMMA, pattern) RPAREN
      { match patterns with
        | [p] -> p  (* 单个模式，不是元组 *)
        | _ -> PTuple patterns
      }
  | LBRACKET RBRACKET { PList [] }  (* 空列表 *)
  | LBRACKET patterns = separated_list(COMMA, pattern) RBRACKET { PList patterns }  (* 列表模式: [x, y, z] *)
  | p1 = pattern CONS p2 = pattern { PCons (p1, p2) }  (* Cons模式: head :: tail *)
  | enum_name = IDENT DOT variant_name = IDENT LPAREN patterns = separated_list(COMMA, pattern) RPAREN
      { PEnumVariant (enum_name, variant_name, patterns) }
  | enum_name = IDENT DOT variant_name = IDENT
      { PEnumVariant (enum_name, variant_name, []) }
  | variant_name = IDENT LPAREN patterns = separated_list(COMMA, pattern) RPAREN
      { PEnumVariant ("", variant_name, patterns) }
  | name = IDENT
      { (* None 单独出现时作为枚举变体，其他作为变量 *)
        if name = "None" then PEnumVariant ("", "None", [])
        else PVar name
      }

match_pattern:
  | n = INT { PInt n }
  | f = FLOAT { PFloat f }
  | s = STRING { PString s }
  | b = BOOL { PBool b }
  | UNDERSCORE { PWildcard }
  | LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { match patterns with
        | [p] -> p
        | _ -> PTuple patterns
      }
  | LBRACKET RBRACKET { PList [] }  (* 空列表 *)
  | LBRACKET patterns = separated_list(COMMA, match_pattern) RBRACKET { PList patterns }  (* 列表模式: [x, y, z] *)
  | p1 = match_pattern CONS p2 = match_pattern { PCons (p1, p2) }  (* Cons模式: head :: tail *)
  | OPTION DOT SOME LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Option", "Some", patterns) }
  | OPTION DOT NONE
      { PEnumVariant ("Option", "None", []) }
  | RESULT DOT OK LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Result", "Ok", patterns) }
  | RESULT DOT ERR LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Result", "Err", patterns) }
  | enum_name = IDENT DOT variant_name = IDENT LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant (enum_name, variant_name, patterns) }
  | enum_name = IDENT DOT variant_name = IDENT
      { PEnumVariant (enum_name, variant_name, []) }
  | SOME LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Option", "Some", patterns) }
  | NONE
      { PEnumVariant ("Option", "None", []) }
  | OK LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Result", "Ok", patterns) }
  | ERR LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("Result", "Err", patterns) }
  | variant_name = IDENT LPAREN patterns = separated_list(COMMA, match_pattern) RPAREN
      { PEnumVariant ("", variant_name, patterns) }
  | name = IDENT
      { PVar name }

for_pattern:
  | name = IDENT { PVar name }
  | LPAREN patterns = separated_list(COMMA, for_pattern) RPAREN { PTuple patterns }

type_expr:
  | RESULT LBRACKET ty1 = type_expr COMMA ty2 = type_expr RBRACKET {
      (* 支持 Result[T, E] 语法 *)
      TResult (ty1, ty2)
    }
  | name = IDENT LBRACKET ty = type_expr RBRACKET {
      (* 支持 list[T] 和 Option[T] 语法 *)
      match name with
      | "list" -> TList ty
      | "Option" -> TOption ty
      | _ -> TVar name  (* 暂时忽略泛型参数 *)
    }
  | IDENT { match $1 with
      | "int" -> TInt
      | "float" -> TFloat
      | "str" -> TStr
      | "bytes" -> TBytes
      | "bool" -> TBool
      | name -> TVar name
    }
  | LBRACKET ty = type_expr RBRACKET { TList ty }
  | LPAREN tys = separated_list(COMMA, type_expr) RPAREN { TTuple tys }
  | ty1 = type_expr PIPE ty2 = type_expr {
      (* 扁平化嵌套的TUnion: int | string | bool -> TUnion [int; string; bool] *)
      let flatten_union t =
        match t with
        | TUnion ts -> ts
        | _ -> [t]
      in
      TUnion (flatten_union ty1 @ flatten_union ty2)
    }

expr:
  | n = INT { EInt (n, make_position $startpos) }
  | f = FLOAT { EFloat (f, make_position $startpos) }
  | s = STRING { EString (s, make_position $startpos) }
  | b = BOOL { EBool (b, make_position $startpos) }
  | name = IDENT { EVar (name, make_position $startpos) }
  | SELF { EVar ("self", make_position $startpos) }
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
  | OPTION DOT SOME LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Option", "Some", args, { line = 0; column = 0 }) }
  | OPTION DOT NONE
      { EEnumVariant ("Option", "None", [], { line = 0; column = 0 }) }
  | RESULT DOT OK LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Result", "Ok", args, { line = 0; column = 0 }) }
  | RESULT DOT ERR LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Result", "Err", args, { line = 0; column = 0 }) }
  | SOME LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Option", "Some", args, { line = 0; column = 0 }) }
  | NONE
      { EEnumVariant ("Option", "None", [], { line = 0; column = 0 }) }
  | OK LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Result", "Ok", args, { line = 0; column = 0 }) }
  | ERR LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant ("Result", "Err", args, { line = 0; column = 0 }) }
  | enum_name = IDENT DOT variant_name = IDENT LPAREN args = separated_list(COMMA, expr) RPAREN
      { EEnumVariant (enum_name, variant_name, args, { line = 0; column = 0 }) }
  | enum_name = IDENT DOT variant_name = IDENT
      { EEnumVariant (enum_name, variant_name, [], { line = 0; column = 0 }) }
  | struct_name = IDENT LBRACE fields = separated_list(COMMA, struct_field_init) RBRACE
      { EStructLiteral (struct_name, fields, { line = 0; column = 0 }) }
  | MATCH e = expr COLON newline_sep INDENT cases = expr_case_list DEDENT
      { EMatch (e, cases, get_expr_pos e) }
  | MATCH TYPE OF e = expr COLON newline_sep INDENT cases = type_case_list_as_expr DEDENT
      { EMatch (e, cases, get_expr_pos e) }
  | cond = expr QUESTION true_expr = expr COLON false_expr = expr
      { ETernary (cond, true_expr, false_expr, get_expr_pos cond) }
  | e = expr QUESTION
      { ETry (e, get_expr_pos e) }

dict_pair:
  | key = expr COLON value = expr { (key, value) }

struct_field_init:
  | name = IDENT COLON value = expr { (name, value) }

slice_start:
  | { None }
  | e = expr { Some e }

slice_end:
  | { None }
  | e = expr { Some e }
