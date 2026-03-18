ARG BUILD_FROM=ghcr.io/hassio-addons/base:3.22
FROM ${BUILD_FROM}

LABEL \
  io.hass.name="Nebula VPN" \
  io.hass.description="Nebula mesh VPN client for Home Assistant OS (x86_64)" \
  io.hass.type="addon"

# Dependencies
RUN apk add --no-cache curl ca-certificates

# Download Nebula for x86_64 (linux-amd64)
ARG NEBULA_VERSION=1.10.3

RUN curl -L \
      "https://github.com/slackhq/nebula/releases/download/v${NEBULA_VERSION}/nebula-linux-amd64.tar.gz" \
      -o /tmp/nebula.tar.gz \
    && tar -xzf /tmp/nebula.tar.gz -C /usr/local/bin nebula \
    && rm /tmp/nebula.tar.gz \
    && chmod +x /usr/local/bin/nebula

# Entry script
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]