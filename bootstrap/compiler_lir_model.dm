from compiler_mir_model import MirProgram, mir_record_count, mir_value_count, mir_record_offset, mir_value_offset, MIR_RECORD_MODULE, MIR_RECORD_TYPE, MIR_RECORD_GLOBAL, MIR_RECORD_EXTERN, MIR_RECORD_FUNCTION, MIR_RECORD_BLOCK, MIR_RECORD_PARAMETER, MIR_RECORD_INSTRUCTION, MIR_RECORD_TERMINATOR, MIR_TYPE_UNKNOWN, MIR_TYPE_UNIT, MIR_TYPE_BOOL, MIR_TYPE_I32, MIR_TYPE_F64, MIR_TYPE_STR, MIR_TYPE_BYTES, MIR_TYPE_PTR, MIR_TYPE_LIST, MIR_TYPE_DICT, MIR_TYPE_TUPLE, MIR_TYPE_STRUCT, MIR_TYPE_ENUM, MIR_TYPE_INTERFACE, MIR_TYPE_UNION, MIR_TYPE_FUNCTION, MIR_TYPE_CLOSURE, MIR_TYPE_DYNAMIC, MIR_TYPE_MAX, MIR_OPERAND_VALUE, MIR_OPERAND_INT, MIR_OPERAND_BLOCK, MIR_OPERAND_TYPE, MIR_OPERAND_SYMBOL, MIR_OP_CONST, MIR_OP_LOCAL, MIR_OP_BINARY, MIR_OP_UNARY, MIR_OP_CALL, MIR_OP_SELECT, MIR_OP_LIST, MIR_OP_DICT, MIR_OP_TUPLE, MIR_OP_INDEX, MIR_OP_SLICE, MIR_OP_FIELD, MIR_OP_STRUCT, MIR_OP_ENUM, MIR_OP_PRINT, MIR_OP_CAST, MIR_OP_SEQUENCE, MIR_OP_ASSIGN, MIR_OP_CLOSURE, MIR_OP_RUNTIME, MIR_OP_MAX, MIR_TERM_JUMP, MIR_TERM_BRANCH, MIR_TERM_SWITCH, MIR_TERM_RETURN, MIR_TERM_UNREACHABLE, MIR_TERM_MAX
from text_buffer import TextBuffer

let lir_value_type_cache: list[int] = []
let lir_block_parameter_cache: list[int] = []
let lir_value_cache_width: list[int] = [0]
let lir_block_parameter_start_cache: list[int] = []
let lir_block_parameter_count_cache: list[int] = []
let lir_block_cache_width: list[int] = [0]
let lir_block_parameter_inferred_cache: list[int] = []
let lir_block_parameter_has_incoming_cache: list[int] = []
let lir_block_parameter_mismatch_cache: list[int] = []

def lir_debug_start() -> int:
    if __c_debug_on():
        return __c_time_ms()
    return 0

def lir_debug_checkpoint(label: str, previous_time: int) -> int:
    if not __c_debug_on():
        return previous_time
    let current_time = __c_time_ms()
    __c_eprint_text("[timing] lir-")
    __c_eprint_text(label)
    __c_eprint_text(" ")
    __c_eprint_int(current_time - previous_time)
    __c_eprint_text("ms\n")
    return current_time

const LIR_MODEL_VERSION: int = 1
const LIR_RECORD_SIZE: int = 14
const LIR_VALUE_SIZE: int = 2
const LIR_LAYOUT_SIZE: int = 6

const LIR_RECORD_MODULE: int = 1
const LIR_RECORD_TYPE: int = 2
const LIR_RECORD_GLOBAL: int = 3
const LIR_RECORD_EXTERN: int = 4
const LIR_RECORD_FUNCTION: int = 5
const LIR_RECORD_BLOCK: int = 6
const LIR_RECORD_PARAMETER: int = 7
const LIR_RECORD_INSTRUCTION: int = 8
const LIR_RECORD_TERMINATOR: int = 9
const LIR_RECORD_MAX: int = LIR_RECORD_TERMINATOR

const LIR_TYPE_VOID: int = 1
const LIR_TYPE_I1: int = 2
const LIR_TYPE_I32: int = 3
const LIR_TYPE_F64: int = 4
const LIR_TYPE_PTR: int = 5
const LIR_TYPE_AGGREGATE: int = 6
const LIR_TYPE_DYNAMIC: int = 7
const LIR_TYPE_MAX: int = LIR_TYPE_DYNAMIC

