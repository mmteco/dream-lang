const DM_DIR_RECORD_MODULE: int = 1
const DM_DIR_RECORD_FUNCTION: int = 2
const DM_DIR_RECORD_BLOCK: int = 3
const DM_DIR_RECORD_PARAMETER: int = 4
const DM_DIR_RECORD_STATEMENT: int = 5
const DM_DIR_RECORD_TERMINATOR: int = 6
const DM_DIR_RECORD_SIZE: int = 12

const DM_DIR_BLOCK_ENTRY: int = 1
const DM_DIR_TERMINATOR_RETURN: int = 1

const DM_DIR_STATEMENT_UNKNOWN: int = 0
const DM_DIR_STATEMENT_LET: int = 1
const DM_DIR_STATEMENT_RETURN: int = 2
const DM_DIR_STATEMENT_IF: int = 3
const DM_DIR_STATEMENT_ELIF: int = 4
const DM_DIR_STATEMENT_ELSE: int = 5
const DM_DIR_STATEMENT_WHILE: int = 6
const DM_DIR_STATEMENT_FOR: int = 7
const DM_DIR_STATEMENT_SWITCH: int = 8
const DM_DIR_STATEMENT_CASE: int = 9
const DM_DIR_STATEMENT_DEFAULT: int = 10

struct DmDirRecord:
    record_kind: int
    function_index: int
    block_index: int
    opcode: int
    value_type: int
    result_value: int
    operand_start: int
    operand_count: int
    source_start: int
    source_end: int
    auxiliary_start: int
    auxiliary_count: int

def dm_dir_append_record(records: list[int], record: DmDirRecord):
    append(records, record.record_kind)
    append(records, record.function_index)
    append(records, record.block_index)
    append(records, record.opcode)
    append(records, record.value_type)
    append(records, record.result_value)
    append(records, record.operand_start)
    append(records, record.operand_count)
    append(records, record.source_start)
    append(records, record.source_end)
    append(records, record.auxiliary_start)
    append(records, record.auxiliary_count)

def dm_dir_statement_kind(token_kind_value: int) -> int:
    switch token_kind_value:
        case TOKEN_LET:
            return DM_DIR_STATEMENT_LET
        case TOKEN_RETURN:
            return DM_DIR_STATEMENT_RETURN
        case TOKEN_IF:
            return DM_DIR_STATEMENT_IF
        case TOKEN_ELIF:
            return DM_DIR_STATEMENT_ELIF
        case TOKEN_ELSE:
            return DM_DIR_STATEMENT_ELSE
        case TOKEN_WHILE:
            return DM_DIR_STATEMENT_WHILE
        case TOKEN_FOR:
            return DM_DIR_STATEMENT_FOR
        case TOKEN_SWITCH:
            return DM_DIR_STATEMENT_SWITCH
        case TOKEN_CASE:
            return DM_DIR_STATEMENT_CASE
        case TOKEN_DEFAULT:
            return DM_DIR_STATEMENT_DEFAULT
        default:
            return DM_DIR_STATEMENT_UNKNOWN

def dm_dir_append_module(records: list[int], source_length: int):
    let invalid_function_index = 0 - 1
    let invalid_block_index = 0 - 1
    let module_record = DmDirRecord{record_kind: DM_DIR_RECORD_MODULE, function_index: invalid_function_index, block_index: invalid_block_index, opcode: 0, value_type: 0, result_value: 0, operand_start: 0, operand_count: 0, source_start: 0, source_end: 0, auxiliary_start: source_length, auxiliary_count: 0}
    dm_dir_append_record(records, module_record)

def dm_dir_append_function(records: list[int], function_index: int, function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], function_return_types: list[int]):
    let function_return_type_value = function_return_types[function_index]
    let function_body_start_value = function_bodies[function_index]
    let function_body_end_value = function_body_ends[function_index]
    let function_body_length_value = function_body_end_value - function_body_start_value
    let function_source_start_value = function_starts[function_index]
    let function_source_end_value = function_ends[function_index]
    let function_parameter_offset_value = function_param_offsets[function_index]
    let function_parameter_count_value = function_param_counts[function_index]
    let function_record = DmDirRecord{record_kind: DM_DIR_RECORD_FUNCTION, function_index: function_index, block_index: 0, opcode: 0, value_type: function_return_type_value, result_value: 0, operand_start: function_body_start_value, operand_count: function_body_length_value, source_start: function_source_start_value, source_end: function_source_end_value, auxiliary_start: function_parameter_offset_value, auxiliary_count: function_parameter_count_value}
    dm_dir_append_record(records, function_record)

