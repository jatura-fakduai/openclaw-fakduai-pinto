ARG OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest

FROM node:24-bookworm-slim AS plugin-build

ARG PINTO_PLUGIN_REPO=https://github.com/jatura-fakduai/pinto-openclaw-gateway.git
ARG PINTO_PLUGIN_REF=main

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/pinto-app-openclaw

COPY patches/pinto-no-register-config-write.patch /tmp/pinto-no-register-config-write.patch

RUN sed -i 's/\r$//' /tmp/pinto-no-register-config-write.patch \
    && git clone --depth 1 --branch "$PINTO_PLUGIN_REF" "$PINTO_PLUGIN_REPO" . \
    && git apply --ignore-space-change --ignore-whitespace /tmp/pinto-no-register-config-write.patch \
    && npm ci \
    && npm run build \
    && PKG_FILE="$(npm pack --pack-destination /tmp | tail -n 1)" \
    && cp "/tmp/${PKG_FILE}" /tmp/pinto-app-openclaw.tgz

FROM ${OPENCLAW_IMAGE}

USER root

RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      libasound2 \
      libatk-bridge2.0-0 \
      libatk1.0-0 \
      libcairo2 \
      libcups2 \
      libdbus-1-3 \
      libdrm2 \
      libgbm1 \
      libglib2.0-0 \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libx11-6 \
      libx11-xcb1 \
      libxcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxkbcommon0 \
      libxrandr2 \
      libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=plugin-build --chown=node:node /tmp/pinto-app-openclaw.tgz /opt/openclaw-plugins/pinto-app-openclaw.tgz
COPY --chown=node:node scripts/docker-entrypoint.sh /usr/local/bin/openclaw-pinto-entrypoint
COPY --chown=node:node scripts/bootstrap-pinto-channel.mjs /usr/local/bin/bootstrap-pinto-channel.mjs

RUN sed -i 's/\r$//' \
      /usr/local/bin/openclaw-pinto-entrypoint \
      /usr/local/bin/bootstrap-pinto-channel.mjs \
    && chmod 755 /usr/local/bin/openclaw-pinto-entrypoint

USER node

ENTRYPOINT ["tini", "-s", "--", "/usr/local/bin/openclaw-pinto-entrypoint"]
CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
