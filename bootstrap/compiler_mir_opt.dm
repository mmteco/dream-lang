from compiler_mir_model import MirProgram, MirRecord, mir_record_count, mir_value_count, mir_record_offset
from compiler_mir_model import mir_value_offset, mir_append_record, mir_append_operand, MIR_RECORD_MODULE
from compiler_mir_model import MIR_RECORD_FUNCTION, MIR_RECORD_BLOCK, MIR_RECORD_PARAMETER, MIR_RECORD_INSTRUCTION
from compiler_mir_model import MIR_RECORD_TERMINATOR, MIR_OPERAND_VALUE, MIR_OPERAND_INT, MIR_OPERAND_BLOCK
from compiler_mir_model import MIR_OPERAND_TYPE, MIR_TYPE_BOOL, MIR_TYPE_I32, MIR_OP_CONST, MIR_OP_BINARY, MIR_OP_UNARY
from compiler_mir_model import MIR_OP_SELECT, MIR_OP_CAST, MIR_OP_LOCAL, MIR_OP_SEQUENCE, MIR_TERM_JUMP, MIR_TERM_BRANCH
from compiler_mir_model import MIR_TERM_SWITCH
from compiler_operator import IR_OPERATOR_ADD, IR_OPERATOR_SUB, IR_OPERATOR_MUL, IR_OPERATOR_DIV, IR_OPERATOR_MOD
from compiler_operator import IR_OPERATOR_LT, IR_OPERATOR_GT, IR_OPERATOR_LE, IR_OPERATOR_GE, IR_OPERATOR_EQ
from compiler_operator import IR_OPERATOR_NE, IR_OPERATOR_AND, IR_OPERATOR_OR

def mir_opt_max_result(program: MirProgram) -> int:
    let maximum = -1
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let result_value = program.records[mir_record_offset(record_id) + 5]
        if result_value > maximum:
            maximum = result_value
        record_id = record_id + 1
    return maximum

def mir_opt_resolve(replacements: list[int], value: int) -> int:
    let current = value
    let guard = 0
    while current >= 0 and current < len(replacements) and guard < len(replacements):
        if replacements[current] < 0:
            return current
        current = replacements[current]
        guard = guard + 1
    return current

def mir_opt_operand_value(program: MirProgram, record_offset: int, operand_index: int, constant_flags: list[int],
    constant_values: list[int]) -> int:
    let operand_start = program.records[record_offset + 6]
    let operand_count = program.records[record_offset + 7]
    if operand_index < 0 or operand_index >= operand_count:
        return -1
    let value_offset = mir_value_offset(operand_start + operand_index)
    let operand_kind = program.values[value_offset]
    let operand_value = program.values[value_offset + 1]
    if operand_kind == MIR_OPERAND_INT:
        return operand_value
    if operand_kind == MIR_OPERAND_VALUE:
        if operand_value >= 0 and operand_value < len(constant_flags):
            if constant_flags[operand_value] != 0:
                return constant_values[operand_value]
    return -1

def mir_opt_read_constant(program: MirProgram, record_offset: int, operand_index: int, constant_flags: list[int],
    constant_values: list[int], result: list[int]) -> bool:
    let operand_start = program.records[record_offset + 6]
    let operand_count = program.records[record_offset + 7]
    if operand_index < 0 or operand_index >= operand_count:
        return false
    let value_offset = mir_value_offset(operand_start + operand_index)
    let operand_kind = program.values[value_offset]
    let operand_value = program.values[value_offset + 1]
    if operand_kind == MIR_OPERAND_INT:
        result[0] = operand_value
        return true
    if operand_kind == MIR_OPERAND_VALUE and operand_value >= 0 and operand_value < len(constant_flags):
        if constant_flags[operand_value] != 0:
            result[0] = constant_values[operand_value]
            return true
    return false

def mir_opt_binary(operator: int, left: int, right: int, result_type: int, result: list[int]) -> bool:
    if operator == IR_OPERATOR_ADD:
        result[0] = left + right
        return true
    if operator == IR_OPERATOR_SUB:
        result[0] = left - right
        return true
    if operator == IR_OPERATOR_MUL:
        result[0] = left * right
        return true
    if operator == IR_OPERATOR_DIV and right != 0:
        result[0] = left / right
        return true
    if operator == IR_OPERATOR_MOD and right != 0:
        result[0] = left % right
        return true
    if operator == IR_OPERATOR_LT:
        result[0] = 0
        if left < right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_GT:
        result[0] = 0
        if left > right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_LE:
        result[0] = 0
        if left <= right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_GE:
        result[0] = 0
        if left >= right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_EQ:
        result[0] = 0
        if left == right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_NE:
        result[0] = 0
        if left != right:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_AND:
        result[0] = 0
        if left != 0 and right != 0:
            result[0] = 1
        return true
    if operator == IR_OPERATOR_OR:
        result[0] = 0
        if left != 0 or right != 0:
            result[0] = 1
        return true
    return false

