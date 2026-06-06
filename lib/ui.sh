# shellcheck shell=bash
# Terminal UI helpers.

ui_width() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    if [[ ! "$cols" =~ ^[0-9]+$ ]] || [[ $cols -lt 60 ]]; then
        cols=80
    fi
    echo "$cols"
}

ui_line() {
    local char=${1:-"─"}
    local width=${2:-$(ui_width)}
    local line=""
    local i
    for ((i=0; i<width; i++)); do
        line+="$char"
    done
    printf '%s\n' "$line"
}

ui_header() {
    local title="$1"
    echo ""
    echo -e "${BLUE}$(ui_line "═" 63)${NC}"
    echo -e "${CYAN}${title}${NC}"
    echo -e "${BLUE}$(ui_line "═" 63)${NC}"
}

ui_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}${title}${NC}"
    echo -e "${BLUE}$(ui_line "─" 63)${NC}"
}

ui_notice() {
    local level="$1"
    local message="$2"
    case "$level" in
        ok) echo -e "${GREEN}✓ ${message}${NC}" ;;
        warn) echo -e "${YELLOW}! ${message}${NC}" ;;
        error) echo -e "${RED}✗ ${message}${NC}" ;;
        *) echo -e "${CYAN}${message}${NC}" ;;
    esac
}

ui_prompt() {
    local message="$1"
    echo -n -e "${YELLOW}${message}${NC}"
}

ui_saved_file() {
    local path="$1"
    ui_notice ok "结果已保存到: $path"
}

ui_output_disabled() {
    ui_notice warn "文件输出已禁用，本次不会写入报告文件"
}

ui_html_view_hint() {
    local path="$1"

    if command -v explorer.exe >/dev/null 2>&1; then
        ui_notice info "HTML查看: explorer.exe \"$(pwd)/$path\""
    elif command -v open >/dev/null 2>&1; then
        ui_notice info "HTML查看: open \"$path\""
    elif command -v xdg-open >/dev/null 2>&1; then
        ui_notice info "HTML查看: xdg-open \"$path\""
    else
        ui_notice info "HTML查看: 在浏览器中打开 $path"
    fi
}

ui_menu_item() {
    local number="$1"
    local label="$2"
    local state="${3:-}"
    if [[ -n "$state" ]]; then
        format_row "${number}:4:right" "${label}:34:left" "${state}:16:left"
    else
        format_row "${number}:4:right" "${label}:34:left"
    fi
}

ui_progress() {
    local label="$1"
    local done="$2"
    local total="$3"
    printf '\r%s %s/%s' "$label" "$done" "$total"
    if [[ "$done" == "$total" ]]; then
        printf '\n'
    fi
}

ui_table_rule() {
    echo -e "${BLUE}$(ui_line "─" 91)${NC}"
}

ui_status() {
    local status="$1"
    case "$status" in
        优秀|excellent) echo -e "${GREEN}✓ 优秀${NC}" ;;
        良好|good) echo -e "${YELLOW}◆ 良好${NC}" ;;
        一般|average) echo -e "${PURPLE}~ 一般${NC}" ;;
        较差|poor) echo -e "${RED}▲ 较差${NC}" ;;
        很差|bad) echo -e "${RED}✗ 很差${NC}" ;;
        失败|failed|超时|timeout) echo -e "${RED}✗ 失败${NC}" ;;
        *) echo "$status" ;;
    esac
}

display_width() {
    local str="$1"
    if command -v python3 >/dev/null 2>&1; then
        STR="$str" python3 -c 'import os; s=os.environ["STR"]; print(sum(2 if ord(c) > 127 else 1 for c in s))'
    else
        # 简单估算：中文字符数*2 + 其他字符数
        local len=${#str}
        local width=0
        for ((i=0; i<len; i++)); do
            local byte="${str:$i:1}"
            if [[ -n "$byte" ]] && [[ $(printf '%d' "'$byte" 2>/dev/null) -gt 127 ]]; then
                width=$((width + 2))
            else
                width=$((width + 1))
            fi
        done
        echo "$width"
    fi
}

truncate_display() {
    local content="$1"
    local width="$2"
    local max=$((width - 3))

    if [[ $max -lt 1 ]]; then
        echo "$content"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        CONTENT="$content" WIDTH="$width" python3 -c '
import os
s = os.environ["CONTENT"]
w = int(os.environ["WIDTH"])
result = ""
cur = 0
for c in s:
    cw = 2 if ord(c) > 127 else 1
    if cur + cw > w - 3:
        break
    result += c
    cur += cw
print(result + "...")
'
    else
        echo "${content:0:max}..."
    fi
}

# 统一的格式化函数 - 支持固定列宽和对齐
# 用法: format_row "col1:width:align" "col2:width:align" ...
# align: left/right/center

format_row() {
    local output=""
    for col_spec in "$@"; do
        IFS=':' read -r content width align <<< "$col_spec"
        
        # 默认左对齐
        if [[ -z "$align" ]]; then
            align="left"
        fi
        
        # 去除ANSI颜色代码计算实际长度
        local clean_content
        local actual_width
        clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
        actual_width=$(display_width "$clean_content")
        local padding=$((width - actual_width))
        
        # 如果内容过长，按显示宽度截断（中文不截中间）
        if [[ $padding -lt 0 ]]; then
            clean_content=$(truncate_display "$clean_content" "$width")
            content="$clean_content"
            padding=0
        fi
        
        # 根据对齐方式输出
        case "$align" in
            right)
                output+="$(printf "%*s" $padding "")$content "
                ;;
            center)
                local left_pad=$((padding / 2))
                local right_pad=$((padding - left_pad))
                output+="$(printf "%*s" $left_pad "")$content$(printf "%*s" $right_pad "") "
                ;;
            *)  # left
                output+="$content$(printf "%*s" $padding "") "
                ;;
        esac
    done
    printf '%b\n' "$output"
}
show_welcome() {
    command clear 2>/dev/null || true
    echo ""
    ui_header "网络延迟一键检测工具"
    echo -e "${BLUE}快速检测您的网络连接到各大网站的延迟情况${NC}"
}

# 显示主菜单

show_menu() {
    local output_state="${YELLOW}[已禁用]${NC}"
    if [[ "$ENABLE_OUTPUT" == "true" ]]; then
        output_state="${GREEN}[已启用]${NC}"
    fi

    ui_section "选择测试模式"
    ui_menu_item "${GREEN}1${NC}" "Ping/真连接测试"
    ui_menu_item "${GREEN}2${NC}" "DNS测试"
    ui_menu_item "${GREEN}3${NC}" "综合测试"
    ui_menu_item "${GREEN}4${NC}" "IPv4/IPv6优先设置"
    ui_menu_item "${GREEN}5${NC}" "DNS解析设置"
    ui_menu_item "${GREEN}6${NC}" "结果文件输出设置" "$output_state"
    ui_menu_item "${RED}0${NC}" "退出程序"
    echo ""
}

# 测试TCP连接延迟（nc 优先，无 nc 时降级）
