#!/bin/bash

# =================================================
# SimplePanel 一键安装脚本
# GitHub: https://github.com/XY83953441-Hue/SimplePanel-Installer
# =================================================

set -euo pipefail  # 严格模式

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 全局配置
readonly GITHUB_USER="XY83953441-Hue"
readonly GITHUB_REPO="SimplePanel"
readonly INSTALL_DIR="/usr/local/simple-panel"
readonly CONFIG_DIR="/etc/simple-panel"
readonly SERVICE_NAME="simple-panel"

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
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/SimplePanel-Installer/main/install.sh | bash

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

# 系统信息
OS=""
OS_VERSION=""
ARCH=""
PACKAGE_MANAGER=""

# 检测系统信息
detect_system() {
    info "检测系统信息..."
    
    # 操作系统检测
    if file_exists "/etc/os-release"; then
        source "/etc/os-release"
        OS="$ID"
        OS_VERSION="$VERSION_ID"
    else
        error "无法检测操作系统"
        exit 1
    fi
    
    # 架构检测
    detect_architecture
    
    # 包管理器检测
    detect_package_manager
    
    info "操作系统: $OS $OS_VERSION"
    info "系统架构: $ARCH"
    info "包管理器: $PACKAGE_MANAGER"
}

# 检测系统架构
detect_architecture() {
    local machine_arch
    machine_arch=$(uname -m)
    
    case "$machine_arch" in
        x86_64|x64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armv7) ARCH="armv7" ;;
        armv6l|armv6) ARCH="armv6" ;;
        *)
            error "不支持的架构: $machine_arch"
            exit 1
            ;;
    esac
}

# 检测包管理器
detect_package_manager() {
    if command_exists "apt"; then
        PACKAGE_MANAGER="apt"
    elif command_exists "yum"; then
        PACKAGE_MANAGER="yum" 
    elif command_exists "dnf"; then
        PACKAGE_MANAGER="dnf"
    elif command_exists "apk"; then
        PACKAGE_MANAGER="apk"
    elif command_exists "pacman"; then
        PACKAGE_MANAGER="pacman"
    else
        error "未找到支持的包管理器"
        exit 1
    fi
}

# 预检检查
run_preflight_checks() {
    info "运行预检检查..."
    
    check_root_privilege
    check_internet_connection
    detect_system
    check_system_compatibility
}

# 检查root权限
check_root_privilege() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 权限运行此脚本"
        info "可以使用: sudo bash $0"
        exit 1
    fi
}

# 检查网络连接
check_internet_connection() {
    if ! curl -s --connect-timeout 10 -I https://github.com > /dev/null; then
        error "网络连接失败，请检查网络设置"
        exit 1
    fi
}

# 检查系统兼容性
check_system_compatibility() {
    case "$OS" in
        ubuntu)
            if [[ "$OS_VERSION" < "18.04" ]]; then
                warn "Ubuntu 版本过低，建议使用 18.04 或更高版本"
            fi
            ;;
        debian)
            if [[ "$OS_VERSION" < "10" ]]; then
                warn "Debian 版本过低，建议使用 10 或更高版本"
            fi
            ;;
        centos|rhel)
            if [[ "$OS_VERSION" < "8" ]]; then
                warn "CentOS/RHEL 版本过低，建议使用 8 或更高版本"
            fi
            ;;
        *)
            warn "未经充分测试的操作系统: $OS"
            ;;
    esac
}

# 安装系统依赖
install_dependencies() {
    info "安装系统依赖..."
    
    local packages=("curl" "wget" "tar" "sudo")
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt update && apt install -y "${packages[@]}"
            ;;
        yum)
            yum install -y "${packages[@]}"
            ;;
        dnf)
            dnf install -y "${packages[@]}"
            ;;
        apk)
            apk update && apk add "${packages[@]}"
            ;;
        pacman)
            pacman -Sy && pacman -S --noconfirm "${packages[@]}"
            ;;
    esac
    
    # 检查是否安装成功
    for pkg in "${packages[@]}"; do
        if ! command_exists "$pkg"; then
            warn "依赖 $pkg 安装失败，继续安装..."
        fi
    done
}

