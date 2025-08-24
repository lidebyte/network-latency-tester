#!/bin/bash
# 网络延迟一键检测工具 - Interactive Network Latency Tester
# Version: 1.0

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 配置变量
PING_COUNT=3

# 基础网站列表（8个）
declare -A BASIC_SITES=(
    ["Google"]="google.com"
    ["GitHub"]="github.com"
    ["Apple"]="apple.com"
    ["Microsoft"]="microsoft.com"
    ["Amazon"]="amazon.com"
    ["Twitter"]="twitter.com"
    ["ChatGPT"]="openai.com"
    ["Steam"]="steampowered.com"
)

# 完整网站列表（20个）
declare -A FULL_SITES=(
    ["Google"]="google.com"
    ["GitHub"]="github.com"
    ["Apple"]="apple.com"
    ["Microsoft"]="microsoft.com"
    ["Amazon"]="amazon.com"
    ["Twitter"]="twitter.com"
    ["ChatGPT"]="openai.com"
    ["Steam"]="steampowered.com"
    ["Netflix"]="netflix.com"
    ["Disney"]="disneyplus.com"
    ["Instagram"]="instagram.com"
    ["Telegram"]="tg.d1ss.eu.org"
    ["Dropbox"]="dropbox.com"
    ["OneDrive"]="onedrive.live.com"
    ["Mega"]="mega.io"
    ["Twitch"]="twitch.tv"
    ["Pornhub"]="pornhub.com"
    ["YouTube"]="youtube.com"
    ["Facebook"]="facebook.com"
    ["TikTok"]="tiktok.com"
)

# 结果数组
declare -a RESULTS=()

# 显示欢迎界面
show_welcome() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║            🚀 ${YELLOW}网络延迟一键检测工具${CYAN}                     ║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║        快速检测您的网络连接到各大网站的延迟情况                 ║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示主菜单
show_menu() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                        🎯 选择测试模式                        │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│                                                             │${NC}"
    echo -e "${BLUE}│  ${GREEN}1${NC} ⚡ 标准测试   ${YELLOW}(8个主要网站，推荐)${NC}                     ${BLUE}│${NC}"
    echo -e "${BLUE}│                                                             │${NC}"
    echo -e "${BLUE}│  ${GREEN}2${NC} 🌐 完整测试   ${YELLOW}(20个网站，全面检测)${NC}                    ${BLUE}│${NC}"
    echo -e "${BLUE}│                                                             │${NC}"
    echo -e "${BLUE}│  ${RED}0${NC} 🚪 退出程序                                       ${BLUE}│${NC}"
    echo -e "${BLUE}│                                                             │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# 测试TCP连接延迟
test_tcp_latency() {
    local host=$1
    local port=$2
    local count=${3:-3}
    
    local total_time=0
    local successful_connects=0
    
    for ((i=1; i<=count; i++)); do
        local start_time=$(date +%s%N)
        if timeout 5 bash -c "exec 3<>/dev/tcp/$host/$port && exec 3<&- && exec 3>&-" 2>/dev/null; then
            local end_time=$(date +%s%N)
            local connect_time=$(( (end_time - start_time) / 1000000 ))
            total_time=$((total_time + connect_time))
            ((successful_connects++))
        fi
    done
    
    if [ $successful_connects -gt 0 ]; then
        echo $((total_time / successful_connects))
    else
        echo "999999"
    fi
}

