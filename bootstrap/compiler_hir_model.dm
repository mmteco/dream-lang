from text_buffer import TextBuffer
from bootstrap_io import text_length

const HIR_MODEL_VERSION: int = 3
const HIR_MODEL_RECORD_SIZE: int = 11
const HIR_MODEL_VALUE_SIZE: int = 2

const HIR_RECORD_MODULE: int = 1
const HIR_RECORD_TYPE: int = 2
const HIR_RECORD_GLOBAL: int = 3
const HIR_RECORD_EXTERN: int = 4
const HIR_RECORD_FUNCTION: int = 5
const HIR_RECORD_BLOCK: int = 6
const HIR_RECORD_PARAMETER: int = 7
const HIR_RECORD_STATEMENT: int = 8
const HIR_RECORD_EXPRESSION: int = 9
const HIR_RECORD_PATTERN: int = 10

const HIR_OP_NONE: int = 0
const HIR_OP_LET: int = 1
const HIR_OP_ASSIGN: int = 2
const HIR_OP_RETURN: int = 3
const HIR_OP_BREAK: int = 4
const HIR_OP_CONTINUE: int = 5
const HIR_OP_IF: int = 6
const HIR_OP_WHILE: int = 7
const HIR_OP_FOR: int = 8
const HIR_OP_MATCH: int = 9
const HIR_OP_LITERAL: int = 10
const HIR_OP_LOCAL: int = 11
const HIR_OP_BINARY: int = 12
const HIR_OP_UNARY: int = 13
const HIR_OP_CALL: int = 14
const HIR_OP_LAMBDA: int = 15
const HIR_OP_LIST: int = 16
const HIR_OP_DICT: int = 17
const HIR_OP_TUPLE: int = 18
const HIR_OP_INDEX: int = 19
const HIR_OP_SLICE: int = 20
const HIR_OP_FIELD: int = 21
const HIR_OP_STRUCT: int = 22
const HIR_OP_ENUM: int = 23
const HIR_OP_PRINT: int = 24
const HIR_OP_SEQUENCE: int = 25
const HIR_OP_MAX: int = HIR_OP_SEQUENCE

const HIR_TYPE_UNKNOWN: int = 0
const HIR_TYPE_UNIT: int = 1
const HIR_TYPE_BOOL: int = 2
const HIR_TYPE_I32: int = 3
const HIR_TYPE_F64: int = 4
const HIR_TYPE_STR: int = 5
const HIR_TYPE_BYTES: int = 6
const HIR_TYPE_LIST: int = 7
const HIR_TYPE_DICT: int = 8
const HIR_TYPE_TUPLE: int = 9
const HIR_TYPE_STRUCT: int = 10
const HIR_TYPE_ENUM: int = 11
const HIR_TYPE_INTERFACE: int = 12
const HIR_TYPE_UNION: int = 13
const HIR_TYPE_CLOSURE: int = 14
const HIR_TYPE_FUNCTION: int = 15
const HIR_TYPE_DYNAMIC: int = 16
const HIR_TYPE_MAX: int = HIR_TYPE_DYNAMIC

const HIR_VALUE_NONE: int = 0
const HIR_VALUE_INT: int = 1
const HIR_VALUE_NODE: int = 2
const HIR_VALUE_BLOCK: int = 3

const HIR_SIGNATURE_PARAM_COUNT: int = 0
const HIR_SIGNATURE_RETURN_TYPE: int = 1
const HIR_SIGNATURE_PARAM_BASE: int = 2
const HIR_SIGNATURE_PARAM_SIZE: int = 4

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

def hir_record_count(records: list[int]) -> int:
    return len(records) / HIR_MODEL_RECORD_SIZE

def hir_value_count(values: list[int]) -> int:
    return len(values) / HIR_MODEL_VALUE_SIZE

def hir_record_offset(record_id: int) -> int:
    return record_id * HIR_MODEL_RECORD_SIZE

def hir_value_offset(value_id: int) -> int:
    return value_id * HIR_MODEL_VALUE_SIZE

def hir_append_record(records: list[int], record: HirRecord) -> int:
    let record_id = hir_record_count(records)
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
    return record_id

def hir_append_value(values: list[int], value_kind: int, value: int):
    append(values, value_kind)
    append(values, value)

def hir_append_int(values: list[int], value: int):
    hir_append_value(values, HIR_VALUE_INT, value)

def hir_append_node_value(values: list[int], node_id: int):
    if node_id < 0:
        hir_append_value(values, HIR_VALUE_NONE, 0)
        return
    hir_append_value(values, HIR_VALUE_NODE, node_id)

def hir_append_block_value(values: list[int], block_id: int):
    if block_id < 0:
        hir_append_value(values, HIR_VALUE_NONE, 0)
        return
    hir_append_value(values, HIR_VALUE_BLOCK, block_id)

def hir_record_kind_from_ast(kind: int) -> int:
    if kind >= AST_PAT_WILDCARD and kind <= AST_PAT_STRUCT or kind == AST_M_CASE:
        return HIR_RECORD_PATTERN
    if kind >= AST_STMT_LET and kind <= AST_STMT_BREAK or kind == AST_ELIF or kind == AST_CASE:
        return HIR_RECORD_STATEMENT
    return HIR_RECORD_EXPRESSION