const LIR_OPERAND_VALUE: int = 1
const LIR_OPERAND_IMMEDIATE: int = 2
const LIR_OPERAND_BLOCK: int = 3
const LIR_OPERAND_TYPE: int = 4
const LIR_OPERAND_SYMBOL: int = 5
const LIR_OPERAND_LAYOUT: int = 6
const LIR_OPERAND_MAX: int = LIR_OPERAND_LAYOUT

const LIR_OP_CONST: int = 1
const LIR_OP_COPY: int = 2
const LIR_OP_BINARY: int = 3
const LIR_OP_UNARY: int = 4
const LIR_OP_CALL: int = 5
const LIR_OP_RUNTIME_CALL: int = 6
const LIR_OP_SELECT: int = 7
const LIR_OP_LOAD: int = 8
const LIR_OP_STORE: int = 9
const LIR_OP_GEP: int = 10
const LIR_OP_ALLOC: int = 11
const LIR_OP_AGGREGATE: int = 12
const LIR_OP_EXTRACT: int = 13
const LIR_OP_INSERT: int = 14
const LIR_OP_ENUM: int = 15
const LIR_OP_ENUM_TAG: int = 16
const LIR_OP_ENUM_PAYLOAD: int = 17
const LIR_OP_CLOSURE: int = 18
const LIR_OP_CAST: int = 19
const LIR_OP_BOUNDS_CHECK: int = 20
const LIR_OP_MAX: int = LIR_OP_BOUNDS_CHECK

const LIR_RUNTIME_NONE: int = 0
const LIR_RUNTIME_PRINT: int = 1
const LIR_RUNTIME_LIST_NEW: int = 2
const LIR_RUNTIME_LIST_GET: int = 3
const LIR_RUNTIME_LIST_SET: int = 4
const LIR_RUNTIME_LIST_APPEND: int = 5
const LIR_RUNTIME_LIST_SLICE: int = 6
const LIR_RUNTIME_DICT_NEW: int = 7
const LIR_RUNTIME_DICT_GET: int = 8
const LIR_RUNTIME_DICT_SET: int = 9
const LIR_RUNTIME_TUPLE_NEW: int = 10
const LIR_RUNTIME_TUPLE_GET: int = 11
const LIR_RUNTIME_STRUCT_NEW: int = 12
const LIR_RUNTIME_ENUM_NEW: int = 13
const LIR_RUNTIME_INDEX_CHECK: int = 14
const LIR_RUNTIME_MAX: int = LIR_RUNTIME_INDEX_CHECK

const LIR_TERM_JUMP: int = 1
const LIR_TERM_BRANCH: int = 2
const LIR_TERM_SWITCH: int = 3
const LIR_TERM_RETURN: int = 4
const LIR_TERM_UNREACHABLE: int = 5
const LIR_TERM_MAX: int = LIR_TERM_UNREACHABLE

struct LirRecord:
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
    layout_id: int
    flags: int
    source_start: int
    source_end: int

struct LirProgram:
    records: list[int]
    values: list[int]
    layouts: list[int]

def lir_record_count(records: list[int]) -> int:
    return len(records) / LIR_RECORD_SIZE

def lir_value_count(values: list[int]) -> int:
    return len(values) / LIR_VALUE_SIZE

def lir_record_offset(record_id: int) -> int:
    return record_id * LIR_RECORD_SIZE

def lir_value_offset(value_id: int) -> int:
    return value_id * LIR_VALUE_SIZE

def lir_layout_count(layouts: list[int]) -> int:
    return len(layouts) / LIR_LAYOUT_SIZE

def lir_layout_offset(layout_id: int) -> int:
    return layout_id * LIR_LAYOUT_SIZE

def lir_append_layout(layouts: list[int], type_tag: int, size: int, alignment: int, element_layout: int, field_start: int, field_count: int):
    append(layouts, type_tag)
    append(layouts, size)
    append(layouts, alignment)
    append(layouts, element_layout)
    append(layouts, field_start)
    append(layouts, field_count)

def lir_build_default_layouts() -> list[int]:
    let layouts = []
    lir_append_layout(layouts, LIR_TYPE_VOID, 0, 1, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_I1, 1, 1, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_I32, 4, 4, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_F64, 8, 8, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_PTR, 8, 8, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_AGGREGATE, 8, 8, -1, -1, 0)
    lir_append_layout(layouts, LIR_TYPE_DYNAMIC, 8, 8, -1, -1, 0)
    return layouts

def lir_append_record(records: list[int], record: LirRecord):
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
    append(records, record.layout_id)
    append(records, record.flags)
    append(records, record.source_start)
    append(records, record.source_end)

