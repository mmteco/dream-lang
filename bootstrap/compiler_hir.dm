const HIR_RECORD_FUNCTION: int = 1
const HIR_RECORD_CONSTANT: int = 2
const HIR_RECORD_STATEMENT: int = 3
const HIR_RECORD_SIZE: int = 9

def hir_append_record(records: list[int], record_kind: int, name_start: int, name_end: int, payload_start: int, payload_end: int, auxiliary_start: int, auxiliary_count: int, declaration_index: int, value_type: int):
    append(records, record_kind)
    append(records, name_start)
    append(records, name_end)
    append(records, payload_start)

    append(records, payload_end)
    append(records, auxiliary_start)
    append(records, auxiliary_count)
    append(records, declaration_index)
    append(records, value_type)

def hir_append_function(records: list[int], function_index: int, function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], function_return_types: list[int]):
    hir_append_record(records, HIR_RECORD_FUNCTION, function_starts[function_index], function_ends[function_index], function_bodies[function_index], function_body_ends[function_index], function_param_offsets[function_index], function_param_counts[function_index], function_index, function_return_types[function_index])

def hir_append_constant(records: list[int], constant_index: int, constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]):
    hir_append_record(records, HIR_RECORD_CONSTANT, constant_starts[constant_index], constant_ends[constant_index], constant_values[constant_index], 0, 0, 0, constant_index, constant_types[constant_index])

def hir_append_statement(records: list[int], function_index: int, kinds: list[int], starts: list[int], source: str, statement_start: int, statement_end: int):
    let statement_kind = token_kind(kinds, statement_start)
    let statement_indent = line_indent(source, token_start(starts, statement_start))
    hir_append_record(records, HIR_RECORD_STATEMENT, 0, 0, statement_start, statement_end, statement_indent, 0, function_index, statement_kind)

def hir_append_function_body(records: list[int], function_index: int, source: str, kinds: list[int], starts: list[int], body_start: int, body_end: int):
    let statement_start = body_start
    while statement_start < body_end:
        if token_kind(kinds, statement_start) == TOKEN_NEWLINE:
            statement_start = statement_start + 1
        if statement_start < body_end and token_kind(kinds, statement_start) != TOKEN_EOF:
            let statement_end = statement_start
            while statement_end < body_end and token_kind(kinds, statement_end) != TOKEN_NEWLINE:
                statement_end = statement_end + 1
            hir_append_statement(records, function_index, kinds, starts, source, statement_start, statement_end)
            statement_start = statement_end

def hir_build_program(records: list[int], source: str, kinds: list[int], starts: list[int], function_starts: list[int], function_ends: list[int], function_bodies: list[int], function_body_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], function_return_types: list[int], constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int]) -> bool:
    let function_index = 0
    let constant_index = 0
    while function_index < len(function_starts) or constant_index < len(constant_starts):
        let append_function_record = false
        if function_index < len(function_starts):
            if constant_index >= len(constant_starts):
                append_function_record = true
            if constant_index < len(constant_starts):
                if function_starts[function_index] <= constant_starts[constant_index]:
                    append_function_record = true
        if append_function_record:
            hir_append_function(records, function_index, function_starts, function_ends, function_bodies, function_body_ends, function_param_offsets, function_param_counts, function_return_types)
            hir_append_function_body(records, function_index, source, kinds, starts, function_bodies[function_index], function_body_ends[function_index])
            function_index = function_index + 1
        if not append_function_record:
            hir_append_constant(records, constant_index, constant_starts, constant_ends, constant_values, constant_types)
            constant_index = constant_index + 1
    return true

def hir_validate_program(records: list[int]) -> bool:
    if len(records) % HIR_RECORD_SIZE != 0:
        return false
    let record_index = 0
    while record_index < len(records):
        let record_kind = records[record_index]
        let name_start = records[record_index + 1]
        let name_end = records[record_index + 2]
        let payload_start = records[record_index + 3]
        let payload_end = records[record_index + 4]
        let auxiliary_start = records[record_index + 5]
        let auxiliary_count = records[record_index + 6]
        let declaration_index = records[record_index + 7]
        let value_type = records[record_index + 8]
        if record_kind != HIR_RECORD_FUNCTION and record_kind != HIR_RECORD_CONSTANT and record_kind != HIR_RECORD_STATEMENT:
            return false
        if name_start < 0 or name_end < name_start:
            return false
        if declaration_index < 0:
            return false
        if record_kind == HIR_RECORD_FUNCTION:
            if payload_start < 0 or payload_end < payload_start:
                return false
            if auxiliary_start < 0 or auxiliary_count < 0:
                return false
        if record_kind == HIR_RECORD_CONSTANT:
            if payload_end != 0 or auxiliary_start != 0 or auxiliary_count != 0:
                return false
        if record_kind == HIR_RECORD_STATEMENT:
            if name_start != 0 or name_end != 0:
                return false
            if payload_start < 0 or payload_end < payload_start:
                return false
            if auxiliary_start < 0 or auxiliary_count != 0:
                return false
        if value_type < 0:
            return false
        record_index = record_index + HIR_RECORD_SIZE
    return true
