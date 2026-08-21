from text_buffer import TextBuffer

const COMPILE_OUTPUT_AST: int = 0
const COMPILE_OUTPUT_HIR: int = 1
const COMPILE_OUTPUT_MIR: int = 2

def module_path(module_name: str) -> str:
    switch module_name:
        case "bootstrap_io":
            return "runtime/stdlib/bootstrap_io.dm"
        case "compiler_lex":
            return "bootstrap/compiler_lex.dm"
        case "compiler_ast":
            return "bootstrap/compiler_ast.dm"
        case "compiler_hir_model":
            return "bootstrap/compiler_hir_model.dm"
        case "compiler_mir_model":
            return "bootstrap/compiler_mir_model.dm"
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

def append_imported_module(imported_source: str, module_name: str, file_packages: list[int], file_starts: list[int], file_ends: list[int]) -> str:
    let imported_path = module_path(module_name)
    let module_source = read_text_file(imported_path)
    let start_offset = text_length(imported_source)
    let new_source = string_concat(imported_source, string_concat(module_source, "\n"))
    let end_offset = text_length(new_source)
    append(file_packages, classify_package(imported_path))
    append(file_starts, start_offset)
    append(file_ends, end_offset)
    return new_source

def load_imported_source(source: str, source_path: str, file_packages: list[int], file_starts: list[int], file_ends: list[int]) -> str:
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
                        imported_source = append_imported_module(imported_source, module_name, file_packages, file_starts, file_ends)
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
        return final_source
    append(file_packages, classify_package(source_path))
    append(file_starts, 0)
    append(file_ends, text_length(source))
    return source

def write_text_buffer(path: str, output: TextBuffer) -> int:
    let bytes = __c_bytes_from_array(output.data)
    return __c_file_write_bytes(path, bytes)

struct AstCompilation:
    nodes: list[int]
    function_nodes_start: list[int]
    function_nodes_end: list[int]
    global_nodes: list[int]
    is_built: bool
    is_valid: bool

def build_ast_compilation(context: ParseContext, function_bodies: list[int], function_body_ends: list[int], global_let_expression_indexes: list[int]) -> AstCompilation:
    let nodes = []
    let function_nodes_start = []
    let function_nodes_end = []
    let global_nodes = []
    let is_built = ast_build_program(context, nodes, function_nodes_start, function_nodes_end, global_nodes, function_bodies, function_body_ends, global_let_expression_indexes)
    let is_valid = false
    if is_built:
        is_valid = ast_validate_program(nodes)
    return AstCompilation{nodes: nodes, function_nodes_start: function_nodes_start, function_nodes_end: function_nodes_end, global_nodes: global_nodes, is_built: is_built, is_valid: is_valid}

def write_ast_validation_error(output_path: str, compilation: AstCompilation):
    let output = TextBuffer{data: []}
    append(output, "; AST validation failed nodes=")
    append(output, len(compilation.nodes))
    append(output, " functions=")
    append(output, len(compilation.function_nodes_start))
    append(output, " valid=")
    if compilation.is_built:
        append(output, "build")
    if not compilation.is_built:
        append(output, "parse")
    append(output, " pool=")
    let pool_index = 0
    while pool_index < len(compilation.nodes) and pool_index < 24:
        append(output, compilation.nodes[pool_index])
        append(output, ",")
        pool_index = pool_index + 1
    append(output, "\n")
    write_text_buffer(output_path, output)

