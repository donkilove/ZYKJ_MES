# 指挥官任务日志：后端 Docker 容量评估

- 日期：2026-04-08
- 执行人：Codex 主 agent（指挥官模式）
- 当前状态：已完成
- 指挥模式：主 agent 拆解调度，子 agent 调研/执行，独立子 agent 验证

## 1. 输入来源

- 用户指令：开启指挥官模式，仔细评估现在的后端在 Docker 中运行时能同时供多少人使用。
- 需求基线：
  - `AGENTS.md`
  - `backend/`
  - Docker / Compose 相关文件
- 代码范围：
  - 后端部署与运行配置
  - 后端关键接口与数据库连接配置
  - 容量评估所需的压测与验证证据

## 2. 任务目标、范围与非目标

### 任务目标

1. 盘点当前后端在 Docker 中的实际部署与并发模型。
2. 通过静态分析与可行的本地实测，给出“同时使用人数”区间与依据。
3. 输出影响容量的关键瓶颈、假设前提与扩容建议。

### 任务范围

1. 允许读取并分析 Docker、后端、数据库与启动脚本配置。
2. 允许在本机执行安全的 Docker / shell / HTTP 压测命令。
3. 允许补充 `evidence/` 留痕。

### 非目标

1. 不修改业务代码或部署代码。
2. 不直接做生产环境容量承诺。
3. 不做超出当前仓库与本机环境边界的云侧成本设计。

## 3. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 用户会话指令 | 2026-04-08 21:43 +08:00 | 本轮任务为 Docker 后端容量评估，且必须按指挥官模式执行 | 主 agent |
| E2 | 仓库部署文件盘点 | 2026-04-08 21:46 +08:00 | 仓库根目录与 `backend/` 下未发现现成 `Dockerfile` / `compose.yml` / `docker-compose.yml` | 调研子 agent |
| E3 | `start_backend.py`、`backend/README.md`、`backend/app/db/session.py` | 2026-04-08 21:50 +08:00 | 当前后端默认口径是单进程 `uvicorn`，数据库连接池未显式调优 | 调研子 agent |
| E4 | `backend/app/api/deps.py`、`backend/app/services/authz_service.py`、`backend/app/services/user_service.py` | 2026-04-08 22:00 +08:00 | 已登录请求会触发用户读取、会话刷新与权限计算，列表页还会走 count + select，属于容量热点 | 调研子 agent |
| E5 | PostgreSQL 只读查询 | 2026-04-08 22:18 +08:00 | 当前数据库样本偏小：`sys_user=95`、`mes_order=7`、`msg_message=1269` 等；当前结论偏乐观 | 主 agent |
| E6 | Docker Desktop 与主机信息 | 2026-04-08 21:51 +08:00 | 当前 Docker daemon 可用，Linux 引擎可用资源约 `8 CPU / 15.5 GiB`；主机为 `i5-1145G7 / 34 GiB RAM` | 主 agent |
| E7 | 执行子 agent 容器压测回执 | 2026-04-08 22:16 +08:00 | 单容器单进程压测中出现 `QueuePool limit of size 5 overflow 10 reached`，连接池先成为硬瓶颈 | 执行子 agent |
| E8 | 主 agent 主机侧压测 | 2026-04-08 22:09 +08:00 | `/api/v1/users?page=1&page_size=20` 在并发 `15` 开始失败、并发 `20` 全失败；`/api/v1/auth/me` 在并发 `10` 仍相对稳定 | 主 agent |
| E9 | 主 agent 容器内顺序压测 | 2026-04-08 22:15 +08:00 | 容器内顺序请求显示应用本体大致时延：`/health≈4.86ms`、`/auth/login≈957ms`、`/auth/me≈63.77ms`、`/users≈463.72ms` | 主 agent |
| E10 | 验证子 agent 独立复核 | 2026-04-08 22:19 +08:00 | “单容器默认口径按 20-40 人保守估算”结论成立 | 验证子 agent |

## 4. 指挥拆解结果

| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 部署与并发模型盘点 | 识别 Docker 拓扑、服务入口、worker 模型、数据库与缓存瓶颈 | 已完成 | 已完成 | 给出关键配置、关键瓶颈与评估口径 | 已完成 |
| 2 | 容量压测与人数换算 | 对代表性接口进行实测或保守估算，形成人数区间 | 已完成 | 已完成 | 给出吞吐、时延、错误率与人数换算依据 | 已完成 |

