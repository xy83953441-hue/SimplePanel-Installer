# SimplePanel 安装器

一个功能强大、易于使用的 SimplePanel 一键安装脚本。

## 功能特性

- 🚀 **一键安装** - 简单快速的安装过程
- 🔄 **自动更新** - 支持版本检查和自动更新
- 🛡️ **安全配置** - 随机生成用户名、密码和端口
- 🔥 **防火墙配置** - 自动配置常见防火墙
- 📊 **服务管理** - 完整的 systemd 服务支持
- 💾 **数据备份** - 更新前自动备份数据
- 🎨 **友好界面** - 彩色输出和交互式菜单

## 系统支持

- Ubuntu 18.04+
- Debian 10+
- CentOS 8+
- RHEL 8+
- 其他主流 Linux 发行版

## 架构支持

- x86_64 (amd64)
- ARM64
- ARMv7
- ARMv6

## 快速开始

### 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/XY83953441-Hue/SimplePanel-Installer/main/install.sh | bash
```

### 手动安装

1. 克隆仓库：
```bash
git clone https://github.com/XY83953441-Hue/SimplePanel-Installer.git
cd SimplePanel-Installer
```

2. 运行安装脚本：
```bash
bash install.sh install
```

## 使用方法

### 命令行参数

```bash
# 安装 SimplePanel
bash install.sh install

# 更新 SimplePanel
bash install.sh update

# 卸载 SimplePanel
bash install.sh uninstall

# 查看服务状态
bash install.sh status

# 显示帮助信息
bash install.sh help
```

### 交互式菜单

直接运行脚本进入交互式菜单：

```bash
bash install.sh
```

## 项目结构

```
SimplePanel-Installer/
├── install.sh                 # 主安装脚本
├── README.md                  # 项目说明
├── LICENSE                    # MIT许可证
└── lib/                       # 库函数
    ├── core.sh                # 核心函数
    ├── system.sh              # 系统检测函数
    ├── network.sh             # 网络相关函数
    └── service.sh             # 服务管理函数
```

## 安装信息

安装完成后，面板信息会保存在 `/root/simple-panel-info.txt` 文件中，包括：

- 面板访问地址
- 用户名和密码
- 管理命令
- 文件位置

## 服务管理

```bash
# 启动服务
systemctl start simple-panel

# 停止服务
systemctl stop simple-panel

# 重启服务
systemctl restart simple-panel

# 查看状态
systemctl status simple-panel

# 查看日志
journalctl -u simple-panel -f
```

## 文件位置

- **程序文件**: `/usr/local/simple-panel/`
- **配置文件**: `/etc/simple-panel/`
- **数据文件**: `/usr/local/simple-panel/data.db`
- **日志文件**: `/var/log/simple-panel.log`
- **服务文件**: `/etc/systemd/system/simple-panel.service`

## 安全说明

- 安装过程中会随机生成端口（50000-60000）
- 用户名和密码随机生成，确保安全性
- 支持自定义访问路径，提高安全性
- 自动配置防火墙规则

## 故障排除

### 常见问题

1. **权限问题**
   ```bash
   sudo bash install.sh install
   ```

2. **网络连接问题**
   - 检查网络连接
   - 确认可以访问 GitHub

3. **服务启动失败**
   ```bash
   journalctl -u simple-panel -f
   ```

### 日志查看

```bash
# 查看安装日志
tail -f /var/log/simple-panel.log

# 查看 systemd 日志
journalctl -u simple-panel -f
```

## 开发说明

### 模块化设计

项目采用模块化设计，每个模块职责单一：

- **core.sh**: 核心工具函数
- **system.sh**: 系统检测和依赖安装
- **network.sh**: 网络下载和版本管理
- **service.sh**: 服务管理和配置

### 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 发起 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 支持

如果您遇到问题或有建议，请：

1. 查看 [Issues](https://github.com/XY83953441-Hue/SimplePanel-Installer/issues)
2. 创建新的 Issue
3. 提供详细的错误信息和系统环境

## 更新日志

### v1.0.0
- 初始版本发布
- 支持一键安装、更新、卸载
- 模块化设计
- 完整的错误处理和日志记录