def hir_opcode_from_ast(kind: int) -> int:
    if kind == AST_STMT_LET or kind == AST_STMT_LET_TUPLE:
        return HIR_OP_LET
    if kind == AST_STMT_ASSIGN:
        return HIR_OP_ASSIGN
    if kind == AST_STMT_RETURN:
        return HIR_OP_RETURN
    if kind == AST_STMT_BREAK:
        return HIR_OP_BREAK
    if kind == AST_STMT_EXPR:
        return HIR_OP_SEQUENCE
    if kind == AST_STMT_IF or kind == AST_ELIF or kind == AST_EXPR_COND:
        return HIR_OP_IF
    if kind == AST_STMT_WHILE:
        return HIR_OP_WHILE
    if kind == AST_STMT_FOR:
        return HIR_OP_FOR
    if kind == AST_STMT_SWITCH or kind == AST_CASE or kind == AST_EXPR_MATCH or kind == AST_M_CASE:
        return HIR_OP_MATCH
    if kind >= AST_EXPR_INT and kind <= AST_EXPR_BOOL or kind >= AST_PAT_INT and kind <= AST_PAT_STRING:
        return HIR_OP_LITERAL
    if kind == AST_EXPR_VAR or kind == AST_PAT_VAR:
        return HIR_OP_LOCAL
    if kind == AST_EXPR_CALL or kind == AST_EXPR_METHOD_CALL:
        return HIR_OP_CALL
    if kind == AST_EXPR_PRINT:
        return HIR_OP_PRINT
    if kind == AST_EXPR_BINARY or kind == AST_EXPR_LOGICAL:
        return HIR_OP_BINARY
    if kind == AST_EXPR_UNARY:
        return HIR_OP_UNARY
    if kind == AST_EXPR_LAMBDA:
        return HIR_OP_LAMBDA
    if kind == AST_EXPR_LIST or kind == AST_EXPR_LIST_COMP or kind == AST_PAT_LIST or kind == AST_PAT_CONS:
        return HIR_OP_LIST
    if kind == AST_EXPR_DICT:
        return HIR_OP_DICT
    if kind == AST_EXPR_TUPLE:
        return HIR_OP_TUPLE
    if kind == AST_EXPR_INDEX:
        return HIR_OP_INDEX
    if kind == AST_EXPR_SLICE:
        return HIR_OP_SLICE
    if kind == AST_EXPR_ATTR:
        return HIR_OP_FIELD
    if kind == AST_EXPR_STRUCT or kind == AST_PAT_STRUCT:
        return HIR_OP_STRUCT
    if kind == AST_EXPR_ENUM or kind == AST_EXPR_BUILTIN_ENUM or kind == AST_PAT_ENUM or kind == AST_PAT_BUILTIN:
        return HIR_OP_ENUM
    return HIR_OP_NONE

def hir_type_from_ast(kind: int) -> int:
    if kind == AST_EXPR_INT or kind == AST_EXPR_RUNE or kind == AST_PAT_INT or kind == AST_PAT_RUNE:
        return HIR_TYPE_I32
    if kind == AST_EXPR_FLOAT or kind == AST_PAT_FLOAT:
        return HIR_TYPE_F64
    if kind == AST_EXPR_STRING or kind == AST_PAT_STRING:
        return HIR_TYPE_STR
    if kind == AST_EXPR_BOOL or kind == AST_PAT_BOOL:
        return HIR_TYPE_BOOL
    if kind == AST_EXPR_LIST or kind == AST_EXPR_LIST_COMP or kind == AST_PAT_LIST or kind == AST_PAT_CONS:
        return HIR_TYPE_LIST
    if kind == AST_EXPR_DICT:
        return HIR_TYPE_DICT
    if kind == AST_EXPR_TUPLE:
        return HIR_TYPE_TUPLE
    if kind == AST_EXPR_LAMBDA:
        return HIR_TYPE_CLOSURE
    if kind == AST_EXPR_STRUCT or kind == AST_PAT_STRUCT:
        return HIR_TYPE_STRUCT
    if kind == AST_EXPR_ENUM or kind == AST_EXPR_BUILTIN_ENUM or kind == AST_PAT_ENUM or kind == AST_PAT_BUILTIN:
        return HIR_TYPE_ENUM
    return HIR_TYPE_DYNAMIC

def hir_copy_values(values: list[int], source: list[int]):
    let index = 0
    while index < len(source):
        append(values, source[index])
        index = index + 1

def hir_append_ast_child(ast: list[int], node: int, records: list[int], values: list[int], payload: list[int], cache: list[int]):
    hir_append_node_value(payload, hir_lower_ast_node(ast, node, records, values, cache))

def hir_append_ast_block(ast: list[int], start: int, end: int, records: list[int], values: list[int], payload: list[int], cache: list[int]):
    hir_append_block_value(payload, hir_lower_ast_block(ast, start, end, records, values, cache))

