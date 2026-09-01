# dream-test: dir
from argparse import create_parser, ArgParser, Args
from str import contains


def check(cond: bool, msg: str):
    if not cond:
        print("FAIL: " + msg)

def test_basic_flags():
    let parser = create_parser("test_app", "1.0.0", "Test application")
    parser.flag("verbose", "-v", "Enable verbose logging")
    parser.flag("quiet", "-q", "Quiet mode")

    let args = parser.parse(["-v"])
    check(args.is_valid, "args valid")
    check(args.has_flag("verbose") == true, "verbose flag true")
    check(args.has_flag("quiet") == false, "quiet flag false")
    check(args.get_bool("verbose") == true, "get_bool verbose")
    check(args.get_bool("quiet") == false, "get_bool quiet")
    print("test_basic_flags passed")

def test_options_parsing():
    let parser = create_parser("compiler", "0.1.0", "Compiler CLI")
    parser.option("output", "-o", "a.out", "Output executable")
    parser.option("target", "-t", "arm64", "Target architecture")
    parser.option("opt-level", "", "2", "Optimization level")

    # 1. 独立短选项 -o out.bin
    let args1 = parser.parse(["-o", "out.bin", "--opt-level", "3"])
    check(args1.is_valid, "args1 valid")
    check(args1.get("output") == "out.bin", "output opt value")
    check(args1.get("target") == "arm64", "target default value")
    check(args1.get_int("opt-level") == 3, "opt-level as int")

    # 2. 等号长选项 --output=build/app
    let args2 = parser.parse(["--output=build/app", "-t=x86_64"])
    check(args2.is_valid, "args2 valid")
    check(args2.get("output") == "build/app", "output with equal sign")
    check(args2.get("target") == "x86_64", "target with equal sign")

    # 3. 紧凑短选项 -oapp
    let args3 = parser.parse(["-oapp"])
    check(args3.is_valid, "args3 valid")
    check(args3.get("output") == "app", "output compact short option")
    print("test_options_parsing passed")

def test_numeric_and_typed_getters():
    let parser = create_parser("server", "2.0.0", "HTTP Server")
    parser.option("port", "-p", "8080", "Port number")
    parser.option("timeout", "-t", "30.5", "Request timeout in seconds")
    parser.flag("ssl", "-s", "Enable SSL")

    let args = parser.parse(["-p", "9000", "-t", "12.75", "-s"])
    check(args.is_valid, "server args valid")
    check(args.get_int("port") == 9000, "port as int")
    let timeout = args.get_float("timeout")
    check(timeout > 12.74 and timeout < 12.76, "timeout as float")
    check(args.get_bool("ssl") == true, "ssl as bool")
    print("test_numeric_and_typed_getters passed")

def test_combined_short_flags():
    let parser = create_parser("tar", "1.0", "Archive tool")
    parser.flag("extract", "-x", "Extract files")
    parser.flag("verbose", "-v", "Verbose output")
    parser.flag("file", "-f", "File mode")

    let args = parser.parse(["-xvf", "archive.tar"])
    check(args.is_valid, "tar args valid")
    check(args.has_flag("extract") == true, "extract enabled")
    check(args.has_flag("verbose") == true, "verbose enabled")
    check(args.has_flag("file") == true, "file enabled")
    check(args.num_pos() == 1, "has one positional")
    check(args.pos(0) == "archive.tar", "positional is archive.tar")
    print("test_combined_short_flags passed")

def test_positionals_and_dash_dash():
    let parser = create_parser("runner", "1.0", "Test runner")
    parser.flag("dry-run", "-n", "Dry run")
    parser.arg("cmd", "Command to run", true)
    parser.arg("extra", "Extra arguments", false)

    # 遇到 -- 后面的所有选项都作为 positional
    let args = parser.parse(["-n", "exec", "--", "--custom-flag", "-x"])
    check(args.is_valid, "runner args valid")
    check(args.has_flag("dry-run") == true, "dry run enabled")
    check(args.num_pos() == 3, "total positionals including trailing")
    check(args.pos(0) == "exec", "first positional")
    check(args.pos(1) == "--custom-flag", "second positional")
    check(args.pos(2) == "-x", "third positional")
    print("test_positionals_and_dash_dash passed")

