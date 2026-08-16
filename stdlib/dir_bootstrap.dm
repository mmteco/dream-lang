const DIR_TAG_INVALID: int = 0
const DIR_TAG_COMMENT: int = 1
const DIR_TAG_MODULE: int = 2
const DIR_TAG_EXTERN: int = 3
const DIR_TAG_FUNCTION: int = 4
const DIR_TAG_BLOCK: int = 5
const DIR_TAG_FUNCTION_END: int = 6
const DIR_TAG_INSTRUCTION_BASE: int = 10

const DIR_LINE_COMMENT: int = 1
const DIR_LINE_MODULE: int = 2
const DIR_LINE_EXTERN: int = 3
const DIR_LINE_FUNCTION_BEGIN: int = 4
const DIR_LINE_BLOCK: int = 5
const DIR_LINE_INSTRUCTION: int = 6
const DIR_LINE_FUNCTION_END: int = 7

const DIR_TYPE_UNKNOWN: int = 0
const DIR_TYPE_I32: int = 1
const DIR_TYPE_POINTER: int = 2
const DIR_TYPE_LIST: int = 3
const DIR_TYPE_BOOL: int = 4
const DIR_RECORD_HEADER_SIZE: int = 5
const DIR_OPERAND_COUNT_UNKNOWN: int = 0
const DIR_OPERAND_MASK_NONE: int = 0
const DIR_OPERAND_MASK_TEMPORARY: int = 1
const DIR_OPERAND_MASK_IMMEDIATE: int = 2
const DIR_OPERAND_MASK_GLOBAL: int = 4
const DIR_OPERAND_MASK_LABEL: int = 8
const DIR_OPERAND_MASK_TYPE: int = 16
const DIR_OPERAND_MASK_NATIVE: int = 32
const DIR_OPERAND_MASK_SYMBOL: int = 64
const DIR_NATIVE_OPERAND_TEMPORARY = DIR_OPERAND_MASK_TEMPORARY
const DIR_NATIVE_OPERAND_IMMEDIATE = DIR_OPERAND_MASK_IMMEDIATE
const DIR_NATIVE_OPERAND_GLOBAL = DIR_OPERAND_MASK_GLOBAL
const DIR_NATIVE_OPERAND_LABEL = DIR_OPERAND_MASK_LABEL
const DIR_NATIVE_OPERAND_SYMBOL = DIR_OPERAND_MASK_SYMBOL
const DIR_NATIVE_OPERAND_TYPE = DIR_OPERAND_MASK_TYPE

const DIR_OPCODE_RET: int = 1
const DIR_OPCODE_BR: int = 2
const DIR_OPCODE_CALL: int = 3
const DIR_OPCODE_STORE: int = 4
const DIR_OPCODE_UNREACHABLE: int = 5
const DIR_OPCODE_ALLOCA: int = 6
const DIR_OPCODE_LOAD: int = 7
const DIR_OPCODE_GETELEMENTPTR: int = 8
const DIR_OPCODE_CALL_VALUE: int = 9
const DIR_OPCODE_ADD: int = 10
const DIR_OPCODE_SUB: int = 11
const DIR_OPCODE_MUL: int = 12
const DIR_OPCODE_SDIV: int = 13
const DIR_OPCODE_SREM: int = 14
const DIR_OPCODE_ICMP: int = 15
const DIR_OPCODE_ZEXT: int = 16
const DIR_OPCODE_AND: int = 17
const DIR_OPCODE_OR: int = 18
const DIR_OPCODE_FALLBACK: int = 19
const DIR_OPCODE_MAX = DIR_OPCODE_FALLBACK

const DIR_PREDICATE_EQ: int = 1
const DIR_PREDICATE_NE: int = 2
const DIR_PREDICATE_SLT: int = 3
const DIR_PREDICATE_SLE: int = 4
const DIR_PREDICATE_SGT: int = 5
const DIR_PREDICATE_SGE: int = 6

def dir_append_code_range(output: list[int], source: list[int], start: int, end: int):
    let index = start
    while index < end:
        append(output, source[index])
        index = index + 1

def dir_line_has_prefix(source: list[int], start: int, end: int, prefix: str) -> bool:
    let prefix_length = text_length(prefix)
    let available_length = end - start
    if available_length < prefix_length:
        return false
    let index = 0
    while index < prefix_length:
        if source[start + index] != ord(prefix[index]):
            return false
        index = index + 1
    return true

def dir_skip_spaces(source: list[int], start: int, end: int) -> int:
    let index = start
    let is_space = true
    while index < end and is_space:
        if source[index] == ord(' '):
            index = index + 1
        elif source[index] == ord('\t'):
            index = index + 1
        else:
            is_space = false
    return index

def dir_line_is_label(source: list[int], start: int, end: int) -> bool:
    if start >= end:
        return false
    if source[end - 1] == ord(':'):
        return true
    return false

def dir_line_contains(source: list[int], start: int, end: int, needle: str) -> bool:
    let needle_length = text_length(needle)
    let index = start
    while index + needle_length <= end:
        let needle_index = 0
        let source_index = index
        let is_match = true
        while needle_index < needle_length and is_match:
            let source_code = source[source_index]
            let needle_code = ord(needle[needle_index])
            if source_code != needle_code:
                is_match = false
            needle_index = needle_index + 1
            source_index = source_index + 1
        if is_match:
            return true
        index = index + 1
    return false

def dir_find_assignment(source: list[int], start: int, end: int) -> int:
    let index = start
    while index + 2 < end:
        if source[index] == ord(' ') and source[index + 1] == ord('=') and source[index + 2] == ord(' '):
            return index
        index = index + 1
    return -1

def dir_instruction_kind(source: list[int], start: int, end: int) -> int:
    let normalized_start = dir_skip_spaces(source, start, end)
    if dir_line_has_prefix(source, normalized_start, end, "ret "):
        return DIR_OPCODE_RET
    if dir_line_has_prefix(source, normalized_start, end, "br "):
        return DIR_OPCODE_BR
    if dir_line_has_prefix(source, normalized_start, end, "call "):
        return DIR_OPCODE_CALL
    if dir_line_has_prefix(source, normalized_start, end, "store "):
        return DIR_OPCODE_STORE
    if dir_line_has_prefix(source, normalized_start, end, "unreachable"):
        return DIR_OPCODE_UNREACHABLE
    let assignment_start = dir_find_assignment(source, normalized_start, end)
    if assignment_start >= 0:
        let opcode_start = assignment_start + 3
        if dir_line_has_prefix(source, opcode_start, end, "alloca "):
            return DIR_OPCODE_ALLOCA
        if dir_line_has_prefix(source, opcode_start, end, "load "):
            return DIR_OPCODE_LOAD
        if dir_line_has_prefix(source, opcode_start, end, "getelementptr "):
            return DIR_OPCODE_GETELEMENTPTR
        if dir_line_has_prefix(source, opcode_start, end, "call "):
            return DIR_OPCODE_CALL_VALUE
        if dir_line_has_prefix(source, opcode_start, end, "add "):
            return DIR_OPCODE_ADD
        if dir_line_has_prefix(source, opcode_start, end, "sub "):
            return DIR_OPCODE_SUB
        if dir_line_has_prefix(source, opcode_start, end, "mul "):
            return DIR_OPCODE_MUL
        if dir_line_has_prefix(source, opcode_start, end, "sdiv "):
            return DIR_OPCODE_SDIV
        if dir_line_has_prefix(source, opcode_start, end, "srem "):
            return DIR_OPCODE_SREM
        if dir_line_has_prefix(source, opcode_start, end, "icmp "):
            return DIR_OPCODE_ICMP
        if dir_line_has_prefix(source, opcode_start, end, "zext "):
            return DIR_OPCODE_ZEXT
        if dir_line_has_prefix(source, opcode_start, end, "and "):
            return DIR_OPCODE_AND
        if dir_line_has_prefix(source, opcode_start, end, "or "):
            return DIR_OPCODE_OR
        if dir_line_has_prefix(source, normalized_start, end, "%"):
            return DIR_OPCODE_FALLBACK
    return DIR_TAG_INVALID

def dir_instruction_type(source: list[int], start: int, end: int) -> int:
    if dir_line_contains(source, start, end, "i8*"):
        return DIR_TYPE_POINTER
    if dir_line_contains(source, start, end, "%dynarray_i32*"):
        return DIR_TYPE_LIST
    if dir_line_contains(source, start, end, "i1"):
        return DIR_TYPE_BOOL
    if dir_line_contains(source, start, end, "i32"):
        return DIR_TYPE_I32
    return DIR_TYPE_UNKNOWN