def hir_lower_ast_block(ast: list[int], start: int, end: int, records: list[int], values: list[int], cache: list[int]) -> int:
    if start == 0 and end == 0:
        return -1
    if start <= 0 or end < start or end > len(ast):
        return -1
    let payload: list[int] = []
    let node = start
    while node < end:
        hir_append_node_value(payload, hir_lower_ast_node(ast, node, records, values, cache))
        let next_node = ast_stmt_next_node(ast, node)
        if next_node <= node:
            return -1
        node = next_node
    let payload_start = hir_value_count(values)
    hir_copy_values(values, payload)
    let block = HirRecord{record_kind: HIR_RECORD_BLOCK, opcode: HIR_OP_NONE, type_tag: HIR_TYPE_UNIT, source_start: 0, source_end: 0, payload_start: payload_start, payload_count: hir_value_count(payload), auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
    return hir_append_record(records, block)

def hir_lower_ast_node(ast: list[int], node: int, records: list[int], values: list[int], cache: list[int]) -> int:
    if node <= 0 or node >= len(ast):
        return -1
    if cache[node] >= 0:
        return cache[node]
    let kind = ast_node_kind(ast, node)
    let payload: list[int] = []
    if kind == AST_EXPR_CALL:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        let count = ast_node_arg(ast, node, 1)
        hir_append_int(payload, count)
        let index = 0
        while index < count:
            hir_append_ast_child(ast, ast_node_arg(ast, node, 3 + index), records, values, payload, cache)
            index = index + 1
    elif kind == AST_EXPR_METHOD_CALL:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_int(payload, ast_node_arg(ast, node, 2))
        let count = ast_node_arg(ast, node, 3)
        hir_append_int(payload, count)
        let index = 0
        while index < count:
            hir_append_ast_child(ast, ast_node_arg(ast, node, 5 + index), records, values, payload, cache)
            index = index + 1
    elif kind == AST_EXPR_ATTR:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_int(payload, ast_node_arg(ast, node, 2))
    elif kind == AST_EXPR_BINARY or kind == AST_EXPR_LOGICAL:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
    elif kind == AST_EXPR_UNARY:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
    elif kind == AST_EXPR_COND:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 3))
    elif kind == AST_EXPR_LIST or kind == AST_EXPR_TUPLE:
        let count = ast_node_arg(ast, node, 0)
        hir_append_int(payload, count)
        let index = 0
        while index < count:
            hir_append_ast_child(ast, ast_node_arg(ast, node, 1 + index), records, values, payload, cache)
            index = index + 1
    elif kind == AST_EXPR_DICT:
        let count = ast_node_arg(ast, node, 0)
        hir_append_int(payload, count)
        let index = 0
        while index < count:
            hir_append_ast_child(ast, ast_node_arg(ast, node, 1 + index), records, values, payload, cache)
            hir_append_ast_child(ast, ast_node_arg(ast, node, 21 + index), records, values, payload, cache)
            index = index + 1
    elif kind == AST_EXPR_STRUCT:
        let index = 0
        while index < 5:
            hir_append_int(payload, ast_node_arg(ast, node, index))
            index = index + 1
        let count = ast_node_arg(ast, node, 4)
        index = 0
        while index < count:
            hir_append_ast_child(ast, ast_node_arg(ast, node, 5 + index), records, values, payload, cache)
            index = index + 1
    elif kind == AST_EXPR_INDEX:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
    elif kind == AST_EXPR_SLICE:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
    elif kind == AST_EXPR_LAMBDA:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 3))
        hir_append_int(payload, ast_node_arg(ast, node, 4))
    elif kind == AST_EXPR_LIST_COMP:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_int(payload, ast_node_arg(ast, node, 2))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 3), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 4))
        hir_append_int(payload, ast_node_arg(ast, node, 5))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 6), records, values, payload, cache)
    elif kind == AST_EXPR_MATCH:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 3))
    elif kind == AST_EXPR_PRINT:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 1))
    elif kind == AST_STMT_LET:
        let index = 0
        while index < 4:
            hir_append_int(payload, ast_node_arg(ast, node, index))
            index = index + 1
        hir_append_ast_child(ast, ast_node_arg(ast, node, 4), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 5))
    elif kind == AST_STMT_LET_TUPLE:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
    elif kind == AST_STMT_ASSIGN:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_int(payload, ast_node_arg(ast, node, 2))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 3), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 4), records, values, payload, cache)
    elif kind == AST_STMT_IF:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 5), ast_node_arg(ast, node, 6), records, values, payload, cache)
    elif kind == AST_ELIF or kind == AST_STMT_WHILE:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2), records, values, payload, cache)
    elif kind == AST_STMT_FOR:
        hir_append_int(payload, ast_node_arg(ast, node, 0))
        hir_append_int(payload, ast_node_arg(ast, node, 1))
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4), records, values, payload, cache)
    elif kind == AST_STMT_SWITCH:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4), records, values, payload, cache)
    elif kind == AST_CASE:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_block(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2), records, values, payload, cache)
    elif kind == AST_STMT_RETURN:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_int(payload, ast_node_arg(ast, node, 1))
    elif kind == AST_STMT_EXPR:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
    elif kind == AST_M_CASE:
        hir_append_ast_child(ast, ast_node_arg(ast, node, 0), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 1), records, values, payload, cache)
        hir_append_ast_child(ast, ast_node_arg(ast, node, 2), records, values, payload, cache)
    else:
        let argument_count = ast_node_size(kind) - AST_HEADER_SIZE
        let index = 0
        while index < argument_count:
            hir_append_int(payload, ast_node_arg(ast, node, index))
            index = index + 1
    let payload_start = hir_value_count(values)
    hir_copy_values(values, payload)
    let record = HirRecord{record_kind: hir_record_kind_from_ast(kind), opcode: hir_opcode_from_ast(kind), type_tag: hir_type_from_ast(kind), source_start: ast_node_start(ast, node), source_end: ast_node_end(ast, node), payload_start: payload_start, payload_count: hir_value_count(payload), auxiliary_start: 0, auxiliary_count: 0, name_start: ast_node_start(ast, node), name_end: ast_node_end(ast, node)}
    let node_id = hir_append_record(records, record)
    cache[node] = node_id
    return node_id

def hir_validate_value(values: list[int], value_id: int, record_count: int) -> bool:
    let offset = hir_value_offset(value_id)
    let value_kind = values[offset]
    let value = values[offset + 1]
    if value_kind == HIR_VALUE_NONE or value_kind == HIR_VALUE_INT:
        return true
    if value_kind == HIR_VALUE_NODE or value_kind == HIR_VALUE_BLOCK:
        return value >= 0 and value < record_count
    return false

def hir_validate_record_shape(record_kind: int, opcode: int, payload_count: int) -> bool:
    if record_kind != HIR_RECORD_STATEMENT:
        return true
    if opcode == HIR_OP_LET:
        return payload_count == 3 or payload_count == 6
    if opcode == HIR_OP_ASSIGN:
        return payload_count == 5
    if opcode == HIR_OP_RETURN:
        return payload_count == 2
    if opcode == HIR_OP_BREAK:
        return payload_count == 0
    if opcode == HIR_OP_SEQUENCE:
        return payload_count == 1
    if opcode == HIR_OP_IF:
        return payload_count == 2 or payload_count == 4
    if opcode == HIR_OP_WHILE:
        return payload_count == 2
    if opcode == HIR_OP_FOR:
        return payload_count == 4
    if opcode == HIR_OP_MATCH:
        return payload_count == 2 or payload_count == 3
    return false

