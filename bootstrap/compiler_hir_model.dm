from text_buffer import TextBuffer

const HIR_MODEL_VERSION: int = 1
const HIR_MODEL_RECORD_SIZE: int = 11

const HIR_MODEL_RECORD_MODULE: int = 1
const HIR_MODEL_RECORD_TYPE: int = 2
const HIR_MODEL_RECORD_GLOBAL: int = 3
const HIR_MODEL_RECORD_EXTERN: int = 4
const HIR_MODEL_RECORD_FUNCTION: int = 5
const HIR_MODEL_RECORD_BLOCK: int = 6
const HIR_MODEL_RECORD_PARAMETER: int = 7
const HIR_MODEL_RECORD_STATEMENT: int = 8
const HIR_MODEL_RECORD_EXPRESSION: int = 9
const HIR_MODEL_RECORD_PATTERN: int = 10

const HIR_MODEL_OP_NONE: int = 0
const HIR_MODEL_OP_LET: int = 1
const HIR_MODEL_OP_ASSIGN: int = 2
const HIR_MODEL_OP_RETURN: int = 3
const HIR_MODEL_OP_BREAK: int = 4
const HIR_MODEL_OP_CONTINUE: int = 5
const HIR_MODEL_OP_IF: int = 6
const HIR_MODEL_OP_WHILE: int = 7
const HIR_MODEL_OP_FOR: int = 8
const HIR_MODEL_OP_MATCH: int = 9
const HIR_MODEL_OP_LITERAL: int = 10
const HIR_MODEL_OP_LOCAL: int = 11
const HIR_MODEL_OP_BINARY: int = 12
const HIR_MODEL_OP_UNARY: int = 13
const HIR_MODEL_OP_CALL: int = 14
const HIR_MODEL_OP_LAMBDA: int = 15
const HIR_MODEL_OP_LIST: int = 16
const HIR_MODEL_OP_DICT: int = 17
const HIR_MODEL_OP_TUPLE: int = 18
const HIR_MODEL_OP_INDEX: int = 19
const HIR_MODEL_OP_SLICE: int = 20
const HIR_MODEL_OP_FIELD: int = 21
const HIR_MODEL_OP_PATTERN: int = 22
const HIR_MODEL_OP_MAX: int = HIR_MODEL_OP_PATTERN

const HIR_MODEL_TYPE_UNKNOWN: int = 0
const HIR_MODEL_TYPE_UNIT: int = 1
const HIR_MODEL_TYPE_BOOL: int = 2
const HIR_MODEL_TYPE_I32: int = 3
const HIR_MODEL_TYPE_F64: int = 4
const HIR_MODEL_TYPE_STR: int = 5
const HIR_MODEL_TYPE_BYTES: int = 6
const HIR_MODEL_TYPE_LIST: int = 7
const HIR_MODEL_TYPE_DICT: int = 8
const HIR_MODEL_TYPE_TUPLE: int = 9
const HIR_MODEL_TYPE_STRUCT: int = 10
const HIR_MODEL_TYPE_ENUM: int = 11
const HIR_MODEL_TYPE_INTERFACE: int = 12
const HIR_MODEL_TYPE_UNION: int = 13
const HIR_MODEL_TYPE_CLOSURE: int = 14
const HIR_MODEL_TYPE_FUNCTION: int = 15
const HIR_MODEL_TYPE_MAX: int = HIR_MODEL_TYPE_FUNCTION

struct HirRecord:
    record_kind: int
    opcode: int
    type_tag: int
    source_start: int
    source_end: int
    payload_start: int
    payload_count: int
    auxiliary_start: int
    auxiliary_count: int
    name_start: int
    name_end: int

struct HirProgram:
    records: list[int]
    values: list[int]

def hir_model_append_record(records: list[int], record: HirRecord):
    append(records, record.record_kind)
    append(records, record.opcode)
    append(records, record.type_tag)
    append(records, record.source_start)
    append(records, record.source_end)
    append(records, record.payload_start)
    append(records, record.payload_count)
    append(records, record.auxiliary_start)
    append(records, record.auxiliary_count)
    append(records, record.name_start)
    append(records, record.name_end)

def hir_record_kind_is_valid(record_kind: int) -> bool:
    return record_kind >= HIR_MODEL_RECORD_MODULE and record_kind <= HIR_MODEL_RECORD_PATTERN

