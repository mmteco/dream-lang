from text_buffer import TextBuffer

const MIR_MODEL_VERSION: int = 2
const MIR_RECORD_SIZE: int = 12
const MIR_VALUE_SIZE: int = 2

const MIR_RECORD_MODULE: int = 1
const MIR_RECORD_TYPE: int = 2
const MIR_RECORD_GLOBAL: int = 3
const MIR_RECORD_EXTERN: int = 4
const MIR_RECORD_FUNCTION: int = 5
const MIR_RECORD_BLOCK: int = 6
const MIR_RECORD_PARAMETER: int = 7
const MIR_RECORD_INSTRUCTION: int = 8
const MIR_RECORD_TERMINATOR: int = 9

const MIR_TYPE_UNKNOWN: int = 0
const MIR_TYPE_UNIT: int = 1
const MIR_TYPE_BOOL: int = 2
const MIR_TYPE_I32: int = 3
const MIR_TYPE_F64: int = 4
const MIR_TYPE_STR: int = 5
const MIR_TYPE_BYTES: int = 6
const MIR_TYPE_PTR: int = 7
const MIR_TYPE_LIST: int = 8
const MIR_TYPE_DICT: int = 9
const MIR_TYPE_TUPLE: int = 10
const MIR_TYPE_STRUCT: int = 11
const MIR_TYPE_ENUM: int = 12
const MIR_TYPE_INTERFACE: int = 13
const MIR_TYPE_UNION: int = 14
const MIR_TYPE_FUNCTION: int = 15
const MIR_TYPE_CLOSURE: int = 16
const MIR_TYPE_MAX: int = MIR_TYPE_CLOSURE

const MIR_OPERAND_VALUE: int = 1
const MIR_OPERAND_INT: int = 2
const MIR_OPERAND_BLOCK: int = 3
const MIR_OPERAND_TYPE: int = 4

const MIR_OP_CONST: int = 1
const MIR_OP_LOCAL: int = 2
const MIR_OP_BINARY: int = 3
const MIR_OP_UNARY: int = 4
const MIR_OP_CALL: int = 5
const MIR_OP_SELECT: int = 6
const MIR_OP_LIST: int = 7
const MIR_OP_DICT: int = 8
const MIR_OP_TUPLE: int = 9
const MIR_OP_INDEX: int = 10
const MIR_OP_SLICE: int = 11
const MIR_OP_FIELD: int = 12
const MIR_OP_STRUCT: int = 13
const MIR_OP_ENUM: int = 14
const MIR_OP_PRINT: int = 15
const MIR_OP_CAST: int = 16
const MIR_OP_MAX: int = MIR_OP_CAST

const MIR_TERM_JUMP: int = 1
const MIR_TERM_BRANCH: int = 2
const MIR_TERM_SWITCH: int = 3
const MIR_TERM_RETURN: int = 4
const MIR_TERM_UNREACHABLE: int = 5
const MIR_TERM_MAX: int = MIR_TERM_UNREACHABLE

struct MirRecord:
    record_kind: int
    function_index: int
    block_index: int
    opcode: int
    type_tag: int
    result_value: int
    operand_start: int
    operand_count: int
    auxiliary_start: int
    auxiliary_count: int
    source_start: int
    source_end: int

struct MirProgram:
    records: list[int]
    values: list[int]

struct MirLowerState:
    records: list[int]
    values: list[int]
    function_index: list[int]
    current_block: list[int]
    next_block: list[int]
    next_value: list[int]
    is_terminated: list[int]
    hir_value_map: list[int]

def mir_record_count(records: list[int]) -> int:
    return len(records) / MIR_RECORD_SIZE

def mir_value_count(values: list[int]) -> int:
    return len(values) / MIR_VALUE_SIZE

def mir_record_offset(record_id: int) -> int:
    return record_id * MIR_RECORD_SIZE

def mir_value_offset(value_id: int) -> int:
    return value_id * MIR_VALUE_SIZE

def mir_append_record(records: list[int], record: MirRecord):
    append(records, record.record_kind)
    append(records, record.function_index)
    append(records, record.block_index)
    append(records, record.opcode)
    append(records, record.type_tag)
    append(records, record.result_value)
    append(records, record.operand_start)
    append(records, record.operand_count)
    append(records, record.auxiliary_start)
    append(records, record.auxiliary_count)
    append(records, record.source_start)
    append(records, record.source_end)