def dir_instruction_operand_count(source: list[int], start: int, end: int, instruction_kind: int) -> int:
    if instruction_kind == DIR_OPCODE_RET:
        if dir_line_contains(source, start, end, "ret void"):
            return 0
        return 1
    if instruction_kind == DIR_OPCODE_BR:
        if dir_line_contains(source, start, end, ", label "):
            return 3
        return 1
    if instruction_kind == DIR_OPCODE_STORE:
        return 2
    if instruction_kind == DIR_OPCODE_UNREACHABLE:
        return 0
    if instruction_kind == DIR_OPCODE_ALLOCA or instruction_kind == DIR_OPCODE_LOAD:
        return 1
    if instruction_kind == DIR_OPCODE_GETELEMENTPTR:
        return 3
    if instruction_kind == DIR_OPCODE_CALL or instruction_kind == DIR_OPCODE_CALL_VALUE or instruction_kind == DIR_OPCODE_FALLBACK:
        return 1
    if instruction_kind == DIR_OPCODE_ADD or instruction_kind == DIR_OPCODE_SUB or instruction_kind == DIR_OPCODE_MUL or instruction_kind == DIR_OPCODE_SDIV or instruction_kind == DIR_OPCODE_SREM or instruction_kind == DIR_OPCODE_ICMP or instruction_kind == DIR_OPCODE_AND or instruction_kind == DIR_OPCODE_OR:
        return 2
    if instruction_kind == DIR_OPCODE_ZEXT:
        return 1
    return DIR_OPERAND_COUNT_UNKNOWN

def dir_instruction_operand_mask(source: list[int], start: int, end: int, instruction_kind: int) -> int:
    let operand_mask = DIR_OPERAND_MASK_NONE
    if instruction_kind == DIR_OPCODE_UNREACHABLE or instruction_kind == DIR_OPCODE_CALL or instruction_kind == DIR_OPCODE_CALL_VALUE or instruction_kind == DIR_OPCODE_FALLBACK:
        return operand_mask
    let has_type = false
    let has_temporary = false
    let has_immediate = false
    let has_global = false
    let has_label = false
    let has_symbol = false
    let index = start
    while index < end:
        let code = source[index]
        if code == ord('@'):
            has_global = true
        if code == 105:
            if index + 1 < end:
                if source[index + 1] == ord('1') or source[index + 1] == ord('3') or source[index + 1] == ord('8'):
                    has_type = true
        if code == 100:
            if index + 5 < end:
                if source[index + 1] == ord('o') and source[index + 2] == ord('u') and source[index + 3] == ord('b') and source[index + 4] == ord('l') and source[index + 5] == ord('e'):
                    has_type = true
        if code == ord('%'):
            let is_label = false
            if index >= start + 6:
                if source[index - 6] == ord('l') and source[index - 5] == ord('a') and source[index - 4] == ord('b') and source[index - 3] == ord('e') and source[index - 2] == ord('l') and source[index - 1] == ord(' '):
                    is_label = true
            if index + 1 < end:
                if source[index + 1] == ord('d') and not is_label:
                    has_type = true
            if is_label:
                has_label = true
            if not is_label:
                let is_type_name = false
                if index + 1 < end:
                    if source[index + 1] == ord('d'):
                        is_type_name = true
                if not is_type_name:
                    has_temporary = true
        if code >= 48 and code <= 57:
            let has_positive_operand_boundary = false
            if index == start:
                has_positive_operand_boundary = true
            if index > start:
                if source[index - 1] == ord(' ') or source[index - 1] == ord(',') or source[index - 1] == ord('('):
                    has_positive_operand_boundary = true
            if has_positive_operand_boundary:
                has_immediate = true
        if code == ord('-'):
            if index + 1 < end:
                if source[index + 1] >= ord('0') and source[index + 1] <= ord('9'):
                    let has_negative_operand_boundary = false
                    if index == start:
                        has_negative_operand_boundary = true
                    if index > start:
                        if source[index - 1] == ord(' ') or source[index - 1] == ord(',') or source[index - 1] == ord('('):
                            has_negative_operand_boundary = true
                    if has_negative_operand_boundary:
                        has_immediate = true
        index = index + 1
    if has_global:
        operand_mask = operand_mask + DIR_OPERAND_MASK_GLOBAL
    if has_label:
        operand_mask = operand_mask + DIR_OPERAND_MASK_LABEL
    if has_type:
        operand_mask = operand_mask + DIR_OPERAND_MASK_TYPE
    if has_temporary:
        operand_mask = operand_mask + DIR_OPERAND_MASK_TEMPORARY
    if has_immediate:
        operand_mask = operand_mask + DIR_OPERAND_MASK_IMMEDIATE
    return operand_mask

def dir_operand_count_is_valid(instruction_kind: int, operand_count: int) -> bool:
    if instruction_kind == DIR_OPCODE_CALL or instruction_kind == DIR_OPCODE_CALL_VALUE:
        if operand_count >= 1:
            return true
        return false
    if instruction_kind == DIR_OPCODE_FALLBACK:
        return true
    if instruction_kind == DIR_OPCODE_RET:
        if operand_count == 0 or operand_count == 1:
            return true
        return false
    if instruction_kind == DIR_OPCODE_BR:
        if operand_count == 1 or operand_count == 3:
            return true
        return false
    if instruction_kind == DIR_OPCODE_UNREACHABLE:
        if operand_count == 0:
            return true
        return false
    if instruction_kind == DIR_OPCODE_STORE or instruction_kind == DIR_OPCODE_ADD or instruction_kind == DIR_OPCODE_SUB or instruction_kind == DIR_OPCODE_MUL or instruction_kind == DIR_OPCODE_SDIV or instruction_kind == DIR_OPCODE_SREM or instruction_kind == DIR_OPCODE_ICMP or instruction_kind == DIR_OPCODE_AND or instruction_kind == DIR_OPCODE_OR:
        if operand_count == 2:
            return true
        return false
    if instruction_kind == DIR_OPCODE_ALLOCA or instruction_kind == DIR_OPCODE_LOAD or instruction_kind == DIR_OPCODE_ZEXT:
        if operand_count == 1:
            return true
        return false
    if instruction_kind == DIR_OPCODE_GETELEMENTPTR:
        if operand_count == 3:
            return true
        return false
    return false

def dir_line_kind(source: list[int], start: int, end: int) -> int:
    let normalized_start = dir_skip_spaces(source, start, end)
    if normalized_start >= end:
        return DIR_TAG_INVALID
    if source[normalized_start] == ord(';'):
        return DIR_LINE_COMMENT
    if source[normalized_start] == ord('}') and end - normalized_start == 1:
        return DIR_LINE_FUNCTION_END
    if dir_line_has_prefix(source, normalized_start, end, "%") and dir_line_contains(source, normalized_start, end, " = type "):
        return DIR_LINE_MODULE
    if dir_line_has_prefix(source, normalized_start, end, "@"):
        return DIR_LINE_MODULE
    if dir_line_has_prefix(source, normalized_start, end, "declare "):
        return DIR_LINE_EXTERN
    if dir_line_has_prefix(source, normalized_start, end, "define "):
        return DIR_LINE_FUNCTION_BEGIN
    if dir_line_is_label(source, normalized_start, end):
        return DIR_LINE_BLOCK
    return DIR_LINE_INSTRUCTION

def dir_split_lines(source: list[int], line_starts: list[int], line_ends: list[int]):
    let line_start = 0
    let index = 0
    while index < len(source):
        if source[index] == ord('\n'):
            if line_start < index:
                append(line_starts, line_start)
                append(line_ends, index)
            line_start = index + 1
        index = index + 1
    if line_start < len(source):
        append(line_starts, line_start)
        append(line_ends, len(source))

def dir_validate_lines(source: list[int], line_starts: list[int], line_ends: list[int]) -> bool:
    let inside_function = false
    let is_valid = true
    let line_index = 0
    while line_index < len(line_starts):
        let line_kind = dir_line_kind(source, line_starts[line_index], line_ends[line_index])
        if line_kind == DIR_LINE_FUNCTION_BEGIN:
            if inside_function:
                is_valid = false
            inside_function = true
        if line_kind == DIR_LINE_FUNCTION_END:
            if not inside_function:
                is_valid = false
            inside_function = false
        if (line_kind == DIR_LINE_BLOCK or line_kind == DIR_LINE_INSTRUCTION) and not inside_function:
            is_valid = false
        if line_kind == DIR_LINE_INSTRUCTION and inside_function and dir_instruction_kind(source, line_starts[line_index], line_ends[line_index]) == DIR_TAG_INVALID:
            is_valid = false
        if line_kind == DIR_TAG_INVALID:
            is_valid = false
        line_index = line_index + 1
    if inside_function:
        is_valid = false
    return is_valid

