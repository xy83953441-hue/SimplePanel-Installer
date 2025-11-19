#!/bin/bash

# 核心函数库

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[信息]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[警告]${NC} $1" >&2
}

error() {
    echo -e "${RED}[错误]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[成功]${NC} $1" >&2
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════╗
║                SimplePanel 安装程序            ║
║                简单 • 快速 • 稳定              ║
╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 确认操作
confirm_action() {
    local action="$1"
    local default="${2:-Y}"
    local prompt="确定要${action}吗？"
    
    if [[ "$default" == "Y" ]]; then
        prompt="${prompt} [Y/n]"
    else
        prompt="${prompt} [y/N]"
    fi
    
    read -rp "$(info "$prompt") " confirm
    
    if [[ "$default" == "Y" ]]; then
        [[ "$confirm" =~ ^[Nn]$ ]] && exit 0
    else
        [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0
    fi
}

# 生成随机字符串
generate_random_string() {
    local length="$1"
    local charset="${2:-a-zA-Z0-9}"
    tr -dc "$charset" < /dev/urandom | head -c "$length"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检查文件是否存在
file_exists() {
    [[ -f "$1" ]]
}

# 检查目录是否存在
dir_exists() {
    [[ -d "$1" ]]
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [命令]

命令:
  install     安装 SimplePanel
  uninstall   卸载 SimplePanel  
  update      更新 SimplePanel
  status      查看服务状态
  help        显示此帮助信息

示例:
  $0 install     # 安装面板
  $0 update      # 更新面板
  $0 uninstall   # 卸载面板

一键安装:
  curl -fsSL https://raw.githubusercontent.com/XY83953441-Hue/SimplePanel-Installer/main/install.sh | bash

EOF
}

# 显示交互菜单
show_interactive_menu() {
    show_banner
    cat << EOF
请选择操作:

  1) 安装 SimplePanel
  2) 更新 SimplePanel  
  3) 卸载 SimplePanel
  4) 查看服务状态
  5) 退出

EOF
    read -rp "$(info "请输入选择 (1-5): ")" choice
    
    case "$choice" in
        1) main_install ;;
        2) main_update ;;
        3) main_uninstall ;;
        4) show_service_status ;;
        5) exit 0 ;;
        *) error "无效选择" && exit 1 ;;
    esac
}