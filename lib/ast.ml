type position = {
  line: int;
  column: int;
}

type token =
  | INT of int
  | FLOAT of float
  | STRING of string
  | BOOL of bool
  | IDENT of string
  | LET
  | DEF
  | CLASS
  | INTERFACE
  | IMPLEMENTS
  | IF
  | ELSE
  | ELIF
  | MATCH
  | CASE
  | FOR
  | WHILE
  | RETURN
  | IMPORT
  | FROM
  | AS
  | ASYNC
  | AWAIT
  | NONE
  | SOME
  | OK
  | ERR
  | SELF
  | SUPER
  | IN
  | PLUS
  | MINUS
  | TIMES
  | DIV
  | MOD
  | EQ
  | NEQ
  | LT
  | GT
  | LTE
  | GTE
  | AND
  | OR
  | NOT
  | ASSIGN
  | ARROW
  | PIPE
  | LPAREN
  | RPAREN
  | LBRACKET
  | RBRACKET
  | LBRACE
  | RBRACE
  | COMMA
  | COLON
  | SEMICOLON
  | DOT
  | INDENT
  | DEDENT
  | NEWLINE
  | EOF

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Eq
  | Neq
  | Lt
  | Gt
  | Lte
  | Gte
  | And
  | Or

type unop =
  | Neg
  | Not

type type_expr =
  | TInt
  | TFloat
  | TString
  | TBool
  | TNone
  | TVar of string
  | TList of type_expr
  | TDict of type_expr * type_expr
  | TTuple of type_expr list
  | TFunc of type_expr list * type_expr
  | TUnion of type_expr list
  | TGeneric of string * type_expr
  | TOption of type_expr
  | TResult of type_expr * type_expr

type expr =
  | EInt of int * position
  | EFloat of float * position
  | EString of string * position
  | EBool of bool * position
  | ENone of position
  | EVar of string * position
  | EBinOp of expr * binop * expr * position
  | EUnOp of unop * expr * position
  | ECall of expr * expr list * position
  | EList of expr list * position
  | EDict of (expr * expr) list * position
  | ETuple of expr list * position
  | EIndex of expr * expr * position
  | ESlice of expr * expr option * expr option * position
  | EAttr of expr * string * position
  | ELambda of (string * type_expr option) list * expr * position
  | EIf of expr * expr * expr option * position
  | EMatch of expr * (pattern * expr) list * position
  | EListComp of expr * string * expr * expr option * position
  | ESome of expr * position
  | EOk of expr * position
  | EErr of expr * position

and pattern =
  | PInt of int
  | PFloat of float
  | PString of string
  | PBool of bool
  | PNone
  | PVar of string
  | PTuple of pattern list
  | PList of pattern list
  | PType of string * type_expr
  | PWildcard
  | PSome of pattern
  | POk of pattern
  | PErr of pattern

type statement =
  | SExpr of expr * position
  | SLet of string * type_expr option * expr * position
  | SLetPat of pattern * expr * position  (* 元组解包: let (a,b) = tuple *)
  | SDef of string * string list * (string * type_expr option) list * type_expr option * statement list * position
  | SReturn of expr option * position
  | SIf of expr * statement list * (expr * statement list) list * statement list option * position
  | SWhile of expr * statement list * position
  | SFor of pattern * expr * statement list * position
  | SMatch of expr * (pattern * statement list) list * position
  | SClass of string * string option * string list * class_member list * position
  | SInterface of string * interface_member list * position
  | SImport of string list * position
  | SFromImport of string * string list * position
  | SAssign of string * expr * position
  | SIndexAssign of expr * expr * expr * position

and class_member =
  | CField of string * type_expr * position
  | CMethod of string * string list * (string * type_expr option) list * type_expr option * statement list * position

and interface_member =
  | IField of string * type_expr * position
  | IMethod of string * string list * (string * type_expr option) list * type_expr option * position

type program = statement list
