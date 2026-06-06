# shellcheck shell=bash
test_dns_resolution_probe() {
    local domain="$1"
    local dns_name="$2"
    local dns_server="$3"
    local start_time end_time resolution_time lookup_ok=1

    start_time=$(get_timestamp_ms)
    if [[ "$dns_server" == "system" ]]; then
        nslookup "$domain" >/dev/null 2>&1 && lookup_ok=0 || lookup_ok=$?
    else
        nslookup "$domain" "$dns_server" >/dev/null 2>&1 && lookup_ok=0 || lookup_ok=$?
    fi
    end_time=$(get_timestamp_ms)
    resolution_time=$((end_time - start_time))

    if [[ $lookup_ok -eq 0 ]]; then
        printf '%s|%s|%s|ok\n' "$dns_name" "$dns_server" "$resolution_time"
    else
        printf '%s|%s|999|failed\n' "$dns_name" "$dns_server"
    fi
}

dns_detailed_resolution_worker() {
    local item="$1"
    local out="$2"
    local log="$3"
    local order dns_name dns_server domains_joined
    IFS='|' read -r order dns_name dns_server domains_joined <<< "$item"

    {
        local total_time=0
        local successful_tests=0
        local failed_tests=0
        local domain probe_name probe_server resolution_time probe_status
        local -a domains=()
        IFS=',' read -r -a domains <<< "$domains_joined"

        for domain in "${domains[@]}"; do
            [[ -z "$domain" ]] && continue
            IFS='|' read -r probe_name probe_server resolution_time probe_status < <(test_dns_resolution_probe "$domain" "$dns_name" "$dns_server")
            if [[ "$probe_status" == "ok" && "$resolution_time" =~ ^[0-9]+$ ]]; then
                total_time=$((total_time + resolution_time))
                ((++successful_tests))
            else
                ((++failed_tests))
            fi
        done

        if [[ $successful_tests -gt 0 ]]; then
            local avg_time status
            avg_time=$((total_time / successful_tests))
            status=$(dns_status_from_ms "$avg_time")
            printf '%s|%s|%s|%s|%s|%s|%s\n' "$order" "$dns_name" "$dns_server" "$avg_time" "$status" "$successful_tests" "$failed_tests" > "$out"
        else
            printf '%s|%s|%s|999|失败|0|%s\n' "$order" "$dns_name" "$dns_server" "$failed_tests" > "$out"
        fi
    } 2>"$log"
}

collect_parallel_dns_detailed_results() {
    local domains_joined="$1"
    local jobs=()
    local order=0
    local dns_name

    while IFS= read -r dns_name; do
        [[ -z "$dns_name" ]] && continue
        ((++order))
        jobs+=("$order|$dns_name|${DNS_SERVERS[$dns_name]}|$domains_joined")
    done < <(printf '%s\n' "${!DNS_SERVERS[@]}" | LC_ALL=C sort)

    DNS_RESULTS=()
    parallel_run_records dns_detailed_resolution_worker "详细DNS解析测试" "${jobs[@]}"

    local ordered_records=()
    local i
    for i in "${!jobs[@]}"; do
        local job="${jobs[$i]}"
        local out="${PARALLEL_OUTPUT_FILES[$i]:-}"
        local job_order job_name job_server job_domains
        IFS='|' read -r job_order job_name job_server job_domains <<< "$job"

        if [[ -n "$out" && -s "$out" ]]; then
            local line
            line=$(head -n1 "$out")
            if [[ "$line" == "$job_order|"* ]]; then
                ordered_records+=("$line")
            else
                ordered_records+=("$job_order|$job_name|$job_server|999|失败|0|0")
            fi
        else
            ordered_records+=("$job_order|$job_name|$job_server|999|失败|0|0")
        fi
    done

    local record
    while IFS= read -r record; do
        [[ -z "$record" ]] && continue
        local _order dns_name dns_server resolution_time status successful_tests failed_tests
        IFS='|' read -r _order dns_name dns_server resolution_time status successful_tests failed_tests <<< "$record"
        DNS_RESULTS+=("$dns_name|$dns_server|$resolution_time|$status")
    done < <(printf '%s\n' "${ordered_records[@]}" | LC_ALL=C sort -t'|' -k1,1n)
}

# 测试DNS服务器网络延迟

dns_latency_status_record() {
    local dns_name="$1"
    local ip="$2"
    local avg="$3"
    local loss="$4"

    if [[ -n "$avg" && -n "$loss" && "$avg" =~ ^[0-9]+\.?[0-9]*$ && "$loss" =~ ^[0-9]+$ ]]; then
        local status score
        local latency_int=${avg%.*}
        if [[ "$loss" -gt 5 ]]; then
            status="较差"
            score=1000
        elif [[ "$latency_int" -lt 30 ]]; then
            status="优秀"
            score=$((latency_int + loss * 10))
        elif [[ "$latency_int" -lt 60 ]]; then
            status="良好"
            score=$((latency_int + loss * 10))
        elif [[ "$latency_int" -lt 120 ]]; then
            status="一般"
            score=$((latency_int + loss * 10))
        else
            status="较差"
            score=$((latency_int + loss * 10))
        fi
        printf '%s|%s|%s|%sms|%s%%|%s\n' "$score" "$dns_name" "$ip" "$avg" "$loss" "$status"
    else
        printf '9999|%s|%s|解析失败|100%%|失败\n' "$dns_name" "$ip"
    fi
}

