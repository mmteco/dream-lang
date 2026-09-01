from utf8 import ord
from hash_index import (
    HashIndex,
    hash_index_build,
    hash_index_build_pairs,
    hir_file_visible
)
from hir_model import (
    HirProgram,
    hir_record_count,
    hir_record_offset,
    hir_value_offset,
    hir_int_list_get,
    HIR_OP_ASSIGN,
    HIR_OP_BINARY,
    HIR_OP_BREAK,
    HIR_OP_CALL,
    HIR_OP_CONTINUE,
    HIR_OP_DICT,
    HIR_OP_ENUM,
    HIR_OP_FIELD,
    HIR_OP_FOR,
    HIR_OP_IF,
    HIR_OP_INDEX,
    HIR_OP_LAMBDA,
    HIR_OP_LET,
    HIR_OP_LIST,
    HIR_OP_LITERAL,
    HIR_OP_LOCAL,
    HIR_OP_MATCH,
    HIR_OP_NONE,
    HIR_OP_RETURN,
    HIR_OP_SEQUENCE,
    HIR_OP_SLICE,
    HIR_OP_STRUCT,
    HIR_OP_TUPLE,
    HIR_OP_UNARY,
    HIR_OP_WHILE,
    HIR_RECORD_BLOCK,
    HIR_RECORD_EXPRESSION,
    HIR_RECORD_FUNCTION,
    HIR_RECORD_GLOBAL,
    HIR_RECORD_MODULE,
    HIR_RECORD_PATTERN,
    HIR_SIGNATURE_PARAM_BASE,
    HIR_SIGNATURE_PARAM_COUNT,
    HIR_SIGNATURE_PARAM_SIZE,
    HIR_SIGNATURE_RETURN_TYPE,
    HIR_TYPE_BYTES,
    HIR_TYPE_CLOSURE,
    HIR_TYPE_DICT,
    HIR_TYPE_DYNAMIC,
    HIR_TYPE_ENUM,
    HIR_TYPE_FUNCTION,
    HIR_TYPE_INTERFACE,
    HIR_TYPE_LIST,
    HIR_TYPE_LIST_INT,
    HIR_TYPE_STR,
    HIR_TYPE_STRUCT,
    HIR_TYPE_TUPLE,
    HIR_TYPE_UNION,
    HIR_VALUE_BLOCK,
    HIR_VALUE_INT,
    HIR_VALUE_NODE,
    HIR_VALUE_NONE
)
from operator import (
    IR_OPERATOR_ADD,
    IR_OPERATOR_EQ,
    IR_OPERATOR_NE,
    IR_OPERATOR_LT,
    IR_OPERATOR_GT,
    IR_OPERATOR_LE,
    IR_OPERATOR_GE,
    IR_OPERATOR_IN,
    IR_OPERATOR_AND,
    IR_OPERATOR_OR
)
from lex import (
    source_ranges_equal,
    find_type_declaration_index,
    find_struct_declaration_index,
    is_identifier_start,
    is_identifier_continue,
    STRUCT_FIELD_INT,
    STRUCT_FIELD_BOOL,
    STRUCT_FIELD_FLOAT,
    STRUCT_FIELD_STR,
    STRUCT_FIELD_LIST_INT,
    STRUCT_FIELD_LIST_STR,
    STRUCT_FIELD_DICT,
    STRUCT_FIELD_DECLARATIONS,
    STRUCT_FIELD_NAME_STARTS,
    STRUCT_FIELD_NAME_ENDS,
    STRUCT_FIELD_SLOTS,
    STRUCT_FIELD_KINDS,
    STRUCT_FIELD_TYPE_DECLS,
    STRUCT_FIELD_VALUE_TYPE_DECLS,
    STRUCT_DECLARATION_STARTS,
    STRUCT_DECLARATION_ENDS,
    FUNC_FILES,
    CONSTANT_FILES,
    GLOBAL_FILES,
    module_candidate_files,
    module_env_file_at,
    TokenStream,
    lex,
    parse_integer,
    token_kind,
    token_start,
    token_end,
    line_indent,
    TOKEN_EOF,
    TOKEN_NEWLINE,
    TOKEN_IDENTIFIER,
    TOKEN_INTEGER,
    TOKEN_RUNE,
    TOKEN_STRING,
    TOKEN_FLOAT,
    TOKEN_TRUE,
    TOKEN_FALSE,
    TOKEN_MINUS,
    TOKEN_COLON,
    TOKEN_COMMA,
    TOKEN_CONS,
    TOKEN_OPEN_BRACKET,
    TOKEN_CLOSE_BRACKET,
    TOKEN_OPEN_PAREN,
    TOKEN_CLOSE_PAREN,
    TOKEN_OPEN_BRACE,
    TOKEN_CLOSE_BRACE,
    TOKEN_DOT,
    ASSIGNMENT_FORM_LOCAL,
    ASSIGNMENT_FORM_INDEX,
    ASSIGNMENT_FORM_FIELD,
    ASSIGNMENT_FORM_INDEX_TARGET
)
from external import (
    external_id_from_name,
    external_return_type,
    EXTERNAL_RETURN_UNIT,
    EXTERNAL_RETURN_INT,
    EXTERNAL_RETURN_BOOL,
    EXTERNAL_RETURN_FLOAT,
    EXTERNAL_RETURN_POINTER,
    EXTERNAL_RETURN_STRING,
    EXTERNAL_ID_LEN,
    EXTERNAL_ID_DICT_CREATE_STR_STR,
    EXTERNAL_ID_DICT_ITEMS_TUPLES,
    EXTERNAL_ID_STR_TO_BYTES,
    EXTERNAL_ID_STRING_FIND,
    EXTERNAL_ID_STRING_UPPER,
    EXTERNAL_ID_STRING_LOWER,
    EXTERNAL_ID_STRING_STRIP,
    EXTERNAL_ID_STRING_SPLIT,
    EXTERNAL_ID_STRING_STARTS_WITH,
    EXTERNAL_ID_STRING_ENDS_WITH,
    EXTERNAL_ID_STRING_REPLACE,
    EXTERNAL_ID_ENUM_CREATE_SIMPLE,
    EXTERNAL_ID_ENUM_CREATE_INT,
    EXTERNAL_ID_ENUM_CREATE_FLOAT,
    EXTERNAL_ID_ENUM_CREATE_STRING,
    EXTERNAL_ID_ENUM_CREATE_BOOL,
    EXTERNAL_ID_ENUM_GET_TAG,
    EXTERNAL_ID_ENUM_GET_INT,
    EXTERNAL_ID_ENUM_GET_FLOAT,
    EXTERNAL_ID_ENUM_GET_STRING,
    EXTERNAL_ID_ENUM_GET_BOOL,
    EXTERNAL_ID_INTERFACE_BOX,
    EXTERNAL_ID_INTERFACE_OBJ,
    EXTERNAL_ID_INTERFACE_TAG,
    EXTERNAL_ID_ENUM_CREATE_TUPLE_PTR,
    EXTERNAL_ID_ENUM_GET_DATA
)
from buffer import Buffer

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
const MIR_FUNCTION_ENTRY: int = 1
const MIR_EXTERNAL_BASE: int = 1000000

const MIR_TYPE_UNKNOWN: int = 0
const MIR_TYPE_UNIT: int = 1
const MIR_TYPE_BOOL: int = 2
const MIR_TYPE_I32: int = 3
const MIR_TYPE_F64: int = 4
const MIR_TYPE_STR: int = 5
const MIR_TYPE_BYTES: int = 6
const MIR_TYPE_PTR: int = 7
const MIR_TYPE_LIST: int = 8
const MIR_TYPE_LIST_PTR: int = 9
const MIR_TYPE_DICT: int = 10
const MIR_TYPE_TUPLE: int = 11
const MIR_TYPE_STRUCT: int = 12
const MIR_TYPE_ENUM: int = 13
const MIR_TYPE_INTERFACE: int = 14
const MIR_TYPE_UNION: int = 15
const MIR_TYPE_FUNCTION: int = 16
const MIR_TYPE_CLOSURE: int = 17
const MIR_TYPE_DYNAMIC: int = 18
const MIR_TYPE_MAX: int = MIR_TYPE_DYNAMIC

const MIR_IMPL_ACCEPTS_STR: int = 0
const MIR_IMPL_ACCEPTS_INT: int = 1
const MIR_IMPL_ACCEPTS_BYTE: int = 2
const MIR_IMPL_ACCEPTS_BOOL: int = 3
const MIR_IMPL_ACCEPTS_FLOAT: int = 4
const MIR_IMPL_ACCEPTS_BYTES: int = 5

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
const MIR_OP_GLOBAL_LOAD: int = 21
const MIR_OP_GLOBAL_STORE: int = 22
const MIR_OP_DISPLAY: int = 23
const MIR_OP_MAX: int = MIR_OP_DISPLAY
const MIR_RUNTIME_NONE: int = 0
const MIR_RUNTIME_PRINT: int = 1
const MIR_RUNTIME_DISPLAY: int = 2
const MIR_RUNTIME_LIST_NEW: int = 3
const MIR_RUNTIME_LIST_GET: int = 4
const MIR_RUNTIME_LIST_SET: int = 5
const MIR_RUNTIME_LIST_SET_DYNAMIC: int = 6
const MIR_RUNTIME_LIST_APPEND: int = 7
const MIR_RUNTIME_LIST_SLICE: int = 8
const MIR_RUNTIME_DICT_NEW: int = 9
const MIR_RUNTIME_DICT_GET: int = 10
const MIR_RUNTIME_DICT_SET: int = 11
const MIR_RUNTIME_TUPLE_NEW: int = 12
const MIR_RUNTIME_TUPLE_GET: int = 13
const MIR_RUNTIME_STRUCT_NEW: int = 14
const MIR_RUNTIME_ENUM_NEW: int = 15
const MIR_RUNTIME_INDEX_CHECK: int = 16
const MIR_RUNTIME_FUNCTION_CALL: int = 17

const MIR_TERM_JUMP: int = 1
const MIR_TERM_BRANCH: int = 2
const MIR_TERM_SWITCH: int = 3
const MIR_TERM_RETURN: int = 4
const MIR_TERM_UNREACHABLE: int = 5
const MIR_TERM_MAX: int = MIR_TERM_UNREACHABLE

struct MirRecord:
    record_kind: int
    func_index: int
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

struct MirFunctionInfo:
    starts: list[int]
    ends: list[int]
    returns: list[int]
    capture_name_starts: list[int]
    capture_name_ends: list[int]
    capture_counts: list[int]
    capture_types: list[int]

struct MirConstantPool:
    starts: list[int]
    ends: list[int]
    values: list[int]
    types: list[int]
    literal_starts: list[int]
    literal_ends: list[int]

struct MirLowerState:
    records: list[int]
    values: list[int]
    func_index: list[int]
    current_block: list[int]
    next_block: list[int]
    next_value: list[int]
    is_terminated: list[int]
    hir_value_map: list[int]
    symbol_starts: list[int]
    symbol_ends: list[int]
    symbol_values: list[int]
    symbol_count: list[int]
    functions: MirFunctionInfo
    constants: MirConstantPool
    source: str
    loop_break_blocks: list[int]
    loop_continue_blocks: list[int]
    loop_symbol_counts: list[int]
    loop_count: list[int]
    value_types: list[int]
    parameter_offsets: list[int]
    parameter_struct_decls: list[int]
    parameter_default_indexes: list[int]
    parameter_annotation_starts: list[int]
    parameter_annotation_ends: list[int]
    func_return_struct_decls: list[int]
    func_param_counts: list[int]
    func_param_types: list[int]
    func_receiver_flags: list[int]
    value_enum_flags: list[int]
    value_struct_declarations: list[int]
    impl_func_indexes: list[int]
    impl_func_decls: list[int]
    impl_func_interface_types: list[int]
    func_ref_values: list[int]
    func_ref_targets: list[int]
    named_ref_name_starts: list[int]
    named_ref_name_ends: list[int]
    named_ref_targets: list[int]
    named_ref_return_types: list[int]
    pending_lambda_nodes: list[int]
    pending_lambda_fn_indexes: list[int]
    enum_variant_name_starts: list[int]
    enum_variant_name_ends: list[int]
    enum_variant_tags: list[int]
    enum_variant_payload_kinds: list[int]
    interface_name_starts: list[int]
    interface_name_ends: list[int]
    interface_func_indexes: list[int]
    impl_decl_indexes: list[int]
    impl_interface_name_starts: list[int]
    impl_interface_name_ends: list[int]
    # 全局变量表：名字区间 + 初始化表达式节点 + 类型 + 每函数缓存值
    global_names: list[int]
    global_initializers: list[int]
    global_types: list[int]
    global_value_cache: list[int]
    # 词法 token 缓存（按需延迟解析 1 次，全生命周期复用）
    lex_kinds: list[int]
    lex_starts: list[int]
    lex_ends: list[int]
    # 当前函数内部 value -> record_offset 快速查找表
    value_records: list[int]
    # 当前函数 record_offset（用于返回类型快速回填）
    current_func_record_offset: list[int]
    # 当前函数是否调用了 dict_items_tuples
    func_has_dict_items: list[int]
    # 扁平符号快速哈希索引（函数、常量、全局变量）
    func_index_map: HashIndex
    constant_index_map: HashIndex
    global_index_map: HashIndex
    # 结构体 declaration_index -> __init__ 函数索引查表
    struct_init_func_map: list[int]

def mir_record_count(records: list[int]) -> int:
    return len(records) / MIR_RECORD_SIZE

def mir_value_count(values: list[int]) -> int:
    return len(values) / MIR_VALUE_SIZE

def mir_int_list_get(values: list[int], index: int) -> int:
    if index < 0 or index >= len(values):
        return 0
    return values[index]

def mir_int_list_set(values: list[int], index: int, value: int):
    values[index] = value

def mir_record_offset(record_id: int) -> int:
    return record_id * MIR_RECORD_SIZE

def mir_value_offset(value_id: int) -> int:
    return value_id * MIR_VALUE_SIZE

def mir_append_record(records: list[int], record: MirRecord):
    append(records, record.record_kind)
    append(records, record.func_index)
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

def mir_state_ensure_tokens(state: MirLowerState):
    if len(state.lex_kinds) > 0:
        return
    lex(TokenStream{
        src: state.source,
        kinds: state.lex_kinds,
        starts: state.lex_starts,
        ends: state.lex_ends
    })

def mir_type_from_hir(type_tag: int) -> int:
    if type_tag == HIR_TYPE_LIST:
        return MIR_TYPE_LIST_PTR
    if type_tag == HIR_TYPE_LIST_INT:
        return MIR_TYPE_LIST
    if type_tag == HIR_TYPE_DICT:
        return MIR_TYPE_DICT
    if type_tag == HIR_TYPE_TUPLE:
        return MIR_TYPE_TUPLE
    if type_tag == HIR_TYPE_STRUCT:
        return MIR_TYPE_STRUCT
    if type_tag == HIR_TYPE_ENUM:
        return MIR_TYPE_ENUM
    if type_tag == HIR_TYPE_INTERFACE:
        return MIR_TYPE_INTERFACE
    if type_tag == HIR_TYPE_UNION:
        return MIR_TYPE_UNION
    if type_tag == HIR_TYPE_CLOSURE:
        return MIR_TYPE_CLOSURE
    if type_tag == HIR_TYPE_FUNCTION:
        return MIR_TYPE_FUNCTION
    if type_tag == HIR_TYPE_DYNAMIC:
        return MIR_TYPE_DYNAMIC
    return type_tag

def mir_type_from_constant(type_tag: int) -> int:
    if type_tag == 1:
        return MIR_TYPE_I32
    if type_tag == 2:
        return MIR_TYPE_STR
    return MIR_TYPE_DYNAMIC

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
    if opcode == HIR_OP_SEQUENCE:
        return MIR_OP_SEQUENCE
    if opcode in [HIR_OP_LET, HIR_OP_ASSIGN]:
        return MIR_OP_ASSIGN
    return MIR_OP_CAST

def mir_state_reserve_block(state: MirLowerState) -> int:
    let block_index = mir_int_list_get(state.next_block, 0)
    mir_int_list_set(state.next_block, 0, block_index + 1)
    return block_index

def mir_state_emit_block(state: MirLowerState, block_index: int):
    let block = MirRecord{
        record_kind: MIR_RECORD_BLOCK,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: block_index,
        opcode: 0,
        type_tag: MIR_TYPE_UNIT,
        result_value: -1,
        operand_start: 0,
        operand_count: 0,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, block)

def mir_state_select_block(state: MirLowerState, block_index: int):
    mir_int_list_set(state.current_block, 0, block_index)
    mir_int_list_set(state.is_terminated, 0, 0)
    # 每 block 清空全局缓存：GLOBAL_LOAD 的 SSA 值不能跨 block 使用
    let global_cache_index = 0
    while global_cache_index < len(state.global_value_cache):
        mir_int_list_set(state.global_value_cache, global_cache_index, -1)
        global_cache_index = global_cache_index + 1

def mir_state_append_instruction(state: MirLowerState, opcode: int, type_tag: int, result_value: int,
    operand_start: int, operand_count: int):
    let instruction = MirRecord{
        record_kind: MIR_RECORD_INSTRUCTION,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: mir_int_list_get(state.current_block, 0),
        opcode: opcode,
        type_tag: type_tag,
        result_value: result_value,
        operand_start: operand_start,
        operand_count: operand_count,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, instruction)
    mir_state_set_value_type(state, result_value, type_tag)
    if result_value >= 0:
        let record_offset = len(state.records) - MIR_RECORD_SIZE
        while len(state.value_records) <= result_value:
            append(state.value_records, -1)
        mir_int_list_set(state.value_records, result_value, record_offset)
    if opcode == MIR_OP_CALL and operand_count > 0:
        let op_offset = mir_value_offset(operand_start)
        if state.values[op_offset] == MIR_OPERAND_SYMBOL and state.values[op_offset + 1] == MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_ITEMS_TUPLES:
            mir_int_list_set(state.func_has_dict_items, 0, 1)

def mir_state_append_instruction_source(state: MirLowerState, opcode: int, type_tag: int, result_value: int,
    operand_start: int, operand_count: int, source_start: int, source_end: int):
    let instruction = MirRecord{
        record_kind: MIR_RECORD_INSTRUCTION,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: mir_int_list_get(state.current_block, 0),
        opcode: opcode,
        type_tag: type_tag,
        result_value: result_value,
        operand_start: operand_start,
        operand_count: operand_count,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: source_start,
        source_end: source_end
    }
    mir_append_record(state.records, instruction)
    mir_state_set_value_type(state, result_value, type_tag)
    if result_value >= 0:
        let record_offset = len(state.records) - MIR_RECORD_SIZE
        while len(state.value_records) <= result_value:
            append(state.value_records, -1)
        mir_int_list_set(state.value_records, result_value, record_offset)
    if opcode == MIR_OP_CALL and operand_count > 0:
        let op_offset = mir_value_offset(operand_start)
        if state.values[op_offset] == MIR_OPERAND_SYMBOL and state.values[op_offset + 1] == MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_ITEMS_TUPLES:
            mir_int_list_set(state.func_has_dict_items, 0, 1)

def mir_state_append_runtime(state: MirLowerState, runtime_id: int, operand_start: int, operand_count: int):
    let instruction = MirRecord{
        record_kind: MIR_RECORD_INSTRUCTION,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: mir_int_list_get(state.current_block, 0),
        opcode: MIR_OP_RUNTIME,
        type_tag: MIR_TYPE_UNIT,
        result_value: -1,
        operand_start: operand_start,
        operand_count: operand_count,
        auxiliary_start: runtime_id,
        auxiliary_count: 1,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, instruction)

def mir_state_append_runtime_result(state: MirLowerState, runtime_id: int, result_type: int, result_value: int,
    operand_start: int, operand_count: int):
    let instruction = MirRecord{
        record_kind: MIR_RECORD_INSTRUCTION,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: mir_int_list_get(state.current_block, 0),
        opcode: MIR_OP_RUNTIME,
        type_tag: result_type,
        result_value: result_value,
        operand_start: operand_start,
        operand_count: operand_count,
        auxiliary_start: runtime_id,
        auxiliary_count: 1,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, instruction)
    mir_state_set_value_type(state, result_value, result_type)
    if result_value >= 0:
        let record_offset = len(state.records) - MIR_RECORD_SIZE
        while len(state.value_records) <= result_value:
            append(state.value_records, -1)
        mir_int_list_set(state.value_records, result_value, record_offset)

def mir_state_append_terminator(state: MirLowerState, opcode: int, operand_start: int, operand_count: int):
    let terminator = MirRecord{
        record_kind: MIR_RECORD_TERMINATOR,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: mir_int_list_get(state.current_block, 0),
        opcode: opcode,
        type_tag: MIR_TYPE_UNIT,
        result_value: -1,
        operand_start: operand_start,
        operand_count: operand_count,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, terminator)
    mir_int_list_set(state.is_terminated, 0, 1)

def mir_find_symbol_value(state: MirLowerState, source_start: int, source_end: int) -> int:
    let symbol_index = mir_int_list_get(state.symbol_count, 0) - 1
    while symbol_index >= 0:
        let symbol_start = mir_int_list_get(state.symbol_starts, symbol_index)
        let symbol_end = mir_int_list_get(state.symbol_ends, symbol_index)
        if state.source[source_start:source_end] == state.source[symbol_start:symbol_end]:
            return mir_int_list_get(state.symbol_values, symbol_index)
        symbol_index = symbol_index - 1
    return -1

def mir_find_constant_index(state: MirLowerState, source_start: int, source_end: int, caller_offset: int) -> int:
    return state.constant_index_map.find(state.source, source_start, source_end,
        state.constants.starts, state.constants.ends, CONSTANT_FILES, caller_offset)

def mir_lower_default_argument(state: MirLowerState, default_token: int) -> int:
    # 解析缺省参数 token 为常量（int/str/float/bool 字面量，负数取 MINUS+数字）
    mir_state_ensure_tokens(state)
    let kinds = state.lex_kinds
    let starts = state.lex_starts
    let ends = state.lex_ends
    if (
        token_kind(kinds, default_token) == TOKEN_OPEN_BRACE and
        token_kind(kinds, default_token + 1) == TOKEN_CLOSE_BRACE
    ):
        let value_id = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, value_id + 1)
        let call_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
            MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_CREATE_STR_STR)
        mir_append_operand(state.values, MIR_OPERAND_INT, 8)
        mir_state_append_instruction_source(state, MIR_OP_CALL, MIR_TYPE_DICT, value_id, call_start, 2,
            token_start(starts, default_token), token_end(ends, default_token + 1))
        return value_id
    let value_token = default_token
    let token_value = token_kind(kinds, default_token)
    if token_value == TOKEN_MINUS:
        value_token = default_token + 1
        token_value = token_kind(kinds, value_token)
    let constant_type = MIR_TYPE_I32
    let constant_value = 0
    if token_value == TOKEN_INTEGER:
        constant_type = MIR_TYPE_I32
        constant_value = parse_integer(state.source, token_start(starts, value_token), token_end(ends, value_token))
        if default_token != value_token:
            constant_value = 0 - constant_value
    elif token_value == TOKEN_STRING:
        constant_type = MIR_TYPE_STR
    elif token_value == TOKEN_FLOAT:
        constant_type = MIR_TYPE_F64
    elif token_value == TOKEN_TRUE:
        constant_type = MIR_TYPE_BOOL
        constant_value = 1
    elif token_value == TOKEN_FALSE:
        constant_type = MIR_TYPE_BOOL
        constant_value = 0
    else:
        return -1
    let value_id = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, value_id + 1)
    let constant_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, constant_value)
    let literal_start = token_start(starts, default_token)
    let literal_end = token_end(ends, value_token)
    mir_state_append_instruction_source(state, MIR_OP_CONST, constant_type, value_id, constant_start, 1, literal_start,
        literal_end)
    return value_id

def mir_find_global_node(hir: HirProgram, source: str, source_start: int, source_end: int, caller_offset: int) -> int:
    let name_len = source_end - source_start
    let caller_file = module_env_file_at(caller_offset)
    if caller_file < 0:
        caller_file = 0
    let record_id = hir_record_count(hir.records) - 1
    while record_id >= 0:
        let offset = hir_record_offset(record_id)
        if hir.records[offset] == HIR_RECORD_FUNCTION:
            return -1
        if hir.records[offset] == HIR_RECORD_GLOBAL:
            let g_start = hir.records[offset + 9]
            let g_end = hir.records[offset + 10]
            if g_end - g_start == name_len and source[source_start:source_end] == source[g_start:g_end]:
                let def_file = module_env_file_at(g_start)
                if caller_file == def_file or hir_file_visible(caller_offset, source, source_start, source_end, def_file):
                    if hir.records[offset + 6] > 0:
                        let value_offset = hir_value_offset(hir.records[offset + 5])
                        if hir.values[value_offset] == HIR_VALUE_NODE:
                            return hir.values[value_offset + 1]
                    return -1
                return -1
        record_id = record_id - 1
    return -1

# 按名字查全局变量 slot；未收集到时返回 -1
def mir_global_slot(state: MirLowerState, source_start: int, source_end: int, caller_offset: int) -> int:
    return state.global_index_map.find_pair(state.source, source_start, source_end,
        state.global_names, GLOBAL_FILES, caller_offset)

# 从 LIST/SLICE 指令推断列表元素类型（slice 沿用其 base 列表的元素类型）
def mir_list_first_element(state: MirLowerState, list_value: int) -> int:
    if list_value < 0 or list_value >= len(state.value_records):
        return -1
    let offset = mir_int_list_get(state.value_records, list_value)
    if offset < 0:
        return -1
    if state.records[offset] == MIR_RECORD_INSTRUCTION and state.records[offset + 3] == MIR_OP_LIST:
        let operand_start = state.records[offset + 6]
        let operand_count = state.records[offset + 7]
        let operand_index = 0
        while operand_index < operand_count:
            let value_offset = mir_value_offset(operand_start + operand_index)
            if state.values[value_offset] == MIR_OPERAND_VALUE:
                return state.values[value_offset + 1]
            operand_index = operand_index + 1
    return -1

def mir_list_element_type(state: MirLowerState, list_value: int) -> int:
    if list_value >= 0 and list_value < len(state.value_records):
        let offset = mir_int_list_get(state.value_records, list_value)
        if offset >= 0:
            if state.records[offset] == MIR_RECORD_INSTRUCTION:
                let op = state.records[offset + 3]
                if op == MIR_OP_LIST:
                    let operand_start = state.records[offset + 6]
                    let operand_count = state.records[offset + 7]
                    let operand_index = 0
                    while operand_index < operand_count:
                        let value_offset = mir_value_offset(operand_start + operand_index)
                        if state.values[value_offset] == MIR_OPERAND_VALUE:
                            return mir_state_value_type(state, state.values[value_offset + 1])
                        operand_index = operand_index + 1
                elif op == MIR_OP_SLICE:
                    let operand_start = state.records[offset + 6]
                    let value_offset = mir_value_offset(operand_start)
                    if state.values[value_offset] == MIR_OPERAND_VALUE:
                        return mir_list_element_type(state, state.values[value_offset + 1])
                elif op == MIR_OP_INDEX:
                    # 嵌套索引（list[list[T]][i][j]）：穿透 base 列表的首元素取内层类型
                    let operand_start = state.records[offset + 6]
                    let value_offset = mir_value_offset(operand_start)
                    if state.values[value_offset] == MIR_OPERAND_VALUE:
                        let nested_base = state.values[value_offset + 1]
                        let first_element = mir_list_first_element(state, nested_base)
                        if first_element >= 0:
                            let element_type = mir_state_value_type(state, first_element)
                            if element_type == MIR_TYPE_LIST:
                                return mir_list_element_type(state, first_element)
                            return element_type
                elif op == MIR_OP_CALL and state.records[offset + 7] > 0:
                    let operand_offset = mir_value_offset(state.records[offset + 6])
                    if state.values[operand_offset] == MIR_OPERAND_SYMBOL:
                        let sym = state.values[operand_offset + 1]
                        if sym == MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_ITEMS_TUPLES:
                            return MIR_TYPE_TUPLE
                        if sym == MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_SPLIT:
                            return MIR_TYPE_STR
    # 无定义可循（函数参数等）：按列表类型推断元素类型
    if mir_state_value_type(state, list_value) == MIR_TYPE_LIST_PTR:
        if mir_int_list_get(state.func_has_dict_items, 0) != 0:
            return MIR_TYPE_TUPLE
        return MIR_TYPE_STR
    return MIR_TYPE_I32

# 将 list 创建指令的类型提升为 LIST_PTR（用于 let 注解 list[str] + 空字面量初始化）
def mir_promote_list_type(state: MirLowerState, value: int, target_type: int):
    if value >= 0 and value < len(state.value_records):
        let offset = mir_int_list_get(state.value_records, value)
        if offset >= 0:
            if state.records[offset] == MIR_RECORD_INSTRUCTION and state.records[offset + 3] == MIR_OP_LIST:
                mir_int_list_set(state.records, offset + 4, target_type)
                if value < len(state.value_types):
                    mir_int_list_set(state.value_types, value, target_type)

def mir_set_empty_dict_types(state: MirLowerState, value: int, annotation: str):
    if annotation.len() < 7 or annotation[0:5] != "dict[" or annotation[annotation.len() - 1:] != "]":
        return
    let comma = 5
    while comma < annotation.len() and annotation[comma] != ',':
        comma = comma + 1
    if comma >= annotation.len() - 1:
        return
    let key_annotation = annotation[5:comma]
    let value_annotation = annotation[comma + 1:annotation.len() - 1]
    let key_type = MIR_TYPE_I32
    let value_type = MIR_TYPE_PTR
    if key_annotation == "str":
        key_type = MIR_TYPE_STR
    if value_annotation == "int":
        value_type = MIR_TYPE_I32
    if value_annotation == "str":
        value_type = MIR_TYPE_STR
    if value_annotation == "bool":
        value_type = MIR_TYPE_BOOL
    if value_annotation == "float":
        value_type = MIR_TYPE_F64
    if value >= 0 and value < len(state.value_records):
        let offset = mir_int_list_get(state.value_records, value)
        if offset >= 0:
            if (
                state.records[offset] == MIR_RECORD_INSTRUCTION and
                state.records[offset + 3] == MIR_OP_DICT and
                state.records[offset + 7] <= 1
            ):
                let operand_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
                mir_append_operand(state.values, MIR_OPERAND_TYPE, key_type)
                mir_append_operand(state.values, MIR_OPERAND_TYPE, value_type)
                mir_int_list_set(state.records, offset + 6, operand_start)
                mir_int_list_set(state.records, offset + 7, 3)

