# Claude Code Router publishes no container image: its Docker setup builds from source.
# So it is built here once, in CI, and a deploy pulls the finished image.
# The stages below follow upstream's own Dockerfile at the pinned tag. On an upgrade,
# diff upstream's Dockerfile and docker/ folder against the previous tag first.
FROM node:22-bookworm-slim AS src
# upgrade: github musistudio/claude-code-router
ARG CCR_VERSION=v3.1.6
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$CCR_VERSION" https://github.com/musistudio/claude-code-router.git /src \
  && rm -rf /src/.git

FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY --from=src /src/ ./
RUN npm ci && npm run build:docker

FROM node:22-bookworm-slim AS production-deps
WORKDIR /app
ENV NODE_ENV=production
COPY --from=src /src/package.json /src/package-lock.json ./
COPY --from=src /src/packages/core/package.json packages/core/package.json
RUN npm ci --omit=dev --workspace=@claude-code-router/core --include-workspace-root=false \
  && npm cache clean --force

FROM node:22-bookworm-slim
ARG CCR_VERSION
LABEL org.opencontainers.image.version="$CCR_VERSION"
ENV NODE_ENV=production \
    CCR_DATA_DIR=/data \
    CCR_WEB_HOST=127.0.0.1 \
    CCR_WEB_PORT=3459 \
    CCR_NGINX_PORT=8080 \
    CCR_GATEWAY_HOST=127.0.0.1 \
    CCR_GATEWAY_PORT=3456 \
    PORT=8080

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libstdc++6 nginx util-linux \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf \
  && rm -rf \
    /opt/yarn-* \
    /usr/local/bin/corepack \
    /usr/local/bin/npm \
    /usr/local/bin/npx \
    /usr/local/bin/yarn \
    /usr/local/bin/yarnpkg \
    /usr/local/include/node \
    /usr/local/lib/node_modules/corepack \
    /usr/local/lib/node_modules/npm \
    /usr/local/share/doc \
    /usr/local/share/man

COPY --from=src /src/package.json /src/package-lock.json ./
COPY --from=src /src/packages/core/package.json packages/core/package.json
COPY --from=production-deps /app/node_modules node_modules
COPY --from=build /app/packages/core/dist packages/core/dist
COPY --from=build /app/packages/ui/dist/renderer /usr/share/nginx/html
COPY --from=src /src/docker/entrypoint.sh /usr/local/bin/ccr-docker-entrypoint
COPY --from=src /src/docker/pm2.config.cjs docker/pm2.config.cjs
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint

RUN chmod +x /usr/local/bin/ccr-docker-entrypoint /usr/local/bin/railway-entrypoint \
  && mkdir -p /data /run/nginx /var/lib/nginx /var/log/nginx \
  && sed -i -e 's#^pid .*#pid /run/nginx/nginx.pid;#' -e '/^user /d' /etc/nginx/nginx.conf \
  && groupadd --system --gid 10001 ccr \
  && useradd --system --uid 10001 --gid ccr --home-dir /data --no-create-home --shell /usr/sbin/nologin ccr

EXPOSE 8080
ENTRYPOINT ["railway-entrypoint"]
