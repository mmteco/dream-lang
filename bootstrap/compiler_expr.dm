def parse_index_operand(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == TOKEN_INTEGER:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    let operand_temporary = temporary_counter + 1
    let operand_variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    let operand_variable_type = VALUE_TYPE_INT
    if operand_variable_index >= 0:
        operand_variable_type = variable_types[operand_variable_index]
    append_text(output, "%t")
    append_integer(output, operand_temporary)
    append_text(output, " = load i32, i32* ")
    append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], operand_variable_type)
    append_text(output, "\n")
    return (index + 1, 1, operand_temporary, operand_temporary)

def parse_index_atom(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let (operator_index, first_is_temporary, first_value, first_counter) = parse_index_operand(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let operator_kind = token_kind(kinds, operator_index)
    if operator_kind != TOKEN_PLUS and operator_kind != TOKEN_MINUS:
        return (operator_index, first_is_temporary, first_value, first_counter)
    let (next_index, second_is_temporary, second_value, second_counter) = parse_index_operand(source, kinds, starts, ends, operator_index + 1, output, variable_starts, variable_ends, variable_types, first_counter)
    let result_temporary = second_counter + 1
    append_text(output, "%t")
    append_integer(output, result_temporary)
    if operator_kind == TOKEN_PLUS:
        append_text(output, " = add i32 ")
    if operator_kind == TOKEN_MINUS:
        append_text(output, " = sub i32 ")
    append_operand(output, first_is_temporary, first_value)
    append_text(output, ", ")
    append_operand(output, second_is_temporary, second_value)
    append_text(output, "\n")
    return (next_index, 1, result_temporary, result_temporary)

def parse_position_call(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let call_name_start = token_start(starts, index)
    let call_name_end = token_end(ends, index)
    let list_argument_index = index + 2
    let list_variable_index = find_variable(source, token_start(starts, list_argument_index), token_end(ends, list_argument_index), variable_starts, variable_ends)
    let list_variable_type = VALUE_TYPE_LIST
    if list_variable_index >= 0:
        list_variable_type = variable_types[list_variable_index]
    let list_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, list_temporary)
    append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
    append_variable_reference(output, source[token_start(starts, list_argument_index):token_end(ends, list_argument_index)], list_variable_type)
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
    if source[name_start:name_end] == "ord":
        let (ord_argument_index, ord_argument_type, ord_argument_value, ord_argument_counter) = parse_argument_atom(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return (ord_argument_index + 1, ord_argument_type, ord_argument_value, ord_argument_counter)
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
    while argument_index < len(kinds) and source[token_start(starts, argument_index)] != ')' and argument_steps < 16:
        let parsed_argument = false
        let parsed_argument_type = VALUE_TYPE_IMMEDIATE
        let parsed_argument_value = 0
        let parsed_argument_index = argument_index + 1
        let parsed_argument_counter = argument_counter
        if token_kind(kinds, argument_index) == TOKEN_INTEGER:
            parsed_argument = true
            parsed_argument_value = parse_integer(source, token_start(starts, argument_index), token_end(ends, argument_index))
        if token_kind(kinds, argument_index) == TOKEN_STRING:
            let string_argument_temporary = argument_counter + 1
            append_string_pointer(output, source, starts, ends, argument_index, string_argument_temporary)
            parsed_argument = true
            parsed_argument_type = VALUE_TYPE_STRING
            parsed_argument_value = string_argument_temporary
            parsed_argument_counter = string_argument_temporary
        let is_call_argument = false
        if token_kind(kinds, argument_index) == TOKEN_IDENTIFIER:
            if token_kind(kinds, argument_index + 1) == TOKEN_OPEN_PAREN:
                is_call_argument = true
        if is_call_argument:
            let argument_name = source[token_start(starts, argument_index):token_end(ends, argument_index)]
            let is_position_call = false
            if argument_name == "token_start":
                is_position_call = true
            if argument_name == "token_end":
                is_position_call = true
            if is_position_call:
                let (position_next_index, position_type, position_value, position_counter) = parse_position_call(source, kinds, starts, ends, argument_index, output, variable_starts, variable_ends, variable_types, argument_counter)
                parsed_argument_index = position_next_index
                parsed_argument_type = position_type
                parsed_argument_value = position_value
                parsed_argument_counter = position_counter
            if not is_position_call:
                let nested_name_start = token_start(starts, argument_index)
                let nested_name_end = token_end(ends, argument_index)
                let nested_argument_flags = []
                let nested_argument_values = []
                let nested_argument_index = argument_index + 2
                let nested_argument_counter = argument_counter
                while token_kind(kinds, nested_argument_index) != TOKEN_CLOSE_PAREN:
                    let nested_argument_type = VALUE_TYPE_IMMEDIATE
                    let nested_argument_value = 0
                    let nested_argument_next_index = nested_argument_index + 1
                    if token_kind(kinds, nested_argument_index) == TOKEN_INTEGER:
                        nested_argument_value = parse_integer(source, token_start(starts, nested_argument_index), token_end(ends, nested_argument_index))
                    if token_kind(kinds, nested_argument_index) == TOKEN_RUNE:
                        nested_argument_value = parse_rune_literal(source, token_start(starts, nested_argument_index), token_end(ends, nested_argument_index))
                    if token_kind(kinds, nested_argument_index) == TOKEN_STRING:
                        let nested_string_literal_temporary = nested_argument_counter + 1
                        append_string_pointer(output, source, starts, ends, nested_argument_index, nested_string_literal_temporary)
                        nested_argument_type = VALUE_TYPE_STRING
                        nested_argument_value = nested_string_literal_temporary
                        nested_argument_counter = nested_string_literal_temporary
                    let nested_is_position_call = false
                    if token_kind(kinds, nested_argument_index) == TOKEN_IDENTIFIER and token_kind(kinds, nested_argument_index + 1) == TOKEN_OPEN_PAREN:
                        let nested_argument_name = source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)]
                        if nested_argument_name == "token_start" or nested_argument_name == "token_end":
                            nested_is_position_call = true
                    let nested_is_ord_call = false
                    if token_kind(kinds, nested_argument_index) == TOKEN_IDENTIFIER and token_kind(kinds, nested_argument_index + 1) == TOKEN_OPEN_PAREN:
                        let ord_nested_argument_name = source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)]
                        if ord_nested_argument_name == "ord":
                            nested_is_ord_call = true
                    if nested_is_position_call:
                        let (nested_position_next_index, nested_position_type, nested_position_value, nested_position_counter) = parse_position_call(source, kinds, starts, ends, nested_argument_index, output, variable_starts, variable_ends, variable_types, nested_argument_counter)
                        nested_argument_next_index = nested_position_next_index
                        nested_argument_type = nested_position_type
                        nested_argument_value = nested_position_value
                        nested_argument_counter = nested_position_counter
                    if nested_is_ord_call:
                        let (nested_ord_argument_next_index, nested_ord_argument_type, nested_ord_argument_value, nested_ord_argument_counter) = parse_argument_atom(source, kinds, starts, ends, nested_argument_index, output, variable_starts, variable_ends, variable_types, nested_argument_counter)
                        nested_argument_next_index = nested_ord_argument_next_index
                        nested_argument_type = nested_ord_argument_type
                        nested_argument_value = nested_ord_argument_value
                        nested_argument_counter = nested_ord_argument_counter
                    if token_kind(kinds, nested_argument_index) == TOKEN_IDENTIFIER and not nested_is_position_call and not nested_is_ord_call:
                        let nested_variable_index = find_variable(source, token_start(starts, nested_argument_index), token_end(ends, nested_argument_index), variable_starts, variable_ends)
                        let nested_string_variable = false
                        let nested_list_variable = false
                        if nested_variable_index >= 0:
                            if variable_types[nested_variable_index] == VALUE_TYPE_STRING:
                                nested_string_variable = true
                            if variable_types[nested_variable_index] == VALUE_TYPE_LIST:
                                nested_list_variable = true
                        if nested_string_variable:
                            let nested_string_variable_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_string_variable_temporary)
                            append_text(output, " = load i8*, i8** ")
                            append_variable_reference(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)], variable_types[nested_variable_index])
                            append_text(output, "\n")
                            nested_argument_type = VALUE_TYPE_STRING
                            nested_argument_value = nested_string_variable_temporary
                            nested_argument_counter = nested_string_variable_temporary
                        if nested_list_variable:
                            let nested_list_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_list_temporary)
                            append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
                            append_variable_reference(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)], variable_types[nested_variable_index])
                            append_text(output, "\n")
                            nested_argument_type = VALUE_TYPE_LIST
                            nested_argument_value = nested_list_temporary
                            nested_argument_counter = nested_list_temporary
                        if not nested_string_variable and not nested_list_variable:
                            let nested_integer_temporary = nested_argument_counter + 1
                            append_text(output, "%t")
                            append_integer(output, nested_integer_temporary)
                            append_text(output, " = load i32, i32* ")
                            let nested_variable_type = VALUE_TYPE_INT
                            if nested_variable_index >= 0:
                                nested_variable_type = variable_types[nested_variable_index]
                            append_variable_reference(output, source[token_start(starts, nested_argument_index):token_end(ends, nested_argument_index)], nested_variable_type)
                            append_text(output, "\n")
                            nested_argument_type = VALUE_TYPE_INT
                            nested_argument_value = nested_integer_temporary
                            nested_argument_counter = nested_integer_temporary
                    append(nested_argument_flags, nested_argument_type)
                    append(nested_argument_values, nested_argument_value)
                    nested_argument_index = nested_argument_next_index
                    if token_kind(kinds, nested_argument_index) == TOKEN_COMMA:
                        nested_argument_index = nested_argument_index + 1
                let nested_result_temporary = nested_argument_counter + 1
                let nested_result_type = VALUE_TYPE_INT
                if source[nested_name_start:nested_name_end] == "read_text_file" or source[nested_name_start:nested_name_end] == "string_substring" or source[nested_name_start:nested_name_end] == "string_concat" or source[nested_name_start:nested_name_end] == "__c_file_read":
                    nested_result_type = VALUE_TYPE_STRING
                append_text(output, "%t")
                append_integer(output, nested_result_temporary)
                if nested_result_type == VALUE_TYPE_STRING:
                    append_text(output, " = call i8* @")
                if nested_result_type != VALUE_TYPE_STRING:
                    append_text(output, " = call i32 @")
                append_text(output, source[nested_name_start:nested_name_end])
                append_text(output, "(")
                let nested_output_index = 0
                while nested_output_index < len(nested_argument_values):
                    if nested_output_index > 0:
                        append_text(output, ", ")
                    if nested_argument_flags[nested_output_index] == VALUE_TYPE_STRING:
                        append_text(output, "i8* ")
                    if nested_argument_flags[nested_output_index] == VALUE_TYPE_LIST:
                        append_text(output, "%dynarray_i32* ")
                    if nested_argument_flags[nested_output_index] == VALUE_TYPE_INT:
                        append_text(output, "i32 ")
                    append_operand(output, nested_argument_flags[nested_output_index], nested_argument_values[nested_output_index])
                    nested_output_index = nested_output_index + 1
                append_text(output, ")\n")
                parsed_argument_index = nested_argument_index + 1
                parsed_argument_type = nested_result_type
                parsed_argument_value = nested_result_temporary
                parsed_argument_counter = nested_result_temporary
            parsed_argument = true
        if not parsed_argument:
            let argument_variable_index = find_variable(source, token_start(starts, argument_index), token_end(ends, argument_index), variable_starts, variable_ends)
            let is_string_variable = false
            let is_list_variable = false
            if argument_variable_index >= 0:
                if variable_types[argument_variable_index] == VALUE_TYPE_STRING:
                    is_string_variable = true
                if variable_types[argument_variable_index] == VALUE_TYPE_LIST:
                    is_list_variable = true
            if is_string_variable:
                let loaded_string_temporary = argument_counter + 1
                append_text(output, "%t")
                append_integer(output, loaded_string_temporary)
                append_text(output, " = load i8*, i8** ")
                append_variable_reference(output, source[token_start(starts, argument_index):token_end(ends, argument_index)], variable_types[argument_variable_index])
                append_text(output, "\n")
                parsed_argument_type = VALUE_TYPE_STRING
                parsed_argument_value = loaded_string_temporary
                parsed_argument_counter = loaded_string_temporary
                if token_kind(kinds, argument_index + 1) == TOKEN_OPEN_BRACKET:
                    let (rune_index_next, rune_index_type, rune_index_value, rune_index_counter) = parse_slice_endpoint(source, kinds, starts, ends, argument_index + 2, output, variable_starts, variable_ends, variable_types, loaded_string_temporary)
                    if token_kind(kinds, rune_index_next) == TOKEN_CLOSE_BRACKET:
                        let rune_temporary = rune_index_counter + 1
                        append_text(output, "%t")
                        append_integer(output, rune_temporary)
                        append_text(output, " = call i32 @__c_utf8_rune_at(i8* %t")
                        append_integer(output, loaded_string_temporary)
                        append_text(output, ", i32 ")
                        append_operand(output, rune_index_type, rune_index_value)
                        append_text(output, ")\n")
                        parsed_argument_index = rune_index_next + 1
                        parsed_argument_type = VALUE_TYPE_INT
                        parsed_argument_value = rune_temporary
                        parsed_argument_counter = rune_temporary
            if is_list_variable:
                let loaded_list_temporary = argument_counter + 1
                append_text(output, "%t")
                append_integer(output, loaded_list_temporary)
                append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
                append_variable_reference(output, source[token_start(starts, argument_index):token_end(ends, argument_index)], variable_types[argument_variable_index])
                append_text(output, "\n")
                parsed_argument_type = VALUE_TYPE_LIST
                parsed_argument_value = loaded_list_temporary
                parsed_argument_counter = loaded_list_temporary
            if not is_string_variable:
                if not is_list_variable:
                    let loaded_integer_temporary = argument_counter + 1
                    append_text(output, "%t")
                    append_integer(output, loaded_integer_temporary)
                    append_text(output, " = load i32, i32* ")
                    let loaded_variable_type = VALUE_TYPE_INT
                    if argument_variable_index >= 0:
                        loaded_variable_type = variable_types[argument_variable_index]
                    append_variable_reference(output, source[token_start(starts, argument_index):token_end(ends, argument_index)], loaded_variable_type)
                    append_text(output, "\n")
                    parsed_argument_type = VALUE_TYPE_INT
                    parsed_argument_value = loaded_integer_temporary
                    parsed_argument_counter = loaded_integer_temporary
            parsed_argument = true
        argument_index = parsed_argument_index
        argument_counter = parsed_argument_counter
        append(argument_temporary_flags, parsed_argument_type)
        append(argument_values, parsed_argument_value)
        if source[token_start(starts, argument_index)] == ',':
            argument_index = argument_index + 1
        argument_steps = argument_steps + 1
    let result_temporary = argument_counter + 1
    let call_result_type = VALUE_TYPE_INT
    if source[name_start:name_end] == "read_text_file" or source[name_start:name_end] == "string_substring" or source[name_start:name_end] == "string_concat" or source[name_start:name_end] == "__c_file_read" or source[name_start:name_end] == "module_path" or source[name_start:name_end] == "append_imported_module" or source[name_start:name_end] == "load_imported_source":
        call_result_type = VALUE_TYPE_STRING
    if source[name_start:name_end] == "parse_nested_call":
        call_result_type = VALUE_TYPE_LIST
    append_text(output, "%t")
    append_integer(output, result_temporary)
    if call_result_type == VALUE_TYPE_STRING:
        append_text(output, " = call i8* @")
    if call_result_type == VALUE_TYPE_LIST:
        append_text(output, " = call %dynarray_i32* @")
    if call_result_type != VALUE_TYPE_STRING:
        if call_result_type != VALUE_TYPE_LIST:
            append_text(output, " = call i32 @")
    append_text(output, source[name_start:name_end])
    append_text(output, "(")
    let output_argument_index = 0
    while output_argument_index < len(argument_values):
        if output_argument_index > 0:
            append_text(output, ", ")
        let output_argument_is_string = false
        let output_argument_is_list = false
        if argument_temporary_flags[output_argument_index] == VALUE_TYPE_STRING:
            output_argument_is_string = true
        if argument_temporary_flags[output_argument_index] == VALUE_TYPE_LIST:
            output_argument_is_list = true
        if output_argument_is_string:
            append_text(output, "i8* ")
        if output_argument_is_list:
            append_text(output, "%dynarray_i32* ")
        if not output_argument_is_string:
            if not output_argument_is_list:
                append_text(output, "i32 ")
        append_operand(output, argument_temporary_flags[output_argument_index], argument_values[output_argument_index])
        output_argument_index = output_argument_index + 1
    append_text(output, ")\n")
    return (argument_index + 1, call_result_type, result_temporary, result_temporary)