def dir_render_lines(source: list[int], line_starts: list[int], line_ends: list[int], output: list[int]):
    let line_index = 0
    while line_index < len(line_starts):
        dir_append_code_range(output, source, line_starts[line_index], line_ends[line_index])
        append(output, 10)
        line_index = line_index + 1

def dir_record_kind(line_kind: int, instruction_kind: int) -> int:
    if line_kind == DIR_LINE_COMMENT:
        return DIR_TAG_COMMENT
    if line_kind == DIR_LINE_MODULE:
        return DIR_TAG_MODULE
    if line_kind == DIR_LINE_EXTERN:
        return DIR_TAG_EXTERN
    if line_kind == DIR_LINE_FUNCTION_BEGIN:
        return DIR_TAG_FUNCTION
    if line_kind == DIR_LINE_FUNCTION_END:
        return DIR_TAG_FUNCTION_END
    if line_kind == DIR_LINE_BLOCK:
        return DIR_TAG_BLOCK
    if line_kind == DIR_LINE_INSTRUCTION:
        if instruction_kind == DIR_TAG_INVALID:
            return DIR_TAG_INVALID
        return DIR_TAG_INSTRUCTION_BASE + instruction_kind
    return DIR_TAG_INVALID

def dir_record_kind_is_valid(record_kind: int) -> bool:
    if record_kind == DIR_TAG_COMMENT or record_kind == DIR_TAG_MODULE or record_kind == DIR_TAG_EXTERN or record_kind == DIR_TAG_FUNCTION or record_kind == DIR_TAG_BLOCK or record_kind == DIR_TAG_FUNCTION_END:
        return true
    let max_record_kind = DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_MAX
    if record_kind > DIR_TAG_INSTRUCTION_BASE and record_kind <= max_record_kind:
        return true
    return false

def dir_append_record(records: list[int], record_kind: int, instruction_kind: int, value_type: int, operand_count: int, operand_mask: int, source: list[int], start: int, end: int):
    append(records, record_kind)
    append(records, instruction_kind)
    append(records, value_type)
    append(records, operand_count)
    append(records, operand_mask)
    dir_append_code_range(records, source, start, end)
    append(records, 0)

def dir_append_text(output: list[int], text: str):
    let index = 0
    while index < text_length(text):
        append(output, ord(text[index]))
        index = index + 1

def dir_append_integer(output: list[int], value: int):
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
            let quotient = number / divisor
            let digit = quotient % 10
            append(output, 48 + digit)
            divisor = divisor / 10

def dir_append_native_operand(records: list[int], operand_kind: int, operand_value: int):
    append(records, operand_kind)
    append(records, operand_value)

def dir_append_native_symbol_operand(records: list[int], symbol: str):
    append(records, DIR_NATIVE_OPERAND_SYMBOL)
    append(records, text_length(symbol))
    let index = 0
    while index < text_length(symbol):
        append(records, ord(symbol[index]))
        index = index + 1

def dir_append_native_symbol_operand_range(records: list[int], source: list[int], start: int, end: int):
    append(records, DIR_NATIVE_OPERAND_SYMBOL)
    append(records, end - start)
    let index = start
    while index < end:
        append(records, source[index])
        index = index + 1

def dir_native_operand_payload_length(records: list[int], start: int, end: int) -> int:
    if start + 1 >= end:
        return 0
    let operand_kind = records[start]
    if operand_kind == DIR_NATIVE_OPERAND_SYMBOL:
        let symbol_length = records[start + 1]
        if symbol_length < 0 or start + 2 + symbol_length > end:
            return 0
        return symbol_length + 2
    return 2

def dir_append_native_ret(records: list[int], value_type: int, operand_kind: int, operand_value: int):
    let operand_count = 0
    let operand_mask = DIR_OPERAND_MASK_NATIVE
    if operand_kind != DIR_TAG_INVALID:
        operand_count = 1
        operand_mask = operand_mask + operand_kind
    dir_append_native_record(records, DIR_OPCODE_RET, value_type, operand_count, operand_mask, operand_kind, operand_value, 0, 0, 0, 0)

def dir_append_native_br(records: list[int], operand_count: int, condition_kind: int, condition_value: int, then_value: int, else_value: int):
    let operand_mask = DIR_OPERAND_MASK_NATIVE
    if operand_count == 1:
        operand_mask = operand_mask + DIR_NATIVE_OPERAND_LABEL
    if operand_count == 3:
        operand_mask = operand_mask + DIR_NATIVE_OPERAND_TEMPORARY + DIR_NATIVE_OPERAND_LABEL
    dir_append_native_record(records, DIR_OPCODE_BR, DIR_TYPE_BOOL, operand_count, operand_mask, condition_kind, condition_value, DIR_NATIVE_OPERAND_LABEL, then_value, DIR_NATIVE_OPERAND_LABEL, else_value)

def dir_append_native_record(records: list[int], instruction_kind: int, value_type: int, operand_count: int, operand_mask: int, first_kind: int, first_value: int, second_kind: int, second_value: int, third_kind: int, third_value: int):
    append(records, DIR_TAG_INSTRUCTION_BASE + instruction_kind)
    append(records, instruction_kind)
    append(records, value_type)
    append(records, operand_count)
    append(records, operand_mask)
    if operand_count >= 1:
        dir_append_native_operand(records, first_kind, first_value)
    if operand_count >= 2:
        dir_append_native_operand(records, second_kind, second_value)
    if operand_count >= 3:
        dir_append_native_operand(records, third_kind, third_value)
    append(records, 0)

def dir_append_native_operation(records: list[int], instruction_kind: int, value_type: int, result_value: int, first_kind: int, first_value: int, second_kind: int, second_value: int):
    let operand_mask = DIR_OPERAND_MASK_NATIVE
    if first_kind == DIR_NATIVE_OPERAND_TEMPORARY or second_kind == DIR_NATIVE_OPERAND_TEMPORARY:
        operand_mask = operand_mask + DIR_OPERAND_MASK_TEMPORARY
    if first_kind == DIR_NATIVE_OPERAND_IMMEDIATE or second_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
        operand_mask = operand_mask + DIR_OPERAND_MASK_IMMEDIATE
    append(records, DIR_TAG_INSTRUCTION_BASE + instruction_kind)
    append(records, instruction_kind)
    append(records, value_type)
    append(records, 2)
    append(records, operand_mask)
    dir_append_native_operand(records, DIR_NATIVE_OPERAND_TEMPORARY, result_value)
    dir_append_native_operand(records, first_kind, first_value)
    dir_append_native_operand(records, second_kind, second_value)
    append(records, 0)

def dir_append_native_compare(records: list[int], value_type: int, predicate: int, result_value: int, first_kind: int, first_value: int, second_kind: int, second_value: int):
    let operand_mask = DIR_OPERAND_MASK_NATIVE
    if first_kind == DIR_NATIVE_OPERAND_TEMPORARY or second_kind == DIR_NATIVE_OPERAND_TEMPORARY:
        operand_mask = operand_mask + DIR_OPERAND_MASK_TEMPORARY
    if first_kind == DIR_NATIVE_OPERAND_IMMEDIATE or second_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
        operand_mask = operand_mask + DIR_OPERAND_MASK_IMMEDIATE
    append(records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_ICMP)
    append(records, DIR_OPCODE_ICMP)
    append(records, value_type)
    append(records, 2)
    append(records, operand_mask)
    dir_append_native_operand(records, DIR_NATIVE_OPERAND_TEMPORARY, result_value)
    dir_append_native_operand(records, first_kind, first_value)
    dir_append_native_operand(records, second_kind, second_value)
    dir_append_native_operand(records, DIR_NATIVE_OPERAND_IMMEDIATE, predicate)
    append(records, 0)

def dir_append_native_zext(records: list[int], result_value: int, operand_kind: int, operand_value: int):
    let operand_mask = DIR_OPERAND_MASK_NATIVE
    if operand_kind == DIR_NATIVE_OPERAND_TEMPORARY:
        operand_mask = operand_mask + DIR_OPERAND_MASK_TEMPORARY
    if operand_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
        operand_mask = operand_mask + DIR_OPERAND_MASK_IMMEDIATE
    append(records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_ZEXT)
    append(records, DIR_OPCODE_ZEXT)
    append(records, DIR_TYPE_I32)
    append(records, 1)
    append(records, operand_mask)
    dir_append_native_operand(records, DIR_NATIVE_OPERAND_TEMPORARY, result_value)
    dir_append_native_operand(records, operand_kind, operand_value)
    append(records, 0)

