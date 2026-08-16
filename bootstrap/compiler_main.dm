def module_path(module_name: str) -> str:
    if module_name == "bootstrap_io":
        return "stdlib/bootstrap_io.dm"
    if module_name == "dir_bootstrap":
        return "stdlib/dir_bootstrap.dm"
    if module_name == "compiler_lex":
        return "bootstrap/compiler_lex.dm"
    if module_name == "compiler_expr":
        return "bootstrap/compiler_expr.dm"
    if module_name == "compiler_stmt":
        return "bootstrap/compiler_stmt.dm"
    if module_name == "compiler_main":
        return "bootstrap/compiler_main.dm"
    let with_prefix = string_concat("stdlib/", module_name)
    return string_concat(with_prefix, ".dm")

def module_id(module_name: str) -> int:
    if module_name == "bootstrap_io":
        return 1
    if module_name == "dir_bootstrap":
        return 2
    if module_name == "compiler_lex":
        return 3
    if module_name == "compiler_expr":
        return 4
    if module_name == "compiler_stmt":
        return 5
    if module_name == "compiler_main":
        return 6
    return 0

def module_is_loaded(loaded_modules: list[int], module_identifier: int) -> bool:
    let module_index = 0
    while module_index < len(loaded_modules):
        if loaded_modules[module_index] == module_identifier:
            return true
        module_index = module_index + 1
    return false

def append_imported_module(imported_source: str, module_name: str) -> str:
    let imported_path = module_path(module_name)
    let module_source = read_text_file(imported_path)
    return string_concat(imported_source, string_concat(module_source, "\n"))

def load_imported_source(source: str) -> str:
    let import_kinds = []
    let import_starts = []
    let import_ends = []
    lex(source, import_kinds, import_starts, import_ends)
    let imported_source = ""
    let loaded_modules = []
    let token_index = 0
    while token_kind(import_kinds, token_index) != TOKEN_EOF:
        if token_kind(import_kinds, token_index) == TOKEN_IDENTIFIER and source_equals(source, token_start(import_starts, token_index), token_end(import_ends, token_index), "from"):
            let module_index = token_index + 1
            if token_kind(import_kinds, module_index) == TOKEN_IDENTIFIER:
                let module_name = source[token_start(import_starts, module_index):token_end(import_ends, module_index)]
                let module_identifier = module_id(module_name)
                if module_identifier != 0 and not module_is_loaded(loaded_modules, module_identifier):
                    imported_source = append_imported_module(imported_source, module_name)
                    append(loaded_modules, module_identifier)
        token_index = token_index + 1
    if len(loaded_modules) != 0:
        return string_concat(imported_source, string_concat("\n", source))
    return source

def compile_source(source_path: str, output_path: str):
    let source = load_imported_source(read_text_file(source_path))
    let kinds = []
    let starts = []
    let ends = []
    lex(source, kinds, starts, ends)
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
    collect_functions(source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types)
    collect_constants(source, kinds, starts, ends, constant_starts, constant_ends, constant_values, constant_types)
    let output = []
    append_text(output, "; function_count=")
    append_integer(output, len(function_starts))
    append_text(output, "\n")
    append_text(output, "; Dream Stage 1 LLVM bootstrap output\n")
    append_text(output, "%dynarray_i32 = type { i32, i32, i32* }\n")
    append_text(output, "%dict_t = type opaque\n")
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
    append_text(output, "declare void @dream_print_int(i32)\n")
    append_text(output, "declare void @dream_print_float(double)\n")
    append_text(output, "declare void @dream_print_bool(i1)\n")
    append_text(output, "declare void @dream_print_string(i8*)\n")
    append_text(output, "declare i8* @malloc(i32)\n")
    append_text(output, "declare i8* @string_substring(i8*, i32, i32)\n")
    append_text(output, "declare i8* @string_concat(i8*, i8*)\n")
    append_text(output, "declare i32 @string_compare(i8*, i8*)\n")
    append_text(output, "declare i8* @__c_file_read(i8*)\n")
    append_text(output, "declare i32 @__c_file_write(i8*, i8*)\n")
    append_text(output, "declare i32 @__c_file_write_bytes(i8*, %dynarray_i32*)\n")
    append_text(output, "declare i32 @__c_utf8_rune_at(i8*, i32)\n")
    append_text(output, "declare i32 @__c_utf8_rune_count(i8*)\n")
    append_text(output, "declare %dynarray_i32* @create_dynarray_i32(i32)\n")
    append_text(output, "declare void @append_i32(%dynarray_i32*, i32)\n")
    append_text(output, "declare void @set_dynarray_i32(%dynarray_i32*, i32, i32)\n")
    append_text(output, "declare i32 @len_dynarray_i32(%dynarray_i32*)\n")
    append_text(output, "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n")
    append_text(output, "declare %dynarray_i32* @slice_dynarray_i32(%dynarray_i32*, i32, i32)\n")
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
    collect_lambdas(source, kinds, starts, ends, output, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let function_index = 0
    while function_index < len(function_starts):
        emit_function(source, kinds, starts, ends, function_index, output, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types, constant_starts, constant_ends, constant_values, constant_types)
        function_index = function_index + 1
    let dir_output = []
    let dir_is_valid = dir_lower_buffer(output, dir_output)
    if not dir_is_valid:
        append_text(dir_output, "; DIR validation failed\n")
    write_text_codes(output_path, dir_output)

def compile_requested_source():
    let request_source_path = read_text_file("tmp/dream_bootstrap_source")
    let request_output_path = read_text_file("tmp/dream_bootstrap_output")
    if text_length(request_source_path) == 0:
        return
    if text_length(request_output_path) == 0:
        return
    compile_source(request_source_path, request_output_path)

def main():
    compile_source("bootstrap/sample_functions.dm", "bootstrap/stage1.ll")
    compile_source("bootstrap/compiler.dm", "bootstrap/stage2.ll")
    compile_source("bootstrap/compiler.dm", "bootstrap/stage3.ll")
    compile_requested_source()