def is_known_list_variable(source: str, name_start: int, name_end: int) -> bool:
    if source[name_start:name_end] == "argument_temporary_flags":
        return true
    if source[name_start:name_end] == "argument_values":
        return true
    if source[name_start:name_end] == "tuple_name_starts":
        return true
    if source[name_start:name_end] == "tuple_name_ends":
        return true
    return false

def variable_type_at(variable_types: list[int], variable_index: int) -> int:
    if variable_index < 0 or variable_index >= len(variable_types):
        return VALUE_TYPE_INT
    return variable_types[variable_index]

def variable_is_function_value(variable_types: list[int], variable_index: int) -> bool:
    if variable_index < 0 or variable_index >= len(variable_types):
        return false
    return is_function_value_type(variable_types[variable_index])

def variable_is_dictionary(variable_types: list[int], variable_index: int) -> bool:
    if variable_index < 0 or variable_index >= len(variable_types):
        return false
    return is_dictionary_value_type(variable_types[variable_index])

def parse_slice_endpoint(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == TOKEN_INTEGER:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    if token_kind(kinds, index) == TOKEN_RUNE:
        let rune_value = parse_rune_literal(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, rune_value, temporary_counter)
    if token_kind(kinds, index + 1) == TOKEN_PLUS or token_kind(kinds, index + 1) == TOKEN_MINUS:
        return parse_index_atom(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let endpoint_variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    let endpoint_variable_type = VALUE_TYPE_INT
    if endpoint_variable_index >= 0:
        endpoint_variable_type = variable_types[endpoint_variable_index]
    let is_list_endpoint = false
    if endpoint_variable_index >= 0:
        if variable_types[endpoint_variable_index] == VALUE_TYPE_LIST:
            is_list_endpoint = true
    if is_known_list_variable(source, token_start(starts, index), token_end(ends, index)):
        is_list_endpoint = true
    if is_list_endpoint and token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
        let endpoint_list_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, endpoint_list_temporary)
        append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
        append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], endpoint_variable_type)
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
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and token_kind(kinds, index + 1) == TOKEN_OPEN_PAREN:
        let argument_name = source[token_start(starts, index):token_end(ends, index)]
        if argument_name == "token_start" or argument_name == "token_end":
            return parse_position_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return parse_nested_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let endpoint_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, endpoint_temporary)
    append_text(output, " = load i32, i32* ")
    append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], endpoint_variable_type)
    append_text(output, "\n")
    return (index + 1, 1, endpoint_temporary, endpoint_temporary)

def parse_integer_list_comprehension(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let expression_index = index + 1
    let loop_name_index = index + 3
    let source_name_index = index + 5
    let condition_keyword_index = source_name_index + 1
    let has_condition = false
    if token_kind(kinds, condition_keyword_index) == TOKEN_IF:
        has_condition = true
    let loop_name_start = token_start(starts, loop_name_index)
    let loop_name_end = token_end(ends, loop_name_index)
    let source_name_start = token_start(starts, source_name_index)
    let source_name_end = token_end(ends, source_name_index)
    let source_variable_index = find_variable(source, source_name_start, source_name_end, variable_starts, variable_ends)
    let source_variable_type = VALUE_TYPE_LIST
    if source_variable_index >= 0:
        source_variable_type = variable_types[source_variable_index]
    let loop_label = temporary_counter + 1
    let list_temporary = loop_label + 1
    let source_temporary = list_temporary + 1
    let index_temporary = source_temporary + 1
    let length_temporary = index_temporary + 1
    let condition_temporary = length_temporary + 1
    let element_temporary = condition_temporary + 1
    append_text(output, "%t")
    append_integer(output, list_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
    append_text(output, "%t")
    append_integer(output, source_temporary)
    append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
    append_variable_reference(output, source[source_name_start:source_name_end], source_variable_type)
    append_text(output, "\n")
    append_text(output, "%comp.index.")
    append_integer(output, loop_label)
    append_text(output, " = alloca i32\nstore i32 0, i32* %comp.index.")
    append_integer(output, loop_label)
    append_text(output, "\nbr label %comp.check.")
    append_integer(output, loop_label)
    append_text(output, "\ncomp.check.")
    append_integer(output, loop_label)
    append_text(output, ":\n%t")
    append_integer(output, index_temporary)
    append_text(output, " = load i32, i32* %comp.index.")
    append_integer(output, loop_label)
    append_text(output, "\n%t")
    append_integer(output, length_temporary)
    append_text(output, " = call i32 @len(%dynarray_i32* %t")
    append_integer(output, source_temporary)
    append_text(output, ")\n%t")
    append_integer(output, condition_temporary)
    append_text(output, " = icmp slt i32 %t")
    append_integer(output, index_temporary)
    append_text(output, ", %t")
    append_integer(output, length_temporary)
    append_text(output, "\nbr i1 %t")
    append_integer(output, condition_temporary)
    append_text(output, ", label %comp.body.")
    append_integer(output, loop_label)
    append_text(output, ", label %comp.end.")
    append_integer(output, loop_label)
    append_text(output, "\ncomp.body.")
    append_integer(output, loop_label)
    append_text(output, ":\n%t")
    append_integer(output, element_temporary)
    append_text(output, " = call i32 @get(%dynarray_i32* %t")
    append_integer(output, source_temporary)
    append_text(output, ", i32 %t")
    append_integer(output, index_temporary)
    append_text(output, ")\n")
    let existing_loop_variable_index = find_variable(source, loop_name_start, loop_name_end, variable_starts, variable_ends)
    if existing_loop_variable_index == -1:
        append_local_storage(output, source[loop_name_start:loop_name_end], 1)
    append_text(output, "store i32 %t")
    append_integer(output, element_temporary)
    append_text(output, ", i32* %")
    append_text(output, source[loop_name_start:loop_name_end])
    append_text(output, "\n")
    append(variable_starts, loop_name_start)
    append(variable_ends, loop_name_end)
    append(variable_types, VALUE_TYPE_INT)
    let comprehension_counter = element_temporary
    if has_condition:
        let condition_expression_index = condition_keyword_index + 1
        let (condition_left_index, condition_left_type, condition_left_value, condition_left_counter) = parse_argument_expression(source, kinds, starts, ends, condition_expression_index, output, variable_starts, variable_ends, variable_types, comprehension_counter)
        let condition_operator = token_kind(kinds, condition_left_index)
        let (condition_right_index, condition_right_type, condition_right_value, condition_right_counter) = parse_argument_expression(source, kinds, starts, ends, condition_left_index + 1, output, variable_starts, variable_ends, variable_types, condition_left_counter)
        let condition_result_temporary = condition_right_counter + 1
        append_text(output, "%t")
        append_integer(output, condition_result_temporary)
        if condition_operator == TOKEN_GREATER:
            append_text(output, " = icmp sgt i32 ")
        if condition_operator == TOKEN_GREATER_EQUAL:
            append_text(output, " = icmp sge i32 ")
        if condition_operator == TOKEN_LESS:
            append_text(output, " = icmp slt i32 ")
        if condition_operator == TOKEN_LESS_EQUAL:
            append_text(output, " = icmp sle i32 ")
        if condition_operator == TOKEN_EQUAL:
            append_text(output, " = icmp eq i32 ")
        if condition_operator == TOKEN_NOT_EQUAL:
            append_text(output, " = icmp ne i32 ")
        append_operand(output, condition_left_type, condition_left_value)
        append_text(output, ", ")
        append_operand(output, condition_right_type, condition_right_value)
        append_text(output, "\nbr i1 %t")
        append_integer(output, condition_result_temporary)
        append_text(output, ", label %comp.append.")
        append_integer(output, loop_label)
        append_text(output, ", label %comp.next.")
        append_integer(output, loop_label)
        append_text(output, "\ncomp.append.")
        append_integer(output, loop_label)
        append_text(output, ":\n")
        comprehension_counter = condition_result_temporary
    let (element_next_index, element_type, element_value, element_next_counter) = parse_argument_expression(source, kinds, starts, ends, expression_index, output, variable_starts, variable_ends, variable_types, comprehension_counter)
    append_text(output, "call void @append_i32(%dynarray_i32* %t")
    append_integer(output, list_temporary)
    append_text(output, ", i32 ")
    append_operand(output, element_type, element_value)
    append_text(output, ")\nbr label %comp.next.")
    append_integer(output, loop_label)
    append_text(output, "\ncomp.next.")
    append_integer(output, loop_label)
    append_text(output, ":\n%t")
    append_integer(output, element_next_counter + 1)
    append_text(output, " = add i32 %t")
    append_integer(output, index_temporary)
    append_text(output, ", 1\nstore i32 %t")
    append_integer(output, element_next_counter + 1)
    append_text(output, ", i32* %comp.index.")
    append_integer(output, loop_label)
    append_text(output, "\nbr label %comp.check.")
    append_integer(output, loop_label)
    append_text(output, "\ncomp.end.")
    append_integer(output, loop_label)
    append_text(output, ":\n")
    let closing_index = element_next_index
    while token_kind(kinds, closing_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, closing_index) != TOKEN_EOF:
        closing_index = closing_index + 1
    return (closing_index + 1, 3, list_temporary, element_next_counter + 1)

def parse_integer_list_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index + 2) == TOKEN_FOR:
        return parse_integer_list_comprehension(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let list_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, list_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
    let element_index = index + 1
    let element_counter = list_temporary
    let element_steps = 0
    while token_kind(kinds, element_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, element_index) != TOKEN_EOF and element_steps < 32:
        let (element_next_index, element_type, element_value, element_next_counter) = parse_argument_expression(source, kinds, starts, ends, element_index, output, variable_starts, variable_ends, variable_types, element_counter)
        if element_type == VALUE_TYPE_IMMEDIATE or element_type == VALUE_TYPE_INT:
            append_text(output, "call void @append_i32(%dynarray_i32* %t")
            append_integer(output, list_temporary)
            append_text(output, ", i32 ")
            append_operand(output, element_type, element_value)
            append_text(output, ")\n")
        element_index = element_next_index
        element_counter = element_next_counter
        if token_kind(kinds, element_index) == TOKEN_COMMA:
            element_index = element_index + 1
        element_steps = element_steps + 1
    return (element_index + 1, 3, list_temporary, element_counter)

def parse_integer_tuple_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let tuple_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, tuple_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
    let element_index = index + 1
    let element_counter = tuple_temporary
    let element_steps = 0
    while token_kind(kinds, element_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, element_index) != TOKEN_EOF and element_steps < 32:
        let (element_next_index, element_type, element_value, element_next_counter) = parse_argument_expression(source, kinds, starts, ends, element_index, output, variable_starts, variable_ends, variable_types, element_counter)
        if element_type == VALUE_TYPE_IMMEDIATE or element_type == VALUE_TYPE_INT:
            append_text(output, "call void @append_i32(%dynarray_i32* %t")
            append_integer(output, tuple_temporary)
            append_text(output, ", i32 ")
            append_operand(output, element_type, element_value)
            append_text(output, ")\n")
        element_index = element_next_index
        element_counter = element_next_counter
        if token_kind(kinds, element_index) == TOKEN_COMMA:
            element_index = element_index + 1
        element_steps = element_steps + 1
    return (element_index + 1, 3, tuple_temporary, element_counter)

def parse_integer_dict_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let pair_keys = []
    let pair_key_types = []
    let pair_values = []
    let pair_value_types = []
    let pair_cursor = index + 1
    let pair_counter = temporary_counter
    while token_kind(kinds, pair_cursor) != TOKEN_CLOSE_BRACE and token_kind(kinds, pair_cursor) != TOKEN_EOF:
        let (key_next_index, key_type, key_value, key_counter) = parse_argument_atom(source, kinds, starts, ends, pair_cursor, output, variable_starts, variable_ends, variable_types, pair_counter)
        let (value_next_index, value_type, value_value, value_counter) = parse_argument_expression(source, kinds, starts, ends, key_next_index + 1, output, variable_starts, variable_ends, variable_types, key_counter)
        append(pair_keys, key_value)
        append(pair_key_types, key_type)
        append(pair_values, value_value)
        append(pair_value_types, value_type)
        pair_counter = value_counter
        pair_cursor = value_next_index
        if token_kind(kinds, pair_cursor) == TOKEN_COMMA:
            pair_cursor = pair_cursor + 1
    let dictionary_type = VALUE_TYPE_DICT_INT_INT
    if len(pair_key_types) > 0:
        if pair_key_types[0] == VALUE_TYPE_IMMEDIATE and pair_value_types[0] == VALUE_TYPE_STRING:
            dictionary_type = VALUE_TYPE_DICT_INT_STRING
        if pair_key_types[0] == VALUE_TYPE_STRING and pair_value_types[0] == VALUE_TYPE_IMMEDIATE:
            dictionary_type = VALUE_TYPE_DICT_STRING_INT
        if pair_key_types[0] == VALUE_TYPE_STRING and pair_value_types[0] == VALUE_TYPE_STRING:
            dictionary_type = VALUE_TYPE_DICT_STRING_STRING
    let dictionary_temporary = pair_counter + 1
    append_text(output, "%t")
    append_integer(output, dictionary_temporary)
    if dictionary_type == VALUE_TYPE_DICT_INT_INT:
        append_text(output, " = call %dict_t* @dream_dict_create_int_int(i32 8)\n")
    if dictionary_type == VALUE_TYPE_DICT_INT_STRING:
        append_text(output, " = call %dict_t* @dream_dict_create_int_str(i32 8)\n")
    if dictionary_type == VALUE_TYPE_DICT_STRING_INT:
        append_text(output, " = call %dict_t* @dream_dict_create_str_int(i32 8)\n")
    if dictionary_type == VALUE_TYPE_DICT_STRING_STRING:
        append_text(output, " = call %dict_t* @dream_dict_create_str_str(i32 8)\n")
    let pair_index = 0
    while pair_index < len(pair_keys):
        if dictionary_type == VALUE_TYPE_DICT_INT_INT:
            append_text(output, "call void @dict_set_int_int(%dict_t* %t")
        if dictionary_type == VALUE_TYPE_DICT_INT_STRING:
            append_text(output, "call void @dict_set_int_str(%dict_t* %t")
        if dictionary_type == VALUE_TYPE_DICT_STRING_INT:
            append_text(output, "call void @dict_set_str_int(%dict_t* %t")
        if dictionary_type == VALUE_TYPE_DICT_STRING_STRING:
            append_text(output, "call void @dict_set_str_str(%dict_t* %t")
        append_integer(output, dictionary_temporary)
        append_text(output, ", ")
        if pair_key_types[pair_index] == VALUE_TYPE_STRING:
            append_text(output, "i8* ")
        if pair_key_types[pair_index] != VALUE_TYPE_STRING:
            append_text(output, "i32 ")
        append_operand(output, pair_key_types[pair_index], pair_keys[pair_index])
        append_text(output, ", ")
        if pair_value_types[pair_index] == VALUE_TYPE_STRING:
            append_text(output, "i8* ")
        if pair_value_types[pair_index] != VALUE_TYPE_STRING:
            append_text(output, "i32 ")
        append_operand(output, pair_value_types[pair_index], pair_values[pair_index])
        append_text(output, ")\n")
        pair_index = pair_index + 1
    return (pair_cursor + 1, dictionary_type, dictionary_temporary, dictionary_temporary)

def struct_field_index(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name_start: int, struct_name_end: int, field_name_start: int, field_name_end: int) -> int:
    let token_index = 0
    while token_index < len(kinds):
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "struct":
            let declaration_name_index = token_index + 1
            if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, declaration_name_index), token_end(ends, declaration_name_index), struct_name_start, struct_name_end):
                let field_token_index = declaration_name_index + 1
                let header_index = field_token_index
                while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
                    header_index = header_index + 1
                let field_index = 0
                let current_field_index = header_index + 1
                while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF:
                    if token_kind(kinds, current_field_index) == TOKEN_DEF or token_kind(kinds, current_field_index) == TOKEN_CONST or (token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and (source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "struct" or source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "enum")):
                        return -1
                    if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
                        if source_ranges_equal(source, token_start(starts, current_field_index), token_end(ends, current_field_index), field_name_start, field_name_end):
                            return field_index
                        field_index = field_index + 1
                    current_field_index = current_field_index + 1
        token_index = token_index + 1
    return -1

