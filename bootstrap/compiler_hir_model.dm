from text_buffer import TextBuffer

const HIR_MODEL_VERSION: int = 2
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
const HIR_TYPE_MAX: int = HIR_TYPE_FUNCTION

const HIR_VALUE_NONE: int = 0
const HIR_VALUE_INT: int = 1
const HIR_VALUE_NODE: int = 2
const HIR_VALUE_BLOCK: int = 3

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
    return HIR_TYPE_UNKNOWN

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
        let next_node = node + ast_node_size(ast_node_kind(ast, node))
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
        if source_start < 0 or source_end < source_start or name_start < 0 or name_end < name_start:
            return false
        if payload_start < 0 or payload_count < 0 or payload_start > value_count or payload_count > value_count - payload_start:
            return false
        if auxiliary_start < 0 or auxiliary_count < 0 or auxiliary_start > value_count or auxiliary_count > value_count - auxiliary_start:
            return false
        let value_id = payload_start
        while value_id < payload_start + payload_count:
            if not hir_validate_value(values, value_id, record_count):
                return false
            let value_offset = hir_value_offset(value_id)
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

def hir_model_build_program(ast: list[int], function_starts: list[int], function_ends: list[int], global_nodes: list[int]) -> HirProgram:
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
    while function_index < len(function_starts):
        let body_id = hir_lower_ast_block(ast, function_starts[function_index], function_ends[function_index], records, values, cache)
        let payload_start = hir_value_count(values)
        hir_append_block_value(values, body_id)
        let function_record = HirRecord{record_kind: HIR_RECORD_FUNCTION, opcode: HIR_OP_NONE, type_tag: HIR_TYPE_FUNCTION, source_start: 0, source_end: 0, payload_start: payload_start, payload_count: 1, auxiliary_start: 0, auxiliary_count: 0, name_start: 0, name_end: 0}
        hir_append_record(records, function_record)
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
        append(output, " payload=")
        append(output, program.records[offset + 6])
        append(output, "\n")
        record_id = record_id + 1
    return true
