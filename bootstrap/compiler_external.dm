const EXTERNAL_ID_LEN: int = 1000
const EXTERNAL_ID_APPEND: int = 1001
const EXTERNAL_ID_VALUE_TO_STR: int = 1002
const EXTERNAL_ID_IO_WRITE: int = 1003
const EXTERNAL_ID_STRING_CONCAT: int = 1004
const EXTERNAL_ID_STRING_LENGTH: int = 1005
const EXTERNAL_ID_STRING_FIND: int = 1006
const EXTERNAL_ID_STRING_UPPER: int = 1007
const EXTERNAL_ID_STRING_LOWER: int = 1008
const EXTERNAL_ID_STRING_STRIP: int = 1009
const EXTERNAL_ID_STRING_SPLIT: int = 1010
const EXTERNAL_ID_STRING_JOIN: int = 1011
const EXTERNAL_ID_DICT_ITEMS_TUPLES: int = 1012
const EXTERNAL_ID_STRING_STARTS_WITH: int = 1013
const EXTERNAL_ID_STRING_ENDS_WITH: int = 1014
const EXTERNAL_ID_STRING_REPLACE: int = 1015
const EXTERNAL_ID_INT_FLOORDIV: int = 1016
const EXTERNAL_ID_FLOAT_FLOORDIV: int = 1017
const EXTERNAL_ID_INT_POW: int = 1018
const EXTERNAL_ID_FLOAT_POW: int = 1019
const EXTERNAL_ID_STRING_IS_DIGIT: int = 1020
const EXTERNAL_ID_STRING_IS_ALPHA: int = 1021
const EXTERNAL_ID_TIME_MS: int = 1022
const EXTERNAL_ID_DEBUG_ON: int = 1023
const EXTERNAL_ID_RANGE_EQUAL: int = 1024
const EXTERNAL_ID_FNV_HASH_RANGE: int = 1025
const EXTERNAL_ID_STRING_IS_WHITESPACE: int = 1026
const EXTERNAL_ID_UNION_CREATE_INT: int = 1027
const EXTERNAL_ID_UNION_CREATE_FLOAT: int = 1028
const EXTERNAL_ID_UNION_CREATE_STRING: int = 1029
const EXTERNAL_ID_UNION_CREATE_BOOL: int = 1030
const EXTERNAL_ID_UNION_CREATE_BYTES: int = 1031
const EXTERNAL_ID_UNION_IS_INT: int = 1032
const EXTERNAL_ID_UNION_IS_FLOAT: int = 1033
const EXTERNAL_ID_UNION_IS_STRING: int = 1034
const EXTERNAL_ID_UNION_IS_BOOL: int = 1035
const EXTERNAL_ID_UNION_IS_BYTES: int = 1036
const EXTERNAL_ID_UNION_GET_INT: int = 1037
const EXTERNAL_ID_UNION_GET_FLOAT: int = 1038
const EXTERNAL_ID_UNION_GET_STRING: int = 1039
const EXTERNAL_ID_UNION_GET_BOOL: int = 1040
const EXTERNAL_ID_UNION_GET_BYTES: int = 1041
const EXTERNAL_ID_UNION_PRINT_VALUE: int = 1042
const EXTERNAL_ID_PROCESS_ARG_COUNT: int = 1043
const EXTERNAL_ID_PROCESS_ARG: int = 1044
const EXTERNAL_ID_FILE_READ: int = 1045
const EXTERNAL_ID_FILE_WRITE: int = 1046
const EXTERNAL_ID_FILE_EXISTS: int = 1047
const EXTERNAL_ID_FILE_DELETE: int = 1048
const EXTERNAL_ID_BUILD_LLVM: int = 1049
const EXTERNAL_ID_FILE_READ_BYTES: int = 1050
const EXTERNAL_ID_FILE_WRITE_BYTES: int = 1051
const EXTERNAL_ID_BYTES_LENGTH: int = 1052
const EXTERNAL_ID_BYTES_GET: int = 1053
const EXTERNAL_ID_BYTES_SLICE: int = 1054
const EXTERNAL_ID_BYTES_FROM_ARRAY: int = 1055
const EXTERNAL_ID_STR_TO_BYTES: int = 1056
const EXTERNAL_ID_BYTES_TO_STR: int = 1057
const EXTERNAL_ID_DICT_SET_INT_INT: int = 1058
const EXTERNAL_ID_DICT_SET_INT_STR: int = 1059
const EXTERNAL_ID_DICT_SET_STR_INT: int = 1060
const EXTERNAL_ID_DICT_SET_STR_STR: int = 1061
const EXTERNAL_ID_DICT_CREATE_INT_INT: int = 1062
const EXTERNAL_ID_DICT_CREATE_INT_STR: int = 1063
const EXTERNAL_ID_DICT_CREATE_STR_INT: int = 1064
const EXTERNAL_ID_DICT_CREATE_STR_STR: int = 1065
const EXTERNAL_ID_DICT_GET_INT_INT: int = 1066
const EXTERNAL_ID_DICT_GET_INT_STR: int = 1067
const EXTERNAL_ID_DICT_GET_STR_INT: int = 1068
const EXTERNAL_ID_DICT_GET_STR_STR: int = 1069
const EXTERNAL_ID_DICT_SIZE_INT_INT: int = 1070
const EXTERNAL_ID_DICT_SIZE_INT_STR: int = 1071
const EXTERNAL_ID_DICT_SIZE_STR_INT: int = 1072
const EXTERNAL_ID_DICT_SIZE_STR_STR: int = 1073
const EXTERNAL_ID_RUNE_COUNT: int = 1074
const EXTERNAL_ID_RUNE_AT: int = 1075
const EXTERNAL_ID_RANGE_EQUALS_CSTR: int = 1076
const EXTERNAL_ID_UTF8_ENCODE_RUNE: int = 1077
const EXTERNAL_ID_ENUM_CREATE_SIMPLE: int = 1078
const EXTERNAL_ID_ENUM_CREATE_INT: int = 1079
const EXTERNAL_ID_ENUM_CREATE_FLOAT: int = 1080
const EXTERNAL_ID_ENUM_CREATE_STRING: int = 1081
const EXTERNAL_ID_ENUM_CREATE_BOOL: int = 1082
const EXTERNAL_ID_ENUM_GET_TAG: int = 1083
const EXTERNAL_ID_ENUM_GET_INT: int = 1084
const EXTERNAL_ID_ENUM_GET_FLOAT: int = 1085
const EXTERNAL_ID_ENUM_GET_STRING: int = 1086
const EXTERNAL_ID_ENUM_GET_BOOL: int = 1087
const EXTERNAL_ID_INTERFACE_BOX: int = 1088
const EXTERNAL_ID_INTERFACE_OBJ: int = 1089
const EXTERNAL_ID_INTERFACE_TAG: int = 1090
const EXTERNAL_ID_FILE_APPEND: int = 1091
const EXTERNAL_ID_FILE_APPEND_BYTES: int = 1092
const EXTERNAL_ID_RUNE_TO_INT: int = 1093
const EXTERNAL_ID_UTF8_BYTE_OFFSET: int = 1094
const EXTERNAL_ID_ENV: int = 1095
const EXTERNAL_ID_FILE_IS_DIR: int = 1096
const EXTERNAL_ID_FILE_MKDIR: int = 1097
const EXTERNAL_ID_FILE_RENAME: int = 1098
const EXTERNAL_ID_FILE_SIZE: int = 1099
const EXTERNAL_ID_ENUM_CREATE_TUPLE_PTR: int = 1100
const EXTERNAL_ID_ENUM_GET_DATA: int = 1101
const EXTERNAL_ID_NET_CONNECT: int = 1102
const EXTERNAL_ID_NET_WRITE: int = 1103
const EXTERNAL_ID_NET_READ: int = 1104
const EXTERNAL_ID_NET_CLOSE: int = 1105
const EXTERNAL_ID_HTTP_REQUEST: int = 1106
const EXTERNAL_ID_CRYPTO_SHA256: int = 1107
const EXTERNAL_ID_CRYPTO_SHA256_BYTES: int = 1108
const EXTERNAL_ID_DICT_SET_INT_PTR: int = 1109
const EXTERNAL_ID_DICT_SET_STR_PTR: int = 1110
const EXTERNAL_ID_DICT_CREATE_INT_PTR: int = 1111
const EXTERNAL_ID_DICT_CREATE_STR_PTR: int = 1112
const EXTERNAL_ID_DICT_GET_INT_PTR: int = 1113
const EXTERNAL_ID_DICT_GET_STR_PTR: int = 1114
const EXTERNAL_ID_DICT_HAS_STR: int = 1115