def struct_field_count(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name_start: int, struct_name_end: int) -> int:
    let token_index = 0
    while token_index < len(kinds):
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "struct":
            let declaration_name_index = token_index + 1
            if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, declaration_name_index), token_end(ends, declaration_name_index), struct_name_start, struct_name_end):
                let header_index = declaration_name_index + 1
                while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
                    header_index = header_index + 1
                let field_count = 0
                let current_field_index = header_index + 1
                while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF:
                    if token_kind(kinds, current_field_index) == TOKEN_DEF or token_kind(kinds, current_field_index) == TOKEN_CONST or (token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and (source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "struct" or source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "enum")):
                        return field_count
                    if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
                        field_count = field_count + 1
                    current_field_index = current_field_index + 1
                return field_count
        token_index = token_index + 1
    return 0

def struct_any_field_index(source: str, kinds: list[int], starts: list[int], ends: list[int], field_name_start: int, field_name_end: int) -> int:
    let token_index = 0
    while token_index < len(kinds):
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "struct":
            let declaration_name_index = token_index + 1
            let header_index = declaration_name_index + 1
            while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
                header_index = header_index + 1
            let field_index = 0
            let current_field_index = header_index + 1
            let field_scan_done = false
            while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF and not field_scan_done:
                if token_kind(kinds, current_field_index) == TOKEN_DEF or token_kind(kinds, current_field_index) == TOKEN_CONST or (token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and (source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "struct" or source[token_start(starts, current_field_index):token_end(ends, current_field_index)] == "enum")):
                    field_scan_done = true
                if not field_scan_done:
                    if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
                        if source_ranges_equal(source, token_start(starts, current_field_index), token_end(ends, current_field_index), field_name_start, field_name_end):
                            return field_index
                        field_index = field_index + 1
                    current_field_index = current_field_index + 1
        token_index = token_index + 1
    return -1

def is_enum_scan_boundary(source: str, kinds: list[int], starts: list[int], ends: list[int], token_index: int) -> bool:
    switch token_kind(kinds, token_index):
        case TOKEN_DEF:
            return true
        case TOKEN_CONST:
            return true
        case TOKEN_IDENTIFIER:
            let name_start = token_start(starts, token_index)
            let name_end = token_end(ends, token_index)
            if source[name_start:name_end] == "struct":
                return true
            if source[name_start:name_end] == "enum":
                return true
    return false

def enum_variant_tag(source: str, kinds: list[int], starts: list[int], ends: list[int], enum_name_start: int, enum_name_end: int, variant_name_start: int, variant_name_end: int) -> int:
    let token_index = 0
    while token_index < len(kinds):
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "enum":
            let declaration_name_index = token_index + 1
            if token_kind(kinds, declaration_name_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, declaration_name_index), token_end(ends, declaration_name_index), enum_name_start, enum_name_end):
                let header_index = declaration_name_index + 1
                while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
                    header_index = header_index + 1
                let variant_index = 0
                let current_variant_index = header_index + 1
                let variant_scan_done = false
                while current_variant_index < len(kinds) and token_kind(kinds, current_variant_index) != TOKEN_EOF and not variant_scan_done:
                    if is_enum_scan_boundary(source, kinds, starts, ends, current_variant_index):
                        variant_scan_done = true
                    if not variant_scan_done:
                        if token_kind(kinds, current_variant_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_variant_index + 1) == TOKEN_OPEN_PAREN:
                            if source_ranges_equal(source, token_start(starts, current_variant_index), token_end(ends, current_variant_index), variant_name_start, variant_name_end):
                                return variant_index
                            variant_index = variant_index + 1
                        if token_kind(kinds, current_variant_index) == TOKEN_IDENTIFIER and (token_kind(kinds, current_variant_index + 1) == TOKEN_NEWLINE or token_kind(kinds, current_variant_index + 1) == TOKEN_EOF):
                            if source_ranges_equal(source, token_start(starts, current_variant_index), token_end(ends, current_variant_index), variant_name_start, variant_name_end):
                                return variant_index
                            variant_index = variant_index + 1
                        current_variant_index = current_variant_index + 1
        token_index = token_index + 1
    return 0