def dir_append_native_unreachable(records: list[int]):
    dir_append_native_record(records, DIR_OPCODE_UNREACHABLE, DIR_TYPE_UNKNOWN, 0, DIR_OPERAND_MASK_NATIVE, DIR_TAG_INVALID, 0, DIR_TAG_INVALID, 0, DIR_TAG_INVALID, 0)

def dir_parse_tail_integer(source: list[int], start: int, end: int) -> int:
    let index = end - 1
    let searching_digits = true
    while index >= start and searching_digits:
        if source[index] >= ord('0') and source[index] <= ord('9'):
            searching_digits = false
        if searching_digits:
            index = index - 1
    let value = 0
    let divisor = 1
    let parsing_digits = true
    while index >= start and parsing_digits:
        if source[index] >= ord('0') and source[index] <= ord('9'):
            let digit_value = source[index] - 48
            let scaled_digit = digit_value * divisor
            value = value + scaled_digit
            divisor = divisor * 10
            index = index - 1
        if index < start:
            parsing_digits = false
        if index >= start:
            if source[index] < ord('0') or source[index] > ord('9'):
                parsing_digits = false
    if index >= start:
        if source[index] == ord('-'):
            return 0 - value
    return value

def dir_parse_temporary_index(source: list[int], start: int, end: int) -> int:
    let index = start
    while index + 1 < end:
        if source[index] == ord('%') and source[index + 1] == ord('t'):
            return dir_parse_tail_integer(source, index + 2, end)
        index = index + 1
    return -1

def dir_parse_native_operand(source: list[int], start: int, end: int) -> (int, int, int):
    if start >= end:
        return (start, DIR_TAG_INVALID, 0)
    if source[start] == ord('%'):
        if start + 1 < end:
            if source[start + 1] == ord('t'):
                let temporary_index = start + 2
                let temporary_value = 0
                if temporary_index >= end:
                    return (temporary_index, DIR_TAG_INVALID, 0)
                while temporary_index < end:
                    let temporary_code = source[temporary_index]
                    if temporary_code < 48 or temporary_code > 57:
                        return (temporary_index, DIR_NATIVE_OPERAND_TEMPORARY, temporary_value)
                    let temporary_digit_value = temporary_code - 48
                    let temporary_shifted_value = temporary_value * 10
                    temporary_value = temporary_shifted_value + temporary_digit_value
                    temporary_index = temporary_index + 1
                return (temporary_index, DIR_NATIVE_OPERAND_TEMPORARY, temporary_value)
    let operand_index = start
    let sign = 1
    if source[operand_index] == ord('-'):
        sign = 0 - 1
        operand_index = operand_index + 1
    let operand_value = 0
    let has_digit = false
    while operand_index < end:
        let operand_code = source[operand_index]
        if operand_code < 48 or operand_code > 57:
            return (operand_index, DIR_NATIVE_OPERAND_IMMEDIATE, sign * operand_value)
        has_digit = true
        let operand_digit_value = operand_code - 48
        let operand_shifted_value = operand_value * 10
        operand_value = operand_shifted_value + operand_digit_value
        operand_index = operand_index + 1
    if has_digit:
        return (operand_index, DIR_NATIVE_OPERAND_IMMEDIATE, sign * operand_value)
    return (start, DIR_TAG_INVALID, 0)

def dir_parse_native_type(source: list[int], start: int, end: int) -> (int, int):
    let normalized_start = dir_skip_spaces(source, start, end)
    if dir_line_has_prefix(source, normalized_start, end, "i1"):
        return (normalized_start + 2, DIR_TYPE_BOOL)
    if dir_line_has_prefix(source, normalized_start, end, "i32"):
        return (normalized_start + 3, DIR_TYPE_I32)
    if dir_line_has_prefix(source, normalized_start, end, "i8*"):
        return (normalized_start + 3, DIR_TYPE_POINTER)
    if dir_line_has_prefix(source, normalized_start, end, "%dynarray_i32*"):
        return (normalized_start + 14, DIR_TYPE_LIST)
    return (normalized_start, DIR_TAG_INVALID)

def dir_is_native_binary_instruction(instruction_kind: int) -> bool:
    if instruction_kind == DIR_OPCODE_ADD or instruction_kind == DIR_OPCODE_SUB or instruction_kind == DIR_OPCODE_MUL or instruction_kind == DIR_OPCODE_SDIV or instruction_kind == DIR_OPCODE_SREM or instruction_kind == DIR_OPCODE_AND or instruction_kind == DIR_OPCODE_OR:
        return true
    return false

def dir_is_native_compare_instruction(instruction_kind: int) -> bool:
    if instruction_kind == DIR_OPCODE_ICMP:
        return true
    return false

def dir_is_native_unary_instruction(instruction_kind: int) -> bool:
    if instruction_kind == DIR_OPCODE_ZEXT:
        return true
    return false

def dir_native_compare_predicate(source: list[int], start: int, end: int) -> int:
    let assignment_start = dir_find_assignment(source, start, end)
    if assignment_start < 0:
        return 0
    let predicate_start = dir_skip_spaces(source, assignment_start + 7, end)
    if dir_line_has_prefix(source, predicate_start, end, "eq "):
        return DIR_PREDICATE_EQ
    if dir_line_has_prefix(source, predicate_start, end, "ne "):
        return DIR_PREDICATE_NE
    if dir_line_has_prefix(source, predicate_start, end, "slt "):
        return DIR_PREDICATE_SLT
    if dir_line_has_prefix(source, predicate_start, end, "sle "):
        return DIR_PREDICATE_SLE
    if dir_line_has_prefix(source, predicate_start, end, "sgt "):
        return DIR_PREDICATE_SGT
    if dir_line_has_prefix(source, predicate_start, end, "sge "):
        return DIR_PREDICATE_SGE
    return 0

def dir_append_native_compare_if_supported(records: list[int], source: list[int], start: int, end: int, value_type: int) -> bool:
    let predicate = dir_native_compare_predicate(source, start, end)
    if predicate == 0 or value_type != DIR_TYPE_BOOL:
        return false
    let assignment_start = dir_find_assignment(source, start, end)
    if assignment_start < 0:
        return false
    let result_start = dir_skip_spaces(source, start, assignment_start)
    let (result_next, result_kind, result_value) = dir_parse_native_operand(source, result_start, assignment_start)
    if result_kind != DIR_NATIVE_OPERAND_TEMPORARY:
        return false
    let type_start = dir_skip_spaces(source, assignment_start + 7, end)
    let type_length = 3
    if predicate == DIR_PREDICATE_SLT or predicate == DIR_PREDICATE_SLE or predicate == DIR_PREDICATE_SGT or predicate == DIR_PREDICATE_SGE:
        type_start = dir_skip_spaces(source, type_start + 4, end)
    if predicate == DIR_PREDICATE_EQ or predicate == DIR_PREDICATE_NE:
        type_start = dir_skip_spaces(source, type_start + 3, end)
    if type_start + type_length >= end:
        return false
    let first_start = dir_skip_spaces(source, type_start + type_length, end)
    let (first_next, first_kind, first_value) = dir_parse_native_operand(source, first_start, end)
    if first_kind == DIR_TAG_INVALID:
        return false
    let second_start = dir_skip_spaces(source, first_next + 1, end)
    let (second_next, second_kind, second_value) = dir_parse_native_operand(source, second_start, end)
    if second_kind == DIR_TAG_INVALID:
        return false
    dir_append_native_compare(records, value_type, predicate, result_value, first_kind, first_value, second_kind, second_value)
    return true

def dir_append_native_zext_if_supported(records: list[int], source: list[int], start: int, end: int) -> bool:
    let assignment_start = dir_find_assignment(source, start, end)
    if assignment_start < 0:
        return false
    let result_start = dir_skip_spaces(source, start, assignment_start)
    let (result_next, result_kind, result_value) = dir_parse_native_operand(source, result_start, assignment_start)
    if result_kind != DIR_NATIVE_OPERAND_TEMPORARY:
        return false
    let opcode_start = assignment_start + 3
    if not dir_line_has_prefix(source, opcode_start, end, "zext "):
        return false
    let input_type_start = dir_skip_spaces(source, opcode_start + 5, end)
    if not dir_line_has_prefix(source, input_type_start, end, "i1 "):
        return false
    let operand_start = dir_skip_spaces(source, input_type_start + 3, end)
    let (operand_next, operand_kind, operand_value) = dir_parse_native_operand(source, operand_start, end)
    if operand_kind == DIR_TAG_INVALID:
        return false
    if not dir_line_contains(source, operand_next, end, "to i32"):
        return false
    dir_append_native_zext(records, result_value, operand_kind, operand_value)
    return true

