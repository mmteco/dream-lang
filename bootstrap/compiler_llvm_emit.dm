from compiler_lir_model import (
    LirProgram,
    lir_record_count,
    lir_value_count,
    lir_record_offset,
    lir_value_offset,
    lir_value_type_in_function,
    lir_value_exists,
    lir_block_parameter_offset,
    LIR_RECORD_MODULE,
    LIR_RECORD_FUNCTION,
    LIR_RECORD_BLOCK,
    LIR_RECORD_PARAMETER,
    LIR_RECORD_INSTRUCTION,
    LIR_RECORD_TERMINATOR,
    LIR_FUNCTION_ENTRY,
    LIR_EXTERNAL_BASE,
    LIR_TYPE_VOID,
    LIR_TYPE_I1,
    LIR_TYPE_I32,
    LIR_TYPE_F64,
    LIR_TYPE_PTR,
    LIR_TYPE_AGGREGATE,
    LIR_TYPE_DYNAMIC,
    LIR_TYPE_STR,
    LIR_TYPE_LIST,
    LIR_TYPE_BYTES,
    LIR_TYPE_DICT,
    LIR_TYPE_TUPLE,
    LIR_TYPE_STRUCT,
    LIR_OPERAND_VALUE,
    LIR_OPERAND_IMMEDIATE,
    LIR_OPERAND_BLOCK,
    LIR_OPERAND_TYPE,
    LIR_OPERAND_SYMBOL,
    LIR_OP_CONST,
    LIR_OP_COPY,
    LIR_OP_BINARY,
    LIR_OP_UNARY,
    LIR_OP_CALL,
    LIR_OP_RUNTIME_CALL,
    LIR_OP_SELECT,
    LIR_OP_AGGREGATE,
    LIR_OP_EXTRACT,
    LIR_OP_ENUM,
    LIR_OP_CLOSURE,
    LIR_OP_CAST,
    LIR_OP_BOUNDS_CHECK,
    LIR_OP_GLOBAL_LOAD,
    LIR_OP_GLOBAL_STORE,
    LIR_TERM_JUMP,
    LIR_TERM_BRANCH,
    LIR_TERM_SWITCH,
    LIR_TERM_RETURN,
    LIR_TERM_UNREACHABLE
)
from compiler_operator import (
    IR_OPERATOR_ADD,
    IR_OPERATOR_SUB,
    IR_OPERATOR_MUL,
    IR_OPERATOR_DIV,
    IR_OPERATOR_MOD,
    IR_OPERATOR_LT,
    IR_OPERATOR_GT,
    IR_OPERATOR_LE,
    IR_OPERATOR_GE,
    IR_OPERATOR_EQ,
    IR_OPERATOR_NE,
    IR_OPERATOR_IN,
    IR_OPERATOR_AND,
    IR_OPERATOR_OR,
    IR_OPERATOR_NOT,
    IR_OPERATOR_POS,
    IR_OPERATOR_NEG
)
from compiler_external import (
    EXTERNAL_COUNT,
    EXTERNAL_ID_BASE,
    EXTERNAL_ID_APPEND,
    EXTERNAL_ID_LEN,
    external_llvm_name,
    external_return_type,
    external_has_declaration,
    EXTERNAL_RETURN_UNIT,
    EXTERNAL_RETURN_INT,
    EXTERNAL_RETURN_BOOL,
    EXTERNAL_RETURN_FLOAT,
    EXTERNAL_RETURN_STRING
)
from buffer import Buffer

let llvm_lir_func_record_cache: list[int] = []
let llvm_lir_func_terminator_start_cache: list[int] = []
let llvm_lir_func_terminator_count_cache: list[int] = []
let llvm_lir_terminator_record_cache: list[int] = []
let llvm_lir_source: str = ""

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

def llvm_lir_resize_int_list(target: list[int], size: int, fill_value: int):
    # 原地扩缩并统一填充；不做全局列表重绑定
    let index = 0
    while index < size:
        if index < len(target):
            target[index] = fill_value
        else:
            append(target, fill_value)
        index = index + 1

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

def llvm_lir_is_pointer_like(type_tag: int) -> bool:
    return (
        type_tag == LIR_TYPE_PTR or
        type_tag == LIR_TYPE_AGGREGATE or
        type_tag == LIR_TYPE_DYNAMIC or
        type_tag == LIR_TYPE_STR or
        type_tag == LIR_TYPE_LIST or
        type_tag == LIR_TYPE_LIST_PTR or
        type_tag == LIR_TYPE_BYTES or
        type_tag == LIR_TYPE_DICT or
        type_tag == LIR_TYPE_TUPLE or
        type_tag == LIR_TYPE_STRUCT
    )

def llvm_lir_is_string(type_tag: int) -> bool:
    return type_tag == LIR_TYPE_STR

def llvm_lir_types_compatible(actual_type: int, expected_type: int) -> bool:
    return (
        actual_type == expected_type or
        llvm_lir_is_pointer_like(actual_type) and
        llvm_lir_is_pointer_like(expected_type)
    )

def llvm_lir_join_int(prefix: str, value: int, suffix: str) -> str:
    let buffer = Buffer{data: []}
    append(buffer, prefix)
    append(buffer, value)
    append(buffer, suffix)
    return buffer.to_str()

def llvm_lir_value_name(value: int) -> str:
    return llvm_lir_join_int("%v", value, "")

def llvm_lir_block_name(block: int) -> str:
    return llvm_lir_join_int("bb", block, "")

def llvm_lir_block_ref_name(block: int) -> str:
    return "%" + llvm_lir_block_name(block)

def llvm_lir_func_name(func_index: int) -> str:
    return llvm_lir_join_int("@dm_func_", func_index, "")

def llvm_lir_is_external_symbol(symbol: int) -> bool:
    return symbol >= LIR_EXTERNAL_BASE

def llvm_lir_external_name(symbol: int) -> str:
    let external_id = symbol - LIR_EXTERNAL_BASE
    return external_llvm_name(external_id)

def llvm_lir_external_type(external_id: int) -> int:
    let return_type = external_return_type(external_id)
    if return_type == EXTERNAL_RETURN_UNIT:
        return LIR_TYPE_VOID
    if return_type == EXTERNAL_RETURN_INT:
        return LIR_TYPE_I32
    if return_type == EXTERNAL_RETURN_BOOL:
        return LIR_TYPE_I1
    if return_type == EXTERNAL_RETURN_FLOAT:
        return LIR_TYPE_F64
    if return_type == EXTERNAL_RETURN_STRING:
        return LIR_TYPE_PTR
    return LIR_TYPE_PTR

def llvm_lir_external_call_name(program: LirProgram, record_offset: int, symbol: int) -> str:
    if symbol == LIR_EXTERNAL_BASE + EXTERNAL_ID_LEN:
        # len 按操作数类型分派：字符串数 rune 数，其余读 dynarray 长度
        let operand_type = LIR_TYPE_I32
        if program.records[record_offset + 7] > 1 and llvm_lir_operand_kind(program, record_offset,
            1) == LIR_OPERAND_VALUE:
            operand_type = llvm_lir_value_type(program, program.records[record_offset + 1],
                llvm_lir_operand_value(program, record_offset, 1))
        if operand_type == LIR_TYPE_STR:
            return "@__c_utf8_rune_count"
        if operand_type == LIR_TYPE_BYTES:
            return "@__c_bytes_length"
        if operand_type == LIR_TYPE_DICT:
            return "@dream_dict_size_int_int"
        if operand_type == LIR_TYPE_LIST_PTR:
            return "@len_dynarray_ptr"
        return "@len_dynarray_i32"
    if symbol != LIR_EXTERNAL_BASE + EXTERNAL_ID_APPEND:
        return llvm_lir_external_name(symbol)
    let operand_type = LIR_TYPE_I32
    if program.records[record_offset + 7] > 2 and llvm_lir_operand_kind(program, record_offset, 2) == LIR_OPERAND_VALUE:
        operand_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program,
            record_offset, 2))
    if llvm_lir_is_pointer_like(operand_type):
        return "@append_ptr"
    if operand_type == LIR_TYPE_F64:
        return "@append_f64"
    if operand_type == LIR_TYPE_I1:
        return "@append_i32"
    return "@append_i32"

def llvm_lir_string_global_name(record_offset: int) -> str:
    return llvm_lir_join_int("@.dm_str_", record_offset, "")

def llvm_emit_hex_byte(value: int, output: Buffer):
    let digits = "0123456789ABCDEF"
    append(output, "\\")
    append(output, digits[(value / 16) % 16:(value / 16) % 16 + 1])
    append(output, digits[value % 16:value % 16 + 1])

def llvm_lir_is_string_literal(source_start: int, source_end: int) -> bool:
    if source_start < 0 or source_end < source_start or source_end > len(llvm_lir_source):
        return false
    return true

# 与宿主语义对齐：返回转义字符的解码值；未知转义返回 -1（原样保留）
def llvm_lir_escape_value(escaped: int) -> int:
    if escaped == 110:
        return 10
    if escaped == 116:
        return 9
    if escaped == 114:
        return 13
    if escaped == 48:
        return 0
    if escaped == 92:
        return 92
    if escaped == 34:
        return 34
    if escaped == 39:
        return 39
    return -1

# 统计转义解码后的内容字节数
def llvm_lir_decoded_content_length(source_start: int, source_end: int) -> int:
    let index = source_start
    let count = 0
    while index < source_end:
        if (
            ord(llvm_lir_source[index]) == 92 and
            index + 1 < source_end and
            llvm_lir_escape_value(ord(llvm_lir_source[index + 1])) >= 0
        ):
            index = index + 2
            count = count + 1
        else:
            let rune_value = ord(llvm_lir_source[index])
            if rune_value >= 0x10000:
                count = count + 4
            elif rune_value >= 0x800:
                count = count + 3
            elif rune_value >= 0x80:
                count = count + 2
            else:
                count = count + 1
            index = index + 1
    return count

def llvm_emit_rune_utf8(value: int, output: Buffer):
    # rune 码 → UTF-8 字节序列（LLVM 字符串常量按字节存储）
    if value < 0x80:
        llvm_emit_hex_byte(value, output)
    elif value < 0x800:
        llvm_emit_hex_byte(0xC0 + value / 64, output)
        llvm_emit_hex_byte(0x80 + value % 64, output)
    elif value < 0x10000:
        llvm_emit_hex_byte(0xE0 + value / 0x1000, output)
        llvm_emit_hex_byte(0x80 + (value / 64) % 64, output)
        llvm_emit_hex_byte(0x80 + value % 64, output)
    else:
        llvm_emit_hex_byte(0xF0 + value / 0x40000, output)
        llvm_emit_hex_byte(0x80 + (value / 0x1000) % 64, output)
        llvm_emit_hex_byte(0x80 + (value / 64) % 64, output)
        llvm_emit_hex_byte(0x80 + value % 64, output)

def llvm_emit_string_global(record_id: int, source_start: int, source_end: int, output: Buffer):
    let content_length = llvm_lir_decoded_content_length(source_start, source_end)
    append(output, llvm_lir_string_global_name(record_id))
    append(output, " = private unnamed_addr constant [")
    append(output, content_length + 1)
    append(output, " x i8] c\"")
    let index = source_start
    while index < source_end:
        let current = ord(llvm_lir_source[index])
        let is_escape = current == 92 and index + 1 < source_end
        let escaped_value = -1
        if is_escape:
            escaped_value = llvm_lir_escape_value(ord(llvm_lir_source[index + 1]))
        if escaped_value >= 0:
            llvm_emit_hex_byte(escaped_value, output)
            index = index + 2
        else:
            llvm_emit_rune_utf8(current, output)
            index = index + 1
    append(output, "\\00\"\n")

