from text_buffer import TextBuffer

const MIR_VERSION: int = 1
const MIR_INPUT_HIR_RECORD_SIZE: int = 11
const MIR_INPUT_HIR_FUNCTION_RECORD: int = 5
const MIR_RECORD_SIZE: int = 12
const MIR_INVALID_INDEX: int = 0 - 1
const MIR_INVALID_VALUE: int = 0 - 1

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
const MIR_TYPE_MAX: int = MIR_TYPE_FUNCTION

const MIR_OPERAND_VALUE: int = 1
const MIR_OPERAND_I32: int = 2
const MIR_OPERAND_F64_TEXT: int = 3
const MIR_OPERAND_BOOL: int = 4
const MIR_OPERAND_STRING: int = 5
const MIR_OPERAND_FUNCTION: int = 6
const MIR_OPERAND_GLOBAL: int = 7
const MIR_OPERAND_BLOCK: int = 8
const MIR_OPERAND_TYPE: int = 9

const MIR_EFFECT_PURE: int = 0
const MIR_EFFECT_READ_MEMORY: int = 1
const MIR_EFFECT_WRITE_MEMORY: int = 2
const MIR_EFFECT_ALLOCATE: int = 4
const MIR_EFFECT_MAY_FAIL: int = 8
const MIR_EFFECT_CALL: int = 16

const MIR_OP_BINARY: int = 1
const MIR_OP_COMPARE: int = 2
const MIR_OP_CAST: int = 3
const MIR_OP_SELECT: int = 4
const MIR_OP_ALLOCA: int = 5
const MIR_OP_LOAD: int = 6
const MIR_OP_STORE: int = 7
const MIR_OP_GEP: int = 8
const MIR_OP_CALL: int = 9
const MIR_OP_CALL_INDIRECT: int = 10
const MIR_OP_TUPLE_MAKE: int = 11
const MIR_OP_TUPLE_GET: int = 12
const MIR_OP_STRUCT_MAKE: int = 13
const MIR_OP_STRUCT_GET: int = 14
const MIR_OP_ENUM_MAKE: int = 15
const MIR_OP_ENUM_TAG: int = 16
const MIR_OP_ENUM_GET: int = 17
const MIR_OP_GLOBAL_LOAD: int = 18
const MIR_OP_GLOBAL_STORE: int = 19
const MIR_OP_MAX: int = MIR_OP_GLOBAL_STORE

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

def mir_record_kind_is_valid(record_kind: int) -> bool:
    return record_kind >= MIR_RECORD_MODULE and record_kind <= MIR_RECORD_TERMINATOR

def mir_type_is_valid(type_tag: int) -> bool:
    return type_tag >= MIR_TYPE_UNKNOWN and type_tag <= MIR_TYPE_MAX

def mir_record_opcode_is_valid(record_kind: int, opcode: int) -> bool:
    if record_kind == MIR_RECORD_MODULE or record_kind == MIR_RECORD_TYPE or record_kind == MIR_RECORD_GLOBAL or record_kind == MIR_RECORD_EXTERN or record_kind == MIR_RECORD_FUNCTION or record_kind == MIR_RECORD_BLOCK or record_kind == MIR_RECORD_PARAMETER:
        return opcode == 0
    if record_kind == MIR_RECORD_INSTRUCTION:
        return opcode >= MIR_OP_BINARY and opcode <= MIR_OP_MAX
    if record_kind == MIR_RECORD_TERMINATOR:
        return opcode >= MIR_TERM_JUMP and opcode <= MIR_TERM_MAX
    return false

def mir_range_is_valid(start: int, count: int, value_count: int) -> bool:
    if start < 0 or count < 0:
        return false
    return start <= value_count and count <= value_count - start

def mir_validate_program(program: MirProgram) -> bool:
    let records = program.records
    let values = program.values
    if len(records) % MIR_RECORD_SIZE != 0:
        return false
    let record_index = 0
    while record_index < len(records):
        let record_kind = records[record_index]
        let function_index = records[record_index + 1]
        let block_index = records[record_index + 2]
        let opcode = records[record_index + 3]
        let type_tag = records[record_index + 4]
        let result_value = records[record_index + 5]
        let operand_start = records[record_index + 6]
        let operand_count = records[record_index + 7]
        let auxiliary_start = records[record_index + 8]
        let auxiliary_count = records[record_index + 9]
        let source_start = records[record_index + 10]
        let source_end = records[record_index + 11]
        if not mir_record_kind_is_valid(record_kind):
            return false
        if not mir_record_opcode_is_valid(record_kind, opcode):
            return false
        if not mir_type_is_valid(type_tag):
            return false
        if result_value < 0 - 1:
            return false
        if source_start < 0 or source_end < source_start:
            return false
        if not mir_range_is_valid(operand_start, operand_count, len(values)):
            return false
        if not mir_range_is_valid(auxiliary_start, auxiliary_count, len(values)):
            return false
        if record_kind == MIR_RECORD_MODULE:
            if function_index != 0 - 1 or block_index != 0 - 1:
                return false
        if record_kind != MIR_RECORD_MODULE:
            if function_index < 0:
                return false
        if record_kind == MIR_RECORD_BLOCK or record_kind == MIR_RECORD_PARAMETER or record_kind == MIR_RECORD_INSTRUCTION or record_kind == MIR_RECORD_TERMINATOR:
            if block_index < 0:
                return false
        record_index = record_index + MIR_RECORD_SIZE
    return true

