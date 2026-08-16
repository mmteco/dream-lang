from bootstrap_io import read_text_file, text_char_code, text_length, write_text_codes

def is_digit(code: int) -> bool:
    return code >= 48 and code <= 57

def is_identifier_start(code: int) -> bool:
    return code >= 65 and code <= 90 or code >= 97 and code <= 122 or code == 95

def is_identifier_continue(code: int) -> bool:
    return is_identifier_start(code) or is_digit(code)

def append_text(output: list[int], text: str):
    let index = 0
    while index < text_length(text):
        append(output, text_char_code(text, index))
        index = index + 1

def append_integer(output: list[int], value: int):
    let number = value
    if number < 0:
        append(output, 45)
        number = 0 - number

    if number == 0:
        append(output, 48)
    if number != 0:
        let divisor = 1
        while divisor <= number / 10:
            divisor = divisor * 10

        while divisor > 0:
            let digit = number / divisor % 10
            append(output, 48 + digit)
            divisor = divisor / 10

def append_operand(output: list[int], is_temporary: int, value: int):
    if is_temporary == 1 or is_temporary == 2 or is_temporary == 3:
        append_text(output, "%t")
        append_integer(output, value)
    if is_temporary != 1 and is_temporary != 2 and is_temporary != 3:
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
        let is_escape = 0
        if text_char_code(source, index) == 92:
            if index + 1 < end:
                is_escape = 1
        if is_escape == 1:
            index = index + 2
        if is_escape == 0:
            index = index + 1
        length = length + 1
    return length + 1

def append_string_contents(output: list[int], source: str, start: int, end: int):
    let index = start
    while index < end:
        let code = text_char_code(source, index)
        let is_escape = 0
        if code == 92:
            if index + 1 < end:
                is_escape = 1
        if is_escape == 1:
            let escaped_code = text_char_code(source, index + 1)
            let is_handled_escape = 0
            if escaped_code == 110:
                append_text(output, "\\0A")
                is_handled_escape = 1
            if escaped_code == 116:
                append_text(output, "\\09")
                is_handled_escape = 1
            if escaped_code == 114:
                append_text(output, "\\0D")
                is_handled_escape = 1
            if escaped_code == 48:
                append_text(output, "\\00")
                is_handled_escape = 1
            if escaped_code == 92:
                append_text(output, "\\5C")
                is_handled_escape = 1
            if escaped_code == 34:
                append_text(output, "\\22")
                is_handled_escape = 1
            if is_handled_escape == 0:
                append(output, escaped_code)
            index = index + 2
        if is_escape == 0:
            let is_handled_code = 0
            if code == 10:
                append_text(output, "\\0A")
                is_handled_code = 1
            if code == 13:
                append_text(output, "\\0D")
                is_handled_code = 1
            if code == 34:
                append_text(output, "\\22")
                is_handled_code = 1
            if code == 92:
                append_text(output, "\\5C")
                is_handled_code = 1
            if is_handled_code == 0:
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
    append_text(output, "%t")
    append_integer(output, temporary_counter)
    append_text(output, " = getelementptr [")
    append_integer(output, string_length)
    append_text(output, " x i8], [")
    append_integer(output, string_length)
    append_text(output, " x i8]* @.str")
    append_integer(output, token_index)
    append_text(output, ", i32 0, i32 0\n")

def append_token(kinds: list[int], starts: list[int], ends: list[int], kind: int, start: int, end: int):
    append(kinds, kind)
    append(starts, start)
    append(ends, end)

def keyword_kind(source: str, start: int, end: int) -> int:
    let word = source[start:end]
    if word == "let":
        return 3
    if word == "print":
        return 4
    if word == "def":
        return 13
    if word == "return":
        return 14
    if word == "if":
        return 19
    if word == "elif":
        return 20
    if word == "else":
        return 21
    if word == "while":
        return 22
    if word == "switch":
        return 23
    if word == "case":
        return 24
    if word == "default":
        return 25
    if word == "and":
        return 34
    if word == "or":
        return 35
    return 2

def lex(source: str, kinds: list[int], starts: list[int], ends: list[int]) -> int:
    let index = 0
    let source_length = text_length(source)
    while index < source_length:
        let code = text_char_code(source, index)
        let handled = 0
        if code == 32 or code == 9 or code == 13:
            index = index + 1
            handled = 1
        if handled == 0 and code == 10:
            append_token(kinds, starts, ends, 12, index, index + 1)
            index = index + 1
            handled = 1
        if handled == 0 and code == 35:
            while index < source_length and text_char_code(source, index) != 10:
                index = index + 1
            handled = 1
        if handled == 0 and is_digit(code):
            let number_start = index
            while index < source_length and is_digit(text_char_code(source, index)):
                index = index + 1
            append_token(kinds, starts, ends, 1, number_start, index)
            handled = 1
        if handled == 0 and is_identifier_start(code):
            let identifier_start = index
            while index < source_length and is_identifier_continue(text_char_code(source, index)):
                index = index + 1
            append_token(kinds, starts, ends, keyword_kind(source, identifier_start, index), identifier_start, index)
            handled = 1
        if handled == 0 and code == 34:
            let string_start = index + 1
            index = index + 1
            while index < source_length and text_char_code(source, index) != 34:
                let step = 1
                if text_char_code(source, index) == 92 and index + 1 < source_length:
                    step = 2
                index = index + step
            append_token(kinds, starts, ends, 26, string_start, index)
            let closing_step = 0
            if index < source_length:
                closing_step = 1
            index = index + closing_step
            handled = 1
        if handled == 0:
            switch code:
                case 43:
                    append_token(kinds, starts, ends, 5, index, index + 1)
                    index = index + 1
                case 45:
                    let is_arrow = 0
                    if index + 1 < source_length and text_char_code(source, index + 1) == 62:
                        is_arrow = 1
                    if is_arrow == 1:
                        append_token(kinds, starts, ends, 17, index, index + 2)
                        index = index + 2
                    if is_arrow == 0:
                        append_token(kinds, starts, ends, 6, index, index + 1)
                        index = index + 1
                case 42:
                    append_token(kinds, starts, ends, 7, index, index + 1)
                    index = index + 1
                case 47:
                    append_token(kinds, starts, ends, 8, index, index + 1)
                    index = index + 1
                case 40:
                    append_token(kinds, starts, ends, 9, index, index + 1)
                    index = index + 1
                case 41:
                    append_token(kinds, starts, ends, 10, index, index + 1)
                    index = index + 1
                case 91:
                    append_token(kinds, starts, ends, 27, index, index + 1)
                    index = index + 1
                case 93:
                    append_token(kinds, starts, ends, 28, index, index + 1)
                    index = index + 1
                case 61:
                    let is_equal = 0
                    if index + 1 < source_length and text_char_code(source, index + 1) == 61:
                        is_equal = 1
                    if is_equal == 1:
                        append_token(kinds, starts, ends, 29, index, index + 2)
                        index = index + 2
                    if is_equal == 0:
                        append_token(kinds, starts, ends, 11, index, index + 1)
                        index = index + 1
                case 58:
                    append_token(kinds, starts, ends, 15, index, index + 1)
                    index = index + 1
                case 44:
                    append_token(kinds, starts, ends, 16, index, index + 1)
                    index = index + 1
                case 60:
                    let is_less_equal = 0
                    if index + 1 < source_length and text_char_code(source, index + 1) == 61:
                        is_less_equal = 1
                    if is_less_equal == 1:
                        append_token(kinds, starts, ends, 31, index, index + 2)
                        index = index + 2
                    if is_less_equal == 0:
                        append_token(kinds, starts, ends, 18, index, index + 1)
                        index = index + 1
                case 62:
                    let is_greater_equal = 0
                    if index + 1 < source_length and text_char_code(source, index + 1) == 61:
                        is_greater_equal = 1
                    if is_greater_equal == 1:
                        append_token(kinds, starts, ends, 32, index, index + 2)
                        index = index + 2
                    if is_greater_equal == 0:
                        append_token(kinds, starts, ends, 33, index, index + 1)
                        index = index + 1
                case 33:
                    let is_not_equal = 0
                    if index + 1 < source_length and text_char_code(source, index + 1) == 61:
                        is_not_equal = 1
                    if is_not_equal == 1:
                        append_token(kinds, starts, ends, 30, index, index + 2)
                        index = index + 2
                    if is_not_equal == 0:
                        index = index + 1
                case 37:
                    append_token(kinds, starts, ends, 36, index, index + 1)
                    index = index + 1
                default:
                    index = index + 1

    append_token(kinds, starts, ends, 0, source_length, source_length)
    return len(kinds)

def token_kind(kinds: list[int], index: int) -> int:
    if index < 0 or index >= len(kinds):
        return 0
    return kinds[index]

def line_indent(source: str, position: int) -> int:
    let line_start = position - 1
    while line_start >= 0 and text_char_code(source, line_start) != 10:
        line_start = line_start - 1
    let current_position = line_start + 1
    let result = 0
    while current_position < position and text_char_code(source, current_position) == 32:
        result = result + 1
        current_position = current_position + 1
    return result

def is_body_line(source: str, kinds: list[int], starts: list[int], index: int, body_indent: int) -> int:
    let result = 0
    if token_kind(kinds, index) == 12:
        result = 1
    if line_indent(source, token_start(starts, index)) >= body_indent:
        result = 1
    return result

def skip_newlines(kinds: list[int], index: int) -> int:
    let result = index
    while token_kind(kinds, result) == 12:
        result = result + 1
    return result

def skip_source_newlines(source: str, starts: list[int], index: int) -> int:
    let result = index
    while result < len(starts) and text_char_code(source, token_start(starts, result)) == 10:
        result = result + 1
    return result

def append_code_range(output: list[int], source: list[int], start: int, end: int):
    let index = start
    while index < end:
        append(output, source[index])
        index = index + 1

def line_has_alloca(source: list[int], start: int, end: int) -> int:
    let marker = " = alloca "
    let marker_length = text_length(marker)
    let index = start
    while index + marker_length <= end:
        let marker_index = 0
        let is_match = 1
        while marker_index < marker_length:
            if source[index + marker_index] != text_char_code(marker, marker_index):
                is_match = 0
            marker_index = marker_index + 1
        if is_match == 1:
            return 1
        index = index + 1
    return 0

def line_is_entry(source: list[int], start: int, end: int) -> int:
    let marker = "entry:"
    let marker_length = text_length(marker)
    if end - start < marker_length:
        return 0
    let index = 0
    while index < marker_length:
        if source[start + index] != text_char_code(marker, index):
            return 0
        index = index + 1
    return 1