dns_latency_record_worker() {
    local item="$1"
    local out="$2"
    local log="$3"
    local order dns_name ip
    IFS='|' read -r order dns_name ip <<< "$item"

    {
        local result avg="" loss=""
        if command -v fping >/dev/null 2>&1; then
            result=$(fping -c 10 -t 2000 -q "$ip" 2>&1 || true)
            if [[ -n "$result" ]]; then
                if echo "$result" | grep -q "min/avg/max"; then
                    avg=$(echo "$result" | sed -n 's/.*min\/avg\/max = [0-9.]*\/\([0-9.]*\)\/.*/\1/p')
                    loss=$(echo "$result" | sed -n 's/.*xmt\/rcv\/%loss = [0-9]*\/[0-9]*\/\([0-9]*\)%.*/\1/p')
                else
                    avg=$(echo "$result" | sed -n 's/.*avg\/max = [0-9.]*\/[0-9.]*\/\([0-9.]*\).*/\1/p')
                    loss=$(echo "$result" | sed -n 's/.*loss = \([0-9]*\)%.*/\1/p')
                fi
            fi
        else
            local timeout_cmd
            timeout_cmd=$(get_timeout_cmd)
            if [[ -n "$timeout_cmd" ]]; then
                result=$($timeout_cmd 12 ping -c 4 -W 2 "$ip" 2>/dev/null || true)
            else
                result=$(ping -c 4 -W 2 "$ip" 2>/dev/null || true)
            fi
            if [[ -n "$result" ]]; then
                if [[ "$OS_TYPE" == "macos" ]]; then
                    avg=$(echo "$result" | grep 'round-trip' | cut -d'=' -f2 | cut -d'/' -f2 2>/dev/null || echo "")
                else
                    avg=$(echo "$result" | grep 'rtt min/avg/max/mdev' | cut -d'/' -f5 | cut -d' ' -f1 2>/dev/null || echo "")
                fi
                loss=$(echo "$result" | grep -o '[0-9]*% packet loss' | sed 's/% packet loss//' 2>/dev/null || echo "")
            fi
        fi

        printf '%s|' "$order" > "$out"
        dns_latency_status_record "$dns_name" "$ip" "$avg" "$loss" >> "$out"
    } 2>"$log" || {
        printf '%s|9999|%s|%s|解析失败|100%%|失败\n' "$order" "$dns_name" "$ip" > "$out"
    }
}

test_dns_servers_latency() {
    local jobs=()
    local order=0
    local dns_name

    while IFS= read -r dns_name; do
        [[ -z "$dns_name" ]] && continue
        if [[ "${DNS_SERVERS[$dns_name]}" != "system" ]]; then
            ((++order))
            jobs+=("$order|$dns_name|${DNS_SERVERS[$dns_name]}")
        fi
    done < <(printf '%s\n' "${!DNS_SERVERS[@]}" | LC_ALL=C sort)

    echo -e "${YELLOW}正在测试DNS服务器网络延迟...${NC}"
    echo ""

    parallel_run_records dns_latency_record_worker "DNS服务器延迟测试" "${jobs[@]}"

    declare -a dns_latency_results=()
    local i
    for i in "${!jobs[@]}"; do
        local job="${jobs[$i]}"
        local out="${PARALLEL_OUTPUT_FILES[$i]:-}"
        local job_order job_name job_ip
        IFS='|' read -r job_order job_name job_ip <<< "$job"
        if [[ -n "$out" && -s "$out" ]]; then
            local line
            line=$(head -n1 "$out")
            if [[ "$line" == "$job_order|"* ]]; then
                dns_latency_results+=("${line#*|}")
            else
                dns_latency_results+=("9999|$job_name|$job_ip|解析失败|100%|失败")
            fi
        else
            dns_latency_results+=("9999|$job_name|$job_ip|解析失败|100%|失败")
        fi
    done

    echo ""
    local sorted_results=()
    IFS=$'\n' sorted_results=($(printf '%s\n' "${dns_latency_results[@]}" | sort -t'|' -k1 -n))
    local rank=1
    local result
    for result in "${sorted_results[@]}"; do
        IFS='|' read -r score dns_name ip latency loss status <<< "$result"
        format_row "${rank}.:4:right" "${dns_name}:14:left" "${ip}:20:left" "${latency}:10:right" "${status}:10:left"
        ((++rank))
    done

    echo ""
    ui_notice ok "DNS服务器延迟测试完成"
    echo ""
}

dns_status_from_ms() {
    local resolution_time="$1"

    if [[ ! "$resolution_time" =~ ^[0-9]+$ ]]; then
        echo "失败"
    elif [[ "$resolution_time" -lt 50 ]]; then
        echo "优秀"
    elif [[ "$resolution_time" -lt 100 ]]; then
        echo "良好"
    elif [[ "$resolution_time" -lt 200 ]]; then
        echo "一般"
    else
        echo "较差"
    fi
}

