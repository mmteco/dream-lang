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
  | I64 -> "i64"
  | I1 -> "i1"
  | Void -> "void"
  | Ptr t -> llvm_type_to_string t ^ "*"
  | Array (n, t) -> "[" ^ string_of_int n ^ " x " ^ llvm_type_to_string t ^ "]"
  | DynArray elem_t ->
      (* 动态数组结构: { i32 capacity, i32 length, elem_t* data } *)
      Printf.sprintf "{ i32, i32, %s* }" (llvm_type_to_string elem_t)
  | DynArrayPtr ->
      (* 指针数组结构: { i32 capacity, i32 length, i64* data } - i64用于64位指针 *)
      "{ i32, i32, i64* }"
  | TuplePtr -> "i32*"  (* 元组指针表示为i32* *)
  | DictPtr -> "i8*"    (* 字典指针表示为i8* *)
  | DictStrPtr -> "i8*" (* 字符串键字典指针也表示为i8* *)
  | UnionPtr -> "%union_t*"  (* Union 类型指针 *)
  | EnumPtr -> "%enum_t*"    (* Enum 类型指针 *)
  | StructPtr _name -> "i32*"  (* 结构体指针表示为 i32* *)

let mangle_name name =
  "@" ^ String.map (fun c -> if c = '_' then '_' else c) name

(* AST 类型表达式转 LLVM 类型 *)
let rec type_expr_to_llvm_type = function
  | TInt -> I32
  | TBool -> I1
  | TFloat -> I32
  | TStr -> Ptr I32
  | TBytes -> DynArray I32  (* bytes 映射为 dynarray_i32 *)
  | TList ty -> DynArray (type_expr_to_llvm_type ty)
  | TTuple _ -> TuplePtr
  | TDict _ -> DictPtr
  | TUnion _ -> UnionPtr  (* Union 类型映射为 union_t* *)
  | TVar _ -> I32
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
let box_to_union buf ctx value src_type =
  let result = fresh_temp () in
  (match src_type with
   | I32 ->
       Printf.bprintf buf "  %s = call %%union_t* @union_create_int(i32 %s)\n" result value
   | I1 ->
       Printf.bprintf buf "  %s = call %%union_t* @union_create_bool(i1 %s)\n" result value
   | Ptr I32 ->
       (* 字符串类型 - 需要先转换为 i8* *)
       let str_i8 = fresh_temp () in
       Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 value;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_string(i8* %s)\n" result str_i8
   | Ptr (DynArray I32) ->
       (* bytes 类型（指针） - 需要先转换为 i8* *)
       let bytes_i8 = fresh_temp () in
       Printf.bprintf buf "  %s = bitcast { i32, i32, i32* }* %s to i8*\n" bytes_i8 value;
       Printf.bprintf buf "  %s = call %%union_t* @union_create_bytes(i8* %s)\n" result bytes_i8
   | DynArray I32 ->
       (* bytes 类型（值） - 应该不会直接装箱值类型 *)
       Printf.bprintf buf "  ; ERROR: Cannot box bytes value type to union\n";
       Printf.bprintf buf "  %s = call %%union_t* @union_create_none()\n" result
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
   | Ptr I32 ->
       (* 字符串类型 *)
       Printf.bprintf buf "  %s = call i8* @union_get_string(%%union_t* %s)\n" result union_val
   | _ ->
       Printf.bprintf buf "  ; TODO: unbox union to type %s\n" (llvm_type_to_string target_type);
       Printf.bprintf buf "  %s = add i32 0, 0  ; placeholder\n" result);
  (result, target_type)
