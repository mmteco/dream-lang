(* LLVM 代码生成工具函数 *)

open Ast
open Cg_types

(* 临时变量和标签计数器 *)
let temp_counter = ref 0
let label_counter = ref 0
let string_counter = ref 0

let fresh_temp () =
  incr temp_counter;
  "%t" ^ string_of_int !temp_counter

let fresh_label prefix =
  incr label_counter;
  prefix ^ string_of_int !label_counter

(* LLVM 类型转字符串 *)
let rec llvm_type_to_string = function
  | I32 -> "i32"
  | U32 -> "i32"  (* LLVM 中无符号和有符号都用 i32 *)
  | I64 -> "i64"
  | I8 -> "i8"
  | U8 -> "i8"  (* LLVM 中无符号和有符号都用 i8 *)
  | I1 -> "i1"
  | Void -> "void"
  | Ptr t -> llvm_type_to_string t ^ "*"
  | Array (n, t) -> "[" ^ string_of_int n ^ " x " ^ llvm_type_to_string t ^ "]"
  | ImmutableArray elem_t ->
      (* 不可变数组结构: { i32 length, elem_t* data } *)
      Printf.sprintf "{ i32, %s* }" (llvm_type_to_string elem_t)
  | DynArray elem_t ->
      (* 动态数组结构: { i32 capacity, i32 length, elem_t* data } *)
      Printf.sprintf "{ i32, i32, %s* }" (llvm_type_to_string elem_t)
  | DynArrayPtr ->
      (* 指针数组结构: { i32 capacity, i32 length, i64* data } - i64用于64位指针 *)
      "{ i32, i32, i64* }"
  | StrType -> "{ i32, i8* }"    (* str: UTF-8 编码的不可变字符串 *)
  | BytesType -> "{ i32, i8* }"  (* bytes: 不可变字节序列 *)
  | TuplePtr -> "i32*"  (* 元组指针表示为i32* *)
  | DictPtr -> "i8*"    (* 字典指针表示为i8* *)
  | DictStrPtr -> "i8*" (* 字符串键字典指针也表示为i8* *)
  | UnionPtr -> "%union_t*"  (* Union 类型指针 *)
  | EnumPtr -> "%enum_t*"    (* Enum 类型指针 *)
  | StructPtr _name -> "i32*"  (* 结构体指针表示为 i32* *)

let mangle_name name =
  "@" ^ String.map (fun c -> if c = '_' then '_' else c) name

(* LLVM 字符串转义 *)
let llvm_escape_string s =
  let buf = Buffer.create (String.length s) in
  let byte_count = ref 0 in
  String.iter (fun c ->
    incr byte_count;  (* 每个字符在 LLVM IR 中都占 1 字节 *)
    match c with
    | '\n' -> Buffer.add_string buf "\\0A"
    | '\t' -> Buffer.add_string buf "\\09"
    | '\r' -> Buffer.add_string buf "\\0D"
    | '\\' -> Buffer.add_string buf "\\\\"
    | '"' -> Buffer.add_string buf "\\\""
    | c when Char.code c < 32 || Char.code c > 126 ->
        Printf.bprintf buf "\\%02X" (Char.code c)
    | c -> Buffer.add_char buf c
  ) s;
  (Buffer.contents buf, !byte_count + 1)  (* +1 for \00 *)

(* AST 类型表达式转 LLVM 类型 *)
let rec type_expr_to_llvm_type = function
  | TInt -> I32
  | TBool -> I1
  | TRune -> U32  (* rune 是 unsigned 32-bit Unicode codepoint *)
  | TByte -> U8   (* byte 是 unsigned 8-bit *)
  | TFloat -> I32
  | TStr -> StrType   (* str 是 UTF-8 编码的不可变字符串 *)
  | TBytes -> BytesType  (* bytes 是不可变字节序列 *)
  | TList ty -> DynArray (type_expr_to_llvm_type ty)  (* list 是可变动态数组 *)
  | TTuple _ -> TuplePtr
  | TDict _ -> DictPtr
  | TUnion _ -> UnionPtr  (* Union 类型映射为 union_t* *)
  | TVar name ->
      (* 检查是否是已注册的结构体 *)
      if Hashtbl.mem struct_registry name then
        Ptr I32  (* 结构体类型映射为指针 *)
      else
        I32
  | TOption _ -> Ptr I32
  | TResult _ -> EnumPtr  (* Result 类型映射为 enum_t* *)
  | TEnum _ -> EnumPtr    (* Enum 类型映射为 enum_t* *)
  | TStruct _ -> Ptr I32  (* 结构体类型映射为指针 *)
  | TNone | TFunc _ | TGeneric _ -> I32

(* 二元运算符代码生成 *)
let gen_binop = function
  | Add -> "add"
  | Sub -> "sub"
  | Mul -> "mul"
  | Div -> "sdiv"
  | Mod -> "srem"
  | Eq -> "icmp eq"
  | Neq -> "icmp ne"
  | Lt -> "icmp slt"
  | Gt -> "icmp sgt"
  | Lte -> "icmp sle"
  | Gte -> "icmp sge"
  | And -> "and"
  | Or -> "or"