const EXTERNAL_ID_BASE: int = 1000
const EXTERNAL_RETURN_UNIT: int = 1
const EXTERNAL_RETURN_INT: int = 2
const EXTERNAL_RETURN_BOOL: int = 3
const EXTERNAL_RETURN_FLOAT: int = 4
const EXTERNAL_RETURN_POINTER: int = 5
const EXTERNAL_RETURN_STRING: int = 6

# 外部调用定义集中在一个全局表中，索引与 external_id 的偏移保持一致。
struct ExternalDef:
    name: str
    return_type: int
    has_declaration: bool

let EXTERNAL_DEFS: list[ExternalDef] = [
    ExternalDef{
        name: "len",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "append",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_value_to_str",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_io_write",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_str_concat",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_len",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_find",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_upper",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_lower",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_strip",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_split",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_join",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_items_tuples",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_starts_with",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_ends_with",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_replace",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_int_floordiv",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_float_floordiv",
        return_type: EXTERNAL_RETURN_FLOAT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_int_pow",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_float_pow",
        return_type: EXTERNAL_RETURN_FLOAT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_is_digit",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_is_alpha",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_time_ms",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_debug_on",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_range_equal",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_fnv_hash_range",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_is_whitespace",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_create_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_create_float",
        return_type: EXTERNAL_RETURN_FLOAT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_create_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_create_bool",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_create_bytes",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_is_int",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_is_float",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_is_str",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_is_bool",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_is_bytes",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_get_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_get_float",
        return_type: EXTERNAL_RETURN_FLOAT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_get_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_get_bool",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_get_bytes",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_union_print_value",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_process_arg_count",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_process_arg",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_read",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_write",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_exists",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_delete",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_build_llvm",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_read_bytes",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_write_bytes",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_bytes_len",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_bytes_get",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_bytes_slice",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_bytes_from_array",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_str_to_bytes",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_bytes_to_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_set_int_int",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_set_int_str",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_set_str_int",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_set_str_str",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_int_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_int_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_str_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_str_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_int_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_int_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_str_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_str_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_size_int_int",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_size_int_str",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_size_str_int",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_size_str_str",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_utf8_rune_count",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_utf8_rune_at",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_range_equals_cstr",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_utf8_encode_rune",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_simple",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_int",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_float",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_str",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_bool",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_tag",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_int",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_float",
        return_type: EXTERNAL_RETURN_FLOAT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_str",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_bool",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_interface_box",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_interface_obj",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_interface_tag",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_append",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_append_bytes",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_rune_to_int",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_utf8_byte_offset",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_env",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_is_dir",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_mkdir",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_rename",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_file_size",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_create_tuple_ptr",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_enum_get_data",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_net_connect",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_net_write",
        return_type: EXTERNAL_RETURN_INT,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_net_read",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_net_close",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_http_request",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_crypto_sha256",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_crypto_sha256_bytes",
        return_type: EXTERNAL_RETURN_STRING,
        has_declaration: true
    },
    ExternalDef{
        name: "__c_dict_set_int_ptr",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_set_str_ptr",
        return_type: EXTERNAL_RETURN_UNIT,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_int_ptr",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_create_str_ptr",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_int_ptr",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_get_str_ptr",
        return_type: EXTERNAL_RETURN_POINTER,
        has_declaration: false
    },
    ExternalDef{
        name: "__c_dict_has_str",
        return_type: EXTERNAL_RETURN_BOOL,
        has_declaration: true
    }
]

def external_llvm_name(external_id: int) -> str:
    # len/append 是内置多态函数，LLVM 层按操作数类型分派。
    if external_id == EXTERNAL_ID_LEN:
        return "@__c_len_dynarray_i32"
    if external_id == EXTERNAL_ID_APPEND:
        return "@__c_append_i32"
    if external_id < EXTERNAL_ID_BASE or external_id >= EXTERNAL_ID_BASE + len(EXTERNAL_DEFS):
        return "@llvm.trap"
    let name = EXTERNAL_DEFS[external_id - EXTERNAL_ID_BASE].name
    if name == "":
        return "@llvm.trap"
    return "@" + name

def external_return_type(external_id: int) -> int:
    if external_id < EXTERNAL_ID_BASE or external_id >= EXTERNAL_ID_BASE + len(EXTERNAL_DEFS):
        return EXTERNAL_RETURN_POINTER
    return EXTERNAL_DEFS[external_id - EXTERNAL_ID_BASE].return_type

def external_has_declaration(external_id: int) -> bool:
    if external_id < EXTERNAL_ID_BASE or external_id >= EXTERNAL_ID_BASE + len(EXTERNAL_DEFS):
        return false
    return EXTERNAL_DEFS[external_id - EXTERNAL_ID_BASE].has_declaration

def external_id_from_name(name: str) -> int:
    let index = 0
    while index < len(EXTERNAL_DEFS):
        if EXTERNAL_DEFS[index].name != "" and EXTERNAL_DEFS[index].name == name:
            return EXTERNAL_ID_BASE + index
        index = index + 1
    return -1
