#!/bin/sh
set -e

BIN=/usr/local/bin/simpweb
CONF_DIR=/etc/simpweb
CERT_DIR=$CONF_DIR/certs

mkdir -p $CERT_DIR

# REALITY 使用高位端口，TLS 固定 443
REALITY_PORT=${REALITY_PORT:-$(awk 'BEGIN{srand();print int(rand()*20000)+40000}')}
TLS_PORT=443

if [ -n "$RAILWAY_TCP_PROXY_DOMAIN" ]; then
    REALITY_HOST="$RAILWAY_TCP_PROXY_DOMAIN"
    REALITY_PUBLIC_PORT="$RAILWAY_TCP_PROXY_PORT"
elif [ -n "$KOYEB_PUBLIC_DOMAIN" ]; then
    REALITY_HOST="$KOYEB_PUBLIC_DOMAIN"
    REALITY_PUBLIC_PORT=$REALITY_PORT
elif [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    REALITY_HOST="$RAILWAY_PUBLIC_DOMAIN"
    REALITY_PUBLIC_PORT=$REALITY_PORT
else
    REALITY_HOST="${DOMAIN:-YOUR_DOMAIN_OR_IP}"
    REALITY_PUBLIC_PORT=$REALITY_PORT
fi

TLS_HOST="${TLS_DOMAIN:-$RAILWAY_PUBLIC_DOMAIN}"
[ -z "$TLS_HOST" ] && TLS_HOST="$REALITY_HOST"

UUID=$($BIN uuid | head -n1 | tr -d ' \r\n')
KEYS=$($BIN x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep -iE 'Private|PrivateKey' | awk -F: '{print $2}' | tr -d ' \r\n')
PUBLIC_KEY=$(echo "$KEYS" | grep -iE 'Public|Password' | awk -F: '{print $2}' | tr -d ' \r\n')

[ -z "$PRIVATE_KEY" ] && echo 'REALITY key generation failed' && exit 1

SHORT_ID=$(openssl rand -hex 4)
PATH_STR=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c8)

DOMAINS="www.apple.com www.microsoft.com www.cloudflare.com"
set -- $DOMAINS
SNI=$1

# TLS证书：优先使用用户提供证书，否则生成临时证书用于测试
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/private.key" ]; then
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
-keyout $CERT_DIR/private.key \
-out $CERT_DIR/fullchain.pem \
-subj "/CN=$TLS_HOST" >/dev/null 2>&1
fi

sed \
 -e "s|REALITY_PORT_PLACEHOLDER|$REALITY_PORT|g" \
 -e "s|UUID_PLACEHOLDER|$UUID|g" \
 -e "s|PRIVATE_KEY_PLACEHOLDER|$PRIVATE_KEY|g" \
 -e "s|SHORT_ID_PLACEHOLDER|$SHORT_ID|g" \
 -e "s|PATH_PLACEHOLDER|$PATH_STR|g" \
 -e "s|TLS_DOMAIN_PLACEHOLDER|$TLS_HOST|g" \
 $CONF_DIR/server.template.json > $CONF_DIR/config.json

$BIN test -c $CONF_DIR/config.json

REALITY_LINK="vless://${UUID}@${REALITY_HOST}:${REALITY_PUBLIC_PORT}?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&pb=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}#simpweb-TCP-REALITY"

TLS_LINK="vless://${UUID}@${TLS_HOST}:443?type=xhttp&security=tls&encryption=none&sni=${TLS_HOST}&path=%2F${PATH_STR}#simpweb-XHTTP-TLS"

echo '============================================='
echo 'simpweb deployment ready'
echo "REALITY: $REALITY_LINK"
echo "TLS: $TLS_LINK"
echo '============================================='

exec $BIN run -c $CONF_DIR/config.json