def mir_hir_list_literal_type(hir: HirProgram, node_id: int) -> int:
    if node_id < 0 or node_id >= hir_record_count(hir.records):
        return MIR_TYPE_DYNAMIC
    let offset = hir_record_offset(node_id)
    if hir.records[offset + 1] != HIR_OP_LIST:
        return MIR_TYPE_DYNAMIC
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count == 7:
        let var_start_offset = hir_value_offset(payload_start + 1)
        let var_end_offset = hir_value_offset(payload_start + 2)
        if hir.values[var_start_offset] == HIR_VALUE_INT and hir.values[var_end_offset] == HIR_VALUE_INT:
            return MIR_TYPE_DYNAMIC
    let result_type = MIR_TYPE_LIST
    let element_index = 0
    while element_index < payload_count:
        let element_offset = hir_value_offset(payload_start + element_index)
        if hir.values[element_offset] == HIR_VALUE_NODE:
            let element_node_id = hir.values[element_offset + 1]
            let element_type = hir.records[hir_record_offset(element_node_id) + 2]
            if element_type == HIR_TYPE_STR or element_type == HIR_TYPE_BYTES:
                result_type = MIR_TYPE_LIST_PTR
            elif element_type == HIR_TYPE_LIST or element_type == HIR_TYPE_LIST_INT:
                result_type = MIR_TYPE_LIST_PTR
            elif element_type == HIR_TYPE_DICT or element_type == HIR_TYPE_TUPLE:
                result_type = MIR_TYPE_LIST_PTR
            elif element_type == HIR_TYPE_STRUCT or element_type == HIR_TYPE_ENUM:
                result_type = MIR_TYPE_LIST_PTR
        element_index = element_index + 1
    return result_type

# 二元运算结果类型：比较/逻辑为 bool，算术沿用操作数类型（int/float/str）
def mir_binary_result_type(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 3:
        return MIR_TYPE_DYNAMIC
    let operator_offset = hir_value_offset(payload_start)
    let left_offset = hir_value_offset(payload_start + 1)
    let right_offset = hir_value_offset(payload_start + 2)
    let operator = 0
    if hir.values[operator_offset] == HIR_VALUE_INT:
        operator = hir.values[operator_offset + 1]
    if operator in [IR_OPERATOR_EQ, IR_OPERATOR_NE, IR_OPERATOR_LT, IR_OPERATOR_GT, IR_OPERATOR_LE, IR_OPERATOR_GE,
        IR_OPERATOR_IN, IR_OPERATOR_AND, IR_OPERATOR_OR]:
        return MIR_TYPE_BOOL
    let operand_type = MIR_TYPE_DYNAMIC
    if hir.values[left_offset] == HIR_VALUE_NODE:
        let left_node_id = hir.values[left_offset + 1]
        let left_value = mir_int_list_get(state.hir_value_map, left_node_id)
        if left_value >= 0:
            operand_type = mir_state_value_type(state, left_value)
        else:
            # emit 阶段无 map 缓存：LOCAL 按名查符号表
            let left_record_offset = hir_record_offset(left_node_id)
            if hir.records[left_record_offset + 1] == HIR_OP_LOCAL:
                let symbol_value = mir_find_symbol_value(state, hir.records[left_record_offset + 3],
                    hir.records[left_record_offset + 4])
                if symbol_value >= 0:
                    operand_type = mir_state_value_type(state, symbol_value)
    if operand_type == MIR_TYPE_DYNAMIC and hir.values[right_offset] == HIR_VALUE_NODE:
        let right_node_id = hir.values[right_offset + 1]
        let right_value = mir_int_list_get(state.hir_value_map, right_node_id)
        if right_value >= 0:
            operand_type = mir_state_value_type(state, right_value)
        else:
            let right_record_offset = hir_record_offset(right_node_id)
            if hir.records[right_record_offset + 1] == HIR_OP_LOCAL:
                let symbol_value = mir_find_symbol_value(state, hir.records[right_record_offset + 3],
                    hir.records[right_record_offset + 4])
                if symbol_value >= 0:
                    operand_type = mir_state_value_type(state, symbol_value)
    return operand_type

# 参数节点的字面量形态：0=非字面量, 1=int 字面量, 2=rune/byte 字面量。
# int 与 byte 在 MIR 中同为 i32，接口分发需按字面量形态区分。
def mir_literal_form(hir: HirProgram, state: MirLowerState, node_id: int) -> int:
    if node_id < 0 or node_id >= hir_record_count(hir.records):
        return 0
    let offset = hir_record_offset(node_id)
    if hir.records[offset + 1] != HIR_OP_LITERAL:
        return 0
    let source_start = hir.records[offset + 3]
    if source_start >= 0 and source_start < state.source.len():
        if state.source[source_start:source_start + 1] == "'":
            return 2
    return 1

# 接口文本（如 Append[str]）是否接受该 MIR 类型的值
def mir_impl_interface_accepts(interface_type: int, value_type: int, literal_form: int) -> bool:
    if interface_type == MIR_IMPL_ACCEPTS_STR:
        return value_type == MIR_TYPE_STR
    if interface_type == MIR_IMPL_ACCEPTS_INT:
        return value_type == MIR_TYPE_I32 and literal_form != 2
    if interface_type == MIR_IMPL_ACCEPTS_BYTE:
        return value_type == MIR_TYPE_I32 and literal_form == 2
    if interface_type == MIR_IMPL_ACCEPTS_BOOL:
        return value_type == MIR_TYPE_BOOL
    if interface_type == MIR_IMPL_ACCEPTS_FLOAT:
        return value_type == MIR_TYPE_F64
    if interface_type == MIR_IMPL_ACCEPTS_BYTES:
        return value_type == MIR_TYPE_BYTES
    return False

def mir_function_has_struct_receiver(state: MirLowerState, function_index: int) -> bool:
    if function_index < 0 or function_index >= len(state.func_receiver_flags):
        return false
    return mir_int_list_get(state.func_receiver_flags, function_index) != 0

def mir_find_function(state: MirLowerState, source_start: int, source_end: int, caller_offset: int) -> int:
    let name_len = source_end - source_start
    if name_len == 3 and state.source[source_start:source_end] == "str":
        return -1
    if name_len == 5 and (state.source[source_start:source_end] == "print" or state.source[source_start:source_end] == "eprint"):
        return -1
    if name_len == 7 and state.source[source_start:source_end] == "eprintln":
        return -1
    let name = state.source[source_start:source_end]
    if external_id_from_name(name) >= 0:
        return -1
    return state.func_index_map.find_func(state.source, source_start, source_end,
        state.functions.starts, state.functions.ends, FUNC_FILES, state.func_receiver_flags, caller_offset)

def mir_find_method_function(state: MirLowerState, source_start: int, source_end: int,
    target_declaration: int) -> int:
    let name_len = source_end - source_start
    let name_hash = __c_fnv_hash_range(state.source, source_start, source_end)
    let bucket = name_hash & state.func_index_map.mask
    if bucket < 0:
        bucket = 0 - bucket
    let method_index = mir_int_list_get(state.func_index_map.heads, bucket)
    let fallback_index = -1
    while method_index >= 0:
        if mir_int_list_get(state.func_index_map.hashes, method_index) == name_hash:
            let candidate_start = mir_int_list_get(state.functions.starts, method_index)
            let candidate_end = mir_int_list_get(state.functions.ends, method_index)
            if candidate_end - candidate_start == name_len:
                if state.source[source_start:source_end] == state.source[candidate_start:candidate_end]:
                    let parameter_count = 0
                    if method_index < len(state.func_param_counts):
                        parameter_count = mir_int_list_get(state.func_param_counts, method_index)
                    if parameter_count > 0 and method_index < len(state.parameter_offsets):
                        let parameter_offset = mir_int_list_get(state.parameter_offsets, method_index)
                        if parameter_offset >= 0 and parameter_offset < len(state.parameter_struct_decls):
                            let parameter_declaration = mir_int_list_get(state.parameter_struct_decls, parameter_offset)
                            if parameter_declaration >= 0:
                                if parameter_declaration == target_declaration:
                                    return method_index
                                if fallback_index < 0:
                                    fallback_index = method_index
        method_index = mir_int_list_get(state.func_index_map.next, method_index)
    return fallback_index

def mir_interface_id(state: MirLowerState, name_start: int, name_end: int) -> int:
    # 注解区间命中接口声明名时返回接口 id；否则 -1
    let type_start = name_start
    while (
        type_start < name_end and
        (state.source[type_start] == ':' or
        state.source[type_start] == ' ' or
        state.source[type_start] == '\t')
    ):
        type_start = type_start + 1
    if type_start >= name_end:
        return -1
    let index = 0
    while index < len(state.interface_name_starts):
        if source_ranges_equal(state.source, type_start, name_end, mir_int_list_get(state.interface_name_starts, index),
            mir_int_list_get(state.interface_name_ends, index)):
            return index
        index = index + 1
    return -1

def mir_lower_interface_dispatch(hir: HirProgram, node_id: int, state: MirLowerState, target_value: int, neg_decl: int,
    method_name: str, argument_count: int, payload_start: int, method_argument_base: int) -> int:
    # 接口方法调用：按 box 的 tag 分支调用对应 impl 方法（编译期已知 impl 集合）
    let interface_id = 0 - neg_decl - 2
    if interface_id < 0 or interface_id >= len(state.interface_name_starts):
        return -1
    let dispatch_functions: list[int] = []
    let dispatch_decls: list[int] = []
    let impl_index = 0
    while impl_index < len(state.interface_func_indexes):
        if source_ranges_equal(state.source, mir_int_list_get(state.impl_interface_name_starts, impl_index),
            mir_int_list_get(state.impl_interface_name_ends, impl_index), mir_int_list_get(state.interface_name_starts,
            interface_id), mir_int_list_get(state.interface_name_ends, interface_id)):
            let impl_fn = mir_int_list_get(state.interface_func_indexes, impl_index)
            if impl_fn < len(state.functions.starts):
                if state.source[mir_int_list_get(state.functions.starts, impl_fn):mir_int_list_get(state.functions.ends,
                    impl_fn)] == method_name:
                    append(dispatch_functions, impl_fn)
                    append(dispatch_decls, mir_int_list_get(state.impl_decl_indexes, impl_index))
        impl_index = impl_index + 1
    if len(dispatch_functions) == 0:
        return -1
    let payload_count = hir.records[hir_record_offset(node_id) + 6]
    let dispatch_arguments: list[int] = []
    let argument_index = 0
    while argument_index < argument_count and payload_count > method_argument_base + argument_index:
        let argument_offset = hir_value_offset(payload_start + method_argument_base + argument_index)
        if hir.values[argument_offset] == HIR_VALUE_NODE:
            let argument_node_id = hir.values[argument_offset + 1]
            let argument_value = mir_lower_hir_node(hir, argument_node_id, state)
            if argument_value >= 0:
                append(dispatch_arguments, argument_value)
        argument_index = argument_index + 1
    # box 拆包
    let box_tag = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, box_tag + 1)
    let box_tag_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_INTERFACE_TAG)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, target_value)
    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, box_tag, box_tag_start, 2)
    let box_obj = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, box_obj + 1)
    let box_obj_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_INTERFACE_OBJ)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, target_value)
    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, box_obj, box_obj_start, 2)
    # 返回类型取首个 impl 的签名
    let result_type = MIR_TYPE_I32
    let first_fn = mir_int_list_get(dispatch_functions, 0)
    if first_fn >= 0 and first_fn < len(state.functions.returns):
        result_type = mir_int_list_get(state.functions.returns, first_fn)
    let done_block = mir_state_reserve_block(state)
    let result_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, result_value + 1)
    # 逐 impl 生成 tag 比较分支
    let impl_candidate = 0
    while impl_candidate < len(dispatch_functions):
        let tag_const = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, tag_const + 1)
        let tag_const_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, mir_int_list_get(dispatch_decls, impl_candidate))
        mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, tag_const, tag_const_start, 1)
        let tag_cmp = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, tag_cmp + 1)
        let tag_cmp_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_EQ)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, box_tag)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, tag_const)
        mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, tag_cmp, tag_cmp_start, 3)
        let call_block = mir_state_reserve_block(state)
        let next_block = mir_state_reserve_block(state)
        let branch_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, tag_cmp)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, call_block)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, next_block)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
        mir_state_emit_block(state, call_block)
        mir_state_select_block(state, call_block)
        let call_operand_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, mir_int_list_get(dispatch_functions, impl_candidate))
        mir_append_operand(state.values, MIR_OPERAND_VALUE, box_obj)
        let call_arg_index = 0
        while call_arg_index < len(dispatch_arguments):
            mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(dispatch_arguments, call_arg_index))
            call_arg_index = call_arg_index + 1
        let call_result = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, call_result + 1)
        mir_state_append_instruction(state, MIR_OP_CALL, result_type, call_result, call_operand_start,
            2 + len(dispatch_arguments))
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, done_block)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, call_result)
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, 2)
        mir_state_emit_block(state, next_block)
        mir_state_select_block(state, next_block)
        impl_candidate = impl_candidate + 1
    # 未匹配 impl：回退 0
    let fallback_jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, done_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_terminator(state, MIR_TERM_JUMP, fallback_jump_start, 2)
    mir_state_emit_block(state, done_block)
    mir_state_select_block(state, done_block)
    mir_state_append_block_parameter(state, done_block, result_type, result_value)
    return result_value

def mir_find_impl_method(state: MirLowerState, declaration_index: int, interface_name: str, method_name: str) -> int:
    let impl_index = 0
    while impl_index < len(state.interface_func_indexes):
        let matches_interface = state.source[mir_int_list_get(state.impl_interface_name_starts,
            impl_index):mir_int_list_get(state.impl_interface_name_ends, impl_index)] == interface_name
        if matches_interface and mir_int_list_get(state.impl_decl_indexes, impl_index) == declaration_index:
            let func_index = mir_int_list_get(state.interface_func_indexes, impl_index)
            if state.source[mir_int_list_get(state.functions.starts,
                func_index):mir_int_list_get(state.functions.ends, func_index)] == method_name:
                return func_index
        impl_index = impl_index + 1
    return -1

def mir_find_struct_method(state: MirLowerState, declaration_index: int, method_name: str) -> int:
    let impl_index = 0
    while impl_index < len(state.interface_func_indexes):
        if mir_int_list_get(state.impl_decl_indexes, impl_index) == declaration_index:
            let func_index = mir_int_list_get(state.interface_func_indexes, impl_index)
            if state.source[mir_int_list_get(state.functions.starts,
                func_index):mir_int_list_get(state.functions.ends, func_index)] == method_name:
                return func_index
        impl_index = impl_index + 1
    return -1

def mir_find_struct_init(state: MirLowerState, declaration_index: int) -> int:
    if declaration_index < 0 or declaration_index >= len(state.struct_init_func_map):
        return -1
    return mir_int_list_get(state.struct_init_func_map, declaration_index)

def mir_impl_method_pair(state: MirLowerState, declaration_index: int) -> (int, int, int):
    let iterator_has_next = mir_find_impl_method(state, declaration_index, "Iterator", "has_next")
    let iterator_next = mir_find_impl_method(state, declaration_index, "Iterator", "next")
    if iterator_has_next >= 0 and iterator_next >= 0:
        return (1, iterator_has_next, iterator_next)
    let iterable_iter = mir_find_impl_method(state, declaration_index, "Iterable", "iter")
    if iterable_iter >= 0:
        return (2, iterable_iter, -1)
    return (0, -1, -1)

def mir_unique_iterator_declaration(state: MirLowerState) -> int:
    let found_declaration = -1
    let impl_index = 0
    while impl_index < len(state.interface_func_indexes):
        let declaration_index = mir_int_list_get(state.impl_decl_indexes, impl_index)
        let interface_start = mir_int_list_get(state.impl_interface_name_starts, impl_index)
        let interface_end = mir_int_list_get(state.impl_interface_name_ends, impl_index)
        if state.source[interface_start:interface_end] == "Iterator":
            let has_next_method = mir_find_impl_method(state, declaration_index, "Iterator", "has_next")
            let next_method = mir_find_impl_method(state, declaration_index, "Iterator", "next")
            if has_next_method >= 0 and next_method >= 0:
                if found_declaration >= 0 and found_declaration != declaration_index:
                    return -1
                found_declaration = declaration_index
        impl_index = impl_index + 1
    return found_declaration

def mir_func_return_struct_decl(hir: HirProgram, state: MirLowerState, func_index: int) -> int:
    let current_function = 0
    let record_id = 0
    while record_id < hir_record_count(hir.records):
        let offset = hir_record_offset(record_id)
        if hir.records[offset] == HIR_RECORD_FUNCTION:
            if current_function == func_index:
                let scan_id = record_id + 1
                while scan_id < hir_record_count(hir.records):
                    let scan_offset = hir_record_offset(scan_id)
                    if hir.records[scan_offset] == HIR_RECORD_FUNCTION:
                        return -1
                    if hir.records[scan_offset + 1] == HIR_OP_STRUCT:
                        let declaration_index = mir_hir_node_struct_declaration(hir, scan_id)
                        if declaration_index < 0:
                            let struct_payload = hir.records[scan_offset + 5]
                            let struct_name_start_offset = hir_value_offset(struct_payload)
                            let struct_name_end_offset = hir_value_offset(struct_payload + 1)
                            if (
                                hir.values[struct_name_start_offset] == HIR_VALUE_INT and
                                hir.values[struct_name_end_offset] == HIR_VALUE_INT
                            ):
                                declaration_index = find_struct_declaration_index(state.source,
                                    hir.values[struct_name_start_offset + 1], hir.values[struct_name_end_offset + 1],
                                    hir.values[struct_name_start_offset + 1])
                        if declaration_index >= 0:
                            return declaration_index
                    scan_id = scan_id + 1
                return -1
            current_function = current_function + 1
        record_id = record_id + 1
    return -1

def mir_emit_impl_call(state: MirLowerState, func_index: int, target_value: int) -> int:
    if func_index < 0 or func_index >= len(state.functions.returns):
        return -1
    let result_type = mir_int_list_get(state.functions.returns, func_index)
    let operand_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, func_index)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, target_value)
    let result_value = -1
    if result_type != MIR_TYPE_UNIT:
        result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, result_value + 1)
    mir_state_append_instruction(state, MIR_OP_CALL, result_type, result_value, operand_start, 2)
    return result_value

def mir_lower_iterator_contains(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    if hir.records[offset + 6] < 3:
        return -1
    let operator_offset = hir_value_offset(payload_start)
    if hir.values[operator_offset] != HIR_VALUE_INT or hir.values[operator_offset + 1] != IR_OPERATOR_IN:
        return -1
    let left_offset = hir_value_offset(payload_start + 1)
    let right_offset = hir_value_offset(payload_start + 2)
    if hir.values[left_offset] != HIR_VALUE_NODE or hir.values[right_offset] != HIR_VALUE_NODE:
        return -1
    let right_value = mir_lower_hir_node(hir, hir.values[right_offset + 1], state)
    if right_value < 0:
        return -1
    let right_declaration = mir_state_struct_declaration(state, right_value)
    if right_declaration < 0:
        return -1
    let (protocol_kind, first_method, second_method) = mir_impl_method_pair(state, right_declaration)
    if protocol_kind == 0:
        return -1
    let iterator_value = right_value
    let has_next_method = first_method
    let next_method = second_method
    if protocol_kind == 2:
        let iter_result = mir_emit_impl_call(state, first_method, right_value)
        if iter_result < 0:
            return -1
        let iterator_declaration = mir_func_return_struct_decl(hir, state, first_method)
        if iterator_declaration < 0:
            iterator_declaration = mir_unique_iterator_declaration(state)
        if iterator_declaration < 0:
            return -1
        mir_state_set_struct_declaration(state, iter_result, iterator_declaration)
        let (iterator_kind, iterator_has_next, iterator_next) = mir_impl_method_pair(state, iterator_declaration)
        if iterator_kind != 1:
            return -1
        iterator_value = iter_result
        has_next_method = iterator_has_next
        next_method = iterator_next
    let needle_value = mir_lower_hir_node(hir, hir.values[left_offset + 1], state)
    if needle_value < 0:
        return -1
    let condition_block = mir_state_reserve_block(state)
    let next_block = mir_state_reserve_block(state)
    let true_block = mir_state_reserve_block(state)
    let false_block = mir_state_reserve_block(state)
    let join_block = mir_state_reserve_block(state)
    let entry_jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, condition_block)
    mir_state_append_terminator(state, MIR_TERM_JUMP, entry_jump_start, 1)
    mir_state_emit_block(state, condition_block)
    mir_state_select_block(state, condition_block)
    let has_next_value = mir_emit_impl_call(state, has_next_method, iterator_value)
    if has_next_value < 0:
        return -1
    let condition_branch_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, has_next_value)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, next_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, false_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, condition_branch_start, 5)
    mir_state_emit_block(state, next_block)
    mir_state_select_block(state, next_block)
    let item_value = mir_emit_impl_call(state, next_method, iterator_value)
    if item_value < 0:
        return -1
    let comparison_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, comparison_value + 1)
    let comparison_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_EQ)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, item_value)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, needle_value)
    mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, comparison_value, comparison_start, 3)
    let item_branch_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, comparison_value)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, true_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, condition_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, item_branch_start, 5)
    mir_state_emit_block(state, true_block)
    mir_state_select_block(state, true_block)
    let true_jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 1)
    mir_state_append_terminator(state, MIR_TERM_JUMP, true_jump_start, 2)
    mir_state_emit_block(state, false_block)
    mir_state_select_block(state, false_block)
    let false_jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_terminator(state, MIR_TERM_JUMP, false_jump_start, 2)
    mir_state_emit_block(state, join_block)
    mir_state_select_block(state, join_block)
    let result_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, result_value + 1)
    mir_state_append_block_parameter(state, join_block, MIR_TYPE_BOOL, result_value)
    mir_int_list_set(state.hir_value_map, node_id, result_value)
    return result_value

def mir_external_id(source: str, source_start: int, source_end: int) -> int:
    let external_id = external_id_from_name(source[source_start:source_end])
    if external_id < 0:
        return -1
    return MIR_EXTERNAL_BASE + external_id

def mir_external_type(external_id: int) -> int:
    let return_type = external_return_type(external_id)
    if return_type == EXTERNAL_RETURN_UNIT:
        return MIR_TYPE_UNIT
    if return_type == EXTERNAL_RETURN_INT:
        return MIR_TYPE_I32
    if return_type == EXTERNAL_RETURN_BOOL:
        return MIR_TYPE_BOOL
    if return_type == EXTERNAL_RETURN_FLOAT:
        return MIR_TYPE_F64
    if return_type == EXTERNAL_RETURN_STRING:
        return MIR_TYPE_STR
    if return_type == EXTERNAL_RETURN_POINTER:
        return MIR_TYPE_PTR
    return MIR_TYPE_PTR

def mir_external_type_for_name(name: str, external_id: int) -> int:
    if name == "__c_str_split":
        return MIR_TYPE_LIST_PTR
    if name == "__c_dict_items_tuples":
        return MIR_TYPE_LIST_PTR
    if name in [
        "__c_dict_create_int_int",
        "__c_dict_create_int_str",
        "__c_dict_create_str_int",
        "__c_dict_create_str_str",
        "__c_dict_create_int_ptr",
        "__c_dict_create_str_ptr",
    ]:
        return MIR_TYPE_DICT
    if name in [
        "__c_file_read_bytes",
        "__c_bytes_from_array",
        "__c_bytes_slice",
        "__c_str_to_bytes",
        "__c_utf8_encode_rune",
    ]:
        return MIR_TYPE_BYTES
    if name in [
        "__c_bytes_to_str",
        "__c_str_concat",
        "__c_str_upper",
        "__c_str_lower",
        "__c_str_strip",
        "__c_str_join",
    ]:
        return MIR_TYPE_STR
    return mir_external_type(external_id)

def mir_bind_symbol(state: MirLowerState, source_start: int, source_end: int, value: int):
    let symbol_index = 0
    while symbol_index < mir_int_list_get(state.symbol_count, 0):
        let symbol_start = mir_int_list_get(state.symbol_starts, symbol_index)
        let symbol_end = mir_int_list_get(state.symbol_ends, symbol_index)
        if state.source[source_start:source_end] == state.source[symbol_start:symbol_end]:
            mir_int_list_set(state.symbol_values, symbol_index, value)
            return
        symbol_index = symbol_index + 1
    let target_index = mir_int_list_get(state.symbol_count, 0)
    if target_index < len(state.symbol_starts):
        mir_int_list_set(state.symbol_starts, target_index, source_start)
        mir_int_list_set(state.symbol_ends, target_index, source_end)
        mir_int_list_set(state.symbol_values, target_index, value)
    else:
        append(state.symbol_starts, source_start)
        append(state.symbol_ends, source_end)
        append(state.symbol_values, value)
    mir_int_list_set(state.symbol_count, 0, mir_int_list_get(state.symbol_count, 0) + 1)

def mir_tuple_element_type(state: MirLowerState, name_start: int, name_end: int) -> int:
    let name = state.source[name_start:name_end]
    if name in ["args_roots", "method_roots", "roots"]:
        return MIR_TYPE_LIST
    return MIR_TYPE_I32

def mir_lower_tuple_let(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 3:
        return -1
    let value_offset = hir_value_offset(payload_start + 2)
    if hir.values[value_offset] != HIR_VALUE_NODE:
        return -1
    let tuple_value = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
    if tuple_value < 0:
        return -1
    let tuple_name_start_value = hir_value_offset(payload_start)
    let tuple_name_end_value = hir_value_offset(payload_start + 1)
    if hir.values[tuple_name_start_value] != HIR_VALUE_INT or hir.values[tuple_name_end_value] != HIR_VALUE_INT:
        return tuple_value
    let tuple_name_start = hir.values[tuple_name_start_value + 1]
    let tuple_name_end = hir.values[tuple_name_end_value + 1]
    mir_state_ensure_tokens(state)
    let kinds = state.lex_kinds
    let starts = state.lex_starts
    let ends = state.lex_ends
    let element_index = 0
    let cursor = tuple_name_start
    while cursor < tuple_name_end and token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) != TOKEN_IDENTIFIER:
            cursor = cursor + 1
            continue
        let name_start = token_start(starts, cursor)
        let name_end = token_end(ends, cursor)
        let result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        let operand_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, tuple_value)
        mir_append_operand(state.values, MIR_OPERAND_INT, element_index)
        let element_type = mir_tuple_element_type(state, name_start, name_end)
        mir_state_append_instruction_source(state, MIR_OP_INDEX, element_type, result_value, operand_start, 2,
            name_start, name_end)
        mir_bind_symbol(state, name_start, name_end, result_value)
        element_index = element_index + 1
        cursor = cursor + 1
    return tuple_value

def mir_copy_symbols(source: list[int]) -> list[int]:
    let copy: list[int] = []
    let index = 0
    while index < len(source):
        append(copy, mir_int_list_get(source, index))
        index = index + 1
    return copy

def mir_restore_symbols(state: MirLowerState, starts: list[int], ends: list[int], values: list[int], count: int):
    let index = 0
    while index < count:
        if index < len(state.symbol_starts):
            mir_int_list_set(state.symbol_starts, index, mir_int_list_get(starts, index))
            mir_int_list_set(state.symbol_ends, index, mir_int_list_get(ends, index))
            mir_int_list_set(state.symbol_values, index, mir_int_list_get(values, index))
        else:
            append(state.symbol_starts, mir_int_list_get(starts, index))
            append(state.symbol_ends, mir_int_list_get(ends, index))
            append(state.symbol_values, mir_int_list_get(values, index))
        index = index + 1
    mir_int_list_set(state.symbol_count, 0, count)

def mir_state_set_value_type(state: MirLowerState, value: int, type_tag: int):
    if value < 0:
        return
    while len(state.value_types) <= value:
        append(state.value_types, MIR_TYPE_DYNAMIC)
    mir_int_list_set(state.value_types, value, type_tag)

def mir_state_value_type(state: MirLowerState, value: int) -> int:
    if value < 0 or value >= len(state.value_types):
        return MIR_TYPE_DYNAMIC
    return mir_int_list_get(state.value_types, value)

def mir_state_struct_declaration(state: MirLowerState, value: int) -> int:
    if value < 0 or value >= len(state.value_struct_declarations):
        return -1
    return mir_int_list_get(state.value_struct_declarations, value)

def mir_state_set_struct_declaration(state: MirLowerState, value: int, declaration_index: int):
    if value < 0:
        return
    while len(state.value_struct_declarations) <= value:
        append(state.value_struct_declarations, -1)
    mir_int_list_set(state.value_struct_declarations, value, declaration_index)

def mir_state_mark_enum_value(state: MirLowerState, value: int):
    if value < 0:
        return
    while len(state.value_enum_flags) <= value:
        append(state.value_enum_flags, 0)
    mir_int_list_set(state.value_enum_flags, value, 1)

def mir_state_is_enum_value(state: MirLowerState, value: int) -> bool:
    if value < 0 or value >= len(state.value_enum_flags):
        return false
    return mir_int_list_get(state.value_enum_flags, value) != 0

def mir_const_value(state: MirLowerState, value: int) -> int:
    if value < 0 or value >= len(state.value_records):
        return -1
    let offset = mir_int_list_get(state.value_records, value)
    if offset >= 0:
        if state.records[offset] == MIR_RECORD_INSTRUCTION and state.records[offset + 3] == MIR_OP_CONST:
            let operand_start = state.records[offset + 6]
            let operand_count = state.records[offset + 7]
            if operand_count >= 1:
                let value_offset = mir_value_offset(operand_start)
                if state.values[value_offset] == MIR_OPERAND_INT:
                    return state.values[value_offset + 1]
    return -1

