#!/bin/bash
# 网络延迟检测工具 - 一键安装脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 网络延迟检测工具 - 一键安装${NC}"
echo "============================================================"

# 检查依赖
echo -e "${BLUE}📋 检查系统依赖...${NC}"
missing_deps=()

if ! command -v curl >/dev/null 2>&1; then
    if ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("curl 或 wget")
    fi
fi

if ! command -v ping >/dev/null 2>&1; then
    missing_deps+=("ping")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}❌ 缺少依赖: ${missing_deps[*]}${NC}"
    echo "请先安装:"
    echo "Ubuntu/Debian: sudo apt update && sudo apt install curl iputils-ping"
    echo "CentOS/RHEL:   sudo yum install curl iputils"
    exit 1
fi

echo -e "${GREEN}✅ 依赖检查通过${NC}"

# 下载脚本
echo -e "${BLUE}📥 下载延迟检测工具...${NC}"
temp_file=$(mktemp)

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://raw.githubusercontent.com/Cd1s/network-latency-tester/main/latency.sh" -o "$temp_file"
elif command -v wget >/dev/null 2>&1; then
    wget -q "https://raw.githubusercontent.com/Cd1s/network-latency-tester/main/latency.sh" -O "$temp_file"
fi

if [[ ! -s "$temp_file" ]]; then
    echo -e "${RED}❌ 下载失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 下载成功${NC}"

# 安装到本地
local_file="latency.sh"
echo -e "${BLUE}💾 安装到当前目录...${NC}"
cp "$temp_file" "$local_file"
chmod +x "$local_file"

# 清理临时文件
rm -f "$temp_file"

echo -e "${GREEN}✅ 安装完成！${NC}"
echo ""
echo -e "${CYAN}🚀 启动网络延迟检测工具...${NC}"
echo ""

# 直接运行
./"$local_file"
