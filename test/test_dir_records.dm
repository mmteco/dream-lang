# dream-test: dir
from bootstrap_io import text_length
from dir_bootstrap import dir_lower_records_buffer, dir_split_lines, dir_validate_lines, dir_line_kind, dir_line_is_label, dir_line_has_prefix, dir_line_contains, dir_skip_spaces, dir_find_assignment, dir_instruction_kind, dir_instruction_type, dir_instruction_operand_count, dir_instruction_operand_mask, dir_operand_count_is_valid, dir_record_kind, dir_record_kind_is_valid, dir_append_code_range, dir_append_record, dir_build_records, dir_build_source_records, dir_render_records, dir_dump_records, dir_render_native_record, dir_native_type, dir_native_operand, dir_native_symbol, dir_render_native_operand, dir_native_operand_payload_length, dir_native_record_payload_length, dir_native_operand_mask_is_valid, dir_native_operand_mask_is_valid_range, dir_append_native_return_if_supported, dir_append_native_call_if_simple, dir_append_native_call_if_supported, dir_append_native_binary_if_supported, dir_append_native_compare_if_supported, dir_append_native_zext_if_supported, dir_append_native_unreachable_if_supported, dir_append_native_operation, dir_append_native_compare, dir_append_native_zext, dir_append_native_unreachable, dir_append_native_ret, dir_append_native_br, dir_append_native_record, dir_append_native_operand, dir_append_native_symbol_operand, dir_append_native_symbol_operand_range, dir_append_text, dir_append_integer, dir_parse_temporary_index, dir_parse_tail_integer, dir_parse_native_operand, dir_parse_native_type, dir_is_native_binary_instruction, dir_is_native_compare_instruction, dir_is_native_unary_instruction, dir_native_compare_predicate

def append_source_text(output: list[int], source: str):
    let index = 0
    while index < text_length(source):
        append(output, ord(source[index]))
        index = index + 1

