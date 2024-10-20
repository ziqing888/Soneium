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
    cd soneium-node/minato || exit
    echo "仓库已克隆并进入 minato 目录。"
}

# 函数：生成 JWT 秘钥
generate_jwt() {
    echo "生成 JWT 秘钥..."
    openssl rand -hex 32 > jwt.txt
    echo "JWT 秘钥已生成：jwt.txt"
}

# 函数：编辑 .env 文件
edit_env() {
    echo "准备编辑 .env 文件..."
    mv sample.env .env
    echo "请在 .env 文件中替换以下内容："
    echo "1. RPC 端点: https://ethereum-sepolia-rpc.publicnode.com"
    echo "2. Beacon API 端点: https://ethereum-sepolia-beacon-api.publicnode.com"
    echo "3. P2P_ADVERTISE_IP: <你的 VPS 公共 IP>"
    nano .env
}

# 函数：编辑 docker-compose.yml 文件
edit_docker_compose() {
    echo "准备编辑 docker-compose.yml 文件..."
    echo "请在 docker-compose.yml 文件中替换 <your_node_ip_address> 为你的 VPS 公共 IP。"
    nano docker-compose.yml
}

# 函数：启动 Docker 容器
start_docker() {
    echo "启动 Docker 容器..."
    docker-compose up -d
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
        echo "4. 编辑 .env 文件"
        echo "5. 编辑 docker-compose.yml 文件"
        echo "6. 启动 Docker 容器"
        echo "7. 查看 Docker 日志"
        echo "8. 退出"
        echo "=============================="
        read -rp "请输入您的选择: " choice

        case $choice in
            1) install_docker ;;
            2) clone_repo ;;
            3) generate_jwt ;;
            4) edit_env ;;
            5) edit_docker_compose ;;
            6) start_docker ;;
            7) check_logs ;;
            8) echo "退出脚本。" ; exit ;;
            *) echo "无效的选择，请重试。" ;;
        esac
    done
}

# 启动主菜单
main_menu