def dir_append_native_unreachable_if_supported(records: list[int], source: list[int], start: int, end: int) -> bool:
    let normalized_start = dir_skip_spaces(source, start, end)
    if not dir_line_has_prefix(source, normalized_start, end, "unreachable"):
        return false
    let suffix_start = dir_skip_spaces(source, normalized_start + 11, end)
    if suffix_start != end:
        return false
    dir_append_native_unreachable(records)
    return true

def dir_append_native_call_if_simple(records: list[int], source: list[int], start: int, end: int) -> bool:
    let suffix_end = end
    let is_trailing_space = true
    while suffix_end > start and is_trailing_space:
        if source[suffix_end - 1] == ord(' ') or source[suffix_end - 1] == ord('\t'):
            suffix_end = suffix_end - 1
        else:
            is_trailing_space = false
    if suffix_end - start < 2:
        return false
    if source[suffix_end - 1] != ord(')') or source[suffix_end - 2] != ord('('):
        return false
    return dir_append_native_call_if_supported(records, source, start, suffix_end)

def dir_append_native_call_if_supported(records: list[int], source: list[int], start: int, end: int) -> bool:
    let normalized_start = dir_skip_spaces(source, start, end)
    let assignment_start = dir_find_assignment(source, normalized_start, end)
    let instruction_start = normalized_start
    let is_value_call = false
    let result_value = 0
    if assignment_start >= 0:
        let result_start = dir_skip_spaces(source, normalized_start, assignment_start)
        let (result_next, result_kind, parsed_result_value) = dir_parse_native_operand(source, result_start, assignment_start)
        if result_kind != DIR_NATIVE_OPERAND_TEMPORARY or result_next != assignment_start:
            return false
        result_value = parsed_result_value
        instruction_start = dir_skip_spaces(source, assignment_start + 3, end)
        is_value_call = true
    if not dir_line_has_prefix(source, instruction_start, end, "call "):
        return false
    let return_type_start = instruction_start + 5
    let return_type = DIR_TYPE_UNKNOWN
    let symbol_start = return_type_start
    if dir_line_has_prefix(source, return_type_start, end, "void "):
        symbol_start = return_type_start + 5
    else:
        let (parsed_type_end, parsed_return_type) = dir_parse_native_type(source, return_type_start, end)
        if parsed_return_type == DIR_TAG_INVALID:
            return false
        return_type = parsed_return_type
        symbol_start = parsed_type_end
    symbol_start = dir_skip_spaces(source, symbol_start, end)
    if symbol_start >= end or source[symbol_start] != ord('@'):
        return false
    let symbol_name_start = symbol_start + 1
    let symbol_end = symbol_name_start
    let has_open_parenthesis = false
    while symbol_end < end and not has_open_parenthesis:
        if source[symbol_end] == ord('('):
            has_open_parenthesis = true
        if not has_open_parenthesis:
            symbol_end = symbol_end + 1
    if not has_open_parenthesis or symbol_end == symbol_name_start:
        return false
    let comma_count = 0
    let argument_scan_index = symbol_end + 1
    let has_argument_close = false
    while argument_scan_index < end and not has_argument_close:
        if source[argument_scan_index] == ord(')'):
            has_argument_close = true
        if source[argument_scan_index] == ord(','):
            comma_count = comma_count + 1
        if comma_count > 2:
            return false
        argument_scan_index = argument_scan_index + 1
    let argument_types = []
    let argument_kinds = []
    let argument_values = []
    let argument_count = 0
    let argument_cursor = dir_skip_spaces(source, symbol_end + 1, end)
    let has_close_parenthesis = false
    while argument_cursor < end and not has_close_parenthesis:
        if source[argument_cursor] == ord(')'):
            has_close_parenthesis = true
        if not has_close_parenthesis:
            let (type_end, argument_type) = dir_parse_native_type(source, argument_cursor, end)
            if argument_type == DIR_TAG_INVALID:
                return false
            let operand_start = dir_skip_spaces(source, type_end, end)
            let (operand_next, operand_kind, operand_value) = dir_parse_native_operand(source, operand_start, end)
            if operand_kind == DIR_TAG_INVALID:
                return false
            append(argument_types, argument_type)
            append(argument_kinds, operand_kind)
            append(argument_values, operand_value)
            argument_count = argument_count + 1
            argument_cursor = dir_skip_spaces(source, operand_next, end)
            if argument_cursor < end and source[argument_cursor] == ord(','):
                argument_cursor = dir_skip_spaces(source, argument_cursor + 1, end)
            elif argument_cursor < end and source[argument_cursor] != ord(')'):
                return false
    if not has_close_parenthesis:
        return false
    let suffix_end = dir_skip_spaces(source, argument_cursor + 1, end)
    if suffix_end != end:
        return false
    if is_value_call:
        append(records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_CALL_VALUE)
        append(records, DIR_OPCODE_CALL_VALUE)
    if not is_value_call:
        append(records, DIR_TAG_INSTRUCTION_BASE + DIR_OPCODE_CALL)
        append(records, DIR_OPCODE_CALL)
    append(records, return_type)
    append(records, argument_count + 1)
    let operand_mask = DIR_OPERAND_MASK_NATIVE + DIR_NATIVE_OPERAND_SYMBOL
    let argument_index = 0
    while argument_index < argument_count:
        let argument_kind = argument_kinds[argument_index]
        if argument_kind == DIR_NATIVE_OPERAND_TEMPORARY or argument_kind == DIR_NATIVE_OPERAND_IMMEDIATE or argument_kind == DIR_NATIVE_OPERAND_GLOBAL or argument_kind == DIR_NATIVE_OPERAND_LABEL:
            operand_mask = operand_mask + argument_kind
        else:
            return false
        argument_index = argument_index + 1
    append(records, operand_mask)
    if is_value_call:
        dir_append_native_operand(records, DIR_NATIVE_OPERAND_TEMPORARY, result_value)
    dir_append_native_symbol_operand_range(records, source, symbol_name_start, symbol_end)
    argument_index = 0
    while argument_index < argument_count:
        append(records, DIR_NATIVE_OPERAND_TYPE)
        append(records, argument_types[argument_index])
        dir_append_native_operand(records, argument_kinds[argument_index], argument_values[argument_index])
        argument_index = argument_index + 1
    append(records, 0)
    return true

def dir_append_native_binary_if_supported(records: list[int], source: list[int], start: int, end: int, instruction_kind: int, value_type: int) -> bool:
    if not dir_is_native_binary_instruction(instruction_kind):
        return false
    let assignment_start = dir_find_assignment(source, start, end)
    if assignment_start < 0:
        return false
    let result_start = dir_skip_spaces(source, start, assignment_start)
    let (result_next, result_kind, result_value) = dir_parse_native_operand(source, result_start, assignment_start)
    if result_kind != DIR_NATIVE_OPERAND_TEMPORARY:
        return false
    let opcode_start = assignment_start + 3
    let opcode_end = opcode_start
    let has_opcode_end = false
    while opcode_end < end and not has_opcode_end:
        if source[opcode_end] == ord(' '):
            has_opcode_end = true
        if not has_opcode_end:
            opcode_end = opcode_end + 1
    if not has_opcode_end:
        return false
    let type_start = dir_skip_spaces(source, opcode_end, end)
    if type_start + 3 >= end:
        return false
    let first_start = dir_skip_spaces(source, type_start + 3, end)
    let (first_next, first_kind, first_value) = dir_parse_native_operand(source, first_start, end)
    if first_kind == DIR_TAG_INVALID:
        return false
    let comma_index = first_next
    let has_comma = false
    while comma_index < end and not has_comma:
        if source[comma_index] == ord(','):
            has_comma = true
        if not has_comma:
            comma_index = comma_index + 1
    if not has_comma:
        return false
    let second_start = dir_skip_spaces(source, comma_index + 1, end)
    let (second_next, second_kind, second_value) = dir_parse_native_operand(source, second_start, end)
    if second_kind == DIR_TAG_INVALID:
        return false
    dir_append_native_operation(records, instruction_kind, value_type, result_value, first_kind, first_value, second_kind, second_value)
    return true