# 在收集阶段字段表中定位 (声明下标, 字段名) 对应表项；未命中返回 -1
def mir_declared_field_entry(state: MirLowerState, declaration_index: int, name_start: int, name_end: int) -> int:
    if declaration_index < 0:
        return -1
    let field_index = 0
    while field_index < len(STRUCT_FIELD_DECLARATIONS):
        if mir_int_list_get(STRUCT_FIELD_DECLARATIONS,
            field_index) == declaration_index and source_ranges_equal(state.source, name_start, name_end,
            mir_int_list_get(STRUCT_FIELD_NAME_STARTS, field_index), mir_int_list_get(STRUCT_FIELD_NAME_ENDS,
            field_index)):
            return field_index
        field_index = field_index + 1
    return -1

def mir_struct_field_slot(state: MirLowerState, declaration_index: int, name_start: int, name_end: int) -> int:
    let entry = mir_declared_field_entry(state, declaration_index, name_start, name_end)
    if entry < 0:
        return -1
    return mir_int_list_get(STRUCT_FIELD_SLOTS, entry)

def mir_struct_field_kind(state: MirLowerState, declaration_index: int, name_start: int, name_end: int) -> int:
    let entry = mir_declared_field_entry(state, declaration_index, name_start, name_end)
    if entry < 0:
        return -1
    return mir_int_list_get(STRUCT_FIELD_KINDS, entry)

def mir_struct_field_type_declaration(state: MirLowerState, declaration_index: int, name_start: int,
    name_end: int) -> int:
    let entry = mir_declared_field_entry(state, declaration_index, name_start, name_end)
    if entry < 0:
        return -1
    return mir_int_list_get(STRUCT_FIELD_TYPE_DECLS, entry)

def mir_struct_field_value_type_declaration(state: MirLowerState, declaration_index: int, name_start: int,
    name_end: int) -> int:
    let entry = mir_declared_field_entry(state, declaration_index, name_start, name_end)
    if entry < 0:
        return -1
    return mir_int_list_get(STRUCT_FIELD_VALUE_TYPE_DECLS, entry)

def mir_dict_value_type_declaration(source: str, type_start: int, type_end: int) -> int:
    let cursor = type_start
    let depth = 0
    while cursor < type_end:
        if source[cursor] == '[':
            depth = depth + 1
        elif source[cursor] == ',' and depth == 1:
            let value_start = cursor + 1
            let value_end = type_end - 1
            while value_start < value_end and source[value_start] == ' ':
                value_start = value_start + 1
            while value_end > value_start and (source[value_end - 1] == ' ' or source[value_end - 1] == ']'):
                value_end = value_end - 1
            return find_type_declaration_index(source, value_start, value_end, value_start)
        cursor = cursor + 1
    return -1

def mir_func_return_dict_value_declaration(state: MirLowerState, function_index: int) -> int:
    if function_index < 0 or function_index >= len(state.functions.ends):
        return -1
    let cursor = mir_int_list_get(state.functions.ends, function_index)
    let source_end = state.source.len()
    while cursor + 1 < source_end and state.source[cursor] != '\n':
        if state.source[cursor] == '-' and state.source[cursor + 1] == '>':
            let type_start = cursor + 2
            let type_end = type_start
            while type_end < source_end and state.source[type_end] not in [':', '\n']:
                type_end = type_end + 1
            while type_end > type_start and state.source[type_end - 1] == ' ':
                type_end = type_end - 1
            if type_start < type_end and state.source[type_start:type_start + 5] == "dict[":
                return mir_dict_value_type_declaration(state.source, type_start, type_end)
            return -1
        cursor = cursor + 1
    return -1

def mir_struct_declaration_by_field(state: MirLowerState, name_start: int, name_end: int) -> int:
    let found = -1
    let field_index = 0
    while field_index < len(STRUCT_FIELD_DECLARATIONS):
        if source_ranges_equal(state.source, mir_int_list_get(STRUCT_FIELD_NAME_STARTS, field_index),
            mir_int_list_get(STRUCT_FIELD_NAME_ENDS, field_index), name_start, name_end):
            if found >= 0 and found != mir_int_list_get(STRUCT_FIELD_DECLARATIONS, field_index):
                return -1
            found = mir_int_list_get(STRUCT_FIELD_DECLARATIONS, field_index)
        field_index = field_index + 1
    return found

def mir_hir_node_struct_declaration(hir: HirProgram, node_id: int) -> int:
    if node_id < 0 or node_id >= len(hir.struct_decls):
        return -1
    return mir_int_list_get(hir.struct_decls, node_id)

def mir_struct_field_count(declaration_index: int) -> int:
    let count = 0
    let field_index = 0
    while field_index < len(STRUCT_FIELD_DECLARATIONS):
        if mir_int_list_get(STRUCT_FIELD_DECLARATIONS, field_index) == declaration_index:
            count = count + 1
        field_index = field_index + 1
    return count

def mir_index_literal(hir: HirProgram, payload_start: int) -> int:
    let index_offset = hir_value_offset(payload_start + 1)
    if hir.values[index_offset] == HIR_VALUE_INT:
        return hir.values[index_offset + 1]
    if hir.values[index_offset] != HIR_VALUE_NODE:
        return -1
    let index_node = hir.values[index_offset + 1]
    let index_node_offset = hir_record_offset(index_node)
    if hir.records[index_node_offset + 1] != HIR_OP_LITERAL or hir.records[index_node_offset + 6] == 0:
        return -1
    let literal_offset = hir_value_offset(hir.records[index_node_offset + 5])
    if hir.values[literal_offset] == HIR_VALUE_INT:
        return hir.values[literal_offset + 1]
    return -1

def mir_value_is_dict_items(state: MirLowerState, value: int) -> bool:
    if value >= 0 and value < len(state.value_records):
        let offset = mir_int_list_get(state.value_records, value)
        if offset >= 0:
            if state.records[offset] == MIR_RECORD_INSTRUCTION:
                let op = state.records[offset + 3]
                if op == MIR_OP_TUPLE:
                    return false
                if op == MIR_OP_CALL and state.records[offset + 7] > 0:
                    let operand_offset = mir_value_offset(state.records[offset + 6])
                    if (
                        state.values[operand_offset] == MIR_OPERAND_SYMBOL and
                        state.values[operand_offset + 1] == MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_ITEMS_TUPLES
                    ):
                        return true
                if op == MIR_OP_INDEX and state.records[offset + 7] > 0:
                    let operand_offset = mir_value_offset(state.records[offset + 6])
                    if state.values[operand_offset] == MIR_OPERAND_VALUE:
                        if mir_value_is_dict_items(state, state.values[operand_offset + 1]):
                            return true
                    if mir_int_list_get(state.func_has_dict_items, 0) != 0:
                        return true
    return mir_int_list_get(state.func_has_dict_items, 0) != 0

def mir_index_result_type(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let node_offset = hir_record_offset(node_id)
    let result_type = mir_type_from_hir(hir.records[node_offset + 2])
    if result_type != MIR_TYPE_DYNAMIC:
        return result_type
    let payload_start = hir.records[node_offset + 5]
    let payload_count = hir.records[node_offset + 6]
    if payload_count < 1:
        return result_type
    let base_offset = hir_value_offset(payload_start)
    if hir.values[base_offset] != HIR_VALUE_NODE:
        return result_type
    let base_node_id = hir.values[base_offset + 1]
    let base_node_offset = hir_record_offset(base_node_id)
    if hir.records[base_node_offset + 1] == HIR_OP_LOCAL:
        # 全局 list 变量索引读取：bootstrap 全局 list 均为 list[int]
        let global_slot = mir_global_slot(state, hir.records[base_node_offset + 3], hir.records[base_node_offset + 4],
            hir.records[base_node_offset + 3])
        if global_slot >= 0 and global_slot < len(state.global_types):
            if mir_int_list_get(state.global_types, global_slot) == MIR_TYPE_LIST:
                return MIR_TYPE_I32
            if mir_int_list_get(state.global_types, global_slot) == MIR_TYPE_LIST_PTR:
                return MIR_TYPE_PTR
            # 全局 dict：从初始化表达式（DICT 字面量）的首个 value 节点类型推断
            let initializer_node = mir_int_list_get(state.global_initializers, global_slot)
            if initializer_node >= 0:
                let init_offset = hir_record_offset(initializer_node)
                if hir.records[init_offset + 1] == HIR_OP_DICT:
                    let init_payload_start = hir.records[init_offset + 5]
                    let init_payload_count = hir.records[init_offset + 6]
                    if init_payload_count >= 3:
                        let value_offset = hir_value_offset(init_payload_start + 2)
                        if hir.values[value_offset] == HIR_VALUE_NODE:
                            let value_node_id = hir.values[value_offset + 1]
                            let value_type = mir_type_from_hir(hir.records[hir_record_offset(value_node_id) + 2])
                            if value_type != MIR_TYPE_DYNAMIC:
                                return value_type
            return result_type
        # 局部 list 变量：从绑定值（LIST 创建）的元素类型推断
        let local_value = mir_find_symbol_value(state, hir.records[base_node_offset + 3],
            hir.records[base_node_offset + 4])
        if local_value >= 0:
            let base_type = mir_state_value_type(state, local_value)
            if base_type == MIR_TYPE_DICT:
                let declared_value = mir_state_struct_declaration(state, local_value)
                if declared_value >= 0:
                    mir_state_set_struct_declaration(state, mir_int_list_get(state.next_value, 0) - 1,
                        declared_value)
                    return MIR_TYPE_STRUCT
                # dict 值类型：从创建指令的首个 value 操作数推断
                if local_value >= 0 and local_value < len(state.value_records):
                    let dict_record_offset = mir_int_list_get(state.value_records, local_value)
                    if (
                        dict_record_offset >= 0 and
                        state.records[dict_record_offset] == MIR_RECORD_INSTRUCTION and
                        state.records[dict_record_offset + 3] == MIR_OP_DICT
                    ):
                        let dict_operand_start = state.records[dict_record_offset + 6]
                        let dict_operand_count = state.records[dict_record_offset + 7]
                        if dict_operand_count >= 3:
                            let value_operand_offset = mir_value_offset(dict_operand_start + 2)
                            if state.values[value_operand_offset] == MIR_OPERAND_TYPE:
                                return state.values[value_operand_offset + 1]
                            if state.values[value_operand_offset] == MIR_OPERAND_VALUE:
                                let value = state.values[value_operand_offset + 1]
                                let value_type = mir_state_value_type(state, value)
                                if value_type == MIR_TYPE_STRUCT:
                                    mir_state_set_struct_declaration(state, mir_int_list_get(state.next_value, 0) - 1,
                                        mir_state_struct_declaration(state, value))
                                return value_type
                            return MIR_TYPE_PTR
                # 泛型 dict 参数（dict[int, T]）无创建指令，默认元素为 PTR
                return MIR_TYPE_PTR
            if base_type in [MIR_TYPE_LIST, MIR_TYPE_LIST_PTR, MIR_TYPE_BYTES]:
                # bytes（encode 结果）元素为 int；list 取定义元素类型
                let element_type = mir_list_element_type(state, local_value)
                if base_type == MIR_TYPE_LIST_PTR and element_type == MIR_TYPE_PTR:
                    return MIR_TYPE_STR
                return element_type
            if base_type == MIR_TYPE_TUPLE:
                let index = mir_index_literal(hir, payload_start)
                if local_value >= 0 and local_value < len(state.value_records):
                    let tuple_offset = mir_int_list_get(state.value_records, local_value)
                    if tuple_offset >= 0:
                        if state.records[tuple_offset] == MIR_RECORD_INSTRUCTION and state.records[tuple_offset + 3] == MIR_OP_TUPLE:
                            let op_count = state.records[tuple_offset + 7]
                            if index >= 0 and index < op_count:
                                let elem_offset = mir_value_offset(state.records[tuple_offset + 6] + index)
                                if state.values[elem_offset] == MIR_OPERAND_VALUE:
                                    return mir_state_value_type(state, state.values[elem_offset + 1])
                if mir_value_is_dict_items(state, local_value):
                    if index == 0:
                        return MIR_TYPE_STR
                    if index == 1:
                        return MIR_TYPE_PTR
                return MIR_TYPE_I32
            if base_type == MIR_TYPE_PTR:
                let index = mir_index_literal(hir, payload_start)
                if index == 0:
                    return MIR_TYPE_STR
                if index == 1:
                    return MIR_TYPE_PTR
        return result_type
    if hir.records[base_node_offset + 1] == HIR_OP_FIELD:
        let field_payload_start = hir.records[base_node_offset + 5]
        if hir.records[base_node_offset + 6] >= 3:
            let base_value_offset = hir_value_offset(field_payload_start)
            let field_start_offset = hir_value_offset(field_payload_start + 1)
            let field_end_offset = hir_value_offset(field_payload_start + 2)
            if (
                hir.values[base_value_offset] == HIR_VALUE_NODE and
                hir.values[field_start_offset] == HIR_VALUE_INT and
                hir.values[field_end_offset] == HIR_VALUE_INT
            ):
                let field_base_node = hir.values[base_value_offset + 1]
                let field_base_value = -1
                if field_base_node >= 0 and field_base_node < len(state.hir_value_map):
                    field_base_value = mir_int_list_get(state.hir_value_map, field_base_node)
                let field_declaration = mir_state_struct_declaration(state, field_base_value)
                if field_declaration < 0:
                    field_declaration = mir_hir_node_struct_declaration(hir, field_base_node)
                let field_start = hir.values[field_start_offset + 1]
                let field_end = hir.values[field_end_offset + 1]
                if mir_struct_field_kind(state, field_declaration, field_start, field_end) == STRUCT_FIELD_DICT:
                    let value_declaration = mir_struct_field_value_type_declaration(state, field_declaration,
                        field_start, field_end)
                    if value_declaration >= 0:
                        mir_state_set_struct_declaration(state, mir_int_list_get(state.next_value, 0) - 1,
                            value_declaration)
                        return MIR_TYPE_STRUCT
                    return MIR_TYPE_PTR

    if hir.records[base_node_offset + 1] == HIR_OP_INDEX:
        # 嵌套索引：base 是列表索引结果（list[list[T]][i][j]），元素类型递归推断
        let inner_index_value = -1
        if base_node_id >= 0 and base_node_id < len(state.hir_value_map):
            inner_index_value = mir_int_list_get(state.hir_value_map, base_node_id)
        if inner_index_value >= 0:
            let inner_index_type = mir_state_value_type(state, inner_index_value)
            if inner_index_type == MIR_TYPE_LIST:
                return mir_list_element_type(state, inner_index_value)
        return result_type
    if hir.records[base_node_offset + 1] == HIR_OP_CALL:
        # base 是外部调用结果（bytes）：encode 返回 bytes，元素为 int
        let call_payload_start = hir.records[base_node_offset + 5]
        let call_callee_offset = hir_value_offset(call_payload_start)
        if hir.values[call_callee_offset] == HIR_VALUE_NODE:
            let call_callee_id = hir.values[call_callee_offset + 1]
            let call_callee_offset_id = hir_record_offset(call_callee_id)
            if hir.records[call_callee_offset_id + 1] == HIR_OP_LOCAL:
                let call_callee_start = hir.records[call_callee_offset_id + 3]
                let call_callee_end = hir.records[call_callee_offset_id + 4]
                let call_callee_name = state.source[call_callee_start:call_callee_end]
                if call_callee_name == "encode":
                    return MIR_TYPE_I32
        return result_type
    if hir.records[base_node_offset + 1] != HIR_OP_FIELD or hir.records[base_node_offset + 6] < 3:
        return result_type
    let field_base_offset = hir_value_offset(hir.records[base_node_offset + 5])
    let field_name_start_offset = hir_value_offset(hir.records[base_node_offset + 5] + 1)
    let field_name_end_offset = hir_value_offset(hir.records[base_node_offset + 5] + 2)
    if (
        hir.values[field_base_offset] != HIR_VALUE_NODE or
        hir.values[field_name_start_offset] != HIR_VALUE_INT or
        hir.values[field_name_end_offset] != HIR_VALUE_INT
    ):
        return result_type
    let field_name_start = hir.values[field_name_start_offset + 1]
    let field_name_end = hir.values[field_name_end_offset + 1]
    let declaration_index = -1
    let field_base_node_id = hir.values[field_base_offset + 1]
    if field_base_node_id >= 0 and field_base_node_id < len(state.hir_value_map):
        declaration_index = mir_state_struct_declaration(state, mir_int_list_get(state.hir_value_map,
            field_base_node_id))
    if declaration_index < 0:
        declaration_index = mir_hir_node_struct_declaration(hir, field_base_node_id)
    if declaration_index < 0:
        declaration_index = mir_struct_declaration_by_field(state, field_name_start, field_name_end)
    if declaration_index < 0:
        return result_type
    let field_slot = mir_struct_field_slot(state, declaration_index, field_name_start, field_name_end)
    let field_kind = mir_struct_field_kind(state, declaration_index, field_name_start, field_name_end)
    if field_slot < 0:
        return result_type
    if field_kind == STRUCT_FIELD_LIST_INT:
        return MIR_TYPE_I32
    if field_kind == STRUCT_FIELD_LIST_STR:
        return MIR_TYPE_STR
    return result_type

def mir_state_append_block_parameter(state: MirLowerState, block_index: int, type_tag: int, result_value: int):
    let parameter = MirRecord{
        record_kind: MIR_RECORD_PARAMETER,
        func_index: mir_int_list_get(state.func_index, 0),
        block_index: block_index,
        opcode: 0,
        type_tag: type_tag,
        result_value: result_value,
        operand_start: 0,
        operand_count: 0,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(state.records, parameter)
    mir_state_set_value_type(state, result_value, type_tag)

def mir_append_current_symbol_arguments(state: MirLowerState, starts: list[int], ends: list[int], symbol_count: int):
    let symbol_index = 0
    while symbol_index < symbol_count:
        let value = mir_find_symbol_value(state, mir_int_list_get(starts, symbol_index), mir_int_list_get(ends,
            symbol_index))
        if value < 0:
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        else:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, value)
        symbol_index = symbol_index + 1

def mir_push_loop(state: MirLowerState, break_block: int, continue_block: int, symbol_count: int):
    let loop_index = mir_int_list_get(state.loop_count, 0)
    if loop_index < len(state.loop_break_blocks):
        mir_int_list_set(state.loop_break_blocks, loop_index, break_block)
        mir_int_list_set(state.loop_continue_blocks, loop_index, continue_block)
        mir_int_list_set(state.loop_symbol_counts, loop_index, symbol_count)
    else:
        append(state.loop_break_blocks, break_block)
        append(state.loop_continue_blocks, continue_block)
        append(state.loop_symbol_counts, symbol_count)
    mir_int_list_set(state.loop_count, 0, mir_int_list_get(state.loop_count, 0) + 1)

def mir_pop_loop(state: MirLowerState):
    if mir_int_list_get(state.loop_count, 0) > 0:
        mir_int_list_set(state.loop_count, 0, mir_int_list_get(state.loop_count, 0) - 1)

def mir_hir_payload_value(hir: HirProgram, record_id: int, payload_index: int) -> int:
    let record_offset = hir_record_offset(record_id)
    let payload_start = hir.records[record_offset + 5]
    return payload_start + payload_index

def mir_hir_signature_value(hir_values: list[int], auxiliary_start: int, metadata_index: int) -> int:
    let value_id = auxiliary_start + metadata_index
    let value_offset = hir_value_offset(value_id)
    return hir_values[value_offset + 1]

def mir_append_func_signature(hir_values: list[int], auxiliary_start: int, values: list[int]) -> int:
    let parameter_count = mir_hir_signature_value(hir_values, auxiliary_start, HIR_SIGNATURE_PARAM_COUNT)
    let parameter_index = 0
    while parameter_index < parameter_count:
        let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
        let parameter_type = mir_type_from_hir(mir_hir_signature_value(hir_values, auxiliary_start, metadata_index))
        mir_append_operand(values, MIR_OPERAND_TYPE, parameter_type)
        parameter_index = parameter_index + 1
    let return_type = mir_type_from_hir(mir_hir_signature_value(hir_values, auxiliary_start, HIR_SIGNATURE_RETURN_TYPE))
    mir_append_operand(values, MIR_OPERAND_TYPE, return_type)
    return parameter_count

def mir_lower_struct_constructor(hir: HirProgram, node_id: int, state: MirLowerState, declaration_index: int,
    init_function: int, payload_start: int, payload_count: int) -> int:
    if init_function >= 0:
        let argument_count = 0
        if payload_count > 1:
            let count_offset = hir_value_offset(payload_start + 1)
            if hir.values[count_offset] == HIR_VALUE_INT:
                argument_count = hir.values[count_offset + 1]
        let init_operand_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, init_function)
        let argument_index = 0
        while argument_index < argument_count and payload_count > argument_index + 2:
            let argument_offset = hir_value_offset(payload_start + argument_index + 2)
            if hir.values[argument_offset] == HIR_VALUE_NODE:
                let argument_value = mir_lower_hir_node(hir, hir.values[argument_offset + 1], state)
                if argument_value >= 0:
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_value)
            argument_index = argument_index + 1
        let result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, result_value + 1)
        let result_type = MIR_TYPE_STRUCT
        if init_function < len(state.functions.returns):
            result_type = mir_int_list_get(state.functions.returns, init_function)
        mir_state_append_instruction(state, MIR_OP_CALL, result_type, result_value, init_operand_start,
            mir_value_count(state.values) - init_operand_start)
        mir_state_set_struct_declaration(state, result_value, declaration_index)
        mir_int_list_set(state.hir_value_map, node_id, result_value)
        return result_value
    let field_values: list[int] = []
    let field_index = 0
    while field_index < len(STRUCT_FIELD_DECLARATIONS):
        if mir_int_list_get(STRUCT_FIELD_DECLARATIONS, field_index) == declaration_index:
            let field_kind = mir_int_list_get(STRUCT_FIELD_KINDS, field_index)
            let field_type = MIR_TYPE_PTR
            if field_kind == STRUCT_FIELD_INT:
                field_type = MIR_TYPE_I32
            if field_kind == STRUCT_FIELD_BOOL:
                field_type = MIR_TYPE_BOOL
            if field_kind == STRUCT_FIELD_FLOAT:
                field_type = MIR_TYPE_F64
            if field_kind == STRUCT_FIELD_LIST_INT:
                field_type = MIR_TYPE_LIST
            if field_kind in [STRUCT_FIELD_LIST_STR, STRUCT_FIELD_DICT]:
                field_type = MIR_TYPE_LIST_PTR
                if field_kind == STRUCT_FIELD_DICT:
                    field_type = MIR_TYPE_DICT
            let field_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, field_value + 1)
            let field_operand_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            let field_opcode = MIR_OP_CONST
            if field_kind in [STRUCT_FIELD_LIST_INT, STRUCT_FIELD_LIST_STR]:
                field_opcode = MIR_OP_LIST
            mir_state_append_instruction(state, field_opcode, field_type, field_value, field_operand_start, 1)
            append(field_values, field_value)
        field_index = field_index + 1
    let struct_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, struct_value + 1)
    let struct_operand_start = mir_value_count(state.values)
    let value_index = 0
    while value_index < len(field_values):
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(field_values, value_index))
        value_index = value_index + 1
    mir_state_append_instruction(state, MIR_OP_STRUCT, MIR_TYPE_STRUCT, struct_value, struct_operand_start,
        len(field_values))
    mir_state_set_struct_declaration(state, struct_value, declaration_index)
    mir_int_list_set(state.hir_value_map, node_id, struct_value)
    return struct_value

