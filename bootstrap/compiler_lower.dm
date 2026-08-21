# AST → DIR records 结构化 lower(自顶向下遍历)
# 指令全部用结构化 native 记录;label/模块级声明用文本记录(非指令)

def int_to_string(value: int) -> str:
    if value == 0:
        return "0"
    let digits = "0123456789"
    let result: list[int] = []
    let is_negative = value < 0
    if is_negative:
        value = -value
    while value > 0:
        let digit_index = value % 10
        append(result, digit_index)
        value = value / 10
    let result_str = ""
    if is_negative:
        result_str = "-"
    let result_cursor = len(result)
    while result_cursor > 0:
        result_cursor = result_cursor - 1
        let digit_index = result[result_cursor]
        let digit_char = digits[digit_index:digit_index + 1]
        result_str = string_concat(result_str, digit_char)
    return result_str

def lower_variable_slot_name_indexed(source: str, name_start: int, name_end: int, variable_type: int, variable_index: int) -> str:
    let base_slot = lower_variable_slot_name(source, name_start, name_end, variable_type)
    let result = string_concat(base_slot, ".p")
    return string_concat(result, int_to_string(variable_index))

def is_access_allowed(context: ParseContext, call_site_offset: int, callee_name: str, callee_offset: int) -> bool:
    let caller_package = get_package_at_offset(context, call_site_offset)
    # __c_ 前缀函数只允许可信包(runtime/stdlib, bootstrap)访问
    if string_starts_with(callee_name, "__c_"):
        return is_trusted_package(caller_package)
    # 以 _ 开头的符号是包私有的
    if is_private_symbol(callee_name):
        return is_same_package(context, call_site_offset, callee_offset)
    # 其他符号公开可访问
    return true

def lower_dir_type(value_type: int) -> int:
    switch value_type:
        case VALUE_TYPE_STRING:
            return DIR_TYPE_POINTER
        case VALUE_TYPE_LIST:
            return DIR_TYPE_LIST
        case VALUE_TYPE_LIST_STRING:
            return DIR_TYPE_LIST
        case VALUE_TYPE_BYTES:
            return DIR_TYPE_LIST
        case VALUE_TYPE_BOOL:
            return DIR_TYPE_BOOL
        case VALUE_TYPE_FLOAT:
            return DIR_TYPE_F64
        case VALUE_TYPE_DICT_INT_INT:
            return DIR_TYPE_DICT
        case VALUE_TYPE_DICT_INT_STRING:
            return DIR_TYPE_DICT
        case VALUE_TYPE_DICT_STRING_INT:
            return DIR_TYPE_DICT
        case VALUE_TYPE_DICT_STRING_STRING:
            return DIR_TYPE_DICT
        case VALUE_TYPE_INTERFACE:
            return DIR_TYPE_INTERFACE
        default:
            return DIR_TYPE_I32

def lower_operand_kind(value_type: int) -> int:
    if value_type == VALUE_TYPE_IMMEDIATE:
        return DIR_NATIVE_OPERAND_IMMEDIATE
    return DIR_NATIVE_OPERAND_TEMPORARY

def lower_variable_slot_name(source: str, name_start: int, name_end: int, variable_type: int) -> str:
    let name = source[name_start:name_end]
    if is_closure_value_type(variable_type):
        return string_concat(name, ".closure")
    switch variable_type:
        case VALUE_TYPE_STRING:
            return string_concat(name, ".string")
        case VALUE_TYPE_LIST:
            return string_concat(name, ".list")
        case VALUE_TYPE_LIST_STRING:
            return string_concat(name, ".list")
        case VALUE_TYPE_BYTES:
            return string_concat(name, ".list")
        case VALUE_TYPE_BOOL:
            return string_concat(name, ".bool")
        case VALUE_TYPE_FLOAT:
            return string_concat(name, ".float")
        case VALUE_TYPE_DICT_INT_INT:
            return string_concat(name, ".dict")
        case VALUE_TYPE_DICT_INT_STRING:
            return string_concat(name, ".dict")
        case VALUE_TYPE_DICT_STRING_INT:
            return string_concat(name, ".dict")
        case VALUE_TYPE_DICT_STRING_STRING:
            return string_concat(name, ".dict")
        case VALUE_TYPE_INTERFACE:
            return string_concat(name, ".interface")
        default:
            return name

def lower_append_label(records: list[int], buffer: list[int], text: str):
    let marker = buffer[0]
    append_text(buffer, text)
    dir_append_record(records, DIR_TAG_BLOCK, DIR_TAG_INVALID, 0, 0, 0, buffer, marker, len(buffer))
    buffer[0] = len(buffer)

def lower_append_label_number(records: list[int], number: int):
    let label_buffer = [1]
    append_text(label_buffer, "dir_block_")
    append_integer(label_buffer, number)
    append_text(label_buffer, ":\n")
    dir_append_record(records, DIR_TAG_BLOCK, DIR_TAG_INVALID, 0, 0, 0, label_buffer, 1, len(label_buffer))

def lower_append_module(records: list[int], buffer: list[int], text: str):
    let marker = buffer[0]
    append_text(buffer, text)
    dir_append_record(records, DIR_TAG_MODULE, DIR_TAG_INVALID, 0, 0, 0, buffer, marker, len(buffer))
    buffer[0] = len(buffer)

def lower_append_extern(records: list[int], buffer: list[int], text: str):
    let marker = buffer[0]
    append_text(buffer, text)
    dir_append_record(records, DIR_TAG_EXTERN, DIR_TAG_INVALID, 0, 0, 0, buffer, marker, len(buffer))
    buffer[0] = len(buffer)

def lower_append_comment(records: list[int], buffer: list[int], text: str):
    let marker = buffer[0]
    append_text(buffer, text)
    dir_append_record(records, DIR_TAG_COMMENT, DIR_TAG_INVALID, 0, 0, 0, buffer, marker, len(buffer))
    buffer[0] = len(buffer)

def lower_find_variable(source: str, name_start: int, name_end: int, variable_starts: list[int], variable_ends: list[int]) -> int:
    let result = -1
    let variable_index = 0
    while variable_index < len(variable_starts):
        if source_ranges_equal(source, name_start, name_end, variable_starts[variable_index], variable_ends[variable_index]):
            result = variable_index
        variable_index = variable_index + 1
    return result

def lower_has_variable(source: str, name_start: int, name_end: int, variable_starts: list[int], variable_ends: list[int]) -> bool:
    return lower_find_variable(source, name_start, name_end, variable_starts, variable_ends) >= 0

