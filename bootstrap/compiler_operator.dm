from compiler_lex import TOKEN_PLUS, TOKEN_MINUS, TOKEN_MULTIPLY, TOKEN_DIVIDE, TOKEN_MODULO, TOKEN_LESS, TOKEN_GREATER
from compiler_lex import TOKEN_LESS_EQUAL, TOKEN_GREATER_EQUAL, TOKEN_EQUAL, TOKEN_NOT_EQUAL, TOKEN_AND, TOKEN_OR
from compiler_lex import TOKEN_NOT, TOKEN_IN

const IR_OPERATOR_UNKNOWN: int = 0
const IR_OPERATOR_ADD: int = 1
const IR_OPERATOR_SUB: int = 2
const IR_OPERATOR_MUL: int = 3
const IR_OPERATOR_DIV: int = 4
const IR_OPERATOR_MOD: int = 5
const IR_OPERATOR_LT: int = 6
const IR_OPERATOR_GT: int = 7
const IR_OPERATOR_LE: int = 8
const IR_OPERATOR_GE: int = 9
const IR_OPERATOR_EQ: int = 10
const IR_OPERATOR_NE: int = 11
const IR_OPERATOR_AND: int = 12
const IR_OPERATOR_OR: int = 13
const IR_OPERATOR_NOT: int = 14
const IR_OPERATOR_POS: int = 15
const IR_OPERATOR_NEG: int = 16
const IR_OPERATOR_IN: int = 17

def ir_binary_operator_from_token(token: int) -> int:
    switch token:
        case TOKEN_PLUS:
            return IR_OPERATOR_ADD
        case TOKEN_MINUS:
            return IR_OPERATOR_SUB
        case TOKEN_MULTIPLY:
            return IR_OPERATOR_MUL
        case TOKEN_DIVIDE:
            return IR_OPERATOR_DIV
        case TOKEN_MODULO:
            return IR_OPERATOR_MOD
        case TOKEN_LESS:
            return IR_OPERATOR_LT
        case TOKEN_GREATER:
            return IR_OPERATOR_GT
        case TOKEN_LESS_EQUAL:
            return IR_OPERATOR_LE
        case TOKEN_GREATER_EQUAL:
            return IR_OPERATOR_GE
        case TOKEN_EQUAL:
            return IR_OPERATOR_EQ
        case TOKEN_NOT_EQUAL:
            return IR_OPERATOR_NE
        case TOKEN_AND:
            return IR_OPERATOR_AND
        case TOKEN_OR:
            return IR_OPERATOR_OR
        case TOKEN_IN:
            return IR_OPERATOR_IN
    return IR_OPERATOR_UNKNOWN

def ir_unary_operator_from_token(token: int) -> int:
    switch token:
        case TOKEN_NOT:
            return IR_OPERATOR_NOT
        case TOKEN_PLUS:
            return IR_OPERATOR_POS
        case TOKEN_MINUS:
            return IR_OPERATOR_NEG
    return IR_OPERATOR_UNKNOWN

def ir_operator_is_comparison(operator: int) -> bool:
    return operator in [
        IR_OPERATOR_LT,
        IR_OPERATOR_GT,
        IR_OPERATOR_LE,
        IR_OPERATOR_GE,
        IR_OPERATOR_EQ,
        IR_OPERATOR_NE,
        IR_OPERATOR_IN,
    ]

def ir_operator_is_boolean_result(operator: int) -> bool:
    return operator in [
        IR_OPERATOR_LT,
        IR_OPERATOR_GT,
        IR_OPERATOR_LE,
        IR_OPERATOR_GE,
        IR_OPERATOR_EQ,
        IR_OPERATOR_NE,
        IR_OPERATOR_IN,
        IR_OPERATOR_AND,
        IR_OPERATOR_OR,
        IR_OPERATOR_NOT,
    ]
