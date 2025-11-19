#!/bin/bash

# =================================================
# SimplePanel 一键安装脚本
# GitHub: https://github.com/XY83953441-Hue/SimplePanel-Installer
# =================================================

set -e  # 严格模式

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局配置
GITHUB_USER="XY83953441-Hue"
GITHUB_REPO="SimplePanel"
INSTALL_DIR="/usr/local/simple-panel"
CONFIG_DIR="/etc/simple-panel"
SERVICE_NAME="simple-panel"

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
    echo "╔════════════════════════════════════════════════╗"
    echo "║                SimplePanel 安装程序            ║"
    echo "║                简单 • 快速 • 稳定              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 从终端读取输入（修复管道执行问题）
safe_read() {
    if [ -t 0 ]; then
        # 直接运行，使用正常读取
        read "$@"
    else
        # 管道执行，从 /dev/tty 读取
        read "$@" < /dev/tty
    fi
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
    
    echo -e "${BLUE}[信息]${NC} $prompt"
    safe_read -p "请输入选择: " confirm
    
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
    tr -dc "$charset" < /dev/urandom | head -c "$length" 2>/dev/null || echo "default${length}"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检查文件是否存在
file_exists() {
    [[ -f "$1" ]]
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
    
    # 包管理器检测
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
    
    info "操作系统: $OS $OS_VERSION"
    info "系统架构: $ARCH"
    info "包管理器: $PACKAGE_MANAGER"
}

# 预检检查
run_preflight_checks() {
    info "运行预检检查..."
    
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 权限运行此脚本"
        echo "可以使用: sudo bash $0"
        exit 1
    fi
    
    # 检查网络连接
    if ! curl -s --connect-timeout 10 -I https://github.com > /dev/null; then
        error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    detect_system
}

# 安装系统依赖
install_dependencies() {
    info "安装系统依赖..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt update && apt install -y curl wget tar sudo
            ;;
        yum)
            yum install -y curl wget tar sudo
            ;;
        dnf)
            dnf install -y curl wget tar sudo
            ;;
        apk)
            apk update && apk add curl wget tar sudo
            ;;
        pacman)
            pacman -Sy && pacman -S --noconfirm curl wget tar sudo
            ;;
    esac
}

