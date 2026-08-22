from compiler_lir_model import LirProgram, lir_record_count, lir_value_count, lir_record_offset, lir_value_offset, lir_value_type_in_function, lir_value_exists, lir_block_parameter_offset, LIR_RECORD_MODULE, LIR_RECORD_FUNCTION, LIR_RECORD_BLOCK, LIR_RECORD_PARAMETER, LIR_RECORD_INSTRUCTION, LIR_RECORD_TERMINATOR, LIR_TYPE_VOID, LIR_TYPE_I1, LIR_TYPE_I32, LIR_TYPE_F64, LIR_TYPE_PTR, LIR_TYPE_AGGREGATE, LIR_TYPE_DYNAMIC, LIR_OPERAND_VALUE, LIR_OPERAND_IMMEDIATE, LIR_OPERAND_BLOCK, LIR_OPERAND_TYPE, LIR_OPERAND_SYMBOL, LIR_OP_CONST, LIR_OP_COPY, LIR_OP_BINARY, LIR_OP_UNARY, LIR_OP_CALL, LIR_OP_RUNTIME_CALL, LIR_OP_SELECT, LIR_OP_AGGREGATE, LIR_OP_EXTRACT, LIR_OP_ENUM, LIR_OP_CLOSURE, LIR_OP_CAST, LIR_OP_BOUNDS_CHECK, LIR_TERM_JUMP, LIR_TERM_BRANCH, LIR_TERM_SWITCH, LIR_TERM_RETURN, LIR_TERM_UNREACHABLE
from text_buffer import TextBuffer

let llvm_lir_function_record_cache: list[int] = []
let llvm_lir_function_terminator_start_cache: list[int] = []
let llvm_lir_function_terminator_count_cache: list[int] = []
let llvm_lir_terminator_record_cache: list[int] = []

def llvm_lir_debug_start() -> int:
    if __c_debug_on():
        return __c_time_ms()
    return 0

def llvm_lir_debug_checkpoint(label: str, previous_time: int) -> int:
    if not __c_debug_on():
        return previous_time
    let current_time = __c_time_ms()
    __c_eprint_text("[timing] llvm-")
    __c_eprint_text(label)
    __c_eprint_text(" ")
    __c_eprint_int(current_time - previous_time)
    __c_eprint_text("ms\n")
    return current_time

def llvm_lir_type(type_tag: int) -> str:
    if type_tag == LIR_TYPE_VOID:
        return "void"
    if type_tag == LIR_TYPE_I1:
        return "i1"
    if type_tag == LIR_TYPE_I32:
        return "i32"
    if type_tag == LIR_TYPE_F64:
        return "double"
    return "i8*"

def llvm_lir_join_int(prefix: str, value: int, suffix: str) -> str:
    let buffer = TextBuffer{data: []}
    append(buffer, prefix)
    append(buffer, value)
    append(buffer, suffix)
    return buffer.to_str()

def llvm_lir_value_name(value: int) -> str:
    return llvm_lir_join_int("%v", value, "")

def llvm_lir_block_name(block: int) -> str:
    return llvm_lir_join_int("bb", block, "")

def llvm_lir_block_ref_name(block: int) -> str:
    return string_concat("%", llvm_lir_block_name(block))

def llvm_lir_function_name(function_index: int) -> str:
    return llvm_lir_join_int("@dm_function_", function_index, "")

def llvm_lir_prepare_function_cache(program: LirProgram):
    let maximum_function = -1
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        let function_index = program.records[offset + 1]
        if function_index > maximum_function:
            maximum_function = function_index
        record_id = record_id + 1
    llvm_lir_function_record_cache = []
    llvm_lir_function_terminator_start_cache = []
    llvm_lir_function_terminator_count_cache = []
    llvm_lir_terminator_record_cache = []
    let function_index = 0
    while function_index <= maximum_function:
        append(llvm_lir_function_record_cache, -1)
        append(llvm_lir_function_terminator_start_cache, -1)
        append(llvm_lir_function_terminator_count_cache, 0)
        function_index = function_index + 1
    record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION:
            let function_index = program.records[offset + 1]
            if function_index >= 0 and function_index < len(llvm_lir_function_record_cache):
                llvm_lir_function_record_cache[function_index] = record_id
        elif program.records[offset] == LIR_RECORD_TERMINATOR:
            let function_index = program.records[offset + 1]
            if function_index >= 0 and function_index < len(llvm_lir_function_terminator_start_cache):
                if llvm_lir_function_terminator_start_cache[function_index] < 0:
                    llvm_lir_function_terminator_start_cache[function_index] = len(llvm_lir_terminator_record_cache)
                append(llvm_lir_terminator_record_cache, record_id)
                llvm_lir_function_terminator_count_cache[function_index] = llvm_lir_function_terminator_count_cache[function_index] + 1
        record_id = record_id + 1

def llvm_lir_operand_kind(program: LirProgram, record_offset: int, operand_index: int) -> int:
    let operand_start = program.records[record_offset + 6]
    return program.values[lir_value_offset(operand_start + operand_index)]

def llvm_lir_operand_value(program: LirProgram, record_offset: int, operand_index: int) -> int:
    let operand_start = program.records[record_offset + 6]
    return program.values[lir_value_offset(operand_start + operand_index) + 1]