def mir_lower_hir_node(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    if node_id < 0 or node_id >= hir_record_count(hir.records):
        return -1
    let mapped_value = mir_int_list_get(state.hir_value_map, node_id)
    if mapped_value >= 0:
        return mapped_value
    let offset = hir_record_offset(node_id)
    let record_kind = hir.records[offset]
    let opcode = hir.records[offset + 1]
    if opcode == HIR_OP_LITERAL:
        let result_type = mir_type_from_hir(hir.records[offset + 2])
        let result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        let operand_start = mir_value_count(state.values)
        if hir.records[offset + 6] > 0:
            let literal_offset = hir_value_offset(hir.records[offset + 5])
            if hir.values[literal_offset] == HIR_VALUE_INT:
                # HIR 载荷已携带解析好的字面量值（int 与 rune 均适用），
                # 不能按源码文本重新解析：rune 的 token 范围不含引号，
                # mir_parse_integer 会把它错解成 0
                mir_append_operand(state.values, MIR_OPERAND_INT, hir.values[literal_offset + 1])
        if mir_value_count(state.values) == operand_start:
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_state_append_instruction_source(state, MIR_OP_CONST, result_type, result_value, operand_start,
            mir_value_count(state.values) - operand_start, hir.records[offset + 3], hir.records[offset + 4])
        mir_int_list_set(state.hir_value_map, node_id, result_value)
        return result_value
    if opcode == HIR_OP_LOCAL:
        let local_value = mir_find_symbol_value(state, hir.records[offset + 3], hir.records[offset + 4])
        if local_value >= 0:
            mir_int_list_set(state.hir_value_map, node_id, local_value)
            return local_value

        let constant_index = mir_find_constant_index(state, hir.records[offset + 3], hir.records[offset + 4],
            hir.records[offset + 3])
        if constant_index >= 0:
            local_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, local_value + 1)
            let operand_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, mir_int_list_get(state.constants.values,
                constant_index))
            # 字符串常量用字面量定义区间作为 source，供 LLVM 提取字符串内容
            let constant_start = mir_int_list_get(state.constants.literal_starts, constant_index)
            let constant_end = mir_int_list_get(state.constants.literal_ends, constant_index)
            mir_state_append_instruction_source(state, MIR_OP_CONST,
                mir_type_from_constant(mir_int_list_get(state.constants.types,
                constant_index)), local_value, operand_start, 1, constant_start, constant_end)
            mir_int_list_set(state.hir_value_map, node_id, local_value)
            return local_value

        let global_slot = mir_global_slot(state, hir.records[offset + 3], hir.records[offset + 4],
            hir.records[offset + 3])
        if global_slot >= 0:
            if global_slot < len(state.global_value_cache):
                local_value = mir_int_list_get(state.global_value_cache, global_slot)
            if local_value < 0:
                local_value = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, local_value + 1)
                let global_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, global_slot)
                let global_type = MIR_TYPE_DYNAMIC
                if global_slot < len(state.global_types):
                    global_type = mir_int_list_get(state.global_types, global_slot)
                mir_state_append_instruction(state, MIR_OP_GLOBAL_LOAD, global_type, local_value, global_start, 1)
                mir_int_list_set(state.global_value_cache, global_slot, local_value)
            mir_int_list_set(state.hir_value_map, node_id, local_value)
            return local_value

        let global_node = mir_find_global_node(hir, state.source, hir.records[offset + 3], hir.records[offset + 4],
            hir.records[offset + 3])
        if global_node >= 0:
            local_value = mir_lower_hir_node(hir, global_node, state)
            if local_value >= 0:
                mir_int_list_set(state.hir_value_map, node_id, local_value)
                return local_value

        # None 字面量：构造 simple 内建枚举（tag=1）
        let local_name_text = state.source[hir.records[offset + 3]:hir.records[offset + 4]]
        let simple_variant_index = mir_enum_variant_index(state, hir.records[offset + 3], hir.records[offset + 4])
        let is_simple_variant = false
        if simple_variant_index >= 0:
            if state.enum_variant_payload_kinds[simple_variant_index] == 0:
                is_simple_variant = true
        if local_name_text == "None" or is_simple_variant:
            let simple_tag = 1
            if simple_variant_index >= 0:
                simple_tag = state.enum_variant_tags[simple_variant_index]
            local_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, local_value + 1)
            let none_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_CREATE_SIMPLE)
            mir_append_operand(state.values, MIR_OPERAND_INT, simple_tag)
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, local_value, none_start, 2)
            mir_int_list_set(state.hir_value_map, node_id, local_value)
            return local_value

        # 标识符是具名函数：生成函数引用值（调用点据此静态展开直接调用）
        let named_function = mir_find_function(state, hir.records[offset + 3], hir.records[offset + 4],
            hir.records[offset + 3])
        if named_function >= 0:
            local_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, local_value + 1)
            let reference_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, named_function)
            mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, local_value, reference_start, 1)
            append(state.func_ref_values, local_value)
            append(state.func_ref_targets, named_function)
            append(state.named_ref_name_starts, hir.records[offset + 3])
            append(state.named_ref_name_ends, hir.records[offset + 4])
            append(state.named_ref_targets, named_function)
            mir_int_list_set(state.hir_value_map, node_id, local_value)
            return local_value

        local_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        mir_state_append_instruction(state, MIR_OP_RUNTIME, MIR_TYPE_DYNAMIC, local_value,
            mir_value_count(state.values), 0)
        mir_int_list_set(state.hir_value_map, node_id, local_value)
        return local_value
    if opcode == HIR_OP_LET:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        if payload_count == 3:
            let tuple_value = mir_lower_tuple_let(hir, node_id, state)
            mir_int_list_set(state.hir_value_map, node_id, tuple_value)
            return tuple_value
        let initializer = -1
        let initializer_node = -1
        if payload_count > 4:
            let initializer_value = payload_start + 4
            let initializer_offset = hir_value_offset(initializer_value)
            if hir.values[initializer_offset] == HIR_VALUE_NODE:
                initializer_node = hir.values[initializer_offset + 1]
                initializer = mir_lower_hir_node(hir, initializer_node, state)
        elif payload_count > 2:
            let initializer_offset = hir_value_offset(payload_start + payload_count - 1)
            if hir.values[initializer_offset] == HIR_VALUE_NODE:
                initializer_node = hir.values[initializer_offset + 1]
                initializer = mir_lower_hir_node(hir, initializer_node, state)
        # ? 后缀：Result 解包（auxiliary_start 携带标志）。
        # Ok：取 __c_enum_get_int 载荷；Err：短路 RETURN 原 Result 盒（块级条件分支）
        if initializer >= 0 and hir.records[offset + 7] == 1:
            let question_tag = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, question_tag + 1)
            let question_tag_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_TAG)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, initializer)
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, question_tag, question_tag_start, 2)
            let zero_result = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, zero_result + 1)
            let zero_result_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, zero_result, zero_result_start, 1)
            let question_is_ok = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, question_is_ok + 1)
            let question_cmp_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_EQ)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, question_tag)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, zero_result)
            mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, question_is_ok, question_cmp_start, 3)
            # Err 短路：tag != 0 时直接 RETURN 原 Result 盒
            let question_err_block = mir_state_reserve_block(state)
            let question_ok_block = mir_state_reserve_block(state)
            let question_branch_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, question_is_ok)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, question_ok_block)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, question_err_block)
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_state_append_terminator(state, MIR_TERM_BRANCH, question_branch_start,
                mir_value_count(state.values) - question_branch_start)
            mir_state_emit_block(state, question_err_block)
            mir_state_select_block(state, question_err_block)
            let question_return_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, initializer)
            mir_state_append_terminator(state, MIR_TERM_RETURN, question_return_start, 1)
            # Ok 分支：取 payload 后继续
            mir_state_emit_block(state, question_ok_block)
            mir_state_select_block(state, question_ok_block)
            let question_payload = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, question_payload + 1)
            let question_payload_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_INT)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, initializer)
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, question_payload, question_payload_start, 2)
            initializer = question_payload
        if payload_count > 1 and initializer >= 0:
            # 接口类型注解：注解名命中接口声明表时装箱（box = {obj, tag}），
            # struct_decl 置 -(接口id+2) 供方法调用点分派
            if payload_count > 4:
                let annotation_start_offset = hir_value_offset(payload_start + 2)
                let annotation_end_offset = hir_value_offset(payload_start + 3)
                if (
                    hir.values[annotation_start_offset] == HIR_VALUE_INT and
                    hir.values[annotation_end_offset] == HIR_VALUE_INT
                ):
                    let interface_id = mir_interface_id(state, hir.values[annotation_start_offset + 1],
                        hir.values[annotation_end_offset + 1])
                    if interface_id >= 0:
                        let box_tag = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, box_tag + 1)
                        let box_tag_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_INT, mir_state_struct_declaration(state,
                            initializer))
                        mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, box_tag, box_tag_start, 1)
                        let box_value = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, box_value + 1)
                        let box_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
                            MIR_EXTERNAL_BASE + EXTERNAL_ID_INTERFACE_BOX)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, initializer)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, box_tag)
                        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, box_value, box_start, 3)
                        mir_state_set_struct_declaration(state, box_value, 0 - (interface_id + 2))
                        initializer = box_value
                        initializer_node = -1
            if initializer >= 0 and initializer_node >= 0:
                let literal_type = mir_hir_list_literal_type(hir, initializer_node)
                if literal_type != MIR_TYPE_DYNAMIC:
                    mir_promote_list_type(state, initializer, literal_type)
            # list[str] 注解：空字面量初始化的容器类型提升为 LIST_PTR。
            # 直接读注解文本，不依赖推断。
            if initializer >= 0 and payload_count > 4:
                let annotation_start_offset = hir_value_offset(payload_start + 2)
                let annotation_end_offset = hir_value_offset(payload_start + 3)
                if (
                    hir.values[annotation_start_offset] == HIR_VALUE_INT and
                    hir.values[annotation_end_offset] == HIR_VALUE_INT
                ):
                    let ann_start = hir.values[annotation_start_offset + 1]
                    let ann_end = hir.values[annotation_end_offset + 1]
                    let annotation = state.source[ann_start:ann_end]
                    mir_set_empty_dict_types(state, initializer, annotation)
                    if (
                        ann_start > 0 and
                        ann_end > ann_start and
                        annotation.len() >= 5 and
                        annotation[0:5] == "list[" and
                        annotation not in ["list[int]", "list[byte]", "list[rune]", "list[bool]", "list[float]"]
                    ):
                        mir_promote_list_type(state, initializer, MIR_TYPE_LIST_PTR)
                    if annotation[0:5] == "dict[":
                        let value_declaration = mir_dict_value_type_declaration(state.source, ann_start, ann_end)
                        if value_declaration >= 0:
                            mir_state_set_struct_declaration(state, initializer, value_declaration)
            let name_start_offset = hir_value_offset(payload_start)
            let name_end_offset = hir_value_offset(payload_start + 1)
            mir_bind_symbol(state, hir.values[name_start_offset + 1], hir.values[name_end_offset + 1], initializer)
            # 函数引用变量登记：变量名 → 目标函数（供调用点静态展开）
            let bound_ref_slot = mir_find_func_ref_index(state, initializer)
            if bound_ref_slot >= 0:
                append(state.named_ref_name_starts, hir.values[name_start_offset + 1])
                append(state.named_ref_name_ends, hir.values[name_end_offset + 1])
                append(state.named_ref_targets, state.func_ref_targets[bound_ref_slot])
                let bound_target = state.func_ref_targets[bound_ref_slot]
                let bound_return_type = MIR_TYPE_I32
                if bound_target < len(state.functions.returns):
                    bound_return_type = mir_int_list_get(state.functions.returns, bound_target)
                append(state.named_ref_return_types, bound_return_type)
        if initializer >= 0 and initializer_node >= 0:
            let initializer_declaration = mir_hir_node_struct_declaration(hir, initializer_node)
            if initializer_declaration >= 0:
                mir_state_set_struct_declaration(state, initializer, initializer_declaration)
        mir_int_list_set(state.hir_value_map, node_id, initializer)
        return initializer
    if opcode == HIR_OP_ASSIGN:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let assigned_value = -1
        let assigned_node = -1
        let is_local_assignment = false
        if payload_count > 2:
            let target_kind_offset = hir_value_offset(payload_start + 2)
            if (
                hir.values[target_kind_offset] == HIR_VALUE_INT and
                hir.values[target_kind_offset + 1] == ASSIGNMENT_FORM_LOCAL
            ):
                is_local_assignment = true
        if payload_count > 0:
            let value_index = payload_start + payload_count - 1
            let value_offset = hir_value_offset(value_index)
            if hir.values[value_offset] == HIR_VALUE_NODE:
                assigned_node = hir.values[value_offset + 1]
                assigned_value = mir_lower_hir_node(hir, assigned_node, state)
        if is_local_assignment and assigned_value >= 0:
            let name_start_offset = hir_value_offset(payload_start)
            let name_end_offset = hir_value_offset(payload_start + 1)
            let name_start = hir.values[name_start_offset + 1]
            let name_end = hir.values[name_end_offset + 1]
            let global_slot = -1
            if mir_find_symbol_value(state, name_start, name_end) < 0:
                global_slot = mir_global_slot(state, name_start, name_end, hir.records[offset + 3])
            if global_slot >= 0:
                let store_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, global_slot)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, assigned_value)
                let global_type = MIR_TYPE_DYNAMIC
                if global_slot < len(state.global_types):
                    global_type = mir_int_list_get(state.global_types, global_slot)
                mir_state_append_instruction(state, MIR_OP_GLOBAL_STORE, global_type, -1, store_start, 2)
                mir_int_list_set(state.global_value_cache, global_slot, assigned_value)
            else:
                mir_bind_symbol(state, name_start, name_end, assigned_value)
        let assignment_form = ASSIGNMENT_FORM_LOCAL
        if payload_count > 2:
            let assignment_form_offset = hir_value_offset(payload_start + 2)
            if hir.values[assignment_form_offset] == HIR_VALUE_INT:
                assignment_form = hir.values[assignment_form_offset + 1]
        if assignment_form == ASSIGNMENT_FORM_INDEX and payload_count >= 5 and assigned_value >= 0:
            let index_offset = hir_value_offset(payload_start + 3)
            let collection_start_offset = hir_value_offset(payload_start)
            let collection_end_offset = hir_value_offset(payload_start + 1)
            let collection_value = mir_find_symbol_value(state, hir.values[collection_start_offset + 1],
                hir.values[collection_end_offset + 1])
            if collection_value < 0:
                # 全局列表的索引赋值：先 GLOBAL_LOAD
                let global_slot = mir_global_slot(state, hir.values[collection_start_offset + 1],
                    hir.values[collection_end_offset + 1], hir.values[collection_start_offset + 1])
                if global_slot >= 0:
                    if global_slot < len(state.global_value_cache):
                        collection_value = mir_int_list_get(state.global_value_cache, global_slot)
                    if collection_value < 0:
                        collection_value = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, collection_value + 1)
                        let global_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_INT, global_slot)
                        let global_type = MIR_TYPE_DYNAMIC
                        if global_slot < len(state.global_types):
                            global_type = mir_int_list_get(state.global_types, global_slot)
                        mir_state_append_instruction(state, MIR_OP_GLOBAL_LOAD, global_type, collection_value,
                            global_start, 1)
                        mir_int_list_set(state.global_value_cache, global_slot, collection_value)
            if collection_value >= 0 and hir.values[index_offset] == HIR_VALUE_NODE:
                let index_value = mir_lower_hir_node(hir, hir.values[index_offset + 1], state)
                let operand_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, collection_value)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, index_value)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, assigned_value)
                let runtime_id = MIR_RUNTIME_LIST_SET_DYNAMIC
                if mir_state_value_type(state, collection_value) == MIR_TYPE_LIST:
                    runtime_id = MIR_RUNTIME_LIST_SET
                mir_state_append_runtime(state, runtime_id, operand_start, 3)
                mir_int_list_set(state.hir_value_map, node_id, -1)
                return -1
        if assignment_form == ASSIGNMENT_FORM_FIELD and payload_count >= 5 and assigned_value >= 0:
            let target_offset = hir_value_offset(payload_start + 3)
            if hir.values[target_offset] == HIR_VALUE_NODE:
                let target_node_id = hir.values[target_offset + 1]
                let target_node_offset = hir_record_offset(target_node_id)
                if hir.records[target_node_offset + 1] == HIR_OP_FIELD and hir.records[target_node_offset + 6] >= 3:
                    let field_payload_start = hir.records[target_node_offset + 5]
                    let base_offset = hir_value_offset(field_payload_start)
                    let field_start_offset = hir_value_offset(field_payload_start + 1)
                    let field_end_offset = hir_value_offset(field_payload_start + 2)
                    if (
                        hir.values[base_offset] == HIR_VALUE_NODE and
                        hir.values[field_start_offset] == HIR_VALUE_INT and
                        hir.values[field_end_offset] == HIR_VALUE_INT
                    ):
                        let base_node_id = hir.values[base_offset + 1]
                        let base_value = mir_lower_hir_node(hir, base_node_id, state)
                        let field_declaration = mir_hir_node_struct_declaration(hir, base_node_id)
                        if field_declaration < 0:
                            field_declaration = mir_state_struct_declaration(state, base_value)
                        let field_start = hir.values[field_start_offset + 1]
                        let field_end = hir.values[field_end_offset + 1]
                        let field_slot = mir_struct_field_slot(state, field_declaration, field_start, field_end)
                        if base_value >= 0 and field_slot >= 0:
                            let operand_start = mir_value_count(state.values)
                            mir_append_operand(state.values, MIR_OPERAND_VALUE, base_value)
                            mir_append_operand(state.values, MIR_OPERAND_INT, field_slot)
                            mir_append_operand(state.values, MIR_OPERAND_VALUE, assigned_value)
                            mir_state_append_runtime(state, MIR_RUNTIME_LIST_SET, operand_start, 3)
                            mir_int_list_set(state.hir_value_map, node_id, -1)
                            return -1
        if assignment_form == ASSIGNMENT_FORM_INDEX_TARGET and payload_count >= 5 and assigned_value >= 0:
            let target_offset = hir_value_offset(payload_start + 3)
            if hir.values[target_offset] == HIR_VALUE_NODE:
                let target_node_id = hir.values[target_offset + 1]
                let target_node_offset = hir_record_offset(target_node_id)
                if hir.records[target_node_offset + 1] == HIR_OP_INDEX and hir.records[target_node_offset + 6] >= 2:
                    let index_payload_start = hir.records[target_node_offset + 5]
                    let collection_offset = hir_value_offset(index_payload_start)
                    let index_value_offset = hir_value_offset(index_payload_start + 1)
                    let collection_value = -1
                    let index_value = -1
                    if hir.values[collection_offset] == HIR_VALUE_NODE:
                        collection_value = mir_lower_hir_node(hir, hir.values[collection_offset + 1], state)
                    if hir.values[index_value_offset] == HIR_VALUE_NODE:
                        index_value = mir_lower_hir_node(hir, hir.values[index_value_offset + 1], state)
                    if collection_value >= 0 and index_value >= 0:
                        let operand_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, collection_value)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, index_value)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, assigned_value)
                        let runtime_id = MIR_RUNTIME_LIST_SET_DYNAMIC
                        if mir_state_value_type(state, collection_value) == MIR_TYPE_LIST:
                            runtime_id = MIR_RUNTIME_LIST_SET
                        mir_state_append_runtime(state, runtime_id, operand_start, 3)
                        mir_int_list_set(state.hir_value_map, node_id, -1)
                        return -1
        if assigned_value >= 0 and assigned_node >= 0:
            let assigned_declaration = mir_hir_node_struct_declaration(hir, assigned_node)
            if assigned_declaration >= 0:
                mir_state_set_struct_declaration(state, assigned_value, assigned_declaration)
        mir_int_list_set(state.hir_value_map, node_id, assigned_value)
        return assigned_value
    if opcode == HIR_OP_LAMBDA:
        return mir_lower_hir_lambda(hir, node_id, state)
    if opcode == HIR_OP_ENUM and record_kind != HIR_RECORD_PATTERN:
        # 无载荷枚举变体表达式（None）：__c_enum_create_simple(tag)
        # 变体名取 record 的 name 区间（表达式节点的 payload 不含变体名）
        let variant_name_start = hir.records[offset + 9]
        let variant_name_end = hir.records[offset + 10]
        let enum_variant_probe2 = mir_enum_variant_index(state, variant_name_start, variant_name_end)
        let simple_tag = 0
        if enum_variant_probe2 >= 0:
            if state.enum_variant_payload_kinds[enum_variant_probe2] == 0:
                simple_tag = state.enum_variant_tags[enum_variant_probe2]
        let simple_result = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, simple_result + 1)
        let simple_call_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_CREATE_SIMPLE)
        mir_append_operand(state.values, MIR_OPERAND_INT, simple_tag)
        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, simple_result, simple_call_start, 2)
        mir_state_mark_enum_value(state, simple_result)
        mir_int_list_set(state.hir_value_map, node_id, simple_result)
        return simple_result
    if opcode == HIR_OP_SEQUENCE:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let sequence_value = -1
        if payload_count > 0:
            let value_offset = hir_value_offset(payload_start)
            if hir.values[value_offset] == HIR_VALUE_NODE:
                sequence_value = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
        mir_int_list_set(state.hir_value_map, node_id, sequence_value)
        return sequence_value
    if opcode == HIR_OP_CALL:
        let payload_start = hir.records[offset + 5]
        let payload_count = hir.records[offset + 6]
        let call_type = mir_type_from_hir(hir.records[offset + 2])
        let direct_function = -1
        let external_function = -1
        let callee_name_text = ""
        let method_target_id = -1
        let method_argument_base = 2
        let callee_name_start = -1
        let callee_name_end = -1
        let enum_construct_tag = -1
        let enum_construct_kind = 0
        if payload_count > 0:
            let callee_offset = hir_value_offset(payload_start)
            if hir.values[callee_offset] == HIR_VALUE_NODE:
                let callee_id = hir.values[callee_offset + 1]
                if callee_id >= 0 and callee_id < hir_record_count(hir.records):
                    let callee_record_offset = hir_record_offset(callee_id)
                    if hir.records[callee_record_offset + 1] == HIR_OP_LOCAL:
                        callee_name_start = hir.records[callee_record_offset + 3]
                        callee_name_end = hir.records[callee_record_offset + 4]
                        callee_name_text = state.source[callee_name_start:callee_name_end]
                        direct_function = mir_find_function(state, hir.records[callee_record_offset + 3],
                            hir.records[callee_record_offset + 4], hir.records[callee_record_offset + 3])
                        if direct_function >= 0:
                            if direct_function < len(state.functions.returns):
                                call_type = mir_int_list_get(state.functions.returns, direct_function)
                        else:
                            external_function = mir_external_id(state.source, hir.records[callee_record_offset + 3],
                                hir.records[callee_record_offset + 4])
                            if external_function >= MIR_EXTERNAL_BASE:
                                call_type = mir_external_type_for_name(callee_name_text,
                                    external_function - MIR_EXTERNAL_BASE)
        if direct_function < 0 and callee_name_text == "len":
            external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN
            call_type = MIR_TYPE_I32
        if direct_function < 0 and callee_name_text == "dict_items":
            external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_DICT_ITEMS_TUPLES
            call_type = MIR_TYPE_LIST_PTR
        let constructor_declaration = -1
        let constructor_function = -1
        if method_target_id < 0 and callee_name_start >= 0:
            constructor_declaration = find_struct_declaration_index(state.source, callee_name_start, callee_name_end,
                callee_name_start)
            if constructor_declaration >= 0:
                constructor_function = mir_find_struct_method(state, constructor_declaration, "__init__")
                if constructor_function < 0:
                    constructor_function = mir_find_struct_init(state, constructor_declaration)
                let constructor_value = mir_lower_struct_constructor(hir, node_id, state, constructor_declaration,
                    constructor_function, payload_start, payload_count)
                return constructor_value
        # 点号方法调用：payload[1]/[2] 为方法名区间，payload[0] 为目标表达式。
        # 目标表达式作为首个参数，方法名查函数表获得目标函数。
        let method_name_start_offset = hir_value_offset(payload_start + 1)
        let method_name_end_offset = hir_value_offset(payload_start + 2)
        let method_name_start = -1
        let method_name_end = -1
        if (
            payload_count > 2 and
            hir.values[method_name_start_offset] == HIR_VALUE_INT and
            hir.values[method_name_end_offset] == HIR_VALUE_INT
        ):
            method_name_start = hir.values[method_name_start_offset + 1]
            method_name_end = hir.values[method_name_end_offset + 1]
            callee_name_text = state.source[method_name_start:method_name_end]
            direct_function = mir_find_function(state, method_name_start, method_name_end,
                method_name_start)
            if direct_function >= 0:
                if direct_function < len(state.functions.returns):
                    call_type = mir_int_list_get(state.functions.returns, direct_function)
            else:
                external_function = mir_external_id(state.source, method_name_start, method_name_end)
                if external_function >= MIR_EXTERNAL_BASE:
                    call_type = mir_external_type_for_name(callee_name_text, external_function - MIR_EXTERNAL_BASE)
            method_target_id = hir.values[hir_value_offset(payload_start) + 1]
            method_argument_base = 4
            # 枚举构造识别：Enum.Variant(args) —— 方法名是已声明变体时，
            # 目标名不是变量而是枚举类型名，整体按 ENUM 构造降级
            let enum_variant_probe = mir_enum_variant_index(state, method_name_start, method_name_end)
            if enum_variant_probe >= 0:
                enum_construct_tag = state.enum_variant_tags[enum_variant_probe]
                enum_construct_kind = state.enum_variant_payload_kinds[enum_variant_probe]
        let argument_count = 0
        let count_offset = hir_value_offset(payload_start + method_argument_base - 1)
        if payload_count >= method_argument_base and hir.values[count_offset] == HIR_VALUE_INT:
            argument_count = hir.values[count_offset + 1]
        let argument_values: list[int] = []
        let argument_node_ids: list[int] = []
        let dispatched_functions: list[int] = []
        if method_target_id >= 0 and enum_construct_tag < 0:
            let target_value = mir_lower_hir_node(hir, method_target_id, state)
            if target_value >= 0:
                let target_type = mir_state_value_type(state, target_value)
                if target_type == MIR_TYPE_STR:
                    if callee_name_text == "find":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_FIND
                        call_type = MIR_TYPE_I32
                    elif callee_name_text == "upper":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_UPPER
                        call_type = MIR_TYPE_STR
                    elif callee_name_text == "lower":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_LOWER
                        call_type = MIR_TYPE_STR
                    elif callee_name_text == "strip":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_STRIP
                        call_type = MIR_TYPE_STR
                    elif callee_name_text == "split":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_SPLIT
                        call_type = MIR_TYPE_LIST_PTR
                    elif callee_name_text == "startswith":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_STARTS_WITH
                        call_type = MIR_TYPE_BOOL
                    elif callee_name_text == "endswith":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_ENDS_WITH
                        call_type = MIR_TYPE_BOOL
                    elif callee_name_text == "replace":
                        external_function = MIR_EXTERNAL_BASE + EXTERNAL_ID_STRING_REPLACE
                        call_type = MIR_TYPE_STR
                # 接口方法调用：目标为接口 box（struct_decl <= -2）时按 tag 分派 impl
                let target_decl = mir_state_struct_declaration(state, target_value)
                if target_decl >= 0:
                    let method_function = mir_find_method_function(state, method_name_start, method_name_end,
                        target_decl)
                    if method_function >= 0:
                        direct_function = method_function
                        if direct_function < len(state.functions.returns):
                            call_type = mir_int_list_get(state.functions.returns, direct_function)
                    let impl_method = mir_find_struct_method(state, target_decl, callee_name_text)
                    if impl_method >= 0:
                        direct_function = impl_method
                        if direct_function < len(state.functions.returns):
                            call_type = mir_int_list_get(state.functions.returns, direct_function)
                if target_decl <= -2:
                    let dispatch_result = mir_lower_interface_dispatch(hir, node_id, state, target_value, target_decl,
                        callee_name_text, argument_count, payload_start, method_argument_base)
                    if dispatch_result >= 0:
                        mir_int_list_set(state.hir_value_map, node_id, dispatch_result)
                        return dispatch_result
                append(argument_values, target_value)
                append(argument_node_ids, method_target_id)
        let argument_index = 0
        while argument_index < argument_count and payload_count > method_argument_base + argument_index:
            let argument_offset = hir_value_offset(payload_start + method_argument_base + argument_index)
            if hir.values[argument_offset] == HIR_VALUE_NODE:
                let argument_node_id = hir.values[argument_offset + 1]
                let argument_value = mir_lower_hir_node(hir, argument_node_id, state)
                if argument_value >= 0:
                    append(argument_values, argument_value)
                    append(argument_node_ids, argument_node_id)
            argument_index = argument_index + 1
        if method_target_id < 0 and callee_name_text == "str":
            if len(argument_values) == 1:
                let display_value = mir_int_list_get(argument_values, 0)
                let display_declaration = mir_state_struct_declaration(state, display_value)
                let display_function = -1
                if display_declaration >= 0:
                    display_function = mir_find_struct_method(state, display_declaration, "to_string")
                if display_function >= 0:
                    let display_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, display_function)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, display_value)
                    let display_result = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, display_result + 1)
                    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_STR, display_result, display_start, 2)
                    mir_int_list_set(state.hir_value_map, node_id, display_result)
                    return display_result
                let display_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, display_value)
                let display_result = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, display_result + 1)
                mir_state_set_value_type(state, display_result, MIR_TYPE_STR)
                mir_state_append_instruction(state, MIR_OP_DISPLAY, MIR_TYPE_STR, display_result, display_start, 1)
                mir_int_list_set(state.hir_value_map, node_id, display_result)
                return display_result
            mir_int_list_set(state.hir_value_map, node_id, -1)
            return -1
        if method_target_id < 0 and callee_name_text in ["print", "eprintln", "eprint", "str"]:
            let valid_arguments = len(argument_values) == 1
            if callee_name_text == "print":
                valid_arguments = len(argument_values) == 1 or len(argument_values) == 3
            if valid_arguments:
                let operand_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(argument_values, 0))
                if len(argument_values) == 3:
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(argument_values, 1))
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(argument_values, 2))
                else:
                    let stream = 0
                    if callee_name_text != "print":
                        stream = 1
                    if callee_name_text == "eprint":
                        stream = 2
                    mir_append_operand(state.values, MIR_OPERAND_INT, stream)
                mir_state_append_instruction(state, MIR_OP_PRINT, MIR_TYPE_UNIT, -1, operand_start,
                    mir_value_count(state.values) - operand_start)
                mir_int_list_set(state.hir_value_map, node_id, -1)
                return -1
            mir_int_list_set(state.hir_value_map, node_id, -1)
            return -1
        # 裸变体构造：Some(7) / Ok(x) 等，callee 名命中已声明变体
        if (
            enum_construct_tag < 0 and
            callee_name_start >= 0 and
            direct_function < 0 and
            external_function < MIR_EXTERNAL_BASE
        ):
            let bare_variant_index = mir_enum_variant_index(state, callee_name_start, callee_name_end)
            if bare_variant_index >= 0:
                enum_construct_tag = state.enum_variant_tags[bare_variant_index]
                enum_construct_kind = state.enum_variant_payload_kinds[bare_variant_index]
        # 函数引用调用（lambda / 函数值）：callee 符号持有函数引用时
        # 静态展开为对合成函数的直接调用，捕获实参按名单前置传入
        let named_ref_slot = mir_find_named_ref_target(state, callee_name_start, callee_name_end)
        let lambda_direct = -1
        if (
            callee_name_start >= 0 and
            direct_function < 0 and
            external_function < MIR_EXTERNAL_BASE and
            enum_construct_tag < 0
        ):
            lambda_direct = -1
            if named_ref_slot >= 0 and named_ref_slot < len(state.named_ref_targets):
                lambda_direct = state.named_ref_targets[named_ref_slot]
            if lambda_direct < 0:
                let callee_symbol_value = mir_find_symbol_value(state, callee_name_start, callee_name_end)
                if callee_symbol_value >= 0:
                    lambda_direct = mir_find_func_ref(state, callee_symbol_value)
            if lambda_direct >= 0 and lambda_direct < len(state.functions.returns):
                # 直接从 functions.returns 取返回类型（analyze 已正确设置）
                call_type = mir_int_list_get(state.functions.returns, lambda_direct)
        else:
            lambda_direct = -1
        if lambda_direct >= 0:
            let capture_count = 0
            if lambda_direct < len(state.functions.capture_counts):
                capture_count = state.functions.capture_counts[lambda_direct]
            let capture_flat_base = 0
            let counted_index = 0
            while counted_index < lambda_direct and counted_index < len(state.functions.capture_counts):
                capture_flat_base = capture_flat_base + state.functions.capture_counts[counted_index]
                counted_index = counted_index + 1
            let merged_arguments: list[int] = []
            let capture_argument_index = 0
            while capture_argument_index < capture_count:
                let capture_name_index = capture_flat_base + capture_argument_index
                let captured_name_start = state.functions.capture_name_starts[capture_name_index]
                let captured_name_end = state.functions.capture_name_ends[capture_flat_base + capture_argument_index]
                let captured_current = mir_find_symbol_value(state, captured_name_start, captured_name_end)
                if captured_current >= 0:
                    append(merged_arguments, captured_current)
                else:
                    append(merged_arguments, 0)
                capture_argument_index = capture_argument_index + 1
            let original_argument_index = 0
            while original_argument_index < len(argument_values):
                append(merged_arguments, mir_int_list_get(argument_values, original_argument_index))
                original_argument_index = original_argument_index + 1
            argument_values = merged_arguments
            # 接口分发：append(struct_target, v) → 对应 impl 方法。
            # 目标为带 Append 实现的结构体时，覆盖外部 runtime-append 路径，
        # 否则 @__c_append_pointer 会把值写进结构体盒子自身，破坏相邻堆内存。
        # 分发结果写入全新变量，避免对既有绑定的重绑定丢失问题。
        let dispatched_function = -1
        if callee_name_text == "append" and enum_construct_tag < 0 and len(argument_values) >= 1:
            let target_decl = mir_state_struct_declaration(state, mir_int_list_get(argument_values, 0))
            if target_decl >= 0:
                let appended_type = MIR_TYPE_DYNAMIC
                let appended_literal_form = 0
                if len(argument_values) >= 2:
                    appended_type = mir_state_value_type(state, mir_int_list_get(argument_values, 1))
                    appended_literal_form = mir_literal_form(hir, state, mir_int_list_get(argument_node_ids, 1))
                let candidate = 0
                while candidate < len(state.impl_func_decls):
                    if state.impl_func_decls[candidate] == target_decl:
                        if mir_impl_interface_accepts(state.impl_func_interface_types[candidate], appended_type,
                            appended_literal_form):
                            if dispatched_function < 0:
                                append(dispatched_functions, state.impl_func_indexes[candidate])
                    candidate = candidate + 1
        let dispatched_value = -1
        if len(dispatched_functions) > 0:
            dispatched_value = mir_int_list_get(dispatched_functions, 0)
        # 函数值调用：callee 符号为函数类型（函数值参数/变量）时生成间接调用
        if (
            lambda_direct < 0 and
            dispatched_value < 0 and
            direct_function < 0 and
            external_function < MIR_EXTERNAL_BASE and
            enum_construct_tag < 0 and
            callee_name_start >= 0
        ):
            let func_symbol_value = mir_find_symbol_value(state, callee_name_start, callee_name_end)
            if func_symbol_value >= 0:
                let func_symbol_type = mir_state_value_type(state, func_symbol_value)
                if func_symbol_type == MIR_TYPE_FUNCTION:
                    let indirect_result = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, indirect_result + 1)
                    let indirect_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, func_symbol_value)
                    let indirect_arg_index = 0
                    while indirect_arg_index < len(argument_values):
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(argument_values,
                            indirect_arg_index))
                        indirect_arg_index = indirect_arg_index + 1
                    mir_state_append_runtime_result(state, MIR_RUNTIME_FUNCTION_CALL, MIR_TYPE_I32, indirect_result,
                        indirect_start, 1 + len(argument_values))
                    mir_int_list_set(state.hir_value_map, node_id, indirect_result)
                    return indirect_result
        # 缺省参数填充：实参不足时按签名补尾部默认值（字面量常量）
        if direct_function >= 0 and direct_function < len(state.func_param_counts):
            let required_count = mir_int_list_get(state.func_param_counts, direct_function)
            let missing_count = required_count - len(argument_values)
            if missing_count > 0:
                let default_offset = 0
                let default_fn_index = 0
                while default_fn_index < direct_function:
                    default_offset = default_offset + mir_int_list_get(state.func_param_counts, default_fn_index)
                    default_fn_index = default_fn_index + 1
                let have_count = len(argument_values)
                let fill_index = 0
                while fill_index < missing_count:
                    let default_index = mir_int_list_get(state.parameter_default_indexes,
                        default_offset + have_count + fill_index)
                    if default_index >= 0:
                        let default_value = mir_lower_default_argument(state, default_index)
                        if default_value >= 0:
                            append(argument_values, default_value)
                    fill_index = fill_index + 1
        # 参数类型转换：签名参数 bytes 而实参 str 时插入 encode（如 append_bytes("hi")）
        if direct_function >= 0 and direct_function < len(state.func_param_counts):
            let param_type_offset = 0
            let param_func_index = 0
            while param_func_index < direct_function:
                param_type_offset = param_type_offset + mir_int_list_get(state.func_param_counts,
                    param_func_index)
                param_func_index = param_func_index + 1
            let convert_index = 0
            while convert_index < len(argument_values) and convert_index < mir_int_list_get(state.func_param_counts,
                direct_function):
                let expected_type = mir_int_list_get(state.func_param_types, param_type_offset + convert_index)
                if expected_type == MIR_TYPE_BYTES:
                    let actual_value = mir_int_list_get(argument_values, convert_index)
                    let actual_type = mir_state_value_type(state, actual_value)
                    if actual_type == MIR_TYPE_STR:
                        let bytes_value = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, bytes_value + 1)
                        let convert_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
                            MIR_EXTERNAL_BASE + EXTERNAL_ID_STR_TO_BYTES)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, actual_value)
                        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_BYTES, bytes_value, convert_start, 2)
                        mir_int_list_set(argument_values, convert_index, bytes_value)
                convert_index = convert_index + 1
        let operand_start = mir_value_count(state.values)
        if enum_construct_tag >= 0:
            # ENUM 构造：call enum_create_<kind>(tag, payload...)
            call_type = MIR_TYPE_PTR
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
                MIR_EXTERNAL_BASE + mir_enum_create_external_id(enum_construct_kind))
            mir_append_operand(state.values, MIR_OPERAND_INT, enum_construct_tag)
        elif dispatched_value >= 0:
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, dispatched_value)
        elif lambda_direct >= 0:
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, lambda_direct)
        elif direct_function >= 0:
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, direct_function)
        elif external_function >= 0:
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, external_function)
        argument_index = 0
        while argument_index < len(argument_values):
            mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(argument_values, argument_index))
            argument_index = argument_index + 1
        let result_value = mir_int_list_get(state.next_value, 0)
        if call_type == MIR_TYPE_UNIT or dispatched_value >= 0:
            result_value = -1
        else:
            mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        mir_state_append_instruction(state, MIR_OP_CALL, call_type, result_value, operand_start,
            mir_value_count(state.values) - operand_start)
        if enum_construct_tag >= 0 and result_value >= 0:
            mir_state_mark_enum_value(state, result_value)
        if direct_function >= 0 and result_value >= 0:
            let return_declaration = -1
            if direct_function < len(state.func_return_struct_decls):
                return_declaration = mir_int_list_get(state.func_return_struct_decls, direct_function)
            if return_declaration < 0:
                return_declaration = mir_func_return_struct_decl(hir, state, direct_function)
            if call_type == MIR_TYPE_DICT:
                return_declaration = mir_func_return_dict_value_declaration(state, direct_function)
            if call_type == MIR_TYPE_INTERFACE and callee_name_text == "iter":
                let iterator_declaration = mir_unique_iterator_declaration(state)
                if iterator_declaration >= 0:
                    return_declaration = iterator_declaration
            mir_state_set_struct_declaration(state, result_value, return_declaration)
        mir_int_list_set(state.hir_value_map, node_id, result_value)
        return result_value
    if opcode == HIR_OP_STRUCT:
        let declaration_index = mir_hir_node_struct_declaration(hir, node_id)
        if declaration_index < 0:
            declaration_index = find_struct_declaration_index(state.source, hir.records[offset + 3],
                hir.records[offset + 4], hir.records[offset + 3])
        let struct_payload_start = hir.records[offset + 5]
        let struct_payload_count = hir.records[offset + 6]
        if struct_payload_count >= 5:
            let literal_count_offset = hir_value_offset(struct_payload_start + 4)
            if hir.values[literal_count_offset] == HIR_VALUE_INT:
                let literal_count = hir.values[literal_count_offset + 1]
                if literal_count >= 0 and struct_payload_count >= 5 + literal_count:
                    let struct_field_values: list[int] = []
                    let struct_lower_failed = false
                    let field_position = 0
                    while field_position < literal_count and not struct_lower_failed:
                        let value_offset = hir_value_offset(struct_payload_start + 5 + field_position)
                        if hir.values[value_offset] != HIR_VALUE_NODE:
                            struct_lower_failed = true
                        else:
                            let child_value = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
                            if child_value < 0:
                                struct_lower_failed = true
                            else:
                                append(struct_field_values, child_value)
                        field_position = field_position + 1
                    if not struct_lower_failed:
                        let struct_operand_start = mir_value_count(state.values)
                        let struct_field_index = 0
                        while struct_field_index < len(struct_field_values):
                            mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(struct_field_values,
                                struct_field_index))
                            struct_field_index = struct_field_index + 1
                        let struct_result = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
                        mir_state_append_instruction(state, MIR_OP_STRUCT, MIR_TYPE_STRUCT, struct_result,
                            struct_operand_start, mir_value_count(state.values) - struct_operand_start)
                        mir_state_set_struct_declaration(state, struct_result, declaration_index)
                        mir_int_list_set(state.hir_value_map, node_id, struct_result)
                        return struct_result
    if opcode == HIR_OP_FIELD:
        let field_payload_start = hir.records[offset + 5]
        let field_payload_count = hir.records[offset + 6]
        if field_payload_count >= 3:
            let base_offset = hir_value_offset(field_payload_start)
            let field_name_start_offset = hir_value_offset(field_payload_start + 1)
            let field_name_end_offset = hir_value_offset(field_payload_start + 2)
            let base_value = -1
            let is_simple_variant = false
            if (
                hir.values[field_name_start_offset] == HIR_VALUE_INT and
                hir.values[field_name_end_offset] == HIR_VALUE_INT
            ):
                let qualified_variant_index = mir_enum_variant_index(state,
                    hir.values[field_name_start_offset + 1], hir.values[field_name_end_offset + 1])
                if qualified_variant_index >= 0:
                    if state.enum_variant_payload_kinds[qualified_variant_index] == 0:
                        is_simple_variant = true
            if hir.values[base_offset] == HIR_VALUE_NODE and not is_simple_variant:
                base_value = mir_lower_hir_node(hir, hir.values[base_offset + 1], state)
            if (
                base_value >= 0 and
                hir.values[field_name_start_offset] == HIR_VALUE_INT and
                hir.values[field_name_end_offset] == HIR_VALUE_INT
            ):
                let field_name_start = hir.values[field_name_start_offset + 1]
                let field_name_end = hir.values[field_name_end_offset + 1]
                let field_declaration = mir_hir_node_struct_declaration(hir, hir.values[base_offset + 1])
                if field_declaration < 0:
                    field_declaration = mir_state_struct_declaration(state, base_value)
                if field_declaration < 0:
                    field_declaration = mir_struct_declaration_by_field(state, field_name_start, field_name_end)
                let field_slot = mir_struct_field_slot(state, field_declaration, field_name_start, field_name_end)
                let field_kind = mir_struct_field_kind(state, field_declaration, field_name_start, field_name_end)
                let field_type_declaration = mir_struct_field_type_declaration(state, field_declaration,
                    field_name_start, field_name_end)
                if field_slot < 0:
                    # Qualified no-payload enum variant: construct a simple enum value.
                    let idle_variant_index = mir_enum_variant_index(state, field_name_start, field_name_end)
                    if idle_variant_index >= 0:
                        if state.enum_variant_payload_kinds[idle_variant_index] != 0:
                            idle_variant_index = -1
                    if idle_variant_index >= 0:
                        let simple_tag = state.enum_variant_tags[idle_variant_index]
                        let simple_result = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, simple_result + 1)
                        let simple_call_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
                            MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_CREATE_SIMPLE)
                        mir_append_operand(state.values, MIR_OPERAND_INT, simple_tag)
                        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, simple_result, simple_call_start,
                            2)
                        mir_state_set_value_type(state, simple_result, MIR_TYPE_PTR)
                        mir_state_mark_enum_value(state, simple_result)
                        mir_int_list_set(state.hir_value_map, node_id, simple_result)
                        return simple_result
                if field_slot >= 0:
                    let field_type = MIR_TYPE_PTR
                    if field_kind == STRUCT_FIELD_INT:
                        field_type = MIR_TYPE_I32
                    if field_kind == STRUCT_FIELD_BOOL:
                        field_type = MIR_TYPE_BOOL
                    if field_kind == STRUCT_FIELD_FLOAT:
                        field_type = MIR_TYPE_F64
                    if field_kind == STRUCT_FIELD_STR:
                        field_type = MIR_TYPE_STR
                    if field_kind == STRUCT_FIELD_LIST_INT:
                        field_type = MIR_TYPE_LIST
                    if field_kind == STRUCT_FIELD_LIST_STR:
                        field_type = MIR_TYPE_LIST_PTR
                    if field_kind == STRUCT_FIELD_DICT:
                        field_type = MIR_TYPE_DICT
                    let field_result = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
                    let field_operand_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, base_value)
                    mir_append_operand(state.values, MIR_OPERAND_INT, field_slot)
                    mir_state_append_instruction(state, MIR_OP_FIELD, field_type, field_result, field_operand_start, 2)
                    mir_state_set_struct_declaration(state, field_result, field_type_declaration)
                    mir_int_list_set(state.hir_value_map, node_id, field_result)
                    return field_result
            if (
                base_value < 0 and
                hir.values[field_name_start_offset] == HIR_VALUE_INT and
                hir.values[field_name_end_offset] == HIR_VALUE_INT
            ):
                let variant_name_start = hir.values[field_name_start_offset + 1]
                let variant_name_end = hir.values[field_name_end_offset + 1]
                let variant_index = mir_enum_variant_index(state, variant_name_start, variant_name_end)
                if variant_index >= 0:
                    if state.enum_variant_payload_kinds[variant_index] != 0:
                        variant_index = -1
                if variant_index >= 0:
                    let simple_tag = state.enum_variant_tags[variant_index]
                    let simple_result = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, simple_result + 1)
                    let simple_call_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_SYMBOL,
                        MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_CREATE_SIMPLE)
                    mir_append_operand(state.values, MIR_OPERAND_INT, simple_tag)
                    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_PTR, simple_result, simple_call_start, 2)
                    mir_state_set_value_type(state, simple_result, MIR_TYPE_PTR)
                    mir_state_mark_enum_value(state, simple_result)
                    mir_int_list_set(state.hir_value_map, node_id, simple_result)
                    return simple_result
    if record_kind in [HIR_RECORD_BLOCK, HIR_RECORD_FUNCTION, HIR_RECORD_MODULE]:
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
                    # 泛型函数返回类型未知时按实际返回值类型回填（调用点与签名同步）
                    let current_fn = mir_int_list_get(state.func_index, 0)
                    if current_fn < len(state.functions.returns):
                        let current_return = mir_int_list_get(state.functions.returns, current_fn)
                        if current_return in [MIR_TYPE_UNKNOWN, MIR_TYPE_DYNAMIC]:
                            let return_value_type = mir_state_value_type(state, result)
                            if return_value_type not in [MIR_TYPE_UNKNOWN, MIR_TYPE_DYNAMIC]:
                                mir_int_list_set(state.functions.returns, current_fn, return_value_type)
                                let fn_offset = mir_int_list_get(state.current_func_record_offset, 0)
                                if (
                                    fn_offset >= 0 and
                                    fn_offset < len(state.records) and
                                    state.records[fn_offset] == MIR_RECORD_FUNCTION
                                ):
                                    let signature_start = state.records[fn_offset + 8]
                                    let signature_count = state.records[fn_offset + 9]
                                    if signature_count >= 1:
                                        let return_slot = mir_value_offset(signature_start + signature_count - 1)
                                        mir_int_list_set(state.values, return_slot + 1, return_value_type)
                    mir_state_append_terminator(state, MIR_TERM_RETURN, operand_start, 1)
                    return -1
        mir_state_append_terminator(state, MIR_TERM_RETURN, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_BREAK:
        if mir_int_list_get(state.loop_count, 0) > 0:
            let loop_index = mir_int_list_get(state.loop_count, 0) - 1
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, mir_int_list_get(state.loop_break_blocks, loop_index))
            mir_append_current_symbol_arguments(state, state.symbol_starts, state.symbol_ends,
                mir_int_list_get(state.loop_symbol_counts, loop_index))
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
        else:
            mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
        return -1
    if opcode == HIR_OP_CONTINUE:
        if mir_int_list_get(state.loop_count, 0) > 0:
            let loop_index = mir_int_list_get(state.loop_count, 0) - 1
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, mir_int_list_get(state.loop_continue_blocks,
                loop_index))
            mir_append_current_symbol_arguments(state, state.symbol_starts, state.symbol_ends,
                mir_int_list_get(state.loop_symbol_counts, loop_index))
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
        else:
            mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
        return -1
    if opcode in [HIR_OP_IF, HIR_OP_WHILE, HIR_OP_FOR, HIR_OP_MATCH]:
        return mir_lower_hir_control(hir, node_id, state, -1, -1, -1, -1)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    # 列表推导与列表字面量同为 HIR_OP_LIST，按载荷形态区分：
    # 推导载荷为 [iterable, var_start, var_end, cond, n1, n2, body]
    if opcode == HIR_OP_LIST and payload_count == 7:
        let var_start_offset = hir_value_offset(payload_start + 1)
        let var_end_offset = hir_value_offset(payload_start + 2)
        if hir.values[var_start_offset] == HIR_VALUE_INT and hir.values[var_end_offset] == HIR_VALUE_INT:
            return mir_lower_hir_list_comp(hir, node_id, state)
    if opcode == HIR_OP_BINARY:
        let iterator_result = mir_lower_iterator_contains(hir, node_id, state)
        if iterator_result >= 0:
            return iterator_result
    let child_kinds: list[int] = []
    let child_values: list[int] = []
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
        if opcode == HIR_OP_SLICE and payload_index == 1 and value_kind == HIR_VALUE_NONE:
            # [:n] 缺省下界补 0
            let zero_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, zero_value + 1)
            let zero_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, zero_value, zero_start, 1)
            append(child_kinds, MIR_OPERAND_VALUE)
            append(child_values, zero_value)
        payload_index = payload_index + 1
    # SLICE 无 end 时补 len(base) 作为 end
    if opcode == HIR_OP_SLICE and payload_count >= 3 and len(child_values) >= 2:
        let end_offset = hir_value_offset(payload_start + 2)
        if hir.values[end_offset] != HIR_VALUE_NODE:
            let len_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, len_value + 1)
            let len_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(child_values, 0))
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, len_value, len_start, 2)
            append(child_kinds, MIR_OPERAND_VALUE)
            append(child_values, len_value)
    if opcode == HIR_OP_BINARY and len(child_values) >= 3:
        let operator = mir_int_list_get(child_values, 0)
        let left_value = mir_int_list_get(child_values, 1)
        let right_value = mir_int_list_get(child_values, 2)
        if operator == IR_OPERATOR_ADD and mir_state_value_type(state, left_value) == MIR_TYPE_STR:
            let right_node_offset = hir_value_offset(payload_start + 2)
            if hir.values[right_node_offset] == HIR_VALUE_NODE:
                let right_node_id = hir.values[right_node_offset + 1]
                let right_declaration = mir_state_struct_declaration(state, right_value)
                if right_declaration < 0:
                    right_declaration = mir_hir_node_struct_declaration(hir, right_node_id)
                let display_function = mir_find_struct_method(state, right_declaration, "to_string")
                if display_function >= 0:
                    let display_value = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, display_value + 1)
                    let display_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, display_function)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, right_value)
                    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_STR, display_value, display_start, 2)
                    mir_int_list_set(child_values, 2, display_value)
    let operand_start = mir_value_count(state.values)
    let child_index = 0
    while child_index < len(child_kinds):
        mir_append_operand(state.values, mir_int_list_get(child_kinds, child_index), mir_int_list_get(child_values,
            child_index))
        child_index = child_index + 1
    # 枚举索引：status[0]=tag、status[1]=payload(int)
    if opcode == HIR_OP_INDEX and len(child_values) >= 2:
        let enum_index_value = -1
        if mir_state_is_enum_value(state, mir_int_list_get(child_values, 0)):
            if mir_int_list_get(child_kinds, 1) == MIR_OPERAND_INT:
                enum_index_value = mir_int_list_get(child_values, 1)
            else:
                enum_index_value = mir_const_value(state, mir_int_list_get(child_values, 1))
        if enum_index_value in [0, 1]:
            let enum_external = EXTERNAL_ID_ENUM_GET_TAG
            if enum_index_value == 1:
                enum_external = EXTERNAL_ID_ENUM_GET_INT
            let enum_result = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, enum_result + 1)
            let enum_call_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + enum_external)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(child_values, 0))
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, enum_result, enum_call_start, 2)
            mir_int_list_set(state.hir_value_map, node_id, enum_result)
            return enum_result
    let operand_count = mir_value_count(state.values) - operand_start
    let result_value = -1
    if record_kind in [HIR_RECORD_EXPRESSION, HIR_RECORD_PATTERN]:
        result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
    let result_type = mir_type_from_hir(hir.records[offset + 2])
    if opcode == HIR_OP_SLICE and len(child_values) > 0:
        let base_type = mir_state_value_type(state, mir_int_list_get(child_values, 0))
        if base_type == MIR_TYPE_STR:
            result_type = MIR_TYPE_STR
        elif base_type == MIR_TYPE_LIST:
            result_type = MIR_TYPE_LIST
        elif base_type == MIR_TYPE_LIST_PTR:
            result_type = MIR_TYPE_LIST_PTR
    if opcode == HIR_OP_LIST and result_type == MIR_TYPE_LIST_PTR:
        let all_scalar = true
        let element_index = 0
        while element_index < len(child_values):
            let element_type = mir_state_value_type(state, mir_int_list_get(child_values, element_index))
            if (
                element_type != MIR_TYPE_I32 and
                element_type != MIR_TYPE_F64 and
                element_type != MIR_TYPE_BOOL and
                element_type != MIR_TYPE_UNIT
            ):
                all_scalar = false
            element_index = element_index + 1
        if all_scalar:
            result_type = MIR_TYPE_LIST
    if opcode == HIR_OP_INDEX:
        result_type = mir_index_result_type(hir, node_id, state)
        if result_type == MIR_TYPE_PTR:
            result_type = MIR_TYPE_STR
    if opcode == HIR_OP_BINARY:
        result_type = mir_binary_result_type(hir, node_id, state)
    mir_state_append_instruction(state, mir_opcode_from_hir(opcode), result_type, result_value, operand_start,
        operand_count)
    mir_int_list_set(state.hir_value_map, node_id, result_value)
    return result_value