# 获取最新版本
get_latest_version() {
    info "获取最新版本..."
    
    local api_urls=(
        "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
        "https://ghproxy.com/https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    )
    
    for api_url in "${api_urls[@]}"; do
        local version
        if command_exists "jq"; then
            version=$(curl -s --connect-timeout 10 "$api_url" | jq -r '.tag_name' 2>/dev/null)
        else
            version=$(curl -s --connect-timeout 10 "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
        fi
        
        if [[ -n "$version" && "$version" != "null" ]]; then
            info "最新版本: $version"
            echo "$version"
            return 0
        fi
    done
    
    warn "无法从GitHub获取最新版本，使用默认版本 v1.0.0"
    echo "v1.0.0"
}

# 获取当前版本
get_current_version() {
    if file_exists "$INSTALL_DIR/version.txt"; then
        cat "$INSTALL_DIR/version.txt"
    else
        echo "未知"
    fi
}

# 下载面板程序
download_panel() {
    local version="$1"
    info "下载 SimplePanel $version..."
    
    local download_url="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/$version/simple-panel-linux-$ARCH.tar.gz"
    local temp_file="/tmp/simple-panel-$$.tar.gz"
    
    info "下载地址: $download_url"
    
    # 下载文件
    if ! curl -fsSL -o "$temp_file" "$download_url"; then
        error "下载失败: $download_url"
        error "请检查:"
        error "  1. 网络连接"
        error "  2. 版本是否存在" 
        error "  3. GitHub 访问权限"
        exit 1
    fi
    
    # 检查文件大小
    local file_size
    file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 1024 ]]; then
        error "下载的文件大小异常，可能下载失败"
        exit 1
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 解压文件
    if ! tar -xzf "$temp_file" -C "$INSTALL_DIR"; then
        error "解压文件失败"
        exit 1
    fi
    
    # 设置执行权限
    chmod +x "$INSTALL_DIR/simple-panel" 2>/dev/null || true
    
    # 保存版本信息
    echo "$version" > "$INSTALL_DIR/version.txt"
    
    # 清理临时文件
    rm -f "$temp_file"
    
    success "面板程序下载完成"
}

# 获取服务器IP
get_server_ip() {
    info "获取服务器IP地址..."
    
    local ipv4 ipv6
    
    ipv4=$(curl -s4 --connect-timeout 5 ip.sb 2>/dev/null || 
           curl -s4 --connect-timeout 5 icanhazip.com 2>/dev/null || 
           echo "无法获取")
    
    ipv6=$(curl -s6 --connect-timeout 5 ip.sb 2>/dev/null || 
           curl -s6 --connect-timeout 5 icanhazip.com 2>/dev/null || 
           echo "无法获取")
    
    echo "------------------------------------------"
    if [[ "$ipv4" != "无法获取" ]]; then
        info "IPv4 地址: $ipv4"
    fi
    if [[ "$ipv6" != "无法获取" ]]; then
        info "IPv6 地址: $ipv6"
    fi
    echo "------------------------------------------"
}

# 生成随机配置
generate_random_config() {
    info "生成随机配置..."
    
    local panel_port=$((50000 + RANDOM % 10000))
    local username="admin_$(generate_random_string 6 'a-z0-9')"
    local password=$(generate_random_string 16 'A-Za-z0-9')
    local secret_path="/$(generate_random_string 8 'a-z0-9')/"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 生成配置文件
    cat > "$CONFIG_DIR/config.yaml" << EOF
# SimplePanel 配置文件
server:
  port: $panel_port
  host: "0.0.0.0"
  
security:
  username: "$username"
  password: "$password" 
  secret_path: "$secret_path"
  
database:
  path: "$INSTALL_DIR/data.db"
  
log:
  level: "info"
  path: "/var/log/simple-panel.log"
EOF

    # 保存安装信息
    save_installation_info "$panel_port" "$username" "$password" "$secret_path"
    success "配置文件生成完成"
}