dns_resolution_record_worker() {
    local item="$1"
    local out="$2"
    local log="$3"
    local order dns_name dns_server domain
    IFS='|' read -r order dns_name dns_server domain <<< "$item"

    {
        local start_time end_time resolution_time lookup_ok=1
        start_time=$(get_timestamp_ms)
        if [[ "$dns_server" == "system" ]]; then
            nslookup "$domain" >/dev/null 2>&1 && lookup_ok=0 || lookup_ok=$?
        else
            nslookup "$domain" "$dns_server" >/dev/null 2>&1 && lookup_ok=0 || lookup_ok=$?
        fi
        end_time=$(get_timestamp_ms)
        resolution_time=$((end_time - start_time))

        if [[ $lookup_ok -eq 0 ]]; then
            local status
            status=$(dns_status_from_ms "$resolution_time")
            printf '%s|%s|%s|%s|%s\n' "$order" "$dns_name" "$dns_server" "$resolution_time" "$status" > "$out"
        else
            printf '%s|%s|%s|999|失败\n' "$order" "$dns_name" "$dns_server" > "$out"
        fi
    } 2>"$log"
}

collect_parallel_dns_resolution_results() {
    local domain="${1:-google.com}"
    local jobs=()
    local order=0
    local dns_name

    while IFS= read -r dns_name; do
        [[ -z "$dns_name" ]] && continue
        ((++order))
        jobs+=("$order|$dns_name|${DNS_SERVERS[$dns_name]}|$domain")
    done < <(printf '%s\n' "${!DNS_SERVERS[@]}" | LC_ALL=C sort)

    DNS_RESULTS=()
    parallel_run_records dns_resolution_record_worker "DNS解析测试" "${jobs[@]}"

    local ordered_records=()
    local i
    for i in "${!jobs[@]}"; do
        local job="${jobs[$i]}"
        local out="${PARALLEL_OUTPUT_FILES[$i]:-}"
        local job_order job_name job_server job_domain
        IFS='|' read -r job_order job_name job_server job_domain <<< "$job"

        if [[ -n "$out" && -s "$out" ]]; then
            local line
            line=$(head -n1 "$out")
            if [[ "$line" == "$job_order|"* ]]; then
                ordered_records+=("$line")
            else
                ordered_records+=("$job_order|$job_name|$job_server|999|失败")
            fi
        else
            ordered_records+=("$job_order|$job_name|$job_server|999|失败")
        fi
    done

    local record
    while IFS= read -r record; do
        [[ -z "$record" ]] && continue
        local _order dns_name dns_server resolution_time status
        IFS='|' read -r _order dns_name dns_server resolution_time status <<< "$record"
        DNS_RESULTS+=("$dns_name|$dns_server|$resolution_time|$status")
    done < <(printf '%s\n' "${ordered_records[@]}" | LC_ALL=C sort -t'|' -k1,1n)
}

show_dns_resolution_table() {
    local title="${1:-📊 DNS解析速度测试结果}"
    echo ""
    echo "$title"
    local sorted_res=()
    IFS=$'\n' sorted_res=($(printf '%s\n' "${DNS_RESULTS[@]}" | sort -t'|' -k3 -n))
    local rank=1
    local result
    for result in "${sorted_res[@]}"; do
        IFS='|' read -r dns_name server resolution_time status <<< "$result"
        local display_server="$server"
        [[ "$server" == "system" ]] && display_server="系统默认"
        local display_time="${resolution_time}ms"
        [[ "$status" == "失败" ]] && display_time="解析失败"
        format_row "${rank}.:4:right" "${dns_name}:14:left" "${display_server}:20:left" "${display_time}:10:right" "${status}:10:left"
        ((++rank))
    done
}

# DNS测试模式（测试所有网站）

