#!/bin/bash

# 网络相关函数库

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