def dm_dir_append_entry_block(records: list[int], function_index: int, starts: list[int], ends: list[int], body_start: int, body_end: int):
    let block_source_start = token_start(starts, body_start)
    let block_source_end = block_source_start
    if body_end > body_start:
        let last_token_index = body_end - 1
        block_source_end = token_end(ends, last_token_index)
    let block_operand_count = body_end - body_start
    let block_record = DmDirRecord{record_kind: DM_DIR_RECORD_BLOCK, function_index: function_index, block_index: 0, opcode: DM_DIR_BLOCK_ENTRY, value_type: 0, result_value: 0, operand_start: body_start, operand_count: block_operand_count, source_start: block_source_start, source_end: block_source_end, auxiliary_start: 0, auxiliary_count: 0}
    dm_dir_append_record(records, block_record)

def dm_dir_append_parameters(records: list[int], function_index: int, parameter_offset: int, parameter_count: int, parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int]):
    let parameter_index = 0
    while parameter_index < parameter_count:
        let parameter_position = parameter_offset + parameter_index
        let parameter_type_value = parameter_types[parameter_position]
        let parameter_result_value = parameter_index + 1
        let parameter_source_start_value = parameter_starts[parameter_position]
        let parameter_source_end_value = parameter_ends[parameter_position]
        let parameter_record = DmDirRecord{record_kind: DM_DIR_RECORD_PARAMETER, function_index: function_index, block_index: 0, opcode: 0, value_type: parameter_type_value, result_value: parameter_result_value, operand_start: parameter_position, operand_count: 0, source_start: parameter_source_start_value, source_end: parameter_source_end_value, auxiliary_start: 0, auxiliary_count: 0}
        dm_dir_append_record(records, parameter_record)
        parameter_index = parameter_index + 1

def dm_dir_append_function_statements(records: list[int], function_index: int, return_type: int, source: str, kinds: list[int], starts: list[int], ends: list[int], body_start: int, body_end: int):
    let token_index = body_start
    while token_index < body_end:
        while token_index < body_end and token_kind(kinds, token_index) == TOKEN_NEWLINE:
            token_index = token_index + 1
        if token_index < body_end and token_kind(kinds, token_index) != TOKEN_EOF:
            let statement_end = token_index
            while statement_end < body_end and token_kind(kinds, statement_end) != TOKEN_NEWLINE:
                statement_end = statement_end + 1
            let statement_kind = dm_dir_statement_kind(token_kind(kinds, token_index))
            let statement_indent = line_indent(source, token_start(starts, token_index))
            if statement_kind == DM_DIR_STATEMENT_RETURN:
                let return_operand_start = token_index + 1
                let return_operand_count = statement_end - return_operand_start
                let return_source_start = token_start(starts, token_index)
                let return_source_end = token_end(ends, statement_end - 1)
                let return_record = DmDirRecord{record_kind: DM_DIR_RECORD_TERMINATOR, function_index: function_index, block_index: 0, opcode: DM_DIR_TERMINATOR_RETURN, value_type: return_type, result_value: 0, operand_start: return_operand_start, operand_count: return_operand_count, source_start: return_source_start, source_end: return_source_end, auxiliary_start: statement_indent, auxiliary_count: 0}
                dm_dir_append_record(records, return_record)
            if statement_kind != DM_DIR_STATEMENT_RETURN:
                let statement_token_kind = token_kind(kinds, token_index)
                let statement_operand_count = statement_end - token_index
                let statement_source_start = token_start(starts, token_index)
                let statement_source_end = token_end(ends, statement_end - 1)
                let statement_record = DmDirRecord{record_kind: DM_DIR_RECORD_STATEMENT, function_index: function_index, block_index: 0, opcode: statement_kind, value_type: statement_token_kind, result_value: 0, operand_start: token_index, operand_count: statement_operand_count, source_start: statement_source_start, source_end: statement_source_end, auxiliary_start: statement_indent, auxiliary_count: 0}
                dm_dir_append_record(records, statement_record)
            token_index = statement_end