def mir_opt_append_rewritten_operands(program: MirProgram, record_offset: int, replacements: list[int],
    constant_flags: list[int], constant_values: list[int], values: list[int]):
    let operand_start = program.records[record_offset + 6]
    let operand_count = program.records[record_offset + 7]
    let operand_index = 0
    while operand_index < operand_count:
        let source_offset = mir_value_offset(operand_start + operand_index)
        let operand_kind = program.values[source_offset]
        let operand_value = program.values[source_offset + 1]
        if operand_kind == MIR_OPERAND_VALUE:
            operand_value = mir_opt_resolve(replacements, operand_value)
            if operand_value >= 0 and operand_value < len(constant_flags):
                if constant_flags[operand_value] != 0:
                    operand_kind = MIR_OPERAND_INT
                    operand_value = constant_values[operand_value]
        mir_append_operand(values, operand_kind, operand_value)
        operand_index = operand_index + 1

def mir_opt_append_auxiliary(program: MirProgram, record_offset: int, values: list[int]) -> int:
    let auxiliary_start = program.records[record_offset + 8]
    let auxiliary_count = program.records[record_offset + 9]
    let target_start = mir_value_count(values)
    let index = 0
    while index < auxiliary_count:
        let source_offset = mir_value_offset(auxiliary_start + index)
        mir_append_operand(values, program.values[source_offset], program.values[source_offset + 1])
        index = index + 1
    return target_start

def mir_opt_same_constant(keys: list[int], types: list[int], values: list[int], type_tag: int, value: int) -> int:
    let index = 0
    while index < len(keys):
        if keys[index] == value and types[index] == type_tag:
            return values[index]
        index = index + 1
    return -1

