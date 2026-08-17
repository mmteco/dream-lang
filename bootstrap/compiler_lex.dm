const TOKEN_EOF: int = 0
const TOKEN_INTEGER: int = 1
const TOKEN_IDENTIFIER: int = 2
const TOKEN_LET: int = 3
const TOKEN_PRINT: int = 4
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

def is_digit(code: int) -> bool:
    if code < ASCII_DIGIT_ZERO:
        return false
    if code > ASCII_DIGIT_NINE:
        return false
    return true

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

def append_text(output: list[int], text: str):
    let index = 0
    while index < text_length(text):
        append(output, ord(text[index]))
        index = index + 1

def append_integer(output: list[int], value: int):
    let number = value
    if number < 0:
        append(output, ASCII_MINUS)
        number = 0 - number

    if number == 0:
        append(output, ASCII_DIGIT_ZERO)
    if number != 0:
        let divisor = 1
        while divisor <= number / 10:
            divisor = divisor * 10

        while divisor > 0:
            let quotient = number / divisor
            let digit = quotient % 10
            append(output, ASCII_DIGIT_ZERO + digit)
            divisor = divisor / 10

def append_temporary(output: list[int], temporary_index: int):
    append_text(output, "%t")
    append_integer(output, temporary_index)

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

def is_function_value_type(value_type: int) -> bool:
    if value_type < 0:
        return true
    return value_type >= VALUE_TYPE_FUNCTION_PARAMETER

def function_value_index(value_type: int) -> int:
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

def collect_lambda_parameter_ranges(kinds: list[int], starts: list[int], ends: list[int], lambda_token_index: int, parameter_starts: list[int], parameter_ends: list[int]):
    let parameter_index = lambda_token_index + 2
    while token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds, parameter_index + 1) == TOKEN_COLON:
            append(parameter_starts, token_start(starts, parameter_index))
            append(parameter_ends, token_end(ends, parameter_index))
        parameter_index = parameter_index + 1

def lambda_body_start(kinds: list[int], lambda_token_index: int) -> int:
    let arrow_index = lambda_token_index + 2
    while token_kind(kinds, arrow_index) != TOKEN_ARROW and token_kind(kinds, arrow_index) != TOKEN_EOF:
        arrow_index = arrow_index + 1
    return arrow_index + 1

def lambda_body_end(kinds: list[int], body_start: int) -> int:
    let body_index = body_start
    let nested_depth = 0
    while token_kind(kinds, body_index) != TOKEN_EOF:
        let body_kind = token_kind(kinds, body_index)
        if body_kind == TOKEN_OPEN_PAREN or body_kind == TOKEN_OPEN_BRACKET or body_kind == TOKEN_OPEN_BRACE:
            nested_depth = nested_depth + 1
        if body_kind == TOKEN_CLOSE_PAREN or body_kind == TOKEN_CLOSE_BRACKET or body_kind == TOKEN_CLOSE_BRACE:
            if nested_depth == 0:
                return body_index
            nested_depth = nested_depth - 1
        if body_kind == TOKEN_COMMA and nested_depth == 0:
            return body_index
        if body_kind == TOKEN_NEWLINE and nested_depth == 0:
            return body_index
        body_index = body_index + 1
    return body_index

def collect_lambda_captures(source: str, kinds: list[int], starts: list[int], ends: list[int], body_start: int, body_end: int, parameter_starts: list[int], parameter_ends: list[int], capture_starts: list[int], capture_ends: list[int]):
    let current_index = body_start
    while current_index < body_end and token_kind(kinds, current_index) != TOKEN_EOF:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER:
            let current_name_start = token_start(starts, current_index)
            let current_name_end = token_end(ends, current_index)
            let current_name = source[current_name_start:current_name_end]
            if current_name == "lambda":
                let nested_parameter_starts = []
                let nested_parameter_ends = []
                collect_lambda_parameter_ranges(kinds, starts, ends, current_index, nested_parameter_starts, nested_parameter_ends)
                let nested_body_start = lambda_body_start(kinds, current_index)
                let nested_body_end = lambda_body_end(kinds, nested_body_start)
                let nested_capture_starts = []
                let nested_capture_ends = []
                collect_lambda_captures(source, kinds, starts, ends, nested_body_start, nested_body_end, nested_parameter_starts, nested_parameter_ends, nested_capture_starts, nested_capture_ends)
                let nested_capture_index = 0
                while nested_capture_index < len(nested_capture_starts):
                    let nested_capture_start = nested_capture_starts[nested_capture_index]
                    let nested_capture_end = nested_capture_ends[nested_capture_index]
                    let nested_is_parameter = find_variable(source, nested_capture_start, nested_capture_end, parameter_starts, parameter_ends) >= 0
                    let is_existing_capture = find_variable(source, nested_capture_start, nested_capture_end, capture_starts, capture_ends) >= 0
                    if not nested_is_parameter and not is_existing_capture:
                        append(capture_starts, nested_capture_start)
                        append(capture_ends, nested_capture_end)
                    nested_capture_index = nested_capture_index + 1
                current_index = nested_body_end
            if current_name != "lambda":
                let direct_is_parameter = find_variable(source, current_name_start, current_name_end, parameter_starts, parameter_ends) >= 0
                let is_call_name = token_kind(kinds, current_index + 1) == TOKEN_OPEN_PAREN
                let is_keyword_name = false
                if current_name == "if" or current_name == "else" or current_name == "match" or current_name == "true" or current_name == "false":
                    is_keyword_name = true
                if current_name != "_" and not direct_is_parameter and not is_call_name and not is_keyword_name and find_variable(source, current_name_start, current_name_end, capture_starts, capture_ends) < 0:
                    append(capture_starts, current_name_start)
                    append(capture_ends, current_name_end)
        current_index = current_index + 1

def enclosing_lambda_token_index(source: str, kinds: list[int], starts: list[int], ends: list[int], token_index: int) -> int:
    let current_index = 0
    let enclosing_index = -1
    while current_index < token_index and token_kind(kinds, current_index) != TOKEN_EOF:
        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER and source[token_start(starts, current_index):token_end(ends, current_index)] == "lambda":
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
    if value_kind == TOKEN_TRUE or value_kind == TOKEN_FALSE:
        return VALUE_TYPE_BOOL
    if value_kind == TOKEN_OPEN_BRACKET:
        return VALUE_TYPE_LIST
    if value_kind == TOKEN_OPEN_BRACE:
        return VALUE_TYPE_DICT_INT_INT
    if value_kind == TOKEN_NOT:
        return VALUE_TYPE_BOOL
    return VALUE_TYPE_INT

