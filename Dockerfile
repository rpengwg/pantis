FROM alpine:latest

# 👇 修改点 1：下载后进行重命名和清理特征文件
RUN apk add --no-cache tzdata openssl ca-certificates jq && \
    wget -O xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip && \
    unzip xray.zip -d /usr/local/bin/ && \
    mv /usr/local/bin/xray /usr/local/bin/web && \
    rm -f xray.zip /usr/local/bin/geoip.dat /usr/local/bin/geosite.dat /usr/local/bin/LICENSE /usr/local/bin/README.md && \
    chmod +x /usr/local/bin/web

# 👇 修改点 2：将配置文件夹的名称也改为 web，避免出现 xray 字眼
RUN mkdir -p /etc/web
COPY server.template.json /etc/web/server.template.json
COPY entrypoint.sh /entrypoint.sh

# 赋予执行权限
RUN chmod +x /entrypoint.sh

# 设置容器入口
ENTRYPOINT ["/entrypoint.sh"]
