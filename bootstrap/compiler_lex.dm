from str import from_int
from utf8 import ord

const TOKEN_EOF: int = 0
const TOKEN_INTEGER: int = 1
const TOKEN_IDENTIFIER: int = 2
const TOKEN_LET: int = 3
const TOKEN_PLUS: int = 5
const TOKEN_MINUS: int = 6
const TOKEN_MULTIPLY: int = 7
const TOKEN_DIVIDE: int = 8
const TOKEN_OPEN_PAREN: int = 9
const TOKEN_CLOSE_PAREN: int = 10
const TOKEN_ASSIGN: int = 11
const TOKEN_NEWLINE: int = 12
const TOKEN_DEF: int = 13
const TOKEN_RETURN: int = 14
const TOKEN_COLON: int = 15
const TOKEN_COMMA: int = 16
const TOKEN_ARROW: int = 17
const TOKEN_LESS: int = 18
const TOKEN_IF: int = 19
const TOKEN_ELIF: int = 20
const TOKEN_ELSE: int = 21
const TOKEN_WHILE: int = 22
const TOKEN_SWITCH: int = 23
const TOKEN_CASE: int = 24
const TOKEN_DEFAULT: int = 25
const TOKEN_STRING: int = 26
const TOKEN_OPEN_BRACKET: int = 27
const TOKEN_CLOSE_BRACKET: int = 28
const TOKEN_EQUAL: int = 29
const TOKEN_NOT_EQUAL: int = 30
const TOKEN_LESS_EQUAL: int = 31
const TOKEN_GREATER_EQUAL: int = 32
const TOKEN_GREATER: int = 33
const TOKEN_AND: int = 34
const TOKEN_OR: int = 35
const TOKEN_MODULO: int = 36
const TOKEN_CONST: int = 37
const TOKEN_TRUE: int = 38
const TOKEN_FALSE: int = 39
const TOKEN_FOR: int = 40
const TOKEN_OPEN_BRACE: int = 41
const TOKEN_CLOSE_BRACE: int = 42
const TOKEN_DOT: int = 43
const TOKEN_QUESTION: int = 44
const TOKEN_FLOAT: int = 45
const TOKEN_NOT: int = 46
const TOKEN_CONS: int = 47
const TOKEN_RUNE: int = 48
const TOKEN_BREAK: int = 49
const TOKEN_IN: int = 51
const TOKEN_CONTINUE: int = 52
const TOKEN_PLUS_ASSIGN: int = 53
const TOKEN_MINUS_ASSIGN: int = 54
const TOKEN_MULTIPLY_ASSIGN: int = 55
const TOKEN_DIVIDE_ASSIGN: int = 56
const TOKEN_MODULO_ASSIGN: int = 57
const TOKEN_FLOORDIVIDE: int = 58
const TOKEN_POWER: int = 59
const TOKEN_AMP: int = 60
const TOKEN_CARET: int = 61
const TOKEN_TILDE: int = 62
const TOKEN_SHL: int = 63
const TOKEN_SHR: int = 64
const TOKEN_POWER_ASSIGN: int = 65
const TOKEN_AMP_ASSIGN: int = 66
const TOKEN_PIPE_ASSIGN: int = 67
const TOKEN_CARET_ASSIGN: int = 68
const TOKEN_SHL_ASSIGN: int = 69
const TOKEN_SHR_ASSIGN: int = 70
const TOKEN_PIPE: int = 71
const TOKEN_FLOORDIVIDE_ASSIGN: int = 72

struct ParseContext:
    src: str
    kinds: list[int]
    starts: list[int]
    ends: list[int]
    fn_starts: list[int]
    fn_ends: list[int]
    param_offsets: list[int]
    param_counts: list[int]
    param_starts: list[int]
    param_ends: list[int]
    ret_types: list[int]
    pd: list[int]
    cst_starts: list[int]
    cst_ends: list[int]
    cst_values: list[int]
    file_packages: list[int]
    file_starts: list[int]
    file_ends: list[int]

const VALUE_TYPE_GLOBAL_INT: int = 30
const VALUE_TYPE_GLOBAL_STRING: int = 31
const VALUE_TYPE_GLOBAL_FLOAT: int = 32
const VALUE_TYPE_GLOBAL_BOOL: int = 33
const VALUE_TYPE_GLOBAL_LIST: int = 34
const VALUE_TYPE_GLOBAL_DICT_INT_INT: int = 35
const VALUE_TYPE_GLOBAL_DICT_INT_STRING: int = 36
const VALUE_TYPE_GLOBAL_DICT_STRING_INT: int = 37
const VALUE_TYPE_GLOBAL_DICT_STRING_STRING: int = 38
const VALUE_TYPE_UNKNOWN: int = 39
const VALUE_TYPE_LIST_STRING: int = 40
const VALUE_TYPE_LIST_INT: int = 41
const VALUE_TYPE_STRUCT: int = 42
const VALUE_TYPE_ENUM: int = 43


const VALUE_TYPE_IMMEDIATE: int = 0
const VALUE_TYPE_INT: int = 1
const VALUE_TYPE_STRING: int = 2
const VALUE_TYPE_LIST: int = 3
const VALUE_TYPE_BOOL: int = 4
const VALUE_TYPE_GLOBAL: int = 5
const VALUE_TYPE_DICT_INT_INT: int = 6
const VALUE_TYPE_DICT_INT_STRING: int = 7
const VALUE_TYPE_DICT_STRING_INT: int = 8
const VALUE_TYPE_DICT_STRING_STRING: int = 9
const VALUE_TYPE_FLOAT: int = 10
const VALUE_TYPE_BYTES: int = 11
const VALUE_TYPE_INTERFACE: int = 12
const VALUE_TYPE_FUNCTION_PARAMETER: int = 100
const VALUE_TYPE_FUNCTION_BASE: int = 101
const VALUE_TYPE_CLOSURE_BASE: int = 1000000

const ASCII_TAB: int = 9
const ASCII_LINE_FEED: int = 10
const ASCII_CARRIAGE_RETURN: int = 13
const ASCII_SPACE: int = 32
const ASCII_HASH: int = 35
const ASCII_DOUBLE_QUOTE: int = 34
const ASCII_SINGLE_QUOTE: int = 39
const ASCII_COMMA: int = 44
const ASCII_MINUS: int = 45
const ASCII_DIGIT_ZERO: int = 48
const ASCII_DIGIT_NINE: int = 57
const ASCII_UPPER_A: int = 65
const ASCII_UPPER_Z: int = 90
const ASCII_LOWER_A: int = 97
const ASCII_LOWER_B: int = 98
const ASCII_LOWER_Z: int = 122
const ASCII_BACKSLASH: int = 92
const ASCII_UNDERSCORE: int = 95
const ASCII_PLUS: int = 43
const ASCII_STAR: int = 42
const ASCII_SLASH: int = 47
const ASCII_OPEN_PAREN: int = 40
const ASCII_CLOSE_PAREN: int = 41
const ASCII_OPEN_BRACKET: int = 91
const ASCII_CLOSE_BRACKET: int = 93
const ASCII_OPEN_BRACE: int = 123
const ASCII_CLOSE_BRACE: int = 125
const ASCII_DOT: int = 46
const ASCII_EQUAL: int = 61
const ASCII_COLON: int = 58
const ASCII_LESS: int = 60
const ASCII_GREATER: int = 62
const ASCII_BANG: int = 33
const ASCII_PERCENT: int = 37
const ASCII_QUESTION: int = 63
const ASCII_AMP: int = 38
const ASCII_CARET: int = 94
const ASCII_TILDE: int = 126
const ASCII_PIPE: int = 124

const PACKAGE_STDLIB: int = 0
const PACKAGE_BOOTSTRAP: int = 1
const PACKAGE_USER: int = 2

struct TokenStream:
    src: str
    kinds: list[int]
    starts: list[int]
    ends: list[int]

struct NameRanges:
    starts: list[int]
    ends: list[int]

struct FunctionTable:
    starts: list[int]
    ends: list[int]
    bodies: list[int]
    body_ends: list[int]
    param_offsets: list[int]
    param_counts: list[int]
    param_starts: list[int]
    param_ends: list[int]
    param_types: list[int]
    param_struct_decls: list[int]
    return_types: list[int]
    return_struct_decls: list[int]
    default_indexes: list[int]
    annotation_starts: list[int]
    annotation_ends: list[int]

struct ConstantTable:
    starts: list[int]
    ends: list[int]
    values: list[int]
    types: list[int]
    literal_starts: list[int]
    literal_ends: list[int]

struct ImplTable:
    func_indexes: list[int]
    declaration_indexes: list[int]
    interface_types: list[int]

struct InterfaceTable:
    name_starts: list[int]
    name_ends: list[int]
    func_indexes: list[int]
    declaration_indexes: list[int]
    impl_name_starts: list[int]
    impl_name_ends: list[int]

struct GlobalTable:
    name_starts: list[int]
    name_ends: list[int]
    types: list[int]
    expression_indexes: list[int]

def classify_package(file_path: str) -> int:
    if __c_str_starts_with(file_path, "runtime/stdlib/"):
        return PACKAGE_STDLIB
    if __c_str_starts_with(file_path, "bootstrap/"):
        return PACKAGE_BOOTSTRAP
    return PACKAGE_USER

def get_file_at_offset(file_starts: list[int], file_ends: list[int], offset: int) -> int:
    let file_count = len(file_starts)
    let file_index = 0
    while file_index < file_count:
        if offset >= file_starts[file_index] and offset < file_ends[file_index]:
            return file_index
        file_index = file_index + 1
    return -1

def get_package_at_offset(context: ParseContext, offset: int) -> int:
    let file_index = get_file_at_offset(context.file_starts, context.file_ends, offset)
    if file_index < 0:
        return PACKAGE_USER
    return context.file_packages[file_index]

def is_same_package(context: ParseContext, offset_a: int, offset_b: int) -> bool:
    let package_a = get_package_at_offset(context, offset_a)
    let package_b = get_package_at_offset(context, offset_b)
    return package_a == package_b

def is_trusted_package(package_id: int) -> bool:
    return package_id == PACKAGE_STDLIB or package_id == PACKAGE_BOOTSTRAP

def is_private_symbol(name: str) -> bool:
    if len(name) == 0:
        return false
    return ord(name[0]) == ASCII_UNDERSCORE

let access_violation_count: list[int] = [0]

def report_access_violation(context: ParseContext, call_site_offset: int, callee_name: str, callee_offset: int):
    access_violation_count[0] = access_violation_count[0] + 1
    eprint("Error: access violation - '")
    eprint(callee_name)
    eprint("' is not accessible from ")
    let caller_pkg = get_package_at_offset(context, call_site_offset)
    if caller_pkg == PACKAGE_STDLIB:
        eprint("stdlib")
    elif caller_pkg == PACKAGE_BOOTSTRAP:
        eprint("bootstrap")
    else:
        eprint("user code")
    eprintln("")

def is_digit(code: int) -> bool:
    if code < ASCII_DIGIT_ZERO:
        return false
    if code > ASCII_DIGIT_NINE:
        return false
    return true

def is_hex_digit(code: int) -> bool:
    if is_digit(code):
        return true
    if code >= ASCII_LOWER_A and code <= ASCII_LOWER_A + 5:
        return true
    if code >= ASCII_UPPER_A and code <= ASCII_UPPER_A + 5:
        return true
    return false