def parse_enum_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let enum_name_start = token_start(starts, index)
    let enum_name_end = token_end(ends, index)
    let variant_name_start = token_start(starts, index + 2)
    let variant_name_end = token_end(ends, index + 2)
    let variant_tag = enum_variant_tag(source, kinds, starts, ends, enum_name_start, enum_name_end, variant_name_start, variant_name_end)
    let enum_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, enum_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\ncall void @append_i32(%dynarray_i32* %t")
    append_integer(output, enum_temporary)
    append_text(output, ", i32 ")
    append_integer(output, variant_tag)
    append_text(output, ")\n")
    if token_kind(kinds, index + 3) == TOKEN_OPEN_PAREN:
        let (payload_next_index, payload_type, payload_value, payload_counter) = parse_argument_expression(source, kinds, starts, ends, index + 4, output, variable_starts, variable_ends, variable_types, enum_temporary)
        if payload_type == VALUE_TYPE_IMMEDIATE or payload_type == VALUE_TYPE_INT:
            append_text(output, "call void @append_i32(%dynarray_i32* %t")
            append_integer(output, enum_temporary)
            append_text(output, ", i32 ")
            append_operand(output, payload_type, payload_value)
            append_text(output, ")\n")
        let closing_index = payload_next_index
        while token_kind(kinds, closing_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, closing_index) != TOKEN_EOF:
            closing_index = closing_index + 1
        return (closing_index + 1, VALUE_TYPE_LIST, enum_temporary, payload_counter)
    return (index + 3, VALUE_TYPE_LIST, enum_temporary, enum_temporary)

def parse_simple_enum_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let enum_name_start = token_start(starts, index)
    let enum_name_end = token_end(ends, index)
    let variant_name_start = token_start(starts, index + 2)
    let variant_name_end = token_end(ends, index + 2)
    let variant_tag = enum_variant_tag(source, kinds, starts, ends, enum_name_start, enum_name_end, variant_name_start, variant_name_end)
    let enum_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, enum_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\ncall void @append_i32(%dynarray_i32* %t")
    append_integer(output, enum_temporary)
    append_text(output, ", i32 ")
    append_integer(output, variant_tag)
    append_text(output, ")\n")
    return (index + 3, VALUE_TYPE_LIST, enum_temporary, enum_temporary)

def parse_builtin_enum_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let name_start = token_start(starts, index)
    let name_end = token_end(ends, index)
    let variant_tag = 0
    if source[name_start:name_end] == "Err" or source[name_start:name_end] == "None":
        variant_tag = 1
    let enum_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, enum_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\ncall void @append_i32(%dynarray_i32* %t")
    append_integer(output, enum_temporary)
    append_text(output, ", i32 ")
    append_integer(output, variant_tag)
    append_text(output, ")\n")
    if token_kind(kinds, index + 1) == TOKEN_OPEN_PAREN:
        let (payload_next_index, payload_type, payload_value, payload_counter) = parse_argument_expression(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, enum_temporary)
        if payload_type == VALUE_TYPE_IMMEDIATE or payload_type == VALUE_TYPE_INT:
            append_text(output, "call void @append_i32(%dynarray_i32* %t")
            append_integer(output, enum_temporary)
            append_text(output, ", i32 ")
            append_operand(output, payload_type, payload_value)
            append_text(output, ")\n")
        let closing_index = payload_next_index
        while token_kind(kinds, closing_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, closing_index) != TOKEN_EOF:
            closing_index = closing_index + 1
        return (closing_index + 1, VALUE_TYPE_LIST, enum_temporary, payload_counter)
    return (index + 1, VALUE_TYPE_LIST, enum_temporary, enum_temporary)

def parse_struct_literal(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let struct_name_start = token_start(starts, index)
    let struct_name_end = token_end(ends, index)
    let struct_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, struct_temporary)
    append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
    let field_indices = []
    let field_types = []
    let field_values = []
    let field_cursor = index + 2
    let field_counter = struct_temporary
    while token_kind(kinds, field_cursor) != TOKEN_CLOSE_BRACE and token_kind(kinds, field_cursor) != TOKEN_EOF:
        if token_kind(kinds, field_cursor) == TOKEN_IDENTIFIER and token_kind(kinds, field_cursor + 1) == TOKEN_COLON:
            let field_name_start = token_start(starts, field_cursor)
            let field_name_end = token_end(ends, field_cursor)
            let current_field_index = struct_field_index(source, kinds, starts, ends, struct_name_start, struct_name_end, field_name_start, field_name_end)
            let (field_next_index, field_type, field_value, field_next_counter) = parse_argument_expression(source, kinds, starts, ends, field_cursor + 2, output, variable_starts, variable_ends, variable_types, field_counter)
            append(field_indices, current_field_index)
            append(field_types, field_type)
            append(field_values, field_value)
            field_cursor = field_next_index
            field_counter = field_next_counter
            if token_kind(kinds, field_cursor) == TOKEN_COMMA:
                field_cursor = field_cursor + 1
            else:
                if token_kind(kinds, field_cursor) != TOKEN_CLOSE_BRACE:
                    field_cursor = field_cursor + 1
    let declared_field_count = struct_field_count(source, kinds, starts, ends, struct_name_start, struct_name_end)
    if declared_field_count == 0:
        declared_field_count = len(field_indices)
    let expected_field_index = 0
    while expected_field_index < declared_field_count:
        let field_entry_index = 0
        while field_entry_index < len(field_indices):
            if field_indices[field_entry_index] == expected_field_index:
                if field_types[field_entry_index] == VALUE_TYPE_IMMEDIATE or field_types[field_entry_index] == VALUE_TYPE_INT:
                    append_text(output, "call void @append_i32(%dynarray_i32* %t")
                    append_integer(output, struct_temporary)
                    append_text(output, ", i32 ")
                    append_operand(output, field_types[field_entry_index], field_values[field_entry_index])
                    append_text(output, ")\n")
            field_entry_index = field_entry_index + 1
        expected_field_index = expected_field_index + 1
    return (field_cursor + 1, 3, struct_temporary, field_counter)

def parse_argument_atom(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    if token_kind(kinds, index) == TOKEN_TRUE:
        let true_argument_temporary = append_bool_literal(output, 1, temporary_counter)
        return (index + 1, 4, true_argument_temporary, true_argument_temporary)
    if token_kind(kinds, index) == TOKEN_FALSE:
        let false_argument_temporary = append_bool_literal(output, 0, temporary_counter)
        return (index + 1, 4, false_argument_temporary, false_argument_temporary)
    if token_kind(kinds, index) == TOKEN_INTEGER:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    if token_kind(kinds, index) == TOKEN_RUNE:
        let rune_value = parse_rune_literal(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, rune_value, temporary_counter)
    if token_kind(kinds, index) == TOKEN_MINUS and token_kind(kinds, index + 1) == TOKEN_INTEGER:
        let negative_value = parse_integer(source, token_start(starts, index + 1), token_end(ends, index + 1))
        return (index + 2, 0, 0 - negative_value, temporary_counter)
    if token_kind(kinds, index) == TOKEN_FLOAT:
        let literal_float_temporary = append_float_literal(output, source, starts, ends, index, temporary_counter)
        return (index + 1, 10, literal_float_temporary, literal_float_temporary)
    if token_kind(kinds, index) == TOKEN_MINUS and token_kind(kinds, index + 1) == TOKEN_FLOAT:
        let negative_float_literal_temporary = append_float_literal(output, source, starts, ends, index + 1, temporary_counter)
        let negative_temporary = negative_float_literal_temporary + 1
        append_text(output, "%t")
        append_integer(output, negative_temporary)
        append_text(output, " = fsub double 0.0, %t")
        append_integer(output, negative_float_literal_temporary)
        append_text(output, "\n")
        return (index + 2, 10, negative_temporary, negative_temporary)
    if token_kind(kinds, index) == TOKEN_STRING:
        let string_temporary = temporary_counter + 1
        append_string_pointer(output, source, starts, ends, index, string_temporary)
        return (index + 1, 2, string_temporary, string_temporary)
    if token_kind(kinds, index) == TOKEN_OPEN_BRACKET:
        return parse_integer_list_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if token_kind(kinds, index) == TOKEN_OPEN_BRACE:
        return parse_integer_dict_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if token_kind(kinds, index) == TOKEN_OPEN_PAREN:
        let tuple_scan_index = index + 1
        let tuple_scan_depth = 0
        let tuple_scan_done = false
        let tuple_has_comma = false
        while not tuple_scan_done and token_kind(kinds, tuple_scan_index) != TOKEN_EOF:
            if token_kind(kinds, tuple_scan_index) == TOKEN_OPEN_PAREN:
                tuple_scan_depth = tuple_scan_depth + 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_CLOSE_PAREN:
                if tuple_scan_depth == 0:
                    tuple_scan_done = true
                if tuple_scan_depth > 0:
                    tuple_scan_depth = tuple_scan_depth - 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_COMMA and tuple_scan_depth == 0:
                tuple_has_comma = true
            if not tuple_scan_done:
                tuple_scan_index = tuple_scan_index + 1
        if tuple_has_comma:
            return parse_integer_tuple_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        let (group_next_index, group_type, group_value, group_next_counter) = parse_argument_expression(source, kinds, starts, ends, index + 1, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return (group_next_index + 1, group_type, group_value, group_next_counter)
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and source[token_start(starts, index):token_end(ends, index)] == "None":
        return parse_builtin_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and token_kind(kinds, index + 1) == TOKEN_OPEN_BRACE:
        return parse_struct_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let qualified_name_variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and token_kind(kinds, index + 1) == TOKEN_DOT and token_kind(kinds, index + 3) == TOKEN_OPEN_PAREN and qualified_name_variable_index < 0:
        return parse_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and token_kind(kinds, index + 1) == TOKEN_DOT and token_kind(kinds, index + 2) == TOKEN_IDENTIFIER and qualified_name_variable_index < 0:
        return parse_simple_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if token_kind(kinds, index) == TOKEN_IDENTIFIER and token_kind(kinds, index + 1) == TOKEN_OPEN_PAREN:
        let argument_name = source[token_start(starts, index):token_end(ends, index)]
        if argument_name == "Some" or argument_name == "Ok" or argument_name == "Err":
            return parse_builtin_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        if argument_name == "token_start" or argument_name == "token_end":
            return parse_position_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        return parse_nested_call(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let variable_index = find_variable(source, token_start(starts, index), token_end(ends, index), variable_starts, variable_ends)
    if variable_index >= 0:
        if variable_types[variable_index] == VALUE_TYPE_BOOL:
            let bool_argument_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, bool_argument_temporary)
            append_text(output, " = load i1, i1* ")
            append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], variable_types[variable_index])
            append_text(output, "\n")
            return (index + 1, VALUE_TYPE_BOOL, bool_argument_temporary, bool_argument_temporary)
        if variable_types[variable_index] == VALUE_TYPE_STRING:
            let string_variable_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, string_variable_temporary)
            append_text(output, " = load i8*, i8** ")
            append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], variable_types[variable_index])
            append_text(output, "\n")
            if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
                let (slice_start_index, slice_start_type, slice_start_value, slice_start_counter) = parse_slice_endpoint(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, string_variable_temporary)
                if token_kind(kinds, slice_start_index) == TOKEN_COLON:
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
                    return (slice_end_index + 1, VALUE_TYPE_STRING, slice_temporary, slice_temporary)
                let rune_temporary = slice_start_counter + 1
                append_text(output, "%t")
                append_integer(output, rune_temporary)
                append_text(output, " = call i32 @__c_utf8_rune_at(i8* %t")
                append_integer(output, string_variable_temporary)
                append_text(output, ", i32 ")
                append_operand(output, slice_start_type, slice_start_value)
                append_text(output, ")\n")
                return (slice_start_index + 1, 1, rune_temporary, rune_temporary)
            return (index + 1, VALUE_TYPE_STRING, string_variable_temporary, string_variable_temporary)
        if variable_types[variable_index] == VALUE_TYPE_FLOAT:
            let loaded_float_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, loaded_float_temporary)
            append_text(output, " = load double, double* ")
            append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], variable_types[variable_index])
            append_text(output, "\n")
            return (index + 1, VALUE_TYPE_FLOAT, loaded_float_temporary, loaded_float_temporary)
    let is_list_variable = false
    if is_known_list_variable(source, token_start(starts, index), token_end(ends, index)):
        is_list_variable = true
    if variable_index >= 0:
        if variable_types[variable_index] == VALUE_TYPE_LIST:
            is_list_variable = true
    if is_list_variable:
        let list_variable_type = VALUE_TYPE_LIST
        if variable_index >= 0:
            list_variable_type = variable_types[variable_index]
        let list_variable_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, list_variable_temporary)
        append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
        append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], list_variable_type)
        append_text(output, "\n")
        if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
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
        return (index + 1, VALUE_TYPE_LIST, list_variable_temporary, list_variable_temporary)
    if variable_is_dictionary(variable_types, variable_index):
        let dictionary_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, dictionary_temporary)
        append_text(output, " = load %dict_t*, %dict_t** ")
        append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], variable_types[variable_index])
        append_text(output, "\n")
        if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
            let (key_next_index, key_type, key_value, key_counter) = parse_argument_expression(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, dictionary_temporary)
            let dictionary_result_temporary = key_counter + 1
            append_text(output, "%t")
            append_integer(output, dictionary_result_temporary)
            if variable_types[variable_index] == VALUE_TYPE_DICT_INT_INT:
                append_text(output, " = call i32 @dream_dict_get_int_int(%dict_t* %t")
            if variable_types[variable_index] == VALUE_TYPE_DICT_INT_STRING:
                append_text(output, " = call i8* @dream_dict_get_int_str(%dict_t* %t")
            if variable_types[variable_index] == VALUE_TYPE_DICT_STRING_INT:
                append_text(output, " = call i32 @dream_dict_get_str_int(%dict_t* %t")
            if variable_types[variable_index] == VALUE_TYPE_DICT_STRING_STRING:
                append_text(output, " = call i8* @dream_dict_get_str_str(%dict_t* %t")
            append_integer(output, dictionary_temporary)
            append_text(output, ", ")
            if key_type == VALUE_TYPE_STRING:
                append_text(output, "i8* ")
            if key_type != VALUE_TYPE_STRING:
                append_text(output, "i32 ")
            append_operand(output, key_type, key_value)
            append_text(output, ")\n")
            if variable_types[variable_index] == VALUE_TYPE_DICT_INT_STRING or variable_types[variable_index] == VALUE_TYPE_DICT_STRING_STRING:
                return (key_next_index + 1, VALUE_TYPE_STRING, dictionary_result_temporary, dictionary_result_temporary)
            return (key_next_index + 1, VALUE_TYPE_INT, dictionary_result_temporary, dictionary_result_temporary)
        return (index + 1, variable_types[variable_index], dictionary_temporary, dictionary_temporary)
    if variable_type_at(variable_types, variable_index) == VALUE_TYPE_BOOL:
        let bool_load_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, bool_load_temporary)
        append_text(output, " = load i1, i1* ")
        append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], variable_types[variable_index])
        append_text(output, "\n")
        return (index + 1, 4, bool_load_temporary, bool_load_temporary)
    let result_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, result_temporary)
    append_text(output, " = load i32, i32* ")
    let result_variable_type = VALUE_TYPE_INT
    if variable_index >= 0:
        result_variable_type = variable_types[variable_index]
    append_variable_reference(output, source[token_start(starts, index):token_end(ends, index)], result_variable_type)
    append_text(output, "\n")
    return (index + 1, 1, result_temporary, result_temporary)

