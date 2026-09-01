from buffer import Buffer
from io import read, write
from fs import exists, remove_file, mkdir, rename
from compiler import build_llvm
from utf8 import ord
from crypto import sha256
from sys import argc, arg, env
from time import monotonic_ms
from compiler_lex import (
    lex,
    parse_integer,
    parse_rune_literal,
    token_kind,
    token_start,
    token_end,
    source_equals,
    source_ranges_equal,
    skip_source_newlines,
    is_body_line,
    line_indent,
    find_struct_declaration_index,
    collect_functions,
    collect_impl_functions,
    collect_interfaces,
    collect_constants,
    collect_declared_types,
    collect_struct_fields,
    struct_field_type_declaration,
    collect_global_lets,
    validate_top_level_symbols,
    parse_import_symbols,
    build_type_attribution,
    build_module_attribution,
    module_env_build,
    module_env_file_index,
    module_resolve,
    module_error_report,
    module_error_count_get,
    module_entry_file,
    classify_package,
    access_violation_count,
    FunctionTable,
    ConstantTable,
    GlobalTable,
    TokenStream,
    ParseContext,
    TOKEN_EOF,
    TOKEN_INTEGER,
    TOKEN_IDENTIFIER,
    TOKEN_LET,
    TOKEN_PLUS,
    TOKEN_MINUS,
    TOKEN_MULTIPLY,
    TOKEN_DIVIDE,
    TOKEN_OPEN_PAREN,
    TOKEN_CLOSE_PAREN,
    TOKEN_ASSIGN,
    TOKEN_NEWLINE,
    TOKEN_DEF,
    TOKEN_RETURN,
    TOKEN_COLON,
    TOKEN_COMMA,
    TOKEN_ARROW,
    TOKEN_LESS,
    TOKEN_IF,
    TOKEN_ELIF,
    TOKEN_ELSE,
    TOKEN_WHILE,
    TOKEN_SWITCH,
    TOKEN_CASE,
    TOKEN_DEFAULT,
    TOKEN_STRING,
    TOKEN_OPEN_BRACKET,
    TOKEN_CLOSE_BRACKET,
    TOKEN_EQUAL,
    TOKEN_NOT_EQUAL,
    TOKEN_LESS_EQUAL,
    TOKEN_GREATER_EQUAL,
    TOKEN_GREATER,
    TOKEN_AND,
    TOKEN_OR,
    TOKEN_MODULO,
    TOKEN_TRUE,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_OPEN_BRACE,
    TOKEN_CLOSE_BRACE,
    TOKEN_DOT,
    TOKEN_QUESTION,
    TOKEN_FLOAT,
    TOKEN_NOT,
    TOKEN_CONS,
    TOKEN_RUNE,
    TOKEN_BREAK,
    TOKEN_CONTINUE
)
from compiler_ast import (
    ast_validate_program,
    ast_build_program,
    ast_node_kind,
    ast_node_arg,
    ast_node_start,
    ast_node_end,
    ast_next_node,
    ast_stmt_next_node,
    ast_node_size,
    ast_kind_name,
    AST_HEADER_SIZE,
    AST_CASE,
    AST_ELIF,
    AST_M_CASE,
    AST_EXPR_ATTR,
    AST_EXPR_BINARY,
    AST_EXPR_BOOL,
    AST_EXPR_BUILTIN_ENUM,
    AST_EXPR_CALL,
    AST_EXPR_COND,
    AST_EXPR_DICT,
    AST_EXPR_ENUM,
    AST_EXPR_FLOAT,
    AST_EXPR_INDEX,
    AST_EXPR_INT,
    AST_EXPR_LAMBDA,
    AST_EXPR_LIST,
    AST_EXPR_LIST_COMP,
    AST_EXPR_LOGICAL,
    AST_EXPR_MATCH,
    AST_EXPR_METHOD_CALL,
    AST_EXPR_RUNE,
    AST_EXPR_SLICE,
    AST_EXPR_STRING,
    AST_EXPR_STRUCT,
    AST_EXPR_TUPLE,
    AST_EXPR_UNARY,
    AST_EXPR_VAR,
    AST_PAT_BOOL,
    AST_PAT_BUILTIN,
    AST_PAT_CONS,
    AST_PAT_ENUM,
    AST_PAT_FLOAT,
    AST_PAT_INT,
    AST_PAT_LIST,
    AST_PAT_RUNE,
    AST_PAT_STRING,
    AST_PAT_STRUCT,
    AST_PAT_VAR,
    AST_PAT_WILDCARD,
    AST_STMT_ASSIGN,
    AST_STMT_BREAK,
    AST_STMT_CONTINUE,
    AST_STMT_EXPR,
    AST_STMT_FOR,
    AST_STMT_IF,
    AST_STMT_LET,
    AST_STMT_LET_TUPLE,
    AST_STMT_RETURN,
    AST_STMT_SWITCH,
    AST_STMT_WHILE
)
from compiler_hir_model import (
    HirDiagnosticContext,
    HirProgram,
    hir_int_list_get,
    hir_model_build_program,
    hir_model_dump_program,
    hir_report_unreachable,
    hir_validate_semantics
)
from compiler_mir_model import (
    mir_model_build_program,
    mir_validate_program,
    mir_dump_program
)
from compiler_mir_opt import mir_optimize_program
from compiler_lir_model import (
    lir_model_build_program,
    lir_validate_program,
    lir_dump_validated_program,
    lir_value_type_in_function,
    lir_value_exists,
    lir_block_parameter_offset
)
from compiler_llvm_emit import llvm_lower_lir