def dm_dir_build_program(records: list[int], source: str, kinds: list[int], starts: list[int], ends: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int], function_return_types: list[int]) -> bool:
    dm_dir_append_module(records, text_length(source))
    let function_index = 0
    while function_index < len(function_starts):
        dm_dir_append_function(records, function_index, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, function_return_types)
        dm_dir_append_entry_block(records, function_index, starts, ends, function_bodies[function_index], function_body_ends[function_index])
        dm_dir_append_parameters(records, function_index, function_param_offsets[function_index], function_param_counts[function_index], parameter_starts, parameter_ends, parameter_types)
        dm_dir_append_function_statements(records, function_index, function_return_types[function_index], source, kinds, starts, ends, function_bodies[function_index], function_body_ends[function_index])
        function_index = function_index + 1
    return true

def dm_dir_validate_program(records: list[int]) -> bool:
    if len(records) % DM_DIR_RECORD_SIZE != 0:
        return false
    let record_index = 0
    while record_index < len(records):
        let record_kind = records[record_index]
        let function_index = records[record_index + 1]
        let block_index = records[record_index + 2]
        let opcode = records[record_index + 3]
        let value_type = records[record_index + 4]
        let result_value = records[record_index + 5]
        let operand_start = records[record_index + 6]
        let operand_count = records[record_index + 7]
        let source_start = records[record_index + 8]
        let source_end = records[record_index + 9]
        let auxiliary_start = records[record_index + 10]
        let auxiliary_count = records[record_index + 11]
        if record_kind != DM_DIR_RECORD_MODULE and record_kind != DM_DIR_RECORD_FUNCTION and record_kind != DM_DIR_RECORD_BLOCK and record_kind != DM_DIR_RECORD_PARAMETER and record_kind != DM_DIR_RECORD_STATEMENT and record_kind != DM_DIR_RECORD_TERMINATOR:
            return false
        if record_kind == DM_DIR_RECORD_MODULE:
            if function_index != -1 or block_index != -1 or source_start != 0 or source_end < 0:
                return false
        if record_kind == DM_DIR_RECORD_FUNCTION:
            if function_index < 0 or block_index < 0 or source_start < 0 or source_end < source_start:
                return false
            if operand_start < 0 or operand_count < 0 or auxiliary_start < 0 or auxiliary_count < 0:
                return false
        if record_kind == DM_DIR_RECORD_BLOCK:
            if function_index < 0 or block_index < 0 or opcode != DM_DIR_BLOCK_ENTRY:
                return false
            if operand_start < 0 or operand_count < 0 or source_start < 0 or source_end < source_start:
                return false
        if record_kind == DM_DIR_RECORD_PARAMETER:
            if function_index < 0 or block_index != 0 or result_value < 1 or source_start < 0 or source_end < source_start:
                return false
            if operand_start < 0 or operand_count != 0 or auxiliary_start != 0 or auxiliary_count != 0:
                return false
        if record_kind == DM_DIR_RECORD_STATEMENT:
            if function_index < 0 or block_index < 0 or opcode < DM_DIR_STATEMENT_UNKNOWN or opcode > DM_DIR_STATEMENT_DEFAULT:
                return false
            if operand_start < 0 or operand_count < 0 or source_start < 0 or source_end < source_start:
                return false
            if auxiliary_start < 0 or auxiliary_count != 0:
                return false
        if record_kind == DM_DIR_RECORD_TERMINATOR:
            if function_index < 0 or block_index < 0 or opcode != DM_DIR_TERMINATOR_RETURN or source_start < 0 or source_end < source_start:
                return false
            if operand_start < 0 or operand_count < 0 or auxiliary_start < 0 or auxiliary_count != 0:
                return false
        if value_type < 0 or result_value < 0:
            return false
        record_index = record_index + DM_DIR_RECORD_SIZE
    return true
