from text_buffer import TextBuffer

const MIR_MODEL_VERSION: int = 3
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
const MIR_TYPE_DYNAMIC: int = 17
const MIR_TYPE_MAX: int = MIR_TYPE_DYNAMIC

const MIR_OPERAND_VALUE: int = 1
const MIR_OPERAND_INT: int = 2
const MIR_OPERAND_BLOCK: int = 3
const MIR_OPERAND_TYPE: int = 4
const MIR_OPERAND_SYMBOL: int = 5

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
const MIR_OP_SEQUENCE: int = 17
const MIR_OP_ASSIGN: int = 18
const MIR_OP_CLOSURE: int = 19
const MIR_OP_RUNTIME: int = 20
const MIR_OP_MAX: int = MIR_OP_RUNTIME

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

struct MirIndex:
    value_offsets: list[int]
    value_defined: list[int]
    block_offsets: list[int]
    block_exists: list[int]
    block_parameter_counts: list[int]
    block_terminators: list[int]

struct MirLowerState:
    records: list[int]
    values: list[int]
    function_index: list[int]
    current_block: list[int]
    next_block: list[int]
    next_value: list[int]
    is_terminated: list[int]
    hir_value_map: list[int]
    symbol_starts: list[int]
    symbol_ends: list[int]
    symbol_values: list[int]
    symbol_count: list[int]
    function_starts: list[int]
    function_ends: list[int]
    function_returns: list[int]
    source: str
    loop_break_blocks: list[int]
    loop_continue_blocks: list[int]
    loop_symbol_counts: list[int]
    loop_count: list[int]
    value_types: list[int]

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
    if type_tag == HIR_TYPE_DYNAMIC:
        return MIR_TYPE_DYNAMIC
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
        return MIR_OP_CLOSURE
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
    if opcode == HIR_OP_SEQUENCE:
        return MIR_OP_SEQUENCE
    if opcode == HIR_OP_LET or opcode == HIR_OP_ASSIGN:
        return MIR_OP_ASSIGN
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
    mir_state_set_value_type(state, result_value, type_tag)