# for 循环展开：for var in iterable: body
# HIR 载荷 [var_start, var_end, iterable, body_block]
def mir_lower_hir_for(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 4:
        return -1
    let var_start = 0
    let var_end = 0
    let var_start_offset = hir_value_offset(payload_start)
    let var_end_offset = hir_value_offset(payload_start + 1)
    if hir.values[var_start_offset] == HIR_VALUE_INT and hir.values[var_end_offset] == HIR_VALUE_INT:
        var_start = hir.values[var_start_offset + 1]
        var_end = hir.values[var_end_offset + 1]
    let iterable = -1
    let iterable_offset = hir_value_offset(payload_start + 2)
    if hir.values[iterable_offset] == HIR_VALUE_NODE:
        iterable = mir_lower_hir_node(hir, hir.values[iterable_offset + 1], state)
    if iterable < 0:
        return -1
    let protocol_kind = 0
    let has_next_method = -1
    let next_method = -1
    let iterable_declaration = mir_state_struct_declaration(state, iterable)
    if iterable_declaration >= 0:
        let (detected_kind, first_method, second_method) = mir_impl_method_pair(state, iterable_declaration)
        protocol_kind = detected_kind
        has_next_method = first_method
        next_method = second_method
        if protocol_kind == 2:
            let iterator_result = mir_emit_impl_call(state, first_method, iterable)
            if iterator_result < 0:
                return -1
            let iterator_declaration = mir_func_return_struct_decl(hir, state, first_method)
            if iterator_declaration < 0:
                iterator_declaration = mir_unique_iterator_declaration(state)
            if iterator_declaration < 0:
                return -1
            mir_state_set_struct_declaration(state, iterator_result, iterator_declaration)
            let (iterator_kind, iterator_has_next, iterator_next) = mir_impl_method_pair(state, iterator_declaration)
            if iterator_kind != 1:
                return -1
            iterable = iterator_result
            has_next_method = iterator_has_next
            next_method = iterator_next
            protocol_kind = 1
    let body_block_id = -1
    let body_offset = hir_value_offset(payload_start + 3)
    if hir.values[body_offset] == HIR_VALUE_BLOCK:
        body_block_id = hir.values[body_offset + 1]
    # 内部变量伪名（var 之前的位置，避免与真实变量冲突）
    let iter_name_start = var_start - 2
    let iter_name_end = var_start - 1
    let index_name_start = var_start - 3
    let index_name_end = var_start - 2
    let zero_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, zero_value + 1)
    let zero_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, zero_value, zero_start, 1)
    mir_bind_symbol(state, iter_name_start, iter_name_end, iterable)
    mir_bind_symbol(state, index_name_start, index_name_end, zero_value)
    let base_count = mir_int_list_get(state.symbol_count, 0)
    let base_starts = mir_copy_symbols(state.symbol_starts)
    let base_ends = mir_copy_symbols(state.symbol_ends)
    let base_values = mir_copy_symbols(state.symbol_values)
    let header_block = mir_state_reserve_block(state)
    let body_block = mir_state_reserve_block(state)
    let step_block = mir_state_reserve_block(state)
    let exit_block = mir_state_reserve_block(state)
    let jump_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    # header：symbol phi
    mir_state_emit_block(state, header_block)
    mir_state_select_block(state, header_block)
    let symbol_index = 0
    while symbol_index < base_count:
        let header_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, header_value + 1)
        let base_value = mir_int_list_get(base_values, symbol_index)
        let header_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, header_block, header_type, header_value)
        mir_state_set_struct_declaration(state, header_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, symbol_index, header_value)
        symbol_index = symbol_index + 1
    let cmp_value = -1
    if protocol_kind == 1:
        cmp_value = mir_emit_impl_call(state, has_next_method, mir_find_symbol_value(state, iter_name_start,
            iter_name_end))
    else:
        let len_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, len_value + 1)
        let len_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, iter_name_start,
            iter_name_end))
        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, len_value, len_start, 2)
        cmp_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, cmp_value + 1)
        let cmp_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_LT)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start,
            index_name_end))
        mir_append_operand(state.values, MIR_OPERAND_VALUE, len_value)
        mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, cmp_value, cmp_start, 3)
    let branch_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, cmp_value)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, body_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, exit_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_INT, base_count)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
    # body：无 block 参数，元素绑定推导变量后执行语句块
    mir_state_emit_block(state, body_block)
    mir_state_select_block(state, body_block)
    let element_value = -1
    if protocol_kind == 1:
        element_value = mir_emit_impl_call(state, next_method, mir_find_symbol_value(state, iter_name_start,
            iter_name_end))
    else:
        element_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, element_value + 1)
        let element_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, iter_name_start,
            iter_name_end))
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start,
            index_name_end))
        mir_state_append_instruction(state, MIR_OP_INDEX, mir_list_element_type(state, iterable), element_value,
            element_start, 2)
    if element_value < 0:
        return -1
    mir_bind_symbol(state, var_start, var_end, element_value)
    mir_push_loop(state, exit_block, step_block, base_count)
    if body_block_id >= 0:
        mir_lower_hir_block(hir, body_block_id, state)
    mir_pop_loop(state)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        let back_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, step_block)
        mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
        mir_state_append_terminator(state, MIR_TERM_JUMP, back_start, mir_value_count(state.values) - back_start)

    mir_state_emit_block(state, step_block)
    mir_state_select_block(state, step_block)
    let step_symbol_index = 0
    while step_symbol_index < base_count:
        let step_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, step_value + 1)
        let base_value = mir_int_list_get(base_values, step_symbol_index)
        let step_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, step_block, step_type, step_value)
        mir_state_set_struct_declaration(state, step_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, step_symbol_index, step_value)
        step_symbol_index = step_symbol_index + 1
    if protocol_kind != 1:
        let next_index = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, next_index + 1)
        let inc_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_ADD)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start,
            index_name_end))
        mir_append_operand(state.values, MIR_OPERAND_INT, 1)
        mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_I32, next_index, inc_start, 3)
        mir_bind_symbol(state, index_name_start, index_name_end, next_index)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        let back_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
        mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
        mir_state_append_terminator(state, MIR_TERM_JUMP, back_start, mir_value_count(state.values) - back_start)
    # exit：symbol phi 恢复
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, exit_block)
    mir_state_select_block(state, exit_block)
    let exit_symbol_index = 0
    while exit_symbol_index < base_count:
        let exit_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, exit_value + 1)
        let base_value = mir_int_list_get(base_values, exit_symbol_index)
        let exit_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, exit_block, exit_type, exit_value)
        mir_state_set_struct_declaration(state, exit_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, exit_symbol_index, exit_value)
        exit_symbol_index = exit_symbol_index + 1
    mir_int_list_set(state.hir_value_map, node_id, -1)
    return -1

# 列表推导展开：list = [body for var in iterable if cond]
# HIR 载荷 [iterable, var_start, var_end, cond, n1, n2, body]
def mir_lower_hir_list_comp(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 7:
        return -1
    # HIR 载荷布局：[body, var_start, var_end, iterable, 0, 0, cond]
    let body_node = -1
    let body_offset = hir_value_offset(payload_start)
    if hir.values[body_offset] == HIR_VALUE_NODE:
        body_node = hir.values[body_offset + 1]
    let var_start = 0
    let var_end = 0
    let var_start_offset = hir_value_offset(payload_start + 1)
    let var_end_offset = hir_value_offset(payload_start + 2)
    if hir.values[var_start_offset] == HIR_VALUE_INT and hir.values[var_end_offset] == HIR_VALUE_INT:
        var_start = hir.values[var_start_offset + 1]
        var_end = hir.values[var_end_offset + 1]
    let iterable = -1
    let iterable_offset = hir_value_offset(payload_start + 3)
    if hir.values[iterable_offset] == HIR_VALUE_NODE:
        iterable = mir_lower_hir_node(hir, hir.values[iterable_offset + 1], state)
    if iterable < 0:
        return -1
    let cond_node = -1
    let cond_offset = hir_value_offset(payload_start + 6)
    if hir.values[cond_offset] == HIR_VALUE_NODE:
        cond_node = hir.values[cond_offset + 1]
    if body_node < 0:
        return -1
    # 结果列表：元素类型按 iterable 元素类型推断（指针元素用 LIST_PTR）
    let list_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, list_value + 1)
    let element_type = mir_list_element_type(state, iterable)
    let list_type = MIR_TYPE_LIST
    if element_type not in [
        MIR_TYPE_I32,
        MIR_TYPE_F64,
        MIR_TYPE_BOOL,
        MIR_TYPE_UNIT,
        MIR_TYPE_UNKNOWN,
        MIR_TYPE_DYNAMIC,
    ]:
        list_type = MIR_TYPE_LIST_PTR
    let list_start = mir_value_count(state.values)
    mir_state_append_instruction(state, MIR_OP_LIST, list_type, list_value, list_start, 0)
    # 内部变量伪名（var 之前的位置，避免与真实变量冲突）
    let list_name_start = var_start - 2
    let list_name_end = var_start - 1
    let iter_name_start = var_start - 3
    let iter_name_end = var_start - 2
    let index_name_start = var_start - 4
    let index_name_end = var_start - 3
    let zero_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, zero_value + 1)
    let zero_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, zero_value, zero_start, 1)
    mir_bind_symbol(state, list_name_start, list_name_end, list_value)
    mir_bind_symbol(state, iter_name_start, iter_name_end, iterable)
    mir_bind_symbol(state, index_name_start, index_name_end, zero_value)
    let base_count = mir_int_list_get(state.symbol_count, 0)
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
    # header：symbol phi
    mir_state_emit_block(state, header_block)
    mir_state_select_block(state, header_block)
    let symbol_index = 0
    while symbol_index < base_count:
        let header_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, header_value + 1)
        let base_value = mir_int_list_get(base_values, symbol_index)
        let header_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, header_block, header_type, header_value)
        mir_state_set_struct_declaration(state, header_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, symbol_index, header_value)
        symbol_index = symbol_index + 1
    # 条件：index < len(iterable)
    let len_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, len_value + 1)
    let len_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, iter_name_start, iter_name_end))
    mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, len_value, len_start, 2)
    let cmp_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, cmp_value + 1)
    let cmp_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_LT)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start, index_name_end))
    mir_append_operand(state.values, MIR_OPERAND_VALUE, len_value)
    mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, cmp_value, cmp_start, 3)
    let branch_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, cmp_value)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, body_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, exit_block)
    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_INT, base_count)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
    # body：无 block 参数（symbol 值沿用 header 的 phi）
    mir_state_emit_block(state, body_block)
    mir_state_select_block(state, body_block)
    # element = iterable[index]，绑定推导变量
    let element_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, element_value + 1)
    let element_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, iter_name_start, iter_name_end))
    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start, index_name_end))
    mir_state_append_instruction(state, MIR_OP_INDEX, mir_list_element_type(state, iterable), element_value,
        element_start, 2)
    mir_bind_symbol(state, var_start, var_end, element_value)
    # 条件满足才追加 body
    if cond_node >= 0:
        let cond_value = mir_lower_hir_node(hir, cond_node, state)
        let append_block = mir_state_reserve_block(state)
        let next_block = mir_state_reserve_block(state)
        let cond_branch_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, cond_value)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, append_block)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, next_block)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_append_operand(state.values, MIR_OPERAND_INT, base_count)
        mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
        mir_state_append_terminator(state, MIR_TERM_BRANCH, cond_branch_start,
            mir_value_count(state.values) - cond_branch_start)
        mir_state_emit_block(state, append_block)
        mir_state_select_block(state, append_block)
        let append_value = mir_lower_hir_node(hir, body_node, state)
        if append_value >= 0:
            let append_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, list_value)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, append_value)
            mir_state_append_runtime(state, MIR_RUNTIME_LIST_APPEND, append_start, 2)
        if mir_int_list_get(state.is_terminated, 0) == 0:
            let append_jump = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, next_block)
            mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
            mir_state_append_terminator(state, MIR_TERM_JUMP, append_jump, mir_value_count(state.values) - append_jump)
        mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
        mir_state_emit_block(state, next_block)
        mir_state_select_block(state, next_block)
        let next_symbol_index = 0
        while next_symbol_index < base_count:
            let next_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, next_value + 1)
            let base_value = mir_find_symbol_value(state, mir_int_list_get(state.symbol_starts, next_symbol_index),
                mir_int_list_get(state.symbol_ends, next_symbol_index))
            let next_type = mir_state_value_type(state, base_value)
            mir_state_append_block_parameter(state, next_block, next_type, next_value)
            mir_int_list_set(state.symbol_values, next_symbol_index, next_value)
            next_symbol_index = next_symbol_index + 1
    else:
        let append_value = mir_lower_hir_node(hir, body_node, state)
        if append_value >= 0:
            let append_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, list_value)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, append_value)
            mir_state_append_runtime(state, MIR_RUNTIME_LIST_APPEND, append_start, 2)
    # index = index + 1
    let next_index = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, next_index + 1)
    let inc_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_ADD)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_find_symbol_value(state, index_name_start, index_name_end))
    mir_append_operand(state.values, MIR_OPERAND_INT, 1)
    mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_I32, next_index, inc_start, 3)
    mir_bind_symbol(state, index_name_start, index_name_end, next_index)
    let back_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
    mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
    mir_state_append_terminator(state, MIR_TERM_JUMP, back_start, mir_value_count(state.values) - back_start)
    # exit：symbol phi 恢复
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, exit_block)
    mir_state_select_block(state, exit_block)
    let exit_symbol_index = 0
    while exit_symbol_index < base_count:
        let exit_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, exit_value + 1)
        let base_value = mir_int_list_get(base_values, exit_symbol_index)
        let exit_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, exit_block, exit_type, exit_value)
        mir_state_set_struct_declaration(state, exit_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, exit_symbol_index, exit_value)
        exit_symbol_index = exit_symbol_index + 1
    mir_int_list_set(state.hir_value_map, node_id, list_value)
    return list_value