def function_result_type(source: str, name_start: int, name_end: int, function_starts: list[int], function_ends: list[int], function_return_types: list[int]) -> int:
    if source[name_start:name_end] == "Some" or source[name_start:name_end] == "None" or source[name_start:name_end] == "Ok" or source[name_start:name_end] == "Err":
        return VALUE_TYPE_LIST
    if source[name_start:name_end] == "read_text_file" or source[name_start:name_end] == "string_substring" or source[name_start:name_end] == "string_concat" or source[name_start:name_end] == "__c_file_read" or source[name_start:name_end] == "module_path" or source[name_start:name_end] == "append_imported_module" or source[name_start:name_end] == "load_imported_source":
        return VALUE_TYPE_STRING
    if source[name_start:name_end] == "is_digit" or source[name_start:name_end] == "is_identifier_start" or source[name_start:name_end] == "is_identifier_continue" or source[name_start:name_end] == "source_equals" or source[name_start:name_end] == "source_ranges_equal" or source[name_start:name_end] == "is_known_list_variable":
        return VALUE_TYPE_BOOL
    if source[name_start:name_end] == "parse_index_operand" or source[name_start:name_end] == "parse_index_atom" or source[name_start:name_end] == "parse_position_call" or source[name_start:name_end] == "parse_nested_call" or source[name_start:name_end] == "parse_slice_endpoint" or source[name_start:name_end] == "parse_integer_list_comprehension" or source[name_start:name_end] == "parse_integer_list_literal" or source[name_start:name_end] == "parse_integer_tuple_literal" or source[name_start:name_end] == "parse_integer_dict_literal" or source[name_start:name_end] == "parse_struct_literal" or source[name_start:name_end] == "parse_enum_literal" or source[name_start:name_end] == "parse_simple_enum_literal" or source[name_start:name_end] == "parse_builtin_enum_literal" or source[name_start:name_end] == "parse_match_expression" or source[name_start:name_end] == "parse_argument_atom" or source[name_start:name_end] == "parse_argument_expression" or source[name_start:name_end] == "parse_primary" or source[name_start:name_end] == "parse_unary" or source[name_start:name_end] == "parse_term" or source[name_start:name_end] == "parse_logical_operand" or source[name_start:name_end] == "parse_expression" or source[name_start:name_end] == "parse_assignment" or source[name_start:name_end] == "parse_branch_body" or source[name_start:name_end] == "parse_switch_statement" or source[name_start:name_end] == "parse_for_statement" or source[name_start:name_end] == "parse_function_body" or source[name_start:name_end] == "dir_parse_native_operand" or source[name_start:name_end] == "dir_parse_native_type":
        return VALUE_TYPE_LIST
    let function_index = find_function(source, name_start, name_end, function_starts, function_ends)
    if function_index >= 0:
        return function_return_types[function_index]
    return VALUE_TYPE_INT

