# 后端启动脚本 Docker 编排控制器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `start_backend.py` 默认切换为 Docker 编排控制器，统一后端启动入口，并让 PostgreSQL / Redis 默认仅容器内可见，同时保留显式临时数据库管理入口。

**Architecture:** 先用单元测试锁定新的脚本行为，再重写 `start_backend.py` 围绕 `docker compose build/up/down/logs/ps/restart/rebuild` 工作；随后收紧根 `compose.yml` 的默认暴露边界，补齐 README 和运行态验证，并在 Windows 场景下收口脚本行尾与编码问题。

**Tech Stack:** Python 3.12、argparse、subprocess、Docker Compose、FastAPI、PostgreSQL 16、Redis 7、pytest/unittest

---

### Task 1: 将 `start_backend.py` 切换为 Docker 编排控制器

**Files:**
- Modify: `start_backend.py`
- Modify: `backend/tests/test_start_backend_script_unit.py`

- [ ] 新增并通过参数解析、compose 命令拼装、数据库临时暴露、日志流式输出、健康检查与环境注入相关单测。
- [ ] 删除旧本地 `.venv + uvicorn/gunicorn + 本地 PostgreSQL` 主线逻辑。
- [ ] 实现 `up/logs/ps/down/restart/rebuild`。
- [ ] 允许 `--expose-db --db-port <port>` 通过 override 文件临时开放 PostgreSQL 给宿主。

### Task 2: 收紧 `compose.yml` 默认宿主暴露边界

**Files:**
- Modify: `compose.yml`

- [ ] 删除 `postgres` 默认 `ports`
- [ ] 保持 `redis` 无宿主端口暴露
- [ ] 保留 `backend-web` 的宿主 HTTP 端口映射
- [ ] 补充注释，说明数据库临时宿主接入应通过 `start_backend.py --expose-db`

### Task 3: 补齐文档口径

**Files:**
- Modify: `backend/README.md`
- Modify: `evidence/task_log_20260418_后端启动脚本Docker化设计.md`

- [ ] 将默认启动主线改为 `python start_backend.py`
- [ ] 补充 `logs`、`ps`、`down`
- [ ] 补充 `--expose-db --db-port 5433`
- [ ] 移除已失效的旧参数说明

### Task 4: 运行态阻塞收口

**Files:**
- Modify: `Dockerfile`
- Modify: `start_backend.py`
- Modify: `backend/.env`
- Modify: `backend/tests/test_start_backend_script_unit.py`

- [ ] 在镜像构建阶段统一修复 `docker/*.sh` 的 CRLF 行尾
- [ ] 只选择性注入 `backend/.env` 中的安全关键变量，避免把 `DB_HOST=127.0.0.1` 之类本地主机值透传进容器
- [ ] 收口 Windows 下 `docker compose` 输出解码问题
- [ ] 收口 worker 启动时的安全关键配置问题

### Task 5: 完整验证与留痕

**Files:**
- Modify: `evidence/task_log_20260418_后端启动脚本Docker化设计.md`

- [ ] `python -m pytest backend/tests/test_start_backend_script_unit.py -q`
- [ ] `python start_backend.py`
- [ ] `python start_backend.py ps`
- [ ] `python start_backend.py logs --service backend-web --no-follow`
- [ ] 验证默认模式下 PostgreSQL / Redis 不对宿主暴露
- [ ] `python start_backend.py --expose-db --db-port 5433`
- [ ] 验证 `127.0.0.1:5433` 可连接 PostgreSQL
- [ ] `python start_backend.py down`

## 自检结论

1. 计划覆盖了脚本、compose、文档、运行态阻塞和最终验证。
2. 无占位符。
3. 与批准后的 spec 一致。