def dir_append_native_return_if_supported(records: list[int], source: list[int], start: int, end: int, value_type: int) -> bool:
    if dir_line_contains(source, start, end, "ret void"):
        dir_append_native_ret(records, DIR_TYPE_UNKNOWN, DIR_TAG_INVALID, 0)
        return true
    if dir_line_contains(source, start, end, "%t"):
        let temporary_index = dir_parse_temporary_index(source, start, end)
        if temporary_index >= 0:
            dir_append_native_ret(records, value_type, DIR_NATIVE_OPERAND_TEMPORARY, temporary_index)
            return true
    if not dir_line_contains(source, start, end, "%"):
        let immediate_value = dir_parse_tail_integer(source, start, end)
        dir_append_native_ret(records, value_type, DIR_NATIVE_OPERAND_IMMEDIATE, immediate_value)
        return true
    return false

def dir_native_type(output: list[int], value_type: int):
    if value_type == DIR_TYPE_I32:
        dir_append_text(output, "i32")
    if value_type == DIR_TYPE_BOOL:
        dir_append_text(output, "i1")
    if value_type == DIR_TYPE_POINTER:
        dir_append_text(output, "i8*")
    if value_type == DIR_TYPE_LIST:
        dir_append_text(output, "%dynarray_i32*")

def dir_native_operand(output: list[int], operand_kind: int, operand_value: int):
    if operand_kind == DIR_NATIVE_OPERAND_TEMPORARY:
        dir_append_text(output, "%t")
        dir_append_integer(output, operand_value)
    if operand_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
        dir_append_integer(output, operand_value)
    if operand_kind == DIR_NATIVE_OPERAND_GLOBAL:
        dir_append_text(output, "@dir_global_")
        dir_append_integer(output, operand_value)
    if operand_kind == DIR_NATIVE_OPERAND_LABEL:
        dir_append_text(output, "%dir_block_")
        dir_append_integer(output, operand_value)

def dir_native_symbol(output: list[int], records: list[int], start: int):
    let symbol_length = records[start + 1]
    append(output, 64)
    let index = start + 2
    let symbol_end = index + symbol_length
    while index < symbol_end:
        append(output, records[index])
        index = index + 1

def dir_render_native_operand(output: list[int], records: list[int], start: int, end: int) -> int:
    let payload_length = dir_native_operand_payload_length(records, start, end)
    if payload_length == 0:
        return 0
    let operand_kind = records[start]
    if operand_kind == DIR_NATIVE_OPERAND_SYMBOL:
        dir_native_symbol(output, records, start)
    if operand_kind != DIR_NATIVE_OPERAND_SYMBOL:
        dir_native_operand(output, operand_kind, records[start + 1])
    return payload_length

def dir_native_record_payload_length(records: list[int], start: int, instruction_kind: int, operand_count: int) -> int:
    let cursor = start
    let has_result = dir_is_native_binary_instruction(instruction_kind)
    if dir_is_native_compare_instruction(instruction_kind) or dir_is_native_unary_instruction(instruction_kind):
        has_result = true
    if instruction_kind == DIR_OPCODE_CALL_VALUE:
        has_result = true
    if has_result:
        if cursor + 1 >= len(records):
            return -1
        cursor = cursor + 2
    if instruction_kind == DIR_OPCODE_CALL or instruction_kind == DIR_OPCODE_CALL_VALUE:
        if operand_count < 1:
            return -1
        let symbol_length = dir_native_operand_payload_length(records, cursor, len(records))
        if records[cursor] != DIR_NATIVE_OPERAND_SYMBOL or symbol_length == 0:
            return -1
        cursor = cursor + symbol_length
        let argument_index = 1
        while argument_index < operand_count:
            if cursor + 1 >= len(records) or records[cursor] != DIR_NATIVE_OPERAND_TYPE:
                return -1
            cursor = cursor + 2
            let argument_length = dir_native_operand_payload_length(records, cursor, len(records))
            if argument_length == 0:
                return -1
            cursor = cursor + argument_length
            argument_index = argument_index + 1
        return cursor - start
    let operand_index = 0
    while operand_index < operand_count:
        let operand_length = dir_native_operand_payload_length(records, cursor, len(records))
        if operand_length == 0:
            return -1
        cursor = cursor + operand_length
        operand_index = operand_index + 1
    if dir_is_native_compare_instruction(instruction_kind):
        if cursor + 1 >= len(records):
            return -1
        cursor = cursor + 2
    return cursor - start

def dir_native_operand_mask_is_valid(operand_mask: int, first_kind: int, second_kind: int, third_kind: int, operand_count: int) -> bool:
    let expected_mask = DIR_OPERAND_MASK_NATIVE
    let has_temporary = false
    let has_immediate = false
    let has_global = false
    let has_label = false
    let has_symbol = false
    if operand_count >= 1:
        if first_kind == DIR_NATIVE_OPERAND_TEMPORARY:
            has_temporary = true
        if first_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
            has_immediate = true
        if first_kind == DIR_NATIVE_OPERAND_GLOBAL:
            has_global = true
        if first_kind == DIR_NATIVE_OPERAND_LABEL:
            has_label = true
        if first_kind == DIR_NATIVE_OPERAND_SYMBOL:
            has_symbol = true
    if operand_count >= 2:
        if second_kind == DIR_NATIVE_OPERAND_TEMPORARY:
            has_temporary = true
        if second_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
            has_immediate = true
        if second_kind == DIR_NATIVE_OPERAND_GLOBAL:
            has_global = true
        if second_kind == DIR_NATIVE_OPERAND_LABEL:
            has_label = true
        if second_kind == DIR_NATIVE_OPERAND_SYMBOL:
            has_symbol = true
    if operand_count >= 3:
        if third_kind == DIR_NATIVE_OPERAND_TEMPORARY:
            has_temporary = true
        if third_kind == DIR_NATIVE_OPERAND_IMMEDIATE:
            has_immediate = true
        if third_kind == DIR_NATIVE_OPERAND_GLOBAL:
            has_global = true
        if third_kind == DIR_NATIVE_OPERAND_LABEL:
            has_label = true
        if third_kind == DIR_NATIVE_OPERAND_SYMBOL:
            has_symbol = true
    if has_temporary:
        expected_mask = expected_mask + DIR_NATIVE_OPERAND_TEMPORARY
    if has_immediate:
        expected_mask = expected_mask + DIR_NATIVE_OPERAND_IMMEDIATE
    if has_global:
        expected_mask = expected_mask + DIR_NATIVE_OPERAND_GLOBAL
    if has_label:
        expected_mask = expected_mask + DIR_NATIVE_OPERAND_LABEL
    if has_symbol:
        expected_mask = expected_mask + DIR_NATIVE_OPERAND_SYMBOL
    if expected_mask == operand_mask:
        return true
    return false

def dir_native_operand_mask_is_valid_range(records: list[int], start: int, end: int, operand_count: int, operand_mask: int) -> bool:
    let expected_mask = DIR_OPERAND_MASK_NATIVE
    let cursor = start
    let operand_index = 0
    while operand_index < operand_count:
        let operand_length = dir_native_operand_payload_length(records, cursor, end)
        if operand_length == 0:
            return false
        let operand_kind = records[cursor]
        if operand_kind == DIR_NATIVE_OPERAND_TEMPORARY or operand_kind == DIR_NATIVE_OPERAND_IMMEDIATE or operand_kind == DIR_NATIVE_OPERAND_GLOBAL or operand_kind == DIR_NATIVE_OPERAND_LABEL or operand_kind == DIR_NATIVE_OPERAND_SYMBOL:
            expected_mask = expected_mask + operand_kind
        else:
            return false
        cursor = cursor + operand_length
        operand_index = operand_index + 1
    if expected_mask == operand_mask:
        return true
    return false

