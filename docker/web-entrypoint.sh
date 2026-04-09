#!/usr/bin/env sh
set -eu

cd /app/backend

if [ "${UVICORN_RELOAD:-false}" = "true" ] || [ "${RELOAD:-false}" = "true" ]; then
  echo "error: 容器生产启动不允许开启 reload，请移除 UVICORN_RELOAD/RELOAD=true" >&2
  exit 1
fi

set -- gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers "${WEB_CONCURRENCY:-4}" \
  --bind "0.0.0.0:${APP_PORT:-8000}" \
  --timeout "${GUNICORN_TIMEOUT_SECONDS:-60}" \
  --graceful-timeout "${GUNICORN_GRACEFUL_TIMEOUT_SECONDS:-20}" \
  --access-logfile - \
  --error-logfile -

if [ "${GUNICORN_MAX_REQUESTS:-0}" -gt 0 ] 2>/dev/null; then
  set -- "$@" --max-requests "${GUNICORN_MAX_REQUESTS}"
  if [ "${GUNICORN_MAX_REQUESTS_JITTER:-0}" -gt 0 ] 2>/dev/null; then
    set -- "$@" --max-requests-jitter "${GUNICORN_MAX_REQUESTS_JITTER}"
  fi
fi

exec "$@"