run_dns_test() {
    command clear 2>/dev/null || true
    show_welcome
    
    ui_section "DNS延迟测试"
    ui_menu_item "${GREEN}1${NC}" "DNS延迟+解析速度综合测试" "推荐"
    ui_menu_item "${GREEN}2${NC}" "传统详细DNS解析测试"
    ui_menu_item "${GREEN}3${NC}" "DNS综合分析"
    ui_menu_item "${RED}0${NC}" "返回主菜单"
    echo ""
    ui_prompt "请选择 (0-3): "
    read -r dns_choice
    
    case $dns_choice in
        1)
            command clear 2>/dev/null || true
            show_welcome
            ui_section "DNS服务器延迟 + DNS解析速度测试"
            echo ""
            
            local dns_hosts=()
            local dns_host_names=()
            for dns_name in "${!DNS_SERVERS[@]}"; do
                if [[ "${DNS_SERVERS[$dns_name]}" != "system" ]]; then
                    dns_hosts+=("${DNS_SERVERS[$dns_name]}")
                    dns_host_names+=("$dns_name")
                fi
            done
            
            echo -e "${YELLOW}📡 第1步: DNS服务器延迟测试${NC}"
            echo -e "${BLUE}测试DNS服务器: ${#dns_hosts[@]}个${NC}"
            echo ""
            test_dns_servers_latency

            echo -e "${YELLOW}🔍 第2步: DNS解析速度测试 (测试域名: google.com)${NC}"
            echo ""

            collect_parallel_dns_resolution_results "google.com"
            show_dns_resolution_table "📊 DNS解析速度测试结果"

            echo ""
            ui_notice ok "DNS解析速度测试完成"
            ;;
        2)
            # 原来的DNS测试方式
            echo -e "${CYAN}🔍 开始全球DNS解析速度测试（测试所有网站）${NC}"
            echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "测试网站: ${YELLOW}${#FULL_SITES[@]}个网站${NC} | DNS服务器: ${YELLOW}${#DNS_SERVERS[@]}个${NC}"
            echo ""
            
            # 重置结果数组
            DNS_RESULTS=()
            local start_time=$(date +%s)
            
            local all_domains=()
            for domain in "${FULL_SITES[@]}"; do
                all_domains+=("$domain")
            done

            local domains_joined=""
            local domain
            for domain in "${all_domains[@]}"; do
                if [[ -n "$domains_joined" ]]; then
                    domains_joined+=","
                fi
                domains_joined+="$domain"
            done

            collect_parallel_dns_detailed_results "$domains_joined"
            
            local end_time=$(date +%s)
            local total_time=$((end_time - start_time))
            
            # 显示DNS测试结果
            show_dns_results "$total_time"
            ;;
        3)
            # DNS综合分析
            run_dns_comprehensive_analysis
            ;;
        0)
            return
            ;;
        *)
            ui_notice error "无效选择"
            sleep 2
            run_dns_test
            ;;
    esac
    
    # 等待用户按键
    echo ""
    if [[ -t 0 ]]; then
        echo -n -e "${YELLOW}按 Enter 键继续...${NC}"
        read -r
    fi
}

# IPv4/IPv6优先测试模式

run_comprehensive_test() {
    command clear 2>/dev/null || true
    show_welcome
    
    echo -e "${CYAN}📊 开始综合测试 (Ping/真连接)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 显示当前DNS设置
    if [[ -n "$SELECTED_DNS_SERVER" && "$SELECTED_DNS_SERVER" != "system" ]]; then
        echo -e "🔍 DNS解析设置: ${YELLOW}${SELECTED_DNS_NAME} (${SELECTED_DNS_SERVER})${NC}"
    else
        echo -e "🔍 DNS解析设置: ${YELLOW}系统默认${NC}"
    fi
    echo ""
    
    # 代理/VPN检测
    echo -n -e "${CYAN}🔍 检测网络环境...${NC} "
    detect_proxy
    if [[ "$PROXY_DETECTED" == "true" ]]; then
        echo -e "${YELLOW}检测到代理/VPN${NC}"
        echo -e "${YELLOW}⚠️  ${PROXY_REASON}${NC}"
        echo -e "${YELLOW}   真实连接延迟将使用TTFB作为端到端体验延迟指标${NC}"
        echo ""
    else
        echo -e "${GREEN}直连环境${NC}"
    fi
    
    # 重置所有结果数组
    RESULTS=()
    local start_time=$(date +%s 2>/dev/null || echo 0)
    
    # 第一步：使用fping进行快速批量测试
    show_fping_results
    
    echo ""
    echo -e "${YELLOW}📡 第1步: 真实连接延迟测试${NC}"
    if [[ "$PROXY_DETECTED" == "true" ]]; then
        echo -e "${YELLOW}   (代理环境: 延迟为端到端TTFB体验延迟，非直连延迟)${NC}"
    fi
    echo ""
    collect_parallel_site_results
    
    echo ""
    echo -e "${YELLOW}🔍 第2步: DNS延迟+解析速度综合测试${NC}"
    echo ""
    
    local dns_hosts=()
    local dns_host_names=()
    for dns_name in "${!DNS_SERVERS[@]}"; do
        if [[ "${DNS_SERVERS[$dns_name]}" != "system" ]]; then
            dns_hosts+=("${DNS_SERVERS[$dns_name]}")
            dns_host_names+=("$dns_name")
        fi
    done
    
    echo -e "${YELLOW}📡 DNS服务器延迟测试${NC}"
    echo -e "${BLUE}测试DNS服务器: ${#dns_hosts[@]}个${NC}"
    echo ""
    test_dns_servers_latency
    
    # 第二步：DNS解析速度测试（使用 get_timestamp_ms）
    echo -e "${YELLOW}🔍 DNS解析速度测试 (测试域名: google.com)${NC}"
    echo ""

    collect_parallel_dns_resolution_results "google.com"

    # 显示DNS解析结果
    if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
        show_dns_resolution_table "${CYAN}📊 DNS解析速度测试结果${NC}"

        echo ""
        ui_notice ok "DNS解析速度测试完成"
        echo ""
    fi
    
    echo ""
    echo -e "${YELLOW}🧪 第3步: DNS综合分析${NC}"
    echo ""
    
    # 使用DNS菜单中的选项3的内容
    echo -e "${CYAN}🔍 DNS综合分析 (测试各DNS解析IP的实际延迟)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}测试域名: google.com github.com apple.com${NC}"
    echo ""
    
    run_parallel_dns_comprehensive_analysis "google.com" "github.com" "apple.com"
    
    local end_time=$(date +%s 2>/dev/null || echo 0)
    local total_time=$((end_time - start_time))
    
    # 确保时间是有效的
    if [[ $total_time -lt 0 ]] || [[ $total_time -gt 10000 ]]; then
        total_time=0
    fi
    
    # 显示综合结果
    show_comprehensive_results "$total_time"
}