def mir_append_operand(values: list[int], operand_kind: int, value: int):
    append(values, operand_kind)
    append(values, value)

def mir_type_from_hir(type_tag: int) -> int:
    if type_tag == HIR_TYPE_CLOSURE:
        return MIR_TYPE_CLOSURE
    return type_tag

def mir_opcode_from_hir(opcode: int) -> int:
    if opcode == HIR_OP_LITERAL:
        return MIR_OP_CONST
    if opcode == HIR_OP_LOCAL:
        return MIR_OP_LOCAL
    if opcode == HIR_OP_BINARY:
        return MIR_OP_BINARY
    if opcode == HIR_OP_UNARY:
        return MIR_OP_UNARY
    if opcode == HIR_OP_CALL:
        return MIR_OP_CALL
    if opcode == HIR_OP_LAMBDA:
        return MIR_OP_CAST
    if opcode == HIR_OP_LIST:
        return MIR_OP_LIST
    if opcode == HIR_OP_DICT:
        return MIR_OP_DICT
    if opcode == HIR_OP_TUPLE:
        return MIR_OP_TUPLE
    if opcode == HIR_OP_INDEX:
        return MIR_OP_INDEX
    if opcode == HIR_OP_SLICE:
        return MIR_OP_SLICE
    if opcode == HIR_OP_FIELD:
        return MIR_OP_FIELD
    if opcode == HIR_OP_STRUCT:
        return MIR_OP_STRUCT
    if opcode == HIR_OP_ENUM:
        return MIR_OP_ENUM
    if opcode == HIR_OP_PRINT:
        return MIR_OP_PRINT
    return MIR_OP_CAST

def mir_state_reserve_block(state: MirLowerState) -> int:
    let block_index = state.next_block[0]
    state.next_block[0] = block_index + 1
    return block_index