def lambda_capture_type(source: str, kinds: list[int], starts: list[int], ends: list[int], lambda_token_index: int, capture_start: int, capture_end: int) -> int:
    let function_definition_index = lambda_token_index - 1
    while function_definition_index >= 0 and token_kind(kinds, function_definition_index) != TOKEN_DEF:
        function_definition_index = function_definition_index - 1
    let declaration_index = lambda_token_index - 1
    while declaration_index > function_definition_index:
        if token_kind(kinds, declaration_index) == TOKEN_LET and token_kind(kinds, declaration_index + 1) == TOKEN_IDENTIFIER:
            let declaration_name_start = token_start(starts, declaration_index + 1)
            let declaration_name_end = token_end(ends, declaration_index + 1)
            if source_ranges_equal(source, declaration_name_start, declaration_name_end, capture_start, capture_end):
                let value_index = declaration_index + 2
                if token_kind(kinds, value_index) == TOKEN_COLON:
                    let annotation_index = value_index + 1
                    let assignment_index = annotation_index
                    while token_kind(kinds, assignment_index) != TOKEN_ASSIGN and token_kind(kinds, assignment_index) != TOKEN_EOF:
                        assignment_index = assignment_index + 1
                    let annotation_type = get_parameter_type(source, kinds, starts, ends, annotation_index)
                    if annotation_type != VALUE_TYPE_IMMEDIATE:
                        return annotation_type
                    value_index = assignment_index + 1
                if token_kind(kinds, value_index) == TOKEN_ASSIGN:
                    value_index = value_index + 1
                return lambda_capture_expression_type(kinds, value_index)
        declaration_index = declaration_index - 1
    let parameter_index = function_definition_index + 2
    while parameter_index < lambda_token_index:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER:
            let parameter_name_start = token_start(starts, parameter_index)
            let parameter_name_end = token_end(ends, parameter_index)
            if source_ranges_equal(source, parameter_name_start, parameter_name_end, capture_start, capture_end) and token_kind(kinds, parameter_index + 1) == TOKEN_COLON:
                let parameter_type = get_parameter_type(source, kinds, starts, ends, parameter_index + 2)
                if parameter_type != VALUE_TYPE_IMMEDIATE:
                    return parameter_type
                return VALUE_TYPE_INT
        parameter_index = parameter_index + 1
    return VALUE_TYPE_INT

def lambda_parameter_type(source: str, kinds: list[int], starts: list[int], ends: list[int], lambda_token_index: int, parameter_number: int) -> int:
    let parameter_index = lambda_token_index + 2
    let current_parameter_number = 0
    while token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
        if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds, parameter_index + 1) == TOKEN_COLON:
            if current_parameter_number == parameter_number:
                return get_parameter_type(source, kinds, starts, ends, parameter_index + 2)
            current_parameter_number = current_parameter_number + 1
        parameter_index = parameter_index + 1
    return VALUE_TYPE_INT

def append_operand(output: list[int], value_type: int, value: int):
    let is_temporary = is_temporary_value_type(value_type)
    if is_temporary:
        append_temporary(output, value)
    if not is_temporary:
        append_integer(output, value)

def token_start(starts: list[int], index: int) -> int:
    if index < 0 or index >= len(starts):
        return 0
    return starts[index]

def token_end(ends: list[int], index: int) -> int:
    if index < 0 or index >= len(ends):
        return 0
    return ends[index]

def utf8_rune_byte_length(codepoint: int) -> int:
    if codepoint <= 127:
        return 1
    if codepoint <= 2047:
        return 2
    if codepoint <= 65535:
        return 3
    return 4

def append_hex_digit(output: list[int], digit: int):
    if digit < 10:
        append(output, ASCII_DIGIT_ZERO + digit)
    if digit >= 10:
        append(output, ASCII_UPPER_A + digit - 10)

def append_llvm_byte(output: list[int], byte_value: int):
    let is_printable = byte_value >= ASCII_SPACE and byte_value <= 126
    if is_printable and byte_value != ASCII_DOUBLE_QUOTE and byte_value != ASCII_BACKSLASH:
        append(output, byte_value)
    if not is_printable or byte_value == ASCII_DOUBLE_QUOTE or byte_value == ASCII_BACKSLASH:
        append(output, ASCII_BACKSLASH)
        append_hex_digit(output, byte_value / 16)
        append_hex_digit(output, byte_value % 16)

def append_utf8_rune(output: list[int], codepoint: int):
    if codepoint <= 127:
        append_llvm_byte(output, codepoint)
    elif codepoint <= 2047:
        let two_byte_high_bits = codepoint / 64
        let two_byte_low_bits = codepoint % 64
        let two_byte_first = 192 + two_byte_high_bits
        let two_byte_second = 128 + two_byte_low_bits
        append_llvm_byte(output, two_byte_first)
        append_llvm_byte(output, two_byte_second)
    elif codepoint <= 65535:
        let three_byte_remainder = codepoint % 4096
        let three_byte_high_bits = codepoint / 4096
        let three_byte_middle_bits = three_byte_remainder / 64
        let three_byte_low_bits = three_byte_remainder % 64
        let three_byte_first = 224 + three_byte_high_bits
        let three_byte_second = 128 + three_byte_middle_bits
        let three_byte_third = 128 + three_byte_low_bits
        append_llvm_byte(output, three_byte_first)
        append_llvm_byte(output, three_byte_second)
        append_llvm_byte(output, three_byte_third)
    else:
        let four_byte_remainder = codepoint % 262144
        let four_byte_high_bits = codepoint / 262144
        let four_byte_middle_bits = four_byte_remainder / 4096
        let final_four_byte_remainder = four_byte_remainder % 4096
        let four_byte_low_middle_bits = final_four_byte_remainder / 64
        let four_byte_low_bits = final_four_byte_remainder % 64
        let four_byte_first = 240 + four_byte_high_bits
        let four_byte_second = 128 + four_byte_middle_bits
        let four_byte_third = 128 + four_byte_low_middle_bits
        let four_byte_fourth = 128 + four_byte_low_bits
        append_llvm_byte(output, four_byte_first)
        append_llvm_byte(output, four_byte_second)
        append_llvm_byte(output, four_byte_third)
        append_llvm_byte(output, four_byte_fourth)

def string_literal_length(source: str, start: int, end: int) -> int:
    let index = start
    let length = 0
    while index < end:
        let is_escape = false
        if source[index] == '\\':
            if index + 1 < end:
                is_escape = true
        if is_escape:
            index = index + 2
        if not is_escape:
            index = index + 1
        if is_escape:
            length = length + 1
        if not is_escape:
            length = length + utf8_rune_byte_length(ord(source[index - 1]))
    return length + 1

