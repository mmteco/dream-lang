open Ast
open Buffer

type llvm_type =
  | I32
  | I64
  | I1
  | Void
  | Ptr of llvm_type
  | Array of int * llvm_type
  | DynArray of llvm_type  (* 动态数组: {capacity, length, data*} *)
  | DynArrayPtr  (* 指针数组: {capacity, length, intptr_t*} - 用于存储指针 *)
  | TuplePtr  (* 元组指针 *)
  | DictPtr   (* 字典指针 dict[int,int] *)
  | DictStrPtr (* 字符串键字典指针 dict[string,int] *)
  | UnionPtr   (* Union 类型指针 *)
  | EnumPtr    (* Enum 类型指针 *)

type llvm_value = string

(* 枚举定义注册表 *)
type enum_variant_info = {
  variant_name: string;
  tag: int;
  has_data: bool;
}

type enum_definition = {
  enum_name: string;
  variants: enum_variant_info list;
}

let enum_registry : (string, enum_definition) Hashtbl.t = Hashtbl.create 16

(* 结构体定义注册表 *)
type struct_field_info = {
  field_name: string;
  field_index: int;
  field_llvm_type: llvm_type;
}

type struct_definition = {
  struct_name: string;
  fields: struct_field_info list;
}

let struct_registry : (string, struct_definition) Hashtbl.t = Hashtbl.create 16

(* 方法注册表: method_name -> struct_name *)
let struct_method_registry : (string, string) Hashtbl.t = Hashtbl.create 16

let temp_counter = ref 0
let label_counter = ref 0
let string_counter = ref 0

let fresh_temp () =
  incr temp_counter;
  "%t" ^ string_of_int !temp_counter

let fresh_label prefix =
  incr label_counter;
  prefix ^ string_of_int !label_counter

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

let mangle_name name =
  "@" ^ String.map (fun c -> if c = '_' then '_' else c) name

type context = {
  mutable variables: (string * llvm_type) list;
  mutable function_type: llvm_type option;
  mutable string_literals: (string * string * int) list;
  (* 变量名重映射表: 原始名 -> LLVM变量名(不含%) *)
  mutable var_renames: (string * string) list;
  (* 跟踪动态分配的对象,需要在作用域结束时释放 *)
  (* 存储 (变量名, LLVM临时变量名) *)
  mutable dynarray_vars: (string * string) list;
  (* 跟踪 GC 分配的对象（union 等），需要在作用域结束时释放 *)
  mutable gc_objects: string list;  (* 存储临时变量名 *)
  (* 函数签名表: 函数名 -> 返回类型 *)
  mutable function_signatures: (string * llvm_type) list;
  (* 函数参数类型表: 函数名 -> 参数类型列表 *)
  mutable function_param_types: (string * llvm_type list) list;
  (* 变量对应的结构体类型: 变量名 -> 结构体名 *)
  mutable var_struct_types: (string * string) list;
}

let create_context () = {
  variables = [];
  function_type = None;
  string_literals = [];
  var_renames = [];
  dynarray_vars = [];
  gc_objects = [];
  function_signatures = [];
  function_param_types = [];
  var_struct_types = [];
}

let add_variable ctx name ty =
  ctx.variables <- (name, ty) :: ctx.variables

let add_variable_with_rename ctx orig_name llvm_name ty =
  ctx.variables <- (orig_name, ty) :: ctx.variables;
  ctx.var_renames <- (orig_name, llvm_name) :: ctx.var_renames

let find_variable ctx name =
  try Some (List.assoc name ctx.variables)
  with Not_found -> None

let find_llvm_name ctx name =
  try Some (List.assoc name ctx.var_renames)
  with Not_found -> None

let rec type_expr_to_llvm_type = function
  | TInt -> I32
  | TBool -> I1
  | TFloat -> I32
  | TString -> Ptr I32
  | TList ty -> DynArray (type_expr_to_llvm_type ty)
  | TTuple _ -> TuplePtr
  | TDict _ -> DictPtr
  | TUnion _ -> UnionPtr  (* Union 类型映射为 union_t* *)
  | TVar _ -> I32
  | TOption _ -> Ptr I32
  | TResult _ -> Ptr I32
  | TEnum _ -> I32
  | TStruct _ -> Ptr I32  (* 结构体类型映射为指针 *)
  | TNone | TFunc _ | TGeneric _ -> I32

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
       (* 字符串类型 *)
       Printf.bprintf buf "  %s = call %%union_t* @union_create_string(i8* %s)\n" result value
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

