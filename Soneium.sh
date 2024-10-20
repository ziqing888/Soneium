#!/bin/bash

# 定义日志文件路径
LOG_FILE="/var/log/minato_node_setup.log"

# 定义颜色代码和样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# 定义图标
INFO_ICON="ℹ️"
SUCCESS_ICON="✅"
WARNING_ICON="⚠️"
ERROR_ICON="❌"

# 日志函数
log_info() {
    echo -e "${BLUE}${INFO_ICON} ${1}${RESET}"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - ${1}" >> $LOG_FILE
}

log_success() {
    echo -e "${GREEN}${SUCCESS_ICON} ${1}${RESET}"
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - ${1}" >> $LOG_FILE
}

log_warning() {
    echo -e "${YELLOW}${WARNING_ICON} ${1}${RESET}"
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - ${1}" >> $LOG_FILE
}

log_error() {
    echo -e "${RED}${ERROR_ICON} ${1}${RESET}"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - ${1}" >> $LOG_FILE
}

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne "0" ]; then
    log_error "请以 root 用户或使用 sudo 运行此脚本"
    exit 1
fi

# 检查并安装 Docker 和 Docker Compose
function check_install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Docker 未安装，正在安装 Docker..."
        apt-get update
        apt-get install -y docker.io
        systemctl start docker
        systemctl enable docker
        log_success "Docker 安装完成。"
    else
        log_success "Docker 已安装。"
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_info "Docker Compose 未安装，正在安装 Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose 安装完成。"
    else
        log_success "Docker Compose 已安装。"
    fi
}

# 生成 JWT 密钥并配置节点
function setup_node() {
    log_info "正在更新系统并安装必要的软件包..."
    apt-get update
    apt-get install -y wget git openssl || { log_error "软件包安装失败"; exit 1; }

    # 检查并安装 Docker 和 Docker Compose
    check_install_docker

    log_info "正在生成 JWT 密钥..."
    openssl rand -hex 32 > jwt.txt || { log_error "JWT 密钥生成失败"; exit 1; }
    log_success "JWT 密钥已生成并保存在 jwt.txt 文件中。"

    # 克隆 GitHub 存储库并进入工作目录
    if [ -d "soneium-node" ]; then
        log_warning "检测到之前的节点仓库，正在删除..."
        rm -rf soneium-node
    fi

    log_info "正在克隆 Soneium 节点存储库..."
    git clone https://github.com/Soneium/soneium-node.git || { log_error "仓库克隆失败"; exit 1; }
    cd soneium-node/minato || { log_error "进入目录失败"; exit 1; }
    log_success "仓库克隆成功并进入 minato 目录"

    log_info "正在重命名配置文件..."
    mv sample.env .env || { log_error ".env 文件重命名失败"; exit 1; }

    # 直接设置 L1_URL 和 L1_BEACON
    L1_URL="https://ethereum-sepolia-rpc.publicnode.com"
    L1_BEACON="https://ethereum-sepolia-beacon-api.publicnode.com"
    
    # 提示用户输入 VPS IP 地址
    read -p "请输入你的 VPS IP 地址: " VPS_IP

    log_info "配置 .env 文件..."
    sed -i "s|L1_URL=.*|L1_URL=$L1_URL|" .env
    sed -i "s|L1_BEACON=.*|L1_BEACON=$L1_BEACON|" .env
    sed -i "s|P2P_ADVERTISE_IP=.*|P2P_ADVERTISE_IP=$VPS_IP|" .env
    log_success ".env 文件配置完成"

    log_info "配置 docker-compose.yml 文件..."
    sed -i "s|<your_node_public_ip>|$VPS_IP|" docker-compose.yml || { log_error "docker-compose.yml 文件配置失败"; exit 1; }
    log_success "docker-compose.yml 文件配置完成"

    log_info "正在启动节点..."
    docker-compose up -d || { log_error "节点启动失败"; exit 1; }
    log_success "节点启动完成"
}

# 查看节点日志
function view_logs() {
    log_info "正在查看节点日志..."
    echo -e "${YELLOW}按 Ctrl+C 退出日志查看，返回主菜单${RESET}"
    docker-compose logs -f op-node-minato &
    docker-compose logs -f op-geth-minato &
    wait # 让用户手动 Ctrl+C 退出日志查看
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo -e "${BOLD}Minato 节点自动化安装脚本${RESET}"
        echo "==========================="
        echo "1. 生成 JWT 密钥并安装节点"
        echo "2. 启动节点"
        echo "3. 查看日志"
        echo "4. 退出"
        echo "==========================="
        read -p "请选择一个选项 (1-4): " choice

        case $choice in
            1)
                setup_node
                ;;
            2)
                view_logs
                ;;
            3)
                view_logs
                ;;
            4)
                log_info "退出脚本，感谢使用！"
                exit 0
                ;;
            *)
                log_warning "无效的选项，请重新输入。"
                read -p "按 Enter 继续..."
                ;;
        esac
    done
}

# 启动主菜单
main_menu
