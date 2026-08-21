type position = {
  line: int;
  column: int;
}

type token =
  | INT of int
  | FLOAT of float
  | STRING of string
  | RUNE of int   (* 32-bit Unicode codepoint *)
  | BYTE of int   (* 8-bit byte *)
  | BOOL of bool
  | IDENT of string
  | LET
  | LAMBDA
  | DEF
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
  | SWITCH
  | MATCH
  | CASE
  | DEFAULT
  | FOR
  | WHILE
  | BREAK
  | RETURN
  | IMPORT
  | FROM
  | AS
  | OF
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
  | FLOORDIV
  | MOD
  | POW
  | AMP
  | CARET
  | TILDE
  | SHL
  | SHR
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
  | FIELD_ASSIGN of string * string
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
  | QUESTION  (* ? for error propagation and ternary operator *)
  | CONS  (* :: for list pattern matching *)
  | INDENT
  | DEDENT
  | NEWLINE
  | EOF

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | FloorDiv
  | Mod
  | Pow
  | BitAnd
  | BitOr
  | BitXor
  | Shl
  | Shr
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
  | Pos
  | Invert
  | Not

type type_expr =
  | TInt
  | TFloat
  | TStr
  | TRune   (* 32-bit Unicode codepoint, like Go's rune *)
  | TByte   (* 8-bit byte *)
  | TBytes  (* byte array *)
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
  | TSelf  (* 接口/impl 方法中的自身类型，解析为实现该接口的具体类型 *)

(* Match 分支体：可以是单个表达式或语句块 *)
type match_body =
  | MExpr of expr  (* 单行表达式 *)
  | MStmts of statement list  (* 多行语句块 *)

and expr =
  | EInt of int * position
  | EFloat of float * position
  | EString of string * position
  | ERune of int * position  (* 32-bit Unicode codepoint *)
  | EByte of int * position   (* 8-bit byte *)
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
  | EMatch of expr * (pattern * expr option * match_body) list * position  (* pattern * guard * body *)
  | EListComp of expr * string * expr * expr option * position
  | EEnumVariant of string * string * expr list * position
  | EStructLiteral of string * (string * expr) list * position  (* 结构体字面量 *)
  | EStructAccess of expr * string * position  (* 字段访问，与 EAttr 类似但专门用于结构体 *)
  | ETernary of expr * expr * expr * position  (* 三元运算符: condition ? true_expr : false_expr *)
  | ETry of expr * position  (* 错误传播: expr? *)
  | ETypeOf of expr * position  (* type of 表达式: 获取表达式的类型 *)

and pattern =
  | PInt of int
  | PFloat of float
  | PString of string
  | PRune of int  (* 32-bit Unicode codepoint *)
  | PByte of int   (* 8-bit byte *)
  | PBool of bool
  | PVar of string
  | PTuple of pattern list
  | PList of pattern list  (* [x, y, z] - exact length match *)
  | PCons of pattern * pattern  (* head :: tail - cons pattern *)
  | PType of string * type_expr
  | PWildcard
  | PEnumVariant of string * string * pattern list
  | PStruct of string * (string * pattern) list  (* StructName{field1: pattern1, field2: pattern2} *)

(* 接口成员 *)
and interface_member =
  | IField of string * type_expr * position
  | IMethod of string * string list * (string * type_expr option * expr option) list * type_expr option * statement list option * position  (* 添加可选的默认实现 *)
  | IAssocType of string * type_expr option * position  (* 关联类型: type Name = T *)
  | IAssocConst of string * type_expr * expr * position  (* 关联常量: const NAME: type = value *)

(* 枚举变体 *)
and enum_variant =
  | VSimple of string * position
  | VTuple of string * type_expr list * position

(* impl 成员 *)
and impl_member =
  | ImplMethod of string * string list * (string * type_expr option * expr option) list * type_expr option * statement list * position
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
  field_name: string option;  (* None 表示匿名嵌入字段 *)
  field_type: type_expr;
  field_pos: position;
}

(* 结构体成员: 字段或方法 *)
and struct_member =
  | SField of struct_field
  | SMethod of string * string list * (string * type_expr option * expr option) list * type_expr option * statement list * position

(* let 语句详细信息 *)
and let_stmt = {
  let_name: string;
  let_name_pos: position;  (* 变量名位置 *)
  let_type: type_expr option;
  let_value: expr;
  let_pos: position;  (* 整个 let 语句位置 *)
}

(* 模块级常量详细信息 *)
and const_stmt = {
  const_name: string;
  const_name_pos: position;
  const_type: type_expr option;
  const_value: expr;
  const_pos: position;
}

(* def 语句详细信息 *)
and def_stmt = {
  def_name: string;
  def_name_pos: position;  (* 函数名位置 *)
  def_type_params: string list;
  def_params: (string * type_expr option * expr option) list;  (* name, type, default_value *)
  def_return_type: type_expr option;
  def_body: statement list;
  def_pos: position;  (* 整个 def 语句位置 *)
}

(* struct 定义详细信息 *)
and struct_def = {
  struct_name: string;
  struct_name_pos: position;  (* 结构体名位置 *)
  struct_type_params: string list;
  struct_members: struct_member list;
  struct_pos: position;  (* 整个 struct 定义位置 *)
}

(* interface 定义详细信息 *)
and interface_def = {
  interface_name: string;
  interface_name_pos: position;  (* 接口名位置 *)
  interface_type_params: string list;
  interface_members: interface_member list;
  interface_pos: position;  (* 整个 interface 定义位置 *)
}

(* enum 定义详细信息 *)
and enum_def = {
  enum_name: string;
  enum_name_pos: position;  (* 枚举名位置 *)
  enum_type_params: string list;
  enum_variants: enum_variant list;
  enum_pos: position;  (* 整个 enum 定义位置 *)
}

(* 语句 *)
and statement =
  | SExpr of expr * position
  | SLet of let_stmt
  | SConst of const_stmt
  | SLetPat of pattern * expr * position  (* 元组解包: let (a,b) = tuple *)
  | SDef of def_stmt
  | SReturn of expr option * position
  | SBreak of position
  | SIf of expr * statement list * (expr * statement list) list * statement list option * position
  | SWhile of expr * statement list * position
  | SFor of pattern * expr * statement list * position
  | SStruct of struct_def
  | SInterface of interface_def
  | SImport of string list * string option * position  (* module path * alias * position *)
  | SFromImport of string * (string * string option) list * position  (* module * (name * alias) list * position *)
  | SAssign of string * expr * position
  | SIndexAssign of expr * expr * expr * position
  | SFieldAssign of expr * string * expr * position  (* 字段赋值: obj.field = value *)
  | SEnum of enum_def
  | SImpl of impl_block * position  (* impl 块 *)

type program = statement list