def dir_render_native_record(records: list[int], start: int, end: int, instruction_kind: int, value_type: int, operand_count: int, operand_mask: int, output: list[int]) -> bool:
    let has_result = dir_is_native_binary_instruction(instruction_kind)
    let is_compare = dir_is_native_compare_instruction(instruction_kind)
    let is_unary = dir_is_native_unary_instruction(instruction_kind)
    let is_call = false
    if instruction_kind == DIR_OPCODE_CALL:
        is_call = true
    let is_unreachable = false
    if instruction_kind == DIR_OPCODE_UNREACHABLE:
        is_unreachable = true
    if is_compare:
        has_result = true
    if is_unary:
        has_result = true
    if instruction_kind == DIR_OPCODE_CALL_VALUE:
        has_result = true
    let operand_start = start
    let result_kind = DIR_TAG_INVALID
    let result_value = 0
    if has_result:
        if operand_start + 1 >= end:
            return false
        result_kind = records[operand_start]
        result_value = records[operand_start + 1]
        operand_start = start + 2
    if is_call or instruction_kind == DIR_OPCODE_CALL_VALUE:
        let call_cursor = operand_start
        let function_length = dir_native_operand_payload_length(records, call_cursor, end)
        if function_length == 0 or records[call_cursor] != DIR_NATIVE_OPERAND_SYMBOL:
            return false
        let function_start = call_cursor
        call_cursor = call_cursor + function_length
        let argument_index = 1
        let expected_mask = DIR_OPERAND_MASK_NATIVE + DIR_NATIVE_OPERAND_SYMBOL
        while argument_index < operand_count:
            if call_cursor + 1 >= end or records[call_cursor] != DIR_NATIVE_OPERAND_TYPE:
                return false
            let call_argument_type_value = records[call_cursor + 1]
            if call_argument_type_value != DIR_TYPE_I32 and call_argument_type_value != DIR_TYPE_BOOL and call_argument_type_value != DIR_TYPE_POINTER and call_argument_type_value != DIR_TYPE_LIST:
                return false
            call_cursor = call_cursor + 2
            let call_argument_payload_length = dir_native_operand_payload_length(records, call_cursor, end)
            if call_argument_payload_length == 0:
                return false
            let call_argument_operand_kind = records[call_cursor]
            if call_argument_operand_kind != DIR_NATIVE_OPERAND_TEMPORARY and call_argument_operand_kind != DIR_NATIVE_OPERAND_IMMEDIATE and call_argument_operand_kind != DIR_NATIVE_OPERAND_GLOBAL and call_argument_operand_kind != DIR_NATIVE_OPERAND_LABEL:
                return false
            expected_mask = expected_mask + call_argument_operand_kind
            call_cursor = call_cursor + call_argument_payload_length
            argument_index = argument_index + 1
        if call_cursor != end or expected_mask != operand_mask:
            return false
        if instruction_kind == DIR_OPCODE_CALL_VALUE:
            if result_kind != DIR_NATIVE_OPERAND_TEMPORARY or value_type == DIR_TYPE_UNKNOWN:
                return false
        if instruction_kind == DIR_OPCODE_CALL:
            if value_type != DIR_TYPE_UNKNOWN:
                return false
        if instruction_kind == DIR_OPCODE_CALL_VALUE:
            dir_native_operand(output, result_kind, result_value)
            dir_append_text(output, " = call ")
            dir_native_type(output, value_type)
            append(output, 32)
        if instruction_kind == DIR_OPCODE_CALL:
            dir_append_text(output, "call void ")
        dir_native_symbol(output, records, function_start)
        append(output, 40)
        call_cursor = function_start + function_length
        argument_index = 1
        while argument_index < operand_count:
            let rendered_argument_type = records[call_cursor + 1]
            call_cursor = call_cursor + 2
            dir_native_type(output, rendered_argument_type)
            append(output, 32)
            let rendered_argument_length = dir_render_native_operand(output, records, call_cursor, end)
            if rendered_argument_length == 0:
                return false
            call_cursor = call_cursor + rendered_argument_length
            if argument_index + 1 < operand_count:
                append(output, 44)
                append(output, 32)
            argument_index = argument_index + 1
        dir_append_text(output, ")")
        append(output, 10)
        return true
    let first_kind = DIR_TAG_INVALID
    let first_value = 0
    let first_start = operand_start
    let second_kind = DIR_TAG_INVALID
    let second_value = 0
    let second_start = operand_start
    let third_kind = DIR_TAG_INVALID
    let third_value = 0
    let third_start = operand_start
    let predicate_kind = DIR_TAG_INVALID
    let predicate = 0
    let operand_cursor = operand_start
    if operand_count >= 1:
        first_start = operand_cursor
        let first_length = dir_native_operand_payload_length(records, first_start, end)
        if first_length == 0:
            return false
        first_kind = records[first_start]
        if first_kind != DIR_NATIVE_OPERAND_SYMBOL:
            first_value = records[first_start + 1]
        operand_cursor = operand_cursor + first_length
    if operand_count >= 2:
        second_start = operand_cursor
        let second_length = dir_native_operand_payload_length(records, second_start, end)
        if second_length == 0:
            return false
        second_kind = records[second_start]
        if second_kind != DIR_NATIVE_OPERAND_SYMBOL:
            second_value = records[second_start + 1]
        operand_cursor = operand_cursor + second_length
    if operand_count >= 3:
        third_start = operand_cursor
        let third_length = dir_native_operand_payload_length(records, third_start, end)
        if third_length == 0:
            return false
        third_kind = records[third_start]
        if third_kind != DIR_NATIVE_OPERAND_SYMBOL:
            third_value = records[third_start + 1]
        operand_cursor = operand_cursor + third_length
    if is_compare:
        let predicate_start = operand_cursor
        if predicate_start + 1 >= end:
            return false
        predicate_kind = records[predicate_start]
        predicate = records[predicate_start + 1]
        operand_cursor = operand_cursor + 2
    if operand_cursor != end:
        return false
    if not dir_native_operand_mask_is_valid(operand_mask, first_kind, second_kind, third_kind, operand_count):
        return false
    if instruction_kind == DIR_OPCODE_RET:
        if operand_count == 1 and value_type == DIR_TYPE_UNKNOWN:
            return false
        if operand_count == 0:
            dir_append_text(output, "ret void")
        if operand_count == 1:
            dir_append_text(output, "ret ")
            dir_native_type(output, value_type)
            append(output, 32)
            dir_render_native_operand(output, records, first_start, end)
    if instruction_kind == DIR_OPCODE_BR:
        if operand_count == 1:
            if first_kind != DIR_NATIVE_OPERAND_LABEL:
                return false
            dir_append_text(output, "br label ")
            dir_render_native_operand(output, records, first_start, end)
        if operand_count == 3:
            if first_kind != DIR_NATIVE_OPERAND_TEMPORARY:
                return false
            if second_kind != DIR_NATIVE_OPERAND_LABEL:
                return false
            if third_kind != DIR_NATIVE_OPERAND_LABEL:
                return false
            dir_append_text(output, "br i1 ")
            dir_render_native_operand(output, records, first_start, end)
            dir_append_text(output, ", label ")
            dir_render_native_operand(output, records, second_start, end)
            dir_append_text(output, ", label ")
            dir_render_native_operand(output, records, third_start, end)
    if is_call:
        if operand_count != 1 or value_type != DIR_TYPE_UNKNOWN:
            return false
        if first_kind != DIR_NATIVE_OPERAND_SYMBOL:
            return false
        dir_append_text(output, "call void ")
        dir_render_native_operand(output, records, first_start, end)
        dir_append_text(output, "()")
    if is_unreachable:
        if operand_count != 0 or value_type != DIR_TYPE_UNKNOWN:
            return false
        dir_append_text(output, "unreachable")
    if is_compare:
        if result_kind != DIR_NATIVE_OPERAND_TEMPORARY or value_type != DIR_TYPE_BOOL:
            return false
        if predicate_kind != DIR_NATIVE_OPERAND_IMMEDIATE:
            return false
        dir_native_operand(output, result_kind, result_value)
        append(output, 32)
        dir_append_text(output, "= icmp ")
        if predicate == DIR_PREDICATE_EQ:
            dir_append_text(output, "eq")
        if predicate == DIR_PREDICATE_NE:
            dir_append_text(output, "ne")
        if predicate == DIR_PREDICATE_SLT:
            dir_append_text(output, "slt")
        if predicate == DIR_PREDICATE_SLE:
            dir_append_text(output, "sle")
        if predicate == DIR_PREDICATE_SGT:
            dir_append_text(output, "sgt")
        if predicate == DIR_PREDICATE_SGE:
            dir_append_text(output, "sge")
        dir_append_text(output, " i32 ")
        dir_render_native_operand(output, records, first_start, end)
        append(output, 44)
        append(output, 32)
        dir_render_native_operand(output, records, second_start, end)
    if is_unary:
        if result_kind != DIR_NATIVE_OPERAND_TEMPORARY or value_type != DIR_TYPE_I32:
            return false
        if first_kind != DIR_NATIVE_OPERAND_TEMPORARY:
            return false
        dir_native_operand(output, result_kind, result_value)
        append(output, 32)
        dir_append_text(output, "= zext i1 ")
        dir_render_native_operand(output, records, first_start, end)
        dir_append_text(output, " to i32")
    if has_result:
        if not is_compare and not is_unary:
            if result_kind != DIR_NATIVE_OPERAND_TEMPORARY:
                return false
            if value_type != DIR_TYPE_I32:
                return false
        if not is_compare and not is_unary:
            dir_native_operand(output, result_kind, result_value)
            append(output, 32)
            if instruction_kind == DIR_OPCODE_ADD:
                dir_append_text(output, "= add ")
            if instruction_kind == DIR_OPCODE_SUB:
                dir_append_text(output, "= sub ")
            if instruction_kind == DIR_OPCODE_MUL:
                dir_append_text(output, "= mul ")
            if instruction_kind == DIR_OPCODE_SDIV:
                dir_append_text(output, "= sdiv ")
            if instruction_kind == DIR_OPCODE_SREM:
                dir_append_text(output, "= srem ")
            if instruction_kind == DIR_OPCODE_AND:
                dir_append_text(output, "= and ")
            if instruction_kind == DIR_OPCODE_OR:
                dir_append_text(output, "= or ")
            dir_native_type(output, value_type)
            append(output, 32)
            dir_render_native_operand(output, records, first_start, end)
            append(output, 44)
            append(output, 32)
            dir_render_native_operand(output, records, second_start, end)
    if not has_result and instruction_kind != DIR_OPCODE_RET and instruction_kind != DIR_OPCODE_BR and not is_call and not is_unreachable:
        return false
    append(output, 10)
    return true

