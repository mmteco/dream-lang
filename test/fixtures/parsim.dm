# 回归 fixture:参数解析模拟(while + 字符串比较 + 多变量重绑定,stage2 曾误判)
# 预期输出:x.dm / /tmp/zz / 1
# 背景: docs/STRUCT_FIELD_PIPELINE.md "parse_build_arguments 误判"
def main() -> int:
    let args: list[str] = []
    append(args, "build")
    append(args, "x.dm")
    append(args, "-o")
    append(args, "/tmp/zz")
    let input_path = ""
    let output_path = ""
    let has_output = false
    let is_valid = true
    let argument_index = 1
    while argument_index < len(args):
        let argument = args[argument_index]
        let step = 1
        if argument == "--dev":
            is_valid = false
        elif argument == "-o":
            if has_output or argument_index + 1 >= len(args):
                is_valid = false
            else:
                output_path = args[argument_index + 1]
                has_output = true
                step = 2
        elif text_len(input_path) == 0:
            input_path = argument
        else:
            is_valid = false
        argument_index = argument_index + step
    print(input_path)
    print(output_path)
    if is_valid:
        print(1)
    else:
        print(0)
    return 0
