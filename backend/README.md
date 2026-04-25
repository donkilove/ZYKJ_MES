# MES Backend

## Quick Start

```powershell
python start_backend.py
```

启动前端（可选）：

```powershell
python start_frontend.py
```

`start_frontend.py` 默认以 Windows 桌面应用方式启动；如需切换设备，可额外传入 `--device <id>`。

常用运维命令（仓库根目录）：

```powershell
python start_backend.py logs
python start_backend.py ps
python start_backend.py down
```

如需让宿主数据库管理软件临时接入 PostgreSQL（默认不暴露）：

```powershell
python start_backend.py --expose-db --db-port 5433
```

### 补充：本地 `.venv + uvicorn` 历史口径

以下方式仅作为补充/历史说明，默认主线以 `python start_backend.py` 为准：

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 容器内启动行为

通过 `python start_backend.py` 拉起后端时，脚本会自动：

- ensure database exists (create if missing)
- run `alembic upgrade head`
- seed roles/processes/admin user

## Default Admin

- username: `admin`
- password: `Admin_Local_20260419!`

## Docker 生产部署基线（单机 Compose）

说明：

- 新增的是容器生产启动口径，不替换现有 `start_backend.py` / `start_frontend.py` 本地开发入口。
- 根目录 `compose.yml` 提供 `postgres`、`redis`、`backend-web`、`backend-worker` 四个服务。
- `backend-web` 固定走 `gunicorn + uvicorn worker`，默认 `WEB_CONCURRENCY=4`，并显式禁用 reload。
- `backend-worker` 仅运行独立 worker 入口，不承载 Web 请求。
- `backend-web` 与 `backend-worker` 默认通过 `env_file: backend/.env` 读取运行参数；Docker 场景下对外扫码地址也应在这里配置。
- 另外，根目录本地 `.env` 会通过 Compose 显式透传 `PUBLIC_BASE_URL`、`BOOTSTRAP_ADMIN_PASSWORD`、`PRODUCTION_DEFAULT_VERIFICATION_CODE` 等宿主机部署参数；这类值建议放在根 `.env`，避免写死进跟踪文件。

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
- 手机扫码复核对外地址：`PUBLIC_BASE_URL`
  - Docker 或反向代理场景必须显式设置为手机实际可访问的宿主机地址，例如 `http://192.168.1.54:8000`
  - 若不设置，系统只能根据当前请求或容器网络自行判断，可能得到 `127.0.0.1` 或 Docker 网段地址
- 若调整了 PostgreSQL 初始账号/密码，请同步 `DB_BOOTSTRAP_USER` / `DB_BOOTSTRAP_PASSWORD`，并在需要时执行一次 `docker compose down -v` 重新初始化数据卷。

### 4. 停止与清理

```powershell
docker compose down
```

如需同时删除数据卷（会清空 PostgreSQL/Redis 数据）：

```powershell
docker compose down -v
```