def lir_append_value(values: list[int], value_kind: int, value: int):
    append(values, value_kind)
    append(values, value)

def lir_type_from_mir(type_tag: int) -> int:
    if type_tag == MIR_TYPE_UNIT:
        return LIR_TYPE_VOID
    if type_tag == MIR_TYPE_BOOL:
        return LIR_TYPE_I1
    if type_tag == MIR_TYPE_I32:
        return LIR_TYPE_I32
    if type_tag == MIR_TYPE_F64:
        return LIR_TYPE_F64
    if type_tag == MIR_TYPE_UNKNOWN:
        return LIR_TYPE_DYNAMIC
    if type_tag == MIR_TYPE_DYNAMIC:
        return LIR_TYPE_DYNAMIC
    if type_tag == MIR_TYPE_STR or type_tag == MIR_TYPE_BYTES or type_tag == MIR_TYPE_PTR:
        return LIR_TYPE_PTR
    if type_tag == MIR_TYPE_LIST or type_tag == MIR_TYPE_DICT or type_tag == MIR_TYPE_ENUM:
        return LIR_TYPE_PTR
    if type_tag == MIR_TYPE_TUPLE or type_tag == MIR_TYPE_STRUCT:
        return LIR_TYPE_AGGREGATE
    if type_tag == MIR_TYPE_INTERFACE or type_tag == MIR_TYPE_UNION or type_tag == MIR_TYPE_CLOSURE:
        return LIR_TYPE_PTR
    if type_tag == MIR_TYPE_FUNCTION:
        return LIR_TYPE_PTR
    return LIR_TYPE_DYNAMIC

def lir_opcode_from_mir(opcode: int) -> int:
    if opcode == MIR_OP_CONST:
        return LIR_OP_CONST
    if opcode == MIR_OP_LOCAL:
        return LIR_OP_COPY
    if opcode == MIR_OP_BINARY:
        return LIR_OP_BINARY
    if opcode == MIR_OP_UNARY:
        return LIR_OP_UNARY
    if opcode == MIR_OP_CALL:
        return LIR_OP_CALL
    if opcode == MIR_OP_SELECT:
        return LIR_OP_SELECT
    if opcode == MIR_OP_LIST or opcode == MIR_OP_DICT or opcode == MIR_OP_TUPLE:
        return LIR_OP_RUNTIME_CALL
    if opcode == MIR_OP_INDEX or opcode == MIR_OP_SLICE:
        return LIR_OP_RUNTIME_CALL
    if opcode == MIR_OP_FIELD:
        return LIR_OP_EXTRACT
    if opcode == MIR_OP_STRUCT:
        return LIR_OP_AGGREGATE
    if opcode == MIR_OP_ENUM:
        return LIR_OP_ENUM
    if opcode == MIR_OP_PRINT:
        return LIR_OP_RUNTIME_CALL
    if opcode == MIR_OP_CAST:
        return LIR_OP_CAST
    if opcode == MIR_OP_CLOSURE:
        return LIR_OP_CLOSURE
    if opcode == MIR_OP_SEQUENCE or opcode == MIR_OP_ASSIGN:
        return LIR_OP_COPY
    if opcode == MIR_OP_RUNTIME:
        return LIR_OP_RUNTIME_CALL
    return LIR_OP_RUNTIME_CALL

def lir_runtime_from_mir(opcode: int) -> int:
    if opcode == MIR_OP_LIST:
        return LIR_RUNTIME_LIST_NEW
    if opcode == MIR_OP_DICT:
        return LIR_RUNTIME_DICT_NEW
    if opcode == MIR_OP_TUPLE:
        return LIR_RUNTIME_TUPLE_NEW
    if opcode == MIR_OP_INDEX:
        return LIR_RUNTIME_LIST_GET
    if opcode == MIR_OP_SLICE:
        return LIR_RUNTIME_LIST_SLICE
    if opcode == MIR_OP_PRINT:
        return LIR_RUNTIME_PRINT
    return LIR_RUNTIME_NONE

def lir_record_kind_from_mir(record_kind: int) -> int:
    if record_kind >= MIR_RECORD_MODULE and record_kind <= MIR_RECORD_TERMINATOR:
        return record_kind
    return LIR_RECORD_MAX + 1