def parse_argument_expression(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_argument_atom(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == TOKEN_MULTIPLY or token_kind(kinds, current_index) == TOKEN_DIVIDE or token_kind(kinds, current_index) == TOKEN_MODULO:
        let term_operator = token_kind(kinds, current_index)
        let (term_next_index, term_next_is_temporary, term_next_value, term_next_counter) = parse_argument_atom(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter)
        let term_result_temporary = term_next_counter + 1
        append_text(output, "%t")
        append_integer(output, term_result_temporary)
        let is_float_term = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if term_next_is_temporary == VALUE_TYPE_FLOAT:
                is_float_term = true
        if is_float_term:
            if term_operator == TOKEN_MULTIPLY:
                append_text(output, " = fmul double ")
            if term_operator == TOKEN_DIVIDE:
                append_text(output, " = fdiv double ")
            if term_operator == TOKEN_MODULO:
                append_text(output, " = frem double ")
        if not is_float_term:
            if term_operator == TOKEN_MULTIPLY:
                append_text(output, " = mul i32 ")
            if term_operator == TOKEN_DIVIDE:
                append_text(output, " = sdiv i32 ")
            if term_operator == TOKEN_MODULO:
                append_text(output, " = srem i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, term_next_is_temporary, term_next_value)
        append_text(output, "\n")
        current_index = term_next_index
        if is_float_term:
            current_is_temporary = VALUE_TYPE_FLOAT
        if not is_float_term:
            current_is_temporary = VALUE_TYPE_INT
        current_value = term_result_temporary
        current_counter = term_result_temporary
    while token_kind(kinds, current_index) == TOKEN_PLUS or token_kind(kinds, current_index) == TOKEN_MINUS:
        let expression_operator = token_kind(kinds, current_index)
        let (expression_next_index, expression_next_is_temporary, expression_next_value, expression_next_counter) = parse_argument_atom(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter)
        let expression_result_temporary = expression_next_counter + 1
        append_text(output, "%t")
        append_integer(output, expression_result_temporary)
        let is_float_expression = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if expression_next_is_temporary == VALUE_TYPE_FLOAT:
                is_float_expression = true
        if is_float_expression:
            if expression_operator == TOKEN_PLUS:
                append_text(output, " = fadd double ")
            if expression_operator == TOKEN_MINUS:
                append_text(output, " = fsub double ")
        if not is_float_expression:
            if expression_operator == TOKEN_PLUS:
                append_text(output, " = add i32 ")
            if expression_operator == TOKEN_MINUS:
                append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, expression_next_is_temporary, expression_next_value)
        append_text(output, "\n")
        current_index = expression_next_index
        if is_float_expression:
            current_is_temporary = VALUE_TYPE_FLOAT
        if not is_float_expression:
            current_is_temporary = VALUE_TYPE_INT
        current_value = expression_result_temporary
        current_counter = expression_result_temporary
    return (current_index, current_is_temporary, current_value, current_counter)

def append_match_branch_condition(output: list[int], value_type: int, value: int, temporary_counter: int) -> int:
    if value_type == VALUE_TYPE_BOOL:
        return value
    let condition_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, condition_temporary)
    append_text(output, " = icmp ne i32 ")
    append_operand(output, value_type, value)
    append_text(output, ", 0\n")
    return condition_temporary

def parse_match_expression(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    let (scrutinee_next_index, scrutinee_type, scrutinee_value, scrutinee_counter) = parse_expression(source, kinds, starts, ends, index + 1, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let match_result_pointer = scrutinee_counter + 1
    append_text(output, "%match.result.")
    append_integer(output, match_result_pointer)
    append_text(output, " = alloca i32\n")
    let match_label_base = scrutinee_counter + 1000
    let match_end_label = match_label_base
    let current_counter = match_result_pointer
    let case_index = skip_source_newlines(source, starts, scrutinee_next_index + 1)
    let case_indent = line_indent(source, token_start(starts, case_index))
    let case_number = 0
    let match_scan_done = false
    let has_case = false
    let has_wildcard = false
    while not match_scan_done and case_index < len(kinds) and token_kind(kinds, case_index) != TOKEN_EOF:
        if line_indent(source, token_start(starts, case_index)) < case_indent:
            match_scan_done = true
        if not match_scan_done:
            let pattern_index = case_index
            let pattern_is_wildcard = false
            let pattern_is_enum = false
            let pattern_is_builtin_enum = false
            let pattern_is_list = false
            let pattern_is_cons = false
            let pattern_has_payload = false
            let pattern_payload_start = 0
            let pattern_payload_end = 0
            let pattern_tag = 0
            let pattern_value = 0
            let pattern_value_is_temporary = false
            let pattern_end_index = pattern_index + 1
            let list_pattern_name_starts = []
            let list_pattern_name_ends = []
            let list_pattern_indices = []
            let list_pattern_count = 0
            let cons_head_start = 0
            let cons_head_end = 0
            let cons_tail_start = 0
            let cons_tail_end = 0
            if token_kind(kinds, pattern_index) == TOKEN_OPEN_BRACKET:
                pattern_is_list = true
                let list_pattern_cursor = pattern_index + 1
                while token_kind(kinds, list_pattern_cursor) != TOKEN_CLOSE_BRACKET and token_kind(kinds, list_pattern_cursor) != TOKEN_EOF:
                    if token_kind(kinds, list_pattern_cursor) == TOKEN_IDENTIFIER:
                        append(list_pattern_name_starts, token_start(starts, list_pattern_cursor))
                        append(list_pattern_name_ends, token_end(ends, list_pattern_cursor))
                        append(list_pattern_indices, list_pattern_count)
                        list_pattern_count = list_pattern_count + 1
                    list_pattern_cursor = list_pattern_cursor + 1
                pattern_end_index = list_pattern_cursor + 1
            if token_kind(kinds, pattern_index) == TOKEN_INTEGER:
                pattern_value = parse_integer(source, token_start(starts, pattern_index), token_end(ends, pattern_index))
            if token_kind(kinds, pattern_index) == TOKEN_RUNE:
                pattern_value = parse_rune_literal(source, token_start(starts, pattern_index), token_end(ends, pattern_index))
            if token_kind(kinds, pattern_index) == TOKEN_IDENTIFIER:
                let pattern_name = source[token_start(starts, pattern_index):token_end(ends, pattern_index)]
                if pattern_name == "_":
                    pattern_is_wildcard = true
                if token_kind(kinds, pattern_index + 1) == TOKEN_CONS and token_kind(kinds, pattern_index + 2) == TOKEN_IDENTIFIER:
                    pattern_is_cons = true
                    cons_head_start = token_start(starts, pattern_index)
                    cons_head_end = token_end(ends, pattern_index)
                    cons_tail_start = token_start(starts, pattern_index + 2)
                    cons_tail_end = token_end(ends, pattern_index + 2)
                    pattern_end_index = pattern_index + 3
                if token_kind(kinds, pattern_index + 1) == TOKEN_DOT:
                    pattern_is_enum = true
                    let variant_name_start = token_start(starts, pattern_index + 2)
                    let variant_name_end = token_end(ends, pattern_index + 2)
                    pattern_tag = enum_variant_tag(source, kinds, starts, ends, token_start(starts, pattern_index), token_end(ends, pattern_index), variant_name_start, variant_name_end)
                    if token_kind(kinds, pattern_index + 3) == TOKEN_OPEN_PAREN:
                        pattern_has_payload = true
                        pattern_payload_start = pattern_index + 4
                        pattern_payload_end = pattern_index + 5
                        pattern_end_index = pattern_index + 6
                    if not pattern_has_payload:
                        pattern_end_index = pattern_index + 3
                if token_kind(kinds, pattern_index + 1) == TOKEN_OPEN_PAREN and (pattern_name == "Some" or pattern_name == "Ok" or pattern_name == "Err"):
                    pattern_is_builtin_enum = true
                    if pattern_name == "Err":
                        pattern_tag = 1
                    if pattern_name == "Some" or pattern_name == "Ok":
                        pattern_tag = 0
                    pattern_has_payload = true
                    pattern_payload_start = pattern_index + 2
                    pattern_payload_end = pattern_index + 3
                    pattern_end_index = pattern_index + 4
                if pattern_name == "None":
                    pattern_is_builtin_enum = true
                    pattern_tag = 1
                    pattern_end_index = pattern_index + 1
            let case_colon_index = pattern_end_index
            while token_kind(kinds, case_colon_index) != TOKEN_COLON and token_kind(kinds, case_colon_index) != TOKEN_EOF:
                case_colon_index = case_colon_index + 1
            let case_body_label = match_label_base + case_number * 3 + 1
            let case_check_label = match_label_base + case_number * 3 + 2
            let case_guard_label = match_label_base + case_number * 3 + 3
            let guard_index = pattern_end_index
            let guard_scan_index = pattern_end_index
            let has_guard = false
            while guard_scan_index < case_colon_index:
                if token_kind(kinds, guard_scan_index) == TOKEN_IF:
                    has_guard = true
                    guard_index = guard_scan_index
                guard_scan_index = guard_scan_index + 1
            let case_condition = current_counter + 1
            let pattern_true_label = case_body_label
            if has_guard:
                pattern_true_label = case_guard_label
            let list_length_temporary = 0
            if pattern_is_list or pattern_is_cons:
                list_length_temporary = current_counter + 1
                append_text(output, "%t")
                append_integer(output, list_length_temporary)
                append_text(output, " = call i32 @len(%dynarray_i32* ")
                append_operand(output, scrutinee_type, scrutinee_value)
                append_text(output, ")\n")
                let list_condition_temporary = list_length_temporary + 1
                append_text(output, "%t")
                append_integer(output, list_condition_temporary)
                if pattern_is_cons:
                    append_text(output, " = icmp sgt i32 %t")
                    append_integer(output, list_length_temporary)
                    append_text(output, ", 0\n")
                if pattern_is_list:
                    append_text(output, " = icmp eq i32 %t")
                    append_integer(output, list_length_temporary)
                    append_text(output, ", ")
                    append_integer(output, list_pattern_count)
                    append_text(output, "\n")
                append_text(output, "br i1 %t")
                append_integer(output, list_condition_temporary)
                if has_guard:
                    append_text(output, ", label %match.guard.")
                if not has_guard:
                    append_text(output, ", label %match.body.")
                append_integer(output, pattern_true_label)
                append_text(output, ", label %match.check.")
                append_integer(output, case_check_label)
                append_text(output, "\n")
                current_counter = list_condition_temporary
            if pattern_is_enum or pattern_is_builtin_enum:
                let tag_temporary = current_counter + 1
                append_text(output, "%t")
                append_integer(output, tag_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* ")
                append_operand(output, scrutinee_type, scrutinee_value)
                append_text(output, ", i32 0)\n")
                let tag_condition = tag_temporary + 1
                append_text(output, "%t")
                append_integer(output, tag_condition)
                append_text(output, " = icmp eq i32 %t")
                append_integer(output, tag_temporary)
                append_text(output, ", ")
                append_integer(output, pattern_tag)
                append_text(output, "\n")
                current_counter = tag_condition
                if not pattern_is_wildcard:
                    append_text(output, "br i1 %t")
                    append_integer(output, tag_condition)
                    if has_guard:
                        append_text(output, ", label %match.guard.")
                    if not has_guard:
                        append_text(output, ", label %match.body.")
                    append_integer(output, pattern_true_label)
                    append_text(output, ", label %match.check.")
                    append_integer(output, case_check_label)
                    append_text(output, "\n")
            if not pattern_is_enum and not pattern_is_builtin_enum and not pattern_is_wildcard and not pattern_is_list and not pattern_is_cons:
                append_text(output, "%t")
                append_integer(output, case_condition)
                append_text(output, " = icmp eq i32 ")
                append_operand(output, scrutinee_type, scrutinee_value)
                append_text(output, ", ")
                append_integer(output, pattern_value)
                append_text(output, "\nbr i1 %t")
                append_integer(output, case_condition)
                if has_guard:
                    append_text(output, ", label %match.guard.")
                if not has_guard:
                    append_text(output, ", label %match.body.")
                append_integer(output, pattern_true_label)
                append_text(output, ", label %match.check.")
                append_integer(output, case_check_label)
                append_text(output, "\n")
                current_counter = case_condition
            if pattern_is_wildcard:
                if has_guard:
                    append_text(output, "br label %match.guard.")
                if not has_guard:
                    append_text(output, "br label %match.body.")
                append_integer(output, pattern_true_label)
                append_text(output, "\n")
                if not has_guard:
                    has_wildcard = true
            if has_guard:
                append_text(output, "match.guard.")
                append_integer(output, case_guard_label)
                append_text(output, ":\n")
                let (guard_next_index, guard_type, guard_value, guard_counter) = parse_expression(source, kinds, starts, ends, guard_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                let guard_condition = append_match_branch_condition(output, guard_type, guard_value, guard_counter)
                append_text(output, "br i1 %t")
                append_integer(output, guard_condition)
                append_text(output, ", label %match.body.")
                append_integer(output, case_body_label)
                append_text(output, ", label %match.check.")
                append_integer(output, case_check_label)
                append_text(output, "\n")
                current_counter = guard_condition
            append_text(output, "match.body.")
            append_integer(output, case_body_label)
            append_text(output, ":\n")
            if pattern_is_list:
                let list_binding_index = 0
                while list_binding_index < len(list_pattern_name_starts):
                    let list_name_start = list_pattern_name_starts[list_binding_index]
                    let list_name_end = list_pattern_name_ends[list_binding_index]
                    if source[list_name_start:list_name_end] != "_":
                        let list_variable_index = find_variable(source, list_name_start, list_name_end, variable_starts, variable_ends)
                        if list_variable_index < 0:
                            append_local_storage(output, source[list_name_start:list_name_end], VALUE_TYPE_INT)
                            append(variable_starts, list_name_start)
                            append(variable_ends, list_name_end)
                            append(variable_types, VALUE_TYPE_INT)
                        let list_element_temporary = current_counter + 1
                        append_text(output, "%t")
                        append_integer(output, list_element_temporary)
                        append_text(output, " = call i32 @get(%dynarray_i32* ")
                        append_operand(output, scrutinee_type, scrutinee_value)
                        append_text(output, ", i32 ")
                        append_integer(output, list_pattern_indices[list_binding_index])
                        append_text(output, ")\nstore i32 %t")
                        append_integer(output, list_element_temporary)
                        append_text(output, ", i32* %")
                        append_text(output, source[list_name_start:list_name_end])
                        append_text(output, "\n")
                        current_counter = list_element_temporary
                    list_binding_index = list_binding_index + 1
            if pattern_is_cons:
                if source[cons_head_start:cons_head_end] != "_":
                    let cons_head_variable_index = find_variable(source, cons_head_start, cons_head_end, variable_starts, variable_ends)
                    if cons_head_variable_index < 0:
                        append_local_storage(output, source[cons_head_start:cons_head_end], VALUE_TYPE_INT)
                        append(variable_starts, cons_head_start)
                        append(variable_ends, cons_head_end)
                        append(variable_types, VALUE_TYPE_INT)
                    let cons_head_temporary = current_counter + 1
                    append_text(output, "%t")
                    append_integer(output, cons_head_temporary)
                    append_text(output, " = call i32 @get(%dynarray_i32* ")
                    append_operand(output, scrutinee_type, scrutinee_value)
                    append_text(output, ", i32 0)\nstore i32 %t")
                    append_integer(output, cons_head_temporary)
                    append_text(output, ", i32* %")
                    append_text(output, source[cons_head_start:cons_head_end])
                    append_text(output, "\n")
                    current_counter = cons_head_temporary
                if source[cons_tail_start:cons_tail_end] != "_":
                    let cons_tail_variable_index = find_variable(source, cons_tail_start, cons_tail_end, variable_starts, variable_ends)
                    if cons_tail_variable_index < 0:
                        append_local_storage(output, source[cons_tail_start:cons_tail_end], VALUE_TYPE_LIST)
                        append(variable_starts, cons_tail_start)
                        append(variable_ends, cons_tail_end)
                        append(variable_types, VALUE_TYPE_LIST)
                    let cons_tail_temporary = current_counter + 1
                    append_text(output, "%t")
                    append_integer(output, cons_tail_temporary)
                    append_text(output, " = call %dynarray_i32* @slice_dynarray_i32(%dynarray_i32* ")
                    append_operand(output, scrutinee_type, scrutinee_value)
                    append_text(output, ", i32 1, i32 %t")
                    append_integer(output, list_length_temporary)
                    append_text(output, ")\nstore %dynarray_i32* %t")
                    append_integer(output, cons_tail_temporary)
                    append_text(output, ", %dynarray_i32** %")
                    append_text(output, source[cons_tail_start:cons_tail_end])
                    append_text(output, "\n")
                    current_counter = cons_tail_temporary
            if pattern_has_payload and (pattern_is_enum or pattern_is_builtin_enum) and token_kind(kinds, pattern_payload_start) == TOKEN_IDENTIFIER and source[token_start(starts, pattern_payload_start):token_end(ends, pattern_payload_start)] != "_":
                let payload_name_start = token_start(starts, pattern_payload_start)
                let payload_name_end = token_end(ends, pattern_payload_start)
                let payload_variable_index = find_variable(source, payload_name_start, payload_name_end, variable_starts, variable_ends)
                if payload_variable_index < 0:
                    append_local_storage(output, source[payload_name_start:payload_name_end], VALUE_TYPE_INT)
                    append(variable_starts, payload_name_start)
                    append(variable_ends, payload_name_end)
                    append(variable_types, VALUE_TYPE_INT)
                let payload_temporary = current_counter + 1
                append_text(output, "%t")
                append_integer(output, payload_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* ")
                append_operand(output, scrutinee_type, scrutinee_value)
                append_text(output, ", i32 1)\nstore i32 %t")
                append_integer(output, payload_temporary)
                append_text(output, ", i32* %")
                append_text(output, source[payload_name_start:payload_name_end])
                append_text(output, "\n")
                current_counter = payload_temporary
            let (body_next_index, body_type, body_value, body_counter) = parse_expression(source, kinds, starts, ends, case_colon_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
            append_text(output, "store i32 ")
            append_operand(output, body_type, body_value)
            append_text(output, ", i32* %match.result.")
            append_integer(output, match_result_pointer)
            append_text(output, "\nbr label %match.end.")
            append_integer(output, match_end_label)
            append_text(output, "\n")
            current_counter = body_counter
            has_case = true
            case_number = case_number + 1
            case_index = skip_source_newlines(source, starts, body_next_index)
            if not has_wildcard:
                append_text(output, "match.check.")
                append_integer(output, case_check_label)
                append_text(output, ":\n")
            if has_wildcard:
                match_scan_done = true
    if not has_wildcard:
        append_text(output, "store i32 0, i32* %match.result.")
        append_integer(output, match_result_pointer)
        append_text(output, "\n")
    append_text(output, "br label %match.end.")
    append_integer(output, match_end_label)
    append_text(output, "\nmatch.end.")
    append_integer(output, match_end_label)
    append_text(output, ":\n")
    let result_temporary = current_counter + 1
    append_text(output, "%t")
    append_integer(output, result_temporary)
    append_text(output, " = load i32, i32* %match.result.")
    append_integer(output, match_result_pointer)
    append_text(output, "\n")
    return (case_index, 1, result_temporary, result_temporary)

def parse_primary(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    let kind = token_kind(kinds, index)
    if kind == TOKEN_TRUE:
        let true_primary_temporary = append_bool_literal(output, 1, temporary_counter)
        return (index + 1, 4, true_primary_temporary, true_primary_temporary)
    if kind == TOKEN_FALSE:
        let false_primary_temporary = append_bool_literal(output, 0, temporary_counter)
        return (index + 1, 4, false_primary_temporary, false_primary_temporary)
    if kind == TOKEN_MINUS and token_kind(kinds, index + 1) == TOKEN_INTEGER:
        let negative_value = parse_integer(source, token_start(starts, index + 1), token_end(ends, index + 1))
        return (index + 2, 0, 0 - negative_value, temporary_counter)
    if kind == TOKEN_INTEGER:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, value, temporary_counter)
    if kind == TOKEN_RUNE:
        let rune_value = parse_rune_literal(source, token_start(starts, index), token_end(ends, index))
        return (index + 1, 0, rune_value, temporary_counter)
    if kind == TOKEN_FLOAT:
        let primary_float_literal_temporary = append_float_literal(output, source, starts, ends, index, temporary_counter)
        return (index + 1, 10, primary_float_literal_temporary, primary_float_literal_temporary)
    if kind == TOKEN_STRING:
        let string_temporary = temporary_counter + 1
        append_string_pointer(output, source, starts, ends, index, string_temporary)
        return (index + 1, 2, string_temporary, string_temporary)
    if kind == TOKEN_OPEN_BRACKET:
        return parse_integer_list_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if kind == TOKEN_OPEN_BRACE:
        return parse_integer_dict_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
    if kind == TOKEN_OPEN_PAREN:
        let tuple_scan_index = index + 1
        let tuple_scan_depth = 0
        let tuple_scan_done = false
        let tuple_has_comma = false
        while not tuple_scan_done and token_kind(kinds, tuple_scan_index) != TOKEN_EOF:
            if token_kind(kinds, tuple_scan_index) == TOKEN_OPEN_PAREN:
                tuple_scan_depth = tuple_scan_depth + 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_CLOSE_PAREN:
                if tuple_scan_depth == 0:
                    tuple_scan_done = true
                if tuple_scan_depth > 0:
                    tuple_scan_depth = tuple_scan_depth - 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_COMMA and tuple_scan_depth == 0:
                tuple_has_comma = true
            if not tuple_scan_done:
                tuple_scan_index = tuple_scan_index + 1
        if tuple_has_comma:
            return parse_integer_tuple_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        let (group_next_index, group_type, group_value, group_next_counter) = parse_expression(source, kinds, starts, ends, index + 1, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        return (group_next_index + 1, group_type, group_value, group_next_counter)
    if kind == TOKEN_IDENTIFIER and source[token_start(starts, index):token_end(ends, index)] == "match":
        return parse_match_expression(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    if kind == TOKEN_IDENTIFIER:
        let name_start = token_start(starts, index)
        let name_end = token_end(ends, index)
        if source[name_start:name_end] == "None":
            return parse_builtin_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        let qualified_name_variable_index = find_variable(source, name_start, name_end, variable_starts, variable_ends)
        if token_kind(kinds, index + 1) == TOKEN_DOT and token_kind(kinds, index + 3) == TOKEN_OPEN_PAREN and qualified_name_variable_index < 0:
            return parse_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        if token_kind(kinds, index + 1) == TOKEN_DOT and token_kind(kinds, index + 2) == TOKEN_IDENTIFIER and qualified_name_variable_index < 0:
            return parse_simple_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACE:
            return parse_struct_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
        if source[name_start:name_end] == "lambda":
            let lambda_body_start_index = lambda_body_start(kinds, index)
            let lambda_body_end_index = lambda_body_end(kinds, lambda_body_start_index)
            let lambda_value_type = VALUE_TYPE_LAMBDA_BASE + index
            return (lambda_body_end_index, lambda_value_type, index, temporary_counter)
        if token_kind(kinds, index + 1) == TOKEN_OPEN_PAREN:
            let call_name_start = name_start
            let call_name_end = name_end
            let is_lambda_call = false
            let lambda_token_index = 0
            if variable_is_function_value(variable_types, qualified_name_variable_index):
                if is_lambda_value_type(variable_types[qualified_name_variable_index]):
                    is_lambda_call = true
                    lambda_token_index = lambda_value_index(variable_types[qualified_name_variable_index])
                if not is_lambda_call:
                    let target_function_index = function_value_index(variable_types[qualified_name_variable_index])
                    call_name_start = function_starts[target_function_index]
                    call_name_end = function_ends[target_function_index]
            let argument_temporary_flags = []
            let argument_values = []
            let argument_index = index + 2
            let argument_counter = temporary_counter
            let call_argument_steps = 0
            if source[name_start:name_end] == "Some" or source[name_start:name_end] == "Ok" or source[name_start:name_end] == "Err":
                return parse_builtin_enum_literal(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter)
            if source[name_start:name_end] == "ord":
                let (ord_primary_next_index, ord_primary_type, ord_primary_value, ord_primary_counter) = parse_argument_expression(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, temporary_counter)
                return (ord_primary_next_index + 1, ord_primary_type, ord_primary_value, ord_primary_counter)
            while argument_index < len(kinds) and token_kind(kinds, argument_index) != TOKEN_CLOSE_PAREN and call_argument_steps < 32:
                let (argument_next_index, argument_is_temporary, argument_value, argument_next_counter) = parse_argument_expression(source, kinds, starts, ends, argument_index, output, variable_starts, variable_ends, variable_types, argument_counter)
                append(argument_temporary_flags, argument_is_temporary)
                append(argument_values, argument_value)
                argument_index = argument_next_index
                argument_counter = argument_next_counter
                if token_kind(kinds, argument_index) == TOKEN_COMMA:
                    argument_index = argument_index + 1
                call_argument_steps = call_argument_steps + 1
            let prepared_argument_temporary_flags = []
            let prepared_argument_values = []
            let prepared_argument_counter = argument_counter
            let prepared_argument_index = 0
            while prepared_argument_index < len(argument_values):
                let expected_argument_type = function_parameter_type(source, kinds, starts, ends, call_name_start, call_name_end, prepared_argument_index)
                if is_lambda_call:
                    expected_argument_type = lambda_parameter_type(source, kinds, starts, ends, lambda_token_index, prepared_argument_index)
                let prepared_argument_type = argument_temporary_flags[prepared_argument_index]
                let prepared_argument_value = argument_values[prepared_argument_index]
                if expected_argument_type == VALUE_TYPE_BOOL and prepared_argument_type == VALUE_TYPE_INT:
                    let bool_argument_temporary = prepared_argument_counter + 1
                    append_text(output, "%t")
                    append_integer(output, bool_argument_temporary)
                    append_text(output, " = icmp ne i32 ")
                    append_operand(output, prepared_argument_type, prepared_argument_value)
                    append_text(output, ", 0\n")
                    prepared_argument_type = VALUE_TYPE_BOOL
                    prepared_argument_value = bool_argument_temporary
                    prepared_argument_counter = bool_argument_temporary
                append(prepared_argument_temporary_flags, prepared_argument_type)
                append(prepared_argument_values, prepared_argument_value)
                prepared_argument_index = prepared_argument_index + 1
            let result_temporary = prepared_argument_counter + 1
            let call_result_type = VALUE_TYPE_INT
            if not is_lambda_call:
                call_result_type = function_result_type(source, call_name_start, call_name_end, function_starts, function_ends, function_return_types)
            append_text(output, "%t")
            append_integer(output, result_temporary)
            if call_result_type == VALUE_TYPE_STRING:
                append_text(output, " = call i8* @")
            if call_result_type == VALUE_TYPE_LIST:
                append_text(output, " = call %dynarray_i32* @")
            if call_result_type == VALUE_TYPE_BOOL:
                append_text(output, " = call i1 @")
            if call_result_type == VALUE_TYPE_FLOAT:
                append_text(output, " = call double @")
            if call_result_type != VALUE_TYPE_STRING and call_result_type != VALUE_TYPE_LIST and call_result_type != VALUE_TYPE_BOOL and call_result_type != VALUE_TYPE_FLOAT:
                append_text(output, " = call i32 @")
            let is_dictionary_length_call = false
            if source[name_start:name_end] == "len":
                if len(prepared_argument_temporary_flags) > 0:
                    if is_dictionary_value_type(prepared_argument_temporary_flags[0]):
                        is_dictionary_length_call = true
            if is_dictionary_length_call:
                if prepared_argument_temporary_flags[0] == VALUE_TYPE_DICT_INT_INT:
                    append_text(output, "dream_dict_size_int_int")
                if prepared_argument_temporary_flags[0] == VALUE_TYPE_DICT_INT_STRING:
                    append_text(output, "dream_dict_size_int_str")
                if prepared_argument_temporary_flags[0] == VALUE_TYPE_DICT_STRING_INT:
                    append_text(output, "dream_dict_size_str_int")
                if prepared_argument_temporary_flags[0] == VALUE_TYPE_DICT_STRING_STRING:
                    append_text(output, "dream_dict_size_str_str")
            if not is_dictionary_length_call:
                if is_lambda_call:
                    append_text(output, "__dir_lambda_")
                    append_integer(output, lambda_token_index)
                if not is_lambda_call:
                    append_text(output, source[call_name_start:call_name_end])
            append_text(output, "(")
            let output_argument_index = 0
            while output_argument_index < len(prepared_argument_values):
                if output_argument_index > 0:
                    append_text(output, ", ")
                let output_argument_is_string = false
                let output_argument_is_list = false
                let output_argument_is_bool = false
                let output_argument_is_dictionary = false
                let output_argument_is_float = false
                let expected_output_argument_type = function_parameter_type(source, kinds, starts, ends, call_name_start, call_name_end, output_argument_index)
                if is_lambda_call:
                    expected_output_argument_type = lambda_parameter_type(source, kinds, starts, ends, lambda_token_index, output_argument_index)
                if prepared_argument_temporary_flags[output_argument_index] == VALUE_TYPE_STRING:
                    output_argument_is_string = true
                if prepared_argument_temporary_flags[output_argument_index] == VALUE_TYPE_LIST:
                    output_argument_is_list = true
                if is_dictionary_value_type(prepared_argument_temporary_flags[output_argument_index]):
                    output_argument_is_dictionary = true
                if prepared_argument_temporary_flags[output_argument_index] == VALUE_TYPE_FLOAT:
                    output_argument_is_float = true
                if expected_output_argument_type == VALUE_TYPE_BOOL:
                    output_argument_is_bool = true
                if output_argument_is_bool:
                    append_text(output, "i1 ")
                if output_argument_is_string:
                    append_text(output, "i8* ")
                if output_argument_is_list:
                    append_text(output, "%dynarray_i32* ")
                if output_argument_is_dictionary:
                    append_text(output, "%dict_t* ")
                if output_argument_is_float:
                    append_text(output, "double ")
                if not output_argument_is_bool and not output_argument_is_string and not output_argument_is_dictionary and not output_argument_is_float:
                    if not output_argument_is_list:
                        append_text(output, "i32 ")
                append_operand(output, prepared_argument_temporary_flags[output_argument_index], prepared_argument_values[output_argument_index])
                output_argument_index = output_argument_index + 1
            append_text(output, ")\n")
            if call_result_type == VALUE_TYPE_BOOL:
                return (argument_index + 1, VALUE_TYPE_BOOL, result_temporary, result_temporary)
            return (argument_index + 1, call_result_type, result_temporary, result_temporary)
        let variable_index = qualified_name_variable_index
        if variable_index < 0:
            let function_index = find_function(source, name_start, name_end, function_starts, function_ends)
            if function_index >= 0:
                let function_value_type = VALUE_TYPE_FUNCTION_BASE + function_index
                return (index + 1, function_value_type, function_index, temporary_counter)
        if variable_is_function_value(variable_types, variable_index):
            return (index + 1, variable_types[variable_index], function_value_index(variable_types[variable_index]), temporary_counter)
        if variable_index >= 0:
            if variable_types[variable_index] == VALUE_TYPE_STRING:
                let string_variable_temporary = temporary_counter + 1
                append_text(output, "%t")
                append_integer(output, string_variable_temporary)
                append_text(output, " = load i8*, i8** ")
                append_variable_reference(output, source[name_start:name_end], variable_types[variable_index])
                append_text(output, "\n")
                if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
                    let (slice_start_index, slice_start_type, slice_start_value, slice_start_counter) = parse_slice_endpoint(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, string_variable_temporary)
                    if token_kind(kinds, slice_start_index) != TOKEN_COLON:
                        let rune_temporary = slice_start_counter + 1
                        append_text(output, "%t")
                        append_integer(output, rune_temporary)
                        append_text(output, " = call i32 @__c_utf8_rune_at(i8* %t")
                        append_integer(output, string_variable_temporary)
                        append_text(output, ", i32 ")
                        append_operand(output, slice_start_type, slice_start_value)
                        append_text(output, ")\n")
                        return (slice_start_index + 1, 1, rune_temporary, rune_temporary)
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
                return (index + 1, VALUE_TYPE_STRING, string_variable_temporary, string_variable_temporary)
        if variable_is_dictionary(variable_types, variable_index):
            let dictionary_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, dictionary_temporary)
            append_text(output, " = load %dict_t*, %dict_t** ")
            append_variable_reference(output, source[name_start:name_end], variable_types[variable_index])
            append_text(output, "\n")
            if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
                let (key_next_index, key_type, key_value, key_counter) = parse_expression(source, kinds, starts, ends, index + 2, output, variable_starts, variable_ends, variable_types, dictionary_temporary, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                let dictionary_result_temporary = key_counter + 1
                append_text(output, "%t")
                append_integer(output, dictionary_result_temporary)
                if variable_types[variable_index] == VALUE_TYPE_DICT_INT_INT:
                    append_text(output, " = call i32 @dream_dict_get_int_int(%dict_t* %t")
                if variable_types[variable_index] == VALUE_TYPE_DICT_INT_STRING:
                    append_text(output, " = call i8* @dream_dict_get_int_str(%dict_t* %t")
                if variable_types[variable_index] == VALUE_TYPE_DICT_STRING_INT:
                    append_text(output, " = call i32 @dream_dict_get_str_int(%dict_t* %t")
                if variable_types[variable_index] == VALUE_TYPE_DICT_STRING_STRING:
                    append_text(output, " = call i8* @dream_dict_get_str_str(%dict_t* %t")
                append_integer(output, dictionary_temporary)
                append_text(output, ", ")
                if key_type == VALUE_TYPE_STRING:
                    append_text(output, "i8* ")
                if key_type != VALUE_TYPE_STRING:
                    append_text(output, "i32 ")
                append_operand(output, key_type, key_value)
                append_text(output, ")\n")
                if variable_types[variable_index] == VALUE_TYPE_DICT_INT_STRING or variable_types[variable_index] == VALUE_TYPE_DICT_STRING_STRING:
                    return (key_next_index + 1, VALUE_TYPE_STRING, dictionary_result_temporary, dictionary_result_temporary)
                return (key_next_index + 1, VALUE_TYPE_INT, dictionary_result_temporary, dictionary_result_temporary)
            return (index + 1, variable_types[variable_index], dictionary_temporary, dictionary_temporary)
        if variable_type_at(variable_types, variable_index) == VALUE_TYPE_FLOAT:
            let loaded_primary_float_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, loaded_primary_float_temporary)
            append_text(output, " = load double, double* ")
            append_variable_reference(output, source[name_start:name_end], variable_types[variable_index])
            append_text(output, "\n")
            return (index + 1, VALUE_TYPE_FLOAT, loaded_primary_float_temporary, loaded_primary_float_temporary)
        if token_kind(kinds, index + 1) == TOKEN_DOT:
            let field_name_start = token_start(starts, index + 2)
            let field_name_end = token_end(ends, index + 2)
            let field_index = struct_any_field_index(source, kinds, starts, ends, field_name_start, field_name_end)
            let field_list_type = 3
            if variable_index >= 0:
                field_list_type = variable_types[variable_index]
            let field_list_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, field_list_temporary)
            append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
            append_variable_reference(output, source[name_start:name_end], field_list_type)
            append_text(output, "\n")
            let field_value_temporary = field_list_temporary + 1
            append_text(output, "%t")
            append_integer(output, field_value_temporary)
            append_text(output, " = call i32 @get(%dynarray_i32* %t")
            append_integer(output, field_list_temporary)
            append_text(output, ", i32 ")
            append_integer(output, field_index)
            append_text(output, ")\n")
            return (index + 3, 1, field_value_temporary, field_value_temporary)
        let is_list_variable = false
        if variable_index >= 0:
            if variable_types[variable_index] == VALUE_TYPE_LIST:
                is_list_variable = true
        if is_known_list_variable(source, name_start, name_end):
            is_list_variable = true
        if is_list_variable:
            let list_variable_type = VALUE_TYPE_LIST
            if variable_index >= 0:
                list_variable_type = variable_types[variable_index]
            let list_variable_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, list_variable_temporary)
            append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
            append_variable_reference(output, source[name_start:name_end], list_variable_type)
            append_text(output, "\n")
            if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
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
        if variable_type_at(variable_types, variable_index) == VALUE_TYPE_BOOL:
            let bool_load_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, bool_load_temporary)
            append_text(output, " = load i1, i1* ")
            append_variable_reference(output, source[name_start:name_end], variable_types[variable_index])
            append_text(output, "\n")
            return (index + 1, VALUE_TYPE_BOOL, bool_load_temporary, bool_load_temporary)
        let next_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, next_temporary)
        append_text(output, " = load i32, i32* ")
        let result_variable_type = VALUE_TYPE_INT
        if variable_index >= 0:
            result_variable_type = variable_types[variable_index]
        append_variable_reference(output, source[name_start:name_end], result_variable_type)
        append_text(output, "\n")
        return (index + 1, 1, next_temporary, next_temporary)
    return (index + 1, 0, 0, temporary_counter)

def parse_unary(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    if token_kind(kinds, index) == TOKEN_NOT:
        let (not_next_index, not_value_type, not_value, not_counter) = parse_unary(source, kinds, starts, ends, index + 1, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let not_result_temporary = not_counter + 1
        append_text(output, "%t")
        append_integer(output, not_result_temporary)
        if not_value_type == VALUE_TYPE_BOOL:
            append_text(output, " = xor i1 ")
            append_operand(output, not_value_type, not_value)
            append_text(output, ", 1\n")
        if not_value_type != VALUE_TYPE_BOOL:
            append_text(output, " = icmp eq i32 ")
            append_operand(output, not_value_type, not_value)
            append_text(output, ", 0\n")
        return (not_next_index, VALUE_TYPE_BOOL, not_result_temporary, not_result_temporary)
    return parse_primary(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)

def parse_term(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_unary(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == TOKEN_MULTIPLY or token_kind(kinds, current_index) == TOKEN_DIVIDE or token_kind(kinds, current_index) == TOKEN_MODULO:
        let operator = token_kind(kinds, current_index)
        let (next_index, next_is_temporary, next_value, next_counter) = parse_unary(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let result_temporary = next_counter + 1
        append_text(output, "%t")
        append_integer(output, result_temporary)
        let is_float_operation = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if next_is_temporary == VALUE_TYPE_FLOAT:
                is_float_operation = true
        if is_float_operation:
            if operator == TOKEN_MULTIPLY:
                append_text(output, " = fmul double ")
            if operator == TOKEN_DIVIDE:
                append_text(output, " = fdiv double ")
            if operator == TOKEN_MODULO:
                append_text(output, " = frem double ")
        if not is_float_operation:
            if operator == TOKEN_MULTIPLY:
                append_text(output, " = mul i32 ")
            if operator == TOKEN_DIVIDE:
                append_text(output, " = sdiv i32 ")
            if operator == TOKEN_MODULO:
                append_text(output, " = srem i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, next_is_temporary, next_value)
        append_text(output, "\n")
        current_index = next_index
        if is_float_operation:
            current_is_temporary = VALUE_TYPE_FLOAT
        if not is_float_operation:
            current_is_temporary = VALUE_TYPE_INT
        current_value = result_temporary
        current_counter = result_temporary
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_logical_operand(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_term(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == TOKEN_PLUS or token_kind(kinds, current_index) == TOKEN_MINUS:
        let additive_operator = token_kind(kinds, current_index)
        let (additive_next_index, additive_is_temporary, additive_value, additive_next_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let additive_result = additive_next_counter + 1
        append_text(output, "%t")
        append_integer(output, additive_result)
        let is_float_additive = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if additive_is_temporary == VALUE_TYPE_FLOAT:
                is_float_additive = true
        if is_float_additive:
            if additive_operator == TOKEN_PLUS:
                append_text(output, " = fadd double ")
            if additive_operator == TOKEN_MINUS:
                append_text(output, " = fsub double ")
        if not is_float_additive:
            if additive_operator == TOKEN_PLUS:
                append_text(output, " = add i32 ")
            if additive_operator == TOKEN_MINUS:
                append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, additive_is_temporary, additive_value)
        append_text(output, "\n")
        current_index = additive_next_index
        if is_float_additive:
            current_is_temporary = VALUE_TYPE_FLOAT
        if not is_float_additive:
            current_is_temporary = VALUE_TYPE_INT
        current_value = additive_result
        current_counter = additive_result
    while token_kind(kinds, current_index) == TOKEN_LESS or token_kind(kinds, current_index) == TOKEN_EQUAL or token_kind(kinds, current_index) == TOKEN_NOT_EQUAL or token_kind(kinds, current_index) == TOKEN_LESS_EQUAL or token_kind(kinds, current_index) == TOKEN_GREATER_EQUAL or token_kind(kinds, current_index) == TOKEN_GREATER:
        let comparison_operator = token_kind(kinds, current_index)
        let (comparison_value_index, comparison_is_temporary, comparison_value, comparison_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let comparison_result = comparison_counter + 1
        append_text(output, "%t")
        append_integer(output, comparison_result)
        let is_string_comparison = false
        if current_is_temporary == VALUE_TYPE_STRING or comparison_is_temporary == VALUE_TYPE_STRING:
            is_string_comparison = true
            append_text(output, " = call i32 @string_compare(i8* ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", i8* ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, ")\n")
            let compare_result = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, compare_result)
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i32 %t")
            if comparison_operator != TOKEN_NOT_EQUAL:
                append_text(output, " = icmp eq i32 %t")
            append_integer(output, comparison_result)
            append_text(output, ", 0\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = compare_result
            current_counter = compare_result
        let is_float_comparison = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if comparison_is_temporary == VALUE_TYPE_FLOAT:
                is_float_comparison = true
        if is_float_comparison:
            if comparison_operator == TOKEN_LESS:
                append_text(output, " = fcmp olt double ")
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = fcmp oeq double ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = fcmp one double ")
            if comparison_operator == TOKEN_LESS_EQUAL:
                append_text(output, " = fcmp ole double ")
            if comparison_operator == TOKEN_GREATER_EQUAL:
                append_text(output, " = fcmp oge double ")
            if comparison_operator == TOKEN_GREATER:
                append_text(output, " = fcmp ogt double ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = comparison_result
            current_counter = comparison_result
        let is_bool_comparison = false
        if current_is_temporary == VALUE_TYPE_BOOL:
            if comparison_is_temporary == VALUE_TYPE_BOOL:
                is_bool_comparison = true
        if is_bool_comparison:
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = icmp eq i1 ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i1 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_value = comparison_result
            current_counter = comparison_result
        if not is_string_comparison and not is_float_comparison and not is_bool_comparison:
            if comparison_operator == TOKEN_LESS:
                append_text(output, " = icmp slt i32 ")
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = icmp eq i32 ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i32 ")
            if comparison_operator == TOKEN_LESS_EQUAL:
                append_text(output, " = icmp sle i32 ")
            if comparison_operator == TOKEN_GREATER_EQUAL:
                append_text(output, " = icmp sge i32 ")
            if comparison_operator == TOKEN_GREATER:
                append_text(output, " = icmp sgt i32 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = comparison_result
            current_counter = comparison_result
    return (current_index, current_is_temporary, current_value, current_counter)

def parse_expression(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int, int, int):
    let (first_index, first_is_temporary, first_value, first_counter) = parse_term(source, kinds, starts, ends, index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let current_index = first_index
    let current_is_temporary = first_is_temporary
    let current_value = first_value
    let current_counter = first_counter
    while token_kind(kinds, current_index) == TOKEN_PLUS or token_kind(kinds, current_index) == TOKEN_MINUS:
        let operator = token_kind(kinds, current_index)
        let (next_index, next_is_temporary, next_value, next_counter) = parse_term(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let result_temporary = next_counter + 1
        append_text(output, "%t")
        append_integer(output, result_temporary)
        let is_float_expression = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if next_is_temporary == VALUE_TYPE_FLOAT:
                is_float_expression = true
        if is_float_expression:
            if operator == TOKEN_PLUS:
                append_text(output, " = fadd double ")
            if operator == TOKEN_MINUS:
                append_text(output, " = fsub double ")
        if not is_float_expression:
            if operator == TOKEN_PLUS:
                append_text(output, " = add i32 ")
            if operator == TOKEN_MINUS:
                append_text(output, " = sub i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, next_is_temporary, next_value)
        append_text(output, "\n")
        current_index = next_index
        if is_float_expression:
            current_is_temporary = 10
        if not is_float_expression:
            current_is_temporary = 1
        current_value = result_temporary
        current_counter = result_temporary
    while token_kind(kinds, current_index) == TOKEN_LESS or token_kind(kinds, current_index) == TOKEN_EQUAL or token_kind(kinds, current_index) == TOKEN_NOT_EQUAL or token_kind(kinds, current_index) == TOKEN_LESS_EQUAL or token_kind(kinds, current_index) == TOKEN_GREATER_EQUAL or token_kind(kinds, current_index) == TOKEN_GREATER:
        let comparison_operator = token_kind(kinds, current_index)
        let comparison_next_index = current_index + 1
        let (comparison_value_index, comparison_is_temporary, comparison_value, comparison_counter) = parse_term(source, kinds, starts, ends, comparison_next_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let comparison_result = comparison_counter + 1
        append_text(output, "%t")
        append_integer(output, comparison_result)
        let expression_is_string_comparison = false
        if current_is_temporary == VALUE_TYPE_STRING or comparison_is_temporary == VALUE_TYPE_STRING:
            expression_is_string_comparison = true
            append_text(output, " = call i32 @string_compare(i8* ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", i8* ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, ")\n")
            let string_comparison_normalized = comparison_result + 1
            append_text(output, "%t")
            append_integer(output, string_comparison_normalized)
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i32 %t")
            if comparison_operator != TOKEN_NOT_EQUAL:
                append_text(output, " = icmp eq i32 %t")
            append_integer(output, comparison_result)
            append_text(output, ", 0\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = string_comparison_normalized
            current_counter = string_comparison_normalized
        let is_float_comparison = false
        if current_is_temporary == VALUE_TYPE_FLOAT:
            if comparison_is_temporary == VALUE_TYPE_FLOAT:
                is_float_comparison = true
        if is_float_comparison:
            if comparison_operator == TOKEN_LESS:
                append_text(output, " = fcmp olt double ")
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = fcmp oeq double ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = fcmp one double ")
            if comparison_operator == TOKEN_LESS_EQUAL:
                append_text(output, " = fcmp ole double ")
            if comparison_operator == TOKEN_GREATER_EQUAL:
                append_text(output, " = fcmp oge double ")
            if comparison_operator == TOKEN_GREATER:
                append_text(output, " = fcmp ogt double ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = comparison_result
            current_counter = comparison_result
        let expression_is_bool_comparison = false
        if current_is_temporary == VALUE_TYPE_BOOL:
            if comparison_is_temporary == VALUE_TYPE_BOOL:
                expression_is_bool_comparison = true
        if expression_is_bool_comparison:
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = icmp eq i1 ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i1 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_value = comparison_result
            current_counter = comparison_result
        if not expression_is_string_comparison and not is_float_comparison and not expression_is_bool_comparison:
            if comparison_operator == TOKEN_LESS:
                append_text(output, " = icmp slt i32 ")
            if comparison_operator == TOKEN_EQUAL:
                append_text(output, " = icmp eq i32 ")
            if comparison_operator == TOKEN_NOT_EQUAL:
                append_text(output, " = icmp ne i32 ")
            if comparison_operator == TOKEN_LESS_EQUAL:
                append_text(output, " = icmp sle i32 ")
            if comparison_operator == TOKEN_GREATER_EQUAL:
                append_text(output, " = icmp sge i32 ")
            if comparison_operator == TOKEN_GREATER:
                append_text(output, " = icmp sgt i32 ")
            append_operand(output, current_is_temporary, current_value)
            append_text(output, ", ")
            append_operand(output, comparison_is_temporary, comparison_value)
            append_text(output, "\n")
            current_index = comparison_value_index
            current_is_temporary = VALUE_TYPE_BOOL
            current_value = comparison_result
            current_counter = comparison_result
    while token_kind(kinds, current_index) == TOKEN_AND or token_kind(kinds, current_index) == TOKEN_OR:
        let logical_operator = token_kind(kinds, current_index)
        let (logical_next_index, logical_is_temporary, logical_value, logical_counter) = parse_logical_operand(source, kinds, starts, ends, current_index + 1, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let logical_result = logical_counter + 1
        append_text(output, "%t")
        append_integer(output, logical_result)
        let is_boolean_logic = false
        if current_is_temporary == VALUE_TYPE_BOOL:
            if logical_is_temporary == VALUE_TYPE_BOOL:
                is_boolean_logic = true
        if is_boolean_logic:
            if logical_operator == TOKEN_AND:
                append_text(output, " = and i1 ")
            if logical_operator != TOKEN_AND:
                append_text(output, " = or i1 ")
        if not is_boolean_logic:
            if logical_operator == TOKEN_AND:
                append_text(output, " = and i32 ")
            if logical_operator != TOKEN_AND:
                append_text(output, " = or i32 ")
        append_operand(output, current_is_temporary, current_value)
        append_text(output, ", ")
        append_operand(output, logical_is_temporary, logical_value)
        append_text(output, "\n")
        current_index = logical_next_index
        if is_boolean_logic:
            current_is_temporary = VALUE_TYPE_BOOL
        if not is_boolean_logic:
            current_is_temporary = VALUE_TYPE_INT
        current_value = logical_result
        current_counter = logical_result
    return (current_index, current_is_temporary, current_value, current_counter)
