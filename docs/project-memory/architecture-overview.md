# ZYKJ_MES 整体架构

## 1. 系统拓扑

### 1.1 概览

```text
┌────────────────────────────────────────────────────────────────────┐
│                       Docker Compose (compose.yml)                 │
│                                                                    │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  ┌────────────────┐│
│  │ postgres │  │  redis   │  │ backend-web    │  │ backend-worker  ││
│  │16-alpine │  │7-alpine  │  │ Gunicorn+     │  │ worker_main.py ││
│  │  :5432   │  │  :6379   │  │ UvicornWorker │  │ bootstrap +    ││
│  │          │  │          │  │ 端口 8000      │  │ 后台循环        ││
│  └──────────┘  └──────────┘  └───────────────┘  └────────────────┘│
└────────────────────────────────────────────────────────────────────┘
         │              │               │                    │
         ▼              ▼               ▼                    ▼
   PostgreSQL         Redis       FastAPI HTTP        后台异步任务
   数据持久化       缓存/会话     API 服务            maintenance/message
```

### 1.2 后端：FastAPI 单体应用

分层结构：

- **API 路由层** (`backend/app/api/v1/`) — 端点路由汇聚
- **Service 业务层** (`backend/app/services/`) — 业务逻辑
- **Model 数据层** (`backend/app/models/`) — SQLAlchemy ORM 模型

两个进程共用同一代码库、同一镜像（`zykj-mes-backend:local`），通过环境变量区分行为：

| 进程 | 入口模块 | bootstrap | 后台循环 |
|------|---------|-----------|----------|
| Web | `app.main:app` | `WEB_RUN_BOOTSTRAP=false` | `WEB_RUN_BACKGROUND_LOOPS=false` |
| Worker | `app.worker_main` | `WORKER_RUN_BOOTSTRAP=true` | `WORKER_RUN_BACKGROUND_LOOPS=true` |

- Web 进程：Gunicorn + `uvicorn.workers.UvicornWorker`，默认 4 workers（通过 `WEB_CONCURRENCY` 控制），监听 `0.0.0.0:8000`
- Worker 进程：`asyncio.run(run_worker())`，运行 `maintenance_auto_generate_loop` 和 `message_delivery_maintenance_loop` 两个后台异步循环

### 1.3 前端：Flutter 桌面应用

分层结构：

- **core 基础设施层** (`frontend/lib/core/`) — 配置、网络、模型、服务、UI 基础组件
- **features 业务模块层** (`frontend/lib/features/`) — 按业务领域分模块

包名：`mes_client`（Dart package `package:mes_client`）。

### 1.4 插件系统

- 嵌入式 Python 3.12 运行时（`plugins/runtime/python312/python.exe`）
- 插件通过 `manifest.json` 声明元数据与启动参数
- 前端 `plugin_host` feature 负责：扫描插件目录 → 启动插件进程（Python）→ 通过 WebView 嵌入插件 UI
- 插件以独立进程运行，通过 HTTP 暴露 UI，前端通过 `PluginProcessService` 管理进程生命周期

### 1.5 基础设施

Docker Compose 编排 4 个 service：

| Service | 镜像 | 说明 |
|---------|------|------|
| `postgres` | `postgres:16-alpine` | 数据持久化，不暴露宿主端口 |
| `redis` | `redis:7-alpine` | 缓存/会话，不暴露宿主端口 |
| `backend-web` | `zykj-mes-backend:local` | Gunicorn + UvicornWorker，端口 8000 |
| `backend-worker` | `zykj-mes-backend:local`（同镜像） | 后台异步任务 |

## 2. 核心依赖方向

### 2.1 后端调用链

```text
backend/app/main.py (FastAPI 应用)
  └── app.api.v1.api (api_router, prefix="/api/v1")
        ├── auth.router      → /api/v1/auth
        ├── authz.router     → /api/v1/authz
        ├── me.router        → /api/v1/me
        ├── users.router     → /api/v1/users
        ├── roles.router     → /api/v1/roles
        ├── audits.router    → /api/v1/audits
        ├── sessions.router  → /api/v1/sessions
        ├── processes.router → /api/v1/processes
        ├── products.router  → /api/v1/products
        ├── craft.router     → /api/v1/craft
        ├── production.router→ /api/v1/production
        ├── quality.router   → /api/v1/quality
        ├── equipment.router → /api/v1/equipment
        ├── ui.router        → /api/v1/ui
        ├── messages.router  → /api/v1/messages
        └── system.router    → /api/v1/system
                  │
                  ▼
        app/services/<domain>_service.py  (业务层)
                  │
                  ▼
        app/models/<entity>.py             (ORM 模型 → PostgreSQL)
```