# 显示测试结果

run_dns_management() {
    command clear 2>/dev/null || true
    show_welcome
    
    ui_section "DNS设置管理"
    echo ""
    echo -e "${YELLOW}说明: 选择用于解析测试网站IP地址的DNS服务器，不会更改系统DNS设置${NC}"
    echo ""
    echo -e "${YELLOW}选择用于IP解析的DNS服务器:${NC}"
    
    local count=1
    declare -a dns_list=()
    
    # 系统默认选项
    ui_menu_item "${GREEN}$count${NC}" "系统默认" "使用系统DNS设置"
    dns_list+=("system|系统默认")
    ((++count))
    
    # 列出所有DNS服务器
    for dns_name in "${!DNS_SERVERS[@]}"; do
        local dns_server="${DNS_SERVERS[$dns_name]}"
        if [[ "$dns_server" != "system" ]]; then
            ui_menu_item "${GREEN}$count${NC}" "$dns_name" "$dns_server"
            dns_list+=("$dns_server|$dns_name")
            ((++count))
        fi
    done
    
    ui_menu_item "${RED}0${NC}" "返回主菜单"
    echo ""
    
    # 显示当前设置
    if [[ -z "$SELECTED_DNS_SERVER" || "$SELECTED_DNS_SERVER" == "system" ]]; then
        ui_notice info "当前设置: 系统默认"
    else
        ui_notice info "当前设置: $SELECTED_DNS_NAME ($SELECTED_DNS_SERVER)"
    fi
    echo ""
    
    ui_prompt "请选择 (0-$((count-1))): "
    read -r dns_choice
    
    case $dns_choice in
        0)
            return
            ;;
        1)
            SELECTED_DNS_SERVER="system"
            SELECTED_DNS_NAME="系统默认"
            ui_notice ok "已设置为系统默认DNS"
            ui_notice warn "现在进行网站测试时将使用系统默认DNS解析IP地址"
            sleep 2
            ;;
        *)
            if [[ "$dns_choice" =~ ^[0-9]+$ ]] && [[ "$dns_choice" -ge 2 ]] && [[ "$dns_choice" -le $((count-1)) ]]; then
                local selected_dns="${dns_list[$((dns_choice-1))]}"
                SELECTED_DNS_SERVER=$(echo "$selected_dns" | cut -d'|' -f1)
                SELECTED_DNS_NAME=$(echo "$selected_dns" | cut -d'|' -f2)
                
                ui_notice ok "已设置DNS服务器为: $SELECTED_DNS_NAME ($SELECTED_DNS_SERVER)"
                ui_notice warn "现在进行网站测试时将使用此DNS服务器解析IP地址"
                sleep 2
            else
                ui_notice error "无效选择"
                sleep 2
                run_dns_management
                return
            fi
            ;;
    esac
    
    # 询问是否立即进行测试
    echo ""
    echo -e "${YELLOW}是否立即进行网站连接测试？${NC}"
    ui_menu_item "${GREEN}1${NC}" "是，进行Ping/真连接测试"
    ui_menu_item "${GREEN}2${NC}" "是，进行综合测试"
    ui_menu_item "${RED}0${NC}" "否，返回主菜单"
    echo ""
    ui_prompt "请选择 (0-2): "
    read -r test_choice
    
    case $test_choice in
        1)
            run_test
            ;;
        2)
            run_comprehensive_test
            ;;
        0|*)
            return
            ;;
    esac
}

# 使用指定DNS服务器解析域名并返回IP