def llvm_lir_value_type(program: LirProgram, function_index: int, value: int) -> int:
    return lir_value_type_in_function(program.records, function_index, value)

def llvm_lir_has_value(program: LirProgram, function_index: int, value: int) -> bool:
    return lir_value_exists(program.records, function_index, value)

def llvm_lir_zero(type_tag: int) -> str:
    if type_tag == LIR_TYPE_VOID:
        return ""
    if type_tag == LIR_TYPE_PTR or type_tag == LIR_TYPE_AGGREGATE or type_tag == LIR_TYPE_DYNAMIC:
        return "null"
    if type_tag == LIR_TYPE_F64:
        return "0.000000e+00"
    return "0"

def llvm_lir_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int) -> str:
    let operand_kind = llvm_lir_operand_kind(program, record_offset, operand_index)
    let operand_value = llvm_lir_operand_value(program, record_offset, operand_index)
    if operand_kind == LIR_OPERAND_VALUE:
        let function_index = program.records[record_offset + 1]
        if not llvm_lir_has_value(program, function_index, operand_value):
            return llvm_lir_zero(expected_type)
        return llvm_lir_value_name(operand_value)
    if operand_kind == LIR_OPERAND_BLOCK:
        return llvm_lir_block_ref_name(operand_value)
    if operand_kind == LIR_OPERAND_SYMBOL:
        return llvm_lir_function_name(operand_value)
    if operand_kind == LIR_OPERAND_TYPE:
        return llvm_lir_type(operand_value)
    if expected_type == LIR_TYPE_PTR or expected_type == LIR_TYPE_AGGREGATE or expected_type == LIR_TYPE_DYNAMIC:
        if operand_value == 0:
            return "null"
        return llvm_lir_join_int("inttoptr (i32 ", operand_value, " to i8*)")
    if expected_type == LIR_TYPE_I1:
        if operand_value == 0:
            return "0"
        return "1"
    return llvm_lir_join_int("", operand_value, "")

def llvm_lir_append_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int, output: TextBuffer):
    let operand_kind = llvm_lir_operand_kind(program, record_offset, operand_index)
    let operand_value = llvm_lir_operand_value(program, record_offset, operand_index)
    if operand_kind == LIR_OPERAND_VALUE:
        let function_index = program.records[record_offset + 1]
        if not llvm_lir_has_value(program, function_index, operand_value):
            append(output, llvm_lir_zero(expected_type))
        else:
            append(output, "%v")
            append(output, operand_value)
        return
    if operand_kind == LIR_OPERAND_BLOCK:
        append(output, "%bb")
        append(output, operand_value)
        return
    if operand_kind == LIR_OPERAND_SYMBOL:
        append(output, "@dm_function_")
        append(output, operand_value)
        return
    if operand_kind == LIR_OPERAND_TYPE:
        append(output, llvm_lir_type(operand_value))
        return
    if expected_type == LIR_TYPE_PTR or expected_type == LIR_TYPE_AGGREGATE or expected_type == LIR_TYPE_DYNAMIC:
        if operand_value == 0:
            append(output, "null")
        else:
            append(output, "inttoptr (i32 ")
            append(output, operand_value)
            append(output, " to i8*)")
        return
    if expected_type == LIR_TYPE_I1:
        if operand_value == 0:
            append(output, "0")
        else:
            append(output, "1")
        return
    append(output, operand_value)

def llvm_lir_runtime_name(runtime_id: int, result_type: int) -> str:
    let suffix = "ptr"
    if result_type == LIR_TYPE_VOID:
        suffix = "void"
    elif result_type == LIR_TYPE_I1:
        suffix = "i1"
    elif result_type == LIR_TYPE_I32:
        suffix = "i32"
    elif result_type == LIR_TYPE_F64:
        suffix = "f64"
    let name = llvm_lir_join_int("@dm_runtime_", runtime_id, "_")
    return string_concat(name, suffix)

def llvm_lir_find_function_record(program: LirProgram, function_index: int) -> int:
    if function_index >= 0 and function_index < len(llvm_lir_function_record_cache):
        return llvm_lir_function_record_cache[function_index]
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION and program.records[offset + 1] == function_index:
            return record_id
        record_id = record_id + 1
    return -1

def llvm_lir_function_parameter_type(program: LirProgram, function_index: int, parameter_index: int) -> int:
    let record_id = llvm_lir_find_function_record(program, function_index)
    if record_id < 0:
        return LIR_TYPE_DYNAMIC
    let offset = lir_record_offset(record_id)
    if parameter_index < 0 or parameter_index >= program.records[offset + 9] - 1:
        return LIR_TYPE_DYNAMIC
    let value_id = program.records[offset + 8] + parameter_index
    let value_offset = lir_value_offset(value_id)
    if program.values[value_offset] != LIR_OPERAND_TYPE:
        return LIR_TYPE_DYNAMIC
    return program.values[value_offset + 1]

