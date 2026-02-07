FROM alpine:3.23
RUN apk add --no-cache wireguard-tools
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