def append_hoisted_function(output: list[int], function_output: list[int]):
    let header = []
    let allocas = []
    let body = []
    let line_start = 0
    let has_entry = 0
    while line_start < len(function_output):
        let current_line_start = line_start
        let line_end = current_line_start
        while line_end < len(function_output) and function_output[line_end] != 10:
            line_end = line_end + 1
        let next_line_start = line_end
        if next_line_start < len(function_output):
            next_line_start = next_line_start + 1
        line_start = next_line_start
        let has_alloca = line_has_alloca(function_output, current_line_start, line_end)
        if has_alloca == 1:
            append_code_range(allocas, function_output, current_line_start, next_line_start)
        if has_alloca == 0:
            let was_header = 0
            if has_entry == 0:
                append_code_range(header, function_output, current_line_start, next_line_start)
                was_header = 1
                if line_is_entry(function_output, current_line_start, line_end) == 1:
                    has_entry = 1
            if was_header == 0:
                append_code_range(body, function_output, current_line_start, next_line_start)
    append_code_range(output, header, 0, len(header))
    append_code_range(output, allocas, 0, len(allocas))
    append_code_range(output, body, 0, len(body))

def append_local_storage(output: list[int], name: str, variable_type: int):
    append_text(output, "%")
    append_text(output, name)
    if variable_type == 2:
        append_text(output, " = alloca i8*\n")
    if variable_type == 3:
        append_text(output, " = alloca %dynarray_i32*\n")
    if variable_type != 2 and variable_type != 3:
        append_text(output, " = alloca i32\n")

def parse_integer(source: str, start: int, end: int) -> int:
    let result = 0
    let index = start
    while index < end:
        result = result * 10 + text_char_code(source, index) - 48
        index = index + 1
    return result

def source_equals(source: str, start: int, end: int, expected: str) -> bool:
    let expected_length = text_length(expected)
    if end - start != expected_length:
        return start < end and start > end
    let index = 0
    while index < expected_length:
        if text_char_code(source, start + index) != text_char_code(expected, index):
            return start < end and start > end
        index = index + 1
    return start == start

def source_ranges_equal(source: str, first_start: int, first_end: int, second_start: int, second_end: int) -> bool:
    let result = 1
    let first_length = first_end - first_start
    let second_length = second_end - second_start
    if first_length != second_length:
        result = 0
    let index = 0
    while index < first_length:
        if result == 1:
            let first_code = text_char_code(source, first_start + index)
            let second_code = text_char_code(source, second_start + index)
            if first_code != second_code:
                result = 0
        index = index + 1
    return result == 1

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
    if token_kind(kinds, index) != 2:
        return 0
    if source_equals(source, token_start(starts, index), token_end(ends, index), "str"):
        return 2
    if source_equals(source, token_start(starts, index), token_end(ends, index), "list"):
        return 3
    return 0

def collect_functions(source: str, kinds: list[int], starts: list[int], ends: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int]) -> int:
    let current_index = 0
    while token_kind(kinds, current_index) != 0:
        let is_function_definition = 0
        if token_kind(kinds, current_index) == 13:
            is_function_definition = 1
        if is_function_definition == 1:
            let name_index = current_index + 1
            let open_index = current_index + 2
            append(function_starts, token_start(starts, name_index))
            append(function_ends, token_end(ends, name_index))
            append(function_param_offsets, len(parameter_starts))
            let parameter_index = open_index + 1
            let parameter_count = 0
            while token_kind(kinds, parameter_index) != 10 and token_kind(kinds, parameter_index) != 0:
                let is_parameter = 0
                if token_kind(kinds, parameter_index) == 2:
                    is_parameter = 1
                if is_parameter == 1:
                    append(parameter_starts, token_start(starts, parameter_index))
                    append(parameter_ends, token_end(ends, parameter_index))
                    let parameter_type_index = parameter_index + 2
                    append(parameter_types, get_parameter_type(source, kinds, starts, ends, parameter_type_index))
                    parameter_count = parameter_count + 1
                    while token_kind(kinds, parameter_index) != 16 and token_kind(kinds, parameter_index) != 10 and token_kind(kinds, parameter_index) != 0:
                        parameter_index = parameter_index + 1
                    if token_kind(kinds, parameter_index) == 16:
                        parameter_index = parameter_index + 1
                if is_parameter == 0:
                    parameter_index = parameter_index + 1
            append(function_param_counts, parameter_count)
            let header_index = parameter_index
            while token_kind(kinds, header_index) != 12 and token_kind(kinds, header_index) != 0:
                header_index = header_index + 1
            let body_index = header_index + 1
            let body_end = body_index
            while token_kind(kinds, body_end) != 0 and token_kind(kinds, body_end) != 13:
                body_end = body_end + 1
            append(function_bodies, body_index)
            append(function_body_ends, body_end)
            current_index = body_end
        if is_function_definition == 0:
            current_index = current_index + 1
    return len(function_starts)

def parse_index_atom(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == 1:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    let index_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, index_temporary)
    append_text(output, " = load i32, i32* %")
    append_text(output, source[token_start(starts, index):token_end(ends, index)])
    append_text(output, "\n")
    return (index + 1, 1, index_temporary, index_temporary)

def parse_position_call(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let call_name_start = token_start(starts, index)
    let call_name_end = token_end(ends, index)
    let list_argument_index = index + 2
    let list_variable_index = find_variable(source, token_start(starts, list_argument_index), token_end(ends, list_argument_index), variable_starts, variable_ends)
    let list_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, list_temporary)
    append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
    append_text(output, source[token_start(starts, list_argument_index):token_end(ends, list_argument_index)])
    append_text(output, "\n")
    let (index_next, index_is_temporary, index_value, index_counter) = parse_index_atom(source, kinds, starts, ends, list_argument_index + 2, output, variable_starts, variable_ends, variable_types, list_temporary)
    let result_temporary = index_counter + 1
    append_text(output, "%t")
    append_integer(output, result_temporary)
    if source[call_name_start:call_name_end] == "token_start":
        append_text(output, " = call i32 @token_start(%dynarray_i32* %t")
    if source[call_name_start:call_name_end] != "token_start":
        append_text(output, " = call i32 @token_end(%dynarray_i32* %t")
    append_integer(output, list_temporary)
    append_text(output, ", i32 ")
    append_operand(output, index_is_temporary, index_value)
    append_text(output, ")\n")
    return (index_next + 1, 1, result_temporary, result_temporary)