def main():
    let valid_records = []
    append(valid_records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_RET)
    append(valid_records, DIR_OPCODE_RET)
    append(valid_records, DIR_TYPE_I32)
    append(valid_records, 1)
    append(valid_records, DIR_OPERAND_MASK_TYPE + DIR_OPERAND_MASK_IMMEDIATE)
    append(valid_records, 114)
    append(valid_records, 101)
    append(valid_records, 116)
    append(valid_records, 32)
    append(valid_records, 105)
    append(valid_records, 51)
    append(valid_records, 50)
    append(valid_records, 32)
    append(valid_records, 48)
    append(valid_records, 0)
    let valid_output = []
    print(dir_render_records(valid_records, valid_output))
    let valid_dump = []
    print(dir_dump_records(valid_records, valid_dump))

    let invalid_records = []
    append(invalid_records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_RET)
    append(invalid_records, DIR_OPCODE_RET)
    append(invalid_records, DIR_TYPE_I32)
    append(invalid_records, 1)
    append(invalid_records, DIR_OPERAND_MASK_TYPE)
    append(invalid_records, 114)
    append(invalid_records, 101)
    append(invalid_records, 116)
    append(invalid_records, 32)
    append(invalid_records, 105)
    append(invalid_records, 51)
    append(invalid_records, 50)
    append(invalid_records, 32)
    append(invalid_records, 48)
    append(invalid_records, 0)
    let invalid_output = []
    print(dir_render_records(invalid_records, invalid_output))

    let native_ret_records = []
    dir_append_native_ret(native_ret_records, DIR_TYPE_I32, DIR_NATIVE_OPERAND_IMMEDIATE, 42)
    let native_ret_output = []
    print(dir_render_records(native_ret_records, native_ret_output))

    let native_br_records = []
    dir_append_native_br(native_br_records, 3, DIR_NATIVE_OPERAND_TEMPORARY, 7, 10, 11)
    let native_br_output = []
    print(dir_render_records(native_br_records, native_br_output))

    let native_add_source = []
    append(native_add_source, 37)
    append(native_add_source, 116)
    append(native_add_source, 49)
    append(native_add_source, 32)
    append(native_add_source, 61)
    append(native_add_source, 32)
    append(native_add_source, 97)
    append(native_add_source, 100)
    append(native_add_source, 100)
    append(native_add_source, 32)
    append(native_add_source, 105)
    append(native_add_source, 51)
    append(native_add_source, 50)
    append(native_add_source, 32)
    append(native_add_source, 37)
    append(native_add_source, 116)
    append(native_add_source, 50)
    append(native_add_source, 44)
    append(native_add_source, 32)
    append(native_add_source, 48)
    let native_add_records = []
    print(dir_append_native_binary_if_supported(native_add_records, native_add_source, 0, len(native_add_source), DIR_OPCODE_ADD, DIR_TYPE_I32))
    let native_add_output = []
    print(dir_render_records(native_add_records, native_add_output))

    let native_temporary_add_source = []
    append_source_text(native_temporary_add_source, "%t3 = add i32 %t1, %t2")
    let native_temporary_ret_source = []
    append_source_text(native_temporary_ret_source, "ret i32 %t3")
    let native_temporary_ret_records = []
    print(dir_append_native_return_if_supported(native_temporary_ret_records, native_temporary_ret_source, 0, len(native_temporary_ret_source), DIR_TYPE_I32))
    let native_temporary_ret_output = []
    print(dir_render_records(native_temporary_ret_records, native_temporary_ret_output))
    let native_temporary_add_records = []
    print(dir_append_native_binary_if_supported(native_temporary_add_records, native_temporary_add_source, 0, len(native_temporary_add_source), DIR_OPCODE_ADD, DIR_TYPE_I32))
    let native_temporary_add_output = []
    print(dir_render_records(native_temporary_add_records, native_temporary_add_output))

    let native_and_source = []
    append_source_text(native_and_source, "%t3 = and i32 %t1, %t2")
    let native_and_records = []
    print(dir_append_native_binary_if_supported(native_and_records, native_and_source, 0, len(native_and_source), DIR_OPCODE_AND, DIR_TYPE_I32))
    let native_and_output = []
    print(dir_render_records(native_and_records, native_and_output))

    let native_compare_source = []
    append_source_text(native_compare_source, "%t3 = icmp sge i32 %t1, 0")
    let native_compare_records = []
    print(dir_append_native_compare_if_supported(native_compare_records, native_compare_source, 0, len(native_compare_source), DIR_TYPE_BOOL))
    let native_compare_output = []
    print(dir_render_records(native_compare_records, native_compare_output))

    let native_float_compare_source = []
    append_source_text(native_float_compare_source, "%t4 = fcmp olt double %t1, %t2")
    let native_float_compare_records = []
    print(dir_append_native_compare_if_supported(native_float_compare_records, native_float_compare_source, 0, len(native_float_compare_source), DIR_TYPE_BOOL))
    let native_float_compare_output = []
    print(dir_render_records(native_float_compare_records, native_float_compare_output))

    let native_float_add_source = []
    append_source_text(native_float_add_source, "%t5 = fadd double %t1, %t2")
    let native_float_add_records = []
    print(dir_append_native_binary_if_supported(native_float_add_records, native_float_add_source, 0, len(native_float_add_source), DIR_OPCODE_ADD, DIR_TYPE_F64))
    let native_float_add_output = []
    print(dir_render_records(native_float_add_records, native_float_add_output))

    let native_zext_source = []
    append_source_text(native_zext_source, "%t4 = zext i1 %t3 to i32")
    let native_zext_records = []
    print(dir_append_native_zext_if_supported(native_zext_records, native_zext_source, 0, len(native_zext_source)))
    let native_zext_output = []
    print(dir_render_records(native_zext_records, native_zext_output))

    let native_unreachable_source = []
    append_source_text(native_unreachable_source, "unreachable")
    let native_unreachable_records = []
    print(dir_append_native_unreachable_if_supported(native_unreachable_records, native_unreachable_source, 0, len(native_unreachable_source)))
    let native_unreachable_output = []
    print(dir_render_records(native_unreachable_records, native_unreachable_output))

    let native_call_source = []
    append_source_text(native_call_source, "call void @dream_flush()")
    let native_call_records = []
    print(dir_append_native_call_if_supported(native_call_records, native_call_source, 0, len(native_call_source)))
    let native_call_output = []
    print(dir_render_records(native_call_records, native_call_output))

    let native_call_value_source = []
    append_source_text(native_call_value_source, "%t3 = call i32 @dream_add(i32 %t1, i32 2)")
    let native_call_value_records = []
    print(dir_append_native_call_if_supported(native_call_value_records, native_call_value_source, 0, len(native_call_value_source)))
    let native_call_value_output = []
    print(dir_render_records(native_call_value_records, native_call_value_output))

    let native_unreachable_module_source = []
    append_source_text(native_unreachable_module_source, "define void @main() {\nentry:\n  unreachable\n}\n")
    let native_unreachable_module_output = []
    print(dir_lower_records_buffer(native_unreachable_module_source, native_unreachable_module_output))