def write_ast_output(output_path: str, source: str, function_starts: list[int], function_ends: list[int], compilation: AstCompilation):
    let ast = compilation.nodes
    let output = TextBuffer{data: []}
    append(output, "module dream\nfunctions=")
    append(output, len(compilation.function_nodes_start))
    append(output, " pool=")
    append(output, len(ast))
    append(output, "\n")
    let function_index = 0
    while function_index < len(compilation.function_nodes_start):
        append(output, "func ")
        append(output, function_index)
        append(output, " ")
        append(output, source[function_starts[function_index]:function_ends[function_index]])
        append(output, " body=")
        append(output, compilation.function_nodes_start[function_index])
        append(output, "..")
        append(output, compilation.function_nodes_end[function_index])
        append(output, "\n")
        function_index = function_index + 1
    let node = 1
    while node < len(ast):
        let kind = ast[node]
        let size = ast_node_size(kind)
        if size < AST_HEADER_SIZE:
            append(output, "; unknown kind ")
            append(output, kind)
            append(output, " at ")
            append(output, node)
            append(output, "\n")
            node = node + 1
        else:
            append(output, "  n")
            append(output, node)
            append(output, " ")
            append(output, ast_kind_name(kind))
            append(output, " s")
            append(output, size)
            append(output, ":")
            let argument_index = 0
            while argument_index < size - AST_HEADER_SIZE and argument_index < 12:
                append(output, " ")
                append(output, ast[node + AST_HEADER_SIZE + argument_index])
                argument_index = argument_index + 1
            append(output, "\n")
            node = node + size
    write_text_buffer(output_path, output)

def compile_source(source_path: str, output_path: str, output_mode: int):
    access_violation_count[0] = 0
    let raw_source = read_text_file(source_path)
    let file_packages = []
    let file_starts: list[int] = []
    let file_ends: list[int] = []
    let source = load_imported_source(raw_source, source_path, file_packages, file_starts, file_ends)
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
    let parameter_default_indexes = []
    collect_declared_types(source, kinds, starts, ends)
    collect_functions(source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types, function_return_types, parameter_default_indexes)
    collect_constants(source, kinds, starts, ends, constant_starts, constant_ends, constant_values, constant_types)
    let parse_context = ParseContext{src: source, kinds: kinds, starts: starts, ends: ends, fn_starts: function_starts, fn_ends: function_ends, param_offsets: function_param_offsets, param_counts: function_param_counts, param_starts: parameter_starts, param_ends: parameter_ends, ret_types: function_return_types, pd: parameter_default_indexes, cst_starts: constant_starts, cst_ends: constant_ends, cst_values: constant_values, file_packages: file_packages, file_starts: file_starts, file_ends: file_ends}
    let global_let_name_starts = []
    let global_let_name_ends = []
    let global_let_collected_types = []
    let global_let_expression_indexes = []
    collect_global_lets(source, kinds, starts, ends, global_let_name_starts, global_let_name_ends, global_let_collected_types, global_let_expression_indexes)
    let ast_compilation = build_ast_compilation(parse_context, function_bodies, function_body_ends, global_let_expression_indexes)
    if not ast_compilation.is_valid:
        write_ast_validation_error(output_path, ast_compilation)
        return
    if output_mode == COMPILE_OUTPUT_AST:
        write_ast_output(output_path, source, function_starts, function_ends, ast_compilation)
        return
    let hir_program = hir_model_build_program(ast_compilation.nodes, ast_compilation.function_nodes_start, ast_compilation.function_nodes_end, ast_compilation.global_nodes)
    if output_mode == COMPILE_OUTPUT_HIR:
        let hir_output = TextBuffer{data: []}
        if not hir_model_dump_program(hir_program, hir_output):
            append(hir_output, "HIR validation failed\n")
        write_text_buffer(output_path, hir_output)
        return
    if output_mode == COMPILE_OUTPUT_MIR:
        let mir_program = mir_model_build_program(hir_program.records)
        let mir_output = TextBuffer{data: []}
        if not mir_validate_program(mir_program) or not mir_dump_program(mir_program, mir_output):
            append(mir_output, "MIR validation failed\n")
        write_text_buffer(output_path, mir_output)
        return
    __c_eprint_text("error: only ast, hir, and mir outputs are supported\n")

def main():
    let argument_count = process_arg_count()
    if argument_count == 5 and process_arg(3) == "-o":
        let command_name = process_arg(1)
        if command_name == "ast":
            compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_AST)
        elif command_name == "hir":
            compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_HIR)
        elif command_name == "mir":
            compile_source(process_arg(2), process_arg(4), COMPILE_OUTPUT_MIR)
        else:
            __c_eprint_text("error: use ast, hir, or mir\n")
        return
    let usage = " ast <input.dm> -o <output> | hir <input.dm> -o <output> | mir <input.dm> -o <output>"
    print(string_concat("用法: ", string_concat(process_arg(0), usage)))