def parse_nested_call(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let name_start = token_start(starts, index)
    let name_end = token_end(ends, index)
    if source[name_start:name_end] == "add":
        let first_token_index = index + 2
        let first_token_start = token_start(starts, first_token_index)
        let first_token_end = token_end(ends, first_token_index)
        let first_value = parse_integer(source, first_token_start, first_token_end)
        let second_token_index = index + 4
        let second_token_start = token_start(starts, second_token_index)
        let second_token_end = token_end(ends, second_token_index)
        let second_value = parse_integer(source, second_token_start, second_token_end)
        let nested_add_result_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, nested_add_result_temporary)
        append_text(output, " = call i32 @add(i32 ")
        append_integer(output, first_value)
        append_text(output, ", i32 ")
        append_integer(output, second_value)
        append_text(output, ")\n")
        return (index + 6, 1, nested_add_result_temporary, nested_add_result_temporary)
    let argument_temporary_flags = []
    let argument_values = []
    let argument_index = index + 2
    let argument_counter = temporary_counter
    let argument_steps = 0
    while argument_index < len(kinds) and text_char_code(source, token_start(starts, argument_index)) != 41 and argument_steps < 16:
        let parsed_argument = 0
        let parsed_argument_type = 0
        let parsed_argument_value = 0
        let parsed_argument_index = argument_index + 1
        let parsed_argument_counter = argument_counter
        if token_kind(kinds, argument_index) == 1:
            parsed_argument = 1
            parsed_argument_value = parse_integer(source, token_start(starts, argument_index), token_end(ends, argument_index))
        if token_kind(kinds, argument_index) == 26:
            let string_argument_temporary = argument_counter + 1
            append_string_pointer(output, source, starts, ends, argument_index, string_argument_temporary)
            parsed_argument = 1
            parsed_argument_type = 2
            parsed_argument_value = string_argument_temporary
            parsed_argument_counter = string_argument_temporary
        let is_call_argument = 0
        if token_kind(kinds, argument_index) == 2:
            if token_kind(kinds, argument_index + 1) == 9:
                is_call_argument = 1
        if is_call_argument == 1:
            let argument_name = source[token_start(starts, argument_index):token_end(ends, argument_index)]
            let is_position_call = 0
            if argument_name == "token_start":
                is_position_call = 1
            if argument_name == "token_end":
                is_position_call = 1
            if is_position_call == 1:
                let (position_next_index, position_type, position_value, position_counter) = parse_position_call(source, kinds, starts, ends, argument_index, output, variable_starts, variable_ends, variable_types, argument_counter)
                parsed_argument_index = position_next_index
                parsed_argument_type = position_type
                parsed_argument_value = position_value
                parsed_argument_counter = position_counter
            if is_position_call == 0:
                let nested_name_start = token_start(starts, argument_index)
                let nested_name_end = token_end(ends, argument_index)
                let nested_argument_flags = []
                let nested_argument_values = []
                let nested_argument_index = argument_index + 2
                let nested_argument_counter = argument_counter
                while token_kind(kinds, nested_argument_index) != 10:
                    let nested_argument_type = 0
                    let nested_argument_value = 0
                    let nested_argument_next_index = nested_argument_index + 1
                    if token_kind(kinds, nested_argument_index) == 1:
                        nested_argument_value = parse_integer(source, token_start(starts, nested_argument_index), token_end(ends, nested_argument_index))
                    if token_kind(kinds, nested_argument_index) == 26:
                        let nested_string_literal_temporary = nested_argument_counter + 1
                        append_string_pointer(output, source, starts, ends, nested_argument_index, nested_string_literal_temporary)
                        nested_argument_type = 2
                        nested_argument_value = nested_string_literal_temporary
                        nested_argument_counter = nested_string_literal_temporary
                    let nested_is_position_call = 0
                    if token_kind(kinds, nested_argument_index) == 2 and token_kind(kinds, nested_argument_index + 1) == 9:
                        let nested_argument_name = source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)]
                        if nested_argument_name == "token_start" or nested_argument_name == "token_end":
                            nested_is_position_call = 1
                    if nested_is_position_call == 1:
                        let (nested_position_next_index, nested_position_type, nested_position_value, nested_position_counter) = parse_position_call(source, kinds, starts, ends, nested_argument_index, output, variable_starts, variable_ends, variable_types, nested_argument_counter)
                        nested_argument_next_index = nested_position_next_index
                        nested_argument_type = nested_position_type
                        nested_argument_value = nested_position_value
                        nested_argument_counter = nested_position_counter
                    if token_kind(kinds, nested_argument_index) == 2 and nested_is_position_call == 0:
                        let nested_variable_index = find_variable(source, token_start(starts, nested_argument_index), token_end(ends, nested_argument_index), variable_starts, variable_ends)
                        let nested_string_variable = 0
                        let nested_list_variable = 0
                        if nested_variable_index >= 0:
                            if variable_types[nested_variable_index] == 2:
                                nested_string_variable = 1
                            if variable_types[nested_variable_index] == 3:
                                nested_list_variable = 1
                        if nested_string_variable == 1:
                            let nested_string_variable_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_string_variable_temporary)
                            append_text(output, " = load i8*, i8** %")
                            append_text(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)])
                            append_text(output, "\n")
                            nested_argument_type = 2
                            nested_argument_value = nested_string_variable_temporary
                            nested_argument_counter = nested_string_variable_temporary
                        if nested_list_variable == 1:
                            let nested_list_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_list_temporary)
                            append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
                            append_text(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)])
                            append_text(output, "\n")
                            nested_argument_type = 3
                            nested_argument_value = nested_list_temporary
                            nested_argument_counter = nested_list_temporary
                        if nested_string_variable == 0 and nested_list_variable == 0:
                            let nested_integer_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_integer_temporary)
                            append_text(output, " = load i32, i32* %")
                            append_text(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)])
                            append_text(output, "\n")
                            nested_argument_type = 1
                            nested_argument_value = nested_integer_temporary
                            nested_argument_counter = nested_integer_temporary
                    append(nested_argument_flags, nested_argument_type)
                    append(nested_argument_values, nested_argument_value)
                    nested_argument_index = nested_argument_next_index
                    if token_kind(kinds, nested_argument_index) == 16:
                        nested_argument_index = nested_argument_index + 1
                let nested_result_temporary = nested_argument_counter + 1
                let nested_result_type = 1
                if source[nested_name_start:nested_name_end] == "read_text_file" or source[nested_name_start:nested_name_end] == "string_substring":
                    nested_result_type = 2
                append_text(output, "%t")
                append_integer(output, nested_result_temporary)
                if nested_result_type == 2:
                    append_text(output, " = call i8* @")
                if nested_result_type != 2:
                    append_text(output, " = call i32 @")
                append_text(output, source[nested_name_start:nested_name_end])
                append_text(output, "(")
                let nested_output_index = 0
                while nested_output_index < len(nested_argument_values):
                    if nested_output_index > 0:
                        append_text(output, ", ")
                    if nested_argument_flags[nested_output_index] == 2:
                        append_text(output, "i8* ")
                    if nested_argument_flags[nested_output_index] == 3:
                        append_text(output, "%dynarray_i32* ")
                    if nested_argument_flags[nested_output_index] == 1:
                        append_text(output, "i32 ")
                    append_operand(output, nested_argument_flags[nested_output_index], nested_argument_values[nested_output_index])
                    nested_output_index = nested_output_index + 1
                append_text(output, ")\n")
                parsed_argument_index = nested_argument_index + 1
                parsed_argument_type = nested_result_type
                parsed_argument_value = nested_result_temporary
                parsed_argument_counter = nested_result_temporary
            parsed_argument = 1
        if parsed_argument == 0:
            let argument_variable_index = find_variable(source, token_start(starts, argument_index), token_end(ends, argument_index), variable_starts, variable_ends)
            let is_string_variable = 0
            let is_list_variable = 0
            if argument_variable_index >= 0:
                if variable_types[argument_variable_index] == 2:
                    is_string_variable = 1
                if variable_types[argument_variable_index] == 3:
                    is_list_variable = 1
            if is_string_variable == 1:
                let loaded_string_temporary = argument_counter + 1
                append_text(output, "%t")
                append_integer(output, loaded_string_temporary)
                append_text(output, " = load i8*, i8** %")
                append_text(output, source[token_start(starts, argument_index):token_end(ends, argument_index)])
                append_text(output, "\n")
                parsed_argument_type = 2
                parsed_argument_value = loaded_string_temporary
                parsed_argument_counter = loaded_string_temporary
            if is_list_variable == 1:
                let loaded_list_temporary = argument_counter + 1
                append_text(output, "%t")
                append_integer(output, loaded_list_temporary)
                append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
                append_text(output, source[token_start(starts, argument_index):token_end(ends, argument_index)])
                append_text(output, "\n")
                parsed_argument_type = 3
                parsed_argument_value = loaded_list_temporary
                parsed_argument_counter = loaded_list_temporary
            if is_string_variable == 0:
                if is_list_variable == 0:
                    let loaded_integer_temporary = argument_counter + 1
                    append_text(output, "%t")
                    append_integer(output, loaded_integer_temporary)
                    append_text(output, " = load i32, i32* %")
                    append_text(output, source[token_start(starts, argument_index):token_end(ends, argument_index)])
                    append_text(output, "\n")
                    parsed_argument_type = 1
                    parsed_argument_value = loaded_integer_temporary
                    parsed_argument_counter = loaded_integer_temporary
            parsed_argument = 1
        argument_index = parsed_argument_index
        argument_counter = parsed_argument_counter
        append(argument_temporary_flags, parsed_argument_type)
        append(argument_values, parsed_argument_value)
        if text_char_code(source, token_start(starts, argument_index)) == 44:
            argument_index = argument_index + 1
        argument_steps = argument_steps + 1
    let result_temporary = argument_counter + 1
    let call_result_type = 1
    if source[name_start:name_end] == "read_text_file" or source[name_start:name_end] == "string_substring":
        call_result_type = 2
    if source[name_start:name_end] == "parse_nested_call":
        call_result_type = 3
    append_text(output, "%t")
    append_integer(output, result_temporary)
    if call_result_type == 2:
        append_text(output, " = call i8* @")
    if call_result_type == 3:
        append_text(output, " = call %dynarray_i32* @")
    if call_result_type != 2:
        if call_result_type != 3:
            append_text(output, " = call i32 @")
    append_text(output, source[name_start:name_end])
    append_text(output, "(")
    let output_argument_index = 0
    while output_argument_index < len(argument_values):
        if output_argument_index > 0:
            append_text(output, ", ")
        let output_argument_is_string = 0
        let output_argument_is_list = 0
        if argument_temporary_flags[output_argument_index] == 2:
            output_argument_is_string = 1
        if argument_temporary_flags[output_argument_index] == 3:
            output_argument_is_list = 1
        if output_argument_is_string == 1:
            append_text(output, "i8* ")
        if output_argument_is_list == 1:
            append_text(output, "%dynarray_i32* ")
        if output_argument_is_string == 0:
            if output_argument_is_list == 0:
                append_text(output, "i32 ")
        append_operand(output, argument_temporary_flags[output_argument_index], argument_values[output_argument_index])
        output_argument_index = output_argument_index + 1
    append_text(output, ")\n")
    return (argument_index + 1, call_result_type, result_temporary, result_temporary)

def is_known_list_variable(source: str, name_start: int, name_end: int) -> bool:
    return source[name_start:name_end] == "argument_temporary_flags" or source[name_start:name_end] == "argument_values" or source[name_start:name_end] == "tuple_name_starts" or source[name_start:name_end] == "tuple_name_ends"

def parse_slice_endpoint(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == 1:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    let endpoint_variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    let is_list_endpoint = 0
    if endpoint_variable_index >= 0:
        if variable_types[endpoint_variable_index] == 3:
            is_list_endpoint = 1
    if is_known_list_variable(source, token_start(starts, index), token_end(ends, index)):
        is_list_endpoint = 1
    if is_list_endpoint == 1 and token_kind(kinds, index + 1) == 27:
        let endpoint_list_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, endpoint_list_temporary)
        append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
        append_text(output, source[token_start(starts, index):token_end(ends, index)])
        append_text(output, "\n")
        let (endpoint_index_next, endpoint_index_type, endpoint_index_value, endpoint_index_counter) = parse_index_atom(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, endpoint_list_temporary)
        let endpoint_value_temporary = endpoint_index_counter + 1
        append_text(output, "%t")
        append_integer(output, endpoint_value_temporary)
        append_text(output, " = call i32 @get(%dynarray_i32* %t")
        append_integer(output, endpoint_list_temporary)
        append_text(output, ", i32 ")
        append_operand(output, endpoint_index_type, endpoint_index_value)
        append_text(output, ")\n")
        return (endpoint_index_next + 1, 1, endpoint_value_temporary, endpoint_value_temporary)
    if token_kind(kinds, index) == 2 and token_kind(kinds, index + 1) == 9:
        let argument_name = source[token_start(starts, index):token_end(ends, index)]
        if argument_name == "token_start" or argument_name == "token_end":
            return parse_position_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return parse_nested_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let endpoint_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, endpoint_temporary)
    append_text(output, " = load i32, i32* %")
    append_text(output, source[token_start(starts, index):token_end(ends, index)])
    append_text(output, "\n")
    return (index + 1, 1, endpoint_temporary, endpoint_temporary)