def llvm_lir_append_runtime_declarations(output: TextBuffer):
    let runtime_id = 1
    while runtime_id <= 32:
        append(output, "declare void @dm_runtime_")
        append(output, runtime_id)
        append(output, "_void(...)\n")
        append(output, "declare i1 @dm_runtime_")
        append(output, runtime_id)
        append(output, "_i1(...)\n")
        append(output, "declare i32 @dm_runtime_")
        append(output, runtime_id)
        append(output, "_i32(...)\n")
        append(output, "declare double @dm_runtime_")
        append(output, runtime_id)
        append(output, "_f64(...)\n")
        append(output, "declare i8* @dm_runtime_")
        append(output, runtime_id)
        append(output, "_ptr(...)\n")
        runtime_id = runtime_id + 1

def llvm_lir_render_call_arguments_from(program: LirProgram, record_offset: int, first_operand: int, output: TextBuffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = first_operand
    let rendered_count = 0
    while operand_index < operand_count:
        if rendered_count > 0:
            append(output, ", ")
        let operand_type = LIR_TYPE_DYNAMIC
        if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
            operand_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program, record_offset, operand_index))
        elif llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_IMMEDIATE:
            operand_type = LIR_TYPE_I32
        append(output, llvm_lir_type(operand_type))
        append(output, " ")
        llvm_lir_append_operand(program, record_offset, operand_index, operand_type, output)
        operand_index = operand_index + 1
        rendered_count = rendered_count + 1

def llvm_lir_render_call_arguments(program: LirProgram, record_offset: int, output: TextBuffer):
    llvm_lir_render_call_arguments_from(program, record_offset, 0, output)

def llvm_lir_append_coerced_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int, output: TextBuffer):
    let actual_type = LIR_TYPE_I32
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        actual_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program, record_offset, operand_index))
    if expected_type == LIR_TYPE_DYNAMIC or expected_type == LIR_TYPE_AGGREGATE:
        expected_type = LIR_TYPE_PTR
    if expected_type == actual_type or actual_type == LIR_TYPE_DYNAMIC and expected_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE and expected_type == LIR_TYPE_PTR:
        llvm_lir_append_operand(program, record_offset, operand_index, actual_type, output)
    elif expected_type == LIR_TYPE_PTR or expected_type == LIR_TYPE_I32 or expected_type == LIR_TYPE_F64 or expected_type == LIR_TYPE_I1:
        append(output, llvm_lir_join_int("%phi_arg_", record_offset + operand_index, ""))
    else:
        append(output, llvm_lir_zero(expected_type))

def llvm_lir_append_direct_call_argument(program: LirProgram, record_offset: int, operand_index: int, expected_type: int, output: TextBuffer):
    let actual_type = LIR_TYPE_I32
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        actual_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program, record_offset, operand_index))
    if expected_type == LIR_TYPE_DYNAMIC:
        expected_type = LIR_TYPE_PTR
    if expected_type == LIR_TYPE_VOID:
        expected_type = actual_type
    append(output, llvm_lir_type(expected_type))
    append(output, " ")
    if expected_type == actual_type or actual_type == LIR_TYPE_DYNAMIC and expected_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE and expected_type == LIR_TYPE_PTR:
        llvm_lir_append_operand(program, record_offset, operand_index, actual_type, output)
    else:
        append(output, llvm_lir_join_int("%call_arg_", record_offset + operand_index, ""))

def llvm_lir_direct_call_argument_needs_cast(actual_type: int, expected_type: int) -> bool:
    if expected_type == LIR_TYPE_DYNAMIC:
        expected_type = LIR_TYPE_PTR
    if expected_type == LIR_TYPE_DYNAMIC or expected_type == LIR_TYPE_AGGREGATE:
        expected_type = LIR_TYPE_PTR
    if actual_type == LIR_TYPE_DYNAMIC and expected_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE and expected_type == LIR_TYPE_PTR:
        return false
    return actual_type != expected_type

def llvm_lir_block_parameter_type(program: LirProgram, function_index: int, block_index: int, parameter_index: int) -> int:
    let offset = lir_block_parameter_offset(function_index, block_index, parameter_index)
    if offset < 0:
        return LIR_TYPE_DYNAMIC
    if offset + 4 >= len(program.records):
        return LIR_TYPE_DYNAMIC
    if program.records[offset] == LIR_RECORD_PARAMETER:
        return program.records[offset + 4]
    return LIR_TYPE_DYNAMIC

def llvm_lir_edge_operand_type(program: LirProgram, record_offset: int, operand_index: int) -> int:
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        return llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program, record_offset, operand_index))
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_IMMEDIATE:
        return LIR_TYPE_I32
    return LIR_TYPE_DYNAMIC