def mir_lower_hir_loop(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 2:
        return -1
    let base_count = mir_int_list_get(state.symbol_count, 0)
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
        let header_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        append(header_values, header_value)
        let base_value = mir_int_list_get(base_values, symbol_index)
        let header_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, header_block, header_type, header_value)
        mir_state_set_struct_declaration(state, header_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, symbol_index, header_value)
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
    if mir_int_list_get(state.is_terminated, 0) == 0:
        let back_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, header_block)
        mir_append_current_symbol_arguments(state, base_starts, base_ends, base_count)
        mir_state_append_terminator(state, MIR_TERM_JUMP, back_start, mir_value_count(state.values) - back_start)

    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, exit_block)
    mir_state_select_block(state, exit_block)
    let exit_symbol_index = 0
    while exit_symbol_index < base_count:
        let exit_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        let base_value = mir_int_list_get(base_values, exit_symbol_index)
        let exit_type = mir_state_value_type(state, base_value)
        mir_state_append_block_parameter(state, exit_block, exit_type, exit_value)
        mir_state_set_struct_declaration(state, exit_value, mir_state_struct_declaration(state, base_value))
        mir_int_list_set(state.symbol_values, exit_symbol_index, exit_value)
        exit_symbol_index = exit_symbol_index + 1
    return -1

def mir_lower_hir_block(hir: HirProgram, block_id: int, state: MirLowerState) -> int:
    if block_id < 0 or block_id >= hir_record_count(hir.records):
        return -1
    let offset = hir_record_offset(block_id)
    if hir.records[offset] != HIR_RECORD_BLOCK:
        return -1
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    let block_result = -1
    let index = 0
    while index < payload_count:
        if mir_int_list_get(state.is_terminated, 0) != 0:
            let next_block = mir_state_reserve_block(state)
            mir_state_emit_block(state, next_block)
            mir_state_select_block(state, next_block)
        let value_id = payload_start + index
        let value_offset = hir_value_offset(value_id)
        if hir.values[value_offset] == HIR_VALUE_NODE:
            let node_result = mir_lower_hir_node(hir, hir.values[value_offset + 1], state)
            if node_result >= 0:
                block_result = node_result
        index = index + 1
    return block_result

# 模式展开：生成匹配条件（AND 组合）与变量绑定
# 支持字面量、变量、通配、列表 [a, b, c]、cons head :: tail、结构 Point{x: v}
def mir_expand_pattern(hir: HirProgram, pattern_id: int, subject: int, state: MirLowerState, conditions: list[int],
    bindings: list[int]):
    if pattern_id < 0 or pattern_id >= hir_record_count(hir.records):
        return
    let offset = hir_record_offset(pattern_id)
    let opcode = hir.records[offset + 1]
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if opcode == HIR_OP_NONE:
        return
    if opcode == HIR_OP_LITERAL:
        let pattern_value = mir_lower_hir_node(hir, pattern_id, state)
        mir_append_pattern_equality(state, subject, pattern_value, conditions)
        return
    if opcode == HIR_OP_ENUM:
        # 枚举模式 Enum.Variant(payload) / 内建 Some(x)/Ok(x)/Err(_)/None:
        # 先比较 tag,再提取 payload 绑定到模式变量
        let variant_tag = -1
        let variant_payload_kind = -1
        let pattern_payload_start = -1
        let pattern_payload_end = -1
        let payload_range_is_token_index = false
        let enum_get_external = -1
        if payload_count >= 6:
            let enum_name_start = hir.values[hir_value_offset(payload_start) + 1]
            let enum_name_end = hir.values[hir_value_offset(payload_start + 1) + 1]
            let enum_name_text = state.source[enum_name_start:enum_name_end]
            let variant_name_start = hir.values[hir_value_offset(payload_start + 2) + 1]
            let variant_name_end = hir.values[hir_value_offset(payload_start + 3) + 1]
            let variant_name_text = state.source[variant_name_start:variant_name_end]
            let probe_index = mir_enum_variant_index(state, hir.values[hir_value_offset(payload_start + 2) + 1],
                hir.values[hir_value_offset(payload_start + 3) + 1])
            if probe_index >= 0:
                variant_tag = state.enum_variant_tags[probe_index]
                variant_payload_kind = state.enum_variant_payload_kinds[probe_index]
            pattern_payload_start = hir.values[hir_value_offset(payload_start + 4) + 1]
            pattern_payload_end = hir.values[hir_value_offset(payload_start + 5) + 1]
            payload_range_is_token_index = true
            enum_get_external = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_TAG
        elif payload_count == 3:
            variant_tag = hir.values[hir_value_offset(payload_start) + 1]
            pattern_payload_start = hir.values[hir_value_offset(payload_start + 1) + 1]
            pattern_payload_end = hir.values[hir_value_offset(payload_start + 2) + 1]
            # 内建变体 None/Err 同 tag=1，按 record 名区分载荷
            let builtin_probe = mir_enum_variant_index(state, hir.records[offset + 9], hir.records[offset + 10])
            if builtin_probe >= 0:
                variant_payload_kind = state.enum_variant_payload_kinds[builtin_probe]
            elif variant_tag == 1:
                variant_payload_kind = 0
            else:
                variant_payload_kind = 1
            enum_get_external = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_TAG
        if variant_tag >= 0 and subject >= 0:
            # tag 比较:__c_enum_get_tag(subject) == tag
            let tag_call = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, tag_call + 1)
            let tag_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_TAG)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
            mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, tag_call, tag_start, 2)
            let tag_const = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, tag_const + 1)
            let tag_const_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, variant_tag)
            mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, tag_const, tag_const_start, 1)
            mir_append_pattern_equality(state, tag_call, tag_const, conditions)
            # 单载荷变体:区间内的绑定名(非 _)提取 payload 值
            if variant_payload_kind > 0 and pattern_payload_start >= 0:
                mir_state_ensure_tokens(state)
                let bind_kinds = state.lex_kinds
                let bind_starts = state.lex_starts
                let bind_ends = state.lex_ends
                let get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_INT
                if variant_payload_kind == 3:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_STRING
                let payload_type = MIR_TYPE_I32
                if variant_payload_kind == 2:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_FLOAT
                    payload_type = MIR_TYPE_F64
                if variant_payload_kind == 4:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_BOOL
                    payload_type = MIR_TYPE_BOOL
                if variant_payload_kind == 3:
                    payload_type = MIR_TYPE_STR
                if variant_payload_kind == 5:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_DATA
                    payload_type = MIR_TYPE_LIST_PTR
                if variant_payload_kind == 6:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_DATA
                    payload_type = MIR_TYPE_PTR
                if variant_payload_kind == 7:
                    get_id = MIR_EXTERNAL_BASE + EXTERNAL_ID_ENUM_GET_DATA
                    payload_type = MIR_TYPE_DICT
                let payload_value = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, payload_value + 1)
                let payload_start_offset = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_SYMBOL, get_id)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
                mir_state_append_instruction(state, MIR_OP_CALL, payload_type, payload_value, payload_start_offset, 2)
                let token_cursor = 0
                while token_cursor < len(bind_kinds):
                    let in_payload_range = false
                    if payload_range_is_token_index:
                        in_payload_range = token_cursor >= pattern_payload_start and token_cursor < pattern_payload_end
                    else:
                        in_payload_range = (
                            bind_starts[token_cursor] >= pattern_payload_start and
                            bind_starts[token_cursor] < pattern_payload_end
                        )
                    if in_payload_range and token_kind(bind_kinds, token_cursor) == TOKEN_IDENTIFIER:
                        let bind_name = state.source[bind_starts[token_cursor]:bind_ends[token_cursor]]
                        if bind_name != "_":
                            append(bindings, bind_starts[token_cursor])
                            append(bindings, bind_ends[token_cursor])
                            append(bindings, payload_value)
                        break
                    token_cursor = token_cursor + 1
        return
    if opcode == HIR_OP_LOCAL:
        # 命名常量标签（如 case ASCII_PLUS:）按常量值生成比较；
        # 未命中常量池的标识符才是绑定模式（枚举/列表载荷变量）
        let constant_index = mir_find_constant_index(state, hir.records[offset + 3], hir.records[offset + 4],
            hir.records[offset + 3])
        if constant_index >= 0:
            let constant_type = mir_type_from_constant(mir_int_list_get(state.constants.types, constant_index))
            if constant_type == MIR_TYPE_I32:
                let const_value = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, const_value + 1)
                let operand_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, mir_int_list_get(state.constants.values,
                    constant_index))
                mir_state_append_instruction(state, MIR_OP_CONST, constant_type, const_value, operand_start, 1)
                mir_append_pattern_equality(state, subject, const_value, conditions)
                return
        append(bindings, hir.records[offset + 3])
        append(bindings, hir.records[offset + 4])
        append(bindings, subject)
        return
    # 复杂模式：重新 lex 源码提取子模式信息
    mir_state_ensure_tokens(state)
    let kinds = state.lex_kinds
    let starts = state.lex_starts
    let ends = state.lex_ends
    if opcode == HIR_OP_LIST and payload_count == 2:
        # 列表模式 [a, b, c]：长度匹配 + 元素绑定
        let first_token = hir.values[hir_value_offset(payload_start) + 1]
        let last_token = hir.values[hir_value_offset(payload_start + 1) + 1]
        let element_tokens: list[int] = []
        let scan_token = first_token
        while scan_token < last_token:
            let tk = token_kind(kinds, scan_token)
            if tk in [TOKEN_IDENTIFIER, TOKEN_INTEGER, TOKEN_RUNE, TOKEN_MINUS]:
                append(element_tokens, scan_token)
            scan_token = scan_token + 1
        let len_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, len_value + 1)
        let len_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, len_value, len_start, 2)
        let count_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, count_value + 1)
        let count_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, len(element_tokens))
        mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, count_value, count_start, 1)
        let cmp_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, cmp_value + 1)
        let cmp_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_EQ)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, len_value)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, count_value)
        mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, cmp_value, cmp_start, 3)
        append(conditions, cmp_value)
        let element_index = 0
        while element_index < len(element_tokens):
            let element_token = mir_int_list_get(element_tokens, element_index)
            let tk = token_kind(kinds, element_token)
            let sub_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, sub_value + 1)
            let sub_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
            mir_append_operand(state.values, MIR_OPERAND_INT, element_index)
            mir_state_append_instruction(state, MIR_OP_INDEX, MIR_TYPE_I32, sub_value, sub_start, 2)
            if tk == TOKEN_IDENTIFIER:
                let element_name = state.source[token_start(starts, element_token):token_end(ends, element_token)]
                if element_name != "_":
                    append(bindings, token_start(starts, element_token))
                    append(bindings, token_end(ends, element_token))
                    append(bindings, sub_value)
            element_index = element_index + 1
        return
    if opcode == HIR_OP_LIST and payload_count == 4:
        # cons 模式 head :: tail
        let len_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, len_value + 1)
        let len_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_SYMBOL, MIR_EXTERNAL_BASE + EXTERNAL_ID_LEN)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
        mir_state_append_instruction(state, MIR_OP_CALL, MIR_TYPE_I32, len_value, len_start, 2)
        let zero_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, zero_value + 1)
        let zero_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, zero_value, zero_start, 1)
        let cmp_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, cmp_value + 1)
        let cmp_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_GT)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, len_value)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, zero_value)
        mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, cmp_value, cmp_start, 3)
        append(conditions, cmp_value)
        let head_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, head_value + 1)
        let head_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_state_append_instruction(state, MIR_OP_INDEX, MIR_TYPE_I32, head_value, head_start, 2)
        append(bindings, hir.values[hir_value_offset(payload_start) + 1])
        append(bindings, hir.values[hir_value_offset(payload_start + 1) + 1])
        append(bindings, head_value)
        let tail_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, tail_value + 1)
        let tail_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
        mir_append_operand(state.values, MIR_OPERAND_INT, 1)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, len_value)
        mir_state_append_instruction(state, MIR_OP_SLICE, MIR_TYPE_LIST, tail_value, tail_start, 3)
        append(bindings, hir.values[hir_value_offset(payload_start + 2) + 1])
        append(bindings, hir.values[hir_value_offset(payload_start + 3) + 1])
        append(bindings, tail_value)
        return
    if opcode == HIR_OP_STRUCT:
        # 结构模式 Point{x: left, y: right}
        # payload: [类型名start, 类型名end, 字段token_start, 字段token_end, 字段起点, 字段终点]
        let type_name_start = hir.values[hir_value_offset(payload_start) + 1]
        let type_name_end = hir.values[hir_value_offset(payload_start + 1) + 1]
        let field_token_start = hir.values[hir_value_offset(payload_start + 2) + 1]
        let field_token_end = hir.values[hir_value_offset(payload_start + 3) + 1]
        let declaration_index = find_struct_declaration_index(state.source, type_name_start, type_name_end,
            type_name_start)
        if declaration_index >= 0:
            let scan_token = field_token_start
            while scan_token < field_token_end:
                if token_kind(kinds, scan_token) == TOKEN_IDENTIFIER:
                    let field_name_start = token_start(starts, scan_token)
                    let field_name_end = token_end(ends, scan_token)
                    let field_slot = mir_struct_field_slot(state, declaration_index, field_name_start, field_name_end)
                    if field_slot >= 0:
                        let field_value = mir_int_list_get(state.next_value, 0)
                        mir_int_list_set(state.next_value, 0, field_value + 1)
                        let field_operand_start = mir_value_count(state.values)
                        mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
                        mir_append_operand(state.values, MIR_OPERAND_INT, field_slot)
                        let field_type = MIR_TYPE_PTR
                        let field_kind = mir_struct_field_kind(state, declaration_index, field_name_start,
                            field_name_end)
                        if field_kind == STRUCT_FIELD_INT:
                            field_type = MIR_TYPE_I32
                        if field_kind == STRUCT_FIELD_BOOL:
                            field_type = MIR_TYPE_BOOL
                        if field_kind == STRUCT_FIELD_FLOAT:
                            field_type = MIR_TYPE_F64
                        if field_kind == STRUCT_FIELD_STR:
                            field_type = MIR_TYPE_STR
                        if field_kind in [STRUCT_FIELD_LIST_INT, STRUCT_FIELD_LIST_STR]:
                            field_type = MIR_TYPE_LIST
                        mir_state_append_instruction(state, MIR_OP_FIELD, field_type, field_value, field_operand_start,
                            2)
                        let value_token = scan_token + 1
                        while value_token < field_token_end and token_kind(kinds, value_token) != TOKEN_COLON:
                            value_token = value_token + 1
                        if value_token < field_token_end:
                            let name_token = value_token + 1
                            if token_kind(kinds, name_token) == TOKEN_IDENTIFIER:
                                let bind_name = state.source[token_start(starts, name_token):token_end(ends,
                                    name_token)]
                                if bind_name != "_":
                                    append(bindings, token_start(starts, name_token))
                                    append(bindings, token_end(ends, name_token))
                                    append(bindings, field_value)
                scan_token = scan_token + 1
        return

def mir_append_pattern_equality(state: MirLowerState, subject: int, pattern_value: int, conditions: list[int]):
    # 生成 subject == pattern_value 的布尔比较并登记为匹配条件
    let cmp_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, cmp_value + 1)
    let cmp_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_EQ)
    mir_append_operand(state.values, MIR_OPERAND_VALUE, subject)
    if pattern_value >= 0:
        mir_append_operand(state.values, MIR_OPERAND_VALUE, pattern_value)
    else:
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, cmp_value, cmp_start, 3)
    append(conditions, cmp_value)

def mir_enum_builtin_tag(name_start: int, name_end: int, state: MirLowerState) -> int:
    # 内建 Option/Result 变体的固定 tag；非内建返回 -1
    let name = state.source[name_start:name_end]
    if name in ["Some", "Ok"]:
        return 0
    if name in ["None", "Err"]:
        return 1
    return -1

def mir_enum_builtin_payload_kind(name_start: int, name_end: int, state: MirLowerState) -> int:
    # 0=simple 1=int 2=float 3=string 4=bool；None 为 simple，其余带一个值
    let name = state.source[name_start:name_end]
    if name == "None":
        return 0
    return 1

def mir_enum_scan_declarations(state: MirLowerState):
    # 内建 Option/Result 变体预注册（用户源码中的同名变体会被去重跳过）
    append(state.enum_variant_name_starts, -4)
    append(state.enum_variant_name_ends, -3)
    append(state.enum_variant_tags, 0)
    append(state.enum_variant_payload_kinds, 1)
    append(state.enum_variant_name_starts, -2)
    append(state.enum_variant_name_ends, -1)
    append(state.enum_variant_tags, 1)
    append(state.enum_variant_payload_kinds, 0)
    append(state.enum_variant_name_starts, -6)
    append(state.enum_variant_name_ends, -5)
    append(state.enum_variant_tags, 0)
    append(state.enum_variant_payload_kinds, 1)
    append(state.enum_variant_name_starts, -8)
    append(state.enum_variant_name_ends, -7)
    append(state.enum_variant_tags, 1)
    append(state.enum_variant_payload_kinds, 1)
    # 扫描源码中的 enum 声明，登记变体名到 tag/payload 类型的映射（tag 按声明序全局递增）
    mir_state_ensure_tokens(state)
    let kinds = state.lex_kinds
    let starts = state.lex_starts
    let ends = state.lex_ends
    let next_tag = 0
    let index = 0
    while token_kind(kinds, index) != TOKEN_EOF:
        if (
            (token_kind(kinds, index) == TOKEN_IDENTIFIER and
            state.source[token_start(starts, index):token_end(ends, index)] == "enum" and
            token_kind(kinds, index + 1) == TOKEN_IDENTIFIER and
            token_kind(kinds, index + 2) == TOKEN_COLON)
        ):
            let row = index + 3
            while token_kind(kinds, row) != TOKEN_EOF:
                if token_kind(kinds, row) != TOKEN_NEWLINE:
                    if line_indent(state.source, token_start(starts, row)) == 0:
                        break
                    if token_kind(kinds, row) == TOKEN_IDENTIFIER:
                        append(state.enum_variant_name_starts, token_start(starts, row))
                        append(state.enum_variant_name_ends, token_end(ends, row))
                        let payload_kind = 0
                        let payload_scan = row + 1
                        if token_kind(kinds, payload_scan) == TOKEN_OPEN_PAREN:
                            let type_token = payload_scan + 1
                            if token_kind(kinds, type_token) == TOKEN_IDENTIFIER:
                                let type_text = state.source[token_start(starts, type_token):token_end(ends,
                                    type_token)]
                                if type_text == "int":
                                    payload_kind = 1
                                if type_text == "float":
                                    payload_kind = 2
                                if type_text == "str":
                                    payload_kind = 3
                                if type_text == "bool":
                                    payload_kind = 4
                                if type_text == "list":
                                    payload_kind = 5
                                if type_text == "dict":
                                    payload_kind = 7
                                if type_text not in ["int", "float", "str", "bool", "list", "dict"]:
                                    payload_kind = 6
                        append(state.enum_variant_tags, next_tag)
                        append(state.enum_variant_payload_kinds, payload_kind)
                        next_tag = next_tag + 1
                        let row_end = row
                        while token_kind(kinds, row_end) not in [TOKEN_NEWLINE, TOKEN_EOF]:
                            row_end = row_end + 1
                        row = row_end
                        continue
                row = row + 1
        index = index + 1

def mir_enum_create_external_id(payload_kind: int) -> int:
    # payload kind → enum_create_* 的 external id
    if payload_kind == 1:
        return EXTERNAL_ID_ENUM_CREATE_INT
    if payload_kind == 2:
        return EXTERNAL_ID_ENUM_CREATE_FLOAT
    if payload_kind == 3:
        return EXTERNAL_ID_ENUM_CREATE_STRING
    if payload_kind == 4:
        return EXTERNAL_ID_ENUM_CREATE_BOOL
    if payload_kind in [5, 6, 7]:
        return EXTERNAL_ID_ENUM_CREATE_TUPLE_PTR
    return EXTERNAL_ID_ENUM_CREATE_SIMPLE

def mir_enum_variant_index(state: MirLowerState, name_start: int, name_end: int) -> int:
    if name_start < 0 or name_end <= name_start or name_end > state.source.len():
        return -1
    let name_text = state.source[name_start:name_end]
    if name_text == "Some":
        return 0
    if name_text == "None":
        return 1
    if name_text == "Ok":
        return 2
    if name_text == "Err":
        return 3
    let index = 0
    while index < len(state.enum_variant_tags):
        let name_start = state.enum_variant_name_starts[index]
        let name_end = state.enum_variant_name_ends[index]
        if name_start >= 0 and name_end > name_start and state.source[name_start:name_end] == name_text:
            return index
        index = index + 1
    return -1

def named_return_slot_for_target(state: MirLowerState, target_fn: int) -> int:
    # 按目标函数索引查 named_ref_return_types 的槽位；未命中 -1
    let index = 0
    while index < len(state.named_ref_return_types):
        if state.named_ref_targets[index] == target_fn:
            return index
        index = index + 1
    return -1

def mir_find_named_ref_target(state: MirLowerState, name_start: int, name_end: int) -> int:
    # 按名字查已登记的函数引用（let f = increment / let c = lambda ...）
    let index = 0
    while index < len(state.named_ref_name_starts):
        let named_ref_start = state.named_ref_name_starts[index]
        let named_ref_end = state.named_ref_name_ends[index]
        if state.source[named_ref_start:named_ref_end] == state.source[name_start:name_end]:
            return index
        index = index + 1
    return -1

def mir_find_func_ref(state: MirLowerState, value: int) -> int:
    # 值是否持有函数引用；是则返回目标 func_index，否则 -1
    let index = 0
    while index < len(state.func_ref_values):
        if mir_int_list_get(state.func_ref_values, index) == value:
            return mir_int_list_get(state.func_ref_targets, index)
        index = index + 1
    return -1

def mir_find_func_ref_index(state: MirLowerState, value: int) -> int:
    # 按值查函数引用登记表；未登记返回 -1
    let index = 0
    while index < len(state.func_ref_values):
        if mir_int_list_get(state.func_ref_values, index) == value:
            return index
        index = index + 1
    return -1

def mir_lambda_annotation_type(state: MirLowerState, text_start: int, text_end: int) -> int:
    let annotation = state.source[text_start:text_end]
    if annotation == "int":
        return MIR_TYPE_I32
    if annotation == "bool":
        return MIR_TYPE_BOOL
    if annotation == "float":
        return MIR_TYPE_F64
    if annotation == "str":
        return MIR_TYPE_STR
    if annotation == "list[int]":
        return MIR_TYPE_LIST
    if annotation == "list[str]":
        return MIR_TYPE_LIST_PTR
    return MIR_TYPE_PTR

def mir_lambda_explicit_params(state: MirLowerState, params_token_start: int, params_token_end: int,
    explicit_name_starts: list[int], explicit_name_ends: list[int], explicit_types: list[int]):
    # 解析 lambda 参数 token 区间：name : Type, name : Type
    mir_state_ensure_tokens(state)
    let param_kinds = state.lex_kinds
    let param_starts = state.lex_starts
    let param_ends = state.lex_ends
    let cursor = params_token_start
    while cursor < params_token_end:
        if token_kind(param_kinds, cursor) != TOKEN_IDENTIFIER:
            cursor = cursor + 1
            continue
        append(explicit_name_starts, token_start(param_starts, cursor))
        append(explicit_name_ends, token_end(param_ends, cursor))
        let type_scan = cursor + 1
        if token_kind(param_kinds, type_scan) == TOKEN_COLON:
            type_scan = type_scan + 1
        let annotation_depth = 0
        let annotation_start = -1
        let annotation_end = -1
        while type_scan < params_token_end:
            let scan_kind = token_kind(param_kinds, type_scan)
            if scan_kind in [TOKEN_OPEN_BRACKET, TOKEN_OPEN_PAREN, TOKEN_OPEN_BRACE]:
                annotation_depth = annotation_depth + 1
            if scan_kind in [TOKEN_CLOSE_BRACKET, TOKEN_CLOSE_PAREN, TOKEN_CLOSE_BRACE]:
                if annotation_depth > 0:
                    annotation_depth = annotation_depth - 1
            if annotation_depth == 0 and scan_kind == TOKEN_COMMA:
                break
            if annotation_depth == 0 and scan_kind == TOKEN_CLOSE_PAREN:
                break
            if annotation_start < 0:
                annotation_start = type_scan
            annotation_end = type_scan + 1
            type_scan = type_scan + 1
        if annotation_start >= 0 and annotation_end > annotation_start:
            append(explicit_types, mir_lambda_annotation_type(state, param_starts[annotation_start],
                param_ends[annotation_end - 1]))
        else:
            append(explicit_types, MIR_TYPE_PTR)
        if type_scan < params_token_end and token_kind(param_kinds, type_scan) == TOKEN_COMMA:
            cursor = type_scan + 1
        else:
            cursor = params_token_end


def mir_infer_lambda_body_type(hir: HirProgram, node_id: int, state: MirLowerState, explicit_name_starts: list[int],
    explicit_name_ends: list[int], explicit_types: list[int], depth: int) -> int:
    # 静态回推 lambda 体类型：LOCAL 匹配显式参数注解、LITERAL 取自身、BINARY 取操作数
    if node_id < 0 or depth > 6:
        return -1
    let offset = hir_record_offset(node_id)
    let opcode = hir.records[offset + 1]
    if opcode == HIR_OP_LOCAL and len(explicit_name_starts) > 0:
        let name_start = hir.records[offset + 3]
        let name_end = hir.records[offset + 4]
        let name_text = state.source[name_start:name_end]
        let match_index = 0
        while match_index < len(explicit_name_starts):
            let explicit_start = mir_int_list_get(explicit_name_starts, match_index)
            let explicit_end = mir_int_list_get(explicit_name_ends, match_index)
            if state.source[explicit_start:explicit_end] == name_text:
                return mir_int_list_get(explicit_types, match_index)
            match_index = match_index + 1
        return -1
    let node_type = mir_type_from_hir(hir.records[offset + 2])
    if node_type not in [MIR_TYPE_DYNAMIC, MIR_TYPE_UNKNOWN, MIR_TYPE_UNIT]:
        return node_type
    let payload_start = hir.records[offset + 5]
    if opcode == HIR_OP_IF and hir.records[offset + 6] >= 3:
        let then_node = hir.values[hir_value_offset(payload_start + 1) + 1]
        let then_result = mir_infer_lambda_body_type(hir, then_node, state, explicit_name_starts, explicit_name_ends,
            explicit_types, depth + 1)
        if then_result >= 0:
            return then_result
        let else_node = hir.values[hir_value_offset(payload_start + 2) + 1]
        return mir_infer_lambda_body_type(hir, else_node, state, explicit_name_starts, explicit_name_ends,
            explicit_types, depth + 1)
    if opcode == HIR_OP_BINARY and hir.records[offset + 6] >= 3:
        let left_node = hir.values[hir_value_offset(payload_start + 1) + 1]
        let left_result = mir_infer_lambda_body_type(hir, left_node, state, explicit_name_starts, explicit_name_ends,
            explicit_types, depth + 1)
        if left_result >= 0:
            return left_result
        let right_node = hir.values[hir_value_offset(payload_start + 2) + 1]
        return mir_infer_lambda_body_type(hir, right_node, state, explicit_name_starts, explicit_name_ends,
            explicit_types, depth + 1)
    return -1