def is_identifier_start(code: int) -> bool:
    if code >= ASCII_UPPER_A and code <= ASCII_UPPER_Z:
        return true
    if code >= ASCII_LOWER_A and code <= ASCII_LOWER_Z:
        return true
    if code == ASCII_UNDERSCORE:
        return true
    return false

def is_identifier_continue(code: int) -> bool:
    if is_identifier_start(code):
        return true
    if is_digit(code):
        return true
    return false


def is_temporary_value_type(value_type: int) -> bool:
    if value_type == VALUE_TYPE_INT:
        return true
    if value_type == VALUE_TYPE_STRING:
        return true
    if value_type == VALUE_TYPE_LIST:
        return true
    if value_type == VALUE_TYPE_BYTES:
        return true
    if value_type == VALUE_TYPE_BOOL:
        return true
    if value_type >= VALUE_TYPE_DICT_INT_INT and value_type <= VALUE_TYPE_DICT_STRING_STRING:
        return true
    if value_type == VALUE_TYPE_FLOAT:
        return true
    if value_type == VALUE_TYPE_INTERFACE:
        return true
    if is_closure_value_type(value_type):
        return true
    return false

def is_dictionary_value_type(value_type: int) -> bool:
    if value_type < VALUE_TYPE_DICT_INT_INT:
        return false
    if value_type > VALUE_TYPE_DICT_STRING_STRING:
        return false
    return true

def is_sequence_value_type(value_type: int) -> bool:
    if value_type == VALUE_TYPE_LIST:
        return true
    if value_type == VALUE_TYPE_LIST_STRING:
        return true
    if value_type == VALUE_TYPE_BYTES:
        return true
    return false

def is_interface_value_type(value_type: int) -> bool:
    return value_type == VALUE_TYPE_INTERFACE

def closure_environment_slot_width(value_type: int) -> int:
    if value_type == VALUE_TYPE_FLOAT:
        return 2
    if value_type == VALUE_TYPE_STRING or is_sequence_value_type(value_type):
        return 2
    if is_dictionary_value_type(value_type) or is_closure_value_type(value_type):
        return 2
    return 1

def is_func_value_type(value_type: int) -> bool:
    if value_type < 0:
        return true
    return value_type >= VALUE_TYPE_FUNCTION_PARAMETER

def func_value_index(value_type: int) -> int:
    return value_type - VALUE_TYPE_FUNCTION_BASE

def is_lambda_value_type(value_type: int) -> bool:
    return value_type < 0

def is_closure_value_type(value_type: int) -> bool:
    if value_type < VALUE_TYPE_CLOSURE_BASE:
        return false
    return true

def closure_value_index(value_type: int) -> int:
    return value_type - VALUE_TYPE_CLOSURE_BASE

def lambda_value_index(value_type: int) -> int:
    return 0 - value_type - 1

def collect_lambda_parameter_ranges(tokens: TokenStream, lambda_token_index: int, parameters: NameRanges):
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let parameter_index = lambda_token_index + 2
    while token_kind(kinds, parameter_index) not in [TOKEN_CLOSE_PAREN, TOKEN_EOF]:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds,
            parameter_index + 1) == TOKEN_COLON:
            append(parameters.starts, token_start(starts, parameter_index))
            append(parameters.ends, token_end(ends, parameter_index))
        parameter_index = parameter_index + 1

def lambda_body_start(kinds: list[int], lambda_token_index: int) -> int:
    let arrow_index = lambda_token_index + 2
    while token_kind(kinds, arrow_index) not in [TOKEN_ARROW, TOKEN_EOF]:
        arrow_index = arrow_index + 1
    return arrow_index + 1

def lambda_body_end(kinds: list[int], body_start: int) -> int:
    let body_index = body_start
    let nested_depth = 0
    while token_kind(kinds, body_index) != TOKEN_EOF:
        let body_kind = token_kind(kinds, body_index)
        if body_kind in [TOKEN_OPEN_PAREN, TOKEN_OPEN_BRACKET, TOKEN_OPEN_BRACE]:
            nested_depth = nested_depth + 1
        if body_kind in [TOKEN_CLOSE_PAREN, TOKEN_CLOSE_BRACKET, TOKEN_CLOSE_BRACE]:
            if nested_depth == 0:
                return body_index
            nested_depth = nested_depth - 1
        if body_kind == TOKEN_COMMA and nested_depth == 0:
            return body_index
        if body_kind == TOKEN_NEWLINE and nested_depth == 0:
            return body_index
        body_index = body_index + 1
    return body_index

def collect_lambda_captures(tokens: TokenStream, body_start: int, body_end: int, parameters: NameRanges,
    captures: NameRanges):
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let parameter_starts = parameters.starts
    let parameter_ends = parameters.ends
    let capture_starts = captures.starts
    let capture_ends = captures.ends
    let current_index = body_start
    while current_index < body_end and token_kind(kinds, current_index) != TOKEN_EOF:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER:
            let current_name_start = token_start(starts, current_index)
            let current_name_end = token_end(ends, current_index)
            let current_name = source[current_name_start:current_name_end]
            if current_name == "lambda":
                let nested_parameters = NameRanges{
                    starts: [],
                    ends: []
                }
                collect_lambda_parameter_ranges(tokens, current_index, nested_parameters)
                let nested_body_start = lambda_body_start(kinds, current_index)
                let nested_body_end = lambda_body_end(kinds, nested_body_start)
                let nested_captures = NameRanges{
                    starts: [],
                    ends: []
                }
                collect_lambda_captures(tokens, nested_body_start, nested_body_end, nested_parameters, nested_captures)
                let nested_capture_index = 0
                while nested_capture_index < len(nested_captures.starts):
                    let nested_capture_start = nested_captures.starts[nested_capture_index]
                    let nested_capture_end = nested_captures.ends[nested_capture_index]
                    let nested_is_parameter = find_variable(source, nested_capture_start, nested_capture_end,
                        parameter_starts, parameter_ends) >= 0
                    let is_existing_capture = find_variable(source, nested_capture_start, nested_capture_end,
                        capture_starts, capture_ends) >= 0
                    if not nested_is_parameter and not is_existing_capture:
                        append(capture_starts, nested_capture_start)
                        append(capture_ends, nested_capture_end)
                    nested_capture_index = nested_capture_index + 1
                current_index = nested_body_end
            if current_name != "lambda":
                let direct_is_parameter = find_variable(source, current_name_start, current_name_end, parameter_starts,
                    parameter_ends) >= 0
                let is_call_name = token_kind(kinds, current_index + 1) == TOKEN_OPEN_PAREN
                let is_keyword_name = false
                if current_name in ["if", "else", "match", "true", "false"]:
                    is_keyword_name = true
                if (
                    current_name != "_" and
                    not direct_is_parameter and
                    not is_call_name and
                    not is_keyword_name and
                    find_variable(source, current_name_start, current_name_end, capture_starts, capture_ends) < 0
                ):
                    append(capture_starts, current_name_start)
                    append(capture_ends, current_name_end)
        current_index = current_index + 1

