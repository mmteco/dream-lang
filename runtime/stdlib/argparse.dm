# Modern, type-safe command-line argument parser for Dream.

from sys import argc, arg
from str import len, startswith, endswith, find, split, join, ljust, strip, parse_int, parse_float


def clean_name(token: str) -> str:
    if startswith(token, "--"):
        return token[2:]
    if startswith(token, "-"):
        return token[1:]
    return token


struct Flag:
    name: str
    short: str
    help: str

struct Opt:
    name: str
    short: str
    default_val: str
    help: str
    required: bool

struct PosArg:
    name: str
    help: str
    required: bool

struct Subcommand:
    name: str
    description: str
    flags: list[Flag]
    options: list[Opt]
    positionals: list[PosArg]

    def flag(self, name: str, short: str, help: str) -> Subcommand:
        append(self.flags, Flag{
            name: clean_name(name),
            short: clean_name(short),
            help: help
        })
        return self

    def option(self, name: str, short: str, default_val: str, help: str) -> Subcommand:
        append(self.options, Opt{
            name: clean_name(name),
            short: clean_name(short),
            default_val: default_val,
            help: help,
            required: false
        })
        return self

    def required_option(self, name: str, short: str, help: str) -> Subcommand:
        append(self.options, Opt{
            name: clean_name(name),
            short: clean_name(short),
            default_val: "",
            help: help,
            required: true
        })
        return self

    def arg(self, name: str, help: str, required: bool) -> Subcommand:
        append(self.positionals, PosArg{
            name: name,
            help: help,
            required: required
        })
        return self


struct Args:
    flags: dict[str, int]
    options: dict[str, str]
    positionals: list[str]
    subcommand: str
    is_valid: bool
    is_help: bool
    is_version: bool
    error: str

    def has_flag(self, name: str) -> bool:
        let key = clean_name(name)
        if key in self.flags:
            return self.flags[key] == 1
        return false

    def get_bool(self, name: str) -> bool:
        return self.has_flag(name)

    def get(self, name: str) -> str:
        let key = clean_name(name)
        if key in self.options:
            return self.options[key]
        return ""

    def get_or(self, name: str, fallback: str) -> str:
        let key = clean_name(name)
        if key in self.options:
            return self.options[key]
        return fallback

    def get_str(self, name: str) -> str:
        return self.get(name)

    def get_int(self, name: str) -> int:
        return parse_int(self.get(name), 0)

    def get_int_or(self, name: str, fallback: int) -> int:
        return parse_int(self.get(name), fallback)

    def get_float(self, name: str) -> float:
        return parse_float(self.get(name), 0.0)

    def get_float_or(self, name: str, fallback: float) -> float:
        return parse_float(self.get(name), fallback)

    def has_opt(self, name: str) -> bool:
        let key = clean_name(name)
        return key in self.options

    def pos(self, index: int) -> str:
        if index >= 0 and index < len(self.positionals):
            return self.positionals[index]
        return ""

    def pos_or(self, index: int, fallback: str) -> str:
        if index >= 0 and index < len(self.positionals):
            return self.positionals[index]
        return fallback

    def num_pos(self) -> int:
        return len(self.positionals)

    def has_subcommand(self) -> bool:
        return self.subcommand != ""

def find_flag(flags: list[Flag], token: str) -> int:
    let key = clean_name(token)
    let idx = 0
    let total = len(flags)
    while idx < total:
        let f = flags[idx]
        if f.name == key or f.short == key:
            return idx
        idx += 1
    return -1

def find_option(options: list[Opt], token: str) -> int:
    let key = clean_name(token)
    let idx = 0
    let total = len(options)
    while idx < total:
        let opt = options[idx]
        if opt.name == key or opt.short == key:
            return idx
        idx += 1
    return -1

def make_help_args(flags: dict[str, int], options: dict[str, str], pos: list[str]) -> Args:
    return Args{
        flags: flags,
        options: options,
        positionals: pos,
        subcommand: "",
        is_valid: true,
        is_help: true,
        is_version: false,
        error: ""
    }