def mir_opt_constant_fold(program: MirProgram) -> MirProgram:
    let maximum = mir_opt_max_result(program)
    let constant_flags: list[int] = []
    let constant_values: list[int] = []
    let replacements: list[int] = []
    let value_index = 0
    while value_index <= maximum:
        append(constant_flags, 0)
        append(constant_values, 0)
        append(replacements, -1)
        value_index = value_index + 1
    let constant_keys: list[int] = []
    let constant_types: list[int] = []
    let constant_results: list[int] = []
    let records = []
    let values = []
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let source_offset = mir_record_offset(record_id)
        let record_kind = program.records[source_offset]
        let opcode = program.records[source_offset + 3]
        let type_tag = program.records[source_offset + 4]
        let result_value = program.records[source_offset + 5]
        let target_opcode = opcode
        let folded = false
        let folded_value = 0
        if record_kind == MIR_RECORD_FUNCTION:
            let reset_index = 0
            while reset_index < len(constant_flags):
                constant_flags[reset_index] = 0
                constant_values[reset_index] = 0
                replacements[reset_index] = -1
                reset_index = reset_index + 1
            constant_keys = []
            constant_types = []
            constant_results = []
        if record_kind == MIR_RECORD_INSTRUCTION and opcode == MIR_OP_CONST and type_tag in [MIR_TYPE_BOOL,
            MIR_TYPE_I32]:
            let immediate: list[int] = [0]
            if mir_opt_read_constant(program, source_offset, 0, constant_flags, constant_values, immediate):
                folded = true
                folded_value = immediate[0]
        elif record_kind == MIR_RECORD_INSTRUCTION and opcode == MIR_OP_BINARY:
            let operator_value: list[int] = [0]
            let left_value: list[int] = [0]
            let right_value: list[int] = [0]
            let folded_result: list[int] = [0]
            let has_operator = mir_opt_read_constant(program, source_offset, 0, constant_flags, constant_values,
                operator_value)
            let has_left = mir_opt_read_constant(program, source_offset, 1, constant_flags, constant_values, left_value)
            let has_right = mir_opt_read_constant(program, source_offset, 2, constant_flags, constant_values,
                right_value)
            if has_operator and has_left and has_right and mir_opt_binary(operator_value[0], left_value[0],
                right_value[0], type_tag, folded_result):
                folded = true
                folded_value = folded_result[0]
                target_opcode = MIR_OP_CONST
        elif record_kind == MIR_RECORD_INSTRUCTION and opcode == MIR_OP_SELECT:
            let condition_value: list[int] = [0]
            let has_condition = mir_opt_read_constant(program, source_offset, 0, constant_flags, constant_values,
                condition_value)
            let selected_index = 1
            if has_condition and condition_value[0] == 0:
                selected_index = 2
            let selected_value: list[int] = [0]
            let has_selected = mir_opt_read_constant(program, source_offset, selected_index, constant_flags,
                constant_values, selected_value)
            if has_condition and has_selected:
                folded = true
                folded_value = selected_value[0]
                target_opcode = MIR_OP_CONST
        let replacement = -1
        if folded and result_value >= 0:
            replacement = mir_opt_same_constant(constant_keys, constant_types, constant_results, type_tag, folded_value)
            if replacement >= 0 and result_value < len(replacements):
                replacements[result_value] = replacement
            else:
                append(constant_keys, folded_value)
                append(constant_types, type_tag)
                append(constant_results, result_value)
                if result_value >= 0 and result_value < len(constant_flags):
                    constant_flags[result_value] = 1
                    constant_values[result_value] = folded_value
        if replacement < 0:
            let operand_start = mir_value_count(values)
            if folded:
                mir_append_operand(values, MIR_OPERAND_INT, folded_value)
            else:
                mir_opt_append_rewritten_operands(program, source_offset, replacements, constant_flags, constant_values,
                    values)
            let operand_count = mir_value_count(values) - operand_start
            let auxiliary_start = mir_opt_append_auxiliary(program, source_offset, values)
            let auxiliary_count = program.records[source_offset + 9]
            let target = MirRecord{
                record_kind: record_kind,
                func_index: program.records[source_offset + 1],
                block_index: program.records[source_offset + 2],
                opcode: target_opcode,
                type_tag: type_tag,
                result_value: result_value,
                operand_start: operand_start,
                operand_count: operand_count,
                auxiliary_start: auxiliary_start,
                auxiliary_count: auxiliary_count,
                source_start: program.records[source_offset + 10],
                source_end: program.records[source_offset + 11]
            }
            mir_append_record(records, target)
        record_id = record_id + 1
    return MirProgram{records: records, values: values}

def mir_opt_is_pure(opcode: int) -> bool:
    return (
        opcode == MIR_OP_CONST or
        opcode == MIR_OP_LOCAL or
        opcode == MIR_OP_BINARY or
        opcode == MIR_OP_UNARY or
        opcode == MIR_OP_SELECT or
        opcode == MIR_OP_CAST or
        opcode == MIR_OP_SEQUENCE
    )

def mir_opt_mark_used(program: MirProgram, used: list[int]):
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let offset = mir_record_offset(record_id)
        let operand_start = program.records[offset + 6]
        let operand_count = program.records[offset + 7]
        let operand_index = 0
        while operand_index < operand_count:
            let value_offset = mir_value_offset(operand_start + operand_index)
            if program.values[value_offset] == MIR_OPERAND_VALUE:
                let value = program.values[value_offset + 1]
                if value >= 0 and value < len(used):
                    used[value] = 1
            operand_index = operand_index + 1
        record_id = record_id + 1

def mir_opt_dce(program: MirProgram) -> MirProgram:
    let maximum = mir_opt_max_result(program)
    let used: list[int] = []
    let value_index = 0
    while value_index <= maximum:
        append(used, 0)
        value_index = value_index + 1
    mir_opt_mark_used(program, used)
    let records = []
    let values = []
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let offset = mir_record_offset(record_id)
        let kind = program.records[offset]
        let opcode = program.records[offset + 3]
        let result_value = program.records[offset + 5]
        let remove = false
        if kind == MIR_RECORD_INSTRUCTION and mir_opt_is_pure(opcode):
            if result_value >= 0 and result_value < len(used):
                remove = used[result_value] == 0
        if not remove:
            let operand_start = mir_value_count(values)
            let source_operand_start = program.records[offset + 6]
            let operand_count = program.records[offset + 7]
            let operand_index = 0
            while operand_index < operand_count:
                let value_offset = mir_value_offset(source_operand_start + operand_index)
                mir_append_operand(values, program.values[value_offset], program.values[value_offset + 1])
                operand_index = operand_index + 1
            let auxiliary_start = mir_opt_append_auxiliary(program, offset, values)
            let target = MirRecord{
                record_kind: kind,
                func_index: program.records[offset + 1],
                block_index: program.records[offset + 2],
                opcode: opcode,
                type_tag: program.records[offset + 4],
                result_value: result_value,
                operand_start: operand_start,
                operand_count: operand_count,
                auxiliary_start: auxiliary_start,
                auxiliary_count: program.records[offset + 9],
                source_start: program.records[offset + 10],
                source_end: program.records[offset + 11]
            }
            mir_append_record(records, target)
        record_id = record_id + 1
    return MirProgram{records: records, values: values}