const COMPILE_OUTPUT_AST: int = 0
const COMPILE_OUTPUT_HIR: int = 1
const COMPILE_OUTPUT_MIR: int = 2
const COMPILE_OUTPUT_LIR: int = 3
const COMPILE_OUTPUT_LLVM: int = 4
const COMPILER_CACHE_VERSION: str = "dream-compiler-cache-v2"

let compiler_temp_sequence: list[int] = [0]
let MODULE_ENTRY_DIR: str = ""

def module_name_component_end(module_name: str, start: int) -> int:
    let end = start
    while end < module_name.len() and module_name[end] != '.':
        end = end + 1
    return end

def parse_module_name(
    source: str, kinds: list[int], starts: list[int], ends: list[int], start_index: int
) -> str:
    if token_kind(kinds, start_index) != TOKEN_IDENTIFIER:
        return ""
    let module_name_buffer = Buffer()
    append(module_name_buffer, source[token_start(starts, start_index):token_end(ends, start_index)])
    let module_index = start_index + 1
    while (
        token_kind(kinds, module_index) == TOKEN_DOT and
        token_kind(kinds, module_index + 1) == TOKEN_IDENTIFIER
    ):
        let component_index = module_index + 1
        append(module_name_buffer, ".")
        append(module_name_buffer, source[token_start(starts, component_index):token_end(ends, component_index)])
        module_index = component_index + 1
    return module_name_buffer.to_str()

def module_name_match_end(source: str, kinds: list[int], starts: list[int], ends: list[int], token_index: int,
    module_name: str) -> int:
    if module_name.len() == 0:
        return -1
    let component_start = 0
    let current_index = token_index
    while component_start < module_name.len():
        let component_end = module_name_component_end(module_name, component_start)
        if token_kind(kinds, current_index) != TOKEN_IDENTIFIER:
            return -1
        if (
            source[token_start(starts, current_index):token_end(ends, current_index)] !=
            module_name[component_start:component_end]
        ):
            return -1
        if component_end == module_name.len():
            return current_index
        if (
            token_kind(kinds, current_index + 1) != TOKEN_DOT or
            token_kind(kinds, current_index + 2) != TOKEN_IDENTIFIER
        ):
            return -1
        component_start = component_end + 1
        current_index = current_index + 2
    return -1

def import_statement_end(kinds: list[int], starts: list[int], ends: list[int], statement_index: int) -> int:
    let current_index = statement_index + 1
    let parenthesis_depth = 0
    while token_kind(kinds, current_index) != TOKEN_EOF:
        let kind = token_kind(kinds, current_index)
        if kind == TOKEN_OPEN_PAREN:
            parenthesis_depth = parenthesis_depth + 1
        elif kind == TOKEN_CLOSE_PAREN and parenthesis_depth > 0:
            parenthesis_depth = parenthesis_depth - 1
            if parenthesis_depth == 0:
                return token_end(ends, current_index)
        elif kind == TOKEN_NEWLINE and parenthesis_depth == 0:
            return token_start(starts, current_index)
        current_index = current_index + 1
    return token_end(ends, current_index)

def is_from_import_token(source: str, kinds: list[int], starts: list[int], ends: list[int], token_index: int) -> bool:
    let current_index = token_index - 1
    while current_index >= 0 and token_kind(kinds, current_index) != TOKEN_NEWLINE:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER and source_equals(source, token_start(starts,
            current_index), token_end(ends, current_index), "from"):
            return true
        current_index = current_index - 1
    return false

def module_dirname(path: str) -> str:
    let index = path.len() - 1
    while index >= 0:
        if path[index] == '/':
            if index == 0:
                return "/"
            return path[0:index]
        index = index - 1
    return "."

def module_join_path(root: str, relative_path: str) -> str:
    if root == "/":
        return "/" + relative_path
    if root == "":
        return relative_path
    return root + "/" + relative_path

def module_relative_name(current_name: str, relative_depth: int, child_name: str) -> str:
    let parent_name = current_name
    let depth = 0
    while depth < relative_depth:
        let separator = parent_name.len() - 1
        while separator >= 0 and parent_name[separator] != '.':
            separator = separator - 1
        if separator < 0:
            parent_name = ""
        else:
            parent_name = parent_name[0:separator]
        depth = depth + 1
    if parent_name == "" or child_name == "":
        if parent_name == "":
            return child_name
        return parent_name
    return parent_name + "." + child_name

def module_relative_path(module_name: str) -> str:
    let relative_buffer = Buffer()
    let path_index = 0
    while path_index < module_name.len():
        if module_name[path_index] == '.':
            append(relative_buffer, "/")
        else:
            append(relative_buffer, module_name[path_index:path_index + 1])
        path_index = path_index + 1
    return relative_buffer.to_str() + ".dm"

