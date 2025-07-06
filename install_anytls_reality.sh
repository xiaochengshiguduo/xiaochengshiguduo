#!/bin/bash

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root用户运行此脚本！"
  exit 1
fi

# 安装必要依赖
apt-get update
apt-get install -y curl unzip jq

# 下载并安装sing-box
LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
ARCH=$(uname -m)
case $ARCH in
  "x86_64") ARCH="amd64" ;;
  "aarch64") ARCH="arm64" ;;
  *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

wget "https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-$LATEST_VERSION-linux-$ARCH.tar.gz" -O sing-box.tar.gz
tar -xzf sing-box.tar.gz
cp "sing-box-$LATEST_VERSION-linux-$ARCH/sing-box" /usr/local/bin/
rm -rf sing-box.tar.gz "sing-box-$LATEST_VERSION-linux-$ARCH"

# 创建配置目录
mkdir -p /etc/sing-box

# 用户输入配置
read -p "请输入用户名 (默认: user): " USERNAME
USERNAME=${USERNAME:-user}

read -p "请输入监听端口 (默认: 443): " LISTEN_PORT
LISTEN_PORT=${LISTEN_PORT:-443}

read -p "请输入REALITY域名 (默认: yahoo.com): " REALITY_DOMAIN
REALITY_DOMAIN=${REALITY_DOMAIN:-yahoo.com}

read -p "请输入REALITY端口 (默认: 443): " REALITY_PORT
REALITY_PORT=${REALITY_PORT:-443}

# 生成随机密码
PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

# 生成REALITY密钥对
PRIVATE_KEY=$(/usr/local/bin/sing-box generate reality-keypair | grep PrivateKey | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 8)

# 创建配置文件
cat > /etc/sing-box/config.json <<EOF
{
    "inbounds": [
        {
            "type": "anytls",
            "listen": "::",
            "listen_port": $LISTEN_PORT,
            "users": [
                {
                    "name": "$USERNAME",
                    "password": "$PASSWORD"
                }
            ],
            "padding_scheme": [
                "stop=8",
                "0=30-30",
                "1=100-400",
                "2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000",
                "3=9-9,500-1000",
                "4=500-1000",
                "5=500-1000",
                "6=500-1000",
                "7=500-1000"
            ],
            "tls": {
                "enabled": true,
                "server_name": "$REALITY_DOMAIN",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "$REALITY_DOMAIN",
                        "server_port": $REALITY_PORT
                    },
                    "private_key": "$PRIVATE_KEY",
                    "short_id": "$SHORT_ID"
                }
            }
        }
    ]
}
EOF

# 创建systemd服务
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
User=root
Group=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable sing-box
systemctl start sing-box

# 获取服务器IP
SERVER_IP=$(curl -s https://api.ipify.org)

# 输出节点信息
echo "=============================================="
echo "anytls+reality 节点配置信息:"
echo "服务器IP: $SERVER_IP"
echo "监听端口: $LISTEN_PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo "REALITY域名: $REALITY_DOMAIN"
echo "REALITY端口: $REALITY_PORT"
echo "Private Key: $PRIVATE_KEY"
echo "Short ID: $SHORT_ID"
echo "=============================================="
echo ""
echo "Sub-Store 本地节点信息:"
echo "anytls://$USERNAME:$PASSWORD@$SERVER_IP:$LISTEN_PORT?server_name=$REALITY_DOMAIN&reality=true&private_key=$PRIVATE_KEY&short_id=$SHORT_ID"
echo ""
echo "=============================================="
echo "sing-box 已安装并启动，可以使用以下命令管理:"
echo "启动: systemctl start sing-box"
echo "停止: systemctl stop sing-box"
echo "重启: systemctl restart sing-box"
echo "查看状态: systemctl status sing-box"
echo "=============================================="
