from buffer import Buffer
from io import read, write, exists
from sys import argc, arg, env, build

const COMPILE_OUTPUT_AST: int = 0
const COMPILE_OUTPUT_HIR: int = 1
const COMPILE_OUTPUT_MIR: int = 2
const COMPILE_OUTPUT_LIR: int = 3
const COMPILE_OUTPUT_LLVM: int = 4

def module_path(module_name: str) -> str:
    switch module_name:
        case "sys":
            return "runtime/stdlib/sys.dm"
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
    let configured_paths = env("DREAM_MODULE_PATH")
    let path_start = 0
    let path_end = 0
    let path_length = len(configured_paths)
    while path_end <= path_length:
        if path_end == path_length or configured_paths[path_end] == ':':
            if path_end > path_start:
                let root = configured_paths[path_start:path_end]
                let candidate = root + "/"
                candidate = candidate + module_name
                candidate = candidate + ".dm"
                if exists(candidate):
                    return candidate
            path_start = path_end + 1
        path_end = path_end + 1
    let with_prefix = "runtime/stdlib/" + module_name
    return with_prefix + ".dm"

def module_is_loaded(loaded_modules: str, module_name: str) -> bool:
    let module_start = 0
    let loaded_length = len(loaded_modules)
    while module_start < loaded_length:
        let module_end = module_start
        while module_end < loaded_length and ord(loaded_modules[module_end]) != 10:
            module_end = module_end + 1
        if loaded_modules[module_start:module_end] == module_name:
            return true
        module_start = module_end + 1
    return false

def add_imported_module(imported_source: str, module_name: str, file_packages: list[int], file_starts: list[int],
    file_ends: list[int], file_paths: Buffer) -> str:
    let imported_path = module_path(module_name)
    let module_source = read(imported_path)
    let start_offset = len(imported_source)
    let new_source = imported_source + module_source
    new_source = new_source + "\n"
    let end_offset = len(new_source)
    append(file_packages, classify_package(imported_path))
    append(file_starts, start_offset)
    append(file_ends, end_offset)
    append(file_paths, imported_path)
    append(file_paths, "\n")
    return new_source

def mask_source_range(source: str, start: int, end: int) -> str:
    let masked = ""
    let index = 0
    while index < len(source):
        if index >= start and index < end and source[index] != '\n':
            masked = masked + " "
        else:
            masked = masked + source[index:index + 1]
        index = index + 1
    return masked

def rewrite_module_namespace(source: str, module_names: str) -> str:
    let rewritten_source = source
    let kinds = []
    let starts = []
    let ends = []
    let tokens = TokenStream{
        src: source,
        kinds: kinds,
        starts: starts,
        ends: ends
    }
    lex(tokens)
    let module_start = 0
    let module_length = len(module_names)
    while module_start < module_length:
        let module_end = module_start
        while module_end < module_length and module_names[module_end] != '\n':
            module_end = module_end + 1
        let module_name = module_names[module_start:module_end]
        let token_index = 0
        while token_kind(kinds, token_index) != TOKEN_EOF:
            let token_start_offset = token_start(starts, token_index)
            let token_end_offset = token_end(ends, token_index)
            if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_equals(source, token_start_offset,
                token_end_offset, "import") and not (token_index > 1 and token_kind(kinds,
                token_index - 2) == TOKEN_IDENTIFIER and source_equals(source, token_start(starts,
                token_index - 2), token_end(ends, token_index - 2), "from")):
                let line_end_index = token_index
                while token_kind(kinds, line_end_index) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                    line_end_index = line_end_index + 1
                let line_end_offset = token_end_offset
                if token_kind(kinds, line_end_index) == TOKEN_NEWLINE:
                    line_end_offset = token_start(starts, line_end_index)
                rewritten_source = mask_source_range(rewritten_source, token_start_offset, line_end_offset)
            if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_equals(source, token_start_offset,
                token_end_offset, module_name):
                let dot_index = token_index + 1
                if token_kind(kinds, dot_index) == TOKEN_DOT:
                    let dot_end_offset = token_end(ends, dot_index)
                    rewritten_source = mask_source_range(rewritten_source, token_start_offset, dot_end_offset)
            token_index = token_index + 1
        module_start = module_end + 1
    return rewritten_source