def mir_analyze_lambda(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    # 第一遍（定义点）：解析签名、收集自由变量、登记合成函数元数据；
    # 返回分配的 func_index。此时即可支撑调用点的静态展开。
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let params_token_start = hir.values[hir_value_offset(payload_start) + 1]
    let params_token_end = hir.values[hir_value_offset(payload_start + 1) + 1]
    let body_node = -1
    let body_offset = hir_value_offset(payload_start + 2)
    if hir.values[body_offset] == HIR_VALUE_NODE:
        body_node = hir.values[body_offset + 1]
    let explicit_name_starts: list[int] = []
    let explicit_name_ends: list[int] = []
    let explicit_types: list[int] = []
    mir_lambda_explicit_params(state, params_token_start, params_token_end, explicit_name_starts, explicit_name_ends,
        explicit_types)

    let body_source_start = -1
    let body_source_end = -1
    let body_return_type = MIR_TYPE_UNIT
    if body_node >= 0:
        let body_node_offset = hir_record_offset(body_node)
        body_source_start = hir.records[body_node_offset + 3]
        body_source_end = hir.records[body_node_offset + 4]
        body_return_type = mir_type_from_hir(hir.records[body_node_offset + 2])
        # HIR infer 未传播 lambda 参数类型时（BINARY 常为 DYNAMIC），
        # 按 BINARY 操作数静态回推：LOCAL 命中显式参数注解、字面量取自身类型
        if body_return_type in [MIR_TYPE_DYNAMIC, MIR_TYPE_UNIT]:
            let guessed = mir_infer_lambda_body_type(hir, body_node, state, explicit_name_starts, explicit_name_ends,
                explicit_types, 0)
            if guessed > 0:
                body_return_type = guessed
    # 合成节点（BINARY 等）无源码区间时退化为 lambda 整体区间，供捕获扫描定位
    if body_source_start == 0 and body_source_end == 0:
        body_source_start = hir.records[offset + 3]
        body_source_end = hir.records[offset + 4]

    let fn_index = len(state.functions.starts)
    append(state.functions.starts, hir.records[offset + 3])
    append(state.functions.ends, hir.records[offset + 4])
    append(state.functions.returns, body_return_type)
    let capture_pair_base = len(state.functions.capture_name_starts)

    # 精确捕获：扫描 body 源码区间内的标识符，过滤显式参数、函数与常量后，
    # 命中外层符号表的才是自由变量（按值捕获）
    let capture_name_starts: list[int] = []
    let capture_name_ends: list[int] = []
    let capture_type_list: list[int] = []
    if body_node >= 0:
        mir_state_ensure_tokens(state)
        let scan_kinds = state.lex_kinds
        let scan_starts = state.lex_starts
        let scan_ends = state.lex_ends
        let scan_index = 0
        while scan_index < len(scan_kinds) and scan_starts[scan_index] < body_source_end:
            if scan_starts[scan_index] >= body_source_start and token_kind(scan_kinds, scan_index) == TOKEN_IDENTIFIER:
                let name_start = scan_starts[scan_index]
                let name_end = scan_ends[scan_index]
                let is_explicit_parameter = false
                let known_index = 0
                while known_index < len(explicit_name_starts):
                    if mir_int_list_get(explicit_name_starts,
                        known_index) == name_start and mir_int_list_get(explicit_name_ends, known_index) == name_end:
                        is_explicit_parameter = true
                    known_index = known_index + 1
                let already_collected = false
                let dedup_index = 0
                while dedup_index < len(capture_name_starts):
                    if capture_name_starts[dedup_index] == name_start and capture_name_ends[dedup_index] == name_end:
                        already_collected = true
                    dedup_index = dedup_index + 1
                if not is_explicit_parameter and not already_collected:
                    let is_named_function = mir_find_function(state, name_start, name_end,
                        name_start) >= 0
                    let is_named_constant = mir_find_constant_index(state, name_start, name_end,
                        name_start) >= 0
                    if not is_named_function and not is_named_constant:
                        let outer_value = mir_find_symbol_value(state, name_start, name_end)
                        if outer_value >= 0:
                            append(capture_name_starts, name_start)
                            append(capture_name_ends, name_end)
                            let captured_type = MIR_TYPE_I32
                            if outer_value < len(state.value_types):
                                captured_type = state.value_types[outer_value]
                            append(capture_type_list, captured_type)
            scan_index = scan_index + 1

    # capture_counts 按 fn_index 对齐（此前函数无捕获时补零占位，emit 按 fn_index 读捕获数）
    while len(state.functions.capture_counts) < fn_index:
        append(state.functions.capture_counts, 0)
    let capture_index = 0
    while capture_index < len(capture_name_starts):
        append(state.functions.capture_name_starts, capture_name_starts[capture_index])
        append(state.functions.capture_name_ends, capture_name_ends[capture_index])
        append(state.functions.capture_types, capture_type_list[capture_index])
        capture_index = capture_index + 1
    append(state.functions.capture_counts, len(capture_name_starts))
    return fn_index

def mir_lower_hir_lambda(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    # 表达式结果：函数引用值（CONST 携带函数索引，调用点据此静态展开直接调用），
    # 函数体推迟到全部源码函数降级完成后统一生成（mir_emit_lambda_body）
    let fn_index = mir_analyze_lambda(hir, node_id, state)
    let reference_value = mir_int_list_get(state.next_value, 0)
    mir_int_list_set(state.next_value, 0, reference_value + 1)
    let reference_operand_start = mir_value_count(state.values)
    mir_append_operand(state.values, MIR_OPERAND_INT, fn_index)
    mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_I32, reference_value, reference_operand_start, 1)
    append(state.func_ref_values, reference_value)
    append(state.func_ref_targets, fn_index)
    let lambda_offset = hir_record_offset(node_id)
    append(state.named_ref_name_starts, hir.records[lambda_offset + 3])
    append(state.named_ref_name_ends, hir.records[lambda_offset + 4])
    append(state.named_ref_targets, fn_index)
    append(state.named_ref_return_types, mir_int_list_get(state.functions.returns, fn_index))
    append(state.pending_lambda_nodes, node_id)
    append(state.pending_lambda_fn_indexes, fn_index)
    return reference_value

def mir_emit_lambda_body(hir: HirProgram, node_id: int, fn_index: int, state: MirLowerState):
    # 第二遍（全部源码函数之后）：生成合成函数体。
    # 签名 = [捕获..., 显式参数...]；捕获实参由调用点按名单前置传入
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let params_token_start = hir.values[hir_value_offset(payload_start) + 1]
    let params_token_end = hir.values[hir_value_offset(payload_start + 1) + 1]
    let body_node = -1
    let body_offset = hir_value_offset(payload_start + 2)
    if hir.values[body_offset] == HIR_VALUE_NODE:
        body_node = hir.values[body_offset + 1]
    let explicit_name_starts: list[int] = []
    let explicit_name_ends: list[int] = []
    let explicit_types: list[int] = []
    mir_lambda_explicit_params(state, params_token_start, params_token_end, explicit_name_starts, explicit_name_ends,
        explicit_types)

    let capture_count = 0
    if fn_index < len(state.functions.capture_counts):
        capture_count = state.functions.capture_counts[fn_index]
    let capture_flat_base = 0
    let counted_index = 0
    while counted_index < fn_index and counted_index < len(state.functions.capture_counts):
        capture_flat_base = capture_flat_base + state.functions.capture_counts[counted_index]
        counted_index = counted_index + 1

    mir_int_list_set(state.func_index, 0, fn_index)
    mir_int_list_set(state.next_block, 0, 0)
    mir_int_list_set(state.next_value, 0, 0)
    mir_int_list_set(state.is_terminated, 0, 0)
    mir_int_list_set(state.loop_count, 0, 0)
    # 字段重绑定（state.field = []）在自举编译时丢 store，
    # 改用别名 + 元素重置：value_types 置 DYNAMIC、声明置 -1（越界读取等价）
    let reset_value_types = state.value_types
    let reset_type_index = 0
    while reset_type_index < len(reset_value_types):
        mir_int_list_set(reset_value_types, reset_type_index, MIR_TYPE_DYNAMIC)
        reset_type_index = reset_type_index + 1
    let reset_value_decls = state.value_struct_declarations
    let reset_decl_index = 0
    while reset_decl_index < len(reset_value_decls):
        mir_int_list_set(reset_value_decls, reset_decl_index, -1)
        reset_decl_index = reset_decl_index + 1
    mir_int_list_set(state.symbol_count, 0, 0)
    # 先收集参数类型（捕获 + 显式），供 FUNCTION 签名与 PARAMETER 共用
    let param_type_list: list[int] = []
    let capture_index = 0
    while capture_index < capture_count:
        let captured_start = state.functions.capture_name_starts[capture_flat_base + capture_index]
        let captured_end = state.functions.capture_name_ends[capture_flat_base + capture_index]
        let captured_type = state.functions.capture_types[capture_flat_base + capture_index]
        append(param_type_list, captured_type)
        capture_index = capture_index + 1
    let explicit_index_t = 0
    while explicit_index_t < len(explicit_types):
        append(param_type_list, mir_int_list_get(explicit_types, explicit_index_t))
        explicit_index_t = explicit_index_t + 1

    # 签名 TYPE 序列写入 values，FUNCTION 的 aux 指向它
    let signature_start = mir_value_count(state.values)
    let signature_type_index = 0
    while signature_type_index < len(param_type_list):
        append(state.values, MIR_OPERAND_TYPE)
        append(state.values, param_type_list[signature_type_index])
        signature_type_index = signature_type_index + 1
    let func_record = MirRecord{
        record_kind: MIR_RECORD_FUNCTION,
        func_index: fn_index,
        block_index: -1,
        opcode: 0,
        type_tag: MIR_TYPE_FUNCTION,
        result_value: -1,
        operand_start: 0,
        operand_count: 0,
        auxiliary_start: signature_start,
        auxiliary_count: len(param_type_list),
        source_start: hir.records[offset + 3],
        source_end: hir.records[offset + 4]
    }
    mir_append_record(state.records, func_record)

    let parameter_value = 0
    capture_index = 0
    while capture_index < capture_count:
        let captured_start = state.functions.capture_name_starts[capture_flat_base + capture_index]
        let captured_end = state.functions.capture_name_ends[capture_flat_base + capture_index]
        let captured_type = state.functions.capture_types[capture_flat_base + capture_index]
        let parameter = MirRecord{
            record_kind: MIR_RECORD_PARAMETER,
            func_index: fn_index,
            block_index: -1,
            opcode: 0,
            type_tag: captured_type,
            result_value: parameter_value,
            operand_start: 0,
            operand_count: 0,
            auxiliary_start: 0,
            auxiliary_count: 0,
            source_start: captured_start,
            source_end: captured_end
        }
        mir_append_record(state.records, parameter)
        mir_state_set_value_type(state, parameter_value, captured_type)
        mir_bind_symbol(state, captured_start, captured_end, parameter_value)
        parameter_value = parameter_value + 1
        capture_index = capture_index + 1

    let explicit_index = 0
    while explicit_index < len(explicit_name_starts):
        let explicit_type = mir_int_list_get(explicit_types, explicit_index)
        let parameter = MirRecord{
            record_kind: MIR_RECORD_PARAMETER,
            func_index: fn_index,
            block_index: -1,
            opcode: 0,
            type_tag: explicit_type,
            result_value: parameter_value,
            operand_start: 0,
            operand_count: 0,
            auxiliary_start: 0,
            auxiliary_count: 0,
            source_start: mir_int_list_get(explicit_name_starts, explicit_index),
            source_end: mir_int_list_get(explicit_name_ends, explicit_index)
        }
        mir_append_record(state.records, parameter)
        mir_state_set_value_type(state, parameter_value, explicit_type)
        mir_bind_symbol(state, mir_int_list_get(explicit_name_starts, explicit_index),
            mir_int_list_get(explicit_name_ends, explicit_index), parameter_value)
        parameter_value = parameter_value + 1
        explicit_index = explicit_index + 1
    mir_int_list_set(state.next_value, 0, parameter_value)

    let entry_block = mir_state_reserve_block(state)
    mir_state_emit_block(state, entry_block)
    mir_state_select_block(state, entry_block)

    let lambda_return_type = MIR_TYPE_UNIT
    if body_node >= 0:
        let body_result = mir_lower_hir_node(hir, body_node, state)
        if body_result >= 0:
            lambda_return_type = mir_state_value_type(state, body_result)
            let return_operand_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_VALUE, body_result)
            mir_state_append_terminator(state, MIR_TERM_RETURN, return_operand_start, 1)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(state.values), 0)
    let return_slots = state.functions.returns
    return_slots[fn_index] = lambda_return_type

def mir_lower_hir_match(hir: HirProgram, node_id: int, state: MirLowerState) -> int:
    let offset = hir_record_offset(node_id)
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count < 2:
        return -1
    let subject = -1
    let subject_offset = hir_value_offset(payload_start)
    if hir.values[subject_offset] == HIR_VALUE_NODE:
        subject = mir_lower_hir_node(hir, hir.values[subject_offset + 1], state)
    let cases_block_offset = hir_value_offset(payload_start + 1)
    let cases_block = -1
    if hir.values[cases_block_offset] == HIR_VALUE_BLOCK:
        cases_block = hir.values[cases_block_offset + 1]
    let default_block = -1
    if payload_count > 2:
        let default_block_offset = hir_value_offset(payload_start + 2)
        if hir.values[default_block_offset] == HIR_VALUE_BLOCK:
            default_block = hir.values[default_block_offset + 1]
    let match_end_block = mir_state_reserve_block(state)
    let match_symbol_count = mir_int_list_get(state.symbol_count, 0)
    let match_starts = mir_copy_symbols(state.symbol_starts)
    let match_ends = mir_copy_symbols(state.symbol_ends)
    let match_values = mir_copy_symbols(state.symbol_values)
    let case_node_ids: list[int] = []
    if cases_block >= 0:
        let block_offset = hir_record_offset(cases_block)
        let case_start = hir.records[block_offset + 5]
        let case_count = hir.records[block_offset + 6]
        let case_index = 0
        while case_index < case_count:
            let value_offset = hir_value_offset(case_start + case_index)
            if hir.values[value_offset] == HIR_VALUE_NODE:
                append(case_node_ids, hir.values[value_offset + 1])
            case_index = case_index + 1
    let match_result_type = MIR_TYPE_UNKNOWN
    let case_index = 0
    while case_index < len(case_node_ids):
        let case_id = mir_int_list_get(case_node_ids, case_index)
        let case_offset = hir_record_offset(case_id)
        let case_payload_start = hir.records[case_offset + 5]
        let case_payload_count = hir.records[case_offset + 6]
        let pattern_node_id = -1
        if case_payload_count > 0:
            let pattern_offset = hir_value_offset(case_payload_start)
            if hir.values[pattern_offset] == HIR_VALUE_NODE:
                pattern_node_id = hir.values[pattern_offset + 1]
        let pattern_conditions: list[int] = []
        let pattern_bindings: list[int] = []
        if pattern_node_id >= 0:
            mir_expand_pattern(hir, pattern_node_id, subject, state, pattern_conditions, pattern_bindings)
        # 组合匹配条件（AND）
        let compare_value = -1
        if len(pattern_conditions) == 0:
            compare_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, compare_value + 1)
            let true_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_INT, 1)
            mir_state_append_instruction(state, MIR_OP_CONST, MIR_TYPE_BOOL, compare_value, true_start, 1)
        elif len(pattern_conditions) == 1:
            compare_value = mir_int_list_get(pattern_conditions, 0)
        else:
            compare_value = mir_int_list_get(pattern_conditions, 0)
            let condition_index = 1
            while condition_index < len(pattern_conditions):
                let next_compare = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, next_compare + 1)
                let and_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_AND)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, compare_value)
                mir_append_operand(state.values, MIR_OPERAND_VALUE, mir_int_list_get(pattern_conditions,
                    condition_index))
                mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, next_compare, and_start, 3)
                compare_value = next_compare
                condition_index = condition_index + 1
        # guard（case ... if cond）：先应用模式绑定再求值，与模式条件 AND；
        # 失败时走 next_block 由后续 case 继续匹配
        if case_payload_count >= 3:
            let guard_offset = hir_value_offset(case_payload_start + 1)
            if hir.values[guard_offset] == HIR_VALUE_NODE:
                let guard_node_id = hir.values[guard_offset + 1]
                let binding_pre_index = 0
                while binding_pre_index < len(pattern_bindings):
                    mir_bind_symbol(state, mir_int_list_get(pattern_bindings, binding_pre_index),
                        mir_int_list_get(pattern_bindings, binding_pre_index + 1), mir_int_list_get(pattern_bindings,
                        binding_pre_index + 2))
                    binding_pre_index = binding_pre_index + 3
                let guard_value = mir_lower_hir_node(hir, guard_node_id, state)
                if guard_value >= 0:
                    let guard_cmp = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, guard_cmp + 1)
                    let guard_and_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_INT, IR_OPERATOR_AND)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, compare_value)
                    mir_append_operand(state.values, MIR_OPERAND_VALUE, guard_value)
                    mir_state_append_instruction(state, MIR_OP_BINARY, MIR_TYPE_BOOL, guard_cmp, guard_and_start, 3)
                    compare_value = guard_cmp
        let body_block = mir_state_reserve_block(state)
        let next_block = mir_state_reserve_block(state)
        let branch_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_VALUE, compare_value)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, body_block)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, next_block)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_append_operand(state.values, MIR_OPERAND_INT, match_symbol_count)
        mir_append_current_symbol_arguments(state, match_starts, match_ends, match_symbol_count)
        mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
        mir_state_emit_block(state, body_block)
        mir_state_select_block(state, body_block)
        # 应用模式变量绑定
        let binding_index = 0
        while binding_index < len(pattern_bindings):
            mir_bind_symbol(state, mir_int_list_get(pattern_bindings, binding_index), mir_int_list_get(pattern_bindings,
                binding_index + 1), mir_int_list_get(pattern_bindings, binding_index + 2))
            binding_index = binding_index + 3
        # M_CASE 载荷为 [pattern, guard, body]；AST_CASE 载荷为 [pattern, body_block]
        let body_result = -1
        if case_payload_count > 1:
            let body_offset = case_payload_start + 1
            if case_payload_count >= 3:
                body_offset = case_payload_start + 2
            let body_value_offset = hir_value_offset(body_offset)
            if hir.values[body_value_offset] == HIR_VALUE_BLOCK:
                body_result = mir_lower_hir_block(hir, hir.values[body_value_offset + 1], state)
            elif hir.values[body_value_offset] == HIR_VALUE_NODE:
                body_result = mir_lower_hir_node(hir, hir.values[body_value_offset + 1], state)
        if body_result >= 0 and match_result_type == MIR_TYPE_UNKNOWN:
            match_result_type = mir_state_value_type(state, body_result)
        if mir_int_list_get(state.is_terminated, 0) == 0:
            # 先备好结果值（必要时生成常量），再开始 JUMP 操作数，
            # 避免常量指令的操作数混入 JUMP 的 operands
            let jump_result = -1
            if match_result_type not in [MIR_TYPE_UNKNOWN, MIR_TYPE_UNIT]:
                if body_result < 0:
                    body_result = mir_int_list_get(state.next_value, 0)
                    mir_int_list_set(state.next_value, 0, body_result + 1)
                    let const_start = mir_value_count(state.values)
                    mir_append_operand(state.values, MIR_OPERAND_INT, 0)
                    mir_state_append_instruction(state, MIR_OP_CONST, match_result_type, body_result, const_start, 1)
                jump_result = body_result
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, match_end_block)
            mir_append_current_symbol_arguments(state, match_starts, match_ends, match_symbol_count)
            if jump_result >= 0:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, jump_result)
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
        mir_restore_symbols(state, match_starts, match_ends, match_values, match_symbol_count)
        mir_state_emit_block(state, next_block)
        mir_state_select_block(state, next_block)
        let symbol_index = 0
        while symbol_index < match_symbol_count:
            let next_value = mir_int_list_get(state.next_value, 0)
            mir_int_list_set(state.next_value, 0, next_value + 1)
            let match_value = mir_int_list_get(match_values, symbol_index)
            let next_type = mir_state_value_type(state, match_value)
            mir_state_append_block_parameter(state, next_block, next_type, next_value)
            mir_state_set_struct_declaration(state, next_value, mir_state_struct_declaration(state, match_value))
            mir_int_list_set(state.symbol_values, symbol_index, next_value)
            symbol_index = symbol_index + 1
        case_index = case_index + 1
    let default_result = -1
    if default_block >= 0:
        default_result = mir_lower_hir_block(hir, default_block, state)
        if default_result >= 0 and match_result_type == MIR_TYPE_UNKNOWN:
            match_result_type = mir_state_value_type(state, default_result)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        # 先备好结果值（必要时生成常量），再开始 JUMP 操作数
        let jump_result = -1
        if match_result_type not in [MIR_TYPE_UNKNOWN, MIR_TYPE_UNIT]:
            if default_result < 0:
                default_result = mir_int_list_get(state.next_value, 0)
                mir_int_list_set(state.next_value, 0, default_result + 1)
                let const_start = mir_value_count(state.values)
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
                mir_state_append_instruction(state, MIR_OP_CONST, match_result_type, default_result, const_start, 1)
            jump_result = default_result
        let jump_start = mir_value_count(state.values)
        mir_append_operand(state.values, MIR_OPERAND_BLOCK, match_end_block)
        mir_append_current_symbol_arguments(state, match_starts, match_ends, match_symbol_count)
        if jump_result >= 0:
            mir_append_operand(state.values, MIR_OPERAND_VALUE, jump_result)
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    mir_state_emit_block(state, match_end_block)
    mir_state_select_block(state, match_end_block)
    let symbol_index = 0
    while symbol_index < match_symbol_count:
        let end_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, end_value + 1)
        let match_value = mir_int_list_get(match_values, symbol_index)
        let end_type = mir_state_value_type(state, match_value)
        mir_state_append_block_parameter(state, match_end_block, end_type, end_value)
        mir_state_set_struct_declaration(state, end_value, mir_state_struct_declaration(state, match_value))
        mir_int_list_set(state.symbol_values, symbol_index, end_value)
        symbol_index = symbol_index + 1
    let match_result_value = -1
    if match_result_type not in [MIR_TYPE_UNKNOWN, MIR_TYPE_UNIT]:
        match_result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, match_result_value + 1)
        mir_state_append_block_parameter(state, match_end_block, match_result_type, match_result_value)
    return match_result_value

def mir_lower_hir_control(hir: HirProgram, node_id: int, state: MirLowerState, external_join_block: int,
    external_else_block: int, elif_block_id: int, else2_block_id: int) -> int:
    let offset = hir_record_offset(node_id)
    let opcode = hir.records[offset + 1]
    let payload_start = hir.records[offset + 5]
    let payload_count = hir.records[offset + 6]
    if payload_count == 0:
        return -1
    if opcode == HIR_OP_MATCH:
        return mir_lower_hir_match(hir, node_id, state)
    if opcode == HIR_OP_WHILE:
        return mir_lower_hir_loop(hir, node_id, state)
    if opcode == HIR_OP_FOR:
        return mir_lower_hir_for(hir, node_id, state)
    let condition_payload_index = 0
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
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
        mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, 5)
        let result_type = mir_type_from_hir(hir.records[offset + 2])
        let then_result = -1
        mir_state_emit_block(state, then_block)
        mir_state_select_block(state, then_block)
        let then_offset = hir_value_offset(payload_start + 1)
        if hir.values[then_offset] == HIR_VALUE_NODE:
            then_result = mir_lower_hir_node(hir, hir.values[then_offset + 1], state)
        if mir_int_list_get(state.is_terminated, 0) == 0:
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
            if then_result >= 0:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, then_result)
            else:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, 2)
        let else_result = -1
        mir_state_emit_block(state, else_block)
        mir_state_select_block(state, else_block)
        let else_offset = hir_value_offset(payload_start + 2)
        if hir.values[else_offset] == HIR_VALUE_NODE:
            else_result = mir_lower_hir_node(hir, hir.values[else_offset + 1], state)
        if mir_int_list_get(state.is_terminated, 0) == 0:
            let jump_start = mir_value_count(state.values)
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
            if else_result >= 0:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, else_result)
            else:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, 2)
        mir_state_emit_block(state, join_block)
        mir_state_select_block(state, join_block)
        let result_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        mir_state_append_block_parameter(state, join_block, result_type, result_value)
        mir_state_set_struct_declaration(state, result_value, mir_state_struct_declaration(state, then_result))
        mir_int_list_set(state.hir_value_map, node_id, result_value)
        return result_value
    let then_block = mir_state_reserve_block(state)
    let else_block = mir_state_reserve_block(state)
    let join_block = -1
    if external_join_block < 0:
        join_block = mir_state_reserve_block(state)
    let branch_start = mir_value_count(state.values)
    if condition_result >= 0:
        mir_append_operand(state.values, MIR_OPERAND_VALUE, condition_result)
    else:
        mir_append_operand(state.values, MIR_OPERAND_INT, 0)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, then_block)
    mir_append_operand(state.values, MIR_OPERAND_BLOCK, else_block)
    mir_state_append_terminator(state, MIR_TERM_BRANCH, branch_start, mir_value_count(state.values) - branch_start)
    let base_count = mir_int_list_get(state.symbol_count, 0)
    let base_starts = mir_copy_symbols(state.symbol_starts)
    let base_ends = mir_copy_symbols(state.symbol_ends)
    let base_values = mir_copy_symbols(state.symbol_values)
    let join_values: list[int] = []
    let symbol_index = 0
    while symbol_index < base_count:
        let join_value = mir_int_list_get(state.next_value, 0)
        mir_int_list_set(state.next_value, 0, mir_int_list_get(state.next_value, 0) + 1)
        append(join_values, join_value)
        symbol_index = symbol_index + 1
    mir_state_emit_block(state, then_block)
    mir_state_select_block(state, then_block)
    if (
        payload_count > block_payload_index and
        hir.values[hir_value_offset(payload_start + block_payload_index)] == HIR_VALUE_BLOCK
    ):
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index) + 1], state)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        let jump_start = mir_value_count(state.values)
        if external_join_block >= 0:
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, external_join_block)
        else:
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        let argument_index = 0
        while argument_index < base_count:
            let argument_value = mir_find_symbol_value(state, mir_int_list_get(base_starts, argument_index),
                mir_int_list_get(base_ends, argument_index))
            if argument_value < 0:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            else:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_value)
            argument_index = argument_index + 1
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    mir_state_emit_block(state, else_block)
    mir_state_select_block(state, else_block)
    let has_elif_block = false
    let elif_if_id = -1
    if payload_count > block_payload_index + 1:
        let elif_value_offset = hir_value_offset(payload_start + block_payload_index + 1)
        if hir.values[elif_value_offset] == HIR_VALUE_BLOCK:
            let elif_block_id = hir.values[elif_value_offset + 1]
            let elif_block_offset = hir_record_offset(elif_block_id)
            has_elif_block = hir.records[elif_block_offset + 6] > 0
            if has_elif_block:
                # elif 块内应含内层 IF 记录
                let elif_payload_start = hir.records[elif_block_offset + 5]
                if hir.records[elif_block_offset + 6] > 0:
                    let elif_value_offset2 = hir_value_offset(elif_payload_start)
                    if hir.values[elif_value_offset2] == HIR_VALUE_NODE:
                        elif_if_id = hir.values[elif_value_offset2 + 1]
    if external_else_block >= 0:
        # 本 IF 是 elif 链的内层：false 分支内容 = 外层传入的 else（可能是块或下一层 IF）
        let external_offset = hir_record_offset(external_else_block)
        if hir.records[external_offset + 1] == HIR_OP_IF:
            # 在 elif 块中定位该 IF，其 next 继续作为链的 false 分支
            let next_else_target = else2_block_id
            if elif_block_id >= 0:
                let elif_offset = hir_record_offset(elif_block_id)
                let elif_payload_start = hir.records[elif_offset + 5]
                let elif_payload_count = hir.records[elif_offset + 6]
                let search_index = 0
                while search_index < elif_payload_count:
                    let search_offset = hir_value_offset(elif_payload_start + search_index)
                    if (
                        hir.values[search_offset] == HIR_VALUE_NODE and
                        hir.values[search_offset + 1] == external_else_block and
                        search_index + 1 < elif_payload_count
                    ):
                        let next_offset = hir_value_offset(elif_payload_start + search_index + 1)
                        if hir.values[next_offset] == HIR_VALUE_NODE:
                            next_else_target = hir.values[next_offset + 1]
                    search_index = search_index + 1
            # 递归降级 external_else_block 自身，其 false 分支继续为链的 next
            if next_else_target >= 0:
                let next_target_offset = hir_record_offset(next_else_target)
                if hir.records[next_target_offset + 1] == HIR_OP_IF:
                    mir_lower_hir_control(hir, external_else_block, state, external_join_block, next_else_target,
                        elif_block_id, else2_block_id)
                else:
                    mir_lower_hir_control(hir, external_else_block, state, external_join_block, next_else_target,
                        elif_block_id, else2_block_id)
            else:
                # 无后续 else（链尾）：仍递归降级本 IF，其 false 分支为空或链后代码
                mir_lower_hir_control(hir, external_else_block, state, external_join_block, else2_block_id,
                    elif_block_id, else2_block_id)
        else:
            mir_lower_hir_block(hir, external_else_block, state)
    elif has_elif_block:
        # elif 链：块内所有内层 IF 链式降级，每个的 then 跳外层 join，
        # 最后一个的 false 分支指向最终 else 块，避免 elif 体执行后落入后续 elif/else 体
        let elif_join_target = join_block
        if external_join_block >= 0:
            elif_join_target = external_join_block
        let else2_block = -1
        if payload_count > block_payload_index + 2:
            let else2_value_offset = hir_value_offset(payload_start + block_payload_index + 2)
            if hir.values[else2_value_offset] == HIR_VALUE_BLOCK:
                else2_block = hir.values[else2_value_offset + 1]
        let elif_block_id = hir.values[hir_value_offset(payload_start + block_payload_index + 1) + 1]
        let elif_block_offset = hir_record_offset(elif_block_id)
        let elif_payload_start = hir.records[elif_block_offset + 5]
        let elif_payload_count = hir.records[elif_block_offset + 6]
        # 只降级第一个 elif，其余由链式递归（external_else 分支）接续，
        # 避免同一 elif 被重复降级
        let elif_index = 0
        let elif_chain_started = false
        while elif_index < elif_payload_count and not elif_chain_started:
            let elif_value_offset = hir_value_offset(elif_payload_start + elif_index)
            if hir.values[elif_value_offset] == HIR_VALUE_NODE:
                let elif_if_id2 = hir.values[elif_value_offset + 1]
                let elif_if_offset2 = hir_record_offset(elif_if_id2)
                if hir.records[elif_if_offset2 + 1] == HIR_OP_IF:
                    let next_else = else2_block
                    if elif_index + 1 < elif_payload_count:
                        let next_offset = hir_value_offset(elif_payload_start + elif_index + 1)
                        if hir.values[next_offset] == HIR_VALUE_NODE:
                            next_else = hir.values[next_offset + 1]
                    mir_lower_hir_control(hir, elif_if_id2, state, elif_join_target, next_else, elif_block_id,
                        else2_block)
                    elif_chain_started = true
            elif_index = elif_index + 1
    elif (
        payload_count > block_payload_index + 2 and
        hir.values[hir_value_offset(payload_start + block_payload_index + 2)] == HIR_VALUE_BLOCK
    ):
        mir_lower_hir_block(hir, hir.values[hir_value_offset(payload_start + block_payload_index + 2) + 1], state)
    if mir_int_list_get(state.is_terminated, 0) == 0:
        let jump_start = mir_value_count(state.values)
        if external_join_block >= 0:
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, external_join_block)
        else:
            mir_append_operand(state.values, MIR_OPERAND_BLOCK, join_block)
        let argument_index = 0
        while argument_index < base_count:
            let argument_value = mir_find_symbol_value(state, mir_int_list_get(base_starts, argument_index),
                mir_int_list_get(base_ends, argument_index))
            if argument_value < 0:
                mir_append_operand(state.values, MIR_OPERAND_INT, 0)
            else:
                mir_append_operand(state.values, MIR_OPERAND_VALUE, argument_value)
            argument_index = argument_index + 1
        mir_state_append_terminator(state, MIR_TERM_JUMP, jump_start, mir_value_count(state.values) - jump_start)
    mir_restore_symbols(state, base_starts, base_ends, base_values, base_count)
    if join_block >= 0:
        mir_state_emit_block(state, join_block)
        mir_state_select_block(state, join_block)
        symbol_index = 0
        while symbol_index < base_count:
            let base_value = mir_int_list_get(base_values, symbol_index)
            let join_value = mir_int_list_get(join_values, symbol_index)
            let parameter_type = mir_state_value_type(state, base_value)
            mir_state_append_block_parameter(state, join_block, parameter_type, join_value)
            mir_state_set_struct_declaration(state, join_value, mir_state_struct_declaration(state, base_value))
            mir_int_list_set(state.symbol_values, symbol_index, join_value)
            symbol_index = symbol_index + 1
    return -1