def enclosing_lambda_token_index(tokens: TokenStream, token_index: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let current_index = 0
    let enclosing_index = -1
    while current_index < token_index and token_kind(kinds, current_index) != TOKEN_EOF:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER and source[token_start(starts,
            current_index):token_end(ends, current_index)] == "lambda":
            let body_start = lambda_body_start(kinds, current_index)
            let body_end = lambda_body_end(kinds, body_start)
            if token_index >= body_start and token_index < body_end:
                enclosing_index = current_index
        current_index = current_index + 1
    return enclosing_index

def lambda_capture_expression_type(kinds: list[int], value_index: int) -> int:
    let value_kind = token_kind(kinds, value_index)
    if value_kind == TOKEN_STRING:
        return VALUE_TYPE_STRING
    if value_kind == TOKEN_FLOAT:
        return VALUE_TYPE_FLOAT
    if value_kind in [TOKEN_TRUE, TOKEN_FALSE]:
        return VALUE_TYPE_BOOL
    if value_kind == TOKEN_OPEN_BRACKET:
        return VALUE_TYPE_LIST
    if value_kind == TOKEN_OPEN_BRACE:
        return VALUE_TYPE_DICT_INT_INT
    if value_kind == TOKEN_NOT:
        return VALUE_TYPE_BOOL
    return VALUE_TYPE_INT

def lambda_capture_type(tokens: TokenStream, lambda_token_index: int, capture_start: int, capture_end: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_definition_index = lambda_token_index - 1
    while func_definition_index >= 0 and token_kind(kinds, func_definition_index) != TOKEN_DEF:
        func_definition_index = func_definition_index - 1
    let declaration_index = lambda_token_index - 1
    while declaration_index > func_definition_index:
        if token_kind(kinds, declaration_index) == TOKEN_LET and token_kind(kinds,
            declaration_index + 1) == TOKEN_IDENTIFIER:
            let declaration_name_start = token_start(starts, declaration_index + 1)
            let declaration_name_end = token_end(ends, declaration_index + 1)
            if source_ranges_equal(source, declaration_name_start, declaration_name_end, capture_start, capture_end):
                let value_index = declaration_index + 2
                if token_kind(kinds, value_index) == TOKEN_COLON:
                    let annotation_index = value_index + 1
                    let assignment_index = annotation_index
                    while token_kind(kinds, assignment_index) not in [TOKEN_ASSIGN, TOKEN_EOF]:
                        assignment_index = assignment_index + 1
                    let annotation_type = get_parameter_type(tokens, annotation_index)
                    if annotation_type != VALUE_TYPE_IMMEDIATE:
                        return annotation_type
                    value_index = assignment_index + 1
                if token_kind(kinds, value_index) == TOKEN_ASSIGN:
                    value_index = value_index + 1
                return lambda_capture_expression_type(kinds, value_index)
        declaration_index = declaration_index - 1
    let parameter_index = func_definition_index + 2
    while parameter_index < lambda_token_index:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER:
            let parameter_name_start = token_start(starts, parameter_index)
            let parameter_name_end = token_end(ends, parameter_index)
            if source_ranges_equal(source, parameter_name_start, parameter_name_end, capture_start,
                capture_end) and token_kind(kinds, parameter_index + 1) == TOKEN_COLON:
                let parameter_type = get_parameter_type(tokens, parameter_index + 2)
                if parameter_type != VALUE_TYPE_IMMEDIATE:
                    return parameter_type
                return VALUE_TYPE_INT
        parameter_index = parameter_index + 1
    return VALUE_TYPE_INT

def lambda_parameter_type(tokens: TokenStream, lambda_token_index: int, parameter_number: int) -> int:
    let kinds = tokens.kinds
    let parameter_index = lambda_token_index + 2
    let current_parameter_number = 0
    while token_kind(kinds, parameter_index) not in [TOKEN_CLOSE_PAREN, TOKEN_EOF]:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds,
            parameter_index + 1) == TOKEN_COLON:
            if current_parameter_number == parameter_number:
                return get_parameter_type(tokens, parameter_index + 2)
            current_parameter_number = current_parameter_number + 1
        parameter_index = parameter_index + 1
    return VALUE_TYPE_INT


def token_start(starts: list[int], index: int) -> int:
    if index < 0 or index >= len(starts):
        return 0
    return starts[index]

def token_end(ends: list[int], index: int) -> int:
    if index < 0 or index >= len(ends):
        return 0
    return ends[index]

def append_token(kinds: list[int], starts: list[int], ends: list[int], kind: int, start: int, end: int):
    append(kinds, kind)
    append(starts, start)
    append(ends, end)

def keyword_kind(source: str, start: int, end: int) -> int:
    let word = source[start:end]
    if word == "let":
        return TOKEN_LET
    if word == "def":
        return TOKEN_DEF
    if word == "return":
        return TOKEN_RETURN
    if word == "if":
        return TOKEN_IF
    if word == "elif":
        return TOKEN_ELIF
    if word == "else":
        return TOKEN_ELSE
    if word == "while":
        return TOKEN_WHILE
    if word == "break":
        return TOKEN_BREAK
    if word == "continue":
        return TOKEN_CONTINUE
    if word == "for":
        return TOKEN_FOR
    if word == "in":
        return TOKEN_IN
    if word == "switch":
        return TOKEN_SWITCH
    if word == "case":
        return TOKEN_CASE
    if word == "default":
        return TOKEN_DEFAULT
    if word == "const":
        return TOKEN_CONST
    if word == "and":
        return TOKEN_AND
    if word == "or":
        return TOKEN_OR
    if word == "not":
        return TOKEN_NOT
    if word == "true":
        return TOKEN_TRUE
    if word == "false":
        return TOKEN_FALSE
    return TOKEN_IDENTIFIER

def lex(tokens: TokenStream) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let index = 0
    let source_length = len(source)
    let bracket_depth = 0
    while index < source_length:
        let code = ord(source[index])
        let handled = false
        if code in [ASCII_SPACE, ASCII_TAB, ASCII_CARRIAGE_RETURN]:
            index = index + 1
            handled = true
        if not handled and code == ASCII_LINE_FEED:
            if bracket_depth == 0:
                append_token(kinds, starts, ends, TOKEN_NEWLINE, index, index + 1)
            index = index + 1
            handled = true
        if not handled and code == ASCII_HASH:
            let comment_at_line_start = index == 0 or source[index - 1] == '\n'
            while index < source_length and source[index] != '\n':
                index = index + 1
            if comment_at_line_start and index < source_length:
                index = index + 1
            handled = true
        if not handled and is_digit(code):
            let number_start = index
            let is_hex = false
            if code == ASCII_DIGIT_ZERO and index + 1 < source_length:
                if source[index + 1] in ['x', 'X']:
                    is_hex = true
                    index = index + 2
                    while index < source_length and is_hex_digit(ord(source[index])):
                        index = index + 1
            if not is_hex:
                while index < source_length and is_digit(ord(source[index])):
                    index = index + 1
            let is_float = false
            if index < source_length and source[index] == '.':
                let next_index = index + 1
                if next_index < source_length:
                    let next_code = ord(source[next_index])
                    if is_digit(next_code):
                        is_float = true
                        index = next_index
                        while index < source_length and is_digit(ord(source[index])):
                            index = index + 1
            if is_float:
                append_token(kinds, starts, ends, TOKEN_FLOAT, number_start, index)
            if not is_float:
                append_token(kinds, starts, ends, TOKEN_INTEGER, number_start, index)
            handled = true
        if not handled and is_identifier_start(code):
            if code == ASCII_LOWER_B and index + 1 < source_length and source[index + 1] == '\'':
                let byte_rune_start = index + 2
                index = index + 2
                while index < source_length and source[index] != '\'':
                    let byte_rune_step = 1
                    if source[index] == '\\' and index + 1 < source_length:
                        byte_rune_step = 2
                    index = index + byte_rune_step
                append_token(kinds, starts, ends, TOKEN_RUNE, byte_rune_start, index)
                if index < source_length:
                    index = index + 1
                handled = true
            if not handled:
                let identifier_start = index
                while index < source_length and is_identifier_continue(ord(source[index])):
                    index = index + 1
                append_token(kinds, starts, ends, keyword_kind(source, identifier_start, index), identifier_start,
                    index)
                handled = true
        if not handled and code == ASCII_DOUBLE_QUOTE:
            let string_start = index + 1
            index = index + 1
            while index < source_length and source[index] != '"':
                let step = 1
                if source[index] == '\\' and index + 1 < source_length:
                    step = 2
                index = index + step
            append_token(kinds, starts, ends, TOKEN_STRING, string_start, index)
            let closing_step = 0
            if index < source_length:
                closing_step = 1
            index = index + closing_step
            handled = true
        if not handled and code == ASCII_SINGLE_QUOTE:
            let is_triple_string = false
            if index + 2 < source_length:
                if source[index + 1] == '\'' and source[index + 2] == '\'':
                    is_triple_string = true
            if is_triple_string:
                let string_start = index + 3
                index = string_start
                let string_closed = false
                while index < source_length and not string_closed:
                    if index + 2 < source_length:
                        if source[index] == '\'' and source[index + 1] == '\'' and source[index + 2] == '\'':
                            string_closed = true
                    if not string_closed:
                        index = index + 1
                append_token(kinds, starts, ends, TOKEN_STRING, string_start, index)
                if string_closed:
                    index = index + 3
                handled = true
            if not is_triple_string:
                let rune_start = index + 1
                index = index + 1
                while index < source_length and source[index] != '\'':
                    let rune_step = 1
                    if source[index] == '\\' and index + 1 < source_length:
                        rune_step = 2
                    index = index + rune_step
                append_token(kinds, starts, ends, TOKEN_RUNE, rune_start, index)
                let rune_closing_step = 0
                if index < source_length:
                    rune_closing_step = 1
                index = index + rune_closing_step
                handled = true
        if not handled:
            switch code:
                case ASCII_PLUS:
                    let is_plus_assign = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_plus_assign = true
                    if is_plus_assign:
                        append_token(kinds, starts, ends, TOKEN_PLUS_ASSIGN, index, index + 2)
                        index = index + 2
                    if not is_plus_assign:
                        append_token(kinds, starts, ends, TOKEN_PLUS, index, index + 1)
                        index = index + 1
                case ASCII_MINUS:
                    let is_arrow = false
                    let is_minus_assign = false
                    if index + 1 < source_length and source[index + 1] == '>':
                        is_arrow = true
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_minus_assign = true
                    if is_arrow:
                        append_token(kinds, starts, ends, TOKEN_ARROW, index, index + 2)
                        index = index + 2
                    if is_minus_assign:
                        append_token(kinds, starts, ends, TOKEN_MINUS_ASSIGN, index, index + 2)
                        index = index + 2
                    if not is_arrow and not is_minus_assign:
                        append_token(kinds, starts, ends, TOKEN_MINUS, index, index + 1)
                        index = index + 1
                case ASCII_STAR:
                    let is_multiply_assign = false
                    let is_power = false
                    let is_power_assign = false
                    if index + 1 < source_length and source[index + 1] == '*':
                        is_power = true
                        if index + 2 < source_length and source[index + 2] == '=':
                            is_power_assign = true
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_multiply_assign = true
                    if is_power_assign:
                        append_token(kinds, starts, ends, TOKEN_POWER_ASSIGN, index, index + 3)
                        index = index + 3
                    elif is_power:
                        append_token(kinds, starts, ends, TOKEN_POWER, index, index + 2)
                        index = index + 2
                    elif is_multiply_assign:
                        append_token(kinds, starts, ends, TOKEN_MULTIPLY_ASSIGN, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_MULTIPLY, index, index + 1)
                        index = index + 1
                case ASCII_SLASH:
                    let is_divide_assign = false
                    let is_floor_divide = false
                    let is_floor_divide_assign = false
                    if index + 1 < source_length and source[index + 1] == '/':
                        is_floor_divide = true
                        if index + 2 < source_length and source[index + 2] == '=':
                            is_floor_divide_assign = true
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_divide_assign = true
                    if is_floor_divide_assign:
                        append_token(kinds, starts, ends, TOKEN_FLOORDIVIDE_ASSIGN, index, index + 3)
                        index = index + 3
                    elif is_floor_divide:
                        append_token(kinds, starts, ends, TOKEN_FLOORDIVIDE, index, index + 2)
                        index = index + 2
                    elif is_divide_assign:
                        append_token(kinds, starts, ends, TOKEN_DIVIDE_ASSIGN, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_DIVIDE, index, index + 1)
                        index = index + 1
                case ASCII_OPEN_PAREN:
                    append_token(kinds, starts, ends, TOKEN_OPEN_PAREN, index, index + 1)
                    bracket_depth = bracket_depth + 1
                    index = index + 1
                case ASCII_CLOSE_PAREN:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_PAREN, index, index + 1)
                    if bracket_depth > 0:
                        bracket_depth = bracket_depth - 1
                    index = index + 1
                case ASCII_OPEN_BRACKET:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACKET, index, index + 1)
                    bracket_depth = bracket_depth + 1
                    index = index + 1
                case ASCII_CLOSE_BRACKET:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACKET, index, index + 1)
                    if bracket_depth > 0:
                        bracket_depth = bracket_depth - 1
                    index = index + 1
                case ASCII_OPEN_BRACE:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACE, index, index + 1)
                    bracket_depth = bracket_depth + 1
                    index = index + 1
                case ASCII_CLOSE_BRACE:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACE, index, index + 1)
                    if bracket_depth > 0:
                        bracket_depth = bracket_depth - 1
                    index = index + 1
                case ASCII_DOT:
                    append_token(kinds, starts, ends, TOKEN_DOT, index, index + 1)
                    index = index + 1
                case ASCII_EQUAL:
                    let is_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_equal = true
                    if is_equal:
                        append_token(kinds, starts, ends, TOKEN_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_equal:
                        append_token(kinds, starts, ends, TOKEN_ASSIGN, index, index + 1)
                        index = index + 1
                case ASCII_COLON:
                    let is_cons = false
                    if index + 1 < source_length and source[index + 1] == ':':
                        is_cons = true
                    if is_cons:
                        append_token(kinds, starts, ends, TOKEN_CONS, index, index + 2)
                        index = index + 2
                    if not is_cons:
                        append_token(kinds, starts, ends, TOKEN_COLON, index, index + 1)
                        index = index + 1
                case ASCII_COMMA:
                    append_token(kinds, starts, ends, TOKEN_COMMA, index, index + 1)
                    index = index + 1
                case ASCII_LESS:
                    let is_less_equal = false
                    let is_shift_left = false
                    let is_shift_left_assign = false
                    if index + 1 < source_length and source[index + 1] == '<':
                        is_shift_left = true
                        if index + 2 < source_length and source[index + 2] == '=':
                            is_shift_left_assign = true
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_less_equal = true
                    if is_shift_left_assign:
                        append_token(kinds, starts, ends, TOKEN_SHL_ASSIGN, index, index + 3)
                        index = index + 3
                    elif is_shift_left:
                        append_token(kinds, starts, ends, TOKEN_SHL, index, index + 2)
                        index = index + 2
                    elif is_less_equal:
                        append_token(kinds, starts, ends, TOKEN_LESS_EQUAL, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_LESS, index, index + 1)
                        index = index + 1
                case ASCII_GREATER:
                    let is_greater_equal = false
                    let is_shift_right = false
                    let is_shift_right_assign = false
                    if index + 1 < source_length and source[index + 1] == '>':
                        is_shift_right = true
                        if index + 2 < source_length and source[index + 2] == '=':
                            is_shift_right_assign = true
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_greater_equal = true
                    if is_shift_right_assign:
                        append_token(kinds, starts, ends, TOKEN_SHR_ASSIGN, index, index + 3)
                        index = index + 3
                    elif is_shift_right:
                        append_token(kinds, starts, ends, TOKEN_SHR, index, index + 2)
                        index = index + 2
                    elif is_greater_equal:
                        append_token(kinds, starts, ends, TOKEN_GREATER_EQUAL, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_GREATER, index, index + 1)
                        index = index + 1
                case ASCII_BANG:
                    let is_not_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_not_equal = true
                    if is_not_equal:
                        append_token(kinds, starts, ends, TOKEN_NOT_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_not_equal:
                        index = index + 1
                case ASCII_PERCENT:
                    let is_modulo_assign = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_modulo_assign = true
                        append_token(kinds, starts, ends, TOKEN_MODULO_ASSIGN, index, index + 2)
                        index = index + 2
                    if not is_modulo_assign:
                        append_token(kinds, starts, ends, TOKEN_MODULO, index, index + 1)
                        index = index + 1
                case ASCII_AMP:
                    if index + 1 < source_length and source[index + 1] == '=':
                        append_token(kinds, starts, ends, TOKEN_AMP_ASSIGN, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_AMP, index, index + 1)
                        index = index + 1
                case ASCII_CARET:
                    if index + 1 < source_length and source[index + 1] == '=':
                        append_token(kinds, starts, ends, TOKEN_CARET_ASSIGN, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_CARET, index, index + 1)
                        index = index + 1
                case ASCII_PIPE:
                    if index + 1 < source_length and source[index + 1] == '=':
                        append_token(kinds, starts, ends, TOKEN_PIPE_ASSIGN, index, index + 2)
                        index = index + 2
                    else:
                        append_token(kinds, starts, ends, TOKEN_PIPE, index, index + 1)
                        index = index + 1
                case ASCII_TILDE:
                    append_token(kinds, starts, ends, TOKEN_TILDE, index, index + 1)
                    index = index + 1
                case ASCII_QUESTION:
                    append_token(kinds, starts, ends, TOKEN_QUESTION, index, index + 1)
                    index = index + 1
                default:
                    index = index + 1

    append_token(kinds, starts, ends, TOKEN_EOF, source_length, source_length)
    return len(kinds)

def token_kind(kinds: list[int], index: int) -> int:
    if index < 0:
        return TOKEN_EOF
    let kinds_length = len(kinds)
    if index >= kinds_length:
        return 0
    return kinds[index]

def line_indent(source: str, position: int) -> int:
    let line_start = position - 1
    while line_start >= 0 and source[line_start] != '\n':
        line_start = line_start - 1
    let current_position = line_start + 1
    let result = 0
    while current_position < position and source[current_position] == ' ':
        result = result + 1
        current_position = current_position + 1
    return result

def enclosing_method_prefix(tokens: TokenStream, func_name_start: int) -> str:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    if line_indent(source, func_name_start) == 0:
        return ""
    let func_token_index = 0
    let func_token_found = false
    while token_kind(kinds, func_token_index) != TOKEN_EOF and not func_token_found:
        if token_start(starts, func_token_index) == func_name_start:
            func_token_found = true
        func_token_index = func_token_index + 1
    func_token_index = func_token_index - 1
    let scan_index = func_token_index
    while scan_index >= 0:
        if line_indent(source, token_start(starts, scan_index)) == 0:
            let declaration_name = source[token_start(starts, scan_index):token_end(ends, scan_index)]
            if declaration_name == "struct":
                if token_kind(kinds, scan_index + 1) == TOKEN_IDENTIFIER:
                    let struct_name = source[token_start(starts, scan_index + 1):token_end(ends, scan_index + 1)]
                    let struct_suffix = struct_name + "_"
                    return "__dir_method_" + struct_suffix
                return ""
            if declaration_name == "interface":
                return ""
            if declaration_name == "def":
                return ""
            if declaration_name == "impl":
                let interface_index = scan_index + 1
                let target_keyword_index = interface_index + 1
                while token_kind(kinds, target_keyword_index) not in [TOKEN_COLON, TOKEN_EOF]:
                    if token_kind(kinds, target_keyword_index) in [TOKEN_IDENTIFIER,
                        TOKEN_FOR] and source[token_start(starts, target_keyword_index):token_end(ends,
                        target_keyword_index)] == "for":
                        let target_index = target_keyword_index + 1
                        if token_kind(kinds, interface_index) == TOKEN_IDENTIFIER and token_kind(kinds,
                            target_index) == TOKEN_IDENTIFIER:
                            let interface_name = source[token_start(starts, interface_index):token_end(ends,
                                interface_index)]
                            let target_name = source[token_start(starts, target_index):token_end(ends, target_index)]
                            let target_suffix = target_name + "_"
                            let separator = "_"
                            let interface_target_name = interface_name + separator
                            let interface_suffix = interface_target_name + target_suffix
                            let implementation_prefix = "__dir_impl_"
                            return implementation_prefix + interface_suffix
                    target_keyword_index = target_keyword_index + 1
                return ""
        scan_index = scan_index - 1
    return ""

def enclosing_self_struct_declaration(tokens: TokenStream, func_name_start: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_token_index = 0
    let func_token_found = false
    while token_kind(kinds, func_token_index) != TOKEN_EOF and not func_token_found:
        if token_start(starts, func_token_index) == func_name_start:
            func_token_found = true
        func_token_index = func_token_index + 1
    let scan_index = func_token_index - 1
    while scan_index >= 0:
        if line_indent(source, token_start(starts, scan_index)) == 0:
            let declaration_name = source[token_start(starts, scan_index):token_end(ends, scan_index)]
            if declaration_name == "struct" and token_kind(kinds, scan_index + 1) == TOKEN_IDENTIFIER:
                return find_struct_declaration_index(source, token_start(starts, scan_index + 1), token_end(ends,
                    scan_index + 1))
            if declaration_name == "impl":
                let interface_index = scan_index + 1
                let target_keyword_index = interface_index + 1
                while token_kind(kinds, target_keyword_index) not in [TOKEN_COLON, TOKEN_EOF]:
                    let target_keyword = source[token_start(starts, target_keyword_index):token_end(ends,
                        target_keyword_index)]
                    if target_keyword == "for" and token_kind(kinds, target_keyword_index + 1) == TOKEN_IDENTIFIER:
                        return find_type_declaration_index(source, token_start(starts, target_keyword_index + 1),
                            token_end(ends, target_keyword_index + 1))
                    target_keyword_index = target_keyword_index + 1
                return -1
            if declaration_name in ["interface", "def"]:
                return -1
        scan_index = scan_index - 1
    return -1

def func_symbol_name(tokens: TokenStream, func_name_start: int, func_name_end: int) -> str:
    let source = tokens.src
    let method_prefix = enclosing_method_prefix(tokens, func_name_start)
    if len(method_prefix) == 0:
        return source[func_name_start:func_name_end]
    let func_name = source[func_name_start:func_name_end]
    return method_prefix + func_name

# 反查函数名所在 impl 行的接口泛型类型码；不在 impl 区段内返回 -1
def enclosing_impl_interface_type(tokens: TokenStream, func_name_start: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_token_index = 0
    let func_token_found = false
    while token_kind(kinds, func_token_index) != TOKEN_EOF and not func_token_found:
        if token_start(starts, func_token_index) == func_name_start:
            func_token_found = true
        func_token_index = func_token_index + 1
    let scan_index = func_token_index - 1
    while scan_index >= 0:
        if line_indent(source, token_start(starts, scan_index)) == 0:
            let declaration_name = source[token_start(starts, scan_index):token_end(ends, scan_index)]
            if declaration_name == "impl":
                let inner_start = -1
                let inner_end = -1
                let token_index = scan_index + 1
                let bracket_depth = 0
                let interface_done = false
                while token_kind(kinds, token_index) not in [TOKEN_COLON, TOKEN_EOF] and not interface_done:
                    let token_text = source[token_start(starts, token_index):token_end(ends, token_index)]
                    if token_text == "for":
                        if inner_start >= 0 and inner_end > inner_start:
                            interface_done = true
                        else:
                            return -1
                    elif token_kind(kinds, token_index) == TOKEN_OPEN_BRACKET:
                        bracket_depth = bracket_depth + 1
                    elif token_kind(kinds, token_index) == TOKEN_CLOSE_BRACKET and bracket_depth > 0:
                        if inner_start >= 0:
                            inner_end = token_start(starts, token_index)
                            bracket_depth = 0
                    elif bracket_depth > 0 and inner_start < 0:
                        inner_start = token_start(starts, token_index)
                    token_index = token_index + 1
                if inner_start < 0 or inner_end <= inner_start:
                    return -1
                let inner_text = source[inner_start:inner_end]
                if inner_text == "str":
                    return 0
                if inner_text == "int":
                    return 1
                if inner_text == "byte":
                    return 2
                if inner_text == "bool":
                    return 3
                if inner_text == "float":
                    return 4
                if inner_text == "bytes":
                    return 5
                return -1
            if declaration_name in ["struct", "interface", "def"]:
                return -1
        scan_index = scan_index - 1
    return -1

# 收集所有 impl 区段内 append 方法的分发表：结构体声明下标、接口泛型类型码、函数索引
def collect_impl_functions(tokens: TokenStream, functions: FunctionTable, impls: ImplTable):
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_starts = functions.starts
    let func_ends = functions.ends
    let impl_func_indexes = impls.func_indexes
    let impl_func_decls = impls.declaration_indexes
    let impl_func_interface_types = impls.interface_types
    let func_index = 0
    while func_index < len(func_starts):
        let func_name_start = func_starts[func_index]
        let func_name_end = func_ends[func_index]
        if source[func_name_start:func_name_end] == "append":
            let declaration_index = enclosing_self_struct_declaration(tokens, func_name_start)
            if declaration_index >= 0:
                let interface_type = enclosing_impl_interface_type(tokens, func_name_start)
                if interface_type >= 0:
                    append(impl_func_indexes, func_index)
                    append(impl_func_decls, declaration_index)
                    append(impl_func_interface_types, interface_type)
        func_index = func_index + 1

def enclosing_impl_interface_range(tokens: TokenStream, func_name_start: int) -> (int, int):
    # 函数所在 impl 块的接口名区间；非 impl 方法返回 (-1, -1)
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_token_index = 0
    let func_token_found = false
    while token_kind(kinds, func_token_index) != TOKEN_EOF and not func_token_found:
        if token_start(starts, func_token_index) == func_name_start:
            func_token_found = true
        func_token_index = func_token_index + 1
    let scan_index = func_token_index - 1
    while scan_index >= 0:
        if line_indent(source, token_start(starts, scan_index)) == 0:
            let declaration_name = source[token_start(starts, scan_index):token_end(ends, scan_index)]
            if declaration_name == "impl":
                if token_kind(kinds, scan_index + 1) == TOKEN_IDENTIFIER:
                    return (token_start(starts, scan_index + 1), token_end(ends, scan_index + 1))
                return (-1, -1)
            if declaration_name in ["struct", "interface", "def"]:
                return (-1, -1)
        scan_index = scan_index - 1
    return (-1, -1)

def collect_interfaces(tokens: TokenStream, functions: FunctionTable, interfaces: InterfaceTable):
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_starts = functions.starts
    let interface_name_starts = interfaces.name_starts
    let interface_name_ends = interfaces.name_ends
    let impl_func_indexes = interfaces.func_indexes
    let impl_decl_indexes = interfaces.declaration_indexes
    let impl_interface_name_starts = interfaces.impl_name_starts
    let impl_interface_name_ends = interfaces.impl_name_ends
    # 收集接口声明名与 impl 方法分发表（函数索引、struct 声明、接口名区间）
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if (
            token_kind(kinds, token_index) == TOKEN_IDENTIFIER and
            source[token_start(starts, token_index):token_end(ends, token_index)] == "interface" and
            token_kind(kinds, token_index + 1) == TOKEN_IDENTIFIER and
            token_kind(kinds, token_index + 2) == TOKEN_COLON
        ):
            append(interface_name_starts, token_start(starts, token_index + 1))
            append(interface_name_ends, token_end(ends, token_index + 1))
        token_index = token_index + 1
    let func_index = 0
    while func_index < len(func_starts):
        let declaration_index = enclosing_self_struct_declaration(tokens, func_starts[func_index])
        if declaration_index >= 0:
            let method_prefix = enclosing_method_prefix(tokens, func_starts[func_index])
            let interface_index = 0
            while interface_index < len(interface_name_starts):
                let interface_start = interface_name_starts[interface_index]
                let interface_end = interface_name_ends[interface_index]
                let interface_prefix = "__dir_impl_" + source[interface_start:interface_end] + "_"
                if (
                    len(method_prefix) >= len(interface_prefix) and
                    method_prefix[:len(interface_prefix)] == interface_prefix
                ):
                    append(impl_func_indexes, func_index)
                    append(impl_decl_indexes, declaration_index)
                    append(impl_interface_name_starts, interface_start)
                    append(impl_interface_name_ends, interface_end)
                    interface_index = len(interface_name_starts)
                else:
                    interface_index = interface_index + 1
        func_index = func_index + 1

def func_has_body(tokens: TokenStream, body_start: int, body_end: int, func_name_start: int) -> bool:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let definition_indent = line_indent(source, func_name_start)
    let current_index = body_start
    while current_index < body_end:
        if token_kind(kinds, current_index) != TOKEN_NEWLINE and line_indent(source, token_start(starts,
            current_index)) > definition_indent:
            return true
        current_index = current_index + 1
    return false

def find_struct_name_for_variable(tokens: TokenStream, name_start: int, name_end: int) -> str:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts,
            token_index), token_end(ends, token_index), name_start, name_end):
            if token_kind(kinds, token_index + 1) == TOKEN_COLON and token_kind(kinds,
                token_index + 2) == TOKEN_IDENTIFIER:
                return source[token_start(starts, token_index + 2):token_end(ends, token_index + 2)]
            if token_kind(kinds, token_index + 1) == TOKEN_ASSIGN and token_kind(kinds,
                token_index + 2) == TOKEN_IDENTIFIER and token_kind(kinds, token_index + 3) == TOKEN_OPEN_BRACE:
                return source[token_start(starts, token_index + 2):token_end(ends, token_index + 2)]
        token_index = token_index + 1
    return ""

def find_method_func_index(tokens: TokenStream, struct_name: str, method_name: str,
    functions: FunctionTable) -> int:
    let source = tokens.src
    let func_starts = functions.starts
    let func_ends = functions.ends
    let func_index = 0
    while func_index < len(func_starts):
        let candidate_name = source[func_starts[func_index]:func_ends[func_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(tokens, func_starts[func_index])
            let struct_suffix = struct_name + "_"
            let struct_prefix = "__dir_method_" + struct_suffix
            if candidate_prefix == struct_prefix:
                return func_index
            if len(candidate_prefix) > 0:
                return func_index
        func_index = func_index + 1
    return -1

def find_interface_name_for_variable(tokens: TokenStream, name_start: int, name_end: int) -> str:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts,
            token_index), token_end(ends, token_index), name_start, name_end):
            if token_kind(kinds, token_index + 1) == TOKEN_COLON and token_kind(kinds,
                token_index + 2) == TOKEN_IDENTIFIER:
                let type_start = token_start(starts, token_index + 2)
                let type_end = token_end(ends, token_index + 2)
                if source_type_is_interface(tokens, type_start, type_end):
                    return source[type_start:type_end]
        token_index = token_index + 1
    return ""

def struct_name_for_literal(tokens: TokenStream, expression_index: int) -> str:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    if token_kind(kinds, expression_index) == TOKEN_IDENTIFIER and token_kind(kinds,
        expression_index + 1) == TOKEN_OPEN_BRACE:
        return source[token_start(starts, expression_index):token_end(ends, expression_index)]
    return ""

def interface_method_index(tokens: TokenStream, interface_name: str, method_name: str) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts,
            token_index):token_end(ends, token_index)] == "interface":
            let name_index = token_index + 1
            if token_kind(kinds, name_index) == TOKEN_IDENTIFIER and source[token_start(starts,
                name_index):token_end(ends, name_index)] == interface_name:
                let interface_indent = line_indent(source, token_start(starts, token_index))
                let method_cursor = name_index + 1
                while token_kind(kinds, method_cursor) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                    method_cursor = method_cursor + 1
                method_cursor = method_cursor + 1
                let method_number = 0
                while token_kind(kinds, method_cursor) != TOKEN_EOF:
                    if token_kind(kinds, method_cursor) != TOKEN_NEWLINE and line_indent(source, token_start(starts,
                        method_cursor)) <= interface_indent:
                        return -1
                    if token_kind(kinds, method_cursor) == TOKEN_DEF and token_kind(kinds,
                        method_cursor + 1) == TOKEN_IDENTIFIER:
                        if source[token_start(starts, method_cursor + 1):token_end(ends,
                            method_cursor + 1)] == method_name:
                            return method_number
                        method_number = method_number + 1
                    method_cursor = method_cursor + 1
        token_index = token_index + 1
    return -1

