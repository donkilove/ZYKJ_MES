# 任务日志：后端启动脚本 Docker 化设计

- 日期：2026-04-18
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源

- 用户指令：修改 `start_backend.py`，希望它能自动构建 Docker 运行环境，并让数据库端口和 Redis 不再向宿主暴露，只给容器内 Python 后端使用。
- 需求基线：
  - `start_backend.py`
  - `compose.yml`
  - `Dockerfile`
  - `backend/README.md`

## 1.1 前置说明

- 默认主线工具：`Sequential Thinking`、`update_plan`、PowerShell、`git`
- 缺失工具：无
- 缺失/降级原因：无
- 替代工具：无
- 影响范围：无

## 2. 当前结论

1. 当前项目已有后端容器基础，但启动脚本与容器编排仍是两套思路。
2. 如果后端后续确定长期跑在 Docker 中，现在统一启动入口和收紧数据库/缓存暴露边界是合理方向。
3. 关键待确认项：`start_backend.py` 是不是要“默认完全切换为 Docker 编排”，还是保留本地 Python fallback 模式。
4. 新增待收敛项：需要提供数据库管理软件临时接入的显式入口，但不能破坏“默认仅容器内可见”的主线边界。
5. 关键设计决策已全部确认：
   - 默认完全切换 Docker 编排
   - 默认后台启动并打印摘要
   - 默认拉起 `backend-web + backend-worker + postgres + redis`
   - 直接改造根 `compose.yml`
   - 提供显式临时数据库暴露参数

## 3. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| B1 | `start_backend.py`、`compose.yml`、`Dockerfile`、`backend/README.md` | 2026-04-18 | 当前后端启动口径与 Docker 运行口径仍分离 | Codex |
| B2 | `docs/superpowers/specs/2026-04-18-start-backend-docker-orchestrator-design.md` | 2026-04-18 | 完整设计文档已写入并通过占位词/一致性自检 | Codex |
| B3 | `docker compose logs backend-web/backend-worker` | 2026-04-19 | 首次运行阻塞根因为镜像内入口脚本带 CRLF，导致 shebang 失效 | Codex |
| B4 | `Dockerfile` 修复后复跑 | 2026-04-19 | 入口脚本已可正常执行，不再出现 `env: 'sh\\r'` 报错 | Codex |
| B5 | `backend/.env` 与 `backend/app/core/config.py` 比对 | 2026-04-19 | `docker compose` 未显式继承 `backend/.env` 中关键变量时，会触发 `jwt_secret_key` fail-fast | Codex |
| B6 | `start_backend.py` 环境注入修复后复跑 | 2026-04-19 | `JWT_SECRET_KEY`、`BOOTSTRAP_ADMIN_PASSWORD`、`PRODUCTION_DEFAULT_VERIFICATION_CODE` 已通过脚本注入，并对历史弱值做本地安全兜底 | Codex |
| B7 | `backend-worker` 运行态日志 | 2026-04-19 | `backend/.env` 中的 `DB_HOST/DB_BOOTSTRAP_HOST=127.0.0.1` 不能直接透传到容器，需要只选择性注入安全关键变量 | Codex |
| B8 | `python start_backend.py` / `ps` / `logs --no-follow` / `--expose-db --db-port 5433` / `down` | 2026-04-19 | 默认启动、状态摘要、日志入口、临时数据库暴露和停止流程均已打通 | Codex |

## 4. 当前交付

1. 已生成设计文档：
   - `docs/superpowers/specs/2026-04-18-start-backend-docker-orchestrator-design.md`
2. 设计覆盖内容：
   - `start_backend.py` 的 Docker 编排职责
   - `compose.yml` 的宿主暴露边界
   - `--expose-db` 临时数据库管理入口
   - `backend/README.md` 与 `start_frontend.py` 的联动边界
   - 验证策略与迁移口径
3. 自检结果：
   - 未发现 `TODO` / `TBD` / 占位词
   - 设计决策与此前用户确认内容一致

## 5. 实施计划路径（2026-04-19 文档/边界切片）

1. 在 `compose.yml` 增补紧邻说明：默认不暴露 PostgreSQL 到宿主；如需宿主数据库管理软件接入，统一通过 `python start_backend.py --expose-db --db-port <port>` 临时开启。
2. 在 `backend/README.md` 收敛启动主线为 `python start_backend.py`，并补齐 `logs`、`ps`、`down` 与 `--expose-db --db-port 5433` 示例；将 `.venv + uvicorn` 调整为补充说明。
3. 检查 `start_frontend.py` 是否存在后端启动口径提示；若无则不改。
4. 执行验证：`python -m pytest backend/tests/test_start_backend_script_unit.py -q`、`docker compose config`，若改动 `start_frontend.py` 再执行 `python -m py_compile start_frontend.py`。
5. 更新日志收尾并提交中文 commit。

## 6. 已完成实施进度摘要（截至 2026-04-19）

1. `start_backend.py` Docker 编排主线已落地：默认编排 `backend-web`、`backend-worker`、`postgres`、`redis`，并支持 `logs/ps/down` 等运维子命令。
2. `compose.yml` 默认宿主暴露已收紧：PostgreSQL 与 Redis 默认不开放宿主端口，服务间通信走容器网络。
3. 文档/边界收口切片已完成：`compose.yml` 明确默认不暴露数据库且给出 `--expose-db --db-port` 临时开启路径；`backend/README.md` 已改为 `python start_backend.py` 主线并补齐 `logs`、`ps`、`down` 与 `--expose-db --db-port 5433` 示例。
4. `start_frontend.py` 已核查：未包含后端启动口径提示，本轮无需联动修改。

## 7. 验证与结果

1. `python -m pytest backend/tests/test_start_backend_script_unit.py -q`
   - 结果：通过（`16 passed`）
2. `python start_backend.py`
   - 结果：通过
   - 默认后台拉起 `backend-web`、`backend-worker`、`postgres`、`redis`
   - 脚本会打印服务集合、HTTP 地址和后续命令摘要
3. `python start_backend.py ps`
   - 结果：通过
   - 可见 4 个服务均在运行
4. `python start_backend.py logs --service backend-web --no-follow`
   - 结果：通过
   - 可读到 `gunicorn` 与应用启动日志
5. 默认数据库/缓存边界验证：`docker compose ps`
   - `backend-web` 暴露 `8000`
   - `postgres` 仅显示 `5432/tcp`
   - `redis` 仅显示 `6379/tcp`
6. `python start_backend.py --expose-db --db-port 5433`
   - 结果：通过
   - 摘要中显示数据库暴露已开启
7. `docker compose -f compose.yml -f .tmp_runtime\\start_backend.compose.override.yml ps`
   - 结果：`postgres` 出现 `127.0.0.1:5433->5432`
8. `docker port zykjsb-postgres-1`
   - 结果：`5432/tcp -> 127.0.0.1:5433`
9. `python -c "import socket; ... 127.0.0.1:5433 ..."`
   - 结果：输出 `db-port-open`
10. `python start_backend.py down`
    - 结果：通过
    - 容器、网络已清理
11. `docker compose config`
    - 结果：通过（配置可解析，且 PostgreSQL 默认仍未暴露宿主端口）
12. 未修改 `start_frontend.py`
    - 按约束无需执行 `python -m py_compile start_frontend.py`

## 8. 迁移说明

- 无迁移，直接替换
