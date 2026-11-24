#!/bin/sh
# Fits Claude Code Router's own Docker entrypoint to Railway, then hands over to it.
# Nothing here exits on a bad variable: each step logs and falls back, so a typo can't
# leave the service crash-looping.
log() { echo "railway: $*"; }

# Railway's healthcheck and domain use $PORT, so Nginx listens there.
case "${PORT:-}" in
  ''|*[!0-9]*) log "PORT='${PORT:-}' is not a number, using 8080"; PORT=8080 ;;
esac
case "$PORT" in
  3456|3459) log "PORT $PORT is used inside the container, using 8080"; PORT=8080 ;;
esac
export PORT CCR_NGINX_PORT="$PORT"

# The address clients are told to use. Railway sets RAILWAY_PUBLIC_DOMAIN once the
# service has a domain; CCR writes it into its configuration on every start.
if [ -z "${CCR_PUBLIC_BASE_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export CCR_PUBLIC_BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

# An empty token is not open access: CCR then makes a new one on each start and prints
# the management URL to the deploy log. Say so, because that URL changes every restart.
if [ -z "${CCR_WEB_AUTH_TOKEN:-}" ]; then
  unset CCR_WEB_AUTH_TOKEN
  log "CCR_WEB_AUTH_TOKEN is empty: a new management token is generated on each start (URL below)"
fi

# Small plans (Free 0.5 GB, Trial 1 GB) cap the whole service's memory. Past the cap the
# kernel kills the gateway, which Railway counts as a failed deploy. Cap Node's heap at
# 60% of the limit there, so V8 collects garbage harder instead. Services over 2 GB, or
# with NODE_OPTIONS set, keep the default.
mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo max)
case "$mem" in ''|*[!0-9]*) mem=max ;; esac
if [ -z "${NODE_OPTIONS:-}" ] && [ "$mem" != max ] && [ "$mem" -le $((2 * 1024 * 1024 * 1024)) ]; then
  heap=$((mem * 6 / 10 / 1024 / 1024))
  export NODE_OPTIONS="--max-old-space-size=${heap}"
  log "memory limit $((mem / 1024 / 1024)) MB: capping Node's heap at ${heap} MB"
fi

if [ ! -w "${CCR_DATA_DIR:-/data}" ]; then
  log "warning: ${CCR_DATA_DIR:-/data} is not writable (is the volume attached and not full?)"
fi

exec ccr-docker-entrypoint "$@"
