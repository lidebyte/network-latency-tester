# shellcheck shell=bash
generate_output_file() {
    local output_path="$1"
    local format="$2"
    
    if [[ -z "$output_path" ]]; then
        output_path="latency_results_$(date +%Y%m%d_%H%M%S).$format"
    fi
    
    case "$format" in
        markdown|md)
            generate_markdown_output "$output_path"
            ;;
        html)
            generate_html_output "$output_path"
            ;;
        json)
            generate_json_output "$output_path"
            ;;
        *)
            generate_text_output "$output_path"
            ;;
    esac
    
    ui_saved_file "$output_path"
}

# 生成文本格式输出

generate_text_output() {
    local file="$1"
    {
        echo "# 网络延迟测试结果 - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# =========================================="
        echo ""
        echo "## Ping/真连接测试结果"
        echo "服务|域名|延迟|状态|IPv4|IPv6|丢包率|版本"
        printf '%s\n' "${RESULTS[@]}"
        echo ""
        if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
            echo "## DNS解析测试结果"
            echo "DNS名称|DNS服务器|解析时间|状态"
            printf '%s\n' "${DNS_RESULTS[@]}"
            echo ""
        fi
    } > "$file"
}

# 生成Markdown格式输出

generate_markdown_output() {
    local file="$1"
    
    if [[ "$SINGLE_RESULT_PAGE" == "true" ]]; then
        # 单页增强版 - 包含统计分析和图表
        {
            echo "# 🚀 网络延迟测试完整报告"
            echo ""
            echo "---"
            echo ""
            echo "**📅 测试时间:** $(date '+%Y-%m-%d %H:%M:%S')  "
            echo "**🖥️ 测试系统:** $OS_TYPE  "
            echo "**📍 测试环境:** $(hostname 2>/dev/null || echo '本地主机')"
            echo ""
            echo "---"
            echo ""
            
            # 统计分析
            echo "## 📊 测试统计概览"
            echo ""
            local total_tests=${#RESULTS[@]}
            local excellent_count=0
            local good_count=0
            local poor_count=0
            
            for result in "${RESULTS[@]}"; do
                IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
                if [[ "$status" == *"优秀"* ]]; then
                    ((++excellent_count))
                elif [[ "$status" == *"良好"* ]]; then
                    ((++good_count))
                else
                    ((++poor_count))
                fi
            done
            
            echo "| 指标 | 数值 |"
            echo "|------|------|"
            echo "| ✅ 优秀节点 | $excellent_count / $total_tests |"
            echo "| 🔸 良好节点 | $good_count / $total_tests |"
            echo "| ❌ 较差节点 | $poor_count / $total_tests |"
            echo ""
            
            # Ping/真连接测试结果
            echo "## 📊 Ping/真连接延迟测试"
            echo ""
            echo "| 🏆 | 服务 | 域名 | ⏱️ 延迟 | 📉 丢包率 | 📍 状态 | 🌐 IPv4 |"
            echo "|:---:|------|------|:------:|:--------:|:------:|---------|"
            local rank=1
            for result in "${RESULTS[@]}"; do
                IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
                local medal="🥇"
                [[ $rank -eq 2 ]] && medal="🥈"
                [[ $rank -eq 3 ]] && medal="🥉"
                [[ $rank -gt 3 ]] && medal="$rank"
                echo "| $medal | **$service** | \`$host\` | $latency | $loss | $status | \`$ipv4\` |"
                ((++rank))
            done
            echo ""
            
            if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
                echo "## 🔍 DNS解析速度测试"
                echo ""
                echo "| 🏆 | DNS服务器 | IP地址 | ⏱️ 解析时间 | 📍 状态 |"
                echo "|:---:|-----------|--------|:---------:|:------:|"
                rank=1
                for result in "${DNS_RESULTS[@]}"; do
                    IFS='|' read -r dns_name server time status <<< "$result"
                    local medal="🥇"
                    [[ $rank -eq 2 ]] && medal="🥈"
                    [[ $rank -eq 3 ]] && medal="🥉"
                    [[ $rank -gt 3 ]] && medal="$rank"
                    echo "| $medal | **$dns_name** | \`$server\` | $time | $status |"
                    ((++rank))
                done
                echo ""
            fi
            
            echo "---"
            echo ""
            echo "## 💡 延迟等级说明"
            echo ""
            echo "- ✅ **优秀** (< 50ms) - 适合游戏、视频通话"
            echo "- 🔸 **良好** (50-150ms) - 适合网页浏览、视频"
            echo "- ⚠️ **一般** (150-300ms) - 基础使用"
            echo "- ❌ **较差** (> 300ms) - 网络质量差"
            echo ""
            echo "---"
            echo ""
            echo "> 💻 生成工具: [Network Latency Tester](https://github.com/Cd1s/network-latency-tester)"
            echo ""
        } > "$file"
    else
        # 标准简洁版
        {
            echo "# 网络延迟测试报告"
            echo ""
            echo "**测试时间:** $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""
            echo "## 📊 Ping/真连接测试结果"
            echo ""
            echo "| 排名 | 服务 | 域名 | 延迟 | 丢包率 | 状态 |"
            echo "|------|------|------|------|--------|------|"
            local rank=1
            for result in "${RESULTS[@]}"; do
                IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
                echo "| $rank | $service | $host | $latency | $loss | $status |"
                ((++rank))
            done
            echo ""
            
            if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
                echo "## 🔍 DNS解析测试结果"
                echo ""
                echo "| 排名 | DNS服务器 | IP地址 | 解析时间 | 状态 |"
                echo "|------|-----------|--------|----------|------|"
                rank=1
                for result in "${DNS_RESULTS[@]}"; do
                    IFS='|' read -r dns_name server time status <<< "$result"
                    echo "| $rank | $dns_name | $server | $time | $status |"
                    ((++rank))
                done
                echo ""
            fi
        } > "$file"
    fi
}

# 生成HTML格式输出

generate_html_output() {
    local file="$1"
    
    # 计算统计数据
    local total_tests=${#RESULTS[@]}
    local excellent_count=0
    local good_count=0
    local poor_count=0
    
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
        if [[ "$status" == *"优秀"* ]]; then
            ((++excellent_count))
        elif [[ "$status" == *"良好"* ]]; then
            ((++good_count))
        else
            ((++poor_count))
        fi
    done
    
    {
        if [[ "$SINGLE_RESULT_PAGE" == "true" ]]; then
            # 单页增强版 - 现代化设计
            cat <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>网络延迟测试完整报告</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; min-height: 100vh; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 16px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header .meta { font-size: 1em; opacity: 0.9; }
        .content { padding: 40px; }
        .stats { display: flex; justify-content: space-around; margin: 30px 0; }
        .stat-card { flex: 1; margin: 0 10px; padding: 20px; background: #f8f9fa; border-radius: 12px; text-align: center; transition: transform 0.2s; }
        .stat-card:hover { transform: translateY(-5px); box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
        .stat-card .number { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .stat-card .label { color: #666; font-size: 0.9em; }
        .stat-card.excellent .number { color: #4CAF50; }
        .stat-card.good .number { color: #FF9800; }
        .stat-card.poor .number { color: #F44336; }
        h2 { color: #333; margin: 40px 0 20px 0; padding-bottom: 10px; border-bottom: 3px solid #667eea; font-size: 1.8em; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        th { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px; text-align: left; font-weight: 600; }
        td { padding: 12px 15px; border-bottom: 1px solid #f0f0f0; }
        tr:hover { background: #f8f9fa; }
        tr:last-child td { border-bottom: none; }
        .rank { font-weight: bold; font-size: 1.2em; }
        .rank.gold { color: #FFD700; }
        .rank.silver { color: #C0C0C0; }
        .rank.bronze { color: #CD7F32; }
        .status { padding: 5px 12px; border-radius: 20px; font-size: 0.85em; font-weight: 600; display: inline-block; }
        .status.excellent { background: #e8f5e9; color: #4CAF50; }
        .status.good { background: #fff3e0; color: #FF9800; }
        .status.poor { background: #ffebee; color: #F44336; }
        .footer { background: #f8f9fa; padding: 30px; text-align: center; color: #666; }
        .footer a { color: #667eea; text-decoration: none; font-weight: 600; }
        .info-box { background: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; font-family: 'Courier New', monospace; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 网络延迟测试完整报告</h1>
            <p class="meta">📅 测试时间: 
HTML_HEADER
            echo "$(date '+%Y-%m-%d %H:%M:%S') | 🖥️ 系统: $OS_TYPE | 📍 主机: $(hostname 2>/dev/null || echo '本地主机')</p>"
            echo "</div>"
            echo "<div class=\"content\">"
            
            # 统计卡片
            echo "<div class=\"stats\">"
            echo "<div class=\"stat-card excellent\"><div class=\"number\">$excellent_count</div><div class=\"label\">✅ 优秀节点</div></div>"
            echo "<div class=\"stat-card good\"><div class=\"number\">$good_count</div><div class=\"label\">🔸 良好节点</div></div>"
            echo "<div class=\"stat-card poor\"><div class=\"number\">$poor_count</div><div class=\"label\">❌ 较差节点</div></div>"
            echo "<div class=\"stat-card\"><div class=\"number\">$total_tests</div><div class=\"label\">📊 测试总数</div></div>"
            echo "</div>"
            
            # Ping测试结果
            echo "<h2>📊 Ping/真连接延迟测试</h2>"
            echo "<table><thead><tr><th style=\"width:60px;\">🏆 排名</th><th>服务</th><th>域名</th><th>⏱️ 延迟</th><th>📉 丢包率</th><th>📍 状态</th><th>🌐 IPv4地址</th></tr></thead><tbody>"
            local rank=1
            for result in "${RESULTS[@]}"; do
                IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
                local rank_class=""
                local rank_display="$rank"
                [[ $rank -eq 1 ]] && rank_class="gold" && rank_display="🥇"
                [[ $rank -eq 2 ]] && rank_class="silver" && rank_display="🥈"
                [[ $rank -eq 3 ]] && rank_class="bronze" && rank_display="🥉"
                
                local status_class="poor"
                [[ "$status" == *"优秀"* ]] && status_class="excellent"
                [[ "$status" == *"良好"* ]] && status_class="good"
                
                echo "<tr><td class=\"rank $rank_class\">$rank_display</td><td><strong>$service</strong></td><td><code>$host</code></td><td>$latency</td><td>$loss</td><td><span class=\"status $status_class\">$status</span></td><td><code>$ipv4</code></td></tr>"
                ((++rank))
            done
            echo "</tbody></table>"
            
            # DNS测试结果
            if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
                echo "<h2>🔍 DNS解析速度测试</h2>"
                echo "<table><thead><tr><th style=\"width:60px;\">🏆 排名</th><th>DNS服务器</th><th>IP地址</th><th>⏱️ 解析时间</th><th>📍 状态</th></tr></thead><tbody>"
                rank=1
                for result in "${DNS_RESULTS[@]}"; do
                    IFS='|' read -r dns_name server time status <<< "$result"
                    local rank_display="$rank"
                    [[ $rank -eq 1 ]] && rank_display="🥇"
                    [[ $rank -eq 2 ]] && rank_display="🥈"
                    [[ $rank -eq 3 ]] && rank_display="🥉"
                    echo "<tr><td class=\"rank\">$rank_display</td><td><strong>$dns_name</strong></td><td><code>$server</code></td><td>$time</td><td>$status</td></tr>"
                    ((++rank))
                done
                echo "</tbody></table>"
            fi
            
            # 说明信息
            echo "<div class=\"info-box\">"
            echo "<h3 style=\"margin-bottom:10px;\">💡 延迟等级说明</h3>"
            echo "<p><strong>✅ 优秀 (&lt; 50ms)</strong> - 适合游戏、视频通话<br>"
            echo "<strong>🔸 良好 (50-150ms)</strong> - 适合网页浏览、视频<br>"
            echo "<strong>⚠️ 一般 (150-300ms)</strong> - 基础使用<br>"
            echo "<strong>❌ 较差 (&gt; 300ms)</strong> - 网络质量差</p>"
            echo "</div>"
            
            echo "</div>"
            echo "<div class=\"footer\">"
            echo "<p>💻 生成工具: <a href=\"https://github.com/Cd1s/network-latency-tester\" target=\"_blank\">Network Latency Tester</a></p>"
            echo "<p style=\"margin-top:10px;font-size:0.9em;\">此报告由自动化工具生成 | 数据仅供参考</p>"
            echo "</div>"
            echo "</div></body></html>"
        else
            # 标准简洁版
            cat <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>网络延迟测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #4CAF50; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .excellent { color: #4CAF50; font-weight: bold; }
        .good { color: #FF9800; font-weight: bold; }
        .poor { color: #F44336; font-weight: bold; }
        .meta { color: #888; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 网络延迟测试报告</h1>
        <p class="meta">测试时间: 
HTML_HEADER
            echo "$(date '+%Y-%m-%d %H:%M:%S')</p>"
            
            echo "<h2>📊 Ping/真连接测试结果</h2>"
            echo "<table><thead><tr><th>排名</th><th>服务</th><th>域名</th><th>延迟</th><th>丢包率</th><th>状态</th></tr></thead><tbody>"
            local rank=1
            for result in "${RESULTS[@]}"; do
                IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
                local status_class="poor"
                [[ "$status" == *"优秀"* ]] && status_class="excellent"
                [[ "$status" == *"良好"* ]] && status_class="good"
                echo "<tr><td>$rank</td><td>$service</td><td>$host</td><td>$latency</td><td>$loss</td><td class='$status_class'>$status</td></tr>"
                ((++rank))
            done
            echo "</tbody></table>"
            
            if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
                echo "<h2>🔍 DNS解析测试结果</h2>"
                echo "<table><thead><tr><th>排名</th><th>DNS服务器</th><th>解析时间</th><th>状态</th></tr></thead><tbody>"
                rank=1
                for result in "${DNS_RESULTS[@]}"; do
                    IFS='|' read -r dns_name server time status <<< "$result"
                    echo "<tr><td>$rank</td><td>$dns_name</td><td>$time</td><td>$status</td></tr>"
                    ((++rank))
                done
                echo "</tbody></table>"
            fi
            
            echo "</div></body></html>"
        fi
    } > "$file"
}

# 生成JSON格式输出

generate_json_output() {
    local file="$1"
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"ping_results\": ["
        local first=true
        for result in "${RESULTS[@]}"; do
            IFS='|' read -r service host latency status ipv4 ipv6 loss version <<< "$result"
            [[ "$first" == "false" ]] && echo ","
            echo -n "    {\"service\": \"$service\", \"host\": \"$host\", \"latency\": \"$latency\", \"status\": \"$status\", \"packet_loss\": \"$loss\"}"
            first=false
        done
        echo ""
        echo "  ]"
        if [[ ${#DNS_RESULTS[@]} -gt 0 ]]; then
            echo "  ,\"dns_results\": ["
            first=true
            for result in "${DNS_RESULTS[@]}"; do
                IFS='|' read -r dns_name server time status <<< "$result"
                [[ "$first" == "false" ]] && echo ","
                echo -n "    {\"dns_name\": \"$dns_name\", \"server\": \"$server\", \"time\": \"$time\", \"status\": \"$status\"}"
                first=false
            done
            echo ""
            echo "  ]"
        fi
        echo "}"
    } > "$file"
}

# 使用fping进行批量测试（跨平台兼容）

show_results() {
    local total_time=$1
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 测试完成！${NC} 总时间: ${YELLOW}${total_time}秒${NC}"
    echo ""
    
    # 生成表格 - 使用新的对齐系统
    if [[ "$PROXY_DETECTED" == "true" ]]; then
        echo -e "${YELLOW}⚠️  代理/VPN环境: ${PROXY_REASON}${NC}"
        echo -e "${YELLOW}   以下延迟为端到端体验延迟(TTFB)，非直连延迟。关闭代理后重试可获得真实延迟。${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}📋 延迟测试结果表格:${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    # 使用format_row输出表头
    format_row "排名:4:right" "服务:15:left" "域名:25:left" "延迟:10:right" "丢包率:8:right" "状态:10:left" "IPv4地址:16:left" "版本:8:left"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    
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
    
    # 显示成功的结果 - 使用新的对齐系统
    local rank=1
    for result in "${sorted_results[@]}"; do
        IFS='|' read -r service host latency status ipv4_addr ipv6_addr packet_loss version <<< "$result"
        
        # 调试：如果packet_loss为空，输出提示
        # [[ -z "$packet_loss" ]] && echo "DEBUG: $service packet_loss is empty, result=$result" >&2
        
        local status_colored=""
        local status_icon=""
        case "$status" in
            "优秀") 
                status_colored="${GREEN}✓ 优秀${NC}"
                status_icon="✓"
                ;;
            "良好") 
                status_colored="${YELLOW}◆ 良好${NC}"
                status_icon="◆"
                ;;
            "较差") 
                status_colored="${RED}▲ 较差${NC}"
                status_icon="▲"
                ;;
            "很差") 
                status_colored="${RED}✗ 很差${NC}"
                status_icon="✗"
                ;;
            "一般")
                status_colored="${PURPLE}~ 一般${NC}"
                status_icon="~"
                ;;
            *) 
                status_colored="$status"
                status_icon=""
                ;;
        esac
        
        # 格式化延迟显示（确保右对齐，保持一致格式）
        local latency_display="$latency"
        # 如果延迟是整数，添加 .0
        if [[ "$latency" =~ ^([0-9]+)ms$ ]]; then
            latency_display="${BASH_REMATCH[1]}.0ms"
        fi
        
        # 格式化丢包率显示（packet_loss 已经包含 % 符号）
        # 先去除可能的空格
        local loss_display=$(echo "$packet_loss" | tr -d '[:space:]')
        # 处理各种情况：空、N/A、或没有 %
        if [[ -z "$loss_display" || "$loss_display" == "%" ]]; then
            loss_display="0%"
        elif [[ "$loss_display" == "N/A" ]]; then
            loss_display="N/A"
        elif [[ ! "$loss_display" =~ % ]]; then
            loss_display="${loss_display}%"
        fi
        
        # 特殊处理Telegram显示
        local host_display="$host"
        local ipv4_display="$ipv4_addr"
        local version_display="${version:-IPv4}"
        
        if [[ "$host" == "telegram_dc_test" || "$host" == "Telegram_DC" ]]; then
            host_display="Telegram_DC"
            version_display="$version"  # DC号显示在版本列
        else
            # 截断过长的IP地址
            if [ ${#ipv4_addr} -gt 15 ]; then
                ipv4_display="${ipv4_addr:0:13}..."
            fi
        fi
        
        # 使用format_row统一输出
        format_row "$rank:4:right" "$service:15:left" "$host_display:25:left" "$latency_display:10:right" "$loss_display:8:right" "$status_colored:10:left" "$ipv4_display:16:left" "$version_display:8:left"
        ((++rank))
    done
    
    # 显示失败的结果 - 使用新的对齐系统
    for result in "${failed_results[@]}"; do
        IFS='|' read -r service host latency status ipv4_addr ipv6_addr packet_loss version <<< "$result"
        
        local status_display="${RED}❌${status}${NC}"
        local loss_display="${packet_loss:-N/A}"
        local ipv4_display="${ipv4_addr:-N/A}"
        
        # 使用format_row统一输出
        format_row "$rank:4:right" "$service:15:left" "$host:25:left" "$latency:10:right" "$loss_display:8:right" "$status_display:10:left" "$ipv4_display:16:left" "${version:-IPv4}:8:left"
        ((++rank))
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
    
    # 保存结果（如果启用）
    if [[ "$ENABLE_OUTPUT" == "true" ]]; then
        if [[ -z "$OUTPUT_FILE" ]]; then
            OUTPUT_FILE="latency_results_$(date +%Y%m%d_%H%M%S).html"
            OUTPUT_FORMAT="html"
        fi
        
        echo ""
        generate_output_file "$OUTPUT_FILE" "$OUTPUT_FORMAT"
        echo ""
        
        if [[ "$OUTPUT_FORMAT" == "html" ]]; then
            ui_html_view_hint "$OUTPUT_FILE"
        fi
        echo ""
    else
        echo ""
        ui_output_disabled
    fi
    echo -e "${CYAN}💡 延迟等级说明:${NC}"
    echo -e "  ${GREEN}🟢 优秀${NC} (< 50ms)     - 适合游戏、视频通话"
    echo -e "  ${YELLOW}🟡 良好${NC} (50-150ms)   - 适合网页浏览、视频"
    echo -e "  ${RED}🔴 较差${NC} (150-500ms)  - 基础使用，可能影响体验"
    echo -e "  ${RED}💀 很差${NC} (> 500ms)    - 网络质量很差"
    
    echo ""
    if [[ -t 0 ]]; then
        echo -n -e "${YELLOW}按 Enter 键返回主菜单...${NC}"
        read -r
    else
        echo -e "${YELLOW}测试完成！${NC}"
        exit 0
    fi
}

# 显示DNS测试结果

show_dns_results() {
    local total_time=$1
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔍 DNS测试完成！${NC} 总时间: ${YELLOW}${total_time}秒${NC}"
    echo ""
    
    # 生成DNS结果表格
    echo -e "${CYAN}📋 DNS解析速度结果:${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"
    format_row "排名:4:right" "DNS服务器:14:left" "IP地址:20:left" "解析时间:10:right" "状态:10:left"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"
    
    # 排序DNS结果
    declare -a sorted_dns_results=()
    declare -a failed_dns_results=()
    
    for result in "${DNS_RESULTS[@]}"; do
        if [[ "$result" == *"失败"* ]]; then
            failed_dns_results+=("$result")
        else
            sorted_dns_results+=("$result")
        fi
    done
    
    # 按解析时间排序成功的结果
    IFS=$'\n' sorted_dns_results=($(printf '%s\n' "${sorted_dns_results[@]}" | sort -t'|' -k3 -n))
    
    # 显示成功的DNS结果
    local rank=1
    local best_dns=""
    for result in "${sorted_dns_results[@]}"; do
        IFS='|' read -r dns_name dns_server resolution_time status <<< "$result"
        
        if [ $rank -eq 1 ]; then
            best_dns="$dns_name"
        fi
        
        local status_colored=""
        if [[ "$status" == *"成功"* ]]; then
            status_colored="${GREEN}✅  $status${NC}"
        else
            status_colored="${RED}❌ $status${NC}"
        fi
        format_row "${rank}.:4:right" "${dns_name}:14:left" "${dns_server}:20:left" "${resolution_time}:10:right" "${status_colored}:10:left"
        ((++rank))
    done
    
    # 显示失败的DNS结果
    for result in "${failed_dns_results[@]}"; do
        IFS='|' read -r dns_name dns_server resolution_time status <<< "$result"
        format_row "${rank}.:4:right" "${dns_name}:14:left" "${dns_server}:20:left" "${resolution_time}:10:right" "${RED}❌ $status${NC}:10:left"
        ((++rank))
    done
    
    # DNS建议
    echo ""
    echo -e "${CYAN}💡 DNS优化建议:${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"
    if [ -n "$best_dns" ]; then
        echo -e "🏆 ${GREEN}推荐使用: $best_dns${NC} (解析速度最快)"
    fi
    
    echo -e "📊 各DNS服务商特点:"
    echo -e "  ${CYAN}Google DNS (8.8.8.8)${NC}     - 全球覆盖，稳定可靠"
    echo -e "  ${CYAN}Cloudflare DNS (1.1.1.1)${NC} - 注重隐私，速度快"
    echo -e "  ${CYAN}Quad9 DNS (9.9.9.10)${NC}     - 安全过滤，阻止恶意网站"
    echo -e "  ${CYAN}OpenDNS${NC}                 - 企业级功能，内容过滤"
    
    # 保存DNS结果
    local dns_output_file="dns_results_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "# DNS解析速度测试结果 - $(date)"
        echo "# DNS服务商|DNS服务器|解析时间|状态"
        printf '%s\n' "${DNS_RESULTS[@]}"
    } > "$dns_output_file"
    
    echo ""
    ui_saved_file "$dns_output_file"
    echo ""
    if [[ -t 0 ]]; then
        echo -n -e "${YELLOW}按 Enter 键返回主菜单...${NC}"
        read -r
    else
        echo -e "${YELLOW}DNS测试完成！${NC}"
        exit 0
    fi
}

# 显示综合测试结果

show_comprehensive_results() {
    local total_time=$1
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 综合测试完成！${NC} 总时间: ${YELLOW}${total_time}秒${NC}"
    echo ""
    
    if [[ "$PROXY_DETECTED" == "true" ]]; then
        echo -e "${YELLOW}⚠️  代理/VPN环境: ${PROXY_REASON}${NC}"
        echo -e "${YELLOW}   延迟数据为端到端体验延迟(TTFB)，非直连延迟${NC}"
        echo ""
    fi
    
    # 显示延迟测试结果摘要
    echo -e "${CYAN}🚀 网站延迟测试摘要:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    local excellent_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "优秀" || true)
    local good_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "良好" || true)
    local poor_count=$(printf '%s\n' "${RESULTS[@]}" | grep -c "较差" || true)
    echo -e "🟢 优秀: ${excellent_count}个  🟡 良好: ${good_count}个  🔴 较差: ${poor_count}个"
    
    # 显示DNS测试结果摘要
    echo ""
    echo -e "${CYAN}🔍 DNS解析测试摘要:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    if [ ${#DNS_RESULTS[@]} -gt 0 ]; then
        # 找出最快的DNS
        local fastest_dns=""
        local fastest_time=9999
        for result in "${DNS_RESULTS[@]}"; do
            if [[ "$result" != *"失败"* ]]; then
                IFS='|' read -r dns_name dns_server resolution_time status <<< "$result"
                local time_val=$(echo "$resolution_time" | sed 's/ms//')
                if [ "$time_val" -lt "$fastest_time" ]; then
                    fastest_time="$time_val"
                    fastest_dns="$dns_name"
                fi
            fi
        done
        
        if [ -n "$fastest_dns" ]; then
            echo -e "🏆 最快DNS: ${GREEN}${fastest_dns}${NC} (${fastest_time}ms)"
        fi
    fi
    
    # 保存综合结果
    local comprehensive_output_file="comprehensive_results_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "# 综合网络测试结果 - $(date)"
        echo ""
        echo "## 网站延迟测试结果"
        echo "# 服务|域名|延迟|状态|IPv4地址|IPv6地址|丢包率|版本"
        printf '%s\n' "${RESULTS[@]}"
        echo ""
        echo "## DNS解析速度测试结果"
        echo "# DNS服务商|DNS服务器|解析时间|状态"
        printf '%s\n' "${DNS_RESULTS[@]}"
    } > "$comprehensive_output_file"
    
    echo ""
    ui_saved_file "$comprehensive_output_file"
    echo ""
    echo -e "${CYAN}💡 网络优化建议:${NC}"
    echo -e "  1. 延迟优化: 选择延迟最低的服务器"
    echo -e "  2. DNS优化: 使用解析最快的DNS服务器"
    
    echo ""
    if [[ -t 0 ]]; then
        echo -n -e "${YELLOW}按 Enter 键返回主菜单...${NC}"
        read -r
    else
        echo -e "${YELLOW}综合测试完成！${NC}"
        exit 0
    fi
}

# 检查并安装依赖（跨平台兼容）