# 保存安装信息
save_installation_info() {
    local port="$1" username="$2" password="$3" path="$4"
    
    cat > "/root/simple-panel-info.txt" << EOF
==========================================
      SimplePanel 安装信息
==========================================

面板访问信息：
------------------------------------------
面板地址: http://你的服务器IP:${port}${path}
用户名: $username
密码: $password
------------------------------------------

管理命令：
------------------------------------------
启动面板: systemctl start $SERVICE_NAME
停止面板: systemctl stop $SERVICE_NAME  
重启面板: systemctl restart $SERVICE_NAME
查看状态: systemctl status $SERVICE_NAME
查看日志: journalctl -u $SERVICE_NAME -f
------------------------------------------

文件位置：
------------------------------------------
程序文件: $INSTALL_DIR
配置文件: $CONFIG_DIR
数据文件: $INSTALL_DIR/data.db
日志文件: /var/log/simple-panel.log
------------------------------------------

安装时间: $(date)
==========================================
EOF
}

# 配置系统服务
setup_system_service() {
    info "配置系统服务..."
    
    if ! command_exists "systemctl"; then
        warn "系统不支持 systemd，跳过服务配置"
        return 0
    fi
    
    # 创建服务文件
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=SimplePanel Service
Description=轻量级代理面板管理系统
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/simple-panel --config $CONFIG_DIR/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用开机自启
    systemctl enable "$SERVICE_NAME"
    
    success "系统服务配置完成"
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙..."
    
    if ! file_exists "$CONFIG_DIR/config.yaml"; then
        warn "配置文件不存在，跳过防火墙配置"
        return 0
    fi
    
    local panel_port
    panel_port=$(grep -E '^\s*port:' "$CONFIG_DIR/config.yaml" | awk '{print $2}' | tr -d '"')
    
    if [[ -z "$panel_port" ]]; then
        warn "无法读取端口配置，跳过防火墙配置"
        return 0
    fi
    
    # 尝试配置不同防火墙
    if configure_ufw "$panel_port" || \
       configure_firewalld "$panel_port" || \
       configure_iptables "$panel_port"; then
        success "防火墙配置完成"
    else
        warn "无法自动配置防火墙，请手动开放端口: $panel_port"
    fi
}

# 配置UFW
configure_ufw() {
    local port="$1"
    if command_exists "ufw" && ufw status | grep -q "active"; then
        ufw allow "$port/tcp"
        info "UFW 防火墙已开放端口: $port"
        return 0
    fi
    return 1
}

# 配置Firewalld
configure_firewalld() {
    local port="$1"
    if command_exists "firewall-cmd" && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="$port/tcp"
        firewall-cmd --reload
        info "Firewalld 防火墙已开放端口: $port"
        return 0
    fi
    return 1
}

# 配置iptables
configure_iptables() {
    local port="$1"
    if command_exists "iptables"; then
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
        info "iptables 已开放端口: $port"
        warn "请手动保存 iptables 规则"
        return 0
    fi
    return 1
}

# 启动服务
start_service() {
    info "启动服务..."
    
    if command_exists "systemctl"; then
        if systemctl start "$SERVICE_NAME"; then
            sleep 2
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                success "服务启动成功"
            else
                error "服务启动失败"
                warn "请查看日志: journalctl -u $SERVICE_NAME"
            fi
        else
            error "服务启动命令执行失败"
        fi
    else
        warn "系统不支持 systemd，请手动启动服务"
    fi
}

# 停止服务
stop_service() {
    if command_exists "systemctl"; then
        if systemctl stop "$SERVICE_NAME" 2>/dev/null; then
            info "服务已停止"
        fi
    fi
}

# 显示服务状态
show_service_status() {
    if command_exists "systemctl"; then
        systemctl status "$SERVICE_NAME"
    else
        info "系统不支持 systemd"
    fi
}