def lower_load_variable(context: ParseContext, name_start: int, name_end: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let source = context.src
    let variable_index = lower_find_variable(source, name_start, name_end, variable_starts, variable_ends)
    if variable_index < 0:
        return (counter, VALUE_TYPE_INT, 0)
    let variable_type = variable_types[variable_index]
    let variable_temporary = counter + 1
    if is_function_value_type(variable_type):
        let function_value_index = function_value_index(variable_type)
        if is_lambda_value_type(variable_type):
            function_value_index = lambda_value_index(variable_type)
        return (counter, variable_type, function_value_index)
    if is_global_let_value_type(variable_type):
        let global_base_type = global_let_base_type(variable_type)
        let global_symbol_buffer = [1]
        append_text(global_symbol_buffer, source[name_start:name_end])
        let global_symbol_buffer_marker = global_symbol_buffer[0]
        dir_append_native_load_global(records, lower_dir_type(global_base_type), DIR_NATIVE_OPERAND_TEMPORARY, variable_temporary, global_symbol_buffer, global_symbol_buffer_marker)
        return (variable_temporary, global_base_type, variable_temporary)
    let variable_base_slot = lower_variable_slot_name(source, name_start, name_end, variable_type)
    let variable_slot = string_concat(variable_base_slot, ".p")
    let variable_slot = string_concat(variable_slot, int_to_string(variable_index))
    dir_append_native_load(records, lower_dir_type(variable_type), DIR_NATIVE_OPERAND_TEMPORARY, variable_temporary, "", DIR_NATIVE_OPERAND_NAMED, 0, variable_slot)
    return (variable_temporary, variable_type, variable_temporary)

def lower_branch_condition(value_type: int, value: int, counter: int, records: list[int]) -> int:
    if value_type == VALUE_TYPE_BOOL:
        return value
    let condition_temporary = counter + 1
    dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_NE, condition_temporary, lower_operand_kind(value_type), value, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
    return condition_temporary

def lower_expr_int(ast: list[int], node: int, counter: int) -> (int, int, int):
    let int_value = ast_node_arg(ast, node, 0)
    return (counter, VALUE_TYPE_IMMEDIATE, int_value)

def lower_expr_bool(ast: list[int], node: int, counter: int, records: list[int]) -> (int, int, int):
    let bool_value = ast_node_arg(ast, node, 0)
    let bool_temporary = counter + 1
    dir_append_native_compare(records, DIR_TYPE_BOOL, DIR_PREDICATE_EQ, bool_temporary, DIR_NATIVE_OPERAND_IMMEDIATE, bool_value, DIR_NATIVE_OPERAND_IMMEDIATE, 1)
    return (bool_temporary, VALUE_TYPE_BOOL, bool_temporary)

def lower_expr_var(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let var_name_start = ast_node_start(ast, node)
    let var_name_end = ast_node_end(ast, node)
    let const_index = lower_find_variable(context.src, var_name_start, var_name_end, context.cst_starts, context.cst_ends)
    if const_index >= 0:
        return (counter, VALUE_TYPE_IMMEDIATE, context.cst_values[const_index])
    let var_index = lower_find_variable(context.src, var_name_start, var_name_end, variable_starts, variable_ends)
    if var_index >= 0:
        return lower_load_variable(context, var_name_start, var_name_end, variable_starts, variable_ends, variable_types, counter, records)
    let fn_index = find_function(context.src, var_name_start, var_name_end, context.fn_starts, context.fn_ends)
    if fn_index >= 0:
        return (counter, VALUE_TYPE_FUNCTION_BASE + fn_index, fn_index)
    return (counter, VALUE_TYPE_INT, 0)

def lower_expr_binary(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let bin_operator = ast_node_arg(ast, node, 0)
    let bin_left_node = ast_node_arg(ast, node, 1)
    let bin_right_node = ast_node_arg(ast, node, 2)
    let (bin_left_next, bin_left_type, bin_left_value) = lower_expr(context, ast, bin_left_node, variable_starts, variable_ends, variable_types, counter, records)
    let (bin_right_next, bin_right_type, bin_right_value) = lower_expr(context, ast, bin_right_node, variable_starts, variable_ends, variable_types, bin_left_next, records)
    let bin_result = bin_right_next + 1
    let bin_is_comparison = false
    if bin_operator == TOKEN_LESS or bin_operator == TOKEN_EQUAL or bin_operator == TOKEN_NOT_EQUAL or bin_operator == TOKEN_LESS_EQUAL or bin_operator == TOKEN_GREATER_EQUAL or bin_operator == TOKEN_GREATER:
        bin_is_comparison = true
    if bin_is_comparison:
        let bin_predicate = DIR_PREDICATE_EQ
        if bin_operator == TOKEN_LESS:
            bin_predicate = DIR_PREDICATE_SLT
        if bin_operator == TOKEN_EQUAL:
            bin_predicate = DIR_PREDICATE_EQ
        if bin_operator == TOKEN_NOT_EQUAL:
            bin_predicate = DIR_PREDICATE_NE
        if bin_operator == TOKEN_LESS_EQUAL:
            bin_predicate = DIR_PREDICATE_SLE
        if bin_operator == TOKEN_GREATER_EQUAL:
            bin_predicate = DIR_PREDICATE_SGE
        if bin_operator == TOKEN_GREATER:
            bin_predicate = DIR_PREDICATE_SGT
        let bin_is_float = false
        if bin_left_type == VALUE_TYPE_FLOAT or bin_right_type == VALUE_TYPE_FLOAT:
            bin_is_float = true
        let bin_is_string = false
        if bin_left_type == VALUE_TYPE_STRING or bin_right_type == VALUE_TYPE_STRING:
            bin_is_string = true
        if bin_is_float:
            if bin_operator == TOKEN_EQUAL:
                bin_predicate = DIR_PREDICATE_FEQ
            if bin_operator == TOKEN_NOT_EQUAL:
                bin_predicate = DIR_PREDICATE_FNE
            if bin_operator == TOKEN_LESS:
                bin_predicate = DIR_PREDICATE_FLT
            if bin_operator == TOKEN_LESS_EQUAL:
                bin_predicate = DIR_PREDICATE_FLE
            if bin_operator == TOKEN_GREATER:
                bin_predicate = DIR_PREDICATE_FGT
            if bin_operator == TOKEN_GREATER_EQUAL:
                bin_predicate = DIR_PREDICATE_FGE
            dir_append_native_compare(records, DIR_TYPE_F64, bin_predicate, bin_result, lower_operand_kind(bin_left_type), bin_left_value, lower_operand_kind(bin_right_type), bin_right_value)
        if bin_is_string:
            let str_cmp_temp = bin_result
            let str_cmp_result = bin_result + 1
            let str_cmp_arg_kinds = []
            let str_cmp_arg_values = []
            let str_cmp_arg_types = []
            append(str_cmp_arg_kinds, lower_operand_kind(bin_left_type))
            append(str_cmp_arg_values, bin_left_value)
            append(str_cmp_arg_types, DIR_TYPE_POINTER)
            append(str_cmp_arg_kinds, lower_operand_kind(bin_right_type))
            append(str_cmp_arg_values, bin_right_value)
            append(str_cmp_arg_types, DIR_TYPE_POINTER)
            let str_cmp_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, str_cmp_temp, "string_compare", str_cmp_arg_kinds, str_cmp_arg_values, str_cmp_arg_types, 2, true, str_cmp_no_names)
            dir_append_native_compare(records, DIR_TYPE_I32, bin_predicate, str_cmp_result, DIR_NATIVE_OPERAND_TEMPORARY, str_cmp_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
            return (str_cmp_result, VALUE_TYPE_BOOL, str_cmp_result)
        if not bin_is_float and not bin_is_string:
            let bin_compare_type = DIR_TYPE_I32
            if bin_left_type == VALUE_TYPE_BOOL or bin_right_type == VALUE_TYPE_BOOL:
                bin_compare_type = DIR_TYPE_BOOL
            dir_append_native_compare(records, bin_compare_type, bin_predicate, bin_result, lower_operand_kind(bin_left_type), bin_left_value, lower_operand_kind(bin_right_type), bin_right_value)
        return (bin_result, VALUE_TYPE_BOOL, bin_result)
    if bin_operator == TOKEN_PLUS:
        if bin_left_type == VALUE_TYPE_STRING or bin_right_type == VALUE_TYPE_STRING:
            let str_cat_arg_kinds = []
            let str_cat_arg_values = []
            let str_cat_arg_types = []
            append(str_cat_arg_kinds, lower_operand_kind(bin_left_type))
            append(str_cat_arg_values, bin_left_value)
            append(str_cat_arg_types, DIR_TYPE_POINTER)
            append(str_cat_arg_kinds, lower_operand_kind(bin_right_type))
            append(str_cat_arg_values, bin_right_value)
            append(str_cat_arg_types, DIR_TYPE_POINTER)
            let str_cat_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, bin_result, "string_concat", str_cat_arg_kinds, str_cat_arg_values, str_cat_arg_types, 2, true, str_cat_no_names)
            return (bin_result, VALUE_TYPE_STRING, bin_result)
        if bin_left_type == VALUE_TYPE_LIST or bin_right_type == VALUE_TYPE_LIST or bin_left_type == VALUE_TYPE_LIST_STRING or bin_right_type == VALUE_TYPE_LIST_STRING:
            let list_concat_symbol = "concat_dynarray_i32"
            if bin_left_type == VALUE_TYPE_LIST_STRING or bin_right_type == VALUE_TYPE_LIST_STRING:
                list_concat_symbol = "concat_dynarray_ptr"
            let list_cat_arg_kinds = []
            let list_cat_arg_values = []
            let list_cat_arg_types = []
            append(list_cat_arg_kinds, lower_operand_kind(bin_left_type))
            append(list_cat_arg_values, bin_left_value)
            append(list_cat_arg_types, DIR_TYPE_LIST)
            append(list_cat_arg_kinds, lower_operand_kind(bin_right_type))
            append(list_cat_arg_values, bin_right_value)
            append(list_cat_arg_types, DIR_TYPE_LIST)
            let list_cat_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, bin_result, list_concat_symbol, list_cat_arg_kinds, list_cat_arg_values, list_cat_arg_types, 2, true, list_cat_no_names)
            return (bin_result, VALUE_TYPE_LIST, bin_result)
    let bin_instruction = DIR_OPCODE_ADD
    if bin_operator == TOKEN_PLUS:
        bin_instruction = DIR_OPCODE_ADD
    if bin_operator == TOKEN_MINUS:
        bin_instruction = DIR_OPCODE_SUB
    if bin_operator == TOKEN_MULTIPLY:
        bin_instruction = DIR_OPCODE_MUL
    if bin_operator == TOKEN_DIVIDE:
        bin_instruction = DIR_OPCODE_SDIV
    if bin_operator == TOKEN_MODULO:
        bin_instruction = DIR_OPCODE_SREM
    let bin_is_float = false
    if bin_left_type == VALUE_TYPE_FLOAT or bin_right_type == VALUE_TYPE_FLOAT:
        bin_is_float = true
    if bin_is_float:
        dir_append_native_operation(records, bin_instruction, DIR_TYPE_F64, bin_result, lower_operand_kind(bin_left_type), bin_left_value, lower_operand_kind(bin_right_type), bin_right_value)
        return (bin_result, VALUE_TYPE_FLOAT, bin_result)
    dir_append_native_operation(records, bin_instruction, DIR_TYPE_I32, bin_result, lower_operand_kind(bin_left_type), bin_left_value, lower_operand_kind(bin_right_type), bin_right_value)
    return (bin_result, VALUE_TYPE_INT, bin_result)

def lower_expr_unary(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let un_operator = ast_node_arg(ast, node, 0)
    let un_operand_node = ast_node_arg(ast, node, 1)
    let (un_next, un_type, un_value) = lower_expr(context, ast, un_operand_node, variable_starts, variable_ends, variable_types, counter, records)
    let un_result = un_next + 1
    if un_operator == TOKEN_NOT:
        if un_type == VALUE_TYPE_BOOL:
            dir_append_native_operation(records, DIR_OPCODE_XOR, DIR_TYPE_BOOL, un_result, lower_operand_kind(un_type), un_value, DIR_NATIVE_OPERAND_IMMEDIATE, 1)
        else:
            dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, un_result, lower_operand_kind(un_type), un_value, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        return (un_result, VALUE_TYPE_BOOL, un_result)
    return (un_next, un_type, un_value)

def lower_expr_logical(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let log_operator = ast_node_arg(ast, node, 0)
    let log_left_node = ast_node_arg(ast, node, 1)
    let log_right_node = ast_node_arg(ast, node, 2)
    let (log_left_next, log_left_type, log_left_value) = lower_expr(context, ast, log_left_node, variable_starts, variable_ends, variable_types, counter, records)
    let (log_right_next, log_right_type, log_right_value) = lower_expr(context, ast, log_right_node, variable_starts, variable_ends, variable_types, log_left_next, records)
    let log_result = log_right_next + 1
    let log_instruction = DIR_OPCODE_AND
    if log_operator == TOKEN_OR:
        log_instruction = DIR_OPCODE_OR
    let log_is_boolean = false
    if log_left_type == VALUE_TYPE_BOOL:
        if log_right_type == VALUE_TYPE_BOOL:
            log_is_boolean = true
    let log_value_type = DIR_TYPE_I32
    if log_is_boolean:
        log_value_type = DIR_TYPE_BOOL
    dir_append_native_operation(records, log_instruction, log_value_type, log_result, lower_operand_kind(log_left_type), log_left_value, lower_operand_kind(log_right_type), log_right_value)
    if log_is_boolean:
        return (log_result, VALUE_TYPE_BOOL, log_result)
    return (log_result, VALUE_TYPE_INT, log_result)

def lower_expr_cond(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let cond_condition_node = ast_node_arg(ast, node, 0)
    let cond_then_node = ast_node_arg(ast, node, 1)
    let cond_else_node = ast_node_arg(ast, node, 2)
    let (cond_next, cond_type, cond_value) = lower_expr(context, ast, cond_condition_node, variable_starts, variable_ends, variable_types, counter, records)
    let cond_condition = lower_branch_condition(cond_type, cond_value, cond_next, records)
    let (cond_then_next, cond_then_type, cond_then_value) = lower_expr(context, ast, cond_then_node, variable_starts, variable_ends, variable_types, cond_condition + 1, records)
    let (cond_else_next, cond_else_type, cond_else_value) = lower_expr(context, ast, cond_else_node, variable_starts, variable_ends, variable_types, cond_then_next, records)
    let cond_result = cond_else_next + 1
    let cond_result_type = cond_then_type
    if cond_result_type == VALUE_TYPE_IMMEDIATE:
        cond_result_type = VALUE_TYPE_INT
    dir_append_native_select(records, lower_dir_type(cond_result_type), DIR_NATIVE_OPERAND_TEMPORARY, cond_result, DIR_NATIVE_OPERAND_TEMPORARY, cond_condition, lower_operand_kind(cond_then_type), cond_then_value, lower_operand_kind(cond_else_type), cond_else_value)
    return (cond_result, cond_result_type, cond_result)

def lower_builtin_return_type(call_name: str) -> int:
    if call_name == "read_text_file" or call_name == "string_substring" or call_name == "string_concat" or call_name == "__c_file_read" or call_name == "__c_process_arg" or call_name == "process_arg" or call_name == "module_path" or call_name == "append_imported_module" or call_name == "load_imported_source" or call_name == "__c_bytes_to_str" or call_name == "bytes_to_str":
        return VALUE_TYPE_STRING
    if call_name == "str_to_bytes" or call_name == "__c_str_to_bytes" or call_name == "bytes_slice" or call_name == "__c_bytes_slice" or call_name == "bytes_from_list" or call_name == "__c_bytes_from_array":
        return VALUE_TYPE_BYTES
    if call_name == "__c_utf8_encode_rune" or call_name == "create_dynarray_i32":
        return VALUE_TYPE_LIST
    if call_name == "build_llvm" or call_name == "__c_build_llvm":
        return VALUE_TYPE_BOOL
    return VALUE_TYPE_INT

def lower_parse_annotation(source: str, kinds: list[int], starts: list[int], ends: list[int], annot_start: int, annot_end: int) -> int:
    let type_start = annot_start
    while type_start < annot_end and source[type_start] != ord(':'):
        type_start = type_start + 1
    type_start = type_start + 1
    while type_start < annot_end and source[type_start] == 32:
        type_start = type_start + 1
    let type_name_end = type_start
    while type_name_end < annot_end and source[type_name_end] != ord('[') and source[type_name_end] != 32:
        type_name_end = type_name_end + 1
    let type_name = source[type_start:type_name_end]
    if type_name == "list":
        let element_check_index = type_name_end
        while element_check_index < annot_end and source[element_check_index] == 32:
            element_check_index = element_check_index + 1
        if element_check_index < annot_end and source[element_check_index] == ord('['):
            let element_name_end = element_check_index + 1
            while element_name_end < annot_end and source[element_name_end] != ord(']') and source[element_name_end] != 32:
                element_name_end = element_name_end + 1
            if element_name_end > element_check_index + 1:
                let element_type_name = source[element_check_index + 1:element_name_end]
                if element_type_name == "str":
                    return VALUE_TYPE_LIST_STRING
        return VALUE_TYPE_LIST
    if type_name == "bytes":
        return VALUE_TYPE_BYTES
    if type_name == "str":
        return VALUE_TYPE_STRING
    if type_name == "bool":
        return VALUE_TYPE_BOOL
    if type_name == "float":
        return VALUE_TYPE_FLOAT
    if type_name == "int" or type_name == "rune" or type_name == "byte":
        return VALUE_TYPE_INT
    if type_name == "dict":
        return VALUE_TYPE_DICT_INT_INT
    if source_type_is_struct(source, kinds, starts, ends, type_start, type_name_end):
        return VALUE_TYPE_LIST
    if source_type_is_interface(source, kinds, starts, ends, type_start, type_name_end):
        return VALUE_TYPE_INTERFACE
    return 0

def lower_append_string_global(records: list[int], buffer: list[int], source: str, start: int, end: int):
    let marker = buffer[0]
    append_text(buffer, "@str")
    append_integer(buffer, start)
    append_text(buffer, " = private unnamed_addr constant [")
    append_integer(buffer, string_literal_length(source, start, end))
    append_text(buffer, " x i8] c")
    append(buffer, 34)
    append_string_contents(buffer, source, start, end)
    append_text(buffer, "\\00")
    append(buffer, 34)
    append(buffer, 10)
    dir_append_record(records, DIR_TAG_MODULE, DIR_TAG_INVALID, 0, 0, 0, buffer, marker, len(buffer))
    buffer[0] = len(buffer)

def lower_expr_string(context: ParseContext, ast: list[int], node: int, counter: int, records: list[int]) -> (int, int, int):
    let str_start = ast_node_start(ast, node)
    let str_end = ast_node_end(ast, node)
    let str_length = string_literal_length(context.src, str_start, str_end)
    let str_result = counter + 1
    let str_symbol_buffer = [1]
    append_text(str_symbol_buffer, "str")
    append_integer(str_symbol_buffer, str_start)
    let str_symbol_buffer_marker = str_symbol_buffer[0]
    dir_append_native_gep_string(records, str_length, DIR_NATIVE_OPERAND_TEMPORARY, str_result, str_symbol_buffer, str_symbol_buffer_marker)
    return (str_result, VALUE_TYPE_STRING, str_result)

def lower_expr_float(context: ParseContext, ast: list[int], node: int, counter: int, records: list[int]) -> (int, int, int):
    let float_text = context.src[ast_node_start(ast, node):ast_node_end(ast, node)]
    let float_result = counter + 1
    dir_append_native_operation_text(records, DIR_OPCODE_ADD, DIR_TYPE_F64, float_result, DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, "0.0", DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, float_text)
    return (float_result, VALUE_TYPE_FLOAT, float_result)

def lower_expr_rune(ast: list[int], node: int, counter: int) -> (int, int, int):
    return (counter, VALUE_TYPE_IMMEDIATE, ast_node_arg(ast, node, 0))

def lower_expr_slice(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let slice_collection_node = ast_node_arg(ast, node, 0)
    let slice_start_node = ast_node_arg(ast, node, 1)
    let slice_end_node = ast_node_arg(ast, node, 2)
    let (slice_collection_next, slice_collection_type, slice_collection_value) = lower_expr(context, ast, slice_collection_node, variable_starts, variable_ends, variable_types, counter, records)
    let slice_start_next = slice_collection_next
    let slice_start_type = VALUE_TYPE_IMMEDIATE
    let slice_start_value = 0
    if slice_start_node != 0:
        let (parsed_start_next, parsed_start_type, parsed_start_value) = lower_expr(context, ast, slice_start_node, variable_starts, variable_ends, variable_types, slice_collection_next, records)
        slice_start_next = parsed_start_next
        slice_start_type = parsed_start_type
        slice_start_value = parsed_start_value
    let slice_end_next = slice_start_next
    let slice_end_type = VALUE_TYPE_IMMEDIATE
    let slice_end_value = 2147483647
    if slice_end_node != 0:
        let (parsed_end_next, parsed_end_type, parsed_end_value) = lower_expr(context, ast, slice_end_node, variable_starts, variable_ends, variable_types, slice_start_next, records)
        slice_end_next = parsed_end_next
        slice_end_type = parsed_end_type
        slice_end_value = parsed_end_value
    let slice_symbol = "slice_dynarray_i32"
    let slice_result_type = VALUE_TYPE_LIST
    if slice_collection_type == VALUE_TYPE_BYTES:
        slice_symbol = "__c_bytes_slice"
        slice_result_type = VALUE_TYPE_BYTES
    if slice_collection_type == VALUE_TYPE_STRING:
        slice_symbol = "string_substring"
        slice_result_type = VALUE_TYPE_STRING
    let slice_result = slice_end_next + 1
    let slice_arg_kinds = []
    let slice_arg_values = []
    let slice_arg_types = []
    append(slice_arg_kinds, lower_operand_kind(slice_collection_type))
    append(slice_arg_values, slice_collection_value)
    append(slice_arg_types, lower_dir_type(slice_collection_type))
    append(slice_arg_kinds, lower_operand_kind(slice_start_type))
    append(slice_arg_values, slice_start_value)
    append(slice_arg_types, DIR_TYPE_I32)
    append(slice_arg_kinds, lower_operand_kind(slice_end_type))
    append(slice_arg_values, slice_end_value)
    append(slice_arg_types, DIR_TYPE_I32)
    let slice_no_names: list[str] = []
    dir_append_native_call_direct(records, lower_dir_type(slice_result_type), DIR_NATIVE_OPERAND_TEMPORARY, slice_result, slice_symbol, slice_arg_kinds, slice_arg_values, slice_arg_types, 3, true, slice_no_names)
    return (slice_result, slice_result_type, slice_result)

def lower_expr_index(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let index_collection_node = ast_node_arg(ast, node, 0)
    let index_index_node = ast_node_arg(ast, node, 1)
    let (index_collection_next, index_collection_type, index_collection_value) = lower_expr(context, ast, index_collection_node, variable_starts, variable_ends, variable_types, counter, records)
    let (index_index_next, index_index_type, index_index_value) = lower_expr(context, ast, index_index_node, variable_starts, variable_ends, variable_types, index_collection_next, records)
    let index_result = index_index_next + 1
    let index_symbol = "get"
    if index_collection_type == VALUE_TYPE_STRING:
        index_symbol = "__c_utf8_rune_at"
    if index_collection_type == VALUE_TYPE_LIST_STRING:
        index_symbol = "get_pointer"
        let index_pointer_offset = index_index_next + 2
        dir_append_native_operation(records, DIR_OPCODE_MUL, DIR_TYPE_I32, index_pointer_offset, lower_operand_kind(index_index_type), index_index_value, DIR_NATIVE_OPERAND_IMMEDIATE, 2)
        index_index_value = index_pointer_offset
    if is_dictionary_value_type(index_collection_type):
        index_symbol = "dream_dict_get_int_int"
        if index_collection_type == VALUE_TYPE_DICT_INT_STRING:
            index_symbol = "dream_dict_get_int_str"
        if index_collection_type == VALUE_TYPE_DICT_STRING_INT:
            index_symbol = "dream_dict_get_str_int"
        if index_collection_type == VALUE_TYPE_DICT_STRING_STRING:
            index_symbol = "dream_dict_get_str_str"
    let index_arg_kinds = []
    let index_arg_values = []
    let index_arg_types = []
    append(index_arg_kinds, lower_operand_kind(index_collection_type))
    append(index_arg_values, index_collection_value)
    append(index_arg_types, lower_dir_type(index_collection_type))
    append(index_arg_kinds, lower_operand_kind(index_index_type))
    append(index_arg_values, index_index_value)
    let index_key_type = DIR_TYPE_I32
    if index_collection_type == VALUE_TYPE_DICT_STRING_INT or index_collection_type == VALUE_TYPE_DICT_STRING_STRING or index_collection_type == VALUE_TYPE_GLOBAL_DICT_STRING_INT or index_collection_type == VALUE_TYPE_GLOBAL_DICT_STRING_STRING:
        index_key_type = DIR_TYPE_POINTER
    append(index_arg_types, index_key_type)
    let index_return_dir_type = DIR_TYPE_I32
    let index_return_value_type = VALUE_TYPE_INT
    if index_collection_type == VALUE_TYPE_DICT_INT_STRING or index_collection_type == VALUE_TYPE_DICT_STRING_STRING or index_collection_type == VALUE_TYPE_GLOBAL_DICT_INT_STRING or index_collection_type == VALUE_TYPE_GLOBAL_DICT_STRING_STRING:
        index_return_dir_type = DIR_TYPE_POINTER
        index_return_value_type = VALUE_TYPE_STRING
    if index_collection_type == VALUE_TYPE_LIST_STRING:
        index_return_dir_type = DIR_TYPE_POINTER
        index_return_value_type = VALUE_TYPE_STRING
    let index_no_names: list[str] = []
    if index_collection_type == VALUE_TYPE_LIST_STRING:
        let index_raw = index_result
        dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, index_raw, index_symbol, index_arg_kinds, index_arg_values, index_arg_types, 2, true, index_no_names)
        return (index_raw + 1, VALUE_TYPE_STRING, index_raw)
    dir_append_native_call_direct(records, index_return_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, index_result, index_symbol, index_arg_kinds, index_arg_values, index_arg_types, 2, true, index_no_names)
    return (index_result, index_return_value_type, index_result)

def lower_append_collection_value(records: list[int], collection_value: int, element_type: int, element_kind: int, element_value: int, counter: int) -> int:
    let append_symbol = "append_i32"
    let append_type = DIR_TYPE_I32
    let append_kind = element_kind
    let append_value = element_value
    let append_counter = counter
    if element_type == VALUE_TYPE_STRING:
        append_symbol = "append_pointer"
        append_type = DIR_TYPE_POINTER
    if element_type == VALUE_TYPE_FLOAT:
        append_symbol = "append_f64"
        append_type = DIR_TYPE_F64
    if element_type == VALUE_TYPE_BOOL:
        let bool_value = counter + 1
        dir_append_native_zext(records, bool_value, element_kind, element_value)
        append_kind = DIR_NATIVE_OPERAND_TEMPORARY
        append_value = bool_value
        append_counter = bool_value
    if is_sequence_value_type(element_type) or is_dictionary_value_type(element_type) or is_closure_value_type(element_type) or is_interface_value_type(element_type):
        let pointer_value = counter + 1
        let pointer_source_type = "%dynarray_i32*"
        if is_dictionary_value_type(element_type):
            pointer_source_type = "%dict_t*"
        if is_closure_value_type(element_type):
            pointer_source_type = "%dir_closure*"
        if is_interface_value_type(element_type):
            pointer_source_type = "%dir_interface*"
        dir_append_native_bitcast(records, DIR_TYPE_POINTER, pointer_source_type, DIR_NATIVE_OPERAND_TEMPORARY, pointer_value, element_kind, element_value)
        append_kind = DIR_NATIVE_OPERAND_TEMPORARY
        append_value = pointer_value
        append_type = DIR_TYPE_POINTER
        append_symbol = "append_pointer"
        append_counter = pointer_value
    let append_kinds = []
    let append_values = []
    let append_types = []
    append(append_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
    append(append_values, collection_value)
    append(append_types, DIR_TYPE_LIST)
    append(append_kinds, append_kind)
    append(append_values, append_value)
    append(append_types, append_type)
    let append_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, append_symbol, append_kinds, append_values, append_types, 2, false, append_no_names)
    return append_counter

def lower_expr_tuple(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let tuple_count = ast_node_arg(ast, node, 0)
    let tuple_result = counter + 1
    let tuple_create_kinds = []
    let tuple_create_values = []
    let tuple_create_types = []
    append(tuple_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(tuple_create_values, 0)
    append(tuple_create_types, DIR_TYPE_I32)
    let tuple_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, tuple_result, "create_dynarray_i32", tuple_create_kinds, tuple_create_values, tuple_create_types, 1, true, tuple_no_names)
    let tuple_element_index = 0
    let tuple_element_counter = tuple_result
    while tuple_element_index < tuple_count:
        let tuple_element_node = ast_node_arg(ast, node, 1 + tuple_element_index)
        let (tuple_element_next, tuple_element_type, tuple_element_value) = lower_expr(context, ast, tuple_element_node, variable_starts, variable_ends, variable_types, tuple_element_counter, records)
        tuple_element_counter = lower_append_collection_value(records, tuple_result, tuple_element_type, lower_operand_kind(tuple_element_type), tuple_element_value, tuple_element_next)
        tuple_element_index = tuple_element_index + 1
    return (tuple_element_counter, VALUE_TYPE_LIST, tuple_result)

def lower_tuple_element_is_pointer(ast: list[int], source: str, kinds: list[int], starts: list[int], ends: list[int], value_node: int, element_index: int) -> bool:
    let value_kind = ast_node_kind(ast, value_node)
    if value_kind != AST_EXPR_CALL:
        return false
    let callee_node = ast_node_arg(ast, value_node, 0)
    if ast_node_kind(ast, callee_node) != AST_EXPR_VAR:
        return false
    let fn_name_start = ast_node_start(ast, callee_node)
    let fn_name_end = ast_node_end(ast, callee_node)

    let token_index = 0
    while token_index < len(kinds):
        if token_kind(kinds, token_index) == TOKEN_DEF:
            let name_index = token_index + 1
            if token_kind(kinds, name_index) == TOKEN_IDENTIFIER and source_ranges_equal(source, token_start(starts, name_index), token_end(ends, name_index), fn_name_start, fn_name_end):
                let scan_index = name_index + 1
                while scan_index < len(kinds) and token_kind(kinds, scan_index) != TOKEN_ARROW and token_kind(kinds, scan_index) != TOKEN_EOF:
                    scan_index = scan_index + 1
                if token_kind(kinds, scan_index) == TOKEN_ARROW and token_kind(kinds, scan_index + 1) == TOKEN_OPEN_PAREN:
                    let element_index_in_annotation = 0
                    let annot_index = scan_index + 2
                    while annot_index < len(kinds) and token_kind(kinds, annot_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, annot_index) != TOKEN_EOF:
                        if element_index_in_annotation == element_index:
                            while token_kind(kinds, annot_index) == TOKEN_NEWLINE:
                                annot_index = annot_index + 1
                            if token_kind(kinds, annot_index) == TOKEN_IDENTIFIER:
                                let element_type_name = source[token_start(starts, annot_index):token_end(ends, annot_index)]
                                if element_type_name == "list" or element_type_name == "str" or element_type_name == "dict" or element_type_name == "bytes" or element_type_name == "closure" or element_type_name == "interface":
                                    return true
                            return false
                        if token_kind(kinds, annot_index) == TOKEN_COMMA:
                            element_index_in_annotation = element_index_in_annotation + 1
                        annot_index = annot_index + 1
        token_index = token_index + 1
    return false

def lower_stmt_let_tuple(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let source = context.src
    let tuple_name_token_start = ast_node_arg(ast, node, 0)
    let tuple_name_token_end = ast_node_arg(ast, node, 1)
    let tuple_value_node = ast_node_arg(ast, node, 2)
    let (tuple_next, tuple_type, tuple_value) = lower_expr(context, ast, tuple_value_node, variable_starts, variable_ends, variable_types, counter, records)
    let tuple_name_index = tuple_name_token_start
    let tuple_element_index = 0
    let tuple_slot_offset = 0
    let tuple_counter = tuple_next
    while tuple_name_index < tuple_name_token_end:
        if token_kind(kinds, tuple_name_index) == TOKEN_IDENTIFIER:
            let tuple_name_start = token_start(starts, tuple_name_index)
            let tuple_name_end = token_end(ends, tuple_name_index)
            let tuple_element_is_pointer = lower_tuple_element_is_pointer(ast, source, kinds, starts, ends, tuple_value_node, tuple_element_index)
            let tuple_element_temporary = tuple_counter + 1
            let tuple_get_kinds = []
            let tuple_get_values = []
            let tuple_get_types = []
            append(tuple_get_kinds, lower_operand_kind(tuple_type))
            append(tuple_get_values, tuple_value)
            append(tuple_get_types, lower_dir_type(tuple_type))
            append(tuple_get_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(tuple_get_values, tuple_slot_offset)
            append(tuple_get_types, DIR_TYPE_I32)
            let tuple_no_names: list[str] = []
            let tuple_element_type = VALUE_TYPE_INT
            if tuple_element_is_pointer:
                dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, tuple_element_temporary, "get_pointer", tuple_get_kinds, tuple_get_values, tuple_get_types, 2, true, tuple_no_names)
                tuple_element_type = VALUE_TYPE_LIST
                tuple_slot_offset = tuple_slot_offset + 2
            else:
                dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, tuple_element_temporary, "get", tuple_get_kinds, tuple_get_values, tuple_get_types, 2, true, tuple_no_names)
                tuple_slot_offset = tuple_slot_offset + 1
            let tuple_index = len(variable_starts)
            let tuple_slot = lower_variable_slot_name_indexed(source, tuple_name_start, tuple_name_end, tuple_element_type, tuple_index)
            dir_append_native_alloca(records, lower_dir_type(tuple_element_type), DIR_NATIVE_OPERAND_NAMED, 0, tuple_slot)
            dir_append_native_store(records, lower_dir_type(tuple_element_type), DIR_NATIVE_OPERAND_TEMPORARY, tuple_element_temporary, "", DIR_NATIVE_OPERAND_NAMED, 0, tuple_slot)
            append(variable_starts, tuple_name_start)
            append(variable_ends, tuple_name_end)
            append(variable_types, tuple_element_type)
            tuple_counter = tuple_element_temporary
            tuple_element_index = tuple_element_index + 1
        tuple_name_index = tuple_name_index + 1
    return (tuple_counter, 0)

def lower_expr_struct(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let struct_field_count = ast_node_arg(ast, node, 4)
    let struct_result = counter + 1
    let struct_create_kinds = []
    let struct_create_values = []
    let struct_create_types = []
    append(struct_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(struct_create_values, 0)
    append(struct_create_types, DIR_TYPE_I32)
    let struct_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, struct_result, "create_dynarray_i32", struct_create_kinds, struct_create_values, struct_create_types, 1, true, struct_no_names)
    let struct_field_index = 0
    let struct_field_counter = struct_result
    while struct_field_index < struct_field_count:
        let struct_field_node = ast_node_arg(ast, node, 5 + struct_field_index)
        let (struct_field_next, struct_field_type, struct_field_value) = lower_expr(context, ast, struct_field_node, variable_starts, variable_ends, variable_types, struct_field_counter, records)
        struct_field_counter = lower_append_collection_value(records, struct_result, struct_field_type, lower_operand_kind(struct_field_type), struct_field_value, struct_field_next)
        struct_field_index = struct_field_index + 1
    return (struct_field_counter, VALUE_TYPE_LIST, struct_result)

def lower_struct_field_type(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name: str, field_name_start: int, field_name_end: int) -> int:
    let declaration_name_index = lower_find_struct_declaration_token(source, kinds, starts, ends, struct_name)
    if declaration_name_index < 0:
        return VALUE_TYPE_INT
    let header_index = declaration_name_index + 1
    while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
        header_index = header_index + 1
    let current_field_index = header_index + 1
    while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF:
        if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
            if source_ranges_equal(source, token_start(starts, current_field_index), token_end(ends, current_field_index), field_name_start, field_name_end):
                let colon_index = current_field_index + 1
                let type_token_index = colon_index + 1
                while type_token_index < len(kinds) and token_kind(kinds, type_token_index) == TOKEN_NEWLINE:
                    type_token_index = type_token_index + 1
                if type_token_index < len(kinds) and token_kind(kinds, type_token_index) == TOKEN_IDENTIFIER:
                    let type_name_start = token_start(starts, type_token_index)
                    let type_name_end = token_end(ends, type_token_index)
                    let type_name = source[type_name_start:type_name_end]
                    if type_name == "str":
                        return VALUE_TYPE_STRING
                    if type_name == "bool":
                        return VALUE_TYPE_BOOL
                    if type_name == "float":
                        return VALUE_TYPE_FLOAT
                    if type_name == "list":
                        return VALUE_TYPE_LIST
                    if type_name == "bytes":
                        return VALUE_TYPE_BYTES
                    if type_name == "dict":
                        return VALUE_TYPE_DICT_INT_INT
                    return VALUE_TYPE_INT
            current_field_index = current_field_index + 1
        current_field_index = current_field_index + 1
    return VALUE_TYPE_INT

def lower_find_struct_declaration_token(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name: str) -> int:
    let name_hash = -2128831035
    let name_index = 0
    let name_length = text_length(struct_name)
    while name_index < name_length:
        let code = ord(struct_name[name_index])
        name_hash = name_hash * 16777619 + code
        name_index = name_index + 1
    let declaration_index = 0
    while declaration_index < len(STRUCT_DECLARATION_HASHES):
        if STRUCT_DECLARATION_HASHES[declaration_index] == name_hash:
            let declaration_token = STRUCT_DECLARATION_TOKENS[declaration_index]
            if source[token_start(starts, declaration_token):token_end(ends, declaration_token)] == struct_name:
                return declaration_token
        declaration_index = declaration_index + 1
    return -1

def lower_emit_interface_dispatch(records: list[int], counter: int, receiver_value: int, method_slot: int, result_type_text: str) -> (int, int):
    let vd0 = counter + 1
    let vd1 = counter + 2
    let vd2 = counter + 3
    let vd3 = counter + 4
    let vd4 = counter + 5
    let vd5 = counter + 6
    let vd6 = counter + 7
    let fallback_text: list[int] = []
    append_text(fallback_text, "  %t")
    append_integer(fallback_text, vd0)
    append_text(fallback_text, " = getelementptr %dir_interface, %dir_interface* %t")
    append_integer(fallback_text, receiver_value)
    append_text(fallback_text, ", i32 0, i32 0\n  %t")
    append_integer(fallback_text, vd1)
    append_text(fallback_text, " = load i8*, i8** %t")
    append_integer(fallback_text, vd0)
    append_text(fallback_text, "\n  %t")
    append_integer(fallback_text, vd2)
    append_text(fallback_text, " = getelementptr %dir_interface, %dir_interface* %t")
    append_integer(fallback_text, receiver_value)
    append_text(fallback_text, ", i32 0, i32 1\n  %t")
    append_integer(fallback_text, vd3)
    append_text(fallback_text, " = load i8*, i8** %t")
    append_integer(fallback_text, vd2)
    append_text(fallback_text, "\n  %t")
    append_integer(fallback_text, vd4)
    append_text(fallback_text, " = bitcast i8* %t")
    append_integer(fallback_text, vd3)
    append_text(fallback_text, " to ")
    append_text(fallback_text, result_type_text)
    append_text(fallback_text, " (i8*)*\n  %t")
    append_integer(fallback_text, vd5)
    append_text(fallback_text, " = load ")
    append_text(fallback_text, result_type_text)
    append_text(fallback_text, " (i8*)*, ")
    append_text(fallback_text, result_type_text)
    append_text(fallback_text, " (i8*)** %t")
    append_integer(fallback_text, vd4)
    append_text(fallback_text, "\n  %t")
    append_integer(fallback_text, vd6)
    append_text(fallback_text, " = call ")
    append_text(fallback_text, result_type_text)
    append_text(fallback_text, " %t")
    append_integer(fallback_text, vd5)
    append_text(fallback_text, "(i8* %t")
    append_integer(fallback_text, vd1)
    append_text(fallback_text, ")")
    dir_append_native_fallback(records, fallback_text, 0, len(fallback_text))
    return (counter + 7, vd6)

def lower_expr_attr(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let attr_receiver_node = ast_node_arg(ast, node, 0)
    let attr_field_start = ast_node_arg(ast, node, 1)
    let attr_field_end = ast_node_arg(ast, node, 2)
    let (attr_receiver_next, attr_receiver_type, attr_receiver_value) = lower_expr(context, ast, attr_receiver_node, variable_starts, variable_ends, variable_types, counter, records)
    let attr_result = attr_receiver_next + 1
    if ast_node_kind(ast, attr_receiver_node) == AST_EXPR_VAR:
        let attr_recv_start = ast_node_start(ast, attr_receiver_node)
        let attr_recv_end = ast_node_end(ast, attr_receiver_node)
        if find_variable(context.src, attr_recv_start, attr_recv_end, variable_starts, variable_ends) < 0:
            let attr_enum_tag = enum_variant_tag(context.src, context.kinds, context.starts, context.ends, attr_recv_start, attr_recv_end, attr_field_start, attr_field_end)
            if attr_enum_tag >= 0:
                let enum_create_kinds = []
                let enum_create_values = []
                let enum_create_types = []
                append(enum_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(enum_create_values, 4)
                append(enum_create_types, DIR_TYPE_I32)
                let enum_no_names: list[str] = []
                dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, attr_result, "create_dynarray_i32", enum_create_kinds, enum_create_values, enum_create_types, 1, true, enum_no_names)
                let enum_tag_kinds = []
                let enum_tag_values = []
                let enum_tag_types = []
                append(enum_tag_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
                append(enum_tag_values, attr_result)
                append(enum_tag_types, DIR_TYPE_LIST)
                append(enum_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(enum_tag_values, attr_enum_tag)
                append(enum_tag_types, DIR_TYPE_I32)
                dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append_i32", enum_tag_kinds, enum_tag_values, enum_tag_types, 2, false, enum_no_names)
                return (attr_result, VALUE_TYPE_LIST, attr_result)
    let attr_struct_name = find_struct_name_for_variable(context.src, context.kinds, context.starts, context.ends, ast_node_start(ast, attr_receiver_node), ast_node_end(ast, attr_receiver_node))
    let attr_field_index = 0
    let attr_field_type = VALUE_TYPE_INT
    if text_length(attr_struct_name) > 0:
        let attr_field_number = lower_struct_field_index(context.src, context.kinds, context.starts, context.ends, attr_struct_name, attr_field_start, attr_field_end)
        if attr_field_number >= 0:
            attr_field_index = lower_struct_field_offset(context.src, context.kinds, context.starts, context.ends, attr_struct_name, attr_field_number)
        attr_field_type = lower_struct_field_type(context.src, context.kinds, context.starts, context.ends, attr_struct_name, attr_field_start, attr_field_end)
    let attr_get_kinds = []
    let attr_get_values = []
    let attr_get_types = []
    append(attr_get_kinds, lower_operand_kind(attr_receiver_type))
    append(attr_get_values, attr_receiver_value)
    append(attr_get_types, lower_dir_type(attr_receiver_type))
    append(attr_get_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(attr_get_values, attr_field_index)
    append(attr_get_types, DIR_TYPE_I32)
    let attr_no_names: list[str] = []
    let attr_result_dir_type = lower_dir_type(attr_field_type)
    if attr_field_type == VALUE_TYPE_STRING or is_sequence_value_type(attr_field_type) or is_dictionary_value_type(attr_field_type) or is_closure_value_type(attr_field_type) or is_interface_value_type(attr_field_type):
        dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, attr_result, "get_pointer", attr_get_kinds, attr_get_values, attr_get_types, 2, true, attr_no_names)
        dir_append_native_bitcast(records, attr_result_dir_type, "i8*", DIR_NATIVE_OPERAND_TEMPORARY, attr_result + 1, DIR_NATIVE_OPERAND_TEMPORARY, attr_result)
        return (attr_result + 1, attr_field_type, attr_result + 1)
    dir_append_native_call_direct(records, attr_result_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, attr_result, "get", attr_get_kinds, attr_get_values, attr_get_types, 2, true, attr_no_names)
    return (attr_result, attr_field_type, attr_result)

def lower_struct_field_offset(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name: str, field_number: int) -> int:
    let declaration_name_index = lower_find_struct_declaration_token(source, kinds, starts, ends, struct_name)
    if declaration_name_index < 0:
        return 0
    let header_index = declaration_name_index + 1
    while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
        header_index = header_index + 1
    let slot_offset = 0
    let current_field_index = header_index + 1
    while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF:
        if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
            if field_number == 0:
                return slot_offset
            let colon_index = current_field_index + 1
            let type_token_index = colon_index + 1
            while type_token_index < len(kinds) and token_kind(kinds, type_token_index) == TOKEN_NEWLINE:
                type_token_index = type_token_index + 1
            let field_type_name = ""
            if type_token_index < len(kinds) and token_kind(kinds, type_token_index) == TOKEN_IDENTIFIER:
                field_type_name = source[token_start(starts, type_token_index):token_end(ends, type_token_index)]
            let is_pointer_field = field_type_name == "str" or field_type_name == "list" or field_type_name == "bytes" or field_type_name == "dict" or field_type_name == "closure" or field_type_name == "interface"
            if is_pointer_field:
                slot_offset = slot_offset + 2
            else:
                slot_offset = slot_offset + 1
            field_number = field_number - 1
        current_field_index = current_field_index + 1
    return 0

def lower_struct_field_index(source: str, kinds: list[int], starts: list[int], ends: list[int], struct_name: str, field_name_start: int, field_name_end: int) -> int:
    let declaration_name_index = lower_find_struct_declaration_token(source, kinds, starts, ends, struct_name)
    if declaration_name_index < 0:
        return -1
    let header_index = declaration_name_index + 1
    while token_kind(kinds, header_index) != TOKEN_NEWLINE and token_kind(kinds, header_index) != TOKEN_EOF:
        header_index = header_index + 1
    let field_index = 0
    let current_field_index = header_index + 1
    while current_field_index < len(kinds) and token_kind(kinds, current_field_index) != TOKEN_EOF:
        if token_kind(kinds, current_field_index) == TOKEN_IDENTIFIER and token_kind(kinds, current_field_index + 1) == TOKEN_COLON:
            if source_ranges_equal(source, token_start(starts, current_field_index), token_end(ends, current_field_index), field_name_start, field_name_end):
                return field_index
            field_index = field_index + 1
        current_field_index = current_field_index + 1
    return -1

def lower_infer_expr_type(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int]) -> int:
    if node >= len(ast):
        return VALUE_TYPE_INT
    let kind = ast_node_kind(ast, node)
    if kind == AST_EXPR_INT:
        return VALUE_TYPE_INT
    if kind == AST_EXPR_FLOAT:
        return VALUE_TYPE_FLOAT
    if kind == AST_EXPR_BOOL:
        return VALUE_TYPE_BOOL
    if kind == AST_EXPR_STRING:
        return VALUE_TYPE_STRING
    if kind == AST_EXPR_RUNE:
        return VALUE_TYPE_IMMEDIATE
    if kind == AST_EXPR_VAR:
        let var_start = ast_node_start(ast, node)
        let var_end = ast_node_end(ast, node)
        let var_index = lower_find_variable(context.src, var_start, var_end, variable_starts, variable_ends)
        if var_index >= 0:
            return variable_types[var_index]
        return VALUE_TYPE_INT
    if kind == AST_EXPR_BINARY:
        let left_node = ast_node_arg(ast, node, 1)
        let right_node = ast_node_arg(ast, node, 2)
        let left_type = lower_infer_expr_type(context, ast, left_node, variable_starts, variable_ends, variable_types)
        let right_type = lower_infer_expr_type(context, ast, right_node, variable_starts, variable_ends, variable_types)
        if left_type == VALUE_TYPE_FLOAT or right_type == VALUE_TYPE_FLOAT:
            return VALUE_TYPE_FLOAT
        if left_type == VALUE_TYPE_STRING or right_type == VALUE_TYPE_STRING:
            return VALUE_TYPE_STRING
        return VALUE_TYPE_INT
    if kind == AST_EXPR_UNARY:
        let operand_node = ast_node_arg(ast, node, 1)
        return lower_infer_expr_type(context, ast, operand_node, variable_starts, variable_ends, variable_types)
    return VALUE_TYPE_INT

def lower_infer_match_result_type(context: ParseContext, ast: list[int], cases_start: int, cases_end: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int]) -> int:
    if cases_start >= cases_end:
        return VALUE_TYPE_INT
    let first_case = cases_start
    let pattern_node = ast_node_arg(ast, first_case, 0)
    let body_node = ast_node_arg(ast, first_case, 2)
    let pattern_kind = ast_node_kind(ast, pattern_node)
    let temp_var_starts = []
    let temp_var_ends = []
    let temp_var_types = []
    let i = 0
    while i < len(variable_starts):
        append(temp_var_starts, variable_starts[i])
        append(temp_var_ends, variable_ends[i])
        append(temp_var_types, variable_types[i])
        i = i + 1
    if pattern_kind == AST_PAT_STRUCT:
        let struct_name = context.src[ast_node_start(ast, pattern_node):ast_node_end(ast, pattern_node)]
        let field_start = ast_node_arg(ast, pattern_node, 2)
        let field_end = ast_node_arg(ast, pattern_node, 3)
        let field_cursor = field_start
        while field_cursor < field_end:
            let fname_start = token_start(context.starts, field_cursor)
            let fname_end = token_end(context.ends, field_cursor)
            let fmode_index = field_cursor + 2
            let fvar_start = token_start(context.starts, fmode_index)
            let fvar_end = token_end(context.ends, fmode_index)
            let fvar_name = context.src[fvar_start:fvar_end]
            if fvar_name != "_":
                let field_number = lower_struct_field_index(context.src, context.kinds, context.starts, context.ends, struct_name, fname_start, fname_end)
                let field_type = VALUE_TYPE_INT
                if field_number >= 0:
                    field_type = lower_struct_field_type(context.src, context.kinds, context.starts, context.ends, struct_name, fname_start, fname_end)
                append(temp_var_starts, fvar_start)
                append(temp_var_ends, fvar_end)
                append(temp_var_types, field_type)
            field_cursor = fmode_index + 1
            while field_cursor < field_end and token_kind(context.kinds, field_cursor) != TOKEN_COMMA:
                field_cursor = field_cursor + 1
            field_cursor = field_cursor + 1
    if pattern_kind == AST_PAT_ENUM:
        let enum_name_start = ast_node_start(ast, pattern_node)
        let enum_name_end = ast_node_end(ast, pattern_node)
        let variant_name_start = ast_node_arg(ast, pattern_node, 2)
        let variant_name_end = ast_node_arg(ast, pattern_node, 3)
        let payload_token_start = ast_node_arg(ast, pattern_node, 4)
        let payload_token_end = ast_node_arg(ast, pattern_node, 5)
        if payload_token_start < payload_token_end:
            let payload_name_start = token_start(context.starts, payload_token_start)
            let payload_name_end = token_end(context.ends, payload_token_start)
            let payload_name = context.src[payload_name_start:payload_name_end]
            if payload_name != "_":
                let payload_type = enum_variant_payload_type(context.src, context.kinds, context.starts, context.ends, enum_name_start, enum_name_end, variant_name_start, variant_name_end, 0)
                append(temp_var_starts, payload_name_start)
                append(temp_var_ends, payload_name_end)
                append(temp_var_types, payload_type)
    return lower_infer_expr_type(context, ast, body_node, temp_var_starts, temp_var_ends, temp_var_types)

def lower_expr_match(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let m_scrutinee_node = ast_node_arg(ast, node, 0)
    let m_cases_start = ast_node_arg(ast, node, 1)
    let m_cases_end = ast_node_arg(ast, node, 2)
    let (m_scrutinee_next, m_scrutinee_type, m_scrutinee_value) = lower_expr(context, ast, m_scrutinee_node, variable_starts, variable_ends, variable_types, counter, records)
    let m_is_scalar = false
    if m_scrutinee_type == VALUE_TYPE_INT or m_scrutinee_type == VALUE_TYPE_BOOL or m_scrutinee_type == VALUE_TYPE_FLOAT or m_scrutinee_type == VALUE_TYPE_STRING or m_scrutinee_type == VALUE_TYPE_IMMEDIATE:
        m_is_scalar = true
    let m_tag = m_scrutinee_next + 1
    let m_compare_value = m_scrutinee_value
    let m_compare_type = m_scrutinee_type
    let m_compare_kind = lower_operand_kind(m_scrutinee_type)
    if m_scrutinee_type == VALUE_TYPE_BOOL:
        let m_bool_conv_temp = m_tag
        dir_append_native_select(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_bool_conv_temp, lower_operand_kind(m_scrutinee_type), m_scrutinee_value, DIR_NATIVE_OPERAND_IMMEDIATE, 1, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        m_compare_value = m_bool_conv_temp
        m_compare_type = VALUE_TYPE_INT
        m_compare_kind = DIR_NATIVE_OPERAND_TEMPORARY
        m_tag = m_bool_conv_temp + 1
    let m_tag_kinds = []
    let m_tag_values = []
    let m_tag_types = []
    append(m_tag_kinds, lower_operand_kind(m_scrutinee_type))
    append(m_tag_values, m_scrutinee_value)
    append(m_tag_types, lower_dir_type(m_scrutinee_type))
    append(m_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(m_tag_values, 0)
    append(m_tag_types, DIR_TYPE_I32)
    let m_no_names: list[str] = []
    if not m_is_scalar:
        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_tag, "get", m_tag_kinds, m_tag_values, m_tag_types, 2, true, m_no_names)
        m_compare_value = m_tag
        m_compare_type = VALUE_TYPE_INT
        m_compare_kind = DIR_NATIVE_OPERAND_TEMPORARY
    let m_result_type = VALUE_TYPE_INT
    if m_cases_start < m_cases_end:
        m_result_type = lower_infer_match_result_type(context, ast, m_cases_start, m_cases_end, variable_starts, variable_ends, variable_types)
    let m_result_dir_type = lower_dir_type(m_result_type)
    let m_result_slot = "match.result"
    if lower_find_variable(context.src, 0, 0, variable_starts, variable_ends) < 0:
        dir_append_native_alloca(records, m_result_dir_type, DIR_NATIVE_OPERAND_NAMED, 0, m_result_slot)
        append(variable_starts, 0)
        append(variable_ends, 0)
        append(variable_types, m_result_type)
    let m_end_label = m_tag + 1
    let m_counter = m_tag
    let m_next_label = m_tag + 1
    let m_case_node = m_cases_start
    while m_case_node < m_cases_end:
        let m_case_var_count = len(variable_starts)
        let m_pattern_node = ast_node_arg(ast, m_case_node, 0)
        let m_guard_node = ast_node_arg(ast, m_case_node, 1)
        let m_body_node = ast_node_arg(ast, m_case_node, 2)
        let m_case_tag = 0
        let m_pattern_kind = ast_node_kind(ast, m_pattern_node)
        let m_pattern_value_kind = DIR_NATIVE_OPERAND_IMMEDIATE
        let m_pattern_value = 0
        let m_pattern_temp = 0
        if m_pattern_kind == AST_PAT_INT or m_pattern_kind == AST_PAT_BOOL:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_FLOAT:
            let m_float_text = context.src[ast_node_start(ast, m_pattern_node):ast_node_end(ast, m_pattern_node)]
            m_pattern_temp = m_counter + 1
            dir_append_native_operation_text(records, DIR_OPCODE_ADD, DIR_TYPE_F64, m_pattern_temp, DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, "0.0", DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, m_float_text)
            m_pattern_value_kind = DIR_NATIVE_OPERAND_TEMPORARY
            m_pattern_value = m_pattern_temp
            m_counter = m_pattern_temp
        if m_pattern_kind == AST_PAT_STRING:
            let m_str_start = ast_node_start(ast, m_pattern_node)
            let m_str_end = ast_node_end(ast, m_pattern_node)
            let m_str_length = string_literal_length(context.src, m_str_start, m_str_end)
            m_pattern_temp = m_counter + 1
            let m_str_symbol_buffer = [1]
            append_text(m_str_symbol_buffer, "str")
            append_integer(m_str_symbol_buffer, m_str_start)
            let m_str_symbol_marker = m_str_symbol_buffer[0]
            dir_append_native_gep_string(records, m_str_length, DIR_NATIVE_OPERAND_TEMPORARY, m_pattern_temp, m_str_symbol_buffer, m_str_symbol_marker)
            m_pattern_value_kind = DIR_NATIVE_OPERAND_TEMPORARY
            m_pattern_value = m_pattern_temp
            m_counter = m_pattern_temp
        if m_pattern_kind == AST_PAT_RUNE:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_ENUM:
            let m_enum_name_start = ast_node_start(ast, m_pattern_node)
            let m_enum_name_end = ast_node_end(ast, m_pattern_node)
            let m_variant_name_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_variant_name_end = ast_node_arg(ast, m_pattern_node, 3)
            m_case_tag = enum_variant_tag(context.src, context.kinds, context.starts, context.ends, m_enum_name_start, m_enum_name_end, m_variant_name_start, m_variant_name_end)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_BUILTIN:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        let m_cond_temp = m_counter + 1
        let m_case_label = m_cond_temp + 1
        m_next_label = m_cond_temp + 2
        if m_pattern_kind == AST_PAT_STRUCT or m_pattern_kind == AST_PAT_WILDCARD or m_pattern_kind == AST_PAT_LIST or m_pattern_kind == AST_PAT_CONS:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_case_label, 0)
        else:
            if m_compare_type == VALUE_TYPE_STRING:
                let m_str_cmp_temp = m_cond_temp + 1
                let m_str_cmp_arg_kinds = []
                let m_str_cmp_arg_values = []
                let m_str_cmp_arg_types = []
                append(m_str_cmp_arg_kinds, m_compare_kind)
                append(m_str_cmp_arg_values, m_compare_value)
                append(m_str_cmp_arg_types, DIR_TYPE_POINTER)
                append(m_str_cmp_arg_kinds, m_pattern_value_kind)
                append(m_str_cmp_arg_values, m_pattern_value)
                append(m_str_cmp_arg_types, DIR_TYPE_POINTER)
                let m_str_cmp_no_names: list[str] = []
                dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cmp_temp, "string_compare", m_str_cmp_arg_kinds, m_str_cmp_arg_values, m_str_cmp_arg_types, 2, true, m_str_cmp_no_names)
                let m_str_cond = m_str_cmp_temp + 1
                dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, m_str_cond, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cmp_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
                dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cond, m_case_label, m_next_label)
                m_counter = m_str_cond
            else:
                let m_compare_dir_type = DIR_TYPE_I32
                let m_compare_predicate = DIR_PREDICATE_EQ
                if m_compare_type == VALUE_TYPE_FLOAT:
                    m_compare_dir_type = DIR_TYPE_F64
                    m_compare_predicate = DIR_PREDICATE_FEQ
                dir_append_native_compare(records, m_compare_dir_type, m_compare_predicate, m_cond_temp, m_compare_kind, m_compare_value, m_pattern_value_kind, m_pattern_value)
                dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_cond_temp, m_case_label, m_next_label)
        lower_append_label_number(records, m_case_label)
        let m_body_counter = m_cond_temp
        if m_pattern_kind == AST_PAT_LIST:
            let m_list_token_start = ast_node_arg(ast, m_pattern_node, 0)
            let m_list_token_end = ast_node_arg(ast, m_pattern_node, 1)
            let m_element_count = 0
            let m_count_cursor = m_list_token_start
            while m_count_cursor < m_list_token_end:
                if token_kind(context.kinds, m_count_cursor) != TOKEN_COMMA:
                    m_element_count = m_element_count + 1
                m_count_cursor = m_count_cursor + 1
            let m_list_len_temp = m_body_counter + 1
            let m_list_len_kinds = []
            let m_list_len_values = []
            let m_list_len_types = []
            append(m_list_len_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_list_len_values, m_scrutinee_value)
            append(m_list_len_types, lower_dir_type(m_scrutinee_type))
            let m_list_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_temp, "len", m_list_len_kinds, m_list_len_values, m_list_len_types, 1, true, m_list_no_names)
            let m_list_len_check = m_list_len_temp + 1
            let m_list_bind_label = m_list_len_check + 1
            let m_list_fail_label = m_list_len_check + 2
            dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, m_list_len_check, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_temp, DIR_NATIVE_OPERAND_IMMEDIATE, m_element_count)
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_check, m_list_bind_label, m_list_fail_label)
            lower_append_label_number(records, m_list_bind_label)
            m_body_counter = m_list_fail_label
            let m_element_slot = 0
            let m_bind_cursor = m_list_token_start
            while m_bind_cursor < m_list_token_end:
                if token_kind(context.kinds, m_bind_cursor) != TOKEN_COMMA:
                    let m_evar_start = token_start(context.starts, m_bind_cursor)
                    let m_evar_end = token_end(context.ends, m_bind_cursor)
                    if context.src[m_evar_start:m_evar_end] != "_":
                        let m_elem_temp = m_body_counter + 1
                        let m_elem_kinds = []
                        let m_elem_values = []
                        let m_elem_types = []
                        append(m_elem_kinds, lower_operand_kind(m_scrutinee_type))
                        append(m_elem_values, m_scrutinee_value)
                        append(m_elem_types, lower_dir_type(m_scrutinee_type))
                        append(m_elem_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                        append(m_elem_values, m_element_slot)
                        append(m_elem_types, DIR_TYPE_I32)
                        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_elem_temp, "get", m_elem_kinds, m_elem_values, m_elem_types, 2, true, m_list_no_names)
                        let m_elem_index = len(variable_starts)
                        let m_elem_slot_name = lower_variable_slot_name_indexed(context.src, m_evar_start, m_evar_end, VALUE_TYPE_INT, m_elem_index)
                        dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, m_elem_slot_name)
                        dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_elem_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_elem_slot_name)
                        append(variable_starts, m_evar_start)
                        append(variable_ends, m_evar_end)
                        append(variable_types, VALUE_TYPE_INT)
                        m_body_counter = m_elem_temp
                    m_element_slot = m_element_slot + 1
                m_bind_cursor = m_bind_cursor + 1
            let m_list_continue_label = m_list_fail_label + 1
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_list_continue_label, 0)
            lower_append_label_number(records, m_list_fail_label)
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_next_label, 0)
            lower_append_label_number(records, m_list_continue_label)
        if m_pattern_kind == AST_PAT_CONS:
            let m_cons_head_start = ast_node_arg(ast, m_pattern_node, 0)
            let m_cons_head_end = ast_node_arg(ast, m_pattern_node, 1)
            let m_cons_tail_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_cons_tail_end = ast_node_arg(ast, m_pattern_node, 3)
            let m_cons_len_temp = m_body_counter + 1
            let m_cons_len_kinds = []
            let m_cons_len_values = []
            let m_cons_len_types = []
            append(m_cons_len_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_cons_len_values, m_scrutinee_value)
            append(m_cons_len_types, lower_dir_type(m_scrutinee_type))
            let m_cons_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_temp, "len", m_cons_len_kinds, m_cons_len_values, m_cons_len_types, 1, true, m_cons_no_names)
            let m_cons_len_check = m_cons_len_temp + 1
            let m_cons_bind_label = m_cons_len_check + 1
            let m_cons_fail_label = m_cons_len_check + 2
            dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_SGT, m_cons_len_check, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_check, m_cons_bind_label, m_cons_fail_label)
            lower_append_label_number(records, m_cons_bind_label)
            m_body_counter = m_cons_fail_label
            if context.src[m_cons_head_start:m_cons_head_end] != "_":
                let m_cons_head_temp = m_body_counter + 1
                let m_cons_head_kinds = []
                let m_cons_head_values = []
                let m_cons_head_types = []
                append(m_cons_head_kinds, lower_operand_kind(m_scrutinee_type))
                append(m_cons_head_values, m_scrutinee_value)
                append(m_cons_head_types, lower_dir_type(m_scrutinee_type))
                append(m_cons_head_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_head_values, 0)
                append(m_cons_head_types, DIR_TYPE_I32)
                dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_head_temp, "get", m_cons_head_kinds, m_cons_head_values, m_cons_head_types, 2, true, m_cons_no_names)
                let m_cons_head_index = len(variable_starts)
                let m_cons_head_slot = lower_variable_slot_name_indexed(context.src, m_cons_head_start, m_cons_head_end, VALUE_TYPE_INT, m_cons_head_index)
                dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, m_cons_head_slot)
                dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_head_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_cons_head_slot)
                append(variable_starts, m_cons_head_start)
                append(variable_ends, m_cons_head_end)
                append(variable_types, VALUE_TYPE_INT)
                m_body_counter = m_cons_head_temp
            if context.src[m_cons_tail_start:m_cons_tail_end] != "_":
                let m_cons_tail_temp = m_body_counter + 1
                let m_cons_tail_kinds = []
                let m_cons_tail_values = []
                let m_cons_tail_types = []
                append(m_cons_tail_kinds, lower_operand_kind(m_scrutinee_type))
                append(m_cons_tail_values, m_scrutinee_value)
                append(m_cons_tail_types, lower_dir_type(m_scrutinee_type))
                append(m_cons_tail_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_tail_values, 1)
                append(m_cons_tail_types, DIR_TYPE_I32)
                append(m_cons_tail_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_tail_values, 2147483647)
                append(m_cons_tail_types, DIR_TYPE_I32)
                dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_tail_temp, "slice_dynarray_i32", m_cons_tail_kinds, m_cons_tail_values, m_cons_tail_types, 3, true, m_cons_no_names)
                let m_cons_tail_index = len(variable_starts)
                let m_cons_tail_slot = lower_variable_slot_name_indexed(context.src, m_cons_tail_start, m_cons_tail_end, VALUE_TYPE_LIST, m_cons_tail_index)
                dir_append_native_alloca(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_NAMED, 0, m_cons_tail_slot)
                dir_append_native_store(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_tail_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_cons_tail_slot)
                append(variable_starts, m_cons_tail_start)
                append(variable_ends, m_cons_tail_end)
                append(variable_types, VALUE_TYPE_LIST)
                m_body_counter = m_cons_tail_temp
            let m_cons_continue_label = m_cons_fail_label + 1
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_cons_continue_label, 0)
            lower_append_label_number(records, m_cons_fail_label)
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_next_label, 0)
            lower_append_label_number(records, m_cons_continue_label)
        if m_pattern_kind == AST_PAT_STRUCT:
            let m_field_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_field_end = ast_node_arg(ast, m_pattern_node, 3)
            let m_struct_name = context.src[ast_node_start(ast, m_pattern_node):ast_node_end(ast, m_pattern_node)]
            let m_field_cursor = m_field_start
            while m_field_cursor < m_field_end:
                let m_fname_start = token_start(context.starts, m_field_cursor)
                let m_fname_end = token_end(context.ends, m_field_cursor)
                let m_fmode_index = m_field_cursor + 2
                let m_fvar_start = token_start(context.starts, m_fmode_index)
                let m_fvar_end = token_end(context.ends, m_fmode_index)
                let m_fvar_name = context.src[m_fvar_start:m_fvar_end]
                if m_fvar_name != "_":
                    let m_field_number = lower_struct_field_index(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_fname_start, m_fname_end)
                    let m_field_slot = 0
                    let m_field_type = VALUE_TYPE_INT
                    if m_field_number >= 0:
                        m_field_slot = lower_struct_field_offset(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_field_number)
                        m_field_type = lower_struct_field_type(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_fname_start, m_fname_end)
                    let m_field_temp = m_body_counter + 1
                    let m_field_kinds = []
                    let m_field_values = []
                    let m_field_types = []
                    append(m_field_kinds, lower_operand_kind(m_scrutinee_type))
                    append(m_field_values, m_scrutinee_value)
                    append(m_field_types, lower_dir_type(m_scrutinee_type))
                    append(m_field_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                    append(m_field_values, m_field_slot)
                    append(m_field_types, DIR_TYPE_I32)
                    if m_field_type == VALUE_TYPE_STRING or is_sequence_value_type(m_field_type) or is_dictionary_value_type(m_field_type) or is_closure_value_type(m_field_type) or is_interface_value_type(m_field_type):
                        dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "get_pointer", m_field_kinds, m_field_values, m_field_types, 2, true, m_no_names)
                        dir_append_native_bitcast(records, lower_dir_type(m_field_type), "i8*", DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp + 1, DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp)
                        m_field_temp = m_field_temp + 1
                    else:
                        dir_append_native_call_direct(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "get", m_field_kinds, m_field_values, m_field_types, 2, true, m_no_names)
                    let m_field_base_slot = lower_variable_slot_name(context.src, m_fvar_start, m_fvar_end, m_field_type)
                    let m_field_index = len(variable_starts)
                    let m_field_slot_name = string_concat(m_field_base_slot, ".p")
                    let m_field_slot_name = string_concat(m_field_slot_name, int_to_string(m_field_index))
                    dir_append_native_alloca(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_NAMED, 0, m_field_slot_name)
                    dir_append_native_store(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_field_slot_name)
                    append(variable_starts, m_fvar_start)
                    append(variable_ends, m_fvar_end)
                    append(variable_types, m_field_type)
                    m_body_counter = m_field_temp
                m_field_cursor = m_fmode_index + 1
                while m_field_cursor < m_field_end and token_kind(context.kinds, m_field_cursor) != TOKEN_COMMA:
                    m_field_cursor = m_field_cursor + 1
                m_field_cursor = m_field_cursor + 1
        # payload 解包:模式记录保存的是 token 范围，直接绑定变量名
        let m_payload_name_start = 0
        let m_payload_name_end = 0
        let m_has_payload_name = false
        if m_pattern_kind == AST_PAT_ENUM:
            let m_payload_token_start = ast_node_arg(ast, m_pattern_node, 4)
            let m_payload_token_end = ast_node_arg(ast, m_pattern_node, 5)
            if m_payload_token_start < m_payload_token_end:
                m_payload_name_start = token_start(context.starts, m_payload_token_start)
                m_payload_name_end = token_end(context.ends, m_payload_token_start)
                m_has_payload_name = true
        if m_pattern_kind == AST_PAT_BUILTIN:
            m_payload_name_start = ast_node_arg(ast, m_pattern_node, 1)
            m_payload_name_end = ast_node_arg(ast, m_pattern_node, 2)
            if m_payload_name_end > m_payload_name_start:
                m_has_payload_name = true
        if m_has_payload_name and context.src[m_payload_name_start:m_payload_name_end] != "_":
            let m_payload_type = VALUE_TYPE_INT
            if m_pattern_kind == AST_PAT_ENUM:
                let m_enum_name_start = ast_node_start(ast, m_pattern_node)
                let m_enum_name_end = ast_node_end(ast, m_pattern_node)
                let m_variant_name_start = ast_node_arg(ast, m_pattern_node, 2)
                let m_variant_name_end = ast_node_arg(ast, m_pattern_node, 3)
                m_payload_type = enum_variant_payload_type(context.src, context.kinds, context.starts, context.ends, m_enum_name_start, m_enum_name_end, m_variant_name_start, m_variant_name_end, 0)
            let m_payload_dir_type = lower_dir_type(m_payload_type)
            let m_payload_temp = m_body_counter + 1
            let m_payload_kinds = []
            let m_payload_values = []
            let m_payload_types = []
            append(m_payload_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_payload_values, m_scrutinee_value)
            append(m_payload_types, lower_dir_type(m_scrutinee_type))
            append(m_payload_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(m_payload_values, 1)
            append(m_payload_types, DIR_TYPE_I32)
            let m_payload_get_symbol = "get"
            let m_payload_storage_type = m_payload_type
            if m_payload_type == VALUE_TYPE_FLOAT:
                m_payload_get_symbol = "get_f64"
            if m_payload_type == VALUE_TYPE_STRING:
                m_payload_get_symbol = "get_pointer"
            if m_payload_type == VALUE_TYPE_BOOL:
                m_payload_storage_type = VALUE_TYPE_INT
            let m_payload_storage_dir_type = lower_dir_type(m_payload_storage_type)
            dir_append_native_call_direct(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, m_payload_temp, m_payload_get_symbol, m_payload_kinds, m_payload_values, m_payload_types, 2, true, m_no_names)
            let m_payload_base_slot = lower_variable_slot_name(context.src, m_payload_name_start, m_payload_name_end, m_payload_storage_type)
            let m_payload_index = len(variable_starts)
            let m_payload_slot = string_concat(m_payload_base_slot, ".p")
            let m_payload_slot = string_concat(m_payload_slot, int_to_string(m_payload_index))
            dir_append_native_alloca(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_NAMED, 0, m_payload_slot)
            dir_append_native_store(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, m_payload_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_payload_slot)
            append(variable_starts, m_payload_name_start)
            append(variable_ends, m_payload_name_end)
            append(variable_types, m_payload_storage_type)
            m_body_counter = m_payload_temp
        if m_guard_node != 0:
            let (m_guard_next, m_guard_type, m_guard_value) = lower_expr(context, ast, m_guard_node, variable_starts, variable_ends, variable_types, m_body_counter, records)
            let m_guard_cond = lower_branch_condition(m_guard_type, m_guard_value, m_guard_next, records)
            let m_guard_body_label = m_guard_cond + 1
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_guard_cond, m_guard_body_label, m_next_label)
            lower_append_label_number(records, m_guard_body_label)
            m_body_counter = m_guard_cond
        let (m_body_next, m_body_type, m_body_value) = lower_expr(context, ast, m_body_node, variable_starts, variable_ends, variable_types, m_body_counter, records)
        dir_append_native_store(records, m_result_dir_type, lower_operand_kind(m_body_type), m_body_value, "", DIR_NATIVE_OPERAND_NAMED, 0, m_result_slot)
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_end_label, 0)
        lower_append_label_number(records, m_next_label)
        m_counter = m_body_next
        if m_counter <= m_next_label:
            m_counter = m_next_label
        m_case_node = ast_node_arg(ast, m_case_node, 3)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_end_label, 0)
    lower_append_label_number(records, m_end_label)
    let m_result_temp = m_counter + 1
    dir_append_native_load(records, m_result_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, m_result_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_result_slot)
    return (m_result_temp, m_result_type, m_result_temp)