def lir_term_from_mir(opcode: int) -> int:
    if opcode == MIR_TERM_JUMP:
        return LIR_TERM_JUMP
    if opcode == MIR_TERM_BRANCH:
        return LIR_TERM_BRANCH
    if opcode == MIR_TERM_SWITCH:
        return LIR_TERM_SWITCH
    if opcode == MIR_TERM_RETURN:
        return LIR_TERM_RETURN
    if opcode == MIR_TERM_UNREACHABLE:
        return LIR_TERM_UNREACHABLE
    return 0

def lir_copy_operands(mir: MirProgram, record_offset: int, values: list[int]) -> int:
    let operand_start = mir.records[record_offset + 6]
    let operand_count = mir.records[record_offset + 7]
    let operand_index = 0
    while operand_index < operand_count:
        let source_offset = mir_value_offset(operand_start + operand_index)
        let source_kind = mir.values[source_offset]
        let source_value = mir.values[source_offset + 1]
        let target_kind = LIR_OPERAND_IMMEDIATE
        if source_kind == MIR_OPERAND_VALUE:
            target_kind = LIR_OPERAND_VALUE
        elif source_kind == MIR_OPERAND_BLOCK:
            target_kind = LIR_OPERAND_BLOCK
        elif source_kind == MIR_OPERAND_TYPE:
            target_kind = LIR_OPERAND_TYPE
        elif source_kind == MIR_OPERAND_SYMBOL:
            target_kind = LIR_OPERAND_SYMBOL
        lir_append_value(values, target_kind, source_value)
        operand_index = operand_index + 1
    return lir_value_count(values)

def lir_copy_value_range(mir: MirProgram, start: int, count: int, values: list[int]):
    let index = 0
    while index < count:
        let source_offset = mir_value_offset(start + index)
        let source_kind = mir.values[source_offset]
        let target_kind = LIR_OPERAND_IMMEDIATE
        if source_kind == MIR_OPERAND_VALUE:
            target_kind = LIR_OPERAND_VALUE
        elif source_kind == MIR_OPERAND_BLOCK:
            target_kind = LIR_OPERAND_BLOCK
        elif source_kind == MIR_OPERAND_TYPE:
            target_kind = LIR_OPERAND_TYPE
        let source_value = mir.values[source_offset + 1]
        if source_kind == MIR_OPERAND_TYPE:
            source_value = lir_type_from_mir(source_value)
        lir_append_value(values, target_kind, source_value)
        index = index + 1

def lir_lower_mir_record(mir: MirProgram, record_id: int, records: list[int], values: list[int]):
    let source_offset = mir_record_offset(record_id)
    let record_kind = mir.records[source_offset]
    let target_kind = lir_record_kind_from_mir(record_kind)
    let target_opcode = mir.records[source_offset + 3]
    let target_type = lir_type_from_mir(mir.records[source_offset + 4])
    let auxiliary_start = mir.records[source_offset + 8]
    let auxiliary_count = mir.records[source_offset + 9]
    if record_kind == MIR_RECORD_INSTRUCTION:
        target_opcode = lir_opcode_from_mir(mir.records[source_offset + 3])
        if (target_opcode == LIR_OP_BINARY or target_opcode == LIR_OP_UNARY or target_opcode == LIR_OP_CAST) and target_type != LIR_TYPE_I1 and target_type != LIR_TYPE_I32 and target_type != LIR_TYPE_F64:
            target_opcode = LIR_OP_RUNTIME_CALL
    elif record_kind == MIR_RECORD_TERMINATOR:
        target_opcode = lir_term_from_mir(mir.records[source_offset + 3])
    let target_auxiliary_start = -1
    let target_auxiliary_count = 0
    if record_kind == MIR_RECORD_FUNCTION:
        target_auxiliary_start = lir_value_count(values)
        lir_copy_value_range(mir, auxiliary_start, auxiliary_count, values)
        target_auxiliary_count = auxiliary_count
    if record_kind == MIR_RECORD_INSTRUCTION:
        let runtime_id = lir_runtime_from_mir(mir.records[source_offset + 3])
        if target_opcode == LIR_OP_RUNTIME_CALL and runtime_id == LIR_RUNTIME_NONE:
            runtime_id = 31
        if runtime_id != LIR_RUNTIME_NONE:
            target_auxiliary_start = runtime_id
            target_auxiliary_count = 1
    let target_operand_start = lir_value_count(values)
    if record_kind == MIR_RECORD_INSTRUCTION and target_opcode == LIR_OP_CONST and mir.records[source_offset + 7] == 0:
        lir_append_value(values, LIR_OPERAND_IMMEDIATE, 0)
    else:
        lir_copy_operands(mir, source_offset, values)
    let target_operand_count = lir_value_count(values) - target_operand_start
    let target = LirRecord{record_kind: target_kind, function_index: mir.records[source_offset + 1], block_index: mir.records[source_offset + 2], opcode: target_opcode, type_tag: target_type, result_value: mir.records[source_offset + 5], operand_start: target_operand_start, operand_count: target_operand_count, auxiliary_start: target_auxiliary_start, auxiliary_count: target_auxiliary_count, layout_id: target_type - 1, flags: 0, source_start: mir.records[source_offset + 10], source_end: mir.records[source_offset + 11]}
    lir_append_record(records, target)

