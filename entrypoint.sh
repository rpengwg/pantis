#!/bin/sh
set -e

BIN=/usr/local/bin/simpweb
CONF_DIR=/etc/simpweb

if [ -n "$PORT" ]; then
    LISTEN_PORT=$PORT
else
    LISTEN_PORT=$(awk 'BEGIN{srand();print int(rand()*40000)+10000}')
fi

if [ -n "$RAILWAY_TCP_PROXY_DOMAIN" ]; then
    CLIENT_HOST="$RAILWAY_TCP_PROXY_DOMAIN"
    CLIENT_PORT="$RAILWAY_TCP_PROXY_PORT"
elif [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    CLIENT_HOST="$RAILWAY_PUBLIC_DOMAIN"
    CLIENT_PORT=443
elif [ -n "$KOYEB_PUBLIC_DOMAIN" ]; then
    CLIENT_HOST="$KOYEB_PUBLIC_DOMAIN"
    CLIENT_PORT=443
else
    CLIENT_HOST="YOUR_DOMAIN_OR_IP"
    CLIENT_PORT=$LISTEN_PORT
fi

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

sed \
 -e "s|LISTEN_PORT_PLACEHOLDER|$LISTEN_PORT|g" \
 -e "s|UUID_PLACEHOLDER|$UUID|g" \
 -e "s|PRIVATE_KEY_PLACEHOLDER|$PRIVATE_KEY|g" \
 -e "s|SHORT_ID_PLACEHOLDER|$SHORT_ID|g" \
 -e "s|PATH_PLACEHOLDER|$PATH_STR|g" \
 -e "s|SNI_PLACEHOLDER|$SNI|g" \
 -e "s|TARGET_PLACEHOLDER|$SNI|g" \
 $CONF_DIR/server.template.json > $CONF_DIR/config.json

$BIN test -c $CONF_DIR/config.json

REALITY_LINK="vless://${UUID}@${CLIENT_HOST}:${CLIENT_PORT}?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}#simpweb-TCP-REALITY"

TLS_LINK="vless://${UUID}@${CLIENT_HOST}:443?type=xhttp&security=tls&encryption=none&sni=${SNI}&path=%2F${PATH_STR}#simpweb-XHTTP-TLS"

echo '============================================='
echo 'simpweb nodes ready'
echo "$REALITY_LINK"
echo "$TLS_LINK"
echo '============================================='

exec $BIN run -c $CONF_DIR/config.json