def dir_build_records(source: list[int], line_starts: list[int], line_ends: list[int], records: list[int]) -> bool:
    let inside_function = false
    let is_valid = true
    let line_index = 0
    while line_index < len(line_starts):
        let line_start = line_starts[line_index]
        let line_end = line_ends[line_index]
        let line_kind = dir_line_kind(source, line_start, line_end)
        if line_kind == DIR_LINE_FUNCTION_BEGIN:
            if inside_function:
                is_valid = false
            inside_function = true
        if line_kind == DIR_LINE_FUNCTION_END:
            if not inside_function:
                is_valid = false
            inside_function = false
        if line_kind == DIR_LINE_BLOCK or line_kind == DIR_LINE_INSTRUCTION:
            if not inside_function:
                is_valid = false
        let instruction_kind = 0
        if line_kind == DIR_LINE_INSTRUCTION:
            instruction_kind = dir_instruction_kind(source, line_start, line_end)
            if inside_function and instruction_kind == DIR_TAG_INVALID:
                is_valid = false
        if line_kind == DIR_TAG_INVALID:
            is_valid = false
        let record_kind = dir_record_kind(line_kind, instruction_kind)
        let value_type = 0
        let operand_count = 0
        let operand_mask = DIR_OPERAND_MASK_NONE
        if line_kind == DIR_LINE_INSTRUCTION:
            value_type = dir_instruction_type(source, line_start, line_end)
            operand_count = dir_instruction_operand_count(source, line_start, line_end, instruction_kind)
            operand_mask = dir_instruction_operand_mask(source, line_start, line_end, instruction_kind)
        let native_record_added = false
        if line_kind == DIR_LINE_INSTRUCTION and instruction_kind == DIR_OPCODE_RET:
            native_record_added = dir_append_native_return_if_supported(records, source, line_start, line_end, value_type)
        if not native_record_added and line_kind == DIR_LINE_INSTRUCTION and (instruction_kind == DIR_OPCODE_CALL or instruction_kind == DIR_OPCODE_CALL_VALUE):
            native_record_added = dir_append_native_call_if_simple(records, source, line_start, line_end)
        if not native_record_added and line_kind == DIR_LINE_INSTRUCTION and dir_is_native_binary_instruction(instruction_kind):
            native_record_added = dir_append_native_binary_if_supported(records, source, line_start, line_end, instruction_kind, value_type)
        if not native_record_added and line_kind == DIR_LINE_INSTRUCTION and dir_is_native_compare_instruction(instruction_kind):
            native_record_added = dir_append_native_compare_if_supported(records, source, line_start, line_end, value_type)
        if not native_record_added and line_kind == DIR_LINE_INSTRUCTION and dir_is_native_unary_instruction(instruction_kind):
            native_record_added = dir_append_native_zext_if_supported(records, source, line_start, line_end)
        if not native_record_added and line_kind == DIR_LINE_INSTRUCTION and instruction_kind == DIR_OPCODE_UNREACHABLE:
            native_record_added = dir_append_native_unreachable_if_supported(records, source, line_start, line_end)
        if not native_record_added:
            dir_append_record(records, record_kind, instruction_kind, value_type, operand_count, operand_mask, source, line_start, line_end)
        line_index = line_index + 1
    if inside_function:
        is_valid = false
    return is_valid

def dir_render_records(records: list[int], output: list[int]) -> bool:
    let record_index = 0
    let record_count = 0
    let native_record_count = 0
    while record_index < len(records):
        if record_index + DIR_RECORD_HEADER_SIZE - 1 >= len(records):
            return false
        let record_kind = records[record_index]
        record_index = record_index + 1
        let instruction_kind = records[record_index]
        record_index = record_index + 1
        let value_type = records[record_index]
        record_index = record_index + 1
        let operand_count = records[record_index]
        record_index = record_index + 1
        let operand_mask = records[record_index]
        record_index = record_index + 1
        if not dir_record_kind_is_valid(record_kind):
            return false
        if record_kind > DIR_TAG_INSTRUCTION_BASE:
            let expected_record_kind = DIR_TAG_INSTRUCTION_BASE + instruction_kind
            if instruction_kind <= DIR_TAG_INVALID or record_kind != expected_record_kind:
                return false
        if record_kind <= DIR_TAG_INSTRUCTION_BASE and instruction_kind != DIR_TAG_INVALID:
            return false
        if value_type < DIR_TYPE_UNKNOWN or value_type > DIR_TYPE_BOOL:
            return false
        if record_kind > DIR_TAG_INSTRUCTION_BASE:
            if not dir_operand_count_is_valid(instruction_kind, operand_count):
                return false
        if record_kind <= DIR_TAG_INSTRUCTION_BASE and operand_count != 0:
            return false
        if record_kind <= DIR_TAG_INSTRUCTION_BASE and operand_mask != DIR_OPERAND_MASK_NONE:
            return false
        let payload_start = record_index
        let has_record_end = false
        let is_native_record = false
        if record_kind > DIR_TAG_INSTRUCTION_BASE and operand_mask >= DIR_OPERAND_MASK_NATIVE:
            is_native_record = true
            native_record_count = native_record_count + 1
            let native_payload_length = dir_native_record_payload_length(records, payload_start, instruction_kind, operand_count)
            if native_payload_length < 0:
                return false
            let native_payload_end = payload_start + native_payload_length
            if native_payload_end >= len(records) or records[native_payload_end] != 0:
                return false
            record_index = native_payload_end
            has_record_end = true
        if not is_native_record:
            while record_index < len(records) and not has_record_end:
                if records[record_index] == 0:
                    has_record_end = true
                if records[record_index] != 0:
                    record_index = record_index + 1
        if not has_record_end:
            return false
        if record_kind > DIR_TAG_INSTRUCTION_BASE and operand_mask >= DIR_OPERAND_MASK_NATIVE:
            let native_render_status = dir_render_native_record(records, payload_start, record_index, instruction_kind, value_type, operand_count, operand_mask, output)
            if not native_render_status:
                return false
        if record_kind > DIR_TAG_INSTRUCTION_BASE and operand_mask < DIR_OPERAND_MASK_NATIVE:
            let actual_operand_mask = dir_instruction_operand_mask(records, payload_start, record_index, instruction_kind)
            if actual_operand_mask != operand_mask:
                return false
            let raw_payload_index = payload_start
            while raw_payload_index < record_index:
                append(output, records[raw_payload_index])
                raw_payload_index = raw_payload_index + 1
            append(output, 10)
        if record_kind <= DIR_TAG_INSTRUCTION_BASE:
            let metadata_payload_index = payload_start
            while metadata_payload_index < record_index:
                append(output, records[metadata_payload_index])
                metadata_payload_index = metadata_payload_index + 1
            append(output, 10)
        record_count = record_count + 1
        record_index = record_index + 1
    dir_append_text(output, "; DIR records=")
    dir_append_integer(output, record_count)
    dir_append_text(output, " native=")
    dir_append_integer(output, native_record_count)
    append(output, 10)
    return true

def dir_lower_buffer(llvm_output: list[int], dir_output: list[int]) -> bool:
    let line_starts = []
    let line_ends = []
    dir_split_lines(llvm_output, line_starts, line_ends)
    dir_render_lines(llvm_output, line_starts, line_ends, dir_output)
    dir_append_text(dir_output, "; DIR records=")
    dir_append_integer(dir_output, len(line_starts))
    dir_append_text(dir_output, " native=0")
    append(dir_output, 10)
    return true
