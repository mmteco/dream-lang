from text_buffer import TextBuffer

const COMPILE_OUTPUT_AST: int = 0
const COMPILE_OUTPUT_HIR: int = 1
const COMPILE_OUTPUT_MIR: int = 2
const COMPILE_OUTPUT_LIR: int = 3
const COMPILE_OUTPUT_LLVM: int = 4

def module_path(module_name: str) -> str:
    switch module_name:
        case "bootstrap_io":
            return "runtime/stdlib/bootstrap_io.dm"
        case "compiler_lex":
            return "bootstrap/compiler_lex.dm"
        case "compiler_operator":
            return "bootstrap/compiler_operator.dm"
        case "compiler_external":
            return "bootstrap/compiler_external.dm"
        case "compiler_ast":
            return "bootstrap/compiler_ast.dm"
        case "compiler_hir_model":
            return "bootstrap/compiler_hir_model.dm"
        case "compiler_mir_model":
            return "bootstrap/compiler_mir_model.dm"
        case "compiler_mir_opt":
            return "bootstrap/compiler_mir_opt.dm"
        case "compiler_lir_model":
            return "bootstrap/compiler_lir_model.dm"
        case "compiler_llvm_emit":
            return "bootstrap/compiler_llvm_emit.dm"
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

def append_imported_module(imported_source: str, module_name: str, file_packages: list[int], file_starts: list[int], file_ends: list[int], file_paths: TextBuffer) -> str:
    let imported_path = module_path(module_name)
    let module_source = read_text_file(imported_path)
    let start_offset = text_length(imported_source)
    let new_source = string_concat(imported_source, string_concat(module_source, "\n"))
    let end_offset = text_length(new_source)
    append(file_packages, classify_package(imported_path))
    append(file_starts, start_offset)
    append(file_ends, end_offset)
    append(file_paths, imported_path)
    append(file_paths, "\n")
    return new_source

def load_imported_source(source: str, source_path: str, file_packages: list[int], file_starts: list[int], file_ends: list[int], file_paths: TextBuffer) -> str:
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
                        imported_source = append_imported_module(imported_source, module_name, file_packages, file_starts, file_ends, file_paths)
                        loaded_modules = string_concat(loaded_modules, string_concat(module_name, "\n"))
                        found_new_module = true
            token_index = token_index + 1
        if found_new_module:
            scan_source = imported_source
        scan_round = scan_round + 1
    let user_source_start = text_length(imported_source)
    if text_length(loaded_modules) != 0:
        user_source_start = user_source_start + 1
        let final_source = string_concat(imported_source, string_concat("\n", source))
        append(file_packages, classify_package(source_path))
        append(file_starts, user_source_start)
        append(file_ends, text_length(final_source))
        append(file_paths, source_path)
        append(file_paths, "\n")
        return final_source
    append(file_packages, classify_package(source_path))
    append(file_starts, 0)
    append(file_ends, text_length(source))
    append(file_paths, source_path)
    append(file_paths, "\n")
    return source

def write_text_buffer(path: str, output: TextBuffer) -> int:
    let bytes = __c_bytes_from_array(output.data)
    return __c_file_write_bytes(path, bytes)

def write_byte_output(path: str, output: list[byte]) -> int:
    let bytes = __c_bytes_from_array(output)
    return __c_file_write_bytes(path, bytes)

def ast_output_append_text(output: list[byte], value: str):
    let bytes = __c_str_to_bytes(value)
    let index = 0
    let length = __c_bytes_length(bytes)
    while index < length:
        let current = __c_bytes_get(bytes, index)
        if current == 92 and index + 1 < length and __c_bytes_get(bytes, index + 1) == 110:
            append(output, 10)
            index = index + 2
        else:
            append(output, current)
            index = index + 1

def ast_output_append_int(output: list[byte], value: int):
    if value == 0:
        append(output, b'0')
        return

    let is_negative = value < 0
    if is_negative:
        append(output, b'-')
        value = 0 - value

    let digits: list[int] = []
    while value > 0:
        let digit = value % 10
        append(digits, 48 + digit)
        value = value / 10

    let index = len(digits) - 1
    while index >= 0:
        append(output, ast_int_list_get(digits, index))
        index = index - 1

def compiler_debug_start() -> int:
    if __c_debug_on():
        return __c_time_ms()
    return 0

def compiler_debug_checkpoint(label: str, previous_time: int) -> int:
    if not __c_debug_on():
        return previous_time
    let current_time = __c_time_ms()
    __c_eprint_text("[timing] ")
    __c_eprint_text(label)
    __c_eprint_text(" ")
    __c_eprint_int(current_time - previous_time)
    __c_eprint_text("ms\n")
    return current_time