def load_imported_source(source: str, source_path: str, file_packages: list[int], file_starts: list[int],
    file_ends: list[int], file_paths: Buffer) -> str:
    let imported_source = ""
    let loaded_modules = ""
    let namespace_modules = ""
    let scan_source = source
    let scan_round = 0
    let found_new_module = true
    while scan_round < 64 and found_new_module:
        let import_kinds = []
        let import_starts = []
        let import_ends = []
        let tokens = TokenStream{
            src: scan_source,
            kinds: import_kinds,
            starts: import_starts,
            ends: import_ends
        }
        lex(tokens)
        found_new_module = false
        let token_index = 0
        while token_kind(import_kinds, token_index) != TOKEN_EOF:
            if token_kind(import_kinds, token_index) == TOKEN_IDENTIFIER and source_equals(scan_source,
                token_start(import_starts, token_index), token_end(import_ends, token_index), "from"):
                let module_index = token_index + 1
                if token_kind(import_kinds, module_index) == TOKEN_IDENTIFIER:
                    let module_name = scan_source[token_start(import_starts, module_index):token_end(import_ends,
                        module_index)]
                    if not module_is_loaded(loaded_modules, module_name):
                        imported_source = add_imported_module(imported_source, module_name, file_packages,
                            file_starts, file_ends, file_paths)
                        loaded_modules = loaded_modules + module_name
                        loaded_modules = loaded_modules + "\n"
                        found_new_module = true
            if (
                token_kind(import_kinds, token_index) == TOKEN_IDENTIFIER and
                scan_source[token_start(import_starts, token_index):token_end(import_ends, token_index)] == "import" and
                not (
                    token_index > 1 and
                    token_kind(import_kinds, token_index - 2) == TOKEN_IDENTIFIER and
                    scan_source[token_start(import_starts, token_index - 2):token_end(import_ends,
                        token_index - 2)] == "from"
                )
            ):
                let module_index = token_index + 1
                if token_kind(import_kinds, module_index) == TOKEN_IDENTIFIER:
                    let module_name = scan_source[token_start(import_starts, module_index):token_end(import_ends,
                        module_index)]
                    if not module_is_loaded(loaded_modules, module_name):
                        imported_source = add_imported_module(imported_source, module_name, file_packages,
                            file_starts, file_ends, file_paths)
                        loaded_modules = loaded_modules + module_name
                        loaded_modules = loaded_modules + "\n"
                        found_new_module = true
                    if not module_is_loaded(namespace_modules, module_name):
                        namespace_modules = namespace_modules + module_name
                        namespace_modules = namespace_modules + "\n"
            token_index = token_index + 1
        if found_new_module:
            scan_source = imported_source
        scan_round = scan_round + 1
    let user_source_start = len(imported_source)
    if len(loaded_modules) != 0:
        user_source_start = user_source_start + 1
        let rewritten_source = rewrite_module_namespace(source, namespace_modules)
        let final_source = imported_source + "\n"
        final_source = final_source + rewritten_source
        append(file_packages, classify_package(source_path))
        append(file_starts, user_source_start)
        append(file_ends, len(final_source))
        append(file_paths, source_path)
        append(file_paths, "\n")
        return final_source
    append(file_packages, classify_package(source_path))
    append(file_starts, 0)
    append(file_ends, len(source))
    append(file_paths, source_path)
    append(file_paths, "\n")
    return rewrite_module_namespace(source, namespace_modules)

def write_buffer(path: str, output: Buffer) -> int:
    return __c_file_write_bytes(path, __c_bytes_from_array(output.data))

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

def build_ast_compilation(
    context: ParseContext,
    func_bodies: list[int],
    func_body_ends: list[int],
    global_let_expression_indexes: list[int],
    nodes: list[int],
    func_nodes_start: list[int],
    func_nodes_end: list[int],
    global_nodes: list[int]
) -> bool:
    if not ast_build_program(context, nodes, func_nodes_start, func_nodes_end, global_nodes, func_bodies,
        func_body_ends, global_let_expression_indexes):
        return false
    return ast_validate_program(nodes)