def module_path(module_name: str, importer_path: str, relative_depth: int) -> str:
    let relative_path = module_relative_path(module_name)
    if relative_depth > 0:
        let base_dir = module_dirname(importer_path)
        let parent_depth = 1
        while parent_depth < relative_depth:
            base_dir = module_dirname(base_dir)
            parent_depth = parent_depth + 1
        return module_join_path(base_dir, relative_path)

    switch module_name:
        case "sys":
            return "runtime/stdlib/sys.dm"
        case "prelude":
            return "runtime/stdlib/prelude.dm"
        case "compiler":
            return "runtime/stdlib/compiler.dm"
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

    let entry_dir = MODULE_ENTRY_DIR
    if entry_dir.len() > 0:
        let entry_candidate = module_join_path(entry_dir, relative_path)
        if exists(entry_candidate):
            return entry_candidate
    let configured_paths = env("DREAM_MODULE_PATH")
    let path_start = 0
    let path_end = 0
    let path_length = configured_paths.len()
    while path_end <= path_length:
        if path_end == path_length or configured_paths[path_end] == ':':
            if path_end > path_start:
                let root = configured_paths[path_start:path_end]
                let candidate = module_join_path(root, relative_path)
                if exists(candidate):
                    return candidate
            path_start = path_end + 1
        path_end = path_end + 1
    let prefix_buffer = Buffer()
    append(prefix_buffer, "runtime/stdlib/")
    append(prefix_buffer, relative_path)
    return prefix_buffer.to_str()

def module_is_loaded(loaded_modules: str, module_key: str) -> bool:
    let module_start = 0
    let loaded_length = loaded_modules.len()
    while module_start < loaded_length:
        let module_end = module_start
        while module_end < loaded_length and loaded_modules[module_end] != '\n':
            module_end = module_end + 1
        if loaded_modules[module_start:module_end] == module_key:
            return true
        module_start = module_end + 1
    return false

def add_imported_module(module_name: str, imported_path: str, imported_source: Buffer, module_text: Buffer,
    file_packages: list[int], file_starts: list[int], file_ends: list[int], file_paths: Buffer) -> bool:
    if not exists(imported_path):
        eprint("Error: module not found: ")
        eprintln(module_name)
        return false
    let module_source = read(imported_path)
    let start_offset = imported_source.to_str().len()
    append(imported_source, module_source)
    append(imported_source, "\n")
    append(module_text, module_source)
    let end_offset = start_offset + module_source.len() + 1
    append(file_packages, classify_package(imported_path))
    append(file_starts, start_offset)
    append(file_ends, end_offset)
    append(file_paths, imported_path)
    append(file_paths, "\n")
    return true

def mask_source_range(source: str, start: int, end: int) -> str:
    let masked = Buffer()
    let index = 0
    while index < source.len():
        if index >= start and index < end and source[index] != '\n':
            append(masked, " ")
        else:
            append(masked, source[index:index + 1])
        index = index + 1
    return masked.to_str()

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
    let module_length = module_names.len()
    while module_start < module_length:
        let module_end = module_start
        while module_end < module_length and module_names[module_end] != '\n':
            module_end = module_end + 1
        let module_name = module_names[module_start:module_end]
        let token_index = 0
        while token_kind(kinds, token_index) != TOKEN_EOF:
            let token_start_offset = token_start(starts, token_index)
            let token_end_offset = token_end(ends, token_index)
            let is_identifier = token_kind(kinds, token_index) == TOKEN_IDENTIFIER
            let is_import = is_identifier and source_equals(source, token_start_offset, token_end_offset, "import")
            if is_import and not is_from_import_token(source, kinds, starts, ends, token_index):
                let statement_end = import_statement_end(kinds, starts, ends, token_index)
                rewritten_source = mask_source_range(rewritten_source, token_start_offset, statement_end)
            let module_end_index = -1
            if is_identifier:
                module_end_index = module_name_match_end(source, kinds, starts, ends, token_index, module_name)
            if module_end_index >= 0 and token_kind(kinds, module_end_index + 1) == TOKEN_DOT:
                let dot_end_offset = token_end(ends, module_end_index + 1)
                rewritten_source = mask_source_range(rewritten_source, token_start_offset, dot_end_offset)
            token_index = token_index + 1
        module_start = module_end + 1
    return rewritten_source

def module_name_stem(path: str) -> str:
    let name_buffer = Buffer()
    let index = 0
    while index < path.len():
        if path[index] == '/':
            name_buffer = Buffer()
        elif path[index] == '.':
            return name_buffer.to_str()
        else:
            append(name_buffer, path[index:index + 1])
        index = index + 1
    return name_buffer.to_str()