def hir_validate_model_program(program: HirProgram) -> bool:
    let records = program.records
    let values = program.values
    if len(records) % HIR_MODEL_RECORD_SIZE != 0 or len(values) % HIR_MODEL_VALUE_SIZE != 0:
        return false
    let record_count = hir_record_count(records)
    let value_count = hir_value_count(values)
    let record_id = 0
    while record_id < record_count:
        let offset = hir_record_offset(record_id)
        let kind = records[offset]
        let opcode = records[offset + 1]
        let type_tag = records[offset + 2]
        let source_start = records[offset + 3]
        let source_end = records[offset + 4]
        let payload_start = records[offset + 5]
        let payload_count = records[offset + 6]
        let auxiliary_start = records[offset + 7]
        let auxiliary_count = records[offset + 8]
        let name_start = records[offset + 9]
        let name_end = records[offset + 10]
        if kind < HIR_RECORD_MODULE or kind > HIR_RECORD_PATTERN:
            return false
        if opcode < HIR_OP_NONE or opcode > HIR_OP_MAX or type_tag < HIR_TYPE_UNKNOWN or type_tag > HIR_TYPE_MAX:
            return false
        if not hir_validate_record_shape(kind, opcode, payload_count):
            return false
        if source_start < 0 or source_end < source_start or name_start < 0 or name_end < name_start:
            return false
        if payload_start < 0 or payload_count < 0 or payload_start > value_count or payload_count > value_count - payload_start:
            return false
        if auxiliary_start < 0 or auxiliary_count < 0 or auxiliary_start > value_count or auxiliary_count > value_count - auxiliary_start:
            return false
        if kind == HIR_RECORD_FUNCTION:
            if payload_count != 1:
                return false
            let function_value_offset = hir_value_offset(payload_start)
            if values[function_value_offset] != HIR_VALUE_BLOCK:
                return false
        let value_id = payload_start
        while value_id < payload_start + payload_count:
            if not hir_validate_value(values, value_id, record_count):
                return false
            let value_offset = hir_value_offset(value_id)
            if kind == HIR_RECORD_BLOCK and values[value_offset] != HIR_VALUE_NODE:
                return false
            if values[value_offset] == HIR_VALUE_BLOCK:
                let target_offset = hir_record_offset(values[value_offset + 1])
                if records[target_offset] != HIR_RECORD_BLOCK:
                    return false
            value_id = value_id + 1
        value_id = auxiliary_start
        while value_id < auxiliary_start + auxiliary_count:
            if not hir_validate_value(values, value_id, record_count):
                return false
            let value_offset = hir_value_offset(value_id)
            if values[value_offset] == HIR_VALUE_BLOCK:
                let target_offset = hir_record_offset(values[value_offset + 1])
                if records[target_offset] != HIR_RECORD_BLOCK:
                    return false
            value_id = value_id + 1
        record_id = record_id + 1
    return true

def hir_semantic_error(reason: str) -> bool:
    __c_eprint_text("HIR semantic validation failed: ")
    __c_eprint_text(reason)
    __c_eprint_text("\n")
    return false

struct HirDiagnosticContext:
    source: str
    source_path: str
    file_paths: str
    file_starts: list[int]
    file_ends: list[int]
    function_name_starts: list[int]
    function_name_ends: list[int]

def hir_diag_file_index(context: HirDiagnosticContext, position: int) -> int:
    let file_index = 0
    while file_index < len(context.file_starts):
        if position >= context.file_starts[file_index] and position < context.file_ends[file_index]:
            return file_index
        file_index = file_index + 1
    return -1

def hir_diag_file_path(context: HirDiagnosticContext, file_index: int) -> str:
    if file_index < 0:
        return context.source_path
    let path_index = 0
    let path_start = 0
    let path_end = 0
    let source_length = text_length(context.file_paths)
    while path_end <= source_length:
        if path_end == source_length or context.file_paths[path_end] == '\n':
            if path_index == file_index:
                return context.file_paths[path_start:path_end]
            path_index = path_index + 1
            path_start = path_end + 1
        path_end = path_end + 1
    return context.source_path

def hir_diag_line_column(context: HirDiagnosticContext, file_index: int, position: int, line: list[int], column: list[int]):
    let file_start = 0
    if file_index >= 0:
        file_start = context.file_starts[file_index]
    let target = position
    if target < file_start:
        target = file_start
    if target > text_length(context.source):
        target = text_length(context.source)
    let cursor = file_start
    while cursor < target:
        if context.source[cursor] == '\n':
            line[0] = line[0] + 1
            column[0] = 1
        else:
            column[0] = column[0] + 1
        cursor = cursor + 1

def hir_diag_record_position(program: HirProgram, node_id: int) -> int:
    if node_id < 0 or node_id >= hir_record_count(program.records):
        return 0
    let offset = hir_record_offset(node_id)
    let position = program.records[offset + 3]
    if position > 0:
        return position
    let payload_start = program.records[offset + 5]
    let payload_count = program.records[offset + 6]
    let payload_index = 0
    while payload_index < payload_count:
        let value_offset = hir_value_offset(payload_start + payload_index)
        if program.values[value_offset] == HIR_VALUE_NODE:
            let child_position = hir_diag_record_position(program, program.values[value_offset + 1])
            if child_position > 0:
                return child_position
        payload_index = payload_index + 1
    return 0

def hir_diag_function_name(context: HirDiagnosticContext, function_index: int) -> str:
    if function_index < 0 or function_index >= len(context.function_name_starts) or function_index >= len(context.function_name_ends):
        return "<anonymous>"
    let name_start = context.function_name_starts[function_index]
    let name_end = context.function_name_ends[function_index]
    if name_start < 0 or name_end <= name_start or name_end > text_length(context.source):
        return "<anonymous>"
    return context.source[name_start:name_end]

def hir_diag_report(program: HirProgram, context: HirDiagnosticContext, function_index: int, node: int):
    let position = hir_diag_record_position(program, node)
    let file_index = hir_diag_file_index(context, position)
    let line: list[int] = [1]
    let column: list[int] = [1]
    hir_diag_line_column(context, file_index, position, line, column)
    __c_eprint_text("warning: ")
    __c_eprint_text(hir_diag_file_path(context, file_index))
    __c_eprint_text(":")
    __c_eprint_int(line[0])
    __c_eprint_text(":")
    __c_eprint_int(column[0])
    __c_eprint_text(": unreachable code in function ")
    __c_eprint_text(hir_diag_function_name(context, function_index))
    __c_eprint_text("\n")

def hir_diag_payload_block(program: HirProgram, node_id: int, payload_index: int) -> int:
    if node_id < 0 or node_id >= hir_record_count(program.records):
        return -1
    let offset = hir_record_offset(node_id)
    let payload_count = program.records[offset + 6]
    if payload_index < 0 or payload_index >= payload_count:
        return -1
    let value_offset = hir_value_offset(program.records[offset + 5] + payload_index)
    if program.values[value_offset] != HIR_VALUE_BLOCK:
        return -1
    return program.values[value_offset + 1]

def hir_diag_block_is_empty(program: HirProgram, block_id: int) -> bool:
    if block_id < 0 or block_id >= hir_record_count(program.records):
        return false
    let offset = hir_record_offset(block_id)
    return program.records[offset] == HIR_RECORD_BLOCK and program.records[offset + 6] == 0

