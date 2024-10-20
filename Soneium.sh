#!/bin/bash

# 定义日志文件路径
LOG_FILE="/var/log/dusk_script.log"

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

# 检查脚本是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    log_error "请以 root 权限运行此脚本"
    exit 1
fi

# 菜单函数
show_menu() {
    clear
    echo -e "${BOLD}请选择一个选项:${RESET}"
    echo "1) 安装并配置节点 (包含系统更新、工具安装、Docker安装等)"
    echo "2) 启动 Docker 容器"
    echo "3) 检查日志"
    echo "4) 退出"
    echo -n "请输入你的选择: "
    read choice
    case $choice in
        1) install_and_setup_node ;;
        2) start_docker ;;
        3) check_logs ;;
        4) exit 0 ;;
        *) log_warning "无效选项，请重新选择。" ; show_menu ;;
    esac
}

# 安装并配置节点（更新系统、安装基础工具、安装 Docker 和 Docker Compose、配置节点）
install_and_setup_node() {
    log_info "更新系统包..."
    sudo apt update && sudo apt upgrade -y
    log_success "系统包更新完成"

    log_info "安装基础工具..."
    sudo apt install -y curl git jq build-essential gcc unzip wget lz4
    log_success "基础工具安装完成"

    log_info "安装 Docker..."
    sudo apt install -y docker.io
    docker --version || { log_error "Docker 未正确安装"; exit 1; }
    log_success "Docker 安装完成"

    log_info "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version || { log_error "Docker Compose 未正确安装"; exit 1; }
    log_success "Docker Compose 安装完成"

    log_info "克隆 GitHub 仓库..."
    if [ -d "soneium-node" ]; then
        log_warning "soneium-node 目录已存在，跳过克隆。"
    else
        git clone https://github.com/Soneium/soneium-node.git || { log_error "仓库克隆失败"; exit 1; }
    fi
    cd soneium-node/minato || { log_error "目录切换失败"; exit 1; }
    log_success "仓库克隆成功并进入 minato 目录"

    log_info "生成 JWT 密钥..."
    openssl rand -hex 32 > jwt.txt || { log_error "JWT 密钥生成失败"; exit 1; }
    log_success "JWT 密钥已生成"

    log_info "重命名 sample.env 为 .env..."
    mv sample.env .env || { log_error ".env 文件重命名失败"; exit 1; }

    # 固定的 Minato 网络的 RPC 端点和 Beacon API 端点
    L1_URL="https://rpc.minato.soneium.org/"
    L1_BEACON="https://explorer-testnet.soneium.org/"
    read -p "请输入你的 VPS 公共 IP 地址: " VPS_IP

    log_info "配置 .env 文件..."
    sed -i "s|L1_URL=.*|L1_URL=$L1_URL|" .env
    sed -i "s|L1_BEACON=.*|L1_BEACON=$L1_BEACON|" .env
    sed -i "s|P2P_ADVERTISE_IP=.*|P2P_ADVERTISE_IP=$VPS_IP|" .env
    log_success ".env 文件配置完成"

    log_info "配置 docker-compose.yml 文件..."
    if [ ! -f docker-compose.yml ]; then
        log_error "docker-compose.yml 文件未找到。请检查路径是否正确。"
        exit 1
    fi

    # 替换 <your_node_ip_address> 为用户输入的实际 IP 地址
    sed -i "s|<your_node_ip_address>|$VPS_IP|" docker-compose.yml || { log_error "替换 docker-compose.yml 中的 IP 地址失败"; exit 1; }

    # 确保 command 或 entrypoint 部分存在并插入 --nat=extip 参数
    if grep -q "command:" docker-compose.yml; then
        sed -i "/command:/a \ \ \ \ --nat=extip=$VPS_IP" docker-compose.yml || { log_error "在 command 中插入 --nat=extip 参数失败。"; exit 1; }
    elif grep -q "entrypoint:" docker-compose.yml; then
        sed -i "/entrypoint:/a \ \ \ \ --nat=extip=$VPS_IP" docker-compose.yml || { log_error "在 entrypoint 中插入 --nat=extip 参数失败。"; exit 1; }
    else
        sed -i "/op-geth-minato/a \ \ \ \ command: --nat=extip=$VPS_IP" docker-compose.yml || { log_error "添加 command 行失败。"; exit 1; }
    fi
    log_success "docker-compose.yml 文件配置完成"

    show_menu
}

# 启动 Docker 容器
start_docker() {
    log_info "验证 docker-compose.yml 文件..."
    docker-compose config || { log_error "docker-compose.yml 文件格式有误。"; exit 1; }

    log_info "启动 Docker 容器..."
    docker-compose up -d || { log_error "Docker 容器启动失败"; exit 1; }
    log_success "Docker 容器启动成功"
    show_menu
}

# 检查日志
check_logs() {
    echo -e "${BOLD}请选择要查看的日志:${RESET}"
    echo "1) 检查 op-node-minato 日志"
    echo "2) 检查 op-geth-minato 日志"
    echo "3) 返回上一级"
    echo -n "请输入你的选择: "
    read log_choice
    case $log_choice in
        1) log_info "检查 op-node-minato 日志..." ; docker-compose logs -f op-node-minato ;;
        2) log_info "检查 op-geth-minato 日志..." ; docker-compose logs -f op-geth-minato ;;
        3) show_menu ;;
        *) log_warning "无效选项，请重新选择。" ; check_logs ;;
    esac
}

# 启动菜单
show_menu