def llvm_lir_print_name(program: LirProgram, record_offset: int) -> str:
    let value_type = LIR_TYPE_PTR
    if program.records[record_offset + 7] > 0:
        let operand_kind = llvm_lir_operand_kind(program, record_offset, 0)
        if operand_kind == LIR_OPERAND_VALUE:
            value_type = llvm_lir_value_type(program, program.records[record_offset + 1],
                llvm_lir_operand_value(program, record_offset, 0))
        elif operand_kind == LIR_OPERAND_IMMEDIATE:
            value_type = LIR_TYPE_I32
    if value_type == LIR_TYPE_I32:
        return "@dream_print_int"
    if value_type == LIR_TYPE_F64:
        return "@dream_print_float"
    if value_type == LIR_TYPE_I1:
        return "@dream_print_bool"
    return "@dream_print_string"

def llvm_lir_prepare_func_cache(program: LirProgram):
    let maximum_function = -1
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        let func_index = program.records[offset + 1]
        if func_index > maximum_function:
            maximum_function = func_index
        record_id = record_id + 1
    # 原地扩缩缓存，不做全局列表重绑定（自举发射器对该形态有误译）
    llvm_lir_resize_int_list(llvm_lir_func_record_cache, maximum_function + 1, -1)
    llvm_lir_resize_int_list(llvm_lir_func_terminator_start_cache, maximum_function + 1, -1)
    llvm_lir_resize_int_list(llvm_lir_func_terminator_count_cache, maximum_function + 1, 0)
    record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION:
            let func_index = program.records[offset + 1]
            if func_index >= 0 and func_index < len(llvm_lir_func_record_cache):
                llvm_lir_func_record_cache[func_index] = record_id
        elif program.records[offset] == LIR_RECORD_TERMINATOR:
            let func_index = program.records[offset + 1]
            if func_index >= 0 and func_index < len(llvm_lir_func_terminator_start_cache):
                if llvm_lir_func_terminator_start_cache[func_index] < 0:
                    llvm_lir_func_terminator_start_cache[func_index] = len(llvm_lir_terminator_record_cache)
                append(llvm_lir_terminator_record_cache, record_id)
                let terminator_count = llvm_lir_func_terminator_count_cache[func_index] + 1
                llvm_lir_func_terminator_count_cache[func_index] = terminator_count
        record_id = record_id + 1

def llvm_lir_operand_kind(program: LirProgram, record_offset: int, operand_index: int) -> int:
    let operand_start = program.records[record_offset + 6]
    return program.values[lir_value_offset(operand_start + operand_index)]

def llvm_lir_operand_value(program: LirProgram, record_offset: int, operand_index: int) -> int:
    let operand_start = program.records[record_offset + 6]
    return program.values[lir_value_offset(operand_start + operand_index) + 1]

def llvm_lir_value_type(program: LirProgram, func_index: int, value: int) -> int:
    return lir_value_type_in_function(program.records, func_index, value)

def llvm_lir_has_value(program: LirProgram, func_index: int, value: int) -> bool:
    return lir_value_exists(program.records, func_index, value)

def llvm_lir_zero(type_tag: int) -> str:
    if type_tag == LIR_TYPE_VOID:
        return ""
    if llvm_lir_is_pointer_like(type_tag):
        return "null"
    if type_tag == LIR_TYPE_F64:
        return "0.000000e+00"
    return "0"

def llvm_emit_zero_definition(type_tag: int, result_name: str, output: Buffer):
    append(output, "  ")
    append(output, result_name)
    if llvm_lir_is_pointer_like(type_tag):
        append(output, " = inttoptr i32 0 to i8*\n")
    elif type_tag == LIR_TYPE_F64:
        append(output, " = fadd double 0.000000e+00, 0.000000e+00\n")
    else:
        append(output, " = add ")
        append(output, llvm_lir_type(type_tag))
        append(output, " 0, 0\n")

def llvm_lir_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int) -> str:
    let operand_kind = llvm_lir_operand_kind(program, record_offset, operand_index)
    let operand_value = llvm_lir_operand_value(program, record_offset, operand_index)
    if operand_kind == LIR_OPERAND_VALUE:
        let func_index = program.records[record_offset + 1]
        if not llvm_lir_has_value(program, func_index, operand_value):
            return llvm_lir_zero(expected_type)
        return llvm_lir_value_name(operand_value)
    if operand_kind == LIR_OPERAND_BLOCK:
        return llvm_lir_block_ref_name(operand_value)
    if operand_kind == LIR_OPERAND_SYMBOL:
        if llvm_lir_is_external_symbol(operand_value):
            return llvm_lir_external_name(operand_value)
        return llvm_lir_func_name(operand_value)
    if operand_kind == LIR_OPERAND_TYPE:
        return llvm_lir_type(operand_value)
    if llvm_lir_is_pointer_like(expected_type):
        if operand_value == 0:
            return "null"
        return llvm_lir_join_int("inttoptr (i32 ", operand_value, " to i8*)")
    if expected_type == LIR_TYPE_I1:
        if operand_value == 0:
            return "0"
        return "1"
    return llvm_lir_join_int("", operand_value, "")

def llvm_emit_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int,
    output: Buffer):
    let operand_kind = llvm_lir_operand_kind(program, record_offset, operand_index)
    let operand_value = llvm_lir_operand_value(program, record_offset, operand_index)
    if operand_kind == LIR_OPERAND_VALUE:
        let func_index = program.records[record_offset + 1]
        if not llvm_lir_has_value(program, func_index, operand_value):
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
        if llvm_lir_is_external_symbol(operand_value):
            append(output, llvm_lir_external_name(operand_value))
            return
        append(output, "@dm_func_")
        append(output, operand_value)
        return
    if operand_kind == LIR_OPERAND_TYPE:
        append(output, llvm_lir_type(operand_value))
        return
    if llvm_lir_is_pointer_like(expected_type):
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
    if runtime_id == 2:
        return "@create_dynarray_i32"
    if runtime_id == 3:
        if result_type == LIR_TYPE_I32:
            return "@get_dynarray_i32"
        return "@get_pointer"
    if runtime_id == 6:
        return "@slice_dynarray_i32"
    return "@llvm.trap"

