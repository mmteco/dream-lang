(* 表达式代码生成 *)

open Ast
open Cg_types
open Cg_utils

(* 将 AST 的 type_expr 转换为代码生成器的 cg_type *)
let ast_type_to_cg_type = function
  | TInt -> I32
  | TFloat -> I64  (* 浮点数暂时用 i64 表示（double 的位模式）*)
  | TStr -> Ptr I32  (* 字符串指针 *)
  | TBytes -> DynArrayPtr  (* 字节数组 *)
  | TBool -> I1
  | TVar _name -> I32  (* 类型变量默认为 i32，实际应该从环境中查找 *)
  | TList _elem_ty -> DynArrayPtr
  | TTuple _elem_tys -> TuplePtr  (* 元组用 tuple pointer *)
  | TDict (_key_ty, _val_ty) -> DictPtr  (* 字典用 dict pointer *)
  | TFunc (_params, _ret) -> Ptr I32  (* 函数指针 *)
  | TUnion _tys -> UnionPtr  (* Union 类型 *)
  | TEnum (_name, _) -> EnumPtr  (* 枚举类型 *)
  | TStruct (name, _) -> StructPtr name  (* 结构体指针，保留结构体名称 *)
  | _ -> I32  (* 其他类型默认 i32 *)

(* LLVM IR 字符串转义：不使用 String.escaped，因为它会双重转义 *)
(* 返回 (转义后的字符串, 实际字节数) *)
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

