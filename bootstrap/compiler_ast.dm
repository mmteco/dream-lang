# AST 节点池:扁平 list[int],节点 = [kind, token_start, token_end, arg0...argN]
# 节点索引 = 池中 kind 字段的下标;池首 dummy 节点(kind=0),真实节点 >= 1,0 表示"无节点"
# 子节点区间 [child_start, child_end) 可走查:从 child_start 循环 ast_next_node 直到 child_end

from compiler_lex import TOKEN_EOF, TOKEN_INTEGER, TOKEN_IDENTIFIER, TOKEN_LET, TOKEN_PRINT, TOKEN_PLUS, TOKEN_MINUS, TOKEN_MULTIPLY, TOKEN_DIVIDE, TOKEN_OPEN_PAREN, TOKEN_CLOSE_PAREN, TOKEN_ASSIGN, TOKEN_NEWLINE, TOKEN_DEF, TOKEN_RETURN, TOKEN_COLON, TOKEN_COMMA, TOKEN_ARROW, TOKEN_LESS, TOKEN_IF, TOKEN_ELIF, TOKEN_ELSE, TOKEN_WHILE, TOKEN_SWITCH, TOKEN_CASE, TOKEN_DEFAULT, TOKEN_STRING, TOKEN_OPEN_BRACKET, TOKEN_CLOSE_BRACKET, TOKEN_EQUAL, TOKEN_NOT_EQUAL, TOKEN_LESS_EQUAL, TOKEN_GREATER_EQUAL, TOKEN_GREATER, TOKEN_AND, TOKEN_OR, TOKEN_MODULO, TOKEN_TRUE, TOKEN_FALSE, TOKEN_FOR, TOKEN_OPEN_BRACE, TOKEN_CLOSE_BRACE, TOKEN_DOT, TOKEN_QUESTION, TOKEN_FLOAT, TOKEN_NOT, TOKEN_CONS, TOKEN_RUNE, TOKEN_BREAK, TOKEN_EPRINT

# kind 编号按类别分组,组内连续,组间留空便于未来插入:
# 表达式 1-31
# 语句 32-63
# 模式 64-95
# 其他 96-127

# === 表达式 ===
const AST_EXPR_INT: int = 1
const AST_EXPR_FLOAT: int = 2
const AST_EXPR_STRING: int = 3
const AST_EXPR_RUNE: int = 4
const AST_EXPR_BOOL: int = 5
const AST_EXPR_VAR: int = 6
const AST_EXPR_CALL: int = 7
const AST_EXPR_METHOD_CALL: int = 8
const AST_EXPR_ATTR: int = 9
const AST_EXPR_BINARY: int = 10
const AST_EXPR_UNARY: int = 11
const AST_EXPR_LOGICAL: int = 12
const AST_EXPR_COND: int = 13
const AST_EXPR_LIST: int = 14
const AST_EXPR_TUPLE: int = 15
const AST_EXPR_DICT: int = 16
const AST_EXPR_STRUCT: int = 17
const AST_EXPR_ENUM: int = 18
const AST_EXPR_BUILTIN_ENUM: int = 19
const AST_EXPR_INDEX: int = 20
const AST_EXPR_SLICE: int = 21
const AST_EXPR_LAMBDA: int = 22
const AST_EXPR_LIST_COMP: int = 23
const AST_EXPR_MATCH: int = 24
const AST_EXPR_PRINT: int = 25

# === 语句 ===
const AST_STMT_LET: int = 32
const AST_STMT_LET_TUPLE: int = 33
const AST_STMT_ASSIGN: int = 34
const AST_STMT_IF: int = 35
const AST_ELIF: int = 36
const AST_STMT_WHILE: int = 37
const AST_STMT_FOR: int = 38
const AST_STMT_SWITCH: int = 39
const AST_CASE: int = 40
const AST_STMT_RETURN: int = 41
const AST_STMT_EXPR: int = 42
const AST_STMT_BREAK: int = 43

# === 模式 ===
const AST_PAT_WILDCARD: int = 64
const AST_PAT_INT: int = 65
const AST_PAT_RUNE: int = 66
const AST_PAT_BOOL: int = 67
const AST_PAT_FLOAT: int = 68
const AST_PAT_STRING: int = 69
const AST_PAT_VAR: int = 70
const AST_PAT_ENUM: int = 71
const AST_PAT_BUILTIN: int = 72
const AST_PAT_LIST: int = 73
const AST_PAT_CONS: int = 74
const AST_PAT_STRUCT: int = 75

# === 其他 ===
const AST_M_CASE: int = 96

# 节点池布局: [kind, token_start, token_end, arg0...argN]
const AST_HEADER_KIND: int = 0
const AST_HEADER_START: int = 1
const AST_HEADER_END: int = 2
const AST_HEADER_SIZE: int = 3
const AST_NODE_INVALID: int = 0  # 解析失败/无节点的哨兵值
const AST_POOL_DUMMY: int = 0    # 池首占位节点(kind=0)

# kind → 节点大小查找表（CALL=7 与 STRUCT=17 动态，特判）；kind 最大 96
let AST_NODE_SIZE_LOOKUP: list[int] = [0, 4, 3, 3, 4, 4, 3, 0, 16, 6, 6, 5, 6, 7, 17, 17, 44, 0, 9, 6, 5, 6, 8, 10, 7, 5, 0, 0, 0, 0, 0, 0, 10, 7, 9, 10, 6, 6, 8, 8, 6, 6, 5, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 4, 4, 3, 3, 3, 9, 6, 5, 7, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7]

# 二元/一元/条件表达式节点参数索引
const ARG_OPERATOR: int = 0
const ARG_LEFT: int = 1
const ARG_RIGHT: int = 2
const ARG_OPERAND: int = 1
const ARG_COND: int = 0
const ARG_THEN: int = 1
const ARG_ELSE: int = 2
const ARG_IS_EXPRESSION: int = 3

# 节点参数个数(size - 头部)
const ARGS_LEAF: int = 1
const ARGS_BINARY: int = 3
const ARGS_UNARY: int = 2
const ARGS_COND: int = 4
const ARGS_CALL: int = 23
const ARGS_METHOD_CALL: int = 13
const ARGS_ATTR: int = 3
const ARGS_INDEX: int = 2
const ARGS_SLICE: int = 3
const ARGS_STRUCT_BASE: int = 5
const ARGS_ENUM: int = 6
const ARGS_BUILTIN_ENUM: int = 3
const ARGS_LIST_TUPLE_DICT: int = 14
const ARGS_DICT: int = 41
const ARGS_LAMBDA: int = 5
const ARGS_LIST_COMP: int = 7
const ARGS_MATCH: int = 4
const ARGS_PRINT: int = 1
const ARGS_STMT_LET: int = 7
const ARGS_STMT_LET_TUPLE: int = 4
const ARGS_STMT_ASSIGN: int = 6
const ARGS_STMT_IF: int = 7
const ARGS_ELIF: int = 3
const ARGS_STMT_WHILE: int = 3
const ARGS_STMT_FOR: int = 5
const ARGS_STMT_SWITCH: int = 5
const ARGS_CASE: int = 3
const ARGS_STMT_RETURN: int = 3
const ARGS_STMT_EXPR: int = 2
const ARGS_M_CASE: int = 4
const ARGS_PAIR: int = 2
const ARGS_PAT_CONS: int = 4
const ARGS_PAT_STRUCT: int = 6

const EXPR_BINDING_NONE: int = 0
const EXPR_BINDING_COND: int = 5
const EXPR_BINDING_OR: int = 10
const EXPR_BINDING_AND: int = 20
const EXPR_BINDING_COMPARE: int = 30
const EXPR_BINDING_ADD: int = 40
const EXPR_BINDING_MULTIPLY: int = 50

def ast_kind_name(kind: int) -> str:
    switch kind:
        case AST_EXPR_INT:
            return "expr_int"
        case AST_EXPR_FLOAT:
            return "expr_float"
        case AST_EXPR_STRING:
            return "expr_string"
        case AST_EXPR_RUNE:
            return "expr_rune"
        case AST_EXPR_BOOL:
            return "expr_bool"
        case AST_EXPR_VAR:
            return "expr_var"
        case AST_EXPR_CALL:
            return "expr_call"
        case AST_EXPR_METHOD_CALL:
            return "expr_method_call"
        case AST_EXPR_ATTR:
            return "expr_attr"
        case AST_EXPR_BINARY:
            return "expr_binary"
        case AST_EXPR_UNARY:
            return "expr_unary"
        case AST_EXPR_LOGICAL:
            return "expr_logical"
        case AST_EXPR_COND:
            return "expr_cond"
        case AST_EXPR_LIST:
            return "expr_list"
        case AST_EXPR_TUPLE:
            return "expr_tuple"
        case AST_EXPR_DICT:
            return "expr_dict"
        case AST_EXPR_STRUCT:
            return "expr_struct"
        case AST_EXPR_ENUM:
            return "expr_enum"
        case AST_EXPR_BUILTIN_ENUM:
            return "expr_builtin_enum"
        case AST_EXPR_INDEX:
            return "expr_index"
        case AST_EXPR_SLICE:
            return "expr_slice"
        case AST_EXPR_LAMBDA:
            return "expr_lambda"
        case AST_EXPR_LIST_COMP:
            return "expr_list_comp"
        case AST_EXPR_MATCH:
            return "expr_match"
        case AST_EXPR_PRINT:
            return "expr_print"
        case AST_STMT_LET:
            return "stmt_let"
        case AST_STMT_LET_TUPLE:
            return "stmt_let_tuple"
        case AST_STMT_ASSIGN:
            return "stmt_assign"
        case AST_STMT_IF:
            return "stmt_if"
        case AST_ELIF:
            return "stmt_elif"
        case AST_STMT_WHILE:
            return "stmt_while"
        case AST_STMT_FOR:
            return "stmt_for"
        case AST_STMT_SWITCH:
            return "stmt_switch"
        case AST_CASE:
            return "stmt_case"
        case AST_STMT_RETURN:
            return "stmt_return"
        case AST_STMT_EXPR:
            return "stmt_expr"
        case AST_STMT_BREAK:
            return "stmt_break"
        case AST_M_CASE:
            return "m_case"
        case AST_PAT_WILDCARD:
            return "pat_wildcard"
        case AST_PAT_INT:
            return "pat_int"
        case AST_PAT_RUNE:
            return "pat_rune"
        case AST_PAT_BOOL:
            return "pat_bool"
        case AST_PAT_FLOAT:
            return "pat_float"
        case AST_PAT_STRING:
            return "pat_string"
        case AST_PAT_VAR:
            return "pat_var"
        case AST_PAT_ENUM:
            return "pat_enum"
        case AST_PAT_BUILTIN:
            return "pat_builtin"
        case AST_PAT_LIST:
            return "pat_list"
        case AST_PAT_CONS:
            return "pat_cons"
        case AST_PAT_STRUCT:
            return "pat_struct"
    return "unknown"