def append_string_contents(output: list[int], source: str, start: int, end: int):
    let index = start
    while index < end:
        let code = ord(source[index])
        let is_escape = false
        if code == ASCII_BACKSLASH:
            if index + 1 < end:
                is_escape = true
        if is_escape:
            let escaped_code = ord(source[index + 1])
            let escaped_value = escaped_code
            if escaped_code == ord('n'):
                escaped_value = ASCII_LINE_FEED
            if escaped_code == ord('t'):
                escaped_value = ASCII_TAB
            if escaped_code == ord('r'):
                escaped_value = ASCII_CARRIAGE_RETURN
            if escaped_code == ASCII_DIGIT_ZERO:
                escaped_value = 0
            if escaped_code == ASCII_BACKSLASH:
                escaped_value = ASCII_BACKSLASH
            if escaped_code == ASCII_DOUBLE_QUOTE:
                escaped_value = ASCII_DOUBLE_QUOTE
            append_llvm_byte(output, escaped_value)
            index = index + 2
        if not is_escape:
            append_utf8_rune(output, code)
            index = index + 1

def append_string_global(output: list[int], source: str, starts: list[int], ends: list[int], token_index: int):
    let string_start = token_start(starts, token_index)
    let string_end = token_end(ends, token_index)
    let string_length = string_literal_length(source, string_start, string_end)
    append_text(output, "@.str")
    append_integer(output, token_index)
    append_text(output, " = private unnamed_addr constant [")
    append_integer(output, string_length)
    append_text(output, " x i8] c")
    append(output, 34)
    append_string_contents(output, source, string_start, string_end)
    append_text(output, "\\00")
    append(output, 34)
    append(output, 10)

def append_string_pointer(output: list[int], source: str, starts: list[int], ends: list[int], token_index: int, temporary_counter: int):
    let string_start = token_start(starts, token_index)
    let string_end = token_end(ends, token_index)
    let string_length = string_literal_length(source, string_start, string_end)
    append_temporary(output, temporary_counter)
    append_text(output, " = getelementptr [")
    append_integer(output, string_length)
    append_text(output, " x i8], [")
    append_integer(output, string_length)
    append_text(output, " x i8]* @.str")
    append_integer(output, token_index)
    append_text(output, ", i32 0, i32 0\n")

def append_float_literal(output: list[int], source: str, starts: list[int], ends: list[int], token_index: int, temporary_counter: int) -> int:
    let float_temporary = temporary_counter + 1
    append_temporary(output, float_temporary)
    append_text(output, " = fadd double 0.0, ")
    append_text(output, source[token_start(starts, token_index):token_end(ends, token_index)])
    append_text(output, "\n")
    return float_temporary

def append_bool_literal(output: list[int], value: int, temporary_counter: int) -> int:
    let bool_temporary = temporary_counter + 1
    append_temporary(output, bool_temporary)
    append_text(output, " = icmp eq i1 ")
    append_integer(output, value)
    append_text(output, ", 1\n")
    return bool_temporary

def append_token(kinds: list[int], starts: list[int], ends: list[int], kind: int, start: int, end: int):
    append(kinds, kind)
    append(starts, start)
    append(ends, end)

let KEYWORD_DICTIONARY = {
    "let": TOKEN_LET,
    "print": TOKEN_PRINT,
    "def": TOKEN_DEF,
    "return": TOKEN_RETURN,
    "if": TOKEN_IF,
    "elif": TOKEN_ELIF,
    "else": TOKEN_ELSE,
    "while": TOKEN_WHILE,
    "for": TOKEN_FOR,
    "switch": TOKEN_SWITCH,
    "case": TOKEN_CASE,
    "default": TOKEN_DEFAULT,
    "const": TOKEN_CONST,
    "and": TOKEN_AND,
    "or": TOKEN_OR,
    "not": TOKEN_NOT,
    "true": TOKEN_TRUE,
    "false": TOKEN_FALSE,
}

def keyword_kind(source: str, start: int, end: int) -> int:
    let word = source[start:end]
    let kind = KEYWORD_DICTIONARY[word]
    if kind == TOKEN_EOF:
        return TOKEN_IDENTIFIER
    return kind