def hir_diag_scan_block(program: HirProgram, block_id: int, context: HirDiagnosticContext, function_index: int, result: list[int]):
    if block_id < 0 or block_id >= hir_record_count(program.records):
        result[0] = 0
        return
    let block_offset = hir_record_offset(block_id)
    if program.records[block_offset] != HIR_RECORD_BLOCK:
        result[0] = 0
        return
    let payload_start = program.records[block_offset + 5]
    let payload_count = program.records[block_offset + 6]
    let payload_index = 0
    let is_terminated = false
    while payload_index < payload_count:
        let value_offset = hir_value_offset(payload_start + payload_index)
        let node = -1
        if program.values[value_offset] == HIR_VALUE_NODE:
            node = program.values[value_offset + 1]
        if is_terminated:
            if node >= 0:
                hir_diag_report(program, context, function_index, node)
        else:
            let statement_result: list[int] = [0]
            if node >= 0:
                hir_diag_scan_statement(program, node, context, function_index, statement_result)
            if statement_result[0] != 0:
                is_terminated = true
        payload_index = payload_index + 1
    result[0] = 0
    if is_terminated:
        result[0] = 1

def hir_diag_scan_branches(program: HirProgram, block_id: int, context: HirDiagnosticContext, function_index: int, result: list[int]):
    if block_id < 0 or block_id >= hir_record_count(program.records):
        result[0] = 0
        return
    let block_offset = hir_record_offset(block_id)
    if program.records[block_offset] != HIR_RECORD_BLOCK:
        result[0] = 0
        return
    let payload_start = program.records[block_offset + 5]
    let payload_count = program.records[block_offset + 6]
    let payload_index = 0
    let has_branch = false
    let all_terminated = true
    while payload_index < payload_count:
        let value_offset = hir_value_offset(payload_start + payload_index)
        if program.values[value_offset] != HIR_VALUE_NODE:
            result[0] = 0
            return
        let node = program.values[value_offset + 1]
        let node_offset = hir_record_offset(node)
        let opcode = program.records[node_offset + 1]
        if opcode != HIR_OP_IF and opcode != HIR_OP_MATCH:
            result[0] = 0
            return
        has_branch = true
        let case_result: list[int] = [0]
        hir_diag_scan_block(program, hir_diag_payload_block(program, node, 1), context, function_index, case_result)
        if case_result[0] == 0:
            all_terminated = false
        payload_index = payload_index + 1
    result[0] = 0
    if has_branch and all_terminated:
        result[0] = 1

def hir_diag_scan_if(program: HirProgram, node: int, context: HirDiagnosticContext, function_index: int, result: list[int]):
    let then_result: list[int] = [0]
    hir_diag_scan_block(program, hir_diag_payload_block(program, node, 1), context, function_index, then_result)
    let elif_result: list[int] = [0]
    let elif_block = hir_diag_payload_block(program, node, 2)
    hir_diag_scan_branches(program, elif_block, context, function_index, elif_result)
    if hir_diag_block_is_empty(program, elif_block):
        elif_result[0] = 1
    let else_block = hir_diag_payload_block(program, node, 3)
    let else_result: list[int] = [0]
    if else_block >= 0:
        hir_diag_scan_block(program, else_block, context, function_index, else_result)
    result[0] = 0
    if then_result[0] != 0 and elif_result[0] != 0 and else_block >= 0 and else_result[0] != 0:
        result[0] = 1

def hir_diag_scan_switch(program: HirProgram, node: int, context: HirDiagnosticContext, function_index: int, result: list[int]):
    let cases_result: list[int] = [0]
    hir_diag_scan_branches(program, hir_diag_payload_block(program, node, 1), context, function_index, cases_result)
    let default_block = hir_diag_payload_block(program, node, 2)
    let default_result: list[int] = [0]
    if default_block >= 0:
        hir_diag_scan_block(program, default_block, context, function_index, default_result)
    result[0] = 0
    if cases_result[0] != 0 and default_block >= 0 and default_result[0] != 0:
        result[0] = 1

def hir_diag_scan_statement(program: HirProgram, node: int, context: HirDiagnosticContext, function_index: int, result: list[int]):
    let offset = hir_record_offset(node)
    let record_kind = program.records[offset]
    let opcode = program.records[offset + 1]
    result[0] = 0
    if opcode == HIR_OP_RETURN or opcode == HIR_OP_BREAK or opcode == HIR_OP_CONTINUE:
        result[0] = 1
        return
    if record_kind == HIR_RECORD_STATEMENT and opcode == HIR_OP_IF and program.records[offset + 6] >= 4:
        hir_diag_scan_if(program, node, context, function_index, result)
        return
    if record_kind == HIR_RECORD_STATEMENT and opcode == HIR_OP_MATCH and program.records[offset + 6] >= 3:
        hir_diag_scan_switch(program, node, context, function_index, result)
        return

def hir_report_unreachable(program: HirProgram, context: HirDiagnosticContext):
    let function_index = 0
    let record_id = 0
    while record_id < hir_record_count(program.records):
        let offset = hir_record_offset(record_id)
        if program.records[offset] == HIR_RECORD_FUNCTION:
            let body_block = hir_diag_payload_block(program, record_id, 0)
            let result: list[int] = [0]
            hir_diag_scan_block(program, body_block, context, function_index, result)
            function_index = function_index + 1
        record_id = record_id + 1

def hir_debug_checkpoint(label: str, previous_time: int) -> int:
    if not __c_debug_on():
        return previous_time
    let current_time = __c_time_ms()
    __c_eprint_text("[timing] hir-")
    __c_eprint_text(label)
    __c_eprint_text(" ")
    __c_eprint_int(current_time - previous_time)
    __c_eprint_text("ms\n")
    return current_time

def hir_type_is_comparison(operator: int) -> bool:
    return operator == 18 or operator == 33 or operator == 31 or operator == 32 or operator == 29 or operator == 30

def hir_source_ranges_equal(source: str, left_start: int, left_end: int, right_start: int, right_end: int) -> bool:
    let source_size = text_length(source)
    if left_start < 0 or left_end < left_start or right_start < 0 or right_end < right_start:
        return false
    if left_end > source_size or right_end > source_size or left_end - left_start != right_end - right_start:
        return false
    return __c_range_equal(source, left_start, left_end, right_start, right_end)

def hir_node_type(program: HirProgram, value_kind: int, value: int) -> int:
    if value_kind != HIR_VALUE_NODE or value < 0 or value >= hir_record_count(program.records):
        return HIR_TYPE_UNKNOWN
    return program.records[hir_record_offset(value) + 2]