def interface_method_count(tokens: TokenStream, interface_name: str) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts,
            token_index):token_end(ends, token_index)] == "interface":
            let name_index = token_index + 1
            if token_kind(kinds, name_index) == TOKEN_IDENTIFIER and source[token_start(starts,
                name_index):token_end(ends, name_index)] == interface_name:
                let interface_indent = line_indent(source, token_start(starts, token_index))
                let method_cursor = name_index + 1
                while token_kind(kinds, method_cursor) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                    method_cursor = method_cursor + 1
                method_cursor = method_cursor + 1
                let method_count = 0
                while token_kind(kinds, method_cursor) != TOKEN_EOF:
                    if token_kind(kinds, method_cursor) != TOKEN_NEWLINE and line_indent(source, token_start(starts,
                        method_cursor)) <= interface_indent:
                        return method_count
                    if token_kind(kinds, method_cursor) == TOKEN_DEF:
                        method_count = method_count + 1
                    method_cursor = method_cursor + 1
                return method_count
        token_index = token_index + 1
    return 0

def find_interface_method_func_index(tokens: TokenStream, interface_name: str, struct_name: str, method_name: str,
    functions: FunctionTable) -> int:
    let source = tokens.src
    let func_starts = functions.starts
    let func_ends = functions.ends
    let interface_target_prefix = interface_name + "_"
    let target_prefix = interface_target_prefix + struct_name
    let target_prefix_with_separator = target_prefix + "_"
    let method_prefix_body = "__dir_impl_" + target_prefix_with_separator
    let func_index = 0
    while func_index < len(func_starts):
        let candidate_name = source[func_starts[func_index]:func_ends[func_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(tokens, func_starts[func_index])
            if candidate_prefix == method_prefix_body:
                return func_index
        func_index = func_index + 1
    return -1

def find_interface_declaration_func_index(tokens: TokenStream, method_name: str, functions: FunctionTable) -> int:
    let source = tokens.src
    let func_starts = functions.starts
    let func_ends = functions.ends
    let func_index = 0
    while func_index < len(func_starts):
        let candidate_name = source[func_starts[func_index]:func_ends[func_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(tokens, func_starts[func_index])
            if len(candidate_prefix) == 0 and not func_has_body(tokens, 0, 0, func_starts[func_index]):
                return func_index
        func_index = func_index + 1
    return -1

def is_body_line(source: str, kinds: list[int], starts: list[int], index: int, body_indent: int) -> bool:
    let result = false
    if token_kind(kinds, index) == TOKEN_NEWLINE:
        result = true
    if line_indent(source, token_start(starts, index)) >= body_indent:
        result = true
    return result

def skip_newlines(kinds: list[int], index: int) -> int:
    let result = index
    while token_kind(kinds, result) == TOKEN_NEWLINE:
        result = result + 1
    return result

def skip_source_newlines(source: str, starts: list[int], index: int) -> int:
    let result = index
    while result < len(starts) and source[token_start(starts, result)] == '\n':
        result = result + 1
    return result


def parse_integer(source: str, start: int, end: int) -> int:
    let result = 0
    let index = start
    let is_hex = false
    if end - start > 2 and source[start] == '0':
        if source[start + 1] in ['x', 'X']:
            is_hex = true
            index = start + 2
    if is_hex:
        while index < end:
            let code = ord(source[index])
            let digit_value = code - 48
            if code >= ASCII_LOWER_A:
                digit_value = code - 87
            elif code >= ASCII_UPPER_A:
                digit_value = code - 55
            result = result * 16 + digit_value
            index = index + 1
    else:
        while index < end:
            result = result * 10 + ord(source[index]) - 48
            index = index + 1
    return result

def parse_rune_literal(source: str, start: int, end: int) -> int:
    if start >= end:
        return 0
    let first_code = ord(source[start])
    if first_code != ASCII_BACKSLASH:
        return first_code
    if start + 1 >= end:
        return 0
    let escaped_code = ord(source[start + 1])
    if escaped_code == ord('n'):
        return 10
    if escaped_code == ord('t'):
        return 9
    if escaped_code == ord('r'):
        return 13
    if escaped_code == ASCII_DIGIT_ZERO:
        return 0
    if escaped_code == ASCII_BACKSLASH:
        return 92
    if escaped_code == ASCII_SINGLE_QUOTE:
        return 39
    return escaped_code

def source_equals(source: str, start: int, end: int, expected: str) -> bool:
    return source[start:end] == expected

def source_ranges_equal(source: str, first_start: int, first_end: int, second_start: int, second_end: int) -> bool:
    return __c_range_equal(source, first_start, first_end, second_start, second_end)

def constant_is_used(tokens: TokenStream, body_start: int, body_end: int, constant_start: int,
    constant_end: int) -> bool:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let token_index = body_start
    while token_index < body_end:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts,
            token_index), token_end(ends, token_index), constant_start, constant_end):
            return true
        token_index = token_index + 1
    return false

def find_variable(source: str, name_start: int, name_end: int, variable_starts: list[int],
    variable_ends: list[int]) -> int:
    let result = -1
    let index = 0
    while index < len(variable_starts):
        if source_ranges_equal(source, name_start, name_end, variable_starts[index], variable_ends[index]):
            result = index
        index = index + 1
    return result

def find_function(source: str, name_start: int, name_end: int, func_starts: list[int],
    func_ends: list[int]) -> int:
    let result = -1
    let index = 0
    while index < len(func_starts):
        if source_ranges_equal(source, name_start, name_end, func_starts[index], func_ends[index]):
            result = index
        index = index + 1
    return result

let STRUCT_DECLARATION_STARTS = []
let STRUCT_DECLARATION_ENDS = []
let STRUCT_DECLARATION_HASHES = []
let STRUCT_DECLARATION_TOKENS = []
let ENUM_DECLARATION_STARTS = []
let ENUM_DECLARATION_ENDS = []
let INTERFACE_DECLARATION_STARTS = []
let INTERFACE_DECLARATION_ENDS = []

def collect_declared_types(tokens: TokenStream):
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    STRUCT_DECLARATION_STARTS = []
    STRUCT_DECLARATION_ENDS = []
    STRUCT_DECLARATION_HASHES = []
    STRUCT_DECLARATION_TOKENS = []
    ENUM_DECLARATION_STARTS = []
    ENUM_DECLARATION_ENDS = []
    INTERFACE_DECLARATION_STARTS = []
    INTERFACE_DECLARATION_ENDS = []
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER:
            let keyword_start = token_start(starts, token_index)
            let keyword_end = token_end(ends, token_index)
            let keyword_length = keyword_end - keyword_start
            let declaration_name_index = token_index + 1
            if keyword_length == 6 and source_equals(source, keyword_start, keyword_end, "struct"):
                if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER:
                    append(STRUCT_DECLARATION_STARTS, token_start(starts, declaration_name_index))
                    append(STRUCT_DECLARATION_ENDS, token_end(ends, declaration_name_index))
                    append(STRUCT_DECLARATION_HASHES, __c_fnv_hash_range(source, token_start(starts,
                        declaration_name_index), token_end(ends, declaration_name_index)))
                    append(STRUCT_DECLARATION_TOKENS, declaration_name_index)
            if keyword_length == 4 and source_equals(source, keyword_start, keyword_end, "enum"):
                if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER:
                    append(ENUM_DECLARATION_STARTS, token_start(starts, declaration_name_index))
                    append(ENUM_DECLARATION_ENDS, token_end(ends, declaration_name_index))
            if keyword_length == 9 and source_equals(source, keyword_start, keyword_end, "interface"):
                if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER:
                    append(INTERFACE_DECLARATION_STARTS, token_start(starts, declaration_name_index))
                    append(INTERFACE_DECLARATION_ENDS, token_end(ends, declaration_name_index))
        token_index = token_index + 1

const STRUCT_FIELD_INT: int = 1
const STRUCT_FIELD_BOOL: int = 2
const STRUCT_FIELD_PTR: int = 3
const STRUCT_FIELD_FLOAT: int = 4
const STRUCT_FIELD_STR: int = 5
const STRUCT_FIELD_LIST_INT: int = 6
const STRUCT_FIELD_LIST_STR: int = 7
const STRUCT_FIELD_DICT: int = 8

let STRUCT_FIELD_DECLARATIONS = []
let STRUCT_FIELD_NAME_STARTS = []
let STRUCT_FIELD_NAME_ENDS = []
let STRUCT_FIELD_SLOTS = []
let STRUCT_FIELD_KINDS = []
let STRUCT_FIELD_TYPE_DECLS = []
let STRUCT_FIELD_VALUE_TYPE_DECLS = []

def struct_field_kind_from_type(tokens: TokenStream, type_index: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    if token_kind(kinds, type_index) != TOKEN_IDENTIFIER:
        return STRUCT_FIELD_PTR
    let type_start = token_start(starts, type_index)
    let type_end = token_end(ends, type_index)
    if source_equals(source, type_start, type_end, "str"):
        return STRUCT_FIELD_STR
    if source_equals(source, type_start, type_end, "list") and token_kind(kinds, type_index + 1) == TOKEN_OPEN_BRACKET:
        let element_index = type_index + 2
        if source_equals(source, token_start(starts, element_index), token_end(ends, element_index), "str"):
            return STRUCT_FIELD_LIST_STR
        return STRUCT_FIELD_LIST_INT
    if source_equals(source, type_start, type_end, "dict") and token_kind(kinds, type_index + 1) == TOKEN_OPEN_BRACKET:
        return STRUCT_FIELD_DICT
    if source_equals(source, type_start, type_end, "int") or source_equals(source, type_start, type_end,
        "rune") or source_equals(source, type_start, type_end, "byte"):
        return STRUCT_FIELD_INT
    if source_equals(source, type_start, type_end, "bool"):
        return STRUCT_FIELD_BOOL
    if source_equals(source, type_start, type_end, "float"):
        return STRUCT_FIELD_FLOAT
    return STRUCT_FIELD_PTR

def struct_field_value_type_declaration(tokens: TokenStream, type_index: int) -> int:
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let source = tokens.src
    if token_kind(kinds, type_index) != TOKEN_IDENTIFIER or not source_equals(source,
        token_start(starts, type_index), token_end(ends, type_index), "dict"):
        return -1
    if token_kind(kinds, type_index + 1) != TOKEN_OPEN_BRACKET:
        return -1
    let cursor = type_index + 2
    let depth = 0
    while token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) == TOKEN_OPEN_BRACKET:
            depth = depth + 1
        elif token_kind(kinds, cursor) == TOKEN_CLOSE_BRACKET:
            if depth == 0:
                return -1
            depth = depth - 1
        elif token_kind(kinds, cursor) == TOKEN_COMMA and depth == 0:
            let value_index = cursor + 1
            if token_kind(kinds, value_index) != TOKEN_IDENTIFIER:
                return -1
            let value_start = token_start(starts, value_index)
            let value_end = token_end(ends, value_index)
            return find_type_declaration_index(source, value_start, value_end)
        cursor = cursor + 1
    return -1

def struct_field_slot_width(field_kind: int) -> int:
    if field_kind in [STRUCT_FIELD_PTR, STRUCT_FIELD_FLOAT, STRUCT_FIELD_STR, STRUCT_FIELD_LIST_INT,
        STRUCT_FIELD_LIST_STR, STRUCT_FIELD_DICT]:
        return 2
    return 1

def struct_field_type_declaration(tokens: TokenStream, type_index: int) -> int:
    let source = tokens.src
    let starts = tokens.starts
    let ends = tokens.ends
    let type_start = token_start(starts, type_index)
    let type_end = token_end(ends, type_index)
    while type_end > type_start and source[type_end - 1] == '?':
        type_end = type_end - 1
    if type_end <= type_start:
        return -1
    return find_type_declaration_index(source, type_start, type_end)

def collect_struct_fields(tokens: TokenStream):
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    STRUCT_FIELD_DECLARATIONS = []
    STRUCT_FIELD_NAME_STARTS = []
    STRUCT_FIELD_NAME_ENDS = []
    STRUCT_FIELD_SLOTS = []
    STRUCT_FIELD_KINDS = []
    STRUCT_FIELD_TYPE_DECLS = []
    STRUCT_FIELD_VALUE_TYPE_DECLS = []
    let declaration_index = 0
    while declaration_index < len(STRUCT_DECLARATION_TOKENS):
        let cursor = STRUCT_DECLARATION_TOKENS[declaration_index] + 1
        while token_kind(kinds, cursor) not in [TOKEN_NEWLINE, TOKEN_EOF]:
            cursor = cursor + 1
        cursor = cursor + 1
        let slot_index = 0
        let scanning = true
        while scanning and token_kind(kinds, cursor) != TOKEN_EOF:
            while token_kind(kinds, cursor) == TOKEN_NEWLINE:
                cursor = cursor + 1
            if token_kind(kinds, cursor) == TOKEN_EOF:
                scanning = false
            elif line_indent(source, token_start(starts, cursor)) == 0:
                scanning = false
            elif token_kind(kinds, cursor) == TOKEN_IDENTIFIER and token_kind(kinds, cursor + 1) == TOKEN_COLON:
                let field_kind = struct_field_kind_from_type(tokens, cursor + 2)
                append(STRUCT_FIELD_DECLARATIONS, declaration_index)
                append(STRUCT_FIELD_NAME_STARTS, token_start(starts, cursor))
                append(STRUCT_FIELD_NAME_ENDS, token_end(ends, cursor))
                append(STRUCT_FIELD_SLOTS, slot_index)
                append(STRUCT_FIELD_KINDS, field_kind)
                append(STRUCT_FIELD_TYPE_DECLS, struct_field_type_declaration(tokens, cursor + 2))
                append(STRUCT_FIELD_VALUE_TYPE_DECLS, struct_field_value_type_declaration(tokens, cursor + 2))
                slot_index = slot_index + struct_field_slot_width(field_kind)
                while token_kind(kinds, cursor) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                    cursor = cursor + 1
            else:
                while token_kind(kinds, cursor) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                    cursor = cursor + 1
        declaration_index = declaration_index + 1

def find_struct_declaration_index(source: str, name_start: int, name_end: int) -> int:
    let declaration_index = 0
    while declaration_index < len(STRUCT_DECLARATION_STARTS):
        if source_ranges_equal(source, STRUCT_DECLARATION_STARTS[declaration_index],
            STRUCT_DECLARATION_ENDS[declaration_index], name_start, name_end):
            return declaration_index
        declaration_index = declaration_index + 1
    return -1

def find_type_declaration_index(source: str, name_start: int, name_end: int) -> int:
    let struct_index = find_struct_declaration_index(source, name_start, name_end)
    if struct_index >= 0:
        return struct_index
    let enum_index = 0
    while enum_index < len(ENUM_DECLARATION_STARTS):
        if source_ranges_equal(source, ENUM_DECLARATION_STARTS[enum_index], ENUM_DECLARATION_ENDS[enum_index],
            name_start, name_end):
            return len(STRUCT_DECLARATION_STARTS) + enum_index
        enum_index = enum_index + 1
    return -1

def source_type_is_struct(tokens: TokenStream, type_start: int, type_end: int) -> bool:
    let source = tokens.src
    let declaration_index = 0
    while declaration_index < len(STRUCT_DECLARATION_STARTS):
        if source_ranges_equal(source, STRUCT_DECLARATION_STARTS[declaration_index],
            STRUCT_DECLARATION_ENDS[declaration_index], type_start, type_end):
            return true
        declaration_index = declaration_index + 1
    return false

def source_type_is_enum(source: str, type_start: int, type_end: int) -> bool:
    let declaration_index = 0
    while declaration_index < len(ENUM_DECLARATION_STARTS):
        if source_ranges_equal(source, ENUM_DECLARATION_STARTS[declaration_index],
            ENUM_DECLARATION_ENDS[declaration_index], type_start, type_end):
            return true
        declaration_index = declaration_index + 1
    return false

def source_type_is_interface(tokens: TokenStream, type_start: int, type_end: int) -> bool:
    let source = tokens.src
    let declaration_index = 0
    while declaration_index < len(INTERFACE_DECLARATION_STARTS):
        if source_ranges_equal(source, INTERFACE_DECLARATION_STARTS[declaration_index],
            INTERFACE_DECLARATION_ENDS[declaration_index], type_start, type_end):
            return true
        declaration_index = declaration_index + 1
    return false

def parameter_type_from_range(tokens: TokenStream, type_start: int, type_end: int) -> int:
    let source = tokens.src
    let type_name: str = source[type_start:type_end]
    let builtin_type_names: list[str] = ["int", "rune", "byte"]
    let found_type = 0
    if type_name == "str":
        found_type = VALUE_TYPE_STRING
    elif type_name == "list":
        found_type = VALUE_TYPE_LIST
    elif type_name == "dict":
        found_type = VALUE_TYPE_DICT_INT_INT
    elif type_name == "bytes":
        found_type = VALUE_TYPE_BYTES
    elif type_name == "bool":
        found_type = VALUE_TYPE_BOOL
    elif type_name == "float":
        found_type = VALUE_TYPE_FLOAT
    elif type_name in builtin_type_names:
        found_type = VALUE_TYPE_INT
    if found_type == 0:
        if source_type_is_enum(source, type_start, type_end):
            return VALUE_TYPE_ENUM
        if source_type_is_interface(tokens, type_start, type_end):
            return VALUE_TYPE_INTERFACE
    return found_type

def get_parameter_type(tokens: TokenStream, index: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    if token_kind(kinds, index) == TOKEN_OPEN_PAREN:
        return VALUE_TYPE_FUNCTION_PARAMETER
    if token_kind(kinds, index) != TOKEN_IDENTIFIER:
        return 0
    let parameter_type = parameter_type_from_range(tokens, token_start(starts, index), token_end(ends, index))
    if parameter_type == VALUE_TYPE_LIST and token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
        let element_index = index + 2
        if token_kind(kinds, element_index) == TOKEN_IDENTIFIER and source[token_start(starts,
            element_index):token_end(ends, element_index)] == "str":
            return VALUE_TYPE_LIST_STRING
        if token_kind(kinds, element_index) == TOKEN_IDENTIFIER and source_type_is_enum(source, token_start(starts,
            element_index), token_end(ends, element_index)):
            return VALUE_TYPE_LIST_STRING
        return VALUE_TYPE_LIST_INT
    if parameter_type != 0:
        return parameter_type
    if source_type_is_struct(tokens, token_start(starts, index), token_end(ends, index)):
        return VALUE_TYPE_STRUCT
    if source_type_is_interface(tokens, token_start(starts, index), token_end(ends, index)):
        return VALUE_TYPE_INTERFACE
    return 0

def parameter_type_from_declaration(tokens: TokenStream, name_start: int, name_end: int) -> int:
    let source = tokens.src
    if source_equals(source, name_start, name_end, "self"):
        return VALUE_TYPE_STRUCT
    let source_length = len(source)
    let type_start = name_end
    while type_start < source_length and source[type_start] != ':':
        type_start = type_start + 1
    if type_start >= source_length:
        return 0
    type_start = type_start + 1
    while type_start < source_length and source[type_start] == ' ':
        type_start = type_start + 1
    let type_end = type_start
    while type_end < source_length and source[type_end] not in [',', ')', '\n']:
        type_end = type_end + 1
    while type_end > type_start and source[type_end - 1] == ' ':
        type_end = type_end - 1
    return parameter_type_from_range(tokens, type_start, type_end)

def get_return_type(tokens: TokenStream, index: int) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    if token_kind(kinds, index) == TOKEN_OPEN_PAREN:
        return 3
    if token_kind(kinds, index) != TOKEN_IDENTIFIER:
        return 1
    let type_start = token_start(starts, index)
    let type_end = token_end(ends, index)
    if source_equals(source, type_start, type_end, "str"):
        return 2
    if source_equals(source, type_start, type_end, "bool"):
        return 4
    if source_equals(source, type_start, type_end, "float"):
        return 10
    if source_equals(source, type_start, type_end, "list"):
        if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
            let element_index = index + 2
            if token_kind(kinds, element_index) == TOKEN_IDENTIFIER and source[token_start(starts,
                element_index):token_end(ends, element_index)] == "str":
                return VALUE_TYPE_LIST_STRING
            if token_kind(kinds, element_index) == TOKEN_IDENTIFIER and source_type_is_enum(source, token_start(starts,
                element_index), token_end(ends, element_index)):
                return VALUE_TYPE_LIST_STRING
            return VALUE_TYPE_LIST_INT
        return 3
    if source_equals(source, type_start, type_end, "dict"):
        return VALUE_TYPE_DICT_INT_INT
    if source_equals(source, type_start, type_end, "bytes"):
        return VALUE_TYPE_BYTES
    if source_equals(source, type_start, type_end, "Option"):
        return 3
    if source_equals(source, type_start, type_end, "Result"):
        return 3
    if source_equals(source, type_start, type_end, "int") or source_equals(source, type_start, type_end,
        "rune") or source_equals(source, type_start, type_end, "byte"):
        return 1
    if source_type_is_struct(tokens, type_start, type_end):
        return VALUE_TYPE_STRUCT
    if source_type_is_enum(source, type_start, type_end):
        return VALUE_TYPE_ENUM
    if source_type_is_interface(tokens, type_start, type_end):
        return VALUE_TYPE_INTERFACE
    return 1

def find_func_open_parenthesis(kinds: list[int], name_index: int) -> int:
    let current_index = name_index + 1
    while token_kind(kinds, current_index) not in [TOKEN_OPEN_PAREN, TOKEN_EOF, TOKEN_NEWLINE]:
        current_index = current_index + 1
    return current_index

def find_parameter_boundary(kinds: list[int], start_index: int) -> int:
    let current_index = start_index
    let bracket_depth = 0
    let parenthesis_depth = 0
    while token_kind(kinds, current_index) != TOKEN_EOF:
        let current_kind = token_kind(kinds, current_index)
        if current_kind == TOKEN_OPEN_BRACKET:
            bracket_depth = bracket_depth + 1
        if current_kind == TOKEN_CLOSE_BRACKET and bracket_depth > 0:
            bracket_depth = bracket_depth - 1
        if current_kind == TOKEN_OPEN_PAREN:
            parenthesis_depth = parenthesis_depth + 1
        if current_kind == TOKEN_CLOSE_PAREN:
            if parenthesis_depth == 0 and bracket_depth == 0:
                return current_index
            if parenthesis_depth > 0:
                parenthesis_depth = parenthesis_depth - 1
        if current_kind == TOKEN_COMMA and bracket_depth == 0 and parenthesis_depth == 0:
            return current_index
        current_index = current_index + 1
    return current_index

def func_parameter_type(tokens: TokenStream, name_start: int, name_end: int, parameter_number: int,
    functions: FunctionTable) -> int:
    let source = tokens.src
    let func_starts = functions.starts
    let func_ends = functions.ends
    let func_param_offsets = functions.param_offsets
    let func_param_counts = functions.param_counts
    let parameter_starts = functions.param_starts
    let parameter_ends = functions.param_ends
    let func_index = find_function(source, name_start, name_end, func_starts, func_ends)
    if func_index < 0:
        return 0
    if func_index >= len(func_param_counts):
        return 0
    if parameter_number < 0 or parameter_number >= func_param_counts[func_index]:
        return 0
    let parameter_index = func_param_offsets[func_index] + parameter_number
    if parameter_index < 0 or parameter_index >= len(parameter_starts) or parameter_index >= len(parameter_ends):
        return 0
    return parameter_type_from_declaration(tokens, parameter_starts[parameter_index], parameter_ends[parameter_index])

def collect_functions(tokens: TokenStream, functions: FunctionTable) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let func_starts = functions.starts
    let func_ends = functions.ends
    let func_bodies = functions.bodies
    let func_body_ends = functions.body_ends
    let func_param_offsets = functions.param_offsets
    let func_param_counts = functions.param_counts
    let parameter_starts = functions.param_starts
    let parameter_ends = functions.param_ends
    let parameter_types = functions.param_types
    let parameter_struct_decls = functions.param_struct_decls
    let func_return_types = functions.return_types
    let func_return_struct_decls = functions.return_struct_decls
    let parameter_default_indexes = functions.default_indexes
    let parameter_annotation_starts = functions.annotation_starts
    let parameter_annotation_ends = functions.annotation_ends
    let current_index = 0
    # interface 声明块内的 def 只是方法签名，不收集为可调用函数
    let interface_indent = -1
    let interface_header_end = -1
    while token_kind(kinds, current_index) != TOKEN_EOF:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER:
            if interface_indent >= 0 and current_index > interface_header_end:
                if line_indent(source, token_start(starts, current_index)) <= interface_indent:
                    interface_indent = -1
            elif (
                source[token_start(starts, current_index):token_end(ends, current_index)] == "interface" and
                token_kind(kinds, current_index + 1) == TOKEN_IDENTIFIER and
                token_kind(kinds, current_index + 2) == TOKEN_COLON
            ):
                interface_indent = line_indent(source, token_start(starts, current_index))
                let header_scan = current_index + 1
                while token_kind(kinds, header_scan) not in [TOKEN_COLON, TOKEN_NEWLINE, TOKEN_EOF]:
                    header_scan = header_scan + 1
                interface_header_end = header_scan
        let is_func_definition = false
        if token_kind(kinds, current_index) == TOKEN_DEF:
            if interface_indent < 0:
                is_func_definition = true
        if is_func_definition:
            let name_index = current_index + 1
            let open_index = find_func_open_parenthesis(kinds, name_index)
            append(func_starts, token_start(starts, name_index))
            append(func_ends, token_end(ends, name_index))
            append(func_param_offsets, len(parameter_starts))
            let parameter_index = open_index + 1
            let parameter_count = 0
            while token_kind(kinds, parameter_index) not in [TOKEN_CLOSE_PAREN, TOKEN_EOF]:
                let is_parameter = false
                let parameter_name = ""
                if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER:
                    parameter_name = source[token_start(starts, parameter_index):token_end(ends, parameter_index)]
                if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds,
                    parameter_index + 1) == TOKEN_COLON:
                    is_parameter = true
                if parameter_name == "self" and line_indent(source, token_start(starts, current_index)) > 0:
                    is_parameter = true
                if is_parameter:
                    append(parameter_starts, token_start(starts, parameter_index))
                    append(parameter_ends, token_end(ends, parameter_index))
                    let parameter_type_index = parameter_index + 2
                    append(parameter_annotation_starts, token_start(starts, parameter_type_index))
                    append(parameter_annotation_ends, token_end(ends, parameter_type_index))
                    let collected_parameter_type = get_parameter_type(tokens, parameter_type_index)
                    let collected_struct_declaration = -1
                    if parameter_name == "self":
                        collected_parameter_type = VALUE_TYPE_STRUCT
                        collected_struct_declaration = enclosing_self_struct_declaration(tokens, token_start(starts,
                            name_index))
                    append(parameter_types, collected_parameter_type)
                    if collected_struct_declaration >= 0:
                        append(parameter_struct_decls, collected_struct_declaration)
                    else:
                        append(parameter_struct_decls, struct_field_type_declaration(tokens, parameter_type_index))
                    let parameter_boundary = find_parameter_boundary(kinds, parameter_index)
                    let default_index = -1
                    let default_scan_index = parameter_index + 1
                    while default_scan_index < parameter_boundary:
                        if token_kind(kinds, default_scan_index) == TOKEN_ASSIGN:
                            default_index = default_scan_index + 1
                            default_scan_index = parameter_boundary
                        else:
                            default_scan_index = default_scan_index + 1
                    append(parameter_default_indexes, default_index)
                    parameter_count = parameter_count + 1
                    parameter_index = parameter_boundary
                    if token_kind(kinds, parameter_index) == TOKEN_COMMA:
                        parameter_index = parameter_index + 1
                if not is_parameter:
                    parameter_index = parameter_index + 1
            append(func_param_counts, parameter_count)
            let header_index = parameter_index
            let func_return_type = 1
            let func_return_struct_decl = -1
            let return_type_scan_index = header_index + 1
            while token_kind(kinds, return_type_scan_index) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                if token_kind(kinds, return_type_scan_index) == TOKEN_ARROW:
                    func_return_type = get_return_type(tokens, return_type_scan_index + 1)
                    func_return_struct_decl = struct_field_type_declaration(tokens, return_type_scan_index + 1)
                return_type_scan_index = return_type_scan_index + 1
            append(func_return_types, func_return_type)
            append(func_return_struct_decls, func_return_struct_decl)
            while token_kind(kinds, header_index) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                header_index = header_index + 1
            let body_index = header_index + 1
            let body_end = body_index
            let found_body_boundary = false
            while token_kind(kinds, body_end) != TOKEN_EOF and not found_body_boundary:
                let is_top_level_boundary = false
                if token_kind(kinds, body_end) == TOKEN_DEF:
                    is_top_level_boundary = true
                if token_kind(kinds, body_end) != TOKEN_NEWLINE and line_indent(source, token_start(starts,
                    body_end)) == 0:
                    is_top_level_boundary = true
                if is_top_level_boundary:
                    found_body_boundary = true
                if not is_top_level_boundary:
                    body_end = body_end + 1
            append(func_bodies, body_index)
            append(func_body_ends, body_end)
            current_index = body_end
        if not is_func_definition:
            current_index = current_index + 1
    return len(func_starts)

def find_constant_index(source: str, constant_starts: list[int], constant_ends: list[int], name_start: int,
    name_end: int) -> int:
    let constant_index = 0
    while constant_index < len(constant_starts):
        if source_ranges_equal(source, constant_starts[constant_index], constant_ends[constant_index], name_start,
            name_end):
            return constant_index
        constant_index = constant_index + 1
    return -1

def collect_constants(tokens: TokenStream, constants: ConstantTable) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let constant_starts = constants.starts
    let constant_ends = constants.ends
    let constant_values = constants.values
    let constant_types = constants.types
    let constant_literal_starts = constants.literal_starts
    let constant_literal_ends = constants.literal_ends
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_CONST and token_kind(kinds, token_index + 1) == TOKEN_IDENTIFIER:
            let name_index = token_index + 1
            let value_index = token_index + 3
            if token_kind(kinds, token_index + 2) == TOKEN_COLON:
                value_index = token_index + 5
            let has_constant_value = false
            let constant_value = 0
            let constant_type = 0
            let literal_start = 0
            let literal_end = 0
            if token_kind(kinds, value_index) == TOKEN_INTEGER:
                has_constant_value = true
                constant_value = parse_integer(source, token_start(starts, value_index), token_end(ends, value_index))
                constant_type = 1
                literal_start = token_start(starts, value_index)
                literal_end = token_end(ends, value_index)
            if token_kind(kinds, value_index) == TOKEN_STRING:
                has_constant_value = true
                constant_type = 2
                literal_start = token_start(starts, value_index)
                literal_end = token_end(ends, value_index)
            if token_kind(kinds, value_index) == TOKEN_IDENTIFIER:
                let referenced_index = find_constant_index(source, constant_starts, constant_ends, token_start(starts,
                    value_index), token_end(ends, value_index))
                if referenced_index >= 0:
                    has_constant_value = true
                    constant_value = constant_values[referenced_index]
                    constant_type = constant_types[referenced_index]
                    literal_start = constant_literal_starts[referenced_index]
                    literal_end = constant_literal_ends[referenced_index]
            if has_constant_value:
                append(constant_starts, token_start(starts, name_index))
                append(constant_ends, token_end(ends, name_index))
                append(constant_values, constant_value)
                append(constant_types, constant_type)
                append(constant_literal_starts, literal_start)
                append(constant_literal_ends, literal_end)
                token_index = value_index
        token_index = token_index + 1
    return len(constant_starts)

def is_global_let_value_type(value_type: int) -> bool:
    return value_type >= VALUE_TYPE_GLOBAL_INT and value_type <= VALUE_TYPE_GLOBAL_DICT_STRING_STRING

def global_let_base_type(value_type: int) -> int:
    switch value_type:
        case VALUE_TYPE_GLOBAL_INT:
            return VALUE_TYPE_INT
        case VALUE_TYPE_GLOBAL_STRING:
            return VALUE_TYPE_STRING
        case VALUE_TYPE_GLOBAL_FLOAT:
            return VALUE_TYPE_FLOAT
        case VALUE_TYPE_GLOBAL_BOOL:
            return VALUE_TYPE_BOOL
        case VALUE_TYPE_GLOBAL_LIST:
            return VALUE_TYPE_LIST
        case VALUE_TYPE_GLOBAL_DICT_INT_INT:
            return VALUE_TYPE_DICT_INT_INT
        case VALUE_TYPE_GLOBAL_DICT_INT_STRING:
            return VALUE_TYPE_DICT_INT_STRING
        case VALUE_TYPE_GLOBAL_DICT_STRING_INT:
            return VALUE_TYPE_DICT_STRING_INT
        case VALUE_TYPE_GLOBAL_DICT_STRING_STRING:
            return VALUE_TYPE_DICT_STRING_STRING
    return VALUE_TYPE_INT

def global_let_value_type(base_type: int) -> int:
    switch base_type:
        case VALUE_TYPE_INT:
            return VALUE_TYPE_GLOBAL_INT
        case VALUE_TYPE_STRING:
            return VALUE_TYPE_GLOBAL_STRING
        case VALUE_TYPE_FLOAT:
            return VALUE_TYPE_GLOBAL_FLOAT
        case VALUE_TYPE_BOOL:
            return VALUE_TYPE_GLOBAL_BOOL
        case VALUE_TYPE_LIST:
            return VALUE_TYPE_GLOBAL_LIST
        case VALUE_TYPE_DICT_INT_INT:
            return VALUE_TYPE_GLOBAL_DICT_INT_INT
        case VALUE_TYPE_DICT_INT_STRING:
            return VALUE_TYPE_GLOBAL_DICT_INT_STRING
        case VALUE_TYPE_DICT_STRING_INT:
            return VALUE_TYPE_GLOBAL_DICT_STRING_INT
        case VALUE_TYPE_DICT_STRING_STRING:
            return VALUE_TYPE_GLOBAL_DICT_STRING_STRING
    return VALUE_TYPE_GLOBAL_INT


def parse_global_let_annotation(source: str, kinds: list[int], starts: list[int], ends: list[int],
    type_index: int) -> int:
    if token_kind(kinds, type_index) == TOKEN_IDENTIFIER:
        let type_name = source[token_start(starts, type_index):token_end(ends, type_index)]
        if type_name == "int":
            return VALUE_TYPE_INT
        if type_name == "str":
            return VALUE_TYPE_STRING
        if type_name == "float":
            return VALUE_TYPE_FLOAT
        if type_name == "bool":
            return VALUE_TYPE_BOOL
        if type_name == "list" and token_kind(kinds, type_index + 1) == TOKEN_OPEN_BRACKET:
            let element_index = type_index + 2
            if token_kind(kinds, element_index) == TOKEN_IDENTIFIER:
                let element_name = source[token_start(starts, element_index):token_end(ends, element_index)]
                if element_name in ["int", "rune", "byte", "float", "bool"]:
                    return VALUE_TYPE_LIST_INT
                return VALUE_TYPE_LIST_STRING
    return VALUE_TYPE_UNKNOWN

def collect_global_lets(tokens: TokenStream, globals: GlobalTable) -> int:
    let source = tokens.src
    let kinds = tokens.kinds
    let starts = tokens.starts
    let ends = tokens.ends
    let global_let_name_starts = globals.name_starts
    let global_let_name_ends = globals.name_ends
    let global_let_types = globals.types
    let global_let_expression_indexes = globals.expression_indexes
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_LET and line_indent(source, token_start(starts,
            token_index)) == 0 and token_kind(kinds, token_index + 1) == TOKEN_IDENTIFIER:
            let name_index = token_index + 1
            let name_start = token_start(starts, name_index)
            let name_end = token_end(ends, name_index)
            let value_type = VALUE_TYPE_UNKNOWN
            let assignment_index = token_index + 2
            if token_kind(kinds, token_index + 2) == TOKEN_COLON:
                value_type = parse_global_let_annotation(source, kinds, starts, ends, token_index + 3)
                assignment_index = token_index + 4
            while token_kind(kinds, assignment_index) not in [TOKEN_ASSIGN, TOKEN_NEWLINE, TOKEN_EOF]:
                assignment_index = assignment_index + 1
            if token_kind(kinds, assignment_index) == TOKEN_ASSIGN:
                let expression_index = assignment_index + 1
                if value_type == VALUE_TYPE_UNKNOWN:
                    if token_kind(kinds, expression_index) == TOKEN_OPEN_BRACKET:
                        value_type = VALUE_TYPE_LIST
                        let first_element_index = expression_index + 1
                        while token_kind(kinds, first_element_index) == TOKEN_NEWLINE:
                            first_element_index = first_element_index + 1
                        if token_kind(kinds, first_element_index) == TOKEN_STRING:
                            value_type = VALUE_TYPE_LIST_STRING
                    if token_kind(kinds, expression_index) == TOKEN_OPEN_BRACE:
                        value_type = VALUE_TYPE_DICT_INT_INT
                        let dict_first_key_index = expression_index + 1
                        while token_kind(kinds, dict_first_key_index) == TOKEN_NEWLINE:
                            dict_first_key_index = dict_first_key_index + 1
                        if token_kind(kinds, dict_first_key_index) == TOKEN_STRING:
                            let dict_colon_index = dict_first_key_index + 1
                            while token_kind(kinds, dict_colon_index) == TOKEN_NEWLINE:
                                dict_colon_index = dict_colon_index + 1
                            if token_kind(kinds, dict_colon_index) == TOKEN_COLON:
                                let dict_value_index = dict_colon_index + 1
                                while token_kind(kinds, dict_value_index) == TOKEN_NEWLINE:
                                    dict_value_index = dict_value_index + 1
                                if token_kind(kinds, dict_value_index) == TOKEN_STRING:
                                    value_type = VALUE_TYPE_DICT_STRING_STRING
                                else:
                                    value_type = VALUE_TYPE_DICT_STRING_INT
                    if token_kind(kinds, expression_index) == TOKEN_INTEGER:
                        value_type = VALUE_TYPE_INT
                    if token_kind(kinds, expression_index) == TOKEN_STRING:
                        value_type = VALUE_TYPE_STRING
                    if token_kind(kinds, expression_index) == TOKEN_FLOAT:
                        value_type = VALUE_TYPE_FLOAT
                    if token_kind(kinds, expression_index) in [TOKEN_TRUE, TOKEN_FALSE]:
                        value_type = VALUE_TYPE_BOOL
                append(global_let_name_starts, name_start)
                append(global_let_name_ends, name_end)
                append(global_let_types, value_type)
                append(global_let_expression_indexes, expression_index)
                token_index = assignment_index
        token_index = token_index + 1
    return len(global_let_name_starts)

def func_parameter_default(name_start: int, name_end: int, parameter_number: int, context: ParseContext) -> int:
    let func_index = find_function(context.src, name_start, name_end, context.fn_starts, context.fn_ends)
    if func_index < 0:
        return -1
    if func_index >= len(context.param_counts):
        return -1
    if parameter_number < 0 or parameter_number >= context.param_counts[func_index]:
        return -1
    let parameter_index = context.param_offsets[func_index] + parameter_number
    if parameter_index < 0 or parameter_index >= len(context.pd):
        return -1
    return context.pd[parameter_index]

def func_parameter_count(name_start: int, name_end: int, context: ParseContext) -> int:
    let func_index = find_function(context.src, name_start, name_end, context.fn_starts, context.fn_ends)
    if func_index < 0:
        return -1
    if func_index >= len(context.param_counts):
        return -1
    return context.param_counts[func_index]