def lex(source: str, kinds: list[int], starts: list[int], ends: list[int]) -> int:
    let index = 0
    let source_length = text_length(source)
    while index < source_length:
        let code = ord(source[index])
        let handled = false
        if code == ASCII_SPACE or code == ASCII_TAB or code == ASCII_CARRIAGE_RETURN:
            index = index + 1
            handled = true
        if not handled and code == ASCII_LINE_FEED:
            append_token(kinds, starts, ends, TOKEN_NEWLINE, index, index + 1)
            index = index + 1
            handled = true
        if not handled and code == ASCII_HASH:
            while index < source_length and source[index] != '\n':
                index = index + 1
            handled = true
        if not handled and is_digit(code):
            let number_start = index
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
                append_token(kinds, starts, ends, keyword_kind(source, identifier_start, index), identifier_start, index)
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
                    append_token(kinds, starts, ends, TOKEN_PLUS, index, index + 1)
                    index = index + 1
                case ASCII_MINUS:
                    let is_arrow = false
                    if index + 1 < source_length and source[index + 1] == '>':
                        is_arrow = true
                    if is_arrow:
                        append_token(kinds, starts, ends, TOKEN_ARROW, index, index + 2)
                        index = index + 2
                    if not is_arrow:
                        append_token(kinds, starts, ends, TOKEN_MINUS, index, index + 1)
                        index = index + 1
                case ASCII_STAR:
                    append_token(kinds, starts, ends, TOKEN_MULTIPLY, index, index + 1)
                    index = index + 1
                case ASCII_SLASH:
                    append_token(kinds, starts, ends, TOKEN_DIVIDE, index, index + 1)
                    index = index + 1
                case ASCII_OPEN_PAREN:
                    append_token(kinds, starts, ends, TOKEN_OPEN_PAREN, index, index + 1)
                    index = index + 1
                case ASCII_CLOSE_PAREN:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_PAREN, index, index + 1)
                    index = index + 1
                case ASCII_OPEN_BRACKET:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACKET, index, index + 1)
                    index = index + 1
                case ASCII_CLOSE_BRACKET:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACKET, index, index + 1)
                    index = index + 1
                case ASCII_OPEN_BRACE:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACE, index, index + 1)
                    index = index + 1
                case ASCII_CLOSE_BRACE:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACE, index, index + 1)
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
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_less_equal = true
                    if is_less_equal:
                        append_token(kinds, starts, ends, TOKEN_LESS_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_less_equal:
                        append_token(kinds, starts, ends, TOKEN_LESS, index, index + 1)
                        index = index + 1
                case ASCII_GREATER:
                    let is_greater_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_greater_equal = true
                    if is_greater_equal:
                        append_token(kinds, starts, ends, TOKEN_GREATER_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_greater_equal:
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
                    append_token(kinds, starts, ends, TOKEN_MODULO, index, index + 1)
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

def enclosing_method_prefix(source: str, kinds: list[int], starts: list[int], ends: list[int], function_name_start: int) -> str:
    if line_indent(source, function_name_start) == 0:
        return ""
    let function_token_index = 0
    let function_token_found = false
    while token_kind(kinds, function_token_index) != TOKEN_EOF and not function_token_found:
        if token_start(starts, function_token_index) == function_name_start:
            function_token_found = true
        function_token_index = function_token_index + 1
    function_token_index = function_token_index - 1
    let scan_index = function_token_index
    while scan_index >= 0:
        if line_indent(source, token_start(starts, scan_index)) == 0:
            let declaration_name = source[token_start(starts, scan_index):token_end(ends, scan_index)]
            if declaration_name == "struct":
                if token_kind(kinds, scan_index + 1) == TOKEN_IDENTIFIER:
                    let struct_name = source[token_start(starts, scan_index + 1):token_end(ends, scan_index + 1)]
                    let struct_suffix = string_concat(struct_name, "_")
                    return string_concat("__dir_method_", struct_suffix)
                return ""
            if declaration_name == "interface":
                return ""
            if declaration_name == "def":
                return ""
            if declaration_name == "impl":
                let interface_index = scan_index + 1
                let target_keyword_index = interface_index + 1
                while token_kind(kinds, target_keyword_index) != TOKEN_COLON and token_kind(kinds, target_keyword_index) != TOKEN_EOF:
                    if (token_kind(kinds, target_keyword_index) == TOKEN_IDENTIFIER or token_kind(kinds, target_keyword_index) == TOKEN_FOR) and source[token_start(starts, target_keyword_index):token_end(ends, target_keyword_index)] == "for":
                        let target_index = target_keyword_index + 1
                        if token_kind(kinds, interface_index) == TOKEN_IDENTIFIER and token_kind(kinds, target_index) == TOKEN_IDENTIFIER:
                            let interface_name = source[token_start(starts, interface_index):token_end(ends, interface_index)]
                            let target_name = source[token_start(starts, target_index):token_end(ends, target_index)]
                            let target_suffix = string_concat(target_name, "_")
                            let separator = "_"
                            let interface_target_name = string_concat(interface_name, separator)
                            let interface_suffix = string_concat(interface_target_name, target_suffix)
                            let implementation_prefix = "__dir_impl_"
                            return string_concat(implementation_prefix, interface_suffix)
                    target_keyword_index = target_keyword_index + 1
                return ""
        scan_index = scan_index - 1
    return ""

def function_symbol_name(source: str, kinds: list[int], starts: list[int], ends: list[int], function_name_start: int, function_name_end: int) -> str:
    let method_prefix = enclosing_method_prefix(source, kinds, starts, ends, function_name_start)
    if text_length(method_prefix) == 0:
        return source[function_name_start:function_name_end]
    let function_name = source[function_name_start:function_name_end]
    return string_concat(method_prefix, function_name)

def function_has_body(source: str, kinds: list[int], starts: list[int], body_start: int, body_end: int, function_name_start: int) -> bool:
    let definition_indent = line_indent(source, function_name_start)
    let current_index = body_start
    while current_index < body_end:
        if token_kind(kinds, current_index) != TOKEN_NEWLINE and line_indent(source, token_start(starts, current_index)) > definition_indent:
            return true
        current_index = current_index + 1
    return false

def find_struct_name_for_variable(source: str, kinds: list[int], starts: list[int], ends: list[int], name_start: int, name_end: int) -> str:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, token_index), token_end(ends, token_index), name_start, name_end):
            if token_kind(kinds, token_index + 1) == TOKEN_COLON and token_kind(kinds, token_index + 2) == TOKEN_IDENTIFIER:
                return source[token_start(starts, token_index + 2):token_end(ends, token_index + 2)]
            if token_kind(kinds, token_index + 1) == TOKEN_ASSIGN and token_kind(kinds, token_index + 2) == TOKEN_IDENTIFIER and token_kind(kinds, token_index + 3) == TOKEN_OPEN_BRACE:
                return source[token_start(starts, token_index + 2):token_end(ends, token_index + 2)]
        token_index = token_index + 1
    return ""

def find_method_function_index(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name: str, method_name: str, function_starts: list[int], function_ends: list[int]) -> int:
    let function_index = 0
    while function_index < len(function_starts):
        let candidate_name = source[function_starts[function_index]:function_ends[function_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(source, kinds, starts, ends, function_starts[function_index])
            let struct_suffix = string_concat(struct_name, "_")
            let struct_prefix = string_concat("__dir_method_", struct_suffix)
            if candidate_prefix == struct_prefix:
                return function_index
            if text_length(candidate_prefix) > 0:
                return function_index
        function_index = function_index + 1
    return -1

def find_interface_name_for_variable(source: str, kinds: list[int], starts: list[int], ends: list[int], name_start: int, name_end: int) -> str:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, token_index), token_end(ends, token_index), name_start, name_end):
            if token_kind(kinds, token_index + 1) == TOKEN_COLON and token_kind(kinds, token_index + 2) == TOKEN_IDENTIFIER:
                let type_start = token_start(starts, token_index + 2)
                let type_end = token_end(ends, token_index + 2)
                if source_type_is_interface(source, kinds, starts, ends, type_start, type_end):
                    return source[type_start:type_end]
        token_index = token_index + 1
    return ""

def struct_name_for_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], expression_index: int) -> str:
    if token_kind(kinds, expression_index) == TOKEN_IDENTIFIER and token_kind(kinds, expression_index + 1) == TOKEN_OPEN_BRACE:
        return source[token_start(starts, expression_index):token_end(ends, expression_index)]
    return ""

def interface_method_index(source: str, kinds: list[int], starts: list[int], ends: list[int], interface_name: str, method_name: str) -> int:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "interface":
            let name_index = token_index + 1
            if token_kind(kinds, name_index) == TOKEN_IDENTIFIER and source[token_start(starts, name_index):token_end(ends, name_index)] == interface_name:
                let interface_indent = line_indent(source, token_start(starts, token_index))
                let method_cursor = name_index + 1
                while token_kind(kinds, method_cursor) != TOKEN_NEWLINE and token_kind(kinds, method_cursor) != TOKEN_EOF:
                    method_cursor = method_cursor + 1
                method_cursor = method_cursor + 1
                let method_number = 0
                while token_kind(kinds, method_cursor) != TOKEN_EOF:
                    if token_kind(kinds, method_cursor) != TOKEN_NEWLINE and line_indent(source, token_start(starts, method_cursor)) <= interface_indent:
                        return -1
                    if token_kind(kinds, method_cursor) == TOKEN_DEF and token_kind(kinds, method_cursor + 1) == TOKEN_IDENTIFIER:
                        if source[token_start(starts, method_cursor + 1):token_end(ends, method_cursor + 1)] == method_name:
                            return method_number
                        method_number = method_number + 1
                    method_cursor = method_cursor + 1
        token_index = token_index + 1
    return -1