def hir_type_is_valid(type_tag: int) -> bool:
    return type_tag >= HIR_MODEL_TYPE_UNKNOWN and type_tag <= HIR_MODEL_TYPE_MAX

def hir_record_opcode_is_valid(record_kind: int, opcode: int) -> bool:
    if record_kind == HIR_MODEL_RECORD_MODULE or record_kind == HIR_MODEL_RECORD_TYPE or record_kind == HIR_MODEL_RECORD_GLOBAL or record_kind == HIR_MODEL_RECORD_EXTERN or record_kind == HIR_MODEL_RECORD_FUNCTION or record_kind == HIR_MODEL_RECORD_BLOCK or record_kind == HIR_MODEL_RECORD_PARAMETER:
        return opcode == HIR_MODEL_OP_NONE
    elif record_kind == HIR_MODEL_RECORD_STATEMENT or record_kind == HIR_MODEL_RECORD_EXPRESSION:
        return opcode >= HIR_MODEL_OP_LET and opcode <= HIR_MODEL_OP_MAX
    elif record_kind == HIR_MODEL_RECORD_PATTERN:
        return opcode == HIR_MODEL_OP_PATTERN
    return false

def hir_model_record_is_function(record_kind: int) -> bool:
    return record_kind == HIR_MODEL_RECORD_FUNCTION

def hir_model_record_kind_from_ast(kind: int) -> int:
    if kind >= AST_PAT_WILDCARD and kind <= AST_PAT_STRUCT or kind == AST_M_CASE:
        return HIR_MODEL_RECORD_PATTERN
    elif kind >= AST_STMT_LET and kind <= AST_STMT_BREAK or kind == AST_ELIF or kind == AST_CASE:
        return HIR_MODEL_RECORD_STATEMENT
    return HIR_MODEL_RECORD_EXPRESSION

def hir_model_opcode_from_ast(kind: int) -> int:
    if kind == AST_STMT_LET or kind == AST_STMT_LET_TUPLE:
        return HIR_MODEL_OP_LET
    elif kind == AST_STMT_ASSIGN:
        return HIR_MODEL_OP_ASSIGN
    elif kind == AST_STMT_RETURN:
        return HIR_MODEL_OP_RETURN
    elif kind == AST_STMT_BREAK:
        return HIR_MODEL_OP_BREAK
    elif kind == AST_STMT_EXPR:
        return HIR_MODEL_OP_CALL
    elif kind == AST_STMT_IF or kind == AST_ELIF or kind == AST_EXPR_COND:
        return HIR_MODEL_OP_IF
    elif kind == AST_STMT_WHILE:
        return HIR_MODEL_OP_WHILE
    elif kind == AST_STMT_FOR:
        return HIR_MODEL_OP_FOR
    elif kind == AST_STMT_SWITCH or kind == AST_CASE or kind == AST_EXPR_MATCH:
        return HIR_MODEL_OP_MATCH
    elif kind >= AST_EXPR_INT and kind <= AST_EXPR_BOOL:
        return HIR_MODEL_OP_LITERAL
    elif kind == AST_EXPR_VAR:
        return HIR_MODEL_OP_LOCAL
    elif kind == AST_EXPR_CALL or kind == AST_EXPR_METHOD_CALL or kind == AST_EXPR_PRINT:
        return HIR_MODEL_OP_CALL
    elif kind == AST_EXPR_BINARY or kind == AST_EXPR_LOGICAL:
        return HIR_MODEL_OP_BINARY
    elif kind == AST_EXPR_UNARY:
        return HIR_MODEL_OP_UNARY
    elif kind == AST_EXPR_LAMBDA:
        return HIR_MODEL_OP_LAMBDA
    elif kind == AST_EXPR_LIST or kind == AST_EXPR_LIST_COMP:
        return HIR_MODEL_OP_LIST
    elif kind == AST_EXPR_DICT:
        return HIR_MODEL_OP_DICT
    elif kind == AST_EXPR_TUPLE:
        return HIR_MODEL_OP_TUPLE
    elif kind == AST_EXPR_INDEX:
        return HIR_MODEL_OP_INDEX
    elif kind == AST_EXPR_SLICE:
        return HIR_MODEL_OP_SLICE
    elif kind == AST_EXPR_ATTR or kind == AST_EXPR_STRUCT or kind == AST_EXPR_ENUM or kind == AST_EXPR_BUILTIN_ENUM:
        return HIR_MODEL_OP_FIELD
    elif kind >= AST_PAT_WILDCARD and kind <= AST_PAT_STRUCT or kind == AST_M_CASE:
        return HIR_MODEL_OP_PATTERN
    return HIR_MODEL_OP_NONE