def test_subcommands():
    let parser = create_parser("git", "2.40.0", "Distributed version control system")
    parser.flag("verbose", "-v", "Verbose output")

    let clone_cmd = parser.subcommand("clone", "Clone a repository")
    clone_cmd.option("depth", "", "0", "Create a shallow clone")
    clone_cmd.arg("repo", "Repository URL", true)

    let commit_cmd = parser.subcommand("commit", "Record changes to the repository")
    commit_cmd.flag("all", "-a", "Stage all modified files")
    commit_cmd.required_option("message", "-m", "Commit message")

    # 测试子命令 clone
    let args1 = parser.parse(["clone", "--depth", "1", "https://github.com/example/repo"])
    check(args1.is_valid, "clone valid")
    check(args1.has_subcommand() == true, "has subcommand")
    check(args1.subcommand == "clone", "subcommand name")
    check(args1.get_int("depth") == 1, "depth is 1")
    check(args1.pos(0) == "https://github.com/example/repo", "repo URL pos")

    # 测试子命令 commit
    let args2 = parser.parse(["commit", "-a", "-m", "Initial commit"])
    check(args2.is_valid, "commit valid")
    check(args2.subcommand == "commit", "subcommand name commit")
    check(args2.has_flag("all") == true, "all staged flag")
    check(args2.get("message") == "Initial commit", "commit message")
    print("test_subcommands passed")

def test_validation_errors():
    let parser = create_parser("builder", "1.0", "Build tool")
    parser.required_option("config", "-c", "Config file")
    parser.arg("target", "Build target", true)

    # 1. 缺少必填参数
    let args1 = parser.parse(["-c", "build.json"])
    check(args1.is_valid == false, "missing positional should be invalid")
    check(contains(args1.error, "missing required argument"), "error message contains missing arg")

    # 2. 缺少必填选项
    let args2 = parser.parse(["app_target"])
    check(args2.is_valid == false, "missing option should be invalid")
    check(contains(args2.error, "missing required option"), "error message contains missing option")

    # 3. 未知选项
    let args3 = parser.parse(["-c", "build.json", "target", "--unknown"])
    check(args3.is_valid == false, "unknown option should be invalid")
    check(contains(args3.error, "unknown option"), "error message contains unknown option")
    print("test_validation_errors passed")

def test_help_and_version_formatting():
    let parser = create_parser("myapp", "1.2.3", "Modern CLI application")
    parser.flag("verbose", "-v", "Turn on verbose logging")
    parser.option("output", "-o", "dist/", "Output path")
    parser.arg("entry", "Entry source file", true)
    parser.subcommand("serve", "Start web server")

    let help_text = parser.format_help()
    check(contains(help_text, "Modern CLI application"), "help contains description")
    check(contains(help_text, "Usage: myapp"), "help contains usage")
    check(contains(help_text, "Commands:"), "help contains commands section")
    check(contains(help_text, "serve"), "help contains serve subcommand")
    check(contains(help_text, "-h, --help"), "help contains -h")
    check(contains(help_text, "-V, --version"), "help contains -V")
    check(contains(help_text, "-v, --verbose"), "help contains -v")
    check(contains(help_text, "<entry>"), "help contains positional entry")

    let version_text = parser.format_version()
    check(version_text == "myapp 1.2.3", "version text matches")

    # 测试命令行自动解析 -h 和 -V
    let h_args = parser.parse(["-h"])
    check(h_args.is_valid == true, "help args valid")
    check(h_args.is_help == true, "is_help flag set")

    let v_args = parser.parse(["-V"])
    check(v_args.is_valid == true, "version args valid")
    check(v_args.is_version == true, "is_version flag set")
    print("test_help_and_version_formatting passed")

def main():
    test_basic_flags()
    test_options_parsing()
    test_numeric_and_typed_getters()
    test_combined_short_flags()
    test_positionals_and_dash_dash()
    test_subcommands()
    test_validation_errors()
    test_help_and_version_formatting()
    print("all 8 argparse test suites passed!")
