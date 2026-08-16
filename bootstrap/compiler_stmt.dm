def parse_assignment(source: str, kinds: list[int], starts: list[int], ends: list[int], index: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> (int, int):
    let assignment_name_start = token_start(starts, index)
    let assignment_name_end = token_end(ends, index)
    let assignment_operator_index = index + 1
    let is_list_element_assignment = false
    let list_index_start = index + 2
    if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACKET:
        let list_index_end = list_index_start
        while token_kind(kinds, list_index_end) != TOKEN_CLOSE_BRACKET and token_kind(kinds, list_index_end) != TOKEN_EOF:
            list_index_end = list_index_end + 1
        if token_kind(kinds, list_index_end) == TOKEN_CLOSE_BRACKET and token_kind(kinds, list_index_end + 1) == TOKEN_ASSIGN:
            is_list_element_assignment = true
            assignment_operator_index = list_index_end + 1
    let assignment_expression_index = assignment_operator_index + 1
    let assignment_variable_index = find_variable(source, assignment_name_start, assignment_name_end, variable_starts, variable_ends)
    if assignment_variable_index >= 0 and is_dictionary_value_type(variable_types[assignment_variable_index]) and is_list_element_assignment:
        let dictionary_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, dictionary_temporary)
        append_text(output, " = load %dict_t*, %dict_t** %")
        append_text(output, source[assignment_name_start:assignment_name_end])
        append_text(output, "\n")
        let (key_next_index, key_type, key_value, key_counter) = parse_expression(source, kinds, starts, ends, list_index_start, output, variable_starts, variable_ends, variable_types, dictionary_temporary, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let (value_next_index, value_type, value_value, value_counter) = parse_expression(source, kinds, starts, ends, key_next_index + 2, output, variable_starts, variable_ends, variable_types, key_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_INT:
            append_text(output, "call void @dict_set_int_int(%dict_t* %t")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_STRING:
            append_text(output, "call void @dict_set_int_str(%dict_t* %t")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_INT:
            append_text(output, "call void @dict_set_str_int(%dict_t* %t")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_STRING:
            append_text(output, "call void @dict_set_str_str(%dict_t* %t")
        append_integer(output, dictionary_temporary)
        append_text(output, ", ")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_INT or variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_STRING:
            append_text(output, "i8* ")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_INT or variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_STRING:
            append_text(output, "i32 ")
        append_operand(output, key_type, key_value)
        append_text(output, ", ")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_STRING or variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_STRING:
            append_text(output, "i8* ")
        if variable_types[assignment_variable_index] == VALUE_TYPE_DICT_INT_INT or variable_types[assignment_variable_index] == VALUE_TYPE_DICT_STRING_INT:
            append_text(output, "i32 ")
        append_operand(output, value_type, value_value)
        append_text(output, ")\n")
        return (skip_source_newlines(source, starts, value_next_index), value_counter)
    if is_list_element_assignment:
        let list_variable_type = VALUE_TYPE_LIST
        if assignment_variable_index >= 0:
            list_variable_type = variable_types[assignment_variable_index]
        let list_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, list_temporary)
        append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
        append_variable_reference(output, source[assignment_name_start:assignment_name_end], list_variable_type)
        append_text(output, "\n")
        let (index_next_index, index_is_temporary, index_value, index_next_counter) = parse_index_atom(source, kinds, starts, ends, list_index_start, output, variable_starts, variable_ends, variable_types, list_temporary)
        let (list_assignment_next_index, list_assignment_is_temporary, list_assignment_value, list_assignment_next_counter) = parse_expression(source, kinds, starts, ends, index_next_index + 2, output, variable_starts, variable_ends, variable_types, index_next_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        append_text(output, "call void @set_dynarray_i32(%dynarray_i32* %t")
        append_integer(output, list_temporary)
        append_text(output, ", i32 ")
        append_operand(output, index_is_temporary, index_value)
        append_text(output, ", i32 ")
        append_operand(output, list_assignment_is_temporary, list_assignment_value)
        append_text(output, ")\n")
        return (skip_source_newlines(source, starts, list_assignment_next_index), list_assignment_next_counter)
    let (assignment_next_index, assignment_is_temporary, assignment_value, assignment_next_counter) = parse_expression(source, kinds, starts, ends, assignment_expression_index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let is_string_assignment = false
    let is_list_assignment = false
    let is_dictionary_assignment = false
    let is_float_assignment = false
    let is_bool_assignment = false
    if assignment_variable_index >= 0:
        if variable_types[assignment_variable_index] == VALUE_TYPE_STRING:
            is_string_assignment = true
        if variable_types[assignment_variable_index] == VALUE_TYPE_LIST:
            is_list_assignment = true
        if is_dictionary_value_type(variable_types[assignment_variable_index]):
            is_dictionary_assignment = true
        if variable_types[assignment_variable_index] == VALUE_TYPE_FLOAT:
            is_float_assignment = true
        if variable_types[assignment_variable_index] == VALUE_TYPE_BOOL:
            is_bool_assignment = true
    if is_string_assignment:
        append_text(output, "store i8* ")
    if is_list_assignment:
        append_text(output, "store %dynarray_i32* ")
    if is_dictionary_assignment:
        append_text(output, "store %dict_t* ")
    if is_float_assignment:
        append_text(output, "store double ")
    if is_bool_assignment:
        append_text(output, "store i1 ")
    if not is_string_assignment and not is_list_assignment and not is_dictionary_assignment and not is_float_assignment and not is_bool_assignment:
        append_text(output, "store i32 ")
    append_operand(output, assignment_is_temporary, assignment_value)
    if is_string_assignment:
        append_text(output, ", i8** %")
    if is_list_assignment:
        append_text(output, ", %dynarray_i32** %")
    if is_dictionary_assignment:
        append_text(output, ", %dict_t** %")
    if is_float_assignment:
        append_text(output, ", double* %")
    if is_bool_assignment:
        append_text(output, ", i1* %")
    if not is_string_assignment and not is_list_assignment and not is_dictionary_assignment and not is_float_assignment and not is_bool_assignment:
        append_text(output, ", i32* %")
    append_text(output, source[assignment_name_start:assignment_name_end])
    append_text(output, "\n")
    return (skip_source_newlines(source, starts, assignment_next_index), assignment_next_counter)

def parse_branch_body(source: str, kinds: list[int], starts: list[int], ends: list[int], branch_start: int, branch_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int], expected_return_type: int) -> (int, int):
    return parse_function_body(source, kinds, starts, ends, branch_start, branch_end, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)

def append_switch_comparison(output: list[int], switch_value_type: int, switch_value: int, case_value_type: int, case_value: int, temporary_counter: int) -> int:
    if switch_value_type == VALUE_TYPE_STRING and case_value_type == VALUE_TYPE_STRING:
        let string_compare_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, string_compare_temporary)
        append_text(output, " = call i32 @string_compare(i8* ")
        append_operand(output, switch_value_type, switch_value)
        append_text(output, ", i8* ")
        append_operand(output, case_value_type, case_value)
        append_text(output, ")\n")
        let string_condition_temporary = string_compare_temporary + 1
        append_text(output, "%t")
        append_integer(output, string_condition_temporary)
        append_text(output, " = icmp eq i32 %t")
        append_integer(output, string_compare_temporary)
        append_text(output, ", 0\n")
        return string_condition_temporary
    if switch_value_type == VALUE_TYPE_FLOAT and case_value_type == VALUE_TYPE_FLOAT:
        let float_condition_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, float_condition_temporary)
        append_text(output, " = fcmp oeq double ")
        append_operand(output, switch_value_type, switch_value)
        append_text(output, ", ")
        append_operand(output, case_value_type, case_value)
        append_text(output, "\n")
        return float_condition_temporary
    if switch_value_type == VALUE_TYPE_BOOL and case_value_type == VALUE_TYPE_BOOL:
        let bool_condition_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, bool_condition_temporary)
        append_text(output, " = icmp eq i1 ")
        append_operand(output, switch_value_type, switch_value)
        append_text(output, ", ")
        append_operand(output, case_value_type, case_value)
        append_text(output, "\n")
        return bool_condition_temporary
    let integer_condition_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, integer_condition_temporary)
    append_text(output, " = icmp eq i32 ")
    append_operand(output, switch_value_type, switch_value)
    append_text(output, ", ")
    append_operand(output, case_value_type, case_value)
    append_text(output, "\n")
    return integer_condition_temporary

