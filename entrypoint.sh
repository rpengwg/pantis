#!/bin/sh

# 1. 动态获取环境端口
if [ -n "$PORT" ]; then
    LISTEN_PORT=$PORT
else
    LISTEN_PORT=$(awk 'BEGIN{srand();print int(rand()*64536)+1000}')
fi

# 获取对外显示的域名
if [ -n "$RAILWAY_TCP_PROXY_DOMAIN" ]; then
    CLIENT_IP="$RAILWAY_TCP_PROXY_DOMAIN"
    CLIENT_PORT="$RAILWAY_TCP_PROXY_PORT"
elif [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    CLIENT_IP="$RAILWAY_PUBLIC_DOMAIN"
    CLIENT_PORT="443"
elif [ -n "$KOYEB_PUBLIC_DOMAIN" ]; then
    CLIENT_IP="$KOYEB_PUBLIC_DOMAIN"
    CLIENT_PORT="443"
else
    CLIENT_IP="你的云平台域名或VPS公网IP"
    CLIENT_PORT=$LISTEN_PORT
fi

# 2. 核心密钥提取 (修复 v26 格式变动，利用冒号精准截取并清理空格)
UUID=$(/usr/local/bin/web uuid | head -n 1 | tr -d '\r\n ')
SHORT_ID=$(openssl rand -hex 4 | tr -d '\r\n ')
PATH_STR=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8 | tr -d '\r\n ')

# 提取 REALITY 密钥对 (兼容 v26 最新格式：PrivateKey: xxx / Password (PublicKey): yyy)
REALITY_KEYS=$(/usr/local/bin/web x25519)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep -iE "Private" | head -n 1 | awk -F ':' '{print $2}' | tr -d '\r\n ')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep -iE "Public|Password" | head -n 1 | awk -F ':' '{print $2}' | tr -d '\r\n ')

# 提取 VLESS 前向抗量子加密串 (精确提取第一组 key，防止多行粘连)
VLESSENC=$(/usr/local/bin/web vlessenc)
DECRYPTION=$(echo "$VLESSENC" | grep '"decryption"' | head -n 1 | awk -F '"' '{print $4}' | tr -d '\r\n ')
ENCRYPTION=$(echo "$VLESSENC" | grep '"encryption"' | head -n 1 | awk -F '"' '{print $4}' | tr -d '\r\n ')

# 3. 随机选择伪装域名
DOMAINS="www.bing.com www.yahoo.com"
set -- $DOMAINS
shift $(expr $(awk 'BEGIN{srand();print int(rand()*2)}') )
SNI=$1

# 4. 使用 jq 安全注入配置，无视任何超长字符串或特殊符号干扰
jq --arg port "$LISTEN_PORT" \
   --arg uuid "$UUID" \
   --arg path_str "$PATH_STR" \
   --arg sni "$SNI" \
   --arg pk "$PRIVATE_KEY" \
   --arg sid "$SHORT_ID" \
   --arg dec "$DECRYPTION" \
   '.inbounds[0].port = ($port | tonumber) |
    .inbounds[0].settings.clients[0].id = $uuid |
    .inbounds[0].settings.decryption = $dec |
    .inbounds[0].streamSettings.xhttpSettings.path = ("/" + $path_str) |
    .inbounds[0].streamSettings.realitySettings.target = ($sni + ":443") |
    .inbounds[0].streamSettings.realitySettings.serverNames[0] = $sni |
    .inbounds[0].streamSettings.realitySettings.privateKey = $pk |
    .inbounds[0].streamSettings.realitySettings.shortIds[0] = $sid' \
   /etc/web/server.template.json > /etc/web/config.json

# 5. 生成分享链接
VLESS_LINK="vless://${UUID}@${CLIENT_IP}:${CLIENT_PORT}?type=xhttp&security=reality&encryption=${ENCRYPTION}&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}&path=%2F${PATH_STR}&flow=xtls-rprx-vision#Xray-PQ-Node"

echo "======================================================"
echo "🎯 抗量子节点部署成功 (VLESS-XHTTP-REALITY)！"
echo "======================================================"
echo "🔗 节点分享链接 (支持最新版 v2rayN / Shadowrocket):"
echo ""
echo "$VLESS_LINK"
echo ""
echo "======================================================"

# 6. 启动进程
exec /usr/local/bin/web run -c /etc/web/config.json