let rec gen_expr buf ctx = function
  | EInt (n, _) ->
      (string_of_int n, I32)

  | EBool (b, _) ->
      ((if b then "1" else "0" : llvm_value), I1)

  | EString (s, _) ->
      incr string_counter;
      let str_name = Printf.sprintf "@.str%d" !string_counter in
      let escaped_str = String.escaped s in
      let str_len = String.length s + 1 in
      ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
      let ptr_temp = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
        ptr_temp str_len str_len str_name;
      (ptr_temp, Ptr I32)

  | EVar (name, _) ->
      (match find_variable ctx name with
       | Some (Array _ as ty) ->
           (* 检查是否有重命名 *)
           let actual_name = match find_llvm_name ctx name with
             | Some renamed -> renamed
             | None -> name
           in
           let local = "%" ^ actual_name in
           (local, ty)
       | Some (DynArray _ as ty) ->
           (* 动态数组存储为指针的指针,需要load出指针值 *)
           let actual_name = match find_llvm_name ctx name with
             | Some renamed -> renamed
             | None -> name
           in
           let local = "%" ^ actual_name in
           let loaded_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             loaded_ptr (llvm_type_to_string ty) (llvm_type_to_string ty) local;
           (loaded_ptr, ty)
       | Some (DynArrayPtr as ty) ->
           (* 指针数组存储为指针的指针，需要load出指针值 *)
           let actual_name = match find_llvm_name ctx name with
             | Some renamed -> renamed
             | None -> name
           in
           let local = "%" ^ actual_name in
           let loaded_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %%dynarray_ptr*, %%dynarray_ptr** %s\n"
             loaded_ptr local;
           (loaded_ptr, ty)
       | Some ((TuplePtr | DictPtr | Ptr I32) as ty) ->
           let temp = fresh_temp () in
           let actual_name = match find_llvm_name ctx name with
             | Some renamed -> renamed
             | None -> name
           in
           let local = "%" ^ actual_name in
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             temp (llvm_type_to_string ty) (llvm_type_to_string ty) local;
           (temp, ty)
       | Some ty ->
           let temp = fresh_temp () in
           let actual_name = match find_llvm_name ctx name with
             | Some renamed -> renamed
             | None -> name
           in
           let local = "%" ^ actual_name in
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             temp (llvm_type_to_string ty) (llvm_type_to_string ty) local;
           (temp, ty)
       | None ->
           ("0", I32))

  | EBinOp (e1, op, e2, _) ->
      let (v1, t1) = gen_expr buf ctx e1 in
      let (v2, t2) = gen_expr buf ctx e2 in
      let result = fresh_temp () in
      let op_str = gen_binop op in
      (match op with
       | Add when (match t1, t2 with
                      | Array _, Array _ -> true
                      | DynArray _, DynArray _ -> true
                      | _ -> false) ->
           (* 数组拼接 *)
           (match t1, t2 with
            | Array (n1, elem_t1), Array (n2, _) ->
                let new_size = n1 + n2 in
                let new_array_type = Array (new_size, elem_t1) in
                let new_array = fresh_temp () in
                Printf.bprintf buf "  %s = alloca %s\n" new_array (llvm_type_to_string new_array_type);

                (* 复制第一个数组的元素 *)
                let i = ref 0 in
                while !i < n1 do
                  let src_ptr = fresh_temp () in
                  let dst_ptr = fresh_temp () in
                  let value = fresh_temp () in
                  Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
                    src_ptr (llvm_type_to_string t1) (llvm_type_to_string t1) v1 !i;
                  Printf.bprintf buf "  %s = load %s, %s* %s\n"
                    value (llvm_type_to_string elem_t1) (llvm_type_to_string elem_t1) src_ptr;
                  Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
                    dst_ptr (llvm_type_to_string new_array_type) (llvm_type_to_string new_array_type) new_array !i;
                  Printf.bprintf buf "  store %s %s, %s* %s\n"
                    (llvm_type_to_string elem_t1) value (llvm_type_to_string elem_t1) dst_ptr;
                  i := !i + 1
                done;

                (* 复制第二个数组的元素 *)
                let j = ref 0 in
                while !j < n2 do
                  let src_ptr = fresh_temp () in
                  let dst_ptr = fresh_temp () in
                  let value = fresh_temp () in
                  Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
                    src_ptr (llvm_type_to_string t2) (llvm_type_to_string t2) v2 !j;
                  Printf.bprintf buf "  %s = load %s, %s* %s\n"
                    value (llvm_type_to_string elem_t1) (llvm_type_to_string elem_t1) src_ptr;
                  Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
                    dst_ptr (llvm_type_to_string new_array_type) (llvm_type_to_string new_array_type) new_array (n1 + !j);
                  Printf.bprintf buf "  store %s %s, %s* %s\n"
                    (llvm_type_to_string elem_t1) value (llvm_type_to_string elem_t1) dst_ptr;
                  j := !j + 1
                done;

                (new_array, new_array_type)
            | DynArray elem_t, DynArray _ ->
                (* 动态数组拼接 - 创建新的动态数组 *)
                (* 获取第一个数组的长度和数据指针 *)
                let len1_ptr = fresh_temp () in
                let len1 = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
                  len1_ptr (llvm_type_to_string t1) (llvm_type_to_string t1) v1;
                Printf.bprintf buf "  %s = load i32, i32* %s\n" len1 len1_ptr;

                let data1_ptr_field = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
                  data1_ptr_field (llvm_type_to_string t1) (llvm_type_to_string t1) v1;
                let data1_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = load i32*, i32** %s\n" data1_ptr data1_ptr_field;

                (* 获取第二个数组的长度和数据指针 *)
                let len2_ptr = fresh_temp () in
                let len2 = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
                  len2_ptr (llvm_type_to_string t2) (llvm_type_to_string t2) v2;
                Printf.bprintf buf "  %s = load i32, i32* %s\n" len2 len2_ptr;

                let data2_ptr_field = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
                  data2_ptr_field (llvm_type_to_string t2) (llvm_type_to_string t2) v2;
                let data2_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = load i32*, i32** %s\n" data2_ptr data2_ptr_field;

                (* 计算新数组的总长度 *)
                let new_len = fresh_temp () in
                Printf.bprintf buf "  %s = add i32 %s, %s\n" new_len len1 len2;

                (* 创建新的动态数组 - 在堆上分配结构体 *)
                let result_arr = fresh_temp () in
                let result_type = DynArray elem_t in
                (* 分配结构体本身: sizeof({ i32, i32, i32* }) = 16 bytes *)
                let struct_malloc = fresh_temp () in
                Printf.bprintf buf "  %s = call i8* @malloc(i32 16)\n" struct_malloc;
                Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
                  result_arr struct_malloc (llvm_type_to_string result_type);

                (* 分配新数组的数据内存 *)
                let size_bytes = fresh_temp () in
                Printf.bprintf buf "  %s = mul i32 %s, 4\n" size_bytes new_len;
                let malloc_result = fresh_temp () in
                Printf.bprintf buf "  %s = call i8* @malloc(i32 %s)\n" malloc_result size_bytes;
                let result_data_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_data_ptr malloc_result;

                (* 设置新数组的 capacity 和 length *)
                let cap_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 0\n"
                  cap_ptr (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" new_len cap_ptr;

                let len_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
                  len_ptr (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" new_len len_ptr;

                let data_ptr_field = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
                  data_ptr_field (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
                Printf.bprintf buf "  store i32* %s, i32** %s\n" result_data_ptr data_ptr_field;

                (* 循环复制第一个数组的元素 *)
                let counter1_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = alloca i32\n" counter1_ptr;
                Printf.bprintf buf "  store i32 0, i32* %s\n" counter1_ptr;

                let loop1_label = fresh_label "concat.loop1" in
                let body1_label = fresh_label "concat.body1" in
                let end1_label = fresh_label "concat.end1" in

                Printf.bprintf buf "  br label %%%s\n" loop1_label;
                Printf.bprintf buf "\n%s:\n" loop1_label;

                let counter1_val = fresh_temp () in
                Printf.bprintf buf "  %s = load i32, i32* %s\n" counter1_val counter1_ptr;

                let cond1 = fresh_temp () in
                Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond1 counter1_val len1;
                Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond1 body1_label end1_label;

                Printf.bprintf buf "\n%s:\n" body1_label;

                (* 从第一个数组读取 *)
                let src1_elem_ptr = fresh_temp () in
                let elem1_val = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
                  src1_elem_ptr data1_ptr counter1_val;
                Printf.bprintf buf "  %s = load i32, i32* %s\n" elem1_val src1_elem_ptr;

                (* 写入结果数组 *)
                let dst1_elem_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
                  dst1_elem_ptr result_data_ptr counter1_val;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" elem1_val dst1_elem_ptr;

                (* 递增计数器 *)
                let next_counter1 = fresh_temp () in
                Printf.bprintf buf "  %s = add i32 %s, 1\n" next_counter1 counter1_val;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" next_counter1 counter1_ptr;

                Printf.bprintf buf "  br label %%%s\n" loop1_label;
                Printf.bprintf buf "\n%s:\n" end1_label;

                (* 循环复制第二个数组的元素 *)
                let counter2_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = alloca i32\n" counter2_ptr;
                Printf.bprintf buf "  store i32 0, i32* %s\n" counter2_ptr;

                let loop2_label = fresh_label "concat.loop2" in
                let body2_label = fresh_label "concat.body2" in
                let end2_label = fresh_label "concat.end2" in

                Printf.bprintf buf "  br label %%%s\n" loop2_label;
                Printf.bprintf buf "\n%s:\n" loop2_label;

                let counter2_val = fresh_temp () in
                Printf.bprintf buf "  %s = load i32, i32* %s\n" counter2_val counter2_ptr;

                let cond2 = fresh_temp () in
                Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond2 counter2_val len2;
                Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond2 body2_label end2_label;

                Printf.bprintf buf "\n%s:\n" body2_label;

                (* 从第二个数组读取 *)
                let src2_elem_ptr = fresh_temp () in
                let elem2_val = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
                  src2_elem_ptr data2_ptr counter2_val;
                Printf.bprintf buf "  %s = load i32, i32* %s\n" elem2_val src2_elem_ptr;

                (* 计算结果数组中的目标索引: len1 + counter2 *)
                let dst2_idx = fresh_temp () in
                Printf.bprintf buf "  %s = add i32 %s, %s\n" dst2_idx len1 counter2_val;

                (* 写入结果数组 *)
                let dst2_elem_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
                  dst2_elem_ptr result_data_ptr dst2_idx;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" elem2_val dst2_elem_ptr;

                (* 递增计数器 *)
                let next_counter2 = fresh_temp () in
                Printf.bprintf buf "  %s = add i32 %s, 1\n" next_counter2 counter2_val;
                Printf.bprintf buf "  store i32 %s, i32* %s\n" next_counter2 counter2_ptr;

                Printf.bprintf buf "  br label %%%s\n" loop2_label;
                Printf.bprintf buf "\n%s:\n" end2_label;

                (result_arr, result_type)
            | _ -> ("0", I32))
       | Eq | Neq | Lt | Gt | Lte | Gte ->
           (match t1 with
            | Ptr I32 ->
                (* 字符串比较 *)
                let str1_i8 = fresh_temp () in
                let str2_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str1_i8 v1;
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str2_i8 v2;
                let cmp_result = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_compare(i8* %s, i8* %s)\n"
                  cmp_result str1_i8 str2_i8;
                (* 根据操作符生成相应的比较 *)
                (match op with
                 | Eq ->
                     Printf.bprintf buf "  %s = icmp eq i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | Neq ->
                     Printf.bprintf buf "  %s = icmp ne i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | Lt ->
                     Printf.bprintf buf "  %s = icmp slt i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | Gt ->
                     Printf.bprintf buf "  %s = icmp sgt i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | Lte ->
                     Printf.bprintf buf "  %s = icmp sle i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | Gte ->
                     Printf.bprintf buf "  %s = icmp sge i32 %s, 0\n" result cmp_result;
                     (result, I1)
                 | _ -> (result, I1))
            | _ ->
                (* 其他类型的比较 *)
                Printf.bprintf buf "  %s = %s %s %s, %s\n"
                  result op_str (llvm_type_to_string t1) v1 v2;
                (result, I1))
       | _ ->
           Printf.bprintf buf "  %s = %s %s %s, %s\n"
             result op_str (llvm_type_to_string t1) v1 v2;
           (result, t1))

  | EUnOp (Not, e, _) ->
      let (v, t) = gen_expr buf ctx e in
      let result = fresh_temp () in
      Printf.bprintf buf "  %s = xor %s %s, 1\n"
        result (llvm_type_to_string t) v;
      (result, t)

  | EUnOp (Neg, e, _) ->
      let (v, t) = gen_expr buf ctx e in
      let result = fresh_temp () in
      Printf.bprintf buf "  %s = sub %s 0, %s\n"
        result (llvm_type_to_string t) v;
      (result, t)

  (* 字符串方法调用 *)
  | ECall (EAttr (obj, method_name, _), args, _) ->
      let (obj_v, obj_t) = gen_expr buf ctx obj in
      (match obj_t with
       | Ptr I32 ->
           (* 字符串方法 *)
           let str_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 obj_v;
           let result = fresh_temp () in
           (match method_name with
            | "length" ->
                Printf.bprintf buf "  %s = call i32 @string_length(i8* %s)\n" result str_i8;
                (result, I32)
            | "upper" ->
                Printf.bprintf buf "  %s = call i8* @string_upper(i8* %s)\n" result str_i8;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                (result_i32, Ptr I32)
            | "lower" ->
                Printf.bprintf buf "  %s = call i8* @string_lower(i8* %s)\n" result str_i8;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                (result_i32, Ptr I32)
            | "strip" ->
                Printf.bprintf buf "  %s = call i8* @string_strip(i8* %s)\n" result str_i8;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                (result_i32, Ptr I32)
            | "find" when List.length args = 1 ->
                let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                let arg_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                Printf.bprintf buf "  %s = call i32 @string_find(i8* %s, i8* %s)\n" result str_i8 arg_i8;
                (result, I32)
            | "starts_with" when List.length args = 1 ->
                let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                let arg_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_starts_with(i8* %s, i8* %s)\n" result_i32 str_i8 arg_i8;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "ends_with" when List.length args = 1 ->
                let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                let arg_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_ends_with(i8* %s, i8* %s)\n" result_i32 str_i8 arg_i8;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "replace" when List.length args = 2 ->
                let (old_v, _) = gen_expr buf ctx (List.nth args 0) in
                let (new_v, _) = gen_expr buf ctx (List.nth args 1) in
                let old_i8 = fresh_temp () in
                let new_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" old_i8 old_v;
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" new_i8 new_v;
                Printf.bprintf buf "  %s = call i8* @string_replace(i8* %s, i8* %s, i8* %s)\n"
                  result str_i8 old_i8 new_i8;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                (result_i32, Ptr I32)
            | "split" when List.length args = 1 ->
                let (delim_v, _) = gen_expr buf ctx (List.hd args) in
                let delim_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" delim_i8 delim_v;
                Printf.bprintf buf "  %s = call %%dynarray_ptr* @string_split(i8* %s, i8* %s)\n"
                  result str_i8 delim_i8;
                (result, DynArrayPtr)
            | "is_digit" when List.length args = 1 ->
                let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_digit(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "is_alpha" when List.length args = 1 ->
                let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_alpha(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "is_whitespace" when List.length args = 1 ->
                let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_whitespace(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | _ ->
                (* 不是字符串方法，可能是结构体方法调用 *)
                (* 从 struct_method_registry 查找方法所属的结构体 *)
                (match Hashtbl.find_opt struct_method_registry method_name with
                 | Some struct_name ->
                     (* 生成结构体方法调用 *)
                     let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                     let arg_vals_types = List.map (gen_expr buf ctx) args in
                     let arg_vals = List.map fst arg_vals_types in
                     let result = fresh_temp () in

                     (* 调用 StructName_method_name(obj, args...) *)
                     Printf.bprintf buf "  %s = call i32 %s(i32* %s"
                       result (mangle_name mangled_name) obj_v;
                     List.iter (fun arg_val ->
                       Printf.bprintf buf ", i32 %s" arg_val
                     ) arg_vals;
                     Printf.bprintf buf ")\n";
                     (result, I32)
                 | None ->
                     Printf.bprintf buf "  ; Unknown string method or struct method: %s\n" method_name;
                     ("0", I32)))
       | _ ->
           Printf.bprintf buf "  ; Method call on non-string type\n";
           ("0", I32))

  | ECall (EVar ("print", _), [EString (s, _)], _) ->
      incr string_counter;
      let str_name = Printf.sprintf "@.str%d" !string_counter in
      let escaped_str = String.escaped s in
      let str_len = String.length s + 1 in
      ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
      let ptr_temp = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
        ptr_temp str_len str_len str_name;
      Printf.bprintf buf "  call i32 (i8*, ...) @printf(i8* %s)\n" ptr_temp;
      ("0", Void)

  | ECall (EVar ("print", _), [arg], _) ->
      let (v, t) = gen_expr buf ctx arg in
      (match t with
       | I32 ->
           Printf.bprintf buf "  call void @print_int(i32 %s)\n" v;
       | I1 ->
           Printf.bprintf buf "  call void @print_bool(i1 %s)\n" v;
       | Ptr I32 ->
           (* String 类型：转换为 i8* 并打印 *)
           let str_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 v;
           Printf.bprintf buf "  call void @print_string(i8* %s)\n" str_i8;
       | UnionPtr ->
           (* Union 类型：调用 union_print_value *)
           Printf.bprintf buf "  call void @union_print_value(%%union_t* %s)\n" v;
       | _ ->
           Printf.bprintf buf "  ; print not implemented for this type\n");
      ("0", Void)

  | ECall (EVar ("len", _), [arr_expr], _) ->
      let (arr_v, arr_t) = gen_expr buf ctx arr_expr in
      (match arr_t with
       | Array (n, _) ->
           (string_of_int n, I32)
       | DynArray _ ->
           (* 从动态数组结构中读取 length 字段 *)
           (* arr_v 已经是加载后的指针 *)
           let len_ptr = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr { i32, i32, i32* }, { i32, i32, i32* }* %s, i32 0, i32 1\n"
             len_ptr arr_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" result len_ptr;
           (result, I32)
       | Ptr I32 ->
           Printf.bprintf buf "  ; len() not supported for pointer arrays\n";
           ("0", I32)
       | _ ->
           Printf.bprintf buf "  ; len() only works with arrays\n";
           ("0", I32))

  | ECall (EVar ("append", _), [arr_expr; value_expr], _) ->
      let (arr_v, arr_t) = gen_expr buf ctx arr_expr in
      (match arr_t with
       | DynArray _ ->
           (* arr_v 已经是加载后的指针 *)
           (* 计算要添加的值 *)
           let (value_v, _) = gen_expr buf ctx value_expr in

           (* 调用 append_i32 函数 *)
           Printf.bprintf buf "  call void @append_i32({ i32, i32, i32* }* %s, i32 %s)\n"
             arr_v value_v;
           ("0", Void)
       | _ ->
           Printf.bprintf buf "  ; append() only works with dynamic arrays\n";
           ("0", Void))

  | ECall (EVar ("join", _), [arr_expr; sep_expr], _) ->
      let (arr_v, arr_t) = gen_expr buf ctx arr_expr in
      let (sep_v, _) = gen_expr buf ctx sep_expr in
      (match arr_t with
       | DynArrayPtr ->
           (* 调用 string_join 函数 *)
           let sep_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" sep_i8 sep_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @string_join(%%dynarray_ptr* %s, i8* %s)\n"
             result arr_v sep_i8;
           let result_i32 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
           (result_i32, Ptr I32)
       | _ ->
           Printf.bprintf buf "  ; join() only works with string arrays\n";
           ("0", Ptr I32))

  | ECall (EVar ("dict_keys", _), [dict_expr], _) ->
      let (dict_v, dict_t) = gen_expr buf ctx dict_expr in
      (match dict_t with
       | DictPtr | Ptr I32 ->
           (* 调用 dict_keys 函数 *)
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call { i32, i32, i32* }* @dict_keys(i8* %s)\n"
             result dict_v;
           (result, DynArray I32)
       | _ ->
           Printf.bprintf buf "  ; dict_keys() only works with dictionaries\n";
           ("0", I32))

  | ECall (EVar ("dict_values", _), [dict_expr], _) ->
      let (dict_v, dict_t) = gen_expr buf ctx dict_expr in
      (match dict_t with
       | DictPtr | Ptr I32 ->
           (* 调用 dict_values 函数 *)
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call { i32, i32, i32* }* @dict_values(i8* %s)\n"
             result dict_v;
           (result, DynArray I32)
       | _ ->
           Printf.bprintf buf "  ; dict_values() only works with dictionaries\n";
           ("0", I32))

  | ECall (EVar ("dict_items", _), [dict_expr], _) ->
      let (dict_v, dict_t) = gen_expr buf ctx dict_expr in
      (match dict_t with
       | DictPtr | Ptr I32 ->
           (* 调用 dict_items 函数 - 返回 dynarray_ptr *)
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call { i32, i32, i64* }* @dict_items(i8* %s)\n"
             result dict_v;
           (result, DynArrayPtr)
       | _ ->
           Printf.bprintf buf "  ; dict_items() only works with dictionaries\n";
           ("0", I32))

  | ECall (EVar (fname, _), args, _) ->
      let arg_vals = List.map (gen_expr buf ctx) args in

      (* 查询函数的参数类型 *)
      let param_types =
        try List.assoc fname ctx.function_param_types
        with Not_found -> []
      in

      (* 检查并装箱参数 *)
      let boxed_arg_vals = List.mapi (fun i (v, t) ->
        if i < List.length param_types then
          let expected_type = List.nth param_types i in
          (* 如果期望的是 union 类型,但实际不是,则装箱 *)
          if expected_type = UnionPtr && t <> UnionPtr then begin
            Printf.bprintf buf "  ; Boxing argument %d to union\n" i;
            box_to_union buf ctx v t
          end else
            (v, t)
        else
          (v, t)
      ) arg_vals in

      let result = fresh_temp () in
      (* 查询函数签名获取返回类型 *)
      let ret_type =
        try List.assoc fname ctx.function_signatures
        with Not_found -> I32  (* 默认返回 i32 *)
      in
      let ret_type_str = match ret_type with
        | DynArray _ | Array _ -> (llvm_type_to_string ret_type) ^ "*"
        | _ -> llvm_type_to_string ret_type
      in
      Printf.bprintf buf "  %s = call %s %s(" result ret_type_str (mangle_name fname);
      List.iteri (fun i (v, t) ->
        if i > 0 then Buffer.add_string buf ", ";
        match t with
        | DynArray _ | Array _ ->
            Printf.bprintf buf "%s* %s" (llvm_type_to_string t) v
        | _ ->
            Printf.bprintf buf "%s %s" (llvm_type_to_string t) v
      ) boxed_arg_vals;
      Buffer.add_string buf ")\n";
      (result, ret_type)

  | EList (elems, _) ->
      let elem_vals = List.map (gen_expr buf ctx) elems in
      let len = List.length elems in
      let elem_t = I32 in

      (* 使用 GC 分配器创建动态数组 *)
      let dyn_arr = fresh_temp () in
      let dyn_arr_type = DynArray elem_t in
      Printf.bprintf buf "  %s = call { i32, i32, i32* }* @create_dynarray_i32(i32 %d)\n" dyn_arr len;

      (* 填充数据 - 使用 append_i32 *)
      List.iter (fun (v, _) ->
        Printf.bprintf buf "  call void @append_i32({ i32, i32, i32* }* %s, i32 %s)\n" dyn_arr v
      ) elem_vals;

      (dyn_arr, dyn_arr_type)

  | EDict (pairs, _) ->
      let initial_capacity = max 16 (List.length pairs * 2) in
      let dict_ptr = fresh_temp () in

      let (is_str_key, is_str_val) =
        match pairs with
        | [] -> (false, false)
        | (key_expr, val_expr) :: _ ->
            let k_is_str = (match key_expr with EString _ -> true | _ -> false) in
            let v_is_str = (match val_expr with EString _ -> true | _ -> false) in
            (k_is_str, v_is_str)
      in

      (* 生成创建字典的代码 - 使用统一的 dict_create(key_type, val_type, capacity) *)
      let key_type = if is_str_key then 1 else 0 in  (* 0=DICT_KEY_INT, 1=DICT_KEY_STRING *)
      let val_type = if is_str_val then 1 else 0 in  (* 0=DICT_VAL_INT, 1=DICT_VAL_STRING *)
      Printf.bprintf buf "  %s = call i8* @dict_create(i32 %d, i32 %d, i32 %d)\n"
        dict_ptr key_type val_type initial_capacity;

      (* 填充字典 - 使用统一的类型特化函数 *)
      List.iter (fun (key_expr, val_expr) ->
        let (key_v, _) = gen_expr buf ctx key_expr in
        let (val_v, _) = gen_expr buf ctx val_expr in
        match (is_str_key, is_str_val) with
        | (false, false) ->
            Printf.bprintf buf "  call void @dict_set_int_int(i8* %s, i32 %s, i32 %s)\n" dict_ptr key_v val_v
        | (false, true) ->
            Printf.bprintf buf "  call void @dict_set_int_str(i8* %s, i32 %s, i8* %s)\n" dict_ptr key_v val_v
        | (true, false) ->
            Printf.bprintf buf "  call void @dict_set_str_int(i8* %s, i8* %s, i32 %s)\n" dict_ptr key_v val_v
        | (true, true) ->
            Printf.bprintf buf "  call void @dict_set_str_str(i8* %s, i8* %s, i8* %s)\n" dict_ptr key_v val_v
      ) pairs;

      (dict_ptr, if is_str_key then DictStrPtr else DictPtr)

  | ETuple (elems, _) ->
      let size = List.length elems in
      if size = 0 then begin
        Printf.bprintf buf "  ; empty tuple not supported\n";
        ("0", TuplePtr)
      end else begin
        (* 统一使用 tuple_t 处理所有元组 *)
        let tuple_i8 = fresh_temp () in
        let tuple_ptr = fresh_temp () in
        Printf.bprintf buf "  %s = call i8* @tuple_create(i32 %d)\n" tuple_i8 size;

        (* 填充元组元素 *)
        List.iteri (fun i elem ->
          let (v, _) = gen_expr buf ctx elem in
          Printf.bprintf buf "  call void @tuple_set(i8* %s, i32 %d, i32 %s)\n"
            tuple_i8 i v
        ) elems;

        (* 转换为 i32* 以符合 TuplePtr 类型 *)
        Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" tuple_ptr tuple_i8;
        (tuple_ptr, TuplePtr)
      end

  | EIndex (arr, idx, _) ->
      let (arr_v, arr_t) = gen_expr buf ctx arr in
      let (idx_v, _) = gen_expr buf ctx idx in

      (match arr_t with
       | Ptr I32 when (match arr with EVar _ | EString _ -> true | _ -> false) ->
           (* 字符串索引:调用 string_char_at *)
           (* 首先将 i32* 转换为 i8* *)
           let str_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 arr_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n"
             result str_i8 idx_v;
           (* 转换为i32返回 *)
           let result_i32 = fresh_temp () in
           Printf.bprintf buf "  %s = zext i8 %s to i32\n" result_i32 result;
           (result_i32, I32)
       | Array (_, elem_t) ->
           let ptr_temp = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
             ptr_temp (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v idx_v;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             result (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) ptr_temp;
           (result, elem_t)
       | DynArray elem_t ->
           (* 从动态数组结构中提取 data 指针 *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v;

           (* 加载 data 指针 *)
           let data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

           (* 使用索引访问元素 *)
           let ptr_temp = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 %s\n"
             ptr_temp (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr idx_v;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             result (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) ptr_temp;
           (result, elem_t)
       | TuplePtr ->
           (* 元组索引:调用 tuple_get *)
           let tuple_i8 = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" tuple_i8 arr_v;
           Printf.bprintf buf "  %s = call i32 @tuple_get(i8* %s, i32 %s)\n"
             result tuple_i8 idx_v;
           (result, I32)
       | DictPtr ->
           (* 字典索引:调用 dict_get_int_int *)
           let found_ptr = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" found_ptr;
           Printf.bprintf buf "  %s = call i32 @dict_get_int_int(i8* %s, i32 %s, i32* %s)\n"
             result arr_v idx_v found_ptr;
           (result, I32)
       | DictStrPtr ->
           (* 字符串键字典索引:调用 dict_get_str_int *)
           let found_ptr = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" found_ptr;
           Printf.bprintf buf "  %s = call i32 @dict_get_str_int(i8* %s, i8* %s, i32* %s)\n"
             result arr_v idx_v found_ptr;
           (result, I32)
       | Ptr I32 ->
           (* 旧的 Ptr I32 类型,默认视为字典 *)
           let found_ptr = fresh_temp () in
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" found_ptr;
           Printf.bprintf buf "  %s = call i32 @dict_get_int_int(i8* %s, i32 %s, i32* %s)\n"
             result arr_v idx_v found_ptr;
           (result, I32)
       | _ ->
           ("0", I32))

  | ESlice (arr, start_opt, end_opt, _) ->
      let (arr_v, arr_t) = gen_expr buf ctx arr in
      (match arr_t with
       | Array (arr_len, elem_t) ->
           (* 计算起始和结束索引 *)
           let start_idx = match start_opt with
             | Some start_expr ->
                 let (start_v, _) = gen_expr buf ctx start_expr in
                 start_v
             | None -> "0"
           in
           let end_idx = match end_opt with
             | Some end_expr ->
                 let (end_v, _) = gen_expr buf ctx end_expr in
                 end_v
             | None -> string_of_int arr_len
           in

           (* 计算切片长度: end - start *)
           let length_temp = fresh_temp () in
           Printf.bprintf buf "  %s = sub i32 %s, %s\n" length_temp end_idx start_idx;

           (* 由于LLVM需要编译时数组大小,这里我们需要动态确定大小 *)
           (* 为简化实现,我们使用最大可能的大小 *)
           let slice_size = arr_len in  (* 最坏情况下切片大小等于原数组 *)
           let slice_type = Array (slice_size, elem_t) in
           let slice_temp = fresh_temp () in
           Printf.bprintf buf "  %s = alloca %s\n" slice_temp (llvm_type_to_string slice_type);

           (* 生成循环来复制元素 *)
           (* 使用展开循环的方式,因为LLVM IR需要静态大小 *)
           (* 这里采用运行时循环的方式,使用 phi 节点 *)
           let loop_label = fresh_label "slice.loop" in
           let body_label = fresh_label "slice.body" in
           let end_label = fresh_label "slice.end" in

           (* 初始化循环计数器 *)
           let counter_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" counter_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" counter_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           (* 加载计数器 *)
           let counter_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" counter_val counter_ptr;

           (* 检查是否到达结束 *)
           let cond_temp = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond_temp counter_val length_temp;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_temp body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 计算源索引: start + counter *)
           let src_idx = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, %s\n" src_idx start_idx counter_val;

           (* 从源数组读取 *)
           let src_ptr = fresh_temp () in
           let value = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
             src_ptr (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v src_idx;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             value (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) src_ptr;

           (* 写入目标数组 *)
           let dst_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
             dst_ptr (llvm_type_to_string slice_type) (llvm_type_to_string slice_type) slice_temp counter_val;
           Printf.bprintf buf "  store %s %s, %s* %s\n"
             (llvm_type_to_string elem_t) value (llvm_type_to_string elem_t) dst_ptr;

           (* 递增计数器 *)
           let next_counter = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_counter counter_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_counter counter_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (* 返回切片数组,但需要返回实际长度的数组类型 *)
           (* 由于我们不知道运行时长度,这里返回最大size的数组 *)
           (slice_temp, slice_type)
       | DynArray elem_t ->
           (* 动态数组切片 - 返回新的动态数组 *)
           (* 获取源数组的 length *)
           let src_len_ptr = fresh_temp () in
           let src_len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             src_len_ptr (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" src_len src_len_ptr;

           (* 计算起始和结束索引 *)
           let start_idx = match start_opt with
             | Some start_expr ->
                 let (start_v, _) = gen_expr buf ctx start_expr in
                 start_v
             | None -> "0"
           in
           let end_idx = match end_opt with
             | Some end_expr ->
                 let (end_v, _) = gen_expr buf ctx end_expr in
                 end_v
             | None -> src_len
           in

           (* 计算切片长度: end - start *)
           let slice_len = fresh_temp () in
           Printf.bprintf buf "  %s = sub i32 %s, %s\n" slice_len end_idx start_idx;

           (* 创建新的动态数组 - 在堆上分配结构体 *)
           let new_arr = fresh_temp () in
           let new_arr_type = DynArray elem_t in
           let struct_malloc = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 16)\n" struct_malloc;
           Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
             new_arr struct_malloc (llvm_type_to_string new_arr_type);

           (* 分配新数组的数据内存 *)
           let size_bytes = fresh_temp () in
           Printf.bprintf buf "  %s = mul i32 %s, 4\n" size_bytes slice_len;
           let malloc_result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 %s)\n" malloc_result size_bytes;
           let new_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" new_data_ptr malloc_result;

           (* 设置新数组的 capacity 和 length *)
           let cap_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 0\n"
             cap_ptr (llvm_type_to_string new_arr_type) (llvm_type_to_string new_arr_type) new_arr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" slice_len cap_ptr;

           let len_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string new_arr_type) (llvm_type_to_string new_arr_type) new_arr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" slice_len len_ptr;

           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string new_arr_type) (llvm_type_to_string new_arr_type) new_arr;
           Printf.bprintf buf "  store i32* %s, i32** %s\n" new_data_ptr data_ptr_field;

           (* 获取源数组的 data 指针 *)
           let src_data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             src_data_ptr_field (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v;
           let src_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load i32*, i32** %s\n" src_data_ptr src_data_ptr_field;

           (* 循环复制元素 *)
           let counter_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" counter_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" counter_ptr;

           let loop_label = fresh_label "slice.loop" in
           let body_label = fresh_label "slice.body" in
           let end_label = fresh_label "slice.end" in

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           let counter_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" counter_val counter_ptr;

           let cond_temp = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond_temp counter_val slice_len;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_temp body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 计算源索引: start + counter *)
           let src_idx = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, %s\n" src_idx start_idx counter_val;

           (* 从源数组读取 *)
           let src_elem_ptr = fresh_temp () in
           let elem_value = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
             src_elem_ptr src_data_ptr src_idx;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" elem_value src_elem_ptr;

           (* 写入目标数组 *)
           let dst_elem_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
             dst_elem_ptr new_data_ptr counter_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" elem_value dst_elem_ptr;

           (* 递增计数器 *)
           let next_counter = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_counter counter_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_counter counter_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (new_arr, new_arr_type)
       | Ptr I32 when (match arr with EVar _ | EString _ -> true | _ -> false) ->
           (* 字符串切片:调用 string_substring *)
           (* 首先将 i32* 转换为 i8* *)
           let str_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 arr_v;

           (* 计算起始和结束索引 *)
           let start_idx = match start_opt with
             | Some start_expr ->
                 let (start_v, _) = gen_expr buf ctx start_expr in
                 start_v
             | None -> "0"
           in
           let end_idx = match end_opt with
             | Some end_expr ->
                 let (end_v, _) = gen_expr buf ctx end_expr in
                 end_v
             | None ->
                 (* 如果没有指定结束位置,获取字符串长度 *)
                 let len_temp = fresh_temp () in
                 Printf.bprintf buf "  %s = call i32 @string_length(i8* %s)\n"
                   len_temp str_i8;
                 len_temp
           in

           (* 调用 string_substring *)
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @string_substring(i8* %s, i32 %s, i32 %s)\n"
             result str_i8 start_idx end_idx;

           (* 将结果转换回 i32* *)
           let result_i32 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
           (result_i32, Ptr I32)
       | _ ->
           Printf.bprintf buf "  ; slice only works with arrays\n";
           ("0", I32))

  | EListComp (elem_expr, var_name, iter_expr, cond_opt, _) ->
      let (iter_v, iter_t) = gen_expr buf ctx iter_expr in
      (match iter_t with
       | Array (arr_len, elem_t) ->
           (* 创建结果数组,大小与源数组相同 *)
           let result_type = Array (arr_len, I32) in
           let result_temp = fresh_temp () in
           Printf.bprintf buf "  %s = alloca %s\n" result_temp (llvm_type_to_string result_type);

           (* 创建计数器来跟踪实际填充的元素数量 *)
           let count_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" count_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" count_ptr;

           (* 创建循环变量 *)
           let loop_var_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" loop_var_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" loop_var_ptr;

           (* 为迭代变量创建存储空间,使用唯一的变量名避免冲突 *)
           (* 使用临时计数器确保变量名唯一 *)
           incr temp_counter;
           let unique_suffix = !temp_counter in
           let unique_var_name = Printf.sprintf "%s_%d" var_name unique_suffix in
           let iter_var_local = "%" ^ unique_var_name in
           Printf.bprintf buf "  %s = alloca %s\n" iter_var_local (llvm_type_to_string elem_t);

           (* 保存原始变量表和重命名表,以便循环后恢复 *)
           let saved_vars = ctx.variables in
           let saved_renames = ctx.var_renames in
           (* 添加变量重命名:var_name -> unique_var_name *)
           add_variable_with_rename ctx var_name unique_var_name elem_t;

           let loop_label = fresh_label "listcomp.loop" in
           let body_label = fresh_label "listcomp.body" in
           let check_label = fresh_label "listcomp.check" in
           let append_label = fresh_label "listcomp.append" in
           let continue_label = fresh_label "listcomp.continue" in
           let end_label = fresh_label "listcomp.end" in

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           (* 加载循环变量 *)
           let loop_var_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" loop_var_val loop_var_ptr;

           (* 检查是否到达数组末尾 *)
           let cond_temp = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %d\n" cond_temp loop_var_val arr_len;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_temp body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 从源数组加载当前元素 *)
           let src_ptr = fresh_temp () in
           let elem_val = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
             src_ptr (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v loop_var_val;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             elem_val (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) src_ptr;

           (* 存储到迭代变量 *)
           Printf.bprintf buf "  store %s %s, %s* %s\n"
             (llvm_type_to_string elem_t) elem_val (llvm_type_to_string elem_t) iter_var_local;

           (* 检查条件(如果有) *)
           (match cond_opt with
            | Some cond_expr ->
                Printf.bprintf buf "  br label %%%s\n" check_label;
                Printf.bprintf buf "\n%s:\n" check_label;
                let (cond_v, _) = gen_expr buf ctx cond_expr in
                Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v append_label continue_label
            | None ->
                Printf.bprintf buf "  br label %%%s\n" append_label);

           Printf.bprintf buf "\n%s:\n" append_label;

           (* 计算元素表达式 *)
           let (result_val, _) = gen_expr buf ctx elem_expr in

           (* 加载当前计数 *)
           let count_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" count_val count_ptr;

           (* 存储到结果数组 *)
           let dst_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
             dst_ptr (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_temp count_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" result_val dst_ptr;

           (* 递增计数 *)
           let next_count = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_count count_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_count count_ptr;

           Printf.bprintf buf "  br label %%%s\n" continue_label;

           Printf.bprintf buf "\n%s:\n" continue_label;

           (* 递增循环变量 *)
           let next_loop_var = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_loop_var loop_var_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_loop_var loop_var_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (* 恢复变量表和重命名表 *)
           ctx.variables <- saved_vars;
           ctx.var_renames <- saved_renames;

           (result_temp, result_type)
       | DynArray elem_t ->
           (* 动态数组列表推导式 - 返回新的动态数组 *)
           (* 获取源数组的 length *)
           let src_len_ptr = fresh_temp () in
           let src_len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             src_len_ptr (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" src_len src_len_ptr;

           (* 获取源数组的 data 指针 *)
           let src_data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             src_data_ptr_field (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           let src_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load i32*, i32** %s\n" src_data_ptr src_data_ptr_field;

           (* 创建结果动态数组 - 在堆上分配结构体 *)
           let result_arr = fresh_temp () in
           let result_type = DynArray I32 in
           let struct_malloc = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 16)\n" struct_malloc;
           Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
             result_arr struct_malloc (llvm_type_to_string result_type);

           (* 分配结果数组的数据内存 *)
           let size_bytes = fresh_temp () in
           Printf.bprintf buf "  %s = mul i32 %s, 4\n" size_bytes src_len;
           let malloc_result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 %s)\n" malloc_result size_bytes;
           let result_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_data_ptr malloc_result;

           (* 设置结果数组的 capacity *)
           let cap_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 0\n"
             cap_ptr (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" src_len cap_ptr;

           (* 设置结果数组的 length (初始为0,循环中递增) *)
           let len_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" len_ptr;

           (* 设置结果数组的 data 指针 *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string result_type) (llvm_type_to_string result_type) result_arr;
           Printf.bprintf buf "  store i32* %s, i32** %s\n" result_data_ptr data_ptr_field;

           (* 创建计数器来跟踪实际填充的元素数量 *)
           let count_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" count_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" count_ptr;

           (* 创建循环变量 *)
           let loop_var_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" loop_var_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" loop_var_ptr;

           (* 为迭代变量创建存储空间,使用唯一的变量名避免冲突 *)
           incr temp_counter;
           let unique_suffix = !temp_counter in
           let unique_var_name = Printf.sprintf "%s_%d" var_name unique_suffix in
           let iter_var_local = "%" ^ unique_var_name in
           Printf.bprintf buf "  %s = alloca %s\n" iter_var_local (llvm_type_to_string elem_t);

           (* 保存原始变量表和重命名表,以便循环后恢复 *)
           let saved_vars = ctx.variables in
           let saved_renames = ctx.var_renames in
           add_variable_with_rename ctx var_name unique_var_name elem_t;

           let loop_label = fresh_label "listcomp.loop" in
           let body_label = fresh_label "listcomp.body" in
           let check_label = fresh_label "listcomp.check" in
           let append_label = fresh_label "listcomp.append" in
           let continue_label = fresh_label "listcomp.continue" in
           let end_label = fresh_label "listcomp.end" in

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           (* 加载循环变量 *)
           let loop_var_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" loop_var_val loop_var_ptr;

           (* 检查是否到达数组末尾 *)
           let cond_temp = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond_temp loop_var_val src_len;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_temp body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 从源数组加载当前元素 *)
           let src_ptr = fresh_temp () in
           let elem_val = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
             src_ptr src_data_ptr loop_var_val;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             elem_val (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) src_ptr;

           (* 存储到迭代变量 *)
           Printf.bprintf buf "  store %s %s, %s* %s\n"
             (llvm_type_to_string elem_t) elem_val (llvm_type_to_string elem_t) iter_var_local;

           (* 检查条件(如果有) *)
           (match cond_opt with
            | Some cond_expr ->
                Printf.bprintf buf "  br label %%%s\n" check_label;
                Printf.bprintf buf "\n%s:\n" check_label;
                let (cond_v, _) = gen_expr buf ctx cond_expr in
                Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v append_label continue_label
            | None ->
                Printf.bprintf buf "  br label %%%s\n" append_label);

           Printf.bprintf buf "\n%s:\n" append_label;

           (* 计算元素表达式 *)
           let (result_val, _) = gen_expr buf ctx elem_expr in

           (* 加载当前计数 *)
           let count_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" count_val count_ptr;

           (* 存储到结果数组 *)
           let dst_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %s\n"
             dst_ptr result_data_ptr count_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" result_val dst_ptr;

           (* 递增计数 *)
           let next_count = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_count count_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_count count_ptr;

           Printf.bprintf buf "  br label %%%s\n" continue_label;

           Printf.bprintf buf "\n%s:\n" continue_label;

           (* 递增循环变量 *)
           let next_loop_var = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_loop_var loop_var_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_loop_var loop_var_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (* 更新结果数组的 length 为实际填充的元素数量 *)
           let final_count = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" final_count count_ptr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" final_count len_ptr;

           (* 恢复变量表和重命名表 *)
           ctx.variables <- saved_vars;
           ctx.var_renames <- saved_renames;

           (result_arr, result_type)
       | _ ->
           Printf.bprintf buf "  ; list comprehension only works with arrays\n";
           ("0", I32))

  | EIf (cond, then_expr, Some else_expr, _) ->
      let (cond_v, _) = gen_expr buf ctx cond in
      let then_label = fresh_label "if.then" in
      let else_label = fresh_label "if.else" in
      let end_label = fresh_label "if.end" in

      Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v then_label else_label;

      Printf.bprintf buf "\n%s:\n" then_label;
      let (then_v, then_t) = gen_expr buf ctx then_expr in
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" else_label;
      let (else_v, _) = gen_expr buf ctx else_expr in
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" end_label;
      let result = fresh_temp () in
      Printf.bprintf buf "  %s = phi %s [%s, %%%s], [%s, %%%s]\n"
        result (llvm_type_to_string then_t) then_v then_label else_v else_label;
      (result, then_t)

  | EEnumVariant (enum_name, variant_name, args, _) ->
      (* 查找枚举定义 *)
      (match Hashtbl.find_opt enum_registry enum_name with
       | None ->
           (* 枚举不存在，尝试作为方法调用或结构体字段访问处理 *)
           (* enum_name.variant_name(args) 可能是 obj.method(args) 或 obj.field *)
           (match find_variable ctx enum_name with
            | Some (Ptr I32) ->
                (* 首先检查是否是结构体字段访问 (args 为空时) *)
                let struct_name_opt = if List.length args = 0 then
                  Hashtbl.fold (fun sname sdef acc ->
                    if List.exists (fun f -> f.field_name = variant_name) sdef.fields then
                      Some sname
                    else acc
                  ) struct_registry None
                else
                  None
                in

                (match struct_name_opt with
                 | Some struct_name ->
                     (* 是结构体字段访问 *)
                     let obj_v = (match gen_expr buf ctx (EVar (enum_name, {line=0; column=0})) with
                                  | (v, Ptr I32) -> v
                                  | _ -> enum_name) in
                     (match Hashtbl.find_opt struct_registry struct_name with
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
                          ("0", I32)
                      | Some struct_def ->
                          let field_info_opt = List.find_opt (fun f -> f.field_name = variant_name) struct_def.fields in
                          (match field_info_opt with
                           | None ->
                               Printf.bprintf buf "  ; ERROR: Field '%s' not found\n" variant_name;
                               ("0", I32)
                           | Some field_info ->
                               let field_ptr = fresh_temp () in
                               Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                                 field_ptr obj_v field_info.field_index;
                               let result = fresh_temp () in
                               Printf.bprintf buf "  %s = load i32, i32* %s\n" result field_ptr;
                               (result, I32)))
                 | None ->
                     (* 字符串方法调用 *)
                     let obj_v = (match gen_expr buf ctx (EVar (enum_name, {line=0; column=0})) with
                                  | (v, Ptr I32) -> v
                                  | _ -> enum_name) in
                let str_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 obj_v;
                let result = fresh_temp () in
                (match variant_name with
                 | "length" when List.length args = 0 ->
                     Printf.bprintf buf "  %s = call i32 @string_length(i8* %s)\n" result str_i8;
                     (result, I32)
                 | "upper" when List.length args = 0 ->
                     Printf.bprintf buf "  %s = call i8* @string_upper(i8* %s)\n" result str_i8;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                     (result_i32, Ptr I32)
                 | "lower" when List.length args = 0 ->
                     Printf.bprintf buf "  %s = call i8* @string_lower(i8* %s)\n" result str_i8;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                     (result_i32, Ptr I32)
                 | "strip" when List.length args = 0 ->
                     Printf.bprintf buf "  %s = call i8* @string_strip(i8* %s)\n" result str_i8;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                     (result_i32, Ptr I32)
                 | "find" when List.length args = 1 ->
                     let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                     let arg_i8 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                     Printf.bprintf buf "  %s = call i32 @string_find(i8* %s, i8* %s)\n" result str_i8 arg_i8;
                     (result, I32)
                 | "starts_with" when List.length args = 1 ->
                     let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                     let arg_i8 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_starts_with(i8* %s, i8* %s)\n" result_i32 str_i8 arg_i8;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "ends_with" when List.length args = 1 ->
                     let (arg_v, _) = gen_expr buf ctx (List.hd args) in
                     let arg_i8 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" arg_i8 arg_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_ends_with(i8* %s, i8* %s)\n" result_i32 str_i8 arg_i8;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "replace" when List.length args = 2 ->
                     let (old_v, _) = gen_expr buf ctx (List.nth args 0) in
                     let (new_v, _) = gen_expr buf ctx (List.nth args 1) in
                     let old_i8 = fresh_temp () in
                     let new_i8 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" old_i8 old_v;
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" new_i8 new_v;
                     Printf.bprintf buf "  %s = call i8* @string_replace(i8* %s, i8* %s, i8* %s)\n"
                       result str_i8 old_i8 new_i8;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                     (result_i32, Ptr I32)
                 | "split" when List.length args = 1 ->
                     let (delim_v, _) = gen_expr buf ctx (List.hd args) in
                     let delim_i8 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" delim_i8 delim_v;
                     Printf.bprintf buf "  %s = call %%dynarray_ptr* @string_split(i8* %s, i8* %s)\n"
                       result str_i8 delim_i8;
                     (result, DynArrayPtr)
                 | "is_digit" when List.length args = 1 ->
                     let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_digit(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "is_alpha" when List.length args = 1 ->
                     let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_alpha(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "is_whitespace" when List.length args = 1 ->
                     let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i8 @string_char_at(i8* %s, i32 %s)\n" char_temp str_i8 idx_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_whitespace(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | _ ->
                     (* 不是字符串方法，检查是否是结构体方法 *)
                     (match Hashtbl.find_opt struct_method_registry variant_name with
                      | Some struct_name ->
                          (* 是结构体方法调用 *)
                          let mangled_name = Printf.sprintf "%s_%s" struct_name variant_name in
                          let obj_v = (match gen_expr buf ctx (EVar (enum_name, {line=0; column=0})) with
                                       | (v, Ptr I32) -> v
                                       | _ -> enum_name) in

                          (* 生成参数列表 *)
                          let arg_vals_types = List.map (gen_expr buf ctx) args in
                          let arg_vals = List.map fst arg_vals_types in
                          let result = fresh_temp () in

                          (* 调用 StructName_method_name(obj, args...) *)
                          Printf.bprintf buf "  %s = call i32 %s(i32* %s"
                            result (mangle_name mangled_name) obj_v;
                          List.iter (fun arg_val ->
                            Printf.bprintf buf ", i32 %s" arg_val
                          ) arg_vals;
                          Printf.bprintf buf ")\n";
                          (result, I32)
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Unknown string method or struct method: %s\n" variant_name;
                          ("0", I32))))
            | _ ->
                Buffer.add_string buf ("  ; ERROR: Enum " ^ enum_name ^ " not found\n");
                ("0", I32))
       | Some enum_def ->
           (* 查找变体 tag *)
           let variant_opt = List.find_opt (fun v -> v.variant_name = variant_name) enum_def.variants in
           (match variant_opt with
            | None ->
                Buffer.add_string buf ("  ; ERROR: Variant " ^ variant_name ^ " not found\n");
                ("0", I32)
            | Some variant_info ->
                let result = fresh_temp () in
                let arg_count = List.length args in
                if arg_count = 0 then begin
                  (* 简单枚举（无数据） *)
                  Printf.bprintf buf "  %s = call %%enum_t* @enum_create_simple(i32 %d)\n"
                    result variant_info.tag;
                  (result, EnumPtr)
                end else if arg_count = 1 then begin
                  (* 单参数枚举 *)
                  let (arg_val, arg_type) = gen_expr buf ctx (List.hd args) in
                  (match arg_type with
                   | I32 ->
                       Printf.bprintf buf "  %s = call %%enum_t* @enum_create_int(i32 %d, i32 %s)\n"
                         result variant_info.tag arg_val;
                       (result, EnumPtr)
                   | I1 ->
                       Printf.bprintf buf "  %s = call %%enum_t* @enum_create_bool(i32 %d, i1 %s)\n"
                         result variant_info.tag arg_val;
                       (result, EnumPtr)
                   | Ptr I32 ->
                       Printf.bprintf buf "  %s = call %%enum_t* @enum_create_string(i32 %d, i8* %s)\n"
                         result variant_info.tag arg_val;
                       (result, EnumPtr)
                   | _ ->
                       Buffer.add_string buf "  ; Unsupported single arg enum data type\n";
                       Printf.bprintf buf "  %s = call %%enum_t* @enum_create_simple(i32 %d)\n"
                         result variant_info.tag;
                       (result, EnumPtr))
                end else begin
                  (* 多参数枚举 - 使用元组存储 *)
                  Printf.bprintf buf "  ; Creating enum with %d arguments (using tuple)\n" arg_count;

                  (* 创建元组来存储所有参数 *)
                  let tuple_temp = fresh_temp () in
                  Printf.bprintf buf "  %s = call i8* @tuple_create(i32 %d)\n" tuple_temp arg_count;

                  (* 将每个参数存入元组 *)
                  List.iteri (fun i arg_expr ->
                    let (arg_val, arg_type) = gen_expr buf ctx arg_expr in
                    (* 目前假设所有参数都是 i32 类型 *)
                    match arg_type with
                    | I32 ->
                        Printf.bprintf buf "  call void @tuple_set(i8* %s, i32 %d, i32 %s)\n"
                          tuple_temp i arg_val
                    | _ ->
                        Printf.bprintf buf "  ; Warning: Non-i32 arg in multi-arg enum\n"
                  ) args;

                  (* 使用 enum_create_tuple_ptr 直接存储元组指针 *)
                  Printf.bprintf buf "  %s = call %%enum_t* @enum_create_tuple_ptr(i32 %d, i8* %s)\n"
                    result variant_info.tag tuple_temp;
                  (result, EnumPtr)
                end))

  | EMatch (scrut, cases, _) ->
      (* 生成被匹配的值 *)
      let (scrut_v, scrut_t) = gen_expr buf ctx scrut in

      (* 创建基本块标签 *)
      let case_labels = List.mapi (fun i _ ->
        (fresh_label ("match.case" ^ string_of_int i),
         fresh_label ("match.body" ^ string_of_int i))
      ) cases in
      let end_label = fresh_label "match.end" in
      let default_label = fresh_label "match.default" in

      (* 为phi节点准备结果 *)
      let result_temp = fresh_temp () in
      let phi_incoming = ref [] in

      (* 生成第一个case的跳转 *)
      (match case_labels with
       | (first_case, _) :: _ -> Printf.bprintf buf "  br label %%%s\n" first_case
       | [] -> Printf.bprintf buf "  br label %%%s\n" default_label);

      (* 生成每个case *)
      List.iteri (fun i ((pat, guard_opt, body_expr), (case_label, body_label)) ->
        Printf.bprintf buf "\n%s:\n" case_label;

        (* 生成模式匹配条件 *)
        let match_cond = gen_pattern_test buf ctx pat scrut_v scrut_t in

        (* 确定下一个case的标签 *)
        let next_label =
          if i + 1 < List.length case_labels then
            fst (List.nth case_labels (i + 1))
          else
            default_label
        in

        (* 如果有守卫条件，需要额外的标签 *)
        let guard_label = match guard_opt with
          | Some _ -> fresh_label ("match.guard" ^ string_of_int i)
          | None -> body_label
        in

        Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n"
          match_cond guard_label next_label;

        (* 如果有守卫条件，生成守卫检查 *)
        (match guard_opt with
         | Some guard_expr ->
             Printf.bprintf buf "\n%s:\n" guard_label;

             (* 保存当前变量表并绑定模式变量 *)
             let saved_vars = ctx.variables in
             gen_pattern_bindings buf ctx pat scrut_v scrut_t;

             (* 生成守卫条件表达式 *)
             let (guard_v, _guard_t) = gen_expr buf ctx guard_expr in

             (* 根据守卫结果跳转 *)
             Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n"
               guard_v body_label next_label;

             (* 恢复变量表（准备进入body或下一个case） *)
             ctx.variables <- saved_vars
         | None -> ());

        Printf.bprintf buf "\n%s:\n" body_label;

        (* 保存当前变量表 *)
        let saved_vars = ctx.variables in

        (* 绑定模式变量 *)
        gen_pattern_bindings buf ctx pat scrut_v scrut_t;

        (* 生成body表达式 *)
        let (body_v, _body_t) = gen_expr buf ctx body_expr in
        phi_incoming := (body_v, body_label) :: !phi_incoming;

        Printf.bprintf buf "  br label %%%s\n" end_label;

        (* 恢复变量表 *)
        ctx.variables <- saved_vars
      ) (List.combine cases case_labels);

      (* 默认分支（不应该到达，但为了安全） *)
      Printf.bprintf buf "\n%s:\n" default_label;
      Printf.bprintf buf "  ; no pattern matched - unreachable\n";
      Printf.bprintf buf "  unreachable\n";

      (* 结束块和phi节点 *)
      Printf.bprintf buf "\n%s:\n" end_label;
      let result_type = match cases with
        | (_, _, e) :: _ ->
            (* 需要一个临时的上下文来推断类型 *)
            let temp_buf = Buffer.create 256 in
            snd (gen_expr temp_buf ctx e)
        | [] -> I32
      in

      if List.length !phi_incoming > 0 then begin
        Printf.bprintf buf "  %s = phi %s " result_temp (llvm_type_to_string result_type);
        List.iteri (fun i (v, label) ->
          if i > 0 then Printf.bprintf buf ", ";
          Printf.bprintf buf "[%s, %%%s]" v label
        ) (List.rev !phi_incoming);
        Printf.bprintf buf "\n"
      end;

      (result_temp, result_type)

  | EAttr (obj, attr, _) ->
      let (obj_v, obj_t) = gen_expr buf ctx obj in
      (match obj_t with
       | Ptr I32 ->
           (* 可能是结构体字段访问或字符串属性 *)
           (* 首先尝试从变量名推断结构体类型 *)
           let struct_name_opt = match obj with
             | EVar (var_name, _) ->
                 (* 从 var_struct_types 查找 *)
                 (match List.assoc_opt var_name ctx.var_struct_types with
                  | Some sname -> Some sname
                  | None ->
                      (* 如果 var_struct_types 中没有，尝试从所有结构体定义中查找 *)
                      Hashtbl.fold (fun sname sdef acc ->
                        if List.exists (fun f -> f.field_name = attr) sdef.fields then
                          Some sname
                        else acc
                      ) struct_registry None)
             | _ ->
                 (* 如果不是变量，从所有结构体定义中查找匹配的字段 *)
                 Hashtbl.fold (fun sname sdef acc ->
                   if List.exists (fun f -> f.field_name = attr) sdef.fields then
                     Some sname
                   else acc
                 ) struct_registry None
           in

           (match struct_name_opt with
            | Some struct_name ->
                (* 是结构体字段访问 *)
                (match Hashtbl.find_opt struct_registry struct_name with
                 | None ->
                     Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
                     ("0", I32)
                 | Some struct_def ->
                     let field_info_opt = List.find_opt (fun f -> f.field_name = attr) struct_def.fields in
                     (match field_info_opt with
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Field '%s' not found\n" attr;
                          ("0", I32)
                      | Some field_info ->
                          let field_ptr = fresh_temp () in
                          Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                            field_ptr obj_v field_info.field_index;
                          let result = fresh_temp () in
                          Printf.bprintf buf "  %s = load i32, i32* %s\n" result field_ptr;
                          (result, I32)))
            | None ->
                (* 不是结构体字段,尝试字符串属性 *)
                let str_i8 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 obj_v;
                let result = fresh_temp () in
                (match attr with
                 | "length" ->
                     Printf.bprintf buf "  %s = call i32 @string_length(i8* %s)\n" result str_i8;
                     (result, I32)
                 | _ ->
                     Printf.bprintf buf "  ; Unknown attribute: %s\n" attr;
                     ("0", I32)))
       | _ ->
           Printf.bprintf buf "  ; Attribute access on non-supported type\n";
           ("0", I32))

  | EStructLiteral (struct_name, field_inits, _) ->
      (* 结构体字面量：分配结构体并初始化字段 *)
      (match Hashtbl.find_opt struct_registry struct_name with
       | None ->
           Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
           ("0", I32)
       | Some struct_def ->
           (* 在堆上分配结构体 *)
           let field_count = List.length struct_def.fields in
           let struct_size = field_count * 4 in
           let malloc_result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 %d)\n" malloc_result struct_size;

           let struct_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" struct_ptr malloc_result;

           (* 初始化每个字段 *)
           List.iter (fun (field_name, field_expr) ->
             let field_info = List.find (fun f -> f.field_name = field_name) struct_def.fields in
             let (field_val, _field_ty) = gen_expr buf ctx field_expr in

             let field_ptr = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
               field_ptr struct_ptr field_info.field_index;
             Printf.bprintf buf "  store i32 %s, i32* %s\n" field_val field_ptr
           ) field_inits;

           (struct_ptr, Ptr I32))

  | EStructAccess (obj_expr, field_name, _) ->
      (* 结构体字段访问 *)
      let (obj_val, obj_ty) = gen_expr buf ctx obj_expr in
      (match obj_ty with
       | Ptr I32 ->
           (* 需要从对象表达式推断结构体类型 *)
           (* 这里简化处理：假设所有 Ptr I32 的结构体访问都是有效的 *)
           (* 从变量名推断结构体类型 *)
           let struct_name_opt = match obj_expr with
             | EVar (_var_name, _) ->
                 (* 尝试从变量名推断结构体类型 *)
                 (* 这需要在 context 中存储变量到结构体类型的映射 *)
                 (* 暂时遍历所有结构体定义查找匹配的字段 *)
                 Hashtbl.fold (fun sname sdef acc ->
                   if List.exists (fun f -> f.field_name = field_name) sdef.fields then
                     Some sname
                   else acc
                 ) struct_registry None
             | _ -> None
           in

           (match struct_name_opt with
            | None ->
                Printf.bprintf buf "  ; ERROR: Cannot determine struct type for field access\n";
                ("0", I32)
            | Some struct_name ->
                (match Hashtbl.find_opt struct_registry struct_name with
                 | None ->
                     Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
                     ("0", I32)
                 | Some struct_def ->
                     let field_info_opt = List.find_opt (fun f -> f.field_name = field_name) struct_def.fields in
                     (match field_info_opt with
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Field '%s' not found in struct '%s'\n" field_name struct_name;
                          ("0", I32)
                      | Some field_info ->
                          let field_ptr = fresh_temp () in
                          Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                            field_ptr obj_val field_info.field_index;
                          let result = fresh_temp () in
                          Printf.bprintf buf "  %s = load i32, i32* %s\n" result field_ptr;
                          (result, I32))))
       | _ ->
           Printf.bprintf buf "  ; ERROR: Field access on non-struct type\n";
           ("0", I32))

  | _ ->
      Buffer.add_string buf "  ; unsupported expression\n";
      ("0", I32)

(* 生成模式匹配测试条件 *)
and gen_pattern_test buf ctx pat scrut_v scrut_t =
  match pat with
  | PInt n ->
      (match scrut_t with
       | UnionPtr ->
           (* Union 类型：检查是否为 int 且值匹配 *)
           let is_int = fresh_temp () in
           Printf.bprintf buf "  %s = call i1 @union_is_int(%%union_t* %s)\n" is_int scrut_v;
           let int_val = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @union_get_int(%%union_t* %s)\n" int_val scrut_v;
           let val_match = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, %d\n" val_match int_val n;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = and i1 %s, %s\n" cond is_int val_match;
           cond
       | _ ->
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, %d\n" cond scrut_v n;
           cond)
  | PBool b ->
      (match scrut_t with
       | UnionPtr ->
           (* Union 类型：检查是否为 bool 且值匹配 *)
           let is_bool = fresh_temp () in
           Printf.bprintf buf "  %s = call i1 @union_is_bool(%%union_t* %s)\n" is_bool scrut_v;
           let bool_val = fresh_temp () in
           Printf.bprintf buf "  %s = call i1 @union_get_bool(%%union_t* %s)\n" bool_val scrut_v;
           let b_val = if b then "1" else "0" in
           let val_match = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i1 %s, %s\n" val_match bool_val b_val;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = and i1 %s, %s\n" cond is_bool val_match;
           cond
       | _ ->
           let cond = fresh_temp () in
           let b_val = if b then "1" else "0" in
           Printf.bprintf buf "  %s = icmp eq i1 %s, %s\n" cond scrut_v b_val;
           cond)
  | PString s ->
      (match scrut_t with
       | UnionPtr ->
           (* Union 类型：检查是否为 string 且值匹配 *)
           let is_string = fresh_temp () in
           Printf.bprintf buf "  %s = call i1 @union_is_string(%%union_t* %s)\n" is_string scrut_v;
           let str_val = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @union_get_string(%%union_t* %s)\n" str_val scrut_v;

           incr string_counter;
           let str_name = Printf.sprintf "@.str%d" !string_counter in
           let escaped_str = String.escaped s in
           let str_len = String.length s + 1 in
           ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
           let ptr_temp = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
             ptr_temp str_len str_len str_name;
           let cmp_result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @string_compare(i8* %s, i8* %s)\n"
             cmp_result str_val ptr_temp;
           let val_match = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, 0\n" val_match cmp_result;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = and i1 %s, %s\n" cond is_string val_match;
           cond
       | _ ->
           (* 字符串比较需要调用string_compare *)
           incr string_counter;
           let str_name = Printf.sprintf "@.str%d" !string_counter in
           let escaped_str = String.escaped s in
           let str_len = String.length s + 1 in
           ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
           let ptr_temp = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
             ptr_temp str_len str_len str_name;
           let cmp_result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @string_compare(i8* %s, i8* %s)\n"
             cmp_result scrut_v ptr_temp;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, 0\n" cond cmp_result;
           cond)
  | PWildcard ->
      "1"  (* 通配符总是匹配 *)
  | PVar _ ->
      "1"  (* 变量模式总是匹配 *)
  | PEnumVariant (enum_name, variant_name, args) ->
      (match scrut_t with
       | EnumPtr ->
           (* 查找枚举定义和变体tag *)
           (match Hashtbl.find_opt enum_registry enum_name with
            | None ->
                Buffer.add_string buf ("  ; ERROR: Enum " ^ enum_name ^ " not found in pattern\n");
                "0"
            | Some enum_def ->
                let variant_opt = List.find_opt (fun v -> v.variant_name = variant_name) enum_def.variants in
                (match variant_opt with
                 | None ->
                     Buffer.add_string buf ("  ; ERROR: Variant " ^ variant_name ^ " not found in pattern\n");
                     "0"
                 | Some variant_info ->
                     (* 检查枚举的 tag 是否匹配 *)
                     let tag_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @enum_get_tag(%%enum_t* %s)\n" tag_temp scrut_v;
                     let cond = fresh_temp () in
                     Printf.bprintf buf "  %s = icmp eq i32 %s, %d\n" cond tag_temp variant_info.tag;

                     (* 如果有参数模式，还需要检查数据 *)
                     if List.length args > 0 then begin
                       (* TODO: 实现数据提取和递归模式匹配 *)
                       Buffer.add_string buf "  ; TODO: Pattern matching with enum data\n";
                       cond
                     end else
                       cond))
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected enum type for enum pattern\n";
           "0")
  | _ ->
      Printf.bprintf buf "  ; unsupported pattern type\n";
      "0"

(* 生成模式变量绑定 *)
and gen_pattern_bindings buf ctx pat scrut_v scrut_t =
  match pat with
  | PVar name ->
      (* 注意：这里不拆箱，保持 union_t* 类型 *)
      let local = "%" ^ name in
      Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string scrut_t);
      Printf.bprintf buf "  store %s %s, %s* %s\n"
        (llvm_type_to_string scrut_t) scrut_v (llvm_type_to_string scrut_t) local;
      add_variable ctx name scrut_t
  | PTuple pats ->
      (* 元组解包 *)
      List.iteri (fun i p ->
        match p with
        | PVar name ->
            let elem_temp = fresh_temp () in
            Printf.bprintf buf "  %s = call i32 @tuple_get(i8* %s, i32 %d)\n"
              elem_temp scrut_v i;
            let local = "%" ^ name in
            Printf.bprintf buf "  %s = alloca i32\n" local;
            Printf.bprintf buf "  store i32 %s, i32* %s\n" elem_temp local;
            add_variable ctx name I32
        | _ -> ()
      ) pats
  | PEnumVariant (enum_name, variant_name, arg_patterns) ->
      (* 枚举变体数据提取 *)
      (match scrut_t with
       | EnumPtr ->
           (* 查找枚举定义 *)
           (match Hashtbl.find_opt enum_registry enum_name with
            | None ->
                Buffer.add_string buf ("  ; ERROR: Enum " ^ enum_name ^ " not found in binding\n")
            | Some enum_def ->
                let variant_opt = List.find_opt (fun v -> v.variant_name = variant_name) enum_def.variants in
                (match variant_opt with
                 | None ->
                     Buffer.add_string buf ("  ; ERROR: Variant " ^ variant_name ^ " not found in binding\n")
                 | Some _variant_info ->
                     let arg_count = List.length arg_patterns in
                     if arg_count = 0 then begin
                       (* 无参数，不需要绑定 *)
                       ()
                     end else if arg_count = 1 then begin
                       (* 单参数枚举 - 直接提取 *)
                       (match List.hd arg_patterns with
                        | PVar name ->
                            (* 提取单个 int 值 *)
                            let data_temp = fresh_temp () in
                            Printf.bprintf buf "  %s = call i32 @enum_get_int(%%enum_t* %s)\n"
                              data_temp scrut_v;
                            let local = fresh_temp () in  (* 使用唯一名称，如 %t123 *)
                            Printf.bprintf buf "  %s = alloca i32\n" local;
                            Printf.bprintf buf "  store i32 %s, i32* %s\n" data_temp local;
                            (* 去掉 % 前缀再存储 *)
                            let local_name = if String.length local > 0 && local.[0] = '%'
                                             then String.sub local 1 (String.length local - 1)
                                             else local in
                            add_variable_with_rename ctx name local_name I32
                        | _ ->
                            Buffer.add_string buf "  ; Warning: Non-var pattern in single-arg enum\n")
                     end else begin
                       (* 多参数枚举 - 从元组中提取 *)
                       let tuple_temp = fresh_temp () in
                       Printf.bprintf buf "  %s = call i8* @enum_get_data(%%enum_t* %s)\n"
                         tuple_temp scrut_v;

                       (* 逐个提取元组元素 *)
                       List.iteri (fun i pat ->
                         match pat with
                         | PVar name ->
                             let elem_temp = fresh_temp () in
                             Printf.bprintf buf "  %s = call i32 @tuple_get(i8* %s, i32 %d)\n"
                               elem_temp tuple_temp i;
                             let local = fresh_temp () in  (* 使用唯一名称，如 %t123 *)
                             Printf.bprintf buf "  %s = alloca i32\n" local;
                             Printf.bprintf buf "  store i32 %s, i32* %s\n" elem_temp local;
                             (* 去掉 % 前缀再存储 *)
                             let local_name = if String.length local > 0 && local.[0] = '%'
                                              then String.sub local 1 (String.length local - 1)
                                              else local in
                             add_variable_with_rename ctx name local_name I32
                         | _ ->
                             Buffer.add_string buf "  ; Warning: Non-var pattern in multi-arg enum\n"
                       ) arg_patterns
                     end))
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected enum type for enum pattern binding\n")
  | _ -> ()  (* 其他模式不需要绑定变量 *)

let rec gen_statement buf ctx = function
  | SLet (name, type_ann, value, _) ->
      let (v, t) = gen_expr buf ctx value in

      (* 检查是否需要装箱为 union *)
      let (final_v, final_t) =
        match type_ann with
        | Some (TUnion _) when t <> UnionPtr ->
            (* 类型注解是 union，但值不是 union_t*，需要装箱 *)
            Printf.bprintf buf "  ; Boxing value to union\n";
            box_to_union buf ctx v t
        | _ ->
            (v, t)
      in

      let local = "%" ^ name in
      (match final_t with
       | Array (n, elem_t) ->
           (* 数组类型需要逐元素复制 *)
           Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string final_t);
           for i = 0 to n - 1 do
             let src_ptr = fresh_temp () in
             let dst_ptr = fresh_temp () in
             let value_temp = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
               src_ptr (llvm_type_to_string final_t) (llvm_type_to_string final_t) final_v i;
             Printf.bprintf buf "  %s = load %s, %s* %s\n"
               value_temp (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) src_ptr;
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %d\n"
               dst_ptr (llvm_type_to_string final_t) (llvm_type_to_string final_t) local i;
             Printf.bprintf buf "  store %s %s, %s* %s\n"
               (llvm_type_to_string elem_t) value_temp (llvm_type_to_string elem_t) dst_ptr
           done;
           add_variable ctx name final_t
       | DynArray _ ->
           (* 动态数组需要创建一个局部指针变量来存储 *)
           Printf.bprintf buf "  ; %s = dynamic array (already allocated by EList)\n" name;
           Printf.bprintf buf "  %s = alloca %s*\n" local (llvm_type_to_string final_t);
           Printf.bprintf buf "  store %s* %s, %s** %s\n"
             (llvm_type_to_string final_t) final_v (llvm_type_to_string final_t) local;
           add_variable ctx name final_t
       | DynArrayPtr ->
           (* 指针数组 - string_split 返回的类型 *)
           Printf.bprintf buf "  ; %s = pointer array (from string_split)\n" name;
           Printf.bprintf buf "  %s = alloca %%dynarray_ptr*\n" local;
           Printf.bprintf buf "  store %%dynarray_ptr* %s, %%dynarray_ptr** %s\n"
             final_v local;
           add_variable ctx name final_t
       | _ ->
           Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string final_t);
           Printf.bprintf buf "  store %s %s, %s* %s\n"
             (llvm_type_to_string final_t) final_v (llvm_type_to_string final_t) local;
           add_variable ctx name final_t)

  | SLetPat (pat, value, _) ->
      let (v, t) = gen_expr buf ctx value in
      (* 从模式中提取变量并分配值 *)
      let rec gen_pattern_bindings pat value_temp value_type =
        match pat with
        | PVar name ->
            let local = "%" ^ name in
            Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string value_type);
            Printf.bprintf buf "  store %s %s, %s* %s\n"
              (llvm_type_to_string value_type) value_temp (llvm_type_to_string value_type) local;
            add_variable ctx name value_type
        | PTuple pats ->
            (* 对于元组,需要从元组中提取每个元素 *)
            (match value_type with
             | TuplePtr ->
                 List.iteri (fun i p ->
                   let elem_temp = fresh_temp () in
                   let tuple_i8 = fresh_temp () in
                   Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" tuple_i8 value_temp;
                   Printf.bprintf buf "  %s = call i32 @tuple2_i32_get(i8* %s, i32 %d)\n"
                     elem_temp tuple_i8 i;
                   gen_pattern_bindings p elem_temp I32
                 ) pats
             | _ ->
                 Printf.bprintf buf "  ; pattern type mismatch - expected tuple\n")
        | _ ->
            Printf.bprintf buf "  ; unsupported pattern in let binding\n"
      in
      gen_pattern_bindings pat v t

  | SAssign (name, value, _) ->
      let (v, t) = gen_expr buf ctx value in
      let local = "%" ^ name in
      Printf.bprintf buf "  store %s %s, %s* %s\n"
        (llvm_type_to_string t) v (llvm_type_to_string t) local

  | SIndexAssign (arr, idx, value, _) ->
      (* 检查是否是字典赋值 *)
      let is_dict = match arr with
        | EVar _ ->
            (* 检查变量类型,看是否是从字典字面量赋值来的 *)
            (* 我们无法完全确定,所以使用 dict_set *)
            (* 这里可以通过在 context 中添加字典变量跟踪来优化 *)
            false  (* 暂时保守处理 *)
        | EDict _ -> true
        | _ -> false
      in

      let (arr_v, arr_t) = gen_expr buf ctx arr in
      let (idx_v, _) = gen_expr buf ctx idx in
      let (value_v, _) = gen_expr buf ctx value in

      if is_dict || arr_t = DictPtr || arr_t = DictStrPtr || arr_t = Ptr I32 then begin
        (* 字典赋值：使用统一的类型特化函数 *)
        if arr_t = DictStrPtr then
          Printf.bprintf buf "  call void @dict_set_str_int(i8* %s, i8* %s, i32 %s)\n"
            arr_v idx_v value_v
        else
          Printf.bprintf buf "  call void @dict_set_int_int(i8* %s, i32 %s, i32 %s)\n"
            arr_v idx_v value_v
      end else begin
        (match arr_t with
         | Array (_, _) ->
             let ptr_temp = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 %s\n"
               ptr_temp (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v idx_v;
             Printf.bprintf buf "  store i32 %s, i32* %s\n" value_v ptr_temp
         | DynArray elem_t ->
             (* 从动态数组结构中提取 data 指针 *)
             let data_ptr_field = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
               data_ptr_field (llvm_type_to_string arr_t) (llvm_type_to_string arr_t) arr_v;

             (* 加载 data 指针 *)
             let data_ptr = fresh_temp () in
             Printf.bprintf buf "  %s = load %s*, %s** %s\n"
               data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

             (* 使用索引定位元素 *)
             let ptr_temp = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 %s\n"
               ptr_temp (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr idx_v;
             Printf.bprintf buf "  store i32 %s, i32* %s\n" value_v ptr_temp
         | _ -> ())
      end

  | SExpr (e, _) ->
      let _ = gen_expr buf ctx e in
      ()

  | SReturn (Some e, _) ->
      let (v, t) = gen_expr buf ctx e in
      (* 检查是否需要装箱为 union *)
      let (final_v, final_t) = match ctx.function_type with
        | Some UnionPtr when t <> UnionPtr ->
            (* 函数返回 union 但值不是 union,需要装箱 *)
            Printf.bprintf buf "  ; Boxing return value to union\n";
            box_to_union buf ctx v t
        | _ ->
            (v, t)
      in
      (match final_t with
       | DynArray _ | Array _ ->
           (* 数组类型返回指针 (EVar已经load过了) *)
           Printf.bprintf buf "  ret %s* %s\n" (llvm_type_to_string final_t) final_v
       | _ ->
           Printf.bprintf buf "  ret %s %s\n" (llvm_type_to_string final_t) final_v)

  | SReturn (None, _) ->
      Buffer.add_string buf "  ret void\n"

  | SIf (cond, then_body, [], None, _) ->
      let (cond_v, _) = gen_expr buf ctx cond in
      let then_label = fresh_label "if.then" in
      let end_label = fresh_label "if.end" in

      Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v then_label end_label;

      Printf.bprintf buf "\n%s:\n" then_label;
      List.iter (gen_statement buf ctx) then_body;
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" end_label

  | SIf (cond, then_body, [], Some else_body, _) ->
      let (cond_v, _) = gen_expr buf ctx cond in
      let then_label = fresh_label "if.then" in
      let else_label = fresh_label "if.else" in
      let end_label = fresh_label "if.end" in

      Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v then_label else_label;

      Printf.bprintf buf "\n%s:\n" then_label;
      List.iter (gen_statement buf ctx) then_body;
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" else_label;
      List.iter (gen_statement buf ctx) else_body;
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" end_label

  | SWhile (cond, body, _) ->
      let loop_label = fresh_label "while.loop" in
      let body_label = fresh_label "while.body" in
      let end_label = fresh_label "while.end" in

      Printf.bprintf buf "  br label %%%s\n" loop_label;
      Printf.bprintf buf "\n%s:\n" loop_label;
      let (cond_v, _) = gen_expr buf ctx cond in
      Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v body_label end_label;

      Printf.bprintf buf "\n%s:\n" body_label;
      List.iter (gen_statement buf ctx) body;
      Printf.bprintf buf "  br label %%%s\n" loop_label;

      Printf.bprintf buf "\n%s:\n" end_label

  | SFor (pat, iter, body, _) ->
      let (iter_v, iter_t) = gen_expr buf ctx iter in
      (match iter_t with
       | DynArray elem_t ->
           (* 获取动态数组的长度 *)
           let len_ptr = fresh_temp () in
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;

           (* 获取数据指针 *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           let data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

           (* 创建循环索引 *)
           let index_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" index_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" index_ptr;

           let loop_label = fresh_label "for.loop" in
           let body_label = fresh_label "for.body" in
           let end_label = fresh_label "for.end" in

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           (* 检查循环条件 *)
           let index_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" index_val index_ptr;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond index_val len;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 从数组中加载当前元素 *)
           let elem_ptr = fresh_temp () in
           let elem_val = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 %s\n"
             elem_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr index_val;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             elem_val (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) elem_ptr;

           (* 保存原始变量表 *)
           let saved_vars = ctx.variables in

           (* 根据模式绑定变量 *)
           let rec gen_for_pattern_bindings pat value_temp value_type =
             match pat with
             | PVar name ->
                 let local = "%" ^ name in
                 Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string value_type);
                 Printf.bprintf buf "  store %s %s, %s* %s\n"
                   (llvm_type_to_string value_type) value_temp (llvm_type_to_string value_type) local;
                 add_variable ctx name value_type
             | PTuple pats ->
                 (* 元素是元组类型，需要提取各个字段 *)
                 (match value_type with
                  | I32 ->
                      (* 假设这是一个 TuplePtr, 需要先转换为指针 *)
                      (* 注意: dict_items 返回的动态数组的元素是 i32*, 实际上是元组指针 *)
                      (* 这里我们需要将 i32 value 当作 TuplePtr 使用 *)
                      List.iteri (fun i p ->
                        let elem_temp = fresh_temp () in
                        (* 需要将 i32 值转换为 i32* 指针 *)
                        let tuple_ptr = fresh_temp () in
                        Printf.bprintf buf "  %s = inttoptr i32 %s to i32*\n" tuple_ptr value_temp;
                        let tuple_i8 = fresh_temp () in
                        Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" tuple_i8 tuple_ptr;
                        Printf.bprintf buf "  %s = call i32 @tuple2_i32_get(i8* %s, i32 %d)\n"
                          elem_temp tuple_i8 i;
                        gen_for_pattern_bindings p elem_temp I32
                      ) pats
                  | TuplePtr ->
                      List.iteri (fun i p ->
                        let elem_temp = fresh_temp () in
                        let tuple_i8 = fresh_temp () in
                        Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" tuple_i8 value_temp;
                        Printf.bprintf buf "  %s = call i32 @tuple2_i32_get(i8* %s, i32 %d)\n"
                          elem_temp tuple_i8 i;
                        gen_for_pattern_bindings p elem_temp I32
                      ) pats
                  | _ ->
                      Printf.bprintf buf "  ; pattern type mismatch in for loop\n")
             | _ ->
                 Printf.bprintf buf "  ; unsupported pattern in for loop\n"
           in
           gen_for_pattern_bindings pat elem_val elem_t;

           (* 生成循环体 *)
           List.iter (gen_statement buf ctx) body;

           (* 递增索引 *)
           let next_index = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_index index_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_index index_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (* 恢复变量表 *)
           ctx.variables <- saved_vars

       | DynArrayPtr ->
           (* 处理指针数组 (如 dict_items 返回的元组指针数组) *)
           let len_ptr = fresh_temp () in
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;

           (* 获取数据指针 i64* *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string iter_t) (llvm_type_to_string iter_t) iter_v;
           let data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load i64*, i64** %s\n"
             data_ptr data_ptr_field;

           (* 创建循环索引 *)
           let index_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = alloca i32\n" index_ptr;
           Printf.bprintf buf "  store i32 0, i32* %s\n" index_ptr;

           let loop_label = fresh_label "for.loop" in
           let body_label = fresh_label "for.body" in
           let end_label = fresh_label "for.end" in

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" loop_label;

           (* 检查循环条件 *)
           let index_val = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" index_val index_ptr;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp slt i32 %s, %s\n" cond index_val len;
           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond body_label end_label;

           Printf.bprintf buf "\n%s:\n" body_label;

           (* 从数组中加载当前元素 i64指针值 *)
           let elem_ptr = fresh_temp () in
           let elem_val = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr i64, i64* %s, i32 %s\n"
             elem_ptr data_ptr index_val;
           Printf.bprintf buf "  %s = load i64, i64* %s\n"
             elem_val elem_ptr;

           (* 保存原始变量表 *)
           let saved_vars = ctx.variables in

           (* 根据模式绑定变量 *)
           let gen_for_pattern_bindings_ptr pat value_temp =
             match pat with
             | PVar name ->
                 (* 对于简单变量,存储i64值 *)
                 let local = "%" ^ name in
                 Printf.bprintf buf "  %s = alloca i64\n" local;
                 Printf.bprintf buf "  store i64 %s, i64* %s\n" value_temp local;
                 add_variable ctx name I64
             | PTuple pats ->
                 (* 元组解包: value_temp是i64指针值,需要转换为tuple2_i32* *)
                 List.iteri (fun i p ->
                   let elem_temp = fresh_temp () in
                   (* 将 i64 转换为指针 *)
                   let tuple_ptr = fresh_temp () in
                   Printf.bprintf buf "  %s = inttoptr i64 %s to i32*\n" tuple_ptr value_temp;
                   let tuple_i8 = fresh_temp () in
                   Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" tuple_i8 tuple_ptr;
                   Printf.bprintf buf "  %s = call i32 @tuple2_i32_get(i8* %s, i32 %d)\n"
                     elem_temp tuple_i8 i;
                   (* 元组元素是i32 *)
                   (match p with
                    | PVar name ->
                        let local = "%" ^ name in
                        Printf.bprintf buf "  %s = alloca i32\n" local;
                        Printf.bprintf buf "  store i32 %s, i32* %s\n" elem_temp local;
                        add_variable ctx name I32
                    | _ ->
                        Printf.bprintf buf "  ; nested tuple patterns not yet supported\n")
                 ) pats
             | _ ->
                 Printf.bprintf buf "  ; unsupported pattern in for loop\n"
           in
           gen_for_pattern_bindings_ptr pat elem_val;

           (* 生成循环体 *)
           List.iter (gen_statement buf ctx) body;

           (* 递增索引 *)
           let next_index = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" next_index index_val;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" next_index index_ptr;

           Printf.bprintf buf "  br label %%%s\n" loop_label;
           Printf.bprintf buf "\n%s:\n" end_label;

           (* 恢复变量表 *)
           ctx.variables <- saved_vars

       | _ ->
           Printf.bprintf buf "  ; for loops only work with dynamic arrays\n")

  | SEnum (name, _type_params, variants, _) ->
      (* 注册枚举定义 *)
      let variant_infos = List.mapi (fun i variant ->
        match variant with
        | VSimple (vname, _) ->
            { variant_name = vname; tag = i; has_data = false }
        | VTuple (vname, types, _) ->
            { variant_name = vname; tag = i; has_data = (List.length types > 0) }
      ) variants in
      let enum_def = { enum_name = name; variants = variant_infos } in
      Hashtbl.replace enum_registry name enum_def;
      Buffer.add_string buf ("  ; enum definition: " ^ name ^ "\n")

  | SMatch (scrut, cases, _) ->
      (* 生成被匹配的值 *)
      let (scrut_v, scrut_t) = gen_expr buf ctx scrut in

      (* 创建基本块标签 *)
      let case_labels = List.mapi (fun i _ ->
        (fresh_label ("match.case" ^ string_of_int i),
         fresh_label ("match.body" ^ string_of_int i))
      ) cases in
      let end_label = fresh_label "match.end" in
      let default_label = fresh_label "match.default" in

      (* 生成第一个case的跳转 *)
      (match case_labels with
       | (first_case, _) :: _ -> Printf.bprintf buf "  br label %%%s\n" first_case
       | [] -> Printf.bprintf buf "  br label %%%s\n" default_label);

      (* 生成每个case *)
      List.iteri (fun i ((pat, guard_opt, body_stmts), (case_label, body_label)) ->
        Printf.bprintf buf "\n%s:\n" case_label;

        (* 生成模式匹配条件 *)
        let match_cond = gen_pattern_test buf ctx pat scrut_v scrut_t in

        (* 确定下一个case的标签 *)
        let next_label =
          if i + 1 < List.length case_labels then
            fst (List.nth case_labels (i + 1))
          else
            default_label
        in

        (* 如果有守卫条件，需要额外的标签 *)
        let guard_label = match guard_opt with
          | Some _ -> fresh_label ("match.guard" ^ string_of_int i)
          | None -> body_label
        in

        Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n"
          match_cond guard_label next_label;

        (* 如果有守卫条件，生成守卫检查 *)
        (match guard_opt with
         | Some guard_expr ->
             Printf.bprintf buf "\n%s:\n" guard_label;

             (* 保存当前变量表并绑定模式变量 *)
             let saved_vars = ctx.variables in
             gen_pattern_bindings buf ctx pat scrut_v scrut_t;

             (* 生成守卫条件表达式 *)
             let (guard_v, _guard_t) = gen_expr buf ctx guard_expr in

             (* 根据守卫结果跳转 *)
             Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n"
               guard_v body_label next_label;

             (* 恢复变量表（准备进入body或下一个case） *)
             ctx.variables <- saved_vars
         | None -> ());

        Printf.bprintf buf "\n%s:\n" body_label;

        (* 保存当前变量表 *)
        let saved_vars = ctx.variables in

        (* 绑定模式变量 *)
        gen_pattern_bindings buf ctx pat scrut_v scrut_t;

        (* 生成body语句 *)
        List.iter (gen_statement buf ctx) body_stmts;

        (* 如果最后一条语句不是 return,才生成跳转到 end_label *)
        let has_return = match List.rev body_stmts with
          | SReturn _ :: _ -> true
          | _ -> false
        in
        if not has_return then
          Printf.bprintf buf "  br label %%%s\n" end_label;

        (* 恢复变量表 *)
        ctx.variables <- saved_vars
      ) (List.combine cases case_labels);

      (* 默认分支（不应该到达，但为了安全） *)
      Printf.bprintf buf "\n%s:\n" default_label;
      Printf.bprintf buf "  ; no pattern matched - unreachable\n";
      Printf.bprintf buf "  unreachable\n";

      (* 结束块 - 检查是否所有分支都有 return *)
      let all_have_return = List.for_all (fun (_, _, body_stmts) ->
        match List.rev body_stmts with
        | SReturn _ :: _ -> true
        | _ -> false
      ) cases in

      Printf.bprintf buf "\n%s:\n" end_label;
      if all_have_return then
        (* 所有分支都有 return,end 块不可达 *)
        Printf.bprintf buf "  unreachable\n"

  | SInterface _ ->
      (* 接口定义不生成代码,只是声明 *)
      Buffer.add_string buf "  ; interface definition (no code generated)\n"

  | SImpl _ ->
      (* impl块在程序级别处理,这里不生成代码 *)
      Buffer.add_string buf "  ; impl block (handled at program level)\n"

  | SStruct (name, _type_params, members, _) ->
      (* 结构体定义：注册到 struct_registry *)
      (* 只处理字段，忽略方法（方法暂时不生成代码） *)
      let field_list = List.filter_map (function
        | Ast.SField field -> Some field
        | Ast.SMethod _ -> None
      ) members in

      let field_infos = List.mapi (fun i field ->
        let field_ty = type_expr_to_llvm_type field.Ast.field_type in
        {
          field_name = field.Ast.field_name;
          field_index = i;
          field_llvm_type = field_ty;
        }
      ) field_list in

      let struct_def = {
        struct_name = name;
        fields = field_infos;
      } in

      Hashtbl.replace struct_registry name struct_def;
      Printf.bprintf buf "  ; struct %s defined with %d fields\n" name (List.length field_list)

  | SFieldAssign (obj_expr, field_name, value_expr, _) ->
      (* 字段赋值：obj.field = value *)
      let (obj_val, obj_ty) = gen_expr buf ctx obj_expr in
      let (value_val, _value_ty) = gen_expr buf ctx value_expr in

      (match obj_ty with
       | Ptr I32 ->
           (* 从对象表达式推断结构体类型 *)
           let struct_name_opt = match obj_expr with
             | EVar (_var_name, _) ->
                 (* 遍历所有结构体定义查找匹配的字段 *)
                 Hashtbl.fold (fun sname sdef acc ->
                   if List.exists (fun f -> f.field_name = field_name) sdef.fields then
                     Some sname
                   else acc
                 ) struct_registry None
             | _ -> None
           in

           (match struct_name_opt with
            | None ->
                Printf.bprintf buf "  ; ERROR: Cannot determine struct type for field assignment\n"
            | Some struct_name ->
                (match Hashtbl.find_opt struct_registry struct_name with
                 | None ->
                     Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name
                 | Some struct_def ->
                     let field_info_opt = List.find_opt (fun f -> f.field_name = field_name) struct_def.fields in
                     (match field_info_opt with
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Field '%s' not found in struct '%s'\n" field_name struct_name
                      | Some field_info ->
                          let field_ptr = fresh_temp () in
                          Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                            field_ptr obj_val field_info.field_index;
                          Printf.bprintf buf "  store i32 %s, i32* %s\n" value_val field_ptr)))
       | _ ->
           Printf.bprintf buf "  ; ERROR: Field assignment on non-struct type\n")

  | _ ->
      Buffer.add_string buf "  ; unsupported statement\n"

let gen_function buf ctx name params ret_ty body =
  temp_counter := 0;
  label_counter := 0;

  ctx.variables <- [];

  let ret_type = match ret_ty with
    | Some t -> type_expr_to_llvm_type t
    | None -> I32
  in

  (* 设置当前函数返回类型到 context *)
  ctx.function_type <- Some ret_type;

  (* 收集参数类型并存储到 context *)
  let param_types = List.map (fun (_, pty) ->
    match pty with
    | Some t -> type_expr_to_llvm_type t
    | None -> I32
  ) params in
  ctx.function_param_types <- (name, param_types) :: ctx.function_param_types;

  (* 对于数组和动态数组返回类型,返回指针 *)
  let ret_type_str = match ret_type with
    | DynArray _ | Array _ -> (llvm_type_to_string ret_type) ^ "*"
    | _ -> llvm_type_to_string ret_type
  in

  Printf.bprintf buf "\ndefine %s %s(" ret_type_str (mangle_name name);

  List.iteri (fun i (pname, pty) ->
    if i > 0 then Buffer.add_string buf ", ";
    let param_type = match pty with
      | Some t -> type_expr_to_llvm_type t
      | None -> I32
    in
    (* 数组和动态数组按引用传递,基本类型按值传递 *)
    (match param_type with
     | DynArray _ | Array _ ->
         Printf.bprintf buf "%s* %%%s.param" (llvm_type_to_string param_type) pname
     | _ ->
         Printf.bprintf buf "%s %%%s.param" (llvm_type_to_string param_type) pname);
    add_variable ctx pname param_type
  ) params;

  Buffer.add_string buf ") {\n";
  Buffer.add_string buf "entry:\n";

  List.iter (fun (pname, pty) ->
    let param_type = match pty with
      | Some t -> type_expr_to_llvm_type t
      | None -> I32
    in
    let local = "%" ^ pname in
    match param_type with
    | DynArray _ | Array _ ->
        (* 数组和动态数组参数按引用传递 *)
        Printf.bprintf buf "  %s = alloca %s*\n" local (llvm_type_to_string param_type);
        Printf.bprintf buf "  store %s* %%%s.param, %s** %s\n"
          (llvm_type_to_string param_type) pname (llvm_type_to_string param_type) local
    | _ ->
        Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string param_type);
        Printf.bprintf buf "  store %s %%%s.param, %s* %s\n"
          (llvm_type_to_string param_type) pname (llvm_type_to_string param_type) local
  ) params;

  List.iter (gen_statement buf ctx) body;

  (* 检查是否需要默认 return *)
  let rec has_return_stmt = function
    | SReturn _ -> true
    | SMatch (_, cases, _) ->
        (* match 的所有分支都有 return *)
        List.for_all (fun (_, _, body_stmts) ->
          List.exists has_return_stmt body_stmts
        ) cases
    | SIf (_, then_body, _, Some else_body, _) ->
        (* if-else 两个分支都有 return *)
        List.exists has_return_stmt then_body && List.exists has_return_stmt else_body
    | _ -> false
  in

  let needs_return = match List.rev body with
    | [] -> true
    | last :: _ -> not (has_return_stmt last)
  in

  (* TODO: 在返回前释放所有 GC 对象（需要更复杂的生命周期分析）
     暂时依赖 gc_cleanup 清理所有泄漏对象 *)
  (*
  List.iter (fun obj ->
    Buffer.add_string buf ("  call void @gc_release(i8* bitcast(%union_t* " ^ obj ^ " to i8*))\n")
  ) (List.rev ctx.gc_objects);
  *)

  (if needs_return then
    match ret_type with
    | UnionPtr ->
        (* Union 返回类型默认返回 null *)
        Buffer.add_string buf "  ret %union_t* null\n"
    | _ ->
        Printf.bprintf buf "  ret %s 0\n" (llvm_type_to_string ret_type));

  Buffer.add_string buf "}\n"

let gen_program program =
  temp_counter := 0;
  label_counter := 0;

  let buf = create 8192 in

  Buffer.add_string buf "; Dream Language - LLVM IR Output\n\n";

  (* Type definitions *)
  Buffer.add_string buf "; Union type definition\n";
  Buffer.add_string buf "%union_t = type { i32, i64 }\n";
  Buffer.add_string buf "; Pointer array type definition (for storing pointers)\n";
  Buffer.add_string buf "%dynarray_ptr = type { i32, i32, i64* }\n\n";

  (* Runtime functions *)
  Buffer.add_string buf "declare void @print_int(i32)\n";
  Buffer.add_string buf "declare void @print_bool(i1)\n";
  Buffer.add_string buf "declare void @print_string(i8*)\n";
  Buffer.add_string buf "declare i32 @printf(i8*, ...)\n";

  (* Memory management functions *)
  Buffer.add_string buf "declare i8* @malloc(i32)\n";
  Buffer.add_string buf "declare void @free(i8*)\n";
  Buffer.add_string buf "declare void @llvm.memcpy.p0i8.p0i8.i32(i8*, i8*, i32, i1)\n";

  (* GC functions (from runtime/memory.c) *)
  Buffer.add_string buf "; GC functions\n";
  Buffer.add_string buf "declare i8* @gc_alloc(i32, i32)\n";
  Buffer.add_string buf "declare void @gc_retain(i8*)\n";
  Buffer.add_string buf "declare void @gc_release(i8*)\n";
  Buffer.add_string buf "declare void @gc_cleanup()\n";

  (* Dynamic array functions *)
  Buffer.add_string buf "declare void @append_i32({ i32, i32, i32* }*, i32)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @create_dynarray_i32(i32)\n";
  Buffer.add_string buf "declare void @free_dynarray_i32({ i32, i32, i32* }*)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @slice_dynarray_i32({ i32, i32, i32* }*, i32, i32)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @concat_dynarray_i32({ i32, i32, i32* }*, { i32, i32, i32* }*)\n";

  (* String functions *)
  Buffer.add_string buf "; String functions\n";
  Buffer.add_string buf "declare i32 @string_length(i8*)\n";
  Buffer.add_string buf "declare i8 @string_char_at(i8*, i32)\n";
  Buffer.add_string buf "declare i8* @string_concat(i8*, i8*)\n";
  Buffer.add_string buf "declare i8* @string_substring(i8*, i32, i32)\n";
  Buffer.add_string buf "declare i32 @string_find(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @string_compare(i8*, i8*)\n";
  Buffer.add_string buf "declare i8* @string_upper(i8*)\n";
  Buffer.add_string buf "declare i8* @string_lower(i8*)\n";
  Buffer.add_string buf "declare i8* @string_strip(i8*)\n";
  Buffer.add_string buf "declare i32 @string_starts_with(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @string_ends_with(i8*, i8*)\n";
  Buffer.add_string buf "declare i8* @string_replace(i8*, i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @string_is_digit(i8)\n";
  Buffer.add_string buf "declare i32 @string_is_alpha(i8)\n";
  Buffer.add_string buf "declare i32 @string_is_whitespace(i8)\n";
  Buffer.add_string buf "declare %dynarray_ptr* @string_split(i8*, i8*)\n";
  Buffer.add_string buf "declare i8* @string_join(%dynarray_ptr*, i8*)\n";

  (* File I/O functions *)
  Buffer.add_string buf "; File I/O functions\n";
  Buffer.add_string buf "declare i8* @file_read(i8*)\n";
  Buffer.add_string buf "declare i32 @file_write(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @file_exists(i8*)\n";
  Buffer.add_string buf "declare i32 @file_append(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @file_delete(i8*)\n";

  (* Dictionary functions - Unified Generic API *)
  Buffer.add_string buf "; Unified Generic Dictionary API\n";
  Buffer.add_string buf "declare i8* @dict_create(i32, i32, i32)\n";
  Buffer.add_string buf "declare void @dict_set_int_int(i8*, i32, i32)\n";
  Buffer.add_string buf "declare void @dict_set_int_str(i8*, i32, i8*)\n";
  Buffer.add_string buf "declare void @dict_set_int_ptr(i8*, i32, i8*)\n";
  Buffer.add_string buf "declare void @dict_set_str_int(i8*, i8*, i32)\n";
  Buffer.add_string buf "declare void @dict_set_str_str(i8*, i8*, i8*)\n";
  Buffer.add_string buf "declare void @dict_set_str_ptr(i8*, i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @dict_get_int_int(i8*, i32, i32*)\n";
  Buffer.add_string buf "declare i8* @dict_get_int_str(i8*, i32, i32*)\n";
  Buffer.add_string buf "declare i8* @dict_get_int_ptr(i8*, i32, i32*)\n";
  Buffer.add_string buf "declare i32 @dict_get_str_int(i8*, i8*, i32*)\n";
  Buffer.add_string buf "declare i8* @dict_get_str_str(i8*, i8*, i32*)\n";
  Buffer.add_string buf "declare i8* @dict_get_str_ptr(i8*, i8*, i32*)\n";
  Buffer.add_string buf "declare i32 @dict_has_int(i8*, i32)\n";
  Buffer.add_string buf "declare i32 @dict_has_str(i8*, i8*)\n";
  Buffer.add_string buf "declare void @dict_remove_int(i8*, i32)\n";
  Buffer.add_string buf "declare void @dict_remove_str(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @dict_size(i8*)\n";
  Buffer.add_string buf "declare void @dict_free(i8*)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @dict_keys(i8*)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @dict_values(i8*)\n";
  Buffer.add_string buf "declare { i32, i32, i64* }* @dict_items(i8*)\n\n";

  (* Tuple functions *)
  Buffer.add_string buf "; Tuple functions\n";
  Buffer.add_string buf "declare i8* @create_tuple2_i32(i32, i32)\n";
  Buffer.add_string buf "declare i32 @tuple2_i32_get(i8*, i32)\n";
  Buffer.add_string buf "declare void @tuple2_i32_free(i8*)\n";
  Buffer.add_string buf "declare i8* @tuple_create(i32)\n";
  Buffer.add_string buf "declare void @tuple_set(i8*, i32, i32)\n";
  Buffer.add_string buf "declare i32 @tuple_get(i8*, i32)\n";
  Buffer.add_string buf "declare i32 @tuple_size(i8*)\n";
  Buffer.add_string buf "declare void @tuple_free(i8*)\n\n";

  (* Union functions *)
  Buffer.add_string buf "; Union functions\n";
  Buffer.add_string buf "declare %union_t* @union_create_int(i32)\n";
  Buffer.add_string buf "declare %union_t* @union_create_float(double)\n";
  Buffer.add_string buf "declare %union_t* @union_create_string(i8*)\n";
  Buffer.add_string buf "declare %union_t* @union_create_bool(i1)\n";
  Buffer.add_string buf "declare %union_t* @union_create_none()\n";
  Buffer.add_string buf "declare i1 @union_is_int(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_float(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_string(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_bool(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_none(%union_t*)\n";
  Buffer.add_string buf "declare i32 @union_get_int(%union_t*)\n";
  Buffer.add_string buf "declare double @union_get_float(%union_t*)\n";
  Buffer.add_string buf "declare i8* @union_get_string(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_get_bool(%union_t*)\n";
  Buffer.add_string buf "declare void @union_free(%union_t*)\n";
  Buffer.add_string buf "declare %union_t* @union_clone(%union_t*)\n";
  Buffer.add_string buf "declare void @union_print_value(%union_t*)\n\n";

  (* Enum functions *)
  Buffer.add_string buf "; Enum functions\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_simple(i32)\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_int(i32, i32)\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_string(i32, i8*)\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_bool(i32, i1)\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_tuple(i32, i8*, i64)\n";
  Buffer.add_string buf "declare %enum_t* @enum_create_tuple_ptr(i32, i8*)\n";
  Buffer.add_string buf "declare i1 @enum_is_variant(%enum_t*, i32)\n";
  Buffer.add_string buf "declare i32 @enum_get_tag(%enum_t*)\n";
  Buffer.add_string buf "declare i32 @enum_get_int(%enum_t*)\n";
  Buffer.add_string buf "declare i8* @enum_get_string(%enum_t*)\n";
  Buffer.add_string buf "declare i1 @enum_get_bool(%enum_t*)\n";
  Buffer.add_string buf "declare i8* @enum_get_data(%enum_t*)\n";
  Buffer.add_string buf "declare void @enum_free(%enum_t*)\n";
  Buffer.add_string buf "declare void @enum_print_value(%enum_t*)\n\n";

  (* 类型定义 *)
  Buffer.add_string buf "; Type definitions\n";
  Buffer.add_string buf "%enum_t = type opaque\n\n";

  let ctx = create_context () in
  let code_buf = create 8192 in

  (* 扫描所有函数定义并注册它们的签名 *)
  List.iter (function
    | SDef (name, _, _, ret_ty, _, _) ->
        let ret_type = match ret_ty with
          | Some t -> type_expr_to_llvm_type t
          | None -> I32
        in
        ctx.function_signatures <- (name, ret_type) :: ctx.function_signatures
    | _ -> ()
  ) program;

  let has_main = List.exists (function
    | SDef ("main", _, _, _, _, _) -> true
    | _ -> false) program
  in

  if has_main then begin
    (* 先注册所有结构体定义 *)
    List.iter (function
      | SStruct (name, _, members, _) ->
          let field_list = List.filter_map (function
            | Ast.SField field -> Some field
            | _ -> None
          ) members in
          let field_infos = List.mapi (fun i field ->
            let field_ty = type_expr_to_llvm_type field.Ast.field_type in
            {
              field_name = field.Ast.field_name;
              field_index = i;
              field_llvm_type = field_ty;
            }
          ) field_list in
          let struct_def = {
            struct_name = name;
            fields = field_infos;
          } in
          Hashtbl.replace struct_registry name struct_def
      | _ -> ()
    ) program;

    (* 生成所有函数定义 *)
    List.iter (function
      | SDef (name, _type_params, params, ret_ty, body, _) ->
          gen_function code_buf ctx name params ret_ty body
      | _ -> ()
    ) program;

    (* 生成所有结构体方法 *)
    List.iter (function
      | SStruct (struct_name, _, members, _) ->
          List.iter (function
            | Ast.SMethod (method_name, _type_params, params, ret_ty_opt, body, _) ->
                (* 注册方法到 struct_method_registry *)
                Hashtbl.replace struct_method_registry method_name struct_name;
                let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                (* 如果第一个参数是 self,给它加上结构体类型标注并记录到 context *)
                let params_with_types = match params with
                  | (pname, None) :: rest when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      (pname, Some (TStruct (struct_name, []))) :: rest
                  | (pname, Some _) :: _ when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      params  (* 如果已经有类型标注,保留 *)
                  | _ -> params
                in
                gen_function code_buf ctx mangled_name params_with_types ret_ty_opt body;
                (* 方法生成后清理 var_struct_types *)
                ctx.var_struct_types <- []
            | _ -> ()
          ) members
      | _ -> ()
    ) program;

    (* 生成所有impl块的方法 *)
    List.iter (function
      | SImpl (impl_block, _) ->
          let target_type_str = match impl_block.impl_target with
            | TVar name -> name
            | TInt -> "int"
            | TFloat -> "float"
            | TString -> "string"
            | TBool -> "bool"
            | _ -> "unknown"
          in
          (match impl_block.impl_interface with
           | Some interface_name ->
               List.iter (function
                 | ImplMethod (method_name, _, params, ret_ty_opt, body, _) ->
                     let mangled_name = Printf.sprintf "%s_%s_for_%s"
                       interface_name method_name target_type_str in
                     gen_function code_buf ctx mangled_name params ret_ty_opt body
                 | _ -> ()
               ) impl_block.impl_members
           | None ->
               (* 没有指定接口的impl块，暂时不处理 *)
               ())
      | _ -> ()
    ) program
  end else begin
    (* 先注册所有结构体定义 *)
    List.iter (function
      | SStruct (name, _, members, _) ->
          let field_list = List.filter_map (function
            | Ast.SField field -> Some field
            | _ -> None
          ) members in
          let field_infos = List.mapi (fun i field ->
            let field_ty = type_expr_to_llvm_type field.Ast.field_type in
            {
              field_name = field.Ast.field_name;
              field_index = i;
              field_llvm_type = field_ty;
            }
          ) field_list in
          let struct_def = {
            struct_name = name;
            fields = field_infos;
          } in
          Hashtbl.replace struct_registry name struct_def
      | _ -> ()
    ) program;

    (* 生成所有函数定义 *)
    List.iter (function
      | SDef (name, _type_params, params, ret_ty, body, _) ->
          gen_function code_buf ctx name params ret_ty body
      | _ -> ()
    ) program;

    (* 生成所有结构体方法 *)
    List.iter (function
      | SStruct (struct_name, _, members, _) ->
          List.iter (function
            | Ast.SMethod (method_name, _type_params, params, ret_ty_opt, body, _) ->
                (* 注册方法到 struct_method_registry *)
                Hashtbl.replace struct_method_registry method_name struct_name;
                let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                (* 如果第一个参数是 self,给它加上结构体类型标注并记录到 context *)
                let params_with_types = match params with
                  | (pname, None) :: rest when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      (pname, Some (TStruct (struct_name, []))) :: rest
                  | (pname, Some _) :: _ when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      params  (* 如果已经有类型标注,保留 *)
                  | _ -> params
                in
                gen_function code_buf ctx mangled_name params_with_types ret_ty_opt body;
                (* 方法生成后清理 var_struct_types *)
                ctx.var_struct_types <- []
            | _ -> ()
          ) members
      | _ -> ()
    ) program;

    (* 生成所有impl块的方法 *)
    List.iter (function
      | SImpl (impl_block, _) ->
          let target_type_str = match impl_block.impl_target with
            | TVar name -> name
            | TInt -> "int"
            | TFloat -> "float"
            | TString -> "string"
            | TBool -> "bool"
            | _ -> "unknown"
          in
          (match impl_block.impl_interface with
           | Some interface_name ->
               List.iter (function
                 | ImplMethod (method_name, _, params, ret_ty_opt, body, _) ->
                     let mangled_name = Printf.sprintf "%s_%s_for_%s"
                       interface_name method_name target_type_str in
                     gen_function code_buf ctx mangled_name params ret_ty_opt body
                 | _ -> ()
               ) impl_block.impl_members
           | None ->
               (* 没有指定接口的impl块，暂时不处理 *)
               ())
      | _ -> ()
    ) program;

    Buffer.add_string code_buf "\ndefine i32 @main() {\nentry:\n";
    List.iter (function
      | SDef _ -> ()
      | stmt -> gen_statement code_buf ctx stmt
    ) program;
    (* TODO: 在返回前释放所有 GC 对象（需要更复杂的生命周期分析）
       暂时依赖 gc_cleanup 清理所有泄漏对象 *)
    (*
    List.iter (fun obj ->
      Buffer.add_string code_buf ("  call void @gc_release(i8* bitcast(%union_t* " ^ obj ^ " to i8*))\n")
    ) (List.rev ctx.gc_objects);
    *)
    Buffer.add_string code_buf "  ret i32 0\n}\n"
  end;

  List.iter (fun (str_name, escaped_str, str_len) ->
    Printf.bprintf buf "%s = private unnamed_addr constant [%d x i8] c\"%s\\00\"\n"
      str_name str_len escaped_str
  ) (List.rev ctx.string_literals);

  if ctx.string_literals <> [] then Buffer.add_string buf "\n";

  Buffer.add_buffer buf code_buf;
  contents buf