def mir_state_emit_block(state: MirLowerState, block_index: int):
    let block = MirRecord{record_kind: MIR_RECORD_BLOCK, function_index: state.function_index[0], block_index: block_index, opcode: 0, type_tag: MIR_TYPE_UNIT, result_value: -1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(state.records, block)

def mir_state_select_block(state: MirLowerState, block_index: int):
    state.current_block[0] = block_index
    state.is_terminated[0] = 0

def mir_state_append_instruction(state: MirLowerState, opcode: int, type_tag: int, result_value: int, operand_start: int, operand_count: int):
    let instruction = MirRecord{record_kind: MIR_RECORD_INSTRUCTION, function_index: state.function_index[0], block_index: state.current_block[0], opcode: opcode, type_tag: type_tag, result_value: result_value, operand_start: operand_start, operand_count: operand_count, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(state.records, instruction)

def mir_state_append_terminator(state: MirLowerState, opcode: int, operand_start: int, operand_count: int):
    let terminator = MirRecord{record_kind: MIR_RECORD_TERMINATOR, function_index: state.function_index[0], block_index: state.current_block[0], opcode: opcode, type_tag: MIR_TYPE_UNIT, result_value: -1, operand_start: operand_start, operand_count: operand_count, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(state.records, terminator)
    state.is_terminated[0] = 1

def mir_hir_payload_value(hir: HirProgram, record_id: int, payload_index: int) -> int:
    let record_offset = hir_record_offset(record_id)
    let payload_start = hir.records[record_offset + 5]
    return payload_start + payload_index

def mir_lower_hir_node(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    if node_id < 0 or node_id >= hir_record_count(hir.records):
        return -1
    if state.hir_value_map[node_id] >= 0:
        return state.hir_value_map[node_id]
    let offset = hir_record_offset(node_id)
    let record_kind = hir.records[offset]
    let opcode = hir.records[offset + 1]
    if record_kind == HIR_RECORD_BLOCK or record_kind == HIR_RECORD_FUNCTION or record_kind == HIR_RECORD_MODULE:
        return -1
    if opcode == HIR_OP_RETURN:
        let payload_count = hir.records[offset + 6]
        if payload_count > 0:
            let value_id = mir_hir_payload_value(hir, node_id, 0)
            if hir.values[hir_value_offset(value_id)] == HIR_VALUE_NODE:
                let result = mir_lower_hir_node(hir, hir.values[hir_value_offset(value_id) + 1], state)
                let operand_start = mir_value_count(state.values)
                if result >= 0:
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, result)
                    mir_state_append_terminator(state, MIR_TERM_RETURN, operand_start, 1)
                    return -1
        mir_state_append_terminator(state, MIR_TERM_RETURN, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_BREAK:
        mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_IF or opcode == HIR_OP_WHILE or opcode == HIR_OP_FOR or opcode == HIR_OP_MATCH:
        return mir_lower_hir_control(hir, node_id, state)
    let operand_start = mir_value_count(state.values)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    let payload_index = 0
    while payload_index < payload_count:
        let value_id = payload_start + payload_index
        let value_offset = hir_value_offset(value_id)
        let value_kind = hir.values[value_offset]
        let value = hir.values[value_offset + 1]
        if value_kind == HIR_VALUE_NODE:
            let child_result = mir_lower_hir_node(hir, value, state)
            if child_result >= 0:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, child_result)
        elif value_kind == HIR_VALUE_INT:
            mir_append_operand(state.values, MIR_OPERAND_INT, value)
        payload_index = payload_index + 1
    let operand_count = mir_value_count(state.values) - operand_start
    let result_value = -1
    if record_kind == HIR_RECORD_EXPRESSION or record_kind == HIR_RECORD_PATTERN:
        result_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
    mir_state_append_instruction(state, mir_opcode_from_hir(opcode), mir_type_from_hir(hir.records[offset + 2]), result_value, operand_start, operand_count)
    state.hir_value_map[node_id] = result_value
    return result_value

def mir_lower_hir_block(hir: HirProgram, block_id: int, state: MirLowerState):
    if block_id < 0 or block_id >= hir_record_count(hir.records):
        return
    let offset = hir_record_offset(block_id)
    if hir.records[offset] != HIR_RECORD_BLOCK:
        return
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    let index = 0
    while index < payload_count:
        if state.is_terminated[0] != 0:
            let next_block = mir_state_reserve_block(state)
            mir_state_emit_block(state, next_block)
            mir_state_select_block(state, next_block)
        let value_id = payload_start + index
        let value_offset = hir_value_offset(value_id)
        if hir.values[value_offset] == HIR_VALUE_NODE:
            mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
        index = index + 1

def mir_lower_hir_control(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let opcode = hir.records[offset + 1]
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count == 0:
        return -1
    let condition_payload_index = 0
    if opcode == HIR_OP_FOR:
        condition_payload_index = 2
    let block_payload_index = condition_payload_index + 1
    let condition_value = payload_start + condition_payload_index
    let condition_offset = hir_value_offset(condition_value)
    let condition_result = -1
    if hir.values[condition_offset] == HIR_VALUE_NODE:
        condition_result = mir_lower_hir_node(hir, hir.values[condition_offset + 1], state)
    let has_blocks = false
    if payload_count > block_payload_index:
        has_blocks = hir.values[hir_value_offset(payload_start + block_payload_index)] == HIR_VALUE_BLOCK
    if not has_blocks and opcode == HIR_OP_IF:
        let operand_start = mir_value_count(state.values)
        if condition_result >= 0:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, condition_result)
        let then_result = mir_lower_hir_node(hir, hir.values[hir_value_offset(payload_start + 1) + 1], state)
        if then_result >= 0:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, then_result)
        let else_result = mir_lower_hir_node(hir, hir.values[hir_value_offset(payload_start + 2) + 1], state)
        if else_result >= 0:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, else_result)
        let result_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
        mir_state_append_instruction(state, MIR_OP_SELECT, mir_type_from_hir(hir.records[offset + 2]), result_value, operand_start, mir_value_count(state.values) - operand_start)
        state.hir_value_map[node_id] = result_value
        return result_value
    let then_block = mir_state_reserve_block(state)
    let else_block = mir_state_reserve_block(state)
    let join_block = mir_state_reserve_block(state)
    let branch_start = mir_value_count(state.values)
    if condition_result >= 0:
        mir_append_operand(state.values, MIR_OPERAND_VALUE, condition_result)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, then_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, else_block)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
    mir_state_emit_block(state, then_block)
    mir_state_select_block(state, then_block)
    if payload_count > block_payload_index and hir.values[hir_value_offset(payload_start + block_payload_index)] == HIR_VALUE_BLOCK:
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index) + 1], state)
    if state.is_terminated[0] == 0:
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, 1)
    mir_state_emit_block(state, else_block)
    mir_state_select_block(state, else_block)
    if payload_count > block_payload_index + 1 and hir.values[hir_value_offset(payload_start + block_payload_index + 1)] == HIR_VALUE_BLOCK:
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index + 1) + 1], state)
    if state.is_terminated[0] == 0:
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, 1)
    mir_state_emit_block(state, join_block)
    mir_state_select_block(state, join_block)
    return -1