# 测试HTTP连接延迟
test_http_latency() {
    local host=$1
    local count=${2:-3}
    
    local total_time=0
    local successful_requests=0
    
    for ((i=1; i<=count; i++)); do
        local connect_time=$(timeout 8 curl -o /dev/null -s -w '%{time_connect}' --max-time 6 --connect-timeout 4 "https://$host" 2>/dev/null || echo "999")
        
        if [[ "$connect_time" =~ ^[0-9]+\.?[0-9]*$ ]] && [ "$(echo "$connect_time < 10" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
            local time_ms=$(echo "$connect_time * 1000" | bc -l 2>/dev/null | cut -d'.' -f1)
            total_time=$((total_time + time_ms))
            ((successful_requests++))
        fi
    done
    
    if [ $successful_requests -gt 0 ]; then
        echo $((total_time / successful_requests))
    else
        echo "999999"
    fi
}

# 测试单个网站延迟
test_site_latency() {
    local host=$1
    local service=$2
    
    echo -n -e "🔍 测试 ${CYAN}$service${NC} ($host)... "
    
    local ping_result=""
    local ping_ms=""
    local status=""
    local latency_ms=""
    
    # 首先尝试ping测试
    ping_result=$(timeout 10 ping -c $PING_COUNT -W 3 "$host" 2>/dev/null | grep 'rtt min/avg/max/mdev' || true)
    
    if [ ! -z "$ping_result" ]; then
        ping_ms=$(echo "$ping_result" | cut -d'/' -f5 | cut -d' ' -f1)
        
        if [[ "$ping_ms" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            latency_ms="$ping_ms"
        fi
    fi
    
    # 如果ping失败，尝试其他方法
    if [ -z "$latency_ms" ]; then
        # 对特定网站使用特定端口进行TCP测试
        case "$service" in
            "Telegram")
                # Telegram使用443端口
                local tcp_latency=$(test_tcp_latency "$host" 443 2)
                if [ "$tcp_latency" != "999999" ]; then
                    latency_ms="$tcp_latency.0"
                fi
                ;;
            "Netflix")
                # Netflix使用特殊HTTP连接测试
                local connect_time=$(timeout 8 curl -o /dev/null -s -w '%{time_connect}' --max-time 6 --connect-timeout 4 "https://$host" 2>/dev/null || echo "999")
                if [[ "$connect_time" =~ ^[0-9]+\.?[0-9]*$ ]] && [ "$(echo "$connect_time < 10" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
                    local time_ms=$(echo "$connect_time * 1000" | bc -l 2>/dev/null | cut -d'.' -f1)
                    latency_ms="$time_ms.0"
                fi
                ;;
            *)
                # 其他网站尝试HTTP连接测试
                local http_latency=$(test_http_latency "$host" 2)
                if [ "$http_latency" != "999999" ]; then
                    latency_ms="$http_latency.0"
                fi
                ;;
        esac
    fi
    
    # 根据延迟结果显示状态
    if [ ! -z "$latency_ms" ] && [[ "$latency_ms" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        local latency_int=$(echo "$latency_ms" | cut -d'.' -f1)
        
        if [ "$latency_int" -lt 50 ]; then
            status="优秀"
            echo -e "${GREEN}${latency_ms}ms 🟢 优秀${NC}"
        elif [ "$latency_int" -lt 150 ]; then
            status="良好"
            echo -e "${YELLOW}${latency_ms}ms 🟡 良好${NC}"
        elif [ "$latency_int" -lt 500 ]; then
            status="较差"
            echo -e "${RED}${latency_ms}ms 🔴 较差${NC}"
        else
            status="很差"
            echo -e "${RED}${latency_ms}ms 🔴 很差${NC}"
        fi
        
        RESULTS+=("$service|$host|${latency_ms}ms|$status")
    else
        # 最后尝试简单连通性测试
        if timeout 5 curl -s --connect-timeout 3 "$host" >/dev/null 2>&1; then
            status="连通但测不出延迟"
            echo -e "${YELLOW}连通(测不出延迟) 🟡${NC}"
            RESULTS+=("$service|$host|连通|连通但测不出延迟")
        else
            status="失败"
            echo -e "${RED}超时/失败 ❌${NC}"
            RESULTS+=("$service|$host|超时|失败")
        fi
    fi
}

# 执行测试
run_test() {
    local mode=$1
    local site_count=""
    
    clear
    show_welcome
    
    # 选择要测试的网站
    declare -A SITES=()
    if [ "$mode" = "1" ]; then
        for key in "${!BASIC_SITES[@]}"; do
            SITES["$key"]="${BASIC_SITES[$key]}"
        done
        site_count="8"
        echo -e "${CYAN}🎯 开始标准测试 (8个主要网站)${NC}"
    else
        for key in "${!FULL_SITES[@]}"; do
            SITES["$key"]="${FULL_SITES[$key]}"
        done
        site_count="20"
        echo -e "${CYAN}🌐 开始完整测试 (20个网站)${NC}"
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "测试参数: ${YELLOW}${site_count}个网站${NC} | Ping次数: ${YELLOW}${PING_COUNT}${NC}"
    echo ""
    
    # 重置结果数组
    RESULTS=()
    local start_time=$(date +%s)
    
    # 执行测试
    for service in "${!SITES[@]}"; do
        host="${SITES[$service]}"
        test_site_latency "$host" "$service"
    done
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    # 显示结果
    show_results "$total_time"
}

# 显示测试结果
show_results() {
    local total_time=$1
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 测试完成！${NC} 总时间: ${YELLOW}${total_time}秒${NC}"
    echo ""
    
    # 生成表格
    echo -e "${CYAN}📋 延迟测试结果表格:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    printf "%-3s %-12s %-25s %-12s %-8s\n" "排名" "服务" "域名" "延迟" "状态"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    
    # 排序结果
    declare -a sorted_results=()
    declare -a failed_results=()
    
    for result in "${RESULTS[@]}"; do
        if [[ "$result" == *"超时"* || "$result" == *"失败"* ]]; then
            failed_results+=("$result")
        else
            sorted_results+=("$result")
        fi
    done
    
    # 按延迟排序成功的结果
    IFS=$'\n' sorted_results=($(printf '%s\n' "${sorted_results[@]}" | sort -t'|' -k3 -n))
    
    # 显示成功的结果
    local rank=1
    for result in "${sorted_results[@]}"; do
        IFS='|' read -r service host latency status <<< "$result"
        
        local status_colored=""
        case "$status" in
            "优秀") status_colored="${GREEN}🟢 $status${NC}" ;;
            "良好") status_colored="${YELLOW}🟡 $status${NC}" ;;
            "较差") status_colored="${RED}🔴 $status${NC}" ;;
            "很差") status_colored="${RED}💀 $status${NC}" ;;
            *) status_colored="$status" ;;
        esac
        
        printf "%2d. %-10s %-25s %-12s " "$rank" "$service" "$host" "$latency"
        echo -e "$status_colored"
        ((rank++))
    done
    
    # 显示失败的结果
    for result in "${failed_results[@]}"; do
        IFS='|' read -r service host latency status <<< "$result"
        printf "%2d. %-10s %-25s %-12s ${RED}❌ $status${NC}\n" "$rank" "$service" "$host" "$latency"
        ((rank++))
    done
    
    # 统计信息
    local excellent_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "优秀" || true)
    local good_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "良好" || true)
    local poor_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "较差" || true)
    local very_poor_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "很差" || true)
    local failed_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "失败" || true)
    
    echo ""
    echo -e "${CYAN}📈 统计摘要:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "🟢 优秀 (< 50ms):     ${GREEN}$excellent_count${NC} 个服务"
    echo -e "🟡 良好 (50-150ms):   ${YELLOW}$good_count${NC} 个服务"
    echo -e "🔴 较差 (150-500ms):  ${RED}$poor_count${NC} 个服务"
    echo -e "💀 很差 (> 500ms):    ${RED}$very_poor_count${NC} 个服务"
    echo -e "❌ 失败:             ${RED}$failed_count${NC} 个服务"
    
    # 网络质量评估
    local total_tested=$((excellent_count + good_count + poor_count + very_poor_count + failed_count))
    if [ $total_tested -gt 0 ]; then
        local success_rate=$(((excellent_count + good_count + poor_count + very_poor_count) * 100 / total_tested))
        echo ""
        if [ $success_rate -gt 80 ] && [ $excellent_count -gt $good_count ]; then
            echo -e "🌟 ${GREEN}网络状况: 优秀${NC} (成功率: ${success_rate}%)"
        elif [ $success_rate -gt 60 ]; then
            echo -e "👍 ${YELLOW}网络状况: 良好${NC} (成功率: ${success_rate}%)"
        else
            echo -e "⚠️  ${RED}网络状况: 一般${NC} (成功率: ${success_rate}%)"
        fi
    fi
    
    # 保存结果
    local output_file="latency_results_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "# 网络延迟测试结果 - $(date)"
        echo "# 服务|域名|延迟|状态"
        printf '%s\n' "${RESULTS[@]}"
    } > "$output_file"
    
    echo ""
    echo -e "💾 结果已保存到: ${GREEN}$output_file${NC}"
    echo ""
    echo -e "${CYAN}💡 延迟等级说明:${NC}"
    echo -e "  ${GREEN}🟢 优秀${NC} (< 50ms)     - 适合游戏、视频通话"
    echo -e "  ${YELLOW}🟡 良好${NC} (50-150ms)   - 适合网页浏览、视频"
    echo -e "  ${RED}🔴 较差${NC} (150-500ms)  - 基础使用，可能影响体验"
    echo -e "  ${RED}💀 很差${NC} (> 500ms)    - 网络质量很差"
    
    echo ""
    echo -n -e "${YELLOW}按 Enter 键返回主菜单...${NC}"
    read -r
}