def interface_method_count(source: str, kinds: list[int], starts: list[int], ends: list[int], interface_name: str) -> int:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "interface":
            let name_index = token_index + 1
            if token_kind(kinds, name_index) == TOKEN_IDENTIFIER and source[token_start(starts, name_index):token_end(ends, name_index)] == interface_name:
                let interface_indent = line_indent(source, token_start(starts, token_index))
                let method_cursor = name_index + 1
                while token_kind(kinds, method_cursor) != TOKEN_NEWLINE and token_kind(kinds, method_cursor) != TOKEN_EOF:
                    method_cursor = method_cursor + 1
                method_cursor = method_cursor + 1
                let method_count = 0
                while token_kind(kinds, method_cursor) != TOKEN_EOF:
                    if token_kind(kinds, method_cursor) != TOKEN_NEWLINE and line_indent(source, token_start(starts, method_cursor)) <= interface_indent:
                        return method_count
                    if token_kind(kinds, method_cursor) == TOKEN_DEF:
                        method_count = method_count + 1
                    method_cursor = method_cursor + 1
                return method_count
        token_index = token_index + 1
    return 0

def find_interface_method_function_index(source: str, kinds: list[int], starts: list[int], ends: list[int], interface_name: str, struct_name: str, method_name: str, function_starts: list[int], function_ends: list[int]) -> int:
    let interface_target_prefix = string_concat(interface_name, "_")
    let target_prefix = string_concat(interface_target_prefix, struct_name)
    let target_prefix_with_separator = string_concat(target_prefix, "_")
    let method_prefix_body = string_concat("__dir_impl_", target_prefix_with_separator)
    let function_index = 0
    while function_index < len(function_starts):
        let candidate_name = source[function_starts[function_index]:function_ends[function_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(source, kinds, starts, ends, function_starts[function_index])
            if candidate_prefix == method_prefix_body:
                return function_index
        function_index = function_index + 1
    return -1

def find_interface_declaration_function_index(source: str, kinds: list[int], starts: list[int], ends: list[int], method_name: str, function_starts: list[int], function_ends: list[int]) -> int:
    let function_index = 0
    while function_index < len(function_starts):
        let candidate_name = source[function_starts[function_index]:function_ends[function_index]]
        if candidate_name == method_name:
            let candidate_prefix = enclosing_method_prefix(source, kinds, starts, ends, function_starts[function_index])
            if text_length(candidate_prefix) == 0 and not function_has_body(source, kinds, starts, 0, 0, function_starts[function_index]):
                return function_index
        function_index = function_index + 1
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

def append_hoisted_function(records: list[int], function_records: list[int]):
    let alloca_record_kind = DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_ALLOCA
    let header_end = 0
    let cursor = 0
    let found_entry = false
    while cursor < len(function_records) and not found_entry:
        if function_records[cursor] == DIR_TAG_BLOCK:
            found_entry = true
        else:
            cursor = dir_next_record_index(function_records, cursor)
    header_end = cursor
    if header_end > len(function_records):
        header_end = len(function_records)
    let function_start = 0
    let find_cursor = 0
    let found_function = false
    while find_cursor < len(function_records) and not found_function:
        if function_records[find_cursor] == DIR_TAG_FUNCTION:
            found_function = true
        else:
            find_cursor = dir_next_record_index(function_records, find_cursor)
    let header_first_end = find_cursor
    # 新管线(lower)的 FUNCTION 记录含 "entry:" 文本;旧管线(emit)的 entry: 是独立 BLOCK
    let function_has_entry_text = false
    let payload_index = find_cursor + 5
    let payload_cursor = payload_index
    while payload_cursor < len(function_records) and function_records[payload_cursor] != 0:
        payload_cursor = payload_cursor + 1
    let payload_end = payload_cursor
    let text_index = payload_index
    while text_index + 6 <= payload_end and not function_has_entry_text:
        if function_records[text_index] == ord('e') and function_records[text_index + 1] == ord('n') and function_records[text_index + 2] == ord('t') and function_records[text_index + 3] == ord('r') and function_records[text_index + 4] == ord('y') and function_records[text_index + 5] == ord(':'):
            function_has_entry_text = true
        text_index = text_index + 1
    if not function_has_entry_text:
        # 旧管线:header 含第一个 BLOCK(entry:),提升的 alloca 插在其后
        let entry_block_end = dir_next_record_index(function_records, header_end)
        if entry_block_end > header_end:
            header_end = entry_block_end
    let allocas = []
    let body = []
    let body_cursor = header_end
    while body_cursor < len(function_records):
        let next_cursor = dir_next_record_index(function_records, body_cursor)
        let copy_end = next_cursor
        if copy_end > len(function_records):
            copy_end = len(function_records)
        let is_alloca = function_records[body_cursor] == alloca_record_kind
        let copy_index = body_cursor
        while copy_index < copy_end:
            if is_alloca:
                append(allocas, function_records[copy_index])
            else:
                append(body, function_records[copy_index])
            copy_index = copy_index + 1
        body_cursor = next_cursor
        if body_cursor > len(function_records):
            body_cursor = len(function_records)
    let header_first_cursor = 0
    while header_first_cursor < header_first_end:
        append(records, function_records[header_first_cursor])
        header_first_cursor = header_first_cursor + 1
    let function_end = dir_next_record_index(function_records, header_first_end)
    let function_cursor = header_first_end
    while function_cursor < function_end:
        append(records, function_records[function_cursor])
        function_cursor = function_cursor + 1
    let allocas_index = 0
    let merge_index = function_end
    if function_has_entry_text:
        while allocas_index < len(allocas):
            append(records, allocas[allocas_index])
            allocas_index = allocas_index + 1
    while merge_index < header_end:
        append(records, function_records[merge_index])
        merge_index = merge_index + 1
    while allocas_index < len(allocas):
        append(records, allocas[allocas_index])
        allocas_index = allocas_index + 1
    let body_index = 0
    while body_index < len(body):
        append(records, body[body_index])
        body_index = body_index + 1

def append_variable_name(output: list[int], name: str, variable_type: int):
    append_text(output, name)
    if is_closure_value_type(variable_type):
        append_text(output, ".closure")
    else:
        switch variable_type:
            case VALUE_TYPE_STRING:
                append_text(output, ".string")
            case VALUE_TYPE_LIST:
                append_text(output, ".list")
            case VALUE_TYPE_BYTES:
                append_text(output, ".list")
            case VALUE_TYPE_BOOL:
                append_text(output, ".bool")
            case VALUE_TYPE_FLOAT:
                append_text(output, ".float")
            case VALUE_TYPE_DICT_INT_INT:
                append_text(output, ".dict")
            case VALUE_TYPE_DICT_INT_STRING:
                append_text(output, ".dict")
            case VALUE_TYPE_DICT_STRING_INT:
                append_text(output, ".dict")
            case VALUE_TYPE_DICT_STRING_STRING:
                append_text(output, ".dict")
            case VALUE_TYPE_INTERFACE:
                append_text(output, ".interface")

def append_local_storage(output: list[int], name: str, variable_type: int):
    append_text(output, "%")
    append_variable_name(output, name, variable_type)
    if is_closure_value_type(variable_type):
        append_text(output, " = alloca %dir_closure*\n")
    else:
        switch variable_type:
            case VALUE_TYPE_STRING:
                append_text(output, " = alloca i8*\n")
            case VALUE_TYPE_LIST:
                append_text(output, " = alloca %dynarray_i32*\n")
            case VALUE_TYPE_BYTES:
                append_text(output, " = alloca %dynarray_i32*\n")
            case VALUE_TYPE_BOOL:
                append_text(output, " = alloca i1\n")
            case VALUE_TYPE_FLOAT:
                append_text(output, " = alloca double\n")
            case VALUE_TYPE_DICT_INT_INT:
                append_text(output, " = alloca %dict_t*\n")
            case VALUE_TYPE_DICT_INT_STRING:
                append_text(output, " = alloca %dict_t*\n")
            case VALUE_TYPE_DICT_STRING_INT:
                append_text(output, " = alloca %dict_t*\n")
            case VALUE_TYPE_DICT_STRING_STRING:
                append_text(output, " = alloca %dict_t*\n")
            case VALUE_TYPE_INTERFACE:
                append_text(output, " = alloca %dir_interface*\n")
            default:
                append_text(output, " = alloca i32\n")

def append_variable_reference(output: list[int], name: str, variable_type: int):
    if variable_type == VALUE_TYPE_GLOBAL:
        append_text(output, "@")
    if variable_type != VALUE_TYPE_GLOBAL:
        append_text(output, "%")
    append_variable_name(output, name, variable_type)

def parse_integer(source: str, start: int, end: int) -> int:
    let result = 0
    let index = start
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

def constant_is_used(source: str, kinds: list[int], starts: list[int], ends: list[int], body_start: int, body_end: int, constant_start: int, constant_end: int) -> bool:
    let token_index = body_start
    while token_index < body_end:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, token_index), token_end(ends, token_index), constant_start, constant_end):
            return true
        token_index = token_index + 1
    return false

