FROM docker:27-cli

# bash (script), curl (REST), jq (JSON), coreutils, iproute2 (host LAN IP detect)
RUN apk add --no-cache bash curl jq coreutils iproute2

COPY uniportical /usr/local/bin/uniportical
RUN chmod +x /usr/local/bin/uniportical

# Exposed configuration — only what cannot be auto-detected. Declared (so the
# interface is discoverable) but EMPTY: no baked-in defaults. Port, site and WAN
# interface are discovered from the controller at runtime.
ENV UNIFI_HOST="" \
    UNIFI_API_KEY="" \
    UNIPORTICAL_POLL_INTERVAL="" \
    UNIPORTICAL_HOST_IP=""

ENTRYPOINT ["uniportical"]
CMD ["poll"]