def lir_model_build_program(mir: MirProgram) -> LirProgram:
    let phase_time = lir_debug_start()
    let records = []
    let values = []
    let layouts = lir_build_default_layouts()
    let record_id = 0
    while record_id < mir_record_count(mir.records):
        lir_lower_mir_record(mir, record_id, records, values)
        record_id = record_id + 1
    phase_time = lir_debug_checkpoint("lower", phase_time)
    let program = LirProgram{records: records, values: values, layouts: layouts}
    lir_prepare_value_cache(program)
    phase_time = lir_debug_checkpoint("cache", phase_time)
    lir_infer_block_parameter_types(program)
    lir_debug_checkpoint("params", phase_time)
    return program

def lir_value_cache_index(function_index: int, value: int) -> int:
    return function_index * lir_value_cache_width[0] + value

def lir_prepare_value_cache(program: LirProgram):
    let maximum_function = -1
    let maximum_value = -1
    let maximum_block = -1
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset + 1] > maximum_function:
            maximum_function = program.records[offset + 1]
        if program.records[offset + 5] > maximum_value:
            maximum_value = program.records[offset + 5]
        if program.records[offset + 2] > maximum_block:
            maximum_block = program.records[offset + 2]
        record_id = record_id + 1
    let width = maximum_value + 1
    if width < 1:
        width = 1
    lir_value_cache_width[0] = width
    lir_value_type_cache = []
    lir_block_parameter_cache = []
    lir_block_parameter_start_cache = []
    lir_block_parameter_count_cache = []
    lir_block_parameter_inferred_cache = []
    lir_block_parameter_has_incoming_cache = []
    lir_block_parameter_mismatch_cache = []
    let cache_size = (maximum_function + 1) * width
    let block_width = maximum_block + 1
    if block_width < 1:
        block_width = 1
    lir_block_cache_width[0] = block_width
    let block_cache_size = (maximum_function + 1) * block_width
    let cache_index = 0
    while cache_index < cache_size:
        append(lir_value_type_cache, 0)
        append(lir_block_parameter_cache, -1)
        append(lir_block_parameter_inferred_cache, LIR_TYPE_DYNAMIC)
        append(lir_block_parameter_has_incoming_cache, 0)
        append(lir_block_parameter_mismatch_cache, 0)
        cache_index = cache_index + 1
    cache_index = 0
    while cache_index < block_cache_size:
        append(lir_block_parameter_start_cache, -1)
        append(lir_block_parameter_count_cache, 0)
        cache_index = cache_index + 1
    record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        let function_index = program.records[offset + 1]
        let result_value = program.records[offset + 5]
        if function_index >= 0 and result_value >= 0:
            let value_index = lir_value_cache_index(function_index, result_value)
            if value_index < len(lir_value_type_cache):
                if program.records[offset] == LIR_RECORD_PARAMETER or program.records[offset] == LIR_RECORD_INSTRUCTION:
                    lir_value_type_cache[value_index] = program.records[offset + 4]
                if program.records[offset] == LIR_RECORD_PARAMETER and program.records[offset + 2] >= 0:
                    lir_block_parameter_cache[value_index] = program.records[offset + 2]
        if program.records[offset] == LIR_RECORD_PARAMETER and function_index >= 0 and program.records[offset + 2] >= 0:
            let block_cache_index = function_index * lir_block_cache_width[0] + program.records[offset + 2]
            if lir_block_parameter_start_cache[block_cache_index] < 0:
                lir_block_parameter_start_cache[block_cache_index] = offset
            lir_block_parameter_count_cache[block_cache_index] = lir_block_parameter_count_cache[block_cache_index] + 1
        record_id = record_id + 1

