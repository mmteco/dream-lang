#!/usr/bin/env fish

# Bootstrap 版本管理器
# 功能：
# 1. bootstrap 成功后保存 stage2 作为历史版本
# 2. 使用历史版本编译新版编译器
# 3. 支持版本切换和回滚

set script_dir (dirname (status --current-filename))
set root_dir (realpath "$script_dir/..")
set history_dir "$root_dir/tmp/bootstrap_history"
set current_link "$root_dir/tmp/stage2_current"

function show_help
    echo "用法: bootstrap_manager <命令>"
    echo ""
    echo "命令:"
    echo "  save <version>     保存当前 stage2 为指定版本"
    echo "  use <version>      使用指定版本作为 stage2"
    echo "  list               列出所有保存的版本"
    echo "  current            显示当前使用的版本"
    echo "  bootstrap          运行完整 bootstrap 并自动保存"
    echo "  compile <input>    使用当前 stage2 编译文件"
    echo "  archive <suffix>   归档当前版本到 ~/Downloads/dream-history/"
end

function save_version
    set version_name $argv[1]
    if test -z "$version_name"
        echo "错误: 请指定版本名称" >&2
        return 1
    end

    if not test -f "$root_dir/tmp/stage2"
        echo "错误: stage2 不存在，先运行 bootstrap" >&2
        return 1
    end

    mkdir -p "$history_dir"
    set version_path "$history_dir/stage2_$version_name"

    cp "$root_dir/tmp/stage2" "$version_path"
    chmod +x "$version_path"

    # 更新 current 链接
    ln -sf "$version_path" "$current_link"

    echo "已保存版本: $version_name"
    echo "路径: $version_path"
end

function use_version
    set version_name $argv[1]
    if test -z "$version_name"
        echo "错误: 请指定版本名称" >&2
        return 1
    end

    set version_path "$history_dir/stage2_$version_name"
    if not test -f "$version_path"
        echo "错误: 版本不存在: $version_name" >&2
        echo "可用版本:" >&2
        list_versions
        return 1
    end

    ln -sf "$version_path" "$current_link"
    echo "已切换到版本: $version_name"
end

function list_versions
    if not test -d "$history_dir"
        echo "暂无保存的版本"
        return 0
    end

    echo "本地版本 (tmp/bootstrap_history/):"
    for version_file in "$history_dir"/stage2_*
        if test -f "$version_file"
            set version_name (basename "$version_file" | string replace 'stage2_' '')
            set is_current ""
            if test -L "$current_link"
                set current_target (realpath "$current_link")
                set this_target (realpath "$version_file")
                if test "$current_target" = "$this_target"
                    set is_current " (当前)"
                end
            end
            # 从文件名解析日期时间
            set date_part (echo "$version_name" | cut -d'_' -f1)
            set time_part (echo "$version_name" | cut -d'_' -f2)
            set formatted_date (echo "$date_part" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
            set formatted_time (echo "$time_part" | sed 's/\(..\)\(..\)\(..\)/\1:\2:\3/')
            echo "  $version_name$is_current - $formatted_date $formatted_time"
        end
    end

    set archive_dir "$HOME/Downloads/dream-history"
    if test -d "$archive_dir"
        set has_archives false
        for version_file in "$archive_dir"/stage2_*
            if test -f "$version_file"
                if not test "$has_archives" = true
                    echo ""
                    echo "归档版本 (~/Downloads/dream-history/):"
                    set has_archives true
                end
                set version_name (basename "$version_file" | string replace 'stage2_' '')
                echo "  $version_name"
            end
        end
    end
end

function show_current
    if not test -L "$current_link"
        echo "未设置当前版本"
        return 1
    end

    set current_target (realpath "$current_link")
    set version_name (basename "$current_target" | string replace 'stage2_' '')
    echo "当前版本: $version_name"
    echo "路径: $current_target"
end

function run_bootstrap
    echo "运行 bootstrap..."
    fish "$script_dir/bootstrap.fish" --skip-stage3
    set bootstrap_status $status

    if test $bootstrap_status -eq 0
        echo ""
        echo "Bootstrap 成功！"

        # 自动生成版本号（时间戳）
        set timestamp (date +%Y%m%d_%H%M%S)
        save_version "$timestamp"

        echo ""
        echo "已自动保存为版本: $timestamp"
    else
        echo ""
        echo "Bootstrap 失败" >&2
        return 1
    end
end

function compile_file
    set input_file $argv[1]
    if test -z "$input_file"
        echo "错误: 请指定输入文件" >&2
        return 1
    end

    if not test -L "$current_link"
        echo "错误: 未设置当前版本，先运行 bootstrap" >&2
        return 1
    end

    set output_file (string replace -r '\.dm$' '' "$input_file")
    "$current_link" build "$input_file" -o "$output_file"
end

function archive_version
    set suffix $argv[1]
    if test -z "$suffix"
        echo "错误: 请指定归档后缀（如版本号）" >&2
        return 1
    end

    if not test -L "$current_link"
        echo "错误: 未设置当前版本，先运行 bootstrap" >&2
        return 1
    end

    set archive_dir "$HOME/Downloads/dream-history"
    mkdir -p "$archive_dir"

    set current_target (realpath "$current_link")
    set archive_name "stage2_$suffix"
    set archive_path "$archive_dir/$archive_name"

    cp "$current_target" "$archive_path"
    chmod +x "$archive_path"

    echo "已归档到: $archive_path"
end

# 主命令分发
set command $argv[1]
switch "$command"
    case save
        save_version $argv[2]
    case use
        use_version $argv[2]
    case list
        list_versions
    case current
        show_current
    case bootstrap
        run_bootstrap
    case compile
        compile_file $argv[2]
    case archive
        archive_version $argv[2]
    case help -h --help ''
        show_help
    case '*'
        echo "错误: 未知命令 '$command'" >&2
        show_help
        exit 1
end