# 扫描单文件源码的 import 语句，记录到模块环境列表，未加载模块入队（BFS）
def scan_module_imports(source: str, file_index: int, source_path: str, source_module_name: str,
    loaded_modules: str, queue: list[str], queue_paths: list[str],
    namespace_modules: Buffer, module_ref_starts: list[int], module_ref_ends: list[int],
    module_ref_files: list[int], module_ref_mod_starts: list[int], module_ref_mod_ends: list[int],
    named_symbol_starts: list[int], named_symbol_ends: list[int], named_symbol_files: list[int],
    named_symbol_mod_starts: list[int], named_symbol_mod_ends: list[int], named_symbol_mod_names: list[str],
    star_import_files: list[int], star_import_mod_starts: list[int], star_import_mod_ends: list[int],
    star_import_mod_names: list[str]):
    let scan_kinds = []
    let scan_starts = []
    let scan_ends = []
    let tokens = TokenStream{
        src: source,
        kinds: scan_kinds,
        starts: scan_starts,
        ends: scan_ends
    }
    lex(tokens)
    let token_index = 0
    while token_kind(scan_kinds, token_index) != TOKEN_EOF:
        if token_kind(scan_kinds, token_index) == TOKEN_IDENTIFIER and source_equals(source,
            token_start(scan_starts, token_index), token_end(scan_ends, token_index), "from"):
            let module_index = token_index + 1
            let relative_depth = 0
            while token_kind(scan_kinds, module_index) == TOKEN_DOT:
                relative_depth = relative_depth + 1
                module_index = module_index + 1
            if token_kind(scan_kinds, module_index) == TOKEN_IDENTIFIER:
                let module_name = parse_module_name(source, scan_kinds, scan_starts, scan_ends, module_index)
                let resolved_module_name = module_name
                if relative_depth > 0:
                    resolved_module_name = module_relative_name(source_module_name, relative_depth, module_name)
                let module_name_end_index = module_name_match_end(source, scan_kinds, scan_starts, scan_ends,
                    module_index, module_name)
                let imported_path = module_path(module_name, source_path, relative_depth)
                if not module_is_loaded(loaded_modules, imported_path):
                    append(queue, resolved_module_name)
                    append(queue_paths, imported_path)
                let import_keyword_index = module_name_end_index + 1
                while token_kind(scan_kinds, import_keyword_index) not in [TOKEN_IDENTIFIER, TOKEN_EOF]:
                    import_keyword_index = import_keyword_index + 1
                if source_equals(source, token_start(scan_starts, import_keyword_index),
                    token_end(scan_ends, import_keyword_index), "import"):
                    let symbol_index = import_keyword_index + 1
                    let symbol_starts: list[int] = []
                    let symbol_ends: list[int] = []
                    let is_star = parse_import_symbols(source, scan_kinds, scan_starts, scan_ends, symbol_index,
                        symbol_starts, symbol_ends)
                    if is_star == 1:
                        append(star_import_files, file_index)
                        append(star_import_mod_starts, token_start(scan_starts, module_index))
                        append(star_import_mod_ends, token_end(scan_ends, module_name_end_index))
                        append(star_import_mod_names, resolved_module_name)
                    else:
                        let symbol_list_index = 0
                        while symbol_list_index < len(symbol_starts):
                            append(named_symbol_starts, symbol_starts[symbol_list_index])
                            append(named_symbol_ends, symbol_ends[symbol_list_index])
                            append(named_symbol_files, file_index)
                            append(named_symbol_mod_starts, token_start(scan_starts, module_index))
                            append(named_symbol_mod_ends, token_end(scan_ends, module_name_end_index))
                            let named_module_name = resolved_module_name + ""
                            append(named_symbol_mod_names, named_module_name)
                            symbol_list_index = symbol_list_index + 1
        if (
            token_kind(scan_kinds, token_index) == TOKEN_IDENTIFIER and
            source[token_start(scan_starts, token_index):token_end(scan_ends, token_index)] == "import" and
            not is_from_import_token(source, scan_kinds, scan_starts, scan_ends, token_index)
        ):
            let module_index = token_index + 1
            if token_kind(scan_kinds, module_index) == TOKEN_IDENTIFIER:
                let module_name = parse_module_name(source, scan_kinds, scan_starts, scan_ends, module_index)
                let imported_path = module_path(module_name, source_path, 0)
                if not module_is_loaded(loaded_modules, imported_path):
                    append(queue, module_name)
                    append(queue_paths, imported_path)
                if not module_is_loaded(namespace_modules.to_str(), module_name):
                    append(namespace_modules, module_name)
                    append(namespace_modules, "\n")
                let module_name_end_index = module_name_match_end(source, scan_kinds, scan_starts, scan_ends,
                    module_index, module_name)
                append(module_ref_starts, token_start(scan_starts, module_index))
                append(module_ref_ends, token_end(scan_ends, module_name_end_index))
                append(module_ref_files, file_index)
                append(module_ref_mod_starts, token_start(scan_starts, module_index))
                append(module_ref_mod_ends, token_end(scan_ends, module_name_end_index))
        token_index = token_index + 1
    let namespace_start = 0
    let namespace_text = namespace_modules.to_str()
    let namespace_length = namespace_text.len()
    while namespace_start < namespace_length:
        let namespace_end = namespace_start
        while namespace_end < namespace_length and namespace_text[namespace_end] != '\n':
            namespace_end = namespace_end + 1
        let namespace_name = namespace_text[namespace_start:namespace_end]
        if namespace_name.len() > 0:
            let qualified_index = 0
            while token_kind(scan_kinds, qualified_index) != TOKEN_EOF:
                if token_kind(scan_kinds, qualified_index) == TOKEN_IDENTIFIER:
                    let qualified_end_index = module_name_match_end(source, scan_kinds, scan_starts, scan_ends,
                        qualified_index, namespace_name)
                    if (
                        qualified_end_index >= 0 and
                        token_kind(scan_kinds, qualified_end_index + 1) == TOKEN_DOT and
                        token_kind(scan_kinds, qualified_end_index + 2) == TOKEN_IDENTIFIER
                    ):
                        append(module_ref_starts, token_start(scan_starts, qualified_index))
                        append(module_ref_ends, token_end(scan_ends, qualified_end_index))
                        append(module_ref_files, file_index)
                        append(module_ref_mod_starts, token_start(scan_starts, qualified_index))
                        append(module_ref_mod_ends, token_end(scan_ends, qualified_end_index))
                qualified_index = qualified_index + 1
        namespace_start = namespace_end + 1