def lower_stmt_match(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], break_label: int) -> (int, int):
    let m_scrutinee_node = ast_node_arg(ast, node, 0)
    let m_cases_start = ast_node_arg(ast, node, 1)
    let m_cases_end = ast_node_arg(ast, node, 2)
    let (m_scrutinee_next, m_scrutinee_type, m_scrutinee_value) = lower_expr(context, ast, m_scrutinee_node, variable_starts, variable_ends, variable_types, counter, records)
    let m_is_scalar = false
    if m_scrutinee_type == VALUE_TYPE_INT or m_scrutinee_type == VALUE_TYPE_BOOL or m_scrutinee_type == VALUE_TYPE_FLOAT or m_scrutinee_type == VALUE_TYPE_STRING or m_scrutinee_type == VALUE_TYPE_IMMEDIATE:
        m_is_scalar = true
    let m_tag = m_scrutinee_next + 1
    let m_compare_value = m_scrutinee_value
    let m_compare_type = m_scrutinee_type
    let m_compare_kind = lower_operand_kind(m_scrutinee_type)
    if m_scrutinee_type == VALUE_TYPE_BOOL:
        let m_bool_conv_temp = m_tag
        dir_append_native_select(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_bool_conv_temp, lower_operand_kind(m_scrutinee_type), m_scrutinee_value, DIR_NATIVE_OPERAND_IMMEDIATE, 1, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        m_compare_value = m_bool_conv_temp
        m_compare_type = VALUE_TYPE_INT
        m_compare_kind = DIR_NATIVE_OPERAND_TEMPORARY
        m_tag = m_bool_conv_temp + 1
    let m_tag_kinds = []
    let m_tag_values = []
    let m_tag_types = []
    append(m_tag_kinds, lower_operand_kind(m_scrutinee_type))
    append(m_tag_values, m_scrutinee_value)
    append(m_tag_types, lower_dir_type(m_scrutinee_type))
    append(m_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(m_tag_values, 0)
    append(m_tag_types, DIR_TYPE_I32)
    let m_no_names: list[str] = []
    if not m_is_scalar:
        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_tag, "get", m_tag_kinds, m_tag_values, m_tag_types, 2, true, m_no_names)
        m_compare_value = m_tag
        m_compare_type = VALUE_TYPE_INT
        m_compare_kind = DIR_NATIVE_OPERAND_TEMPORARY
    let m_end_label = m_tag + 1
    let m_counter = m_tag
    let m_next_label = m_tag + 1
    let m_case_node = m_cases_start
    while m_case_node < m_cases_end:
        let m_case_var_count = len(variable_starts)
        let m_pattern_node = ast_node_arg(ast, m_case_node, 0)
        let m_guard_node = ast_node_arg(ast, m_case_node, 1)
        let m_body_node = ast_node_arg(ast, m_case_node, 2)
        let m_case_tag = 0
        let m_pattern_kind = ast_node_kind(ast, m_pattern_node)
        let m_pattern_value_kind = DIR_NATIVE_OPERAND_IMMEDIATE
        let m_pattern_value = 0
        let m_pattern_temp = 0
        if m_pattern_kind == AST_PAT_INT or m_pattern_kind == AST_PAT_BOOL:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_FLOAT:
            let m_float_text = context.src[ast_node_start(ast, m_pattern_node):ast_node_end(ast, m_pattern_node)]
            m_pattern_temp = m_counter + 1
            dir_append_native_operation_text(records, DIR_OPCODE_ADD, DIR_TYPE_F64, m_pattern_temp, DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, "0.0", DIR_NATIVE_OPERAND_FLOAT_TEXT, 0, m_float_text)
            m_pattern_value_kind = DIR_NATIVE_OPERAND_TEMPORARY
            m_pattern_value = m_pattern_temp
            m_counter = m_pattern_temp
        if m_pattern_kind == AST_PAT_STRING:
            let m_str_start = ast_node_start(ast, m_pattern_node)
            let m_str_end = ast_node_end(ast, m_pattern_node)
            let m_str_length = string_literal_length(context.src, m_str_start, m_str_end)
            m_pattern_temp = m_counter + 1
            let m_str_symbol_buffer = [1]
            append_text(m_str_symbol_buffer, "str")
            append_integer(m_str_symbol_buffer, m_str_start)
            let m_str_symbol_marker = m_str_symbol_buffer[0]
            dir_append_native_gep_string(records, m_str_length, DIR_NATIVE_OPERAND_TEMPORARY, m_pattern_temp, m_str_symbol_buffer, m_str_symbol_marker)
            m_pattern_value_kind = DIR_NATIVE_OPERAND_TEMPORARY
            m_pattern_value = m_pattern_temp
            m_counter = m_pattern_temp
        if m_pattern_kind == AST_PAT_RUNE:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_ENUM:
            let m_enum_name_start = ast_node_start(ast, m_pattern_node)
            let m_enum_name_end = ast_node_end(ast, m_pattern_node)
            let m_variant_name_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_variant_name_end = ast_node_arg(ast, m_pattern_node, 3)
            m_case_tag = enum_variant_tag(context.src, context.kinds, context.starts, context.ends, m_enum_name_start, m_enum_name_end, m_variant_name_start, m_variant_name_end)
            m_pattern_value = m_case_tag
        if m_pattern_kind == AST_PAT_BUILTIN:
            m_case_tag = ast_node_arg(ast, m_pattern_node, 0)
            m_pattern_value = m_case_tag
        let m_cond_temp = m_counter + 1
        let m_case_label = m_cond_temp + 1
        m_next_label = m_cond_temp + 2
        if m_pattern_kind == AST_PAT_STRUCT or m_pattern_kind == AST_PAT_WILDCARD or m_pattern_kind == AST_PAT_LIST or m_pattern_kind == AST_PAT_CONS:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_case_label, 0)
        else:
            if m_compare_type == VALUE_TYPE_STRING:
                let m_str_cmp_temp = m_cond_temp + 1
                let m_str_cmp_arg_kinds = []
                let m_str_cmp_arg_values = []
                let m_str_cmp_arg_types = []
                append(m_str_cmp_arg_kinds, m_compare_kind)
                append(m_str_cmp_arg_values, m_compare_value)
                append(m_str_cmp_arg_types, DIR_TYPE_POINTER)
                append(m_str_cmp_arg_kinds, m_pattern_value_kind)
                append(m_str_cmp_arg_values, m_pattern_value)
                append(m_str_cmp_arg_types, DIR_TYPE_POINTER)
                let m_str_cmp_no_names: list[str] = []
                dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cmp_temp, "string_compare", m_str_cmp_arg_kinds, m_str_cmp_arg_values, m_str_cmp_arg_types, 2, true, m_str_cmp_no_names)
                let m_str_cond = m_str_cmp_temp + 1
                dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, m_str_cond, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cmp_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
                dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_str_cond, m_case_label, m_next_label)
                m_counter = m_str_cond
            else:
                let m_compare_dir_type = DIR_TYPE_I32
                let m_compare_predicate = DIR_PREDICATE_EQ
                if m_compare_type == VALUE_TYPE_FLOAT:
                    m_compare_dir_type = DIR_TYPE_F64
                    m_compare_predicate = DIR_PREDICATE_FEQ
                dir_append_native_compare(records, m_compare_dir_type, m_compare_predicate, m_cond_temp, m_compare_kind, m_compare_value, m_pattern_value_kind, m_pattern_value)
                dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_cond_temp, m_case_label, m_next_label)
        lower_append_label_number(records, m_case_label)
        let m_body_counter = m_cond_temp
        if m_pattern_kind == AST_PAT_LIST:
            let m_list_token_start = ast_node_arg(ast, m_pattern_node, 0)
            let m_list_token_end = ast_node_arg(ast, m_pattern_node, 1)
            let m_element_count = 0
            let m_count_cursor = m_list_token_start
            while m_count_cursor < m_list_token_end:
                if token_kind(context.kinds, m_count_cursor) != TOKEN_COMMA:
                    m_element_count = m_element_count + 1
                m_count_cursor = m_count_cursor + 1
            let m_list_len_temp = m_body_counter + 1
            let m_list_len_kinds = []
            let m_list_len_values = []
            let m_list_len_types = []
            append(m_list_len_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_list_len_values, m_scrutinee_value)
            append(m_list_len_types, lower_dir_type(m_scrutinee_type))
            let m_list_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_temp, "len", m_list_len_kinds, m_list_len_values, m_list_len_types, 1, true, m_list_no_names)
            let m_list_len_check = m_list_len_temp + 1
            let m_list_bind_label = m_list_len_check + 1
            let m_list_fail_label = m_list_len_check + 2
            dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, m_list_len_check, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_temp, DIR_NATIVE_OPERAND_IMMEDIATE, m_element_count)
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_list_len_check, m_list_bind_label, m_list_fail_label)
            lower_append_label_number(records, m_list_bind_label)
            m_body_counter = m_list_fail_label
            let m_element_slot = 0
            let m_bind_cursor = m_list_token_start
            while m_bind_cursor < m_list_token_end:
                if token_kind(context.kinds, m_bind_cursor) != TOKEN_COMMA:
                    let m_evar_start = token_start(context.starts, m_bind_cursor)
                    let m_evar_end = token_end(context.ends, m_bind_cursor)
                    if context.src[m_evar_start:m_evar_end] != "_":
                        let m_elem_temp = m_body_counter + 1
                        let m_elem_kinds = []
                        let m_elem_values = []
                        let m_elem_types = []
                        append(m_elem_kinds, lower_operand_kind(m_scrutinee_type))
                        append(m_elem_values, m_scrutinee_value)
                        append(m_elem_types, lower_dir_type(m_scrutinee_type))
                        append(m_elem_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                        append(m_elem_values, m_element_slot)
                        append(m_elem_types, DIR_TYPE_I32)
                        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_elem_temp, "get", m_elem_kinds, m_elem_values, m_elem_types, 2, true, m_list_no_names)
                        let m_elem_index = len(variable_starts)
                        let m_elem_slot_name = lower_variable_slot_name_indexed(context.src, m_evar_start, m_evar_end, VALUE_TYPE_INT, m_elem_index)
                        dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, m_elem_slot_name)
                        dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_elem_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_elem_slot_name)
                        append(variable_starts, m_evar_start)
                        append(variable_ends, m_evar_end)
                        append(variable_types, VALUE_TYPE_INT)
                        m_body_counter = m_elem_temp
                    m_element_slot = m_element_slot + 1
                m_bind_cursor = m_bind_cursor + 1
            let m_list_continue_label = m_list_fail_label + 1
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_list_continue_label, 0)
            lower_append_label_number(records, m_list_fail_label)
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_next_label, 0)
            lower_append_label_number(records, m_list_continue_label)
        if m_pattern_kind == AST_PAT_CONS:
            let m_cons_head_start = ast_node_arg(ast, m_pattern_node, 0)
            let m_cons_head_end = ast_node_arg(ast, m_pattern_node, 1)
            let m_cons_tail_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_cons_tail_end = ast_node_arg(ast, m_pattern_node, 3)
            let m_cons_len_temp = m_body_counter + 1
            let m_cons_len_kinds = []
            let m_cons_len_values = []
            let m_cons_len_types = []
            append(m_cons_len_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_cons_len_values, m_scrutinee_value)
            append(m_cons_len_types, lower_dir_type(m_scrutinee_type))
            let m_cons_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_temp, "len", m_cons_len_kinds, m_cons_len_values, m_cons_len_types, 1, true, m_cons_no_names)
            let m_cons_len_check = m_cons_len_temp + 1
            let m_cons_bind_label = m_cons_len_check + 1
            let m_cons_fail_label = m_cons_len_check + 2
            dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_SGT, m_cons_len_check, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_len_check, m_cons_bind_label, m_cons_fail_label)
            lower_append_label_number(records, m_cons_bind_label)
            m_body_counter = m_cons_fail_label
            if context.src[m_cons_head_start:m_cons_head_end] != "_":
                let m_cons_head_temp = m_body_counter + 1
                let m_cons_head_kinds = []
                let m_cons_head_values = []
                let m_cons_head_types = []
                append(m_cons_head_kinds, lower_operand_kind(m_scrutinee_type))
                append(m_cons_head_values, m_scrutinee_value)
                append(m_cons_head_types, lower_dir_type(m_scrutinee_type))
                append(m_cons_head_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_head_values, 0)
                append(m_cons_head_types, DIR_TYPE_I32)
                dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_head_temp, "get", m_cons_head_kinds, m_cons_head_values, m_cons_head_types, 2, true, m_cons_no_names)
                let m_cons_head_index = len(variable_starts)
                let m_cons_head_slot = lower_variable_slot_name_indexed(context.src, m_cons_head_start, m_cons_head_end, VALUE_TYPE_INT, m_cons_head_index)
                dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, m_cons_head_slot)
                dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_head_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_cons_head_slot)
                append(variable_starts, m_cons_head_start)
                append(variable_ends, m_cons_head_end)
                append(variable_types, VALUE_TYPE_INT)
                m_body_counter = m_cons_head_temp
            if context.src[m_cons_tail_start:m_cons_tail_end] != "_":
                let m_cons_tail_temp = m_body_counter + 1
                let m_cons_tail_kinds = []
                let m_cons_tail_values = []
                let m_cons_tail_types = []
                append(m_cons_tail_kinds, lower_operand_kind(m_scrutinee_type))
                append(m_cons_tail_values, m_scrutinee_value)
                append(m_cons_tail_types, lower_dir_type(m_scrutinee_type))
                append(m_cons_tail_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_tail_values, 1)
                append(m_cons_tail_types, DIR_TYPE_I32)
                append(m_cons_tail_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                append(m_cons_tail_values, 2147483647)
                append(m_cons_tail_types, DIR_TYPE_I32)
                dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_tail_temp, "slice_dynarray_i32", m_cons_tail_kinds, m_cons_tail_values, m_cons_tail_types, 3, true, m_cons_no_names)
                let m_cons_tail_index = len(variable_starts)
                let m_cons_tail_slot = lower_variable_slot_name_indexed(context.src, m_cons_tail_start, m_cons_tail_end, VALUE_TYPE_LIST, m_cons_tail_index)
                dir_append_native_alloca(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_NAMED, 0, m_cons_tail_slot)
                dir_append_native_store(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, m_cons_tail_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_cons_tail_slot)
                append(variable_starts, m_cons_tail_start)
                append(variable_ends, m_cons_tail_end)
                append(variable_types, VALUE_TYPE_LIST)
                m_body_counter = m_cons_tail_temp
            let m_cons_continue_label = m_cons_fail_label + 1
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_cons_continue_label, 0)
            lower_append_label_number(records, m_cons_fail_label)
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_next_label, 0)
            lower_append_label_number(records, m_cons_continue_label)
        if m_pattern_kind == AST_PAT_STRUCT:
            let m_field_start = ast_node_arg(ast, m_pattern_node, 2)
            let m_field_end = ast_node_arg(ast, m_pattern_node, 3)
            let m_struct_name = context.src[ast_node_start(ast, m_pattern_node):ast_node_end(ast, m_pattern_node)]
            let m_field_cursor = m_field_start
            while m_field_cursor < m_field_end:
                let m_fname_start = token_start(context.starts, m_field_cursor)
                let m_fname_end = token_end(context.ends, m_field_cursor)
                let m_fmode_index = m_field_cursor + 2
                let m_fvar_start = token_start(context.starts, m_fmode_index)
                let m_fvar_end = token_end(context.ends, m_fmode_index)
                let m_fvar_name = context.src[m_fvar_start:m_fvar_end]
                if m_fvar_name != "_":
                    let m_field_number = lower_struct_field_index(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_fname_start, m_fname_end)
                    let m_field_slot = 0
                    let m_field_type = VALUE_TYPE_INT
                    if m_field_number >= 0:
                        m_field_slot = lower_struct_field_offset(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_field_number)
                        m_field_type = lower_struct_field_type(context.src, context.kinds, context.starts, context.ends, m_struct_name, m_fname_start, m_fname_end)
                    let m_field_temp = m_body_counter + 1
                    let m_field_kinds = []
                    let m_field_values = []
                    let m_field_types = []
                    append(m_field_kinds, lower_operand_kind(m_scrutinee_type))
                    append(m_field_values, m_scrutinee_value)
                    append(m_field_types, lower_dir_type(m_scrutinee_type))
                    append(m_field_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
                    append(m_field_values, m_field_slot)
                    append(m_field_types, DIR_TYPE_I32)
                    if m_field_type == VALUE_TYPE_STRING or is_sequence_value_type(m_field_type) or is_dictionary_value_type(m_field_type) or is_closure_value_type(m_field_type) or is_interface_value_type(m_field_type):
                        dir_append_native_call_direct(records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "get_pointer", m_field_kinds, m_field_values, m_field_types, 2, true, m_no_names)
                        dir_append_native_bitcast(records, lower_dir_type(m_field_type), "i8*", DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp + 1, DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp)
                        m_field_temp = m_field_temp + 1
                    else:
                        dir_append_native_call_direct(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "get", m_field_kinds, m_field_values, m_field_types, 2, true, m_no_names)
                    let m_field_base_slot = lower_variable_slot_name(context.src, m_fvar_start, m_fvar_end, m_field_type)
                    let m_field_index = len(variable_starts)
                    let m_field_slot_name = string_concat(m_field_base_slot, ".p")
                    let m_field_slot_name = string_concat(m_field_slot_name, int_to_string(m_field_index))
                    dir_append_native_alloca(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_NAMED, 0, m_field_slot_name)
                    dir_append_native_store(records, lower_dir_type(m_field_type), DIR_NATIVE_OPERAND_TEMPORARY, m_field_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_field_slot_name)
                    append(variable_starts, m_fvar_start)
                    append(variable_ends, m_fvar_end)
                    append(variable_types, m_field_type)
                    m_body_counter = m_field_temp
                m_field_cursor = m_fmode_index + 1
                while m_field_cursor < m_field_end and token_kind(context.kinds, m_field_cursor) != TOKEN_COMMA:
                    m_field_cursor = m_field_cursor + 1
                m_field_cursor = m_field_cursor + 1
        # payload 解包:模式记录保存的是 token 范围，直接绑定变量名
        let m_payload_name_start = 0
        let m_payload_name_end = 0
        let m_has_payload_name = false
        if m_pattern_kind == AST_PAT_ENUM:
            let m_payload_token_start = ast_node_arg(ast, m_pattern_node, 4)
            let m_payload_token_end = ast_node_arg(ast, m_pattern_node, 5)
            if m_payload_token_start < m_payload_token_end:
                m_payload_name_start = token_start(context.starts, m_payload_token_start)
                m_payload_name_end = token_end(context.ends, m_payload_token_start)
                m_has_payload_name = true
        if m_pattern_kind == AST_PAT_BUILTIN:
            m_payload_name_start = ast_node_arg(ast, m_pattern_node, 1)
            m_payload_name_end = ast_node_arg(ast, m_pattern_node, 2)
            if m_payload_name_end > m_payload_name_start:
                m_has_payload_name = true
        if m_has_payload_name and context.src[m_payload_name_start:m_payload_name_end] != "_":
            let m_payload_type = VALUE_TYPE_INT
            if m_pattern_kind == AST_PAT_ENUM:
                let m_enum_name_start = ast_node_start(ast, m_pattern_node)
                let m_enum_name_end = ast_node_end(ast, m_pattern_node)
                let m_variant_name_start = ast_node_arg(ast, m_pattern_node, 2)
                let m_variant_name_end = ast_node_arg(ast, m_pattern_node, 3)
                m_payload_type = enum_variant_payload_type(context.src, context.kinds, context.starts, context.ends, m_enum_name_start, m_enum_name_end, m_variant_name_start, m_variant_name_end, 0)
            let m_payload_dir_type = lower_dir_type(m_payload_type)
            let m_payload_temp = m_body_counter + 1
            let m_payload_kinds = []
            let m_payload_values = []
            let m_payload_types = []
            append(m_payload_kinds, lower_operand_kind(m_scrutinee_type))
            append(m_payload_values, m_scrutinee_value)
            append(m_payload_types, lower_dir_type(m_scrutinee_type))
            append(m_payload_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(m_payload_values, 1)
            append(m_payload_types, DIR_TYPE_I32)
            let m_payload_get_symbol = "get"
            let m_payload_storage_type = m_payload_type
            if m_payload_type == VALUE_TYPE_FLOAT:
                m_payload_get_symbol = "get_f64"
            if m_payload_type == VALUE_TYPE_STRING:
                m_payload_get_symbol = "get_pointer"
            if m_payload_type == VALUE_TYPE_BOOL:
                m_payload_storage_type = VALUE_TYPE_INT
            let m_payload_storage_dir_type = lower_dir_type(m_payload_storage_type)
            dir_append_native_call_direct(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, m_payload_temp, m_payload_get_symbol, m_payload_kinds, m_payload_values, m_payload_types, 2, true, m_no_names)
            let m_payload_base_slot = lower_variable_slot_name(context.src, m_payload_name_start, m_payload_name_end, m_payload_storage_type)
            let m_payload_index = len(variable_starts)
            let m_payload_slot = string_concat(m_payload_base_slot, ".p")
            let m_payload_slot = string_concat(m_payload_slot, int_to_string(m_payload_index))
            dir_append_native_alloca(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_NAMED, 0, m_payload_slot)
            dir_append_native_store(records, m_payload_storage_dir_type, DIR_NATIVE_OPERAND_TEMPORARY, m_payload_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, m_payload_slot)
            append(variable_starts, m_payload_name_start)
            append(variable_ends, m_payload_name_end)
            append(variable_types, m_payload_storage_type)
            m_body_counter = m_payload_temp
        if m_guard_node != 0:
            let (m_guard_next, m_guard_type, m_guard_value) = lower_expr(context, ast, m_guard_node, variable_starts, variable_ends, variable_types, m_body_counter, records)
            let m_guard_cond = lower_branch_condition(m_guard_type, m_guard_value, m_guard_next, records)
            let m_guard_body_label = m_guard_cond + 1
            dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, m_guard_cond, m_guard_body_label, m_next_label)
            lower_append_label_number(records, m_guard_body_label)
            m_body_counter = m_guard_cond
        let m_body_next = m_body_counter
        let m_body_block_end = ast_node_arg(ast, m_case_node, 3)
        let (stmt_body_next, stmt_body_has) = lower_stmt_block(context, ast, m_body_node, m_body_block_end, variable_starts, variable_ends, variable_types, m_body_counter, records, buffer, 0, break_label)
        m_body_next = stmt_body_next
        if stmt_body_has == 0:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_end_label, 0)
        lower_append_label_number(records, m_next_label)
        m_counter = m_body_next
        if m_counter <= m_next_label:
            m_counter = m_next_label
        m_case_node = ast_node_arg(ast, m_case_node, 3)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, m_end_label, 0)
    lower_append_label_number(records, m_end_label)
    return (m_counter + 1, 0)

