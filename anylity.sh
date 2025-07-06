#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root用户运行此脚本！"
  exit 1
fi

# 安装必要的依赖
apt-get update >/dev/null 2>&1
apt-get install -y curl jq uuid-runtime >/dev/null 2>&1

# 用户输入参数
read -p "请输入用户名 (默认: user): " username
username=${username:-user}

read -p "请输入监听端口 (默认: 443): " listen_port
listen_port=${listen_port:-443}

read -p "请输入Reality域名 (默认: yahoo.com): " server_name
server_name=${server_name:-yahoo.com}

read -p "请输入Reality握手端口 (默认: 443): " handshake_port
handshake_port=${handshake_port:-443}

# 生成随机密码
password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)

# 生成Reality参数
private_key=$(./sing-box generate reality-keypair | grep PrivateKey | cut -d'"' -f4)
short_id=$(head -c 8 /proc/sys/kernel/random/uuid | sed 's/-//g')

# 安装sing-box
echo "正在安装sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.12.0-beta.30

# 创建配置文件
cat > /usr/local/etc/sing-box/config.json <<EOF
{
    "inbounds": [
        {
            "type": "anytls",
            "listen": "::",
            "listen_port": ${listen_port},
            "users": [
                {
                    "name": "${username}",
                    "password": "${password}"
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
                "server_name": "${server_name}",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "${server_name}",
                        "server_port": ${handshake_port}
                    },
                    "private_key": "${private_key}",
                    "short_id": "${short_id}"
                }
            }
        }
    ]
}
EOF

# 启动服务
systemctl enable --now sing-box

# 获取服务器IP
server_ip=$(curl -4s ip.sb)

# 输出节点信息
echo "=============================="
echo "AnyReality 节点配置信息:"
echo "地址: ${server_ip}"
echo "端口: ${listen_port}"
echo "用户: ${username}"
echo "密码: ${password}"
echo "SNI: ${server_name}"
echo "Short ID: ${short_id}"
echo "=============================="
echo "Sub-Store 本地节点URI:"
echo "anytls://${username}:${password}@${server_ip}:${listen_port}?sni=${server_name}&short_id=${short_id}#AnyReality"
echo "=============================="