def load_imported_source(source: str, source_path: str, file_packages: list[int], file_starts: list[int],
    file_ends: list[int], file_paths: Buffer, file_names: list[str], final_source: Buffer) -> bool:
    MODULE_ENTRY_DIR = module_dirname(source_path)
    let entry_module_name = module_name_stem(source_path)
    let source_with_prelude = source
    let imported_source = Buffer()
    let loaded_modules = ""
    let namespace_modules = Buffer()
    let queue_paths: list[str] = []
    let module_ref_starts: list[int] = []
    let module_ref_ends: list[int] = []
    let module_ref_files: list[int] = []
    let module_ref_mod_starts: list[int] = []
    let module_ref_mod_ends: list[int] = []
    let named_symbol_starts: list[int] = []
    let named_symbol_ends: list[int] = []
    let named_symbol_files: list[int] = []
    let named_symbol_mod_starts: list[int] = []
    let named_symbol_mod_ends: list[int] = []
    let named_symbol_mod_names: list[str] = []
    let star_import_files: list[int] = []
    let star_import_mod_starts: list[int] = []
    let star_import_mod_ends: list[int] = []
    let star_import_mod_names: list[str] = []
    let queue: list[str] = []
    scan_module_imports(source_with_prelude, -1, source_path, entry_module_name, loaded_modules, queue, queue_paths,
        namespace_modules, module_ref_starts,
        module_ref_ends, module_ref_files, module_ref_mod_starts, module_ref_mod_ends, named_symbol_starts,
        named_symbol_ends, named_symbol_files, named_symbol_mod_starts, named_symbol_mod_ends,
        named_symbol_mod_names, star_import_files, star_import_mod_starts, star_import_mod_ends,
        star_import_mod_names)
    if source_path != "runtime/stdlib/prelude.dm":
        append(star_import_files, -1)
        append(star_import_mod_starts, 0)
        append(star_import_mod_ends, 0)
        let prelude_module_name = "pre" + "lude"
        append(star_import_mod_names, prelude_module_name)
        let prelude_queue_name = prelude_module_name + ""
        append(queue, prelude_queue_name)
        let prelude_path = module_path(prelude_module_name, source_path, 0)
        append(queue_paths, prelude_path)
    let queue_head = 0
    while queue_head < len(queue):
        let module_name = queue[queue_head]
        let imported_path = queue_paths[queue_head]
        queue_head = queue_head + 1
        if module_is_loaded(loaded_modules, imported_path):
            continue
        let module_text = Buffer()
        if not add_imported_module(module_name, imported_path, imported_source, module_text, file_packages,
            file_starts, file_ends, file_paths):
            return false
        let module_file_index = len(file_starts) - 1
        append(file_names, module_name)
        let loaded_buffer = Buffer()
        append(loaded_buffer, loaded_modules)
        append(loaded_buffer, imported_path)
        append(loaded_buffer, "\n")
        loaded_modules = loaded_buffer.to_str()
        scan_module_imports(module_text.to_str(), module_file_index, imported_path, module_name, loaded_modules,
            queue, queue_paths, namespace_modules, module_ref_starts, module_ref_ends, module_ref_files,
            module_ref_mod_starts, module_ref_mod_ends,
            named_symbol_starts, named_symbol_ends, named_symbol_files, named_symbol_mod_starts,
            named_symbol_mod_ends, named_symbol_mod_names, star_import_files, star_import_mod_starts,
            star_import_mod_ends, star_import_mod_names)
        # 每个模块隐式注入 prelude（与入口一致；prelude 自身不注入）
        if module_name != "prelude":
            append(star_import_files, module_file_index)
            append(star_import_mod_starts, 0)
            append(star_import_mod_ends, 0)
            let prelude_module_name = "pre" + "lude"
            append(star_import_mod_names, prelude_module_name)
    let entry_file_index = len(file_starts)
    let entry_base = imported_source.to_str().len()
    let has_loaded_modules = len(loaded_modules) != 0
    if has_loaded_modules:
        entry_base = entry_base + 1
    # 入口记录文件下标回填
    let record_index = 0
    while record_index < len(module_ref_files):
        if module_ref_files[record_index] == -1:
            module_ref_files[record_index] = entry_file_index
        record_index = record_index + 1
    record_index = 0
    while record_index < len(named_symbol_files):
        if named_symbol_files[record_index] == -1:
            named_symbol_files[record_index] = entry_file_index
        record_index = record_index + 1
    record_index = 0
    while record_index < len(star_import_files):
        if star_import_files[record_index] == -1:
            star_import_files[record_index] = entry_file_index
        record_index = record_index + 1
    # 区间从文件内部偏移转为拼接后全局偏移（入口文件基址 = entry_base，尚未写入 file_starts）
    record_index = 0
    while record_index < len(module_ref_files):
        let module_file = module_ref_files[record_index]
        let module_base = entry_base
        if module_file != entry_file_index:
            module_base = file_starts[module_file]
        module_ref_starts[record_index] = module_ref_starts[record_index] + module_base
        module_ref_ends[record_index] = module_ref_ends[record_index] + module_base
        record_index = record_index + 1
    record_index = 0
    while record_index < len(named_symbol_files):
        let symbol_file = named_symbol_files[record_index]
        let symbol_base = entry_base
        if symbol_file != entry_file_index:
            symbol_base = file_starts[symbol_file]
        named_symbol_starts[record_index] = named_symbol_starts[record_index] + symbol_base
        named_symbol_ends[record_index] = named_symbol_ends[record_index] + symbol_base
        record_index = record_index + 1
    record_index = 0
    while record_index < len(star_import_files):
        let star_file = star_import_files[record_index]
        let star_base = entry_base
        if star_file != entry_file_index:
            star_base = file_starts[star_file]
        star_import_mod_starts[record_index] = star_import_mod_starts[record_index] + star_base
        star_import_mod_ends[record_index] = star_import_mod_ends[record_index] + star_base
        record_index = record_index + 1
    record_index = 0
    while record_index < len(module_ref_mod_starts):
        let module_file = module_ref_files[record_index]
        let module_base = entry_base
        if module_file != entry_file_index:
            module_base = file_starts[module_file]
        module_ref_mod_starts[record_index] = module_ref_mod_starts[record_index] + module_base
        module_ref_mod_ends[record_index] = module_ref_mod_ends[record_index] + module_base
        record_index = record_index + 1
    record_index = 0
    while record_index < len(named_symbol_mod_starts):
        let symbol_file = named_symbol_files[record_index]
        let symbol_base = entry_base
        if symbol_file != entry_file_index:
            symbol_base = file_starts[symbol_file]
        named_symbol_mod_starts[record_index] = named_symbol_mod_starts[record_index] + symbol_base
        named_symbol_mod_ends[record_index] = named_symbol_mod_ends[record_index] + symbol_base
        record_index = record_index + 1
    record_index = 0
    while record_index < len(star_import_mod_starts):
        let star_file = star_import_files[record_index]
        let star_base = entry_base
        if star_file != entry_file_index:
            star_base = file_starts[star_file]
        star_import_mod_starts[record_index] = star_import_mod_starts[record_index] + star_base
        star_import_mod_ends[record_index] = star_import_mod_ends[record_index] + star_base
        record_index = record_index + 1
    append(file_names, module_name_stem(source_path))
    let imported_source_text = imported_source.to_str()
    let user_source_start = imported_source_text.len()
    if len(loaded_modules) != 0:
        user_source_start = user_source_start + 1
        let rewritten_source = rewrite_module_namespace(source, namespace_modules.to_str())
        append(final_source, imported_source_text)
        append(final_source, "\n")
        append(final_source, rewritten_source)
        let final_source_text = final_source.to_str()
        append(file_packages, classify_package(source_path))
        append(file_starts, user_source_start)
        append(file_ends, final_source_text.len())
        append(file_paths, source_path)
        append(file_paths, "\n")
    else:
        append(file_packages, classify_package(source_path))
        append(file_starts, 0)
        append(file_ends, source.len())
        append(file_paths, source_path)
        append(file_paths, "\n")
        append(final_source, rewrite_module_namespace(source, namespace_modules.to_str()))
    # 模块名区间 → 文件下标（区间已转为拼接后偏移，用完整源码提取文本）
    let final_text = final_source.to_str()
    let module_ref_mods: list[int] = []
    record_index = 0
    while record_index < len(module_ref_mod_starts):
        let module_name = final_text[module_ref_mod_starts[record_index]:module_ref_mod_ends[record_index]]
        if module_ref_files[record_index] == entry_file_index:
            let source_module_start = module_ref_mod_starts[record_index] - entry_base
            let source_module_end = module_ref_mod_ends[record_index] - entry_base
            module_name = source[source_module_start:source_module_end]
        append(module_ref_mods, module_env_file_index(file_names, module_name))
        record_index = record_index + 1
    let named_symbol_mods: list[int] = []
    record_index = 0
    while record_index < len(named_symbol_mod_starts):
        append(named_symbol_mods, module_env_file_index(file_names, named_symbol_mod_names[record_index]))
        record_index = record_index + 1
    let star_import_mods: list[int] = []
    record_index = 0
    while record_index < len(star_import_mod_starts):
        append(star_import_mods, module_env_file_index(file_names, star_import_mod_names[record_index]))
        record_index = record_index + 1
    module_env_build(file_names, module_ref_starts, module_ref_ends, module_ref_files, module_ref_mods,
        named_symbol_starts, named_symbol_ends, named_symbol_files, named_symbol_mods, star_import_files,
        star_import_mods, entry_file_index)
    return true