def lower_lambda_number(ast: list[int], node: int) -> int:
    if node >= len(ast):
        return 0
    let count = 0
    let scan_node = 1
    while scan_node < node:
        if ast_node_kind(ast, scan_node) == AST_EXPR_LAMBDA:
            count = count + 1
        scan_node = ast_next_node(ast, scan_node)
    return count

def lower_lambda_symbol_name(lambda_number: int) -> str:
    let symbol_bytes: list[byte] = []
    append(symbol_bytes, 108)
    append(symbol_bytes, 97)
    append(symbol_bytes, 109)
    append(symbol_bytes, 98)
    append(symbol_bytes, 100)
    append(symbol_bytes, 97)
    append(symbol_bytes, 46)
    if lambda_number == 0:
        append(symbol_bytes, 48)
    else:
        let digits: list[byte] = []
        let remaining_number = lambda_number
        while remaining_number > 0:
            let digit = remaining_number % 10
            append(digits, 48 + digit)
            remaining_number = remaining_number / 10
        let digit_index = len(digits) - 1
        while digit_index >= 0:
            append(symbol_bytes, digits[digit_index])
            digit_index = digit_index - 1
    let symbol_value = __c_bytes_from_array(symbol_bytes)
    return __c_bytes_to_str(symbol_value)