def write_ast_output(output_path: str, source: str, func_starts: list[int], func_ends: list[int],
    nodes: list[int], func_nodes_start: list[int], func_nodes_end: list[int]):
    let ast = nodes
    let output = Buffer{data: []}
    append(output, "module dream\nfunctions=")
    append(output, len(func_nodes_start))
    append(output, " pool=")
    append(output, len(ast))
    append(output, "\n")
    let func_index = 0
    while func_index < len(func_nodes_start):
        append(output, "func ")
        append(output, func_index)
        append(output, " ")
        append(output, source[func_starts[func_index]:func_ends[func_index]])
        append(output, " body=")
        append(output, func_nodes_start[func_index])
        append(output, "..")
        append(output, func_nodes_end[func_index])
        append(output, "\n")
        func_index = func_index + 1
    let node = 1
    while node < len(ast):
        let kind = ast[node]
        let size = ast_node_size(ast, node)
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
    write_buffer(output_path, output)

def compile_source(source_path: str, output_path: str, output_mode: int) -> bool:
    access_violation_count[0] = 0
    let phase_time = compiler_debug_start()
    let raw_source = read(source_path)
    let file_packages = []
    let file_starts: list[int] = []
    let file_ends: list[int] = []
    let file_paths = Buffer{data: []}
    let source = load_imported_source(raw_source, source_path, file_packages, file_starts, file_ends, file_paths)
    phase_time = compiler_debug_checkpoint("load", phase_time)
    let kinds = []
    let starts = []
    let ends = []
    let tokens = TokenStream{
        src: source,
        kinds: kinds,
        starts: starts,
        ends: ends
    }
    lex(tokens)
    phase_time = compiler_debug_checkpoint("lex", phase_time)
    let func_starts = []
    let func_ends = []
    let func_bodies = []
    let func_body_ends = []
    let func_param_offsets = []
    let func_param_counts = []
    let parameter_starts = []
    let parameter_ends = []
    let parameter_types = []
    let parameter_struct_decls = []
    let func_return_types = []
    let func_return_struct_decls = []
    let constant_starts = []
    let constant_ends = []
    let constant_values = []
    let constant_types = []
    let constant_literal_starts = []
    let constant_literal_ends = []
    let parameter_default_indexes = []
    let parameter_annotation_starts: list[int] = []
    let parameter_annotation_ends: list[int] = []
    let functions = FunctionTable{
        starts: func_starts,
        ends: func_ends,
        bodies: func_bodies,
        body_ends: func_body_ends,
        param_offsets: func_param_offsets,
        param_counts: func_param_counts,
        param_starts: parameter_starts,
        param_ends: parameter_ends,
        param_types: parameter_types,
        param_struct_decls: parameter_struct_decls,
        return_types: func_return_types,
        return_struct_decls: func_return_struct_decls,
        default_indexes: parameter_default_indexes,
        annotation_starts: parameter_annotation_starts,
        annotation_ends: parameter_annotation_ends
    }
    let constants = ConstantTable{
        starts: constant_starts,
        ends: constant_ends,
        values: constant_values,
        types: constant_types,
        literal_starts: constant_literal_starts,
        literal_ends: constant_literal_ends
    }
    let ast_nodes: list[int] = []
    let ast_func_nodes_start: list[int] = []
    let ast_func_nodes_end: list[int] = []
    let ast_global_nodes: list[int] = []
    collect_declared_types(tokens)
    collect_struct_fields(tokens)
    collect_functions(tokens, functions)
    collect_constants(tokens, constants)
    let impl_func_indexes: list[int] = []
    let impl_func_decls: list[int] = []
    let impl_func_interface_types: list[int] = []
    let impls = ImplTable{
        func_indexes: impl_func_indexes,
        declaration_indexes: impl_func_decls,
        interface_types: impl_func_interface_types
    }
    collect_impl_functions(tokens, functions, impls)
    let interface_name_starts: list[int] = []
    let interface_name_ends: list[int] = []
    let interface_func_indexes: list[int] = []
    let impl_decl_indexes: list[int] = []
    let impl_interface_name_starts: list[int] = []
    let impl_interface_name_ends: list[int] = []
    let interfaces = InterfaceTable{
        name_starts: interface_name_starts,
        name_ends: interface_name_ends,
        func_indexes: interface_func_indexes,
        declaration_indexes: impl_decl_indexes,
        impl_name_starts: impl_interface_name_starts,
        impl_name_ends: impl_interface_name_ends
    }
    collect_interfaces(tokens, functions, interfaces)
    phase_time = compiler_debug_checkpoint("collect", phase_time)
    let parse_context = ParseContext{
        src: source,
        kinds: kinds,
        starts: starts,
        ends: ends,
        fn_starts: func_starts,
        fn_ends: func_ends,
        param_offsets: func_param_offsets,
        param_counts: func_param_counts,
        param_starts: parameter_starts,
        param_ends: parameter_ends,
        ret_types: func_return_types,
        pd: parameter_default_indexes,
        cst_starts: constant_starts,
        cst_ends: constant_ends,
        cst_values: constant_values,
        file_packages: file_packages,
        file_starts: file_starts,
        file_ends: file_ends
    }
    let global_let_name_starts = []
    let global_let_name_ends = []
    let global_let_collected_types = []
    let global_let_expression_indexes = []
    let globals = GlobalTable{
        name_starts: global_let_name_starts,
        name_ends: global_let_name_ends,
        types: global_let_collected_types,
        expression_indexes: global_let_expression_indexes
    }
    collect_global_lets(tokens, globals)
    let is_ast_valid = build_ast_compilation(parse_context, func_bodies, func_body_ends,
        global_let_expression_indexes, ast_nodes, ast_func_nodes_start, ast_func_nodes_end, ast_global_nodes)
    phase_time = compiler_debug_checkpoint("ast", phase_time)
    if not is_ast_valid:
        __c_eprint_text("error: AST validation failed\n")
        return false
    if output_mode == COMPILE_OUTPUT_AST:
        write_ast_output(output_path, source, func_starts, func_ends, ast_nodes, ast_func_nodes_start,
            ast_func_nodes_end)
        return true
    let hir_records: list[int] = []
    let hir_values: list[int] = []
    let hir_struct_decls: list[int] = []
    if not hir_model_build_program(
        ast_nodes,
        ast_func_nodes_start,
        ast_func_nodes_end,
        ast_global_nodes,
        global_let_name_starts,
        global_let_name_ends,
        global_let_collected_types,
        func_starts,
        func_ends,
        func_param_offsets,
        func_param_counts,
        parameter_starts,
        parameter_ends,
        parameter_types,
        func_return_types,
        parameter_default_indexes,
        constant_starts,
        constant_ends,
        constant_types,
        hir_records,
        hir_values,
        hir_struct_decls,
    ):
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
    if not hir_validate_semantics(hir_records, hir_values, hir_struct_decls, source, validated_hir_records,
        validated_hir_struct_decls):
        __c_eprint_text("error: HIR semantic validation failed\n")
        return false
    let hir_program = HirProgram{
        records: validated_hir_records,
        values: hir_values,
        struct_decls: validated_hir_struct_decls
    }
    phase_time = compiler_debug_checkpoint("hir-validate", phase_time)
    if output_mode == COMPILE_OUTPUT_HIR:
        let raw_hir_program = HirProgram{
            records: hir_output_records,
            values: hir_values,
            struct_decls: hir_output_struct_decls
        }
        let hir_output = Buffer{data: []}
        if not hir_model_dump_program(raw_hir_program, hir_output):
            __c_eprint_text("error: HIR validation failed while dumping\n")
            return false
        write_buffer(output_path, hir_output)
        compiler_debug_checkpoint("hir-dump", phase_time)
        return true
    let mir_program = mir_model_build_program(
        validated_hir_records,
        hir_values,
        validated_hir_struct_decls,
        source,
        constant_starts,
        constant_ends,
        constant_values,
        constant_types,
        constant_literal_starts,
        constant_literal_ends,
        func_return_struct_decls,
        func_param_offsets,
        parameter_struct_decls,
        parameter_default_indexes,
        parameter_annotation_starts,
        parameter_annotation_ends,
        impl_func_indexes,
        impl_func_decls,
        impl_func_interface_types,
        interface_name_starts,
        interface_name_ends,
        interface_func_indexes,
        impl_decl_indexes,
        impl_interface_name_starts,
        impl_interface_name_ends,
    )
    phase_time = compiler_debug_checkpoint("mir-build", phase_time)
    let optimized_mir_program = mir_optimize_program(mir_program)
    phase_time = compiler_debug_checkpoint("mir-opt", phase_time)
    if output_mode == COMPILE_OUTPUT_MIR:
        let mir_output = Buffer{data: []}
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        if not mir_dump_program(optimized_mir_program, mir_output):
            __c_eprint_text("error: MIR validation failed while dumping\n")
            return false
        write_buffer(output_path, mir_output)
        return true
    elif output_mode == COMPILE_OUTPUT_LIR:
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let lir_output = Buffer{data: []}
        let is_lir_valid = lir_validate_program(lir_program)
        phase_time = compiler_debug_checkpoint("lir-validate", phase_time)
        if not is_lir_valid:
            __c_eprint_text("error: LIR validation failed\n")
            return false
        if not lir_dump_validated_program(lir_program, lir_output):
            __c_eprint_text("error: LIR validation failed while dumping\n")
            return false
        write_buffer(output_path, lir_output)
        return true
    elif output_mode == COMPILE_OUTPUT_LLVM:
        if not mir_validate_program(optimized_mir_program):
            __c_eprint_text("error: MIR validation failed\n")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let llvm_output = Buffer{data: []}
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
        write_buffer(output_path, llvm_output)
        return true
    __c_eprint_text("error: only ast, hir, mir, lir, and llvm outputs are supported\n")
    return false

