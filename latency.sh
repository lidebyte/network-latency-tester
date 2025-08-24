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
    ["Telegram"]="telegram.org"
    ["Dropbox"]="dropbox.com"
    ["OneDrive"]="onedrive.live.com"
    ["Mega"]="mega.nz"
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
    echo -n -e "${YELLOW}请选择 (0-2): ${NC}"
}

# 测试单个网站延迟
test_site_latency() {
    local host=$1
    local service=$2
    
    echo -n -e "🔍 测试 ${CYAN}$service${NC} ($host)... "
    
    local ping_result=""
    local ping_ms=""
    local status=""
    
    # 执行ping测试
    ping_result=$(timeout 10 ping -c $PING_COUNT -W 3 "$host" 2>/dev/null | grep 'rtt min/avg/max/mdev' || true)
    
    if [ ! -z "$ping_result" ]; then
        ping_ms=$(echo "$ping_result" | cut -d'/' -f5 | cut -d' ' -f1)
        
        if [[ "$ping_ms" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            local ping_int=$(echo "$ping_ms" | cut -d'.' -f1)
            
            if [ "$ping_int" -lt 50 ]; then
                status="优秀"
                echo -e "${GREEN}${ping_ms}ms 🟢 优秀${NC}"
            elif [ "$ping_int" -lt 150 ]; then
                status="良好"
                echo -e "${YELLOW}${ping_ms}ms 🟡 良好${NC}"
            else
                status="较差"
                echo -e "${RED}${ping_ms}ms 🔴 较差${NC}"
            fi
            
            RESULTS+=("$service|$host|${ping_ms}ms|$status")
        else
            status="失败"
            echo -e "${RED}解析失败 ❌${NC}"
            RESULTS+=("$service|$host|超时|失败")
        fi
    else
        # 如果ping失败，尝试curl测试连通性
        if timeout 5 curl -s --connect-timeout 3 "$host" >/dev/null 2>&1; then
            status="连通但无ping"
            echo -e "${YELLOW}连通(无ping) 🟡${NC}"
            RESULTS+=("$service|$host|连通|连通但无ping")
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
    local failed_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "失败" || true)
    
    echo ""
    echo -e "${CYAN}📈 统计摘要:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "🟢 优秀 (< 50ms):     ${GREEN}$excellent_count${NC} 个服务"
    echo -e "🟡 良好 (50-150ms):   ${YELLOW}$good_count${NC} 个服务"
    echo -e "🔴 较差 (> 150ms):    ${RED}$poor_count${NC} 个服务"
    echo -e "❌ 失败:             ${RED}$failed_count${NC} 个服务"
    
    # 网络质量评估
    local total_tested=$((excellent_count + good_count + poor_count + failed_count))
    if [ $total_tested -gt 0 ]; then
        local success_rate=$(((excellent_count + good_count) * 100 / total_tested))
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
    echo -e "  ${GREEN}🟢 优秀${NC} (< 50ms)   - 适合游戏、视频通话"
    echo -e "  ${YELLOW}🟡 良好${NC} (50-150ms) - 适合网页浏览、视频"
    echo -e "  ${RED}🔴 较差${NC} (> 150ms)  - 基础使用，可能影响体验"
    
    echo ""
    echo -n -e "${YELLOW}按 Enter 键返回主菜单...${NC}"
    read -r
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v ping >/dev/null 2>&1; then
        missing_deps+=("ping")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}❌ 错误: 缺少必要的依赖:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        echo ""
        echo "请先安装缺少的依赖:"
        echo "Ubuntu/Debian: sudo apt update && sudo apt install curl iputils-ping"
        echo "CentOS/RHEL:   sudo yum install curl iputils"
        echo "macOS:         已自带所需工具"
        exit 1
    fi
}

# 主循环
main() {
    # 检查依赖
    check_dependencies
    
    while true; do
        show_welcome
        show_menu
        
        # 读取用户输入，确保等待输入
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