resolve_with_dns() {
    local domain=$1
    local dns_server=$2
    local ip=""
    
    if [[ "$dns_server" == "system" ]]; then
        # 使用系统默认DNS
        if command -v dig >/dev/null 2>&1; then
            ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)
        fi
        
        if [ -z "$ip" ] && command -v nslookup >/dev/null 2>&1; then
            ip=$(nslookup "$domain" 2>/dev/null | grep -A 1 "Name:" | grep "Address:" | head -n1 | awk '{print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
        fi
    else
        # 使用指定DNS服务器
        if command -v dig >/dev/null 2>&1; then
            ip=$(dig +short @"$dns_server" "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)
        fi
        
        if [ -z "$ip" ] && command -v nslookup >/dev/null 2>&1; then
            ip=$(nslookup "$domain" "$dns_server" 2>/dev/null | grep -A 1 "Name:" | grep "Address:" | head -n1 | awk '{print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
        fi
    fi
    
    echo "$ip"
}

# 测试IP的ping延迟

test_ip_latency() {
    local ip=$1
    local count=${2:-5}
    
    if [[ -z "$ip" || "$ip" == "N/A" ]]; then
        echo "999999"
        return
    fi
    
    # 简化ping命令，直接使用ping，不需要复杂的版本判断
    local ping_cmd="ping"
    
    # 检查是否有fping，fping更快更可靠
    if command -v fping >/dev/null 2>&1; then
        local fping_result=$(fping -c $count -t 1000 -q "$ip" 2>&1 | tail -1)
        if [[ -n "$fping_result" ]] && echo "$fping_result" | grep -q "min/avg/max\|avg/max"; then
            # macOS格式: min/avg/max = 1.23/2.34/3.45 ms
            # Linux格式: 1.23/2.34/3.45/0.12 ms
            local avg_latency=$(echo "$fping_result" | sed -n 's/.*[=:] *[0-9.]*\/\([0-9.]*\)\/.*/\1/p')
            if [[ "$avg_latency" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                echo "$avg_latency"
                return
            fi
        fi
    fi
    
    # 回退到标准ping
    local total_time=0
    local successful_pings=0
    
    for ((i=1; i<=count; i++)); do
        local ping_result=""
        
        # 根据操作系统使用不同的ping参数
        if [[ "$OS_TYPE" == "macos" ]]; then
            # macOS: ping -c 1 -W 2000 (timeout in milliseconds)
            ping_result=$(ping -c 1 -W 2 "$ip" 2>/dev/null || true)
        else
            # Linux: ping -c 1 -W 2 (timeout in seconds)
            ping_result=$(ping -c 1 -W 2 "$ip" 2>/dev/null || true)
        fi
        
        if [[ -n "$ping_result" ]] && echo "$ping_result" | grep -q "time="; then
            local ping_ms=""
            
            # 提取时间，兼容多种格式
            # 格式: time=12.3 ms 或 time=12.3ms
            ping_ms=$(echo "$ping_result" | grep -oP 'time=\K[0-9.]+' 2>/dev/null || \
                      echo "$ping_result" | grep -o 'time=[0-9.]*' | cut -d'=' -f2 2>/dev/null || echo "")
            
            if [[ -n "$ping_ms" ]] && [[ "$ping_ms" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                if command -v bc >/dev/null 2>&1; then
                    total_time=$(echo "$total_time + $ping_ms" | bc -l 2>/dev/null || echo "$total_time")
                else
                    # 如果没有bc，使用awk
                    total_time=$(awk "BEGIN {print $total_time + $ping_ms}" 2>/dev/null || echo "$total_time")
                fi
                ((++successful_pings))
            fi
        fi
    done
    
    if [ $successful_pings -gt 0 ]; then
        if command -v bc >/dev/null 2>&1; then
            echo "scale=1; $total_time / $successful_pings" | bc -l 2>/dev/null || echo "999999"
        else
            awk "BEGIN {printf \"%.1f\", $total_time / $successful_pings}" 2>/dev/null || echo "999999"
        fi
    else
        echo "999999"
    fi
}

dns_composite_score() {
    local avg_resolution_time="$1"
    local avg_ping_time="$2"
    local composite_score=0

    if [[ "$avg_ping_time" != "9999" ]] && [[ "$avg_resolution_time" != "9999" ]]; then
        local ping_time_int=${avg_ping_time%.*}
        local resolution_time_int=${avg_resolution_time%.*}
        local ping_score=0
        local dns_score=0

        [[ ! "$ping_time_int" =~ ^[0-9]+$ ]] && ping_time_int=999
        [[ ! "$resolution_time_int" =~ ^[0-9]+$ ]] && resolution_time_int=999

        if (( ping_time_int <= 20 )); then
            ping_score=70
        elif (( ping_time_int <= 40 )); then
            ping_score=$((70 - (ping_time_int - 20) / 2))
        elif (( ping_time_int <= 60 )); then
            ping_score=$((60 - (ping_time_int - 40) / 2))
        elif (( ping_time_int <= 100 )); then
            ping_score=$((50 - (ping_time_int - 60) / 2))
        elif (( ping_time_int <= 150 )); then
            ping_score=$((30 - (ping_time_int - 100) / 3))
        elif (( ping_time_int <= 200 )); then
            ping_score=$((15 - (ping_time_int - 150) / 5))
        else
            ping_score=5
        fi

        if (( resolution_time_int <= 30 )); then
            dns_score=30
        elif (( resolution_time_int <= 50 )); then
            dns_score=$((30 - (resolution_time_int - 30) / 4))
        elif (( resolution_time_int <= 80 )); then
            dns_score=$((25 - (resolution_time_int - 50) / 6))
        elif (( resolution_time_int <= 120 )); then
            dns_score=$((20 - (resolution_time_int - 80) / 8))
        elif (( resolution_time_int <= 200 )); then
            dns_score=$((15 - (resolution_time_int - 120) / 16))
        else
            dns_score=5
        fi

        [[ $ping_score -lt 0 ]] && ping_score=0
        [[ $dns_score -lt 0 ]] && dns_score=0
        composite_score=$((ping_score + dns_score))
    fi

    echo "$composite_score"
}

dns_comprehensive_probe_worker() {
    local item="$1"
    local out="$2"
    local log="$3"
    local order dns_name dns_server domain
    IFS='|' read -r order dns_name dns_server domain <<< "$item"

    {
        local start_time end_time resolution_time resolved_ip ping_latency
        start_time=$(get_timestamp_ms)
        resolved_ip=$(resolve_with_dns "$domain" "$dns_server")
        end_time=$(get_timestamp_ms)
        resolution_time=$((end_time - start_time))

        if [[ -n "$resolved_ip" && "$resolved_ip" != "N/A" ]]; then
            ping_latency=$(test_ip_latency "$resolved_ip" 2)
            if [[ "$ping_latency" != "999999" && "$ping_latency" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                printf '%s|%s|%s|%s|%s|%s|%s|ok|ok\n' "$order" "$dns_name" "$dns_server" "$domain" "$resolution_time" "$resolved_ip" "$ping_latency" > "$out"
            else
                printf '%s|%s|%s|%s|%s|%s|9999|ok|failed\n' "$order" "$dns_name" "$dns_server" "$domain" "$resolution_time" "$resolved_ip" > "$out"
            fi
        else
            printf '%s|%s|%s|%s|9999|N/A|9999|failed|failed\n' "$order" "$dns_name" "$dns_server" "$domain" > "$out"
        fi
    } 2>"$log"
}

run_parallel_dns_comprehensive_analysis() {
    local -a test_domains=("$@")
    local jobs=()
    local dns_order=0
    local order=0
    local dns_name domain

    while IFS= read -r dns_name; do
        [[ -z "$dns_name" ]] && continue
        ((++dns_order))
        for domain in "${test_domains[@]}"; do
            ((++order))
            jobs+=("$order|$dns_name|${DNS_SERVERS[$dns_name]}|$domain")
        done
    done < <(printf '%s\n' "${!DNS_SERVERS[@]}" | LC_ALL=C sort)

    parallel_run_records dns_comprehensive_probe_worker "DNS综合分析" "${jobs[@]}"

    declare -A total_resolution_time=()
    declare -A total_ping_time=()
    declare -A successful_resolutions=()
    declare -A successful_pings=()
    declare -A dns_server_by_name=()
    declare -A seen_dns=()
    declare -a dns_names=()
    local i

    for i in "${!jobs[@]}"; do
        local job="${jobs[$i]}"
        local out="${PARALLEL_OUTPUT_FILES[$i]:-}"
        local job_order job_dns_name job_dns_server job_domain
        IFS='|' read -r job_order job_dns_name job_dns_server job_domain <<< "$job"

        if [[ -z "${seen_dns[$job_dns_name]:-}" ]]; then
            seen_dns["$job_dns_name"]=1
            dns_names+=("$job_dns_name")
            dns_server_by_name["$job_dns_name"]="$job_dns_server"
        fi

        local line="$job_order|$job_dns_name|$job_dns_server|$job_domain|9999|N/A|9999|failed|failed"
        if [[ -n "$out" && -s "$out" ]]; then
            line=$(head -n1 "$out")
        fi

        local rec_order rec_dns_name rec_dns_server rec_domain rec_resolution_time rec_ip rec_ping rec_resolution_ok rec_ping_ok
        IFS='|' read -r rec_order rec_dns_name rec_dns_server rec_domain rec_resolution_time rec_ip rec_ping rec_resolution_ok rec_ping_ok <<< "$line"
        [[ -z "$rec_dns_name" ]] && rec_dns_name="$job_dns_name"

        if [[ "$rec_resolution_ok" == "ok" && "$rec_resolution_time" =~ ^[0-9]+$ ]]; then
            total_resolution_time["$rec_dns_name"]=$(( ${total_resolution_time["$rec_dns_name"]:-0} + rec_resolution_time ))
            successful_resolutions["$rec_dns_name"]=$(( ${successful_resolutions["$rec_dns_name"]:-0} + 1 ))
        fi

        if [[ "$rec_ping_ok" == "ok" && "$rec_ping" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            total_ping_time["$rec_dns_name"]=$(awk "BEGIN {print ${total_ping_time["$rec_dns_name"]:-0} + $rec_ping}" 2>/dev/null || echo "${total_ping_time["$rec_dns_name"]:-0}")
            successful_pings["$rec_dns_name"]=$(( ${successful_pings["$rec_dns_name"]:-0} + 1 ))
        fi
    done

    declare -a analysis_results=()
    local name
    for name in "${dns_names[@]}"; do
        local avg_resolution_time=9999
        local avg_ping_time=9999
        local resolution_count=${successful_resolutions["$name"]:-0}
        local ping_count=${successful_pings["$name"]:-0}

        if [[ $resolution_count -gt 0 ]]; then
            avg_resolution_time=$(( ${total_resolution_time["$name"]:-0} / resolution_count ))
        fi
        if [[ $ping_count -gt 0 ]]; then
            avg_ping_time=$(awk "BEGIN {printf \"%.1f\", ${total_ping_time["$name"]:-0} / $ping_count}" 2>/dev/null || echo "9999")
        fi

        local composite_score
        composite_score=$(dns_composite_score "$avg_resolution_time" "$avg_ping_time")
        analysis_results+=("$((100-composite_score))|$name|${dns_server_by_name[$name]}|$avg_resolution_time|$avg_ping_time|$resolution_count|$ping_count|$composite_score")
    done

    echo ""
    echo -e "${CYAN}📊 DNS综合分析结果${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    local sorted_results=()
    IFS=$'\n' sorted_results=($(printf '%s\n' "${analysis_results[@]}" | sort -t'|' -k1 -n))

    local temp_table
    temp_table=$(register_temp)
    echo "DNS服务器|IP地址|解析速度|Ping延迟|综合得分|状态" > "$temp_table"

    local rank=1
    local best_dns=""
    local best_score=""
    local result
    for result in "${sorted_results[@]}"; do
        IFS='|' read -r sort_key dns_name dns_server avg_resolution_time avg_ping_time successful_resolutions successful_pings composite_score <<< "$result"

        local display_server="$dns_server"
        if [[ ${#display_server} -gt 18 ]]; then
            display_server="${display_server:0:15}..."
        fi

        local status=""
        local display_resolution="${avg_resolution_time}ms"
        local display_ping="${avg_ping_time}ms"
        if [[ "$composite_score" == "0" ]]; then
            status="失败"
            display_ping="失败"
        elif [[ $composite_score -ge 95 ]]; then
            status="优秀"
        elif [[ $composite_score -ge 85 ]]; then
            status="良好"
        elif [[ $composite_score -ge 70 ]]; then
            status="一般"
        else
            status="较差"
        fi

        if [[ $rank -eq 1 && "$status" != "失败" ]]; then
            best_dns="$dns_name"
            best_score="$composite_score"
        fi

        echo "$dns_name|$display_server|$display_resolution|$display_ping|$composite_score|$status" >> "$temp_table"
        ((++rank))
    done

    local is_header=true
    while IFS='|' read -r table_dns table_server table_resolution table_ping table_score table_status; do
        if [[ "$is_header" == "true" ]]; then
            format_row "$table_dns:18:left" "$table_server:20:left" "$table_resolution:12:right" "$table_ping:12:right" "$table_score:8:right" "$table_status:10:left"
            is_header=false
        else
            local status_colored=""
            case "$table_status" in
                "优秀") status_colored="${GREEN}✓ 优秀${NC}" ;;
                "良好") status_colored="${YELLOW}◆ 良好${NC}" ;;
                "一般") status_colored="${PURPLE}~ 一般${NC}" ;;
                "较差") status_colored="${RED}▲ 较差${NC}" ;;
                "失败") status_colored="${RED}✗ 失败${NC}" ;;
                *) status_colored="$table_status" ;;
            esac
            format_row "$table_dns:18:left" "$table_server:20:left" "$table_resolution:12:right" "$table_ping:12:right" "$table_score:8:right" "$status_colored:10:left"
        fi
    done < "$temp_table"

    echo ""
    echo -e "${CYAN}🏆 综合分析建议${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    if [[ -n "$best_dns" ]]; then
        echo -e "${GREEN}🥇 最佳推荐: ${best_dns}${NC}"
        echo -e "   • 综合得分: ${best_score}/100分"
        echo -e "   • 建议: 设置为默认DNS可获得最佳网络体验"
        echo ""
        echo -e "${YELLOW}📝 评分标准说明:${NC}"
        echo -e "   • 100分制，分数越高越好（采用严谨的指数衰减算法）"
        echo -e "   • Ping延迟评分: 70分 (≤20ms=70分, 20-40ms递减, >200ms=5分)"
        echo -e "   • DNS解析评分: 30分 (≤30ms=30分, 30-50ms递减, >200ms=5分)"
        echo -e "   • 95分以上=优秀, 85-94分=良好, 70-84分=一般, 70分以下=较差"
    else
        echo -e "${RED}✗ 所有DNS测试均失败，请检查网络连接${NC}"
    fi

    rm -f "$temp_table"
}

# DNS综合分析功能

run_dns_comprehensive_analysis() {
    command clear 2>/dev/null || true
    show_welcome
    
    echo -e "${CYAN}🧪 DNS综合分析 - 测试各DNS解析IP的实际延迟${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📋 测试说明：${NC}"
    echo -e "   • 使用每个DNS服务器解析测试域名获得IP地址"
    echo -e "   • 测试解析出的IP地址的实际ping延迟"
    echo -e "   • 综合考虑DNS解析速度和ping延迟给出最佳建议"
    echo ""
    
    # 选择测试域名
    local test_domains=("google.com" "github.com" "apple.com")
    echo -e "${CYAN}🎯 测试域名: ${test_domains[*]}${NC}"
    echo ""
    
    run_parallel_dns_comprehensive_analysis "${test_domains[@]}"
    
    echo ""
    echo -e "${GREEN}✅ DNS综合分析完成${NC}"
    echo ""
    echo "按 Enter 键返回主菜单..."
    read -r
}