def append_branch_condition(output: list[int], value_type: int, value: int, temporary_counter: int) -> int:
    if value_type == VALUE_TYPE_BOOL:
        return value
    let integer_condition_temporary = temporary_counter + 1
    append_text(output, "%t")
    append_integer(output, integer_condition_temporary)
    append_text(output, " = icmp ne i32 ")
    append_operand(output, value_type, value)
    append_text(output, ", 0\n")
    return integer_condition_temporary

def parse_switch_statement(source: str, kinds: list[int], starts: list[int], ends: list[int], switch_index: int, body_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int], expected_return_type: int) -> (int, int):
    let switch_expression_index = switch_index + 1
    let (switch_header_next_index, switch_header_is_temporary, switch_header_value, switch_header_counter) = parse_expression(source, kinds, starts, ends, switch_expression_index, output, variable_starts, variable_ends, variable_types, temporary_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
    let switch_label_base = switch_header_counter + 1000
    let switch_end_label = switch_label_base
    let case_index = skip_source_newlines(source, starts, switch_header_next_index + 1)
    let case_number = 0
    let current_counter = switch_header_counter
    while token_kind(kinds, case_index) == TOKEN_CASE:
        let case_value_index = case_index + 1
        let (case_header_next_index, case_value_is_temporary, case_value, case_header_counter) = parse_expression(source, kinds, starts, ends, case_value_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
        let case_condition = append_switch_comparison(output, switch_header_is_temporary, switch_header_value, case_value_is_temporary, case_value, case_header_counter)
        let case_body_label = switch_label_base + case_number * 3 + 1
        let case_check_label = switch_label_base + case_number * 3 + 2
        append_text(output, "br i1 %t")
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
        while case_body_end < body_end and is_body_line(source, kinds, starts, case_body_end, case_body_indent):
            case_body_end = case_body_end + 1
        let (case_body_counter, case_body_has_return_value) = parse_branch_body(source, kinds, starts, ends, case_body_start, case_body_end, output, variable_starts, variable_ends, variable_types, case_condition, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
        let case_body_has_return = case_body_has_return_value != 0
        if not case_body_has_return:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        append_text(output, "switch.check.")
        append_integer(output, case_check_label)
        append_text(output, ":\n")
        case_index = case_body_end
        current_counter = case_body_counter
        case_number = case_number + 1
    let has_default = false
    if token_kind(kinds, case_index) == TOKEN_DEFAULT:
        has_default = true
        let default_body_start = skip_source_newlines(source, starts, case_index + 1)
        let default_body_label = switch_label_base + case_number * 3 + 1
        append_text(output, "br label %switch.case.")
        append_integer(output, default_body_label)
        append_text(output, "\nswitch.case.")
        append_integer(output, default_body_label)
        append_text(output, ":\n")
        let default_body_indent = line_indent(source, token_start(starts, default_body_start))
        let default_body_end = default_body_start
        while default_body_end < body_end and is_body_line(source, kinds, starts, default_body_end, default_body_indent):
            default_body_end = default_body_end + 1
        let (default_body_counter, default_body_has_return_value) = parse_branch_body(source, kinds, starts, ends, default_body_start, default_body_end, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
        let default_body_has_return = default_body_has_return_value != 0
        if not default_body_has_return:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        current_counter = default_body_counter
        case_index = default_body_end
    if not has_default:
        append_text(output, "br label %switch.end.")
        append_integer(output, switch_end_label)
        append_text(output, "\n")
    append_text(output, "switch.end.")
    append_integer(output, switch_end_label)
    append_text(output, ":\n")
    return (case_index, current_counter)

def parse_for_statement(source: str, kinds: list[int], starts: list[int], ends: list[int], for_index: int, body_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int], expected_return_type: int) -> (int, int):
    let loop_name_start = token_start(starts, for_index + 1)
    let loop_name_end = token_end(ends, for_index + 1)
    let list_name_index = for_index + 3
    let list_name_start = token_start(starts, list_name_index)
    let list_name_end = token_end(ends, list_name_index)
    let colon_index = list_name_index + 1
    let list_variable_index = find_variable(source, list_name_start, list_name_end, variable_starts, variable_ends)
    let list_variable_type = VALUE_TYPE_LIST
    if list_variable_index >= 0:
        list_variable_type = variable_types[list_variable_index]
    let loop_label = temporary_counter + 1
    let list_temporary = loop_label + 1
    let index_temporary = list_temporary + 1
    let length_temporary = index_temporary + 1
    let condition_temporary = length_temporary + 1
    let element_temporary = condition_temporary + 1
    append_text(output, "%for.index.")
    append_integer(output, loop_label)
    append_text(output, " = alloca i32\n")
    append_text(output, "%t")
    append_integer(output, list_temporary)
    append_text(output, " = load %dynarray_i32*, %dynarray_i32** ")
    append_variable_reference(output, source[list_name_start:list_name_end], list_variable_type)
    append_text(output, "\nstore i32 0, i32* %for.index.")
    append_integer(output, loop_label)
    append_text(output, "\nbr label %for.check.")
    append_integer(output, loop_label)
    append_text(output, "\nfor.check.")
    append_integer(output, loop_label)
    append_text(output, ":\n%t")
    append_integer(output, length_temporary)
    append_text(output, " = call i32 @len(%dynarray_i32* %t")
    append_integer(output, list_temporary)
    append_text(output, ")\n%t")
    append_integer(output, index_temporary)
    append_text(output, " = load i32, i32* %for.index.")
    append_integer(output, loop_label)
    append_text(output, "\n%t")
    append_integer(output, condition_temporary)
    append_text(output, " = icmp slt i32 %t")
    append_integer(output, index_temporary)
    append_text(output, ", %t")
    append_integer(output, length_temporary)
    append_text(output, "\nbr i1 %t")
    append_integer(output, condition_temporary)
    append_text(output, ", label %for.body.")
    append_integer(output, loop_label)
    append_text(output, ", label %for.end.")
    append_integer(output, loop_label)
    append_text(output, "\nfor.body.")
    append_integer(output, loop_label)
    append_text(output, ":\n%t")
    append_integer(output, element_temporary)
    append_text(output, " = call i32 @get(%dynarray_i32* %t")
    append_integer(output, list_temporary)
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
    let loop_body_start = skip_source_newlines(source, starts, colon_index + 1)
    let loop_body_indent = line_indent(source, token_start(starts, loop_body_start))
    let loop_body_end = loop_body_start
    while loop_body_end < body_end and is_body_line(source, kinds, starts, loop_body_end, loop_body_indent):
        loop_body_end = loop_body_end + 1
    let (loop_body_counter, loop_body_has_return_value) = parse_branch_body(source, kinds, starts, ends, loop_body_start, loop_body_end, output, variable_starts, variable_ends, variable_types, element_temporary, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
    let loop_body_has_return = loop_body_has_return_value != 0
    let for_result_counter = loop_body_counter
    if not loop_body_has_return:
        let next_index_temporary = loop_body_counter + 1
        append_text(output, "%t")
        append_integer(output, next_index_temporary)
        append_text(output, " = add i32 %t")
        append_integer(output, index_temporary)
        append_text(output, ", 1\nstore i32 %t")
        append_integer(output, next_index_temporary)
        append_text(output, ", i32* %for.index.")
        append_integer(output, loop_label)
        append_text(output, "\nbr label %for.check.")
        append_integer(output, loop_label)
        append_text(output, "\n")
        for_result_counter = next_index_temporary
    append_text(output, "for.end.")
    append_integer(output, loop_label)
    append_text(output, ":\n")
    return (loop_body_end, for_result_counter)

def parse_function_body(source: str, kinds: list[int], starts: list[int], ends: list[int], body_start: int, body_end: int, output: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int], expected_return_type: int) -> (int, int):
    let current_index = skip_source_newlines(source, starts, body_start)
    let current_counter = temporary_counter
    let has_return = false
    while current_index < body_end and token_kind(kinds, current_index) != TOKEN_EOF:
        let statement_token_kind = token_kind(kinds, current_index)
        let next_statement_token_kind = token_kind(kinds, current_index + 1)
        let is_let_statement = false
        let is_tuple_let_statement = false
        let is_assignment_statement = false
        let is_switch_statement = false
        let is_while_statement = false
        let is_for_statement = false
        if statement_token_kind == TOKEN_LET and next_statement_token_kind != TOKEN_OPEN_PAREN:
            is_let_statement = true
        if statement_token_kind == TOKEN_LET and next_statement_token_kind == TOKEN_OPEN_PAREN:
            is_tuple_let_statement = true
        if statement_token_kind == TOKEN_IDENTIFIER and next_statement_token_kind == TOKEN_ASSIGN:
            is_assignment_statement = true
        if statement_token_kind == TOKEN_IDENTIFIER and next_statement_token_kind == TOKEN_OPEN_BRACKET:
            let assignment_probe_index = current_index + 2
            while token_kind(kinds, assignment_probe_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, assignment_probe_index) != TOKEN_EOF:
                assignment_probe_index = assignment_probe_index + 1
            if token_kind(kinds, assignment_probe_index) == TOKEN_CLOSE_BRACKET and token_kind(kinds, assignment_probe_index + 1) == TOKEN_ASSIGN:
                is_assignment_statement = true
        if statement_token_kind == TOKEN_SWITCH:
            is_switch_statement = true
        if statement_token_kind == TOKEN_WHILE:
            is_while_statement = true
        if statement_token_kind == TOKEN_FOR:
            is_for_statement = true
        let is_known_statement = false
        if is_let_statement or is_tuple_let_statement or is_assignment_statement or is_switch_statement or is_while_statement or is_for_statement:
            is_known_statement = true
        if is_let_statement:
            let name_start = token_start(starts, current_index + 1)
            let name_end = token_end(ends, current_index + 1)
            let let_expression_index = current_index + 3
            if token_kind(kinds, current_index + 2) == TOKEN_COLON:
                let annotation_index = current_index + 3
                while token_kind(kinds, annotation_index) != TOKEN_ASSIGN and token_kind(kinds, annotation_index) != TOKEN_EOF:
                    annotation_index = annotation_index + 1
                if token_kind(kinds, annotation_index) == TOKEN_ASSIGN:
                    let_expression_index = annotation_index + 1
            let (let_next_index, let_is_temporary, let_value, let_next_counter) = parse_expression(source, kinds, starts, ends, let_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
            let is_function_binding = is_function_value_type(let_is_temporary)
            let is_question_binding = false
            if let_is_temporary == VALUE_TYPE_LIST and token_kind(kinds, let_next_index) == TOKEN_QUESTION:
                is_question_binding = true
            if is_question_binding:
                let question_tag_temporary = let_next_counter + 1
                append_text(output, "%t")
                append_integer(output, question_tag_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* ")
                append_operand(output, let_is_temporary, let_value)
                append_text(output, ", i32 0)\n")
                let question_condition_temporary = question_tag_temporary + 1
                append_text(output, "%t")
                append_integer(output, question_condition_temporary)
                append_text(output, " = icmp eq i32 %t")
                append_integer(output, question_tag_temporary)
                append_text(output, ", 0\nbr i1 %t")
                append_integer(output, question_condition_temporary)
                append_text(output, ", label %question.ok.")
                append_integer(output, question_condition_temporary)
                append_text(output, ", label %question.error.")
                append_integer(output, question_condition_temporary)
                append_text(output, "\nquestion.error.")
                append_integer(output, question_condition_temporary)
                append_text(output, ":\nret %dynarray_i32* ")
                append_operand(output, let_is_temporary, let_value)
                append_text(output, "\nquestion.ok.")
                append_integer(output, question_condition_temporary)
                append_text(output, ":\n")
                let question_value_temporary = question_condition_temporary + 1
                append_text(output, "%t")
                append_integer(output, question_value_temporary)
                append_text(output, " = call i32 @get(%dynarray_i32* ")
                append_operand(output, let_is_temporary, let_value)
                append_text(output, ", i32 1)\n")
                append_local_storage(output, source[name_start:name_end], 1)
                append_text(output, "store i32 %t")
                append_integer(output, question_value_temporary)
                append_text(output, ", i32* %")
                append_text(output, source[name_start:name_end])
                append_text(output, "\n")
                append(variable_starts, name_start)
                append(variable_ends, name_end)
                append(variable_types, VALUE_TYPE_INT)
                current_index = skip_source_newlines(source, starts, let_next_index + 1)
                current_counter = question_value_temporary
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_STRING:
                append_local_storage(output, source[name_start:name_end], 2)
                append_text(output, "store i8* ")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_LIST:
                append_local_storage(output, source[name_start:name_end], 3)
                append_text(output, "store %dynarray_i32* ")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_FLOAT:
                append_local_storage(output, source[name_start:name_end], 10)
                append_text(output, "store double ")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_BOOL:
                append_local_storage(output, source[name_start:name_end], 4)
                append_text(output, "store i1 ")
            if not is_question_binding and not is_function_binding and is_dictionary_value_type(let_is_temporary):
                append_local_storage(output, source[name_start:name_end], let_is_temporary)
                append_text(output, "store %dict_t* ")
            if not is_question_binding and not is_function_binding and let_is_temporary != VALUE_TYPE_STRING and let_is_temporary != VALUE_TYPE_LIST and let_is_temporary != VALUE_TYPE_BOOL and let_is_temporary != VALUE_TYPE_FLOAT and not is_dictionary_value_type(let_is_temporary):
                append_local_storage(output, source[name_start:name_end], 1)
                append_text(output, "store i32 ")
            if not is_question_binding and not is_function_binding:
                append_operand(output, let_is_temporary, let_value)
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_STRING:
                append_text(output, ", i8** %")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_LIST:
                append_text(output, ", %dynarray_i32** %")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_FLOAT:
                append_text(output, ", double* %")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_BOOL:
                append_text(output, ", i1* %")
            if not is_question_binding and not is_function_binding and is_dictionary_value_type(let_is_temporary):
                append_text(output, ", %dict_t** %")
            if not is_question_binding and not is_function_binding and let_is_temporary != VALUE_TYPE_STRING and let_is_temporary != VALUE_TYPE_LIST and let_is_temporary != VALUE_TYPE_BOOL and let_is_temporary != VALUE_TYPE_FLOAT and not is_dictionary_value_type(let_is_temporary):
                append_text(output, ", i32* %")
            if not is_question_binding:
                if not is_function_binding:
                    append_text(output, source[name_start:name_end])
                    append_text(output, "\n")
                append(variable_starts, name_start)
                append(variable_ends, name_end)
                append(variable_types, let_is_temporary)
                current_index = let_next_index
                while current_index < body_end and source[token_start(starts, current_index)] == '\n':
                    current_index = current_index + 1
                current_counter = let_next_counter
        if is_tuple_let_statement:
            let tuple_name_starts = []
            let tuple_name_ends = []
            let tuple_name_index = current_index + 2
            while token_kind(kinds, tuple_name_index) != TOKEN_CLOSE_PAREN:
                if token_kind(kinds, tuple_name_index) == TOKEN_IDENTIFIER:
                    append(tuple_name_starts, token_start(starts, tuple_name_index))
                    append(tuple_name_ends, token_end(ends, tuple_name_index))
                tuple_name_index = tuple_name_index + 1
            let tuple_expression_index = tuple_name_index + 2
            let (tuple_next_index, tuple_is_temporary, tuple_value, tuple_next_counter) = parse_expression(source, kinds, starts, ends, tuple_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
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
                append(variable_types, VALUE_TYPE_INT)
                tuple_element_index = tuple_element_index + 1
            current_index = skip_source_newlines(source, starts, tuple_next_index)
            current_counter = tuple_next_counter + len(tuple_name_starts)
        if is_assignment_statement:
            let (assignment_next_index, assignment_next_counter) = parse_assignment(source, kinds, starts, ends, current_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
            current_index = assignment_next_index
            current_counter = assignment_next_counter
        if is_switch_statement:
            let (switch_next_index, switch_next_counter) = parse_switch_statement(source, kinds, starts, ends, current_index, body_end, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
            current_index = switch_next_index
            current_counter = switch_next_counter
        if is_while_statement:
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
            let (while_header_next_index, while_header_is_temporary, while_header_value, while_header_counter) = parse_expression(source, kinds, starts, ends, while_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
            let while_condition = append_branch_condition(output, while_header_is_temporary, while_header_value, while_header_counter)
            let while_body_counter = while_header_counter + 1
            append_text(output, "br i1 %t")
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
            while while_body_end < body_end and is_body_line(source, kinds, starts, while_body_end, while_body_indent):
                while_body_end = while_body_end + 1
            let (while_body_result_counter, while_body_has_return_value) = parse_branch_body(source, kinds, starts, ends, while_body_start, while_body_end, output, variable_starts, variable_ends, variable_types, while_body_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
            let while_body_has_return = while_body_has_return_value != 0
            if not while_body_has_return:
                append_text(output, "br label %while.check.")
                append_integer(output, while_check_label)
                append_text(output, "\n")
            append_text(output, "while.end.")
            append_integer(output, while_end_label)
            append_text(output, ":\n")
            current_index = while_body_end
            current_counter = while_body_result_counter
        if is_for_statement:
            let (for_next_index, for_next_counter) = parse_for_statement(source, kinds, starts, ends, current_index, body_end, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
            current_index = for_next_index
            current_counter = for_next_counter
        if not is_known_statement:
            if token_kind(kinds, current_index) == TOKEN_PRINT:
                let print_expression_index = current_index + 2
                let (print_next_index, print_is_temporary, print_value, print_next_counter) = parse_expression(source, kinds, starts, ends, print_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                let is_print_string = false
                let is_print_float = false
                let is_print_bool = false
                if print_is_temporary == VALUE_TYPE_STRING:
                    is_print_string = true
                if print_is_temporary == VALUE_TYPE_FLOAT:
                    is_print_float = true
                if print_is_temporary == VALUE_TYPE_BOOL:
                    is_print_bool = true
                if is_print_string:
                    append_text(output, "call void @dream_print_string(i8* ")
                if is_print_float:
                    append_text(output, "call void @dream_print_float(double ")
                if is_print_bool:
                    append_text(output, "call void @dream_print_bool(i1 ")
                if not is_print_string and not is_print_float and not is_print_bool:
                    append_text(output, "call void @dream_print_int(i32 ")
                append_operand(output, print_is_temporary, print_value)
                append_text(output, ")\n")
                current_index = skip_source_newlines(source, starts, print_next_index + 1)
                current_counter = print_next_counter
            else:
                if token_kind(kinds, current_index) == TOKEN_IF:
                    let if_expression_index = current_index + 1
                    let (if_header_next_index, if_header_is_temporary, if_header_value, if_header_counter) = parse_expression(source, kinds, starts, ends, if_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                    let if_condition = append_branch_condition(output, if_header_is_temporary, if_header_value, if_header_counter)
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
                    while if_block_end < body_end and is_body_line(source, kinds, starts, if_block_end, if_block_indent):
                        if_block_end = if_block_end + 1
                    let (if_block_counter, if_block_has_return_value) = parse_branch_body(source, kinds, starts, ends, if_block_start, if_block_end, output, variable_starts, variable_ends, variable_types, if_condition + 3, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
                    let if_block_has_return = if_block_has_return_value != 0
                    if not if_block_has_return:
                        append_text(output, "br label %if.end.")
                        append_integer(output, if_end_label)
                        append_text(output, "\n")
                    append_text(output, "if.check.")
                    append_integer(output, if_check_label)
                    append_text(output, ":\n")
                    let branch_index = if_block_end
                    let branch_counter = if_block_counter
                    while token_kind(kinds, branch_index) == TOKEN_ELIF:
                        let elif_expression_index = branch_index + 1
                        let (elif_header_next_index, elif_header_is_temporary, elif_header_value, elif_header_counter) = parse_expression(source, kinds, starts, ends, elif_expression_index, output, variable_starts, variable_ends, variable_types, branch_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                        let elif_condition = append_branch_condition(output, elif_header_is_temporary, elif_header_value, elif_header_counter)
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
                        while elif_block_end < body_end and is_body_line(source, kinds, starts, elif_block_end, elif_block_indent):
                            elif_block_end = elif_block_end + 1
                        let (elif_block_counter, elif_block_has_return_value) = parse_branch_body(source, kinds, starts, ends, elif_block_start, elif_block_end, output, variable_starts, variable_ends, variable_types, elif_condition + 2, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
                        let elif_block_has_return = elif_block_has_return_value != 0
                        if not elif_block_has_return:
                            append_text(output, "br label %if.end.")
                            append_integer(output, if_end_label)
                            append_text(output, "\n")
                        append_text(output, "if.check.")
                        append_integer(output, elif_check_label)
                        append_text(output, ":\n")
                        branch_index = elif_block_end
                        branch_counter = elif_block_counter
                    let has_else_branch = false
                    if token_kind(kinds, branch_index) == TOKEN_ELSE:
                        has_else_branch = true
                    if has_else_branch:
                        let else_block_start = skip_source_newlines(source, starts, branch_index + 1)
                        let else_label = branch_counter + 1
                        append_text(output, "br label %if.else.")
                        append_integer(output, else_label)
                        append_text(output, "\nif.else.")
                        append_integer(output, else_label)
                        append_text(output, ":\n")
                        let else_block_indent = line_indent(source, token_start(starts, else_block_start))
                        let else_block_end = else_block_start
                        while else_block_end < body_end and is_body_line(source, kinds, starts, else_block_end, else_block_indent):
                            else_block_end = else_block_end + 1
                        let (else_block_counter, else_block_has_return_value) = parse_branch_body(source, kinds, starts, ends, else_block_start, else_block_end, output, variable_starts, variable_ends, variable_types, else_label, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, expected_return_type)
                        let else_block_has_return = else_block_has_return_value != 0
                        if not else_block_has_return:
                            append_text(output, "br label %if.end.")
                            append_integer(output, if_end_label)
                            append_text(output, "\n")
                        current_index = else_block_end
                        current_counter = else_block_counter
                    if not has_else_branch:
                        append_text(output, "br label %if.end.")
                        append_integer(output, if_end_label)
                        append_text(output, "\n")
                        current_index = branch_index
                        current_counter = branch_counter
                    append_text(output, "if.end.")
                    append_integer(output, if_end_label)
                    append_text(output, ":\n")
                else:
                    if token_kind(kinds, current_index) == TOKEN_RETURN:
                        let return_expression_index = current_index + 1
                        if token_kind(kinds, return_expression_index) == TOKEN_OPEN_PAREN:
                            let tuple_return_temporary = current_counter + 1
                            append_text(output, "%t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\n")
                            let tuple_return_index = return_expression_index + 1
                            let tuple_return_counter = tuple_return_temporary
                            while token_kind(kinds, tuple_return_index) != TOKEN_CLOSE_PAREN:
                                let (tuple_component_next_index, tuple_component_type, tuple_component_value, tuple_component_counter) = parse_expression(source, kinds, starts, ends, tuple_return_index, output, variable_starts, variable_ends, variable_types, tuple_return_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                                append_text(output, "call void @append_i32(%dynarray_i32* %t")
                                append_integer(output, tuple_return_temporary)
                                append_text(output, ", i32 ")
                                append_operand(output, tuple_component_type, tuple_component_value)
                                append_text(output, ")\n")
                                tuple_return_counter = tuple_component_counter
                                tuple_return_index = tuple_component_next_index
                                if token_kind(kinds, tuple_return_index) == TOKEN_COMMA:
                                    tuple_return_index = tuple_return_index + 1
                            append_text(output, "ret %dynarray_i32* %t")
                            append_integer(output, tuple_return_temporary)
                            append_text(output, "\n")
                            current_counter = tuple_return_counter
                        if token_kind(kinds, return_expression_index) != TOKEN_OPEN_PAREN:
                            let is_tuple_call = false
                            if expected_return_type == VALUE_TYPE_LIST:
                                is_tuple_call = true
                            if is_tuple_call:
                                let (tuple_call_next_index, tuple_call_is_temporary, tuple_call_value, tuple_call_next_counter) = parse_expression(source, kinds, starts, ends, return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                                append_text(output, "ret %dynarray_i32* ")
                                append_operand(output, tuple_call_is_temporary, tuple_call_value)
                                append_text(output, "\n")
                                current_counter = tuple_call_next_counter
                            if not is_tuple_call:
                                let (return_next_index, return_is_temporary, return_value, return_next_counter) = parse_expression(source, kinds, starts, ends, return_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                                if expected_return_type == VALUE_TYPE_BOOL:
                                    if return_is_temporary == VALUE_TYPE_INT:
                                        let boolean_return_temporary = return_next_counter + 1
                                        append_text(output, "%t")
                                        append_integer(output, boolean_return_temporary)
                                        append_text(output, " = icmp ne i32 ")
                                        append_operand(output, return_is_temporary, return_value)
                                        append_text(output, ", 0\n")
                                        append_integer(output, boolean_return_temporary)
                                        append_text(output, "\n")
                                        append_text(output, "ret i1 %t")
                                        append_integer(output, boolean_return_temporary)
                                        append_text(output, "\n")
                                    if return_is_temporary == VALUE_TYPE_BOOL:
                                        append_text(output, "ret i1 ")
                                        append_operand(output, return_is_temporary, return_value)
                                        append_text(output, "\n")
                                if expected_return_type == VALUE_TYPE_FLOAT:
                                    append_text(output, "ret double ")
                                    append_operand(output, return_is_temporary, return_value)
                                    append_text(output, "\n")
                                if expected_return_type != VALUE_TYPE_BOOL and expected_return_type != VALUE_TYPE_FLOAT and return_is_temporary == VALUE_TYPE_STRING:
                                    append_text(output, "ret i8* ")
                                if expected_return_type != VALUE_TYPE_BOOL and expected_return_type != VALUE_TYPE_FLOAT and return_is_temporary != VALUE_TYPE_STRING:
                                    append_text(output, "ret i32 ")
                                if expected_return_type != VALUE_TYPE_BOOL and expected_return_type != VALUE_TYPE_FLOAT:
                                    append_operand(output, return_is_temporary, return_value)
                                    append_text(output, "\n")
                                if expected_return_type == VALUE_TYPE_BOOL and return_is_temporary == VALUE_TYPE_INT:
                                    current_counter = return_next_counter + 1
                                if expected_return_type != VALUE_TYPE_BOOL and expected_return_type != VALUE_TYPE_FLOAT or return_is_temporary != VALUE_TYPE_INT:
                                    current_counter = return_next_counter
                        has_return = true
                        current_index = body_end
                    else:
                        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_index + 1) == TOKEN_OPEN_PAREN:
                            let call_expression_index = current_index
                            let (call_next_index, call_is_temporary, call_value, call_next_counter) = parse_expression(source, kinds, starts, ends, call_expression_index, output, variable_starts, variable_ends, variable_types, current_counter, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                            current_index = skip_source_newlines(source, starts, call_next_index)
                            current_counter = call_next_counter
                        else:
                            current_index = current_index + 1
    if has_return:
        return (current_counter, 1)
    return (current_counter, 0)

def collect_lambdas(source: str, kinds: list[int], starts: list[int], ends: list[int], output: list[int], function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]) -> int:
    let token_index = 0
    let lambda_count = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        let is_lambda = false
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER:
            if source[token_start(starts, token_index):token_end(ends, token_index)] == "lambda":
                is_lambda = true
        if is_lambda:
            let body_start_index = lambda_body_start(kinds, token_index)
            let body_end_index = lambda_body_end(kinds, body_start_index)
            let lambda_parameter_starts = []
            let lambda_parameter_ends = []
            let lambda_parameter_types = []
            let parameter_index = token_index + 2
            while token_kind(kinds, parameter_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, parameter_index) != TOKEN_EOF:
                if token_kind(kinds, parameter_index) == TOKEN_IDENTIFIER and token_kind(kinds, parameter_index + 1) == TOKEN_COLON:
                    append(lambda_parameter_starts, token_start(starts, parameter_index))
                    append(lambda_parameter_ends, token_end(ends, parameter_index))
                    let parameter_type_index = parameter_index + 2
                    append(lambda_parameter_types, get_parameter_type(source, kinds, starts, ends, parameter_type_index))
                parameter_index = parameter_index + 1
            let lambda_body_output = []
            let lambda_variable_starts = lambda_parameter_starts
            let lambda_variable_ends = lambda_parameter_ends
            let lambda_variable_types = lambda_parameter_types
            let (body_next_index, body_type, body_value, body_counter) = parse_expression(source, kinds, starts, ends, body_start_index, lambda_body_output, lambda_variable_starts, lambda_variable_ends, lambda_variable_types, 0, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
            append_text(output, "define ")
            if body_type == VALUE_TYPE_STRING:
                append_text(output, "i8* ")
            if body_type == VALUE_TYPE_LIST:
                append_text(output, "%dynarray_i32* ")
            if body_type == VALUE_TYPE_BOOL:
                append_text(output, "i1 ")
            if body_type == VALUE_TYPE_FLOAT:
                append_text(output, "double ")
            if body_type != VALUE_TYPE_STRING and body_type != VALUE_TYPE_LIST and body_type != VALUE_TYPE_BOOL and body_type != VALUE_TYPE_FLOAT:
                append_text(output, "i32 ")
            append_text(output, "@__dir_lambda_")
            append_integer(output, token_index)
            append_text(output, "(")
            let lambda_parameter_number = 0
            while lambda_parameter_number < len(lambda_parameter_starts):
                if lambda_parameter_number > 0:
                    append_text(output, ", ")
                let parameter_type = lambda_parameter_types[lambda_parameter_number]
                if parameter_type == VALUE_TYPE_STRING:
                    append_text(output, "i8* %")
                if parameter_type == VALUE_TYPE_LIST:
                    append_text(output, "%dynarray_i32* %")
                if parameter_type == VALUE_TYPE_BOOL:
                    append_text(output, "i1 %")
                if parameter_type == VALUE_TYPE_FLOAT:
                    append_text(output, "double %")
                if parameter_type != VALUE_TYPE_STRING and parameter_type != VALUE_TYPE_LIST and parameter_type != VALUE_TYPE_BOOL and parameter_type != VALUE_TYPE_FLOAT:
                    append_text(output, "i32 %")
                append_text(output, source[lambda_parameter_starts[lambda_parameter_number]:lambda_parameter_ends[lambda_parameter_number]])
                append_text(output, ".param")
                lambda_parameter_number = lambda_parameter_number + 1
            append_text(output, ") {\nentry:\n")
            let initialize_parameter_number = 0
            while initialize_parameter_number < len(lambda_parameter_starts):
                let initialized_parameter_type = lambda_parameter_types[initialize_parameter_number]
                let parameter_name = source[lambda_parameter_starts[initialize_parameter_number]:lambda_parameter_ends[initialize_parameter_number]]
                append_local_storage(output, parameter_name, initialized_parameter_type)
                if initialized_parameter_type == VALUE_TYPE_STRING:
                    append_text(output, "store i8* %")
                if initialized_parameter_type == VALUE_TYPE_LIST:
                    append_text(output, "store %dynarray_i32* %")
                if initialized_parameter_type == VALUE_TYPE_BOOL:
                    append_text(output, "store i1 %")
                if initialized_parameter_type == VALUE_TYPE_FLOAT:
                    append_text(output, "store double %")
                if initialized_parameter_type != VALUE_TYPE_STRING and initialized_parameter_type != VALUE_TYPE_LIST and initialized_parameter_type != VALUE_TYPE_BOOL and initialized_parameter_type != VALUE_TYPE_FLOAT:
                    append_text(output, "store i32 %")
                append_text(output, parameter_name)
                append_text(output, ".param, ")
                if initialized_parameter_type == VALUE_TYPE_STRING:
                    append_text(output, "i8** %")
                if initialized_parameter_type == VALUE_TYPE_LIST:
                    append_text(output, "%dynarray_i32** %")
                if initialized_parameter_type == VALUE_TYPE_BOOL:
                    append_text(output, "i1* %")
                if initialized_parameter_type == VALUE_TYPE_FLOAT:
                    append_text(output, "double* %")
                if initialized_parameter_type != VALUE_TYPE_STRING and initialized_parameter_type != VALUE_TYPE_LIST and initialized_parameter_type != VALUE_TYPE_BOOL and initialized_parameter_type != VALUE_TYPE_FLOAT:
                    append_text(output, "i32* %")
                append_text(output, parameter_name)
                append_text(output, "\n")
                initialize_parameter_number = initialize_parameter_number + 1
            append_code_range(output, lambda_body_output, 0, len(lambda_body_output))
            append_text(output, "ret ")
            if body_type == VALUE_TYPE_STRING:
                append_text(output, "i8* ")
            if body_type == VALUE_TYPE_LIST:
                append_text(output, "%dynarray_i32* ")
            if body_type == VALUE_TYPE_BOOL:
                append_text(output, "i1 ")
            if body_type == VALUE_TYPE_FLOAT:
                append_text(output, "double ")
            if body_type != VALUE_TYPE_STRING and body_type != VALUE_TYPE_LIST and body_type != VALUE_TYPE_BOOL and body_type != VALUE_TYPE_FLOAT:
                append_text(output, "i32 ")
            append_operand(output, body_type, body_value)
            append_text(output, "\n}\n")
            lambda_count = lambda_count + 1
        token_index = token_index + 1
    return lambda_count

def emit_function(source: str, kinds: list[int], starts: list[int], ends: list[int], function_index: int, output: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int], function_return_types: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]) -> int:
    let function_output = []
    append_text(function_output, "; function_index=")
    append_integer(function_output, function_index)
    append_text(function_output, "; body_start=")
    append_integer(function_output, function_bodies[function_index])
    append_text(function_output, "; body_end=")
    append_integer(function_output, function_body_ends[function_index])
    append_text(function_output, "\n")
    let function_name_start = function_starts[function_index]
    let function_name_end = function_ends[function_index]
    let function_result_type_value = function_return_types[function_index]
    if function_result_type_value == VALUE_TYPE_LIST:
        append_text(function_output, "define %dynarray_i32* @")
    if function_result_type_value == VALUE_TYPE_STRING:
        append_text(function_output, "define i8* @")
    if function_result_type_value == VALUE_TYPE_BOOL:
        append_text(function_output, "define i1 @")
    if function_result_type_value == VALUE_TYPE_FLOAT:
        append_text(function_output, "define double @")
    if function_result_type_value != VALUE_TYPE_STRING and function_result_type_value != VALUE_TYPE_LIST and function_result_type_value != VALUE_TYPE_BOOL and function_result_type_value != VALUE_TYPE_FLOAT:
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
        if parameter_types[emit_parameter_position] == VALUE_TYPE_STRING:
            append_text(function_output, "i8* %")
        if parameter_types[emit_parameter_position] == VALUE_TYPE_LIST:
            append_text(function_output, "%dynarray_i32* %")
        if parameter_types[emit_parameter_position] == VALUE_TYPE_BOOL:
            append_text(function_output, "i1 %")
        if parameter_types[emit_parameter_position] == VALUE_TYPE_FLOAT:
            append_text(function_output, "double %")
        if parameter_types[emit_parameter_position] != VALUE_TYPE_STRING and parameter_types[emit_parameter_position] != VALUE_TYPE_LIST and parameter_types[emit_parameter_position] != VALUE_TYPE_BOOL and parameter_types[emit_parameter_position] != VALUE_TYPE_FLOAT:
            append_text(function_output, "i32 %")
        append_text(function_output, source[parameter_starts[emit_parameter_position]:parameter_ends[emit_parameter_position]])
        append_text(function_output, ".param")
        parameter_index = parameter_index + 1
    append_text(function_output, ") {\nentry:\n")

    let variable_starts = []
    let variable_ends = []
    let variable_types = []
    let constant_index = 0
    while constant_index < len(constant_starts):
        let constant_name_start = constant_starts[constant_index]
        let constant_name_end = constant_ends[constant_index]
        let constant_name = source[constant_name_start:constant_name_end]
        if constant_is_used(source, kinds, starts, ends, function_bodies[function_index], function_body_ends[function_index], constant_name_start, constant_name_end):
            append(variable_starts, constant_name_start)
            append(variable_ends, constant_name_end)
            append(variable_types, VALUE_TYPE_GLOBAL)
        constant_index = constant_index + 1
    let initialize_index = 0
    while initialize_index < parameter_count:
        let initialize_parameter_position = parameter_offset + initialize_index
        let parameter_name_start = parameter_starts[initialize_parameter_position]
        let parameter_name_end = parameter_ends[initialize_parameter_position]
        let initialize_parameter_type = parameter_types[initialize_parameter_position]
        let parameter_name = source[parameter_name_start:parameter_name_end]
        if initialize_parameter_type == VALUE_TYPE_STRING:
            append_local_storage(function_output, parameter_name, VALUE_TYPE_STRING)
            append_text(function_output, "store i8* %")
        if initialize_parameter_type == VALUE_TYPE_LIST:
            append_local_storage(function_output, parameter_name, VALUE_TYPE_LIST)
            append_text(function_output, "store %dynarray_i32* %")
        if initialize_parameter_type == VALUE_TYPE_BOOL:
            append_local_storage(function_output, parameter_name, VALUE_TYPE_BOOL)
            append_text(function_output, "store i1 %")
        if initialize_parameter_type == VALUE_TYPE_FLOAT:
            append_local_storage(function_output, parameter_name, VALUE_TYPE_FLOAT)
            append_text(function_output, "store double %")
        if initialize_parameter_type != VALUE_TYPE_STRING and initialize_parameter_type != VALUE_TYPE_LIST and initialize_parameter_type != VALUE_TYPE_BOOL and initialize_parameter_type != VALUE_TYPE_FLOAT:
            append_local_storage(function_output, parameter_name, VALUE_TYPE_INT)
            append_text(function_output, "store i32 %")
        append_text(function_output, parameter_name)
        if initialize_parameter_type == VALUE_TYPE_STRING:
            append_text(function_output, ".param, i8** %")
        if initialize_parameter_type == VALUE_TYPE_LIST:
            append_text(function_output, ".param, %dynarray_i32** %")
        if initialize_parameter_type == VALUE_TYPE_BOOL:
            append_text(function_output, ".param, i1* %")
        if initialize_parameter_type == VALUE_TYPE_FLOAT:
            append_text(function_output, ".param, double* %")
        if initialize_parameter_type != VALUE_TYPE_STRING and initialize_parameter_type != VALUE_TYPE_LIST and initialize_parameter_type != VALUE_TYPE_BOOL and initialize_parameter_type != VALUE_TYPE_FLOAT:
            append_text(function_output, ".param, i32* %")
        append_text(function_output, source[parameter_name_start:parameter_name_end])
        append_text(function_output, "\n")
        append(variable_starts, parameter_name_start)
        append(variable_ends, parameter_name_end)
        append(variable_types, initialize_parameter_type)
        initialize_index = initialize_index + 1

    let (next_counter, has_return_value) = parse_function_body(source, kinds, starts, ends, function_bodies[function_index], function_body_ends[function_index], function_output, variable_starts, variable_ends, variable_types, 0, function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types, function_result_type_value)
    let has_return = has_return_value != 0
    if not has_return:
        if function_result_type_value == VALUE_TYPE_LIST:
            append_text(function_output, "%t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\nret %dynarray_i32* %t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, "\n")
        if function_result_type_value == VALUE_TYPE_FLOAT:
            append_text(function_output, "ret double 0.0\n")
        if function_result_type_value != VALUE_TYPE_LIST:
            if function_result_type_value == VALUE_TYPE_BOOL:
                append_text(function_output, "ret i1 0\n")
            if function_result_type_value != VALUE_TYPE_BOOL and function_result_type_value != VALUE_TYPE_FLOAT:
                append_text(function_output, "ret i32 0\n")
    append_text(function_output, "}\n")
    append_hoisted_function(output, function_output)
    return next_counter
