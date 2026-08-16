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
const VALUE_TYPE_FUNCTION_BASE: int = 100
const VALUE_TYPE_LAMBDA_BASE: int = 1000000

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
const ASCII_LOWER_Z: int = 122
const ASCII_BACKSLASH: int = 92
const ASCII_UNDERSCORE: int = 95

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
    if value_type == VALUE_TYPE_BOOL:
        return true
    if value_type >= VALUE_TYPE_DICT_INT_INT and value_type <= VALUE_TYPE_DICT_STRING_STRING:
        return true
    if value_type == VALUE_TYPE_FLOAT:
        return true
    return false

def is_dictionary_value_type(value_type: int) -> bool:
    if value_type < VALUE_TYPE_DICT_INT_INT:
        return false
    if value_type > VALUE_TYPE_DICT_STRING_STRING:
        return false
    return true

def is_function_value_type(value_type: int) -> bool:
    return value_type >= VALUE_TYPE_FUNCTION_BASE

def function_value_index(value_type: int) -> int:
    return value_type - VALUE_TYPE_FUNCTION_BASE

def is_lambda_value_type(value_type: int) -> bool:
    return value_type >= VALUE_TYPE_LAMBDA_BASE

def lambda_value_index(value_type: int) -> int:
    return value_type - VALUE_TYPE_LAMBDA_BASE

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
        length = length + 1
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
            let is_handled_escape = false
            if escaped_code == ord('n'):
                append_text(output, "\\0A")
                is_handled_escape = true
            if escaped_code == ord('t'):
                append_text(output, "\\09")
                is_handled_escape = true
            if escaped_code == ord('r'):
                append_text(output, "\\0D")
                is_handled_escape = true
            if escaped_code == ASCII_DIGIT_ZERO:
                append_text(output, "\\00")
                is_handled_escape = true
            if escaped_code == ASCII_BACKSLASH:
                append_text(output, "\\5C")
                is_handled_escape = true
            if escaped_code == ASCII_DOUBLE_QUOTE:
                append_text(output, "\\22")
                is_handled_escape = true
            if not is_handled_escape:
                append(output, escaped_code)
            index = index + 2
        if not is_escape:
            let is_handled_code = false
            if code == ASCII_LINE_FEED:
                append_text(output, "\\0A")
                is_handled_code = true
            if code == ASCII_CARRIAGE_RETURN:
                append_text(output, "\\0D")
                is_handled_code = true
            if code == ASCII_DOUBLE_QUOTE:
                append_text(output, "\\22")
                is_handled_code = true
            if code == ASCII_BACKSLASH:
                append_text(output, "\\5C")
                is_handled_code = true
            if not is_handled_code:
                append(output, code)
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