def build_ast_compilation(context: ParseContext, function_bodies: list[int], function_body_ends: list[int], global_let_expression_indexes: list[int], nodes: list[int], function_nodes_start: list[int], function_nodes_end: list[int], global_nodes: list[int]) -> bool:
    if not ast_build_program(context, nodes, function_nodes_start, function_nodes_end, global_nodes, function_bodies, function_body_ends, global_let_expression_indexes):
        return false
    return ast_validate_program(nodes)

def write_ast_output(output_path: str, source: str, function_starts: list[int], function_ends: list[int], nodes: list[int], function_nodes_start: list[int], function_nodes_end: list[int]):
    let ast = nodes
    let output: list[byte] = []
    ast_output_append_text(output, "module dream\nfunctions=")
    ast_output_append_int(output, len(function_nodes_start))
    ast_output_append_text(output, " pool=")
    ast_output_append_int(output, len(ast))
    ast_output_append_text(output, "\n")
    let function_index = 0
    while function_index < len(function_nodes_start):
        ast_output_append_text(output, "func ")
        ast_output_append_int(output, function_index)
        ast_output_append_text(output, " ")
        ast_output_append_text(output, source[function_starts[function_index]:function_ends[function_index]])
        ast_output_append_text(output, " body=")
        ast_output_append_int(output, function_nodes_start[function_index])
        ast_output_append_text(output, "..")
        ast_output_append_int(output, function_nodes_end[function_index])
        ast_output_append_text(output, "\n")
        function_index = function_index + 1
    let node = 1
    while node < len(ast):
        let kind = ast[node]
        let size = ast_node_size(ast, node)
        if size < AST_HEADER_SIZE:
            ast_output_append_text(output, "; unknown kind ")
            ast_output_append_int(output, kind)
            ast_output_append_text(output, " at ")
            ast_output_append_int(output, node)
            ast_output_append_text(output, "\n")
            node = node + 1
        else:
            ast_output_append_text(output, "  n")
            ast_output_append_int(output, node)
            ast_output_append_text(output, " ")
            ast_output_append_text(output, ast_kind_name(kind))
            ast_output_append_text(output, " s")
            ast_output_append_int(output, size)
            ast_output_append_text(output, ":")
            let argument_index = 0
            while argument_index < size - AST_HEADER_SIZE and argument_index < 12:
                ast_output_append_text(output, " ")
                ast_output_append_int(output, ast[node + AST_HEADER_SIZE + argument_index])
                argument_index = argument_index + 1
            ast_output_append_text(output, "\n")
            node = node + size
    write_byte_output(output_path, output)