def llvm_lir_append_edge_cast(program: LirProgram, record_offset: int, operand_index: int, expected_type: int, output: TextBuffer):
    let actual_type = llvm_lir_edge_operand_type(program, record_offset, operand_index)
    if expected_type == LIR_TYPE_DYNAMIC or expected_type == LIR_TYPE_AGGREGATE:
        expected_type = LIR_TYPE_PTR
    if not llvm_lir_direct_call_argument_needs_cast(actual_type, expected_type):
        return
    let temp_name = llvm_lir_join_int("%phi_arg_", record_offset + operand_index, "")
    if expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "inttoptr i32 ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, " to i8*\n")
    elif expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I1:
        let integer_name = llvm_lir_join_int("%phi_arg_int_", record_offset + operand_index, "")
        append(output, "  ")
        append(output, integer_name)
        append(output, " = zext i1 ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
        append(output, " to i32\n  ")
        append(output, temp_name)
        append(output, " = inttoptr i32 ")
        append(output, integer_name)
        append(output, " to i8*\n")
    elif expected_type == LIR_TYPE_I32 and (actual_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE or actual_type == LIR_TYPE_DYNAMIC):
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "ptrtoint i8* ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_F64 and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "sitofp i32 ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, " to double\n")
    elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_F64:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "fptosi double ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_I1:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "zext i1 ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "icmp ne i32 ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, ", 0\n")
    elif expected_type == LIR_TYPE_I1 and (actual_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE or actual_type == LIR_TYPE_DYNAMIC):
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "icmp ne i8* ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, ", null\n")
    elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_F64:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "fcmp one double ")
        llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, ", 0.000000e+00\n")
    else:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, llvm_lir_zero(expected_type))
        append(output, "\n")

def llvm_lir_append_edge_casts(program: LirProgram, record_offset: int, target_block: int, argument_start: int, argument_count: int, output: TextBuffer):
    let parameter_index = 0
    let function_index = program.records[record_offset + 1]
    while parameter_index < argument_count:
        let expected_type = llvm_lir_block_parameter_type(program, function_index, target_block, parameter_index)
        llvm_lir_append_edge_cast(program, record_offset, argument_start + parameter_index, expected_type, output)
        parameter_index = parameter_index + 1

def llvm_lir_append_direct_call_casts(program: LirProgram, record_offset: int, function_index: int, output: TextBuffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = 1
    let argument_index = 0
    while operand_index < operand_count:
        let expected_type = llvm_lir_function_parameter_type(program, function_index, argument_index)
        if expected_type == LIR_TYPE_DYNAMIC:
            expected_type = LIR_TYPE_PTR
        let actual_type = LIR_TYPE_I32
        if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
            actual_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program, record_offset, operand_index))
        if llvm_lir_direct_call_argument_needs_cast(actual_type, expected_type):
            let temp_name = llvm_lir_join_int("%call_arg_", record_offset + operand_index, "")
            if expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "inttoptr i32 ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, " to i8*\n")
            elif expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I1:
                let integer_name = llvm_lir_join_int("%call_arg_int_", record_offset + operand_index, "")
                append(output, "  ")
                append(output, integer_name)
                append(output, " = zext i1 ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
                append(output, " to i32\n  ")
                append(output, temp_name)
                append(output, " = inttoptr i32 ")
                append(output, integer_name)
                append(output, " to i8*\n")
            elif expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_F64:
                let integer_name = llvm_lir_join_int("%call_arg_int_", record_offset + operand_index, "")
                append(output, "  ")
                append(output, integer_name)
                append(output, " = fptosi double ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, " to i32\n  ")
                append(output, temp_name)
                append(output, " = inttoptr i32 ")
                append(output, integer_name)
                append(output, " to i8*\n")
            elif expected_type == LIR_TYPE_I32 and (actual_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE or actual_type == LIR_TYPE_DYNAMIC):
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "ptrtoint i8* ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_F64 and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "sitofp i32 ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, " to double\n")
            elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_F64:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "fptosi double ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_I1:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "zext i1 ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "icmp ne i32 ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, ", 0\n")
            elif expected_type == LIR_TYPE_I1 and (actual_type == LIR_TYPE_PTR or actual_type == LIR_TYPE_AGGREGATE or actual_type == LIR_TYPE_DYNAMIC):
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "icmp ne i8* ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
                append(output, ", null\n")
            elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_F64:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "fcmp one double ")
                llvm_lir_append_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, ", 0.000000e+00\n")
            else:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, llvm_lir_zero(expected_type))
                append(output, "\n")
        operand_index = operand_index + 1
        argument_index = argument_index + 1