def ensure_compiler_dirs() -> bool:
    if not mkdir("target"):
        return false
    if not mkdir("target/tmp"):
        return false
    if not mkdir("target/cache"):
        return false
    return mkdir("target/cache/v1")

def compiler_temp_token(label: str) -> str:
    let sequence = compiler_temp_sequence[0]
    compiler_temp_sequence[0] = compiler_temp_sequence[0] + 1
    let label_hash = sha256(label)
    let token = Buffer()
    append(token, monotonic_ms())
    append(token, "_")
    append(token, label_hash[0:16])
    append(token, "_")
    append(token, sequence)
    return token.to_str()

def compiler_temp_path(label: str) -> str:
    let path = Buffer()
    append(path, "target/tmp/")
    append(path, label)
    append(path, "_")
    append(path, compiler_temp_token(label))
    return path.to_str()

def write_text_atomic(path: str, content: str) -> bool:
    let temp_path = compiler_temp_path("text")
    let result = write(temp_path, content)
    let written = match result:
        Ok(_): true
        Err(_): false
    if not written:
        remove_file(temp_path)
        return false
    if not rename(temp_path, path):
        remove_file(temp_path)
        return false
    return true

def write_buffer(path: str, output: Buffer) -> bool:
    let temp_path = compiler_temp_path("buffer")
    let written = __c_file_write_bytes(temp_path, __c_bytes_from_array(output.data))
    if written < 0:
        remove_file(temp_path)
        return false
    if not rename(temp_path, path):
        remove_file(temp_path)
        return false
    return true

def copy_text_file(source_path: str, output_path: str) -> bool:
    if not exists(source_path):
        return false
    return write_text_atomic(output_path, read(source_path))

def compiler_cache_namespace() -> str:
    let namespace = env("DREAM_COMPILER_CACHE_NAMESPACE")
    if namespace.len() == 0:
        return "default"
    return namespace