## 5. 子 agent 输出摘要

- 调研摘要：
  - 仓库没有现成 Dockerfile / Compose，当前可确认的启动链路是 [start_backend.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/start_backend.py) 或 [backend/README.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/README.md) 中的 `python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`。
  - [backend/app/db/session.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/db/session.py) 只配置了 `create_engine(..., pool_pre_ping=True, future=True)`，未显式配置 `pool_size` / `max_overflow`，将落到 SQLAlchemy 默认池行为。
  - [backend/app/api/deps.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/api/deps.py) 的认证路径会读取用户、刷新 session 并写回数据库；[backend/app/services/authz_service.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/services/authz_service.py) 的权限检查每次都要重新计算有效权限，未见外部缓存。
  - [backend/app/main.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/main.py) 启动后还会拉起消息维护循环和保养调度循环；后续若加 worker / 多副本，这两个循环会按进程重复执行。
- 执行摘要：
  - 执行子 agent 以 `python:3.12-slim` 基线镜像在 Docker 中拉起单容器单进程 uvicorn，成功验证 `/health`、`/api/v1/auth/bootstrap-admin`、`/api/v1/auth/login`、`/api/v1/auth/me`、`/api/v1/users?page=1&page_size=20` 可访问。
  - 主 agent 另起等价临时容器，对运行态做补充压测；主机侧压测中，`/api/v1/users?page=1&page_size=20` 在并发 `15` 出现 `12.5%` 超时、并发 `20` 时 `100%` 超时；`/api/v1/auth/me` 在并发 `10` 时仍能保持 `24.86 RPS / P95 703ms`。
  - 容器内顺序压测结果：
    - `/health`：平均 `4.86ms`
    - `/api/v1/auth/login`：平均 `957.16ms`
    - `/api/v1/auth/me`：平均 `63.77ms`
    - `/api/v1/users?page=1&page_size=20`：平均 `463.72ms`
  - 主机侧压测中，`/health` 最高可见约 `49.21 RPS`，但该数字明显受 Windows Docker Desktop 端口映射开销影响，不作为业务容量主结论。
- 验证摘要：
  - 验证子 agent 认为“单容器、单进程 uvicorn、默认连接池配置下，先按 20-40 人同时使用估算”结论通过。
  - 通过理由：默认连接池未调优，压测期间已出现 `QueuePool size 5 + overflow 10` 耗尽；业务列表接口在并发 `15` 开始失败，而轻鉴权接口在并发 `10` 仍较稳。

## 6. 失败重试记录

| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 容量压测与人数换算 | 初次全量压测脚本在主机侧超时，未收敛出完整场景表 | 单次脚本覆盖场景过多，且业务接口已在高并发下撞上连接池等待 | 拆为分场景、小样本压测，并增加容器内顺序压测用于隔离 Docker Desktop 网络开销 | 已收口 |

## 7. 工具降级、硬阻塞与限制

- 不可用工具：无
- 降级原因：无
- 替代流程：无
- 影响范围：无
- 补偿措施：无
- 硬阻塞：
  - 初始状态 Docker daemon 未启动，无法直接进入容器压测。
  - 已处理动作：主 agent 启动 Docker Desktop，待 `docker info` 可用后继续执行。
- 已知限制：
  - 当前仓库没有现成 Dockerfile / Compose，压测容器是“按当前仓库默认运行方式临时构造”的单容器基线。
  - 当前数据库数据量偏小，尤其 `mes_order=7`、`mes_first_article_record=2`，因此业务查询吞吐结论偏乐观。
  - 主机到 Docker Desktop 的端口映射开销会放大轻接口时延，所以人数结论以“保守区间”呈现，不给出精确上限。

## 8. 交付判断

- 已完成项：
  - 已盘点当前后端在 Docker 中的实际运行口径与主要瓶颈。
  - 已完成单容器单进程基线压测与容器内顺序压测。
  - 已给出“同时使用人数”的保守区间和支撑依据。
  - 已由独立验证子 agent 复核通过。
- 未完成项：
  - 无现成生产 Docker 编排文件，无法直接对“正式生产编排”做等价压测。
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明

- 无迁移，直接替换。
