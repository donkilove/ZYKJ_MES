# 任务日志：后端启动脚本 Docker 化设计

- 日期：2026-04-18
- 执行人：Codex
- 当前状态：进行中
- 当前状态：待审阅

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
## 5. 迁移说明

- 无迁移，直接替换
