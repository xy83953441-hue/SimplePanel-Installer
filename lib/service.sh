#!/bin/bash

# 服务管理函数库

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