def lir_value_type_in_function(records: list[int], function_index: int, value: int) -> int:
    if function_index >= 0 and value >= 0 and lir_value_cache_width[0] > 0:
        let value_index = lir_value_cache_index(function_index, value)
        if value_index >= 0 and value_index < len(lir_value_type_cache) and lir_value_type_cache[value_index] != 0:
            return lir_value_type_cache[value_index]
        return LIR_TYPE_DYNAMIC
    let record_id = 0
    while record_id < lir_record_count(records):
        let offset = lir_record_offset(record_id)
        if records[offset + 1] == function_index and records[offset + 5] == value:
            if records[offset] == LIR_RECORD_PARAMETER or records[offset] == LIR_RECORD_INSTRUCTION:
                return records[offset + 4]
        record_id = record_id + 1
    return LIR_TYPE_DYNAMIC

def lir_is_block_parameter_value(records: list[int], function_index: int, value: int) -> bool:
    if function_index >= 0 and value >= 0 and lir_value_cache_width[0] > 0:
        let value_index = lir_value_cache_index(function_index, value)
        return value_index >= 0 and value_index < len(lir_block_parameter_cache) and lir_block_parameter_cache[value_index] >= 0
    let record_id = 0
    while record_id < lir_record_count(records):
        let offset = lir_record_offset(record_id)
        if records[offset] == LIR_RECORD_PARAMETER and records[offset + 1] == function_index and records[offset + 5] == value and records[offset + 2] >= 0:
            return true
        record_id = record_id + 1
    return false

def lir_block_parameter_offset(function_index: int, block_index: int, parameter_index: int) -> int:
    if function_index < 0 or block_index < 0 or parameter_index < 0 or lir_block_cache_width[0] <= 0:
        return -1
    let block_cache_index = function_index * lir_block_cache_width[0] + block_index
    if block_cache_index < 0 or block_cache_index >= len(lir_block_parameter_start_cache):
        return -1
    let parameter_count = lir_block_parameter_count_cache[block_cache_index]
    if parameter_index >= parameter_count:
        return -1
    return lir_block_parameter_start_cache[block_cache_index] + parameter_index * LIR_RECORD_SIZE

def lir_edge_argument_type(program: LirProgram, term_offset: int, operand_index: int, target_block: int) -> int:
    let value_offset = lir_value_offset(program.records[term_offset + 6] + operand_index)
    let operand_kind = program.values[value_offset]
    let operand_value = program.values[value_offset + 1]
    if operand_kind == LIR_OPERAND_VALUE:
        if lir_is_block_parameter_value(program.records, program.records[term_offset + 1], operand_value):
            let parameter_index = lir_value_cache_index(program.records[term_offset + 1], operand_value)
            if lir_block_parameter_cache[parameter_index] == target_block:
                return LIR_TYPE_DYNAMIC
            let parameter_type = lir_value_type_cache[parameter_index]
            return parameter_type
        let value_type = lir_value_type_in_function(program.records, program.records[term_offset + 1], operand_value)
        return value_type
    if operand_kind == LIR_OPERAND_SYMBOL:
        return LIR_TYPE_PTR
    if operand_kind == LIR_OPERAND_IMMEDIATE:
        return LIR_TYPE_I32
    return LIR_TYPE_DYNAMIC

def lir_merge_block_parameter_type(program: LirProgram, term_offset: int, target_block: int, argument_index: int, parameter_index: int):
    let function_index = program.records[term_offset + 1]
    let parameter_offset = lir_block_parameter_offset(function_index, target_block, parameter_index)
    if parameter_offset < 0:
        return
    let parameter_value = program.records[parameter_offset + 5]
    let cache_index = lir_value_cache_index(function_index, parameter_value)
    if cache_index < 0 or cache_index >= len(lir_block_parameter_inferred_cache):
        return
    let incoming_type = lir_edge_argument_type(program, term_offset, argument_index, target_block)
    if incoming_type == LIR_TYPE_DYNAMIC:
        return
    if lir_block_parameter_has_incoming_cache[cache_index] == 0:
        lir_block_parameter_inferred_cache[cache_index] = incoming_type
        lir_block_parameter_has_incoming_cache[cache_index] = 1
    elif lir_block_parameter_inferred_cache[cache_index] != incoming_type:
        lir_block_parameter_mismatch_cache[cache_index] = 1

def lir_collect_block_edge_types(program: LirProgram, term_offset: int, target_block: int, argument_start: int, argument_count: int):
    let parameter_index = 0
    while parameter_index < argument_count:
        lir_merge_block_parameter_type(program, term_offset, target_block, argument_start + parameter_index, parameter_index)
        parameter_index = parameter_index + 1