def hir_collect_function_index(program: HirProgram, source: str, offsets: list[int], hashes: list[int]):
    let source_size = text_length(source)
    let record_id = 0
    while record_id < hir_record_count(program.records):
        let offset = hir_record_offset(record_id)
        if program.records[offset] == HIR_RECORD_FUNCTION:
            let name_start = program.records[offset + 9]
            let name_end = program.records[offset + 10]
            let name_hash = 0
            if name_start >= 0 and name_end > name_start and name_end <= source_size:
                name_hash = __c_fnv_hash_range(source, name_start, name_end)
            append(offsets, offset)
            append(hashes, name_hash)
        record_id = record_id + 1

def hir_find_function_return_type(program: HirProgram, source: str, name_start: int, name_end: int, function_offsets: list[int], function_name_hashes: list[int]) -> int:
    if name_start < 0 or name_end <= name_start or name_end > text_length(source):
        return HIR_TYPE_UNKNOWN
    let name_hash = __c_fnv_hash_range(source, name_start, name_end)
    let function_index = 0
    while function_index < len(function_offsets):
        let offset = function_offsets[function_index]
        if function_name_hashes[function_index] == name_hash and hir_source_ranges_equal(source, name_start, name_end, program.records[offset + 9], program.records[offset + 10]):
            return hir_signature_int(program, offset, HIR_SIGNATURE_RETURN_TYPE)
        function_index = function_index + 1
    return HIR_TYPE_UNKNOWN

def hir_is_builtin_name(name: str) -> bool:
    return name == "print" or name == "eprint" or name == "append" or name == "len"

def hir_find_local_type(program: HirProgram, source: str, current_record_id: int, name_start: int, name_end: int) -> int:
    let record_id = current_record_id - 1
    while record_id >= 0:
        let offset = hir_record_offset(record_id)
        if program.records[offset] == HIR_RECORD_FUNCTION:
            let parameter_count = hir_signature_int(program, offset, HIR_SIGNATURE_PARAM_COUNT)
            let parameter_index = 0
            while parameter_index < parameter_count:
                let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
                if hir_source_ranges_equal(source, name_start, name_end, hir_signature_int(program, offset, metadata_index + 1), hir_signature_int(program, offset, metadata_index + 2)):
                    return hir_signature_int(program, offset, metadata_index)
                parameter_index = parameter_index + 1
            return HIR_TYPE_UNKNOWN
        if program.records[offset] == HIR_RECORD_STATEMENT and program.records[offset + 1] == HIR_OP_LET and program.records[offset + 6] > 1:
            let payload_start = program.records[offset + 5]
            let start_offset = hir_value_offset(payload_start)
            let end_offset = hir_value_offset(payload_start + 1)
            if hir_source_ranges_equal(source, name_start, name_end, program.values[start_offset + 1], program.values[end_offset + 1]):
                return program.records[offset + 2]
        record_id = record_id - 1
    return HIR_TYPE_UNKNOWN

def hir_infer_node_type(program: HirProgram, source: str, record_id: int, function_offsets: list[int], function_name_hashes: list[int]) -> int:
    let offset = hir_record_offset(record_id)
    let opcode = program.records[offset + 1]
    let payload_start = program.records[offset + 5]
    let payload_count = program.records[offset + 6]
    if opcode == HIR_OP_LOCAL:
        return hir_find_local_type(program, source, record_id, program.records[offset + 3], program.records[offset + 4])
    if opcode == HIR_OP_CALL and payload_count > 0:
        let callee_offset = hir_value_offset(payload_start)
        if program.values[callee_offset] == HIR_VALUE_NODE:
            let callee_id = program.values[callee_offset + 1]
            if callee_id >= 0 and callee_id < hir_record_count(program.records):
                let callee_record_offset = hir_record_offset(callee_id)
                if program.records[callee_record_offset + 1] == HIR_OP_LOCAL:
                    let name = source[program.records[callee_record_offset + 3]:program.records[callee_record_offset + 4]]
                    if hir_is_builtin_name(name):
                        if name == "len":
                            return HIR_TYPE_I32
                        return HIR_TYPE_UNIT
                    let function_type = hir_find_function_return_type(program, source, program.records[callee_record_offset + 3], program.records[callee_record_offset + 4], function_offsets, function_name_hashes)
                    if function_type != HIR_TYPE_UNKNOWN:
                        return function_type
        return HIR_TYPE_DYNAMIC
    if opcode == HIR_OP_BINARY and payload_count >= 3:
        let operator_offset = hir_value_offset(payload_start)
        let left_offset = hir_value_offset(payload_start + 1)
        let right_offset = hir_value_offset(payload_start + 2)
        let left_type = hir_node_type(program, program.values[left_offset], program.values[left_offset + 1])
        let right_type = hir_node_type(program, program.values[right_offset], program.values[right_offset + 1])
        let operator = program.values[operator_offset + 1]
        if hir_type_is_comparison(operator):
            return HIR_TYPE_BOOL
        if left_type == HIR_TYPE_F64 or right_type == HIR_TYPE_F64:
            return HIR_TYPE_F64
        if left_type == HIR_TYPE_STR and right_type == HIR_TYPE_STR and operator == 5:
            return HIR_TYPE_STR
        if left_type == HIR_TYPE_I32 and right_type == HIR_TYPE_I32:
            return HIR_TYPE_I32
        return HIR_TYPE_DYNAMIC
    if opcode == HIR_OP_UNARY and payload_count >= 2:
        let value_offset = hir_value_offset(payload_start + 1)
        return hir_node_type(program, program.values[value_offset], program.values[value_offset + 1])
    if opcode == HIR_OP_LET or opcode == HIR_OP_ASSIGN:
        let value_index = payload_start + payload_count - 1
        if opcode == HIR_OP_LET and payload_count > 4:
            value_index = payload_start + 4
        if payload_count > 0:
            let value_offset = hir_value_offset(value_index)
            return hir_node_type(program, program.values[value_offset], program.values[value_offset + 1])
    if opcode == HIR_OP_SEQUENCE and payload_count > 0:
        let value_offset = hir_value_offset(payload_start)
        return hir_node_type(program, program.values[value_offset], program.values[value_offset + 1])
    if opcode == HIR_OP_INDEX or opcode == HIR_OP_FIELD:
        return HIR_TYPE_DYNAMIC
    if opcode == HIR_OP_LIST:
        return HIR_TYPE_LIST
    if opcode == HIR_OP_DICT:
        return HIR_TYPE_DICT
    if opcode == HIR_OP_TUPLE:
        return HIR_TYPE_TUPLE
    if opcode == HIR_OP_LAMBDA:
        return HIR_TYPE_CLOSURE
    if opcode == HIR_OP_PRINT:
        return HIR_TYPE_UNIT
    return program.records[offset + 2]