def compile_source(source_path: str, output_path: str, output_mode: int) -> bool:
    access_violation_count[0] = 0
    let phase_time = compiler_debug_start()
    let raw_source = read_text_file(source_path)
    let file_packages = []
    let file_starts: list[int] = []
    let file_ends: list[int] = []
    let file_paths = TextBuffer{data: []}
    let source = load_imported_source(raw_source, source_path, file_packages, file_starts, file_ends, file_paths)
    phase_time = compiler_debug_checkpoint("load", phase_time)
    let kinds = []
    let starts = []
    let ends = []
    lex(source, kinds, starts, ends)
    phase_time = compiler_debug_checkpoint("lex", phase_time)
    let function_starts = []
    let function_ends = []
    let function_bodies = []
    let function_body_ends = []
    let function_param_offsets = []
    let function_param_counts = []
    let parameter_starts = []
    let parameter_ends = []
    let parameter_types = []
    let parameter_struct_decls = []
    let function_return_types = []
    let function_return_struct_decls = []
    let constant_starts = []
    let constant_ends = []
    let constant_values = []
    let constant_types = []
    let constant_literal_starts = []
    let constant_literal_ends = []
    let parameter_default_indexes = []
    let parameter_annotation_starts: list[int] = []
    let parameter_annotation_ends: list[int] = []
    let ast_nodes: list[int] = []
    let ast_function_nodes_start: list[int] = []
    let ast_function_nodes_end: list[int] = []
    let ast_global_nodes: list[int] = []
    collect_declared_types(source, kinds, starts, ends)
    collect_struct_fields(source, kinds, starts, ends)
    collect_functions(source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, parameter_struct_decls, function_return_types, function_return_struct_decls, parameter_default_indexes, parameter_annotation_starts, parameter_annotation_ends)
    collect_constants(source, kinds, starts, ends, constant_starts, constant_ends, constant_values, constant_types, constant_literal_starts, constant_literal_ends)
    let impl_func_indexes: list[int] = []
    let impl_func_decls: list[int] = []
    let impl_func_interface_types: list[int] = []
    collect_impl_functions(source, kinds, starts, ends, function_starts, function_ends, impl_func_indexes, impl_func_decls, impl_func_interface_types)
    let interface_name_starts: list[int] = []
    let interface_name_ends: list[int] = []
    let impl_function_indexes: list[int] = []
    let impl_decl_indexes: list[int] = []
    let impl_interface_name_starts: list[int] = []
    let impl_interface_name_ends: list[int] = []
    collect_interfaces(source, kinds, starts, ends, function_starts, interface_name_starts, interface_name_ends, impl_function_indexes, impl_decl_indexes, impl_interface_name_starts, impl_interface_name_ends)
    phase_time = compiler_debug_checkpoint("collect", phase_time)
    let parse_context = ParseContext{src: source, kinds: kinds, starts: starts, ends: ends, fn_starts: function_starts, fn_ends: function_ends, param_offsets: function_param_offsets, param_counts: function_param_counts, param_starts: parameter_starts, param_ends: parameter_ends, ret_types: function_return_types, pd: parameter_default_indexes, cst_starts: constant_starts, cst_ends: constant_ends, cst_values: constant_values, file_packages: file_packages, file_starts: file_starts, file_ends: file_ends}
    let global_let_name_starts = []
    let global_let_name_ends = []
    let global_let_collected_types = []
    let global_let_expression_indexes = []
    collect_global_lets(source, kinds, starts, ends, global_let_name_starts, global_let_name_ends, global_let_collected_types, global_let_expression_indexes)
    let is_ast_valid = build_ast_compilation(parse_context, function_bodies, function_body_ends, global_let_expression_indexes, ast_nodes, ast_function_nodes_start, ast_function_nodes_end, ast_global_nodes)
    phase_time = compiler_debug_checkpoint("ast", phase_time)
    if not is_ast_valid:
        __c_eprint_text("error: AST validation failed\n")
        return false
    if output_mode == COMPILE_OUTPUT_AST:
        write_ast_output(output_path, source, function_starts, function_ends, ast_nodes, ast_function_nodes_start, ast_function_nodes_end)
        return true
    let hir_records: list[int] = []
    let hir_values: list[int] = []
    let hir_struct_decls: list[int] = []
    if not hir_model_build_program(ast_nodes, ast_function_nodes_start, ast_function_nodes_end, ast_global_nodes, global_let_name_starts, global_let_name_ends, global_let_collected_types, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types, parameter_default_indexes, constant_starts, constant_ends, constant_types, hir_records, hir_values, hir_struct_decls):
        __c_eprint_text("error: HIR build failed\n")
        return false
    let hir_output_records: list[int] = []
    let hir_output_struct_decls: list[int] = []
    if output_mode == COMPILE_OUTPUT_HIR:
        let copy_index = 0
        while copy_index < len(hir_records):
            append(hir_output_records, hir_int_list_get(hir_records, copy_index))
            copy_index = copy_index + 1
        copy_index = 0
        while copy_index < len(hir_struct_decls):
            append(hir_output_struct_decls, hir_int_list_get(hir_struct_decls, copy_index))
            copy_index = copy_index + 1
    phase_time = compiler_debug_checkpoint("hir-build", phase_time)
    let validated_hir_records: list[int] = []
    let validated_hir_struct_decls: list[int] = []
    if not hir_validate_semantics(hir_records, hir_values, hir_struct_decls, source, validated_hir_records, validated_hir_struct_decls):
        __c_eprint_text("error: HIR semantic validation failed\n")
        return false
    let hir_program = HirProgram{records: validated_hir_records, values: hir_values, struct_decls: validated_hir_struct_decls}
    phase_time = compiler_debug_checkpoint("hir-validate", phase_time)
    if output_mode == COMPILE_OUTPUT_HIR:
        let raw_hir_program = HirProgram{records: hir_output_records, values: hir_values, struct_decls: hir_output_struct_decls}
        let hir_output: list[byte] = []
        if not hir_model_dump_program(raw_hir_program, hir_output):
            __c_eprint_text("error: HIR validation failed while dumping\n")
            return false
        write_byte_output(output_path, hir_output)
        compiler_debug_checkpoint("hir-dump", phase_time)
        return true
    let mir_program = mir_model_build_program(validated_hir_records, hir_values, validated_hir_struct_decls, source, constant_starts, constant_ends, constant_values, constant_types, constant_literal_starts, constant_literal_ends, function_return_struct_decls, function_param_offsets, parameter_struct_decls, parameter_default_indexes, parameter_annotation_starts, parameter_annotation_ends, impl_func_indexes, impl_func_decls, impl_func_interface_types, interface_name_starts, interface_name_ends, impl_function_indexes, impl_decl_indexes, impl_interface_name_starts, impl_interface_name_ends)
    phase_time = compiler_debug_checkpoint("mir-build", phase_time)
    let optimized_mir_program = mir_optimize_program(mir_program)
    phase_time = compiler_debug_checkpoint("mir-opt", phase_time)
    if output_mode == COMPILE_OUTPUT_MIR:
        let mir_output: list[byte] = []
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        if not mir_dump_program(optimized_mir_program, mir_output):
            __c_eprint_text("error: MIR validation failed while dumping\n")
            return false
        write_byte_output(output_path, mir_output)
        return true
    elif output_mode == COMPILE_OUTPUT_LIR:
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let lir_output = TextBuffer{data: []}
        let is_lir_valid = lir_validate_program(lir_program)
        phase_time = compiler_debug_checkpoint("lir-validate", phase_time)
        if not is_lir_valid:
            __c_eprint_text("error: LIR validation failed\n")
            return false
        if not lir_dump_validated_program(lir_program, lir_output):
            __c_eprint_text("error: LIR validation failed while dumping\n")
            return false
        write_text_buffer(output_path, lir_output)
        return true
    elif output_mode == COMPILE_OUTPUT_LLVM:
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let llvm_output = TextBuffer{data: []}
        let is_lir_valid = lir_validate_program(lir_program)
        phase_time = compiler_debug_checkpoint("lir-validate", phase_time)
        if not is_lir_valid:
            __c_eprint_text("error: LIR validation failed\n")
            return false
        let is_llvm_valid = llvm_lower_lir(lir_program, source, llvm_output)
        phase_time = compiler_debug_checkpoint("llvm-lower", phase_time)
        if not is_llvm_valid:
            __c_eprint_text("error: LLVM lowering failed\n")
            return false
        write_text_buffer(output_path, llvm_output)
        return true
    __c_eprint_text("error: only ast, hir, mir, lir, and llvm outputs are supported\n")
    return false