def find_variable(source: str, name_start: int, name_end: int, variable_starts: list[int], variable_ends: list[int]) -> int:
    let result = -1
    let index = 0
    while index < len(variable_starts):
        if source_ranges_equal(source, name_start, name_end, variable_starts[index], variable_ends[index]):
            result = index
        index = index + 1
    return result

def find_function(source: str, name_start: int, name_end: int, function_starts: list[int], function_ends: list[int]) -> int:
    let result = -1
    let index = 0
    while index < len(function_starts):
        if source_ranges_equal(source, name_start, name_end, function_starts[index], function_ends[index]):
            result = index
        index = index + 1
    return result

let STRUCT_DECLARATION_STARTS = []
let STRUCT_DECLARATION_ENDS = []
let STRUCT_DECLARATION_HASHES = []
let STRUCT_DECLARATION_TOKENS = []
let INTERFACE_DECLARATION_STARTS = []
let INTERFACE_DECLARATION_ENDS = []

def collect_declared_types(source: str, kinds: list[int], starts: list[int], ends: list[int]):
    STRUCT_DECLARATION_STARTS = []
    STRUCT_DECLARATION_ENDS = []
    STRUCT_DECLARATION_HASHES = []
    STRUCT_DECLARATION_TOKENS = []
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
                    append(STRUCT_DECLARATION_HASHES, __c_fnv_hash_range(source, token_start(starts, declaration_name_index), token_end(ends, declaration_name_index)))
                    append(STRUCT_DECLARATION_TOKENS, declaration_name_index)
            if keyword_length == 9 and source_equals(source, keyword_start, keyword_end, "interface"):
                if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER:
                    append(INTERFACE_DECLARATION_STARTS, token_start(starts, declaration_name_index))
                    append(INTERFACE_DECLARATION_ENDS, token_end(ends, declaration_name_index))
        token_index = token_index + 1

def source_type_is_struct(source: str, kinds: list[int], starts: list[int], ends: list[int], type_start: int, type_end: int) -> bool:
    let declaration_index = 0
    while declaration_index < len(STRUCT_DECLARATION_STARTS):
        if source_ranges_equal(source, STRUCT_DECLARATION_STARTS[declaration_index], STRUCT_DECLARATION_ENDS[declaration_index], type_start, type_end):
            return true
        declaration_index = declaration_index + 1
    return false

def source_type_is_interface(source: str, kinds: list[int], starts: list[int], ends: list[int], type_start: int, type_end: int) -> bool:
    let declaration_index = 0
    while declaration_index < len(INTERFACE_DECLARATION_STARTS):
        if source_ranges_equal(source, INTERFACE_DECLARATION_STARTS[declaration_index], INTERFACE_DECLARATION_ENDS[declaration_index], type_start, type_end):
            return true
        declaration_index = declaration_index + 1
    return false

let TYPE_DICTIONARY = {
    "str": VALUE_TYPE_STRING,
    "list": VALUE_TYPE_LIST,
    "dict": VALUE_TYPE_DICT_INT_INT,
    "bytes": VALUE_TYPE_BYTES,
    "bool": VALUE_TYPE_BOOL,
    "float": VALUE_TYPE_FLOAT,
    "int": VALUE_TYPE_INT,
    "rune": VALUE_TYPE_INT,
    "byte": VALUE_TYPE_INT,
}

def parameter_type_from_range(source: str, kinds: list[int], starts: list[int], ends: list[int], type_start: int, type_end: int) -> int:
    let type_name = source[type_start:type_end]
    let found_type = TYPE_DICTIONARY[type_name]
    if found_type == 0:
        if source_type_is_interface(source, kinds, starts, ends, type_start, type_end):
            return VALUE_TYPE_INTERFACE
    return found_type