(* 装箱：将具体类型值包装为 union_t* *)
(* type_name_opt: 当装箱结构体时，提供具体的结构体名称 *)
let box_to_union buf ctx value src_type type_name_opt =
  let result = fresh_temp () in
  (match src_type with
   | I32 ->
       Printf.bprintf buf "  %s = call %%union_t* @union_create_int(i32 %s)\n" result value
   | I1 ->
       Printf.bprintf buf "  %s = call %%union_t* @union_create_bool(i1 %s)\n" result value
   | StrType ->
       (* 字符串类型 - 需要转换为 i8* *)
       let str_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = extractvalue { i32, i8* } %s, 1\n" str_ptr value;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_string(i8* %s)\n" result str_ptr
   | BytesType ->
       (* bytes 类型 - 需要转换为 i8* *)
       let bytes_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = extractvalue { i32, i8* } %s, 1\n" bytes_ptr value;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_bytes(i8* %s)\n" result bytes_ptr
   | Ptr I8 ->
       (* i8* 指针类型 - 通常是字符串字面量 *)
       Printf.bprintf buf "  %s = call %%union_t* @union_create_string(i8* %s)\n" result value
   | StructPtr struct_name ->
       (* 结构体指针类型 - 装箱为 union struct，使用结构体名称 *)
       let type_name = struct_name in
       (* 将 i32* 转换为 i8* *)
       let ptr_as_i8 = fresh_temp () in
       Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" ptr_as_i8 value;
       (* 创建类型名字符串 *)
       incr string_counter;
       let type_str_name = Printf.sprintf "@.str%d" !string_counter in
       let (escaped_type_name, type_name_len) = llvm_escape_string type_name in
       (* 注意：这里需要在调用 box_to_union 的上下文中添加字符串字面量 *)
       ctx.string_literals <- (type_str_name, escaped_type_name, type_name_len) :: ctx.string_literals;
       let type_name_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
         type_name_ptr type_name_len type_name_len type_str_name;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_struct(i8* %s, i8* %s)\n" result ptr_as_i8 type_name_ptr
   | Ptr I32 ->
       (* 通用指针类型 - 使用传入的类型名，或使用默认值 *)
       let type_name = match type_name_opt with
         | Some name -> name
         | None -> "unknown_struct"
       in
       (* 将 i32* 转换为 i8* *)
       let ptr_as_i8 = fresh_temp () in
       Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" ptr_as_i8 value;
       (* 创建类型名字符串 *)
       incr string_counter;
       let type_str_name = Printf.sprintf "@.str%d" !string_counter in
       let (escaped_type_name, type_name_len) = llvm_escape_string type_name in
       (* 注意：这里需要在调用 box_to_union 的上下文中添加字符串字面量 *)
       ctx.string_literals <- (type_str_name, escaped_type_name, type_name_len) :: ctx.string_literals;
       let type_name_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
         type_name_ptr type_name_len type_name_len type_str_name;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_struct(i8* %s, i8* %s)\n" result ptr_as_i8 type_name_ptr
   | _ ->
       (* 其他类型暂不支持 *)
       Printf.bprintf buf "  ; TODO: box type %s to union\n" (llvm_type_to_string src_type);
       Printf.bprintf buf "  %s = call %%union_t* @union_create_none()\n" result);
  (* 记录 GC 对象以便后续释放 *)
  ctx.gc_objects <- result :: ctx.gc_objects;
  (result, UnionPtr)

(* 拆箱：从 union_t* 提取具体类型的值 *)
let unbox_from_union buf union_val target_type =
  let result = fresh_temp () in
  (match target_type with
   | I32 ->
       Printf.bprintf buf "  %s = call i32 @union_get_int(%%union_t* %s)\n" result union_val
   | I1 ->
       Printf.bprintf buf "  %s = call i1 @union_get_bool(%%union_t* %s)\n" result union_val
   | StrType ->
       (* 字符串类型 - 需要构造 { i32, i8* } 结构 *)
       let str_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = call i8* @union_get_string(%%union_t* %s)\n" str_ptr union_val;
       (* TODO: 获取字符串长度并构造完整的结构 *)
       Printf.bprintf buf "  ; TODO: construct str struct from pointer\n";
       Printf.bprintf buf "  %s = insertvalue { i32, i8* } undef, i8* %s, 1\n" result str_ptr
   | BytesType ->
       (* bytes 类型 - 需要构造 { i32, i8* } 结构 *)
       let bytes_ptr = fresh_temp () in
       Printf.bprintf buf "  %s = call i8* @union_get_bytes(%%union_t* %s)\n" bytes_ptr union_val;
       (* TODO: 获取字节数组长度并构造完整的结构 *)
       Printf.bprintf buf "  ; TODO: construct bytes struct from pointer\n";
       Printf.bprintf buf "  %s = insertvalue { i32, i8* } undef, i8* %s, 1\n" result bytes_ptr
   | _ ->
       Printf.bprintf buf "  ; TODO: unbox union to type %s\n" (llvm_type_to_string target_type);
       Printf.bprintf buf "  %s = add i32 0, 0  ; placeholder\n" result);
  (result, target_type)

(* LLVM 类型转 Dream 类型名 *)
let rec llvm_type_to_type_name = function
  | I32 -> "int"
  | U32 -> "rune"
  | I64 -> "int64"
  | I8 -> "i8"
  | U8 -> "byte"
  | I1 -> "bool"
  | Void -> "None"
  | StrType -> "str"
  | BytesType -> "bytes"
  | Ptr t -> llvm_type_to_type_name t ^ "*"
  | Array (n, t) -> Printf.sprintf "[%s; %d]" (llvm_type_to_type_name t) n
  | ImmutableArray t -> Printf.sprintf "immutable[%s]" (llvm_type_to_type_name t)
  | DynArray t -> Printf.sprintf "list[%s]" (llvm_type_to_type_name t)
  | DynArrayPtr -> "list[ptr]"
  | TuplePtr -> "tuple"
  | DictPtr -> "dict"
  | DictStrPtr -> "dict[str, int]"
  | UnionPtr -> "union"
  | EnumPtr -> "enum"
  | StructPtr name -> name
