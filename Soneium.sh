#!/bin/bash

# 函数：安装 Docker 和 Docker Compose
install_docker() {
    echo "更新系统并安装 Docker..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install docker.io -y

    echo "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # 检查 Docker 和 Docker Compose 版本
    docker --version
    docker-compose --version
    echo "Docker 和 Docker Compose 已安装。"
}

# 函数：克隆 GitHub 仓库
clone_repo() {
    echo "克隆 Soneium 仓库..."
    git clone https://github.com/Soneium/soneium-node.git
    cd soneium-node/minato || exit 1
    echo "仓库已克隆并进入 minato 目录。"
}

# 函数：生成 JWT 秘钥并存储到 /etc/optimism/jwt.txt
generate_jwt() {
    echo "生成 JWT 秘钥..."
    
    # 生成 JWT 秘钥
    openssl rand -hex 32 > jwt.txt

    # 验证 JWT 是否为 32 字节的十六进制
    jwt_value=$(cat jwt.txt)
    
    # 添加调试信息
    echo "生成的 JWT 秘钥为: $jwt_value"
    
    if [[ ${#jwt_value} -ne 64 ]]; then
        echo "错误：JWT 秘钥格式无效。生成的密钥不是 32 字节的十六进制格式。"
        echo "请重新运行生成 JWT 秘钥的选项。"
        return 1  # 返回主菜单，不退出脚本
    fi

    # 创建目标目录并移动 JWT 秘钥
    sudo mkdir -p /etc/optimism
    sudo mv jwt.txt /etc/optimism/jwt.txt
    echo "JWT 秘钥已生成并存储在 /etc/optimism/jwt.txt"
}

# 函数：配置 .env 文件并自动设置 RPC、Beacon API 和 P2P_ADVERTISE_IP
configure_env() {
    echo "配置 .env 文件..."
    mv sample.env .env

    # 直接固定 RPC 和 Beacon API 端点
    sed -i 's|^L1_URL=.*|L1_URL=https://ethereum-sepolia-rpc.publicnode.com|' .env
    sed -i 's|^L1_BEACON=.*|L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com|' .env

    # 读取用户的 VPS 公共 IP 地址
    read -rp "请输入您的 VPS 公共 IP 地址: " vps_ip

    # 替换 .env 文件中的 P2P_ADVERTISE_IP
    sed -i "s|^P2P_ADVERTISE_IP=.*|P2P_ADVERTISE_IP=${vps_ip}|" .env

    echo ".env 文件已更新，包含固定的 RPC 端点和用户提供的 VPS IP。"
}

# 函数：自动替换 docker-compose.yml 文件中的 <your_node_ip_address> 为 VPS 公共 IP
edit_docker_compose() {
    # 读取用户的 VPS 公共 IP 地址
    read -rp "请输入您的 VPS 公共 IP 地址: " vps_ip

    # 替换 docker-compose.yml 文件中的 <your_node_ip_address>
    sed -i "s|<your_node_ip_address>|${vps_ip}|" docker-compose.yml

    echo "docker-compose.yml 文件中的 <your_node_ip_address> 已替换为 ${vps_ip}。"
}

# 函数：启动 Docker 容器并检查网络状态
start_docker() {
    echo "启动 Docker 容器..."
    docker-compose up -d

    # 检查 Docker 服务状态
    docker-compose ps

    echo "检查 Docker 网络状态..."
    docker network ls

    echo "Docker 容器已启动。"
}

# 函数：查看日志
check_logs() {
    echo "选择要查看的日志类型："
    echo "1. 查看 op-node-minato 日志"
    echo "2. 查看 op-geth-minato 日志"
    read -rp "输入选择的编号: " log_choice

    case $log_choice in
        1)
            echo "正在查看 op-node-minato 日志..."
            docker-compose logs -f op-node-minato
            ;;
        2)
            echo "正在查看 op-geth-minato 日志..."
            docker-compose logs -f op-geth-minato
            ;;
        *)
            echo "无效的选择，请重试。"
            ;;
    esac
}

# 主菜单函数
main_menu() {
    while true; do
        echo "=============================="
        echo "   Minato 节点设置主菜单"
        echo "=============================="
        echo "1. 安装 Docker 和 Docker Compose"
        echo "2. 克隆 Soneium GitHub 仓库"
        echo "3. 生成 JWT 秘钥"
        echo "4. 配置 .env 文件"
        

