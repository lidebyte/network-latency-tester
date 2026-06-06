# shellcheck shell=bash
# Shared state for network-latency-tester.

# 颜色定义
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
PURPLE=$'\033[0;35m'
NC=$'\033[0m'

# 全局临时文件注册表（用于 trap 清理）
_TEMP_FILES=()
_TEMP_DIRS=()

# 配置变量
PING_COUNT=10
DNS_TEST_DOMAIN="google.com"
IP_VERSION=""
SELECTED_DNS_SERVER=""
SELECTED_DNS_NAME=""
CONCURRENCY_LIMIT="${LATENCY_CONCURRENCY:-6}"

# 输出文件配置
OUTPUT_FILE=""  # 输出文件路径
OUTPUT_FORMAT="text"  # 输出格式: text/markdown/html/json
ENABLE_OUTPUT=true  # 是否启用文件输出
SINGLE_RESULT_PAGE=false  # 是否生成单页结果

# Telegram测试缓存
TELEGRAM_BEST_IP=""  # Telegram最佳IP
TELEGRAM_BEST_DC=""  # Telegram最佳DC号
TELEGRAM_BEST_LATENCY=""  # Telegram最佳延迟
TELEGRAM_BEST_LOSS=""  # Telegram丢包率

# 代理/VPN检测
PROXY_DETECTED=false
PROXY_REASON=""
PROXY_SHARED_IP=""
OS_TYPE="unknown"

# 完整网站列表（20个）
declare -A FULL_SITES=(
    ["Google"]="google.com"
    ["GitHub"]="github.com"
    ["Apple"]="apple.com"
    ["Microsoft"]="m365.cloud.microsoft"
    ["AWS"]="aws.amazon.com"
    ["X"]="x.com"
    ["ChatGPT"]="openai.com"
    ["Claude"]="claude.ai"
    ["Steam"]="steampowered.com"
    ["NodeSeek"]="nodeseek.com"
    ["Netflix"]="fast.com"
    ["Disney"]="disneyplus.com"
    ["Instagram"]="instagram.com"
    ["Telegram"]="telegram_dc_test"
    ["OneDrive"]="onedrive.live.com"
    ["Twitch"]="twitch.tv"
    ["Pornhub"]="pornhub.com"
    ["YouTube"]="youtube.com"
    ["Facebook"]="facebook.com"
    ["TikTok"]="tiktok.com"
)

# DNS服务器列表（全球常用）
declare -A DNS_SERVERS=(
    ["系统DNS"]="system"
    ["Google DNS"]="8.8.8.8"
    ["Google备用"]="8.8.4.4"
    ["Cloudflare DNS"]="1.1.1.1"
    ["Cloudflare备用"]="1.0.0.1"
    ["Quad9 DNS"]="9.9.9.9"
    ["Quad9备用"]="149.112.112.112"
    ["OpenDNS"]="208.67.222.222"
    ["OpenDNS备用"]="208.67.220.220"
    ["AdGuard DNS"]="94.140.14.14"
    ["AdGuard备用"]="94.140.15.15"
    ["Comodo DNS"]="8.26.56.26"
    ["Comodo备用"]="8.20.247.20"
    ["Level3 DNS"]="4.2.2.1"
    ["Level3备用"]="4.2.2.2"
    ["Verisign DNS"]="64.6.64.6"
    ["Verisign备用"]="64.6.65.6"
)

# 结果数组
RESULTS=()
DNS_RESULTS=()
PARALLEL_OUTPUT_FILES=()