def hir_infer_types(program: HirProgram, source: str):
    let function_offsets: list[int] = []
    let function_name_hashes: list[int] = []
    hir_collect_function_index(program, source, function_offsets, function_name_hashes)
    let record_id = 0
    while record_id < hir_record_count(program.records):
        let offset = hir_record_offset(record_id)
        let inferred_type = hir_infer_node_type(program, source, record_id, function_offsets, function_name_hashes)
        if inferred_type != HIR_TYPE_UNKNOWN and inferred_type != HIR_TYPE_DYNAMIC:
            program.records[offset + 2] = inferred_type
        record_id = record_id + 1

def hir_signature_int(program: HirProgram, record_offset: int, index: int) -> int:
    let value_id = program.records[record_offset + 7] + index
    let value_offset = hir_value_offset(value_id)
    return program.values[value_offset + 1]

def hir_parameter_type_name(source: str, name_start: int, name_end: int) -> str:
    let source_length = text_length(source)
    let type_start = name_end
    while type_start < source_length and source[type_start] != ':' and source[type_start] != ',' and source[type_start] != ')' and source[type_start] != '\n':
        type_start = type_start + 1
    if type_start >= source_length or source[type_start] != ':':
        return ""
    type_start = type_start + 1
    while type_start < source_length and source[type_start] == ' ':
        type_start = type_start + 1
    let type_end = type_start
    while type_end < source_length and source[type_end] != ',' and source[type_end] != ')' and source[type_end] != '\n':
        type_end = type_end + 1
    while type_end > type_start and source[type_end - 1] == ' ':
        type_end = type_end - 1
    return source[type_start:type_end]

def hir_is_method_name(source: str, name_start: int) -> bool:
    let line_start = name_start
    while line_start > 0 and source[line_start - 1] != '\n':
        line_start = line_start - 1
    return name_start > line_start and source[line_start] == ' '

def hir_function_signatures_equal(program: HirProgram, source: str, left_offset: int, right_offset: int) -> bool:
    let left_count = hir_signature_int(program, left_offset, HIR_SIGNATURE_PARAM_COUNT)
    let right_count = hir_signature_int(program, right_offset, HIR_SIGNATURE_PARAM_COUNT)
    if left_count != right_count:
        return false
    let parameter_index = 0
    while parameter_index < left_count:
        let left_metadata = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
        let right_metadata = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
        if hir_signature_int(program, left_offset, left_metadata) != hir_signature_int(program, right_offset, right_metadata):
            return false
        let left_name_start = hir_signature_int(program, left_offset, left_metadata + 1)
        let left_name_end = hir_signature_int(program, left_offset, left_metadata + 2)
        let right_name_start = hir_signature_int(program, right_offset, right_metadata + 1)
        let right_name_end = hir_signature_int(program, right_offset, right_metadata + 2)
        if hir_parameter_type_name(source, left_name_start, left_name_end) != hir_parameter_type_name(source, right_name_start, right_name_end):
            return false
        parameter_index = parameter_index + 1
    return true

def hir_validate_semantics(program: HirProgram, source: str) -> bool:
    let phase_time = 0
    if __c_debug_on():
        phase_time = __c_time_ms()
    if not hir_validate_model_program(program):
        return hir_semantic_error("invalid model")
    phase_time = hir_debug_checkpoint("model", phase_time)
    hir_infer_types(program, source)
    phase_time = hir_debug_checkpoint("infer", phase_time)
    let records = program.records
    let record_id = 0
    while record_id < hir_record_count(records):
        let offset = hir_record_offset(record_id)
        if records[offset] == HIR_RECORD_FUNCTION:
            let name_start = records[offset + 9]
            let name_end = records[offset + 10]
            if name_end <= name_start or name_end > text_length(source):
                return hir_semantic_error("function name range")
            if records[offset + 8] < HIR_SIGNATURE_PARAM_BASE:
                return hir_semantic_error("function signature")
            let parameter_count = hir_signature_int(program, offset, HIR_SIGNATURE_PARAM_COUNT)
            let expected_auxiliary_count = HIR_SIGNATURE_PARAM_BASE + parameter_count * HIR_SIGNATURE_PARAM_SIZE
            if parameter_count < 0 or records[offset + 8] != expected_auxiliary_count:
                return hir_semantic_error("function parameter metadata")
            let parameter_index = 0
            while parameter_index < parameter_count:
                let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
                let parameter_type = hir_signature_int(program, offset, metadata_index)
                let parameter_name_start = hir_signature_int(program, offset, metadata_index + 1)
                let parameter_name_end = hir_signature_int(program, offset, metadata_index + 2)
                if parameter_type < HIR_TYPE_UNKNOWN or parameter_type > HIR_TYPE_MAX:
                    return hir_semantic_error("parameter type")
                if parameter_name_start < 0 or parameter_name_end <= parameter_name_start or parameter_name_end > text_length(source):
                    return hir_semantic_error("parameter name range")
                let previous_index = 0
                while previous_index < parameter_index:
                    let previous_metadata = HIR_SIGNATURE_PARAM_BASE + previous_index * HIR_SIGNATURE_PARAM_SIZE
                    let previous_start = hir_signature_int(program, offset, previous_metadata + 1)
                    let previous_end = hir_signature_int(program, offset, previous_metadata + 2)
                    if source[parameter_name_start:parameter_name_end] == source[previous_start:previous_end]:
                        return hir_semantic_error("duplicate parameter")
                    previous_index = previous_index + 1
                parameter_index = parameter_index + 1
        record_id = record_id + 1
    phase_time = hir_debug_checkpoint("functions", phase_time)
    let function_offsets: list[int] = []
    let function_name_hashes: list[int] = []
    let function_record_id = 0
    while function_record_id < hir_record_count(records):
        let function_offset = hir_record_offset(function_record_id)
        if records[function_offset] == HIR_RECORD_FUNCTION and not hir_is_method_name(source, records[function_offset + 9]):
            append(function_offsets, function_offset)
            append(function_name_hashes, __c_fnv_hash_range(source, records[function_offset + 9], records[function_offset + 10]))
        function_record_id = function_record_id + 1
    let left_index = 0
    while left_index < len(function_offsets):
        let right_index = 0
        while right_index < left_index:
            let left_offset = function_offsets[left_index]
            let right_offset = function_offsets[right_index]
            if function_name_hashes[left_index] == function_name_hashes[right_index] and hir_source_ranges_equal(source, records[left_offset + 9], records[left_offset + 10], records[right_offset + 9], records[right_offset + 10]) and hir_function_signatures_equal(program, source, left_offset, right_offset):
                return hir_semantic_error("duplicate function")
            right_index = right_index + 1
        left_index = left_index + 1
    hir_debug_checkpoint("duplicates", phase_time)
    return true