def mir_state_append_terminator(state: MirLowerState, opcode: int, operand_start: int, operand_count: int):
    let terminator = MirRecord{record_kind: MIR_RECORD_TERMINATOR, function_index: state.function_index[0], block_index: state.current_block[0], opcode: opcode, type_tag: MIR_TYPE_UNIT, result_value: -1, operand_start: operand_start, operand_count: operand_count, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(state.records, terminator)
    state.is_terminated[0] = 1

def mir_find_symbol_value(state: MirLowerState, source_start: int, source_end: int) -> int:
    let symbol_index = state.symbol_count[0] - 1
    while symbol_index >= 0:
        let symbol_start = state.symbol_starts[symbol_index]
        let symbol_end = state.symbol_ends[symbol_index]
        if state.source[source_start:source_end] == state.source[symbol_start:symbol_end]:
            return state.symbol_values[symbol_index]
        symbol_index = symbol_index - 1
    return -1

def mir_find_function(state: MirLowerState, source_start: int, source_end: int) -> int:
    let name = state.source[source_start:source_end]
    if name == "print" or name == "eprint" or name == "append" or name == "len":
        return -1
    let function_index = 0
    while function_index < len(state.function_starts):
        let function_start = state.function_starts[function_index]
        let function_end = state.function_ends[function_index]
        if state.source[source_start:source_end] == state.source[function_start:function_end]:
            return function_index
        function_index = function_index + 1
    return -1

def mir_bind_symbol(state: MirLowerState, source_start: int, source_end: int, value: int):
    let symbol_index = 0
    while symbol_index < state.symbol_count[0]:
        let symbol_start = state.symbol_starts[symbol_index]
        let symbol_end = state.symbol_ends[symbol_index]
        if state.source[source_start:source_end] == state.source[symbol_start:symbol_end]:
            state.symbol_values[symbol_index] = value
            return
        symbol_index = symbol_index + 1
    let target_index = state.symbol_count[0]
    if target_index < len(state.symbol_starts):
        state.symbol_starts[target_index] = source_start
        state.symbol_ends[target_index] = source_end
        state.symbol_values[target_index] = value
    else:
        append(state.symbol_starts, source_start)
        append(state.symbol_ends, source_end)
        append(state.symbol_values, value)
    state.symbol_count[0] = state.symbol_count[0] + 1

def mir_copy_symbols(source: list[int]) -> list[int]:
    let copy: list[int] = []
    let index = 0
    while index < len(source):
        append(copy, source[index])
        index = index + 1
    return copy

def mir_restore_symbols(state: MirLowerState, starts: list[int], ends: list[int], values: list[int], count: int):
    let index = 0
    while index < count:
        if index < len(state.symbol_starts):
            state.symbol_starts[index] = starts[index]
            state.symbol_ends[index] = ends[index]
            state.symbol_values[index] = values[index]
        else:
            append(state.symbol_starts, starts[index])
            append(state.symbol_ends, ends[index])
            append(state.symbol_values, values[index])
        index = index + 1
    state.symbol_count[0] = count

def mir_state_set_value_type(state: MirLowerState, value: int, type_tag: int):
    if value < 0:
        return
    while len(state.value_types) <= value:
        append(state.value_types, MIR_TYPE_DYNAMIC)
    state.value_types[value] = type_tag

def mir_state_value_type(state: MirLowerState, value: int) -> int:
    if value < 0 or value >= len(state.value_types):
        return MIR_TYPE_DYNAMIC
    return state.value_types[value]

def mir_state_append_block_parameter(state: MirLowerState, block_index: int, type_tag: int, result_value: int):
    let parameter = MirRecord{record_kind: MIR_RECORD_PARAMETER, function_index: state.function_index[0], block_index: block_index, opcode: 0, type_tag: type_tag, result_value: result_value, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(state.records, parameter)
    mir_state_set_value_type(state, result_value, type_tag)

def mir_append_current_symbol_arguments(state: MirLowerState, starts: list[int], ends: list[int], symbol_count: int):
    let symbol_index = 0
    while symbol_index < symbol_count:
        let value = mir_find_symbol_value(state, starts[symbol_index], ends[symbol_index])
        if value < 0:
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        else:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, value)
        symbol_index = symbol_index + 1

def mir_push_loop(state: MirLowerState, break_block: int, continue_block: int, symbol_count: int):
    let loop_index = state.loop_count[0]
    if loop_index < len(state.loop_break_blocks):
        state.loop_break_blocks[loop_index] = break_block
        state.loop_continue_blocks[loop_index] = continue_block
        state.loop_symbol_counts[loop_index] = symbol_count
    else:
        append(state.loop_break_blocks, break_block)
        append(state.loop_continue_blocks, continue_block)
        append(state.loop_symbol_counts, symbol_count)
    state.loop_count[0] = state.loop_count[0] + 1

def mir_pop_loop(state: MirLowerState):
    if state.loop_count[0] > 0:
        state.loop_count[0] = state.loop_count[0] - 1

def mir_hir_payload_value(hir: HirProgram, record_id: int, payload_index: int) -> int:
    let record_offset = hir_record_offset(record_id)
    let payload_start = hir.records[record_offset + 5]
    return payload_start + payload_index

def mir_hir_signature_value(hir: HirProgram, record_offset: int, metadata_index: int) -> int:
    let value_id = hir.records[record_offset + 7] + metadata_index
    let value_offset = hir_value_offset(value_id)
    return hir.values[value_offset + 1]

def mir_append_function_signature(hir: HirProgram, hir_offset: int, values: list[int]) -> int:
    let parameter_count = mir_hir_signature_value(hir, hir_offset, HIR_SIGNATURE_PARAM_COUNT)
    let parameter_index = 0
    while parameter_index < parameter_count:
        let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
        let parameter_type = mir_type_from_hir(mir_hir_signature_value(hir, hir_offset, metadata_index))
        mir_append_operand(values, MIR_OPERAND_TYPE, parameter_type)
        parameter_index = parameter_index + 1
    let return_type = mir_type_from_hir(mir_hir_signature_value(hir, hir_offset, HIR_SIGNATURE_RETURN_TYPE))
    mir_append_operand(values, MIR_OPERAND_TYPE, return_type)
    return parameter_count

def mir_lower_hir_node(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    if node_id < 0 or node_id >= hir_record_count(hir.records):
        return -1
    if state.hir_value_map[node_id] >= 0:
        return state.hir_value_map[node_id]
    let offset = hir_record_offset(node_id)
    let record_kind = hir.records[offset]
    let opcode = hir.records[offset + 1]
    if opcode == HIR_OP_LOCAL:
        let local_value = mir_find_symbol_value(state, hir.records[offset + 3], hir.records[offset + 4])
        if local_value < 0:
            local_value = state.next_value[0]
            state.next_value[0] = state.next_value[0] + 1
            mir_state_append_instruction(state, MIR_OP_RUNTIME, MIR_TYPE_DYNAMIC, local_value, mir_value_count(state.values), 0)
        state.hir_value_map[node_id] = local_value
        return local_value
    if opcode == HIR_OP_LET:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let initializer = -1
        if payload_count > 4:
            let initializer_value = payload_start + 4
            let initializer_offset = hir_value_offset(initializer_value)
            if hir.values[initializer_offset] == HIR_VALUE_NODE:
                initializer = mir_lower_hir_node(hir, hir.values[initializer_offset + 1], state)
        if payload_count > 1 and initializer >= 0:
            let name_start_offset = hir_value_offset(payload_start)
            let name_end_offset = hir_value_offset(payload_start + 1)
            mir_bind_symbol(state, hir.values[name_start_offset + 1], hir.values[name_end_offset + 1], initializer)
        state.hir_value_map[node_id] = initializer
        return initializer
    if opcode == HIR_OP_ASSIGN:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let assigned_value = -1
        if payload_count > 0:
            let value_index = payload_start + payload_count - 1
            let value_offset = hir_value_offset(value_index)
            if hir.values[value_offset] == HIR_VALUE_NODE:
                assigned_value = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
        if payload_count > 2 and assigned_value >= 0:
            let name_start_offset = hir_value_offset(payload_start)
            let name_end_offset = hir_value_offset(payload_start + 1)
            mir_bind_symbol(state, hir.values[name_start_offset + 1], hir.values[name_end_offset + 1], assigned_value)
        state.hir_value_map[node_id] = assigned_value
        return assigned_value
    if opcode == HIR_OP_SEQUENCE:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let sequence_value = -1
        if payload_count > 0:
            let value_offset = hir_value_offset(payload_start)
            if hir.values[value_offset] == HIR_VALUE_NODE:
                sequence_value = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
        state.hir_value_map[node_id] = sequence_value
        return sequence_value
    if opcode == HIR_OP_CALL:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let call_type = mir_type_from_hir(hir.records[offset + 2])
        let direct_function = -1
        if payload_count > 0:
            let callee_offset = hir_value_offset(payload_start)
            if hir.values[callee_offset] == HIR_VALUE_NODE:
                let callee_id = hir.values[callee_offset + 1]
                if callee_id >= 0 and callee_id < hir_record_count(hir.records):
                    let callee_record_offset = hir_record_offset(callee_id)
                    if hir.records[callee_record_offset + 1] == HIR_OP_LOCAL:
                        direct_function = mir_find_function(state, hir.records[callee_record_offset + 3], hir.records[callee_record_offset + 4])
                        if direct_function >= 0:
                            if direct_function < len(state.function_returns):
                                call_type = state.function_returns[direct_function]
        let argument_count = 0
        if payload_count > 1:
            let count_offset = hir_value_offset(payload_start + 1)
            if hir.values[count_offset] == HIR_VALUE_INT:
                argument_count = hir.values[count_offset + 1]
        let argument_values: list[int] = []
        let argument_index = 0
        while argument_index < argument_count and payload_count > argument_index + 2:
            let argument_offset = hir_value_offset(payload_start + argument_index + 2)
            if hir.values[argument_offset] == HIR_VALUE_NODE:
                let argument_value = mir_lower_hir_node(hir, hir.values[argument_offset + 1], state)
                if argument_value >= 0:
                    append(argument_values, argument_value)
            argument_index = argument_index + 1
        let operand_start = mir_value_count(state.values)
        if direct_function >= 0:
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, direct_function)
        argument_index = 0
        while argument_index < len(argument_values):
            mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_values[argument_index])
            argument_index = argument_index + 1
        let result_value = state.next_value[0]
        if call_type == MIR_TYPE_UNIT:
            result_value = -1
        else:
            state.next_value[0] = state.next_value[0] + 1
        mir_state_append_instruction(state, MIR_OP_CALL, call_type, result_value, operand_start, mir_value_count(state.values) - operand_start)
        state.hir_value_map[node_id] = result_value
        return result_value
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
        if state.loop_count[0] > 0:
            let loop_index = state.loop_count[0] - 1
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, state.loop_break_blocks[loop_index])
            mir_append_current_symbol_arguments(state, state.symbol_starts, state.symbol_ends, state.loop_symbol_counts[loop_index])
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
        else:
            mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_CONTINUE:
        if state.loop_count[0] > 0:
            let loop_index = state.loop_count[0] - 1
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, state.loop_continue_blocks[loop_index])
            mir_append_current_symbol_arguments(state, state.symbol_starts, state.symbol_ends, state.loop_symbol_counts[loop_index])
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
        else:
            mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_IF or opcode == HIR_OP_WHILE or opcode == HIR_OP_FOR or opcode == HIR_OP_MATCH:
        return mir_lower_hir_control(hir, node_id, state)
    let child_kinds: list[int] = []
    let child_values: list[int] = []
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
                append(child_kinds, MIR_OPERAND_VALUE)
                append(child_values, child_result)
        elif value_kind == HIR_VALUE_INT:
            append(child_kinds, MIR_OPERAND_INT)
            append(child_values, value)
        payload_index = payload_index + 1
    let operand_start = mir_value_count(state.values)
    let child_index = 0
    while child_index < len(child_kinds):
        mir_append_operand(state.values, child_kinds[child_index], child_values[child_index])
        child_index = child_index + 1
    let operand_count = mir_value_count(state.values) - operand_start
    let result_value = -1
    if record_kind == HIR_RECORD_EXPRESSION or record_kind == HIR_RECORD_PATTERN:
        result_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
    mir_state_append_instruction(state, mir_opcode_from_hir(opcode), mir_type_from_hir(hir.records[offset + 2]), result_value, operand_start, operand_count)
    state.hir_value_map[node_id] = result_value
    return result_value