def parse_argument_atom(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == 1:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    if token_kind(kinds, index) == 26:
        let string_temporary = temporary_counter + 1
        append_string_pointer(output, source, starts, ends, index, string_temporary)
        return (index + 1, 2, string_temporary, string_temporary)
    if token_kind(kinds, index) == 27 and token_kind(kinds, index + 1) == 28:
        let list_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, list_temporary)
        append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
        return (index + 2, 3, list_temporary, list_temporary)
    if token_kind(kinds, index) == 2 and token_kind(kinds, index + 1) == 9:
        let argument_name = source[token_start(starts, index):token_end(ends, index)]
        if argument_name == "token_start" or argument_name == "token_end":
            return parse_position_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return parse_nested_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    if variable_index >= 0 and variable_types[variable_index] == 2:
        let string_variable_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, string_variable_temporary)
        append_text(output, " = load i8*, i8** %")
        append_text(output, source[token_start(starts, index):token_end(ends, index)])
        append_text(output, "\n")
        if token_kind(kinds, index + 1) == 27:
            let (slice_start_index, slice_start_type, slice_start_value, slice_start_counter) = parse_slice_endpoint(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, string_variable_temporary)
            let (slice_end_index, slice_end_type, slice_end_value, slice_end_counter) = parse_slice_endpoint(source, kinds, starts, ends, slice_start_index + 1, output, variable_starts, variable_ends, variable_types, slice_start_counter)
            let slice_temporary = slice_end_counter + 1
            append_text(output, "%t")
            append_integer(output, slice_temporary)
            append_text(output, " = call i8* @string_substring(i8* %t")
            append_integer(output, string_variable_temporary)
            append_text(output, ", i32 ")
            append_operand(output, slice_start_type, slice_start_value)
            append_text(output, ", i32 ")
            append_operand(output, slice_end_type, slice_end_value)
            append_text(output, ")\n")
            return (slice_end_index + 1, 2, slice_temporary, slice_temporary)
        return (index + 1, 2, string_variable_temporary, string_variable_temporary)
    let is_list_variable = 0
    if is_known_list_variable(source, token_start(starts, index), token_end(ends, index)):
        is_list_variable = 1
    if variable_index >= 0:
        if variable_types[variable_index] == 3:
            is_list_variable = 1
    if is_list_variable == 1:
        let list_variable_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, list_variable_temporary)
        append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
        append_text(output, source[token_start(starts, index):token_end(ends, index)])
        append_text(output, "\n")
        if token_kind(kinds, index + 1) == 27:
            let (index_next_index, index_is_temporary, index_value, index_next_counter) = parse_index_atom(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, list_variable_temporary)
            let element_temporary = index_next_counter + 1
            append_text(output, "%t")
            append_integer(output, element_temporary)
            append_text(output, " = call i32 @get(%dynarray_i32* %t")
            append_integer(output, list_variable_temporary)
            append_text(output, ", i32 ")
            append_operand(output, index_is_temporary, index_value)
            append_text(output, ")\n")
            return (index_next_index + 1, 1, element_temporary, element_temporary)
        return (index + 1, 3, list_variable_temporary, list_variable_temporary)
    let result_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, result_temporary)
    append_text(output, " = load i32, i32* %")
    append_text(output, source[token_start(starts, index):token_end(ends, index)])
    append_text(output, "\n")
    return (index + 1, 1, result_temporary, result_temporary)

def function_result_type(source: str, name_start: int, name_end: int) -> int:
    if source[name_start:name_end] == "read_text_file" or source[name_start:name_end] == "string_substring":
        return 2
    if source[name_start:name_end] == "parse_index_atom" or source[name_start:name_end] == "parse_position_call" or source[name_start:name_end] == "parse_nested_call" or source[name_start:name_end] == "parse_slice_endpoint" or source[name_start:name_end] == "parse_argument_atom" or source[name_start:name_end] == "parse_argument_expression" or source[name_start:name_end] == "parse_primary" or source[name_start:name_end] == "parse_unary" or source[name_start:name_end] == "parse_term" or source[name_start:name_end] == "parse_logical_operand" or source[name_start:name_end] == "parse_expression" or source[name_start:name_end] == "parse_assignment" or source[name_start:name_end] == "parse_branch_body" or source[name_start:name_end] == "parse_switch_statement" or source[name_start:name_end] == "parse_function_body":
        return 3
    return 1

def parse_argument_expression(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_argument_atom(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == 7 or token_kind(kinds, current_index) == 8 or token_kind(kinds, current_index) == 36:
        let term_operator = token_kind(kinds, current_index)
        let (term_next_index, term_next_is_temporary, term_next_value, term_next_counter) = parse_argument_atom(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter)
        let term_result_temporary = term_next_counter + 1
        append_text(output, "%t")
        append_integer(output, term_result_temporary)
        if term_operator == 7:
            append_text(output, " = mul i32 ")
        if term_operator == 8:
            append_text(output, " = sdiv i32 ")
        if term_operator == 36:
            append_text(output, " = srem i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, term_next_is_temporary, term_next_value)
        append_text(output, "\n")
        current_index = term_next_index
        current_is_temporary = 1
        current_value = term_result_temporary
        current_counter = term_result_temporary
    while token_kind(kinds, current_index) == 5 or token_kind(kinds, current_index) == 6:
        let expression_operator = token_kind(kinds, current_index)
        let (expression_next_index, expression_next_is_temporary, expression_next_value, expression_next_counter) = parse_argument_atom(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter)
        let expression_result_temporary = expression_next_counter + 1
        append_text(output, "%t")
        append_integer(output, expression_result_temporary)
        if expression_operator == 5:
            append_text(output, " = add i32 ")
        if expression_operator == 6:
            append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, expression_next_is_temporary, expression_next_value)
        append_text(output, "\n")
        current_index = expression_next_index
        current_is_temporary = 1
        current_value = expression_result_temporary
        current_counter = expression_result_temporary
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_primary(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int, int, int):
    let kind = token_kind(kinds, index)
    if kind == 1:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    if kind == 26:
        let string_temporary = temporary_counter + 1
        append_string_pointer(output, source, starts, ends, index, string_temporary)
        return (index + 1, 2, string_temporary, string_temporary)
    if kind == 27 and token_kind(kinds, index + 1) == 28:
        let list_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, list_temporary)
        append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
        return (index + 2, 3, list_temporary, list_temporary)
    if kind == 2:
        let name_start = token_start(starts, index)
        let name_end = token_end(ends, index)
        if token_kind(kinds, index + 1) == 9:
            let argument_temporary_flags = []
            let argument_values = []
            let argument_index = index + 2
            let argument_counter = temporary_counter
            let call_argument_steps = 0
            while argument_index < len(kinds) and token_kind(kinds, argument_index) != 10 and call_argument_steps < 32:
                let (argument_next_index, argument_is_temporary, argument_value, argument_next_counter) = parse_argument_expression(source, kinds, starts, ends, argument_index, output, variable_starts, variable_ends, variable_types, argument_counter)
                append(argument_temporary_flags, argument_is_temporary)
                append(argument_values, argument_value)
                argument_index = argument_next_index
                argument_counter = argument_next_counter
                if token_kind(kinds, argument_index) == 16:
                    argument_index = argument_index + 1
                call_argument_steps = call_argument_steps + 1
            let result_temporary = argument_counter + 1
            let call_result_type = function_result_type(source, name_start, name_end)
            append_text(output, "%t")
            append_integer(output, result_temporary)
            if call_result_type == 2:
                append_text(output, " = call i8* @")
            if call_result_type == 3:
                append_text(output, " = call %dynarray_i32* @")
            if call_result_type != 2 and call_result_type != 3:
                append_text(output, " = call i32 @")
            append_text(output, source[name_start:name_end])
            append_text(output, "(")
            let output_argument_index = 0
            while output_argument_index < len(argument_values):
                if output_argument_index > 0:
                    append_text(output, ", ")
                let output_argument_is_string = 0
                let output_argument_is_list = 0
                if argument_temporary_flags[output_argument_index] == 2:
                    output_argument_is_string = 1
                if argument_temporary_flags[output_argument_index] == 3:
                    output_argument_is_list = 1
                if output_argument_is_string == 1:
                    append_text(output, "i8* ")
                if output_argument_is_list == 1:
                    append_text(output, "%dynarray_i32* ")
                if output_argument_is_string == 0:
                    if output_argument_is_list == 0:
                        append_text(output, "i32 ")
                append_operand(output, argument_temporary_flags[output_argument_index], argument_values[output_argument_index])
                output_argument_index = output_argument_index + 1
            append_text(output, ")\n")
            return (argument_index + 1, call_result_type, result_temporary, result_temporary)
        let variable_index = find_variable(source, name_start, name_end, variable_starts, variable_ends)
        if variable_index >= 0 and variable_types[variable_index] == 2:
            let string_variable_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, string_variable_temporary)
            append_text(output, " = load i8*, i8** %")
            append_text(output, source[name_start:name_end])
            append_text(output, "\n")
            if token_kind(kinds, index + 1) == 27:
                let (slice_start_index, slice_start_type, slice_start_value, slice_start_counter) = parse_slice_endpoint(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, string_variable_temporary)
                let (slice_end_index, slice_end_type, slice_end_value, slice_end_counter) = parse_slice_endpoint(source, kinds, starts, ends, slice_start_index + 1, output, variable_starts, variable_ends, variable_types, slice_start_counter)
                let slice_temporary = slice_end_counter + 1
                append_text(output, "%t")
                append_integer(output, slice_temporary)
                append_text(output, " = call i8* @string_substring(i8* %t")
                append_integer(output, string_variable_temporary)
                append_text(output, ", i32 ")
                append_operand(output, slice_start_type, slice_start_value)
                append_text(output, ", i32 ")
                append_operand(output, slice_end_type, slice_end_value)
                append_text(output, ")\n")
                return (slice_end_index + 1, 2, slice_temporary, slice_temporary)
            return (index + 1, 2, string_variable_temporary, string_variable_temporary)
        let is_list_variable = 0
        if variable_index >= 0:
            if variable_types[variable_index] == 3:
                is_list_variable = 1
        if is_known_list_variable(source, name_start, name_end):
            is_list_variable = 1
        if is_list_variable == 1:
            let list_variable_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, list_variable_temporary)
            append_text(output, " = load %dynarray_i32*, %dynarray_i32** %")
            append_text(output, source[name_start:name_end])
            append_text(output, "\n")
            if token_kind(kinds, index + 1) == 27:
                let (index_next_index, index_is_temporary, index_value, index_next_counter) = parse_index_atom(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, list_variable_temporary)
                let element_temporary = index_next_counter + 1
                append_text(output, "%t")
                append_integer(output, element_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* %t")
                append_integer(output, list_variable_temporary)
                append_text(output, ", i32 ")
                append_operand(output, index_is_temporary, index_value)
                append_text(output, ")\n")
                return (index_next_index + 1, 1, element_temporary, element_temporary)
            return (index + 1, 3, list_variable_temporary, list_variable_temporary)
        let next_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, next_temporary)
        append_text(output, " = load i32, i32* %")
        append_text(output, source[name_start:name_end])
        append_text(output, "\n")
        return (index + 1, 1, next_temporary, next_temporary)
    return (index + 1, 0, 0, temporary_counter)

def parse_unary(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int, int, int):
    return parse_primary(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)