def mir_model_build_program(hir_program: HirProgram) -> MirProgram:
    let records = []
    let values = []
    let module = MirRecord{record_kind: MIR_RECORD_MODULE, function_index: -1, block_index: -1, opcode: 0, type_tag: MIR_TYPE_UNKNOWN, result_value: -1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(records, module)
    let hir_value_map: list[int] = []
    let map_index = 0
    while map_index < hir_record_count(hir_program.records):
        append(hir_value_map, -1)
        map_index = map_index + 1
    let state = MirLowerState{records: records, values: values, function_index: [0], current_block: [-1], next_block: [0], next_value: [0], is_terminated: [0], hir_value_map: hir_value_map}
    let function_index = 0
    let hir_record_id = 0
    while hir_record_id < hir_record_count(hir_program.records):
        let hir_offset = hir_record_offset(hir_record_id)
        if hir_program.records[hir_offset] == HIR_RECORD_FUNCTION:
            state.function_index[0] = function_index
            state.next_block[0] = 0
            state.next_value[0] = 0
            state.is_terminated[0] = 0
            let function = MirRecord{record_kind: MIR_RECORD_FUNCTION, function_index: function_index, block_index: -1, opcode: 0, type_tag: MIR_TYPE_FUNCTION, result_value: -1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
            mir_append_record(records, function)
            let entry_block = mir_state_reserve_block(state)
            mir_state_emit_block(state, entry_block)
            mir_state_select_block(state, entry_block)
            let payload_start = hir_program.records[hir_offset + 5]
            if hir_program.records[hir_offset + 6] > 0:
                let value_offset = hir_value_offset(payload_start)
                if hir_program.values[value_offset] == HIR_VALUE_NODE or hir_program.values[value_offset] == HIR_VALUE_BLOCK:
                    mir_lower_hir_block(hir_program, hir_program.values[value_offset + 1], state)
            if state.is_terminated[0] == 0:
                mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(values), 0)
            function_index = function_index + 1
        hir_record_id = hir_record_id + 1
    return MirProgram{records: records, values: values}

def mir_validation_error(record_id: int, reason: str) -> bool:
    __c_eprint_text("MIR validation failed record=")
    __c_eprint_int(record_id)
    __c_eprint_text(" reason=")
    __c_eprint_text(reason)
    __c_eprint_text("\n")
    return false

def mir_validate_model_program(program: MirProgram) -> bool:
    let records = program.records
    let values = program.values
    if len(records) % MIR_RECORD_SIZE != 0 or len(values) % MIR_VALUE_SIZE != 0:
        return mir_validation_error(-1, "record/value alignment")
    let value_count = mir_value_count(values)
    let record_count = mir_record_count(records)
    let record_id = 0
    let active_function = -1
    let active_block = -1
    let block_has_terminator = true
    while record_id < record_count:
        let offset = mir_record_offset(record_id)
        let kind = records[offset]
        let function_index = records[offset + 1]
        let block_index = records[offset + 2]
        let opcode = records[offset + 3]
        let type_tag = records[offset + 4]
        let result_value = records[offset + 5]
        let operand_start = records[offset + 6]
        let operand_count = records[offset + 7]
        if kind < MIR_RECORD_MODULE or kind > MIR_RECORD_TERMINATOR:
            return mir_validation_error(record_id, "record kind")
        if type_tag < MIR_TYPE_UNKNOWN or type_tag > MIR_TYPE_MAX or result_value < -1:
            return mir_validation_error(record_id, "type or result")
        if kind == MIR_RECORD_INSTRUCTION and (opcode < MIR_OP_CONST or opcode > MIR_OP_MAX):
            return mir_validation_error(record_id, "instruction opcode")
        if kind == MIR_RECORD_TERMINATOR and (opcode < MIR_TERM_JUMP or opcode > MIR_TERM_MAX):
            return mir_validation_error(record_id, "terminator opcode")
        if operand_start < 0 or operand_count < 0 or operand_start > value_count or operand_count > value_count - operand_start:
            return mir_validation_error(record_id, "operand range")
        if kind == MIR_RECORD_MODULE:
            if function_index != -1 or block_index != -1:
                return mir_validation_error(record_id, "module owner")
        elif function_index < 0:
            return mir_validation_error(record_id, "missing function")
        if kind == MIR_RECORD_BLOCK or kind == MIR_RECORD_INSTRUCTION or kind == MIR_RECORD_TERMINATOR:
            if block_index < 0:
                return mir_validation_error(record_id, "block index")
        if kind == MIR_RECORD_FUNCTION:
            if active_block >= 0 and not block_has_terminator:
                return mir_validation_error(record_id, "unterminated block before function")
            active_function = function_index
            active_block = -1
            block_has_terminator = true
        elif kind == MIR_RECORD_BLOCK:
            if active_block >= 0 and not block_has_terminator:
                return mir_validation_error(record_id, "block owner")
            if function_index != active_function:
                return mir_validation_error(record_id, "block order")
            active_block = block_index
            block_has_terminator = false
        elif kind == MIR_RECORD_INSTRUCTION:
            if function_index != active_function or block_index != active_block or block_has_terminator:
                return mir_validation_error(record_id, "instruction placement")
        elif kind == MIR_RECORD_TERMINATOR:
            if function_index != active_function or block_index != active_block or block_has_terminator:
                return mir_validation_error(record_id, "terminator placement")
            if opcode == MIR_TERM_JUMP and operand_count < 1:
                return mir_validation_error(record_id, "jump operands")
            if opcode == MIR_TERM_BRANCH and operand_count < 3:
                return mir_validation_error(record_id, "branch operands")
            if opcode == MIR_TERM_RETURN and operand_count > 1:
                return mir_validation_error(record_id, "return operands")
            block_has_terminator = true
        let operand_index = operand_start
        while operand_index < operand_start + operand_count:
            let value_offset = mir_value_offset(operand_index)
            let operand_kind = values[value_offset]
            let operand_value = values[value_offset + 1]
            if operand_kind < MIR_OPERAND_VALUE or operand_kind > MIR_OPERAND_TYPE or operand_value < 0:
                return mir_validation_error(record_id, "operand value")
            operand_index = operand_index + 1
        record_id = record_id + 1
    if active_block >= 0 and not block_has_terminator:
        return mir_validation_error(-1, "unterminated final block")
    return true

def mir_validate_program(program: MirProgram) -> bool:
    return mir_validate_model_program(program)

def mir_empty_program() -> MirProgram:
    return MirProgram{records: [], values: []}

def mir_dump_program(program: MirProgram, output: TextBuffer) -> bool:
    if not mir_validate_model_program(program):
        return false
    append(output, "MIR version=")
    append(output, MIR_MODEL_VERSION)
    append(output, " records=")
    append(output, mir_record_count(program.records))
    append(output, " values=")
    append(output, mir_value_count(program.values))
    append(output, "\n")
    let record_id = 0
    while record_id < mir_record_count(program.records):
        let offset = mir_record_offset(record_id)
        append(output, "record id=")
        append(output, record_id)
        append(output, " kind=")
        append(output, program.records[offset])
        append(output, " function=")
        append(output, program.records[offset + 1])
        append(output, " block=")
        append(output, program.records[offset + 2])
        append(output, " opcode=")
        append(output, program.records[offset + 3])
        append(output, " operands=")
        append(output, program.records[offset + 7])
        append(output, "\n")
        record_id = record_id + 1
    return true