def mir_lower_hir_loop(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 2:
        return -1
    let base_count = state.symbol_count[0]
    let base_starts = mir_copy_symbols(state.symbol_starts)
    let base_ends = mir_copy_symbols(state.symbol_ends)
    let base_values = mir_copy_symbols(state.symbol_values)
    let header_block = mir_state_reserve_block(state)
    let body_block = mir_state_reserve_block(state)
    let exit_block = mir_state_reserve_block(state)
    let jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)

    mir_state_emit_block(state, header_block)
    mir_state_select_block(state, header_block)
    let header_values: list[int] = []
    let symbol_index = 0
    while symbol_index < base_count:
        let header_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
        append(header_values, header_value)
        let header_type = mir_state_value_type(state, base_values[symbol_index])
        mir_state_append_block_parameter(state, header_block, header_type, header_value)
        state.symbol_values[symbol_index] = header_value
        symbol_index = symbol_index + 1
    let condition_value = -1
    let condition_offset = hir_value_offset(payload_start)
    if hir.values[condition_offset] == HIR_VALUE_NODE:
        condition_value = mir_lower_hir_node(hir, hir.values[condition_offset + 1], state)
    let branch_start = mir_value_count(state.values)
    if condition_value >= 0:
        mir_append_operand(state.values, MIR_OPERAND_VALUE, condition_value)
    else:
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, body_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, exit_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_INT, base_count)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)

    mir_state_emit_block(state, body_block)
    mir_state_select_block(state, body_block)
    mir_push_loop(state, exit_block, header_block, base_count)
    let body_value_offset = hir_value_offset(payload_start + 1)
    let body_value = hir.values[body_value_offset + 1]
    if hir.values[body_value_offset] == HIR_VALUE_BLOCK:
        mir_lower_hir_block(hir, body_value, state)
    mir_pop_loop(state)
    if state.is_terminated[0] == 0:
        let back_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
        mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
        mir_state_append_terminator(state, MIR_TERM_JUMP, back_start, mir_value_count(state.values) - back_start)

    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, exit_block)
    mir_state_select_block(state, exit_block)
    symbol_index = 0
    while symbol_index < base_count:
        let exit_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
        let exit_type = mir_state_value_type(state, base_values[symbol_index])
        mir_state_append_block_parameter(state, exit_block, exit_type, exit_value)
        state.symbol_values[symbol_index] = exit_value
        symbol_index = symbol_index + 1
    return -1

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
    if opcode == HIR_OP_WHILE:
        return mir_lower_hir_loop(hir, node_id, state)
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
        let select_values: list[int] = []
        if condition_result >= 0:
            append(select_values, condition_result)
        let then_result = mir_lower_hir_node(hir, hir.values[hir_value_offset(payload_start + 1) + 1], state)
        if then_result >= 0:
            append(select_values, then_result)
        let else_result = mir_lower_hir_node(hir, hir.values[hir_value_offset(payload_start + 2) + 1], state)
        if else_result >= 0:
            append(select_values, else_result)
        let operand_start = mir_value_count(state.values)
        let select_index = 0
        while select_index < len(select_values):
            mir_append_operand(state.values, MIR_OPERAND_VALUE, select_values[select_index])
            select_index = select_index + 1
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
    else:
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, then_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, else_block)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
    let base_count = state.symbol_count[0]
    let base_starts = mir_copy_symbols(state.symbol_starts)
    let base_ends = mir_copy_symbols(state.symbol_ends)
    let base_values = mir_copy_symbols(state.symbol_values)
    let join_values: list[int] = []
    let symbol_index = 0
    while symbol_index < base_count:
        let join_value = state.next_value[0]
        state.next_value[0] = state.next_value[0] + 1
        append(join_values, join_value)
        symbol_index = symbol_index + 1
    mir_state_emit_block(state, then_block)
    mir_state_select_block(state, then_block)
    if payload_count > block_payload_index and hir.values[hir_value_offset(payload_start + block_payload_index)] == HIR_VALUE_BLOCK:
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index) + 1], state)
    if state.is_terminated[0] == 0:
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        let argument_index = 0
        while argument_index < base_count:
            let argument_value = mir_find_symbol_value(state, base_starts[argument_index], base_ends[argument_index])
            if argument_value < 0:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            else:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_value)
            argument_index = argument_index + 1
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, else_block)
    mir_state_select_block(state, else_block)
    if payload_count > block_payload_index + 1 and hir.values[hir_value_offset(payload_start + block_payload_index + 1)] == HIR_VALUE_BLOCK:
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index + 1) + 1], state)
    if state.is_terminated[0] == 0:
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        let argument_index = 0
        while argument_index < base_count:
            let argument_value = mir_find_symbol_value(state, base_starts[argument_index], base_ends[argument_index])
            if argument_value < 0:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            else:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_value)
            argument_index = argument_index + 1
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, join_block)
    mir_state_select_block(state, join_block)
    symbol_index = 0
    while symbol_index < base_count:
        let parameter_type = mir_state_value_type(state, base_values[symbol_index])
        mir_state_append_block_parameter(state, join_block, parameter_type, join_values[symbol_index])
        state.symbol_values[symbol_index] = join_values[symbol_index]
        symbol_index = symbol_index + 1
    return -1

