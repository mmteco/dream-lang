(* LLVM IR Code Generator - Top Level *)

open Ast
open Buffer
open Cg_types
open Cg_utils

(* 导入核心生成函数 *)
let gen_expr = Cg_expr.gen_expr
let gen_statement = Cg_stmt.gen_statement

let gen_function buf ctx name params ret_ty body =
  temp_counter := 0;
  label_counter := 0;

  ctx.variables <- [];
  ctx.var_renames <- [];

  let ret_type = match ret_ty with
    | Some t -> type_expr_to_llvm_type t
    | None -> I32
  in

  (* 设置当前函数返回类型到 context *)
  ctx.function_type <- Some ret_type;

  (* 收集参数类型并存储到 context *)
  let param_types = List.map (fun (_, pty, _) ->
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

  List.iteri (fun i (pname, pty, _) ->
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

  List.iter (fun (pname, pty, _) ->
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
    | SIf (_, then_body, _, Some else_body, _) ->
        (* if-else 两个分支都有 return *)
        List.exists has_return_stmt then_body && List.exists has_return_stmt else_body
    | SExpr (EMatch (_, cases, _), _) ->
        (* match 表达式的所有分支都有 return *)
        List.for_all (fun (_, _, body) ->
          match body with
          | MExpr _ -> false  (* 单行表达式不算 return *)
          | MStmts stmts -> List.exists has_return_stmt stmts
        ) cases
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
    | EnumPtr ->
        (* Enum 返回类型默认返回 null *)
        Buffer.add_string buf "  ret %enum_t* null\n"
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
  Buffer.add_string buf "declare void @print_rune(i32)\n";
  Buffer.add_string buf "declare i32 @printf(i8*, ...)\n";

  (* Memory management functions *)
  Buffer.add_string buf "declare i8* @malloc(i32)\n";
  Buffer.add_string buf "declare void @free(i8*)\n";
  Buffer.add_string buf "declare void @llvm.memcpy.p0i8.p0i8.i32(i8*, i8*, i32, i1)\n";
  Buffer.add_string buf "declare void @llvm.memset.p0i8.i32(i8*, i8, i32, i1)\n";

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

  (* String functions - UTF-8 aware *)
  Buffer.add_string buf "; String functions (UTF-8 aware)\n";
  Buffer.add_string buf "declare i32 @string_length(i8*)\n";  (* 返回 rune 数量 *)
  Buffer.add_string buf "declare i32 @string_char_at(i8*, i32)\n";  (* 返回 rune (U32) *)
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

  (* File I/O functions - C runtime uses __c_ prefix *)
  Buffer.add_string buf "; File I/O functions\n";
  Buffer.add_string buf "declare i8* @__c_file_read(i8*)\n";
  Buffer.add_string buf "declare i32 @__c_file_write(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @__c_file_exists(i8*)\n";
  Buffer.add_string buf "declare i32 @__c_file_append(i8*, i8*)\n";
  Buffer.add_string buf "declare i32 @__c_file_delete(i8*)\n";
  Buffer.add_string buf "declare { i32, i32, i32* }* @__c_file_read_bytes(i8*)\n";
  Buffer.add_string buf "declare i32 @__c_file_write_bytes(i8*, { i32, i32, i32* }*)\n";
  Buffer.add_string buf "declare i32 @__c_file_append_bytes(i8*, { i32, i32, i32* }*)\n\n";

  (* UTF-8 encoding/decoding functions *)
  Buffer.add_string buf "; UTF-8 encoding/decoding functions\n";
  Buffer.add_string buf "declare { i32, i32 } @__c_utf8_decode_rune({ i32, i32, i8* }*, i32)\n";
  Buffer.add_string buf "declare { i32, i32, i8* }* @__c_utf8_encode_rune(i32)\n";
  Buffer.add_string buf "declare i32 @__c_utf8_rune_count(i8*)\n";
  Buffer.add_string buf "declare i32 @__c_utf8_rune_at(i8*, i32)\n";
  Buffer.add_string buf "declare i32 @__c_utf8_byte_offset(i8*, i32)\n\n";

  (* bytes operations *)
  Buffer.add_string buf "; Bytes operations\n";
  Buffer.add_string buf "declare i32 @__c_bytes_length({ i32, i32, i8* }*)\n";
  Buffer.add_string buf "declare i32 @__c_bytes_get({ i32, i32, i8* }*, i32)\n";
  Buffer.add_string buf "declare { i32, i32, i8* }* @__c_bytes_slice({ i32, i32, i8* }*, i32, i32)\n";
  Buffer.add_string buf "declare { i32, i32, i8* }* @__c_bytes_from_array({ i32, i32, i8* }*)\n";
  Buffer.add_string buf "declare { i32, i32, i8* }* @__c_str_to_bytes(i8*)\n";
  Buffer.add_string buf "declare i8* @__c_bytes_to_str({ i32, i32, i8* }*)\n";

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
  Buffer.add_string buf "declare %union_t* @union_create_bytes(i8*)\n";
  Buffer.add_string buf "declare %union_t* @union_create_none()\n";
  Buffer.add_string buf "declare i1 @union_is_int(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_float(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_string(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_bool(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_bytes(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_is_none(%union_t*)\n";
  Buffer.add_string buf "declare i32 @union_get_int(%union_t*)\n";
  Buffer.add_string buf "declare double @union_get_float(%union_t*)\n";
  Buffer.add_string buf "declare i8* @union_get_string(%union_t*)\n";
  Buffer.add_string buf "declare i1 @union_get_bool(%union_t*)\n";
  Buffer.add_string buf "declare i8* @union_get_bytes(%union_t*)\n";
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

  (* 注册内置枚举类型 Result *)
  let result_enum_def = {
    enum_name = "Result";
    variants = [
      { variant_name = "Ok"; tag = 0; has_data = true };
      { variant_name = "Err"; tag = 1; has_data = true }
    ]
  } in
  Hashtbl.replace enum_registry "Result" result_enum_def;

  (* 处理导入语句，加载导入模块的函数 *)
  let imported_modules = ref [] in
  List.iter (function
    | SImport (module_path, _alias, _) ->
        (match Module_loader.load_module module_path with
         | Ok (_path, ast) -> imported_modules := ast :: !imported_modules
         | Error _ -> ())
    | SFromImport (module_name, _selections, _) ->
        (match Module_loader.load_module [module_name] with
         | Ok (_path, ast) -> imported_modules := ast :: !imported_modules
         | Error _ -> ())
    | _ -> ()
  ) program;

  (* 扫描所有函数定义并注册它们的签名（包括导入的） *)
  let all_programs = program :: !imported_modules in
  List.iter (fun prog ->
    List.iter (function
      | SDef def_info ->
          let ret_type = match def_info.def_return_type with
            | Some t -> type_expr_to_llvm_type t
            | None -> I32
          in
          ctx.function_signatures <- (def_info.def_name, ret_type) :: ctx.function_signatures;
          (* 同时注册参数类型 *)
          let param_types = List.map (fun (_, pty, _) ->
            match pty with
            | Some t -> type_expr_to_llvm_type t
            | None -> I32
          ) def_info.def_params in
          ctx.function_param_types <- (def_info.def_name, param_types) :: ctx.function_param_types
      | _ -> ()
    ) prog
  ) all_programs;

  let has_main = List.exists (function
    | SDef def_info -> def_info.def_name = "main"
    | _ -> false) program
  in

  if has_main then begin
    (* 先注册所有结构体定义 *)
    List.iter (function
      | SStruct struct_info ->
          let name = struct_info.struct_name in
          let members = struct_info.struct_members in
          let field_list = List.filter_map (function
            | Ast.SField field -> Some field
            | _ -> None
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
          Hashtbl.replace struct_registry name struct_def
      | _ -> ()
    ) program;

    (* 生成所有函数定义（包括导入的） *)
    List.iter (fun prog ->
      List.iter (function
        | SDef def_info ->
            gen_function code_buf ctx def_info.def_name def_info.def_params
              def_info.def_return_type def_info.def_body
        | _ -> ()
      ) prog
    ) all_programs;

    (* 生成所有结构体方法 *)
    List.iter (function
      | SStruct struct_info ->
          let struct_name = struct_info.struct_name in
          List.iter (function
            | Ast.SMethod (method_name, _type_params, params, ret_ty_opt, body, _) ->
                (* 注册方法到 struct_method_registry *)
                Hashtbl.replace struct_method_registry method_name struct_name;
                let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                (* 如果第一个参数是 self,给它加上结构体类型标注并记录到 context *)
                let params_with_types = match params with
                  | (pname, None, def) :: rest when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      (pname, Some (TStruct (struct_name, [])), def) :: rest
                  | (pname, Some _, _) :: _ when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      params  (* 如果已经有类型标注,保留 *)
                  | _ -> params
                in
                gen_function code_buf ctx mangled_name params_with_types ret_ty_opt body;
                (* 方法生成后清理 var_struct_types *)
                ctx.var_struct_types <- []
            | _ -> ()
          ) struct_info.struct_members
      | _ -> ()
    ) program;

    (* 生成所有impl块的方法 *)
    List.iter (function
      | SImpl (impl_block, _) ->
          let target_type_str = match impl_block.impl_target with
            | TVar name -> name
            | TInt -> "int"
            | TFloat -> "float"
            | TStr -> "string"
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
      | SStruct struct_info ->
          let name = struct_info.struct_name in
          let members = struct_info.struct_members in
          let field_list = List.filter_map (function
            | Ast.SField field -> Some field
            | _ -> None
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
          Hashtbl.replace struct_registry name struct_def
      | _ -> ()
    ) program;

    (* 生成所有函数定义（包括导入的） *)
    List.iter (fun prog ->
      List.iter (function
        | SDef def_info ->
            gen_function code_buf ctx def_info.def_name def_info.def_params
              def_info.def_return_type def_info.def_body
        | _ -> ()
      ) prog
    ) all_programs;

    (* 生成所有结构体方法 *)
    List.iter (function
      | SStruct struct_info ->
          let struct_name = struct_info.struct_name in
          List.iter (function
            | Ast.SMethod (method_name, _type_params, params, ret_ty_opt, body, _) ->
                (* 注册方法到 struct_method_registry *)
                Hashtbl.replace struct_method_registry method_name struct_name;
                let mangled_name = Printf.sprintf "%s_%s" struct_name method_name in
                (* 如果第一个参数是 self,给它加上结构体类型标注并记录到 context *)
                let params_with_types = match params with
                  | (pname, None, def) :: rest when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      (pname, Some (TStruct (struct_name, [])), def) :: rest
                  | (pname, Some _, _) :: _ when pname = "self" ->
                      (* 记录 self 的结构体类型 *)
                      ctx.var_struct_types <- ("self", struct_name) :: ctx.var_struct_types;
                      params  (* 如果已经有类型标注,保留 *)
                  | _ -> params
                in
                gen_function code_buf ctx mangled_name params_with_types ret_ty_opt body;
                (* 方法生成后清理 var_struct_types *)
                ctx.var_struct_types <- []
            | _ -> ()
          ) struct_info.struct_members
      | _ -> ()
    ) program;

    (* 生成所有impl块的方法 *)
    List.iter (function
      | SImpl (impl_block, _) ->
          let target_type_str = match impl_block.impl_target with
            | TVar name -> name
            | TInt -> "int"
            | TFloat -> "float"
            | TStr -> "string"
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

    (* 清理 context 为 main 函数准备 *)
    ctx.variables <- [];
    ctx.var_renames <- [];

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
