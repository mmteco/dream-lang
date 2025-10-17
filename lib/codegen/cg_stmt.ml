(* 语句代码生成 *)

open Ast
open Cg_types
open Cg_utils

let gen_expr = Cg_expr.gen_expr
let gen_pattern_test = Cg_expr.gen_pattern_test
let gen_pattern_bindings = Cg_expr.gen_pattern_bindings
let rec gen_statement buf ctx = function
  | SLet let_info ->
      let name = let_info.let_name in
      let type_ann = let_info.let_type in
      let value = let_info.let_value in
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
        | PList pats ->
            (* 对于列表,需要从列表中提取每个元素 *)
            (match value_type with
             | DynArray elem_t ->
                 (* 从动态数组结构中提取 data 指针 *)
                 let data_ptr_field = fresh_temp () in
                 Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
                   data_ptr_field (llvm_type_to_string value_type) (llvm_type_to_string value_type) value_temp;

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
                   gen_pattern_bindings p elem_val elem_t
                 ) pats
             | _ ->
                 Printf.bprintf buf "  ; pattern type mismatch - expected list\n")
        | PStruct (struct_name, field_pats) ->
            (* 结构体解构：如果struct_name为空，从字段名或value_type查找匹配的结构体 *)
            let actual_struct_name =
              if struct_name = "" then
                (* 首先尝试从value_type获取结构体名称 *)
                match value_type with
                | StructPtr name -> name
                | Ptr I32 ->
                    (* 从字段名推断结构体：遍历所有结构体定义查找包含这些字段的结构体 *)
                    let field_names = List.map fst field_pats in
                    Hashtbl.fold (fun sname sdef acc ->
                      match acc with
                      | Some _ -> acc  (* 已经找到了，跳过 *)
                      | None ->
                          (* 检查是否所有字段都存在于这个结构体中 *)
                          let all_fields_exist = List.for_all (fun fname ->
                            List.exists (fun f -> f.field_name = fname) sdef.fields
                          ) field_names in
                          if all_fields_exist then Some sname else None
                    ) struct_registry None
                    |> (function
                        | Some name -> name
                        | None ->
                            Printf.bprintf buf "  ; ERROR: Cannot infer struct type from fields\n";
                            "")
                | _ ->
                    Printf.bprintf buf "  ; ERROR: Cannot infer struct type from value_type\n";
                    ""
              else
                struct_name
            in
            (match value_type with
             | Ptr I32 | StructPtr _ ->
                 (* 查找结构体定义 *)
                 (match Hashtbl.find_opt struct_registry actual_struct_name with
                  | None ->
                      Printf.bprintf buf "  ; ERROR: Struct '%s' not found in registry\n" actual_struct_name
                  | Some struct_def ->
                      (* 为每个字段模式提取值并绑定 *)
                      List.iter (fun (field_name, field_pat) ->
                        (* 查找字段索引 *)
                        match List.find_opt (fun f -> f.field_name = field_name) struct_def.fields with
                        | None ->
                            Printf.bprintf buf "  ; WARNING: Field '%s' not found in struct '%s'\n" field_name actual_struct_name
                        | Some field_info ->
                            (* 计算字段指针 *)
                            let field_ptr = fresh_temp () in
                            Printf.bprintf buf "  %s = getelementptr i32, i32* %s, i32 %d\n"
                              field_ptr value_temp field_info.field_index;
                            (* 加载字段值 *)
                            let field_val = fresh_temp () in
                            Printf.bprintf buf "  %s = load %s, %s* %s\n"
                              field_val (llvm_type_to_string field_info.field_llvm_type)
                              (llvm_type_to_string field_info.field_llvm_type) field_ptr;
                            (* 递归处理字段模式 *)
                            gen_pattern_bindings field_pat field_val field_info.field_llvm_type
                      ) field_pats)
             | _ ->
                 Printf.bprintf buf "  ; ERROR: Expected struct pointer type for struct pattern, got %s\n"
                   (llvm_type_to_string value_type))
        | PCons (head_pat, tail_pat) ->
            (* Cons模式: head :: tail *)
            (match value_type with
             | DynArray elem_t ->
                 (* 提取第一个元素 (head) *)
                 let data_ptr_field = fresh_temp () in
                 Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 2\n"
                   data_ptr_field (llvm_type_to_string value_type) (llvm_type_to_string value_type) value_temp;

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
                 gen_pattern_bindings head_pat head_val elem_t;

                 (* 创建tail列表 (从索引1开始的切片) - 直接用指针指向原数组数据+1 *)
                 (* 由于这是let绑定,tail应该是一个新的独立列表 *)
                 (* 获取原列表长度 *)
                 let len_ptr = fresh_temp () in
                 let len = fresh_temp () in
                 Printf.bprintf buf "  %s = getelementptr %s, %s* %s, i32 0, i32 1\n"
                   len_ptr (llvm_type_to_string value_type) (llvm_type_to_string value_type) value_temp;
                 Printf.bprintf buf "  %s = load i32, i32* %s\n" len len_ptr;

                 (* 计算tail长度 = len - 1 *)
                 let tail_len = fresh_temp () in
                 Printf.bprintf buf "  %s = sub i32 %s, 1\n" tail_len len;

                 (* 分配tail列表 *)
                 let tail_list = fresh_temp () in
                 Printf.bprintf buf "  %s = call { i32, i32, %s* }* @create_dynarray_i32(i32 %s)\n"
                   tail_list (llvm_type_to_string elem_t) tail_len;


                (* 设置tail的length字段为tail_len *)
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

                 (* 绑定tail - tail_list是指针,但需要作为DynArray类型绑定 *)
                 (match tail_pat with
                  | PVar tail_name ->
                      let local = "%" ^ tail_name in
                      Printf.bprintf buf "  %s = alloca %s*\n" local (llvm_type_to_string value_type);
                      Printf.bprintf buf "  store %s* %s, %s** %s\n"
                        (llvm_type_to_string value_type) tail_list (llvm_type_to_string value_type) local;
                      add_variable ctx tail_name value_type
                  | PCons _ ->
                      (* 嵌套Cons模式: tail_list是指针,需要作为scrut_v传递给递归调用 *)
                      gen_pattern_bindings tail_pat tail_list value_type
                  | _ ->
                      (* 其他复杂模式 *)
                      Printf.bprintf buf "  ; unsupported nested pattern in cons\n")
             | _ ->
                 Printf.bprintf buf "  ; pattern type mismatch - expected list for cons\n")
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
      (* 检查 then 分支是否有 return *)
      let then_has_return = match List.rev then_body with
        | SReturn _ :: _ -> true
        | _ -> false
      in
      if not then_has_return then
        Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" else_label;
      List.iter (gen_statement buf ctx) else_body;
      (* 检查 else 分支是否有 return *)
      let else_has_return = match List.rev else_body with
        | SReturn _ :: _ -> true
        | _ -> false
      in
      if not else_has_return then
        Printf.bprintf buf "  br label %%%s\n" end_label;

      Printf.bprintf buf "\n%s:\n" end_label;
      (* 如果两个分支都有 return,end 块不可达 *)
      if then_has_return && else_has_return then
        Printf.bprintf buf "  unreachable\n"

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

  | SEnum enum_info ->
      let name = enum_info.enum_name in
      let variants = enum_info.enum_variants in
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

  | SInterface _ ->
      (* 接口定义不生成代码,只是声明 *)
      Buffer.add_string buf "  ; interface definition (no code generated)\n"

  | SImpl _ ->
      (* impl块在程序级别处理,这里不生成代码 *)
      Buffer.add_string buf "  ; impl block (handled at program level)\n"

  | SStruct struct_info ->
      let name = struct_info.struct_name in
      let members = struct_info.struct_members in
      (* 结构体定义：注册到 struct_registry *)
      (* 只处理字段，忽略方法（方法暂时不生成代码） *)
      let field_list = List.filter_map (function
        | Ast.SField field -> Some field
        | Ast.SMethod _ -> None
      ) members in

      let field_infos = List.mapi (fun i field ->
        let field_ty = type_expr_to_llvm_type field.Ast.field_type in
        (* 对于匿名嵌入字段,从类型表达式提取类型名作为字段名 *)
        let field_name = match field.Ast.field_name with
          | Some name -> name
          | None ->
              (match field.Ast.field_type with
               | TVar type_name -> type_name
               | _ -> "_invalid_")
        in
        {
          field_name = field_name;
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

  | SImport _ | SFromImport _ ->
      (* 导入语句在代码生成时不产生任何运行时代码 *)
      ()

  | _ ->
      Buffer.add_string buf "  ; unsupported statement\n"