def hir_type_from_collected_type(value_type: int) -> int:
    if value_type == 1:
        return HIR_TYPE_I32
    if value_type == 2:
        return HIR_TYPE_STR
    if value_type == 3 or value_type == 40:
        return HIR_TYPE_LIST
    if value_type == 4:
        return HIR_TYPE_BOOL
    if value_type == 10:
        return HIR_TYPE_F64
    if value_type == 11:
        return HIR_TYPE_BYTES
    if value_type == 12:
        return HIR_TYPE_INTERFACE
    if value_type >= 100:
        return HIR_TYPE_FUNCTION
    return HIR_TYPE_DYNAMIC

def hir_append_signature_value(values: list[int], value: int):
    hir_append_value(values, HIR_VALUE_INT, value)

def hir_model_build_program(ast: list[int], function_body_starts: list[int], function_body_ends: list[int], global_nodes: list[int], function_name_starts: list[int], function_name_ends: list[int], function_param_offsets: list[int], function_param_counts: list[int], parameter_starts: list[int], parameter_ends: list[int], parameter_types: list[int], function_return_types: list[int], parameter_default_indexes: list[int]) -> HirProgram:
    let records = []
    let values = []
    let cache: list[int] = []
    let cache_index = 0
    while cache_index < len(ast):
        append(cache, -1)
        cache_index = cache_index + 1
    let module = HirRecord{record_kind: HIR_RECORD_MODULE, opcode: HIR_OP_NONE, type_tag: HIR_TYPE_UNKNOWN, source_start: 0, source_end: 0, payload_start: 0, payload_count: 0, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
    hir_append_record(records, module)
    let function_index = 0
    while function_index < len(function_body_starts):
        let function_name_start = 0
        let function_name_end = 0
        if function_index < len(function_name_starts) and function_index < len(function_name_ends):
            function_name_start = function_name_starts[function_index]
            function_name_end = function_name_ends[function_index]
        let function_record = HirRecord{record_kind: HIR_RECORD_FUNCTION, opcode: HIR_OP_NONE, type_tag: HIR_TYPE_FUNCTION, source_start: function_name_start, source_end: function_name_end, payload_start: 0, payload_count: 0, auxiliary_start: 0, auxiliary_count: 0, name_start: function_name_start, name_end: function_name_end}
        let function_record_id = hir_append_record(records, function_record)
        let body_id = hir_lower_ast_block(ast, function_body_starts[function_index], function_body_ends[function_index], records, values, cache)
        let payload_start = hir_value_count(values)
        hir_append_block_value(values, body_id)
        let auxiliary_start = hir_value_count(values)
        let parameter_offset = function_param_offsets[function_index]
        let parameter_count = function_param_counts[function_index]
        hir_append_signature_value(values, parameter_count)
        hir_append_signature_value(values, hir_type_from_collected_type(function_return_types[function_index]))
        let parameter_index = 0
        while parameter_index < parameter_count:
            let parameter_value_index = parameter_offset + parameter_index
            hir_append_signature_value(values, hir_type_from_collected_type(parameter_types[parameter_value_index]))
            hir_append_signature_value(values, parameter_starts[parameter_value_index])
            hir_append_signature_value(values, parameter_ends[parameter_value_index])
            hir_append_signature_value(values, parameter_default_indexes[parameter_value_index])
            parameter_index = parameter_index + 1
        let auxiliary_count = hir_value_count(values) - auxiliary_start
        let function_offset = hir_record_offset(function_record_id)
        records[function_offset + 5] = payload_start
        records[function_offset + 6] = 1
        records[function_offset + 7] = auxiliary_start
        records[function_offset + 8] = auxiliary_count
        function_index = function_index + 1
    let global_index = 0
    while global_index < len(global_nodes):
        let global_id = hir_lower_ast_node(ast, global_nodes[global_index], records, values, cache)
        let payload_start = hir_value_count(values)
        hir_append_node_value(values, global_id)
        let global_record = HirRecord{record_kind: HIR_RECORD_GLOBAL, opcode: HIR_OP_NONE, type_tag: HIR_TYPE_UNKNOWN, source_start: 0, source_end: 0, payload_start: payload_start, payload_count: 1, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
        hir_append_record(records, global_record)
        global_index = global_index + 1
    return HirProgram{records: records, values: values}

def hir_empty_program() -> HirProgram:
    return HirProgram{records: [], values: []}

def hir_model_dump_program(program: HirProgram, output: TextBuffer) -> bool:
    if not hir_validate_model_program(program):
        return false
    append(output, "HIR version=")
    append(output, HIR_MODEL_VERSION)
    append(output, " records=")
    append(output, hir_record_count(program.records))
    append(output, " values=")
    append(output, hir_value_count(program.values))
    append(output, "\n")
    let record_id = 0
    while record_id < hir_record_count(program.records):
        let offset = hir_record_offset(record_id)
        append(output, "record id=")
        append(output, record_id)
        append(output, " kind=")
        append(output, program.records[offset])
        append(output, " opcode=")
        append(output, program.records[offset + 1])
        append(output, " type=")
        append(output, program.records[offset + 2])
        append(output, " range=")
        append(output, program.records[offset + 3])
        append(output, "..")
        append(output, program.records[offset + 4])
        append(output, " payload=")
        append(output, program.records[offset + 6])
        append(output, " [")
        let payload_index = 0
        while payload_index < program.records[offset + 6]:
            if payload_index > 0:
                append(output, ",")
            let value_offset = hir_value_offset(program.records[offset + 5] + payload_index)
            append(output, program.values[value_offset])
            append(output, ":")
            append(output, program.values[value_offset + 1])
            payload_index = payload_index + 1
        append(output, "]")
        append(output, "\n")
        record_id = record_id + 1
    return true