def lower_lambda_helper(context: ParseContext, ast: list[int], lambda_node: int, records: list[int], lambda_number: int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let source = context.src
    let lambda_param_start = ast_node_arg(ast, lambda_node, 0)
    let lambda_param_end = ast_node_arg(ast, lambda_node, 1)
    let lambda_body_node = ast_node_arg(ast, lambda_node, 2)
    let lambda_records = []
    let header_buffer = [1]
    append_text(header_buffer, "define i32 @lambda.")
    append_integer(header_buffer, lambda_number)
    append_text(header_buffer, "(i32 %value.param) {\nentry:\n")
    let header_buffer_marker = header_buffer[0]
    dir_append_record(lambda_records, DIR_TAG_FUNCTION, DIR_TAG_INVALID, 0, 0, 0, header_buffer, header_buffer_marker, len(header_buffer))
    let lambda_var_starts = []
    let lambda_var_ends = []
    let lambda_var_types = []
    let lambda_param_index = lambda_param_start
    let lambda_param_counter = 0
    while lambda_param_index < lambda_param_end:
        if token_kind(kinds, lambda_param_index) == TOKEN_IDENTIFIER:
            let lambda_param_name_start = token_start(starts, lambda_param_index)
            let lambda_param_name_end = token_end(ends, lambda_param_index)
            let lambda_param_name = source[lambda_param_name_start:lambda_param_name_end]
            if lambda_param_name != "int" and lambda_param_name != "str" and lambda_param_name != "bool" and lambda_param_name != "float":
                let lambda_param_index_id = len(lambda_var_starts)
                let lambda_param_slot = lower_variable_slot_name_indexed(source, lambda_param_name_start, lambda_param_name_end, VALUE_TYPE_INT, lambda_param_index_id)
                dir_append_native_alloca(lambda_records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, lambda_param_slot)
                dir_append_native_store(lambda_records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, string_concat(lambda_param_name, ".param"), DIR_NATIVE_OPERAND_NAMED, 0, lambda_param_slot)
                append(lambda_var_starts, lambda_param_name_start)
                append(lambda_var_ends, lambda_param_name_end)
                append(lambda_var_types, VALUE_TYPE_INT)
                lambda_param_counter = lambda_param_counter + 1
        lambda_param_index = lambda_param_index + 1
    let (lambda_body_next, lambda_body_type, lambda_body_value) = lower_expr(context, ast, lambda_body_node, lambda_var_starts, lambda_var_ends, lambda_var_types, lambda_param_counter, lambda_records)
    dir_append_native_ret(lambda_records, DIR_TYPE_I32, lower_operand_kind(lambda_body_type), lambda_body_value)
    let function_end_buffer = [1]
    append_text(function_end_buffer, "}\n")
    let function_end_buffer_marker = function_end_buffer[0]
    dir_append_record(lambda_records, DIR_TAG_FUNCTION_END, DIR_TAG_INVALID, 0, 0, 0, function_end_buffer, function_end_buffer_marker, len(function_end_buffer))
    append_hoisted_function(records, lambda_records)

def lower_expr_lambda(context: ParseContext, ast: list[int], node: int, counter: int) -> (int, int, int):
    let lambda_number = lower_lambda_number(ast, node)
    return (counter, 0 - (lambda_number + 1), lambda_number)

def lower_expr_method_call(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let mc_receiver_node = ast_node_arg(ast, node, 0)
    let mc_name_start = ast_node_arg(ast, node, 1)
    let mc_name_end = ast_node_arg(ast, node, 2)
    let mc_arg_count = ast_node_arg(ast, node, 3)
    let mc_receiver_kind = ast_node_kind(ast, mc_receiver_node)
    if mc_receiver_kind == AST_EXPR_VAR:
        # enum 构造:receiver 名匹配 enum 声明
        let mc_receiver_start = ast_node_start(ast, mc_receiver_node)
        let mc_receiver_end = ast_node_end(ast, mc_receiver_node)
        if find_variable(context.src, mc_receiver_start, mc_receiver_end, variable_starts, variable_ends) < 0:
            let mc_enum_variant_tag = enum_variant_tag(context.src, context.kinds, context.starts, context.ends, mc_receiver_start, mc_receiver_end, mc_name_start, mc_name_end)
            let mc_result = counter + 1
            let mc_create_kinds = []
            let mc_create_values = []
            let mc_create_types = []
            append(mc_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(mc_create_values, 4)
            append(mc_create_types, DIR_TYPE_I32)
            let mc_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, mc_result, "create_dynarray_i32", mc_create_kinds, mc_create_values, mc_create_types, 1, true, mc_no_names)
            let mc_tag_kinds = []
            let mc_tag_values = []
            let mc_tag_types = []
            append(mc_tag_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
            append(mc_tag_values, mc_result)
            append(mc_tag_types, DIR_TYPE_LIST)
            append(mc_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(mc_tag_values, mc_enum_variant_tag)
            append(mc_tag_types, DIR_TYPE_I32)
            dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append_i32", mc_tag_kinds, mc_tag_values, mc_tag_types, 2, false, mc_no_names)
            let mc_arg_counter = mc_result
            let mc_arg_index = 0
            while mc_arg_index < mc_arg_count:
                let mc_arg_node = ast_node_arg(ast, node, 5 + mc_arg_index)
                let (mc_arg_next, mc_arg_type, mc_arg_value) = lower_expr(context, ast, mc_arg_node, variable_starts, variable_ends, variable_types, mc_arg_counter, records)
                let mc_payload_kinds = []
                let mc_payload_values = []
                let mc_payload_types = []
                append(mc_payload_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
                append(mc_payload_values, mc_result)
                append(mc_payload_types, DIR_TYPE_LIST)
                append(mc_payload_kinds, lower_operand_kind(mc_arg_type))
                append(mc_payload_values, mc_arg_value)
                append(mc_payload_types, lower_dir_type(mc_arg_type))
                dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append_i32", mc_payload_kinds, mc_payload_values, mc_payload_types, 2, false, mc_no_names)
                mc_arg_counter = mc_arg_next
                mc_arg_index = mc_arg_index + 1
            return (mc_arg_counter, VALUE_TYPE_LIST, mc_result)
    return (counter, VALUE_TYPE_INT, 0)

def lower_expr_list_comp(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let lc_element_node = ast_node_arg(ast, node, 0)
    let lc_name_start = ast_node_arg(ast, node, 1)
    let lc_name_end = ast_node_arg(ast, node, 2)
    let lc_source_node = ast_node_arg(ast, node, 3)
    let lc_condition_node = ast_node_arg(ast, node, 6)
    let (lc_source_next, lc_source_type, lc_source_value) = lower_expr(context, ast, lc_source_node, variable_starts, variable_ends, variable_types, counter, records)
    let lc_index_id = len(variable_starts)
    let lc_index_slot = lower_variable_slot_name_indexed(context.src, lc_name_start, lc_name_end, VALUE_TYPE_INT, lc_index_id)
    dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, lc_index_slot)
    dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_IMMEDIATE, 0, "", DIR_NATIVE_OPERAND_NAMED, 0, lc_index_slot)
    append(variable_starts, lc_name_start)
    append(variable_ends, lc_name_end)
    append(variable_types, VALUE_TYPE_INT)
    let lc_result = lc_source_next + 1
    let lc_create_kinds = []
    let lc_create_values = []
    let lc_create_types = []
    append(lc_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(lc_create_values, 0)
    append(lc_create_types, DIR_TYPE_I32)
    let lc_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, lc_result, "create_dynarray_i32", lc_create_kinds, lc_create_values, lc_create_types, 1, true, lc_no_names)
    let lc_length = lc_source_next + 2
    let lc_label_base = lc_source_next + 3
    let lc_check = lc_label_base
    let lc_body = lc_label_base + 1
    let lc_end = lc_label_base + 2
    let lc_len_kinds = []
    let lc_len_values = []
    let lc_len_types = []
    append(lc_len_kinds, lower_operand_kind(lc_source_type))
    append(lc_len_values, lc_source_value)
    append(lc_len_types, lower_dir_type(lc_source_type))
    dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, lc_length, "len", lc_len_kinds, lc_len_values, lc_len_types, 1, true, lc_no_names)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, lc_check, 0)
    lower_append_label_number(records, lc_check)
    let lc_index_temp = lc_length + 1
    dir_append_native_load(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, lc_index_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, lc_index_slot)
    let lc_cond_temp = lc_index_temp + 1
    dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_SLT, lc_cond_temp, DIR_NATIVE_OPERAND_TEMPORARY, lc_index_temp, DIR_NATIVE_OPERAND_TEMPORARY, lc_length)
    dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, lc_cond_temp, lc_body, lc_end)
    lower_append_label_number(records, lc_body)
    let lc_get_kinds = []
    let lc_get_values = []
    let lc_get_types = []
    append(lc_get_kinds, lower_operand_kind(lc_source_type))
    append(lc_get_values, lc_source_value)
    append(lc_get_types, lower_dir_type(lc_source_type))
    append(lc_get_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
    append(lc_get_values, lc_index_temp)
    append(lc_get_types, DIR_TYPE_I32)
    let lc_element_temp = lc_cond_temp + 1
    dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, lc_element_temp, "get", lc_get_kinds, lc_get_values, lc_get_types, 2, true, lc_no_names)
    dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, lc_element_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, lc_index_slot)
    let lc_after_cond_counter = lc_element_temp
    let lc_append_label = lc_element_temp + 1
    let lc_next_label = lc_element_temp + 2
    if lc_condition_node != 0:
        let (lc_cond_next, lc_cond_type, lc_cond_value) = lower_expr(context, ast, lc_condition_node, variable_starts, variable_ends, variable_types, lc_element_temp, records)
        let lc_condition = lower_branch_condition(lc_cond_type, lc_cond_value, lc_cond_next, records)
        lc_append_label = lc_condition + 1
        lc_next_label = lc_condition + 2
        dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, lc_condition, lc_append_label, lc_next_label)
        lower_append_label_number(records, lc_append_label)
        lc_after_cond_counter = lc_cond_next
    let (lc_element_next, lc_element_type, lc_element_value) = lower_expr(context, ast, lc_element_node, variable_starts, variable_ends, variable_types, lc_after_cond_counter, records)
    let lc_append_kinds = []
    let lc_append_values = []
    let lc_append_types = []
    append(lc_append_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
    append(lc_append_values, lc_result)
    append(lc_append_types, DIR_TYPE_LIST)
    append(lc_append_kinds, lower_operand_kind(lc_element_type))
    append(lc_append_values, lc_element_value)
    append(lc_append_types, lower_dir_type(lc_element_type))
    dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append", lc_append_kinds, lc_append_values, lc_append_types, 2, false, lc_no_names)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, lc_next_label, 0)
    lower_append_label_number(records, lc_next_label)
    let lc_inc_temp = lc_element_next + 1
    let lc_added_temp = lc_inc_temp + 1
    dir_append_native_operation(records, DIR_OPCODE_ADD, DIR_TYPE_I32, lc_added_temp, DIR_NATIVE_OPERAND_TEMPORARY, lc_index_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 1)
    dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, lc_added_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, lc_index_slot)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, lc_check, 0)
    lower_append_label_number(records, lc_end)
    return (lc_added_temp, VALUE_TYPE_LIST, lc_result)