def make_version_args(flags: dict[str, int], options: dict[str, str], pos: list[str]) -> Args:
    return Args{
        flags: flags,
        options: options,
        positionals: pos,
        subcommand: "",
        is_valid: true,
        is_help: false,
        is_version: true,
        error: ""
    }

def make_error_args(flags: dict[str, int], options: dict[str, str], pos: list[str], err: str) -> Args:
    return Args{
        flags: flags,
        options: options,
        positionals: pos,
        subcommand: "",
        is_valid: false,
        is_help: false,
        is_version: false,
        error: err
    }

def parse_tokens(flags: list[Flag], options: list[Opt], pos_defs: list[PosArg], tokens: list[str], version: str) -> Args:
    let parsed_flags: dict[str, int] = {}
    let parsed_options: dict[str, str] = {}
    let positionals: list[str] = []

    let flag_init_idx = 0
    while flag_init_idx < len(flags):
        parsed_flags[flags[flag_init_idx].name] = 0
        flag_init_idx += 1

    let opt_init_idx = 0
    while opt_init_idx < len(options):
        let current_opt = options[opt_init_idx]
        if current_opt.default_val != "":
            parsed_options[current_opt.name] = current_opt.default_val
        opt_init_idx += 1

    let total = len(tokens)
    let idx = 0
    let parse_opts = true

    while idx < total:
        let item = tokens[idx]

        # '--' ends option parsing
        if parse_opts and item == "--":
            parse_opts = false
            idx += 1
            continue

        if parse_opts and (item == "-h" or item == "--help"):
            return make_help_args(parsed_flags, parsed_options, positionals)

        if parse_opts and (item == "-V" or item == "--version") and version != "":
            return make_version_args(parsed_flags, parsed_options, positionals)

        # Long format: --name or --name=value
        if parse_opts and startswith(item, "--") and len(item) > 2:
            let eq_pos = find(item, "=")
            let opt_key = ""
            let opt_val = ""
            let has_eq = false
            if eq_pos > 0:
                opt_key = item[2:eq_pos]
                opt_val = item[eq_pos + 1:]
                has_eq = true
            else:
                opt_key = item[2:]

            let flag_idx = find_flag(flags, opt_key)
            if flag_idx >= 0:
                let target_flag_name = flags[flag_idx].name
                parsed_flags[target_flag_name] = 1
                idx += 1
                continue

            let opt_idx = find_option(options, opt_key)
            if opt_idx >= 0:
                let key_name = options[opt_idx].name
                if has_eq:
                    parsed_options[key_name] = opt_val
                elif idx + 1 < total:
                    idx += 1
                    parsed_options[key_name] = tokens[idx]
                else:
                    let err = "Error: option '--" + opt_key + "' requires a value"
                    return make_error_args(parsed_flags, parsed_options, positionals, err)
                idx += 1
                continue

            let err = "Error: unknown option '--" + opt_key + "'"
            return make_error_args(parsed_flags, parsed_options, positionals, err)

        # Short format: -o, -o=value, -ovalue, or -xvf
        if parse_opts and startswith(item, "-") and len(item) > 1 and item != "-":
            let eq_pos = find(item, "=")
            let short_str = ""
            let opt_val = ""
            let has_eq = false
            if eq_pos > 0:
                short_str = item[1:eq_pos]
                opt_val = item[eq_pos + 1:]
                has_eq = true
            else:
                short_str = item[1:]

            let first_char = short_str[:1]
            let opt_idx = find_option(options, first_char)
            if opt_idx >= 0:
                let key_name = options[opt_idx].name
                if has_eq:
                    parsed_options[key_name] = opt_val
                elif len(short_str) > 1:
                    parsed_options[key_name] = short_str[1:]
                elif idx + 1 < total:
                    idx += 1
                    parsed_options[key_name] = tokens[idx]
                else:
                    let err = "Error: option '-" + first_char + "' requires a value"
                    return make_error_args(parsed_flags, parsed_options, positionals, err)
                idx += 1
                continue

            # Check grouped flags: -abc
            let all_flags = true
            let f_i = 0
            while f_i < len(short_str):
                let ch = short_str[f_i:f_i + 1]
                let matched = find_flag(flags, ch)
                if matched >= 0:
                    let target_flag_name = flags[matched].name
                    parsed_flags[target_flag_name] = 1
                else:
                    all_flags = false
                    break
                f_i += 1

            if all_flags:
                idx += 1
                continue

            let err = "Error: unknown option '" + item + "'"
            return make_error_args(parsed_flags, parsed_options, positionals, err)

        # Positional
        append(positionals, item)
        idx += 1

    # Validation: required options
    let opt_val_idx = 0
    while opt_val_idx < len(options):
        let opt = options[opt_val_idx]
        if opt.required and not (opt.name in parsed_options):
            let err = "Error: missing required option '--" + opt.name + "'"
            return make_error_args(parsed_flags, parsed_options, positionals, err)
        opt_val_idx += 1

    # Validation: required positional arguments
    let p_idx = 0
    while p_idx < len(pos_defs):
        let p = pos_defs[p_idx]
        if p.required and p_idx >= len(positionals):
            let err = "Error: missing required argument <" + p.name + ">"
            return make_error_args(parsed_flags, parsed_options, positionals, err)
        p_idx += 1

    return Args{
        flags: parsed_flags,
        options: parsed_options,
        positionals: positionals,
        subcommand: "",
        is_valid: true,
        is_help: false,
        is_version: false,
        error: ""
    }


