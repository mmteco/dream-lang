def parse_assignment(context: ParseContext, index: int, output: list[int], records: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends

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
    if variable_is_dictionary(variable_types, assignment_variable_index) and is_list_element_assignment:
        let dictionary_temporary = temporary_counter + 1
        append_text(output, "%t")
        append_integer(output, dictionary_temporary)
        append_text(output, " = load %dict_t*, %dict_t** %")
        append_variable_name(output, source[assignment_name_start:assignment_name_end], variable_types[assignment_variable_index])
        append_text(output, "\n")
        let (key_next_index, key_type, key_value, key_counter) = parse_expression(context, list_index_start, output, records, variable_starts, variable_ends, variable_types, dictionary_temporary)
        let (value_next_index, value_type, value_value, value_counter) = parse_expression(context, key_next_index + 2, output, records, variable_starts, variable_ends, variable_types, key_counter)
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
        let (index_next_index, index_is_temporary, index_value, index_next_counter) = parse_index_atom(context, list_index_start, output, records, variable_starts, variable_ends, variable_types, list_temporary)
        let (list_assignment_next_index, list_assignment_is_temporary, list_assignment_value, list_assignment_next_counter) = parse_expression(context, index_next_index + 2, output, records, variable_starts, variable_ends, variable_types, index_next_counter)
        append_text(output, "call void @set_dynarray_i32(%dynarray_i32* %t")
        append_integer(output, list_temporary)
        append_text(output, ", i32 ")
        append_operand(output, index_is_temporary, index_value)
        append_text(output, ", i32 ")
        append_operand(output, list_assignment_is_temporary, list_assignment_value)
        append_text(output, ")\n")
        return (skip_source_newlines(source, starts, list_assignment_next_index), list_assignment_next_counter)
    let (assignment_next_index, assignment_is_temporary, assignment_value, assignment_next_counter) = parse_expression(context, assignment_expression_index, output, records, variable_starts, variable_ends, variable_types, temporary_counter)
    let is_string_assignment = false
    let is_list_assignment = false
    let is_dictionary_assignment = false
    let is_float_assignment = false
    let is_bool_assignment = false
    let is_closure_assignment = false
    let is_global_let_assignment = false
    if assignment_variable_index >= 0:
        if variable_types[assignment_variable_index] == VALUE_TYPE_STRING:
            is_string_assignment = true
        if is_sequence_value_type(variable_types[assignment_variable_index]):
            is_list_assignment = true
        if is_dictionary_value_type(variable_types[assignment_variable_index]):
            is_dictionary_assignment = true
        if variable_types[assignment_variable_index] == VALUE_TYPE_FLOAT:
            is_float_assignment = true
        if variable_types[assignment_variable_index] == VALUE_TYPE_BOOL:
            is_bool_assignment = true
        if is_closure_value_type(variable_types[assignment_variable_index]):
            is_closure_assignment = true
        if is_global_let_value_type(variable_types[assignment_variable_index]):
            is_global_let_assignment = true
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
    if is_closure_assignment:
        append_text(output, "store %dir_closure* ")
    if not is_string_assignment and not is_list_assignment and not is_dictionary_assignment and not is_float_assignment and not is_bool_assignment and not is_closure_assignment and not is_global_let_assignment:
        append_text(output, "store i32 ")
    if is_global_let_assignment:
        append_text(output, "store ")
        append_llvm_type_text(output, global_let_base_type(variable_types[assignment_variable_index]))
        append_text(output, " ")
    append_operand(output, assignment_is_temporary, assignment_value)
    if is_global_let_assignment:
        append_text(output, ", ")
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
    if is_closure_assignment:
        append_text(output, ", %dir_closure** %")
    if not is_string_assignment and not is_list_assignment and not is_dictionary_assignment and not is_float_assignment and not is_bool_assignment and not is_closure_assignment and not is_global_let_assignment:
        append_text(output, ", i32* %")
    if is_global_let_assignment:
        append_llvm_type_text(output, global_let_base_type(variable_types[assignment_variable_index]))
        append_text(output, "* @")
        append_variable_name(output, source[assignment_name_start:assignment_name_end], VALUE_TYPE_GLOBAL)
        append_text(output, "\n")
        return (skip_source_newlines(source, starts, assignment_next_index), assignment_next_counter)
    append_variable_name(output, source[assignment_name_start:assignment_name_end], variable_types[assignment_variable_index])
    append_text(output, "\n")
    return (skip_source_newlines(source, starts, assignment_next_index), assignment_next_counter)

def parse_branch_body(context: ParseContext, branch_start: int, branch_end: int, output: list[int], records: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, expected_return_type: int) -> (int, int):

    return parse_function_body(context, branch_start, branch_end, output, records, variable_starts, variable_ends, variable_types, temporary_counter, expected_return_type)

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
    if value_type == VALUE_TYPE_STRING or is_sequence_value_type(value_type) or is_dictionary_value_type(value_type) or is_closure_value_type(value_type) or is_interface_value_type(value_type):
        append_text(output, " = icmp ne ")
        append_llvm_type_text(output, value_type)
        append_text(output, " ")
        append_operand(output, value_type, value)
        append_text(output, ", null\n")
    else:
        append_text(output, " = icmp ne i32 ")
        append_operand(output, value_type, value)
        append_text(output, ", 0\n")
    return integer_condition_temporary

def parse_switch_statement(context: ParseContext, switch_index: int, body_end: int, output: list[int], records: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, expected_return_type: int) -> (int, int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts

    let switch_expression_index = switch_index + 1
    let (switch_header_next_index, switch_header_is_temporary, switch_header_value, switch_header_counter) = parse_expression(context, switch_expression_index, output, records, variable_starts, variable_ends, variable_types, temporary_counter)
    let switch_label_base = switch_header_counter + 1000
    let switch_end_label = switch_label_base
    let case_index = skip_source_newlines(source, starts, switch_header_next_index + 1)
    let case_number = 0
    let current_counter = switch_header_counter
    let all_cases_return = true
    while token_kind(kinds, case_index) == TOKEN_CASE:
        let case_value_index = case_index + 1
        let (case_header_next_index, case_value_is_temporary, case_value, case_header_counter) = parse_expression(context, case_value_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
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
        let (case_body_counter, case_body_has_return_value) = parse_branch_body(context, case_body_start, case_body_end, output, records, variable_starts, variable_ends, variable_types, case_condition, expected_return_type)
        let case_body_has_return = case_body_has_return_value != 0
        if not case_body_has_return:
            all_cases_return = false
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
    let default_body_has_return = false
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
        let (default_body_counter, default_body_has_return_value) = parse_branch_body(context, default_body_start, default_body_end, output, records, variable_starts, variable_ends, variable_types, current_counter, expected_return_type)
        default_body_has_return = default_body_has_return_value != 0
        if not default_body_has_return:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        current_counter = default_body_counter
        case_index = default_body_end
    let switch_has_return = 0
    if has_default:
        if default_body_has_return and all_cases_return:
            switch_has_return = 1
    if switch_has_return == 0:
        if not has_default:
            append_text(output, "br label %switch.end.")
            append_integer(output, switch_end_label)
            append_text(output, "\n")
        append_text(output, "switch.end.")
        append_integer(output, switch_end_label)
        append_text(output, ":\n")
    return (case_index, current_counter, switch_has_return)

def parse_for_statement(context: ParseContext, for_index: int, body_end: int, output: list[int], records: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, expected_return_type: int) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends

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
    append_variable_name(output, source[loop_name_start:loop_name_end], VALUE_TYPE_INT)
    append_text(output, "\n")
    append(variable_starts, loop_name_start)
    append(variable_ends, loop_name_end)
    append(variable_types, VALUE_TYPE_INT)
    let loop_body_start = skip_source_newlines(source, starts, colon_index + 1)
    let loop_body_indent = line_indent(source, token_start(starts, loop_body_start))
    let loop_body_end = loop_body_start
    while loop_body_end < body_end and is_body_line(source, kinds, starts, loop_body_end, loop_body_indent):
        loop_body_end = loop_body_end + 1
    let (loop_body_counter, loop_body_has_return_value) = parse_branch_body(context, loop_body_start, loop_body_end, output, records, variable_starts, variable_ends, variable_types, element_temporary, expected_return_type)
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

def append_native_typed_return(records: list[int], expected_return_type: int, operand_type: int, operand_value: int) -> bool:
    let dir_value_type = DIR_TYPE_I32
    if expected_return_type == VALUE_TYPE_BOOL:
        dir_value_type = DIR_TYPE_BOOL
    if expected_return_type == VALUE_TYPE_STRING:
        dir_value_type = DIR_TYPE_POINTER
    if is_sequence_value_type(expected_return_type):
        dir_value_type = DIR_TYPE_LIST
    if expected_return_type == VALUE_TYPE_FLOAT:
        return false
    let operand_kind = DIR_TAG_INVALID
    if operand_type == VALUE_TYPE_IMMEDIATE:
        operand_kind = DIR_NATIVE_OPERAND_IMMEDIATE
    elif is_temporary_value_type(operand_type):
        operand_kind = DIR_NATIVE_OPERAND_TEMPORARY
    if operand_kind == DIR_TAG_INVALID:
        return false
    dir_append_native_ret(records, dir_value_type, operand_kind, operand_value)
    return true

def append_typed_return(output: list[int], records: list[int], expected_return_type: int, operand_type: int, operand_value: int, temporary_counter: int) -> int:
    if is_sequence_value_type(expected_return_type):
        if append_native_typed_return(records, expected_return_type, operand_type, operand_value):
            return temporary_counter
        append_text(output, "ret %dynarray_i32* ")
        append_operand(output, operand_type, operand_value)
        append_text(output, "\n")
        return temporary_counter
    if expected_return_type == VALUE_TYPE_BOOL:
        if operand_type == VALUE_TYPE_INT:
            let boolean_return_temporary = temporary_counter + 1
            append_text(output, "%t")
            append_integer(output, boolean_return_temporary)
            append_text(output, " = icmp ne i32 ")
            append_operand(output, operand_type, operand_value)
            append_text(output, ", 0\n")
            dir_flush_line(records, output)
            if append_native_typed_return(records, expected_return_type, VALUE_TYPE_BOOL, boolean_return_temporary):
                return boolean_return_temporary
            append_text(output, "ret i1 %t")
            append_integer(output, boolean_return_temporary)
            append_text(output, "\n")
            return boolean_return_temporary
        if operand_type == VALUE_TYPE_BOOL:
            if append_native_typed_return(records, expected_return_type, operand_type, operand_value):
                return temporary_counter
            append_text(output, "ret i1 ")
            append_operand(output, operand_type, operand_value)
            append_text(output, "\n")
            return temporary_counter
        return temporary_counter
    if expected_return_type == VALUE_TYPE_FLOAT:
        append_text(output, "ret double ")
        append_operand(output, operand_type, operand_value)
        append_text(output, "\n")
        return temporary_counter
    if append_native_typed_return(records, expected_return_type, operand_type, operand_value):
        return temporary_counter
    if operand_type == VALUE_TYPE_STRING:
        append_text(output, "ret i8* ")
    if operand_type != VALUE_TYPE_STRING:
        append_text(output, "ret i32 ")
    append_operand(output, operand_type, operand_value)
    append_text(output, "\n")
    return temporary_counter

def parse_function_body(context: ParseContext, body_start: int, body_end: int, output: list[int], records: list[int], variable_starts: list[int], variable_ends: list[int], variable_types: list[int], temporary_counter: int, expected_return_type: int) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends

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
        let is_match_statement = false
        switch statement_token_kind:
            case TOKEN_LET:
                if next_statement_token_kind == TOKEN_OPEN_PAREN:
                    is_tuple_let_statement = true
                else:
                    is_let_statement = true
            case TOKEN_IDENTIFIER:
                if next_statement_token_kind == TOKEN_ASSIGN:
                    is_assignment_statement = true
                elif next_statement_token_kind == TOKEN_OPEN_BRACKET:
                    let assignment_probe_index = current_index + 2
                    while token_kind(kinds, assignment_probe_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, assignment_probe_index) != TOKEN_EOF:
                        assignment_probe_index = assignment_probe_index + 1
                    if token_kind(kinds, assignment_probe_index) == TOKEN_CLOSE_BRACKET and token_kind(kinds, assignment_probe_index + 1) == TOKEN_ASSIGN:
                        is_assignment_statement = true
                else:
                    if source[token_start(starts, current_index):token_end(ends, current_index)] == "match":
                        is_match_statement = true
            case TOKEN_SWITCH:
                is_switch_statement = true
            case TOKEN_WHILE:
                is_while_statement = true
            case TOKEN_FOR:
                is_for_statement = true
        let is_known_statement = false
        if is_let_statement or is_tuple_let_statement or is_assignment_statement or is_switch_statement or is_while_statement or is_for_statement or is_match_statement:
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
            let (let_next_index, let_is_temporary, let_value, let_next_counter) = parse_expression(context, let_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
            let annotated_interface_name = ""
            if token_kind(kinds, current_index + 2) == TOKEN_COLON:
                let annotation_type_index = current_index + 3
                if token_kind(kinds, annotation_type_index) == TOKEN_IDENTIFIER and source_type_is_interface(source, kinds, starts, ends, token_start(starts, annotation_type_index), token_end(ends, annotation_type_index)):
                    annotated_interface_name = source[token_start(starts, annotation_type_index):token_end(ends, annotation_type_index)]
            if text_length(annotated_interface_name) > 0 and let_is_temporary == VALUE_TYPE_LIST:
                let concrete_struct_name = struct_name_for_literal(source, kinds, starts, ends, let_expression_index)
                if text_length(concrete_struct_name) > 0:
                    let interface_method_total = interface_method_count(source, kinds, starts, ends, annotated_interface_name)
                    let interface_value_temporary = make_interface_value(output, let_value, annotated_interface_name, concrete_struct_name, interface_method_total, let_next_counter)
                    let_is_temporary = VALUE_TYPE_INTERFACE
                    let_value = interface_value_temporary
                    let_next_counter = interface_value_temporary + 3
            let is_function_binding = is_function_value_type(let_is_temporary) and not is_closure_value_type(let_is_temporary)
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
                append_variable_name(output, source[name_start:name_end], VALUE_TYPE_INT)
                append_text(output, "\n")
                append(variable_starts, name_start)
                append(variable_ends, name_end)
                append(variable_types, VALUE_TYPE_INT)
                current_index = skip_source_newlines(source, starts, let_next_index + 1)
                current_counter = question_value_temporary
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_STRING:
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], 2)
                append_text(output, "store i8* ")
            if not is_question_binding and not is_function_binding and is_sequence_value_type(let_is_temporary):
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], 3)
                append_text(output, "store %dynarray_i32* ")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_FLOAT:
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], 10)
                append_text(output, "store double ")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_BOOL:
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], 4)
                append_text(output, "store i1 ")
            if not is_question_binding and not is_function_binding and is_dictionary_value_type(let_is_temporary):
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], let_is_temporary)
                append_text(output, "store %dict_t* ")
            if not is_question_binding and not is_function_binding and is_closure_value_type(let_is_temporary):
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], let_is_temporary)
                append_text(output, "store %dir_closure* ")
            if not is_question_binding and not is_function_binding and is_interface_value_type(let_is_temporary):
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], let_is_temporary)
                append_text(output, "store %dir_interface* ")
            if not is_question_binding and not is_function_binding and let_is_temporary != VALUE_TYPE_STRING and not is_sequence_value_type(let_is_temporary) and let_is_temporary != VALUE_TYPE_BOOL and let_is_temporary != VALUE_TYPE_FLOAT and not is_dictionary_value_type(let_is_temporary) and not is_closure_value_type(let_is_temporary) and not is_interface_value_type(let_is_temporary):
                if find_variable(source, name_start, name_end, variable_starts, variable_ends) == -1:
                    append_local_storage(output, source[name_start:name_end], 1)
                append_text(output, "store i32 ")
            if not is_question_binding and not is_function_binding:
                append_operand(output, let_is_temporary, let_value)
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_STRING:
                append_text(output, ", i8** %")
            if not is_question_binding and not is_function_binding and is_sequence_value_type(let_is_temporary):
                append_text(output, ", %dynarray_i32** %")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_FLOAT:
                append_text(output, ", double* %")
            if not is_question_binding and not is_function_binding and let_is_temporary == VALUE_TYPE_BOOL:
                append_text(output, ", i1* %")
            if not is_question_binding and not is_function_binding and is_dictionary_value_type(let_is_temporary):
                append_text(output, ", %dict_t** %")
            if not is_question_binding and not is_function_binding and is_closure_value_type(let_is_temporary):
                append_text(output, ", %dir_closure** %")
            if not is_question_binding and not is_function_binding and is_interface_value_type(let_is_temporary):
                append_text(output, ", %dir_interface** %")
            if not is_question_binding and not is_function_binding and let_is_temporary != VALUE_TYPE_STRING and not is_sequence_value_type(let_is_temporary) and let_is_temporary != VALUE_TYPE_BOOL and let_is_temporary != VALUE_TYPE_FLOAT and not is_dictionary_value_type(let_is_temporary) and not is_closure_value_type(let_is_temporary) and not is_interface_value_type(let_is_temporary):
                append_text(output, ", i32* %")
            if not is_question_binding:
                if not is_function_binding:
                    append_variable_name(output, source[name_start:name_end], let_is_temporary)
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
            let (tuple_next_index, tuple_is_temporary, tuple_value, tuple_next_counter) = parse_expression(context, tuple_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
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
                append_variable_name(output, source[tuple_name_starts[tuple_element_index]:tuple_name_ends[tuple_element_index]], VALUE_TYPE_INT)
                append_text(output, "\n")
                append(variable_starts, tuple_name_starts[tuple_element_index])
                append(variable_ends, tuple_name_ends[tuple_element_index])
                append(variable_types, VALUE_TYPE_INT)
                tuple_element_index = tuple_element_index + 1
            current_index = skip_source_newlines(source, starts, tuple_next_index)
            current_counter = tuple_next_counter + len(tuple_name_starts)
        if is_assignment_statement:
            let (assignment_next_index, assignment_next_counter) = parse_assignment(context, current_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
            current_index = assignment_next_index
            current_counter = assignment_next_counter
        if is_switch_statement:
            let (switch_next_index, switch_next_counter, switch_has_return) = parse_switch_statement(context, current_index, body_end, output, records, variable_starts, variable_ends, variable_types, current_counter, expected_return_type)
            current_index = switch_next_index
            current_counter = switch_next_counter
            if switch_has_return != 0:
                has_return = true
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
            let (while_header_next_index, while_header_is_temporary, while_header_value, while_header_counter) = parse_expression(context, while_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
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
            let (while_body_result_counter, while_body_has_return_value) = parse_branch_body(context, while_body_start, while_body_end, output, records, variable_starts, variable_ends, variable_types, while_body_counter, expected_return_type)
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
            let (for_next_index, for_next_counter) = parse_for_statement(context, current_index, body_end, output, records, variable_starts, variable_ends, variable_types, current_counter, expected_return_type)
            current_index = for_next_index
            current_counter = for_next_counter
        if is_match_statement:
            let (match_next_index, match_result_type, match_result_value, match_next_counter) = parse_match_expression(context, current_index, output, records, variable_starts, variable_ends, variable_types, current_counter, true)
            current_index = skip_source_newlines(source, starts, match_next_index)
            current_counter = match_next_counter
        if not is_known_statement:
            if token_kind(kinds, current_index) == TOKEN_PRINT:
                let print_expression_index = current_index + 2
                let (print_next_index, print_is_temporary, print_value, print_next_counter) = parse_expression(context, print_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
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
                    let (if_header_next_index, if_header_is_temporary, if_header_value, if_header_counter) = parse_expression(context, if_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
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
                    let (if_block_counter, if_block_has_return_value) = parse_branch_body(context, if_block_start, if_block_end, output, records, variable_starts, variable_ends, variable_types, if_condition + 3, expected_return_type)
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
                        let (elif_header_next_index, elif_header_is_temporary, elif_header_value, elif_header_counter) = parse_expression(context, elif_expression_index, output, records, variable_starts, variable_ends, variable_types, branch_counter)
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
                        let (elif_block_counter, elif_block_has_return_value) = parse_branch_body(context, elif_block_start, elif_block_end, output, records, variable_starts, variable_ends, variable_types, elif_condition + 2, expected_return_type)
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
                        let else_block_start = skip_source_newlines(source, starts, branch_index + 2)
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
                        let (else_block_counter, else_block_has_return_value) = parse_branch_body(context, else_block_start, else_block_end, output, records, variable_starts, variable_ends, variable_types, else_label, expected_return_type)
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
                                let (tuple_component_next_index, tuple_component_type, tuple_component_value, tuple_component_counter) = parse_expression(context, tuple_return_index, output, records, variable_starts, variable_ends, variable_types, tuple_return_counter)
                                if tuple_component_type == VALUE_TYPE_FLOAT:
                                    append_text(output, "call void @append_f64(%dynarray_i32* %t")
                                    append_integer(output, tuple_return_temporary)
                                    append_text(output, ", double ")
                                    append_operand(output, tuple_component_type, tuple_component_value)
                                    append_text(output, ")\n")
                                if tuple_component_type == VALUE_TYPE_STRING or is_sequence_value_type(tuple_component_type) or is_dictionary_value_type(tuple_component_type) or is_closure_value_type(tuple_component_type):
                                    append_text(output, "call void @append_pointer(%dynarray_i32* %t")
                                    append_integer(output, tuple_return_temporary)
                                    append_text(output, ", i8* ")
                                    append_operand(output, tuple_component_type, tuple_component_value)
                                    append_text(output, ")\n")
                                if tuple_component_type != VALUE_TYPE_FLOAT and tuple_component_type != VALUE_TYPE_STRING and not is_sequence_value_type(tuple_component_type) and not is_dictionary_value_type(tuple_component_type) and not is_closure_value_type(tuple_component_type):
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
                                let (tuple_call_next_index, tuple_call_is_temporary, tuple_call_value, tuple_call_next_counter) = parse_expression(context, return_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
                                append_text(output, "ret %dynarray_i32* ")
                                append_operand(output, tuple_call_is_temporary, tuple_call_value)
                                append_text(output, "\n")
                                current_counter = tuple_call_next_counter
                            if not is_tuple_call:
                                let (return_next_index, return_is_temporary, return_value, return_next_counter) = parse_expression(context, return_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
                                current_counter = append_typed_return(output, records, expected_return_type, return_is_temporary, return_value, return_next_counter)
                        has_return = true
                        current_index = body_end
                    else:
                        if token_kind(kinds, current_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_index + 1) == TOKEN_OPEN_PAREN:
                            let call_expression_index = current_index
                            let (call_next_index, call_is_temporary, call_value, call_next_counter) = parse_expression(context, call_expression_index, output, records, variable_starts, variable_ends, variable_types, current_counter)
                            current_index = skip_source_newlines(source, starts, call_next_index)
                            current_counter = call_next_counter
                        else:
                            current_index = current_index + 1
    dir_flush_line(records, output)
    if has_return:
        return (current_counter, 1)
    return (current_counter, 0)

def collect_lambdas(context: ParseContext, output: list[int], records: list[int]) -> int:
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
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
            let lambda_body_output = [1]
            let lambda_body_records = []
            let lambda_parameter_count = len(lambda_parameter_starts)
            let lambda_capture_starts = []
            let lambda_capture_ends = []
            collect_lambda_captures(source, kinds, starts, ends, body_start_index, body_end_index, lambda_parameter_starts, lambda_parameter_ends, lambda_capture_starts, lambda_capture_ends)
            let lambda_variable_starts = lambda_parameter_starts
            let lambda_variable_ends = lambda_parameter_ends
            let lambda_variable_types = lambda_parameter_types
            let lambda_capture_index = 0
            while lambda_capture_index < len(lambda_capture_starts):
                append(lambda_variable_starts, lambda_capture_starts[lambda_capture_index])
                append(lambda_variable_ends, lambda_capture_ends[lambda_capture_index])
                let lambda_capture_type_value = lambda_capture_type(source, kinds, starts, ends, token_index, lambda_capture_starts[lambda_capture_index], lambda_capture_ends[lambda_capture_index])
                append(lambda_variable_types, lambda_capture_type_value)
                lambda_capture_index = lambda_capture_index + 1
            let (body_next_index, body_type, body_value, body_counter) = parse_expression(context, body_start_index, lambda_body_output, lambda_body_records, lambda_variable_starts, lambda_variable_ends, lambda_variable_types, 0)
            dir_flush_line(lambda_body_records, lambda_body_output)
            append_text(output, "define ")
            if is_closure_value_type(body_type):
                append_text(output, "%dir_closure* ")
            else:
                switch body_type:
                    case VALUE_TYPE_STRING:
                        append_text(output, "i8* ")
                    case VALUE_TYPE_LIST:
                        append_text(output, "%dynarray_i32* ")
                    case VALUE_TYPE_BYTES:
                        append_text(output, "%dynarray_i32* ")
                    case VALUE_TYPE_BOOL:
                        append_text(output, "i1 ")
                    case VALUE_TYPE_FLOAT:
                        append_text(output, "double ")
                    default:
                        append_text(output, "i32 ")
            append_text(output, "@__dir_lambda_")
            append_integer(output, token_index)
            append_text(output, "(")
            let lambda_parameter_number = 0
            while lambda_parameter_number < len(lambda_variable_starts):
                if lambda_parameter_number > 0:
                    append_text(output, ", ")
                let parameter_type = lambda_variable_types[lambda_parameter_number]
                if is_closure_value_type(parameter_type):
                    append_text(output, "%dir_closure* %")
                else:
                    switch parameter_type:
                        case VALUE_TYPE_STRING:
                            append_text(output, "i8* %")
                        case VALUE_TYPE_LIST:
                            append_text(output, "%dynarray_i32* %")
                        case VALUE_TYPE_BYTES:
                            append_text(output, "%dynarray_i32* %")
                        case VALUE_TYPE_BOOL:
                            append_text(output, "i1 %")
                        case VALUE_TYPE_FLOAT:
                            append_text(output, "double %")
                        default:
                            append_text(output, "i32 %")
                append_text(output, source[lambda_variable_starts[lambda_parameter_number]:lambda_variable_ends[lambda_parameter_number]])
                if lambda_parameter_number < lambda_parameter_count:
                    append_text(output, ".param")
                if lambda_parameter_number >= lambda_parameter_count:
                    append_text(output, ".capture")
                lambda_parameter_number = lambda_parameter_number + 1
            append_text(output, ") {\nentry:\n")
            let initialize_parameter_number = 0
            while initialize_parameter_number < len(lambda_variable_starts):
                let initialized_parameter_type = lambda_variable_types[initialize_parameter_number]
                let parameter_name = source[lambda_variable_starts[initialize_parameter_number]:lambda_variable_ends[initialize_parameter_number]]
                append_local_storage(output, parameter_name, initialized_parameter_type)
                if is_closure_value_type(initialized_parameter_type):
                    append_text(output, "store %dir_closure* %")
                else:
                    switch initialized_parameter_type:
                        case VALUE_TYPE_STRING:
                            append_text(output, "store i8* %")
                        case VALUE_TYPE_LIST:
                            append_text(output, "store %dynarray_i32* %")
                        case VALUE_TYPE_BYTES:
                            append_text(output, "store %dynarray_i32* %")
                        case VALUE_TYPE_BOOL:
                            append_text(output, "store i1 %")
                        case VALUE_TYPE_FLOAT:
                            append_text(output, "store double %")
                        default:
                            append_text(output, "store i32 %")
                append_text(output, parameter_name)
                if initialize_parameter_number < lambda_parameter_count:
                    append_text(output, ".param, ")
                if initialize_parameter_number >= lambda_parameter_count:
                    append_text(output, ".capture, ")
                if is_closure_value_type(initialized_parameter_type):
                    append_text(output, "%dir_closure** %")
                else:
                    switch initialized_parameter_type:
                        case VALUE_TYPE_STRING:
                            append_text(output, "i8** %")
                        case VALUE_TYPE_LIST:
                            append_text(output, "%dynarray_i32** %")
                        case VALUE_TYPE_BYTES:
                            append_text(output, "%dynarray_i32** %")
                        case VALUE_TYPE_BOOL:
                            append_text(output, "i1* %")
                        case VALUE_TYPE_FLOAT:
                            append_text(output, "double* %")
                        default:
                            append_text(output, "i32* %")
                append_variable_name(output, parameter_name, initialized_parameter_type)
                append_text(output, "\n")
                initialize_parameter_number = initialize_parameter_number + 1
            dir_flush_line(records, output)
            dir_merge_records(records, lambda_body_records)
            append_text(output, "ret ")
            if is_closure_value_type(body_type):
                append_text(output, "%dir_closure* ")
            else:
                switch body_type:
                    case VALUE_TYPE_STRING:
                        append_text(output, "i8* ")
                    case VALUE_TYPE_LIST:
                        append_text(output, "%dynarray_i32* ")
                    case VALUE_TYPE_BYTES:
                        append_text(output, "%dynarray_i32* ")
                    case VALUE_TYPE_BOOL:
                        append_text(output, "i1 ")
                    case VALUE_TYPE_FLOAT:
                        append_text(output, "double ")
                    default:
                        append_text(output, "i32 ")
            append_operand(output, body_type, body_value)
            append_text(output, "\n}\n")
            let enclosing_lambda_index = enclosing_lambda_token_index(source, kinds, starts, ends, token_index)
            if enclosing_lambda_index >= 0:
                let adapter_result_type = body_type
                if adapter_result_type == VALUE_TYPE_IMMEDIATE:
                    adapter_result_type = VALUE_TYPE_INT
                append_text(output, "define ")
                append_match_result_type(output, adapter_result_type)
                append_text(output, " @__dir_lambda_invoke_")
                append_integer(output, token_index)
                append_text(output, "(i8* %environment")
                let adapter_parameter_index = 0
                while adapter_parameter_index < lambda_parameter_count:
                    append_text(output, ", ")
                    append_match_result_type(output, lambda_parameter_types[adapter_parameter_index])
                    append_text(output, " %")
                    append_text(output, source[lambda_parameter_starts[adapter_parameter_index]:lambda_parameter_ends[adapter_parameter_index]])
                    append_text(output, ".param")
                    adapter_parameter_index = adapter_parameter_index + 1
                append_text(output, ") {\nentry:\n")
                append_text(output, "%dir_environment_")
                append_integer(output, token_index)
                append_text(output, " = bitcast i8* %environment to %dynarray_i32*\n")
                let adapter_capture_values = []
                let adapter_capture_index = 0
                let adapter_capture_slot = 0
                let adapter_counter = 0
                while adapter_capture_index < len(lambda_capture_starts):
                    let capture_type = lambda_variable_types[lambda_parameter_count + adapter_capture_index]
                    let raw_capture_temporary = adapter_counter + 1
                    append_text(output, "%t")
                    append_integer(output, raw_capture_temporary)
                    if capture_type == VALUE_TYPE_FLOAT:
                        append_text(output, " = call double @get_f64(%dynarray_i32* %dir_environment_")
                        append_integer(output, token_index)
                        append_text(output, ", i32 ")
                        append_integer(output, adapter_capture_slot)
                        append_text(output, ")\n")
                    if capture_type != VALUE_TYPE_FLOAT:
                        if capture_type == VALUE_TYPE_STRING or is_sequence_value_type(capture_type) or is_dictionary_value_type(capture_type) or is_closure_value_type(capture_type):
                            append_text(output, " = call i8* @get_pointer(%dynarray_i32* %dir_environment_")
                            append_integer(output, token_index)
                            append_text(output, ", i32 ")
                            append_integer(output, adapter_capture_slot)
                            append_text(output, ")\n")
                        if capture_type != VALUE_TYPE_STRING and not is_sequence_value_type(capture_type) and not is_dictionary_value_type(capture_type) and not is_closure_value_type(capture_type):
                            append_text(output, " = call i32 @get_dynarray_i32(%dynarray_i32* %dir_environment_")
                            append_integer(output, token_index)
                            append_text(output, ", i32 ")
                            append_integer(output, adapter_capture_slot)
                            append_text(output, ")\n")
                    let capture_value_temporary = raw_capture_temporary
                    if capture_type == VALUE_TYPE_BOOL:
                        let bool_capture_temporary = raw_capture_temporary + 1
                        append_text(output, "%t")
                        append_integer(output, bool_capture_temporary)
                        append_text(output, " = icmp ne i32 %t")
                        append_integer(output, raw_capture_temporary)
                        append_text(output, ", 0\n")
                        capture_value_temporary = bool_capture_temporary
                    if capture_type != VALUE_TYPE_STRING and (is_sequence_value_type(capture_type) or is_dictionary_value_type(capture_type) or is_closure_value_type(capture_type)):
                        let typed_capture_temporary = raw_capture_temporary + 1
                        append_text(output, "%t")
                        append_integer(output, typed_capture_temporary)
                        append_text(output, " = bitcast i8* %t")
                        append_integer(output, raw_capture_temporary)
                        append_text(output, " to ")
                        append_match_result_type(output, capture_type)
                        append_text(output, "\n")
                        capture_value_temporary = typed_capture_temporary
                    append(adapter_capture_values, capture_value_temporary)
                    adapter_counter = capture_value_temporary
                    adapter_capture_slot = adapter_capture_slot + closure_environment_slot_width(capture_type)
                    adapter_capture_index = adapter_capture_index + 1
                let adapter_result_temporary = adapter_counter + 1
                append_text(output, "%t")
                append_integer(output, adapter_result_temporary)
                append_text(output, " = call ")
                append_match_result_type(output, adapter_result_type)
                append_text(output, " @__dir_lambda_")
                append_integer(output, token_index)
                append_text(output, "(")
                let adapter_call_argument_index = 0
                while adapter_call_argument_index < lambda_parameter_count:
                    if adapter_call_argument_index > 0:
                        append_text(output, ", ")
                    append_match_result_type(output, lambda_parameter_types[adapter_call_argument_index])
                    append_text(output, " %")
                    append_text(output, source[lambda_parameter_starts[adapter_call_argument_index]:lambda_parameter_ends[adapter_call_argument_index]])
                    append_text(output, ".param")
                    adapter_call_argument_index = adapter_call_argument_index + 1
                let adapter_call_capture_index = 0
                while adapter_call_capture_index < len(lambda_capture_starts):
                    if adapter_call_argument_index > 0 or adapter_call_capture_index > 0:
                        append_text(output, ", ")
                    append_match_result_type(output, lambda_variable_types[lambda_parameter_count + adapter_call_capture_index])
                    append_text(output, " %t")
                    append_integer(output, adapter_capture_values[adapter_call_capture_index])
                    adapter_call_capture_index = adapter_call_capture_index + 1
                append_text(output, ")\nret ")
                append_match_result_type(output, adapter_result_type)
                append_text(output, " %t")
                append_integer(output, adapter_result_temporary)
                append_text(output, "\n}\n")
            lambda_count = lambda_count + 1
        token_index = token_index + 1
    dir_flush_line(records, output)
    return lambda_count

def append_interface_adapter(output: list[int], source: str, kinds: list[int], starts: list[int], ends: list[int], interface_name: str, struct_name: str, method_name: str, function_index: int, function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]):
    let target_prefix = string_concat(interface_name, "_")
    let target_name = string_concat(target_prefix, struct_name)
    let adapter_prefix = string_concat("__dir_adapter_", target_name)
    let adapter_prefix_with_separator = string_concat(adapter_prefix, "_")
    let adapter_name = string_concat(adapter_prefix_with_separator, method_name)
    let result_type = function_return_types[function_index]
    append_text(output, "define ")
    append_match_result_type(output, result_type)
    append_text(output, " @")
    append_text(output, adapter_name)
    append_text(output, "(i8* %data")
    let parameter_count = function_param_counts[function_index]
    let parameter_number = 1
    while parameter_number < parameter_count:
        let parameter_position = function_param_offsets[function_index] + parameter_number
        append_text(output, ", ")
        append_match_result_type(output, parameter_type_from_declaration(source, kinds, starts, ends, parameter_starts[parameter_position], parameter_ends[parameter_position]))
        append_text(output, " %arg")
        append_integer(output, parameter_number - 1)
        parameter_number = parameter_number + 1
    append_text(output, ") {\nentry:\n%object = bitcast i8* %data to %dynarray_i32*\n")
    append_text(output, "%result = call ")
    append_match_result_type(output, result_type)
    append_text(output, " @")
    append_text(output, function_symbol_name(source, kinds, starts, ends, function_starts[function_index], function_ends[function_index]))
    append_text(output, "(%dynarray_i32* %object")
    parameter_number = 1
    while parameter_number < parameter_count:
        let call_parameter_position = function_param_offsets[function_index] + parameter_number
        append_text(output, ", ")
        append_match_result_type(output, parameter_type_from_declaration(source, kinds, starts, ends, parameter_starts[call_parameter_position], parameter_ends[call_parameter_position]))
        append_text(output, " %arg")
        append_integer(output, parameter_number - 1)
        parameter_number = parameter_number + 1
    append_text(output, ")\nret ")
    append_match_result_type(output, result_type)
    append_text(output, " %result\n}\n")

def append_interface_artifacts(output: list[int], source: str, kinds: list[int], starts: list[int], ends: list[int], function_starts: list[int], function_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], function_return_types: list[int]):
    let token_index = 0
    while token_kind(kinds, token_index) != TOKEN_EOF:
        if token_kind(kinds, token_index) == TOKEN_IDENTIFIER and source[token_start(starts, token_index):token_end(ends, token_index)] == "impl" and line_indent(source, token_start(starts, token_index)) == 0:
            let interface_index = token_index + 1
            let target_keyword_index = interface_index + 1
            let found_target = false
            while token_kind(kinds, target_keyword_index) != TOKEN_COLON and token_kind(kinds, target_keyword_index) != TOKEN_EOF and not found_target:
                if token_kind(kinds, target_keyword_index) == TOKEN_FOR:
                    found_target = true
                target_keyword_index = target_keyword_index + 1
            if found_target:
                let target_index = target_keyword_index
                let interface_name = source[token_start(starts, interface_index):token_end(ends, interface_index)]
                let struct_name = source[token_start(starts, target_index):token_end(ends, target_index)]
                let method_starts = []
                let method_ends = []
                let method_function_indices = []
                let method_cursor = target_index + 1
                while token_kind(kinds, method_cursor) != TOKEN_NEWLINE and token_kind(kinds, method_cursor) != TOKEN_EOF:
                    method_cursor = method_cursor + 1
                method_cursor = method_cursor + 1
                let method_done = false
                let impl_indent = line_indent(source, token_start(starts, token_index))
                while token_kind(kinds, method_cursor) != TOKEN_EOF and not method_done:
                    if token_kind(kinds, method_cursor) != TOKEN_NEWLINE and line_indent(source, token_start(starts, method_cursor)) <= impl_indent:
                        method_done = true
                    if not method_done and token_kind(kinds, method_cursor) == TOKEN_DEF and token_kind(kinds, method_cursor + 1) == TOKEN_IDENTIFIER:
                        let method_name_start = token_start(starts, method_cursor + 1)
                        let method_name_end = token_end(ends, method_cursor + 1)
                        let method_name = source[method_name_start:method_name_end]
                        let method_function_index = find_interface_method_function_index(source, kinds, starts, ends, interface_name, struct_name, method_name, function_starts, function_ends)
                        append(method_starts, method_name_start)
                        append(method_ends, method_name_end)
                        append(method_function_indices, method_function_index)
                    method_cursor = method_cursor + 1
                let method_count = interface_method_count(source, kinds, starts, ends, interface_name)
                let method_number = 0
                while method_number < len(method_function_indices):
                    if method_function_indices[method_number] >= 0:
                        append_interface_adapter(output, source, kinds, starts, ends, interface_name, struct_name, source[method_starts[method_number]:method_ends[method_number]], method_function_indices[method_number], function_starts, function_ends, function_param_offsets, function_param_counts, parameter_starts, parameter_ends, function_return_types)
                    method_number = method_number + 1
                append_text(output, "@__dir_vtable_")
                append_text(output, interface_name)
                append_text(output, "_")
                append_text(output, struct_name)
                append_text(output, " = global [")
                append_integer(output, method_count)
                append_text(output, " x i8*] [")
                let slot_index = 0
                while slot_index < method_count:
                    if slot_index > 0:
                        append_text(output, ", ")
                    let slot_method_number = 0
                    let slot_method_function_index = -1
                    let slot_method_name = ""
                    while slot_method_number < len(method_function_indices):
                        let candidate_method_name = source[method_starts[slot_method_number]:method_ends[slot_method_number]]
                        if interface_method_index(source, kinds, starts, ends, interface_name, candidate_method_name) == slot_index:
                            slot_method_function_index = method_function_indices[slot_method_number]
                            slot_method_name = candidate_method_name
                        slot_method_number = slot_method_number + 1
                    if slot_method_function_index < 0:
                        append_text(output, "i8* null")
                    if slot_method_function_index >= 0:
                        let slot_result_type = function_return_types[slot_method_function_index]
                        append_text(output, "i8* bitcast (")
                        append_match_result_type(output, slot_result_type)
                        append_text(output, " (i8*")
                        let slot_parameter_number = 1
                        while slot_parameter_number < function_param_counts[slot_method_function_index]:
                            let slot_parameter_position = function_param_offsets[slot_method_function_index] + slot_parameter_number
                            append_text(output, ", ")
                            append_match_result_type(output, parameter_type_from_declaration(source, kinds, starts, ends, parameter_starts[slot_parameter_position], parameter_ends[slot_parameter_position]))
                            slot_parameter_number = slot_parameter_number + 1
                        append_text(output, ")* @__dir_adapter_")
                        append_text(output, interface_name)
                        append_text(output, "_")
                        append_text(output, struct_name)
                        append_text(output, "_")
                        append_text(output, slot_method_name)
                        append_text(output, " to i8*)")
                    slot_index = slot_index + 1
                append_text(output, "]\n\n")
        token_index = token_index + 1

def emit_function(context: ParseContext, function_index: int, output: list[int], records: list[int], function_bodies: list[int], function_body_ends: list[int], parameter_types: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int], global_let_name_starts: list[int], global_let_name_ends: list[int], global_let_types: list[int], global_let_expression_indexes: list[int]) -> int:
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let function_starts = context.fn_starts
    let function_ends = context.fn_ends
    let function_param_offsets = context.param_offsets
    let function_param_counts = context.param_counts
    let parameter_starts = context.param_starts
    let parameter_ends = context.param_ends
    let function_return_types = context.ret_types
    if not function_has_body(source, kinds, starts, function_bodies[function_index], function_body_ends[function_index], function_starts[function_index]):
        return 0
    let function_output = [1]
    let function_records = []
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
    let parameter_offset = function_param_offsets[function_index]
    let parameter_count = function_param_counts[function_index]
    let is_process_entry = false
    if source[function_name_start:function_name_end] == "main" and parameter_count == 0:
        is_process_entry = true
    if is_closure_value_type(function_result_type_value):
        append_text(function_output, "define %dir_closure* @")
    else:
        switch function_result_type_value:
            case VALUE_TYPE_LIST:
                append_text(function_output, "define %dynarray_i32* @")
            case VALUE_TYPE_BYTES:
                append_text(function_output, "define %dynarray_i32* @")
            case VALUE_TYPE_STRING:
                append_text(function_output, "define i8* @")
            case VALUE_TYPE_BOOL:
                append_text(function_output, "define i1 @")
            case VALUE_TYPE_FLOAT:
                append_text(function_output, "define double @")
            case VALUE_TYPE_INTERFACE:
                append_text(function_output, "define %dir_interface* @")
            default:
                append_text(function_output, "define i32 @")
    let emitted_function_name = function_symbol_name(source, kinds, starts, ends, function_starts[function_index], function_ends[function_index])
    append_text(function_output, emitted_function_name)
    append_text(function_output, "(")
    let parameter_index = 0
    while parameter_index < parameter_count:
        if parameter_index > 0:
            append_text(function_output, ", ")
        let emit_parameter_position = parameter_offset + parameter_index
        let emit_parameter_type = parameter_types[emit_parameter_position]
        if is_closure_value_type(emit_parameter_type):
            append_text(function_output, "%dir_closure* %")
        elif emit_parameter_type == VALUE_TYPE_FUNCTION_PARAMETER:
            append_text(function_output, "i32 (i32)* %")
        else:
            switch emit_parameter_type:
                case VALUE_TYPE_STRING:
                    append_text(function_output, "i8* %")
                case VALUE_TYPE_LIST:
                    append_text(function_output, "%dynarray_i32* %")
                case VALUE_TYPE_BYTES:
                    append_text(function_output, "%dynarray_i32* %")
                case VALUE_TYPE_BOOL:
                    append_text(function_output, "i1 %")
                case VALUE_TYPE_FLOAT:
                    append_text(function_output, "double %")
                case VALUE_TYPE_INTERFACE:
                    append_text(function_output, "%dir_interface* %")
                case VALUE_TYPE_DICT_INT_INT:
                    append_text(function_output, "%dict_t* %")
                case VALUE_TYPE_DICT_INT_STRING:
                    append_text(function_output, "%dict_t* %")
                case VALUE_TYPE_DICT_STRING_INT:
                    append_text(function_output, "%dict_t* %")
                case VALUE_TYPE_DICT_STRING_STRING:
                    append_text(function_output, "%dict_t* %")
                default:
                    append_text(function_output, "i32 %")
        append_text(function_output, source[parameter_starts[emit_parameter_position]:parameter_ends[emit_parameter_position]])
        append_text(function_output, ".param")
        parameter_index = parameter_index + 1
    if is_process_entry:
        if parameter_count > 0:
            append_text(function_output, ", ")
        append_text(function_output, "i32 %dream_argc.param, i8** %dream_argv.param")
    append_text(function_output, ") {\nentry:\n")
    if is_process_entry:
        append_text(function_output, "call void @__c_process_set_args(i32 %dream_argc.param, i8** %dream_argv.param)\n")

    let variable_starts = []
    let variable_ends = []
    let variable_types = []
    let global_let_register_index = 0
    while global_let_register_index < len(global_let_name_starts):
        append(variable_starts, global_let_name_starts[global_let_register_index])
        append(variable_ends, global_let_name_ends[global_let_register_index])
        append(variable_types, global_let_value_type(global_let_types[global_let_register_index]))
        global_let_register_index = global_let_register_index + 1
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
        if initialize_parameter_type != VALUE_TYPE_FUNCTION_PARAMETER:
            if initialize_parameter_type == VALUE_TYPE_STRING:
                append_local_storage(function_output, parameter_name, VALUE_TYPE_STRING)
                append_text(function_output, "store i8* %")
            if is_sequence_value_type(initialize_parameter_type):
                append_local_storage(function_output, parameter_name, VALUE_TYPE_LIST)
                append_text(function_output, "store %dynarray_i32* %")
            if is_interface_value_type(initialize_parameter_type):
                append_local_storage(function_output, parameter_name, VALUE_TYPE_INTERFACE)
                append_text(function_output, "store %dir_interface* %")
            if initialize_parameter_type == VALUE_TYPE_BOOL:
                append_local_storage(function_output, parameter_name, VALUE_TYPE_BOOL)
                append_text(function_output, "store i1 %")
            if initialize_parameter_type == VALUE_TYPE_FLOAT:
                append_local_storage(function_output, parameter_name, VALUE_TYPE_FLOAT)
                append_text(function_output, "store double %")
            if is_dictionary_value_type(initialize_parameter_type):
                append_local_storage(function_output, parameter_name, initialize_parameter_type)
                append_text(function_output, "store %dict_t* %")
            if initialize_parameter_type != VALUE_TYPE_STRING and not is_sequence_value_type(initialize_parameter_type) and not is_dictionary_value_type(initialize_parameter_type) and initialize_parameter_type != VALUE_TYPE_BOOL and initialize_parameter_type != VALUE_TYPE_FLOAT and not is_interface_value_type(initialize_parameter_type):
                append_local_storage(function_output, parameter_name, VALUE_TYPE_INT)
                append_text(function_output, "store i32 %")
            append_text(function_output, parameter_name)
            if initialize_parameter_type == VALUE_TYPE_STRING:
                append_text(function_output, ".param, i8** %")
            if is_sequence_value_type(initialize_parameter_type):
                append_text(function_output, ".param, %dynarray_i32** %")
            if is_interface_value_type(initialize_parameter_type):
                append_text(function_output, ".param, %dir_interface** %")
            if initialize_parameter_type == VALUE_TYPE_BOOL:
                append_text(function_output, ".param, i1* %")
            if initialize_parameter_type == VALUE_TYPE_FLOAT:
                append_text(function_output, ".param, double* %")
            if is_dictionary_value_type(initialize_parameter_type):
                append_text(function_output, ".param, %dict_t** %")
            if initialize_parameter_type != VALUE_TYPE_STRING and not is_sequence_value_type(initialize_parameter_type) and not is_dictionary_value_type(initialize_parameter_type) and initialize_parameter_type != VALUE_TYPE_BOOL and initialize_parameter_type != VALUE_TYPE_FLOAT and not is_interface_value_type(initialize_parameter_type):
                append_text(function_output, ".param, i32* %")
            append_variable_name(function_output, parameter_name, initialize_parameter_type)
            append_text(function_output, "\n")
        append(variable_starts, parameter_name_start)
        append(variable_ends, parameter_name_end)
        append(variable_types, initialize_parameter_type)
        initialize_index = initialize_index + 1

    let global_init_counter = 0
    if is_process_entry:
        let global_init_index = 0
        while global_init_index < len(global_let_name_starts):
            let global_base_type = global_let_types[global_init_index]
            let (_, init_type, init_value, init_counter) = parse_argument_expression(context, global_let_expression_indexes[global_init_index], function_output, function_records, variable_starts, variable_ends, variable_types, global_init_counter)
            append_text(function_output, "store ")
            append_llvm_type_text(function_output, global_base_type)
            append_text(function_output, " ")
            append_operand(function_output, init_type, init_value)
            append_text(function_output, ", ")
            append_llvm_type_text(function_output, global_base_type)
            append_text(function_output, "* @")
            append_text(function_output, source[global_let_name_starts[global_init_index]:global_let_name_ends[global_init_index]])
            append_text(function_output, "\n")
            global_init_counter = init_counter
            global_init_index = global_init_index + 1

    let (next_counter, has_return_value) = parse_function_body(context, function_bodies[function_index], function_body_ends[function_index], function_output, function_records, variable_starts, variable_ends, variable_types, global_init_counter, function_result_type_value)
    let has_return = has_return_value != 0
    if not has_return:
        if function_result_type_value == VALUE_TYPE_LIST or function_result_type_value == VALUE_TYPE_BYTES:
            append_text(function_output, "%t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, " = call %dynarray_i32* @create_dynarray_i32(i32 4)\nret %dynarray_i32* %t")
            append_integer(function_output, next_counter + 1)
            append_text(function_output, "\n")
        if function_result_type_value == VALUE_TYPE_FLOAT:
            append_text(function_output, "ret double 0.0\n")
        if is_interface_value_type(function_result_type_value):
            append_text(function_output, "ret %dir_interface* null\n")
        if function_result_type_value != VALUE_TYPE_LIST and function_result_type_value != VALUE_TYPE_BYTES:
            if function_result_type_value == VALUE_TYPE_BOOL:
                append_text(function_output, "ret i1 0\n")
            if function_result_type_value == VALUE_TYPE_STRING:
                append_text(function_output, "ret i8* null\n")
            if function_result_type_value != VALUE_TYPE_BOOL and function_result_type_value != VALUE_TYPE_STRING and function_result_type_value != VALUE_TYPE_FLOAT and not is_interface_value_type(function_result_type_value):
                append_text(function_output, "ret i32 0\n")
    append_text(function_output, "}\n")
    dir_flush_line(function_records, function_output)
    append_hoisted_function(records, function_records)
    return next_counter