def mir_model_build_program(hir_program: HirProgram, source: str) -> MirProgram:
    let records = []
    let values = []
    let module = MirRecord{record_kind: MIR_RECORD_MODULE, function_index: -1, block_index: -1, opcode: 0, type_tag: MIR_TYPE_UNKNOWN, result_value: -1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(records, module)
    let hir_value_map: list[int] = []
    let map_index = 0
    while map_index < hir_record_count(hir_program.records):
        append(hir_value_map, -1)
        map_index = map_index + 1
    let function_starts: list[int] = []
    let function_ends: list[int] = []
    let function_returns: list[int] = []
    let function_record_id = 0
    while function_record_id < hir_record_count(hir_program.records):
        let function_offset = hir_record_offset(function_record_id)
        if hir_program.records[function_offset] == HIR_RECORD_FUNCTION:
            append(function_starts, hir_program.records[function_offset + 9])
            append(function_ends, hir_program.records[function_offset + 10])
            append(function_returns, mir_type_from_hir(mir_hir_signature_value(hir_program, function_offset, HIR_SIGNATURE_RETURN_TYPE)))
        function_record_id = function_record_id + 1
    let state = MirLowerState{records: records, values: values, function_index: [0], current_block: [-1], next_block: [0], next_value: [0], is_terminated: [0], hir_value_map: hir_value_map, symbol_starts: [], symbol_ends: [], symbol_values: [], symbol_count: [0], function_starts: function_starts, function_ends: function_ends, function_returns: function_returns, source: source, loop_break_blocks: [], loop_continue_blocks: [], loop_symbol_counts: [], loop_count: [0], value_types: []}
    let function_index = 0
    let hir_record_id = 0
    while hir_record_id < hir_record_count(hir_program.records):
        let hir_offset = hir_record_offset(hir_record_id)
        if hir_program.records[hir_offset] == HIR_RECORD_FUNCTION:
            state.function_index[0] = function_index
            state.next_block[0] = 0
            state.next_value[0] = 0
            state.is_terminated[0] = 0
            state.loop_count[0] = 0
            state.value_types = []
            let reset_index = 0
            while reset_index < len(state.hir_value_map):
                state.hir_value_map[reset_index] = -1
                reset_index = reset_index + 1
            let symbol_reset_index = 0
            while symbol_reset_index < len(state.symbol_starts):
                state.symbol_starts[symbol_reset_index] = -1
                state.symbol_ends[symbol_reset_index] = -1
                state.symbol_values[symbol_reset_index] = -1
                symbol_reset_index = symbol_reset_index + 1
            state.symbol_count[0] = 0
            let signature_start = mir_value_count(values)
            let parameter_count = mir_append_function_signature(hir_program, hir_offset, values)
            let signature_count = mir_value_count(values) - signature_start
            let function = MirRecord{record_kind: MIR_RECORD_FUNCTION, function_index: function_index, block_index: -1, opcode: 0, type_tag: MIR_TYPE_FUNCTION, result_value: -1, operand_start: 0, operand_count: 0, auxiliary_start: signature_start, auxiliary_count: signature_count, source_start: hir_program.records[hir_offset + 9], source_end: hir_program.records[hir_offset + 10]}
            mir_append_record(records, function)
            let parameter_index = 0
            while parameter_index < parameter_count:
                let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
                let parameter_type = mir_type_from_hir(mir_hir_signature_value(hir_program, hir_offset, metadata_index))
                let parameter = MirRecord{record_kind: MIR_RECORD_PARAMETER, function_index: function_index, block_index: -1, opcode: 0, type_tag: parameter_type, result_value: parameter_index, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: mir_hir_signature_value(hir_program, hir_offset, metadata_index + 1), source_end: mir_hir_signature_value(hir_program, hir_offset, metadata_index + 2)}
                mir_append_record(records, parameter)
                mir_state_set_value_type(state, parameter_index, parameter_type)
                mir_bind_symbol(state, mir_hir_signature_value(hir_program, hir_offset, metadata_index + 1), mir_hir_signature_value(hir_program, hir_offset, metadata_index + 2), parameter_index)
                parameter_index = parameter_index + 1
            let entry_block = mir_state_reserve_block(state)
            mir_state_emit_block(state, entry_block)
            mir_state_select_block(state, entry_block)
            state.next_value[0] = parameter_count
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

def mir_index_ensure_function(max_values: list[int], max_blocks: list[int], function_index: int):
    while len(max_values) <= function_index:
        append(max_values, -1)
        append(max_blocks, -1)

def mir_index_build(records: list[int]) -> MirIndex:
    let max_values: list[int] = []
    let max_blocks: list[int] = []
    let record_id = 0
    while record_id < mir_record_count(records):
        let offset = mir_record_offset(record_id)
        let function_index = records[offset + 1]
        if function_index >= 0:
            mir_index_ensure_function(max_values, max_blocks, function_index)
            let result_value = records[offset + 5]
            if result_value > max_values[function_index]:
                max_values[function_index] = result_value
            let block_index = records[offset + 2]
            if block_index > max_blocks[function_index]:
                max_blocks[function_index] = block_index
        record_id = record_id + 1

    let value_offsets: list[int] = [0]
    let block_offsets: list[int] = [0]
    let function_index = 0
    while function_index < len(max_values):
        let value_size = max_values[function_index] + 1
        if value_size < 0:
            value_size = 0
        let block_size = max_blocks[function_index] + 1
        if block_size < 0:
            block_size = 0
        append(value_offsets, value_offsets[function_index] + value_size)
        append(block_offsets, block_offsets[function_index] + block_size)
        function_index = function_index + 1

    let value_defined: list[int] = []
    while len(value_defined) < value_offsets[len(value_offsets) - 1]:
        append(value_defined, 0)
    let block_exists: list[int] = []
    let block_parameter_counts: list[int] = []
    let block_terminators: list[int] = []
    while len(block_exists) < block_offsets[len(block_offsets) - 1]:
        append(block_exists, 0)
        append(block_parameter_counts, 0)
        append(block_terminators, -1)

    record_id = 0
    while record_id < mir_record_count(records):
        let offset = mir_record_offset(record_id)
        let kind = records[offset]
        let function_index = records[offset + 1]
        if function_index >= 0 and function_index < len(value_offsets) - 1:
            let result_value = records[offset + 5]
            if (kind == MIR_RECORD_PARAMETER or kind == MIR_RECORD_INSTRUCTION) and result_value >= 0:
                let value_offset = value_offsets[function_index] + result_value
                if value_offset < len(value_defined):
                    value_defined[value_offset] = 1
            let block_index = records[offset + 2]
            if block_index >= 0 and block_index < block_offsets[function_index + 1] - block_offsets[function_index]:
                let block_offset = block_offsets[function_index] + block_index
                if kind == MIR_RECORD_BLOCK:
                    block_exists[block_offset] = 1
                elif kind == MIR_RECORD_PARAMETER:
                    block_parameter_counts[block_offset] = block_parameter_counts[block_offset] + 1
                elif kind == MIR_RECORD_TERMINATOR:
                    block_terminators[block_offset] = record_id
        record_id = record_id + 1
    return MirIndex{value_offsets: value_offsets, value_defined: value_defined, block_offsets: block_offsets, block_exists: block_exists, block_parameter_counts: block_parameter_counts, block_terminators: block_terminators}

def mir_block_exists(index: MirIndex, function_index: int, block_index: int) -> bool:
    if function_index < 0 or function_index + 1 >= len(index.block_offsets) or block_index < 0:
        return false
    let block_count = index.block_offsets[function_index + 1] - index.block_offsets[function_index]
    if block_index >= block_count:
        return false
    return index.block_exists[index.block_offsets[function_index] + block_index] != 0

def mir_block_parameter_count(index: MirIndex, function_index: int, block_index: int) -> int:
    if function_index < 0 or function_index + 1 >= len(index.block_offsets) or block_index < 0:
        return 0
    let block_count = index.block_offsets[function_index + 1] - index.block_offsets[function_index]
    if block_index >= block_count:
        return 0
    return index.block_parameter_counts[index.block_offsets[function_index] + block_index]

def mir_value_exists_in_function(index: MirIndex, function_index: int, value: int) -> bool:
    if function_index < 0 or function_index + 1 >= len(index.value_offsets) or value < 0:
        return false
    let value_count = index.value_offsets[function_index + 1] - index.value_offsets[function_index]
    if value >= value_count:
        return false
    return index.value_defined[index.value_offsets[function_index] + value] != 0

def mir_validate_model_program(program: MirProgram) -> bool:
    let records = program.records
    let values = program.values
    let index = mir_index_build(records)
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
        let auxiliary_start = records[offset + 8]
        let auxiliary_count = records[offset + 9]
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
        if auxiliary_start < 0 or auxiliary_count < 0 or auxiliary_start > value_count or auxiliary_count > value_count - auxiliary_start:
            return mir_validation_error(record_id, "auxiliary range")
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
        elif kind == MIR_RECORD_PARAMETER:
            if function_index != active_function:
                return mir_validation_error(record_id, "parameter function")
            if block_index == -1 and active_block >= 0:
                return mir_validation_error(record_id, "function parameter placement")
            if block_index >= 0 and (block_index != active_block or block_has_terminator):
                return mir_validation_error(record_id, "block parameter placement")
            if result_value < 0:
                return mir_validation_error(record_id, "parameter value")
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
            if operand_kind < MIR_OPERAND_VALUE or operand_kind > MIR_OPERAND_SYMBOL or operand_value < 0:
                return mir_validation_error(record_id, "operand value")
            if operand_kind == MIR_OPERAND_VALUE and not mir_value_exists_in_function(index, function_index, operand_value):
                return mir_validation_error(record_id, "unknown SSA value")
            operand_index = operand_index + 1
        if kind == MIR_RECORD_TERMINATOR and opcode == MIR_TERM_JUMP:
            let target_offset = mir_value_offset(operand_start)
            if values[target_offset] != MIR_OPERAND_BLOCK:
                return mir_validation_error(record_id, "jump target")
            let target_block = values[target_offset + 1]
            if not mir_block_exists(index, function_index, target_block):
                return mir_validation_error(record_id, "unknown jump block")
            let parameter_count = mir_block_parameter_count(index, function_index, target_block)
            if operand_count != parameter_count + 1:
                return mir_validation_error(record_id, "jump argument count")
        if kind == MIR_RECORD_TERMINATOR and opcode == MIR_TERM_BRANCH:
            let branch_target_index = 1
            let true_argument_count = 0
            let false_argument_count = 0
            if operand_count > 3:
                let true_count_offset = mir_value_offset(operand_start + 3)
                if values[true_count_offset] != MIR_OPERAND_INT or values[true_count_offset + 1] < 0:
                    return mir_validation_error(record_id, "true edge count")
                true_argument_count = values[true_count_offset + 1]
                let false_count_index = 4 + true_argument_count
                if operand_count <= false_count_index:
                    return mir_validation_error(record_id, "false edge count")
                let false_count_offset = mir_value_offset(operand_start + false_count_index)
                if values[false_count_offset] != MIR_OPERAND_INT or values[false_count_offset + 1] < 0:
                    return mir_validation_error(record_id, "false edge count")
                false_argument_count = values[false_count_offset + 1]
                if operand_count != false_count_index + false_argument_count + 1:
                    return mir_validation_error(record_id, "branch edge range")
            while branch_target_index <= 2:
                let target_value_id = operand_start + branch_target_index
                let target_offset = mir_value_offset(target_value_id)
                if values[target_offset] != MIR_OPERAND_BLOCK:
                    return mir_validation_error(record_id, "branch target")
                if not mir_block_exists(index, function_index, values[target_offset + 1]):
                    return mir_validation_error(record_id, "unknown branch block")
                let expected_argument_count = 0
                if branch_target_index == 1:
                    expected_argument_count = true_argument_count
                else:
                    expected_argument_count = false_argument_count
                if mir_block_parameter_count(index, function_index, values[target_offset + 1]) != expected_argument_count:
                    return mir_validation_error(record_id, "branch arguments")
                branch_target_index = branch_target_index + 1
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
        append(output, " type=")
        append(output, program.records[offset + 4])
        append(output, " result=")
        append(output, program.records[offset + 5])
        append(output, " operands=")
        append(output, program.records[offset + 7])
        append(output, " [")
        let operand_index = 0
        while operand_index < program.records[offset + 7]:
            if operand_index > 0:
                append(output, ",")
            let value_offset = mir_value_offset(program.records[offset + 6] + operand_index)
            append(output, program.values[value_offset])
            append(output, ":")
            append(output, program.values[value_offset + 1])
            operand_index = operand_index + 1
        append(output, "]")
        append(output, "\n")
        record_id = record_id + 1
    return true
