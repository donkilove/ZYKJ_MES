# MES Backend

## Quick Start

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

在仓库根目录也可以直接执行：

```powershell
.\.venv\Scripts\python.exe .\start_backend.py
.\.venv\Scripts\python.exe .\start_frontend.py
```

`start_frontend.py` 默认以 Windows 桌面应用方式启动；如需切换设备，可额外传入 `--device <id>`。

### 本地性能宿主模式

如需按当前压测口径启动后端，可在仓库根目录执行：

```bash
./.venv/bin/python start_backend.py --mode perf --no-reload
```

说明：

- `--mode perf` 会切到 `gunicorn + uvicorn worker` 启动方式。
- perf 模式默认关闭 bootstrap、后台循环和 reload，避免把启动/后台开销混入压测结果。
- perf 模式默认采用当前安全连接池预算：
  - `DB_POOL_SIZE=6`
  - `DB_MAX_OVERFLOW=4`
  - `DB_POOL_TIMEOUT_SECONDS=5`
- 如需覆盖 worker 数，可额外传入 `--workers 4` 等参数。

Backend startup now performs bootstrap automatically:

- ensure database exists (create if missing)
- run `alembic upgrade head`
- seed roles/processes/admin user

## Local Proxy Note

If your environment sets `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`, local
requests to `127.0.0.1` may be forwarded to the proxy and fail with `502`.

根目录启动入口 `start_backend.py`、`start_frontend.py` 会自动合并：

`NO_PROXY` and `no_proxy` => `localhost,127.0.0.1,::1`

for spawned subprocesses so localhost traffic bypasses the proxy. If you start
services manually, set `NO_PROXY` yourself.

Manual seed command remains available:

```powershell
..\.venv\Scripts\python.exe -m scripts.init_admin
```

## Default Admin

- username: `admin`
- password: `Admin@123456`

## Docker 生产部署基线（单机 Compose）

说明：

- 新增的是容器生产启动口径，不替换现有 `start_backend.py` / `start_frontend.py` 本地开发入口。
- 根目录 `compose.yml` 提供 `postgres`、`redis`、`backend-web`、`backend-worker` 四个服务。
- `backend-web` 固定走 `gunicorn + uvicorn worker`，默认 `WEB_CONCURRENCY=4`，并显式禁用 reload。
- `backend-worker` 仅运行独立 worker 入口，不承载 Web 请求。

### 1. 启动

在仓库根目录执行：

```powershell
docker compose up -d --build
```

### 2. 核验

```powershell
docker compose ps
docker compose logs backend-web --tail=100
docker compose logs backend-worker --tail=100
```

可选健康检查（按项目现有接口路径调整）：

```powershell
curl http://127.0.0.1:8000/health
```

### 3. 关键环境变量（Compose 已内置默认值）

- Web 并发：`WEB_CONCURRENCY`（默认 `4`）
- 数据库连接：`DB_HOST` `DB_PORT` `DB_NAME` `DB_USER` `DB_PASSWORD`
- Bootstrap 连接：`DB_BOOTSTRAP_HOST` `DB_BOOTSTRAP_PORT` `DB_BOOTSTRAP_USER` `DB_BOOTSTRAP_PASSWORD`
- 数据库连接池：`DB_POOL_SIZE` `DB_MAX_OVERFLOW` `DB_POOL_TIMEOUT_SECONDS` `DB_POOL_RECYCLE_SECONDS`
- 后台任务开关：
  - `backend-web`: `WEB_RUN_BOOTSTRAP=false`、`WEB_RUN_BACKGROUND_LOOPS=false`
  - `backend-worker`: `WORKER_RUN_BOOTSTRAP=true`、`WORKER_RUN_BACKGROUND_LOOPS=true`
  - 后台循环细分仍由 `MAINTENANCE_AUTO_GENERATE_ENABLED`、`MESSAGE_DELIVERY_MAINTENANCE_ENABLED` 控制
- 若调整了 PostgreSQL 初始账号/密码，请同步 `DB_BOOTSTRAP_USER` / `DB_BOOTSTRAP_PASSWORD`，并在需要时执行一次 `docker compose down -v` 重新初始化数据卷。

### 4. 停止与清理

```powershell
docker compose down
```

如需同时删除数据卷（会清空 PostgreSQL/Redis 数据）：

```powershell
docker compose down -v
```
