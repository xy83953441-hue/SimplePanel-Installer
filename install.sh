#!/bin/bash

# =================================================
# SimplePanel 一键安装脚本
# GitHub: https://github.com/XY83953441-Hue/SimplePanel-Installer
# =================================================

set -euo pipefail  # 严格模式

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# 加载库函数
source "${LIB_DIR}/core.sh"
source "${LIB_DIR}/system.sh"
source "${LIB_DIR}/network.sh"
source "${LIB_DIR}/service.sh"

# 全局配置
readonly GITHUB_USER="XY83953441-Hue"
readonly GITHUB_REPO="SimplePanel"
readonly INSTALL_DIR="/usr/local/simple-panel"
readonly CONFIG_DIR="/etc/simple-panel"
readonly SERVICE_NAME="simple-panel"

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

# 仅当脚本直接执行时运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi