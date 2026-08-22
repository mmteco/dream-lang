from bootstrap_io import text_length

const EXTERNAL_ID_PRINT_INT: int = 1000
const EXTERNAL_ID_PRINT_FLOAT: int = 1001
const EXTERNAL_ID_PRINT_BOOL: int = 1002
const EXTERNAL_ID_PRINT_STRING: int = 1003
const EXTERNAL_ID_EPRINT_INT: int = 1004
const EXTERNAL_ID_EPRINT_FLOAT: int = 1005
const EXTERNAL_ID_EPRINT_BOOL: int = 1006
const EXTERNAL_ID_EPRINT_STRING: int = 1007
const EXTERNAL_ID_STRING_CONCAT: int = 1008
const EXTERNAL_ID_STRING_LENGTH: int = 1009
const EXTERNAL_ID_STRING_FIND: int = 1010
const EXTERNAL_ID_STRING_UPPER: int = 1011
const EXTERNAL_ID_STRING_LOWER: int = 1012
const EXTERNAL_ID_STRING_STRIP: int = 1013
const EXTERNAL_ID_STRING_SPLIT: int = 1014
const EXTERNAL_ID_STRING_JOIN: int = 1015
const EXTERNAL_ID_DICT_ITEMS_TUPLES: int = 1016
const EXTERNAL_ID_STRING_STARTS_WITH: int = 1017
const EXTERNAL_ID_STRING_ENDS_WITH: int = 1018
const EXTERNAL_ID_STRING_REPLACE: int = 1019
const EXTERNAL_ID_INT_FLOORDIV: int = 1020
const EXTERNAL_ID_FLOAT_FLOORDIV: int = 1021
const EXTERNAL_ID_INT_POW: int = 1022
const EXTERNAL_ID_FLOAT_POW: int = 1023
const EXTERNAL_ID_STRING_IS_DIGIT: int = 1024
const EXTERNAL_ID_STRING_IS_ALPHA: int = 1025
const EXTERNAL_ID_TIME_MS: int = 1026
const EXTERNAL_ID_DEBUG_ON: int = 1027
const EXTERNAL_ID_EPRINT_TEXT: int = 1028
const EXTERNAL_ID_EPRINT_INTEGER: int = 1029
const EXTERNAL_ID_RANGE_EQUAL: int = 1030
const EXTERNAL_ID_FNV_HASH_RANGE: int = 1031
const EXTERNAL_ID_STRING_IS_WHITESPACE: int = 1032
const EXTERNAL_ID_UNION_CREATE_INT: int = 1033
const EXTERNAL_ID_UNION_CREATE_FLOAT: int = 1034
const EXTERNAL_ID_UNION_CREATE_STRING: int = 1035
const EXTERNAL_ID_UNION_CREATE_BOOL: int = 1036
const EXTERNAL_ID_UNION_CREATE_BYTES: int = 1037
const EXTERNAL_ID_UNION_IS_INT: int = 1038
const EXTERNAL_ID_UNION_IS_FLOAT: int = 1039
const EXTERNAL_ID_UNION_IS_STRING: int = 1040
const EXTERNAL_ID_UNION_IS_BOOL: int = 1041
const EXTERNAL_ID_UNION_IS_BYTES: int = 1042
const EXTERNAL_ID_UNION_GET_INT: int = 1043
const EXTERNAL_ID_UNION_GET_FLOAT: int = 1044
const EXTERNAL_ID_UNION_GET_STRING: int = 1045
const EXTERNAL_ID_UNION_GET_BOOL: int = 1046
const EXTERNAL_ID_UNION_GET_BYTES: int = 1047
const EXTERNAL_ID_UNION_PRINT_VALUE: int = 1048
const EXTERNAL_ID_PROCESS_ARG_COUNT: int = 1049
const EXTERNAL_ID_PROCESS_ARG: int = 1050
const EXTERNAL_ID_FILE_READ: int = 1051
const EXTERNAL_ID_FILE_WRITE: int = 1052
const EXTERNAL_ID_FILE_EXISTS: int = 1053
const EXTERNAL_ID_FILE_DELETE: int = 1054
const EXTERNAL_ID_BUILD_LLVM: int = 1055
const EXTERNAL_ID_FILE_READ_BYTES: int = 1056
const EXTERNAL_ID_FILE_WRITE_BYTES: int = 1057
const EXTERNAL_ID_BYTES_LENGTH: int = 1058
const EXTERNAL_ID_BYTES_GET: int = 1059
const EXTERNAL_ID_BYTES_SLICE: int = 1060
const EXTERNAL_ID_BYTES_FROM_ARRAY: int = 1061
const EXTERNAL_ID_STR_TO_BYTES: int = 1062
const EXTERNAL_ID_BYTES_TO_STR: int = 1063
const EXTERNAL_ID_DICT_SET_INT_INT: int = 1064
const EXTERNAL_ID_DICT_SET_INT_STR: int = 1065
const EXTERNAL_ID_DICT_SET_STR_INT: int = 1066
const EXTERNAL_ID_DICT_SET_STR_STR: int = 1067
const EXTERNAL_ID_DICT_CREATE_INT_INT: int = 1068
const EXTERNAL_ID_DICT_CREATE_INT_STR: int = 1069
const EXTERNAL_ID_DICT_CREATE_STR_INT: int = 1070
const EXTERNAL_ID_DICT_CREATE_STR_STR: int = 1071
const EXTERNAL_ID_DICT_GET_INT_INT: int = 1072
const EXTERNAL_ID_DICT_GET_INT_STR: int = 1073
const EXTERNAL_ID_DICT_GET_STR_INT: int = 1074
const EXTERNAL_ID_DICT_GET_STR_STR: int = 1075
const EXTERNAL_ID_DICT_SIZE_INT_INT: int = 1076
const EXTERNAL_ID_DICT_SIZE_INT_STR: int = 1077
const EXTERNAL_ID_DICT_SIZE_STR_INT: int = 1078
const EXTERNAL_ID_DICT_SIZE_STR_STR: int = 1079
const EXTERNAL_ID_RUNE_COUNT: int = 1080
const EXTERNAL_ID_RUNE_AT: int = 1081
const EXTERNAL_ID_PRINT: int = 1082
const EXTERNAL_ID_EPRINT: int = 1083
const EXTERNAL_ID_LEN: int = 1084
const EXTERNAL_ID_APPEND: int = 1085
const EXTERNAL_ID_UTF8_ENCODE_RUNE: int = 1087
const EXTERNAL_ID_ENUM_CREATE_SIMPLE: int = 1088
const EXTERNAL_ID_ENUM_CREATE_INT: int = 1089
const EXTERNAL_ID_ENUM_CREATE_FLOAT: int = 1090
const EXTERNAL_ID_ENUM_CREATE_STRING: int = 1091
const EXTERNAL_ID_ENUM_CREATE_BOOL: int = 1092
const EXTERNAL_ID_ENUM_GET_TAG: int = 1093
const EXTERNAL_ID_ENUM_GET_INT: int = 1094
const EXTERNAL_ID_ENUM_GET_FLOAT: int = 1095
const EXTERNAL_ID_ENUM_GET_STRING: int = 1096
const EXTERNAL_ID_ENUM_GET_BOOL: int = 1097

const EXTERNAL_COUNT: int = 98
const EXTERNAL_ID_BASE: int = 1000
const EXTERNAL_RETURN_UNIT: int = 1
const EXTERNAL_RETURN_INT: int = 2
const EXTERNAL_RETURN_BOOL: int = 3
const EXTERNAL_RETURN_FLOAT: int = 4
const EXTERNAL_RETURN_POINTER: int = 5
const EXTERNAL_RETURN_STRING: int = 6

const RUNTIME_EXTERN_NAMES: str = "dream_print_int\ndream_print_float\ndream_print_bool\ndream_print_string\ndream_eprint_int\ndream_eprint_float\ndream_eprint_bool\ndream_eprint_string\nstring_concat\nstring_length\nstring_find\nstring_upper\nstring_lower\nstring_strip\nstring_split\nstring_join\ndict_items_tuples\nstring_starts_with\nstring_ends_with\nstring_replace\nint_floordiv\nfloat_floordiv\nint_pow\nfloat_pow\nstring_is_digit\nstring_is_alpha\n__c_time_ms\n__c_debug_on\n__c_eprint_text\n__c_eprint_int\n__c_range_equal\n__c_fnv_hash_range\nstring_is_whitespace\nunion_create_int\nunion_create_float\nunion_create_string\nunion_create_bool\nunion_create_bytes\nunion_is_int\nunion_is_float\nunion_is_string\nunion_is_bool\nunion_is_bytes\nunion_get_int\nunion_get_float\nunion_get_string\nunion_get_bool\nunion_get_bytes\nunion_print_value\n__c_process_arg_count\n__c_process_arg\n__c_file_read\n__c_file_write\n__c_file_exists\n__c_file_delete\n__c_build_llvm\n__c_file_read_bytes\n__c_file_write_bytes\n__c_bytes_length\n__c_bytes_get\n__c_bytes_slice\n__c_bytes_from_array\n__c_str_to_bytes\n__c_bytes_to_str\ndict_set_int_int\ndict_set_int_str\ndict_set_str_int\ndict_set_str_str\ndream_dict_create_int_int\ndream_dict_create_int_str\ndream_dict_create_str_int\ndream_dict_create_str_str\ndream_dict_get_int_int\ndream_dict_get_int_str\ndream_dict_get_str_int\ndream_dict_get_str_str\ndream_dict_size_int_int\ndream_dict_size_int_str\ndream_dict_size_str_int\ndream_dict_size_str_str\n__c_utf8_rune_count\n__c_utf8_rune_at\nprint\neprint\nlen\nappend\n__c_range_equals_cstr\n__c_utf8_encode_rune\nenum_create_simple\nenum_create_int\nenum_create_float\nenum_create_string\nenum_create_bool\nenum_get_tag\nenum_get_int\nenum_get_float\nenum_get_string\nenum_get_bool"
const RUNTIME_EXTERN_LLVM_NAMES: str = "@dream_print_int\n@dream_print_float\n@dream_print_bool\n@dream_print_string\n@dream_eprint_int\n@dream_eprint_float\n@dream_eprint_bool\n@dream_eprint_string\n@string_concat\n@string_length\n@string_find\n@string_upper\n@string_lower\n@string_strip\n@string_split\n@string_join\n@dict_items_tuples\n@string_starts_with\n@string_ends_with\n@string_replace\n@int_floordiv\n@float_floordiv\n@int_pow\n@float_pow\n@string_is_digit\n@string_is_alpha\n@__c_time_ms\n@__c_debug_on\n@__c_eprint_text\n@__c_eprint_int\n@__c_range_equal\n@__c_fnv_hash_range\n@string_is_whitespace\n@union_create_int\n@union_create_float\n@union_create_string\n@union_create_bool\n@union_create_bytes\n@union_is_int\n@union_is_float\n@union_is_string\n@union_is_bool\n@union_is_bytes\n@union_get_int\n@union_get_float\n@union_get_string\n@union_get_bool\n@union_get_bytes\n@union_print_value\n@__c_process_arg_count\n@__c_process_arg\n@__c_file_read\n@__c_file_write\n@__c_file_exists\n@__c_file_delete\n@__c_build_llvm\n@__c_file_read_bytes\n@__c_file_write_bytes\n@__c_bytes_length\n@__c_bytes_get\n@__c_bytes_slice\n@__c_bytes_from_array\n@__c_str_to_bytes\n@__c_bytes_to_str\n@dict_set_int_int\n@dict_set_int_str\n@dict_set_str_int\n@dict_set_str_str\n@dream_dict_create_int_int\n@dream_dict_create_int_str\n@dream_dict_create_str_int\n@dream_dict_create_str_str\n@dream_dict_get_int_int\n@dream_dict_get_int_str\n@dream_dict_get_str_int\n@dream_dict_get_str_str\n@dream_dict_size_int_int\n@dream_dict_size_int_str\n@dream_dict_size_str_int\n@dream_dict_size_str_str\n@__c_utf8_rune_count\n@__c_utf8_rune_at\n@dream_print_string\n@dream_eprint_string\n@len_dynarray_i32\n@append_i32\n@__c_range_equals_cstr\n@__c_utf8_encode_rune\n@enum_create_simple\n@enum_create_int\n@enum_create_float\n@enum_create_string\n@enum_create_bool\n@enum_get_tag\n@enum_get_int\n@enum_get_float\n@enum_get_string\n@enum_get_bool"
let runtime_extern_return_types: list[int] = []
let runtime_extern_declarations: list[int] = []
let runtime_externs_initialized: list[int] = [0]

def runtime_extern_int_get(values: list[int], index: int) -> int:
    if index < 0 or index >= len(values):
        return 0
    return values[index]

def runtime_extern_int_set(values: list[int], index: int, value: int):
    values[index] = value

def runtime_externs_init():
    if runtime_extern_int_get(runtime_externs_initialized, 0) != 0:
        return
    runtime_extern_int_set(runtime_externs_initialized, 0, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_FLOAT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_FLOAT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_FLOAT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_FLOAT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_UNIT)
    append(runtime_extern_declarations, 0)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_POINTER)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_INT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_FLOAT)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_STRING)
    append(runtime_extern_declarations, 1)
    append(runtime_extern_return_types, EXTERNAL_RETURN_BOOL)
    append(runtime_extern_declarations, 1)

def runtime_extern_at(source: str, external_id: int) -> str:
    let current_id = 1
    let line_start = 0
    let source_length = text_length(source)
    while current_id < external_id and line_start < source_length:
        if source[line_start] == '\n':
            current_id = current_id + 1
        line_start = line_start + 1
    let line_end = line_start
    while line_end < source_length and source[line_end] != '\n':
        line_end = line_end + 1
    return source[line_start:line_end]

def external_llvm_name(external_id: int) -> str:
    if external_id < EXTERNAL_ID_BASE or external_id > EXTERNAL_ID_BASE + EXTERNAL_COUNT - 1:
        return "@llvm.trap"
    return runtime_extern_at(RUNTIME_EXTERN_LLVM_NAMES, external_id - EXTERNAL_ID_BASE + 1)

def external_return_type(external_id: int) -> int:
    if external_id == EXTERNAL_ID_BYTES_LENGTH or external_id == EXTERNAL_ID_BYTES_GET:
        return EXTERNAL_RETURN_INT
    if external_id >= EXTERNAL_ID_BYTES_SLICE and external_id <= EXTERNAL_ID_BYTES_TO_STR:
        return EXTERNAL_RETURN_POINTER
    if external_id == EXTERNAL_ID_APPEND or external_id == EXTERNAL_ID_PRINT or external_id == EXTERNAL_ID_EPRINT:
        return EXTERNAL_RETURN_UNIT
    runtime_externs_init()
    if external_id < EXTERNAL_ID_BASE or external_id > EXTERNAL_ID_BASE + EXTERNAL_COUNT - 1:
        return EXTERNAL_RETURN_POINTER
    return runtime_extern_int_get(runtime_extern_return_types, external_id - EXTERNAL_ID_BASE)

def external_has_declaration(external_id: int) -> bool:
    runtime_externs_init()
    if external_id < EXTERNAL_ID_BASE or external_id > EXTERNAL_ID_BASE + EXTERNAL_COUNT - 1:
        return false
    return runtime_extern_int_get(runtime_extern_declarations, external_id - EXTERNAL_ID_BASE) != 0

def external_id_from_name(name: str) -> int:
    if name == "__c_bytes_length":
        return EXTERNAL_ID_BYTES_LENGTH
    if name == "__c_bytes_get":
        return EXTERNAL_ID_BYTES_GET
    if name == "__c_bytes_slice":
        return EXTERNAL_ID_BYTES_SLICE
    if name == "__c_bytes_from_array":
        return EXTERNAL_ID_BYTES_FROM_ARRAY
    if name == "__c_str_to_bytes":
        return EXTERNAL_ID_STR_TO_BYTES
    if name == "__c_bytes_to_str":
        return EXTERNAL_ID_BYTES_TO_STR
    if name == "__c_utf8_rune_count":
        return EXTERNAL_ID_RUNE_COUNT
    if name == "__c_utf8_rune_at":
        return EXTERNAL_ID_RUNE_AT
    if name == "print":
        return EXTERNAL_ID_PRINT
    if name == "eprint":
        return EXTERNAL_ID_EPRINT
    if name == "len":
        return EXTERNAL_ID_LEN
    if name == "append":
        return EXTERNAL_ID_APPEND
    let external_id = 1
    let line_start = 0
    let source_length = text_length(RUNTIME_EXTERN_NAMES)
    while external_id <= EXTERNAL_COUNT:
        let line_end = line_start
        while line_end < source_length and RUNTIME_EXTERN_NAMES[line_end] != '\n':
            line_end = line_end + 1
        if RUNTIME_EXTERN_NAMES[line_start:line_end] == name:
            return external_id + EXTERNAL_ID_BASE - 1
        external_id = external_id + 1
        line_start = line_end + 1
    return -1