def llvm_lir_render_direct_call_arguments(program: LirProgram, record_offset: int, function_index: int, output: TextBuffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = 1
    let argument_index = 0
    while operand_index < operand_count:
        if argument_index > 0:
            append(output, ", ")
        let expected_type = llvm_lir_function_parameter_type(program, function_index, argument_index)
        llvm_lir_append_direct_call_argument(program, record_offset, operand_index, expected_type, output)
        operand_index = operand_index + 1
        argument_index = argument_index + 1

def llvm_lir_append_binary(program: LirProgram, offset: int, output: TextBuffer, result_name: str, result_type: int):
    let operator = llvm_lir_operand_value(program, offset, 0)
    let operand_type = LIR_TYPE_I32
    if llvm_lir_operand_kind(program, offset, 1) == LIR_OPERAND_VALUE:
        operand_type = llvm_lir_value_type(program, program.records[offset + 1], llvm_lir_operand_value(program, offset, 1))
    let instruction = "add"
    let is_compare = false
    if operand_type != LIR_TYPE_I1 and operand_type != LIR_TYPE_I32 and operand_type != LIR_TYPE_F64:
        append(output, "  ")
        append(output, result_name)
        append(output, " = call ")
        append(output, llvm_lir_type(result_type))
        append(output, " @dm_runtime_31_ptr(")
        llvm_lir_render_call_arguments(program, offset, output)
        append(output, ")\n")
        return
    if operator == 6:
        instruction = "sub"
    elif operator == 7:
        instruction = "mul"
    elif operator == 8:
        instruction = "sdiv"
    elif operator == 36:
        instruction = "srem"
    elif operator == 18:
        instruction = "icmp slt"
        is_compare = true
    elif operator == 33:
        instruction = "icmp sgt"
        is_compare = true
    elif operator == 31:
        instruction = "icmp sle"
        is_compare = true
    elif operator == 32:
        instruction = "icmp sge"
        is_compare = true
    elif operator == 29:
        instruction = "icmp eq"
        is_compare = true
    elif operator == 30:
        instruction = "icmp ne"
        is_compare = true
    elif operator == 34:
        instruction = "and"
    elif operator == 35:
        instruction = "or"
    if operand_type == LIR_TYPE_F64:
        if operator == 18:
            instruction = "fcmp olt"
            is_compare = true
        elif operator == 33:
            instruction = "fcmp ogt"
            is_compare = true
        elif operator == 31:
            instruction = "fcmp ole"
            is_compare = true
        elif operator == 32:
            instruction = "fcmp oge"
            is_compare = true
        elif operator == 29:
            instruction = "fcmp oeq"
            is_compare = true
        elif operator == 30:
            instruction = "fcmp one"
            is_compare = true
        elif operator == 1:
            instruction = "fadd"
        elif operator == 6:
            instruction = "fsub"
        elif operator == 7:
            instruction = "fmul"
        elif operator == 8:
            instruction = "fdiv"
        elif operator == 36:
            instruction = "frem"
        elif operator == 5:
            instruction = "fadd"
    append(output, "  ")
    append(output, result_name)
    append(output, " = ")
    append(output, instruction)
    append(output, " ")
    if is_compare:
        append(output, llvm_lir_type(operand_type))
        append(output, " ")
    else:
        append(output, llvm_lir_type(operand_type))
        append(output, " ")
    llvm_lir_append_operand(program, offset, 1, operand_type, output)
    append(output, ", ")
    llvm_lir_append_operand(program, offset, 2, operand_type, output)
    append(output, "\n")

def llvm_lir_append_instruction(program: LirProgram, offset: int, output: TextBuffer):
    let opcode = program.records[offset + 3]
    let result_value = program.records[offset + 5]
    let result_type = program.records[offset + 4]
    let result_name = llvm_lir_value_name(result_value)
    if result_value < 0 and opcode != LIR_OP_RUNTIME_CALL and opcode != LIR_OP_CALL and opcode != LIR_OP_AGGREGATE and opcode != LIR_OP_EXTRACT and opcode != LIR_OP_ENUM and opcode != LIR_OP_CLOSURE and opcode != LIR_OP_BOUNDS_CHECK:
        return
    if program.records[offset + 7] == 0 and opcode != LIR_OP_RUNTIME_CALL and opcode != LIR_OP_CALL and opcode != LIR_OP_AGGREGATE and opcode != LIR_OP_EXTRACT and opcode != LIR_OP_ENUM and opcode != LIR_OP_CLOSURE and opcode != LIR_OP_BOUNDS_CHECK:
        return
    if opcode == LIR_OP_BINARY:
        if result_type != LIR_TYPE_I1 and result_type != LIR_TYPE_I32 and result_type != LIR_TYPE_F64:
            append(output, "  call i8* @dm_runtime_31_ptr(")
            llvm_lir_render_call_arguments(program, offset, output)
            append(output, ")\n")
            return
        llvm_lir_append_binary(program, offset, output, result_name, result_type)
        return
    if opcode == LIR_OP_CONST:
        append(output, "  ")
        append(output, result_name)
        append(output, " = ")
        if result_type == LIR_TYPE_PTR or result_type == LIR_TYPE_AGGREGATE or result_type == LIR_TYPE_DYNAMIC:
            append(output, "inttoptr i32 ")
            llvm_lir_append_operand(program, offset, 0, LIR_TYPE_I32, output)
            append(output, " to i8*\n")
        elif result_type == LIR_TYPE_F64:
            append(output, "sitofp i32 ")
            llvm_lir_append_operand(program, offset, 0, LIR_TYPE_I32, output)
            append(output, " to double\n")
        else:
            append(output, "add ")
            append(output, llvm_lir_type(result_type))
            append(output, " 0, ")
            llvm_lir_append_operand(program, offset, 0, result_type, output)
            append(output, "\n")
        return
    if opcode == LIR_OP_COPY:
        if result_type == LIR_TYPE_PTR or result_type == LIR_TYPE_AGGREGATE or result_type == LIR_TYPE_DYNAMIC:
            append(output, "  ")
            append(output, result_name)
            append(output, " = call i8* @dm_runtime_31_ptr(")
            llvm_lir_render_call_arguments(program, offset, output)
            append(output, ")\n")
            return
        append(output, "  ")
        append(output, result_name)
        append(output, " = add ")
        append(output, llvm_lir_type(result_type))
        append(output, " 0, ")
        llvm_lir_append_operand(program, offset, 0, result_type, output)
        append(output, "\n")
        return
    if opcode == LIR_OP_SELECT:
        append(output, "  ")
        append(output, result_name)
        append(output, " = select i1 ")
        llvm_lir_append_operand(program, offset, 0, LIR_TYPE_I1, output)
        append(output, ", ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        llvm_lir_append_operand(program, offset, 1, result_type, output)
        append(output, ", ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        llvm_lir_append_operand(program, offset, 2, result_type, output)
        append(output, "\n")
        return
    if opcode == LIR_OP_CALL:
        let has_direct_target = false
        if program.records[offset + 7] > 0:
            has_direct_target = llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_SYMBOL
        if has_direct_target:
            let target = llvm_lir_operand_value(program, offset, 0)
            llvm_lir_append_direct_call_casts(program, offset, target, output)
            if result_type != LIR_TYPE_VOID and result_value >= 0:
                append(output, "  ")
                append(output, result_name)
                append(output, " = ")
            else:
                append(output, "  ")
            append(output, "call ")
            append(output, llvm_lir_type(result_type))
            append(output, " ")
            append(output, llvm_lir_function_name(target))
            append(output, "(")
            llvm_lir_render_direct_call_arguments(program, offset, target, output)
            append(output, ")\n")
            return
    if opcode == LIR_OP_RUNTIME_CALL or opcode == LIR_OP_CALL or opcode == LIR_OP_AGGREGATE or opcode == LIR_OP_EXTRACT or opcode == LIR_OP_ENUM or opcode == LIR_OP_CLOSURE or opcode == LIR_OP_BOUNDS_CHECK:
        let runtime_id = program.records[offset + 8]
        if runtime_id <= 0:
            runtime_id = 31
        let return_type = result_type
        let runtime_name = llvm_lir_runtime_name(runtime_id, return_type)
        if return_type != LIR_TYPE_VOID and result_value >= 0:
            append(output, "  ")
            append(output, result_name)
            append(output, " = ")
        else:
            append(output, "  ")
        append(output, "call ")
        append(output, llvm_lir_type(return_type))
        append(output, " ")
        append(output, runtime_name)
        append(output, "(")
        llvm_lir_render_call_arguments(program, offset, output)
        append(output, ")\n")
        return
    if opcode == LIR_OP_UNARY:
        if result_type == LIR_TYPE_I32:
            append(output, "  ")
            append(output, result_name)
            append(output, " = sub i32 0, ")
            llvm_lir_append_operand(program, offset, 1, result_type, output)
            append(output, "\n")
        elif result_type == LIR_TYPE_I1:
            append(output, "  ")
            append(output, result_name)
            append(output, " = xor i1 1, ")
            llvm_lir_append_operand(program, offset, 1, result_type, output)
            append(output, "\n")
        return
    if opcode == LIR_OP_CAST:
        append(output, "  ")
        append(output, result_name)
        append(output, " = add ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        append(output, "0, ")
        llvm_lir_append_operand(program, offset, 0, result_type, output)
        append(output, "\n")

def llvm_lir_append_terminator(program: LirProgram, offset: int, return_type: int, output: TextBuffer):
    let opcode = program.records[offset + 3]
    if opcode == LIR_TERM_JUMP:
        let target_block = llvm_lir_operand_value(program, offset, 0)
        llvm_lir_append_edge_casts(program, offset, target_block, 1, program.records[offset + 7] - 1, output)
        append(output, "  br label %")
        append(output, llvm_lir_block_name(target_block))
        append(output, "\n")
    elif opcode == LIR_TERM_BRANCH:
        let operand_count = program.records[offset + 7]
        if operand_count > 3:
            let operand_start = program.records[offset + 6]
            let true_count_offset = lir_value_offset(operand_start + 3)
            let true_count = program.values[true_count_offset + 1]
            llvm_lir_append_edge_casts(program, offset, llvm_lir_operand_value(program, offset, 1), 4, true_count, output)
            let false_count_index = 4 + true_count
            if false_count_index < operand_count:
                let false_count_offset = lir_value_offset(operand_start + false_count_index)
                let false_count = program.values[false_count_offset + 1]
                llvm_lir_append_edge_casts(program, offset, llvm_lir_operand_value(program, offset, 2), false_count_index + 1, false_count, output)
        let condition = llvm_lir_operand(program, offset, 0, LIR_TYPE_I1)
        if llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_VALUE:
            let condition_value = llvm_lir_operand_value(program, offset, 0)
            let function_index = program.records[offset + 1]
            let condition_type = llvm_lir_value_type(program, function_index, condition_value)
            let has_condition = llvm_lir_has_value(program, function_index, condition_value)
            if condition_type == LIR_TYPE_I32 and has_condition:
                let condition_name = llvm_lir_join_int("%branch_cond_", program.records[offset + 2], "")
                append(output, "  ")
                append(output, condition_name)
                append(output, " = icmp ne i32 ")
                append(output, condition)
                append(output, ", 0\n  br i1 ")
                append(output, condition_name)
            elif (condition_type == LIR_TYPE_PTR or condition_type == LIR_TYPE_AGGREGATE or condition_type == LIR_TYPE_DYNAMIC) and has_condition:
                let condition_name = llvm_lir_join_int("%branch_cond_", program.records[offset + 2], "")
                append(output, "  ")
                append(output, condition_name)
                append(output, " = icmp ne i8* ")
                append(output, condition)
                append(output, ", null\n  br i1 ")
                append(output, condition_name)
            elif condition_type == LIR_TYPE_F64 and has_condition:
                let condition_name = llvm_lir_join_int("%branch_cond_", program.records[offset + 2], "")
                append(output, "  ")
                append(output, condition_name)
                append(output, " = fcmp one double ")
                append(output, condition)
                append(output, ", 0.000000e+00\n  br i1 ")
                append(output, condition_name)
            else:
                append(output, "  br i1 ")
                append(output, condition)
        else:
            append(output, "  br i1 ")
            append(output, condition)
        append(output, ", label %")
        append(output, llvm_lir_block_name(llvm_lir_operand_value(program, offset, 1)))
        append(output, ", label %")
        append(output, llvm_lir_block_name(llvm_lir_operand_value(program, offset, 2)))
        append(output, "\n")
    elif opcode == LIR_TERM_SWITCH:
        append(output, "  switch i32 ")
        llvm_lir_append_operand(program, offset, 0, LIR_TYPE_I32, output)
        append(output, ", label %")
        append(output, llvm_lir_block_name(llvm_lir_operand_value(program, offset, 1)))
        append(output, " []\n")
    elif opcode == LIR_TERM_RETURN:
        if return_type == LIR_TYPE_VOID or program.records[offset + 7] == 0:
            if return_type == LIR_TYPE_VOID:
                append(output, "  ret void\n")
            else:
                append(output, "  ret ")
                append(output, llvm_lir_type(return_type))
                append(output, " ")
                append(output, llvm_lir_zero(return_type))
                append(output, "\n")
        else:
            let return_value = llvm_lir_operand_value(program, offset, 0)
            append(output, "  ret ")
            append(output, llvm_lir_type(return_type))
            append(output, " ")
            let function_index = program.records[offset + 1]
            if llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_VALUE and llvm_lir_has_value(program, function_index, return_value) and llvm_lir_value_type(program, function_index, return_value) == return_type:
                llvm_lir_append_operand(program, offset, 0, return_type, output)
            elif llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_IMMEDIATE:
                llvm_lir_append_operand(program, offset, 0, return_type, output)
            else:
                append(output, llvm_lir_zero(return_type))
            append(output, "\n")
    else:
        append(output, "  unreachable\n")

def llvm_lir_append_edge_incoming(program: LirProgram, offset: int, target_block: int, parameter_index: int, parameter_type: int, incoming: TextBuffer, incoming_count: list[int]) -> bool:
    let opcode = program.records[offset + 3]
    let operand_count = program.records[offset + 7]
    let target_index = -1
    let argument_start = -1
    let edge_argument_count = 0
    if opcode == LIR_TERM_JUMP:
        target_index = 0
        argument_start = 1
        edge_argument_count = operand_count - 1
    elif opcode == LIR_TERM_BRANCH and operand_count > 3:
        let true_count_offset = lir_value_offset(program.records[offset + 6] + 3)
        let true_count = program.values[true_count_offset + 1]
        let false_count_index = 4 + true_count
        if false_count_index < operand_count:
            let edge_index = 0
            while edge_index < 2:
                let candidate_target_index = 1
                let candidate_argument_start = 4
                let candidate_argument_count = true_count
                if edge_index == 1:
                    candidate_target_index = 2
                    let false_count_offset = lir_value_offset(program.records[offset + 6] + false_count_index)
                    candidate_argument_start = false_count_index + 1
                    candidate_argument_count = program.values[false_count_offset + 1]
                if candidate_target_index < operand_count:
                    let candidate_target_offset = lir_value_offset(program.records[offset + 6] + candidate_target_index)
                    if program.values[candidate_target_offset] == LIR_OPERAND_BLOCK and program.values[candidate_target_offset + 1] == target_block and parameter_index < candidate_argument_count:
                        if incoming_count[0] > 0:
                            append(incoming, ",")
                        append(incoming, " [")
                        llvm_lir_append_coerced_operand(program, offset, candidate_argument_start + parameter_index, parameter_type, incoming)
                        append(incoming, ", %")
                        append(incoming, llvm_lir_block_name(program.records[offset + 2]))
                        append(incoming, "]")
                        incoming_count[0] = incoming_count[0] + 1
                        return true
                edge_index = edge_index + 1
            return false
    if target_index >= 0 and target_index < operand_count:
        let target_offset = lir_value_offset(program.records[offset + 6] + target_index)
        if program.values[target_offset] == LIR_OPERAND_BLOCK and program.values[target_offset + 1] == target_block and parameter_index < edge_argument_count:
            if incoming_count[0] > 0:
                append(incoming, ",")
            append(incoming, " [")
            llvm_lir_append_coerced_operand(program, offset, argument_start + parameter_index, parameter_type, incoming)
            append(incoming, ", %")
            append(incoming, llvm_lir_block_name(program.records[offset + 2]))
            append(incoming, "]")
            incoming_count[0] = incoming_count[0] + 1
            return true
    return false

def llvm_lir_append_block_parameter(program: LirProgram, block_record_id: int, parameter_record_id: int, parameter_index: int, output: TextBuffer):
    let block_offset = lir_record_offset(block_record_id)
    let parameter_offset = lir_record_offset(parameter_record_id)
    let function_index = program.records[block_offset + 1]
    let block_index = program.records[block_offset + 2]
    let type_tag = program.records[parameter_offset + 4]
    let result_value = program.records[parameter_offset + 5]
    let incoming = TextBuffer{data: []}
    let incoming_count = 0
    let term_start = 0
    let term_count = 0
    if function_index >= 0 and function_index < len(llvm_lir_function_terminator_start_cache):
        term_start = llvm_lir_function_terminator_start_cache[function_index]
        term_count = llvm_lir_function_terminator_count_cache[function_index]
    if term_start < 0:
        term_start = 0
    let term_index = term_start
    while term_index < term_start + term_count:
        let offset = lir_record_offset(llvm_lir_terminator_record_cache[term_index])
        if program.records[offset + 1] == function_index and program.records[offset] == LIR_RECORD_TERMINATOR:
            let incoming_count_box: list[int] = [incoming_count]
            llvm_lir_append_edge_incoming(program, offset, block_index, parameter_index, type_tag, incoming, incoming_count_box)
            incoming_count = incoming_count_box[0]
        term_index = term_index + 1
    append(output, "  ")
    append(output, llvm_lir_value_name(result_value))
    append(output, " = ")
    if incoming_count > 0:
        append(output, "phi ")
        append(output, llvm_lir_type(type_tag))
        append(output, incoming.to_str())
    elif type_tag == LIR_TYPE_F64:
        append(output, "fadd double 0.000000e+00, 0.000000e+00")
    elif type_tag == LIR_TYPE_PTR or type_tag == LIR_TYPE_AGGREGATE or type_tag == LIR_TYPE_DYNAMIC:
        append(output, "inttoptr i32 0 to i8*")
    else:
        append(output, "add ")
        append(output, llvm_lir_type(type_tag))
        append(output, " 0, 0")
    append(output, "\n")

def llvm_lir_function_return_type(program: LirProgram, offset: int) -> int:
    let auxiliary_count = program.records[offset + 9]
    if auxiliary_count == 0:
        return LIR_TYPE_VOID
    let value_id = program.records[offset + 8] + auxiliary_count - 1
    let value_offset = lir_value_offset(value_id)
    return program.values[value_offset + 1]

def llvm_lir_emit_function(program: LirProgram, function_id: int, function_record_id: int, output: TextBuffer):
    let function_offset = lir_record_offset(function_record_id)
    let return_type = llvm_lir_function_return_type(program, function_offset)
    append(output, "define ")
    append(output, llvm_lir_type(return_type))
    append(output, " ")
    append(output, llvm_lir_function_name(function_id))
    append(output, "(")
    let record_id = function_record_id + 1
    let first_block = record_id
    let parameter_index = 0
    let scanning_parameters = true
    while scanning_parameters:
        if record_id >= lir_record_count(program.records):
            scanning_parameters = false
        elif program.records[lir_record_offset(record_id)] != LIR_RECORD_PARAMETER:
            scanning_parameters = false
        else:
            if parameter_index > 0:
                append(output, ", ")
            let parameter_offset = lir_record_offset(record_id)
            append(output, llvm_lir_type(program.records[parameter_offset + 4]))
            append(output, " ")
            append(output, llvm_lir_value_name(program.records[parameter_offset + 5]))
            parameter_index = parameter_index + 1
            record_id = record_id + 1
    append(output, ") {\n")
    record_id = first_block
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        let kind = program.records[offset]
        if kind == LIR_RECORD_FUNCTION:
            append(output, "}\n")
            return
        if kind == LIR_RECORD_BLOCK:
            append(output, llvm_lir_block_name(program.records[offset + 2]))
            append(output, ":\n")
            let parameter_record_id = record_id + 1
            let parameter_index = 0
            while parameter_record_id < lir_record_count(program.records):
                let parameter_offset = lir_record_offset(parameter_record_id)
                if program.records[parameter_offset] != LIR_RECORD_PARAMETER or program.records[parameter_offset + 2] != program.records[offset + 2]:
                    parameter_record_id = lir_record_count(program.records)
                else:
                    llvm_lir_append_block_parameter(program, record_id, parameter_record_id, parameter_index, output)
                    parameter_index = parameter_index + 1
                    parameter_record_id = parameter_record_id + 1
        elif kind == LIR_RECORD_INSTRUCTION:
            llvm_lir_append_instruction(program, offset, output)
        elif kind == LIR_RECORD_TERMINATOR:
            llvm_lir_append_terminator(program, offset, return_type, output)
        record_id = record_id + 1
    append(output, "}\n")

def llvm_lower_lir(program: LirProgram, output: TextBuffer) -> bool:
    let phase_time = llvm_lir_debug_start()
    llvm_lir_prepare_function_cache(program)
    phase_time = llvm_lir_debug_checkpoint("cache", phase_time)
    append(output, "; Dream LIR to LLVM IR\n")
    llvm_lir_append_runtime_declarations(output)
    append(output, "\n")
    phase_time = llvm_lir_debug_checkpoint("declarations", phase_time)
    let record_id = 0
    let function_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION:
            llvm_lir_emit_function(program, function_id, record_id, output)
            function_id = function_id + 1
        record_id = record_id + 1
    llvm_lir_debug_checkpoint("functions", phase_time)
    return true