def keyword_kind(source: str, start: int, end: int) -> int:
    let word = source[start:end]
    if word == "let":
        return TOKEN_LET
    if word == "print":
        return TOKEN_PRINT
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
    if word == "for":
        return TOKEN_FOR
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
    return 2

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
                case 43:
                    append_token(kinds, starts, ends, TOKEN_PLUS, index, index + 1)
                    index = index + 1
                case 45:
                    let is_arrow = false
                    if index + 1 < source_length and source[index + 1] == '>':
                        is_arrow = true
                    if is_arrow:
                        append_token(kinds, starts, ends, TOKEN_ARROW, index, index + 2)
                        index = index + 2
                    if not is_arrow:
                        append_token(kinds, starts, ends, TOKEN_MINUS, index, index + 1)
                        index = index + 1
                case 42:
                    append_token(kinds, starts, ends, TOKEN_MULTIPLY, index, index + 1)
                    index = index + 1
                case 47:
                    append_token(kinds, starts, ends, TOKEN_DIVIDE, index, index + 1)
                    index = index + 1
                case 40:
                    append_token(kinds, starts, ends, TOKEN_OPEN_PAREN, index, index + 1)
                    index = index + 1
                case 41:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_PAREN, index, index + 1)
                    index = index + 1
                case 91:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACKET, index, index + 1)
                    index = index + 1
                case 93:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACKET, index, index + 1)
                    index = index + 1
                case 123:
                    append_token(kinds, starts, ends, TOKEN_OPEN_BRACE, index, index + 1)
                    index = index + 1
                case 125:
                    append_token(kinds, starts, ends, TOKEN_CLOSE_BRACE, index, index + 1)
                    index = index + 1
                case 46:
                    append_token(kinds, starts, ends, TOKEN_DOT, index, index + 1)
                    index = index + 1
                case 61:
                    let is_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_equal = true
                    if is_equal:
                        append_token(kinds, starts, ends, TOKEN_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_equal:
                        append_token(kinds, starts, ends, TOKEN_ASSIGN, index, index + 1)
                        index = index + 1
                case 58:
                    let is_cons = false
                    if index + 1 < source_length and source[index + 1] == ':':
                        is_cons = true
                    if is_cons:
                        append_token(kinds, starts, ends, TOKEN_CONS, index, index + 2)
                        index = index + 2
                    if not is_cons:
                        append_token(kinds, starts, ends, TOKEN_COLON, index, index + 1)
                        index = index + 1
                case 44:
                    append_token(kinds, starts, ends, TOKEN_COMMA, index, index + 1)
                    index = index + 1
                case 60:
                    let is_less_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_less_equal = true
                    if is_less_equal:
                        append_token(kinds, starts, ends, TOKEN_LESS_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_less_equal:
                        append_token(kinds, starts, ends, TOKEN_LESS, index, index + 1)
                        index = index + 1
                case 62:
                    let is_greater_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_greater_equal = true
                    if is_greater_equal:
                        append_token(kinds, starts, ends, TOKEN_GREATER_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_greater_equal:
                        append_token(kinds, starts, ends, TOKEN_GREATER, index, index + 1)
                        index = index + 1
                case 33:
                    let is_not_equal = false
                    if index + 1 < source_length and source[index + 1] == '=':
                        is_not_equal = true
                    if is_not_equal:
                        append_token(kinds, starts, ends, TOKEN_NOT_EQUAL, index, index + 2)
                        index = index + 2
                    if not is_not_equal:
                        index = index + 1
                case 37:
                    append_token(kinds, starts, ends, TOKEN_MODULO, index, index + 1)
                    index = index + 1
                case 63:
                    append_token(kinds, starts, ends, TOKEN_QUESTION, index, index + 1)
                    index = index + 1
                default:
                    index = index + 1

    append_token(kinds, starts, ends, TOKEN_EOF, source_length, source_length)
    return len(kinds)

def token_kind(kinds: list[int], index: int) -> int:
    if index < 0 or index >= len(kinds):
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

def append_code_range(output: list[int], source: list[int], start: int, end: int):
    let index = start
    while index < end:
        append(output, source[index])
        index = index + 1

def line_has_alloca(source: list[int], start: int, end: int) -> bool:
    let marker = " = alloca "
    let marker_length = text_length(marker)
    let index = start
    while index + marker_length <= end:
        let marker_index = 0
        let is_match = true
        while marker_index < marker_length:
            if source[index + marker_index] != ord(marker[marker_index]):
                is_match = false
            marker_index = marker_index + 1
        if is_match:
            return true
        index = index + 1
    return false

def line_is_entry(source: list[int], start: int, end: int) -> bool:
    let marker = "entry:"
    let marker_length = text_length(marker)
    if end - start < marker_length:
        return false
    let index = 0
    while index < marker_length:
        if source[start + index] != ord(marker[index]):
            return false
        index = index + 1
    return true

def append_hoisted_function(output: list[int], function_output: list[int]):
    let header = []
    let allocas = []
    let body = []
    let line_start = 0
    let has_entry = false
    while line_start < len(function_output):
        let current_line_start = line_start
        let line_end = current_line_start
        let has_line_end = false
        while line_end < len(function_output) and not has_line_end:
            if function_output[line_end] == ASCII_LINE_FEED:
                has_line_end = true
            if function_output[line_end] != ASCII_LINE_FEED:
                line_end = line_end + 1
        let next_line_start = line_end
        if next_line_start < len(function_output):
            next_line_start = next_line_start + 1
        line_start = next_line_start
        let has_alloca = line_has_alloca(function_output, current_line_start, line_end)
        if has_alloca:
            append_code_range(allocas, function_output, current_line_start, next_line_start)
        if not has_alloca:
            let was_header = false
            if not has_entry:
                append_code_range(header, function_output, current_line_start, next_line_start)
                was_header = true
                if line_is_entry(function_output, current_line_start, line_end):
                    has_entry = true
            if not was_header:
                append_code_range(body, function_output, current_line_start, next_line_start)
    append_code_range(output, header, 0, len(header))
    append_code_range(output, allocas, 0, len(allocas))
    append_code_range(output, body, 0, len(body))

def append_local_storage(output: list[int], name: str, variable_type: int):
    append_text(output, "%")
    append_text(output, name)
    if variable_type == VALUE_TYPE_STRING:
        append_text(output, " = alloca i8*\n")
    if variable_type == VALUE_TYPE_LIST:
        append_text(output, " = alloca %dynarray_i32*\n")
    if variable_type == VALUE_TYPE_BOOL:
        append_text(output, " = alloca i1\n")
    if variable_type == VALUE_TYPE_FLOAT:
        append_text(output, " = alloca double\n")
    if is_dictionary_value_type(variable_type):
        append_text(output, " = alloca %dict_t*\n")
    if variable_type != VALUE_TYPE_STRING and variable_type != VALUE_TYPE_LIST and variable_type != VALUE_TYPE_BOOL and not is_dictionary_value_type(variable_type) and variable_type != VALUE_TYPE_FLOAT:
        append_text(output, " = alloca i32\n")

def append_variable_reference(output: list[int], name: str, variable_type: int):
    if variable_type == VALUE_TYPE_GLOBAL:
        append_text(output, "@")
    if variable_type != VALUE_TYPE_GLOBAL:
        append_text(output, "%")
    append_text(output, name)

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
    let expected_length = text_length(expected)
    if end - start != expected_length:
        return false
    let index = 0
    while index < expected_length:
        if ord(source[start + index]) != ord(expected[index]):
            return false
        index = index + 1
    return true

def source_ranges_equal(source: str, first_start: int, first_end: int, second_start: int, second_end: int) -> bool:
    let first_length = first_end - first_start
    let second_length = second_end - second_start
    if first_length != second_length:
        return false
    let index = 0
    while index < first_length:
        let first_code = ord(source[first_start + index])
        let second_code = ord(source[second_start + index])
        if first_code != second_code:
            return false
        index = index + 1
    return true

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

def get_parameter_type(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int) -> int:
    if token_kind(kinds, index) != TOKEN_IDENTIFIER:
        return 0
    if source_equals(source, token_start(starts, index), token_end(ends, index), "str"):
        return 2
    if source_equals(source, token_start(starts, index), token_end(ends, index), "list"):
        return 3
    if source_equals(source, token_start(starts, index), token_end(ends, index), "bool"):
        return 4
    if source_equals(source, token_start(starts, index), token_end(ends, index), "float"):
        return 10
    return 0

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
    if source_equals(source, type_start, type_end, "Option"):
        return 3
    if source_equals(source, type_start, type_end, "Result"):
        return 3
    return 1

def function_parameter_type(source: str, kinds: list[int], starts: list[int], ends: list[int], name_start: int, name_end: int, parameter_number: int) -> int:
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_DEF and token_kind(kinds, token_index + 1) == TOKEN_IDENTIFIER:
            let function_name_start = token_start(starts, token_index + 1)
            let function_name_end = token_end(ends, token_index + 1)
            if source_ranges_equal(source, function_name_start, function_name_end, name_start, name_end):
                let parameter_index = token_index + 3
                let current_parameter_number = 0
                while token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
                    if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER:
                        if current_parameter_number == parameter_number:
                            return get_parameter_type(source, kinds, starts, ends, parameter_index + 2)
                        current_parameter_number = current_parameter_number + 1
                    parameter_index = parameter_index + 1
        token_index = token_index + 1
    return 0

def collect_functions(source: str, kinds: list[int], starts: list[int], ends: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int], function_return_types: list[int]) -> int:
    let current_index = 0
    while token_kind(kinds, current_index) != TOKEN_EOF:
        let is_function_definition = false
        if token_kind(kinds, current_index) == TOKEN_DEF:
            is_function_definition = true
        if is_function_definition:
            let name_index = current_index + 1
            let open_index = current_index + 2
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
                    append(parameter_types, get_parameter_type(source, kinds, starts, ends, parameter_type_index))
                    parameter_count = parameter_count + 1
                    while token_kind(kinds, parameter_index) != TOKEN_COMMA and token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
                        parameter_index = parameter_index + 1
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