def compiler_cache_key(source_path: str, source: str, output_mode: int) -> str:
    let key_source = Buffer()
    append(key_source, COMPILER_CACHE_VERSION)
    append(key_source, "|namespace=")
    append(key_source, compiler_cache_namespace())
    append(key_source, "|")
    append(key_source, source_path)
    append(key_source, "|")
    append(key_source, output_mode)
    append(key_source, "|")
    append(key_source, source)
    return sha256(key_source.to_str())

def compiler_cache_dir(cache_key: str) -> str:
    let path = Buffer()
    append(path, "target/cache/v1/")
    append(path, cache_key)
    return path.to_str()

def compiler_cache_artifact(cache_key: str) -> str:
    let path = Buffer()
    append(path, compiler_cache_dir(cache_key))
    append(path, "/artifact")
    return path.to_str()

def compiler_cache_manifest(cache_key: str) -> str:
    let path = Buffer()
    append(path, compiler_cache_dir(cache_key))
    append(path, "/manifest")
    return path.to_str()

def compiler_cache_hit(cache_key: str, output_path: str, output_mode: int) -> bool:
    if output_mode == COMPILE_OUTPUT_LLVM:
        return false
    let artifact_path = compiler_cache_artifact(cache_key)
    let manifest_path = compiler_cache_manifest(cache_key)
    if not exists(artifact_path) or not exists(manifest_path):
        return false
    return copy_text_file(artifact_path, output_path)

def compiler_cache_store(cache_key: str, output_path: str, output_mode: int, source_length: int) -> bool:
    if output_mode == COMPILE_OUTPUT_LLVM:
        return true
    let cache_dir = compiler_cache_dir(cache_key)
    if not mkdir(cache_dir):
        return false
    if not copy_text_file(output_path, compiler_cache_artifact(cache_key)):
        return false
    let manifest = Buffer()
    append(manifest, "schema=1\nversion=")
    append(manifest, COMPILER_CACHE_VERSION)
    append(manifest, "\nmode=")
    append(manifest, output_mode)
    append(manifest, "\nsource_length=")
    append(manifest, source_length)
    append(manifest, "\n")
    return write_text_atomic(compiler_cache_manifest(cache_key), manifest.to_str())

def compiler_debug_start() -> int:
    if __c_debug_on():
        return __c_time_ms()
    return 0

def compiler_debug_checkpoint(label: str, previous_time: int) -> int:
    if not __c_debug_on():
        return previous_time
    let current_time = __c_time_ms()
    eprint("[timing] ")
    eprint(label)
    eprint(" ")
    eprint(current_time - previous_time)
    eprintln("ms")
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
    nodes: list[int], func_nodes_start: list[int], func_nodes_end: list[int]) -> bool:
    let ast = nodes
    let output = Buffer()
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
    return write_buffer(output_path, output)

