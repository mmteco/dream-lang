def module_path(module_name: str) -> str:
    switch module_name:
        case "bootstrap_io":
            return "runtime/stdlib/bootstrap_io.dm"
        case "dir_bootstrap":
            return "runtime/stdlib/dir_bootstrap.dm"
        case "compiler_lex":
            return "bootstrap/compiler_lex.dm"
        case "compiler_dir":
            return "bootstrap/compiler_dir.dm"
        case "compiler_hir":
            return "bootstrap/compiler_hir.dm"
        case "compiler_ast":
            return "bootstrap/compiler_ast.dm"
        case "compiler_lower":
            return "bootstrap/compiler_lower.dm"
        case "compiler_expr":
            return "bootstrap/compiler_expr.dm"
        case "compiler_stmt":
            return "bootstrap/compiler_stmt.dm"
        case "compiler_main":
            return "bootstrap/compiler_main.dm"
    let with_prefix = string_concat("runtime/stdlib/", module_name)
    return string_concat(with_prefix, ".dm")

def module_is_loaded(loaded_modules: str, module_name: str) -> bool:
    let module_start = 0
    let loaded_length = text_length(loaded_modules)
    while module_start < loaded_length:
        let module_end = module_start
        while module_end < loaded_length and ord(loaded_modules[module_end]) != 10:
            module_end = module_end + 1
        if loaded_modules[module_start:module_end] == module_name:
            return true
        module_start = module_end + 1
    return false

def append_imported_module(imported_source: str, module_name: str) -> str:
    let imported_path = module_path(module_name)
    let module_source = read_text_file(imported_path)
    return string_concat(imported_source, string_concat(module_source, "\n"))

def load_imported_source(source: str) -> str:
    let imported_source = ""
    let loaded_modules = ""
    let scan_source = source
    let scan_round = 0
    let found_new_module = true
    while scan_round < 64 and found_new_module:
        let import_kinds = []
        let import_starts = []
        let import_ends = []
        lex(scan_source, import_kinds, import_starts, import_ends)
        found_new_module = false
        let token_index = 0
        while token_kind(import_kinds, token_index) != TOKEN_EOF:
            if token_kind(import_kinds, token_index) == TOKEN_IDENTIFIER and source_equals(scan_source, token_start(import_starts, token_index), token_end(import_ends, token_index), "from"):
                let module_index = token_index + 1
                if token_kind(import_kinds, module_index) == TOKEN_IDENTIFIER:
                    let module_name = scan_source[token_start(import_starts, module_index):token_end(import_ends, module_index)]
                    if not module_is_loaded(loaded_modules, module_name):
                        imported_source = append_imported_module(imported_source, module_name)
                        loaded_modules = string_concat(loaded_modules, string_concat(module_name, "\n"))
                        found_new_module = true
            token_index = token_index + 1
        if found_new_module:
            scan_source = imported_source
        scan_round = scan_round + 1
    if text_length(loaded_modules) != 0:
        return string_concat(imported_source, string_concat("\n", source))
    return source

const COMPILE_OUTPUT_LL: int = 0
const COMPILE_OUTPUT_DIR_SOURCE: int = 1
const COMPILE_OUTPUT_AST: int = 2