def ast_node_size(ast: list[int], node: int) -> int:
    let kind = ast_node_kind(ast, node)
    if kind == AST_EXPR_CALL:
        return AST_HEADER_SIZE + 3 + ast_node_arg(ast, node, 1)
    if kind == AST_EXPR_LIST:
        return AST_HEADER_SIZE + 1 + ast_node_arg(ast, node, 0)
    if kind == AST_EXPR_STRUCT:
        return AST_HEADER_SIZE + ARGS_STRUCT_BASE + ast_node_arg(ast, node, 4)
    if kind >= 0 and kind <= 96:
        return ast_int_list_get(AST_NODE_SIZE_LOOKUP, kind)
    return 0

def ast_node_kind(ast: list[int], node: int) -> int:
    return ast_int_list_get(ast, node)

def ast_node_start(ast: list[int], node: int) -> int:
    return ast_int_list_get(ast, node + 1)

def ast_node_end(ast: list[int], node: int) -> int:
    return ast_int_list_get(ast, node + 2)

def ast_node_arg(ast: list[int], node: int, argument_index: int) -> int:
    return ast_int_list_get(ast, node + 3 + argument_index)

def ast_next_node(ast: list[int], node: int) -> int:
    return node + ast_node_size(ast, node)

def ast_stmt_next_node(ast: list[int], node: int) -> int:
    let kind = ast_node_kind(ast, node)
    switch kind:
        case AST_STMT_LET:
            return ast_node_arg(ast, node, 6)
        case AST_STMT_LET_TUPLE:
            return ast_node_arg(ast, node, 3)
        case AST_STMT_ASSIGN:
            return ast_node_arg(ast, node, 5)
        case AST_STMT_IF:
            return ast_node_arg(ast, node, 6)
        case AST_STMT_WHILE:
            return ast_node_arg(ast, node, 2)
        case AST_STMT_FOR:
            return ast_node_arg(ast, node, 4)
        case AST_STMT_SWITCH:
            return ast_node_arg(ast, node, 4)
        case AST_STMT_RETURN:
            return ast_node_arg(ast, node, 2)
        case AST_ELIF:
            return ast_node_arg(ast, node, 2)
        case AST_CASE:
            return ast_node_arg(ast, node, 2)
        case AST_M_CASE:
            return ast_node_arg(ast, node, 3)
        case AST_STMT_EXPR:
            return ast_node_arg(ast, node, 1)
        default:
            return ast_next_node(ast, node)

def ast_append_node(ast: list[int], kind: int, token_start: int, token_end: int, argument_count: int) -> int:
    let node = len(ast)
    append(ast, kind)
    append(ast, token_start)
    append(ast, token_end)
    let argument_index = 0
    while argument_index < argument_count:
        append(ast, 0)
        argument_index = argument_index + 1
    return node

def ast_append_leaf(ast: list[int], kind: int, token_start: int, token_end: int, value: int) -> int:
    let node = ast_append_node(ast, kind, token_start, token_end, ARGS_LEAF)
    ast[node + 3] = value
    return node

def ast_set_arg(ast: list[int], node: int, argument_index: int, value: int):
    let target_index = node + 3 + argument_index
    ast[target_index] = value

def ast_next_index(index: int) -> int:
    return index + 1

def ast_advance_index(index: int, amount: int) -> int:
    return index + amount

def ast_int_list_get(values: list[int], index: int) -> int:
    return values[index]

def ast_node_index_is_valid(ast: list[int], node: int) -> bool:
    if node <= 0 or node >= len(ast):
        return false
    let current_node = 1
    while current_node < node:
        let node_size = ast_node_size(ast, current_node)
        if node_size < AST_HEADER_SIZE or current_node + node_size > len(ast):
            return false
        current_node = current_node + node_size
    return current_node == node

def ast_range_is_walkable(ast: list[int], start: int, end: int) -> bool:
    if start == 0 and end == 0:
        return true
    if start <= 0 or end < start or end > len(ast):
        return false
    if not ast_node_index_is_valid(ast, start):
        return false
    let node = start
    while node < end:
        let node_size = ast_node_size(ast, node)
        if node_size == 0 or node + node_size > len(ast):
            return false
        let next = node + node_size
        if next <= node:
            return false
        node = next
    return node == end

def ast_optional_range_is_walkable(ast: list[int], start: int, end: int) -> bool:
    if start == 0:
        return end >= 0 and end <= len(ast)
    return ast_range_is_walkable(ast, start, end)

def ast_child_is_valid(ast: list[int], node: int) -> bool:
    if node == AST_NODE_INVALID:
        return true
    return ast_node_index_is_valid(ast, node)

def ast_required_child_is_valid(ast: list[int], node: int) -> bool:
    if node == AST_NODE_INVALID:
        return false
    return ast_node_index_is_valid(ast, node)

def ast_validate_child_array(ast: list[int], node: int, count_argument: int, first_argument: int, max_count: int) -> bool:
    let child_count = ast_node_arg(ast, node, count_argument)
    if child_count < 0 or child_count > max_count:
        return false
    let child_index = 0
    while child_index < child_count:
        if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, first_argument + child_index)):
            return false
        child_index = child_index + 1
    return true

def ast_validate_node_children(ast: list[int], node: int) -> bool:
    let kind = ast_node_kind(ast, node)
    switch kind:
        case AST_EXPR_CALL:
            if ast_node_arg(ast, node, 1) < 0 or node + ast_node_size(ast, node) > len(ast):
                return false
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_validate_child_array(ast, node, 1, 3, len(ast))
        case AST_EXPR_METHOD_CALL:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_validate_child_array(ast, node, 3, 5, 8)
        case AST_EXPR_ATTR:
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0))
        case AST_EXPR_BINARY:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_LEFT)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_RIGHT))
        case AST_EXPR_LOGICAL:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_LEFT)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_RIGHT))
        case AST_EXPR_UNARY:
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_OPERAND))
        case AST_EXPR_COND:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_COND)):
                return false
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_THEN)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, ARG_ELSE))
        case AST_EXPR_LIST:
            let list_count = ast_node_arg(ast, node, 0)
            if list_count < 0:
                return false
            let list_index = 0
            while list_index < list_count:
                if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 1 + list_index)):
                    return false
                list_index = list_index + 1
            return true
        case AST_EXPR_TUPLE:
            return ast_validate_child_array(ast, node, 0, 1, 13)
        case AST_EXPR_DICT:
            if not ast_validate_child_array(ast, node, 0, 1, 20):
                return false
            let pair_count = ast_node_arg(ast, node, 0)
            let pair_index = 0
            while pair_index < pair_count:
                if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 21 + pair_index)):
                    return false
                pair_index = pair_index + 1
            return true
        case AST_EXPR_STRUCT:
            let field_count = ast_node_arg(ast, node, 4)
            if field_count < 0:
                return false
            if node + AST_HEADER_SIZE + ARGS_STRUCT_BASE + field_count > len(ast):
                return false
            return ast_validate_child_array(ast, node, 4, 5, field_count)
        case AST_EXPR_INDEX:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 1))
        case AST_EXPR_SLICE:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_child_is_valid(ast, ast_node_arg(ast, node, 1)):
                return false
            return ast_child_is_valid(ast, ast_node_arg(ast, node, 2))
        case AST_EXPR_LAMBDA:
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 2))
        case AST_EXPR_LIST_COMP:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 3)):
                return false
            return ast_child_is_valid(ast, ast_node_arg(ast, node, 6))
        case AST_EXPR_MATCH:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_range_is_walkable(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2))
        case AST_EXPR_PRINT:
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0))
        case AST_STMT_LET:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 4)):
                return false
            return ast_range_is_walkable(ast, node, ast_node_arg(ast, node, 6))
        case AST_STMT_LET_TUPLE:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 2)):
                return false
            return ast_range_is_walkable(ast, node, ast_node_arg(ast, node, 3))
        case AST_STMT_ASSIGN:
            if ast_node_arg(ast, node, 2) != 0 and not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 3)):
                return false
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 4)):
                return false
            return ast_range_is_walkable(ast, node, ast_node_arg(ast, node, 5))
        case AST_STMT_IF:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_range_is_walkable(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2)):
                return false
            if not ast_range_is_walkable(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4)):
                return false
            return ast_optional_range_is_walkable(ast, ast_node_arg(ast, node, 5), ast_node_arg(ast, node, 6))
        case AST_ELIF:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_range_is_walkable(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2))
        case AST_STMT_WHILE:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_range_is_walkable(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2))
        case AST_STMT_FOR:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 2)):
                return false
            return ast_range_is_walkable(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4))
        case AST_STMT_SWITCH:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_range_is_walkable(ast, ast_node_arg(ast, node, 1), ast_node_arg(ast, node, 2)):
                return false
            return ast_optional_range_is_walkable(ast, ast_node_arg(ast, node, 3), ast_node_arg(ast, node, 4))
        case AST_CASE:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_child_is_valid(ast, ast_node_arg(ast, node, 1)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 2))
        case AST_STMT_RETURN:
            if not ast_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_range_is_walkable(ast, node, ast_node_arg(ast, node, 2))
        case AST_STMT_EXPR:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            return ast_range_is_walkable(ast, node, ast_node_arg(ast, node, 1))
        case AST_M_CASE:
            if not ast_required_child_is_valid(ast, ast_node_arg(ast, node, 0)):
                return false
            if not ast_child_is_valid(ast, ast_node_arg(ast, node, 1)):
                return false
            return ast_required_child_is_valid(ast, ast_node_arg(ast, node, 2))
        default:
            return true

def ast_validate_program(ast: list[int]) -> bool:
    if len(ast) == 0:
        return false
    if ast[0] != 0:
        return false
    let node = 1
    while node < len(ast):
        if not ast_validate_node_children(ast, node):
            __c_eprint_text("AST validation failed node=")
            __c_eprint_int(node)
            __c_eprint_text(" kind=")
            __c_eprint_int(ast_node_kind(ast, node))
            __c_eprint_text(" args=")
            let diagnostic_argument_index = 0
            while diagnostic_argument_index < ast_node_size(ast, node) - AST_HEADER_SIZE:
                if diagnostic_argument_index > 0:
                    __c_eprint_text(",")
                __c_eprint_int(ast_node_arg(ast, node, diagnostic_argument_index))
                diagnostic_argument_index = diagnostic_argument_index + 1
            __c_eprint_text("\n")
            return false
        node = node + ast_node_size(ast, node)
    return true