def llvm_emit_dynamic_truthy(program: LirProgram, record_offset: int, operand_index: int, output: Buffer) -> str:
    let operand_type = llvm_lir_binary_operand_type(program, record_offset, operand_index)
    let result_name = llvm_lir_join_int("%dynamic_truthy_", record_offset + operand_index, "")
    append(output, "  ")
    append(output, result_name)
    append(output, " = ")
    if operand_type == LIR_TYPE_I1:
        append(output, "add i1 0, ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
    elif operand_type == LIR_TYPE_I32:
        append(output, "icmp ne i32 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, ", 0")
    elif operand_type == LIR_TYPE_F64:
        append(output, "fcmp one double ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, ", 0.000000e+00")
    else:
        append(output, "icmp ne i8* ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, ", null")
    append(output, "\n")
    return result_name

def llvm_emit_dynamic_i64(program: LirProgram, record_offset: int, operand_index: int, output: Buffer) -> str:
    let operand_type = llvm_lir_binary_operand_type(program, record_offset, operand_index)
    let result_name = llvm_lir_join_int("%dynamic_i64_", record_offset + operand_index, "")
    append(output, "  ")
    append(output, result_name)
    append(output, " = ")
    if operand_type == LIR_TYPE_I1:
        append(output, "zext i1 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
        append(output, " to i64")
    elif operand_type == LIR_TYPE_I32:
        append(output, "sext i32 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, " to i64")
    elif operand_type == LIR_TYPE_F64:
        append(output, "fptosi double ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, " to i64")
    else:
        append(output, "ptrtoint i8* ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, " to i64")
    append(output, "\n")
    return result_name

def llvm_emit_dynamic_membership(program: LirProgram, offset: int, left_type: int, right_type: int,
    output: Buffer, result_name: str) -> bool:
    if right_type in [LIR_TYPE_LIST, LIR_TYPE_BYTES]:
        if left_type == LIR_TYPE_F64:
            let match_name = llvm_lir_join_int("%dynamic_membership_match_", offset, "")
            append(output, "  ")
            append(output, match_name)
            append(output, " = call i32 @contains_dynarray_f64(i8* ")
            llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
            append(output, ", double ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_F64, output)
            append(output, ")\n  ")
            append(output, result_name)
            append(output, " = icmp ne i32 ")
            append(output, match_name)
            append(output, ", 0\n")
            return true

        if left_type not in [LIR_TYPE_I1, LIR_TYPE_I32]:
            return false

        let needle_name = llvm_lir_join_int("%dynamic_membership_needle_", offset, "")
        if left_type == LIR_TYPE_I1:
            append(output, "  ")
            append(output, needle_name)
            append(output, " = zext i1 ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_I1, output)
            append(output, " to i32\n")

        let match_name = llvm_lir_join_int("%dynamic_membership_match_", offset, "")
        append(output, "  ")
        append(output, match_name)
        append(output, " = call i32 @contains_dynarray_i32(i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ", i32 ")
        if left_type == LIR_TYPE_I1:
            append(output, needle_name)
        else:
            llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
        append(output, ")\n  ")
        append(output, result_name)
        append(output, " = icmp ne i32 ")
        append(output, match_name)
        append(output, ", 0\n")
        return true

    if right_type == LIR_TYPE_LIST_PTR and left_type == LIR_TYPE_STR:
        let match_name = llvm_lir_join_int("%dynamic_membership_match_", offset, "")
        append(output, "  ")
        append(output, match_name)
        append(output, " = call i32 @contains_dynarray_str(i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ")\n  ")
        append(output, "  ")
        append(output, result_name)
        append(output, " = icmp ne i32 ")
        append(output, match_name)
        append(output, ", 0\n")
        return true

    return false

def llvm_emit_dynamic_boolean(program: LirProgram, offset: int, operator: int, output: Buffer, result_name: str):
    let left_type = llvm_lir_binary_operand_type(program, offset, 1)
    let right_type = llvm_lir_binary_operand_type(program, offset, 2)
    if operator in [IR_OPERATOR_AND, IR_OPERATOR_OR]:
        let left_truthy = llvm_emit_dynamic_truthy(program, offset, 1, output)
        let right_truthy = llvm_emit_dynamic_truthy(program, offset, 2, output)
        let instruction = "and"
        if operator == IR_OPERATOR_OR:
            instruction = "or"
        append(output, "  ")
        append(output, result_name)
        append(output, " = ")
        append(output, instruction)
        append(output, " i1 ")
        append(output, left_truthy)
        append(output, ", ")
        append(output, right_truthy)
        append(output, "\n")
        return
    if operator == IR_OPERATOR_IN and llvm_emit_dynamic_membership(program, offset, left_type, right_type, output,
        result_name):
        return
    if operator == IR_OPERATOR_IN and left_type == LIR_TYPE_STR and right_type == LIR_TYPE_STR:
        append(output, "  %dynamic_find_")
        append(output, offset)
        append(output, " = call i32 @string_find(i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ")\n  ")
        append(output, result_name)
        append(output, " = icmp sge i32 %dynamic_find_")
        append(output, offset)
        append(output, ", 0\n")
        return
    if llvm_lir_is_pointer_like(left_type) and llvm_lir_is_pointer_like(right_type):
        append(output, "  %dynamic_compare_")
        append(output, offset)
        append(output, " = call i32 @string_compare(i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ")\n")
        append(output, "  ")
        append(output, result_name)
        append(output, " = icmp ")
        if operator == IR_OPERATOR_LT:
            append(output, "slt")
        elif operator == IR_OPERATOR_GT:
            append(output, "sgt")
        elif operator == IR_OPERATOR_LE:
            append(output, "sle")
        elif operator == IR_OPERATOR_GE:
            append(output, "sge")
        elif operator == IR_OPERATOR_EQ:
            append(output, "eq")
        else:
            append(output, "ne")
        append(output, " i32 %dynamic_compare_")
        append(output, offset)
        append(output, ", 0\n")
        return
    let left_integer = llvm_emit_dynamic_i64(program, offset, 1, output)
    let right_integer = llvm_emit_dynamic_i64(program, offset, 2, output)
    append(output, "  ")
    append(output, result_name)
    append(output, " = icmp ")
    if operator == IR_OPERATOR_LT:
        append(output, "slt")
    elif operator == IR_OPERATOR_GT:
        append(output, "sgt")
    elif operator == IR_OPERATOR_LE:
        append(output, "sle")
    elif operator == IR_OPERATOR_GE:
        append(output, "sge")
    elif operator == IR_OPERATOR_EQ:
        append(output, "eq")
    else:
        append(output, "ne")
    append(output, " i64 ")
    append(output, left_integer)
    append(output, ", ")
    append(output, right_integer)
    append(output, "\n")

def llvm_emit_dynamic_unary(program: LirProgram, offset: int, output: Buffer, result_name: str, result_type: int):
    let operator = llvm_lir_operand_value(program, offset, 0)
    let operand_type = llvm_lir_binary_operand_type(program, offset, 1)
    if operator == IR_OPERATOR_NOT:
        let boolean_name = result_name
        if result_type != LIR_TYPE_I1:
            boolean_name = llvm_lir_join_int("%dynamic_unary_bool_", offset, "")
        append(output, "  ")
        append(output, boolean_name)
        append(output, " = ")
        if operand_type == LIR_TYPE_I1:
            append(output, "xor i1 1, ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_I1, output)
        elif operand_type == LIR_TYPE_I32:
            append(output, "icmp eq i32 ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
            append(output, ", 0")
        elif operand_type == LIR_TYPE_F64:
            append(output, "fcmp oeq double ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_F64, output)
            append(output, ", 0.000000e+00")
        else:
            append(output, "icmp eq i8* ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
            append(output, ", null")
        append(output, "\n")
        if result_type == LIR_TYPE_I1:
            return
        if llvm_lir_is_pointer_like(result_type):
            let integer_name = llvm_lir_join_int("%dynamic_unary_int_", offset, "")
            append(output, "  ")
            append(output, integer_name)
            append(output, " = zext i1 ")
            append(output, boolean_name)
            append(output, " to i32\n  ")
            append(output, result_name)
            append(output, " = inttoptr i32 ")
            append(output, integer_name)
            append(output, " to i8*\n")
            return
        if result_type == LIR_TYPE_I32:
            append(output, "  ")
            append(output, result_name)
            append(output, " = zext i1 ")
            append(output, boolean_name)
            append(output, " to i32\n")
            return
        return
    if operator == IR_OPERATOR_POS:
        if result_type == operand_type:
            append(output, "  ")
            append(output, result_name)
            append(output, " = getelementptr i8, i8* ")
            llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
            append(output, ", i32 0\n")
        return
    if operator == IR_OPERATOR_NEG and result_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, result_name)
        append(output, " = sub i32 0, ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
        append(output, "\n")

def llvm_emit_dynamic_binary(program: LirProgram, offset: int, output: Buffer, result_name: str,
    result_type: int):
    let operator = llvm_lir_operand_value(program, offset, 0)
    let left_type = llvm_lir_binary_operand_type(program, offset, 1)
    let right_type = llvm_lir_binary_operand_type(program, offset, 2)
    if result_type == LIR_TYPE_I1:
        llvm_emit_dynamic_boolean(program, offset, operator, output, result_name)
        return
    if operator == IR_OPERATOR_ADD and llvm_lir_is_string(left_type) and llvm_lir_is_string(right_type):
        append(output, "  ")
        append(output, result_name)
        append(output, " = call i8* @string_concat(i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ")\n")
        return
    if operator == IR_OPERATOR_ADD and left_type == LIR_TYPE_LIST and right_type == LIR_TYPE_LIST:
        append(output, "  ")
        append(output, result_name)
        append(output, " = call i8* @concat_dynarray_i32(i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ")\n")
        return
    if operator == IR_OPERATOR_ADD and left_type == LIR_TYPE_LIST_PTR and right_type == LIR_TYPE_LIST_PTR:
        append(output, "  ")
        append(output, result_name)
        append(output, " = call i8* @concat_dynarray_ptr(i8* ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
        append(output, ", i8* ")
        llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
        append(output, ")\n")
        return
    if llvm_lir_is_pointer_like(result_type):
        let boolean_name = llvm_lir_join_int("%dynamic_bool_", offset, "")
        llvm_emit_dynamic_boolean(program, offset, operator, output, boolean_name)
        let integer_name = llvm_lir_join_int("%dynamic_bool_int_", offset, "")
        append(output, "  ")
        append(output, integer_name)
        append(output, " = zext i1 ")
        append(output, boolean_name)
        append(output, " to i32\n  ")
        append(output, result_name)
        append(output, " = inttoptr i32 ")
        append(output, integer_name)
        append(output, " to i8*\n")
        return
    let left_integer = llvm_emit_dynamic_i64(program, offset, 1, output)
    let right_integer = llvm_emit_dynamic_i64(program, offset, 2, output)
    let instruction = "add"
    if operator == IR_OPERATOR_SUB:
        instruction = "sub"
    elif operator == IR_OPERATOR_MUL:
        instruction = "mul"
    elif operator == IR_OPERATOR_DIV:
        instruction = "sdiv"
    elif operator == IR_OPERATOR_MOD:
        instruction = "srem"
    let integer_result = llvm_lir_join_int("%dynamic_integer_result_", offset, "")
    append(output, "  ")
    append(output, integer_result)
    append(output, " = ")
    append(output, instruction)
    append(output, " i64 ")
    append(output, left_integer)
    append(output, ", ")
    append(output, right_integer)
    append(output, "\n")
    if result_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, result_name)
        append(output, " = trunc i64 ")
        append(output, integer_result)
        append(output, " to i32\n")
    elif result_type == LIR_TYPE_F64:
        append(output, "  ")
        append(output, result_name)
        append(output, " = sitofp i64 ")
        append(output, integer_result)
        append(output, " to double\n")

def llvm_emit_container_create(program: LirProgram, offset: int, output: Buffer, result_name: str):
    let is_ptr_list = program.records[offset + 4] == LIR_TYPE_LIST_PTR
    let operand_count = program.records[offset + 7]
    let capacity = operand_count - 1
    if operand_count > 0 and llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_IMMEDIATE:
        capacity = llvm_lir_operand_value(program, offset, 0)
    append(output, "  ")
    append(output, result_name)
    append(output, " = call i8* @")
    if is_ptr_list:
        append(output, "create_dynarray_ptr(i32 ")
    else:
        append(output, "create_dynarray_i32(i32 ")
    append(output, capacity)
    append(output, ")\n")
    let operand_index = 1
    while operand_index < operand_count:
        let operand_type = llvm_lir_binary_operand_type(program, offset, operand_index)
        let integer_name = ""
        if operand_type == LIR_TYPE_I1:
            integer_name = llvm_lir_join_int("%container_i32_", offset + operand_index, "")
            append(output, "  ")
            append(output, integer_name)
            append(output, " = zext i1 ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_I1, output)
            append(output, " to i32\n")
        append(output, "  call void @")
        if operand_type == LIR_TYPE_F64:
            append(output, "append_f64(i8* ")
            append(output, result_name)
            append(output, ", double ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_F64, output)
        elif llvm_lir_is_pointer_like(operand_type):
            if is_ptr_list:
                append(output, "append_ptr(i8* ")
            else:
                append(output, "append_pointer(i8* ")
            append(output, result_name)
            append(output, ", i8* ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_PTR, output)
        else:
            append(output, "append_i32(i8* ")
            append(output, result_name)
            append(output, ", i32 ")
            if operand_type == LIR_TYPE_I1:
                append(output, integer_name)
            else:
                llvm_emit_operand(program, offset, operand_index, LIR_TYPE_I32, output)
        append(output, ")\n")
        operand_index = operand_index + 1

def llvm_emit_struct_create(program: LirProgram, offset: int, output: Buffer, result_name: str):
    let operand_count = program.records[offset + 7]
    let capacity = 0
    let capacity_index = 0
    while capacity_index < operand_count:
        let field_type = llvm_lir_binary_operand_type(program, offset, capacity_index)
        if field_type in [LIR_TYPE_I32, LIR_TYPE_I1]:
            capacity = capacity + 1
        else:
            capacity = capacity + 2
        capacity_index = capacity_index + 1
    append(output, "  ")
    append(output, result_name)
    append(output, " = call i8* @create_dynarray_i32(i32 ")
    append(output, capacity)
    append(output, ")\n")
    let operand_index = 0
    while operand_index < operand_count:
        let operand_type = llvm_lir_binary_operand_type(program, offset, operand_index)
        let integer_name = ""
        if operand_type == LIR_TYPE_I1:
            integer_name = llvm_lir_join_int("%struct_i32_", offset + operand_index, "")
            append(output, "  ")
            append(output, integer_name)
            append(output, " = zext i1 ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_I1, output)
            append(output, " to i32\n")
        append(output, "  call void @")
        if operand_type == LIR_TYPE_F64:
            append(output, "append_f64(i8* ")
            append(output, result_name)
            append(output, ", double ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_F64, output)
        elif llvm_lir_is_pointer_like(operand_type):
            append(output, "append_pointer(i8* ")
            append(output, result_name)
            append(output, ", i8* ")
            llvm_emit_operand(program, offset, operand_index, LIR_TYPE_PTR, output)
        else:
            append(output, "append_i32(i8* ")
            append(output, result_name)
            append(output, ", i32 ")
            if operand_type == LIR_TYPE_I1:
                append(output, integer_name)
            else:
                llvm_emit_operand(program, offset, operand_index, LIR_TYPE_I32, output)
        append(output, ")\n")
        operand_index = operand_index + 1

def llvm_lir_dict_func_name(key_type: int, value_type: int, operation: int) -> str:
    if operation == 1:
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_I32:
            return "@dream_dict_create_str_int"
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_STR:
            return "@dream_dict_create_str_str"
        if key_type == LIR_TYPE_I32 and value_type == LIR_TYPE_I32:
            return "@dream_dict_create_int_int"
        return "@dream_dict_create_int_str"
    if operation == 2:
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_I32:
            return "@dict_set_str_int"
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_STR:
            return "@dict_set_str_str"
        if key_type == LIR_TYPE_I32 and value_type == LIR_TYPE_I32:
            return "@dict_set_int_int"
        return "@dict_set_int_str"
    if operation == 3:
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_I32:
            return "@dream_dict_get_str_int"
        if key_type == LIR_TYPE_STR and value_type == LIR_TYPE_STR:
            return "@dream_dict_get_str_str"
        if key_type == LIR_TYPE_I32 and value_type == LIR_TYPE_I32:
            return "@dream_dict_get_int_int"
        return "@dream_dict_get_int_str"
    return "@llvm.trap"

def llvm_emit_dict_create(program: LirProgram, offset: int, output: Buffer, result_name: str):
    let operand_count = program.records[offset + 7]
    let key_type = LIR_TYPE_I32
    let value_type = LIR_TYPE_I32
    if operand_count > 1:
        key_type = llvm_lir_binary_operand_type(program, offset, 1)
    if operand_count > 2:
        value_type = llvm_lir_binary_operand_type(program, offset, 2)
    append(output, "  ")
    append(output, result_name)
    append(output, " = call i8* ")
    append(output, llvm_lir_dict_func_name(key_type, value_type, 1))
    append(output, "(i32 ")
    if operand_count > 0:
        llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
    else:
        append(output, "0")
    append(output, ")\n")
    let operand_index = 1
    while operand_index + 1 < operand_count:
        append(output, "  call void ")
        append(output, llvm_lir_dict_func_name(key_type, value_type, 2))
        append(output, "(i8* ")
        append(output, result_name)
        append(output, ", ")
        append(output, llvm_lir_type(key_type))
        append(output, " ")
        llvm_emit_operand(program, offset, operand_index, key_type, output)
        append(output, ", ")
        append(output, llvm_lir_type(value_type))
        append(output, " ")
        llvm_emit_operand(program, offset, operand_index + 1, value_type, output)
        append(output, ")\n")
        operand_index = operand_index + 2

def llvm_emit_dict_get(program: LirProgram, offset: int, output: Buffer, result_name: str, result_type: int):
    let key_type = LIR_TYPE_I32
    if program.records[offset + 7] > 1:
        key_type = llvm_lir_binary_operand_type(program, offset, 1)
    let value_type = result_type
    if value_type not in [LIR_TYPE_I32, LIR_TYPE_STR]:
        value_type = LIR_TYPE_I32
    append(output, "  ")
    append(output, result_name)
    append(output, " = call ")
    append(output, llvm_lir_type(value_type))
    append(output, " ")
    append(output, llvm_lir_dict_func_name(key_type, value_type, 3))
    append(output, "(i8* ")
    llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
    append(output, ", ")
    append(output, llvm_lir_type(key_type))
    append(output, " ")
    if program.records[offset + 7] > 1:
        llvm_emit_operand(program, offset, 1, key_type, output)
    else:
        append(output, llvm_lir_zero(key_type))
    append(output, ")\n")

def llvm_emit_tuple_get(program: LirProgram, offset: int, output: Buffer, result_name: str, result_type: int):
    let operand_count = program.records[offset + 7]
    if operand_count < 2:
        append(output, "  ")
        append(output, result_name)
        append(output, " = inttoptr i32 0 to i8*\n")
        return
    let base_type = llvm_lir_binary_operand_type(program, offset, 0)
    let base_name = llvm_lir_join_int("%tuple_base_", offset, "")
    if not llvm_lir_is_pointer_like(base_type):
        if base_type == LIR_TYPE_I1:
            let base_integer = llvm_lir_join_int("%tuple_base_int_", offset, "")
            append(output, "  ")
            append(output, base_integer)
            append(output, " = zext i1 ")
            llvm_emit_operand(program, offset, 0, LIR_TYPE_I1, output)
            append(output, " to i32\n")
            append(output, "  ")
            append(output, base_name)
            append(output, " = inttoptr i32 ")
            append(output, base_integer)
            append(output, " to i8*\n")
        elif base_type == LIR_TYPE_I32:
            append(output, "  ")
            append(output, base_name)
            append(output, " = inttoptr i32 ")
            llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
            append(output, " to i8*\n")
        else:
            append(output, "  ")
            append(output, base_name)
            append(output, " = inttoptr i32 0 to i8*\n")
    append(output, "  ")
    if result_type == LIR_TYPE_I1:
        let bool_integer = llvm_lir_join_int("%tuple_bool_", offset, "")
        append(output, bool_integer)
        append(output, " = call i32 @get_dynarray_i32(i8* ")
        if llvm_lir_is_pointer_like(base_type):
            llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
        else:
            append(output, base_name)
        append(output, ", i32 ")
        llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
        append(output, ")\n")
        append(output, "  ")
        append(output, result_name)
        append(output, " = trunc i32 ")
        append(output, bool_integer)
        append(output, " to i1\n")
        return
    append(output, result_name)
    if result_type == LIR_TYPE_I32:
        append(output, " = call i32 @get_dynarray_i32(i8* ")
    elif result_type == LIR_TYPE_F64:
        append(output, " = call double @get_f64(i8* ")
    else:
        append(output, " = call i8* @get_pointer(i8* ")
    if llvm_lir_is_pointer_like(base_type):
        llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
    else:
        append(output, base_name)
    append(output, ", i32 ")
    llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
    append(output, ")\n")

def llvm_lir_find_func_record(program: LirProgram, func_index: int) -> int:
    if func_index >= 0 and func_index < len(llvm_lir_func_record_cache):
        return llvm_lir_func_record_cache[func_index]
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION and program.records[offset + 1] == func_index:
            return record_id
        record_id = record_id + 1
    return -1

def llvm_lir_func_parameter_type(program: LirProgram, func_index: int, parameter_index: int) -> int:
    let record_id = llvm_lir_find_func_record(program, func_index)
    if record_id < 0:
        return LIR_TYPE_DYNAMIC
    let offset = lir_record_offset(record_id)
    if parameter_index < 0 or parameter_index >= program.records[offset + 9]:
        return LIR_TYPE_DYNAMIC
    let value_id = program.records[offset + 8] + parameter_index
    let value_offset = lir_value_offset(value_id)
    if program.values[value_offset] != LIR_OPERAND_TYPE:
        return LIR_TYPE_DYNAMIC
    return program.values[value_offset + 1]

def llvm_emit_runtime_declarations(output: Buffer):
    append(output, "declare void @llvm.trap()\n")
    append(output, "declare void @__c_process_set_args(i32, i8**)\n")
    append(output, "declare i8* @create_dynarray_i32(i32)\n")
    append(output, "declare void @append_i32(i8*, i32)\n")
    append(output, "declare void @append_pointer(i8*, i8*)\n")
    append(output, "declare i32 @get_dynarray_i32(i8*, i32)\n")
    append(output, "declare i32 @contains_dynarray_i32(i8*, i32)\n")
    append(output, "declare i32 @contains_dynarray_f64(i8*, double)\n")
    append(output, "declare double @get_f64(i8*, i32)\n")
    append(output, "declare void @set_dynarray_i32(i8*, i32, i32)\n")
    append(output, "declare i8* @get_pointer(i8*, i32)\n")
    append(output, "declare i8* @slice_dynarray_i32(i8*, i32, i32)\n")
    append(output, "declare i8* @concat_dynarray_i32(i8*, i8*)\n")
    append(output, "declare i8* @create_dynarray_ptr(i32)\n")
    append(output, "declare void @append_ptr(i8*, i8*)\n")
    append(output, "declare i8* @get_dynarray_ptr(i8*, i32)\n")
    append(output, "declare i32 @contains_dynarray_str(i8*, i8*)\n")
    append(output, "declare void @set_dynarray_ptr(i8*, i32, i8*)\n")
    append(output, "declare i32 @len_dynarray_ptr(i8*)\n")
    append(output, "declare i8* @slice_dynarray_ptr(i8*, i32, i32)\n")
    append(output, "declare i8* @concat_dynarray_ptr(i8*, i8*)\n")
    append(output, "declare i8* @string_substring(i8*, i32, i32)\n")

def llvm_emit_func_signature(program: LirProgram, record_id: int, output: Buffer):
    # 写函数 LLVM 签名 "return_type (param_types...)"，供函数指针表 bitcast 使用
    let func_offset = lir_record_offset(record_id)
    append(output, llvm_lir_type(llvm_lir_func_return_type(program, func_offset)))
    append(output, " (")
    let scan_record = record_id + 1
    let parameter_index = 0
    let scanning_parameters = true
    while scanning_parameters:
        if scan_record >= lir_record_count(program.records):
            scanning_parameters = false
        elif program.records[lir_record_offset(scan_record)] != LIR_RECORD_PARAMETER:
            scanning_parameters = false
        else:
            if parameter_index > 0:
                append(output, ", ")
            let parameter_offset = lir_record_offset(scan_record)
            append(output, llvm_lir_type(program.records[parameter_offset + 4]))
            parameter_index = parameter_index + 1
            scan_record = scan_record + 1
    append(output, ")")

def llvm_emit_func_table(program: LirProgram, output: Buffer):
    # 函数指针表：@dm_func_table = [ptr @dm_func_N, ...]
    let func_count = len(llvm_lir_func_record_cache)
    append(output, "@dm_func_table = private global [")
    append(output, func_count)
    append(output, " x ptr] [")
    let func_index = 0
    while func_index < func_count:
        if func_index > 0:
            append(output, ", ")
        let record_id = llvm_lir_find_func_record(program, func_index)
        if record_id >= 0:
            if program.records[lir_record_offset(record_id) + 3] == LIR_FUNCTION_ENTRY:
                append(output, "ptr null")
            else:
                append(output, "ptr @dm_func_")
                append(output, func_index)
        else:
            append(output, "ptr null")
        func_index = func_index + 1
    append(output, "]\n")
    append(output, "declare i32 @string_compare(i8*, i8*)\n")
    append(output, "declare i8* @dream_dict_create_int_int(i32)\n")
    append(output, "declare i8* @dream_dict_create_int_str(i32)\n")
    append(output, "declare i8* @dream_dict_create_str_int(i32)\n")
    append(output, "declare i8* @dream_dict_create_str_str(i32)\n")
    append(output, "declare void @dict_set_int_int(i8*, i32, i32)\n")
    append(output, "declare void @dict_set_int_str(i8*, i32, i8*)\n")
    append(output, "declare void @dict_set_str_int(i8*, i8*, i32)\n")
    append(output, "declare void @dict_set_str_str(i8*, i8*, i8*)\n")
    append(output, "declare i32 @dream_dict_get_int_int(i8*, i32)\n")
    append(output, "declare i8* @dream_dict_get_int_str(i8*, i32)\n")
    append(output, "declare i32 @dream_dict_get_str_int(i8*, i8*)\n")
    append(output, "declare i8* @dream_dict_get_str_str(i8*, i8*)\n")

def llvm_emit_external_declarations(output: Buffer):
    let external_id = EXTERNAL_ID_BASE
    while external_id < EXTERNAL_ID_BASE + EXTERNAL_COUNT:
        if external_has_declaration(external_id):
            append(output, "declare ")
            append(output, llvm_lir_type(llvm_lir_external_type(external_id)))
            append(output, " ")
            append(output, llvm_lir_external_name(LIR_EXTERNAL_BASE + external_id))
            append(output, "(...)\n")
        external_id = external_id + 1
    append(output, "declare void @append_f64(i8*, double)\n")

def llvm_emit_string_globals(program: LirProgram, output: Buffer):
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if (
            program.records[offset] == LIR_RECORD_INSTRUCTION and
            program.records[offset + 3] == LIR_OP_CONST and
            llvm_lir_is_string(program.records[offset + 4])
        ):
            let source_start = program.records[offset + 12]
            let source_end = program.records[offset + 13]
            if source_start >= 0 and source_end >= source_start:
                llvm_emit_string_global(record_id, source_start, source_end, output)
        record_id = record_id + 1

def llvm_lir_render_call_arguments_from(program: LirProgram, record_offset: int, first_operand: int, output: Buffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = first_operand
    let rendered_count = 0
    while operand_index < operand_count:
        if rendered_count > 0:
            append(output, ", ")
        let operand_type = LIR_TYPE_DYNAMIC
        if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
            operand_type = llvm_lir_value_type(program, program.records[record_offset + 1],
                llvm_lir_operand_value(program, record_offset, operand_index))
        elif llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_IMMEDIATE:
            operand_type = LIR_TYPE_I32
        append(output, llvm_lir_type(operand_type))
        append(output, " ")
        llvm_emit_operand(program, record_offset, operand_index, operand_type, output)
        operand_index = operand_index + 1
        rendered_count = rendered_count + 1

def llvm_lir_render_call_arguments(program: LirProgram, record_offset: int, output: Buffer):
    llvm_lir_render_call_arguments_from(program, record_offset, 0, output)

# 全局 slot 名与 LLVM 类型：slot 类型为指针类时用 i8* 存储
def llvm_lir_global_slot_name(program: LirProgram, record_offset: int, operand_index: int) -> str:
    let slot = llvm_lir_operand_value(program, record_offset, operand_index)
    return llvm_lir_join_int("@dm_global_", slot, "")

def llvm_lir_global_slot_type(lir_type: int) -> str:
    if lir_type == LIR_TYPE_I32:
        return "i32"
    if lir_type == LIR_TYPE_F64:
        return "double"
    if lir_type == LIR_TYPE_I1:
        return "i1"
    return "i8*"

def llvm_emit_global_declarations(program: LirProgram, output: Buffer):
    # 按出现顺序收集全局 slot 的类型（LOAD 的 result 类型优先）
    let slot_types: list[int] = []
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_INSTRUCTION:
            let opcode = program.records[offset + 3]
            if opcode in [LIR_OP_GLOBAL_LOAD, LIR_OP_GLOBAL_STORE]:
                let slot = llvm_lir_operand_value(program, offset, 0)
                while len(slot_types) <= slot:
                    append(slot_types, 0)
                if slot_types[slot] == 0:
                    slot_types[slot] = program.records[offset + 4]
        record_id = record_id + 1
    let slot_index = 0
    while slot_index < len(slot_types):
        let slot_type = slot_types[slot_index]
        if slot_type != 0:
            append(output, "@dm_global_")
            append(output, slot_index)
            append(output, " = global ")
            append(output, llvm_lir_global_slot_type(slot_type))
            append(output, " zeroinitializer\n")
        slot_index = slot_index + 1

def llvm_emit_coerced_operand(program: LirProgram, record_offset: int, operand_index: int, expected_type: int,
    output: Buffer):
    let actual_type = LIR_TYPE_I32
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        let operand_value = llvm_lir_operand_value(program, record_offset, operand_index)
        actual_type = llvm_lir_value_type(program, program.records[record_offset + 1], operand_value)
        # 幽灵值或 void 结果都没有可引用的定义：以零占位，避免 SSA 未定义引用
        if actual_type == LIR_TYPE_VOID or not lir_value_exists(program.records, program.records[record_offset + 1],
            operand_value):
            if expected_type in [LIR_TYPE_DYNAMIC, LIR_TYPE_AGGREGATE, LIR_TYPE_VOID]:
                append(output, "inttoptr i32 0 to i8*")
            else:
                append(output, llvm_lir_zero(expected_type))
            return
    if expected_type in [LIR_TYPE_DYNAMIC, LIR_TYPE_AGGREGATE]:
        expected_type = LIR_TYPE_PTR
    if (
        expected_type == actual_type or
        llvm_lir_is_pointer_like(actual_type) and
        llvm_lir_is_pointer_like(expected_type)
    ):
        llvm_emit_operand(program, record_offset, operand_index, actual_type, output)
    elif expected_type in [LIR_TYPE_PTR, LIR_TYPE_I32, LIR_TYPE_F64, LIR_TYPE_I1]:
        append(output, llvm_lir_join_int("%phi_arg_", record_offset + operand_index, ""))
    else:
        append(output, llvm_lir_zero(expected_type))

def llvm_emit_direct_call_argument(program: LirProgram, record_offset: int, operand_index: int,
    expected_type: int, output: Buffer):
    let actual_type = LIR_TYPE_I32
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        actual_type = llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program,
            record_offset, operand_index))
    if expected_type == LIR_TYPE_DYNAMIC:
        expected_type = LIR_TYPE_PTR
    if expected_type == LIR_TYPE_VOID:
        expected_type = actual_type
    append(output, llvm_lir_type(expected_type))
    append(output, " ")
    if (
        expected_type == actual_type or
        llvm_lir_is_pointer_like(actual_type) and
        llvm_lir_is_pointer_like(expected_type)
    ):
        llvm_emit_operand(program, record_offset, operand_index, actual_type, output)
    else:
        append(output, llvm_lir_join_int("%call_arg_", record_offset + operand_index, ""))

def llvm_lir_direct_call_argument_needs_cast(actual_type: int, expected_type: int) -> bool:
    if expected_type in [LIR_TYPE_DYNAMIC, LIR_TYPE_AGGREGATE]:
        expected_type = LIR_TYPE_PTR
    if llvm_lir_is_pointer_like(actual_type) and llvm_lir_is_pointer_like(expected_type):
        return false
    return actual_type != expected_type

def llvm_lir_block_parameter_type(program: LirProgram, func_index: int, block_index: int,
    parameter_index: int) -> int:
    let offset = lir_block_parameter_offset(func_index, block_index, parameter_index)
    if offset < 0:
        return LIR_TYPE_DYNAMIC
    if offset + 4 >= len(program.records):
        return LIR_TYPE_DYNAMIC
    if program.records[offset] == LIR_RECORD_PARAMETER:
        # void 值不构成合法 phi；全链路统一按整型槽处理
        let parameter_type = program.records[offset + 4]
        if parameter_type == LIR_TYPE_VOID:
            return LIR_TYPE_I32
        return parameter_type
    return LIR_TYPE_DYNAMIC

def llvm_lir_edge_operand_type(program: LirProgram, record_offset: int, operand_index: int) -> int:
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
        return llvm_lir_value_type(program, program.records[record_offset + 1], llvm_lir_operand_value(program,
            record_offset, operand_index))
    if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_IMMEDIATE:
        return LIR_TYPE_I32
    return LIR_TYPE_DYNAMIC

def llvm_emit_edge_cast(program: LirProgram, record_offset: int, operand_index: int, expected_type: int,
    output: Buffer):
    let actual_type = llvm_lir_edge_operand_type(program, record_offset, operand_index)
    # void 操作数由占位端发零；cast 端不再生成定义
    if actual_type == LIR_TYPE_VOID or expected_type == LIR_TYPE_VOID:
        return
        expected_type = LIR_TYPE_PTR
    if not llvm_lir_direct_call_argument_needs_cast(actual_type, expected_type):
        return
    let temp_name = llvm_lir_join_int("%phi_arg_", record_offset + operand_index, "")
    if expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "inttoptr i32 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, " to i8*\n")
    elif expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I1:
        let integer_name = llvm_lir_join_int("%phi_arg_int_", record_offset + operand_index, "")
        append(output, "  ")
        append(output, integer_name)
        append(output, " = zext i1 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
        append(output, " to i32\n  ")
        append(output, temp_name)
        append(output, " = inttoptr i32 ")
        append(output, integer_name)
        append(output, " to i8*\n")
    elif expected_type == LIR_TYPE_I32 and llvm_lir_is_pointer_like(actual_type):
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "ptrtoint i8* ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_F64 and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "sitofp i32 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, " to double\n")
    elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_F64:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "fptosi double ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_I1:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "zext i1 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
        append(output, " to i32\n")
    elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_I32:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "icmp ne i32 ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
        append(output, ", 0\n")
    elif expected_type == LIR_TYPE_I1 and llvm_lir_is_pointer_like(actual_type):
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "icmp ne i8* ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
        append(output, ", null\n")
    elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_F64:
        append(output, "  ")
        append(output, temp_name)
        append(output, " = ")
        append(output, "fcmp one double ")
        llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
        append(output, ", 0.000000e+00\n")
    else:
        llvm_emit_zero_definition(expected_type, temp_name, output)

def llvm_emit_edge_casts(program: LirProgram, record_offset: int, target_block: int, argument_start: int,
    argument_count: int, output: Buffer):
    let parameter_index = 0
    let func_index = program.records[record_offset + 1]
    while parameter_index < argument_count:
        let expected_type = llvm_lir_block_parameter_type(program, func_index, target_block, parameter_index)
        llvm_emit_edge_cast(program, record_offset, argument_start + parameter_index, expected_type, output)
        parameter_index = parameter_index + 1

def llvm_emit_direct_call_casts(program: LirProgram, record_offset: int, func_index: int, output: Buffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = 1
    let argument_index = 0
    while operand_index < operand_count:
        let expected_type = llvm_lir_func_parameter_type(program, func_index, argument_index)
        if expected_type == LIR_TYPE_DYNAMIC:
            expected_type = LIR_TYPE_PTR
        let actual_type = LIR_TYPE_I32
        if llvm_lir_operand_kind(program, record_offset, operand_index) == LIR_OPERAND_VALUE:
            actual_type = llvm_lir_value_type(program, program.records[record_offset + 1],
                llvm_lir_operand_value(program, record_offset, operand_index))
        if llvm_lir_direct_call_argument_needs_cast(actual_type, expected_type):
            let temp_name = llvm_lir_join_int("%call_arg_", record_offset + operand_index, "")
            if expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "inttoptr i32 ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, " to i8*\n")
            elif expected_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I1:
                let integer_name = llvm_lir_join_int("%call_arg_int_", record_offset + operand_index, "")
                append(output, "  ")
                append(output, integer_name)
                append(output, " = zext i1 ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
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
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, " to i32\n  ")
                append(output, temp_name)
                append(output, " = inttoptr i32 ")
                append(output, integer_name)
                append(output, " to i8*\n")
            elif expected_type == LIR_TYPE_I32 and llvm_lir_is_pointer_like(actual_type):
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "ptrtoint i8* ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_F64 and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "sitofp i32 ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, " to double\n")
            elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_F64:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "fptosi double ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_I32 and actual_type == LIR_TYPE_I1:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "zext i1 ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I1, output)
                append(output, " to i32\n")
            elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "icmp ne i32 ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_I32, output)
                append(output, ", 0\n")
            elif expected_type == LIR_TYPE_I1 and llvm_lir_is_pointer_like(actual_type):
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "icmp ne i8* ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_PTR, output)
                append(output, ", null\n")
            elif expected_type == LIR_TYPE_I1 and actual_type == LIR_TYPE_F64:
                append(output, "  ")
                append(output, temp_name)
                append(output, " = ")
                append(output, "fcmp one double ")
                llvm_emit_operand(program, record_offset, operand_index, LIR_TYPE_F64, output)
                append(output, ", 0.000000e+00\n")
            else:
                llvm_emit_zero_definition(expected_type, temp_name, output)
        operand_index = operand_index + 1
        argument_index = argument_index + 1

def llvm_lir_render_direct_call_arguments(program: LirProgram, record_offset: int, func_index: int, output: Buffer):
    let operand_count = program.records[record_offset + 7]
    let operand_index = 1
    let argument_index = 0
    while operand_index < operand_count:
        if argument_index > 0:
            append(output, ", ")
        let expected_type = llvm_lir_func_parameter_type(program, func_index, argument_index)
        llvm_emit_direct_call_argument(program, record_offset, operand_index, expected_type, output)
        operand_index = operand_index + 1
        argument_index = argument_index + 1

def llvm_emit_token_call(program: LirProgram, offset: int, result_name: str, result_type: int, output: Buffer):
    append(output, "  call void @append_i32(i8* ")
    llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
    append(output, ", i32 ")
    llvm_emit_operand(program, offset, 4, LIR_TYPE_I32, output)
    append(output, ")\n  call void @append_i32(i8* ")
    llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
    append(output, ", i32 ")
    llvm_emit_operand(program, offset, 5, LIR_TYPE_I32, output)
    append(output, ")\n  call void @append_i32(i8* ")
    llvm_emit_operand(program, offset, 3, LIR_TYPE_PTR, output)
    append(output, ", i32 ")
    llvm_emit_operand(program, offset, 6, LIR_TYPE_I32, output)
    append(output, ")\n")
    if result_name != "" and result_type != LIR_TYPE_VOID:
        llvm_emit_zero_definition(result_type, result_name, output)

def llvm_lir_binary_operand_type(program: LirProgram, offset: int, operand_index: int) -> int:
    let operand_kind = llvm_lir_operand_kind(program, offset, operand_index)
    if operand_kind == LIR_OPERAND_VALUE:
        return llvm_lir_value_type(program, program.records[offset + 1], llvm_lir_operand_value(program, offset,
            operand_index))
    if operand_kind == LIR_OPERAND_IMMEDIATE:
        return LIR_TYPE_I32
    if operand_kind == LIR_OPERAND_TYPE:
        return llvm_lir_operand_value(program, offset, operand_index)
    return LIR_TYPE_DYNAMIC

def llvm_lir_can_emit_without_result(opcode: int) -> bool:
    if opcode == LIR_OP_RUNTIME_CALL or opcode == LIR_OP_CALL:
        return true
    if opcode == LIR_OP_AGGREGATE or opcode == LIR_OP_EXTRACT:
        return true
    if opcode == LIR_OP_ENUM or opcode == LIR_OP_CLOSURE:
        return true
    if opcode == LIR_OP_BOUNDS_CHECK or opcode == LIR_OP_GLOBAL_STORE:
        return true
    return false

def llvm_emit_binary(program: LirProgram, offset: int, output: Buffer, result_name: str, result_type: int):
    let operator = llvm_lir_operand_value(program, offset, 0)
    let left_type = llvm_lir_binary_operand_type(program, offset, 1)
    let right_type = llvm_lir_binary_operand_type(program, offset, 2)
    let operand_type = left_type
    if left_type != right_type:
        operand_type = LIR_TYPE_DYNAMIC
    let instruction = "add"
    let is_compare = false
    if operand_type not in [LIR_TYPE_I1, LIR_TYPE_I32, LIR_TYPE_F64]:
        llvm_emit_dynamic_binary(program, offset, output, result_name, result_type)
        return
    if operator == IR_OPERATOR_SUB:
        instruction = "sub"
    elif operator == IR_OPERATOR_MUL:
        instruction = "mul"
    elif operator == IR_OPERATOR_DIV:
        instruction = "sdiv"
    elif operator == IR_OPERATOR_MOD:
        instruction = "srem"
    elif operator == IR_OPERATOR_LT:
        instruction = "icmp slt"
        is_compare = true
    elif operator == IR_OPERATOR_GT:
        instruction = "icmp sgt"
        is_compare = true
    elif operator == IR_OPERATOR_LE:
        instruction = "icmp sle"
        is_compare = true
    elif operator == IR_OPERATOR_GE:
        instruction = "icmp sge"
        is_compare = true
    elif operator == IR_OPERATOR_EQ:
        instruction = "icmp eq"
        is_compare = true
    elif operator == IR_OPERATOR_NE:
        instruction = "icmp ne"
        is_compare = true
    elif operator == IR_OPERATOR_AND:
        instruction = "and"
    elif operator == IR_OPERATOR_OR:
        instruction = "or"
    if operand_type == LIR_TYPE_F64:
        if operator == IR_OPERATOR_LT:
            instruction = "fcmp olt"
            is_compare = true
        elif operator == IR_OPERATOR_GT:
            instruction = "fcmp ogt"
            is_compare = true
        elif operator == IR_OPERATOR_LE:
            instruction = "fcmp ole"
            is_compare = true
        elif operator == IR_OPERATOR_GE:
            instruction = "fcmp oge"
            is_compare = true
        elif operator == IR_OPERATOR_EQ:
            instruction = "fcmp oeq"
            is_compare = true
        elif operator == IR_OPERATOR_NE:
            instruction = "fcmp one"
            is_compare = true
        elif operator == IR_OPERATOR_ADD:
            instruction = "fadd"
        elif operator == IR_OPERATOR_SUB:
            instruction = "fsub"
        elif operator == IR_OPERATOR_MUL:
            instruction = "fmul"
        elif operator == IR_OPERATOR_DIV:
            instruction = "fdiv"
        elif operator == IR_OPERATOR_MOD:
            instruction = "frem"
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
    llvm_emit_operand(program, offset, 1, operand_type, output)
    append(output, ", ")
    llvm_emit_operand(program, offset, 2, operand_type, output)
    append(output, "\n")

def llvm_emit_instruction(program: LirProgram, offset: int, output: Buffer):
    let opcode = program.records[offset + 3]
    let result_value = program.records[offset + 5]
    let result_type = program.records[offset + 4]
    let result_name = llvm_lir_value_name(result_value)
    if result_value < 0 and not llvm_lir_can_emit_without_result(opcode):
        return
    if program.records[offset + 7] == 0 and not llvm_lir_can_emit_without_result(opcode):
        return
    if opcode == LIR_OP_BINARY:
        if result_type not in [LIR_TYPE_I1, LIR_TYPE_I32, LIR_TYPE_F64]:
            llvm_emit_dynamic_binary(program, offset, output, result_name, result_type)
            return
        llvm_emit_binary(program, offset, output, result_name, result_type)
        return
    if opcode == LIR_OP_CONST:
        let string_start = program.records[offset + 12]
        let string_end = program.records[offset + 13]
        if llvm_lir_is_string(result_type) and llvm_lir_is_string_literal(string_start, string_end):
            append(output, "  ")
            append(output, result_name)
            append(output, " = getelementptr inbounds [")
            append(output, string_end - string_start + 1)
            append(output, " x i8], ptr ")
            append(output, llvm_lir_string_global_name(offset / 14))
            append(output, ", i32 0, i32 0\n")
            return
        append(output, "  ")
        append(output, result_name)
        append(output, " = ")
        if llvm_lir_is_pointer_like(result_type):
            append(output, "inttoptr i32 ")
            llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
            append(output, " to i8*\n")
        elif result_type == LIR_TYPE_F64:
            if string_start >= 0 and string_end > string_start and string_end <= len(llvm_lir_source):
                # 从源码区间取 float 文本（如 "1.5"），LLVM 无裸 double 赋值，用 fadd 0.0 构造
                append(output, "fadd double ")
                append(output, llvm_lir_source[string_start:string_end])
                append(output, ", 0.000000e+00")
                append(output, "\n")
            else:
                append(output, "sitofp i32 ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
                append(output, " to double\n")
        else:
            append(output, "add ")
            append(output, llvm_lir_type(result_type))
            append(output, " 0, ")
            llvm_emit_operand(program, offset, 0, result_type, output)
            append(output, "\n")
        return
    if opcode == LIR_OP_COPY:
        if llvm_lir_is_pointer_like(result_type):
            append(output, "  ")
            append(output, result_name)
            append(output, " = getelementptr i8, i8* ")
            llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
            append(output, ", i32 0\n")
            return
        append(output, "  ")
        append(output, result_name)
        append(output, " = add ")
        append(output, llvm_lir_type(result_type))
        append(output, " 0, ")
        llvm_emit_operand(program, offset, 0, result_type, output)
        append(output, "\n")
        return
    if opcode == LIR_OP_SELECT:
        append(output, "  ")
        append(output, result_name)
        append(output, " = select i1 ")
        llvm_emit_operand(program, offset, 0, LIR_TYPE_I1, output)
        append(output, ", ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        llvm_emit_operand(program, offset, 1, result_type, output)
        append(output, ", ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        llvm_emit_operand(program, offset, 2, result_type, output)
        append(output, "\n")
        return
    if opcode == LIR_OP_GLOBAL_LOAD:
        append(output, "  ")
        append(output, result_name)
        append(output, " = load ")
        append(output, llvm_lir_global_slot_type(result_type))
        append(output, ", ")
        append(output, llvm_lir_global_slot_type(result_type))
        append(output, "* ")
        append(output, llvm_lir_global_slot_name(program, offset, 0))
        append(output, "\n")
        return
    if opcode == LIR_OP_GLOBAL_STORE:
        append(output, "  store ")
        append(output, llvm_lir_global_slot_type(result_type))
        append(output, " ")
        llvm_emit_operand(program, offset, 1, result_type, output)
        append(output, ", ")
        append(output, llvm_lir_global_slot_type(result_type))
        append(output, "* ")
        append(output, llvm_lir_global_slot_name(program, offset, 0))
        append(output, "\n")
        return
    if opcode == LIR_OP_CALL:
        let has_direct_target = false
        if program.records[offset + 7] > 0:
            has_direct_target = llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_SYMBOL
        if has_direct_target:
            let target = llvm_lir_operand_value(program, offset, 0)
            let is_external_target = llvm_lir_is_external_symbol(target)
            if not is_external_target and target == 38 and program.records[offset + 7] >= 7:
                let token_result_name = ""
                if result_value >= 0:
                    token_result_name = result_name
                llvm_emit_token_call(program, offset, token_result_name, result_type, output)
                return
            if not is_external_target:
                llvm_emit_direct_call_casts(program, offset, target, output)
            if result_type != LIR_TYPE_VOID and result_value >= 0:
                append(output, "  ")
                append(output, result_name)
                append(output, " = ")
            else:
                append(output, "  ")
            append(output, "call ")
            append(output, llvm_lir_type(result_type))
            append(output, " ")
            if is_external_target:
                append(output, llvm_lir_external_call_name(program, offset, target))
            else:
                append(output, llvm_lir_func_name(target))
            append(output, "(")
            if is_external_target:
                llvm_lir_render_call_arguments_from(program, offset, 1, output)
            else:
                llvm_lir_render_direct_call_arguments(program, offset, target, output)
            append(output, ")\n")
            return
    if opcode in [LIR_OP_RUNTIME_CALL, LIR_OP_CALL, LIR_OP_AGGREGATE, LIR_OP_EXTRACT, LIR_OP_ENUM, LIR_OP_CLOSURE,
        LIR_OP_BOUNDS_CHECK]:
        let runtime_id = program.records[offset + 8]
        if runtime_id <= 0:
            runtime_id = 31
        if runtime_id == 15:
            # 函数值间接调用：operand0 = 函数索引，经函数指针表取地址后统一签名调用
            let operand_count = program.records[offset + 7]
            let fn_index_name = llvm_lir_join_int("%fn_idx_", offset, "")
            append(output, "  ")
            append(output, fn_index_name)
            let fn_index_type = llvm_lir_binary_operand_type(program, offset, 0)
            if llvm_lir_is_pointer_like(fn_index_type):
                append(output, " = ptrtoint i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            else:
                append(output, " = add i32 0, ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
                append(output, "\n")
            append(output, "  %fn_ptr_")
            append(output, offset)
            append(output, " = getelementptr inbounds [")
            append(output, len(llvm_lir_func_record_cache))
            append(output, " x ptr], ptr @dm_func_table, i32 0, i32 ")
            append(output, fn_index_name)
            append(output, "\n  %fn_ptr_load_")
            append(output, offset)
            append(output, " = load ptr, ptr %fn_ptr_")
            append(output, offset)
            append(output, "\n  %fn_cast_")
            append(output, offset)
            append(output, " = bitcast ptr %fn_ptr_load_")
            append(output, offset)
            append(output, " to i32 (i32, i32, i32)*\n")
            let call_arg_index = 1
            while call_arg_index < operand_count and call_arg_index <= 3:
                let arg_type = llvm_lir_binary_operand_type(program, offset, call_arg_index)
                if llvm_lir_is_pointer_like(arg_type):
                    let arg_int_name = llvm_lir_join_int("%fn_arg_int_", offset + call_arg_index, "")
                    append(output, "  ")
                    append(output, arg_int_name)
                    append(output, " = ptrtoint i8* ")
                    llvm_emit_operand(program, offset, call_arg_index, LIR_TYPE_PTR, output)
                    append(output, " to i32\n")
                call_arg_index = call_arg_index + 1
            append(output, "  ")
            append(output, result_name)
            append(output, " = call i32 %fn_cast_")
            append(output, offset)
            append(output, "(")
            let call_arg_index = 1
            let first_argument_emitted = false
            while call_arg_index < operand_count and call_arg_index <= 3:
                let arg_type = llvm_lir_binary_operand_type(program, offset, call_arg_index)
                if first_argument_emitted:
                    append(output, ", ")
                if llvm_lir_is_pointer_like(arg_type):
                    let arg_int_name = llvm_lir_join_int("%fn_arg_int_", offset + call_arg_index, "")
                    append(output, "i32 ")
                    append(output, arg_int_name)
                else:
                    append(output, "i32 ")
                    llvm_emit_operand(program, offset, call_arg_index, LIR_TYPE_I32, output)
                first_argument_emitted = true
                call_arg_index = call_arg_index + 1
            while call_arg_index <= 3:
                if first_argument_emitted:
                    append(output, ", ")
                append(output, "i32 0")
                first_argument_emitted = true
                call_arg_index = call_arg_index + 1
            append(output, ")\n")
            return
        if runtime_id == 1:
            append(output, "  call void ")
            append(output, llvm_lir_print_name(program, offset))
            append(output, "(")
            llvm_lir_render_call_arguments(program, offset, output)
            append(output, ")\n")
            return
        if runtime_id == 7 and program.records[offset + 4] == LIR_TYPE_DICT:
            # dict 字面量与 list append 共用 runtime id 7；按结果类型分派
            if result_value >= 0:
                llvm_emit_dict_create(program, offset, output, result_name)
            return
        if runtime_id == 7:
            # LIR_RUNTIME_LIST_APPEND（含 dict 外的追加）：按值类型选 append_i32 /
            # append_pointer / append_ptr
            let append_type = llvm_lir_binary_operand_type(program, offset, 1)
            if llvm_lir_is_pointer_like(append_type):
                let append_name = "@append_pointer"
                if llvm_lir_binary_operand_type(program, offset, 0) == LIR_TYPE_LIST_PTR:
                    append_name = "@append_ptr"
                append(output, "  call void ")
                append(output, append_name)
                append(output, "(i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, ", i8* ")
                llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
                append(output, ")\n")
            else:
                append(output, "  call void @append_i32(i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, ", i32 ")
                llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
                append(output, ")\n")
            return
        if runtime_id in [4, 5]:
            let collection_type = llvm_lir_binary_operand_type(program, offset, 0)
            if collection_type == LIR_TYPE_DICT and runtime_id in [4, 5]:
                # 字典键赋值：dict[key] = value（int/int 变体）
                append(output, "  call void @dict_set_int_int(i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, ", i32 ")
                llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
                append(output, ", i32 ")
                llvm_emit_operand(program, offset, 2, LIR_TYPE_I32, output)
                append(output, ")\n")
                return
            if collection_type == LIR_TYPE_LIST_PTR:
                # 指针元素列表：单槽写入
                append(output, "  call void @set_dynarray_ptr(i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, ", i32 ")
                llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
                append(output, ", i8* ")
                llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
                append(output, ")\n")
                return
            let collection_name = ""
            if runtime_id == 5 or collection_type == LIR_TYPE_DYNAMIC:
                collection_name = llvm_lir_join_int("%list_set_collection_", offset, "")
                append(output, "  ")
                append(output, collection_name)
                append(output, " = call i8* @get_pointer(i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, ", i32 0)\n")
            let value_type = llvm_lir_binary_operand_type(program, offset, 2)
            let value_name = ""
            if llvm_lir_is_pointer_like(value_type):
                value_name = llvm_lir_join_int("%list_set_value_", offset, "")
                append(output, "  ")
                append(output, value_name)
                append(output, " = ptrtoint i8* ")
                llvm_emit_operand(program, offset, 2, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            let index_type = llvm_lir_binary_operand_type(program, offset, 1)
            let index_name = ""
            if llvm_lir_is_pointer_like(index_type):
                index_name = llvm_lir_join_int("%list_set_index_", offset, "")
                append(output, "  ")
                append(output, index_name)
                append(output, " = ptrtoint i8* ")
                llvm_emit_operand(program, offset, 1, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            append(output, "  call void @set_dynarray_i32(i8* ")
            if collection_name != "":
                append(output, collection_name)
            else:
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
            append(output, ", i32 ")
            if index_name != "":
                append(output, index_name)
            else:
                llvm_emit_operand(program, offset, 1, LIR_TYPE_I32, output)
            append(output, ", i32 ")
            if value_name != "":
                append(output, value_name)
            else:
                llvm_emit_operand(program, offset, 2, LIR_TYPE_I32, output)
            append(output, ")\n")
            return
        let return_type = result_type
        if runtime_id in [2, 10]:
            if result_value >= 0:
                llvm_emit_container_create(program, offset, output, result_name)
            return
        if runtime_id == 12:
            if result_value >= 0:
                llvm_emit_struct_create(program, offset, output, result_name)
            return
        if runtime_id == 11:
            if result_value >= 0:
                llvm_emit_tuple_get(program, offset, output, result_name, return_type)
            return
        let runtime_name = llvm_lir_runtime_name(runtime_id, return_type)
        if runtime_id == 3 and program.records[offset + 7] > 1:
            let base_type = llvm_lir_binary_operand_type(program, offset, 0)
            if base_type == LIR_TYPE_LIST_PTR:
                runtime_name = "@get_dynarray_ptr"
            elif base_type == LIR_TYPE_DICT and result_value >= 0:
                llvm_emit_dict_get(program, offset, output, result_name, return_type)
                return
            elif llvm_lir_is_string(base_type):
                runtime_name = "@__c_utf8_rune_at"
        elif runtime_id == 6 and program.records[offset + 7] > 2:
            let base_type = llvm_lir_binary_operand_type(program, offset, 0)
            if base_type == LIR_TYPE_LIST_PTR:
                runtime_name = "@slice_dynarray_ptr"
            elif llvm_lir_is_string(base_type) or base_type in [LIR_TYPE_DYNAMIC, LIR_TYPE_PTR]:
                runtime_name = "@string_substring"
        if runtime_id == 31 and program.records[offset + 7] == 2:
            llvm_emit_dynamic_unary(program, offset, output, result_name, return_type)
            return
        if runtime_id == 31 and program.records[offset + 7] >= 3:
            llvm_emit_dynamic_binary(program, offset, output, result_name, return_type)
            return
        if runtime_id == 31:
            if return_type == LIR_TYPE_VOID or result_value < 0:
                return
            let operand_count = program.records[offset + 7]
            let actual_type = LIR_TYPE_DYNAMIC
            if operand_count > 0:
                actual_type = llvm_lir_binary_operand_type(program, offset, 0)
            if operand_count > 0 and llvm_lir_types_compatible(actual_type, return_type):
                if llvm_lir_is_pointer_like(return_type):
                    append(output, "  ")
                    append(output, result_name)
                    append(output, " = getelementptr i8, i8* ")
                    llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                    append(output, ", i32 0\n")
                else:
                    append(output, "  ")
                    append(output, result_name)
                    append(output, " = add ")
                    append(output, llvm_lir_type(return_type))
                    append(output, " 0, ")
                    llvm_emit_operand(program, offset, 0, return_type, output)
                    append(output, "\n")
            elif return_type == LIR_TYPE_PTR and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, result_name)
                append(output, " = inttoptr i32 ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
                append(output, " to i8*\n")
            elif return_type == LIR_TYPE_I32 and llvm_lir_is_pointer_like(actual_type):
                append(output, "  ")
                append(output, result_name)
                append(output, " = ptrtoint i8* ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_PTR, output)
                append(output, " to i32\n")
            elif llvm_lir_is_pointer_like(return_type) and actual_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, result_name)
                append(output, " = inttoptr i32 ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
                append(output, " to i8*\n")
            elif llvm_lir_is_pointer_like(return_type) and actual_type == LIR_TYPE_I1:
                let integer_name = llvm_lir_join_int("%dynamic_copy_int_", offset, "")
                append(output, "  ")
                append(output, integer_name)
                append(output, " = zext i1 ")
                llvm_emit_operand(program, offset, 0, LIR_TYPE_I1, output)
                append(output, " to i32\n  ")
                append(output, result_name)
                append(output, " = inttoptr i32 ")
                append(output, integer_name)
                append(output, " to i8*\n")
            elif llvm_lir_is_pointer_like(return_type):
                append(output, "  ")
                append(output, result_name)
                append(output, " = inttoptr i32 0 to i8*\n")
            else:
                append(output, "  ")
                append(output, result_name)
                append(output, " = add ")
                append(output, llvm_lir_type(return_type))
                append(output, " 0, ")
                append(output, llvm_lir_zero(return_type))
                append(output, "\n")
            return
        if runtime_name == "@llvm.trap":
            append(output, "  call void @llvm.trap()\n")
            if result_value >= 0 and return_type != LIR_TYPE_VOID:
                llvm_emit_zero_definition(return_type, result_name, output)
            return
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
        let operator = llvm_lir_operand_value(program, offset, 0)
        let operand_type = llvm_lir_binary_operand_type(program, offset, 1)
        if operator == IR_OPERATOR_NOT:
            llvm_emit_dynamic_unary(program, offset, output, result_name, result_type)
        elif operator == IR_OPERATOR_NEG and result_type == LIR_TYPE_I32:
            append(output, "  ")
            append(output, result_name)
            append(output, " = sub i32 0, ")
            llvm_emit_operand(program, offset, 1, result_type, output)
            append(output, "\n")
        elif operator == IR_OPERATOR_NEG and result_type == LIR_TYPE_F64:
            append(output, "  ")
            append(output, result_name)
            append(output, " = fneg double ")
            llvm_emit_operand(program, offset, 1, result_type, output)
            append(output, "\n")
        elif operator == IR_OPERATOR_POS and operand_type in [LIR_TYPE_I32, LIR_TYPE_F64]:
            append(output, "  ")
            append(output, result_name)
            if operand_type == LIR_TYPE_F64:
                append(output, " = fadd double 0.000000e+00, ")
            else:
                append(output, " = add i32 0, ")
            llvm_emit_operand(program, offset, 1, result_type, output)
            append(output, "\n")
        return
    if opcode == LIR_OP_CAST:
        append(output, "  ")
        append(output, result_name)
        append(output, " = add ")
        append(output, llvm_lir_type(result_type))
        append(output, " ")
        append(output, "0, ")
        llvm_emit_operand(program, offset, 0, result_type, output)
        append(output, "\n")

def llvm_emit_terminator(program: LirProgram, offset: int, return_type: int, output: Buffer):
    let opcode = program.records[offset + 3]
    if opcode == LIR_TERM_JUMP:
        let target_block = llvm_lir_operand_value(program, offset, 0)
        llvm_emit_edge_casts(program, offset, target_block, 1, program.records[offset + 7] - 1, output)
        append(output, "  br label %")
        append(output, llvm_lir_block_name(target_block))
        append(output, "\n")
    elif opcode == LIR_TERM_BRANCH:
        let operand_count = program.records[offset + 7]
        if operand_count > 3:
            let operand_start = program.records[offset + 6]
            let true_count_offset = lir_value_offset(operand_start + 3)
            let true_count = program.values[true_count_offset + 1]
            llvm_emit_edge_casts(program, offset, llvm_lir_operand_value(program, offset, 1), 4, true_count,
                output)
            let false_count_index = 4 + true_count
            if false_count_index < operand_count:
                let false_count_offset = lir_value_offset(operand_start + false_count_index)
                let false_count = program.values[false_count_offset + 1]
                llvm_emit_edge_casts(program, offset, llvm_lir_operand_value(program, offset, 2),
                    false_count_index + 1, false_count, output)
        let condition = llvm_lir_operand(program, offset, 0, LIR_TYPE_I1)
        if llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_VALUE:
            let condition_value = llvm_lir_operand_value(program, offset, 0)
            let func_index = program.records[offset + 1]
            let condition_type = llvm_lir_value_type(program, func_index, condition_value)
            let has_condition = llvm_lir_has_value(program, func_index, condition_value)
            if condition_type == LIR_TYPE_I32 and has_condition:
                let condition_name = llvm_lir_join_int("%branch_cond_", program.records[offset + 2], "")
                append(output, "  ")
                append(output, condition_name)
                append(output, " = icmp ne i32 ")
                append(output, condition)
                append(output, ", 0\n  br i1 ")
                append(output, condition_name)
            elif llvm_lir_is_pointer_like(condition_type) and has_condition:
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
        llvm_emit_operand(program, offset, 0, LIR_TYPE_I32, output)
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
            let func_index = program.records[offset + 1]
            let actual_type = LIR_TYPE_DYNAMIC
            if llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_VALUE and llvm_lir_has_value(program,
                func_index, return_value):
                actual_type = llvm_lir_value_type(program, func_index, return_value)
            let cast_name = llvm_lir_join_int("%return_cast_", offset, "")
            if llvm_lir_is_pointer_like(actual_type) and return_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, cast_name)
                append(output, " = ptrtoint i8* ")
                llvm_emit_operand(program, offset, 0, actual_type, output)
                append(output, " to i32\n")
            elif actual_type == LIR_TYPE_I32 and return_type == LIR_TYPE_PTR:
                append(output, "  ")
                append(output, cast_name)
                append(output, " = inttoptr i32 ")
                llvm_emit_operand(program, offset, 0, actual_type, output)
                append(output, " to i8*\n")
            elif actual_type == LIR_TYPE_I1 and return_type == LIR_TYPE_I32:
                append(output, "  ")
                append(output, cast_name)
                append(output, " = zext i1 ")
                llvm_emit_operand(program, offset, 0, actual_type, output)
                append(output, " to i32\n")
            append(output, "  ret ")
            append(output, llvm_lir_type(return_type))
            append(output, " ")
            if llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_VALUE and llvm_lir_has_value(program,
                func_index, return_value):
                if llvm_lir_types_compatible(actual_type, return_type):
                    llvm_emit_operand(program, offset, 0, return_type, output)
                elif llvm_lir_is_pointer_like(actual_type) and return_type == LIR_TYPE_I32:
                    append(output, cast_name)
                elif actual_type == LIR_TYPE_I32 and return_type == LIR_TYPE_PTR:
                    append(output, cast_name)
                elif actual_type == LIR_TYPE_I1 and return_type == LIR_TYPE_I32:
                    append(output, cast_name)
                else:
                    append(output, llvm_lir_zero(return_type))
            elif llvm_lir_operand_kind(program, offset, 0) == LIR_OPERAND_IMMEDIATE:
                llvm_emit_operand(program, offset, 0, return_type, output)
            else:
                append(output, llvm_lir_zero(return_type))
            append(output, "\n")
    else:
        if return_type == LIR_TYPE_VOID:
            append(output, "  ret void\n")
        else:
            append(output, "  ret ")
            append(output, llvm_lir_type(return_type))
            append(output, " ")
            append(output, llvm_lir_zero(return_type))
            append(output, "\n")

def llvm_emit_edge_incoming(program: LirProgram, offset: int, target_block: int, parameter_index: int,
    parameter_type: int, incoming: Buffer, incoming_count: list[int]) -> bool:
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
        # 计算 true 分支的参数计数（操作数索引 3 处为立即数，其内容为计数）
        let true_count_offset = lir_value_offset(program.records[offset + 6] + 3)
        let true_count = program.values[true_count_offset + 1]
        # false 参数计数的位置：在操作数数组中，位于 true 参数之后
        let false_count_index = 4 + true_count
        # 只有当存在 false 目标块（操作数索引 2）且 false 参数计数在操作数范围内时，
        # 才处理两条入边。
        if false_count_index < operand_count:
            # 两条分支可能指向同一目标块，各自贡献一条入边，不能提前返回
            let matched_any = false
            let edge_index = 0
            while edge_index < 2:
                # 真实分支目标在操作数索引 1，假分支目标在操作数索引 2
                let candidate_target_index = 1
                # 真实分支参数从操作数索引 4 开始，假分支参数从 false_count_index + 1 开始
                let candidate_argument_start = 4
                let candidate_argument_count = true_count
                if edge_index == 1:
                    candidate_target_index = 2
                    # 假分支的参数计数从操作数数组的 false_count_index 处读取（立即数内容）
                    let false_count_offset = lir_value_offset(program.records[offset + 6] + false_count_index)
                    candidate_argument_start = false_count_index + 1
                    candidate_argument_count = program.values[false_count_offset + 1]
                if candidate_target_index < operand_count:
                    # 检查目标操作数的类型和内容是否与期望的目标块匹配
                    let candidate_target_offset = lir_value_offset(program.records[offset + 6] + candidate_target_index)
                    if (
                        program.values[candidate_target_offset] == LIR_OPERAND_BLOCK and
                        program.values[candidate_target_offset + 1] == target_block and
                        parameter_index < candidate_argument_count
                    ):
                        # 只有当参数索引在该分支传递的参数范围内时，才生成入边
                        if incoming_count[0] > 0:
                            append(incoming, ",")
                        append(incoming, " [")
                        # 参数值在操作数数组中的索引：起始位置 + 参数索引
                        llvm_emit_coerced_operand(program, offset, candidate_argument_start + parameter_index,
                            parameter_type, incoming)
                        append(incoming, ", %")
                        append(incoming, llvm_lir_block_name(program.records[offset + 2]))
                        append(incoming, "]")
                        incoming_count[0] = incoming_count[0] + 1
                        matched_any = true
                edge_index = edge_index + 1
            return matched_any
    if target_index >= 0 and target_index < operand_count:
        let target_offset = lir_value_offset(program.records[offset + 6] + target_index)
        if (
            program.values[target_offset] == LIR_OPERAND_BLOCK and
            program.values[target_offset + 1] == target_block and
            parameter_index < edge_argument_count
        ):
            if incoming_count[0] > 0:
                append(incoming, ",")
            append(incoming, " [")
            llvm_emit_coerced_operand(program, offset, argument_start + parameter_index, parameter_type, incoming)
            append(incoming, ", %")
            append(incoming, llvm_lir_block_name(program.records[offset + 2]))
            append(incoming, "]")
            incoming_count[0] = incoming_count[0] + 1
            return true
    return false

def llvm_emit_block_parameter(program: LirProgram, block_record_id: int, parameter_record_id: int,
    parameter_index: int, output: Buffer):
    let block_offset = lir_record_offset(block_record_id)
    let parameter_offset = lir_record_offset(parameter_record_id)
    let func_index = program.records[block_offset + 1]
    let block_index = program.records[block_offset + 2]
    let type_tag = program.records[parameter_offset + 4]
    # void 值不构成合法 phi；按整型槽处理
    if type_tag == LIR_TYPE_VOID:
        type_tag = LIR_TYPE_I32
    let result_value = program.records[parameter_offset + 5]
    let incoming = Buffer{data: []}
    let incoming_count = 0
    let term_start = 0
    let term_count = 0
    if func_index >= 0 and func_index < len(llvm_lir_func_terminator_start_cache):
        term_start = llvm_lir_func_terminator_start_cache[func_index]
        term_count = llvm_lir_func_terminator_count_cache[func_index]
    if term_start < 0:
        term_start = 0
    let term_index = term_start
    while term_index < term_start + term_count:
        let offset = lir_record_offset(llvm_lir_terminator_record_cache[term_index])
        if program.records[offset + 1] == func_index and program.records[offset] == LIR_RECORD_TERMINATOR:
            let incoming_count_box: list[int] = [incoming_count]
            llvm_emit_edge_incoming(program, offset, block_index, parameter_index, type_tag, incoming,
                incoming_count_box)
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
    elif llvm_lir_is_pointer_like(type_tag):
        append(output, "inttoptr i32 0 to i8*")
    else:
        append(output, "add ")
        append(output, llvm_lir_type(type_tag))
        append(output, " 0, 0")
    append(output, "\n")

def llvm_lir_func_return_type(program: LirProgram, offset: int) -> int:
    let auxiliary_count = program.records[offset + 9]
    if auxiliary_count == 0:
        return LIR_TYPE_VOID
    let value_id = program.records[offset + 8] + auxiliary_count - 1
    let value_offset = lir_value_offset(value_id)
    return program.values[value_offset + 1]

def llvm_lir_emit_function(program: LirProgram, func_id: int, func_record_id: int, output: Buffer):
    let func_offset = lir_record_offset(func_record_id)
    let return_type = llvm_lir_func_return_type(program, func_offset)
    let is_process_entry = program.records[func_offset + 3] == LIR_FUNCTION_ENTRY
    append(output, "define ")
    append(output, llvm_lir_type(return_type))
    append(output, " ")
    if is_process_entry:
        append(output, "@main")
    else:
        append(output, llvm_lir_func_name(func_id))
    append(output, "(")
    let record_id = func_record_id + 1
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
    if is_process_entry:
        if parameter_index > 0:
            append(output, ", ")
        append(output, "i32 %dream_argc.param, i8** %dream_argv.param")
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
            if is_process_entry and program.records[offset + 2] == 0:
                append(output, "  call void @__c_process_set_args(i32 %dream_argc.param, i8** %dream_argv.param)\n")
            let parameter_record_id = record_id + 1
            let parameter_index = 0
            while parameter_record_id < lir_record_count(program.records):
                let parameter_offset = lir_record_offset(parameter_record_id)
                if (
                    program.records[parameter_offset] != LIR_RECORD_PARAMETER or
                    program.records[parameter_offset + 2] != program.records[offset + 2]
                ):
                    parameter_record_id = lir_record_count(program.records)
                else:
                    llvm_emit_block_parameter(program, record_id, parameter_record_id, parameter_index, output)
                    parameter_index = parameter_index + 1
                    parameter_record_id = parameter_record_id + 1
        elif kind == LIR_RECORD_INSTRUCTION:
            llvm_emit_instruction(program, offset, output)
        elif kind == LIR_RECORD_TERMINATOR:
            llvm_emit_terminator(program, offset, return_type, output)
        record_id = record_id + 1
    append(output, "}\n")

def llvm_lower_lir(program: LirProgram, source: str, output: Buffer) -> bool:
    llvm_lir_source = source
    let phase_time = llvm_lir_debug_start()
    llvm_lir_prepare_func_cache(program)
    phase_time = llvm_lir_debug_checkpoint("cache", phase_time)
    append(output, "; Dream LIR to LLVM IR\n")
    append(output, "; DIR records=")
    append(output, lir_record_count(program.records))
    append(output, "\n")
    llvm_emit_runtime_declarations(output)
    llvm_emit_external_declarations(output)
    llvm_emit_global_declarations(program, output)
    llvm_emit_string_globals(program, output)
    append(output, "\n")
    phase_time = llvm_lir_debug_checkpoint("declarations", phase_time)
    let record_id = 0
    let func_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_FUNCTION:
            llvm_lir_emit_function(program, func_id, record_id, output)
            func_id = func_id + 1
        record_id = record_id + 1
    llvm_emit_func_table(program, output)
    llvm_lir_debug_checkpoint("functions", phase_time)
    return true
