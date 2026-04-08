FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY backend/requirements.txt /tmp/requirements.txt

RUN python -m pip install --upgrade pip \
    && pip install -r /tmp/requirements.txt

COPY backend /app/backend
COPY docker /app/docker

RUN chmod +x /app/docker/*.sh

WORKDIR /app/backend

EXPOSE 8000

CMD ["/app/docker/web-entrypoint.sh"]