def compile_source(source_path: str, output_path: str, output_mode: int):
    let debug_enabled = __c_debug_on()
    let total_start = __c_time_ms()
    let stage_start = __c_time_ms()
    let stage_end = 0
    let source = load_imported_source(read_text_file(source_path))
    let kinds = []
    let starts = []
    let ends = []
    lex(source, kinds, starts, ends)
    if debug_enabled:
        stage_end = __c_time_ms()
        __c_eprint_text("lex: ")
        __c_eprint_int(stage_end - stage_start)
        __c_eprint_text(" ms\n")
        stage_start = stage_end
    let function_starts = []
    let function_ends = []
    let function_bodies = []
    let function_body_ends = []
    let function_param_offsets = []
    let function_param_counts = []
    let parameter_starts = []
    let parameter_ends = []
    let parameter_types = []
    let function_return_types = []
    let constant_starts = []
    let constant_ends = []
    let constant_values = []
    let constant_types = []
    let parameter_default_indexes = []
    collect_declared_types(source, kinds, starts, ends)
    collect_functions(source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types, parameter_default_indexes)
    collect_constants(source, kinds, starts, ends, constant_starts, constant_ends, constant_values, constant_types)
    let parse_context = ParseContext{src: source, kinds: kinds, starts: starts, ends: ends, fn_starts: function_starts, fn_ends: function_ends, param_offsets: function_param_offsets, param_counts: function_param_counts, param_starts: parameter_starts, param_ends: parameter_ends, ret_types: function_return_types, pd: parameter_default_indexes, cst_starts: constant_starts, cst_ends: constant_ends, cst_values: constant_values}
    let global_let_name_starts = []
    let global_let_name_ends = []
    let global_let_collected_types = []
    let global_let_expression_indexes = []
    collect_global_lets(source, kinds, starts, ends, global_let_name_starts, global_let_name_ends, global_let_collected_types, global_let_expression_indexes)
    let global_let_types = []
    let global_let_index = 0
    while global_let_index < len(global_let_name_starts):
        let inferred_type = global_let_collected_types[global_let_index]
        if inferred_type == VALUE_TYPE_UNKNOWN:
            let probe_output = []
            let probe_records = []
            let (probe_next_index, probe_type, probe_value, probe_next_counter) = parse_argument_expression(parse_context, global_let_expression_indexes[global_let_index], probe_output, probe_records, [], [], [], 0)
            inferred_type = probe_type
        append(global_let_types, inferred_type)
        global_let_index = global_let_index + 1
    if output_mode == COMPILE_OUTPUT_AST:
        let ast = []
        let fn_ast_starts = []
        let fn_ast_ends = []
        let global_let_nodes = []
        let ast_is_valid = ast_build_program(parse_context, ast, fn_ast_starts, fn_ast_ends, global_let_nodes, function_bodies, function_body_ends, global_let_expression_indexes)
        if not ast_is_valid or not ast_validate_program(ast):
            let ast_invalid_output = []
            append_text(ast_invalid_output, "; AST validation failed nodes=")
            append_integer(ast_invalid_output, len(ast))
            append_text(ast_invalid_output, " functions=")
            append_integer(ast_invalid_output, len(fn_ast_starts))
            append_text(ast_invalid_output, " valid=")
            if ast_is_valid:
                append_text(ast_invalid_output, "build")
            if not ast_is_valid:
                append_text(ast_invalid_output, "parse")
            append_text(ast_invalid_output, "\n")
            write_text_codes(output_path, ast_invalid_output)
            return
        let ast_dump = []
        append_text(ast_dump, "module dream\n")
        append_text(ast_dump, "functions=")
        append_integer(ast_dump, len(fn_ast_starts))
        append_text(ast_dump, " pool=")
        append_integer(ast_dump, len(ast))
        append_text(ast_dump, "\n")
        let dump_fn = 0
        while dump_fn < len(fn_ast_starts):
            append_text(ast_dump, "func ")
            append_integer(ast_dump, dump_fn)
            append_text(ast_dump, " ")
            append_text(ast_dump, source[function_starts[dump_fn]:function_ends[dump_fn]])
            append_text(ast_dump, " body=")
            append_integer(ast_dump, fn_ast_starts[dump_fn])
            append_text(ast_dump, "..")
            append_integer(ast_dump, fn_ast_ends[dump_fn])
            append_text(ast_dump, "\n")
            dump_fn = dump_fn + 1
        let dump_node = 1
        while dump_node < len(ast):
            let dump_kind = ast[dump_node]
            let dump_size = ast_node_size(dump_kind)
            if dump_size < 3:
                append_text(ast_dump, "; unknown kind ")
                append_integer(ast_dump, dump_kind)
                append_text(ast_dump, " at ")
                append_integer(ast_dump, dump_node)
                append_text(ast_dump, "\n")
                dump_node = dump_node + 1
            append_text(ast_dump, "  n")
            append_integer(ast_dump, dump_node)
            append_text(ast_dump, " ")
            append_text(ast_dump, ast_kind_name(dump_kind))
            append_text(ast_dump, " s")
            append_integer(ast_dump, dump_size)
            append_text(ast_dump, ":")
            let dump_arg = 0
            while dump_arg < dump_size - 3 and dump_arg < 12:
                append_text(ast_dump, " ")
                append_integer(ast_dump, ast[dump_node + 3 + dump_arg])
                dump_arg = dump_arg + 1
            append_text(ast_dump, "\n")
            dump_node = dump_node + dump_size
        write_text_codes(output_path, ast_dump)
        return
    if debug_enabled:
        stage_end = __c_time_ms()
        __c_eprint_text("collect: ")
        __c_eprint_int(stage_end - stage_start)
        __c_eprint_text(" ms\n")
        stage_start = stage_end
    if true:
        let ast = []
        let fn_ast_starts = []
        let fn_ast_ends = []
        let global_let_nodes = []
        let ast_is_valid = ast_build_program(parse_context, ast, fn_ast_starts, fn_ast_ends, global_let_nodes, function_bodies, function_body_ends, global_let_expression_indexes)
        if not ast_is_valid or not ast_validate_program(ast):
            let ast_invalid_output = []
            append_text(ast_invalid_output, "; AST validation failed nodes=")
            append_integer(ast_invalid_output, len(ast))
            append_text(ast_invalid_output, " functions=")
            append_integer(ast_invalid_output, len(fn_ast_starts))
            append_text(ast_invalid_output, " valid=")
            if ast_is_valid:
                append_text(ast_invalid_output, "build")
            if not ast_is_valid:
                append_text(ast_invalid_output, "parse")
            append_text(ast_invalid_output, " pool=")
            let pool_index = 0
            while pool_index < len(ast) and pool_index < 24:
                append_integer(ast_invalid_output, ast[pool_index])
                append_text(ast_invalid_output, ",")
                pool_index = pool_index + 1
            append_text(ast_invalid_output, "\n")
            write_text_codes(output_path, ast_invalid_output)
            return
        if debug_enabled:
            stage_end = __c_time_ms()
            __c_eprint_text("ast: ")
            __c_eprint_int(stage_end - stage_start)
            __c_eprint_text(" ms\n")
            stage_start = stage_end
        let lower_records = []
        let lower_is_valid = lower_program(parse_context, ast, fn_ast_starts, fn_ast_ends, global_let_nodes, lower_records, global_let_name_starts, global_let_name_ends, global_let_types, function_bodies, function_body_ends, parameter_types, constant_starts, constant_ends, constant_values, constant_types)
        if not lower_is_valid or not dir_validate_records(lower_records):
            let lower_invalid_output = []
            append_text(lower_invalid_output, "; DIR validation failed\n")
            dir_dump_records(lower_records, lower_invalid_output)
            write_text_codes(output_path, lower_invalid_output)
            return
        if output_mode == COMPILE_OUTPUT_DIR_SOURCE:
            let formal_dir = []
            if not dir_render_formal_records(lower_records, formal_dir):
                append_text(formal_dir, "; formal DreamIR rendering failed\n")
            write_text_codes(output_path, formal_dir)
            return
        let lower_llvm_output = []
        if not dir_render_records(lower_records, lower_llvm_output):
            append_text(lower_llvm_output, "; DIR rendering failed\n")
            dir_dump_records(lower_records, lower_llvm_output)
            write_text_codes(output_path, lower_llvm_output)
            return
        write_text_codes(output_path, lower_llvm_output)
        if debug_enabled:
            stage_end = __c_time_ms()
            __c_eprint_text("lower: ")
            __c_eprint_int(stage_end - stage_start)
            __c_eprint_text(" ms\n")
        return
    let old_pipe_index = 0
    while old_pipe_index < len(parameter_types):
        if parameter_types[old_pipe_index] == VALUE_TYPE_LIST_STRING:
            parameter_types[old_pipe_index] = VALUE_TYPE_LIST
        old_pipe_index = old_pipe_index + 1
    let hir_records = []
    let hir_is_valid = hir_build_program(hir_records, source, kinds, starts, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, function_return_types, constant_starts, constant_ends, constant_values, constant_types)
    if not hir_is_valid or not hir_validate_program(hir_records):
        let hir_invalid_output = []
        append_text(hir_invalid_output, "; HIR validation failed\n")
        write_text_codes(output_path, hir_invalid_output)
        return
    let dm_dir_records = []
    let dm_dir_is_valid = dm_dir_build_program(dm_dir_records, source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types)
    if not dm_dir_is_valid or not dm_dir_validate_program(dm_dir_records):
        let dm_dir_invalid_output = []
        append_text(dm_dir_invalid_output, "; DM DIR validation failed\n")
        write_text_codes(output_path, dm_dir_invalid_output)
        return
    if debug_enabled:
        stage_end = __c_time_ms()
        __c_eprint_text("hir+dir: ")
        __c_eprint_int(stage_end - stage_start)
        __c_eprint_text(" ms\n")
        stage_start = stage_end
    let output = [1]
    let dir_records = []
    append_text(output, "; HIR records=")
    append_integer(output, len(hir_records) / HIR_RECORD_SIZE)
    append_text(output, "\n")
    append_text(output, "; DM DIR records=")
    append_integer(output, len(dm_dir_records) / DM_DIR_RECORD_SIZE)
    append_text(output, "\n")
    append_text(output, "; function_count=")
    append_integer(output, len(function_starts))
    append_text(output, "\n")
    append_text(output, "; Dream LLVM bootstrap output\n")
    append_text(output, "%dynarray_i32 = type { i32, i32, i32* }\n")
    append_text(output, "%dict_t = type opaque\n")
    append_text(output, "%dir_closure = type { i8*, i8* }\n")
    append_text(output, "%dir_interface = type { i8*, i8* }\n")
    let literal_index = 0
    while literal_index < len(kinds):
        if token_kind(kinds, literal_index) == TOKEN_STRING:
            append_string_global(output, source, starts, ends, literal_index)
        literal_index = literal_index + 1
    let constant_index = 0
    while constant_index < len(constant_starts):
        if constant_ends[constant_index] > constant_starts[constant_index]:
            append_text(output, "@")
            append_text(output, source[constant_starts[constant_index]:constant_ends[constant_index]])
            append_text(output, " = constant i32 ")
            append_integer(output, constant_values[constant_index])
            append_text(output, "\n")
        constant_index = constant_index + 1
    let global_let_declare_index = 0
    while global_let_declare_index < len(global_let_name_starts):
        append_text(output, "@")
        append_text(output, source[global_let_name_starts[global_let_declare_index]:global_let_name_ends[global_let_declare_index]])
        append_text(output, " = global ")
        append_llvm_type_text(output, global_let_types[global_let_declare_index])
        append_text(output, " zeroinitializer\n")
        global_let_declare_index = global_let_declare_index + 1
    dir_flush_line(dir_records, output)
    append_text(output, "declare void @dream_print_int(i32)\n")
    append_text(output, "declare void @dream_print_float(double)\n")
    append_text(output, "declare void @dream_print_bool(i1)\n")
    append_text(output, "declare void @dream_print_string(i8*)\n")
    append_text(output, "declare i8* @malloc(i32)\n")
    append_text(output, "declare i8* @string_substring(i8*, i32, i32)\n")
    append_text(output, "declare i8* @string_concat(i8*, i8*)\n")
    append_text(output, "declare i32 @string_compare(i8*, i8*)\n")
    append_text(output, "declare i32 @string_length(i8*)\n")
    append_text(output, "declare i8* @__c_file_read(i8*)\n")
    append_text(output, "declare i32 @__c_file_write(i8*, i8*)\n")
    append_text(output, "declare i32 @__c_file_write_bytes(i8*, %dynarray_i32*)\n")
    append_text(output, "declare i32 @__c_build_llvm(i8*, i8*)\n")
    append_text(output, "declare i32 @__c_time_ms()\n")
    append_text(output, "declare i1 @__c_debug_on()\n")
    append_text(output, "declare void @__c_eprint_text(i8*)\n")
    append_text(output, "declare void @__c_eprint_int(i32)\n")
    append_text(output, "declare void @__c_process_set_args(i32, i8**)\n")
    append_text(output, "declare i32 @__c_process_arg_count()\n")
    append_text(output, "declare i8* @__c_process_arg(i32)\n")
    append_text(output, "declare %dynarray_i32* @__c_str_to_bytes(i8*)\n")
    append_text(output, "declare %dynarray_i32* @__c_bytes_slice(%dynarray_i32*, i32, i32)\n")
    append_text(output, "declare %dynarray_i32* @__c_bytes_from_array(%dynarray_i32*)\n")
    append_text(output, "declare i32 @__c_bytes_get(%dynarray_i32*, i32)\n")
    append_text(output, "declare i32 @__c_bytes_length(%dynarray_i32*)\n")
    append_text(output, "declare i8* @__c_bytes_to_str(%dynarray_i32*)\n")
    append_text(output, "declare %dynarray_i32* @__c_utf8_encode_rune(i32)\n")
    append_text(output, "declare i32 @__c_utf8_rune_at(i8*, i32)\n")
    append_text(output, "declare i32 @__c_utf8_rune_count(i8*)\n")
    append_text(output, "declare %dynarray_i32* @create_dynarray_i32(i32)\n")
    append_text(output, "declare void @append_i32(%dynarray_i32*, i32)\n")
    append_text(output, "declare void @append_f64(%dynarray_i32*, double)\n")
    append_text(output, "declare void @append_pointer(%dynarray_i32*, i8*)\n")
    append_text(output, "declare double @get_f64(%dynarray_i32*, i32)\n")
    append_text(output, "declare i8* @get_pointer(%dynarray_i32*, i32)\n")
    append_text(output, "declare void @set_dynarray_i32(%dynarray_i32*, i32, i32)\n")
    append_text(output, "declare i32 @len_dynarray_i32(%dynarray_i32*)\n")
    append_text(output, "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n")
    append_text(output, "declare %dynarray_i32* @slice_dynarray_i32(%dynarray_i32*, i32, i32)\n")
    append_text(output, "declare %dynarray_i32* @concat_dynarray_i32(%dynarray_i32*, %dynarray_i32*)\n")
    append_text(output, "declare %dir_closure* @dream_closure_create(i8*, i8*)\n")
    append_text(output, "declare i8* @dream_closure_alloc(i64)\n")
    append_text(output, "declare %dict_t* @dream_dict_create_int_int(i32)\n")
    append_text(output, "declare %dict_t* @dream_dict_create_int_str(i32)\n")
    append_text(output, "declare %dict_t* @dream_dict_create_str_int(i32)\n")
    append_text(output, "declare %dict_t* @dream_dict_create_str_str(i32)\n")
    append_text(output, "declare void @dict_set_int_int(%dict_t*, i32, i32)\n")
    append_text(output, "declare void @dict_set_int_str(%dict_t*, i32, i8*)\n")
    append_text(output, "declare void @dict_set_str_int(%dict_t*, i8*, i32)\n")
    append_text(output, "declare void @dict_set_str_str(%dict_t*, i8*, i8*)\n")
    append_text(output, "declare i32 @dream_dict_get_int_int(%dict_t*, i32)\n")
    append_text(output, "declare i8* @dream_dict_get_int_str(%dict_t*, i32)\n")
    append_text(output, "declare i32 @dream_dict_get_str_int(%dict_t*, i8*)\n")
    append_text(output, "declare i8* @dream_dict_get_str_str(%dict_t*, i8*)\n")
    append_text(output, "declare i32 @dream_dict_size_int_int(%dict_t*)\n")
    append_text(output, "declare i32 @dream_dict_size_int_str(%dict_t*)\n")
    append_text(output, "declare i32 @dream_dict_size_str_int(%dict_t*)\n")
    append_text(output, "declare i32 @dream_dict_size_str_str(%dict_t*)\n")
    append_text(output, "define i32 @append(%dynarray_i32* %array, i32 %value) {\nentry:\ncall void @append_i32(%dynarray_i32* %array, i32 %value)\nret i32 0\n}\n")
    append_text(output, "define i32 @len(%dynarray_i32* %array) alwaysinline {\nentry:\n%is_null = icmp eq %dynarray_i32* %array, null\nbr i1 %is_null, label %len.invalid, label %len.valid\nlen.valid:\n%length_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 1\n%length = load i32, i32* %length_ptr\nret i32 %length\nlen.invalid:\nret i32 0\n}\n")
    append_text(output, "define i32 @get(%dynarray_i32* %array, i32 %index) alwaysinline {\nentry:\n%is_null = icmp eq %dynarray_i32* %array, null\nbr i1 %is_null, label %get.invalid, label %get.check\nget.check:\n%length_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 1\n%length = load i32, i32* %length_ptr\n%valid_low = icmp sge i32 %index, 0\n%valid_high = icmp slt i32 %index, %length\n%valid = and i1 %valid_low, %valid_high\nbr i1 %valid, label %get.valid, label %get.invalid\nget.valid:\n%data_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 2\n%data = load i32*, i32** %data_ptr\n%element_ptr = getelementptr i32, i32* %data, i32 %index\n%value = load i32, i32* %element_ptr\nret i32 %value\nget.invalid:\nret i32 0\n}\n")
    append_interface_artifacts(output, source, kinds, starts, ends, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    dir_flush_line(dir_records, output)
    collect_lambdas(parse_context, output, dir_records)
    dir_flush_line(dir_records, output)
    let dm_dir_record_index = 0
    while dm_dir_record_index < len(dm_dir_records):
        if dm_dir_records[dm_dir_record_index] == DM_DIR_RECORD_FUNCTION:
            let function_index = dm_dir_records[dm_dir_record_index + 1]
            emit_function(parse_context, function_index, output, dir_records, function_bodies, function_body_ends, parameter_types, constant_starts, constant_ends, constant_values, constant_types, global_let_name_starts, global_let_name_ends, global_let_types, global_let_expression_indexes)
        dm_dir_record_index = dm_dir_record_index + DM_DIR_RECORD_SIZE
    dir_flush_line(dir_records, output)
    if debug_enabled:
        stage_end = __c_time_ms()
        __c_eprint_text("emit: ")
        __c_eprint_int(stage_end - stage_start)
        __c_eprint_text(" ms\n")
        stage_start = stage_end
    if not dir_validate_records(dir_records):
        let dir_invalid_output = []
        append_text(dir_invalid_output, "; DIR validation failed\n")
        write_text_codes(output_path, dir_invalid_output)
        return
    if output_mode == COMPILE_OUTPUT_DIR_SOURCE:
        let formal_dir = []
        if not dir_render_formal_records(dir_records, formal_dir):
            append_text(formal_dir, "; formal DreamIR rendering failed\n")
        write_text_codes(output_path, formal_dir)
        return
    let llvm_output = []
    let dir_is_valid = dir_render_records(dir_records, llvm_output)
    if not dir_is_valid:
        append_text(llvm_output, "; DIR rendering failed\n")
    write_text_codes(output_path, llvm_output)
    if debug_enabled:
        stage_end = __c_time_ms()
        __c_eprint_text("render: ")
        __c_eprint_int(stage_end - stage_start)
        __c_eprint_text(" ms\ntotal: ")
        __c_eprint_int(stage_end - total_start)
        __c_eprint_text(" ms\n")

def compile_requested_source():
    let request_source_path = read_text_file("tmp/dream_bootstrap_source")
    let request_output_path = read_text_file("tmp/dream_bootstrap_output")
    if text_length(request_source_path) == 0:
        return
    if text_length(request_output_path) == 0:
        return
    compile_source(request_source_path, request_output_path, COMPILE_OUTPUT_LL)

def main():
    let argument_count = process_arg_count()
    if argument_count == 5 and process_arg(3) == "-o":
        let command_name = process_arg(1)
        switch command_name:
            case "llvm":
                compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_LL)
            case "compile":
                compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_LL)
            case "dir":
                compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_DIR_SOURCE)
            case "ast":
                compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_AST)
            case "build":
                let output_path = process_arg(4)
                let llvm_path = string_concat(output_path, ".dream.ll")
                compile_source(process_arg(2), llvm_path, COMPILE_OUTPUT_LL)
                if not build_llvm(llvm_path, output_path):
                    print(string_concat("构建失败: ", output_path))
            default:
                print(string_concat("未知命令: ", command_name))
        return
    let usage = " build <input.dm> -o <output> | llvm <input.dm> -o <output.ll> | dir <input.dm> -o <output.dir> | ast <input.dm> -o <output.ast>"
    print(string_concat("用法: ", string_concat(process_arg(0), usage)))