def ast_parse_primary(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let kind = token_kind(kinds, index)
    if kind == TOKEN_INTEGER:
        let value = parse_integer(source, token_start(starts, index), token_end(ends, index))
        return (ast_next_index(index), ast_append_leaf(ast, AST_EXPR_INT, token_start(starts, index), token_end(ends, index), value))
    if kind == TOKEN_RUNE:
        let rune_value = parse_rune_literal(source, token_start(starts, index), token_end(ends, index))
        return (ast_next_index(index), ast_append_leaf(ast, AST_EXPR_RUNE, token_start(starts, index), token_end(ends, index), rune_value))
    if kind == TOKEN_FLOAT:
        return (ast_next_index(index), ast_append_node(ast, AST_EXPR_FLOAT, token_start(starts, index), token_end(ends, index), 0))
    if kind == TOKEN_STRING:
        return (ast_next_index(index), ast_append_node(ast, AST_EXPR_STRING, token_start(starts, index), token_end(ends, index), 0))
    if kind == TOKEN_TRUE:
        return (ast_next_index(index), ast_append_leaf(ast, AST_EXPR_BOOL, token_start(starts, index), token_end(ends, index), 1))
    if kind == TOKEN_FALSE:
        return (ast_next_index(index), ast_append_leaf(ast, AST_EXPR_BOOL, token_start(starts, index), token_end(ends, index), 0))
    if kind == TOKEN_IDENTIFIER:
        let identifier_name_start = token_start(starts, index)
        let identifier_name_end = token_end(ends, index)
        if __c_range_equals_cstr(source, identifier_name_start, identifier_name_end, "match"):
            return ast_parse_match_expression(context, index, ast, 0)
        if __c_range_equals_cstr(source, identifier_name_start, identifier_name_end, "lambda"):
            return ast_parse_lambda(context, index, ast)
        if __c_range_equals_cstr(source, identifier_name_start, identifier_name_end, "None"):
            let none_node = ast_append_node(ast, AST_EXPR_BUILTIN_ENUM, identifier_name_start, identifier_name_end, ARGS_BUILTIN_ENUM)
            ast_set_arg(ast, none_node, 0, 1)
            return (ast_next_index(index), none_node)
        let next_index = ast_next_index(index)
        if token_kind(kinds, next_index) == TOKEN_OPEN_BRACE:
            return ast_parse_struct_literal(context, index, ast)
        let var_node = ast_append_node(ast, AST_EXPR_VAR, identifier_name_start, identifier_name_end, 0)
        return (next_index, var_node)
    if kind == TOKEN_IF:
        let (cond_next_index, cond_node) = ast_parse_expression(context, index + 1, ast)
        if cond_node == 0:
            return (index, 0)
        let colon_index = cond_next_index
        while token_kind(kinds, colon_index) != TOKEN_COLON and token_kind(kinds, colon_index) != TOKEN_NEWLINE and token_kind(kinds, colon_index) != TOKEN_EOF:
            colon_index = colon_index + 1
        if token_kind(kinds, colon_index) != TOKEN_COLON:
            return (index, 0)
        let (then_next_index, then_node) = ast_parse_expression(context, colon_index + 1, ast)
        if then_node == 0:
            return (index, 0)
        let else_keyword = then_next_index
        while token_kind(kinds, else_keyword) != TOKEN_ELSE and token_kind(kinds, else_keyword) != TOKEN_NEWLINE and token_kind(kinds, else_keyword) != TOKEN_EOF:
            else_keyword = else_keyword + 1
        if token_kind(kinds, else_keyword) != TOKEN_ELSE:
            return (index, 0)
        let else_colon = else_keyword + 1
        while token_kind(kinds, else_colon) != TOKEN_COLON and token_kind(kinds, else_colon) != TOKEN_NEWLINE and token_kind(kinds, else_colon) != TOKEN_EOF:
            else_colon = else_colon + 1
        if token_kind(kinds, else_colon) != TOKEN_COLON:
            return (index, 0)
        let (else_next_index, else_node) = ast_parse_expression(context, else_colon + 1, ast)
        if else_node == 0:
            return (index, 0)
        let cond_node2 = ast_append_node(ast, AST_EXPR_COND, 0, 0, ARGS_COND)
        ast_set_arg(ast, cond_node2, ARG_COND, cond_node)
        ast_set_arg(ast, cond_node2, ARG_THEN, then_node)
        ast_set_arg(ast, cond_node2, ARG_ELSE, else_node)
        ast_set_arg(ast, cond_node2, ARG_IS_EXPRESSION, 0)
        return (else_next_index, cond_node2)
    if kind == TOKEN_OPEN_BRACKET:
        return ast_parse_list_or_comprehension(context, index, ast)
    if kind == TOKEN_OPEN_BRACE:
        return ast_parse_dict_literal(context, index, ast)
    if kind == TOKEN_OPEN_PAREN:
        let tuple_scan_index = index + 1
        let tuple_scan_depth = 0
        let tuple_scan_done = false
        let tuple_has_comma = false
        while not tuple_scan_done and token_kind(kinds, tuple_scan_index) != TOKEN_EOF:
            if token_kind(kinds, tuple_scan_index) == TOKEN_OPEN_PAREN:
                tuple_scan_depth = tuple_scan_depth + 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_CLOSE_PAREN:
                if tuple_scan_depth == 0:
                    tuple_scan_done = true
                if tuple_scan_depth > 0:
                    tuple_scan_depth = tuple_scan_depth - 1
            if token_kind(kinds, tuple_scan_index) == TOKEN_COMMA and tuple_scan_depth == 0:
                tuple_has_comma = true
            if not tuple_scan_done:
                tuple_scan_index = tuple_scan_index + 1
        if tuple_has_comma:
            return ast_parse_tuple_literal(context, index, ast)
        let group_index = ast_next_index(index)
        let (group_next_index, group_node) = ast_parse_expression(context, group_index, ast)
        if group_node == 0:
            return (index, 0)
        if token_kind(kinds, group_next_index) == TOKEN_CLOSE_PAREN:
            return (ast_next_index(group_next_index), group_node)
        return (index, 0)
    return (index, 0)

def ast_infix_binding_power(operator: int) -> (int, int):
    if operator == TOKEN_OR:
        return (EXPR_BINDING_OR, EXPR_BINDING_OR + 1)
    if operator == TOKEN_AND:
        return (EXPR_BINDING_AND, EXPR_BINDING_AND + 1)
    if operator == TOKEN_LESS or operator == TOKEN_EQUAL or operator == TOKEN_NOT_EQUAL or operator == TOKEN_LESS_EQUAL or operator == TOKEN_GREATER_EQUAL or operator == TOKEN_GREATER:
        return (EXPR_BINDING_COMPARE, EXPR_BINDING_COMPARE + 1)
    if operator == TOKEN_PLUS or operator == TOKEN_MINUS:
        return (EXPR_BINDING_ADD, EXPR_BINDING_ADD + 1)
    if operator == TOKEN_MULTIPLY or operator == TOKEN_DIVIDE or operator == TOKEN_MODULO:
        return (EXPR_BINDING_MULTIPLY, EXPR_BINDING_MULTIPLY + 1)
    return (EXPR_BINDING_NONE, EXPR_BINDING_NONE)

def ast_append_binary_node(ast: list[int], operator: int, left_node: int, right_node: int) -> int:
    let node = ast_append_node(ast, AST_EXPR_BINARY, 0, 0, ARGS_BINARY)
    ast_set_arg(ast, node, ARG_OPERATOR, operator)
    ast_set_arg(ast, node, ARG_LEFT, left_node)
    ast_set_arg(ast, node, ARG_RIGHT, right_node)
    return node

def ast_append_logical_node(ast: list[int], operator: int, left_node: int, right_node: int) -> int:
    let node = ast_append_node(ast, AST_EXPR_LOGICAL, 0, 0, ARGS_BINARY)
    ast_set_arg(ast, node, ARG_OPERATOR, operator)
    ast_set_arg(ast, node, ARG_LEFT, left_node)
    ast_set_arg(ast, node, ARG_RIGHT, right_node)
    return node

def ast_append_unary_node(ast: list[int], operator: int, operand_node: int) -> int:
    let node = ast_append_node(ast, AST_EXPR_UNARY, 0, 0, ARGS_UNARY)
    ast_set_arg(ast, node, ARG_OPERATOR, operator)
    ast_set_arg(ast, node, ARG_OPERAND, operand_node)
    return node

def ast_parse_unary(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let operator = token_kind(context.kinds, index)
    if operator == TOKEN_NOT or operator == TOKEN_PLUS or operator == TOKEN_MINUS:
        let operand_index = ast_next_index(index)
        let (next_index, operand_node) = ast_parse_unary(context, operand_index, ast)
        if operand_node == 0 or next_index <= index:
            return (index, 0)
        return (next_index, ast_append_unary_node(ast, operator, operand_node))
    let (primary_next_index, primary_node) = ast_parse_primary(context, index, ast)
    if primary_node == 0:
        return (index, 0)
    let (postfix_next_index, postfix_node) = ast_parse_postfix(context, primary_node, primary_next_index, ast)
    return (postfix_next_index, postfix_node)

def ast_has_ternary_colon(context: ParseContext, index: int) -> bool:
    let kinds = context.kinds
    let cursor = index
    let paren_depth = 0
    let bracket_depth = 0
    let brace_depth = 0
    let scanning = true
    while scanning and token_kind(kinds, cursor) != TOKEN_EOF:
        let kind = token_kind(kinds, cursor)
        if kind == TOKEN_NEWLINE and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
            scanning = false
        if kind == TOKEN_OPEN_PAREN:
            paren_depth = paren_depth + 1
        if kind == TOKEN_CLOSE_PAREN and paren_depth > 0:
            paren_depth = paren_depth - 1
        if kind == TOKEN_OPEN_BRACKET:
            bracket_depth = bracket_depth + 1
        if kind == TOKEN_CLOSE_BRACKET and bracket_depth > 0:
            bracket_depth = bracket_depth - 1
        if kind == TOKEN_OPEN_BRACE:
            brace_depth = brace_depth + 1
        if kind == TOKEN_CLOSE_BRACE and brace_depth > 0:
            brace_depth = brace_depth - 1
        if kind == TOKEN_COLON and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
            return true
        cursor = cursor + 1
    return false

def ast_parse_expression_bp(context: ParseContext, index: int, min_binding_power: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let (first_index, first_node) = ast_parse_unary(context, index, ast)
    if first_node == 0:
        return (index, 0)

    let current_index = first_index
    let current_node = first_node
    let parsing = true
    while parsing:
        let operator = token_kind(kinds, current_index)
        if operator == TOKEN_QUESTION:
            let question_next_index = ast_next_index(current_index)
            let question_next_kind = token_kind(kinds, question_next_index)
            if question_next_kind == TOKEN_NEWLINE or question_next_kind == TOKEN_EOF or not ast_has_ternary_colon(context, question_next_index):
                parsing = false
            if parsing and EXPR_BINDING_COND < min_binding_power:
                parsing = false
            if parsing:
                let then_index_start = ast_next_index(current_index)
                let (then_index, then_node) = ast_parse_expression_bp(context, then_index_start, 0, ast)
                if then_node == 0 or token_kind(kinds, then_index) != TOKEN_COLON:
                    return (index, 0)
                let else_index_start = ast_next_index(then_index)
                let (else_index, else_node) = ast_parse_expression_bp(context, else_index_start, EXPR_BINDING_COND, ast)
                if else_node == 0:
                    return (index, 0)
                let conditional_node = ast_append_node(ast, AST_EXPR_COND, 0, 0, ARGS_COND)
                ast_set_arg(ast, conditional_node, ARG_COND, current_node)
                ast_set_arg(ast, conditional_node, ARG_THEN, then_node)
                ast_set_arg(ast, conditional_node, ARG_ELSE, else_node)
                ast_set_arg(ast, conditional_node, ARG_IS_EXPRESSION, 1)
                current_index = else_index
                current_node = conditional_node
        if parsing and operator != TOKEN_QUESTION:
            let (left_binding_power, right_binding_power) = ast_infix_binding_power(operator)
            if left_binding_power < min_binding_power or left_binding_power == EXPR_BINDING_NONE:
                parsing = false
            else:
                let right_index = ast_next_index(current_index)
                let (next_index, next_node) = ast_parse_expression_bp(context, right_index, right_binding_power, ast)
                if next_node == 0 or next_index <= current_index:
                    return (index, 0)
                if operator == TOKEN_AND or operator == TOKEN_OR:
                    current_node = ast_append_logical_node(ast, operator, current_node, next_node)
                else:
                    current_node = ast_append_binary_node(ast, operator, current_node, next_node)
                current_index = next_index
    return (current_index, current_node)

def ast_parse_expression(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    return ast_parse_expression_bp(context, index, 0, ast)

def ast_parse_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let token_kind_value = token_kind(kinds, index)
    if token_kind_value == TOKEN_LET:
        if token_kind(kinds, ast_next_index(index)) == TOKEN_OPEN_PAREN:
            return ast_parse_let_tuple_statement(context, index, body_end, ast)
        return ast_parse_let_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_RETURN:
        return ast_parse_return_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_BREAK:
        let break_node = ast_append_node(ast, AST_STMT_BREAK, token_start(starts, index), token_end(ends, index), 0)
        return (break_node, ast_next_index(index))
    if token_kind_value == TOKEN_IF:
        return ast_parse_if_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_WHILE:
        return ast_parse_while_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_FOR:
        return ast_parse_for_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_SWITCH:
        return ast_parse_switch_statement(context, index, body_end, ast)
    if token_kind_value == TOKEN_PRINT:
        let print_node = ast_parse_print_statement(context, index, ast, 0)
        let print_next_index = ast_scan_print_end(context, index)
        return (print_next_index, print_node)
    if token_kind_value == TOKEN_EPRINT:
        let eprint_node = ast_parse_print_statement(context, index, ast, 1)
        return (ast_scan_print_end(context, index), eprint_node)
    if token_kind_value == TOKEN_IDENTIFIER:
        let next_index = ast_next_index(index)
        let next_kind = token_kind(kinds, next_index)
        if next_kind == TOKEN_ASSIGN:
            return ast_parse_assign_statement(context, index, ast)
        if next_kind == TOKEN_DOT and token_kind(kinds, ast_advance_index(index, 2)) == TOKEN_IDENTIFIER and token_kind(kinds, ast_advance_index(index, 3)) == TOKEN_OPEN_BRACKET:
            let assign_probe_index = ast_advance_index(index, 4)
            while token_kind(kinds, assign_probe_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, assign_probe_index) != TOKEN_EOF:
                assign_probe_index = assign_probe_index + 1
            if token_kind(kinds, assign_probe_index) == TOKEN_CLOSE_BRACKET and token_kind(kinds, ast_next_index(assign_probe_index)) == TOKEN_ASSIGN:
                return ast_parse_attribute_element_assign_statement(context, index, ast)
        if next_kind == TOKEN_DOT and token_kind(kinds, ast_advance_index(index, 2)) == TOKEN_IDENTIFIER and token_kind(kinds, ast_advance_index(index, 3)) == TOKEN_ASSIGN:
            return ast_parse_attribute_assign_statement(context, index, ast)
        if next_kind == TOKEN_OPEN_BRACKET:
            let assign_probe_index = ast_advance_index(index, 2)
            while token_kind(kinds, assign_probe_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, assign_probe_index) != TOKEN_EOF:
                assign_probe_index = assign_probe_index + 1
            if token_kind(kinds, assign_probe_index) == TOKEN_CLOSE_BRACKET and token_kind(kinds, ast_next_index(assign_probe_index)) == TOKEN_ASSIGN:
                return ast_parse_element_assign_statement(context, index, ast)
        if __c_range_equals_cstr(source, token_start(starts, index), token_end(ends, index), "match"):
            return ast_parse_match_statement(context, index, body_end, ast)
        let expr_stmt_node = ast_append_node(ast, AST_STMT_EXPR, 0, 0, ARGS_STMT_EXPR)
        let (expression_next_index, expression_node) = ast_parse_expression(context, index, ast)
        if expression_node != 0:
            ast_set_arg(ast, expr_stmt_node, 0, expression_node)
            ast_set_arg(ast, expr_stmt_node, 1, len(ast))
            return (expression_next_index, expr_stmt_node)
    return (index, 0)

def ast_parse_statement_into(context: ParseContext, index: int, body_end: int, ast: list[int], result: list[int]) -> int:
    let (next_index, node) = ast_parse_statement(context, index, body_end, ast)
    result[0] = next_index
    result[1] = node
    return node

def ast_parse_let_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let starts = context.starts
    let ends = context.ends
    let kinds = context.kinds
    let name_index = ast_next_index(index)
    let let_name_start = token_start(starts, name_index)
    let let_name_end = token_end(ends, name_index)
    let let_annotation_start = 0
    let let_annotation_end = 0
    let let_value_index = ast_advance_index(index, 3)
    let annotation_index = ast_advance_index(index, 2)
    if token_kind(kinds, annotation_index) == TOKEN_COLON:
        let_annotation_start = token_start(starts, annotation_index)
        let_annotation_end = token_end(ends, annotation_index)
        let annotation_cursor = ast_advance_index(index, 3)
        while token_kind(kinds, annotation_cursor) != TOKEN_ASSIGN and token_kind(kinds, annotation_cursor) != TOKEN_NEWLINE and token_kind(kinds, annotation_cursor) != TOKEN_EOF:
            annotation_cursor = annotation_cursor + 1
        if token_kind(kinds, annotation_cursor) == TOKEN_ASSIGN:
            let_annotation_end = token_end(ends, annotation_cursor - 1)
            let_value_index = ast_next_index(annotation_cursor)
    let let_node = ast_append_node(ast, AST_STMT_LET, let_name_start, let_name_end, ARGS_STMT_LET)
    let (let_value_next_index, let_value_node) = ast_parse_expression(context, let_value_index, ast)
    if let_value_node == 0:
        return (index, 0)
    let question_flag = 0
    let let_next_index = let_value_next_index
    if token_kind(kinds, let_value_next_index) == TOKEN_QUESTION:
        question_flag = 1
        let_next_index = ast_next_index(let_value_next_index)
    ast_set_arg(ast, let_node, 0, let_name_start)
    ast_set_arg(ast, let_node, 1, let_name_end)
    ast_set_arg(ast, let_node, 2, let_annotation_start)
    ast_set_arg(ast, let_node, 3, let_annotation_end)
    ast_set_arg(ast, let_node, 4, let_value_node)
    ast_set_arg(ast, let_node, 5, question_flag)
    ast_set_arg(ast, let_node, 6, len(ast))
    return (let_next_index, let_node)

def ast_parse_let_tuple_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let tuple_name_index = index + 2
    let tuple_name_start = tuple_name_index
    while token_kind(kinds, tuple_name_index) != TOKEN_CLOSE_PAREN and token_kind(kinds, tuple_name_index) != TOKEN_NEWLINE and token_kind(kinds, tuple_name_index) != TOKEN_EOF:
        tuple_name_index = tuple_name_index + 1
    if token_kind(kinds, tuple_name_index) != TOKEN_CLOSE_PAREN:
        return (index, 0)
    let tuple_name_end = tuple_name_index
    let tuple_expression_index = tuple_name_index + 2
    let node = ast_append_node(ast, AST_STMT_LET_TUPLE, token_start(starts, index), token_end(ends, index), ARGS_STMT_LET_TUPLE)
    let (tuple_next_index, tuple_value_node) = ast_parse_expression(context, tuple_expression_index, ast)
    if tuple_value_node == 0:
        return (index, 0)
    if tuple_next_index > tuple_expression_index:
        ast[node + 2] = token_end(ends, tuple_next_index - 1)
    ast_set_arg(ast, node, 0, tuple_name_start)
    ast_set_arg(ast, node, 1, tuple_name_end)
    ast_set_arg(ast, node, 2, tuple_value_node)
    ast_set_arg(ast, node, 3, len(ast))
    return (tuple_next_index, node)

def ast_parse_return_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let return_node = ast_append_node(ast, AST_STMT_RETURN, token_start(context.starts, index), token_end(context.ends, index), ARGS_STMT_RETURN)
    let return_value_node = 0
    let return_tuple_flag = 0
    let return_next_index = index + 1
    if token_kind(kinds, index + 1) == TOKEN_OPEN_PAREN:
        let scan_index = index + 2
        let scan_depth = 1
        let has_comma = false
        while scan_index < body_end and scan_depth > 0:
            if token_kind(kinds, scan_index) == TOKEN_OPEN_PAREN:
                scan_depth = scan_depth + 1
            if token_kind(kinds, scan_index) == TOKEN_CLOSE_PAREN:
                scan_depth = scan_depth - 1
            if scan_depth == 1 and token_kind(kinds, scan_index) == TOKEN_COMMA:
                has_comma = true
            scan_index = scan_index + 1
        if has_comma:
            return_tuple_flag = 1
            let (tuple_next_index, tuple_node) = ast_parse_expression(context, index + 1, ast)
            return_next_index = tuple_next_index
            return_value_node = tuple_node
    if return_value_node == 0 and return_tuple_flag == 0:
        let (return_expr_next_index, return_expr_node) = ast_parse_expression(context, index + 1, ast)
        if return_expr_node != 0:
            return_value_node = return_expr_node
            return_next_index = return_expr_next_index
    ast_set_arg(ast, return_node, 0, return_value_node)
    ast_set_arg(ast, return_node, 1, return_tuple_flag)
    ast_set_arg(ast, return_node, 2, len(ast))
    return (return_next_index, return_node)

def ast_scan_print_end(context: ParseContext, index: int) -> int:
    let kinds = context.kinds
    let cursor = index + 1
    let depth = 0
    while token_kind(kinds, cursor) != TOKEN_EOF:
        let kind = token_kind(kinds, cursor)
        if kind == TOKEN_OPEN_PAREN:
            depth = depth + 1
        elif kind == TOKEN_CLOSE_PAREN:
            depth = depth - 1
            if depth == 0:
                return cursor + 1
        cursor = cursor + 1
    return index

def ast_parse_print_statement(context: ParseContext, index: int, ast: list[int], to_stderr: int) -> int:
    let starts = context.starts
    let ends = context.ends
    let print_stmt_node = ast_append_node(ast, AST_STMT_EXPR, 0, 0, ARGS_STMT_EXPR)
    let print_node = ast_append_node(ast, AST_EXPR_PRINT, token_start(starts, index), token_end(ends, index), 2)
    let value_index = ast_advance_index(index, 2)
    let (print_value_next_index, print_value_node) = ast_parse_expression(context, value_index, ast)
    if print_value_node == 0:
        return 0
    ast_set_arg(ast, print_node, 0, print_value_node)
    ast_set_arg(ast, print_node, 1, to_stderr)
    ast_set_arg(ast, print_stmt_node, 0, print_node)
    ast_set_arg(ast, print_stmt_node, 1, len(ast))
    return print_stmt_node

def ast_parse_assign_statement(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let starts = context.starts
    let ends = context.ends
    let kinds = context.kinds
    let name_start = token_start(starts, index)
    let name_end = token_end(ends, index)
    let node = ast_append_node(ast, AST_STMT_ASSIGN, name_start, name_end, ARGS_STMT_ASSIGN)
    let value_index = ast_advance_index(index, 2)
    let (value_next_index, value_node) = ast_parse_expression(context, value_index, ast)
    if value_node == 0:
        return (index, 0)
    ast_set_arg(ast, node, 0, name_start)
    ast_set_arg(ast, node, 1, name_end)
    ast_set_arg(ast, node, 2, 0)
    ast_set_arg(ast, node, 3, 0)
    ast_set_arg(ast, node, 4, value_node)
    ast_set_arg(ast, node, 5, len(ast))
    return (value_next_index, node)

def ast_parse_attribute_assign_statement(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let (target_next_index, target_node) = ast_parse_expression(context, index, ast)
    if target_node == 0 or token_kind(kinds, target_next_index) != TOKEN_ASSIGN:
        return (index, 0)
    let (value_next_index, value_node) = ast_parse_expression(context, target_next_index + 1, ast)
    if value_node == 0:
        return (index, 0)
    let node = ast_append_node(ast, AST_STMT_ASSIGN, token_start(starts, index), token_end(ends, index), ARGS_STMT_ASSIGN)
    ast_set_arg(ast, node, 0, token_start(starts, index))
    ast_set_arg(ast, node, 1, token_end(ends, index))
    ast_set_arg(ast, node, 2, 2)
    ast_set_arg(ast, node, 3, target_node)
    ast_set_arg(ast, node, 4, value_node)
    ast_set_arg(ast, node, 5, len(ast))
    return (value_next_index, node)

def ast_parse_attribute_element_assign_statement(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let (target_next_index, target_node) = ast_parse_expression(context, index, ast)
    if target_node == 0 or token_kind(kinds, target_next_index) != TOKEN_ASSIGN:
        return (index, 0)
    let (value_next_index, value_node) = ast_parse_expression(context, target_next_index + 1, ast)
    if value_node == 0:
        return (index, 0)
    let node = ast_append_node(ast, AST_STMT_ASSIGN, token_start(starts, index), token_end(ends, index), ARGS_STMT_ASSIGN)
    ast_set_arg(ast, node, 0, token_start(starts, index))
    ast_set_arg(ast, node, 1, token_end(ends, index))
    ast_set_arg(ast, node, 2, 3)
    ast_set_arg(ast, node, 3, target_node)
    ast_set_arg(ast, node, 4, value_node)
    ast_set_arg(ast, node, 5, len(ast))
    return (value_next_index, node)

def ast_parse_element_assign_statement(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let starts = context.starts
    let ends = context.ends
    let kinds = context.kinds
    let name_start = token_start(starts, index)
    let name_end = token_end(ends, index)
    let node = ast_append_node(ast, AST_STMT_ASSIGN, name_start, name_end, ARGS_STMT_ASSIGN)
    let key_index = ast_advance_index(index, 2)
    let (key_next_index, key_node) = ast_parse_expression(context, key_index, ast)
    if key_node == 0:
        return (index, 0)
    let assign_next_index = key_next_index
    let assign_form = 1
    while token_kind(kinds, assign_next_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, assign_next_index) != TOKEN_NEWLINE and token_kind(kinds, assign_next_index) != TOKEN_EOF:
        assign_next_index = assign_next_index + 1
    if token_kind(kinds, assign_next_index) != TOKEN_CLOSE_BRACKET:
        return (index, 0)
    let value_index = ast_advance_index(assign_next_index, 2)
    let (value_next_index, value_node) = ast_parse_expression(context, value_index, ast)
    if value_node == 0:
        return (index, 0)
    ast_set_arg(ast, node, 0, name_start)
    ast_set_arg(ast, node, 1, name_end)
    ast_set_arg(ast, node, 2, assign_form)
    ast_set_arg(ast, node, 3, key_node)
    ast_set_arg(ast, node, 4, value_node)
    ast_set_arg(ast, node, 5, len(ast))
    return (value_next_index, node)

def ast_parse_if_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let node = ast_append_node(ast, AST_STMT_IF, 0, 0, ARGS_STMT_IF)
    let condition_index = ast_next_index(index)
    let (cond_next_index, cond_node) = ast_parse_expression(context, condition_index, ast)
    if cond_node == 0:
        return (index, 0)
    let then_block_index = ast_next_index(cond_next_index)
    let (then_block_start, then_block_end) = ast_parse_block_range(context, then_block_index, body_end)
    let (then_block_next_index, then_block_node) = ast_parse_stmt_block(context, then_block_start, then_block_end, ast)
    if then_block_node == 0:
        return (index, 0)
    let then_block_end_node = len(ast)
    let elifs_start = len(ast)
    let branch_index = then_block_end
    while token_kind(kinds, branch_index) == TOKEN_ELIF:
        let elif_node = ast_append_node(ast, AST_ELIF, 0, 0, ARGS_ELIF)
        let elif_condition_index = ast_next_index(branch_index)
        let (elif_cond_next, elif_cond_node) = ast_parse_expression(context, elif_condition_index, ast)
        if elif_cond_node == 0:
            return (index, 0)
        let elif_block_index = ast_next_index(elif_cond_next)
        let (elif_block_start, elif_block_end) = ast_parse_block_range(context, elif_block_index, body_end)
        if elif_block_end <= branch_index:
            return (index, 0)
        let (elif_block_next_index, elif_block_node) = ast_parse_stmt_block(context, elif_block_start, elif_block_end, ast)
        if elif_block_node == 0:
            return (index, 0)
        ast_set_arg(ast, elif_node, 0, elif_cond_node)
        ast_set_arg(ast, elif_node, 1, elif_block_node)
        ast_set_arg(ast, elif_node, 2, len(ast))
        branch_index = elif_block_end
    let elifs_end = len(ast)
    let else_block_node = 0
    let else_block_end_node = len(ast)
    if token_kind(kinds, branch_index) == TOKEN_ELSE:
        let else_block_index = ast_advance_index(branch_index, 2)
        let (else_block_start, else_block_end) = ast_parse_block_range(context, else_block_index, body_end)
        let (else_stmt_next_index, else_parsed_node) = ast_parse_stmt_block(context, else_block_start, else_block_end, ast)
        if else_parsed_node == 0:
            return (index, 0)
        else_block_node = else_parsed_node
        else_block_end_node = len(ast)
        branch_index = else_block_end
    ast_set_arg(ast, node, 0, cond_node)
    ast_set_arg(ast, node, 1, then_block_node)
    ast_set_arg(ast, node, 2, then_block_end_node)
    ast_set_arg(ast, node, 3, elifs_start)
    ast_set_arg(ast, node, 4, elifs_end)
    ast_set_arg(ast, node, 5, else_block_node)
    ast_set_arg(ast, node, 6, else_block_end_node)
    return (branch_index, node)

def ast_parse_while_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let node = ast_append_node(ast, AST_STMT_WHILE, 0, 0, ARGS_STMT_WHILE)
    let condition_index = ast_next_index(index)
    let (cond_next_index, cond_node) = ast_parse_expression(context, condition_index, ast)
    if cond_node == 0:
        return (index, 0)
    let block_index = ast_next_index(cond_next_index)
    let (block_start, block_end) = ast_parse_block_range(context, block_index, body_end)
    if block_end <= index:
        return (index, 0)
    let (_, block_node) = ast_parse_stmt_block(context, block_start, block_end, ast)
    if block_node == 0:
        return (index, 0)
    let block_end_node = len(ast)
    ast_set_arg(ast, node, 0, cond_node)
    ast_set_arg(ast, node, 1, block_node)
    ast_set_arg(ast, node, 2, block_end_node)
    return (block_end, node)

def ast_parse_for_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let starts = context.starts
    let ends = context.ends
    let kinds = context.kinds
    let loop_name_index = ast_next_index(index)
    let loop_name_start = token_start(starts, loop_name_index)
    let loop_name_end = token_end(ends, loop_name_index)
    let node = ast_append_node(ast, AST_STMT_FOR, 0, 0, ARGS_STMT_FOR)
    let source_index = ast_advance_index(index, 3)
    let (source_next_index, source_node) = ast_parse_expression(context, source_index, ast)
    if source_node == 0:
        return (index, 0)
    let block_index = ast_next_index(source_next_index)
    let (block_start, block_end) = ast_parse_block_range(context, block_index, body_end)
    if block_end <= index:
        return (index, 0)
    let (_, block_node) = ast_parse_stmt_block(context, block_start, block_end, ast)
    if block_node == 0:
        return (index, 0)
    let block_end_node = len(ast)
    ast_set_arg(ast, node, 0, loop_name_start)
    ast_set_arg(ast, node, 1, loop_name_end)
    ast_set_arg(ast, node, 2, source_node)
    ast_set_arg(ast, node, 3, block_node)
    ast_set_arg(ast, node, 4, block_end_node)
    return (block_end, node)

def ast_parse_switch_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let node = ast_append_node(ast, AST_STMT_SWITCH, 0, 0, ARGS_STMT_SWITCH)
    let header_index = ast_next_index(index)
    let (header_next_index, header_node) = ast_parse_expression(context, header_index, ast)
    if header_node == 0:
        return (index, 0)
    let cases_start = len(ast)
    let case_start_index = ast_next_index(header_next_index)
    let case_index = skip_source_newlines(source, starts, case_start_index)
    while token_kind(kinds, case_index) == TOKEN_CASE:
        let case_node = ast_append_node(ast, AST_CASE, 0, 0, ARGS_CASE)
        let case_value_index = ast_next_index(case_index)
        let (case_value_next_index, case_value_node) = ast_parse_expression(context, case_value_index, ast)
        if case_value_node == 0:
            return (index, 0)
        let case_values: list[int] = []
        append(case_values, case_value_node)
        let next_value_index = case_value_next_index
        while token_kind(kinds, next_value_index) == TOKEN_COMMA:
            let next_value_start = ast_next_index(next_value_index)
            let (next_value_end, next_value_node) = ast_parse_expression(context, next_value_start, ast)
            if next_value_node == 0:
                return (index, 0)
            append(case_values, next_value_node)
            next_value_index = next_value_end
        let case_block_index = ast_next_index(next_value_index)
        let (case_block_start, case_block_end) = ast_parse_block_range(context, case_block_index, body_end)
        if case_block_end <= case_index:
            return (index, 0)
        let (_, case_block_node) = ast_parse_stmt_block(context, case_block_start, case_block_end, ast)
        if case_block_node == 0:
            return (index, 0)
        let case_block_end_node = len(ast)
        ast_set_arg(ast, case_node, 0, ast_int_list_get(case_values, 0))
        ast_set_arg(ast, case_node, 1, case_block_node)
        ast_set_arg(ast, case_node, 2, case_block_end_node)
        let extra_value_index = 1
        while extra_value_index < len(case_values):
            let extra_case_node = ast_append_node(ast, AST_CASE, 0, 0, ARGS_CASE)
            let (_, extra_case_block_node) = ast_parse_stmt_block(context, case_block_start, case_block_end, ast)
            if extra_case_block_node == 0:
                return (index, 0)
            ast_set_arg(ast, extra_case_node, 0, ast_int_list_get(case_values, extra_value_index))
            ast_set_arg(ast, extra_case_node, 1, extra_case_block_node)
            ast_set_arg(ast, extra_case_node, 2, len(ast))
            extra_value_index = extra_value_index + 1
        case_index = case_block_end
    let cases_end = len(ast)
    let default_block_node = 0
    let default_block_end_node = 0
    if token_kind(kinds, case_index) == TOKEN_DEFAULT:
        let default_block_index = ast_advance_index(case_index, 2)
        let (default_block_start, default_block_end) = ast_parse_block_range(context, default_block_index, body_end)
        if default_block_end <= case_index:
            return (index, 0)
        let (default_stmt_next_index, default_parsed_node) = ast_parse_stmt_block(context, default_block_start, default_block_end, ast)
        if default_parsed_node == 0:
            return (index, 0)
        default_block_node = default_parsed_node
        default_block_end_node = len(ast)
        case_index = default_block_end
    if default_block_end_node == 0:
        default_block_end_node = len(ast)
    ast_set_arg(ast, node, 0, header_node)
    ast_set_arg(ast, node, 1, cases_start)
    ast_set_arg(ast, node, 2, cases_end)
    ast_set_arg(ast, node, 3, default_block_node)
    ast_set_arg(ast, node, 4, default_block_end_node)
    return (case_index, node)

def ast_parse_call_args(context: ParseContext, open_paren_index: int, ast: list[int]) -> (int, int, int, list[int]):
    let kinds = context.kinds
    let args_start = len(ast)
    let argument_index = ast_next_index(open_paren_index)
    let parsing_args = true
    let args_done = false
    let roots = []
    while parsing_args and token_kind(kinds, argument_index) != TOKEN_EOF:
        if token_kind(kinds, argument_index) == TOKEN_CLOSE_PAREN:
            parsing_args = false
            args_done = true
        if parsing_args:
            let (argument_next_index, argument_node) = ast_parse_expression(context, argument_index, ast)
            if argument_node == 0 or argument_next_index <= argument_index:
                return (-1, 0, 0, [])
            append(roots, argument_node)
            argument_index = argument_next_index
            if token_kind(kinds, argument_index) == TOKEN_COMMA:
                argument_index = ast_next_index(argument_index)
    if args_done and token_kind(kinds, argument_index) == TOKEN_CLOSE_PAREN:
        return (ast_next_index(argument_index), args_start, len(ast), roots)
    return (-1, 0, 0, [])

def ast_parse_index_slice(context: ParseContext, open_bracket_index: int, ast: list[int]) -> (int, int, int, int, int):
    let kinds = context.kinds
    let cursor = ast_next_index(open_bracket_index)
    let index_node = 0
    let has_slice = 0
    let slice_start_node = 0
    let slice_end_node = 0
    if token_kind(kinds, cursor) == TOKEN_COLON:
        has_slice = 1
        cursor = ast_next_index(cursor)
    if has_slice == 0:
        let (index_next_index, parsed_index_node) = ast_parse_expression(context, cursor, ast)
        if parsed_index_node == 0:
            return (-1, 0, 0, 0, 0)
        cursor = index_next_index
        if token_kind(kinds, cursor) == TOKEN_COLON:
            has_slice = 1
            slice_start_node = parsed_index_node
            cursor = ast_next_index(cursor)
        else:
            index_node = parsed_index_node
    if has_slice != 0:
        if token_kind(kinds, cursor) != TOKEN_CLOSE_BRACKET:
            let (end_next_index, end_node) = ast_parse_expression(context, cursor, ast)
            if end_node == 0:
                return (-1, 0, 0, 0, 0)
            slice_end_node = end_node
            cursor = end_next_index
    if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACKET:
        return (ast_next_index(cursor), index_node, has_slice, slice_start_node, slice_end_node)
    return (-1, 0, 0, 0, 0)

def ast_parse_postfix(context: ParseContext, base_node: int, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let kind = token_kind(kinds, index)
    if kind == TOKEN_CLOSE_PAREN:
        return (index, base_node)
    if kind == TOKEN_CLOSE_BRACKET:
        return (index, base_node)
    if kind == TOKEN_CLOSE_BRACE:
        return (index, base_node)
    if kind == TOKEN_NEWLINE:
        return (index, base_node)
    if kind == TOKEN_EOF:
        return (index, base_node)
    if kind == TOKEN_OPEN_PAREN:
        let (args_next_index, args_start, args_end, args_roots) = ast_parse_call_args(context, index, ast)
        if args_next_index <= index:
            return (index, 0)
        let call_argument_count = 3 + len(args_roots)
        let call_node = ast_append_node(ast, AST_EXPR_CALL, 0, 0, call_argument_count)
        ast_set_arg(ast, call_node, 0, base_node)
        ast_set_arg(ast, call_node, 1, len(args_roots))
        ast_set_arg(ast, call_node, 2, args_start)
        let call_root_slot = 3
        while call_root_slot < call_argument_count:
            if call_root_slot - 3 < len(args_roots):
                ast_set_arg(ast, call_node, call_root_slot, ast_int_list_get(args_roots, call_root_slot - 3))
            else:
                ast_set_arg(ast, call_node, call_root_slot, 0)
            call_root_slot = call_root_slot + 1
        return ast_parse_postfix(context, call_node, args_next_index, ast)
    if kind == TOKEN_DOT:
        if token_kind(kinds, index + 1) != TOKEN_IDENTIFIER:
            return (index, base_node)
        let method_name_start = token_start(starts, index + 1)
        let method_name_end = token_end(ends, index + 1)
        if token_kind(kinds, index + 2) == TOKEN_OPEN_PAREN:
            let (method_args_next, method_args_start, method_args_end, method_roots) = ast_parse_call_args(context, index + 2, ast)
            if method_args_next <= index:
                return (index, 0)
            let method_call_node = ast_append_node(ast, AST_EXPR_METHOD_CALL, 0, 0, ARGS_METHOD_CALL)
            ast_set_arg(ast, method_call_node, 0, base_node)
            ast_set_arg(ast, method_call_node, 1, method_name_start)
            ast_set_arg(ast, method_call_node, 2, method_name_end)
            ast_set_arg(ast, method_call_node, 3, len(method_roots))
            ast_set_arg(ast, method_call_node, 4, method_args_start)
            let method_root_slot = 5
            while method_root_slot < ARGS_METHOD_CALL:
                if method_root_slot - 5 < len(method_roots):
                    ast_set_arg(ast, method_call_node, method_root_slot, ast_int_list_get(method_roots, method_root_slot - 5))
                else:
                    ast_set_arg(ast, method_call_node, method_root_slot, 0)
                method_root_slot = method_root_slot + 1
            return ast_parse_postfix(context, method_call_node, method_args_next, ast)
        let attr_node = ast_append_node(ast, AST_EXPR_ATTR, 0, 0, ARGS_ATTR)
        ast_set_arg(ast, attr_node, 0, base_node)
        ast_set_arg(ast, attr_node, 1, method_name_start)
        ast_set_arg(ast, attr_node, 2, method_name_end)
        let next_index = ast_advance_index(index, 2)
        let next_kind = token_kind(kinds, next_index)
        if next_kind == TOKEN_OPEN_PAREN or next_kind == TOKEN_DOT or next_kind == TOKEN_OPEN_BRACKET:
            return ast_parse_postfix(context, attr_node, next_index, ast)
        return (next_index, attr_node)
    if kind == TOKEN_OPEN_BRACKET:
        let (bracket_next_index, bracket_index_node, bracket_has_slice, bracket_slice_start, bracket_slice_end) = ast_parse_index_slice(context, index, ast)
        if bracket_next_index <= index:
            return (index, 0)
        if bracket_has_slice != 0:
            let slice_node = ast_append_node(ast, AST_EXPR_SLICE, 0, 0, ARGS_SLICE)
            ast_set_arg(ast, slice_node, 0, base_node)
            ast_set_arg(ast, slice_node, 1, bracket_slice_start)
            ast_set_arg(ast, slice_node, 2, bracket_slice_end)
            return ast_parse_postfix(context, slice_node, bracket_next_index, ast)
        let index_node = ast_append_node(ast, AST_EXPR_INDEX, 0, 0, ARGS_INDEX)
        ast_set_arg(ast, index_node, 0, base_node)
        ast_set_arg(ast, index_node, 1, bracket_index_node)
        return ast_parse_postfix(context, index_node, bracket_next_index, ast)
    return (index, base_node)

def ast_parse_list_literal(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let cursor = ast_next_index(index)
    let parsing = true
    let roots = []
    while parsing and token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACKET:
            parsing = false
        if parsing:
            while token_kind(kinds, cursor) == TOKEN_NEWLINE:
                cursor = cursor + 1
            if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACKET:
                parsing = false
            else:
                let (element_next_index, element_node) = ast_parse_expression(context, cursor, ast)
                if element_node == 0 or element_next_index <= cursor:
                    return (index, 0)
                append(roots, element_node)
                cursor = element_next_index
                if token_kind(kinds, cursor) == TOKEN_COMMA:
                    cursor = ast_next_index(cursor)
    if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACKET:
        let node = ast_append_node(ast, AST_EXPR_LIST, 0, 0, 1 + len(roots))
        ast_set_arg(ast, node, 0, len(roots))
        let root_slot = 1
        while root_slot < 1 + len(roots):
            ast_set_arg(ast, node, root_slot, ast_int_list_get(roots, root_slot - 1))
            root_slot = root_slot + 1
        return (ast_next_index(cursor), node)
    return (index, 0)

def ast_parse_list_comprehension(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let element_index = ast_next_index(index)
    let for_index = ast_advance_index(index, 2)
    while token_kind(kinds, for_index) != TOKEN_FOR and token_kind(kinds, for_index) != TOKEN_CLOSE_BRACKET and token_kind(kinds, for_index) != TOKEN_NEWLINE and token_kind(kinds, for_index) != TOKEN_EOF:
        for_index = for_index + 1
    if token_kind(kinds, for_index) != TOKEN_FOR:
        return (index, 0)
    let (element_next_index, element_node) = ast_parse_expression(context, element_index, ast)
    if element_node == 0:
        return (index, 0)
    let loop_name_index = ast_next_index(for_index)
    let loop_name_start = token_start(starts, loop_name_index)
    let loop_name_end = token_end(ends, loop_name_index)
    let source_index = ast_advance_index(for_index, 3)
    let (source_next_index, source_node) = ast_parse_expression(context, source_index, ast)
    if source_node == 0:
        return (index, 0)
    let condition_node = 0
    let condition_next_index = source_next_index
    if token_kind(kinds, source_next_index) == TOKEN_IF:
        let condition_index = ast_next_index(source_next_index)
        let (parsed_condition_next_index, parsed_condition_node) = ast_parse_expression(context, condition_index, ast)
        if parsed_condition_node == 0:
            return (index, 0)
        condition_node = parsed_condition_node
        condition_next_index = parsed_condition_next_index
    if token_kind(kinds, condition_next_index) != TOKEN_CLOSE_BRACKET:
        return (index, 0)
    let node = ast_append_node(ast, AST_EXPR_LIST_COMP, 0, 0, ARGS_LIST_COMP)
    ast_set_arg(ast, node, 0, element_node)
    ast_set_arg(ast, node, 1, loop_name_start)
    ast_set_arg(ast, node, 2, loop_name_end)
    ast_set_arg(ast, node, 3, source_node)
    ast_set_arg(ast, node, 4, 0)
    ast_set_arg(ast, node, 5, 0)
    ast_set_arg(ast, node, 6, condition_node)
    return (ast_next_index(condition_next_index), node)

def ast_parse_list_or_comprehension(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let scan_index = ast_next_index(index)
    let scan_depth = 1
    let has_for = false
    while token_kind(kinds, scan_index) != TOKEN_EOF and scan_depth > 0:
        if token_kind(kinds, scan_index) == TOKEN_OPEN_BRACKET:
            scan_depth = scan_depth + 1
        if token_kind(kinds, scan_index) == TOKEN_CLOSE_BRACKET:
            scan_depth = scan_depth - 1
        if scan_depth == 1 and token_kind(kinds, scan_index) == TOKEN_FOR:
            has_for = true
        scan_index = scan_index + 1
    if has_for:
        return ast_parse_list_comprehension(context, index, ast)
    return ast_parse_list_literal(context, index, ast)

def ast_parse_dict_literal(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let cursor = index + 1
    let parsing = true
    let key_roots = []
    let value_roots = []
    while parsing and token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
            parsing = false
        if parsing:
            while token_kind(kinds, cursor) == TOKEN_NEWLINE:
                cursor = cursor + 1
            if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
                parsing = false
            else:
                let (key_next_index, key_node) = ast_parse_expression(context, cursor, ast)
                if key_node == 0 or key_next_index <= cursor:
                    return (index, 0)
                cursor = key_next_index
                if token_kind(kinds, cursor) != TOKEN_COLON:
                    return (index, 0)
                let (value_next_index, value_node) = ast_parse_expression(context, cursor + 1, ast)
                if value_node == 0 or value_next_index <= cursor:
                    return (index, 0)
                append(key_roots, key_node)
                append(value_roots, value_node)
                cursor = value_next_index
                if token_kind(kinds, cursor) == TOKEN_COMMA:
                    cursor = cursor + 1
    if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
        let node = ast_append_node(ast, AST_EXPR_DICT, 0, 0, ARGS_DICT)
        ast_set_arg(ast, node, 0, len(key_roots))
        let key_slot = 1
        while key_slot < 21:
            if key_slot - 1 < len(key_roots):
                ast_set_arg(ast, node, key_slot, ast_int_list_get(key_roots, key_slot - 1))
            else:
                ast_set_arg(ast, node, key_slot, 0)
            key_slot = key_slot + 1
        let value_slot = 21
        while value_slot < 41:
            if value_slot - 21 < len(value_roots):
                ast_set_arg(ast, node, value_slot, ast_int_list_get(value_roots, value_slot - 21))
            else:
                ast_set_arg(ast, node, value_slot, 0)
            value_slot = value_slot + 1
        return (cursor + 1, node)
    return (index, 0)

def ast_parse_tuple_literal(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let cursor = index + 1
    let parsing = true
    let roots = []
    while parsing and token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) == TOKEN_CLOSE_PAREN:
            parsing = false
        if parsing:
            while token_kind(kinds, cursor) == TOKEN_NEWLINE:
                cursor = cursor + 1
            if token_kind(kinds, cursor) == TOKEN_CLOSE_PAREN:
                parsing = false
            else:
                let (element_next_index, element_node) = ast_parse_expression(context, cursor, ast)
                if element_node == 0 or element_next_index <= cursor:
                    return (index, 0)
                append(roots, element_node)
                cursor = element_next_index
                if token_kind(kinds, cursor) == TOKEN_COMMA:
                    cursor = cursor + 1
    if token_kind(kinds, cursor) == TOKEN_CLOSE_PAREN:
        let node = ast_append_node(ast, AST_EXPR_TUPLE, 0, 0, ARGS_LIST_TUPLE_DICT)
        ast_set_arg(ast, node, 0, len(roots))
        let root_slot = 1
        while root_slot < ARGS_LIST_TUPLE_DICT:
            if root_slot - 1 < len(roots):
                ast_set_arg(ast, node, root_slot, ast_int_list_get(roots, root_slot - 1))
            else:
                ast_set_arg(ast, node, root_slot, 0)
            root_slot = root_slot + 1
        return (cursor + 1, node)
    return (index, 0)

def ast_parse_struct_literal(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let struct_name_start = token_start(starts, index)
    let struct_name_end = token_end(ends, index)
    let field_names_start = index + 2
    let cursor = index + 2
    let parsing = true
    let field_roots: list[int] = []
    while parsing and token_kind(kinds, cursor) != TOKEN_EOF:
        if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
            parsing = false
        if parsing:
            while token_kind(kinds, cursor) == TOKEN_NEWLINE:
                cursor = cursor + 1
            if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
                parsing = false
            elif token_kind(kinds, cursor) == TOKEN_IDENTIFIER and token_kind(kinds, cursor + 1) == TOKEN_COLON:
                let (value_next_index, value_node) = ast_parse_expression(context, cursor + 2, ast)
                if value_node == 0 or value_next_index <= cursor:
                    return (index, 0)
                append(field_roots, value_node)
                cursor = value_next_index
            else:
                return (index, 0)
            if token_kind(kinds, cursor) == TOKEN_COMMA:
                cursor = cursor + 1
    if token_kind(kinds, cursor) == TOKEN_CLOSE_BRACE:
        let node = ast_append_node(ast, AST_EXPR_STRUCT, struct_name_start, struct_name_end, ARGS_STRUCT_BASE + len(field_roots))
        ast_set_arg(ast, node, 0, struct_name_start)
        ast_set_arg(ast, node, 1, struct_name_end)
        ast_set_arg(ast, node, 2, field_names_start)
        ast_set_arg(ast, node, 3, cursor)
        ast_set_arg(ast, node, 4, len(field_roots))
        let field_slot = 0
        while field_slot < len(field_roots):
            let field_root = ast_int_list_get(field_roots, field_slot)
            ast_set_arg(ast, node, ARGS_STRUCT_BASE + field_slot, field_root)
            field_slot = field_slot + 1
        return (cursor + 1, node)
    return (index, 0)

def ast_parse_lambda(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let arrow_index = index + 2
    while token_kind(kinds, arrow_index) != TOKEN_ARROW and token_kind(kinds, arrow_index) != TOKEN_NEWLINE and token_kind(kinds, arrow_index) != TOKEN_EOF:
        arrow_index = arrow_index + 1
    if token_kind(kinds, arrow_index) != TOKEN_ARROW:
        return (index, 0)
    let (body_next_index, body_node) = ast_parse_expression(context, arrow_index + 1, ast)
    if body_node == 0:
        return (index, 0)
    let node = ast_append_node(ast, AST_EXPR_LAMBDA, token_start(starts, index), token_end(ends, index), ARGS_LAMBDA)
    ast_set_arg(ast, node, 0, index + 1)
    ast_set_arg(ast, node, 1, arrow_index)
    ast_set_arg(ast, node, 2, body_node)
    ast_set_arg(ast, node, 3, 0)
    ast_set_arg(ast, node, 4, 0)
    return (body_next_index, node)

def ast_parse_pattern(context: ParseContext, index: int, ast: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let pattern_kind = token_kind(kinds, index)
    switch pattern_kind:
        case TOKEN_OPEN_BRACKET:
            let list_names_start = index + 1
            let list_cursor = index + 1
            while token_kind(kinds, list_cursor) != TOKEN_CLOSE_BRACKET and token_kind(kinds, list_cursor) != TOKEN_NEWLINE and token_kind(kinds, list_cursor) != TOKEN_EOF:
                list_cursor = list_cursor + 1
            if token_kind(kinds, list_cursor) != TOKEN_CLOSE_BRACKET:
                return (0, index)
            let list_node = ast_append_node(ast, AST_PAT_LIST, 0, 0, ARGS_PAIR)
            ast_set_arg(ast, list_node, 0, list_names_start)
            ast_set_arg(ast, list_node, 1, list_cursor)
            return (list_node, list_cursor + 1)
        case TOKEN_INTEGER:
            let int_value = parse_integer(source, token_start(starts, index), token_end(ends, index))
            let int_node = ast_append_node(ast, AST_PAT_INT, token_start(starts, index), token_end(ends, index), 1)
            ast_set_arg(ast, int_node, 0, int_value)
            return (int_node, index + 1)
        case TOKEN_RUNE:
            let rune_value = parse_rune_literal(source, token_start(starts, index), token_end(ends, index))
            let rune_node = ast_append_node(ast, AST_PAT_RUNE, token_start(starts, index), token_end(ends, index), 1)
            ast_set_arg(ast, rune_node, 0, rune_value)
            return (rune_node, index + 1)
        case TOKEN_STRING:
            return (ast_append_node(ast, AST_PAT_STRING, token_start(starts, index), token_end(ends, index), 0), index + 1)
        case TOKEN_FLOAT:
            return (ast_append_node(ast, AST_PAT_FLOAT, token_start(starts, index), token_end(ends, index), 0), index + 1)
        case TOKEN_TRUE:
            let true_node = ast_append_node(ast, AST_PAT_BOOL, token_start(starts, index), token_end(ends, index), 1)
            ast_set_arg(ast, true_node, 0, 1)
            return (true_node, index + 1)
        case TOKEN_FALSE:
            let false_node = ast_append_node(ast, AST_PAT_BOOL, token_start(starts, index), token_end(ends, index), 1)
            ast_set_arg(ast, false_node, 0, 0)
            return (false_node, index + 1)
        case TOKEN_IDENTIFIER:
            let pattern_name_start = token_start(starts, index)
            let pattern_name_end = token_end(ends, index)
            let pattern_name = source[pattern_name_start:pattern_name_end]
            if pattern_name == "_":
                return (ast_append_node(ast, AST_PAT_WILDCARD, pattern_name_start, pattern_name_end, 0), index + 1)
            if pattern_name == "None":
                let none_node = ast_append_node(ast, AST_PAT_BUILTIN, pattern_name_start, pattern_name_end, ARGS_BUILTIN_ENUM)
                ast_set_arg(ast, none_node, 0, 1)
                return (none_node, index + 1)
            if token_kind(kinds, index + 1) == TOKEN_OPEN_BRACE:
                let struct_field_cursor = index + 2
                while token_kind(kinds, struct_field_cursor) != TOKEN_CLOSE_BRACE and token_kind(kinds, struct_field_cursor) != TOKEN_NEWLINE and token_kind(kinds, struct_field_cursor) != TOKEN_EOF:
                    struct_field_cursor = struct_field_cursor + 1
                if token_kind(kinds, struct_field_cursor) != TOKEN_CLOSE_BRACE:
                    return (0, index)
                let struct_node = ast_append_node(ast, AST_PAT_STRUCT, pattern_name_start, pattern_name_end, ARGS_PAT_STRUCT)
                ast_set_arg(ast, struct_node, 0, pattern_name_start)
                ast_set_arg(ast, struct_node, 1, pattern_name_end)
                ast_set_arg(ast, struct_node, 2, index + 2)
                ast_set_arg(ast, struct_node, 3, struct_field_cursor)
                ast_set_arg(ast, struct_node, 4, index + 2)
                ast_set_arg(ast, struct_node, 5, struct_field_cursor)
                return (struct_node, struct_field_cursor + 1)
            if token_kind(kinds, index + 1) == TOKEN_CONS and token_kind(kinds, index + 2) == TOKEN_IDENTIFIER:
                let cons_head_start = token_start(starts, index)
                let cons_head_end = token_end(ends, index)
                let cons_tail_start = token_start(starts, index + 2)
                let cons_tail_end = token_end(ends, index + 2)
                let cons_node = ast_append_node(ast, AST_PAT_CONS, 0, 0, ARGS_PAT_CONS)
                ast_set_arg(ast, cons_node, 0, cons_head_start)
                ast_set_arg(ast, cons_node, 1, cons_head_end)
                ast_set_arg(ast, cons_node, 2, cons_tail_start)
                ast_set_arg(ast, cons_node, 3, cons_tail_end)
                return (cons_node, index + 3)
            let next_index = ast_next_index(index)
            if token_kind(kinds, next_index) == TOKEN_DOT and token_kind(kinds, ast_advance_index(index, 2)) == TOKEN_IDENTIFIER:
                let variant_name_index = ast_advance_index(index, 2)
                let variant_name_start = token_start(starts, variant_name_index)
                let variant_name_end = token_end(ends, variant_name_index)
                let payload_start = 0
                let payload_end = 0
                let pattern_end_index = ast_advance_index(index, 3)
                if token_kind(kinds, pattern_end_index) == TOKEN_OPEN_PAREN:
                    let payload_cursor = ast_advance_index(index, 4)
                    let payload_close_index = ast_next_index(payload_cursor)
                    if token_kind(kinds, payload_close_index) != TOKEN_CLOSE_PAREN:
                        return (0, index)
                    payload_start = ast_advance_index(index, 4)
                    payload_end = payload_close_index
                    pattern_end_index = ast_next_index(payload_close_index)
                let enum_node = ast_append_node(ast, AST_PAT_ENUM, pattern_name_start, pattern_name_end, ARGS_ENUM)
                ast_set_arg(ast, enum_node, 0, pattern_name_start)
                ast_set_arg(ast, enum_node, 1, pattern_name_end)
                ast_set_arg(ast, enum_node, 2, variant_name_start)
                ast_set_arg(ast, enum_node, 3, variant_name_end)
                ast_set_arg(ast, enum_node, 4, payload_start)
                ast_set_arg(ast, enum_node, 5, payload_end)
                return (enum_node, pattern_end_index)
            if token_kind(kinds, next_index) == TOKEN_OPEN_PAREN and (pattern_name == "Some" or pattern_name == "Ok" or pattern_name == "Err"):
                let builtin_tag = 0
                if pattern_name == "Err":
                    builtin_tag = 1
                let builtin_payload_index = ast_advance_index(index, 2)
                let builtin_payload_start = token_start(starts, builtin_payload_index)
                let builtin_payload_end = token_end(ends, builtin_payload_index)
                let builtin_node = ast_append_node(ast, AST_PAT_BUILTIN, pattern_name_start, pattern_name_end, ARGS_BUILTIN_ENUM)
                ast_set_arg(ast, builtin_node, 0, builtin_tag)
                ast_set_arg(ast, builtin_node, 1, builtin_payload_start)
                ast_set_arg(ast, builtin_node, 2, builtin_payload_end)
                return (builtin_node, ast_advance_index(index, 4))
            return (ast_append_node(ast, AST_PAT_VAR, pattern_name_start, pattern_name_end, 0), ast_next_index(index))
        default:
            return (0, index)

def ast_parse_match_expression(context: ParseContext, index: int, ast: list[int], is_statement: int) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let scrutinee_index = ast_next_index(index)
    let (scrutinee_next_index, scrutinee_node) = ast_parse_expression(context, scrutinee_index, ast)
    if scrutinee_node == 0:
        return (index, 0)
    let first_case_start = ast_next_index(scrutinee_next_index)
    let first_case_index = skip_source_newlines(source, starts, first_case_start)
    let case_indent = line_indent(source, token_start(starts, first_case_index))
    let cases_start = len(ast)
    let case_index = first_case_index
    let scan_done = false
    let has_case = false
    while not scan_done and case_index < len(kinds) and token_kind(kinds, case_index) != TOKEN_EOF:
        if line_indent(source, token_start(starts, case_index)) < case_indent:
            scan_done = true
        if not scan_done:
            let case_node = ast_append_node(ast, AST_M_CASE, 0, 0, ARGS_M_CASE)
            let (pattern_node, pattern_end_index) = ast_parse_pattern(context, case_index, ast)
            if pattern_node == 0:
                return (index, 0)
            let colon_index = pattern_end_index
            while token_kind(kinds, colon_index) != TOKEN_COLON and token_kind(kinds, colon_index) != TOKEN_EOF:
                colon_index = colon_index + 1
            if token_kind(kinds, colon_index) != TOKEN_COLON:
                return (index, 0)
            let guard_node = 0
            let guard_scan_index = pattern_end_index
            while guard_scan_index < colon_index:
                if token_kind(kinds, guard_scan_index) == TOKEN_IF:
                    let guard_index = ast_next_index(guard_scan_index)
                    let (guard_next_index, parsed_guard_node) = ast_parse_expression(context, guard_index, ast)
                    if parsed_guard_node == 0:
                        return (index, 0)
                    guard_node = parsed_guard_node
                guard_scan_index = guard_scan_index + 1
            let body_start_index = ast_next_index(colon_index)
            let body_is_block = 0
            if is_statement != 0:
                if token_kind(kinds, body_start_index) == TOKEN_NEWLINE:
                    body_is_block = 1
            let body_node = 0
            let body_next_index = body_start_index
            if body_is_block != 0:
                let (case_block_start, case_block_end) = ast_parse_block_range(context, body_start_index, len(kinds))
                let (case_block_next_index, case_block_node) = ast_parse_stmt_block(context, case_block_start, case_block_end, ast)
                if case_block_node == 0:
                    return (index, 0)
                body_node = case_block_node
                body_next_index = case_block_end
            if body_is_block == 0:
                let (body_expr_next_index, body_expr_node) = ast_parse_expression(context, body_start_index, ast)
                if body_expr_node == 0:
                    return (index, 0)
                body_node = body_expr_node
                body_next_index = body_expr_next_index
            ast_set_arg(ast, case_node, 0, pattern_node)
            ast_set_arg(ast, case_node, 1, guard_node)
            ast_set_arg(ast, case_node, 2, body_node)
            ast_set_arg(ast, case_node, 3, len(ast))
            has_case = true
            let next_case_index = skip_source_newlines(source, starts, body_next_index)
            if next_case_index <= case_index:
                return (index, 0)
            case_index = next_case_index
    if not has_case:
        return (index, 0)
    let cases_end = len(ast)
    let match_node = ast_append_node(ast, AST_EXPR_MATCH, 0, 0, ARGS_MATCH)
    ast_set_arg(ast, match_node, 0, scrutinee_node)
    ast_set_arg(ast, match_node, 1, cases_start)
    ast_set_arg(ast, match_node, 2, cases_end)
    ast_set_arg(ast, match_node, 3, is_statement)
    return (case_index, match_node)

def ast_parse_match_statement(context: ParseContext, index: int, body_end: int, ast: list[int]) -> (int, int):
    let match_stmt_node = ast_append_node(ast, AST_STMT_EXPR, 0, 0, ARGS_STMT_EXPR)
    let (match_next_index, match_node) = ast_parse_match_expression(context, index, ast, 1)
    if match_node == 0:
        return (index, 0)
    ast_set_arg(ast, match_stmt_node, 0, match_node)
    ast_set_arg(ast, match_stmt_node, 1, len(ast))
    return (match_next_index, match_stmt_node)

def ast_token_is_docstring(context: ParseContext, index: int) -> bool:
    let source = context.src
    let starts = context.starts
    if token_kind(context.kinds, index) != TOKEN_STRING:
        return false
    let token_start_position = token_start(starts, index)
    if token_start_position < 3:
        return false
    return source[token_start_position - 3] == '\'' and source[token_start_position - 2] == '\'' and source[token_start_position - 1] == '\''

def ast_parse_stmt_block(context: ParseContext, body_start: int, body_end: int, ast: list[int]) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let ends = context.ends
    let current_index = skip_source_newlines(source, starts, body_start)
    let block_start = len(ast)
    while current_index < body_end and token_kind(kinds, current_index) != TOKEN_EOF:
        if ast_token_is_docstring(context, current_index):
            current_index = skip_source_newlines(source, starts, current_index + 1)
        else:
            let node = 0
            let next_index = current_index
            let current_kind = token_kind(kinds, current_index)
            if current_kind == TOKEN_PRINT:
                node = ast_parse_print_statement(context, current_index, ast, 0)
                next_index = ast_scan_print_end(context, current_index)
            elif current_kind == TOKEN_EPRINT:
                node = ast_parse_print_statement(context, current_index, ast, 1)
                next_index = ast_scan_print_end(context, current_index)
            if current_kind != TOKEN_PRINT and current_kind != TOKEN_EPRINT:
                let statement_result: list[int] = [0, 0]
                node = ast_parse_statement_into(context, current_index, body_end, ast, statement_result)
                next_index = ast_int_list_get(statement_result, 0)
            if node == 0:
                return (current_index, 0)
            if next_index > current_index:
                current_index = skip_source_newlines(source, starts, next_index)
            else:
                current_index = current_index + 1
    return (current_index, block_start)

def ast_parse_block_range(context: ParseContext, start_index: int, body_end: int) -> (int, int):
    let source = context.src
    let kinds = context.kinds
    let starts = context.starts
    let block_start = skip_source_newlines(source, starts, start_index)
    let block_indent = line_indent(source, token_start(starts, block_start))
    let block_end = block_start
    while block_end < body_end and is_body_line(source, kinds, starts, block_end, block_indent):
        block_end = block_end + 1
    return (block_start, block_end)

def ast_parse_branch_block(context: ParseContext, start_index: int, body_end: int, ast: list[int]) -> (int, int):
    let (block_start, block_end) = ast_parse_block_range(context, start_index, body_end)
    let (_, block_node) = ast_parse_stmt_block(context, block_start, block_end, ast)
    if block_node == 0:
        return (block_end, 0)
    return (block_end, block_node)

def ast_parse_global_let(context: ParseContext, expression_index: int, ast: list[int]) -> int:
    let (_, node) = ast_parse_expression(context, expression_index, ast)
    return node

def ast_build_function(context: ParseContext, function_index: int, ast: list[int], function_bodies: list[int], function_body_ends: list[int]) -> (int, int):
    let (next_index, block_start) = ast_parse_stmt_block(context, function_bodies[function_index], function_body_ends[function_index], ast)
    return (next_index, block_start)

def ast_build_program(context: ParseContext, ast: list[int], fn_ast_starts: list[int], fn_ast_ends: list[int], global_let_nodes: list[int], function_bodies: list[int], function_body_ends: list[int], global_let_expression_indexes: list[int]) -> bool:
    append(ast, 0)
    let fn_starts = context.fn_starts
    let function_index = 0
    while function_index < len(fn_starts):
        let (block_end_index, block_start) = ast_build_function(context, function_index, ast, function_bodies, function_body_ends)
        if block_start == 0:
            return false
        append(fn_ast_starts, block_start)
        append(fn_ast_ends, len(ast))
        function_index = function_index + 1
    let global_index = 0
    while global_index < len(global_let_expression_indexes):
        let node = ast_parse_global_let(context, global_let_expression_indexes[global_index], ast)
        if node == 0:
            return false
        append(global_let_nodes, node)
        global_index = global_index + 1
    return true