let rec gen_expr buf ctx = function
  | EInt (n, _) ->
      (string_of_int n, I32)

  | EBool (b, _) ->
      ((if b then "1" else "0" : llvm_value), I1)

  | ERune (c, _) ->
      (* rune 是 unsigned 32-bit Unicode codepoint *)
      (string_of_int (Char.code c), U32)

  | EByte (b, _) ->
      (* byte 是 unsigned 8-bit *)
      (string_of_int b, U8)

  | EString (s, _) ->
      incr string_counter;
      let str_name = Printf.sprintf "@.str%d" !string_counter in
      let (escaped_str, str_len) = llvm_escape_string s in
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
      let (v2, t2_raw) = gen_expr buf ctx e2 in
      (* 修正字符串字面量的类型：如果是 EString 则类型应该是 i8* 而不是 i32* *)
      let t2 = match (e2, t2_raw) with
        | (EString _, Ptr I32) -> Ptr I8  (* 字符串字面量实际是 i8* *)
        | _ -> t2_raw
      in
      let result = fresh_temp () in

      (* 首先检查是否有运算符重载 (仅对结构体类型) *)
      let overload_result =
        match t1 with
        | StructPtr type_name ->
            (* 获取运算符对应的接口名和方法名 *)
            let interface_name = match op with
              | Add -> Some "Add" | Sub -> Some "Sub" | Mul -> Some "Mul"
              | Div -> Some "Div" | Mod -> Some "Mod" | Eq | Neq -> Some "Eq"
              | Lt | Gt | Lte | Gte -> Some "Ord"
              | _ -> None
            in
            let method_name = match op with
              | Add -> Some "add" | Sub -> Some "sub" | Mul -> Some "mul"
              | Div -> Some "div" | Mod -> Some "mod" | Eq -> Some "eq"
              | Neq -> Some "neq" | Lt -> Some "lt" | Gt -> Some "gt"
              | Lte -> Some "lte" | Gte -> Some "gte"
              | _ -> None
            in
            Cg_types.debug_print "DEBUG: Looking for operator overload: type=%s, iface=%s, method=%s\n"
              type_name
              (match interface_name with Some s -> s | None -> "None")
              (match method_name with Some s -> s | None -> "None");
            (match interface_name, method_name with
             | Some iface, Some meth ->
                 let result = Hashtbl.find_opt impl_method_registry (type_name, iface, meth) in
                 Cg_types.debug_print "DEBUG: Registry lookup result: %s\n"
                   (match result with Some name -> name | None -> "Not found");
                 result
             | _ -> None)
        | _ -> None
      in

      (* 如果找到运算符重载实现，使用它；否则使用内置运算符 *)
      (match overload_result with
       | Some mangled_name ->
           (* 使用运算符重载 *)
           (* 查找方法的参数类型 *)
           let param_types = Hashtbl.find_opt impl_method_param_types mangled_name in
           Cg_types.debug_print "DEBUG: Looking up param types for %s: %s\n"
             mangled_name
             (match param_types with
              | Some types -> String.concat ", " (List.map llvm_type_to_string types)
              | None -> "Not found");
           let (param2_value, param2_type) =
             match param_types with
             | Some types when List.length types >= 2 ->
                 (* 第二个参数的期望类型 *)
                 let expected_type = List.nth types 1 in
                 Cg_types.debug_print "DEBUG: Expected type for param2: %s, actual: %s\n"
                   (llvm_type_to_string expected_type)
                   (llvm_type_to_string t2);
                 (* 如果期望 Union 类型但实际不是，则装箱 *)
                 if expected_type = UnionPtr && t2 <> UnionPtr then begin
                   Printf.bprintf buf "  ; Boxing parameter 2 to union\n";
                   (* 提取 t2 的结构体名称（如果是结构体） *)
                   let type_name_opt = match t2 with
                     | StructPtr name -> Some name
                     | _ -> None
                   in
                   box_to_union buf ctx v2 t2 type_name_opt
                 end else
                   (v2, t2)
             | _ ->
                 (* 找不到参数类型信息，保持原样 *)
                 (v2, t2)
           in
           let param2_type_str = llvm_type_to_string param2_type in
           (* 从注册表查找返回类型，如果找不到则默认使用 i32* *)
           let ret_llvm_type =
             try Hashtbl.find impl_method_return_types mangled_name
             with Not_found -> StructPtr ""  (* 默认为结构体指针 *)
           in
           let ret_type_str = llvm_type_to_string ret_llvm_type in
           Printf.bprintf buf "  %s = call %s %s(i32* %s, %s %s)\n"
             result ret_type_str (mangle_name mangled_name) v1 param2_type_str param2_value;
           (result, ret_llvm_type)
       | None ->
           (* 使用内置运算符或默认处理 *)
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
           (result, t1)))

  | EUnOp (Not, e, _) ->
      let (v, t) = gen_expr buf ctx e in
      let result = fresh_temp () in
      Printf.bprintf buf "  %s = xor %s %s, 1\n"
        result (llvm_type_to_string t) v;
      (result, t)

  | EUnOp (Neg, e, _) ->
      let (v, t) = gen_expr buf ctx e in
      let result = fresh_temp () in

      (* 检查是否有运算符重载 *)
      let overload_result =
        match t with
        | StructPtr type_name ->
            Hashtbl.find_opt impl_method_registry (type_name, "Neg", "neg")
        | _ -> None
      in

      (match overload_result with
       | Some mangled_name ->
           (* 使用运算符重载 *)
           Printf.bprintf buf "  %s = call i32* %s(i32* %s)\n"
             result (mangle_name mangled_name) v;
           (result, t)
       | None ->
           (* 使用内置取负 *)
           Printf.bprintf buf "  %s = sub %s 0, %s\n"
             result (llvm_type_to_string t) v;
           (result, t))

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
                (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                let rune_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_digit(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "is_alpha" when List.length args = 1 ->
                let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                let rune_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_alpha(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "is_whitespace" when List.length args = 1 ->
                let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                let rune_temp = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                let char_temp = fresh_temp () in
                Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @string_is_whitespace(i8 %s)\n" result_i32 char_temp;
                Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                (result, I1)
            | "substring" when List.length args = 2 ->
                let (start_v, _) = gen_expr buf ctx (List.nth args 0) in
                let (end_v, _) = gen_expr buf ctx (List.nth args 1) in
                Printf.bprintf buf "  %s = call i8* @string_substring(i8* %s, i32 %s, i32 %s)\n"
                  result str_i8 start_v end_v;
                let result_i32 = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                (result_i32, Ptr I32)
            | _ ->
                (* 不是字符串方法，可能是结构体字段或方法调用 *)
                (match obj_t with
                 | StructPtr struct_name ->
                     (* 先检查是否是字段访问（直接字段或通过嵌入提升的字段） *)
                     let is_field =
                       match Hashtbl.find_opt struct_registry struct_name with
                       | None -> false
                       | Some struct_def ->
                           (* 检查直接字段 *)
                           if List.exists (fun f -> f.field_name = method_name) struct_def.fields then
                             true
                           else
                             (* 检查嵌入字段提升 *)
                             match List.find_opt (fun f -> Hashtbl.mem struct_registry f.field_name) struct_def.fields with
                             | None -> false
                             | Some embedded_field_info ->
                                 match Hashtbl.find_opt struct_registry embedded_field_info.field_name with
                                 | None -> false
                                 | Some embedded_struct_def ->
                                     List.exists (fun f -> f.field_name = method_name) embedded_struct_def.fields
                     in

                     if is_field then
                       (* 这实际上是字段访问，直接求值 EAttr *)
                       gen_expr buf ctx (EAttr (obj, method_name, { line = 0; column = 0 }))
                     else
                       (* 真正的方法调用 *)
                       let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                       let arg_vals_types = List.map (gen_expr buf ctx) args in
                       let arg_vals = List.map fst arg_vals_types in
                       let result = fresh_temp () in
                       Printf.bprintf buf "  %s = call i32 %s(i32* %s"
                         result (mangle_name mangled_name) obj_v;
                       List.iter (fun arg_val ->
                         Printf.bprintf buf ", i32 %s" arg_val
                       ) arg_vals;
                       Printf.bprintf buf ")\n";
                       (result, I32)
                 | _ ->
                     (* 如果不是 StructPtr,回退到旧的全局查找方式 *)
                     (match Hashtbl.find_opt struct_method_registry method_name with
                      | Some struct_name ->
                          let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                          let arg_vals_types = List.map (gen_expr buf ctx) args in
                          let arg_vals = List.map fst arg_vals_types in
                          let result = fresh_temp () in
                          Printf.bprintf buf "  %s = call i32 %s(i32* %s"
                            result (mangle_name mangled_name) obj_v;
                          List.iter (fun arg_val ->
                            Printf.bprintf buf ", i32 %s" arg_val
                          ) arg_vals;
                          Printf.bprintf buf ")\n";
                          (result, I32)
                      | None ->
                          Printf.bprintf buf "  ; Unknown string method or struct method: %s\n" method_name;
                          ("0", I32))))
       | _ ->
           Printf.bprintf buf "  ; Method call on non-string type\n";
           ("0", I32))

  | ECall (EVar ("chr", _), [arg], _) ->
      (* chr(int) -> rune: 将整数转换为Unicode字符 *)
      (* int 是 i32, rune 是 u32，需要转换 *)
      let (v, _) = gen_expr buf ctx arg in
      (v, U32)

  | ECall (EVar ("ord", _), [arg], _) ->
      (* ord(rune) -> int: 将Unicode字符转换为整数 *)
      (* rune 是 u32, int 是 i32，需要转换 *)
      let (v, _) = gen_expr buf ctx arg in
      (v, I32)

  | ECall (EVar ("print", _), [EString (s, _)], _) ->
      incr string_counter;
      let str_name = Printf.sprintf "@.str%d" !string_counter in
      let (escaped_str, str_len) = llvm_escape_string s in
      ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
      let ptr_temp = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
        ptr_temp str_len str_len str_name;
      Printf.bprintf buf "  call void @print_string(i8* %s)\n" ptr_temp;
      ("0", Void)

  | ECall (EVar ("print", _), [arg], _) ->
      let (v, t) = gen_expr buf ctx arg in
      (match t with
       | I32 ->
           Printf.bprintf buf "  call void @print_int(i32 %s)\n" v;
       | U32 ->
           (* Rune 类型：打印 Unicode codepoint *)
           Printf.bprintf buf "  call void @print_rune(i32 %s)\n" v;
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

  | ECall (EVar ("array", _), [list_expr], _) ->
      (* array(list) - 从 list 创建固定长度数组（内容可变但不能增长） *)
      let (list_v, list_t) = gen_expr buf ctx list_expr in
      (match list_t with
       | DynArray elem_t ->
           (* 获取 list 的 length *)
           let len_ptr = fresh_temp () in
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string list_t) (llvm_type_to_string list_t) list_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;

           (* 获取 list 的 data 指针 *)
           let data_ptr_field = fresh_temp () in
           let src_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string list_t) (llvm_type_to_string list_t) list_v;
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             src_data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

           (* 分配新的 DynArray 结构 *)
           let result_arr = fresh_temp () in
           let array_type = DynArray elem_t in
           let struct_malloc = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 16)\n" struct_malloc;
           Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
             result_arr struct_malloc (llvm_type_to_string array_type);

           (* 分配新的数据内存并复制 *)
           let elem_size = 4 in  (* 假设元素大小为 4 字节 *)
           let size_bytes = fresh_temp () in
           Printf.bprintf buf "  %s = mul i32 %s, %d\n" size_bytes len elem_size;
           let data_malloc = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @malloc(i32 %s)\n" data_malloc size_bytes;
           let new_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
             new_data_ptr data_malloc (llvm_type_to_string elem_t);

           (* 复制数据 *)
           let src_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast %s* %s to i8*\n"
             src_i8 (llvm_type_to_string elem_t) src_data_ptr;
           Printf.bprintf buf "  call void @llvm.memcpy.p0i8.p0i8.i32(i8* %s, i8* %s, i32 %s, i1 false)\n"
             data_malloc src_i8 size_bytes;

           (* 设置 capacity = length (固定大小) *)
           let cap_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 0\n"
             cap_ptr (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" len cap_ptr;

           (* 设置 length *)
           let len_ptr2 = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr2 (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" len len_ptr2;

           (* 设置 data 指针 *)
           let data_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_field (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
           Printf.bprintf buf "  store %s* %s, %s** %s\n"
             (llvm_type_to_string elem_t) new_data_ptr (llvm_type_to_string elem_t) data_field;

           (result_arr, array_type)
       | _ ->
           Printf.bprintf buf "  ; array() only works with lists\n";
           ("0", I32))

  | ECall (EVar ("array_new", _), [size_expr], _) ->
      (* array_new(n) - 创建长度为 n 的数组，填充 None (null/0) *)
      let (size_v, _) = gen_expr buf ctx size_expr in
      (* 默认元素类型为 Ptr I32 (Option 类型) *)
      let elem_t = Ptr I32 in
      let array_type = DynArray elem_t in

      (* 分配 DynArray 结构 *)
      let result_arr = fresh_temp () in
      let struct_malloc = fresh_temp () in
      Printf.bprintf buf "  %s = call i8* @malloc(i32 16)\n" struct_malloc;
      Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
        result_arr struct_malloc (llvm_type_to_string array_type);

      (* 分配数据内存 *)
      let size_bytes = fresh_temp () in
      Printf.bprintf buf "  %s = mul i32 %s, 4\n" size_bytes size_v;
      let data_malloc = fresh_temp () in
      Printf.bprintf buf "  %s = call i8* @malloc(i32 %s)\n" data_malloc size_bytes;

      (* 用 0 (null/None) 填充 *)
      Printf.bprintf buf "  call void @llvm.memset.p0i8.i32(i8* %s, i8 0, i32 %s, i1 false)\n"
        data_malloc size_bytes;

      let data_ptr = fresh_temp () in
      Printf.bprintf buf "  %s = bitcast i8* %s to %s*\n"
        data_ptr data_malloc (llvm_type_to_string elem_t);

      (* 设置 capacity = length *)
      let cap_ptr = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 0\n"
        cap_ptr (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
      Printf.bprintf buf "  store i32 %s, i32* %s\n" size_v cap_ptr;

      (* 设置 length *)
      let len_ptr = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
        len_ptr (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
      Printf.bprintf buf "  store i32 %s, i32* %s\n" size_v len_ptr;

      (* 设置 data 指针 *)
      let data_field = fresh_temp () in
      Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
        data_field (llvm_type_to_string array_type) (llvm_type_to_string array_type) result_arr;
      Printf.bprintf buf "  store %s* %s, %s** %s\n"
        (llvm_type_to_string elem_t) data_ptr (llvm_type_to_string elem_t) data_field;

      (result_arr, array_type)

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

  (* C Runtime 函数统一处理 - 需要类型转换 i32* <-> i8* *)
  | ECall (EVar (fname, _), args, _) when Env.is_c_runtime_function fname ->
      (* 根据函数名分发到具体的处理逻辑 *)
      (match (fname, args) with
       | ("__c_file_read", [path_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @__c_file_read(i8* %s)\n" result_i8 path_i8;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result result_i8;
           (result, Ptr I32)

       | ("__c_file_write", [path_expr; content_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let (content_v, _) = gen_expr buf ctx content_expr in
           let path_i8 = fresh_temp () in
           let content_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" content_i8 content_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_write(i8* %s, i8* %s)\n"
             result path_i8 content_i8;
           (result, I32)

       | ("__c_file_exists", [path_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_exists(i8* %s)\n" result path_i8;
           (result, I32)

       | ("__c_file_append", [path_expr; content_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let (content_v, _) = gen_expr buf ctx content_expr in
           let path_i8 = fresh_temp () in
           let content_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" content_i8 content_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_append(i8* %s, i8* %s)\n"
             result path_i8 content_i8;
           (result, I32)

       | ("__c_file_delete", [path_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_delete(i8* %s)\n" result path_i8;
           (result, I32)

       | ("__c_file_read_bytes", [path_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @__c_file_read_bytes(i8* %s)\n" result path_i8;
           (result, Ptr U8)

       | ("__c_file_write_bytes", [path_expr; data_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let (data_v, _) = gen_expr buf ctx data_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_write_bytes(i8* %s, i8* %s)\n"
             result path_i8 data_v;
           (result, I32)

       | ("__c_file_append_bytes", [path_expr; data_expr]) ->
           let (path_v, _) = gen_expr buf ctx path_expr in
           let (data_v, _) = gen_expr buf ctx data_expr in
           let path_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" path_i8 path_v;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @__c_file_append_bytes(i8* %s, i8* %s)\n"
             result path_i8 data_v;
           (result, I32)

       | _ ->
           failwith (Printf.sprintf "Unsupported C runtime function: %s with %d args" fname (List.length args))
      )

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
            let type_name_opt = match t with
              | StructPtr name -> Some name
              | _ -> None
            in
            box_to_union buf ctx v t type_name_opt
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
           (* 字符串索引:返回单字符字符串 str，等价于 substring(idx, idx+1) *)
           let str_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i32* %s to i8*\n" str_i8 arr_v;
           (* 计算 end_idx = idx + 1 *)
           let end_idx = fresh_temp () in
           Printf.bprintf buf "  %s = add i32 %s, 1\n" end_idx idx_v;
           (* 调用 string_substring 返回单字符字符串 *)
           let result_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @string_substring(i8* %s, i32 %s, i32 %s)\n"
             result_i8 str_i8 idx_v end_idx;
           let result = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result result_i8;
           (result, Ptr I32)
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
            | Some (StructPtr struct_name) ->
                (* 是结构体方法或字段访问 *)
                let obj_v = (match gen_expr buf ctx (EVar (enum_name, {line=0; column=0})) with
                             | (v, StructPtr _) -> v
                             | (v, _) -> v) in

                if List.length args = 0 then begin
                  (* 可能是字段访问 *)
                  (match Hashtbl.find_opt struct_registry struct_name with
                   | None ->
                       Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
                       ("0", I32)
                   | Some struct_def ->
                       let field_info_opt = List.find_opt (fun f -> f.field_name = variant_name) struct_def.fields in
                       (match field_info_opt with
                        | Some field_info ->
                            (* 直接字段访问 *)
                            let field_ptr = fresh_temp () in
                            Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                              field_ptr obj_v field_info.field_index;
                            let result = fresh_temp () in
                            Printf.bprintf buf "  %s = load i32, i32* %s\n" result field_ptr;
                            (result, I32)
                        | None ->
                            (* 不是直接字段,尝试字段提升 *)
                            let embedded_field_opt = List.find_opt (fun f ->
                              Hashtbl.mem struct_registry f.field_name
                            ) struct_def.fields in
                            (match embedded_field_opt with
                             | None ->
                                 (* 不是字段，是无参数方法 *)
                                 let mangled_name = Printf.sprintf "%s_%s" struct_name variant_name in
                                 let result = fresh_temp () in
                                 Printf.bprintf buf "  %s = call i32 %s(i32* %s)\n"
                                   result (mangle_name mangled_name) obj_v;
                                 (result, I32)
                             | Some embedded_field_info ->
                                 (match Hashtbl.find_opt struct_registry embedded_field_info.field_name with
                                  | None ->
                                      Printf.bprintf buf "  ; ERROR: Embedded struct '%s' not found\n" embedded_field_info.field_name;
                                      ("0", I32)
                                  | Some embedded_struct_def ->
                                      let embedded_attr_info_opt = List.find_opt (fun f -> f.field_name = variant_name) embedded_struct_def.fields in
                                      (match embedded_attr_info_opt with
                                       | None ->
                                           (* 嵌入结构体中也没有这个字段，是方法调用 *)
                                           let mangled_name = Printf.sprintf "%s_%s" struct_name variant_name in
                                           let result = fresh_temp () in
                                           Printf.bprintf buf "  %s = call i32 %s(i32* %s)\n"
                                             result (mangle_name mangled_name) obj_v;
                                           (result, I32)
                                       | Some embedded_attr_info ->
                                           (* 通过嵌入字段提升访问 *)
                                           let embedded_ptr_field = fresh_temp () in
                                           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                                             embedded_ptr_field obj_v embedded_field_info.field_index;
                                           let embedded_ptr_int = fresh_temp () in
                                           Printf.bprintf buf "  %s = load i32, i32* %s\n" embedded_ptr_int embedded_ptr_field;
                                           let embedded_ptr = fresh_temp () in
                                           Printf.bprintf buf "  %s = inttoptr i32 %s to i32*\n" embedded_ptr embedded_ptr_int;
                                           let attr_ptr = fresh_temp () in
                                           Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                                             attr_ptr embedded_ptr embedded_attr_info.field_index;
                                           let result = fresh_temp () in
                                           Printf.bprintf buf "  %s = load i32, i32* %s\n" result attr_ptr;
                                           (result, I32))))))
                end else begin
                  (* 方法调用 *)
                  let mangled_name = Printf.sprintf "%s_%s" struct_name variant_name in
                  let arg_vals_types = List.map (gen_expr buf ctx) args in
                  let arg_vals = List.map fst arg_vals_types in
                  let result = fresh_temp () in
                  Printf.bprintf buf "  %s = call i32 %s(i32* %s"
                    result (mangle_name mangled_name) obj_v;
                  List.iter (fun arg_val ->
                    Printf.bprintf buf ", i32 %s" arg_val
                  ) arg_vals;
                  Printf.bprintf buf ")\n";
                  (result, I32)
                end
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
                     (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                     let rune_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_digit(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "is_alpha" when List.length args = 1 ->
                     let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                     (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                     let rune_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_alpha(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "is_whitespace" when List.length args = 1 ->
                     let (idx_v, _) = gen_expr buf ctx (List.hd args) in
                     (* string_char_at 返回 rune (i32)，需要转换为 byte (i8) *)
                     let rune_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_char_at(i8* %s, i32 %s)\n" rune_temp str_i8 idx_v;
                     let char_temp = fresh_temp () in
                     Printf.bprintf buf "  %s = trunc i32 %s to i8\n" char_temp rune_temp;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = call i32 @string_is_whitespace(i8 %s)\n" result_i32 char_temp;
                     Printf.bprintf buf "  %s = trunc i32 %s to i1\n" result result_i32;
                     (result, I1)
                 | "substring" when List.length args = 2 ->
                     let (start_v, _) = gen_expr buf ctx (List.nth args 0) in
                     let (end_v, _) = gen_expr buf ctx (List.nth args 1) in
                     Printf.bprintf buf "  %s = call i8* @string_substring(i8* %s, i32 %s, i32 %s)\n"
                       result str_i8 start_v end_v;
                     let result_i32 = fresh_temp () in
                     Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" result_i32 result;
                     (result_i32, Ptr I32)
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
      (* 特殊处理 match type of 的情况 *)
      let (scrut_v, scrut_t, scrut_var_name) = match scrut with
        | ETypeOf (inner_expr, _) ->
            (* match type of expr 的情况 *)
            (* 生成内部表达式以获取其真实值和类型 *)
            let (inner_v, inner_t) = gen_expr buf ctx inner_expr in
            (* 提取变量名 *)
            let var_name = match inner_expr with
              | EVar (name, _) -> Some name
              | _ -> None
            in
            (* 返回内部表达式的值和类型，用于模式匹配和绑定 *)
            (inner_v, inner_t, var_name)
        | EVar (name, _) ->
            (* match 普通变量 *)
            let (scrut_v, scrut_t) = gen_expr buf ctx scrut in
            (scrut_v, scrut_t, Some name)
        | _ ->
            (* 其他情况 *)
            let (scrut_v, scrut_t) = gen_expr buf ctx scrut in
            (scrut_v, scrut_t, None)
      in

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
      List.iteri (fun i ((pat, guard_opt, body), (case_label, body_label)) ->
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

             (* 保存当前变量表和重命名表并绑定模式变量 *)
             let saved_vars = ctx.variables in
             let saved_renames = ctx.var_renames in
             gen_pattern_bindings buf ctx pat scrut_v scrut_t scrut_var_name;

             (* 生成守卫条件表达式 *)
             let (guard_v, _guard_t) = gen_expr buf ctx guard_expr in

             (* 根据守卫结果跳转 *)
             Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n"
               guard_v body_label next_label;

             (* 恢复变量表和重命名表（准备进入body或下一个case） *)
             ctx.variables <- saved_vars;
             ctx.var_renames <- saved_renames
         | None -> ());

        Printf.bprintf buf "\n%s:\n" body_label;

        (* 保存当前变量表和重命名表 *)
        let saved_vars = ctx.variables in
        let saved_renames = ctx.var_renames in

        (* 绑定模式变量 *)
        gen_pattern_bindings buf ctx pat scrut_v scrut_t scrut_var_name;

        (* 生成body，根据类型处理 *)
        let (body_v, body_t) = match body with
          | MExpr expr ->
              (* 单行表达式，包括嵌套 match *)
              gen_expr buf ctx expr
          | MStmts stmts ->
              (* 多行语句块 *)
              (* 由于循环依赖问题，这里直接处理简单的赋值语句 *)
              (match stmts with
               | [SExpr (expr, _)] ->
                   (* 单个表达式，包括嵌套 match *)
                   gen_expr buf ctx expr
               | [SAssign (name, value, _)] ->
                   (* 单个赋值语句 *)
                   let (val_v, val_t) = gen_expr buf ctx value in
                   (match find_variable ctx name with
                    | Some _ ->
                        let local = "%" ^ name in
                        Printf.bprintf buf "  store %s %s, %s* %s\n"
                          (llvm_type_to_string val_t) val_v (llvm_type_to_string val_t) local;
                        ("0", Void)  (* 赋值返回 void *)
                    | None ->
                        Printf.bprintf buf "  ; ERROR: Variable %s not found\n" name;
                        ("0", I32))
               | _ ->
                   (* 其他复杂语句块，返回 None (用 0 表示) *)
                   (* TODO: 解决循环依赖后完整支持 *)
                   ("0", I32))
        in

        (* 创建桥接块，用于统一处理控制流 *)
        (* 这样不管 body 是简单表达式还是嵌套 match，都从桥接块跳转到 end_label *)
        let bridge_label = fresh_label ("match.bridge" ^ string_of_int i) in
        Printf.bprintf buf "  br label %%%s\n" bridge_label;
        Printf.bprintf buf "\n%s:\n" bridge_label;

        (* 如果这个分支返回 void，将其转换为返回 0 (None) *)
        let normalized_v = if body_t = Void then "0" else body_v in
        phi_incoming := (normalized_v, bridge_label) :: !phi_incoming;

        Printf.bprintf buf "  br label %%%s\n" end_label;

        (* 恢复变量表和重命名表 *)
        ctx.variables <- saved_vars;
        ctx.var_renames <- saved_renames
      ) (List.combine cases case_labels);

      (* 默认分支（不应该到达，但为了安全） *)
      Printf.bprintf buf "\n%s:\n" default_label;
      Printf.bprintf buf "  ; no pattern matched - unreachable\n";
      Printf.bprintf buf "  unreachable\n";

      (* 结束块和phi节点 *)
      Printf.bprintf buf "\n%s:\n" end_label;
      let result_type = match cases with
        | (_, _, body) :: _ ->
            (* 需要一个临时的上下文来推断类型 *)
            let temp_buf = Buffer.create 256 in
            (match body with
             | MExpr e ->
                 let ty = snd (gen_expr temp_buf ctx e) in
                 (* 如果是 void，转换为 I32 (None) *)
                 if ty = Void then I32 else ty
             | MStmts stmts ->
                 (match List.rev stmts with
                  | SExpr (e, _) :: _ ->
                      let ty = snd (gen_expr temp_buf ctx e) in
                      (* 如果是 void，转换为 I32 (None) *)
                      if ty = Void then I32 else ty
                  | _ -> I32))  (* 多个语句默认返回 I32 (None) *)
        | [] -> I32
      in

      (* 总是生成 phi 节点 (void 已经被转换为 I32) *)
      if List.length !phi_incoming > 0 then begin
        Printf.bprintf buf "  %s = phi %s " result_temp (llvm_type_to_string result_type);
        List.iteri (fun i (v, label) ->
          if i > 0 then Printf.bprintf buf ", ";
          Printf.bprintf buf "[%s, %%%s]" v label
        ) (List.rev !phi_incoming);
        Printf.bprintf buf "\n"
      end;

      (* 检查所有分支是否都有 return 语句 *)
      let all_branches_return = List.for_all (fun (_, _, body) ->
        match body with
        | MExpr _ -> false  (* 单行表达式不算 return *)
        | MStmts stmts ->
            let rec has_return = function
              | SReturn _ -> true
              | SIf (_, then_body, _, Some else_body, _) ->
                  List.exists has_return then_body && List.exists has_return else_body
              | _ -> false
            in
            (match List.rev stmts with
             | [] -> false
             | last :: _ -> has_return last)
      ) cases in

      (* 如果所有分支都有 return，match.end 块不可达，需要添加 unreachable *)
      if all_branches_return then
        Printf.bprintf buf "  unreachable\n";

      (result_temp, result_type)

  | EAttr (obj, attr, _) ->
      let (obj_v, obj_t) = gen_expr buf ctx obj in
      (match obj_t with
       | StructPtr struct_name ->
           (* 结构体字段访问 - 类型信息明确 *)
           (match Hashtbl.find_opt struct_registry struct_name with
            | None ->
                Printf.bprintf buf "  ; ERROR: Struct '%s' not found\n" struct_name;
                ("0", I32)
            | Some struct_def ->
                let field_info_opt = List.find_opt (fun f -> f.field_name = attr) struct_def.fields in
                (match field_info_opt with
                 | Some field_info ->
                     (* 直接字段访问 *)
                     let field_ptr = fresh_temp () in
                     Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                       field_ptr obj_v field_info.field_index;
                     let result = fresh_temp () in
                     Printf.bprintf buf "  %s = load i32, i32* %s\n" result field_ptr;
                     (result, I32)
                 | None ->
                     (* 字段不存在,尝试字段提升 *)
                     let embedded_field_opt = List.find_opt (fun f ->
                       Hashtbl.mem struct_registry f.field_name
                     ) struct_def.fields in

                     (match embedded_field_opt with
                      | None ->
                          Printf.bprintf buf "  ; ERROR: Field '%s' not found in struct '%s'\n" attr struct_name;
                          ("0", I32)
                      | Some embedded_field_info ->
                          (match Hashtbl.find_opt struct_registry embedded_field_info.field_name with
                           | None ->
                               Printf.bprintf buf "  ; ERROR: Embedded struct '%s' not found\n" embedded_field_info.field_name;
                               ("0", I32)
                           | Some embedded_struct_def ->
                               let embedded_attr_info_opt = List.find_opt (fun f -> f.field_name = attr) embedded_struct_def.fields in
                               (match embedded_attr_info_opt with
                                | None ->
                                    Printf.bprintf buf "  ; ERROR: Field '%s' not found in embedded struct '%s'\n" attr embedded_field_info.field_name;
                                    ("0", I32)
                                | Some embedded_attr_info ->
                                    (* 先获取嵌入字段的指针 *)
                                    let embedded_ptr_field = fresh_temp () in
                                    Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                                      embedded_ptr_field obj_v embedded_field_info.field_index;
                                    let embedded_ptr_int = fresh_temp () in
                                    Printf.bprintf buf "  %s = load i32, i32* %s\n" embedded_ptr_int embedded_ptr_field;
                                    (* 将 i32 转换回指针 *)
                                    let embedded_ptr = fresh_temp () in
                                    Printf.bprintf buf "  %s = inttoptr i32 %s to i32*\n" embedded_ptr embedded_ptr_int;
                                    (* 从嵌入结构体中获取字段 *)
                                    let attr_ptr = fresh_temp () in
                                    Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                                      attr_ptr embedded_ptr embedded_attr_info.field_index;
                                    let result = fresh_temp () in
                                    Printf.bprintf buf "  %s = load i32, i32* %s\n" result attr_ptr;
                                    (result, I32))))))
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
             let (field_val, field_ty) = gen_expr buf ctx field_expr in

             let field_ptr = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
               field_ptr struct_ptr field_info.field_index;

             (* 检查字段类型: 如果是结构体指针,需要特殊处理 *)
             (match field_ty with
              | StructPtr _ | Ptr I32 ->
                  (* 字段值是指针,需要先转换为 i32 再存储 *)
                  let ptr_as_int = fresh_temp () in
                  Printf.bprintf buf "  %s = ptrtoint i32* %s to i32\n" ptr_as_int field_val;
                  Printf.bprintf buf "  store i32 %s, i32* %s\n" ptr_as_int field_ptr
              | _ ->
                  (* 普通值类型,直接存储 *)
                  Printf.bprintf buf "  store i32 %s, i32* %s\n" field_val field_ptr)
           ) field_inits;

           (struct_ptr, StructPtr struct_name))

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

  | ETernary (cond, true_expr, false_expr, _) ->
      (* 三元运算符: condition ? true_expr : false_expr *)
      let (cond_v, _) = gen_expr buf ctx cond in
      let then_label = fresh_label "ternary.then" in
      let else_label = fresh_label "ternary.else" in
      let end_label = fresh_label "ternary.end" in

      Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" cond_v then_label else_label;

      Printf.bprintf buf "\n%s:\n" then_label;
      let (then_v, then_t) = gen_expr buf ctx true_expr in
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" else_label;
      let (else_v, _) = gen_expr buf ctx false_expr in
      Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" end_label;
      let result = fresh_temp () in
      Printf.bprintf buf "  %s = phi %s [%s, %%%s], [%s, %%%s]\n"
        result (llvm_type_to_string then_t) then_v then_label else_v else_label;
      (result, then_t)

  | ETry (expr, _) ->
      (* 错误传播: expr? *)
      (* 计算表达式，表达式必须返回 Result 类型（EnumPtr） *)
      let (result_val, result_ty) = gen_expr buf ctx expr in
      (match result_ty with
       | EnumPtr ->
           (* Result 是枚举类型，需要检查是 Ok 还是 Err *)
           (* 获取枚举的 tag *)
           let tag = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @enum_get_tag(%%enum_t* %s)\n" tag result_val;

           (* 检查是否是 Ok (tag = 0) *)
           let is_ok = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, 0\n" is_ok tag;

           let ok_label = fresh_label "try.ok" in
           let err_label = fresh_label "try.err" in
           let end_label = fresh_label "try.end" in

           Printf.bprintf buf "  br i1 %s, label %%%s, label %%%s\n" is_ok ok_label err_label;

           (* Ok 分支：提取值 *)
           Printf.bprintf buf "\n%s:\n" ok_label;
           let ok_val = fresh_temp () in
           Printf.bprintf buf "  %s = call i32 @enum_get_int(%%enum_t* %s)\n" ok_val result_val;
           Printf.bprintf buf "  br label %%%s\n" end_label;

           (* Err 分支：提前返回错误 - 类似 Rust 的 ? 运算符 *)
           Printf.bprintf buf "\n%s:\n" err_label;
           (* 检查当前函数的返回类型 *)
           (match ctx.function_type with
            | Some EnumPtr ->
                (* 如果函数返回 Result 类型，直接返回错误 *)
                Printf.bprintf buf "  ret %%enum_t* %s\n" result_val
            | Some I32 ->
                (* 如果函数返回 int，提取错误码或返回 0 *)
                let err_val = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @enum_get_int(%%enum_t* %s)\n" err_val result_val;
                Printf.bprintf buf "  ret i32 %s\n" err_val
            | _ ->
                (* 其他情况，简化处理：返回 0 *)
                Printf.bprintf buf "  ; ERROR: Cannot propagate error - function return type mismatch\n";
                Printf.bprintf buf "  br label %%%s\n" end_label);

           (* 正常结束块 *)
           Printf.bprintf buf "\n%s:\n" end_label;
           (ok_val, I32)

       | _ ->
           Printf.bprintf buf "  ; ERROR: Try operator requires Result type\n";
           ("0", I32))

  | ETypeOf (expr, _) ->
      (* type of 表达式：返回表达式的类型信息 *)
      (* 生成表达式以获取其值和类型 *)
      let (expr_val, expr_ty) = gen_expr buf ctx expr in
      (match expr_ty with
       | UnionPtr ->
           (* 对于 Union 类型，调用运行时函数获取实际类型名 *)
           let type_name_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @union_get_struct_type(%%union_t* %s)\n" type_name_ptr expr_val;
           (* 检查是否为 NULL（非结构体类型） *)
           let is_null = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i8* %s, null\n" is_null type_name_ptr;
           (* 如果是 NULL，调用 union_type_name 获取基本类型名 *)
           let basic_type_name = fresh_temp () in
           Printf.bprintf buf "  %s = call i8* @union_type_name(%%union_t* %s)\n" basic_type_name expr_val;
           (* 选择返回哪个类型名 *)
           let result_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = select i1 %s, i8* %s, i8* %s\n" result_ptr is_null basic_type_name type_name_ptr;
           (result_ptr, Ptr I32)
       | _ ->
           (* 对于其他类型，返回静态类型名称 *)
           let type_string = Cg_utils.llvm_type_to_type_name expr_ty in
           incr string_counter;
           let str_name = Printf.sprintf "@.str%d" !string_counter in
           let (escaped_str, str_len) = llvm_escape_string type_string in
           ctx.string_literals <- (str_name, escaped_str, str_len) :: ctx.string_literals;
           let ptr_temp = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
             ptr_temp str_len str_len str_name;
           (ptr_temp, Ptr I32))

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
           (* Union 类型：检查类型名是否匹配（用于 match type of） *)
           (* 根据字符串 s 判断是基本类型还是结构体类型 *)
           let is_struct_type = Hashtbl.mem struct_registry s in
           if is_struct_type then begin
             (* 结构体类型：调用 union_is_struct *)
             incr string_counter;
             let type_str_name = Printf.sprintf "@.str%d" !string_counter in
             let (escaped_type_name, type_name_len) = llvm_escape_string s in
             ctx.string_literals <- (type_str_name, escaped_type_name, type_name_len) :: ctx.string_literals;
             let type_name_ptr = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
               type_name_ptr type_name_len type_name_len type_str_name;
             let is_struct = fresh_temp () in
             Printf.bprintf buf "  %s = call i1 @union_is_struct(%%union_t* %s, i8* %s)\n" is_struct scrut_v type_name_ptr;
             is_struct
           end else begin
             (* 基本类型或字符串类型：检查类型名 *)
             match s with
             | "int" ->
                 let is_int = fresh_temp () in
                 Printf.bprintf buf "  %s = call i1 @union_is_int(%%union_t* %s)\n" is_int scrut_v;
                 is_int
             | "bool" ->
                 let is_bool = fresh_temp () in
                 Printf.bprintf buf "  %s = call i1 @union_is_bool(%%union_t* %s)\n" is_bool scrut_v;
                 is_bool
             | "str" ->
                 let is_string = fresh_temp () in
                 Printf.bprintf buf "  %s = call i1 @union_is_string(%%union_t* %s)\n" is_string scrut_v;
                 is_string
             | "bytes" ->
                 let is_bytes = fresh_temp () in
                 Printf.bprintf buf "  %s = call i1 @union_is_bytes(%%union_t* %s)\n" is_bytes scrut_v;
                 is_bytes
             | _ ->
                 (* 未知类型，返回 false *)
                 Printf.bprintf buf "  ; Unknown type name: %s\n" s;
                 "0"
           end
       | _ ->
           (* 字符串比较需要调用string_compare *)
           incr string_counter;
           let str_name = Printf.sprintf "@.str%d" !string_counter in
           let (escaped_str, str_len) = llvm_escape_string s in
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
  | PType (_var_name, type_expr) ->
      (* 类型模式：检查 Union 中的具体类型 *)
      (match scrut_t with
       | UnionPtr ->
           (* Union 类型：根据 type_expr 生成对应的类型检查 *)
           let target_ty = ast_type_to_cg_type type_expr in
           (match target_ty with
            | I32 ->
                let is_int = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_int(%%union_t* %s)\n" is_int scrut_v;
                is_int
            | I64 ->
                (* 浮点数检查 *)
                let is_float = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_float(%%union_t* %s)\n" is_float scrut_v;
                is_float
            | Ptr I32 | StrType ->
                (* 字符串检查 *)
                let is_string = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_string(%%union_t* %s)\n" is_string scrut_v;
                is_string
            | Ptr U8 | BytesType ->
                (* bytes 类型检查 *)
                let is_bytes = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_bytes(%%union_t* %s)\n" is_bytes scrut_v;
                is_bytes
            | I1 ->
                let is_bool = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_bool(%%union_t* %s)\n" is_bool scrut_v;
                is_bool
            | StructPtr struct_name ->
                (* 结构体类型检查 *)
                (* 创建类型名字符串 *)
                incr string_counter;
                let type_str_name = Printf.sprintf "@.str%d" !string_counter in
                let (escaped_type_name, type_name_len) = llvm_escape_string struct_name in
                ctx.string_literals <- (type_str_name, escaped_type_name, type_name_len) :: ctx.string_literals;
                let type_name_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = getelementptr [%d x i8], [%d x i8]* %s, i32 0, i32 0\n"
                  type_name_ptr type_name_len type_name_len type_str_name;
                let is_struct = fresh_temp () in
                Printf.bprintf buf "  %s = call i1 @union_is_struct(%%union_t* %s, i8* %s)\n" is_struct scrut_v type_name_ptr;
                is_struct
            | _ ->
                Buffer.add_string buf "  ; ERROR: Unsupported type in type pattern\n";
                "0")
       | _ ->
           (* 非 Union 类型：检查类型是否直接匹配 *)
           let target_ty = ast_type_to_cg_type type_expr in
           if scrut_t = target_ty then
             "1"  (* 类型匹配 *)
           else
             "0"  (* 类型不匹配 *))
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
  | PList pats ->
      (* 列表模式: 检查长度是否匹配 *)
      (match scrut_t with
       | DynArray _ ->
           let len_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string scrut_t) (llvm_type_to_string scrut_t) scrut_v;
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp eq i32 %s, %d\n" cond len (List.length pats);
           cond
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected list type for list pattern\n";
           "0")
  | PCons (_head_pat, _tail_pat) ->
      (* Cons模式: 检查列表非空 *)
      (match scrut_t with
       | DynArray _ ->
           let len_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string scrut_t) (llvm_type_to_string scrut_t) scrut_v;
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;
           let cond = fresh_temp () in
           Printf.bprintf buf "  %s = icmp sgt i32 %s, 0\n" cond len;
           cond
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected list type for cons pattern\n";
           "0")
  | _ ->
      Printf.bprintf buf "  ; unsupported pattern type\n";
      "0"

(* 生成模式变量绑定 *)
and gen_pattern_bindings buf ctx pat scrut_v scrut_t scrut_var_name_opt =
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
  | PType (var_name, type_expr) ->
      (* 类型模式：从 Union 中拆箱并绑定变量 *)
      (* 如果匹配的是一个变量，使用原变量名；否则使用模式中的变量名 *)
      let bind_name = match scrut_var_name_opt with
        | Some scrut_var -> scrut_var
        | None -> var_name
      in
      (match scrut_t with
       | UnionPtr ->
           (* Union 类型：根据 type_expr 拆箱对应的值 *)
           let target_ty = ast_type_to_cg_type type_expr in
           (* 检查变量是否已存在，如果是则直接更新值到现有的栈位置 *)
           let existing_var_opt = find_llvm_name ctx bind_name in
           (match target_ty with
            | I32 ->
                let unboxed_val = fresh_temp () in
                Printf.bprintf buf "  %s = call i32 @union_get_int(%%union_t* %s)\n" unboxed_val scrut_v;
                (match existing_var_opt with
                 | Some llvm_name ->
                     (* 变量已存在，直接存储到现有位置 *)
                     Printf.bprintf buf "  store i32 %s, i32* %%%s\n" unboxed_val llvm_name;
                     (* 更新变量类型 *)
                     ctx.variables <- List.map (fun (n, t) -> if n = bind_name then (n, I32) else (n, t)) ctx.variables
                 | None ->
                     (* 变量不存在，创建新的 *)
                     let local = "%" ^ bind_name in
                     Printf.bprintf buf "  %s = alloca i32\n" local;
                     Printf.bprintf buf "  store i32 %s, i32* %s\n" unboxed_val local;
                     add_variable ctx bind_name I32)
            | StructPtr struct_name ->
                (* 结构体拆箱 *)
                let unboxed_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = call i8* @union_get_struct(%%union_t* %s)\n" unboxed_ptr scrut_v;
                (* 将 i8* 转换回 i32* *)
                let struct_ptr = fresh_temp () in
                Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" struct_ptr unboxed_ptr;
                (match existing_var_opt with
                 | Some llvm_name ->
                     (* 变量已存在，直接存储到现有位置 *)
                     Printf.bprintf buf "  store i32* %s, i32** %%%s\n" struct_ptr llvm_name;
                     (* 更新变量类型为结构体指针 *)
                     ctx.variables <- List.map (fun (n, t) -> if n = bind_name then (n, StructPtr struct_name) else (n, t)) ctx.variables
                 | None ->
                     (* 变量不存在，创建新的 *)
                     let local = "%" ^ bind_name in
                     Printf.bprintf buf "  %s = alloca i32*\n" local;
                     Printf.bprintf buf "  store i32* %s, i32** %s\n" struct_ptr local;
                     add_variable ctx bind_name (StructPtr struct_name))
            | Ptr I32 | StrType ->
                (* 字符串拆箱 *)
                let unboxed_val = fresh_temp () in
                Printf.bprintf buf "  %s = call i8* @union_get_string(%%union_t* %s)\n" unboxed_val scrut_v;
                (match existing_var_opt with
                 | Some llvm_name ->
                     Printf.bprintf buf "  store i8* %s, i8** %%%s\n" unboxed_val llvm_name;
                     ctx.variables <- List.map (fun (n, t) -> if n = bind_name then (n, Ptr I32) else (n, t)) ctx.variables
                 | None ->
                     let local = "%" ^ bind_name in
                     Printf.bprintf buf "  %s = alloca i8*\n" local;
                     Printf.bprintf buf "  store i8* %s, i8** %s\n" unboxed_val local;
                     add_variable ctx bind_name (Ptr I32))
            | _ ->
                Buffer.add_string buf "  ; ERROR: Unsupported type in type pattern binding\n")
       | _ ->
           (* 非 Union 类型：直接绑定 *)
           let local = "%" ^ var_name in
           Printf.bprintf buf "  %s = alloca %s\n" local (llvm_type_to_string scrut_t);
           Printf.bprintf buf "  store %s %s, %s* %s\n"
             (llvm_type_to_string scrut_t) scrut_v (llvm_type_to_string scrut_t) local;
           add_variable ctx var_name scrut_t)
  | PList pats ->
      (* 列表解构: [x; y; z] - 精确长度匹配 *)
      (match scrut_t with
       | DynArray elem_t ->
           (* 从动态数组结构中提取 data 指针 *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string scrut_t) (llvm_type_to_string scrut_t) scrut_v;

           (* 加载 data 指针 *)
           let data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

           (* 为每个模式提取对应索引的元素 *)
           List.iteri (fun i p ->
             let elem_ptr = fresh_temp () in
             let elem_val = fresh_temp () in
             Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 %d\n"
               elem_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr i;
             Printf.bprintf buf "  %s = load %s, %s* %s\n"
               elem_val (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) elem_ptr;
             gen_pattern_bindings buf ctx p elem_val elem_t None
           ) pats
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected list type for list pattern binding\n")
  | PCons (head_pat, tail_pat) ->
      (* Cons模式: head :: tail *)
      (match scrut_t with
       | DynArray elem_t ->
           (* 提取第一个元素 (head) *)
           let data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
             data_ptr_field (llvm_type_to_string scrut_t) (llvm_type_to_string scrut_t) scrut_v;

           let data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr_field;

           (* 提取head *)
           let head_ptr = fresh_temp () in
           let head_val = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0\n"
             head_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr;
           Printf.bprintf buf "  %s = load %s, %s* %s\n"
             head_val (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) head_ptr;

           (* 绑定head *)
           gen_pattern_bindings buf ctx head_pat head_val elem_t None;

           (* 创建tail列表 (从索引1开始的切片) *)
           (* 获取原列表长度 *)
           let len_ptr = fresh_temp () in
           let len = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
             len_ptr (llvm_type_to_string scrut_t) (llvm_type_to_string scrut_t) scrut_v;
           Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;

           (* 计算tail长度 = len - 1 *)
           let tail_len = fresh_temp () in
           Printf.bprintf buf "  %s = sub i32 %s, 1\n" tail_len len;

           (* 分配tail列表 *)
           let tail_list = fresh_temp () in
           Printf.bprintf buf "  %s = call { i32, i32, %s* }* @create_dynarray_i32(i32 %s)\n"
             tail_list (llvm_type_to_string elem_t) tail_len;

           (* 设置tail的length字段 *)
           let tail_len_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr { i32, i32, %s* }, { i32, i32, %s* }* %s, i32 0, i32 1\n"
             tail_len_field (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) tail_list;
           Printf.bprintf buf "  store i32 %s, i32* %s\n" tail_len tail_len_field;

           (* 复制数据: 从原数组的索引1开始复制tail_len个元素 *)
           let tail_data_ptr_field = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr { i32, i32, %s* }, { i32, i32, %s* }* %s, i32 0, i32 2\n"
             tail_data_ptr_field (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) tail_list;
           let tail_data_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = load %s*, %s** %s\n"
             tail_data_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) tail_data_ptr_field;

           (* 源地址: data_ptr + 1 *)
           let src_ptr = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 1\n"
             src_ptr (llvm_type_to_string elem_t) (llvm_type_to_string elem_t) data_ptr;

           (* 使用memcpy复制数据 *)
           let elem_size = fresh_temp () in
           Printf.bprintf buf "  %s = getelementptr %s, %s* null, i32 1\n"
             elem_size (llvm_type_to_string elem_t) (llvm_type_to_string elem_t);
           let elem_size_int = fresh_temp () in
           Printf.bprintf buf "  %s = ptrtoint %s* %s to i32\n"
             elem_size_int (llvm_type_to_string elem_t) elem_size;
           let src_i8 = fresh_temp () in
           let dst_i8 = fresh_temp () in
           Printf.bprintf buf "  %s = bitcast %s* %s to i8*\n"
             src_i8 (llvm_type_to_string elem_t) src_ptr;
           Printf.bprintf buf "  %s = bitcast %s* %s to i8*\n"
             dst_i8 (llvm_type_to_string elem_t) tail_data_ptr;
           let copy_size = fresh_temp () in
           Printf.bprintf buf "  %s = mul i32 %s, %s\n" copy_size tail_len elem_size_int;
           Printf.bprintf buf "  call void @llvm.memcpy.p0i8.p0i8.i32(i8* %s, i8* %s, i32 %s, i1 false)\n"
             dst_i8 src_i8 copy_size;

           (* 绑定tail - tail_list是指针,需要特殊处理 *)
           (match tail_pat with
            | PVar tail_name ->
                let local = "%" ^ tail_name in
                Printf.bprintf buf "  %s = alloca %s*\n" local (llvm_type_to_string scrut_t);
                Printf.bprintf buf "  store %s* %s, %s** %s\n"
                  (llvm_type_to_string scrut_t) tail_list (llvm_type_to_string scrut_t) local;
                add_variable ctx tail_name scrut_t
            | _ ->
                (* tail_pat可能是更复杂的模式,比如 x :: y :: rest *)
                gen_pattern_bindings buf ctx tail_pat tail_list scrut_t None)
       | _ ->
           Buffer.add_string buf "  ; ERROR: Expected list type for cons pattern binding\n")
  | PString type_name ->
      (* 字符串模式：在 match type of 的情况下，需要从 Union 拆箱 *)
      (match (scrut_t, scrut_var_name_opt) with
       | (UnionPtr, Some bind_name) ->
           (* 这是 match type of 变量 的情况，需要拆箱并重新绑定变量 *)
           (* 根据 type_name 确定目标类型 *)
           let target_ty = match type_name with
             | "int" -> I32
             | "float" -> I64
             | "bool" -> I1
             | "str" -> StrType
             | "bytes" -> BytesType
             | struct_name ->
                 (* 尝试查找是否是已注册的结构体 *)
                 if Hashtbl.mem struct_registry struct_name then
                   StructPtr struct_name
                 else
                   I32  (* 默认 *)
           in

           (* 检查变量是否已存在，以及其类型是否匹配 *)
           let var_exists = List.exists (fun (n, _) -> n = bind_name) ctx.variables in
           let old_type_opt = try Some (List.assoc bind_name ctx.variables) with Not_found -> None in

           (* 判断是否需要创建影子变量（类型不匹配时） *)
           let needs_shadow = match old_type_opt with
             | Some old_ty -> old_ty <> target_ty
             | None -> false
           in

           if var_exists && needs_shadow then begin
             (* 需要创建影子变量：类型不同，创建新的 LLVM 变量并重命名 *)
             (match target_ty with
              | I32 ->
                  let unboxed_val = fresh_temp () in
                  Printf.bprintf buf "  %s = call i32 @union_get_int(%%union_t* %s)\n" unboxed_val scrut_v;
                  let shadow_var = fresh_temp () in
                  Printf.bprintf buf "  %s = alloca i32\n" shadow_var;
                  Printf.bprintf buf "  store i32 %s, i32* %s\n" unboxed_val shadow_var;
                  (* 添加重命名：后续访问 bind_name 实际访问 shadow_var *)
                  let shadow_name = String.sub shadow_var 1 (String.length shadow_var - 1) in  (* 去掉 % 前缀 *)
                  ctx.var_renames <- (bind_name, shadow_name) :: ctx.var_renames;
                  (* 更新变量类型 *)
                  ctx.variables <- List.map (fun (n, t) -> if n = bind_name then (n, I32) else (n, t)) ctx.variables
              | StructPtr struct_name ->
                  let unboxed_ptr = fresh_temp () in
                  Printf.bprintf buf "  %s = call i8* @union_get_struct(%%union_t* %s)\n" unboxed_ptr scrut_v;
                  let struct_ptr = fresh_temp () in
                  Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" struct_ptr unboxed_ptr;
                  let shadow_var = fresh_temp () in
                  Printf.bprintf buf "  %s = alloca i32*\n" shadow_var;
                  Printf.bprintf buf "  store i32* %s, i32** %s\n" struct_ptr shadow_var;
                  (* 添加重命名 *)
                  let shadow_name = String.sub shadow_var 1 (String.length shadow_var - 1) in
                  ctx.var_renames <- (bind_name, shadow_name) :: ctx.var_renames;
                  (* 更新变量类型 *)
                  ctx.variables <- List.map (fun (n, t) -> if n = bind_name then (n, StructPtr struct_name) else (n, t)) ctx.variables
              | _ ->
                  Printf.bprintf buf "  ; TODO: shadow variable for type %s\n" (llvm_type_to_string target_ty);
                  ())
           end else if var_exists then begin
             (* 变量存在且类型匹配，直接存储（理论上不应该到这里，因为 Union 类型和其他类型不同） *)
             Printf.bprintf buf "  ; TODO: same-type variable rebinding\n";
             ()
           end else begin
             (* 变量不存在，创建新的 *)
             (match target_ty with
              | I32 ->
                  let unboxed_val = fresh_temp () in
                  Printf.bprintf buf "  %s = call i32 @union_get_int(%%union_t* %s)\n" unboxed_val scrut_v;
                  let local = "%" ^ bind_name in
                  Printf.bprintf buf "  %s = alloca i32\n" local;
                  Printf.bprintf buf "  store i32 %s, i32* %s\n" unboxed_val local;
                  add_variable ctx bind_name I32
              | StructPtr struct_name ->
                  let unboxed_ptr = fresh_temp () in
                  Printf.bprintf buf "  %s = call i8* @union_get_struct(%%union_t* %s)\n" unboxed_ptr scrut_v;
                  let struct_ptr = fresh_temp () in
                  Printf.bprintf buf "  %s = bitcast i8* %s to i32*\n" struct_ptr unboxed_ptr;
                  let local = "%" ^ bind_name in
                  Printf.bprintf buf "  %s = alloca i32*\n" local;
                  Printf.bprintf buf "  store i32* %s, i32** %s\n" struct_ptr local;
                  add_variable ctx bind_name (StructPtr struct_name)
              | _ ->
                  Printf.bprintf buf "  ; TODO: create variable for type %s\n" (llvm_type_to_string target_ty);
                  ())
           end
       | _ ->
           (* 非 match type of 的情况，不需要绑定 *)
           ())
  | _ -> ()  (* 其他模式不需要绑定变量 *)