def lir_infer_block_parameter_types(program: LirProgram):
    let cache_index = 0
    while cache_index < len(lir_block_parameter_inferred_cache):
        lir_block_parameter_inferred_cache[cache_index] = LIR_TYPE_DYNAMIC
        lir_block_parameter_has_incoming_cache[cache_index] = 0
        lir_block_parameter_mismatch_cache[cache_index] = 0
        cache_index = cache_index + 1
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_TERMINATOR:
            let opcode = program.records[offset + 3]
            let operand_start = program.records[offset + 6]
            let operand_count = program.records[offset + 7]
            if opcode == LIR_TERM_JUMP and operand_count > 0:
                let target_offset = lir_value_offset(operand_start)
                let target_block = program.values[target_offset + 1]
                lir_collect_block_edge_types(program, offset, target_block, 1, operand_count - 1)
            elif opcode == LIR_TERM_BRANCH and operand_count > 3:
                let true_count_offset = lir_value_offset(operand_start + 3)
                let true_count = program.values[true_count_offset + 1]
                let false_count_index = 4 + true_count
                let true_target_offset = lir_value_offset(operand_start + 1)
                lir_collect_block_edge_types(program, offset, program.values[true_target_offset + 1], 4, true_count)
                if false_count_index < operand_count:
                    let false_count_offset = lir_value_offset(operand_start + false_count_index)
                    let false_count = program.values[false_count_offset + 1]
                    let false_target_offset = lir_value_offset(operand_start + 2)
                    lir_collect_block_edge_types(program, offset, program.values[false_target_offset + 1], false_count_index + 1, false_count)
        record_id = record_id + 1
    record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
        if program.records[offset] == LIR_RECORD_PARAMETER and program.records[offset + 2] >= 0:
            let function_index = program.records[offset + 1]
            let result_value = program.records[offset + 5]
            let value_index = lir_value_cache_index(function_index, result_value)
            if value_index >= 0 and value_index < len(lir_block_parameter_inferred_cache) and lir_block_parameter_has_incoming_cache[value_index] == 1 and lir_block_parameter_mismatch_cache[value_index] == 0:
                let inferred_type = lir_block_parameter_inferred_cache[value_index]
                program.records[offset + 4] = inferred_type
                if value_index < len(lir_value_type_cache):
                    lir_value_type_cache[value_index] = inferred_type
        record_id = record_id + 1

def lir_validation_error(record_id: int, reason: str) -> bool:
    __c_eprint_text("LIR validation failed record=")
    __c_eprint_int(record_id)
    __c_eprint_text(" reason=")
    __c_eprint_text(reason)
    __c_eprint_text("\n")
    return false