def get_parameter_type(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int) -> int:
    if token_kind(kinds, index) == TOKEN_OPEN_PAREN:
        return VALUE_TYPE_FUNCTION_PARAMETER
    if token_kind(kinds, index) != TOKEN_IDENTIFIER:
        return 0
    let parameter_type = parameter_type_from_range(source, kinds, starts, ends, token_start(starts, index), token_end(ends, index))
    if parameter_type == VALUE_TYPE_LIST and token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
        let element_index = index + 2
        if token_kind(kinds, element_index) == TOKEN_IDENTIFIER and source[token_start(starts, element_index):token_end(ends, element_index)] == "str":
            return VALUE_TYPE_LIST_STRING
    if parameter_type != 0:
        return parameter_type
    if source_type_is_struct(source, kinds, starts, ends, token_start(starts, index), token_end(ends, index)):
        return VALUE_TYPE_LIST
    if source_type_is_interface(source, kinds, starts, ends, token_start(starts, index), token_end(ends, index)):
        return VALUE_TYPE_INTERFACE
    return 0

def parameter_type_from_declaration(source: str, kinds: list[int], starts: list[int], ends: list[int], name_start: int, name_end: int) -> int:
    if source_equals(source, name_start, name_end, "self"):
        return VALUE_TYPE_LIST
    let source_length = text_length(source)
    let type_start = name_end
    while type_start < source_length and source[type_start] != ':':
        type_start = type_start + 1
    if type_start >= source_length:
        return 0
    type_start = type_start + 1
    while type_start < source_length and source[type_start] == ' ':
        type_start = type_start + 1
    let type_end = type_start
    while type_end < source_length and source[type_end] != ',' and source[type_end] != ')' and source[type_end] != '\n':
        type_end = type_end + 1
    while type_end > type_start and source[type_end - 1] == ' ':
        type_end = type_end - 1
    return parameter_type_from_range(source, kinds, starts, ends, type_start, type_end)

def get_return_type(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int) -> int:
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
        return 3
    if source_equals(source, type_start, type_end, "dict"):
        return VALUE_TYPE_DICT_INT_INT
    if source_equals(source, type_start, type_end, "bytes"):
        return VALUE_TYPE_BYTES
    if source_equals(source, type_start, type_end, "Option"):
        return 3
    if source_equals(source, type_start, type_end, "Result"):
        return 3
    if source_equals(source, type_start, type_end, "int") or source_equals(source, type_start, type_end, "rune") or source_equals(source, type_start, type_end, "byte"):
        return 1
    if source_type_is_struct(source, kinds, starts, ends, type_start, type_end):
        return VALUE_TYPE_LIST
    if source_type_is_interface(source, kinds, starts, ends, type_start, type_end):
        return VALUE_TYPE_INTERFACE
    return 1

def find_function_open_parenthesis(kinds: list[int], name_index: int) -> int:
    let current_index = name_index + 1
    while token_kind(kinds, current_index) != TOKEN_OPEN_PAREN and token_kind(kinds, current_index) != TOKEN_EOF and token_kind(kinds, current_index) != TOKEN_NEWLINE:
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

def function_parameter_type(source: str, kinds: list[int], starts: list[int], ends: list[int], name_start: int, name_end: int, parameter_number: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> int:
    let function_index = find_function(source, name_start, name_end, function_starts, function_ends)
    if function_index < 0:
        return 0
    if function_index >= len(function_param_counts):
        return 0
    if parameter_number < 0 or parameter_number >= function_param_counts[function_index]:
        return 0
    let parameter_index = function_param_offsets[function_index] + parameter_number
    if parameter_index < 0 or parameter_index >= len(parameter_starts) or parameter_index >= len(parameter_ends):
        return 0
    return parameter_type_from_declaration(source, kinds, starts, ends, parameter_starts[parameter_index], parameter_ends[parameter_index])

def collect_functions(source: str, kinds: list[int], starts: list[int], ends: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int], function_return_types: list[int], parameter_default_indexes: list[int]) -> int:
    let current_index = 0
    while token_kind(kinds, current_index) != TOKEN_EOF:
        let is_function_definition = false
        if token_kind(kinds, current_index) == TOKEN_DEF:
            is_function_definition = true
        if is_function_definition:
            let name_index = current_index + 1
            let open_index = find_function_open_parenthesis(kinds, name_index)
            append(function_starts, token_start(starts, name_index))
            append(function_ends, token_end(ends, name_index))
            append(function_param_offsets, len(parameter_starts))
            let parameter_index = open_index + 1
            let parameter_count = 0
            while token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
                let is_parameter = false
                if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER:
                    is_parameter = true
                if is_parameter:
                    append(parameter_starts, token_start(starts, parameter_index))
                    append(parameter_ends, token_end(ends, parameter_index))
                    let parameter_type_index = parameter_index + 2
                    let collected_parameter_type = get_parameter_type(source, kinds, starts, ends, parameter_type_index)
                    if source[token_start(starts, parameter_index):token_end(ends, parameter_index)] == "self":
                        collected_parameter_type = VALUE_TYPE_LIST
                    append(parameter_types, collected_parameter_type)
                    let default_index = -1
                    let default_scan_index = parameter_index + 1
                    let default_depth = 0
                    let default_scan_done = false
                    while token_kind(kinds, default_scan_index) != TOKEN_COMMA and token_kind(kinds, default_scan_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, default_scan_index) != TOKEN_EOF and not default_scan_done:
                        if token_kind(kinds, default_scan_index) == TOKEN_OPEN_BRACKET or token_kind(kinds, default_scan_index) == TOKEN_OPEN_PAREN or token_kind(kinds, default_scan_index) == TOKEN_OPEN_BRACE:
                            default_depth = default_depth + 1
                        if token_kind(kinds, default_scan_index) == TOKEN_CLOSE_BRACKET or token_kind(kinds, default_scan_index) == TOKEN_CLOSE_PAREN or token_kind(kinds, default_scan_index) == TOKEN_CLOSE_BRACE:
                            if default_depth > 0:
                                default_depth = default_depth - 1
                        if default_depth == 0 and token_kind(kinds, default_scan_index) == TOKEN_ASSIGN:
                            default_index = default_scan_index + 1
                            default_scan_done = true
                        default_scan_index = default_scan_index + 1
                    append(parameter_default_indexes, default_index)
                    parameter_count = parameter_count + 1
                    let parameter_boundary = find_parameter_boundary(kinds, parameter_index)
                    parameter_index = parameter_boundary
                    if token_kind(kinds, parameter_index) == TOKEN_COMMA:
                        parameter_index = parameter_index + 1
                if not is_parameter:
                    parameter_index = parameter_index + 1
            append(function_param_counts, parameter_count)
            let header_index = parameter_index
            let function_return_type = 1
            let return_type_scan_index = header_index + 1
            while token_kind(kinds, return_type_scan_index) != TOKEN_NEWLINE and token_kind(kinds, return_type_scan_index) != TOKEN_EOF:
                if token_kind(kinds, return_type_scan_index) == TOKEN_ARROW:
                    function_return_type = get_return_type(source, kinds, starts, ends, return_type_scan_index + 1)
                return_type_scan_index = return_type_scan_index + 1
            append(function_return_types, function_return_type)
            while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
                header_index = header_index + 1
            let body_index = header_index + 1
            let body_end = body_index
            let found_body_boundary = false
            while token_kind(kinds, body_end) != TOKEN_EOF and not found_body_boundary:
                let is_top_level_boundary = false
                if token_kind(kinds, body_end) == TOKEN_DEF:
                    is_top_level_boundary = true
                if token_kind(kinds, body_end) != TOKEN_NEWLINE and line_indent(source, token_start(starts, body_end)) == 0:
                    is_top_level_boundary = true
                if is_top_level_boundary:
                    found_body_boundary = true
                if not is_top_level_boundary:
                    body_end = body_end + 1
            append(function_bodies, body_index)
            append(function_body_ends, body_end)
            current_index = body_end
        if not is_function_definition:
            current_index = current_index + 1
    return len(function_starts)