struct BuildArguments:
    input_path: str
    output_path: str
    is_optimized: bool
    is_valid: bool

def remove_source_extension(source_path: str) -> str:
    let index = text_length(source_path) - 1
    while index >= 0:
        if source_path[index] == '.':
            if index > 0:
                return source_path[0:index]
            return source_path
        index = index - 1
    return source_path

def parse_build_arguments(argument_count: int):
    let input_path = ""
    let output_path = ""
    let is_optimized = true
    let is_valid = true
    if argument_count >= 3:
        input_path = process_arg(2)
    if argument_count >= 5 and process_arg(3) == "-o":
        output_path = process_arg(4)
    elif argument_count >= 4:
        output_path = process_arg(3)
    if text_length(input_path) < 3:
        is_valid = false
    BA_input_path = input_path
    BA_output_path = output_path
    BA_is_optimized = is_optimized
    BA_is_valid = is_valid

def build_source(source_path: str, output_path: str, is_optimized: bool) -> bool:
    let llvm_path = string_concat(output_path, ".ll")
    if not compile_source(source_path, llvm_path, COMPILE_OUTPUT_LLVM):
        return false
    let is_built = build_llvm(llvm_path, output_path, is_optimized)
    if not is_built:
        __c_file_delete(llvm_path)
        __c_eprint_text("error: failed to build executable\n")
        return false
    return true

def run_build_command(argument_count: int) -> bool:
    parse_build_arguments(argument_count)
    if not BA_is_valid:
        __c_eprint_text("error: build accepts [--dev] <file.dm> [-o output]\n")
        return false
    let input_length = text_length(BA_input_path)
    if input_length < 3 or BA_input_path[input_length - 3:input_length] != ".dm":
        __c_eprint_text("error: input file must have .dm extension\n")
        return false
    return build_source(BA_input_path, BA_output_path, BA_is_optimized)

def main() -> int:
    let argument_count = process_arg_count()
    let usage = " build [--dev] <file.dm> [-o output] | ast/hir/mir/lir/llvm <input.dm> -o <output>"
    if argument_count == 2:
        let command_name = process_arg(1)
        if command_name == "help" or command_name == "--help":
            print(string_concat("用法: ", string_concat(process_arg(0), usage)))
            return 0
    if argument_count >= 4 and process_arg(1) == "build" and process_arg(3) == "-o":
        if build_source(process_arg(2), process_arg(4), true):
            return 0
        return 1
    if argument_count == 5 and process_arg(3) == "-o":
        let command_name = process_arg(1)
        if command_name == "ast":
            if compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_AST):
                return 0
        elif command_name == "hir":
            if compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_HIR):
                return 0
        elif command_name == "mir":
            if compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_MIR):
                return 0
        elif command_name == "lir":
            if compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_LIR):
                return 0
        elif command_name == "llvm":
            if compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_LLVM):
                return 0
        else:
            __c_eprint_text("error: use ast, hir, mir, lir, or llvm\n")
        return 1
    print(string_concat("用法: ", string_concat(process_arg(0), usage)))
    return 1