此外 `main.py` 通过 `lifespan` 可选启动：
- `app.services.maintenance_scheduler_service.run_maintenance_auto_generate_loop()`
- `app.services.message_service.run_message_delivery_maintenance_loop()`

Worker 进程 (`worker_main.py`) 直接导入并运行这两个后台循环。

### 2.2 前端调用链

```text
frontend/lib/main.dart (入口)
  └── MesClientApp → AppBootstrapPage
        └── LoginPage → MainShellPage
              └── MainShellPageRegistry 按 pageCode 路由:
                    ├── home_page.dart          (shell)
                    ├── user_page.dart           (user)
                    ├── product_page.dart        (product)
                    ├── equipment_page.dart      (equipment)
                    ├── production_page.dart     (production)
                    ├── quality_page.dart        (quality)
                    ├── craft_page.dart           (craft)
                    ├── software_settings_page.dart (settings)
                    ├── message_center_page.dart  (message)
                    └── plugin_host_page.dart     (plugin_host)
                          │
                          ▼
              core/network/http_client.dart
              (package:http 封装，GET/POST/PUT/PATCH/DELETE)
                          │
                          ▼
                  后端 HTTP API (/api/v1/*)
```

### 2.3 前后端接口契约

前端 `features/*/services/` 通过 `core/network/http_client.dart` 调用后端 REST API，接口前缀为 `/api/v1`（由 `settings.api_v1_prefix` 配置，默认值 `"/api/v1"`）。

## 3. 关键进程

### 3.1 backend-web

- **入口**：`docker/web-entrypoint.sh` → `gunicorn app.main:app`
- **Worker 类型**：`uvicorn.workers.UvicornWorker`
- **端口**：`0.0.0.0:8000`
- **bootstrap**：生产环境禁用（`web_run_bootstrap: false`）
- **后台循环**：生产环境禁用（`web_run_background_loops: false`）
- **DB 连接池**：pool_size=6, max_overflow=4
- **健康检查**：TCP connect to 127.0.0.1:8000

### 3.2 backend-worker

- **入口**：`docker/worker-entrypoint.sh` → `python app/worker_main.py`
- **运行方式**：`asyncio.run(run_worker())`
- **bootstrap**：生产环境启用（`worker_run_bootstrap: true`）
- **后台循环**：生产环境启用（`worker_run_background_loops: true`）
  - `maintenance_auto_generate_loop` — 维保计划自动生成（每天 `00:05` + `Asia/Shanghai`）
  - `message_delivery_maintenance_loop` — 消息投递维护（每 15 秒）
- **DB 连接池**：pool_size=2, max_overflow=2（Worker 专用，比 Web 小）

### 3.3 Bootstrap 流程

`run_startup_bootstrap()` 位于 `backend/app/bootstrap/startup_bootstrap.py`：

1. 确保数据库存在（`ensure_database_exists()`）
2. 运行 Alembic 数据库迁移
3. 初始化种子数据（`seed_initial_data()` — 管理员账号、默认角色等）

## 4. 数据流方向

### 4.1 前端 → 后端

```text
Flutter features/services
  → core/network/http_client.dart (package:http)
  → HTTP Request (30s timeout)
  → FastAPI endpoints (app.api.v1.endpoints.*)
  → app.services.* (业务逻辑)
  → app.models.* (SQLAlchemy ORM)
  → PostgreSQL
```

### 4.2 Worker 后台任务

```text
backend-worker (worker_main.py)
  → run_maintenance_auto_generate_loop()
       → maintenance_scheduler_service
       → models (maintenance_plan, maintenance_work_order, maintenance_item, maintenance_record)
       → PostgreSQL

  → run_message_delivery_maintenance_loop()
       → message_service
       → models (message, message_recipient)
       → PostgreSQL
```

### 4.3 Web 进程与后台循环

Web 进程在开发环境（`web_run_background_loops=true`）下也会以 `asyncio.create_task` 方式启动同样的后台循环，但生产环境默认关闭，统一由 Worker 进程承担。