# 检查并安装依赖
check_dependencies() {
    echo -e "${CYAN}🔧 检查系统依赖...${NC}"
    
    local missing_deps=()
    local install_cmd=""
    
    # 检测系统类型
    if command -v apt-get >/dev/null 2>&1; then
        install_cmd="apt-get"
    elif command -v yum >/dev/null 2>&1; then
        install_cmd="yum"
    elif command -v apk >/dev/null 2>&1; then
        install_cmd="apk"
    elif command -v brew >/dev/null 2>&1; then
        install_cmd="brew"
    fi
    
    # 检查必要的依赖
    if ! command -v ping >/dev/null 2>&1; then
        missing_deps+=("ping")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    # 如果有缺失的依赖，尝试自动安装
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${YELLOW}⚠️  发现缺失依赖: ${missing_deps[*]}${NC}"
        
        if [ -n "$install_cmd" ] && [ "$(id -u)" = "0" ]; then
            echo -e "${CYAN}🚀 正在自动安装依赖...${NC}"
            
            case $install_cmd in
                "apt-get")
                    apt-get update -qq >/dev/null 2>&1
                    if echo "${missing_deps[*]}" | grep -q "ping"; then
                        apt-get install -y iputils-ping >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "curl"; then
                        apt-get install -y curl >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "bc"; then
                        apt-get install -y bc >/dev/null 2>&1
                    fi
                    ;;
                "yum")
                    if echo "${missing_deps[*]}" | grep -q "ping"; then
                        yum install -y iputils >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "curl"; then
                        yum install -y curl >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "bc"; then
                        yum install -y bc >/dev/null 2>&1
                    fi
                    ;;
                "apk")
                    apk update >/dev/null 2>&1
                    if echo "${missing_deps[*]}" | grep -q "ping"; then
                        apk add iputils >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "curl"; then
                        apk add curl >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "bc"; then
                        apk add bc >/dev/null 2>&1
                    fi
                    ;;
                "brew")
                    if echo "${missing_deps[*]}" | grep -q "curl"; then
                        brew install curl >/dev/null 2>&1
                    fi
                    if echo "${missing_deps[*]}" | grep -q "bc"; then
                        brew install bc >/dev/null 2>&1
                    fi
                    ;;
            esac
            
            # 再次检查安装结果
            local still_missing=()
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "ping")
                        if ! command -v ping >/dev/null 2>&1; then
                            still_missing+=("ping")
                        fi
                        ;;
                    "curl")
                        if ! command -v curl >/dev/null 2>&1; then
                            still_missing+=("curl")
                        fi
                        ;;
                    "bc")
                        if ! command -v bc >/dev/null 2>&1; then
                            still_missing+=("bc")
                        fi
                        ;;
                esac
            done
            
            if [ ${#still_missing[@]} -eq 0 ]; then
                echo -e "${GREEN}✅ 所有依赖安装成功！${NC}"
            else
                echo -e "${RED}❌ 部分依赖安装失败: ${still_missing[*]}${NC}"
                show_manual_install_instructions
                exit 1
            fi
            
        else
            echo -e "${RED}❌ 无法自动安装依赖${NC}"
            if [ "$(id -u)" != "0" ]; then
                echo -e "${YELLOW}💡 提示: 请使用 root 权限运行脚本以自动安装依赖${NC}"
            fi
            show_manual_install_instructions
            exit 1
        fi
    else
        echo -e "${GREEN}✅ 所有依赖已安装${NC}"
    fi
    
    echo ""
}

# 显示手动安装说明
show_manual_install_instructions() {
    echo ""
    echo -e "${CYAN}📝 手动安装说明:${NC}"
    echo ""
    echo "🐧 Ubuntu/Debian:"
    echo "   sudo apt update && sudo apt install curl iputils-ping bc"
    echo ""
    echo "🎩 CentOS/RHEL/Fedora:"
    echo "   sudo yum install curl iputils bc"
    echo "   # 或者: sudo dnf install curl iputils bc"
    echo ""
    echo "🏔️  Alpine Linux:"
    echo "   sudo apk update && sudo apk add curl iputils bc"
    echo ""
    echo "🍎 macOS:"
    echo "   brew install curl bc"
    echo "   # ping 通常已预装"
    echo ""
}

# 主循环
main() {
    # 检查依赖
    check_dependencies
    
    while true; do
        show_welcome
        show_menu
        
        # 读取用户输入，确保等待输入
        echo -n -e "${YELLOW}请选择 (0-2): ${NC}"
        read -r choice
        
        # 处理空输入
        if [ -z "$choice" ]; then
            continue
        fi
        
        case $choice in
            1)
                run_test "1"
                ;;
            2)
                run_test "2"
                ;;
            0)
                echo ""
                echo -e "${GREEN}👋 感谢使用网络延迟检测工具！${NC}"
                echo -e "${CYAN}🌟 项目地址: https://github.com/Cd1s/network-latency-tester${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 无效选择，请输入 0、1 或 2${NC}"
                echo -n -e "${YELLOW}按 Enter 键继续...${NC}"
                read -r
                ;;
        esac
    done
}

# 运行主程序
main