struct ArgParser:
    name: str
    version: str
    description: str
    flags: list[Flag]
    options: list[Opt]
    positionals: list[PosArg]
    subcommands: list[Subcommand]

    def flag(self, name: str, short: str, help: str) -> ArgParser:
        append(self.flags, Flag{
            name: clean_name(name),
            short: clean_name(short),
            help: help
        })
        return self

    def option(self, name: str, short: str, default_val: str, help: str) -> ArgParser:
        append(self.options, Opt{
            name: clean_name(name),
            short: clean_name(short),
            default_val: default_val,
            help: help,
            required: false
        })
        return self

    def required_option(self, name: str, short: str, help: str) -> ArgParser:
        append(self.options, Opt{
            name: clean_name(name),
            short: clean_name(short),
            default_val: "",
            help: help,
            required: true
        })
        return self

    def arg(self, name: str, help: str, required: bool) -> ArgParser:
        append(self.positionals, PosArg{
            name: name,
            help: help,
            required: required
        })
        return self

    def subcommand(self, name: str, description: str) -> Subcommand:
        let empty_f: list[Flag] = []
        let empty_o: list[Opt] = []
        let empty_p: list[PosArg] = []
        let sub = Subcommand{
            name: name,
            description: description,
            flags: empty_f,
            options: empty_o,
            positionals: empty_p
        }
        append(self.subcommands, sub)
        return sub

    def format_version(self) -> str:
        if self.version != "":
            return self.name + " " + self.version
        return self.name

    def format_help(self) -> str:
        let lines: list[str] = []

        if self.description != "":
            append(lines, self.description)
            append(lines, "")

        let usage = "Usage: " + self.name
        if len(self.flags) > 0 or len(self.options) > 0:
            usage += " [OPTIONS]"
        if len(self.subcommands) > 0:
            usage += " [COMMAND]"
        let p_scan_idx = 0
        while p_scan_idx < len(self.positionals):
            let p = self.positionals[p_scan_idx]
            if p.required:
                usage += " <" + p.name + ">"
            else:
                usage += " [" + p.name + "]"
            p_scan_idx += 1
        append(lines, usage)
        append(lines, "")

        if len(self.subcommands) > 0:
            append(lines, "Commands:")
            let max_w = 0
            let sub_scan_idx = 0
            while sub_scan_idx < len(self.subcommands):
                let s = self.subcommands[sub_scan_idx]
                if len(s.name) > max_w:
                    max_w = len(s.name)
                sub_scan_idx += 1
            sub_scan_idx = 0
            while sub_scan_idx < len(self.subcommands):
                let s = self.subcommands[sub_scan_idx]
                append(lines, "  " + ljust(s.name, max_w + 2, " ") + s.description)
                sub_scan_idx += 1
            append(lines, "")

        if len(self.positionals) > 0:
            append(lines, "Arguments:")
            let max_w = 0
            let p_len_idx = 0
            while p_len_idx < len(self.positionals):
                let p = self.positionals[p_len_idx]
                if len(p.name) > max_w:
                    max_w = len(p.name)
                p_len_idx += 1
            p_len_idx = 0
            while p_len_idx < len(self.positionals):
                let p = self.positionals[p_len_idx]
                let note = p.help
                if not p.required:
                    if note != "":
                        note += " (optional)"
                    else:
                        note = "(optional)"
                append(lines, "  " + ljust(p.name, max_w + 2, " ") + note)
                p_len_idx += 1
            append(lines, "")

        if len(self.options) > 0 or len(self.flags) > 0:
            let left_col: list[str] = []
            let right_col: list[str] = []
            let max_w = 0

            let h_str = "-h, --help"
            append(left_col, h_str)
            append(right_col, "Print help information")
            max_w = len(h_str)

            if self.version != "":
                let v_str = "-V, --version"
                append(left_col, v_str)
                append(right_col, "Print version information")
                if len(v_str) > max_w:
                    max_w = len(v_str)

            let f_scan_idx = 0
            while f_scan_idx < len(self.flags):
                let f = self.flags[f_scan_idx]
                let s = "    --" + f.name
                if f.short != "":
                    s = "-" + f.short + ", --" + f.name
                append(left_col, s)
                append(right_col, f.help)
                if len(s) > max_w:
                    max_w = len(s)
                f_scan_idx += 1

            let opt_scan_idx = 0
            while opt_scan_idx < len(self.options):
                let opt = self.options[opt_scan_idx]
                let s = "    --" + opt.name + " <" + opt.name + ">"
                if opt.short != "":
                    s = "-" + opt.short + ", --" + opt.name + " <" + opt.name + ">"
                append(left_col, s)
                let note = opt.help
                if opt.required:
                    if note != "":
                        note += " (required)"
                    else:
                        note = "(required)"
                elif opt.default_val != "":
                    let def_note = "[default: " + opt.default_val + "]"
                    if note != "":
                        note += " " + def_note
                    else:
                        note = def_note
                append(right_col, note)
                if len(s) > max_w:
                    max_w = len(s)
                opt_scan_idx += 1

            let i = 0
            while i < len(left_col):
                append(lines, "  " + ljust(left_col[i], max_w + 2, " ") + right_col[i])
                i += 1
            append(lines, "")

        return join(lines, "\n")

    def print_help(self):
        print(self.format_help())

    def print_version(self):
        print(self.format_version())

    def parse(self, raw_args: list[str]) -> Args:
        if len(raw_args) > 0 and len(self.subcommands) > 0 and not startswith(raw_args[0], "-"):
            let sub_name = raw_args[0]
            let sub_idx = 0
            while sub_idx < len(self.subcommands):
                let sub = self.subcommands[sub_idx]
                if sub.name == sub_name:
                    let sub_tokens: list[str] = []
                    let i = 1
                    while i < len(raw_args):
                        append(sub_tokens, raw_args[i])
                        i += 1
                    let sub_res = parse_tokens(sub.flags, sub.options, sub.positionals, sub_tokens, self.version)
                    sub_res.subcommand = sub_name
                    return sub_res
                sub_idx += 1

        return parse_tokens(self.flags, self.options, self.positionals, raw_args, self.version)

    def parse_sys(self) -> Args:
        let count = argc()
        let raw_args: list[str] = []
        let idx = 1
        while idx < count:
            append(raw_args, arg(idx))
            idx += 1
        return self.parse(raw_args)


def create_parser(name: str, version: str, description: str) -> ArgParser:
    let empty_f: list[Flag] = []
    let empty_o: list[Opt] = []
    let empty_p: list[PosArg] = []
    let empty_s: list[Subcommand] = []
    return ArgParser{
        name: name,
        version: version,
        description: description,
        flags: empty_f,
        options: empty_o,
        positionals: empty_p,
        subcommands: empty_s
    }