# 显示安装结果
show_installation_result() {
    local version="$1"
    
    echo ""
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║             安装完成！                        ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    get_server_ip
    
    if file_exists "/root/simple-panel-info.txt"; then
        echo "安装信息:"
        echo "------------------------------------------"
        grep -E "(面板地址|用户名|密码)" "/root/simple-panel-info.txt" | head -3
        echo "------------------------------------------"
    fi
    
    echo ""
    echo "管理命令:"
    echo "------------------------------------------"
    echo "systemctl start $SERVICE_NAME     # 启动"
    echo "systemctl stop $SERVICE_NAME      # 停止" 
    echo "systemctl restart $SERVICE_NAME   # 重启"
    echo "systemctl status $SERVICE_NAME    # 状态"
    echo "journalctl -u $SERVICE_NAME -f    # 日志"
    echo "------------------------------------------"
    echo ""
    info "安装信息已保存至: /root/simple-panel-info.txt"
}

# 备份数据
backup_data() {
    if file_exists "$INSTALL_DIR/data.db"; then
        local backup_file="/tmp/simple-panel-backup-$(date +%Y%m%d-%H%M%S).db"
        cp "$INSTALL_DIR/data.db" "$backup_file"
        info "数据已备份到: $backup_file"
    fi
}

# 恢复数据
restore_data() {
    local backup_file
    backup_file=$(ls -t /tmp/simple-panel-backup-*.db 2>/dev/null | head -1)
    if [[ -n "$backup_file" && -f "$backup_file" ]]; then
        cp "$backup_file" "$INSTALL_DIR/data.db"
        info "数据已从备份恢复: $backup_file"
    fi
}

# 移除系统服务
remove_system_service() {
    if command_exists "systemctl"; then
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload 2>/dev/null || true
        info "系统服务已移除"
    fi
}

# 移除安装文件
remove_installation_files() {
    rm -rf "$INSTALL_DIR"
    info "程序文件已移除"
}

# 移除配置文件
remove_config_files() {
    rm -rf "$CONFIG_DIR"
    info "配置文件已移除"
}

# 清理残留文件
cleanup_residual_files() {
    rm -f "/root/simple-panel-info.txt"
    rm -f "/var/log/simple-panel.log" 2>/dev/null || true
    info "残留文件已清理"
}

# 主安装流程
main_install() {
    show_banner
    log "开始安装 SimplePanel..."
    
    # 预检检查
    run_preflight_checks
    
    # 安装流程
    local version
    version=$(get_latest_version)
    
    install_dependencies
    download_panel "$version"
    generate_random_config
    setup_system_service
    configure_firewall
    start_service
    
    show_installation_result "$version"
    log "安装完成！"
}

# 卸载流程
main_uninstall() {
    show_banner
    confirm_action "卸载 SimplePanel"
    
    log "开始卸载..."
    
    stop_service
    remove_system_service
    remove_installation_files
    remove_config_files
    cleanup_residual_files
    
    success "SimplePanel 已完全卸载"
}

# 更新流程
main_update() {
    show_banner
    log "检查更新..."
    
    local current_version
    current_version=$(get_current_version)
    local latest_version
    latest_version=$(get_latest_version)
    
    if [[ "$current_version" == "$latest_version" ]]; then
        success "已经是最新版本: $latest_version"
        return 0
    fi
    
    confirm_action "更新到版本 $latest_version"
    
    log "开始更新..."
    backup_data
    stop_service
    download_panel "$latest_version"
    restore_data
    start_service
    
    success "更新完成: $current_version → $latest_version"
}

# 主程序入口
main() {
    local action="${1:-}"
    
    case "$action" in
        install)
            main_install
            ;;
        uninstall)
            main_uninstall
            ;;
        update)
            main_update
            ;;
        status)
            show_service_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_interactive_menu
            ;;
    esac
}

# 修复管道执行问题：检查是否通过管道执行
if [[ -t 0 ]]; then
    # 直接执行
    main "$@"
else
    # 通过管道执行，移除严格模式中的 -u 选项以避免未绑定变量错误
    set -eo pipefail
    main "$@"
fi