def mir_model_build_program(hir_records: list[int], hir_values: list[int], hir_struct_decls: list[int], source: str,
    constant_starts: list[int], constant_ends: list[int], constant_values: list[int], constant_types: list[int],
    constant_literal_starts: list[int], constant_literal_ends: list[int], func_return_struct_decls: list[int],
    parameter_offsets: list[int], parameter_struct_decls: list[int], parameter_default_indexes: list[int],
    parameter_annotation_starts: list[int], parameter_annotation_ends: list[int], impl_func_indexes: list[int],
    impl_func_decls: list[int], impl_func_interface_types: list[int], interface_name_starts: list[int],
    interface_name_ends: list[int], interface_func_indexes: list[int], impl_decl_indexes: list[int],
    impl_interface_name_starts: list[int], impl_interface_name_ends: list[int]) -> MirProgram:
    let hir_program = HirProgram{records: hir_records, values: hir_values, struct_decls: hir_struct_decls}
    let records = []
    let values = []
    let module = MirRecord{
        record_kind: MIR_RECORD_MODULE,
        func_index: -1,
        block_index: -1,
        opcode: 0,
        type_tag: MIR_TYPE_UNKNOWN,
        result_value: -1,
        operand_start: 0,
        operand_count: 0,
        auxiliary_start: 0,
        auxiliary_count: 0,
        source_start: 0,
        source_end: 0
    }
    mir_append_record(records, module)
    let hir_value_map: list[int] = []
    let map_index = 0
    while map_index < hir_record_count(hir_records):
        append(hir_value_map, -1)
        map_index = map_index + 1
    let func_starts: list[int] = []
    let func_ends: list[int] = []
    let func_returns: list[int] = []
    let capture_name_starts: list[int] = []
    let capture_name_ends: list[int] = []
    let capture_counts: list[int] = []
    let capture_types: list[int] = []
    let func_record_id = 0
    while func_record_id < hir_record_count(hir_records):
        let func_offset = hir_record_offset(func_record_id)
        if hir_records[func_offset] == HIR_RECORD_FUNCTION:
            append(func_starts, hir_records[func_offset + 9])
            append(func_ends, hir_records[func_offset + 10])
            append(func_returns, mir_type_from_hir(mir_hir_signature_value(hir_values,
                hir_records[func_offset + 7], HIR_SIGNATURE_RETURN_TYPE)))
        func_record_id = func_record_id + 1
    let func_info = MirFunctionInfo{
        starts: func_starts,
        ends: func_ends,
        returns: func_returns,
        capture_name_starts: capture_name_starts,
        capture_name_ends: capture_name_ends,
        capture_counts: capture_counts,
        capture_types: capture_types
    }
    let constant_pool = MirConstantPool{
        starts: constant_starts,
        ends: constant_ends,
        values: constant_values,
        types: constant_types,
        literal_starts: constant_literal_starts,
        literal_ends: constant_literal_ends
    }
    let initial_func_index: list[int] = [0]
    let initial_current_block: list[int] = [-1]
    let initial_next_block: list[int] = [0]
    let initial_next_value: list[int] = [0]
    let initial_is_terminated: list[int] = [0]
    let initial_symbol_count: list[int] = [0]
    let initial_loop_count: list[int] = [0]
    # 收集全局变量表：名字区间、初始化表达式节点、MIR 类型
    let global_names: list[int] = []
    let global_initializers: list[int] = []
    let global_types: list[int] = []
    let global_scan_id = 0
    while global_scan_id < hir_record_count(hir_records):
        let global_offset = hir_record_offset(global_scan_id)
        if hir_records[global_offset] == HIR_RECORD_GLOBAL:
            append(global_names, hir_records[global_offset + 9])
            append(global_names, hir_records[global_offset + 10])
            let initializer_node = -1
            if hir_records[global_offset + 6] > 0:
                let value_offset = hir_value_offset(hir_records[global_offset + 5])
                if hir_values[value_offset] == HIR_VALUE_NODE:
                    initializer_node = hir_values[value_offset + 1]
            append(global_initializers, initializer_node)
            append(global_types, mir_type_from_hir(hir_records[global_offset + 2]))
        global_scan_id = global_scan_id + 1
    let global_value_cache: list[int] = []
    let global_cache_index = 0
    while global_cache_index < len(global_names) / 2:
        append(global_value_cache, -1)
        global_cache_index = global_cache_index + 1

    let func_index_map = hash_index_build(source, func_starts, func_ends)
    let constant_index_map = hash_index_build(source, constant_starts, constant_ends)
    let global_index_map = hash_index_build_pairs(source, global_names)

    let struct_init_func_map: list[int] = []
    let decl_idx = 0
    let decl_count = len(STRUCT_DECLARATION_STARTS)
    while decl_idx < decl_count:
        let struct_start = mir_int_list_get(STRUCT_DECLARATION_ENDS, decl_idx)
        let next_struct = source.len()
        if decl_idx + 1 < decl_count:
            next_struct = mir_int_list_get(STRUCT_DECLARATION_STARTS, decl_idx + 1)
        let found_init = -1
        let f_scan = 0
        let f_count = len(func_starts)
        while f_scan < f_count:
            let f_start = mir_int_list_get(func_starts, f_scan)
            let f_end = mir_int_list_get(func_ends, f_scan)
            if (
                f_start > struct_start and
                f_start < next_struct and
                f_end - f_start == 8 and
                source[f_start:f_end] == "__init__"
            ):
                found_init = f_scan
                f_scan = f_count
            else:
                f_scan = f_scan + 1
        append(struct_init_func_map, found_init)
        decl_idx = decl_idx + 1

    let state = MirLowerState{
        records: records,
        values: values,
        func_index: initial_func_index,
        current_block: initial_current_block,
        next_block: initial_next_block,
        next_value: initial_next_value,
        is_terminated: initial_is_terminated,
        hir_value_map: hir_value_map,
        symbol_starts: [],
        symbol_ends: [],
        symbol_values: [],
        symbol_count: initial_symbol_count,
        functions: func_info,
        constants: constant_pool,
        source: source,
        loop_break_blocks: [],
        loop_continue_blocks: [],
        loop_symbol_counts: [],
        loop_count: initial_loop_count,
        value_types: [],
        parameter_offsets: parameter_offsets,
        parameter_struct_decls: parameter_struct_decls,
        parameter_default_indexes: parameter_default_indexes,
        parameter_annotation_starts: parameter_annotation_starts,
        parameter_annotation_ends: parameter_annotation_ends,
        func_return_struct_decls: func_return_struct_decls,
        func_param_counts: [],
        func_param_types: [],
        func_receiver_flags: [],
        value_enum_flags: [],
        value_struct_declarations: [],
        impl_func_indexes: impl_func_indexes,
        impl_func_decls: impl_func_decls,
        impl_func_interface_types: impl_func_interface_types,
        func_ref_values: [],
        func_ref_targets: [],
        pending_lambda_nodes: [],
        pending_lambda_fn_indexes: [],
        named_ref_name_starts: [],
        named_ref_name_ends: [],
        named_ref_targets: [],
        named_ref_return_types: [],
        enum_variant_name_starts: [],
        enum_variant_name_ends: [],
        enum_variant_tags: [],
        enum_variant_payload_kinds: [],
        interface_name_starts: interface_name_starts,
        interface_name_ends: interface_name_ends,
        interface_func_indexes: interface_func_indexes,
        impl_decl_indexes: impl_decl_indexes,
        impl_interface_name_starts: impl_interface_name_starts,
        impl_interface_name_ends: impl_interface_name_ends,
        global_names: global_names,
        global_initializers: global_initializers,
        global_types: global_types,
        global_value_cache: global_value_cache,
        lex_kinds: [],
        lex_starts: [],
        lex_ends: [],
        value_records: [],
        current_func_record_offset: [0],
        func_has_dict_items: [0],
        func_index_map: func_index_map,
        constant_index_map: constant_index_map,
        global_index_map: global_index_map,
        struct_init_func_map: struct_init_func_map
    }
    let parameter_scan_id = 0
    while parameter_scan_id < hir_record_count(hir_records):
        let parameter_scan_offset = hir_record_offset(parameter_scan_id)
        if hir_records[parameter_scan_offset] == HIR_RECORD_FUNCTION:
            let signature_start = hir_records[parameter_scan_offset + 7]
            let parameter_count = mir_hir_signature_value(hir_values, signature_start, HIR_SIGNATURE_PARAM_COUNT)
            append(state.func_param_counts, parameter_count)
            let has_receiver = 0
            if parameter_count > 0:
                let receiver_name_start = mir_hir_signature_value(hir_values, signature_start,
                    HIR_SIGNATURE_PARAM_BASE + 1)
                let receiver_name_end = mir_hir_signature_value(hir_values, signature_start,
                    HIR_SIGNATURE_PARAM_BASE + 2)
                if source[receiver_name_start:receiver_name_end] == "self":
                    has_receiver = 1
            append(state.func_receiver_flags, has_receiver)
            let parameter_index = 0
            while parameter_index < parameter_count:
                let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
                let parameter_type = mir_type_from_hir(mir_hir_signature_value(hir_values, signature_start,
                    metadata_index))
                append(state.func_param_types, parameter_type)
                parameter_index = parameter_index + 1
        parameter_scan_id = parameter_scan_id + 1
    mir_enum_scan_declarations(state)
    let func_index = 0
    let hir_record_id = 0
    while hir_record_id < hir_record_count(hir_records):
        let hir_offset = hir_record_offset(hir_record_id)
        if hir_records[hir_offset] == HIR_RECORD_FUNCTION:
            mir_int_list_set(state.func_index, 0, func_index)
            mir_int_list_set(state.next_block, 0, 0)
            mir_int_list_set(state.next_value, 0, 0)
            mir_int_list_set(state.is_terminated, 0, 0)
            mir_int_list_set(state.loop_count, 0, 0)
            # 字段重绑定（state.field = []）在自举编译时丢 store，
            # 改用别名 + 元素重置：value_types 置 DYNAMIC、声明置 -1（越界读取等价）
            let reset_value_types = state.value_types
            let reset_type_index = 0
            while reset_type_index < len(reset_value_types):
                mir_int_list_set(reset_value_types, reset_type_index, MIR_TYPE_DYNAMIC)
                reset_type_index = reset_type_index + 1
            let reset_value_decls = state.value_struct_declarations
            let reset_decl_index = 0
            while reset_decl_index < len(reset_value_decls):
                mir_int_list_set(reset_value_decls, reset_decl_index, -1)
                reset_decl_index = reset_decl_index + 1
            let reset_enum_flags = state.value_enum_flags
            let reset_enum_index = 0
            while reset_enum_index < len(reset_enum_flags):
                mir_int_list_set(reset_enum_flags, reset_enum_index, 0)
                reset_enum_index = reset_enum_index + 1
            let reset_index = 0
            while reset_index < len(state.hir_value_map):
                mir_int_list_set(state.hir_value_map, reset_index, -1)
                reset_index = reset_index + 1
            let symbol_reset_index = 0
            while symbol_reset_index < len(state.symbol_starts):
                mir_int_list_set(state.symbol_starts, symbol_reset_index, -1)
                mir_int_list_set(state.symbol_ends, symbol_reset_index, -1)
                mir_int_list_set(state.symbol_values, symbol_reset_index, -1)
                symbol_reset_index = symbol_reset_index + 1
            mir_int_list_set(state.symbol_count, 0, 0)
            let global_reset_index = 0
            while global_reset_index < len(state.global_value_cache):
                mir_int_list_set(state.global_value_cache, global_reset_index, -1)
                global_reset_index = global_reset_index + 1
            let reset_value_records = state.value_records
            let reset_vr_index = 0
            while reset_vr_index < len(reset_value_records):
                mir_int_list_set(reset_value_records, reset_vr_index, -1)
                reset_vr_index = reset_vr_index + 1
            mir_int_list_set(state.func_has_dict_items, 0, 0)
            let signature_start = mir_value_count(values)
            let signature_offset = hir_records[hir_offset + 7]
            let parameter_count = mir_append_func_signature(hir_values, signature_offset, values)
            let signature_count = mir_value_count(values) - signature_start
            let func_opcode = 0
            if source[hir_records[hir_offset + 9]:hir_records[hir_offset + 10]] == "main":
                func_opcode = MIR_FUNCTION_ENTRY
            let function = MirRecord{
                record_kind: MIR_RECORD_FUNCTION,
                func_index: func_index,
                block_index: -1,
                opcode: func_opcode,
                type_tag: MIR_TYPE_FUNCTION,
                result_value: -1,
                operand_start: 0,
                operand_count: 0,
                auxiliary_start: signature_start,
                auxiliary_count: signature_count,
                source_start: hir_records[hir_offset + 9],
                source_end: hir_records[hir_offset + 10]
            }
            mir_append_record(records, function)
            let func_rec_offset = len(records) - MIR_RECORD_SIZE
            mir_int_list_set(state.current_func_record_offset, 0, func_rec_offset)
            let parameter_index = 0
            while parameter_index < parameter_count:
                let metadata_index = HIR_SIGNATURE_PARAM_BASE + parameter_index * HIR_SIGNATURE_PARAM_SIZE
                let parameter_type = mir_type_from_hir(mir_hir_signature_value(hir_values, hir_records[hir_offset + 7],
                    metadata_index))
                let parameter = MirRecord{
                    record_kind: MIR_RECORD_PARAMETER,
                    func_index: func_index,
                    block_index: -1,
                    opcode: 0,
                    type_tag: parameter_type,
                    result_value: parameter_index,
                    operand_start: 0,
                    operand_count: 0,
                    auxiliary_start: 0,
                    auxiliary_count: 0,
                    source_start: mir_hir_signature_value(hir_values, hir_records[hir_offset + 7], metadata_index + 1),
                    source_end: mir_hir_signature_value(hir_values, hir_records[hir_offset + 7], metadata_index + 2)
                }
                mir_append_record(records, parameter)
                let param_rec_offset = len(records) - MIR_RECORD_SIZE
                while len(state.value_records) <= parameter_index:
                    append(state.value_records, -1)
                mir_int_list_set(state.value_records, parameter_index, param_rec_offset)
                mir_state_set_value_type(state, parameter_index, parameter_type)
                mir_bind_symbol(state, mir_hir_signature_value(hir_values, hir_records[hir_offset + 7],
                    metadata_index + 1), mir_hir_signature_value(hir_values, hir_records[hir_offset + 7],
                    metadata_index + 2), parameter_index)
                let collected_parameter_index = -1
                if func_index < len(state.parameter_offsets):
                    collected_parameter_index = mir_int_list_get(state.parameter_offsets,
                        func_index) + parameter_index
                let bound_decl = mir_hir_signature_value(hir_values, hir_records[hir_offset + 7], metadata_index + 4)
                if collected_parameter_index >= 0 and collected_parameter_index < len(state.parameter_struct_decls):
                    if bound_decl < 0:
                        bound_decl = mir_int_list_get(state.parameter_struct_decls, collected_parameter_index)
                if (
                    parameter_type == MIR_TYPE_INTERFACE or
                    bound_decl < 0
                ) and (
                    collected_parameter_index >= 0 and
                    collected_parameter_index < len(state.parameter_annotation_starts)
                ):
                    # 接口类型参数：按注解区间标记为接口 box（dispatch 识别用）
                    let annotation_start = mir_int_list_get(state.parameter_annotation_starts,
                        collected_parameter_index)
                    let annotation_end = mir_int_list_get(state.parameter_annotation_ends, collected_parameter_index)
                    let parameter_interface_id = mir_interface_id(state, annotation_start, annotation_end)
                    if parameter_interface_id >= 0:
                        bound_decl = 0 - (parameter_interface_id + 2)
                mir_state_set_struct_declaration(state, parameter_index, bound_decl)
                parameter_index = parameter_index + 1
            let entry_block = mir_state_reserve_block(state)
            mir_state_emit_block(state, entry_block)
            mir_state_select_block(state, entry_block)
            mir_int_list_set(state.next_value, 0, parameter_count)
            # main 入口统一初始化全局变量：store 初始化表达式结果到全局 slot
            if func_opcode == MIR_FUNCTION_ENTRY:
                let global_index = 0
                while global_index < len(state.global_initializers):
                    let initializer_node = mir_int_list_get(state.global_initializers, global_index)
                    if initializer_node >= 0:
                        let init_value = mir_lower_hir_node(hir_program, initializer_node, state)
                        let store_start = mir_value_count(values)
                        mir_append_operand(values, MIR_OPERAND_INT, global_index)
                        if init_value >= 0:
                            mir_append_operand(values, MIR_OPERAND_VALUE, init_value)
                        else:
                            mir_append_operand(values, MIR_OPERAND_INT, 0)
                        let global_type = MIR_TYPE_DYNAMIC
                        if global_index < len(state.global_types):
                            global_type = mir_int_list_get(state.global_types, global_index)
                        mir_state_append_instruction(state, MIR_OP_GLOBAL_STORE, global_type, -1, store_start, 2)
                        if init_value >= 0:
                            mir_int_list_set(state.global_value_cache, global_index, init_value)
                    global_index = global_index + 1
            let payload_start = hir_records[hir_offset + 5]
            if hir_records[hir_offset + 6] > 0:
                let value_offset = hir_value_offset(payload_start)
                if hir_values[value_offset] in [HIR_VALUE_NODE, HIR_VALUE_BLOCK]:
                    mir_lower_hir_block(hir_program, hir_values[value_offset + 1], state)
            if mir_int_list_get(state.is_terminated, 0) == 0:
                mir_state_append_terminator(state, MIR_TERM_UNREACHABLE, mir_value_count(values), 0)
            func_index = func_index + 1
        hir_record_id = hir_record_id + 1
    # 第二遍：全部源码函数降级完成后，统一生成 lambda 合成函数体
    let pending_index = 0
    while pending_index < len(state.pending_lambda_nodes):
        mir_emit_lambda_body(hir_program, mir_int_list_get(state.pending_lambda_nodes, pending_index),
            mir_int_list_get(state.pending_lambda_fn_indexes, pending_index), state)
        pending_index = pending_index + 1
    return MirProgram{records: records, values: values}

def mir_validation_error(record_id: int, reason: str) -> bool:
    eprint("MIR validation failed record=")
    eprint(record_id)
    eprint(" reason=")
    eprint(reason)
    eprintln("")
    return false

def mir_index_ensure_function(max_values: list[int], max_blocks: list[int], func_index: int):
    while len(max_values) <= func_index:
        append(max_values, -1)
        append(max_blocks, -1)

def mir_index_build(records: list[int]) -> MirIndex:
    let max_values: list[int] = []
    let max_blocks: list[int] = []
    let record_id = 0
    while record_id < mir_record_count(records):
        let offset = mir_record_offset(record_id)
        let func_index = records[offset + 1]
        if func_index >= 0:
            mir_index_ensure_function(max_values, max_blocks, func_index)
            let result_value = records[offset + 5]
            if result_value > mir_int_list_get(max_values, func_index):
                mir_int_list_set(max_values, func_index, result_value)
            let block_index = records[offset + 2]
            if block_index > mir_int_list_get(max_blocks, func_index):
                mir_int_list_set(max_blocks, func_index, block_index)
        record_id = record_id + 1

    let value_offsets: list[int] = [0]
    let block_offsets: list[int] = [0]
    let func_index = 0
    while func_index < len(max_values):
        let value_size = mir_int_list_get(max_values, func_index) + 1
        if value_size < 0:
            value_size = 0
        let block_size = mir_int_list_get(max_blocks, func_index) + 1
        if block_size < 0:
            block_size = 0
        append(value_offsets, mir_int_list_get(value_offsets, func_index) + value_size)
        append(block_offsets, mir_int_list_get(block_offsets, func_index) + block_size)
        func_index = func_index + 1

    let value_defined: list[int] = []
    while len(value_defined) < mir_int_list_get(value_offsets, len(value_offsets) - 1):
        append(value_defined, 0)
    let block_exists: list[int] = []
    let block_parameter_counts: list[int] = []
    let block_terminators: list[int] = []
    while len(block_exists) < mir_int_list_get(block_offsets, len(block_offsets) - 1):
        append(block_exists, 0)
        append(block_parameter_counts, 0)
        append(block_terminators, -1)

    record_id = 0
    while record_id < mir_record_count(records):
        let offset = mir_record_offset(record_id)
        let kind = records[offset]
        let func_index = records[offset + 1]
        if func_index >= 0 and func_index < len(value_offsets) - 1:
            let result_value = records[offset + 5]
            if kind in [MIR_RECORD_PARAMETER, MIR_RECORD_INSTRUCTION] and result_value >= 0:
                let value_offset = mir_int_list_get(value_offsets, func_index) + result_value
                if value_offset < len(value_defined):
                    mir_int_list_set(value_defined, value_offset, 1)
            let block_index = records[offset + 2]
            if block_index >= 0 and block_index < mir_int_list_get(block_offsets,
                func_index + 1) - mir_int_list_get(block_offsets, func_index):
                let block_offset = mir_int_list_get(block_offsets, func_index) + block_index
                if kind == MIR_RECORD_BLOCK:
                    mir_int_list_set(block_exists, block_offset, 1)
                elif kind == MIR_RECORD_PARAMETER:
                    mir_int_list_set(block_parameter_counts, block_offset, mir_int_list_get(block_parameter_counts,
                        block_offset) + 1)
                elif kind == MIR_RECORD_TERMINATOR:
                    mir_int_list_set(block_terminators, block_offset, record_id)
        record_id = record_id + 1
    return MirIndex{
        value_offsets: value_offsets,
        value_defined: value_defined,
        block_offsets: block_offsets,
        block_exists: block_exists,
        block_parameter_counts: block_parameter_counts,
        block_terminators: block_terminators
    }

def mir_block_exists(index: MirIndex, func_index: int, block_index: int) -> bool:
    if func_index < 0 or func_index + 1 >= len(index.block_offsets) or block_index < 0:
        return false
    let block_count = mir_int_list_get(index.block_offsets, func_index + 1) - mir_int_list_get(index.block_offsets,
        func_index)
    if block_index >= block_count:
        return false
    return mir_int_list_get(index.block_exists, mir_int_list_get(index.block_offsets,
        func_index) + block_index) != 0

def mir_block_parameter_count(index: MirIndex, func_index: int, block_index: int) -> int:
    if func_index < 0 or func_index + 1 >= len(index.block_offsets) or block_index < 0:
        return 0
    let block_count = mir_int_list_get(index.block_offsets, func_index + 1) - mir_int_list_get(index.block_offsets,
        func_index)
    if block_index >= block_count:
        return 0
    return mir_int_list_get(index.block_parameter_counts, mir_int_list_get(index.block_offsets,
        func_index) + block_index)

def mir_value_exists_in_function(index: MirIndex, func_index: int, value: int) -> bool:
    if func_index < 0 or func_index + 1 >= len(index.value_offsets) or value < 0:
        return false
    let value_count = mir_int_list_get(index.value_offsets, func_index + 1) - mir_int_list_get(index.value_offsets,
        func_index)
    if value >= value_count:
        return false
    return mir_int_list_get(index.value_defined, mir_int_list_get(index.value_offsets, func_index) + value) != 0

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
        let voffset = mir_record_offset(record_id)
        let offset = mir_record_offset(record_id)
        let kind = records[offset]
        let func_index = records[offset + 1]
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
        if (
            operand_start < 0 or
            operand_count < 0 or
            operand_start > value_count or
            operand_count > value_count - operand_start
        ):
            return mir_validation_error(record_id, "operand range")
        if (
            auxiliary_start < 0 or
            auxiliary_count < 0 or
            auxiliary_start > value_count or
            auxiliary_count > value_count - auxiliary_start
        ):
            return mir_validation_error(record_id, "auxiliary range")
        if kind == MIR_RECORD_MODULE:
            if func_index != -1 or block_index != -1:
                return mir_validation_error(record_id, "module owner")
        elif func_index < 0:
            return mir_validation_error(record_id, "missing function")
        if kind in [MIR_RECORD_BLOCK, MIR_RECORD_INSTRUCTION, MIR_RECORD_TERMINATOR]:
            if block_index < 0:
                return mir_validation_error(record_id, "block index")
        if kind == MIR_RECORD_FUNCTION:
            if active_block >= 0 and not block_has_terminator:
                return mir_validation_error(record_id, "unterminated block before function")
            active_function = func_index
            active_block = -1
            block_has_terminator = true
        elif kind == MIR_RECORD_BLOCK:
            if active_block >= 0 and not block_has_terminator:
                return mir_validation_error(record_id, "block owner")
            if func_index != active_function:
                return mir_validation_error(record_id, "block order")
            active_block = block_index
            block_has_terminator = false
        elif kind == MIR_RECORD_INSTRUCTION:
            if func_index != active_function or block_index != active_block or block_has_terminator:
                return mir_validation_error(record_id, "instruction placement")
        elif kind == MIR_RECORD_PARAMETER:
            if func_index != active_function:
                return mir_validation_error(record_id, "parameter function")
            if block_index == -1 and active_block >= 0:
                return mir_validation_error(record_id, "function parameter placement")
            if block_index >= 0 and (block_index != active_block or block_has_terminator):
                return mir_validation_error(record_id, "block parameter placement")
            if result_value < 0:
                return mir_validation_error(record_id, "parameter value")
        elif kind == MIR_RECORD_TERMINATOR:
            if func_index != active_function or block_index != active_block or block_has_terminator:
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
            if operand_kind == MIR_OPERAND_VALUE and not mir_value_exists_in_function(index, func_index,
                operand_value):
                return mir_validation_error(record_id, "unknown SSA value")
            operand_index = operand_index + 1
        if kind == MIR_RECORD_TERMINATOR and opcode == MIR_TERM_JUMP:
            let target_offset = mir_value_offset(operand_start)
            if values[target_offset] != MIR_OPERAND_BLOCK:
                return mir_validation_error(record_id, "jump target")
            let target_block = values[target_offset + 1]
            if not mir_block_exists(index, func_index, target_block):
                return mir_validation_error(record_id, "unknown jump block")
            let parameter_count = mir_block_parameter_count(index, func_index, target_block)
            if operand_count != parameter_count + 1:
                eprint(record_id)
                eprint(" fn=")
                eprint(func_index)
                eprint(" opc=")
                eprint(operand_count)
                eprint(" tgt=")
                eprint(target_block)
                eprint(" pc=")
                eprint(parameter_count)
                let debug_index = 0
                while debug_index < operand_count:
                    let debug_offset = mir_value_offset(operand_start + debug_index)
                    eprint(" v")
                    eprint(mir_int_list_get(values, debug_offset))
                    eprint(":")
                    eprint(mir_int_list_get(values, debug_offset + 1))
                    debug_index = debug_index + 1
                eprintln("")
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
                if not mir_block_exists(index, func_index, values[target_offset + 1]):
                    return mir_validation_error(record_id, "unknown branch block")
                let expected_argument_count = 0
                if branch_target_index == 1:
                    expected_argument_count = true_argument_count
                else:
                    expected_argument_count = false_argument_count
                if mir_block_parameter_count(index, func_index,
                    values[target_offset + 1]) != expected_argument_count:
                    eprint(record_id)
                    eprint(" tgt=")
                    eprint(branch_target_index)
                    eprint(" blk=")
                    eprint(values[target_offset + 1])
                    eprint(" exp=")
                    eprint(expected_argument_count)
                    eprint(" got=")
                    eprint(mir_block_parameter_count(index, func_index, values[target_offset + 1]))
                    eprintln("")
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

def mir_dump_program(program: MirProgram, output: Buffer) -> bool:
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
        append(output, mir_int_list_get(program.records, offset))
        append(output, " function=")
        append(output, mir_int_list_get(program.records, offset + 1))
        append(output, " block=")
        append(output, mir_int_list_get(program.records, offset + 2))
        append(output, " opcode=")
        append(output, mir_int_list_get(program.records, offset + 3))
        append(output, " type=")
        append(output, mir_int_list_get(program.records, offset + 4))
        append(output, " result=")
        append(output, mir_int_list_get(program.records, offset + 5))
        append(output, " operands=")
        append(output, mir_int_list_get(program.records, offset + 7))
        append(output, " [")
        let operand_index = 0
        while operand_index < mir_int_list_get(program.records, offset + 7):
            if operand_index > 0:
                append(output, ",")
            let value_offset = mir_value_offset(mir_int_list_get(program.records, offset + 6) + operand_index)
            append(output, mir_int_list_get(program.values, value_offset))
            append(output, ":")
            append(output, mir_int_list_get(program.values, value_offset + 1))
            operand_index = operand_index + 1
        append(output, "]")
        append(output, "\n")
        record_id = record_id + 1
    return true