def hir_model_type_from_ast(kind: int) -> int:
    if kind == AST_EXPR_INT or kind == AST_EXPR_RUNE:
        return HIR_MODEL_TYPE_I32
    elif kind == AST_EXPR_FLOAT:
        return HIR_MODEL_TYPE_F64
    elif kind == AST_EXPR_STRING:
        return HIR_MODEL_TYPE_STR
    elif kind == AST_EXPR_BOOL:
        return HIR_MODEL_TYPE_BOOL
    elif kind == AST_EXPR_LIST or kind == AST_EXPR_LIST_COMP:
        return HIR_MODEL_TYPE_LIST
    elif kind == AST_EXPR_DICT:
        return HIR_MODEL_TYPE_DICT
    elif kind == AST_EXPR_TUPLE:
        return HIR_MODEL_TYPE_TUPLE
    elif kind == AST_EXPR_LAMBDA:
        return HIR_MODEL_TYPE_CLOSURE
    return HIR_MODEL_TYPE_UNKNOWN

def hir_range_is_valid(start: int, count: int, value_count: int) -> bool:
    if start < 0 or count < 0:
        return false
    return start <= value_count and count <= value_count - start

def hir_report_invalid_record(records: list[int], record_index: int, values: list[int]):
    __c_eprint_text("HIR invalid record=")
    __c_eprint_int(record_index / HIR_MODEL_RECORD_SIZE)
    __c_eprint_text(" kind=")
    __c_eprint_int(records[record_index])
    __c_eprint_text(" opcode=")
    __c_eprint_int(records[record_index + 1])
    __c_eprint_text(" type=")
    __c_eprint_int(records[record_index + 2])
    __c_eprint_text(" source=")
    __c_eprint_int(records[record_index + 3])
    __c_eprint_text("..")
    __c_eprint_int(records[record_index + 4])
    __c_eprint_text(" payload=")
    __c_eprint_int(records[record_index + 5])
    __c_eprint_text("+")
    __c_eprint_int(records[record_index + 6])
    __c_eprint_text(" values=")
    __c_eprint_int(len(values))
    __c_eprint_text("\n")

def hir_validate_model_program(program: HirProgram) -> bool:
    let records = program.records
    let values = program.values
    if len(records) % HIR_MODEL_RECORD_SIZE != 0:
        return false
    let record_index = 0
    while record_index < len(records):
        let record_kind = records[record_index]
        let opcode = records[record_index + 1]
        let type_tag = records[record_index + 2]
        let source_start = records[record_index + 3]
        let source_end = records[record_index + 4]
        let payload_start = records[record_index + 5]
        let payload_count = records[record_index + 6]
        let auxiliary_start = records[record_index + 7]
        let auxiliary_count = records[record_index + 8]
        let name_start = records[record_index + 9]
        let name_end = records[record_index + 10]
        if not hir_record_kind_is_valid(record_kind):
            hir_report_invalid_record(records, record_index, values)
            return false
        if not hir_record_opcode_is_valid(record_kind, opcode):
            hir_report_invalid_record(records, record_index, values)
            return false
        if not hir_type_is_valid(type_tag):
            hir_report_invalid_record(records, record_index, values)
            return false
        if source_start < 0 or source_end < source_start:
            hir_report_invalid_record(records, record_index, values)
            return false
        if name_start < 0 or name_end < name_start:
            hir_report_invalid_record(records, record_index, values)
            return false
        if not hir_range_is_valid(payload_start, payload_count, len(values)):
            hir_report_invalid_record(records, record_index, values)
            return false
        if not hir_range_is_valid(auxiliary_start, auxiliary_count, len(values)):
            hir_report_invalid_record(records, record_index, values)
            return false
        record_index = record_index + HIR_MODEL_RECORD_SIZE
    return true