def compile_source(source_path: str, output_path: str, output_mode: int) -> bool:
    access_violation_count[0] = 0
    if not ensure_compiler_dirs():
        eprintln("error: failed to create compiler target directories")
        return false
    let phase_time = compiler_debug_start()
    let raw_source = read(source_path)
    let file_packages = []
    let file_starts: list[int] = []
    let file_ends: list[int] = []
    let file_paths = Buffer()
    let module_source = Buffer()
    let file_names: list[str] = []
    if not load_imported_source(raw_source, source_path, file_packages, file_starts, file_ends, file_paths,
        file_names, module_source):
        return false
    let source = module_source.to_str()
    let cache_key = compiler_cache_key(source_path, source, output_mode)
    if compiler_cache_hit(cache_key, output_path, output_mode):
        return true
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
    if not validate_top_level_symbols(tokens, file_starts, file_ends):
        return false
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
    build_type_attribution(file_starts, file_ends)
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
    build_module_attribution(func_starts, constant_starts, global_let_name_starts, file_starts, file_ends)
    build_type_attribution(file_starts, file_ends)
    if module_error_count_get() > 0:
        eprintln("error: module resolution failed")
        return false
    let is_ast_valid = build_ast_compilation(parse_context, func_bodies, func_body_ends,
        global_let_expression_indexes, ast_nodes, ast_func_nodes_start, ast_func_nodes_end, ast_global_nodes)
    phase_time = compiler_debug_checkpoint("ast", phase_time)
    if not is_ast_valid:
        eprintln("error: AST validation failed")
        return false
    if output_mode == COMPILE_OUTPUT_AST:
        if not write_ast_output(output_path, source, func_starts, func_ends, ast_nodes, ast_func_nodes_start,
            ast_func_nodes_end):
            return false
        if not compiler_cache_store(cache_key, output_path, output_mode, source.len()):
            eprintln("warning: failed to store compiler cache")
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
        parameter_struct_decls,
        func_return_types,
        parameter_default_indexes,
        constant_starts,
        constant_ends,
        constant_types,
        hir_records,
        hir_values,
        hir_struct_decls,
    ):
        eprintln("error: HIR build failed")
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
        eprintln("error: HIR semantic validation failed")
        return false
    if module_error_count_get() > 0:
        eprintln("error: module resolution failed")
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
        let hir_output = Buffer()
        if not hir_model_dump_program(raw_hir_program, hir_output):
            eprintln("error: HIR validation failed while dumping")
            return false
        if not write_buffer(output_path, hir_output):
            return false
        if not compiler_cache_store(cache_key, output_path, output_mode, source.len()):
            eprintln("warning: failed to store compiler cache")
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
    if module_error_count_get() > 0:
        eprintln("error: module resolution failed")
        return false
    phase_time = compiler_debug_checkpoint("mir-build", phase_time)
    let optimized_mir_program = mir_optimize_program(mir_program)
    phase_time = compiler_debug_checkpoint("mir-opt", phase_time)
    if output_mode == COMPILE_OUTPUT_MIR:
        let mir_output = Buffer()
        if not mir_validate_program(optimized_mir_program):
            eprintln("error: MIR validation failed")
            return false
        if not mir_dump_program(optimized_mir_program, mir_output):
            eprintln("error: MIR validation failed while dumping")
            return false
        if not write_buffer(output_path, mir_output):
            return false
        if not compiler_cache_store(cache_key, output_path, output_mode, source.len()):
            eprintln("warning: failed to store compiler cache")
        return true
    elif output_mode == COMPILE_OUTPUT_LIR:
        if not mir_validate_program(optimized_mir_program):
            eprintln("error: MIR validation failed")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let lir_output = Buffer()
        let is_lir_valid = lir_validate_program(lir_program)
        phase_time = compiler_debug_checkpoint("lir-validate", phase_time)
        if not is_lir_valid:
            eprintln("error: LIR validation failed")
            return false
        if not lir_dump_validated_program(lir_program, lir_output):
            eprintln("error: LIR validation failed while dumping")
            return false
        if not write_buffer(output_path, lir_output):
            return false
        if not compiler_cache_store(cache_key, output_path, output_mode, source.len()):
            eprintln("warning: failed to store compiler cache")
        return true
    elif output_mode == COMPILE_OUTPUT_LLVM:
        if not mir_validate_program(optimized_mir_program):
            eprintln("error: MIR validation failed")
            return false
        let lir_program = lir_model_build_program(optimized_mir_program)
        phase_time = compiler_debug_checkpoint("lir-build", phase_time)
        let llvm_output = Buffer()
        let is_lir_valid = lir_validate_program(lir_program)
        phase_time = compiler_debug_checkpoint("lir-validate", phase_time)
        if not is_lir_valid:
            eprintln("error: LIR validation failed")
            return false
        let is_llvm_valid = llvm_lower_lir(lir_program, source, llvm_output)
        phase_time = compiler_debug_checkpoint("llvm-lower", phase_time)
        if not is_llvm_valid:
            eprintln("error: LLVM lowering failed")
            return false
        if not write_buffer(output_path, llvm_output):
            return false
        phase_time = compiler_debug_checkpoint("llvm-write", phase_time)
        if not compiler_cache_store(cache_key, output_path, output_mode, source.len()):
            eprintln("warning: failed to store compiler cache")
        phase_time = compiler_debug_checkpoint("llvm-cache-store", phase_time)
        return true
    eprintln("error: only ast, hir, mir, lir, and llvm outputs are supported")
    return false

struct BuildArguments:
    input_path: str
    output_path: str
    is_optimized: bool
    is_valid: bool

def remove_source_extension(source_path: str) -> str:
    let index = source_path.len() - 1
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
    if input_path.len() < 3:
        is_valid = false
    BA_input_path = input_path
    BA_output_path = output_path
    BA_is_optimized = is_optimized
    BA_is_valid = is_valid

def build_source(source_path: str, output_path: str, is_optimized: bool) -> bool:
    if not ensure_compiler_dirs():
        eprintln("error: failed to create compiler target directories")
        return false
    let build_label = Buffer()
    append(build_label, "build_")
    append(build_label, source_path)
    let build_token = compiler_temp_token(build_label.to_str())
    let llvm_path_buffer = Buffer()
    append(llvm_path_buffer, "target/tmp/llvm_")
    append(llvm_path_buffer, build_token)
    append(llvm_path_buffer, ".ll")
    let llvm_path = llvm_path_buffer.to_str()
    let build_output_buffer = Buffer()
    append(build_output_buffer, "target/tmp/output_")
    append(build_output_buffer, build_token)
    let build_output_path = build_output_buffer.to_str()
    if not compile_source(source_path, llvm_path, COMPILE_OUTPUT_LLVM):
        remove_file(llvm_path)
        return false
    if not build_llvm(llvm_path, build_output_path, is_optimized):
        remove_file(llvm_path)
        remove_file(build_output_path)
        eprintln("error: failed to build executable")
        return false
    if not rename(build_output_path, output_path):
        remove_file(llvm_path)
        remove_file(build_output_path)
        eprintln("error: failed to publish executable")
        return false
    remove_file(llvm_path)
    return true

def run_build_command(argument_count: int) -> bool:
    parse_build_arguments(argument_count)
    if not BA_is_valid:
        eprintln("error: build accepts [--dev] <file.dm> [-o output]")
        return false
    let input_length = BA_input_path.len()
    if input_length < 3 or BA_input_path[input_length - 3:input_length] != ".dm":
        eprintln("error: input file must have .dm extension")
        return false
    return build_source(BA_input_path, BA_output_path, BA_is_optimized)

def print_usage(usage: str):
    print("用法: " + arg(0) + usage)

def main() -> int:
    let argument_count = argc()
    let usage = " build [--dev] <file.dm> [-o output] | ast/hir/mir/lir/llvm <input.dm> -o <output>"
    if argument_count == 2:
        let command_name = arg(1)
        if command_name in ["help", "--help"]:
            print_usage(usage)
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
                eprintln("error: use ast, hir, mir, lir, or llvm")
                return 1
        if compile_source(arg(2), arg(4), output_mode):
            return 0
        return 1
    print_usage(usage)
    return 1
