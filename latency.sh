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

# shellcheck source=lib/state.sh
source "$SCRIPT_DIR/lib/state.sh"
# shellcheck source=lib/bootstrap.sh
source "$SCRIPT_DIR/lib/bootstrap.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/parallel.sh
source "$SCRIPT_DIR/lib/parallel.sh"
# shellcheck source=lib/reports.sh
source "$SCRIPT_DIR/lib/reports.sh"
# shellcheck source=lib/network.sh
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=lib/dns.sh
source "$SCRIPT_DIR/lib/dns.sh"
# shellcheck source=lib/menus.sh
source "$SCRIPT_DIR/lib/menus.sh"

detect_os
parse_arguments "$@"
main

# 生成输出文件（如果启用且主循环返回）
if [[ "$ENABLE_OUTPUT" == "true" && -n "$OUTPUT_FILE" ]]; then
    generate_output_file "$OUTPUT_FILE" "$OUTPUT_FORMAT"
fi
