FROM alpine:latest

# 固定使用当前 Xray 版本
RUN apk add --no-cache tzdata openssl ca-certificates jq wget unzip && \
    wget -O xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip && \
    unzip xray.zip -d /usr/local/bin/ && \
    mv /usr/local/bin/xray /usr/local/bin/simpweb && \
    rm -f xray.zip /usr/local/bin/geoip.dat /usr/local/bin/geosite.dat /usr/local/bin/LICENSE /usr/local/bin/README.md && \
    chmod +x /usr/local/bin/simpweb

RUN mkdir -p /etc/simpweb
COPY server.template.json /etc/simpweb/server.template.json
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
