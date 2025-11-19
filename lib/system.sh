#!/bin/bash

# 系统检测函数库

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