def mir_opt_max_block(program: MirProgram, func_index: int) -> int:
    let maximum = -1
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let offset = mir_record_offset(record_id)
        if program.records[offset + 1] == func_index and program.records[offset + 2] > maximum:
            maximum = program.records[offset + 2]
        record_id = record_id + 1
    return maximum

def mir_opt_mark_blocks(program: MirProgram, func_index: int, reachable: list[int]):
    if len(reachable) > 0:
        reachable[0] = 1
    let changed = true
    while changed:
        changed = false
        let record_id = 0
        while record_id < mir_record_count(program.records):
            let offset = mir_record_offset(record_id)
            let current_block = program.records[offset + 2]
            let is_active_block = false
            if program.records[offset + 1] == func_index and program.records[offset] == MIR_RECORD_TERMINATOR:
                if current_block >= 0 and current_block < len(reachable):
                    is_active_block = reachable[current_block] != 0
            if is_active_block:
                let operand_start = program.records[offset + 6]
                let operand_count = program.records[offset + 7]
                let operand_index = 0
                while operand_index < operand_count:
                    let value_offset = mir_value_offset(operand_start + operand_index)
                    if program.values[value_offset] == MIR_OPERAND_BLOCK:
                        let target = program.values[value_offset + 1]
                        if target >= 0 and target < len(reachable):
                            if reachable[target] == 0:
                                reachable[target] = 1
                                changed = true
                    operand_index = operand_index + 1
            record_id = record_id + 1

def mir_opt_reachable_blocks(program: MirProgram, func_index: int) -> list[int]:
    let reachable: list[int] = []
    let block_index = 0
    while block_index <= mir_opt_max_block(program, func_index):
        append(reachable, 0)
        block_index = block_index + 1
    mir_opt_mark_blocks(program, func_index, reachable)
    return reachable

def mir_opt_remove_unreachable(program: MirProgram) -> MirProgram:
    let reachable: list[int] = []
    let records = []
    let values = []
    let active_function = -1
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let offset = mir_record_offset(record_id)
        let kind = program.records[offset]
        let func_index = program.records[offset + 1]
        let block = program.records[offset + 2]
        if func_index >= 0 and func_index != active_function:
            active_function = func_index
            reachable = mir_opt_reachable_blocks(program, func_index)
        let remove = false
        if kind in [MIR_RECORD_BLOCK, MIR_RECORD_INSTRUCTION,
            MIR_RECORD_TERMINATOR] or kind == MIR_RECORD_PARAMETER and block >= 0:
            if block < 0:
                remove = true
            elif block >= len(reachable):
                remove = true
            elif reachable[block] == 0:
                remove = true
        if not remove:
            let operand_start = mir_value_count(values)
            let source_operand_start = program.records[offset + 6]
            let operand_count = program.records[offset + 7]
            let operand_index = 0
            while operand_index < operand_count:
                let value_offset = mir_value_offset(source_operand_start + operand_index)
                mir_append_operand(values, program.values[value_offset], program.values[value_offset + 1])
                operand_index = operand_index + 1
            let auxiliary_start = mir_opt_append_auxiliary(program, offset, values)
            let target = MirRecord{
                record_kind: kind,
                func_index: program.records[offset + 1],
                block_index: block,
                opcode: program.records[offset + 3],
                type_tag: program.records[offset + 4],
                result_value: program.records[offset + 5],
                operand_start: operand_start,
                operand_count: operand_count,
                auxiliary_start: auxiliary_start,
                auxiliary_count: program.records[offset + 9],
                source_start: program.records[offset + 10],
                source_end: program.records[offset + 11]
            }
            mir_append_record(records, target)
        record_id = record_id + 1
    return MirProgram{records: records, values: values}

def mir_optimize_program(program: MirProgram) -> MirProgram:
    let records = program.records
    let values = program.values
    return MirProgram{records: records, values: values}