## 5. 插件系统

### 5.1 架构

```text
Flutter (plugin_host feature)
  │
  ├── PluginRuntimeLocator → 定位 Python 运行时路径
  │     ├── MES_PYTHON_RUNTIME_DIR 环境变量（优先）
  │     └── plugins/runtime/python312/python.exe（默认）
  │
  ├── PluginCatalogService → 扫描 plugins/ 目录，解析 manifest.json
  │     └── PluginManifest: id, name, version, entryScript, pythonVersion,
  │         arch, dependencyPaths, permissions, startupTimeout, heartbeatInterval
  │
  ├── PluginProcessService → 启动 Python 进程
  │     └── 设置环境变量: PYTHONHOME, MES_PLUGIN_ID, MES_PLUGIN_DIR
  │     └── 心跳检测: HTTP GET 到插件的 heartbeat endpoint
  │
  └── PluginHostPage → WebView 嵌入插件 UI (embedded mode)
```

### 5.2 插件 manifest 规范

当前已注册插件：`plugins/serial_assistant/manifest.json`

```json
{
  "id": "serial_assistant",
  "name": "串口助手",
  "version": "0.1.0",
  "entry": { "type": "python", "script": "launcher.py" },
  "ui": { "type": "web", "mode": "embedded" },
  "runtime": { "python": "3.12", "arch": "win_amd64" },
  "dependencies": { "mode": "plugin_local", "paths": ["vendor", "app"] },
  "permissions": ["serial", "filesystem"],
  "lifecycle": { "startup_timeout_sec": 15, "heartbeat_interval_sec": 5 }
}
```

### 5.3 与后端的关系

插件使用嵌入式 Python 运行时独立启动，不调用后端 API。插件 UI 通过 WebView 嵌入到 Flutter 桌面应用中，与后端服务无直接依赖。

## 6. 核心配置

由 `backend/app/core/config.py` 中的 `Settings` 类（基于 `pydantic_settings.BaseSettings`）管理，环境变量及 `.env` 文件提供值。关键配置项：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `app_name` | `ZYKJ MES API` | 应用名称 |
| `api_v1_prefix` | `/api/v1` | API 路由前缀 |
| `db_pool_size` | 6 | Web 数据库连接池 |
| `jwt_expire_minutes` | 120 | JWT 过期时间 |
| `maintenance_auto_generate_enabled` | true | 维保自动生成开关 |
| `maintenance_auto_generate_time` | `00:05` | 维保计划生成时间 |
| `message_delivery_maintenance_enabled` | true | 消息投递维护开关 |
| `authz_permission_cache_redis_enabled` | true | 权限缓存 Redis 开关 |

## 7. 前端模块清单

`frontend/lib/features/` 下共有 13 个业务模块：

| 模块目录 | 功能域 |
|----------|--------|
| `auth` | 认证（登录、Token 刷新、权限） |
| `craft` | 工艺管理 |
| `equipment` | 设备管理 |
| `message` | 消息中心（WebSocket 推送） |
| `misc` | 杂项（登录页、强制改密页） |
| `plugin_host` | 插件宿主管道 |
| `product` | 产品管理 |
| `production` | 生产管理（含首件检验） |
| `quality` | 质量管理 |
| `settings` | 软件设置（主题、视觉密度） |
| `shell` | 主壳/导航框架 |
| `time_sync` | 时间同步（NTP 客户端同步） |
| `user` | 用户管理 |

## 8. 技术栈

| 层 | 技术 | 说明 |
|----|------|------|
| 后端框架 | FastAPI (Python) | ASGI Web 框架 |
| 数据库 | PostgreSQL 16 | 通过 SQLAlchemy ORM 访问 |
| 缓存 | Redis 7 | 权限缓存、在线状态、会话 |
| Web 服务器 | Gunicorn + UvicornWorker | 生产环境 ASGI 服务 |
| 数据库迁移 | Alembic | Schema 版本管理 |
| 前端框架 | Flutter (Dart) | 桌面应用（Material Design） |
| HTTP 客户端 | `package:http` | Flutter 端 HTTP 调用 |
| 插件运行时 | Python 3.12 嵌入式 | 独立进程运行 |
| 容器化 | Docker Compose | 4 容器编排 |