def parse_term(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_unary(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == 7 or token_kind(kinds, current_index) == 8 or token_kind(kinds, current_index) == 36:
        let operator = token_kind(kinds, current_index)
        let (next_index, next_is_temporary, next_value, next_counter) = parse_unary(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let result_temporary = next_counter + 1
        append_text(output, "%t")
        append_integer(output, result_temporary)
        if operator == 7:
            append_text(output, " = mul i32 ")
        if operator == 8:
            append_text(output, " = sdiv i32 ")
        if operator == 36:
            append_text(output, " = srem i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, next_is_temporary, next_value)
        append_text(output, "\n")
        current_index = next_index
        current_is_temporary = 1
        current_value = result_temporary
        current_counter = result_temporary
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_logical_operand(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_term(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == 5 or token_kind(kinds, current_index) == 6:
        let additive_operator = token_kind(kinds, current_index)
        let (additive_next_index, additive_is_temporary, additive_value, additive_next_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let additive_result = additive_next_counter + 1
        append_text(output, "%t")
        append_integer(output, additive_result)
        if additive_operator == 5:
            append_text(output, " = add i32 ")
        if additive_operator == 6:
            append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, additive_is_temporary, additive_value)
        append_text(output, "\n")
        current_index = additive_next_index
        current_is_temporary = 1
        current_value = additive_result
        current_counter = additive_result
    while token_kind(kinds, current_index) == 18 or token_kind(kinds, current_index) == 29 or token_kind(kinds, current_index) == 30 or token_kind(kinds, current_index) == 31 or token_kind(kinds, current_index) == 32 or token_kind(kinds, current_index) == 33:
        let comparison_operator = token_kind(kinds, current_index)
        let (comparison_value_index, comparison_is_temporary, comparison_value, comparison_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let comparison_result = comparison_counter + 1
        append_text(output, "%t")
        append_integer(output, comparison_result)
        if current_is_temporary == 2 or comparison_is_temporary == 2:
            append_text(output, " = call i32 @string_compare(i8* ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", i8* ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, ")\n")
            let compare_result = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, compare_result)
            if comparison_operator == 30:
                append_text(output, " = icmp ne i32 %t")
            if comparison_operator != 30:
                append_text(output, " = icmp eq i32 %t")
            append_integer(output, comparison_result)
            append_text(output, ", 0\n")
            let string_normalized_result = compare_result + 1
            append_text(output, "%t")
            append_integer(output, string_normalized_result)
            append_text(output, " = zext i1 %t")
            append_integer(output, compare_result)
            append_text(output, " to i32\n")
            current_index = comparison_value_index
            current_is_temporary = 1
            current_value = string_normalized_result
            current_counter = string_normalized_result
        if current_is_temporary != 2 and comparison_is_temporary != 2:
            if comparison_operator == 18:
                append_text(output, " = icmp slt i32 ")
            if comparison_operator == 29:
                append_text(output, " = icmp eq i32 ")
            if comparison_operator == 30:
                append_text(output, " = icmp ne i32 ")
            if comparison_operator == 31:
                append_text(output, " = icmp sle i32 ")
            if comparison_operator == 32:
                append_text(output, " = icmp sge i32 ")
            if comparison_operator == 33:
                append_text(output, " = icmp sgt i32 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            let integer_normalized_result = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, integer_normalized_result)
            append_text(output, " = zext i1 %t")
            append_integer(output, comparison_result)
            append_text(output, " to i32\n")
            current_index = comparison_value_index
            current_is_temporary = 1
            current_value = integer_normalized_result
            current_counter = integer_normalized_result
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_expression(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_term(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == 5 or token_kind(kinds, current_index) == 6:
        let operator = token_kind(kinds, current_index)
        let (next_index, next_is_temporary, next_value, next_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let result_temporary = next_counter + 1
        append_text(output, "%t")
        append_integer(output, result_temporary)
        if operator == 5:
            append_text(output, " = add i32 ")
        if operator == 6:
            append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, next_is_temporary, next_value)
        append_text(output, "\n")
        current_index = next_index
        current_is_temporary = 1
        current_value = result_temporary
        current_counter = result_temporary
    while token_kind(kinds, current_index) == 18 or token_kind(kinds, current_index) == 29 or token_kind(kinds, current_index) == 30 or token_kind(kinds, current_index) == 31 or token_kind(kinds, current_index) == 32 or token_kind(kinds, current_index) == 33:
        let comparison_operator = token_kind(kinds, current_index)
        let comparison_next_index = current_index + 1
        let (comparison_value_index, comparison_is_temporary, comparison_value, comparison_counter) = parse_term(source, kinds, starts, ends, comparison_next_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let comparison_result = comparison_counter + 1
        append_text(output, "%t")
        append_integer(output, comparison_result)
        if current_is_temporary == 2 or comparison_is_temporary == 2:
            append_text(output, " = call i32 @string_compare(i8* ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", i8* ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, ")\n")
            let string_comparison_normalized = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, string_comparison_normalized)
            if comparison_operator == 30:
                append_text(output, " = icmp ne i32 %t")
            if comparison_operator != 30:
                append_text(output, " = icmp eq i32 %t")
            append_integer(output, comparison_result)
            append_text(output, ", 0\n")
            let string_comparison_value = string_comparison_normalized + 1
            append_text(output, "%t")
            append_integer(output, string_comparison_value)
            append_text(output, " = zext i1 %t")
            append_integer(output, string_comparison_normalized)
            append_text(output, " to i32\n")
            current_index = comparison_value_index
            current_is_temporary = 1
            current_value = string_comparison_value
            current_counter = string_comparison_value
        if current_is_temporary != 2 and comparison_is_temporary != 2:
            if comparison_operator == 18:
                append_text(output, " = icmp slt i32 ")
            if comparison_operator == 29:
                append_text(output, " = icmp eq i32 ")
            if comparison_operator == 30:
                append_text(output, " = icmp ne i32 ")
            if comparison_operator == 31:
                append_text(output, " = icmp sle i32 ")
            if comparison_operator == 32:
                append_text(output, " = icmp sge i32 ")
            if comparison_operator == 33:
                append_text(output, " = icmp sgt i32 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            let comparison_normalized = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, comparison_normalized)
            append_text(output, " = zext i1 %t")
            append_integer(output, comparison_result)
            append_text(output, " to i32\n")
            current_index = comparison_value_index
            current_is_temporary = 1
            current_value = comparison_normalized
            current_counter = comparison_normalized
    while token_kind(kinds, current_index) == 34 or token_kind(kinds, current_index) == 35:
        let logical_operator = token_kind(kinds, current_index)
        let (logical_next_index, logical_is_temporary, logical_value, logical_counter) = parse_logical_operand(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let logical_result = logical_counter + 1
        append_text(output, "%t")
        append_integer(output, logical_result)
        if logical_operator == 34:
            append_text(output, " = and i32 ")
        if logical_operator != 34:
            append_text(output, " = or i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, logical_is_temporary, logical_value)
        append_text(output, "\n")
        current_index = logical_next_index
        current_is_temporary = 1
        current_value = logical_result
        current_counter = logical_result
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_assignment(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int):
    let assignment_name_start = token_start(starts, index)
    let assignment_name_end = token_end(ends, index)
    let assignment_expression_index = index + 2
    let (assignment_next_index, assignment_is_temporary, assignment_value, assignment_next_counter) = parse_expression(source, kinds, starts, ends, assignment_expression_index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let assignment_variable_index = find_variable(source, assignment_name_start, assignment_name_end, variable_starts, variable_ends)
    let is_string_assignment = 0
    let is_list_assignment = 0
    if assignment_variable_index >= 0 and variable_types[assignment_variable_index] == 2:
        is_string_assignment = 1
    if assignment_variable_index >= 0 and variable_types[assignment_variable_index] == 3:
        is_list_assignment = 1
    if is_string_assignment == 1:
        append_text(output, "store i8* ")
    if is_list_assignment == 1:
        append_text(output, "store %dynarray_i32* ")
    if is_string_assignment == 0 and is_list_assignment == 0:
        append_text(output, "store i32 ")
    append_operand(output, assignment_is_temporary, assignment_value)
    if is_string_assignment == 1:
        append_text(output, ", i8** %")
    if is_list_assignment == 1:
        append_text(output, ", %dynarray_i32** %")
    if is_string_assignment == 0 and is_list_assignment == 0:
        append_text(output, ", i32* %")
    append_text(output, source[assignment_name_start:assignment_name_end])
    append_text(output, "\n")
    return (skip_source_newlines(source, starts, assignment_next_index), assignment_next_counter)

def parse_branch_body(source: str, kinds: list[int], starts: list[int], ends: list[int], branch_start: int, branch_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int):
    return parse_function_body(source, kinds, starts, ends, branch_start, branch_end, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let current_index = skip_source_newlines(source, starts, branch_start)
    let current_counter = temporary_counter
    let has_return = 0
    while current_index < branch_end and token_kind(kinds, current_index) != 0:
        if token_kind(kinds, current_index) == 3 and token_kind(kinds, current_index + 1) != 9:
            let branch_let_name_start = token_start(starts, current_index + 1)
            let branch_let_name_end = token_end(ends, current_index + 1)
            let branch_let_expression_index = current_index + 3
            let (branch_let_next_index, branch_let_is_temporary, branch_let_value, branch_let_next_counter) = parse_expression(source, kinds, starts, ends, branch_let_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            if branch_let_is_temporary == 2:
                append_local_storage(output, source[branch_let_name_start:branch_let_name_end], 2)
                append_text(output, "store i8* ")
            elif branch_let_is_temporary == 3:
                append_local_storage(output, source[branch_let_name_start:branch_let_name_end], 3)
                append_text(output, "store %dynarray_i32* ")
            else:
                append_local_storage(output, source[branch_let_name_start:branch_let_name_end], 1)
                append_text(output, "store i32 ")
            append_operand(output, branch_let_is_temporary, branch_let_value)
            if branch_let_is_temporary == 2:
                append_text(output, ", i8** %")
            elif branch_let_is_temporary == 3:
                append_text(output, ", %dynarray_i32** %")
            else:
                append_text(output, ", i32* %")
            append_text(output, source[branch_let_name_start:branch_let_name_end])
            append_text(output, "\n")
            append(variable_starts, branch_let_name_start)
            append(variable_ends, branch_let_name_end)
            append(variable_types, branch_let_is_temporary)
            current_index = skip_source_newlines(source, starts, branch_let_next_index)
            current_counter = branch_let_next_counter
        elif token_kind(kinds, current_index) == 3 and token_kind(kinds, current_index + 1) == 9:
            let tuple_name_starts = []
            let tuple_name_ends = []
            let tuple_name_index = current_index + 2
            while token_kind(kinds, tuple_name_index) != 10:
                if token_kind(kinds, tuple_name_index) == 2:
                    append(tuple_name_starts, token_start(starts, tuple_name_index))
                    append(tuple_name_ends, token_end(ends, tuple_name_index))
                tuple_name_index = tuple_name_index + 1
            let tuple_expression_index = tuple_name_index + 2
            let (tuple_next_index, tuple_is_temporary, tuple_value, tuple_next_counter) = parse_expression(source, kinds, starts, ends, tuple_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            let tuple_element_index = 0
            while tuple_element_index < len(tuple_name_starts):
                let tuple_element_temporary = tuple_next_counter + tuple_element_index + 1
                append_text(output, "%t")
                append_integer(output, tuple_element_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* %t")
                append_integer(output, tuple_value)
                append_text(output, ", i32 ")
                append_integer(output, tuple_element_index)
                append_text(output, ")\n")
                append_local_storage(output, source[tuple_name_starts[tuple_element_index]:tuple_name_ends[tuple_element_index]], 1)
                append_text(output, "store i32 %t")
                append_integer(output, tuple_element_temporary)
                append_text(output, ", i32* %")
                append_text(output, source[tuple_name_starts[tuple_element_index]:tuple_name_ends[tuple_element_index]])
                append_text(output, "\n")
                append(variable_starts, tuple_name_starts[tuple_element_index])
                append(variable_ends, tuple_name_ends[tuple_element_index])
                append(variable_types, 1)
                tuple_element_index = tuple_element_index + 1
            current_index = skip_source_newlines(source, starts, tuple_next_index)
            current_counter = tuple_next_counter + len(tuple_name_starts)
        else:
            if token_kind(kinds, current_index) == 2 and token_kind(kinds, current_index + 1) == 11:
                let (assignment_next_index, assignment_next_counter) = parse_assignment(source, kinds, starts, ends, current_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                current_index = assignment_next_index
                current_counter = assignment_next_counter
            else:
                if token_kind(kinds, current_index) == 4:
                    let branch_print_expression_index = current_index + 2
                    let (branch_print_next_index, branch_print_is_temporary, branch_print_value, branch_print_next_counter) = parse_expression(source, kinds, starts, ends, branch_print_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                    let is_branch_print_string = 0
                    if branch_print_is_temporary == 2:
                        is_branch_print_string = 1
                    if is_branch_print_string == 1:
                        append_text(output, "call void @print_string(i8* ")
                    if is_branch_print_string == 0:
                        append_text(output, "call void @print_int(i32 ")
                    append_operand(output, branch_print_is_temporary, branch_print_value)
                    append_text(output, ")\n")
                    current_index = skip_source_newlines(source, starts, branch_print_next_index + 1)
                    current_counter = branch_print_next_counter
                else:
                    if token_kind(kinds, current_index) == 14:
                        let branch_return_expression_index = current_index + 1
                        if token_kind(kinds, branch_return_expression_index) == 9:
                            let tuple_return_temporary = current_counter + 1
                            append_text(output, "%t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
                            let tuple_return_index = branch_return_expression_index + 1
                            let tuple_return_counter = tuple_return_temporary
                            while token_kind(kinds, tuple_return_index) != 10:
                                let (tuple_component_next_index, tuple_component_type, tuple_component_value, tuple_component_counter) = parse_expression(source, kinds, starts, ends, tuple_return_index, output, variable_starts, variable_ends, variable_types, tuple_return_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                                append_text(output, "call void @append_i32(%dynarray_i32* %t")
                                append_integer(output, tuple_return_temporary)
                                append_text(output, ", i32 ")
                                append_operand(output, tuple_component_type, tuple_component_value)
                                append_text(output, ")\n")
                                tuple_return_counter = tuple_component_counter
                                tuple_return_index = tuple_component_next_index
                                if token_kind(kinds, tuple_return_index) == 16:
                                    tuple_return_index = tuple_return_index + 1
                            append_text(output, "ret %dynarray_i32* %t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, "\n")
                            current_counter = tuple_return_counter
                        elif token_kind(kinds, branch_return_expression_index) == 2 and token_kind(kinds, branch_return_expression_index + 1) == 9 and function_result_type(source, token_start(starts, branch_return_expression_index), token_end(ends, branch_return_expression_index)) == 3:
                            let (branch_tuple_call_next_index, branch_tuple_call_is_temporary, branch_tuple_call_value, branch_tuple_call_next_counter) = parse_expression(source, kinds, starts, ends, branch_return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                            append_text(output, "ret %dynarray_i32* ")
                            append_operand(output, branch_tuple_call_is_temporary, branch_tuple_call_value)
                            append_text(output, "\n")
                            current_counter = branch_tuple_call_next_counter
                        else:
                            let (branch_return_next_index, branch_return_is_temporary, branch_return_value, branch_return_next_counter) = parse_expression(source, kinds, starts, ends, branch_return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                            append_text(output, "ret i32 ")
                            append_operand(output, branch_return_is_temporary, branch_return_value)
                            append_text(output, "\n")
                            current_counter = branch_return_next_counter
                        has_return = 1
                        current_index = branch_end
                    else:
                        if token_kind(kinds, current_index) == 2 and token_kind(kinds, current_index + 1) == 9:
                            let branch_call_expression_index = current_index
                            let (branch_call_next_index, branch_call_is_temporary, branch_call_value, branch_call_next_counter) = parse_expression(source, kinds, starts, ends, branch_call_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                            current_index = skip_source_newlines(source, starts, branch_call_next_index + 1)
                            current_counter = branch_call_next_counter
                        else:
                            current_index = current_index + 1
    return (current_counter, has_return)

def parse_switch_statement(source: str, kinds: list[int], starts: list[int], ends: list[int], switch_index: int, body_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int):
    let switch_expression_index = switch_index + 1
    let (switch_header_next_index, switch_header_is_temporary, switch_header_value, switch_header_counter) = parse_expression(source, kinds, starts, ends, switch_expression_index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    let switch_label_base = switch_header_counter + 1000
    let switch_end_label = switch_label_base
    let case_index = skip_source_newlines(source, starts, switch_header_next_index + 1)
    let case_number = 0
    let current_counter = switch_header_counter
    while token_kind(kinds, case_index) == 24:
        let case_value_index = case_index + 1
        let (case_header_next_index, case_value_is_temporary, case_value, case_header_counter) = parse_expression(source, kinds, starts, ends, case_value_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        let case_condition = case_header_counter + 1
        let case_body_label = switch_label_base + case_number * 3 + 1
        let case_check_label = switch_label_base + case_number * 3 + 2
        append_text(output, "%t")
        append_integer(output, case_condition)
        append_text(output, " = icmp eq i32 ")
        append_operand(output, switch_header_is_temporary, switch_header_value)
        append_text(output, ", ")
        append_operand(output, case_value_is_temporary, case_value)
        append_text(output, "\nbr i1 %t")
        append_integer(output, case_condition)
        append_text(output, ", label %switch.case.")
        append_integer(output, case_body_label)
        append_text(output, ", label %switch.check.")
        append_integer(output, case_check_label)
        append_text(output, "\nswitch.case.")
        append_integer(output, case_body_label)
        append_text(output, ":\n")
        let case_body_start = skip_source_newlines(source, starts, case_header_next_index + 1)
        let case_body_indent = line_indent(source, token_start(starts, case_body_start))
        let case_body_end = case_body_start
        while case_body_end < body_end and is_body_line(source, kinds, starts, case_body_end, case_body_indent) == 1:
            case_body_end = case_body_end + 1
        let (case_body_counter, case_body_has_return) = parse_branch_body(source, kinds, starts, ends, case_body_start, case_body_end, output, variable_starts, variable_ends, variable_types, case_condition, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        if case_body_has_return == 0:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        append_text(output, "switch.check.")
        append_integer(output, case_check_label)
        append_text(output, ":\n")
        case_index = case_body_end
        current_counter = case_body_counter
        case_number = case_number + 1
    let has_default = 0
    if token_kind(kinds, case_index) == 25:
        has_default = 1
        let default_body_start = skip_source_newlines(source, starts, case_index + 1)
        let default_body_label = switch_label_base + case_number * 3 + 1
        append_text(output, "br label %switch.case.")
        append_integer(output, default_body_label)
        append_text(output, "\nswitch.case.")
        append_integer(output, default_body_label)
        append_text(output, ":\n")
        let default_body_indent = line_indent(source, token_start(starts, default_body_start))
        let default_body_end = default_body_start
        while default_body_end < body_end and is_body_line(source, kinds, starts, default_body_end, default_body_indent) == 1:
            default_body_end = default_body_end + 1
        let (default_body_counter, default_body_has_return) = parse_branch_body(source, kinds, starts, ends, default_body_start, default_body_end, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
        if default_body_has_return == 0:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        current_counter = default_body_counter
        case_index = default_body_end
    if has_default == 0:
        append_text(output, "br label %switch.end.")
        append_integer(output, switch_end_label)
        append_text(output, "\n")
    append_text(output, "switch.end.")
    append_integer(output, switch_end_label)
    append_text(output, ":\n")
    return (case_index, current_counter)

def parse_function_body(source: str, kinds: list[int], starts: list[int], ends: list[int], body_start: int, body_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int]) -> (int, int):
    let current_index = skip_source_newlines(source, starts, body_start)
    let current_counter = temporary_counter
    let has_return = 0
    while current_index < body_end and token_kind(kinds, current_index) != 0:
        let statement_token_kind = token_kind(kinds, current_index)
        let next_statement_token_kind = token_kind(kinds, current_index + 1)
        let is_let_statement = 0
        let is_tuple_let_statement = 0
        let is_assignment_statement = 0
        let is_switch_statement = 0
        let is_while_statement = 0
        if statement_token_kind == 3 and next_statement_token_kind != 9:
            is_let_statement = 1
        if statement_token_kind == 3 and next_statement_token_kind == 9:
            is_tuple_let_statement = 1
        if statement_token_kind == 2 and next_statement_token_kind == 11:
            is_assignment_statement = 1
        if statement_token_kind == 23:
            is_switch_statement = 1
        if statement_token_kind == 22:
            is_while_statement = 1
        let is_known_statement = 0
        if is_let_statement == 1 or is_tuple_let_statement == 1 or is_assignment_statement == 1 or is_switch_statement == 1 or is_while_statement == 1:
            is_known_statement = 1
        if is_let_statement == 1:
            let name_start = token_start(starts, current_index + 1)
            let name_end = token_end(ends, current_index + 1)
            let let_expression_index = current_index + 3
            let (let_next_index, let_is_temporary, let_value, let_next_counter) = parse_expression(source, kinds, starts, ends, let_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            if let_is_temporary == 2:
                append_local_storage(output, source[name_start:name_end], 2)
                append_text(output, "store i8* ")
            if let_is_temporary == 3:
                append_local_storage(output, source[name_start:name_end], 3)
                append_text(output, "store %dynarray_i32* ")
            if let_is_temporary != 2 and let_is_temporary != 3:
                append_local_storage(output, source[name_start:name_end], 1)
                append_text(output, "store i32 ")
            append_operand(output, let_is_temporary, let_value)
            if let_is_temporary == 2:
                append_text(output, ", i8** %")
            if let_is_temporary == 3:
                append_text(output, ", %dynarray_i32** %")
            if let_is_temporary != 2 and let_is_temporary != 3:
                append_text(output, ", i32* %")
            append_text(output, source[name_start:name_end])
            append_text(output, "\n")
            append(variable_starts, name_start)
            append(variable_ends, name_end)
            append(variable_types, let_is_temporary)
            current_index = let_next_index
            while current_index < body_end and text_char_code(source, token_start(starts, current_index)) == 10:
                current_index = current_index + 1
            current_counter = let_next_counter
        if is_tuple_let_statement == 1:
            let tuple_name_starts = []
            let tuple_name_ends = []
            let tuple_name_index = current_index + 2
            while token_kind(kinds, tuple_name_index) != 10:
                if token_kind(kinds, tuple_name_index) == 2:
                    append(tuple_name_starts, token_start(starts, tuple_name_index))
                    append(tuple_name_ends, token_end(ends, tuple_name_index))
                tuple_name_index = tuple_name_index + 1
            let tuple_expression_index = tuple_name_index + 2
            let (tuple_next_index, tuple_is_temporary, tuple_value, tuple_next_counter) = parse_expression(source, kinds, starts, ends, tuple_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            let tuple_element_index = 0
            while tuple_element_index < len(tuple_name_starts):
                let tuple_element_temporary = tuple_next_counter + tuple_element_index + 1
                append_text(output, "%t")
                append_integer(output, tuple_element_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* %t")
                append_integer(output, tuple_value)
                append_text(output, ", i32 ")
                append_integer(output, tuple_element_index)
                append_text(output, ")\n")
                append_local_storage(output, source[tuple_name_starts[tuple_element_index]:tuple_name_ends[tuple_element_index]], 1)
                append_text(output, "store i32 %t")
                append_integer(output, tuple_element_temporary)
                append_text(output, ", i32* %")
                append_text(output, source[tuple_name_starts[tuple_element_index]:tuple_name_ends[tuple_element_index]])
                append_text(output, "\n")
                append(variable_starts, tuple_name_starts[tuple_element_index])
                append(variable_ends, tuple_name_ends[tuple_element_index])
                append(variable_types, 1)
                tuple_element_index = tuple_element_index + 1
            current_index = skip_source_newlines(source, starts, tuple_next_index)
            current_counter = tuple_next_counter + len(tuple_name_starts)
        if is_assignment_statement == 1:
            let (assignment_next_index, assignment_next_counter) = parse_assignment(source, kinds, starts, ends, current_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            current_index = assignment_next_index
            current_counter = assignment_next_counter
        if is_switch_statement == 1:
            let (switch_next_index, switch_next_counter) = parse_switch_statement(source, kinds, starts, ends, current_index, body_end, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            current_index = switch_next_index
            current_counter = switch_next_counter
        if is_while_statement == 1:
            let while_expression_index = current_index + 1
            let while_label_base = current_counter + 1
            let while_check_label = while_label_base
            let while_body_label = while_label_base + 1
            let while_end_label = while_label_base + 2
            append_text(output, "br label %while.check.")
            append_integer(output, while_check_label)
            append_text(output, "\nwhile.check.")
            append_integer(output, while_check_label)
            append_text(output, ":\n")
            let (while_header_next_index, while_header_is_temporary, while_header_value, while_header_counter) = parse_expression(source, kinds, starts, ends, while_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            let while_condition = while_header_counter + 1
            append_text(output, "%t")
            append_integer(output, while_condition)
            append_text(output, " = icmp ne i32 ")
            append_operand(output, while_header_is_temporary, while_header_value)
            append_text(output, ", 0\nbr i1 %t")
            append_integer(output, while_condition)
            append_text(output, ", label %while.body.")
            append_integer(output, while_body_label)
            append_text(output, ", label %while.end.")
            append_integer(output, while_end_label)
            append_text(output, "\nwhile.body.")
            append_integer(output, while_body_label)
            append_text(output, ":\n")
            let while_body_start = skip_source_newlines(source, starts, while_header_next_index + 1)
            let while_body_indent = line_indent(source, token_start(starts, while_body_start))
            let while_body_end = while_body_start
            while while_body_end < body_end and is_body_line(source, kinds, starts, while_body_end, while_body_indent) == 1:
                while_body_end = while_body_end + 1
            let (while_body_counter, while_body_has_return) = parse_branch_body(source, kinds, starts, ends, while_body_start, while_body_end, output, variable_starts, variable_ends, variable_types, while_condition, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
            if while_body_has_return == 0:
                append_text(output, "br label %while.check.")
                append_integer(output, while_check_label)
                append_text(output, "\n")
            append_text(output, "while.end.")
            append_integer(output, while_end_label)
            append_text(output, ":\n")
            current_index = while_body_end
            current_counter = while_body_counter
        if is_known_statement == 0:
            if token_kind(kinds, current_index) == 4:
                let print_expression_index = current_index + 2
                let (print_next_index, print_is_temporary, print_value, print_next_counter) = parse_expression(source, kinds, starts, ends, print_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                let is_print_string = 0
                if print_is_temporary == 2:
                    is_print_string = 1
                if is_print_string == 1:
                    append_text(output, "call void @print_string(i8* ")
                if is_print_string == 0:
                    append_text(output, "call void @print_int(i32 ")
                append_operand(output, print_is_temporary, print_value)
                append_text(output, ")\n")
                current_index = skip_source_newlines(source, starts, print_next_index + 1)
                current_counter = print_next_counter
            else:
                if token_kind(kinds, current_index) == 19:
                    let if_expression_index = current_index + 1
                    let (if_header_next_index, if_header_is_temporary, if_header_value, if_header_counter) = parse_expression(source, kinds, starts, ends, if_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                    let if_condition = if_header_counter + 1
                    append_text(output, "%t")
                    append_integer(output, if_condition)
                    append_text(output, " = icmp ne i32 ")
                    append_operand(output, if_header_is_temporary, if_header_value)
                    append_text(output, ", 0\n")
                    let if_then_label = if_condition + 1
                    let if_check_label = if_condition + 2
                    let if_end_label = if_condition + 3
                    append_text(output, "br i1 %t")
                    append_integer(output, if_condition)
                    append_text(output, ", label %if.then.")
                    append_integer(output, if_then_label)
                    append_text(output, ", label %if.check.")
                    append_integer(output, if_check_label)
                    append_text(output, "\nif.then.")
                    append_integer(output, if_then_label)
                    append_text(output, ":\n")
                    let if_block_start = skip_source_newlines(source, starts, if_header_next_index + 1)
                    let if_block_indent = line_indent(source, token_start(starts, if_block_start))
                    let if_block_end = if_block_start
                    while if_block_end < body_end and is_body_line(source, kinds, starts, if_block_end, if_block_indent) == 1:
                        if_block_end = if_block_end + 1
                    let (if_block_counter, if_block_has_return) = parse_branch_body(source, kinds, starts, ends, if_block_start, if_block_end, output, variable_starts, variable_ends, variable_types, if_condition + 3, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                    if if_block_has_return == 0:
                        append_text(output, "br label %if.end.")
                        append_integer(output, if_end_label)
                        append_text(output, "\n")
                    append_text(output, "if.check.")
                    append_integer(output, if_check_label)
                    append_text(output, ":\n")
                    let branch_index = if_block_end
                    let branch_counter = if_block_counter
                    while token_kind(kinds, branch_index) == 20:
                        let elif_expression_index = branch_index + 1
                        let (elif_header_next_index, elif_header_is_temporary, elif_header_value, elif_header_counter) = parse_expression(source, kinds, starts, ends, elif_expression_index, output, variable_starts, variable_ends, variable_types, branch_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                        let elif_condition = elif_header_counter + 1
                        append_text(output, "%t")
                        append_integer(output, elif_condition)
                        append_text(output, " = icmp ne i32 ")
                        append_operand(output, elif_header_is_temporary, elif_header_value)
                        append_text(output, ", 0\n")
                        let elif_then_label = elif_condition + 1
                        let elif_check_label = elif_condition + 2
                        append_text(output, "br i1 %t")
                        append_integer(output, elif_condition)
                        append_text(output, ", label %if.then.")
                        append_integer(output, elif_then_label)
                        append_text(output, ", label %if.check.")
                        append_integer(output, elif_check_label)
                        append_text(output, "\nif.then.")
                        append_integer(output, elif_then_label)
                        append_text(output, ":\n")
                        let elif_block_start = skip_source_newlines(source, starts, elif_header_next_index + 1)
                        let elif_block_indent = line_indent(source, token_start(starts, elif_block_start))
                        let elif_block_end = elif_block_start
                        while elif_block_end < body_end and is_body_line(source, kinds, starts, elif_block_end, elif_block_indent) == 1:
                            elif_block_end = elif_block_end + 1
                        let (elif_block_counter, elif_block_has_return) = parse_branch_body(source, kinds, starts, ends, elif_block_start, elif_block_end, output, variable_starts, variable_ends, variable_types, elif_condition + 2, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                        if elif_block_has_return == 0:
                            append_text(output, "br label %if.end.")
                            append_integer(output, if_end_label)
                            append_text(output, "\n")
                        append_text(output, "if.check.")
                        append_integer(output, elif_check_label)
                        append_text(output, ":\n")
                        branch_index = elif_block_end
                        branch_counter = elif_block_counter
                    let has_else_branch = 0
                    if token_kind(kinds, branch_index) == 21:
                        has_else_branch = 1
                    if has_else_branch == 1:
                        let else_block_start = skip_source_newlines(source, starts, branch_index + 1)
                        let else_label = branch_counter + 1
                        append_text(output, "br label %if.else.")
                        append_integer(output, else_label)
                        append_text(output, "\nif.else.")
                        append_integer(output, else_label)
                        append_text(output, ":\n")
                        let else_block_indent = line_indent(source, token_start(starts, else_block_start))
                        let else_block_end = else_block_start
                        while else_block_end < body_end and is_body_line(source, kinds, starts, else_block_end, else_block_indent) == 1:
                            else_block_end = else_block_end + 1
                        let (else_block_counter, else_block_has_return) = parse_branch_body(source, kinds, starts, ends, else_block_start, else_block_end, output, variable_starts, variable_ends, variable_types, else_label, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                        if else_block_has_return == 0:
                            append_text(output, "br label %if.end.")
                            append_integer(output, if_end_label)
                            append_text(output, "\n")
                        current_index = else_block_end
                        current_counter = else_block_counter
                    if has_else_branch == 0:
                        append_text(output, "br label %if.end.")
                        append_integer(output, if_end_label)
                        append_text(output, "\n")
                        current_index = branch_index
                        current_counter = branch_counter
                    append_text(output, "if.end.")
                    append_integer(output, if_end_label)
                    append_text(output, ":\n")
                else:
                    if token_kind(kinds, current_index) == 14:
                        let return_expression_index = current_index + 1
                        if token_kind(kinds, return_expression_index) == 9:
                            let tuple_return_temporary = current_counter + 1
                            append_text(output, "%t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
                            let tuple_return_index = return_expression_index + 1
                            let tuple_return_counter = tuple_return_temporary
                            while token_kind(kinds, tuple_return_index) != 10:
                                let (tuple_component_next_index, tuple_component_type, tuple_component_value, tuple_component_counter) = parse_expression(source, kinds, starts, ends, tuple_return_index, output, variable_starts, variable_ends, variable_types, tuple_return_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                                append_text(output, "call void @append_i32(%dynarray_i32* %t")
                                append_integer(output, tuple_return_temporary)
                                append_text(output, ", i32 ")
                                append_operand(output, tuple_component_type, tuple_component_value)
                                append_text(output, ")\n")
                                tuple_return_counter = tuple_component_counter
                                tuple_return_index = tuple_component_next_index
                                if token_kind(kinds, tuple_return_index) == 16:
                                    tuple_return_index = tuple_return_index + 1
                            append_text(output, "ret %dynarray_i32* %t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, "\n")
                            current_counter = tuple_return_counter
                        if token_kind(kinds, return_expression_index) != 9:
                            let is_tuple_call = 0
                            if token_kind(kinds, return_expression_index) == 2 and token_kind(kinds, return_expression_index + 1) == 9 and function_result_type(source, token_start(starts, return_expression_index), token_end(ends, return_expression_index)) == 3:
                                is_tuple_call = 1
                            if is_tuple_call == 1:
                                let (tuple_call_next_index, tuple_call_is_temporary, tuple_call_value, tuple_call_next_counter) = parse_expression(source, kinds, starts, ends, return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                                append_text(output, "ret %dynarray_i32* ")
                                append_operand(output, tuple_call_is_temporary, tuple_call_value)
                                append_text(output, "\n")
                                current_counter = tuple_call_next_counter
                            if is_tuple_call == 0:
                                let (return_next_index, return_is_temporary, return_value, return_next_counter) = parse_expression(source, kinds, starts, ends, return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                                append_text(output, "ret i32 ")
                                append_operand(output, return_is_temporary, return_value)
                                append_text(output, "\n")
                                current_counter = return_next_counter
                        has_return = 1
                        current_index = body_end
                    else:
                        if token_kind(kinds, current_index) == 2 and token_kind(kinds, current_index + 1) == 9:
                            let call_expression_index = current_index
                            let (call_next_index, call_is_temporary, call_value, call_next_counter) = parse_expression(source, kinds, starts, ends, call_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
                            current_index = skip_source_newlines(source, starts, call_next_index)
                            current_counter = call_next_counter
                        else:
                            current_index = current_index + 1
    return (current_counter, has_return)

def emit_function(source: str, kinds: list[int], starts: list[int], ends: list[int], function_index: int, output: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int]) -> int:
    let function_output = []
    append_text(function_output, "; function_index=")
    append_integer(function_output, function_index)
    append_text(function_output, "; body_start=")
    append_integer(function_output, function_bodies[function_index])
    append_text(function_output, "; body_end=")
    append_integer(function_output, function_body_ends[function_index])
    append_text(function_output, "\n")
    let function_result_type_value = function_result_type(source, function_starts[function_index], function_ends[function_index])
    if function_result_type_value == 3:
        append_text(function_output, "define %dynarray_i32* @")
    if function_result_type_value != 3:
        append_text(function_output, "define i32 @")
    append_text(function_output, source[function_starts[function_index]:function_ends[function_index]])
    append_text(function_output, "(")
    let parameter_offset = function_param_offsets[function_index]
    let parameter_count = function_param_counts[function_index]
    let parameter_index = 0
    while parameter_index < parameter_count:
        if parameter_index > 0:
            append_text(function_output, ", ")
        let emit_parameter_position = parameter_offset + parameter_index
        if parameter_types[emit_parameter_position] == 2:
            append_text(function_output, "i8* %")
        if parameter_types[emit_parameter_position] == 3:
            append_text(function_output, "%dynarray_i32* %")
        if parameter_types[emit_parameter_position] != 2 and parameter_types[emit_parameter_position] != 3:
            append_text(function_output, "i32 %")
        append_text(function_output, source[parameter_starts[emit_parameter_position]:parameter_ends[emit_parameter_position]])
        append_text(function_output, ".param")
        parameter_index = parameter_index + 1
    append_text(function_output, ") {\nentry:\n")

    let variable_starts = []
    let variable_ends = []
    let variable_types = []
    let initialize_index = 0
    while initialize_index < parameter_count:
        let initialize_parameter_position = parameter_offset + initialize_index
        let parameter_name_start = parameter_starts[initialize_parameter_position]
        let parameter_name_end = parameter_ends[initialize_parameter_position]
        let initialize_parameter_type = parameter_types[initialize_parameter_position]
        let parameter_name = source[parameter_name_start:parameter_name_end]
        if initialize_parameter_type == 2:
            append_local_storage(function_output, parameter_name, 2)
            append_text(function_output, "store i8* %")
        if initialize_parameter_type == 3:
            append_local_storage(function_output, parameter_name, 3)
            append_text(function_output, "store %dynarray_i32* %")
        if initialize_parameter_type != 2 and initialize_parameter_type != 3:
            append_local_storage(function_output, parameter_name, 1)
            append_text(function_output, "store i32 %")
        append_text(function_output, parameter_name)
        if initialize_parameter_type == 2:
            append_text(function_output, ".param, i8** %")
        if initialize_parameter_type == 3:
            append_text(function_output, ".param, %dynarray_i32** %")
        if initialize_parameter_type != 2 and initialize_parameter_type != 3:
            append_text(function_output, ".param, i32* %")
        append_text(function_output, source[parameter_name_start:parameter_name_end])
        append_text(function_output, "\n")
        append(variable_starts, parameter_name_start)
        append(variable_ends, parameter_name_end)
        append(variable_types, initialize_parameter_type)
        initialize_index = initialize_index + 1

    let (next_counter, has_return) = parse_function_body(source, kinds, starts, ends, function_bodies[function_index], function_body_ends[function_index], function_output, variable_starts, variable_ends, variable_types, 0, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends)
    if has_return == 0:
        if function_result_type_value == 3:
            append_text(function_output, "%t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\nret %dynarray_i32* %t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, "\n")
        if function_result_type_value != 3:
            append_text(function_output, "ret i32 0\n")
    append_text(function_output, "}\n")
    append_hoisted_function(output, function_output)
    return next_counter

def compile_source(source_path: str, output_path: str):
    let source = read_text_file(source_path)
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
    collect_functions(source, kinds, starts, ends, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types)
    let output = []
    append_text(output, "; function_count=")
    append_integer(output, len(function_starts))
    append_text(output, "\n")
    append_text(output, "; Dream Stage 1 LLVM bootstrap output\n")
    append_text(output, "%dynarray_i32 = type { i32, i32, i32* }\n")
    let literal_index = 0
    while literal_index < len(kinds):
        if token_kind(kinds, literal_index) == 26:
            append_string_global(output, source, starts, ends, literal_index)
        literal_index = literal_index + 1
    append_text(output, "declare void @print_int(i32)\n")
    append_text(output, "declare void @print_string(i8*)\n")
    append_text(output, "declare i8* @malloc(i32)\n")
    append_text(output, "declare i8* @string_substring(i8*, i32, i32)\n")
    append_text(output, "declare i32 @string_compare(i8*, i8*)\n")
    append_text(output, "declare i8* @__c_file_read(i8*)\n")
    append_text(output, "declare i32 @__c_file_write_bytes(i8*, %dynarray_i32*)\n")
    append_text(output, "declare i32 @__c_utf8_rune_at(i8*, i32)\n")
    append_text(output, "declare i32 @__c_utf8_rune_count(i8*)\n")
    append_text(output, "declare %dynarray_i32* @create_dynarray_i32(i32)\n")
    append_text(output, "declare void @append_i32(%dynarray_i32*, i32)\n")
    append_text(output, "declare i32 @len_dynarray_i32(%dynarray_i32*)\n")
    append_text(output, "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n")
    append_text(output, "define i32 @append(%dynarray_i32* %array, i32 %value) {\nentry:\ncall void @append_i32(%dynarray_i32* %array, i32 %value)\nret i32 0\n}\n")
    append_text(output, "define i32 @len(%dynarray_i32* %array) {\nentry:\n%length = call i32 @len_dynarray_i32(%dynarray_i32* %array)\nret i32 %length\n}\n")
    append_text(output, "define i32 @get(%dynarray_i32* %array, i32 %index) {\nentry:\n%length = call i32 @len_dynarray_i32(%dynarray_i32* %array)\n%valid_low = icmp sge i32 %index, 0\n%valid_high = icmp slt i32 %index, %length\n%valid = and i1 %valid_low, %valid_high\nbr i1 %valid, label %get.valid, label %get.invalid\nget.valid:\n%value = call i32 @get_dynarray_i32(%dynarray_i32* %array, i32 %index)\nret i32 %value\nget.invalid:\nret i32 0\n}\n")
    append_text(output, "define i8* @read_text_file(i8* %path) {\nentry:\n%content = call i8* @__c_file_read(i8* %path)\nret i8* %content\n}\n")
    append_text(output, "define i32 @text_char_code(i8* %content, i32 %index) {\nentry:\n%byte_pointer = getelementptr i8, i8* %content, i32 %index\n%byte = load i8, i8* %byte_pointer\n%code = zext i8 %byte to i32\nret i32 %code\n}\n")
    append_text(output, "define i32 @text_length(i8* %content) {\nentry:\n%length = call i32 @__c_utf8_rune_count(i8* %content)\nret i32 %length\n}\n")
    append_text(output, "define i32 @write_text_codes(i8* %path, %dynarray_i32* %codes) {\nentry:\n%result = call i32 @__c_file_write_bytes(i8* %path, %dynarray_i32* %codes)\nret i32 %result\n}\n")
    let function_index = 0
    while function_index < len(function_starts):
        emit_function(source, kinds, starts, ends, function_index, output, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, parameter_types)
        function_index = function_index + 1
    write_text_codes(output_path, output)

def main():
    compile_source("bootstrap/sample_functions.dm", "bootstrap/stage1.ll")
    compile_source("bootstrap/compiler.dm", "bootstrap/stage2.ll")
    compile_source("bootstrap/compiler.dm", "bootstrap/stage3.ll")