def mir_empty_program() -> MirProgram:
    return MirProgram{records: [], values: []}

def mir_model_build_program(hir_records: list[int]) -> MirProgram:
    let records = []
    let values = []
    let module_record = MirRecord{record_kind: MIR_RECORD_MODULE, function_index: 0 - 1, block_index: 0 - 1, opcode: 0, type_tag: MIR_TYPE_UNKNOWN, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    mir_append_record(records, module_record)
    let hir_record_index = 0
    let function_index = 0
    while hir_record_index < len(hir_records):
        let hir_record_kind = hir_records[hir_record_index]
        if hir_record_kind == MIR_INPUT_HIR_FUNCTION_RECORD:
            let source_start = hir_records[hir_record_index + 3]
            let source_end = hir_records[hir_record_index + 4]
            let function_record = MirRecord{record_kind: MIR_RECORD_FUNCTION, function_index: function_index, block_index: 0, opcode: 0, type_tag: MIR_TYPE_FUNCTION, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: source_start, source_end: source_end}
            let block_record = MirRecord{record_kind: MIR_RECORD_BLOCK, function_index: function_index, block_index: 0, opcode: 0, type_tag: MIR_TYPE_UNIT, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: source_start, source_end: source_end}
            let terminator_record = MirRecord{record_kind: MIR_RECORD_TERMINATOR, function_index: function_index, block_index: 0, opcode: MIR_TERM_UNREACHABLE, type_tag: MIR_TYPE_UNKNOWN, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: source_start, source_end: source_end}
            mir_append_record(records, function_record)
            mir_append_record(records, block_record)
            mir_append_record(records, terminator_record)
            function_index = function_index + 1
        hir_record_index = hir_record_index + MIR_INPUT_HIR_RECORD_SIZE
    return MirProgram{records: records, values: values}

def mir_sample_program() -> MirProgram:
    let records = []
    let values = [MIR_OPERAND_I32, 1, MIR_OPERAND_I32, 2]
    let module_record = MirRecord{record_kind: MIR_RECORD_MODULE, function_index: 0 - 1, block_index: 0 - 1, opcode: 0, type_tag: MIR_TYPE_UNKNOWN, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 0}
    let function_record = MirRecord{record_kind: MIR_RECORD_FUNCTION, function_index: 0, block_index: 0, opcode: 0, type_tag: MIR_TYPE_I32, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 1}
    let block_record = MirRecord{record_kind: MIR_RECORD_BLOCK, function_index: 0, block_index: 0, opcode: 0, type_tag: MIR_TYPE_UNIT, result_value: 0 - 1, operand_start: 0, operand_count: 0, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 1}
    let instruction_record = MirRecord{record_kind: MIR_RECORD_INSTRUCTION, function_index: 0, block_index: 0, opcode: MIR_OP_BINARY, type_tag: MIR_TYPE_I32, result_value: 0, operand_start: 0, operand_count: 4, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 1}
    let terminator_record = MirRecord{record_kind: MIR_RECORD_TERMINATOR, function_index: 0, block_index: 0, opcode: MIR_TERM_RETURN, type_tag: MIR_TYPE_I32, result_value: 0 - 1, operand_start: 0, operand_count: 1, auxiliary_start: 0, auxiliary_count: 0, source_start: 0, source_end: 1}
    mir_append_record(records, module_record)
    mir_append_record(records, function_record)
    mir_append_record(records, block_record)
    mir_append_record(records, instruction_record)
    mir_append_record(records, terminator_record)
    return MirProgram{records: records, values: values}

def mir_dump_program(program: MirProgram, output: TextBuffer) -> bool:
    if not mir_validate_program(program):
        return false
    append(output, "MIR version=")
    append(output, MIR_VERSION)
    append(output, " records=")
    append(output, len(program.records) / MIR_RECORD_SIZE)
    append(output, " values=")
    append(output, len(program.values))
    append(output, "\n")
    let record_index = 0
    while record_index < len(program.records):
        append(output, "record kind=")
        append(output, program.records[record_index])
        append(output, " function=")
        append(output, program.records[record_index + 1])
        append(output, " block=")
        append(output, program.records[record_index + 2])
        append(output, " opcode=")
        append(output, program.records[record_index + 3])
        append(output, " operands=")
        append(output, program.records[record_index + 7])
        append(output, "\n")
        record_index = record_index + MIR_RECORD_SIZE
    return true