def lir_validate_model_program(program: LirProgram) -> bool:
    let records = program.records
    let values = program.values
    let layouts = program.layouts
    if len(records) % LIR_RECORD_SIZE != 0 or len(values) % LIR_VALUE_SIZE != 0 or len(layouts) % LIR_LAYOUT_SIZE != 0:
        return lir_validation_error(-1, "record/value alignment")
    let value_count = lir_value_count(values)
    let record_count = lir_record_count(records)
    let record_id = 0
    let active_function = -1
    let active_block = -1
    let block_has_terminator = true
    while record_id < record_count:
        let offset = lir_record_offset(record_id)
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
        let layout_id = records[offset + 10]
        if kind < LIR_RECORD_MODULE or kind > LIR_RECORD_MAX:
            return lir_validation_error(record_id, "record kind")
        if type_tag < LIR_TYPE_VOID or type_tag > LIR_TYPE_MAX or result_value < -1:
            return lir_validation_error(record_id, "type or result")
        if kind == LIR_RECORD_INSTRUCTION and (opcode < LIR_OP_CONST or opcode > LIR_OP_MAX):
            return lir_validation_error(record_id, "instruction opcode")
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_CONST and operand_count < 1:
            return lir_validation_error(record_id, "constant operands")
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_COPY and operand_count < 1:
            return lir_validation_error(record_id, "copy operands")
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_BINARY and operand_count < 3:
            return lir_validation_error(record_id, "binary operands")
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_SELECT and operand_count < 3:
            return lir_validation_error(record_id, "select operands")
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_BINARY and type_tag != LIR_TYPE_I1 and type_tag != LIR_TYPE_I32 and type_tag != LIR_TYPE_F64:
            return lir_validation_error(record_id, "binary type")
        if kind == LIR_RECORD_TERMINATOR and (opcode < LIR_TERM_JUMP or opcode > LIR_TERM_MAX):
            return lir_validation_error(record_id, "terminator opcode")
        if operand_start < 0 or operand_count < 0 or operand_start > value_count or operand_count > value_count - operand_start:
            return lir_validation_error(record_id, "operand range")
        if auxiliary_count < 0 or (auxiliary_count > 0 and auxiliary_start < 0):
            return lir_validation_error(record_id, "auxiliary range")
        if layout_id < 0 or layout_id >= lir_layout_count(layouts):
            return lir_validation_error(record_id, "layout")
        if kind == LIR_RECORD_MODULE:
            if function_index != -1 or block_index != -1:
                return lir_validation_error(record_id, "module owner")
        elif function_index < 0:
            return lir_validation_error(record_id, "missing function")
        if kind == LIR_RECORD_BLOCK or kind == LIR_RECORD_INSTRUCTION or kind == LIR_RECORD_TERMINATOR:
            if block_index < 0:
                return lir_validation_error(record_id, "block index")
        if kind == LIR_RECORD_FUNCTION:
            if active_block >= 0 and not block_has_terminator:
                return lir_validation_error(record_id, "unterminated block before function")
            active_function = function_index
            active_block = -1
            block_has_terminator = true
        elif kind == LIR_RECORD_BLOCK:
            if active_block >= 0 and not block_has_terminator:
                return lir_validation_error(record_id, "block owner")
            if function_index != active_function:
                return lir_validation_error(record_id, "block order")
            active_block = block_index
            block_has_terminator = false
        elif kind == LIR_RECORD_INSTRUCTION:
            if function_index != active_function or block_index != active_block or block_has_terminator:
                return lir_validation_error(record_id, "instruction placement")
        elif kind == LIR_RECORD_TERMINATOR:
            if function_index != active_function or block_index != active_block or block_has_terminator:
                return lir_validation_error(record_id, "terminator placement")
            if opcode == LIR_TERM_JUMP and operand_count < 1:
                return lir_validation_error(record_id, "jump operands")
            if opcode == LIR_TERM_BRANCH and operand_count < 3:
                return lir_validation_error(record_id, "branch operands")
            if opcode == LIR_TERM_RETURN and operand_count > 1:
                return lir_validation_error(record_id, "return operands")
            block_has_terminator = true
        let operand_index = operand_start
        while operand_index < operand_start + operand_count:
            let value_offset = lir_value_offset(operand_index)
            let operand_kind = values[value_offset]
            let operand_value = values[value_offset + 1]
            if operand_kind < LIR_OPERAND_VALUE or operand_kind > LIR_OPERAND_MAX or operand_value < 0:
                return lir_validation_error(record_id, "operand value")
            operand_index = operand_index + 1
        if kind == LIR_RECORD_INSTRUCTION and opcode == LIR_OP_RUNTIME_CALL and auxiliary_count != 1:
            return lir_validation_error(record_id, "runtime id")
        if kind == LIR_RECORD_INSTRUCTION and type_tag == LIR_TYPE_AGGREGATE and layout_id < -1:
            return lir_validation_error(record_id, "aggregate layout")
        record_id = record_id + 1
    if active_block >= 0 and not block_has_terminator:
        return lir_validation_error(-1, "unterminated final block")
    return true

def lir_validate_program(program: LirProgram) -> bool:
    return lir_validate_model_program(program)

def lir_empty_program() -> LirProgram:
    return LirProgram{records: [], values: [], layouts: lir_build_default_layouts()}

def lir_dump_validated_program(program: LirProgram, output: TextBuffer) -> bool:
    append(output, "LIR version=")
    append(output, LIR_MODEL_VERSION)
    append(output, " records=")
    append(output, lir_record_count(program.records))
    append(output, " values=")
    append(output, lir_value_count(program.values))
    append(output, " layouts=")
    append(output, lir_layout_count(program.layouts))
    append(output, "\n")
    let record_id = 0
    while record_id < lir_record_count(program.records):
        let offset = lir_record_offset(record_id)
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
            let operand_offset = lir_value_offset(program.records[offset + 6] + operand_index)
            append(output, program.values[operand_offset])
            append(output, ":")
            append(output, program.values[operand_offset + 1])
            operand_index = operand_index + 1
        append(output, "]")
        append(output, " aux=")
        append(output, program.records[offset + 8])
        append(output, ":")
        append(output, program.records[offset + 9])
        append(output, "\n")
        record_id = record_id + 1
    return true

def lir_dump_program(program: LirProgram, output: TextBuffer) -> bool:
    if not lir_validate_model_program(program):
        return false
    return lir_dump_validated_program(program, output)