struct BuildArguments:
    input_path: str
    output_path: str
    is_optimized: bool
    is_valid: bool

def remove_source_extension(source_path: str) -> str:
    let index = len(source_path) - 1
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
        input_path = arg(2)
    if argument_count >= 5 and arg(3) == "-o":
        output_path = arg(4)
    elif argument_count >= 4:
        output_path = arg(3)
    if len(input_path) < 3:
        is_valid = false
    BA_input_path = input_path
    BA_output_path = output_path
    BA_is_optimized = is_optimized
    BA_is_valid = is_valid

def build_source(source_path: str, output_path: str, is_optimized: bool) -> bool:
    let llvm_path = output_path + ".ll"
    if not compile_source(source_path, llvm_path, COMPILE_OUTPUT_LLVM):
        return false
    if not build(llvm_path, output_path, is_optimized):
        __c_file_delete(llvm_path)
        __c_eprint_text("error: failed to build executable\n")
        return false
    return true

def run_build_command(argument_count: int) -> bool:
    parse_build_arguments(argument_count)
    if not BA_is_valid:
        __c_eprint_text("error: build accepts [--dev] <file.dm> [-o output]\n")
        return false
    let input_length = len(BA_input_path)
    if input_length < 3 or BA_input_path[input_length - 3:input_length] != ".dm":
        __c_eprint_text("error: input file must have .dm extension\n")
        return false
    return build_source(BA_input_path, BA_output_path, BA_is_optimized)

def main() -> int:
    let argument_count = argc()
    let usage = " build [--dev] <file.dm> [-o output] | ast/hir/mir/lir/llvm <input.dm> -o <output>"
    if argument_count == 2:
        let command_name = arg(1)
        if command_name in ["help", "--help"]:
            print("用法: " + arg(0) + usage)
            return 0
    if argument_count >= 4 and arg(1) == "build" and arg(3) == "-o":
        if build_source(arg(2), arg(4), true):
            return 0
        return 1
    if argument_count == 5 and arg(3) == "-o":
        let command_name = arg(1)
        let output_mode = -1
        switch command_name:
            case "ast":
                output_mode = COMPILE_OUTPUT_AST
            case "hir":
                output_mode = COMPILE_OUTPUT_HIR
            case "mir":
                output_mode = COMPILE_OUTPUT_MIR
            case "lir":
                output_mode = COMPILE_OUTPUT_LIR
            case "llvm":
                output_mode = COMPILE_OUTPUT_LLVM
            default:
                __c_eprint_text("error: use ast, hir, mir, lir, or llvm\n")
                return 1
        if compile_source(arg(2), arg(4), output_mode):
            return 0
        return 1
    print("用法: " + arg(0) + usage)
    return 1