# 获取最新版本
get_latest_version() {
    info "获取最新版本..."
    
    local version
    # 尝试直接获取版本
    version=$(curl -s --connect-timeout 10 "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || true)
    
    if [[ -n "$version" && "$version" != "null" ]]; then
        info "最新版本: $version"
        echo "$version"
        return 0
    fi
    
    warn "无法从GitHub获取最新版本，使用默认版本 v1.0.0"
    echo "v1.0.0"
}

# 创建测试版本的面板程序
create_test_panel() {
    info "创建测试版本的面板程序..."
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 创建一个简单的测试程序
    cat > "$INSTALL_DIR/simple-panel" << 'EOF'
#!/bin/bash

echo "=========================================="
echo "        SimplePanel 测试版本"
echo "=========================================="
echo ""
echo "这是一个测试版本的面板程序"
echo "实际使用时请替换为真实的面板程序"
echo ""
echo "面板运行信息:"
echo "- 配置文件: /etc/simple-panel/config.yaml"
echo "- 数据目录: /usr/local/simple-panel/"
echo "- 日志文件: /var/log/simple-panel.log"
echo ""

# 读取配置
CONFIG_FILE="/etc/simple-panel/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
    PORT=$(grep -E '^\s*port:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    USERNAME=$(grep -E '^\s*username:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    echo "面板端口: $PORT"
    echo "管理员: $USERNAME"
    echo ""
    echo "请访问: http://你的服务器IP:$PORT/"
fi

echo "按 Ctrl+C 退出"
while true; do
    echo "$(date): SimplePanel 运行中..." >> /var/log/simple-panel.log
    sleep 60
done
EOF

    chmod +x "$INSTALL_DIR/simple-panel"
    echo "v1.0.0" > "$INSTALL_DIR/version.txt"
    
    success "测试面板程序创建完成"
}

# 下载面板程序
download_panel() {
    local version="$1"
    info "下载 SimplePanel $version..."
    
    local download_url="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/$version/simple-panel-linux-$ARCH.tar.gz"
    local temp_file="/tmp/simple-panel.tar.gz"
    
    info "下载地址: $download_url"
    
    # 检查下载URL是否可用
    if ! curl -s --head "$download_url" | grep -q "200 OK"; then
        warn "发布版本不存在，创建测试版本"
        create_test_panel
        return 0
    fi
    
    # 使用 curl 下载文件（兼容性更好）
    info "正在下载..."
    if ! curl -fSL -o "$temp_file" "$download_url"; then
        error "下载失败: $download_url"
        error "这可能是因为:"
        error "  1. 网络连接问题"
        error "  2. 该版本不存在" 
        error "  3. GitHub 访问限制"
        error ""
        warn "将创建测试版本继续安装"
        create_test_panel
        return 0
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
    cat > "/root/simple-panel-info.txt" << EOF
==========================================
      SimplePanel 安装信息
==========================================

面板访问信息：
------------------------------------------
面板地址: http://你的服务器IP:${panel_port}${secret_path}
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

    success "配置文件生成完成"
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
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/simple-panel --config $CONFIG_DIR/config.yaml
Restart=on-failure
RestartSec=5s

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
    if command_exists "ufw" && ufw status | grep -q "active"; then
        ufw allow "$panel_port/tcp"
        info "UFW 防火墙已开放端口: $panel_port"
    elif command_exists "firewall-cmd" && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="$panel_port/tcp"
        firewall-cmd --reload
        info "Firewalld 防火墙已开放端口: $panel_port"
    elif command_exists "iptables"; then
        iptables -I INPUT -p tcp --dport "$panel_port" -j ACCEPT
        info "iptables 已开放端口: $panel_port"
        warn "请手动保存 iptables 规则"
    else
        warn "未检测到防火墙，或使用其他防火墙系统"
        info "请确保端口 $panel_port 已开放"
    fi
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
                warn "服务状态异常，但安装已完成"
                warn "请查看日志: journalctl -u $SERVICE_NAME"
            fi
        else
            warn "服务启动命令执行失败，但安装已完成"
        fi
    else
        warn "系统不支持 systemd，请手动启动服务: $INSTALL_DIR/simple-panel"
    fi
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
    
    echo ""
    warn "注意: 当前安装的是测试版本"
    info "请将真实的面板程序替换到: $INSTALL_DIR/simple-panel"
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

# 显示交互菜单
show_interactive_menu() {
    show_banner
    echo "请选择操作:"
    echo ""
    echo "  1) 安装 SimplePanel"
    echo "  2) 更新 SimplePanel"  
    echo "  3) 卸载 SimplePanel"
    echo "  4) 退出"
    echo ""
    
    echo -e "${BLUE}[信息]${NC} 请输入选择 (1-4): "
    safe_read -p ">" choice
    
    case "$choice" in
        1) main_install ;;
        2) 
            warn "更新功能暂未实现"
            exit 0 
            ;;
        3) 
            warn "卸载功能暂未实现" 
            exit 0
            ;;
        4) exit 0 ;;
        *) 
            error "无效选择: $choice"
            exit 1 
            ;;
    esac
}

# 主程序入口
main() {
    local action="${1:-}"
    
    case "$action" in
        install)
            main_install
            ;;
        uninstall)
            warn "卸载功能暂未实现"
            ;;
        update)
            warn "更新功能暂未实现"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_interactive_menu
            ;;
    esac
}

# 检查是否通过管道执行，如果是则自动选择安装
if [[ ! -t 0 ]]; then
    # 通过管道执行，自动选择安装
    log "检测到通过管道执行，开始自动安装..."
    main_install
else
    # 直接执行，显示菜单
    main "$@"
fi
