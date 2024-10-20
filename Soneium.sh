#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

# 函数：更新系统包和安装基础工具
update_system() {
    echo -e "${GREEN}更新系统包并安装基本工具...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl git jq build-essential gcc unzip wget lz4 -y
    echo -e "${GREEN}系统更新和工具安装完成！${NC}"
}

# 函数：安装 Docker 和 Docker Compose
install_docker() {
    echo -e "${GREEN}安装 Docker...${NC}"
    sudo apt install docker.io -y
    docker --version

    echo -e "${GREEN}安装 Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version

    echo -e "${GREEN}Docker 和 Docker Compose 安装完成！${NC}"
}

# 函数：克隆 GitHub 仓库并生成 JWT 秘钥
setup_node() {
    echo -e "${GREEN}克隆 GitHub 仓库...${NC}"
    git clone https://github.com/Soneium/soneium-node.git
    cd soneium-node/minato || exit
    echo -e "${GREEN}生成 JWT 秘钥...${NC}"
    openssl rand -hex 32 > jwt.txt
    echo -e "${GREEN}JWT 秘钥生成完成！${NC}"
}

# 函数：配置环境变量
configure_env() {
    if [ ! -f ".env" ];then
        echo -e "${GREEN}创建并配置 .env 文件...${NC}"
        read -p "请输入 L1_URL (例如: https://ethereum-sepolia-rpc.publicnode.com): " L1_URL
        read -p "请输入 L1_BEACON (例如: https://ethereum-sepolia-beacon-api.publicnode.com): " L1_BEACON
        read -p "请输入您的 VPS IP 地址: " P2P_IP
        read -p "请输入 L2_URL (默认: http://localhost:9545): " L2_URL
        read -p "请输入 L1_TRUST_RPC (true/false, 默认: true): " L1_TRUST_RPC
        read -p "请输入 RPC 地址 (默认: 127.0.0.1): " RPC_ADDR
        read -p "请输入 RPC 端口 (默认: 9545): " RPC_PORT
        read -p "请选择 SYNC_MODE (consensus-layer 或 execution-layer, 默认: consensus-layer): " SYNC_MODE

        # 如果用户没有输入特定值，使用默认值
        L2_URL=${L2_URL:-"http://localhost:9545"}
        L1_TRUST_RPC=${L1_TRUST_RPC:-"true"}
        RPC_ADDR=${RPC_ADDR:-"127.0.0.1"}
        RPC_PORT=${RPC_PORT:-"9545"}
        SYNC_MODE=${SYNC_MODE:-"consensus-layer"}

        # 确保 P2P 相关的路径也已设置
        P2P_PRIV_PATH=${P2P_PRIV_PATH:-"/root/.p2p_priv"}
        P2P_DISCOVERY_PATH=${P2P_DISCOVERY_PATH:-"/root/.p2p_discovery"}
        P2P_PEERSTORE_PATH=${P2P_PEERSTORE_PATH:-"/root/.p2p_peerstore"}

        cat <<EOL > .env
L1_URL=${L1_URL}
L1_BEACON=${L1_BEACON}
P2P_ADVERTISE_IP=${P2P_IP}
L2_URL=${L2_URL}
L2_JWT_SECRET=jwt.txt
L1_TRUST_RPC=${L1_TRUST_RPC}
RPC_ADDR=${RPC_ADDR}
RPC_PORT=${RPC_PORT}
SYNC_MODE=${SYNC_MODE}
P2P_PRIV_PATH=${P2P_PRIV_PATH}
P2P_DISCOVERY_PATH=${P2P_DISCOVERY_PATH}
P2P_PEERSTORE_PATH=${P2P_PEERSTORE_PATH}
L1_RPC_KIND=geth
METRICS_ENABLED=false
METRICS_PORT=9100
OP_NODE_P2P_PEER_BANNING=false
ROLLUP_CONFIG=你的Rollup配置文件路径
EOL

        echo -e "${GREEN}.env 文件已创建并配置！${NC}"
    else
        echo -e "${RED}.env 文件已存在，跳过配置！${NC}"
    fi
}

# 函数：配置 Docker Compose 文件
configure_docker_compose() {
    if [ -f "docker-compose.yml" ];then
        echo -e "${GREEN}配置 docker-compose.yml 文件...${NC}"
        read -p "请输入您的 VPS IP 地址以替换 <your_node_ip_address>: " NODE_IP
        sed -i "s/<your_node_ip_address>/${NODE_IP}/g" docker-compose.yml
        echo -e "${GREEN}docker-compose.yml 文件配置完成！${NC}"
    else
        echo -e "${RED}docker-compose.yml 文件未找到！${NC}"
    fi
}

# 函数：启动 Docker 容器
start_docker_containers() {
    echo -e "${GREEN}启动 Docker 容器...${NC}"
    docker-compose up -d
    echo -e "${GREEN}Docker 容器启动完成！${NC}"
}

# 函数：查看日志
check_logs() {
    echo -e "${GREEN}请选择要查看日志的容器:${NC}"
    echo "1) op-node-minato"
    echo "2) op-geth-minato"
    echo "3) 返回主菜单"
    read -rp "输入您的选择: " log_choice

    case $log_choice in
    1)
        echo -e "${GREEN}查看 op-node-minato 日志...${NC}"
        docker-compose logs -f op-node-minato
        ;;
    2)
        echo -e "${GREEN}查看 op-geth-minato 日志...${NC}"
        docker-compose logs -f op-geth-minato
        ;;
    3)
        main_menu
        ;;
    *)
        echo -e "${RED}无效选择！${NC}"
        ;;
    esac
}

# 主菜单函数
main_menu() {
    while true;do
        echo -e "${GREEN}--- 节点设置主菜单 ---${NC}"
        echo "1) 更新系统包和安装基础工具"
        echo "2) 安装 Docker 和 Docker Compose"
        echo "3) 克隆 GitHub 仓库并生成 JWT 秘钥"
        echo "4) 配置 .env 文件"
        echo "5) 配置 docker-compose.yml 文件"
        echo "6) 启动 Docker 容器"
        echo "7) 查看容器日志"
        echo "8) 退出"
        read -rp "请选择操作 (输入数字): " choice

        case $choice in
        1)
            update_system
            ;;
        2)
            install_docker
            ;;
        3)
            setup_node
            ;;
        4)
            configure_env
            ;;
        5)
            configure_docker_compose
            ;;
        6)
            start_docker_containers
            ;;
        7)
            check_logs
            ;;
        8)
            echo -e "${GREEN}退出脚本。再见！${NC}"
            exit
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入！${NC}"
            ;;
        esac
    done
}

# 启动主菜单
main_menu

