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
  | STRUCT
  | INTERFACE
  | IMPLEMENTS
  | IMPL
  | TYPE
  | CONST
  | ENUM
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
  | SELF
  | SUPER
  | IN
  | SOME
  | NONE
  | OK
  | ERR
  | OPTION
  | RESULT
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
  | UNDERSCORE
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
  | TEnum of string * type_expr list
  | TStruct of string * type_expr list

type expr =
  | EInt of int * position
  | EFloat of float * position
  | EString of string * position
  | EBool of bool * position
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
  | EMatch of expr * (pattern * expr option * expr) list * position  (* pattern * guard * body *)
  | EListComp of expr * string * expr * expr option * position
  | EEnumVariant of string * string * expr list * position
  | EStructLiteral of string * (string * expr) list * position  (* 结构体字面量 *)
  | EStructAccess of expr * string * position  (* 字段访问，与 EAttr 类似但专门用于结构体 *)

and pattern =
  | PInt of int
  | PFloat of float
  | PString of string
  | PBool of bool
  | PVar of string
  | PTuple of pattern list
  | PList of pattern list
  | PType of string * type_expr
  | PWildcard
  | PEnumVariant of string * string * pattern list

(* 类成员 *)
and class_member =
  | CField of string * type_expr * position
  | CMethod of string * string list * (string * type_expr option) list * type_expr option * statement list * position

(* 接口成员 *)
and interface_member =
  | IField of string * type_expr * position
  | IMethod of string * string list * (string * type_expr option) list * type_expr option * statement list option * position  (* 添加可选的默认实现 *)
  | IAssocType of string * type_expr option * position  (* 关联类型: type Name = T *)
  | IAssocConst of string * type_expr * expr * position  (* 关联常量: const NAME: type = value *)

(* 枚举变体 *)
and enum_variant =
  | VSimple of string * position
  | VTuple of string * type_expr list * position

(* impl 成员 *)
and impl_member =
  | ImplMethod of string * string list * (string * type_expr option) list * type_expr option * statement list * position
  | ImplAssocType of string * type_expr * position  (* 关联类型实现 *)
  | ImplAssocConst of string * expr * position  (* 关联常量实现 *)

(* impl 块：为类型实现接口或定义方法 *)
and impl_block = {
  impl_interface: string option;  (* 接口名(可选,None表示只是为类型定义方法) *)
  impl_type_params: string list;  (* 类型参数 *)
  impl_target: type_expr;  (* 目标类型 *)
  impl_members: impl_member list;  (* 实现的成员 *)
  impl_pos: position;
}

(* 结构体字段定义 *)
and struct_field = {
  field_name: string;
  field_type: type_expr;
  field_pos: position;
}

(* 结构体成员: 字段或方法 *)
and struct_member =
  | SField of struct_field
  | SMethod of string * string list * (string * type_expr option) list * type_expr option * statement list * position

(* 语句 *)
and statement =
  | SExpr of expr * position
  | SLet of string * type_expr option * expr * position
  | SLetPat of pattern * expr * position  (* 元组解包: let (a,b) = tuple *)
  | SDef of string * string list * (string * type_expr option) list * type_expr option * statement list * position
  | SReturn of expr option * position
  | SIf of expr * statement list * (expr * statement list) list * statement list option * position
  | SWhile of expr * statement list * position
  | SFor of pattern * expr * statement list * position
  | SMatch of expr * (pattern * expr option * statement list) list * position  (* pattern * guard * body *)
  | SClass of string * string option * string list * class_member list * position
  | SStruct of string * string list * struct_member list * position  (* 结构体定义,支持字段和方法 *)
  | SInterface of string * string list * interface_member list * position  (* 添加类型参数支持 *)
  | SImport of string list * position
  | SFromImport of string * string list * position
  | SAssign of string * expr * position
  | SIndexAssign of expr * expr * expr * position
  | SFieldAssign of expr * string * expr * position  (* 字段赋值: obj.field = value *)
  | SEnum of string * string list * enum_variant list * position
  | SImpl of impl_block * position  (* impl 块 *)

type program = statement list