def lower_expr_dict(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let dict_count = ast_node_arg(ast, node, 0)
    let dict_first_key_node = ast_node_arg(ast, node, 1)
    let (dict_first_key_next, dict_first_key_type, dict_first_key_value) = lower_expr(context, ast, dict_first_key_node, variable_starts, variable_ends, variable_types, counter, records)
    let dict_first_value_node = ast_node_arg(ast, node, 21)
    let (dict_first_value_next, dict_first_value_type, dict_first_value_value) = lower_expr(context, ast, dict_first_value_node, variable_starts, variable_ends, variable_types, dict_first_key_next, records)
    let dict_key_is_string = dict_first_key_type == VALUE_TYPE_STRING
    let dict_value_is_string = dict_first_value_type == VALUE_TYPE_STRING
    let dict_result = dict_first_value_next + 1
    let dict_create_symbol = "dream_dict_create_int_int"
    if dict_key_is_string:
        dict_create_symbol = "dream_dict_create_str_int"
    if dict_key_is_string and dict_value_is_string:
        dict_create_symbol = "dream_dict_create_str_str"
    if not dict_key_is_string and dict_value_is_string:
        dict_create_symbol = "dream_dict_create_int_str"
    let dict_create_kinds = []
    let dict_create_values = []
    let dict_create_types = []
    append(dict_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(dict_create_values, 8)
    append(dict_create_types, DIR_TYPE_I32)
    let dict_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_DICT, DIR_NATIVE_OPERAND_TEMPORARY, dict_result, dict_create_symbol, dict_create_kinds, dict_create_values, dict_create_types, 1, true, dict_no_names)
    let dict_set_symbol = "dict_set_int_int"
    if dict_key_is_string:
        dict_set_symbol = "dict_set_str_int"
    if dict_key_is_string and dict_value_is_string:
        dict_set_symbol = "dict_set_str_str"
    if not dict_key_is_string and dict_value_is_string:
        dict_set_symbol = "dict_set_int_str"
    let dict_set_kinds = []
    let dict_set_values = []
    let dict_set_types = []
    append(dict_set_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
    append(dict_set_values, dict_result)
    append(dict_set_types, DIR_TYPE_DICT)
    append(dict_set_kinds, lower_operand_kind(dict_first_key_type))
    append(dict_set_values, dict_first_key_value)
    if dict_key_is_string:
        append(dict_set_types, DIR_TYPE_POINTER)
    else:
        append(dict_set_types, DIR_TYPE_I32)
    append(dict_set_kinds, lower_operand_kind(dict_first_value_type))
    append(dict_set_values, dict_first_value_value)
    if dict_value_is_string:
        append(dict_set_types, DIR_TYPE_POINTER)
    else:
        append(dict_set_types, DIR_TYPE_I32)
    dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, dict_set_symbol, dict_set_kinds, dict_set_values, dict_set_types, 3, false, dict_no_names)
    let dict_pair_counter = dict_first_value_next + 1
    let dict_pair_index = 1
    while dict_pair_index < dict_count:
        let dict_key_node = ast_node_arg(ast, node, 1 + dict_pair_index)
        let dict_value_node = ast_node_arg(ast, node, 21 + dict_pair_index)
        let (dict_key_next, dict_key_type, dict_key_value) = lower_expr(context, ast, dict_key_node, variable_starts, variable_ends, variable_types, dict_pair_counter, records)
        let (dict_value_next, dict_value_type, dict_value_value) = lower_expr(context, ast, dict_value_node, variable_starts, variable_ends, variable_types, dict_key_next, records)
        let dict_set_more_kinds = []
        let dict_set_more_values = []
        let dict_set_more_types = []
        append(dict_set_more_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
        append(dict_set_more_values, dict_result)
        append(dict_set_more_types, DIR_TYPE_DICT)
        append(dict_set_more_kinds, lower_operand_kind(dict_key_type))
        append(dict_set_more_values, dict_key_value)
        if dict_key_is_string:
            append(dict_set_more_types, DIR_TYPE_POINTER)
        else:
            append(dict_set_more_types, DIR_TYPE_I32)
        append(dict_set_more_kinds, lower_operand_kind(dict_value_type))
        append(dict_set_more_values, dict_value_value)
        if dict_value_is_string:
            append(dict_set_more_types, DIR_TYPE_POINTER)
        else:
            append(dict_set_more_types, DIR_TYPE_I32)
        dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, dict_set_symbol, dict_set_more_kinds, dict_set_more_values, dict_set_more_types, 3, false, dict_no_names)
        dict_pair_counter = dict_value_next
        dict_pair_index = dict_pair_index + 1
    let dict_result_type = VALUE_TYPE_DICT_INT_INT
    if dict_key_is_string and dict_value_is_string:
        dict_result_type = VALUE_TYPE_DICT_STRING_STRING
    if dict_key_is_string and not dict_value_is_string:
        dict_result_type = VALUE_TYPE_DICT_STRING_INT
    if not dict_key_is_string and dict_value_is_string:
        dict_result_type = VALUE_TYPE_DICT_INT_STRING
    return (dict_pair_counter, dict_result_type, dict_result)

def lower_expr_list(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let list_count = ast_node_arg(ast, node, 0)
    let list_result = counter + 1
    let create_arg_kinds = []
    let create_arg_values = []
    let create_arg_types = []
    append(create_arg_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
    append(create_arg_values, 0)
    append(create_arg_types, DIR_TYPE_I32)
    let create_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, list_result, "create_dynarray_i32", create_arg_kinds, create_arg_values, create_arg_types, 1, true, create_no_names)
    let list_element_index = 0
    let list_element_counter = list_result
    while list_element_index < list_count:
        let list_element_node = ast_node_arg(ast, node, 1 + list_element_index)
        let (list_element_next, list_element_type, list_element_value) = lower_expr(context, ast, list_element_node, variable_starts, variable_ends, variable_types, list_element_counter, records)
        list_element_counter = lower_append_collection_value(records, list_result, list_element_type, lower_operand_kind(list_element_type), list_element_value, list_element_next)
        list_element_index = list_element_index + 1
    return (list_element_counter, VALUE_TYPE_LIST, list_result)

def lower_expr_call(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    let ends = context.ends
    let fn_ends = context.fn_ends
    let fn_starts = context.fn_starts
    let kinds = context.kinds
    let starts = context.starts
    let source = context.src
    let call_callee_node = ast_node_arg(ast, node, 0)
    let call_arg_count = ast_node_arg(ast, node, 1)
    let call_callee_kind = ast_node_kind(ast, call_callee_node)
    if call_callee_kind != AST_EXPR_VAR:
        return (counter, VALUE_TYPE_INT, 0)
    let call_name_start = ast_node_start(ast, call_callee_node)
    let call_name_end = ast_node_end(ast, call_callee_node)
    let call_name = source[call_name_start:call_name_end]
    let call_function_index = find_function(source, call_name_start, call_name_end, context.fn_starts, context.fn_ends)
    let call_symbol = call_name
    let call_return_type = VALUE_TYPE_INT
    if call_name == "__c_range_equal":
        call_return_type = VALUE_TYPE_BOOL
    if call_function_index < 0:
        # 函数值调用:callee 变量类型是函数值 → 解析目标函数
        let call_callee_var_index = lower_find_variable(source, call_name_start, call_name_end, variable_starts, variable_ends)
        if call_callee_var_index >= 0:
            let call_callee_type = variable_types[call_callee_var_index]
            if is_lambda_value_type(call_callee_type):
                call_symbol = lower_lambda_symbol_name(lambda_value_index(call_callee_type))
                call_return_type = VALUE_TYPE_INT
            elif is_function_value_type(call_callee_type):
                call_function_index = function_value_index(variable_types[call_callee_var_index])
    if call_function_index >= 0:
        call_symbol = function_symbol_name(source, context.kinds, context.starts, context.ends, context.fn_starts[call_function_index], context.fn_ends[call_function_index])
        call_return_type = context.ret_types[call_function_index]
        # 包级可见性检查:跨包不能调用私有符号
        if not is_access_allowed(context, call_name_start, call_name, context.fn_starts[call_function_index]):
            report_access_violation(context, call_name_start, call_name, context.fn_starts[call_function_index])
            return (counter, VALUE_TYPE_INT, 0)
    let call_arg_kinds = []
    let call_arg_values = []
    let call_arg_types = []
    let call_argument_counter = counter
    let call_argument_index = 0
    while call_argument_index < call_arg_count:
        let call_argument_node = ast_node_arg(ast, node, 3 + call_argument_index)
        let (call_argument_next, call_argument_type, call_argument_value) = lower_expr(context, ast, call_argument_node, variable_starts, variable_ends, variable_types, call_argument_counter, records)
        append(call_arg_kinds, lower_operand_kind(call_argument_type))
        append(call_arg_values, call_argument_value)
        append(call_arg_types, lower_dir_type(call_argument_type))
        call_argument_counter = call_argument_next
        call_argument_index = call_argument_index + 1
    if call_function_index >= 0:
        let call_param_offset = context.param_offsets[call_function_index]
        let call_param_count = context.param_counts[call_function_index]
        let call_missing_index = call_arg_count
        while call_missing_index < call_param_count:
            let call_default_token = context.pd[call_param_offset + call_missing_index]
            if call_default_token < 0:
                break
            let call_default_ast = [0]
            let (call_default_next_index, call_default_node) = ast_parse_expression(context, call_default_token, call_default_ast)
            let (call_default_next, call_default_type, call_default_value) = lower_expr(context, call_default_ast, call_default_node, variable_starts, variable_ends, variable_types, call_argument_counter, records)
            append(call_arg_kinds, lower_operand_kind(call_default_type))
            append(call_arg_values, call_default_value)
            append(call_arg_types, lower_dir_type(call_default_type))
            call_argument_counter = call_default_next
            call_missing_index = call_missing_index + 1
    if call_name == "ord" and len(call_arg_kinds) > 0:
        # ord 是身份函数(rune 与 int 底层都是 i32)
        let ord_result_type = VALUE_TYPE_INT
        if call_arg_kinds[0] == DIR_NATIVE_OPERAND_IMMEDIATE:
            ord_result_type = VALUE_TYPE_IMMEDIATE
        return (call_argument_counter, ord_result_type, call_arg_values[0])
    if call_function_index < 0:
        # 内置 enum 构造(Ok/Some=0, Err/None=1):dynarray 存 tag + 载荷
        if call_name == "Ok" or call_name == "Err" or call_name == "Some" or call_name == "None":
            let enum_result = call_argument_counter + 1
            let enum_tag = 0
            if call_name == "Err" or call_name == "None":
                enum_tag = 1
            let enum_create_kinds = []
            let enum_create_values = []
            let enum_create_types = []
            append(enum_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(enum_create_values, 4)
            append(enum_create_types, DIR_TYPE_I32)
            let enum_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, enum_result, "create_dynarray_i32", enum_create_kinds, enum_create_values, enum_create_types, 1, true, enum_no_names)
            let enum_tag_kinds = []
            let enum_tag_values = []
            let enum_tag_types = []
            append(enum_tag_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
            append(enum_tag_values, enum_result)
            append(enum_tag_types, DIR_TYPE_LIST)
            append(enum_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(enum_tag_values, enum_tag)
            append(enum_tag_types, DIR_TYPE_I32)
            dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append_i32", enum_tag_kinds, enum_tag_values, enum_tag_types, 2, false, enum_no_names)
            let enum_counter = enum_result
            if len(call_arg_kinds) > 0:
                let enum_payload_kinds = []
                let enum_payload_values = []
                let enum_payload_types = []
                append(enum_payload_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
                append(enum_payload_values, enum_result)
                append(enum_payload_types, DIR_TYPE_LIST)
                let enum_payload_kind = call_arg_kinds[0]
                let enum_payload_value = call_arg_values[0]
                let enum_payload_type = call_arg_types[0]
                let enum_payload_symbol = "append_i32"
                if enum_payload_type == DIR_TYPE_POINTER:
                    enum_payload_symbol = "append_pointer"
                if enum_payload_type == DIR_TYPE_F64:
                    enum_payload_symbol = "append_f64"
                if enum_payload_type == DIR_TYPE_BOOL:
                    let enum_bool_value = enum_result + 1
                    dir_append_native_zext(records, enum_bool_value, enum_payload_kind, enum_payload_value)
                    enum_payload_kind = DIR_NATIVE_OPERAND_TEMPORARY
                    enum_payload_value = enum_bool_value
                    enum_payload_type = DIR_TYPE_I32
                    enum_counter = enum_bool_value
                append(enum_payload_kinds, enum_payload_kind)
                append(enum_payload_values, enum_payload_value)
                append(enum_payload_types, enum_payload_type)
                dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, enum_payload_symbol, enum_payload_kinds, enum_payload_values, enum_payload_types, 2, false, enum_no_names)
            return (enum_counter, VALUE_TYPE_LIST, enum_result)
        # 内建调用:len 按实参类型分派,其余同名符号调用
        call_return_type = lower_builtin_return_type(call_name)
        if call_name == "__c_range_equal":
            call_return_type = VALUE_TYPE_BOOL
        if call_name == "len":
            if len(call_arg_kinds) > 0:
                if call_arg_types[0] == DIR_TYPE_INTERFACE:
                    let (len_iface_counter, len_iface_result) = lower_emit_interface_dispatch(records, call_argument_counter, call_arg_values[0], 0, "i32")
                    return (len_iface_counter, VALUE_TYPE_INT, len_iface_result)
                if call_arg_types[0] == DIR_TYPE_POINTER:
                    call_symbol = "string_length"
                if call_arg_types[0] == DIR_TYPE_DICT:
                    call_symbol = "dream_dict_size_int_int"
            call_return_type = VALUE_TYPE_INT
        if call_name == "append" or call_name == "get" or call_name == "print":
            call_return_type = VALUE_TYPE_IMMEDIATE
        if call_name == "append" and len(call_arg_types) >= 2:
            if call_arg_types[1] == DIR_TYPE_POINTER:
                call_symbol = "append_pointer"
            elif call_arg_types[1] == DIR_TYPE_F64:
                call_symbol = "append_f64"
            elif call_arg_types[1] == DIR_TYPE_BOOL:
                let append_bool_tmp = call_argument_counter + 1
                dir_append_native_zext(records, append_bool_tmp, call_arg_kinds[1], call_arg_values[1])
                call_arg_kinds[1] = DIR_NATIVE_OPERAND_TEMPORARY
                call_arg_values[1] = append_bool_tmp
                call_arg_types[1] = DIR_TYPE_I32
                call_argument_counter = append_bool_tmp
                call_symbol = "append_i32"
            else:
                call_symbol = "append_i32"
    let call_is_value = call_return_type != VALUE_TYPE_IMMEDIATE
    let call_result = call_argument_counter + 1
    let call_no_names: list[str] = []
    let call_dir_return_type = DIR_TYPE_UNKNOWN
    if call_is_value:
        call_dir_return_type = lower_dir_type(call_return_type)
    dir_append_native_call_direct(records, call_dir_return_type, DIR_NATIVE_OPERAND_TEMPORARY, call_result, call_symbol, call_arg_kinds, call_arg_values, call_arg_types, len(call_arg_kinds), call_is_value, call_no_names)
    if call_is_value:
        return (call_result, call_return_type, call_result)
    return (call_result, VALUE_TYPE_IMMEDIATE, 0)

def lower_expr(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int, int):
    if node <= 0 or node >= len(ast):
        __c_eprint_text("lower_expr: bad node=")
        __c_eprint_int(node)
        __c_eprint_text(" pool=")
        __c_eprint_int(len(ast))
        __c_eprint_text(" counter=")
        __c_eprint_int(counter)
        __c_eprint_text("\n")
        return (counter, VALUE_TYPE_INT, 0)
    let kind = ast_node_kind(ast, node)
    if kind == 0:
        __c_eprint_text("lower_expr: kind=0 at node=")
        __c_eprint_int(node)
        __c_eprint_text("\n")
        return (counter, VALUE_TYPE_INT, 0)
    switch kind:
        case AST_EXPR_INT:
            return lower_expr_int(ast, node, counter)
        case AST_EXPR_BOOL:
            return lower_expr_bool(ast, node, counter, records)
        case AST_EXPR_VAR:
            return lower_expr_var(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_BINARY:
            return lower_expr_binary(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_UNARY:
            return lower_expr_unary(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_LOGICAL:
            return lower_expr_logical(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_COND:
            return lower_expr_cond(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_CALL:
            return lower_expr_call(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_LIST:
            return lower_expr_list(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_STRING:
            return lower_expr_string(context, ast, node, counter, records)
        case AST_EXPR_FLOAT:
            return lower_expr_float(context, ast, node, counter, records)
        case AST_EXPR_RUNE:
            return lower_expr_rune(ast, node, counter)
        case AST_EXPR_INDEX:
            return lower_expr_index(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_SLICE:
            return lower_expr_slice(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_DICT:
            return lower_expr_dict(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_TUPLE:
            return lower_expr_tuple(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_STRUCT:
            return lower_expr_struct(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_ATTR:
            return lower_expr_attr(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_LIST_COMP:
            return lower_expr_list_comp(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_BUILTIN_ENUM:
            let be_tag = ast_node_arg(ast, node, 0)
            let be_result = counter + 1
            let be_create_kinds = []
            let be_create_values = []
            let be_create_types = []
            append(be_create_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(be_create_values, 4)
            append(be_create_types, DIR_TYPE_I32)
            let be_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, be_result, "create_dynarray_i32", be_create_kinds, be_create_values, be_create_types, 1, true, be_no_names)
            let be_tag_kinds = []
            let be_tag_values = []
            let be_tag_types = []
            append(be_tag_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
            append(be_tag_values, be_result)
            append(be_tag_types, DIR_TYPE_LIST)
            append(be_tag_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(be_tag_values, be_tag)
            append(be_tag_types, DIR_TYPE_I32)
            dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "append_i32", be_tag_kinds, be_tag_values, be_tag_types, 2, false, be_no_names)
            return (be_result, VALUE_TYPE_LIST, be_result)
        case AST_EXPR_METHOD_CALL:
            return lower_expr_method_call(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_MATCH:
            return lower_expr_match(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_EXPR_LAMBDA:
            return lower_expr_lambda(context, ast, node, counter)
        default:
            return (counter, VALUE_TYPE_INT, 0)

def lower_stmt_let(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let let_name_start = ast_node_arg(ast, node, 0)
    let let_name_end = ast_node_arg(ast, node, 1)
    let let_value_node = ast_node_arg(ast, node, 4)
    let let_annotation_start = ast_node_arg(ast, node, 2)
    let let_annotation_end = ast_node_arg(ast, node, 3)
    let let_question = ast_node_arg(ast, node, 5)
    let (let_next, let_value_type, let_value_value) = lower_expr(context, ast, let_value_node, variable_starts, variable_ends, variable_types, counter, records)
    if let_question != 0:
        # question 解包:tag 非 0 则返回 enum,否则绑定 payload(int)
        let q_tag = let_next + 1
        let q_get_kinds = []
        let q_get_values = []
        let q_get_types = []
        append(q_get_kinds, lower_operand_kind(let_value_type))
        append(q_get_values, let_value_value)
        append(q_get_types, lower_dir_type(let_value_type))
        append(q_get_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
        append(q_get_values, 0)
        append(q_get_types, DIR_TYPE_I32)
        let q_no_names: list[str] = []
        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, q_tag, "get", q_get_kinds, q_get_values, q_get_types, 2, true, q_no_names)
        let q_cond = q_tag + 1
        dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, q_cond, DIR_NATIVE_OPERAND_TEMPORARY, q_tag, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        let q_ok_label = q_cond + 1
        let q_error_label = q_cond + 2
        let q_index = len(variable_starts)
        let q_slot = lower_variable_slot_name_indexed(source, let_name_start, let_name_end, VALUE_TYPE_INT, q_index)
        dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, q_slot)
        dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, q_cond, q_ok_label, q_error_label)
        lower_append_label_number(records, q_error_label)
        dir_append_native_ret(records, lower_dir_type(let_value_type), lower_operand_kind(let_value_type), let_value_value)
        lower_append_label_number(records, q_ok_label)
        let q_value = q_cond + 3
        let q_value_kinds = []
        let q_value_values = []
        let q_value_types = []
        append(q_value_kinds, lower_operand_kind(let_value_type))
        append(q_value_values, let_value_value)
        append(q_value_types, lower_dir_type(let_value_type))
        append(q_value_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
        append(q_value_values, 1)
        append(q_value_types, DIR_TYPE_I32)
        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, q_value, "get", q_value_kinds, q_value_values, q_value_types, 2, true, q_no_names)
        dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, q_value, "", DIR_NATIVE_OPERAND_NAMED, 0, q_slot)
        append(variable_starts, let_name_start)
        append(variable_ends, let_name_end)
        append(variable_types, VALUE_TYPE_INT)
        return (q_value, 0)
    let let_type_final = let_value_type
    if is_function_value_type(let_type_final):
        append(variable_starts, let_name_start)
        append(variable_ends, let_name_end)
        append(variable_types, let_type_final)
        return (let_next, 0)
    if let_annotation_start != 0:
        let annotated_type = lower_parse_annotation(source, kinds, starts, ends, let_annotation_start, let_annotation_end)
        if annotated_type != 0:
            let_type_final = annotated_type
    if let_type_final == VALUE_TYPE_IMMEDIATE:
        let_type_final = VALUE_TYPE_INT
    let let_existing_index = lower_find_variable(source, let_name_start, let_name_end, variable_starts, variable_ends)
    let let_is_existing_global = let_existing_index >= 0 and is_global_let_value_type(variable_types[let_existing_index])
    let let_index = len(variable_starts)
    if let_existing_index >= 0 and not let_is_existing_global:
        let_index = let_existing_index
    let let_slot = lower_variable_slot_name_indexed(source, let_name_start, let_name_end, let_type_final, let_index)
    let let_need_alloca = let_existing_index < 0 or let_is_existing_global
    if let_need_alloca:
        dir_append_native_alloca(records, lower_dir_type(let_type_final), DIR_NATIVE_OPERAND_NAMED, 0, let_slot)
    dir_append_native_store(records, lower_dir_type(let_type_final), lower_operand_kind(let_value_type), let_value_value, "", DIR_NATIVE_OPERAND_NAMED, 0, let_slot)
    if let_existing_index < 0 or (let_existing_index >= 0 and is_global_let_value_type(variable_types[let_existing_index])):
        append(variable_starts, let_name_start)
        append(variable_ends, let_name_end)
        append(variable_types, let_type_final)
    return (let_next, 0)

def lower_stmt_return(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], expected_return_type: int) -> (int, int):
    let ret_value_node = ast_node_arg(ast, node, 0)
    if ret_value_node == 0:
        if expected_return_type == VALUE_TYPE_UNKNOWN or expected_return_type == 0:
            dir_append_native_ret(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0)
        else:
            let ret_dir_type = lower_dir_type(expected_return_type)
            dir_append_native_ret(records, ret_dir_type, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        return (counter, 1)
    let (ret_next, ret_type, ret_value) = lower_expr(context, ast, ret_value_node, variable_starts, variable_ends, variable_types, counter, records)
    let ret_dir_type = lower_dir_type(expected_return_type)
    dir_append_native_ret(records, ret_dir_type, lower_operand_kind(ret_type), ret_value)
    return (ret_next, 1)

def lower_stmt_expr(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], break_label: int) -> (int, int):
    let expr_expression_node = ast_node_arg(ast, node, 0)
    if ast_node_kind(ast, expr_expression_node) == AST_EXPR_MATCH and ast_node_arg(ast, expr_expression_node, 3) != 0:
        return lower_stmt_match(context, ast, expr_expression_node, variable_starts, variable_ends, variable_types, counter, records, buffer, break_label)
    if ast_node_kind(ast, expr_expression_node) == AST_EXPR_PRINT:
        let expr_print_value = ast_node_arg(ast, expr_expression_node, 0)
        let expr_print_stderr = ast_node_arg(ast, expr_expression_node, 1)
        let print_fn_prefix = "dream_print"
        if expr_print_stderr != 0:
            print_fn_prefix = "dream_eprint"
        let (expr_next, expr_value_type, expr_value_value) = lower_expr(context, ast, expr_print_value, variable_starts, variable_ends, variable_types, counter, records)
        if expr_value_type == VALUE_TYPE_INTERFACE:
            let (print_iface_counter, print_to_string_result) = lower_emit_interface_dispatch(records, expr_next, expr_value_value, 0, "i8*")
            let print_str_kinds = []
            let print_str_values = []
            let print_str_types = []
            append(print_str_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
            append(print_str_values, print_to_string_result)
            append(print_str_types, DIR_TYPE_POINTER)
            let print_str_no_names: list[str] = []
            let print_str_fn = string_concat(print_fn_prefix, "_string")
            dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, print_str_fn, print_str_kinds, print_str_values, print_str_types, 1, false, print_str_no_names)
            return (print_iface_counter, 0)
        let expr_symbol = string_concat(print_fn_prefix, "_int")
        if expr_value_type == VALUE_TYPE_STRING:
            expr_symbol = string_concat(print_fn_prefix, "_string")
        if expr_value_type == VALUE_TYPE_FLOAT:
            expr_symbol = string_concat(print_fn_prefix, "_float")
        if expr_value_type == VALUE_TYPE_BOOL:
            expr_symbol = string_concat(print_fn_prefix, "_bool")
        let expr_arg_kinds = []
        let expr_arg_values = []
        let expr_arg_types = []
        append(expr_arg_kinds, lower_operand_kind(expr_value_type))
        append(expr_arg_values, expr_value_value)
        append(expr_arg_types, lower_dir_type(expr_value_type))
        let expr_no_names: list[str] = []
        dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, expr_symbol, expr_arg_kinds, expr_arg_values, expr_arg_types, 1, false, expr_no_names)
        return (expr_next, 0)
    let (expr_stmt_next, expr_stmt_type, expr_stmt_value) = lower_expr(context, ast, expr_expression_node, variable_starts, variable_ends, variable_types, counter, records)
    return (expr_stmt_next, 0)

def lower_switch_comparison(sw_type: int, sw_value: int, case_type: int, case_value: int, counter: int, records: list[int]) -> int:
    if sw_type == VALUE_TYPE_STRING and case_type == VALUE_TYPE_STRING:
        let str_cmp_temp = counter + 1
        let str_cmp_arg_kinds = []
        let str_cmp_arg_values = []
        let str_cmp_arg_types = []
        append(str_cmp_arg_kinds, lower_operand_kind(sw_type))
        append(str_cmp_arg_values, sw_value)
        append(str_cmp_arg_types, DIR_TYPE_POINTER)
        append(str_cmp_arg_kinds, lower_operand_kind(case_type))
        append(str_cmp_arg_values, case_value)
        append(str_cmp_arg_types, DIR_TYPE_POINTER)
        let str_cmp_no_names: list[str] = []
        dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, str_cmp_temp, "string_compare", str_cmp_arg_kinds, str_cmp_arg_values, str_cmp_arg_types, 2, true, str_cmp_no_names)
        let str_cond = str_cmp_temp + 1
        dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, str_cond, DIR_NATIVE_OPERAND_TEMPORARY, str_cmp_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        return str_cond
    if sw_type == VALUE_TYPE_FLOAT and case_type == VALUE_TYPE_FLOAT:
        let float_cond = counter + 1
        dir_append_native_compare(records, DIR_TYPE_F64, DIR_PREDICATE_FEQ, float_cond, lower_operand_kind(sw_type), sw_value, lower_operand_kind(case_type), case_value)
        return float_cond
    if sw_type == VALUE_TYPE_BOOL and case_type == VALUE_TYPE_BOOL:
        let bool_cond = counter + 1
        dir_append_native_compare(records, DIR_TYPE_BOOL, DIR_PREDICATE_EQ, bool_cond, lower_operand_kind(sw_type), sw_value, lower_operand_kind(case_type), case_value)
        return bool_cond
    let int_cond = counter + 1
    dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_EQ, int_cond, lower_operand_kind(sw_type), sw_value, lower_operand_kind(case_type), case_value)
    return int_cond

def lower_stmt_switch(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let sw_header_node = ast_node_arg(ast, node, 0)
    let sw_cases_start = ast_node_arg(ast, node, 1)
    let sw_cases_end = ast_node_arg(ast, node, 2)
    let sw_default_node = ast_node_arg(ast, node, 3)
    let sw_default_end = ast_node_arg(ast, node, 4)
    let (sw_counter, sw_type, sw_value) = lower_expr(context, ast, sw_header_node, variable_starts, variable_ends, variable_types, counter, records)
    let sw_end_label = sw_counter + 1000
    let current_counter = sw_counter
    let case_node = sw_cases_start
    while case_node < sw_cases_end:
        let case_value_node = ast_node_arg(ast, case_node, 0)
        let case_block_node = ast_node_arg(ast, case_node, 1)
        let case_block_end = ast_node_arg(ast, case_node, 2)
        let (case_next, case_type, case_value) = lower_expr(context, ast, case_value_node, variable_starts, variable_ends, variable_types, current_counter, records)
        let case_condition = lower_switch_comparison(sw_type, sw_value, case_type, case_value, case_next, records)
        let case_body_label = case_condition + 1
        let case_check_label = case_condition + 2
        dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, case_condition, case_body_label, case_check_label)
        lower_append_label_number(records, case_body_label)
        let (body_next, body_has_return) = lower_stmt_block(context, ast, case_block_node, case_block_end, variable_starts, variable_ends, variable_types, case_condition + 2, records, buffer, expected_return_type, break_label)
        if body_has_return == 0:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, sw_end_label, 0)
        lower_append_label_number(records, case_check_label)
        current_counter = body_next
        case_node = case_block_end
    if sw_default_node != 0:
        let (default_next, default_has_return) = lower_stmt_block(context, ast, sw_default_node, sw_default_end, variable_starts, variable_ends, variable_types, current_counter, records, buffer, expected_return_type, break_label)
        if default_has_return == 0:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, sw_end_label, 0)
        current_counter = default_next
    else:
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, sw_end_label, 0)
    lower_append_label_number(records, sw_end_label)
    return (current_counter, 0)

def lower_stmt_if(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let if_condition_node = ast_node_arg(ast, node, 0)
    let if_then_block = ast_node_arg(ast, node, 1)
    let if_then_end = ast_node_arg(ast, node, 2)
    let if_elifs_start = ast_node_arg(ast, node, 3)
    let if_elifs_end = ast_node_arg(ast, node, 4)
    let if_else_block = ast_node_arg(ast, node, 5)
    let if_else_block_end = ast_node_arg(ast, node, 6)
    let (if_cond_next, if_cond_type, if_cond_value) = lower_expr(context, ast, if_condition_node, variable_starts, variable_ends, variable_types, counter, records)
    let if_condition = lower_branch_condition(if_cond_type, if_cond_value, if_cond_next, records)
    let if_then_label = if_condition + 1
    let if_check_label = if_condition + 2
    let if_end_label = if_condition + 3
    dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, if_condition, if_then_label, if_check_label)
    lower_append_label_number(records, if_then_label)
    let (if_then_next, if_then_has) = lower_stmt_block(context, ast, if_then_block, if_then_end, variable_starts, variable_ends, variable_types, if_condition + 3, records, buffer, expected_return_type, break_label)
    if if_then_has == 0:
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, if_end_label, 0)
    lower_append_label_number(records, if_check_label)
    let if_branch_counter = if_then_next
    let if_elif_node = if_elifs_start
    while if_elif_node < if_elifs_end:
        let if_elif_cond_node = ast_node_arg(ast, if_elif_node, 0)
        let if_elif_block = ast_node_arg(ast, if_elif_node, 1)
        let if_elif_block_end = ast_node_arg(ast, if_elif_node, 2)
        let (if_elif_cond_next, if_elif_cond_type, if_elif_cond_value) = lower_expr(context, ast, if_elif_cond_node, variable_starts, variable_ends, variable_types, if_branch_counter, records)
        let if_elif_condition = lower_branch_condition(if_elif_cond_type, if_elif_cond_value, if_elif_cond_next, records)
        let if_elif_then_label = if_elif_condition + 1
        let if_elif_check_label = if_elif_condition + 2
        dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, if_elif_condition, if_elif_then_label, if_elif_check_label)
        lower_append_label_number(records, if_elif_then_label)
        let (if_elif_next, if_elif_has) = lower_stmt_block(context, ast, if_elif_block, if_elif_block_end, variable_starts, variable_ends, variable_types, if_elif_condition + 2, records, buffer, expected_return_type, break_label)
        if if_elif_has == 0:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, if_end_label, 0)
        lower_append_label_number(records, if_elif_check_label)
        if_branch_counter = if_elif_next
        if_elif_node = if_elif_block_end
    let if_has_else = if_else_block != 0
    if if_has_else:
        let if_else_label = if_branch_counter + 1
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, if_else_label, 0)
        lower_append_label_number(records, if_else_label)
        let (if_else_next, if_else_has) = lower_stmt_block(context, ast, if_else_block, if_else_block_end, variable_starts, variable_ends, variable_types, if_else_label, records, buffer, expected_return_type, break_label)
        if if_else_has == 0:
            dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, if_end_label, 0)
        if_branch_counter = if_else_next
    if not if_has_else:
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, if_end_label, 0)
    lower_append_label_number(records, if_end_label)
    return (if_branch_counter, 0)

def lower_stmt_while(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let wh_condition_node = ast_node_arg(ast, node, 0)
    let wh_block_node = ast_node_arg(ast, node, 1)
    let wh_block_end = ast_node_arg(ast, node, 2)
    let wh_label_base = counter + 1
    let wh_check = wh_label_base
    let wh_body = wh_label_base + 1
    let wh_end = wh_label_base + 2
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, wh_check, 0)
    lower_append_label_number(records, wh_check)
    let (wh_cond_next, wh_cond_type, wh_cond_value) = lower_expr(context, ast, wh_condition_node, variable_starts, variable_ends, variable_types, counter, records)
    let wh_condition = lower_branch_condition(wh_cond_type, wh_cond_value, wh_cond_next, records)
    let wh_body_counter = wh_cond_next + 1
    dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, wh_condition, wh_body, wh_end)
    lower_append_label_number(records, wh_body)
    let (wh_body_next, wh_body_has) = lower_stmt_block(context, ast, wh_block_node, wh_block_end, variable_starts, variable_ends, variable_types, wh_body_counter, records, buffer, expected_return_type, wh_end)
    if wh_body_has == 0:
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, wh_check, 0)
    lower_append_label_number(records, wh_end)
    return (wh_body_next, 0)

def lower_stmt_for(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let source = context.src
    let for_loop_name_start = ast_node_arg(ast, node, 0)
    let for_loop_name_end = ast_node_arg(ast, node, 1)
    let for_source_node = ast_node_arg(ast, node, 2)
    let for_block_node = ast_node_arg(ast, node, 3)
    let for_block_end = ast_node_arg(ast, node, 4)
    let (for_source_next, for_source_type, for_source_value) = lower_expr(context, ast, for_source_node, variable_starts, variable_ends, variable_types, counter, records)
    let for_label_base = for_source_next + 1
    let for_check = for_label_base
    let for_body = for_label_base + 1
    let for_end = for_label_base + 2
    let for_index_id = len(variable_starts)
    let for_index_slot = lower_variable_slot_name_indexed(source, for_loop_name_start, for_loop_name_end, VALUE_TYPE_INT, for_index_id)
    dir_append_native_alloca(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_NAMED, 0, for_index_slot)
    dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_IMMEDIATE, 0, "", DIR_NATIVE_OPERAND_NAMED, 0, for_index_slot)
    append(variable_starts, for_loop_name_start)
    append(variable_ends, for_loop_name_end)
    append(variable_types, VALUE_TYPE_INT)
    let for_length = for_label_base + 1
    let for_arg_kinds = []
    let for_arg_values = []
    let for_arg_types = []
    append(for_arg_kinds, lower_operand_kind(for_source_type))
    append(for_arg_values, for_source_value)
    append(for_arg_types, lower_dir_type(for_source_type))
    let for_len_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, for_length, "len", for_arg_kinds, for_arg_values, for_arg_types, 1, true, for_len_no_names)
    dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, for_check, 0)
    lower_append_label_number(records, for_check)
    let for_index_temp = for_length + 1
    dir_append_native_load(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, for_index_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, for_index_slot)
    let for_cond_temp = for_index_temp + 1
    dir_append_native_compare(records, DIR_TYPE_I32, DIR_PREDICATE_SLT, for_cond_temp, DIR_NATIVE_OPERAND_TEMPORARY, for_index_temp, DIR_NATIVE_OPERAND_TEMPORARY, for_length)
    dir_append_native_br(records, 3, DIR_NATIVE_OPERAND_TEMPORARY, for_cond_temp, for_body, for_end)
    lower_append_label_number(records, for_body)
    let for_get_arg_kinds = []
    let for_get_arg_values = []
    let for_get_arg_types = []
    append(for_get_arg_kinds, lower_operand_kind(for_source_type))
    append(for_get_arg_values, for_source_value)
    append(for_get_arg_types, lower_dir_type(for_source_type))
    append(for_get_arg_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
    append(for_get_arg_values, for_index_temp)
    append(for_get_arg_types, DIR_TYPE_I32)
    let for_element_temp = for_cond_temp + 1
    let for_get_no_names: list[str] = []
    dir_append_native_call_direct(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, for_element_temp, "get", for_get_arg_kinds, for_get_arg_values, for_get_arg_types, 2, true, for_get_no_names)
    dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, for_element_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, for_index_slot)
    let (for_body_next, for_body_has) = lower_stmt_block(context, ast, for_block_node, for_block_end, variable_starts, variable_ends, variable_types, for_element_temp, records, buffer, expected_return_type, for_end)
    let for_return_counter = for_body_next
    if for_body_has == 0:
        let for_inc_temp = for_body_next + 1
        let for_added_temp = for_inc_temp + 1
        dir_append_native_operation(records, DIR_OPCODE_ADD, DIR_TYPE_I32, for_added_temp, DIR_NATIVE_OPERAND_TEMPORARY, for_index_temp, DIR_NATIVE_OPERAND_IMMEDIATE, 1)
        dir_append_native_store(records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_TEMPORARY, for_added_temp, "", DIR_NATIVE_OPERAND_NAMED, 0, for_index_slot)
        dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, for_check, 0)
        for_return_counter = for_added_temp
    lower_append_label_number(records, for_end)
    return (for_return_counter, 0)

def lower_stmt_assign(context: ParseContext, ast: list[int], node: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int]) -> (int, int):
    let source = context.src
    let as_name_start = ast_node_arg(ast, node, 0)
    let as_name_end = ast_node_arg(ast, node, 1)
    let as_form = ast_node_arg(ast, node, 2)
    let as_key_node = ast_node_arg(ast, node, 3)
    let as_value_node = ast_node_arg(ast, node, 4)
    let as_variable_index = lower_find_variable(source, as_name_start, as_name_end, variable_starts, variable_ends)
    let as_variable_type = VALUE_TYPE_LIST
    if as_variable_index >= 0:
        as_variable_type = variable_types[as_variable_index]
    let (as_next, as_type, as_value) = lower_expr(context, ast, as_value_node, variable_starts, variable_ends, variable_types, counter, records)
    if as_form != 0:
        if is_dictionary_value_type(as_variable_type):
            let as_dict_temporary = as_next + 1
            if is_global_let_value_type(as_variable_type):
                let as_dict_base = global_let_base_type(as_variable_type)
                let as_dict_sym = [1]
                append_text(as_dict_sym, source[as_name_start:as_name_end])
                dir_append_native_load_global(records, lower_dir_type(as_dict_base), DIR_NATIVE_OPERAND_TEMPORARY, as_dict_temporary, as_dict_sym, as_dict_sym[0])
            else:
                let as_dict_slot = lower_variable_slot_name_indexed(source, as_name_start, as_name_end, as_variable_type, as_variable_index)
                dir_append_native_load(records, DIR_TYPE_DICT, DIR_NATIVE_OPERAND_TEMPORARY, as_dict_temporary, "", DIR_NATIVE_OPERAND_NAMED, 0, as_dict_slot)
            let (as_dict_key_next, as_dict_key_type, as_dict_key_value) = lower_expr(context, ast, as_key_node, variable_starts, variable_ends, variable_types, as_dict_temporary, records)
            let as_dict_symbol = "dict_set_int_int"
            if as_variable_type == VALUE_TYPE_DICT_INT_STRING:
                as_dict_symbol = "dict_set_int_str"
            if as_variable_type == VALUE_TYPE_DICT_STRING_INT:
                as_dict_symbol = "dict_set_str_int"
            if as_variable_type == VALUE_TYPE_DICT_STRING_STRING:
                as_dict_symbol = "dict_set_str_str"
            let as_dict_kinds = []
            let as_dict_values = []
            let as_dict_types = []
            append(as_dict_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
            append(as_dict_values, as_dict_temporary)
            append(as_dict_types, DIR_TYPE_DICT)
            append(as_dict_kinds, lower_operand_kind(as_dict_key_type))
            append(as_dict_values, as_dict_key_value)
            append(as_dict_types, DIR_TYPE_I32)
            append(as_dict_kinds, lower_operand_kind(as_type))
            append(as_dict_values, as_value)
            append(as_dict_types, DIR_TYPE_I32)
            let as_dict_no_names: list[str] = []
            dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, as_dict_symbol, as_dict_kinds, as_dict_values, as_dict_types, 3, false, as_dict_no_names)
            return (as_dict_key_next, 0)
        # 元素赋值 name[key] = value → set_dynarray_i32(name, key, value)
        let as_list_temporary = as_next + 1
        if is_global_let_value_type(as_variable_type):
            let as_list_base = global_let_base_type(as_variable_type)
            let as_list_sym = [1]
            append_text(as_list_sym, source[as_name_start:as_name_end])
            dir_append_native_load_global(records, lower_dir_type(as_list_base), DIR_NATIVE_OPERAND_TEMPORARY, as_list_temporary, as_list_sym, as_list_sym[0])
        else:
            let as_list_slot = lower_variable_slot_name_indexed(source, as_name_start, as_name_end, VALUE_TYPE_LIST, as_variable_index)
            dir_append_native_load(records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, as_list_temporary, "", DIR_NATIVE_OPERAND_NAMED, 0, as_list_slot)
        let (as_key_next, as_key_type, as_key_value) = lower_expr(context, ast, as_key_node, variable_starts, variable_ends, variable_types, as_list_temporary, records)
        let as_set_kinds = []
        let as_set_values = []
        let as_set_types = []
        append(as_set_kinds, DIR_NATIVE_OPERAND_TEMPORARY)
        append(as_set_values, as_list_temporary)
        append(as_set_types, DIR_TYPE_LIST)
        append(as_set_kinds, lower_operand_kind(as_key_type))
        append(as_set_values, as_key_value)
        append(as_set_types, DIR_TYPE_I32)
        append(as_set_kinds, lower_operand_kind(as_type))
        append(as_set_values, as_value)
        append(as_set_types, DIR_TYPE_I32)
        let as_no_names: list[str] = []
        dir_append_native_call_direct(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "set_dynarray_i32", as_set_kinds, as_set_values, as_set_types, 3, false, as_no_names)
        return (as_key_next, 0)
    if as_variable_index >= 0:
        let as_variable_type = variable_types[as_variable_index]
        if is_global_let_value_type(as_variable_type):
            let as_global_buffer = [1]
            append_text(as_global_buffer, source[as_name_start:as_name_end])
            let as_global_marker = as_global_buffer[0]
            let as_global_base_type = global_let_base_type(as_variable_type)
            dir_append_native_store_symbol(records, lower_dir_type(as_global_base_type), lower_operand_kind(as_type), as_value, "", as_global_buffer, as_global_marker)
        else:
            let as_slot = lower_variable_slot_name_indexed(source, as_name_start, as_name_end, as_variable_type, as_variable_index)
            dir_append_native_store(records, lower_dir_type(as_variable_type), lower_operand_kind(as_type), as_value, "", DIR_NATIVE_OPERAND_NAMED, 0, as_slot)
    return (as_next, 0)

def lower_stmt(context: ParseContext, ast: list[int], node: int, body_end: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let kind = ast_node_kind(ast, node)
    switch kind:
        case AST_STMT_LET:
            return lower_stmt_let(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer)
        case AST_STMT_LET_TUPLE:
            return lower_stmt_let_tuple(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_STMT_RETURN:
            return lower_stmt_return(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, expected_return_type)
        case AST_STMT_EXPR:
            return lower_stmt_expr(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer, break_label)
        case AST_STMT_IF:
            return lower_stmt_if(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer, expected_return_type, break_label)
        case AST_STMT_WHILE:
            return lower_stmt_while(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer, expected_return_type, break_label)
        case AST_STMT_FOR:
            return lower_stmt_for(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer, expected_return_type, break_label)
        case AST_STMT_ASSIGN:
            return lower_stmt_assign(context, ast, node, variable_starts, variable_ends, variable_types, counter, records)
        case AST_STMT_SWITCH:
            return lower_stmt_switch(context, ast, node, variable_starts, variable_ends, variable_types, counter, records, buffer, expected_return_type, break_label)
        case AST_STMT_BREAK:
            if break_label >= 0:
                dir_append_native_br(records, 1, DIR_TAG_INVALID, 0, break_label, 0)
            return (counter, 0)
        default:
            return (counter, 0)

def lower_stmt_block(context: ParseContext, ast: list[int], block_start: int, block_end: int, variable_starts: list[int], variable_ends: list[int], variable_types: list[int], counter: int, records: list[int], buffer: list[int], expected_return_type: int, break_label: int) -> (int, int):
    let node = block_start
    let current_counter = counter
    let has_return = 0
    while node < block_end:
        if node >= len(ast):
            __c_eprint_text("lower_stmt_block: node=")
            __c_eprint_int(node)
            __c_eprint_text(" >= pool=")
            __c_eprint_int(len(ast))
            __c_eprint_text(" block_start=")
            __c_eprint_int(block_start)
            __c_eprint_text(" block_end=")
            __c_eprint_int(block_end)
            __c_eprint_text("\n")
            return (current_counter, has_return)
        let node_kind = ast_node_kind(ast, node)
        let node_size = ast_node_size(node_kind)
        if node_size == 0:
            __c_eprint_text("lower_stmt_block: bad kind=")
            __c_eprint_int(node_kind)
            __c_eprint_text(" at node=")
            __c_eprint_int(node)
            __c_eprint_text("\n")
            return (current_counter, has_return)
        let (next_counter, statement_has_return) = lower_stmt(context, ast, node, block_end, variable_starts, variable_ends, variable_types, current_counter, records, buffer, expected_return_type, break_label)
        current_counter = next_counter
        if statement_has_return != 0:
            has_return = 1
        node = ast_stmt_next_node(ast, node)
    return (current_counter, has_return)

def lower_function(context: ParseContext, ast: list[int], function_index: int, fn_ast_starts: list[int], fn_ast_ends: list[int], records: list[int], buffer: list[int], global_let_name_starts: list[int], global_let_name_ends: list[int], global_let_types: list[int], global_let_nodes: list[int], function_bodies: list[int], function_body_ends: list[int], parameter_types: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]) -> (int, int):
    let ends = context.ends
    let kinds = context.kinds
    let starts = context.starts
    let source = context.src
    let function_records = []
    let function_buffer = [1]
    let function_starts = context.fn_starts
    let function_ends = context.fn_ends
    let function_param_offsets = context.param_offsets
    let function_param_counts = context.param_counts
    let parameter_starts = context.param_starts
    let parameter_ends = context.param_ends
    let function_return_types = context.ret_types
    let return_type_value = function_return_types[function_index]
    let has_body = function_bodies[function_index] < function_body_ends[function_index]
    if not has_body:
        return (0, 0)
    let function_output = [1]
    let body_start = fn_ast_starts[function_index]
    let body_end = fn_ast_ends[function_index]
    # 头部注释
    let comment_buffer = [1]
    append_text(comment_buffer, "; function_index=")
    append_integer(comment_buffer, function_index)
    append_text(comment_buffer, "; body_start=")
    append_integer(comment_buffer, function_bodies[function_index])
    append_text(comment_buffer, "; body_end=")
    append_integer(comment_buffer, function_body_ends[function_index])
    append_text(comment_buffer, "\n")
    let comment_buffer_marker = comment_buffer[0]
    dir_append_record(function_records, DIR_TAG_COMMENT, DIR_TAG_INVALID, 0, 0, 0, comment_buffer, comment_buffer_marker, len(comment_buffer))
    let function_name_start = function_starts[function_index]
    let function_name_end = function_ends[function_index]
    let is_process_entry = false
    if source_equals(source, function_name_start, function_name_end, "main") and function_param_counts[function_index] == 0:
        is_process_entry = true
    let header_buffer = [1]
    if is_closure_value_type(return_type_value):
        append_text(header_buffer, "define %dir_closure* @")
    else:
        switch return_type_value:
            case VALUE_TYPE_LIST:
                append_text(header_buffer, "define %dynarray_i32* @")
            case VALUE_TYPE_LIST_STRING:
                append_text(header_buffer, "define %dynarray_i32* @")
            case VALUE_TYPE_BYTES:
                append_text(header_buffer, "define %dynarray_i32* @")
            case VALUE_TYPE_STRING:
                append_text(header_buffer, "define i8* @")
            case VALUE_TYPE_BOOL:
                append_text(header_buffer, "define i1 @")
            case VALUE_TYPE_FLOAT:
                append_text(header_buffer, "define double @")
            case VALUE_TYPE_INTERFACE:
                append_text(header_buffer, "define %dir_interface* @")
            default:
                append_text(header_buffer, "define i32 @")
    let emitted_function_name = function_symbol_name(source, context.kinds, context.starts, context.ends, function_starts[function_index], function_ends[function_index])
    append_text(header_buffer, emitted_function_name)
    append_text(header_buffer, "(")
    let parameter_index = 0
    let parameter_offset = function_param_offsets[function_index]
    let parameter_count = function_param_counts[function_index]
    while parameter_index < parameter_count:
        if parameter_index > 0:
            append_text(header_buffer, ", ")
        let parameter_position = parameter_offset + parameter_index
        let parameter_type = parameter_types[parameter_position]
        if is_closure_value_type(parameter_type):
            append_text(header_buffer, "%dir_closure* %")
        elif parameter_type == VALUE_TYPE_FUNCTION_PARAMETER:
            append_text(header_buffer, "i32 (i32)* %")
        else:
            switch parameter_type:
                case VALUE_TYPE_STRING:
                    append_text(header_buffer, "i8* %")
                case VALUE_TYPE_LIST:
                    append_text(header_buffer, "%dynarray_i32* %")
                case VALUE_TYPE_LIST_STRING:
                    append_text(header_buffer, "%dynarray_i32* %")
                case VALUE_TYPE_BYTES:
                    append_text(header_buffer, "%dynarray_i32* %")
                case VALUE_TYPE_BOOL:
                    append_text(header_buffer, "i1 %")
                case VALUE_TYPE_FLOAT:
                    append_text(header_buffer, "double %")
                case VALUE_TYPE_INTERFACE:
                    append_text(header_buffer, "%dir_interface* %")
                case VALUE_TYPE_DICT_INT_INT:
                    append_text(header_buffer, "%dict_t* %")
                case VALUE_TYPE_DICT_INT_STRING:
                    append_text(header_buffer, "%dict_t* %")
                case VALUE_TYPE_DICT_STRING_INT:
                    append_text(header_buffer, "%dict_t* %")
                case VALUE_TYPE_DICT_STRING_STRING:
                    append_text(header_buffer, "%dict_t* %")
                default:
                    append_text(header_buffer, "i32 %")
        append_text(header_buffer, source[parameter_starts[parameter_position]:parameter_ends[parameter_position]])
        append_text(header_buffer, ".param")
        parameter_index = parameter_index + 1
    if is_process_entry:
        if parameter_count > 0:
            append_text(header_buffer, ", ")
        append_text(header_buffer, "i32 %dream_argc.param, i8** %dream_argv.param")
    append_text(header_buffer, ") {\nentry:\n")
    let header_buffer_marker = header_buffer[0]
    dir_append_record(function_records, DIR_TAG_FUNCTION, DIR_TAG_INVALID, 0, 0, 0, header_buffer, header_buffer_marker, len(header_buffer))
    let variable_starts = []
    let variable_ends = []
    let variable_types = []
    let global_let_index = 0
    while global_let_index < len(global_let_name_starts):
        append(variable_starts, global_let_name_starts[global_let_index])
        append(variable_ends, global_let_name_ends[global_let_index])
        append(variable_types, global_let_value_type(global_let_types[global_let_index]))
        global_let_index = global_let_index + 1
    let constant_index = 0
    while constant_index < len(constant_starts):
        let constant_name_start = constant_starts[constant_index]
        let constant_name_end = constant_ends[constant_index]
        if constant_is_used(source, context.kinds, context.starts, context.ends, function_bodies[function_index], function_body_ends[function_index], constant_name_start, constant_name_end):
            append(variable_starts, constant_name_start)
            append(variable_ends, constant_name_end)
            append(variable_types, VALUE_TYPE_GLOBAL)
        constant_index = constant_index + 1
    let initialize_index = 0
    while initialize_index < parameter_count:
        let parameter_init_position = parameter_offset + initialize_index
        let parameter_name_start = parameter_starts[parameter_init_position]
        let parameter_name_end = parameter_ends[parameter_init_position]
        let parameter_init_type = parameter_types[parameter_init_position]
        let parameter_name = source[parameter_name_start:parameter_name_end]
        if parameter_init_type != VALUE_TYPE_FUNCTION_PARAMETER:
            let parameter_index = len(variable_starts)
            let parameter_slot = lower_variable_slot_name_indexed(source, parameter_name_start, parameter_name_end, parameter_init_type, parameter_index)
            let parameter_param_name = string_concat(parameter_name, ".param")
            dir_append_native_alloca(function_records, lower_dir_type(parameter_init_type), DIR_NATIVE_OPERAND_NAMED, 0, parameter_slot)
            dir_append_native_store(function_records, lower_dir_type(parameter_init_type), DIR_NATIVE_OPERAND_NAMED, 0, parameter_param_name, DIR_NATIVE_OPERAND_NAMED, 0, parameter_slot)
        append(variable_starts, parameter_name_start)
        append(variable_ends, parameter_name_end)
        append(variable_types, parameter_init_type)
        initialize_index = initialize_index + 1
    let entry_counter = parameter_count
    if is_process_entry:
        let set_args_arg_kinds = []
        let set_args_arg_values = []
        let set_args_arg_types = []
        append(set_args_arg_kinds, DIR_NATIVE_OPERAND_NAMED)
        append(set_args_arg_values, 0)
        append(set_args_arg_types, DIR_TYPE_I32)
        append(set_args_arg_kinds, DIR_NATIVE_OPERAND_NAMED)
        append(set_args_arg_values, 0)
        append(set_args_arg_types, DIR_TYPE_POINTER_POINTER)
        dir_append_native_call_direct(function_records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0, "__c_process_set_args", set_args_arg_kinds, set_args_arg_values, set_args_arg_types, 2, false, ["dream_argc.param", "dream_argv.param"])
        entry_counter = entry_counter + 1
    if is_process_entry:
        let global_init_index = 0
        while global_init_index < len(global_let_name_starts):
            let global_init_name = source[global_let_name_starts[global_init_index]:global_let_name_ends[global_init_index]]
            let global_init_type = global_let_types[global_init_index]
            let global_init_buffer = [1]
            append_text(global_init_buffer, global_init_name)
            let global_init_marker = global_init_buffer[0]
            if global_init_index < len(global_let_nodes):
                let (init_expr_next, init_expr_type, init_expr_value) = lower_expr(context, ast, global_let_nodes[global_init_index], variable_starts, variable_ends, variable_types, entry_counter, function_records)
                dir_append_native_store_symbol(function_records, lower_dir_type(global_init_type), lower_operand_kind(init_expr_type), init_expr_value, "", global_init_buffer, global_init_marker)
                entry_counter = init_expr_next
            global_init_index = global_init_index + 1
    let (body_counter, has_return) = lower_stmt_block(context, ast, body_start, body_end, variable_starts, variable_ends, variable_types, entry_counter, function_records, function_buffer, return_type_value, -1)
    if has_return == 0:
        if return_type_value == VALUE_TYPE_LIST or return_type_value == VALUE_TYPE_BYTES:
            let result_temporary = body_counter + 1
            let create_arg_kinds = []
            let create_arg_values = []
            let create_arg_types = []
            append(create_arg_kinds, DIR_NATIVE_OPERAND_IMMEDIATE)
            append(create_arg_values, 4)
            append(create_arg_types, DIR_TYPE_I32)
            let create_no_names: list[str] = []
            dir_append_native_call_direct(function_records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, result_temporary, "create_dynarray_i32", create_arg_kinds, create_arg_values, create_arg_types, 1, true, create_no_names)
            dir_append_native_ret(function_records, DIR_TYPE_LIST, DIR_NATIVE_OPERAND_TEMPORARY, result_temporary)
        if return_type_value == VALUE_TYPE_FLOAT:
            dir_append_native_ret(function_records, DIR_TYPE_F64, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        if is_interface_value_type(return_type_value):
            dir_append_native_ret(function_records, DIR_TYPE_INTERFACE, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
        if return_type_value != VALUE_TYPE_LIST and return_type_value != VALUE_TYPE_BYTES:
            if return_type_value == VALUE_TYPE_BOOL:
                dir_append_native_ret(function_records, DIR_TYPE_BOOL, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
            if return_type_value == VALUE_TYPE_STRING:
                dir_append_native_ret(function_records, DIR_TYPE_POINTER, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
            if return_type_value != VALUE_TYPE_BOOL and return_type_value != VALUE_TYPE_STRING and return_type_value != VALUE_TYPE_FLOAT and not is_interface_value_type(return_type_value):
                dir_append_native_ret(function_records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_IMMEDIATE, 0)
    let function_end_buffer = [1]
    append_text(function_end_buffer, "}\n")
    let function_end_buffer_marker = function_end_buffer[0]
    dir_append_record(function_records, DIR_TAG_FUNCTION_END, DIR_TAG_INVALID, 0, 0, 0, function_end_buffer, function_end_buffer_marker, len(function_end_buffer))
    append_hoisted_function(records, function_records)
    return (body_counter, 0)

def lower_program(context: ParseContext, ast: list[int], fn_ast_starts: list[int], fn_ast_ends: list[int], global_let_nodes: list[int], records: list[int], global_let_name_starts: list[int], global_let_name_ends: list[int], global_let_types: list[int], function_bodies: list[int], function_body_ends: list[int], parameter_types: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]) -> bool:
    let buffer = [1]
    lower_append_module(records, buffer, "%dynarray_i32 = type { i32, i32, i32* }\n")
    lower_append_module(records, buffer, "%dynarray_ptr = type { i32, i32, i64* }\n")
    lower_append_module(records, buffer, "%dict_t = type opaque\n")
    lower_append_module(records, buffer, "%dir_closure = type { i8*, i8* }\n")
    lower_append_module(records, buffer, "%dir_interface = type { i8*, i8* }\n")
    lower_append_extern(records, buffer, "declare void @dream_print_int(i32)\n")
    lower_append_extern(records, buffer, "declare void @dream_print_float(double)\n")
    lower_append_extern(records, buffer, "declare void @dream_print_bool(i1)\n")
    lower_append_extern(records, buffer, "declare void @dream_print_string(i8*)\n")
    lower_append_extern(records, buffer, "declare void @dream_eprint_int(i32)\n")
    lower_append_extern(records, buffer, "declare void @dream_eprint_float(double)\n")
    lower_append_extern(records, buffer, "declare void @dream_eprint_bool(i1)\n")
    lower_append_extern(records, buffer, "declare void @dream_eprint_string(i8*)\n")
    lower_append_extern(records, buffer, "declare i8* @malloc(i32)\n")
    lower_append_extern(records, buffer, "declare i8* @string_substring(i8*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare i8* @string_concat(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @string_compare(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @string_find(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @string_starts_with(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i1 @__c_range_equal(i8*, i32, i32, i32, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_fnv_hash_range(i8*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @string_length(i8*)\n")
    lower_append_extern(records, buffer, "declare i8* @__c_file_read(i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_file_write(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_file_write_bytes(i8*, %dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_build_llvm(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_time_ms()\n")
    lower_append_extern(records, buffer, "declare i1 @__c_debug_on()\n")
    lower_append_extern(records, buffer, "declare void @__c_eprint_text(i8*)\n")
    lower_append_extern(records, buffer, "declare void @__c_eprint_int(i32)\n")
    lower_append_extern(records, buffer, "declare void @__c_process_set_args(i32, i8**)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_process_arg_count()\n")
    lower_append_extern(records, buffer, "declare i8* @__c_process_arg(i32)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @__c_str_to_bytes(i8*)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @__c_bytes_slice(%dynarray_i32*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @__c_bytes_from_array(%dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_bytes_get(%dynarray_i32*, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_bytes_length(%dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare i8* @__c_bytes_to_str(%dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @__c_utf8_encode_rune(i32)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_utf8_rune_at(i8*, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @__c_utf8_rune_count(i8*)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @create_dynarray_i32(i32)\n")
    lower_append_extern(records, buffer, "declare void @append_i32(%dynarray_i32*, i32)\n")
    lower_append_extern(records, buffer, "declare void @append_f64(%dynarray_i32*, double)\n")
    lower_append_extern(records, buffer, "declare void @append_pointer(%dynarray_i32*, i8*)\n")
    lower_append_extern(records, buffer, "declare double @get_f64(%dynarray_i32*, i32)\n")
    lower_append_extern(records, buffer, "declare i8* @get_pointer(%dynarray_i32*, i32)\n")
    lower_append_extern(records, buffer, "declare void @set_dynarray_i32(%dynarray_i32*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @len_dynarray_i32(%dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare i32 @get_dynarray_i32(%dynarray_i32*, i32)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @slice_dynarray_i32(%dynarray_i32*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare %dynarray_i32* @concat_dynarray_i32(%dynarray_i32*, %dynarray_i32*)\n")
    lower_append_extern(records, buffer, "declare %dynarray_ptr* @concat_dynarray_ptr(%dynarray_ptr*, %dynarray_ptr*)\n")
    lower_append_extern(records, buffer, "declare %dir_closure* @dream_closure_create(i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i8* @dream_closure_alloc(i64)\n")
    lower_append_extern(records, buffer, "declare %dict_t* @dream_dict_create_int_int(i32)\n")
    lower_append_extern(records, buffer, "declare %dict_t* @dream_dict_create_int_str(i32)\n")
    lower_append_extern(records, buffer, "declare %dict_t* @dream_dict_create_str_int(i32)\n")
    lower_append_extern(records, buffer, "declare %dict_t* @dream_dict_create_str_str(i32)\n")
    lower_append_extern(records, buffer, "declare void @dict_set_int_int(%dict_t*, i32, i32)\n")
    lower_append_extern(records, buffer, "declare void @dict_set_int_str(%dict_t*, i32, i8*)\n")
    lower_append_extern(records, buffer, "declare void @dict_set_str_int(%dict_t*, i8*, i32)\n")
    lower_append_extern(records, buffer, "declare void @dict_set_str_str(%dict_t*, i8*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_get_int_int(%dict_t*, i32)\n")
    lower_append_extern(records, buffer, "declare i8* @dream_dict_get_int_str(%dict_t*, i32)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_get_str_int(%dict_t*, i8*)\n")
    lower_append_extern(records, buffer, "declare i8* @dream_dict_get_str_str(%dict_t*, i8*)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_size_int_int(%dict_t*)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_size_int_str(%dict_t*)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_size_str_int(%dict_t*)\n")
    lower_append_extern(records, buffer, "declare i32 @dream_dict_size_str_str(%dict_t*)\n")
    lower_builtin_helpers(records)
    let string_scan_node = 1
    let string_scan_prev = 0
    while string_scan_node < len(ast):
        let scan_kind = ast_node_kind(ast, string_scan_node)
        let scan_size = ast_node_size(scan_kind)
        if scan_size == 0:
            __c_eprint_text("ast_scan: kind=0 at node ")
            __c_eprint_int(string_scan_node)
            __c_eprint_text(" prev=")
            __c_eprint_int(string_scan_prev)
            __c_eprint_text(" pool=")
            __c_eprint_int(len(ast))
            __c_eprint_text("\n")
            string_scan_node = string_scan_node + 1
        else:
            let scan_next = string_scan_node + scan_size
            if scan_next > len(ast):
                __c_eprint_text("ast_scan: overshoot node=")
                __c_eprint_int(string_scan_node)
                __c_eprint_text(" kind=")
                __c_eprint_int(scan_kind)
                __c_eprint_text(" size=")
                __c_eprint_int(scan_size)
                __c_eprint_text(" next=")
                __c_eprint_int(scan_next)
                __c_eprint_text(" pool=")
                __c_eprint_int(len(ast))
                __c_eprint_text("\n")
            if scan_kind == AST_EXPR_STRING or scan_kind == AST_PAT_STRING:
                lower_append_string_global(records, buffer, context.src, ast_node_start(ast, string_scan_node), ast_node_end(ast, string_scan_node))
            string_scan_prev = string_scan_node
            string_scan_node = scan_next
    let def_param_scan = 0
    while def_param_scan < len(context.pd):
        let def_param_token = context.pd[def_param_scan]
        if def_param_token >= 0:
            if token_kind(context.kinds, def_param_token) == TOKEN_STRING:
                lower_append_string_global(records, buffer, context.src, token_start(context.starts, def_param_token), token_end(context.ends, def_param_token))
        def_param_scan = def_param_scan + 1
    let lambda_scan_node = 1
    let lambda_scan_number = 0
    while lambda_scan_node < len(ast):
        if ast_node_kind(ast, lambda_scan_node) == AST_EXPR_LAMBDA:
            lower_lambda_helper(context, ast, lambda_scan_node, records, lambda_scan_number)
            lambda_scan_number = lambda_scan_number + 1
        lambda_scan_node = ast_next_node(ast, lambda_scan_node)
    let const_index = 0
    while const_index < len(constant_starts):
        if constant_ends[const_index] > constant_starts[const_index]:
            let const_marker = buffer[0]
            append_text(buffer, "@")
            append_text(buffer, context.src[constant_starts[const_index]:constant_ends[const_index]])
            append_text(buffer, " = constant i32 ")
            append_integer(buffer, constant_values[const_index])
            append_text(buffer, "\n")
            dir_append_record(records, DIR_TAG_MODULE, DIR_TAG_INVALID, 0, 0, 0, buffer, const_marker, len(buffer))
            buffer[0] = len(buffer)
        const_index = const_index + 1
    let global_decl_index = 0
    while global_decl_index < len(global_let_name_starts):
        let global_decl_text = string_concat("@", string_concat(context.src[global_let_name_starts[global_decl_index]:global_let_name_ends[global_decl_index]], " = global "))
        let global_decl_type = global_let_types[global_decl_index]
        if global_decl_type == VALUE_TYPE_STRING:
            global_decl_text = string_concat(global_decl_text, "i8*")
        if global_decl_type == VALUE_TYPE_LIST:
            global_decl_text = string_concat(global_decl_text, "%dynarray_i32*")
        if global_decl_type == VALUE_TYPE_BOOL:
            global_decl_text = string_concat(global_decl_text, "i1")
        if global_decl_type == VALUE_TYPE_FLOAT:
            global_decl_text = string_concat(global_decl_text, "double")
        if global_decl_type == VALUE_TYPE_DICT_INT_INT or global_decl_type == VALUE_TYPE_DICT_INT_STRING or global_decl_type == VALUE_TYPE_DICT_STRING_INT or global_decl_type == VALUE_TYPE_DICT_STRING_STRING:
            global_decl_text = string_concat(global_decl_text, "%dict_t*")
        let global_decl_is_known = global_decl_type == VALUE_TYPE_STRING or global_decl_type == VALUE_TYPE_LIST or global_decl_type == VALUE_TYPE_BOOL or global_decl_type == VALUE_TYPE_FLOAT or global_decl_type == VALUE_TYPE_DICT_INT_INT or global_decl_type == VALUE_TYPE_DICT_INT_STRING or global_decl_type == VALUE_TYPE_DICT_STRING_INT or global_decl_type == VALUE_TYPE_DICT_STRING_STRING
        if not global_decl_is_known:
            global_decl_text = string_concat(global_decl_text, "i32")
        global_decl_text = string_concat(global_decl_text, " zeroinitializer\n")
        lower_append_module(records, buffer, global_decl_text)
        global_decl_index = global_decl_index + 1
    let function_index = 0
    while function_index < len(fn_ast_starts):
        lower_function(context, ast, function_index, fn_ast_starts, fn_ast_ends, records, buffer, global_let_name_starts, global_let_name_ends, global_let_types, global_let_nodes, function_bodies, function_body_ends, parameter_types, constant_starts, constant_ends, constant_values, constant_types)
        function_index = function_index + 1
    return true

def lower_builtin_helpers(records: list[int]):
    let helper_append_buffer = [1]
    append_text(helper_append_buffer, "define i32 @append(%dynarray_i32* %array, i32 %value) {\nentry:\ncall void @append_i32(%dynarray_i32* %array, i32 %value)\nret i32 0\n}\n")
    let helper_append_buffer_marker = helper_append_buffer[0]
    dir_append_record(records, DIR_TAG_FUNCTION, DIR_TAG_INVALID, 0, 0, 0, helper_append_buffer, helper_append_buffer_marker, len(helper_append_buffer))
    let helper_len_buffer = [1]
    append_text(helper_len_buffer, "define i32 @len(%dynarray_i32* %array) alwaysinline {\nentry:\n%is_null = icmp eq %dynarray_i32* %array, null\nbr i1 %is_null, label %len.invalid, label %len.valid\nlen.valid:\n%length_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 1\n%length = load i32, i32* %length_ptr\nret i32 %length\nlen.invalid:\nret i32 0\n}\n")
    let helper_len_buffer_marker = helper_len_buffer[0]
    dir_append_record(records, DIR_TAG_FUNCTION, DIR_TAG_INVALID, 0, 0, 0, helper_len_buffer, helper_len_buffer_marker, len(helper_len_buffer))
    let helper_get_buffer = [1]
    append_text(helper_get_buffer, "define i32 @get(%dynarray_i32* %array, i32 %index) alwaysinline {\nentry:\n%is_null = icmp eq %dynarray_i32* %array, null\nbr i1 %is_null, label %get.invalid, label %get.check\nget.check:\n%length_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 1\n%length = load i32, i32* %length_ptr\n%valid_low = icmp sge i32 %index, 0\n%valid_high = icmp slt i32 %index, %length\n%valid = and i1 %valid_low, %valid_high\nbr i1 %valid, label %get.valid, label %get.invalid\nget.valid:\n%data_ptr = getelementptr %dynarray_i32, %dynarray_i32* %array, i32 0, i32 2\n%data = load i32*, i32** %data_ptr\n%element_ptr = getelementptr i32, i32* %data, i32 %index\n%value = load i32, i32* %element_ptr\nret i32 %value\nget.invalid:\nret i32 0\n}\n")
    let helper_get_buffer_marker = helper_get_buffer[0]
    dir_append_record(records, DIR_TAG_FUNCTION, DIR_TAG_INVALID, 0, 0, 0, helper_get_buffer, helper_get_buffer_marker, len(helper_get_buffer))