def hir_model_append_ast_node(records: list[int], values: list[int], ast: list[int], node: int):
    let kind = ast_node_kind(ast, node)
    let argument_count = ast_node_size(kind) - 3
    let payload_start = len(values)
    let argument_index = 0
    while argument_index < argument_count:
        append(values, ast_node_arg(ast, node, argument_index))
        argument_index = argument_index + 1
    let record = HirRecord{record_kind: hir_model_record_kind_from_ast(kind), opcode: hir_model_opcode_from_ast(kind), type_tag: hir_model_type_from_ast(kind), source_start: ast_node_start(ast, node), source_end: ast_node_end(ast, node), payload_start: payload_start, payload_count: argument_count, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
    hir_model_append_record(records, record)

def hir_model_append_ast_range(records: list[int], values: list[int], ast: list[int], start: int, end: int):
    let node = start
    while node < end:
        hir_model_append_ast_node(records, values, ast, node)
        let next_node = node + ast_node_size(ast_node_kind(ast, node))
        if next_node <= node:
            return
        node = next_node

def hir_model_build_program(ast: list[int], function_starts: list[int], function_ends: list[int], global_nodes: list[int]) -> HirProgram:
    let records = []
    let values = []
    let module_record = HirRecord{record_kind: HIR_MODEL_RECORD_MODULE, opcode: HIR_MODEL_OP_NONE, type_tag: HIR_MODEL_TYPE_UNKNOWN, source_start: 0, source_end: 0, payload_start: 0, payload_count: 0, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
    hir_model_append_record(records, module_record)
    let function_index = 0
    while function_index < len(function_starts):
        let function_start = function_starts[function_index]
        let function_end = function_ends[function_index]
        let function_payload_start = len(values)
        append(values, function_start)
        append(values, function_end)
        let function_record = HirRecord{record_kind: HIR_MODEL_RECORD_FUNCTION, opcode: HIR_MODEL_OP_NONE, type_tag: HIR_MODEL_TYPE_FUNCTION, source_start: 0, source_end: 0, payload_start: function_payload_start, payload_count: 2, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
        hir_model_append_record(records, function_record)
        hir_model_append_ast_range(records, values, ast, function_start, function_end)
        function_index = function_index + 1
    let global_index = 0
    while global_index < len(global_nodes):
        let global_node = global_nodes[global_index]
        let global_payload_start = len(values)
        append(values, global_node)
        let global_record = HirRecord{record_kind: HIR_MODEL_RECORD_GLOBAL, opcode: HIR_MODEL_OP_NONE, type_tag: HIR_MODEL_TYPE_UNKNOWN, source_start: ast_node_start(ast, global_node), source_end: ast_node_end(ast, global_node), payload_start: global_payload_start, payload_count: 1, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
        hir_model_append_record(records, global_record)
        hir_model_append_ast_node(records, values, ast, global_node)
        global_index = global_index + 1
    return HirProgram{records: records, values: values}

def hir_empty_program() -> HirProgram:
    return HirProgram{records: [], values: []}

def hir_model_sample_program() -> HirProgram:
    let records = []
    let values = [0, 0]
    let module_record = HirRecord{record_kind: HIR_MODEL_RECORD_MODULE, opcode: HIR_MODEL_OP_NONE, type_tag: HIR_MODEL_TYPE_UNKNOWN, source_start: 0, source_end: 0, payload_start: 0, payload_count: 0, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
    let expression_record = HirRecord{record_kind: HIR_MODEL_RECORD_EXPRESSION, opcode: HIR_MODEL_OP_LITERAL, type_tag: HIR_MODEL_TYPE_I32, source_start: 0, source_end: 1, payload_start: 0, payload_count: 1, auxiliary_start: 1, auxiliary_count: 1, name_start: 0, name_end: 0}
    hir_model_append_record(records, module_record)
    hir_model_append_record(records, expression_record)
    return HirProgram{records: records, values: values}

def hir_model_dump_program(program: HirProgram, output: TextBuffer) -> bool:
    if not hir_validate_model_program(program):
        return false
    append(output, "HIR version=")
    append(output, HIR_MODEL_VERSION)
    append(output, " records=")
    append(output, len(program.records) / HIR_MODEL_RECORD_SIZE)
    append(output, " values=")
    append(output, len(program.values))
    append(output, "\n")
    let record_index = 0
    while record_index < len(program.records):
        append(output, "record kind=")
        append(output, program.records[record_index])
        append(output, " opcode=")
        append(output, program.records[record_index + 1])
        append(output, " type=")
        append(output, program.records[record_index + 2])
        append(output, " payload=")
        append(output, program.records[record_index + 6])
        append(output, " auxiliary=")
        append(output, program.records[record_index + 8])
        append(output, "\n")
        record_index = record_index + HIR_MODEL_RECORD_SIZE
    return true
