#!/bin/bash
set -eo pipefail

# 网络延迟一键检测工具 - Interactive Network Latency Tester
# Version: 2.3 - Modular architecture and bounded parallel checks

if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "错误: 此脚本需要 bash 4.0 或更高版本"
    echo "当前版本: $BASH_VERSION"
    echo ""
    echo "macOS用户请安装新版bash:"
    echo "  brew install bash"
    echo "  然后使用新版bash运行: /opt/homebrew/bin/bash latency.sh"
    echo ""
    echo "或者在脚本开头指定新版bash:"
    echo "  #!/opt/homebrew/bin/bash"
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
MODULE_DIR="$SCRIPT_DIR/lib"
REMOTE_MODULE_ROOT=""

fetch_remote_modules() {
    local base_url="${LATENCY_MODULE_BASE_URL:-https://raw.githubusercontent.com/Cd1s/network-latency-tester/main/lib}"
    local module
    local modules=(state.sh bootstrap.sh ui.sh parallel.sh reports.sh network.sh dns.sh menus.sh)

    REMOTE_MODULE_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t latency_modules_XXXXXX)
    MODULE_DIR="$REMOTE_MODULE_ROOT/lib"
    mkdir -p "$MODULE_DIR"

    for module in "${modules[@]}"; do
        if command -v wget >/dev/null 2>&1; then
            wget -qO "$MODULE_DIR/$module" "$base_url/$module" || {
                echo "错误: 无法下载运行模块 $module"
                rm -rf "$REMOTE_MODULE_ROOT"
                exit 1
            }
        elif command -v curl >/dev/null 2>&1; then
            curl -fsSL "$base_url/$module" -o "$MODULE_DIR/$module" || {
                echo "错误: 无法下载运行模块 $module"
                rm -rf "$REMOTE_MODULE_ROOT"
                exit 1
            }
        else
            echo "错误: 当前运行方式需要 wget 或 curl 下载模块"
            rm -rf "$REMOTE_MODULE_ROOT"
            exit 1
        fi
    done
}

if [[ ! -r "$MODULE_DIR/state.sh" ]]; then
    fetch_remote_modules
fi

# shellcheck source=lib/state.sh
source "$MODULE_DIR/state.sh"
if [[ -n "$REMOTE_MODULE_ROOT" ]]; then
    _TEMP_DIRS+=("$REMOTE_MODULE_ROOT")
fi
# shellcheck source=lib/bootstrap.sh
source "$MODULE_DIR/bootstrap.sh"
# shellcheck source=lib/ui.sh
source "$MODULE_DIR/ui.sh"
# shellcheck source=lib/parallel.sh
source "$MODULE_DIR/parallel.sh"
# shellcheck source=lib/reports.sh
source "$MODULE_DIR/reports.sh"
# shellcheck source=lib/network.sh
source "$MODULE_DIR/network.sh"
# shellcheck source=lib/dns.sh
source "$MODULE_DIR/dns.sh"
# shellcheck source=lib/menus.sh
source "$MODULE_DIR/menus.sh"

detect_os
parse_arguments "$@"
main

# 生成输出文件（如果启用且主循环返回）
if [[ "$ENABLE_OUTPUT" == "true" && -n "$OUTPUT_FILE" ]]; then
    generate_output_file "$OUTPUT_FILE" "$OUTPUT_FORMAT"
fi