def find_constant_index(source: str, constant_starts: list[int], constant_ends: list[int], name_start: int, name_end: int) -> int:
    let constant_index = 0
    while constant_index < len(constant_starts):
        if source_ranges_equal(source, constant_starts[constant_index], constant_ends[constant_index], name_start, name_end):
            return constant_index
        constant_index = constant_index + 1
    return -1

def collect_constants(source: str, kinds: list[int], starts: list[int], ends: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]) -> int:
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
            if token_kind(kinds, value_index) == TOKEN_INTEGER:
                has_constant_value = true
                constant_value = parse_integer(source, token_start(starts, value_index), token_end(ends, value_index))
                constant_type = 1
            if token_kind(kinds, value_index) == TOKEN_IDENTIFIER:
                let referenced_index = find_constant_index(source, constant_starts, constant_ends, token_start(starts, value_index), token_end(ends, value_index))
                if referenced_index >= 0:
                    has_constant_value = true
                    constant_value = constant_values[referenced_index]
                    constant_type = constant_types[referenced_index]
            if has_constant_value:
                append(constant_starts, token_start(starts, name_index))
                append(constant_ends, token_end(ends, name_index))
                append(constant_values, constant_value)
                append(constant_types, constant_type)
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

def append_llvm_type_text(output: list[int], value_type: int):
    if value_type == VALUE_TYPE_STRING:
        append_text(output, "i8*")
    if value_type == VALUE_TYPE_FLOAT:
        append_text(output, "double")
    if value_type == VALUE_TYPE_BOOL:
        append_text(output, "i1")
    if value_type == VALUE_TYPE_LIST:
        append_text(output, "%dynarray_i32*")
    if value_type == VALUE_TYPE_DICT_INT_INT or value_type == VALUE_TYPE_DICT_INT_STRING or value_type == VALUE_TYPE_DICT_STRING_INT or value_type == VALUE_TYPE_DICT_STRING_STRING:
        append_text(output, "%dict_t*")
    if value_type == VALUE_TYPE_INT or value_type == VALUE_TYPE_IMMEDIATE or value_type == VALUE_TYPE_UNKNOWN:
        append_text(output, "i32")

def parse_global_let_annotation(source: str, kinds: list[int], starts: list[int], ends: list[int], type_index: int) -> int:
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
    return VALUE_TYPE_UNKNOWN

def collect_global_lets(source: str, kinds: list[int], starts: list[int], ends: list[int], global_let_name_starts: list[int], global_let_name_ends: list[int], global_let_types: list[int], global_let_expression_indexes: list[int]) -> int:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_LET and line_indent(source, token_start(starts, token_index)) == 0 and token_kind(kinds, token_index + 1) == TOKEN_IDENTIFIER:
            let name_index = token_index + 1
            let name_start = token_start(starts, name_index)
            let name_end = token_end(ends, name_index)
            let value_type = VALUE_TYPE_UNKNOWN
            let assignment_index = token_index + 2
            if token_kind(kinds, token_index + 2) == TOKEN_COLON:
                value_type = parse_global_let_annotation(source, kinds, starts, ends, token_index + 3)
                assignment_index = token_index + 4
            while token_kind(kinds, assignment_index) != TOKEN_ASSIGN and token_kind(kinds, assignment_index) != TOKEN_NEWLINE and token_kind(kinds, assignment_index) != TOKEN_EOF:
                assignment_index = assignment_index + 1
            if token_kind(kinds, assignment_index) == TOKEN_ASSIGN:
                let expression_index = assignment_index + 1
                if value_type == VALUE_TYPE_UNKNOWN:
                    if token_kind(kinds, expression_index) == TOKEN_OPEN_BRACKET:
                        value_type = VALUE_TYPE_LIST
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
                    if token_kind(kinds, expression_index) == TOKEN_STRING:
                        value_type = VALUE_TYPE_STRING
                    if token_kind(kinds, expression_index) == TOKEN_FLOAT:
                        value_type = VALUE_TYPE_FLOAT
                    if token_kind(kinds, expression_index) == TOKEN_TRUE or token_kind(kinds, expression_index) == TOKEN_FALSE:
                        value_type = VALUE_TYPE_BOOL
                append(global_let_name_starts, name_start)
                append(global_let_name_ends, name_end)
                append(global_let_types, value_type)
                append(global_let_expression_indexes, expression_index)
                token_index = assignment_index
        token_index = token_index + 1
    return len(global_let_name_starts)

def function_parameter_default(name_start: int, name_end: int, parameter_number: int, context: ParseContext) -> int:
    let function_index = find_function(context.src, name_start, name_end, context.fn_starts, context.fn_ends)
    if function_index < 0:
        return -1
    if function_index >= len(context.param_counts):
        return -1
    if parameter_number < 0 or parameter_number >= context.param_counts[function_index]:
        return -1
    let parameter_index = context.param_offsets[function_index] + parameter_number
    if parameter_index < 0 or parameter_index >= len(context.pd):
        return -1
    return context.pd[parameter_index]

def function_parameter_count(name_start: int, name_end: int, context: ParseContext) -> int:
    let function_index = find_function(context.src, name_start, name_end, context.fn_starts, context.fn_ends)
    if function_index < 0:
        return -1
    if function_index >= len(context.param_counts):
        return -1
    return context.param_counts[function_index]
