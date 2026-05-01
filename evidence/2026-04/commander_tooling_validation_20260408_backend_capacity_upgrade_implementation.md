# 工具化验证日志：后端容量升级实施

- 执行日期：2026-04-08
- 对应主日志：`evidence/commander_execution_20260408_backend_capacity_upgrade_implementation.md`
- 当前状态：已完成（真实容器压测门禁已收口）

## 1. 任务分类

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | Docker 生产化与容量整改 | 涉及本地联调、部署口径、压测门禁与数据库边界 | G1~G7 |

## 2. 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | Sequential Thinking | 默认 | 拆解容量整改实施路径 | 执行分解与风险识别 | 2026-04-08 |
| 2 | 启动 | update_plan | 默认 | 维护实施计划 | 可追踪步骤状态 | 2026-04-08 |
| 3 | 执行 | Serena + PowerShell | 降级 | `rg` 不可用，改走语义检索与文本检索 | 代码定位与改造落点 | 2026-04-08 |
| 4 | 执行 | `apply_patch` | 默认 | 实施后端/部署/工具链改造 | 代码落地 | 2026-04-08 |
| 5 | 验证 | `python -m pytest` | 默认 | 验证新增与改造单测 | 回归结果 | 2026-04-08 |
| 6 | 验证 | `docker compose config` | 默认 | 验证 compose 语法与服务编排 | 配置有效性 | 2026-04-08 |
| 7 | 验证 | `python tools/project_toolkit.py backend-capacity-gate --help` | 默认 | 验证新命令接入 | CLI 可用性 | 2026-04-08 |
| 8 | 验证 | `backend-capacity-gate` 最小运行 | 默认 | 验证门禁脚本执行与阈值退出码 | 非零退出符合预期 | 2026-04-08 |

## 3. 执行留痕

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `apply_patch` | `evidence/` | 建立主日志与验证日志 | 已完成 | 本文件与主日志 |
| 2 | `apply_patch` | 后端热点文件 | 落地连接池、节流、缓存、worker 入口 | 已完成 | `backend/app/**` |
| 3 | `apply_patch` | 部署文件 | 落地 Dockerfile/compose/entrypoint | 已完成 | 根目录部署文件 |
| 4 | `apply_patch` | 工具脚本 | 新增 `backend-capacity-gate` | 已完成 | `tools/project_toolkit.py` `tools/perf/**` |

## 4. 验证留痕

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | I1 | 已映射 CAT-05 |
| G2 | 通过 | I1 | 已记录默认工具触发 |
| G3 | 通过 | I2~I4 | 已完成执行与验证闭环 |
| G4 | 通过 | I5~I7 | 已有真实命令验证 |
| G5 | 通过 | I1~I7 | evidence 已完成闭环 |
| G6 | 通过 | I3 | `rg` 降级已补偿 |
| G7 | 通过 | I2 | 迁移口径“无迁移，直接替换” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `.venv\\Scripts\\python.exe -m pytest` | 新增/改造单测 | `backend/tests/test_session_service_unit.py` `backend/tests/test_authz_service_unit.py` `backend/tests/test_app_startup_worker_split.py` | 通过（8 passed） | 通过 |
| `docker compose config` | 部署编排 | 解析 `compose.yml` | 通过 | 通过 |
| `python tools/project_toolkit.py backend-capacity-gate --help` | CLI 接入 | 打印子命令帮助 | 通过 | 通过 |
| `python tools/project_toolkit.py backend-capacity-gate ...` | 门禁执行路径 | 最小参数执行（无可达后端） | 返回 `exit 1`，输出 `gate_passed=false` | 行为符合门禁判定 |

## 5. 失败重试

| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 无 | 无 | 无 | 无 | 无 | 无 |

## 6. 降级/阻塞/代记

- 工具降级：`rg` 不可用，降级 Serena + PowerShell。
- 阻塞记录：无硬阻塞。
- evidence 代记：主 agent 直接记录，来源为本轮会话与命令执行结果

## 7. 通过判定

- 是否完成闭环：是
- 是否满足门禁：否
- 是否存在残余风险：有（当前稳定容量低于 40 人，需继续扩容或调参后复测）
- 最终判定：不通过（真实容器压测未达到发布门禁）

## 8. 迁移说明

- 无迁移，直接替换。

## 9. 真实压测阶段追加记录

- 启动时间：2026-04-08 23:39:40 +08:00
- 收尾时间：2026-04-09 01:18:43 +08:00
- 当前状态：已完成（真实容器压测门禁已收口）

### 9.1 工具触发补充

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 9 | 启动 | Sequential Thinking | 默认 | 拆解真实压测阶段执行顺序与风险 | 压测阶段任务拆解 | 2026-04-08 23:39:40 +08:00 |
| 10 | 启动 | update_plan | 默认 | 维护真实压测阶段步骤状态 | 可追踪压测计划 | 2026-04-08 23:39:40 +08:00 |
| 11 | 执行 | Serena + PowerShell | 降级 | `rg` 不可用，需定位账号池/数据入口并执行容器命令 | 前置条件确认与容器执行结果 | 2026-04-08 23:39:40 +08:00 |
| 12 | 执行 | `docker compose` | 默认 | 启动正式容器栈并确认健康状态 | 真实容器运行证据 | 2026-04-08 23:41 ~ 23:42 +08:00 |
| 13 | 执行 | PowerShell HTTP 探针 | 默认 | 验证管理员登录与目标接口可达性 | 压测前置接口可用性证据 | 2026-04-08 23:42 ~ 23:44 +08:00 |
| 14 | 执行 | PowerShell 批量调用 API | 默认 | 创建压测账号池并统一重置口令 | 多 token 账号池 | 2026-04-08 23:44 ~ 2026-04-09 00:56 +08:00 |
| 15 | 执行 | PowerShell + `psql` | 默认 | 核对订单样本与账号池数量 | 数据样本真实性证据 | 2026-04-09 01:15 +08:00 |
| 16 | 验证 | `backend-capacity-gate` | 默认 | 执行 `40/80/120/150` 梯度压测 | JSON 结果与门禁判定 | 2026-04-09 00:02 ~ 01:17 +08:00 |
| 17 | 验证 | `docker logs` / `docker stats` / `docker inspect` | 默认 | 采集容器异常、资源与运行状态 | 限制因素与异常信号证据 | 2026-04-09 01:10 ~ 01:18 +08:00 |
| 18 | 验证 | `backend-capacity-gate` | 默认 | 追加执行 `5/10/20` 边界补测与 `80` 官方复跑 | 下边界与重试一致性证据 | 2026-04-09 02:10 ~ 02:27 +08:00 |
| 19 | 收尾 | `apply_patch` | 默认 | 回填最终压测边界到 evidence | 闭环留痕 | 2026-04-09 02:28 +08:00 |

### 9.2 执行留痕补充

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 5 | `apply_patch` | `evidence/` | 追加真实压测阶段启动与收尾留痕 | 已完成 | 本文件与主日志追加记录 |
| 6 | `docker compose up -d --build` | 正式容器栈 | 启动 `postgres` `redis` `backend-web` `backend-worker` | 成功启动，`/health` 返回 `200` | `docker compose ps` |
| 7 | PowerShell HTTP 探针 | `authz/users/production/orders/stats` | 直连验证管理员与压测账号 | 目标接口均返回 `200` | 命令输出 |
| 8 | PowerShell 批量 API 调用 | 压测账号池 | 先尝试 `perfadmin*`，后改为 `pa1..160` 并统一重置密码为 `Load@2026Aa` | 最终可复用账号 `160` 个 | 命令输出 |
| 9 | PowerShell + `psql` | 业务样本 | 通过真实 API 补单并通过数据库核对 | 订单样本 `308` 条，状态分布有效 | 命令输出 |
| 10 | `backend-capacity-gate` | `.tmp_runtime/capacity_*.json` | 执行正式四档真实压测并落盘 | 四档均生成结果文件 | `.tmp_runtime/capacity_40.json` 等 |
| 11 | `docker logs` / `docker stats` | Web / DB / Redis 容器 | 采集异常堆栈与资源 | 观察到 worker recycle 与 QueuePool 超时 | 日志与资源采样 |
| 12 | `backend-capacity-gate` | `.tmp_runtime/capacity_5.json` 等 | 追加执行 `5/10/20` 与 `80` 官方复跑 | 已收窄严格门禁下的容量上限 | 边界补测结果文件 |

### 9.3 验证留痕补充

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | I8 | 真实压测仍归类 CAT-05 |
| G2 | 通过 | I8~I15 | 默认工具与降级原因已补齐 |
| G3 | 通过 | I9~I15 | 已形成执行与独立核对闭环 |
| G4 | 通过 | I9~I15 | 有真实容器命令、真实接口、真实压测 JSON、真实日志与数据库核对 |
| G5 | 通过 | I8~I15 | evidence 已串起“启动 -> 准备 -> 压测 -> 重试 -> 收口” |
| G6 | 通过 | I8 | `rg` 降级已代偿 |
| G7 | 通过 | I2 | 迁移口径仍为“无迁移，直接替换” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `docker compose ps` + `/health` | 正式容器栈 | 启动后检查服务状态与健康接口 | 通过 | 容器栈可用于真实压测 |
| PowerShell HTTP 探针 | 压测账号抽样 | 登录 `pa1/pa40/pa80/pa120/pa160` 并访问目标接口 | 全部 `200` | 压测账号池可用 |
| `docker exec ... psql` | 压测数据样本 | 核对 `pa%` 用户数与订单状态分布 | `160` 用户、`308` 订单 | 压测样本有效 |
| `backend-capacity-gate` 5 | 边界补测 | `.tmp_runtime/capacity_5.json` | `error_rate 0.00%`，`P95 779.09ms` | 不通过 |
| `backend-capacity-gate` 10 | 边界补测 | `.tmp_runtime/capacity_10.json` | `error_rate 0.00%`，`P95 1233.96ms` | 不通过 |
| `backend-capacity-gate` 20 | 边界补测 | `.tmp_runtime/capacity_20.json` | `error_rate 0.38%`，`P95 2810.25ms` | 不通过 |
| `backend-capacity-gate` 40 | 门禁第一档 | `.tmp_runtime/capacity_40.json` | `error_rate 0.57%`，`P95 3551.79ms` | 不通过 |
| `backend-capacity-gate` 40 重试 | 失败重试 | `.tmp_runtime/capacity_40_retry.json` | `error_rate 1.30%`，`P95 3158.94ms` | 不通过 |
| `backend-capacity-gate` 80 | 门禁第二档 | `.tmp_runtime/capacity_80.json` | `error_rate 22.08%`，`P95 10143.33ms` | 不通过 |
| `backend-capacity-gate` 80 官方重试 | 失败重试 | `.tmp_runtime/capacity_80_retry_official.json` | `error_rate 0.98%`，`P95 7754.89ms` | 不通过 |
| `backend-capacity-gate` 120 | 门禁第三档 | `.tmp_runtime/capacity_120.json` | `error_rate 5.19%`，`P95 9997.39ms` | 不通过 |
| `backend-capacity-gate` 150 | 门禁第四档 | `.tmp_runtime/capacity_150.json` | `error_rate 23.92%`，`P95 10057.88ms` | 不通过 |
| `docker logs backend-web` | 容器异常 | 检查 worker recycle 与连接池异常 | 命中 `Maximum request limit` 与 `QueuePool ... timeout 15.00` | 确认关键瓶颈 |

### 9.4 失败重试补充

| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 账号池创建 | `perfadmin10+` 创建返回 `422` | 用户名长度上限 `10` | 改用短前缀 `pa` | 用户列表核对 | 通过 |
| 2 | token 预取 | `failed to acquire any token from login flow` | 新建账号初始密码不可稳定复用 | 批量执行 `reset-password` 统一口令 | 登录抽样探针 | 通过 |
| 3 | 40 档门禁 | 出现 `EXC` 与高延迟 | Worker recycle 与连接池争用叠加 | 退避 2 秒后重试一次 | `capacity_40_retry.json` | 仍不通过 |
| 4 | 80 档门禁 | 外层命令先超时，但 JSON 已落盘 | 压测尾部回收时间超过工具等待窗口 | 读取结果文件收口，不重跑第二次 | `capacity_80.json` | 已补证 |
| 5 | 80 档复检 | 首次结果波动较大 | 需要验证 80 档是否稳定失稳 | 退避后执行官方重试一次 | `capacity_80_retry_official.json` | 仍不通过 |

### 9.5 阶段判定

- 是否完成闭环：是
- 是否满足门禁：否
- 是否存在残余风险：有（严格门禁下稳定容量低于 5 人；Web 连接池、登录链路与 worker recycle 仍会在正式压测中触发）
- 最终判定：不通过（真实容器压测未达到发布门禁）

## 10. 修复回合追加记录

- 启动时间：2026-04-09 02:35 +08:00
- 当前状态：进行中（代码修复与定向回归已完成，待重跑 `20/40/80` 门禁）
- 本阶段新增工具：
  - Sequential Thinking
  - update_plan
  - 执行子 agent
  - 独立验证子 agent

### 10.1 工具触发补充

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 20 | 执行 | 执行子 agent | 默认 | 分离“热路径修复”和“Web 侧部署参数修复”两个原子任务 | 子 agent 回执与限定文件改动 | 2026-04-09 01:20 ~ 01:58 +08:00 |
| 21 | 执行 | `apply_patch` | 默认 | 合并登录/鉴权/session/user/deploy 最小修复面 | 代码改动与单测同步更新 | 2026-04-09 01:40 ~ 01:56 +08:00 |
| 22 | 验证 | `.venv\\Scripts\\python.exe -m pytest` / `python -m pytest` | 默认 | 验证 session/authz/deps/login/deploy 与关键集成路径 | 真实通过结果 | 2026-04-09 01:47 ~ 01:57 +08:00 |
| 23 | 收尾 | `apply_patch` | 默认 | 主 agent 代记子 agent 结果并补 evidence | 修复回合留痕闭环 | 2026-04-09 01:58 ~ 02:00 +08:00 |

### 10.2 执行留痕补充

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 13 | 执行子 agent + `apply_patch` | `auth.py/deps.py/session_service.py/authz_service.py/user_service.py` | 收敛登录与鉴权热路径 | 已降低登录成功路径同步库操作、session 热读写与 authz 默认初始化频率 | 代码变更 |
| 14 | 执行子 agent + `apply_patch` | `config.py/session.py/compose.yml/web-entrypoint.sh/.env.example` | 重算 Web/Worker DB 池预算并关闭 `gunicorn max_requests` 默认值 | 已完成参数收敛与 SQLite 兼容修复 | 代码变更 |
| 15 | `apply_patch` | `backend/tests/*.py` | 补充 session/authz/deps/login 相关定向测试 | 新增/更新用例已通过 | 测试文件 |

### 10.3 验证留痕补充

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G3 | 通过 | R7 | 已完成执行子 agent 回执与主 agent 集成 |
| G4 | 通过 | R8 | 有真实 `pytest` 结果，覆盖热路径与关键集成场景 |
| G5 | 通过 | R6~R8 | 已串起“启动 -> 修复 -> 验证 -> 待复测” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `python -m pytest` | `session/authz/db/app-startup` | `backend/tests/test_session_service_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_db_session_config_unit.py backend/tests/test_app_startup_worker_split.py` | `17 passed` | 通过 |
| `python -m pytest` | `deps/login unit` | `backend/tests/test_api_deps_unit.py backend/tests/test_auth_endpoint_unit.py` | `3 passed` | 通过 |
| `python -m pytest` | `user login/session integration` | `backend/tests/test_user_module_integration.py -k "test_auth_login_rejects_missing_pending_rejected_disabled_and_deleted_accounts or test_auth_login_success_persists_side_effects_and_auth_contracts or test_me_session_returns_404_when_token_sid_is_missing or test_sessions_filters_and_me_session_foreign_or_expired"` | `4 passed, 37 deselected` | 通过 |

### 10.4 二次迭代与最终门禁复测

| 阶段 | 工具 | 对象 | 动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- | --- |
| 修复 | `apply_patch` | `core/security.py` `auth.py` `test_security_unit.py` | 增加成功验密缓存并接入登录链路 | 已完成 | 进入复测 |
| 验证 | `python -m pytest` | `security/session/authz/deps/auth` | `backend/tests/test_security_unit.py backend/tests/test_session_service_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_api_deps_unit.py backend/tests/test_auth_endpoint_unit.py` | `20 passed` | 通过 |
| 验证 | `python -m pytest` | `user login integration` | `backend/tests/test_user_module_integration.py -k "test_auth_login_rejects_missing_pending_rejected_disabled_and_deleted_accounts or test_auth_login_success_persists_side_effects_and_auth_contracts or test_change_password_requires_immediate_relogin"` | `3 passed, 38 deselected` | 通过 |
| 试验 | `docker compose up -d --force-recreate` | `backend-web` | 临时切到 `WEB_CONCURRENCY=8`、`DB_POOL_SIZE=4`、`DB_MAX_OVERFLOW=1` | 压测变差 | 不采纳 |
| 门禁 | `backend-capacity-gate` | `.tmp_runtime/capacity_fix_round4_20_pwdcache.json` | 默认正式口径复测 `20` | `gate_passed=true`，overall `P95 491.15ms` | 通过 |
| 门禁 | `backend-capacity-gate` | `.tmp_runtime/capacity_fix_round4_40_pwdcache.json` | 默认正式口径复测 `40` | `gate_passed=true`，overall `P95 499.04ms` | 通过 |
| 门禁 | `backend-capacity-gate` | `.tmp_runtime/capacity_fix_round4_80_pwdcache.json` | 默认正式口径复测 `80` | `gate_passed=false`，overall `P95 988.37ms` | 不通过 |

### 10.5 当前判定更新

- 是否完成闭环：是
- 是否满足门禁：是（最低要求 `40` 已通过）
- 是否存在残余风险：有（`80` 并发仍未通过，当前上限位于 `40~80` 之间）
- 最终判定：通过（满足用户最低要求 `40` 通过）

## 11. 其余链路 40 并发检查启动记录

- 启动时间：2026-04-09 02:22 +08:00
- 当前状态：进行中

### 11.1 工具触发预告

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 24 | 启动 | Sequential Thinking | 默认 | 重新定义“其余链路”范围与验证分层 | 可执行清单与检查策略 | 2026-04-09 02:22 +08:00 |
| 25 | 启动 | update_plan | 默认 | 维护其余链路 40 并发检查步骤 | 可追踪计划 | 2026-04-09 02:22 +08:00 |
| 26 | 启动 | 执行/调研子 agent | 默认 | 盘点路由清单、定位 perf 工具扩展点 | 路由分层与实现建议 | 2026-04-09 02:22 +08:00 |
| 27 | 调研 | PowerShell 文本检索 | 降级 | `rg` 不可用，需补 route/endpoint 盘点 | 路由分层与代表性链路清单 | 2026-04-09 09:40 ~ 09:55 +08:00 |
| 28 | 调研 | 调研子 agent 回执代记 | 默认 | 收口“其余链路”清单与 perf 工具最小改造方案 | evidence 代记与原子任务输入 | 2026-04-09 09:55 +08:00 |

### 11.2 当前分类判定

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 其余认证读链路 40 并发门禁 | 目标是基于正式容器口径做真实压测与健康核对，属于本地联调与启动/健康检查延伸 | G1~G7 |

### 11.3 当前分层结论

- 可直接进入真实 `40` 并发压测的代表性只读链路：
  - `GET /api/v1/auth/me`
  - `GET /api/v1/auth/accounts`
  - `GET /api/v1/me/profile`
  - `GET /api/v1/me/session`
  - `GET /api/v1/sessions/login-logs`
  - `GET /api/v1/sessions/online`
  - `GET /api/v1/audits`
  - `GET /api/v1/roles`
  - `GET /api/v1/messages/unread-count`
  - `GET /api/v1/messages/summary`
  - `GET /api/v1/messages`
  - `GET /api/v1/products`
  - `GET /api/v1/products/parameter-query`
  - `GET /api/v1/craft/stages`
  - `GET /api/v1/craft/stages/light`
  - `GET /api/v1/craft/processes`
  - `GET /api/v1/craft/processes/light`
  - `GET /api/v1/equipment/ledger`
  - `GET /api/v1/equipment/items`
  - `GET /api/v1/equipment/plans`
  - `GET /api/v1/equipment/executions`
  - `GET /api/v1/equipment/records`
  - `GET /api/v1/equipment/rules`
  - `GET /api/v1/equipment/runtime-parameters`
  - `GET /api/v1/quality/stats/overview`
  - `GET /api/v1/quality/stats/processes`
  - `GET /api/v1/quality/stats/operators`
  - `GET /api/v1/quality/stats/products`
  - `GET /api/v1/quality/trend`
  - `GET /api/v1/quality/defect-analysis`
  - `GET /api/v1/quality/scrap-statistics`
  - `GET /api/v1/quality/repair-orders`
  - `GET /api/v1/quality/suppliers`
- 需要补通用 URL/方法/请求体能力后再测的链路：
  - 详情类 GET
  - 生产模块剩余读链路
  - `GET /api/v1/ui/page-catalog`
  - `GET /api/v1/processes`
  - 少量可重复 POST 代表链路
- 暂不纳入本轮真实 `40` 并发门禁的链路：
  - 导出/下载/流式
  - 强副作用账户链路
  - 会话/消息运维链路
  - 生命周期/发布/导入/回滚类写链路

### 11.4 当前门禁检查状态

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | R9~R11 | “其余链路”范围已收口并分类 |
| G2 | 通过 | 24~28 | 默认工具与 `rg` 降级原因已记录 |
| G3 | 进行中 | R10~R11 | 已有调研子 agent，待进入执行/独立验证闭环 |
| G4 | 进行中 | R9~R11 | 真实 `40` 并发结果尚未补录 |
| G5 | 进行中 | R9~R11 | 启动与调研已留痕，待接续执行/验证/收口 |
| G6 | 通过 | 27 | `rg` 不可用已代偿为 Serena/PowerShell |
| G7 | 通过 | I2 | 迁移口径仍为“无迁移，直接替换” |

### 11.5 其余链路 40 并发执行留痕

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 29 | `apply_patch` | `tools/perf/scenarios/remaining_read_40_scan.json` | 新增其余链路只读扫描场景文件 | 纳入 `63` 条可认证只读链路 | 场景配置文件 |
| 30 | `python -m tools.project_toolkit backend-capacity-gate` | `auth-me` | 单场景自定义配置冒烟 | `gate_passed=true`，确认 `--scenario-config-file` 可用 | `.tmp_runtime/remaining_auth_me_40.json` |
| 31 | 内联 Python + HTTP | `pa1..pa40` | 生成统一 token 文件 | 成功生成 `40` 个 token，后续压测复用 | `.tmp_runtime/pa_tokens_40.txt` |
| 32 | 内联 Python + `backend-capacity-gate` | `63` 条首轮场景 | 单链路逐条执行 `40` 并发门禁并逐条落盘 | 完成首轮全量结果 | `.tmp_runtime/remaining_read_40/`、`.tmp_runtime/remaining_read_40_summary.json` |
| 33 | 内联 Python + `backend-capacity-gate` | `auth-accounts/authz-snapshot/me-session/production-data-today-realtime/production-assist-authorizations` | 独立复核抽样复跑 | 复核确认存在“首轮通过后翻转失败”现象 | `.tmp_runtime/remaining_read_40_verify_summary.json` |
| 34 | 内联 Python + `backend-capacity-gate` | 首轮 `10` 条通过链路 | 全量二次复核 | 仅 `quality-repair-orders` 保持通过，其余 `9` 条翻转失败 | `.tmp_runtime/remaining_read_40_reverify_passes_summary.json` |
| 35 | `docker stats --no-stream` | 容器资源 | 采样 Web/Postgres 资源占用 | Web 约 `405.29% CPU`、`1.77GiB`；Postgres 约 `106.52% CPU` | 终端输出 |

### 11.6 其余链路 40 并发验证留痕

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | R12 | 已固化 `63` 条其余只读链路清单 |
| G2 | 通过 | 29~35 | 执行工具、门禁参数与复核步骤均可追溯 |
| G3 | 通过（降级代偿） | R13 | 子 agent 调度未形成可用回执，改以“独立复核脚本 + 单独结果目录”代偿执行/验证分离 |
| G4 | 通过 | R14 | 已完成首轮全量 `63` 条真实 `40` 并发命令与二次复核 |
| G5 | 通过 | R9~R14 | 已形成“启动 -> 调研 -> 执行 -> 复核 -> 收口”闭环 |
| G6 | 通过 | 27、R13 | `rg` 不可用与子 agent 调度异常均已记录代偿 |
| G7 | 通过 | I2 | 迁移口径不变 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `backend-capacity-gate` | `63` 条其余只读链路 | `40` 并发、`20` 会话池、`6s` 测量、`2s` warmup、复用 `40` token | 首轮 `10` 通过、`53` 不通过 | 首轮仅少量边界通过 |
| `backend-capacity-gate` | `5` 条抽样链路 | 独立复核抽样复跑 | `1` 条首轮通过链路翻转失败，`3` 条失败链路复核仍失败 | 首轮存在边界波动 |
| `backend-capacity-gate` | 首轮 `10` 条通过链路 | 全量二次复核 | 仅 `quality-repair-orders` 保持通过 | 稳定通过口径需收缩为 `1/63` |

### 11.7 当前轮最终判定

- 是否完成闭环：是
- 是否满足门禁：否
- 是否存在残余风险：有
- 最终判定：不通过

### 11.8 当前轮结论摘要

- 已真实检查其余 `63` 条认证后只读链路。
- 稳定满足 `40` 并发门禁的仅 `quality-repair-orders` 一条。
- 其余 `62` 条已测链路均不能宣告满足 `40` 并发要求：
  - `53` 条首轮即未通过；
  - `9` 条首轮通过但在二次复核中翻转失败。
- 本轮未纳入真实 `40` 的仍是详情类 GET、导出/下载/流式、强副作用写链路与生命周期/发布/导入/回滚类接口。

### 11.9 降级/阻塞/代记补充

- 工具降级：
  - `rg` 不可用，继续降级为 PowerShell 文本检索。
  - 子 agent 调度未在可接受时间内返回可用回执，主线改为“脚本执行目录 + 独立复核目录”代偿执行/验证分离。
- 阻塞记录：无硬阻塞。
- evidence 代记：
  - 主 agent 代记本轮调研、执行与复核摘要。
  - 代记时间：2026-04-09 10:17 +08:00
  - 原始来源：`.tmp_runtime/remaining_read_40_summary.json`、`.tmp_runtime/remaining_read_40_verify_summary.json`、`.tmp_runtime/remaining_read_40_reverify_passes_summary.json`
  - 适用结论：除 `quality-repair-orders` 外，其余已测链路均未证明满足稳定 `40` 并发门禁。

## 12. 其余失败链路 40 并发修复回合

- 启动时间：2026-04-09 10:25 +08:00
- 当前状态：进行中

### 12.1 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 36 | 启动 | Sequential Thinking | 默认 | 复盘失败链路共性热点，定义修复顺序 | 本轮修复策略与代表样本 | 2026-04-09 10:25 +08:00 |
| 37 | 启动 | update_plan | 默认 | 维护修复循环步骤与状态 | 可追踪计划 | 2026-04-09 10:25 +08:00 |
| 38 | 启动 | `apply_patch` | 默认 | 补本轮启动 evidence 与原子任务拆解 | 留痕闭环 | 2026-04-09 10:25 +08:00 |

### 12.2 当前门禁状态

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | R15 | 已定义“其余失败链路修复回合”范围 |
| G2 | 通过 | 36~38 | 工具触发依据已记录 |
| G3 | 进行中 | R15 | 待形成执行子 agent 与独立验证子 agent 闭环 |
| G4 | 进行中 | R15 | 本轮尚未产生新的真实回归结果 |
| G5 | 进行中 | R15 | 已有启动留痕，待补执行/验证/收口 |
| G6 | 通过 | 27 | `rg` 降级口径延续 |
| G7 | 通过 | I2 | 迁移口径不变 |

### 12.3 当前轮补充触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 39 | 调研 | `wait_agent/send_input` | 补充 | 收口上一轮悬挂调研子 agent，避免空转阻塞主线 | 可复用的热点摘要 | 2026-04-09 10:30 +08:00 |
| 40 | 调研 | Serena + PowerShell | 默认 + 降级 | 核对 `deps/session/authz/message` 当前实现与未提交改动 | 最小修复边界 | 2026-04-09 10:33 +08:00 |
| 41 | 执行 | `spawn_agent` | 默认 | 派发业务热路径执行子 agent | 会话/鉴权热路径修复回执 | 2026-04-09 10:35 +08:00 |
| 42 | 执行 | `spawn_agent` | 默认 | 派发消息读链路执行子 agent | 消息热路径修复回执 | 2026-04-09 10:36 +08:00 |
| 43 | 留痕 | `apply_patch` | 默认 | 追加本轮失败聚类、热点诊断与子 agent 拆解 | evidence 闭环 | 2026-04-09 10:37 +08:00 |

### 12.4 当前轮调研结论

- 代表样本固定为：
  - `me-session`
  - `sessions-online`
  - `authz-snapshot`
  - `ui-page-catalog`
  - `auth-accounts`
- 当前已确认的共性热点：
  - session 读链路内清理与触达写放大；
  - `sessions/online` 的角色/工序阶段信息存在 `N+1` 风险；
  - authz 读接口缺少顶层读模型缓存；
  - 消息读接口仍同步跑 `run_message_maintenance()`；
  - Web 侧当前更像连接池争用与热路径多余读写叠加，而非 Postgres `max_connections` 打满。

### 12.5 当前轮执行/验证分离状态

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G3 | 进行中 | R15 | `Lagrange` 负责会话/鉴权热路径修复；`Linnaeus` 负责消息读链路修复；独立验证子 agent 待在实现回执后派发 |

### 12.6 当前轮执行留痕补充

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 44 | `spawn_agent` | `deps/session/authz/authz_snapshot` 热路径 | 派发执行子 agent 实现会话、鉴权热路径修复 | 已落地代码与定向单测 | 工作树改动 |
| 45 | `spawn_agent` | `message_service` 热路径 | 派发执行子 agent 剥离消息读请求中的同步维护 | 已落地代码与定向单测 | 工作树改动 |
| 46 | `spawn_agent` | `session_service` 正确性尾巴 | 派发最小执行子 agent 收口会话缓存 TTL 上限 | 已落地代码与定向单测 | 工作树改动 |
| 47 | `spawn_agent` | 容器回归验证 | 派发独立验证子 agent 做 pytest + 容器短回归 | 进行中 | 待生成 `.tmp_runtime/*verify*.json` |

### 12.7 当前轮实现侧结果

- `session/authz` 热路径：
  - 过期会话清理改为节流执行；
  - `sessions/login-logs` 改走节流清理 helper；
  - `sessions/online` 预加载 `roles/stage`，压掉 `N+1`；
  - `authz` 新增只读本地缓存并统一走 `_ensure_authz_defaults_once()`；
  - `authz_snapshot` 新增短 TTL 本地缓存；
  - 会话活跃缓存 TTL 已受剩余会话寿命约束。
- `messages` 热路径：
  - 消息读接口默认不再触发 `run_message_maintenance()`。

### 12.8 当前轮实现侧测试证据

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | `test_session_service_unit.py test_authz_service_unit.py test_auth_endpoint_unit.py test_api_deps_unit.py` | `python -m pytest ...` | `23 passed` | 会话/鉴权热路径单测通过 |
| `pytest` | `test_message_service_unit.py` | `python -m pytest backend/tests/test_message_service_unit.py` | `14 passed` | 消息热路径单测通过 |
| `pytest` | `test_session_service_unit.py` | `python -m pytest backend/tests/test_session_service_unit.py` | `13 passed` | 会话缓存 TTL 上限定向验证通过 |

### 12.9 当前门禁状态更新

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G3 | 通过（执行侧） | 44~46 | 执行子 agent 已形成闭环；独立验证子 agent `Lorentz` 已派发 |
| G4 | 进行中 | 47 | 正等待正式容器回归结果 |
| G5 | 进行中 | 39~47 | 已补齐“调研 -> 执行 -> 测试 -> 验证派发”，待最终回归收口 |

### 12.10 当前轮独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | `session/authz/auth/message` 定向单测 | `python -m pytest backend/tests/test_session_service_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_auth_endpoint_unit.py backend/tests/test_api_deps_unit.py backend/tests/test_message_service_unit.py` | `37 passed in 3.50s` | 定向单测通过 |
| `docker compose` | `backend-web backend-worker` | `docker compose up -d --build backend-web backend-worker` | 完成 | 已切到当前工作树镜像 |
| `backend-capacity-gate` | 代表样本 `8` 条 | `40` 并发、`20` 会话池、`6s` 测量、`2s` warmup | `7/8` 单链路通过 | 仅 `me-session` 未达标 |

### 12.11 当前轮代表样本门禁结果

- 结果文件：`.tmp_runtime/remaining_read_40_fix_verify_repr.json`
- 单链路结论：
  - `me-session`：`P95 535.19ms`，不通过
  - `sessions-online`：通过
  - `authz-snapshot`：通过
  - `ui-page-catalog`：通过
  - `auth-accounts`：通过
  - `messages-unread-count`：通过
  - `messages-summary`：通过
  - `messages-list`：通过
- 日志结论：
  - `backend-web` 最近 `200` 行仅见 `HTTP 200`；
  - `postgres` 尾部未见当前压测时段的新错误；
  - 当前剩余问题已收缩为 `me-session` 纯延迟超线，而非错误率或连接池异常。

### 12.12 当前门禁状态再更新

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G4 | 通过（阶段性） | 47 | 已完成正式容器真实回归；当前代表样本仅剩 `me-session` 单链路未过逐项门禁 |
| G5 | 进行中 | 39~47 | 已形成“调研 -> 执行 -> 测试 -> 容器回归 -> 再定位”闭环，待下一轮 `me-session` 精修后收口 |

### 12.13 `me-session` 二轮验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 48 | 执行 | `spawn_agent` | 默认 | 派发 `me-session` 单链路执行子 agent | 定向代码修复与单测 | 2026-04-09 10:52 +08:00 |
| 49 | 验证 | `pytest` | 默认 | 校验 `me-session` 新增定向单测 | 本地接口级单测结果 | 2026-04-09 10:54 +08:00 |
| 50 | 验证 | `send_input` | 默认 | 复用独立验证子 agent 进行第二轮 `me-session -> 代表样本 -> 批次 -> 全量` 阶梯验证 | 第二轮真实回归结果 | 2026-04-09 10:55 +08:00 |

### 12.14 `me-session` 二轮执行侧结果

- `me.py`：
  - `get_my_session()` 已从通用 `get_current_active_user` 依赖链剥离；
  - 当前路径改为单次 token 解析 + 最小用户状态查询 + 当前 session 校验。
- 新增测试：
  - `backend/tests/test_me_endpoint_unit.py`
  - 本地结果：`python -m pytest backend/tests/test_me_endpoint_unit.py` -> `6 passed`
- 当前验证策略：
  - 先单独验证 `me-session`；
  - 再按“代表样本 8 条 -> 14 条批次 -> 全量 63 条”逐级扩展；
  - 任一步骤出现单链路不通过即停止扩批并抓日志。

### 12.15 `sessions-online` 三轮验证后的收敛判断

- 第三轮独立验证结果：
  - `sessions-online` 第 `1` 轮通过：`P95 452.79ms`
  - 第 `2` 轮失败：`P95 728.02ms`
  - 第 `3` 轮按规则未执行
- 结论：
  - 当前 `sessions-online` 问题属于纯延迟抖动，不是错误率问题；
  - `backend-web` / `postgres` 日志均未见当前窗口异常堆栈；
  - 因此主线转入该链路的查询侧精修，而不先扩大到全量复测。

### 12.16 `sessions-online` 四轮执行/验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 51 | 执行 | `spawn_agent` | 默认 | 派发 `sessions-online` 单链路执行子 agent | 查询侧优化与定向单测 | 2026-04-09 11:08 +08:00 |
| 52 | 验证 | `pytest` | 默认 | 校验 `sessions-online` 相关定向单测 | `test_session_service_unit.py` 结果 | 2026-04-09 11:10 +08:00 |
| 53 | 验证 | `send_input` | 默认 | 复用独立验证子 agent 做第四轮 `sessions-online` 三轮稳定性采样与条件式全量复测 | 第四轮真实回归结果 | 2026-04-09 11:11 +08:00 |

### 12.17 `sessions-online` 四轮执行侧结果

- `session_service.list_online_sessions()`：
  - `count` 查询改为窄 `count(UserSession.id)`；
  - 分页 rows 查询改为按需 `load_only(...)`；
- 继续保留 `roles/stage` 受控预加载。
- 本地测试：
  - `python -m pytest backend/tests/test_session_service_unit.py`
  - 结果：`13 passed`

### 12.18 `sessions-online` 四轮独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | `session_service` 定向单测 | `python -m pytest backend/tests/test_session_service_unit.py` | `13 passed` | 定向单测通过 |
| `docker compose` | `backend-web` | `docker compose up -d --build backend-web` | 完成 | 已加载第四轮工作树镜像 |
| `backend-capacity-gate` | `sessions-online` | `40` 并发、`20` 会话池、`6s` 测量、`2s` warmup | `P95 507.62ms`、`error_rate 0.0` | 单链路门禁失败 |
| `docker logs` | `backend-web/postgres` | 尾日志检查 | 未见当前窗口应用异常与数据库新错误 | 问题仍为纯延迟抖动 |

- 结果文件：
  - `.tmp_runtime/sessions_online_40_verify_round4_run1.json`
- 当前门禁判断：
  - 第四轮未达到 `P95 <= 500ms`
  - 未进入 run2/run3 与更宽覆盖验证
  - 需要继续做查询侧减负后再验证。

### 12.19 `sessions-online` 五轮执行与验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 54 | 执行 | `send_input` | 默认 | 复用执行子 agent，限定 `session_service/sessions/test_session_service` 三文件继续收敛 | 投影查询版实现与定向单测 | 2026-04-09 11:17 +08:00 |
| 55 | 验证 | `send_input` | 默认 | 复用独立验证子 agent，先做 `sessions-online` `3` 轮 `40` 并发短压，再检查其他所有链路 | 第五轮真实回归结果与覆盖结论 | 2026-04-09 11:17 +08:00 |

- 第五轮执行侧已知结果：
  - `list_online_sessions()` 已改为按需投影查询，直接返回 `OnlineSessionProjection`
  - 直接 `outer join sys_user_role -> sys_role -> mes_process_stage` 获取 `role/stage`
  - `/api/v1/sessions/online` endpoint 直接消费投影结果
  - `python -m pytest backend/tests/test_session_service_unit.py` -> `15 passed`
- 第五轮验证策略：
  - 单链路 `3` 轮全部通过后，才进入“其他所有链路是否满足 `40` 并发需求”的检查
  - 优先使用 `tools/perf/scenarios/other_authenticated_read_scenarios.json` 覆盖其他链路
  - 若执行条件变化，再明确退回场景与实际覆盖范围。

### 12.20 `sessions-online` 五轮独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | `session_service` 定向单测 | `python -m pytest backend/tests/test_session_service_unit.py` | `15 passed` | 单测通过 |
| `docker compose` | `backend-web` | `docker compose up -d --build backend-web` | 完成 | 已切到投影查询版镜像 |
| `backend-capacity-gate` | `sessions-online` run1 | `40` 并发短压 | `P95 496.46ms`、`error_rate 0.001488` | 通过 |
| `backend-capacity-gate` | `sessions-online` run2 | `40` 并发短压 | `P95 447.53ms`、`error_rate 0.0` | 通过 |
| `backend-capacity-gate` | `sessions-online` run3 | `40` 并发短压 | `P95 428.81ms`、`error_rate 0.0` | 通过 |
| `backend-capacity-gate` | `remaining_read_40_scan` 全量 `63` 条 | `40` 并发短压 | `gate_passed=false`，`23` 条通过、`40` 条未通过 | 仅可作为筛查，不足以形成全链路通过结论 |

- 结果文件：
  - `.tmp_runtime/sessions_online_40_verify_round5_run1.json`
  - `.tmp_runtime/sessions_online_40_verify_round5_run2.json`
  - `.tmp_runtime/sessions_online_40_verify_round5_run3.json`
  - `.tmp_runtime/remaining_read_40_full_round5.json`
- 当前验证判断：
  - `sessions-online` 已通过并具备稳定性证据
  - 全量 `63` 条短跑存在 `21` 条 `total_requests=0`，说明当前口径会让后半段场景缺少有效采样
  - 因此“其他所有链路满足 `40` 并发”仍未形成通过证据，需拆分为更公平的分组验证。

### 12.21 当前门禁状态再更新

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G4 | 通过（阶段性） | 48~51 | `sessions-online` 已完成三轮真实容器验证并通过；其余链路已完成一轮全量筛查 |
| G5 | 进行中 | 39~51 | 证据链已覆盖“执行 -> 单链路验证 -> 全量筛查 -> 再拆分”闭环，待其余链路公平验证后收口 |

### 12.22 其余链路第六轮公平分组验证

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `docker inspect` | `backend-web` | `running healthy` 检查 | 通过 | 沿用现有健康容器，无需重建 |
| `backend-capacity-gate` | `group1` | `40` 并发公平分组短压 | `gate=false` | `auth/authz` 入口组整体超线 |
| `backend-capacity-gate` | `group2` | `40` 并发公平分组短压 | `gate=false` | `authz/me/messages` 入口组整体超线 |
| `backend-capacity-gate` | `group3` | `40` 并发公平分组短压 | `gate=false` | 设备账册与所有者相关链路部分超线 |
| `backend-capacity-gate` | `group4` | `40` 并发公平分组短压 | `gate=true` | 全部通过 |
| `backend-capacity-gate` | `group5` | `40` 并发公平分组短压 | `gate=true` | 组级通过，但 `roles-list` 逐链路超线 |
| `backend-capacity-gate` | `group6` | `40` 并发公平分组短压 | `gate=true` | 全部通过 |
| `backend-capacity-gate` | `group7` | `40` 并发公平分组短压 | `gate=true` | 组级通过，但 `production-data-unfinished-progress` 逐链路超线 |
| `backend-capacity-gate` | `group8` | `40` 并发公平分组短压 | `gate=false` | 生产相关链路仍有 4 条超线 |

- 结果文件：
  - `.tmp_runtime/remaining_read_40_group1_round6.json`
  - `.tmp_runtime/remaining_read_40_group2_round6.json`
  - `.tmp_runtime/remaining_read_40_group3_round6.json`
  - `.tmp_runtime/remaining_read_40_group4_round6.json`
  - `.tmp_runtime/remaining_read_40_group5_round6.json`
  - `.tmp_runtime/remaining_read_40_group6_round6.json`
  - `.tmp_runtime/remaining_read_40_group7_round6.json`
  - `.tmp_runtime/remaining_read_40_group8_round6.json`
- 当前验证判断：
  - 分组后所有链路都拿到了真实样本，`total_requests=0` 已不再存在
  - 当前最低要求 `40` 并发仍未通过，真实失败链路数为 `25`
  - 下一轮验证应聚焦第六轮失败组与失败链路，而不必再回到不公平的 `63` 条混跑口径。

### 12.23 当前门禁状态再更新

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G4 | 通过（阶段性） | 52~60 | 已完成公平分组真实容器验证；当前失败链路与通过链路边界已清晰 |
| G5 | 进行中 | 39~60 | 证据链已覆盖“筛查 -> 公平分组 -> 失败链路确认 -> 再修复”闭环，待第七轮修复与复测收口 |

### 12.24 第七轮执行侧修复与复测派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 61 | 执行 | `spawn_agent` | 默认 | 派发公共鉴权入口减负执行子 agent | `get_current_user` 读链减负与相关单测 | 2026-04-09 11:43 +08:00 |
| 62 | 执行 | `spawn_agent` | 默认 | 派发 `authz/message` 读热点执行子 agent | read cache / SQL 聚合优化与相关单测 | 2026-04-09 11:43 +08:00 |
| 63 | 验证 | `pytest` | 默认 | 先做第七轮定向单测 | 第七轮实现侧单测结果 | 2026-04-09 11:50 +08:00 |
| 64 | 验证 | `send_input` | 默认 | 复用独立验证子 agent 对 round6 失败组做同门禁复测 | 第七轮真实容器回归结果 | 2026-04-09 11:51 +08:00 |

- 第七轮执行侧已知结果：
  - 公共鉴权入口减负相关单测：`11 passed in 1.66s`
  - `authz/message` 热点减负相关单测：`25 passed in 1.68s`
- 当前验证策略：
  - 先重跑 round6 失败的 `group1/group2/group3/group5/group7/group8`
  - 若以上组内所有逐链路都通过，再补跑 `group4/group6`
  - 最终按“所有链路 `40` 并发”口径判定是否收口。

### 12.25 第七轮独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | 第七轮定向单测 | `python -m pytest backend/tests/test_api_deps_unit.py backend/tests/test_auth_endpoint_unit.py backend/tests/test_me_endpoint_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_message_service_unit.py` | `36 passed` | 单测通过 |
| `docker compose` | `backend-web` | `docker compose up -d --build backend-web` | 完成 | 已切到第七轮镜像 |
| `backend-capacity-gate` | `group1/group2/group3/group5/group7/group8` | `40` 并发公平分组复测 | `group3` 通过，其余 5 组失败 | 当前仍不满足全链路 `40` 并发门禁 |

- round7 结果文件：
  - `.tmp_runtime/remaining_read_40_group1_round7.json`
  - `.tmp_runtime/remaining_read_40_group2_round7.json`
  - `.tmp_runtime/remaining_read_40_group3_round7.json`
  - `.tmp_runtime/remaining_read_40_group5_round7.json`
  - `.tmp_runtime/remaining_read_40_group7_round7.json`
  - `.tmp_runtime/remaining_read_40_group8_round7.json`
- round7 关键判断：
  - `group3` 已显著改善并通过，说明共享热路径优化并非全无收益；
  - 但 round6 原本较好的 `group5/group7` 在 round7 明显回退，表明第七轮公共鉴权入口改法引入了新的全局负担；
  - 第八轮应优先纠偏该回退，再继续压 `authz` 主簇。

### 12.26 第八轮执行与验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 65 | 执行 | `send_input` | 默认 | 将公共鉴权入口回退到更保守的窄读取方案 | 消除 round7 全局回退 | 2026-04-09 11:58 +08:00 |
| 66 | 执行 | `send_input` | 默认 | 为 `authz` 顶层只读函数补齐结果缓存 | 压低 `group1/group2` 主热点 | 2026-04-09 11:58 +08:00 |

- 第八轮计划验证口径：
  - 先重跑 `group1/group2/group5`
  - 再视结果扩到 `group7/group8`
  - 核心失败簇不过线时，不提前补跑已通过组。

### 12.27 第八轮执行侧结果与验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 67 | 验证 | `pytest` | 默认 | 统一补跑 round8 定向单测，覆盖两条执行改动 | round8 单测结果 | 2026-04-09 12:04 +08:00 |
| 68 | 验证 | `send_input` | 默认 | 复用独立验证子 agent 先重跑 `group1/group2/group5` | round8 核心失败簇回归结果 | 2026-04-09 12:04 +08:00 |

- 第八轮执行侧已知结果：
  - 公共鉴权入口纠偏相关单测：`11 passed in 2.38s`
  - `authz` 顶层缓存代码已落盘，但执行子 agent 尚未本地补跑 round8 的 `test_authz_service_unit.py`，本轮统一交由独立验证完成
- 第八轮当前验证策略：
  - 先用 round8 定向 pytest 兜底代码正确性
  - 再验证 `group1/group2/group5`
  - 若核心失败簇全部逐链路通过，再扩到 `group7/group8`。

### 12.28 第八轮独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `pytest` | round8 定向单测 | `python -m pytest backend/tests/test_api_deps_unit.py backend/tests/test_auth_endpoint_unit.py backend/tests/test_me_endpoint_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_message_service_unit.py` | `42 passed` | 通过 |
| `docker compose` | `backend-web` | `docker compose up -d --build backend-web` | 完成 | 已切到第八轮镜像 |
| `backend-capacity-gate` | `group1/group2/group5` | `40` 并发公平分组回归 | 3 组均未逐链路通过 | 当前仍不满足最低要求 |

- round8 结果文件：
  - `.tmp_runtime/remaining_read_40_group1_round8.json`
  - `.tmp_runtime/remaining_read_40_group2_round8.json`
  - `.tmp_runtime/remaining_read_40_group5_round8.json`
- round8 关键判断：
  - `group2` 已从整组大面积失败收缩到 `authz-hierarchy-role-config-user` 单条失败
  - `group1` 仍有 `7` 条残余失败，但整体 P95 已明显下降
  - `group5` 仍整组失败，但因其中含 `sessions-online` 这类已知单链可过端点，下一步必须用单链验证剥离混合干扰。

### 12.29 第九轮单链验证派发

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 69 | 验证 | `send_input` | 默认 | 对 round8 残余失败链路逐条做单链 `40` 并发验证 | 区分真实单链不足与混合干扰 | 2026-04-09 12:10 +08:00 |

- 第九轮当前验证策略：
  - 不再先混跑
  - 逐条验证 round8 残余失败端点
  - 只把单链也失败的端点送回下一轮实现侧修复。

### 12.30 第九轮单链验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `backend-capacity-gate` | `16` 条残余失败端点 | 逐条单链 `40` 并发验证 | `2` 条通过，`14` 条失败 | 已完成混合干扰与真实单链不足拆分 |

- 第九轮已通过单链：
  - `auth-me`
  - `authz-hierarchy-role-config-user`
- 第九轮单链仍失败：
  - `auth-register-requests`
  - `authz-permissions-catalog-user`
  - `authz-snapshot`
  - `authz-role-permissions-user`
  - `authz-role-permissions-matrix-user`
  - `authz-hierarchy-catalog-user`
  - `roles-list`
  - `audits-list`
  - `sessions-login-logs`
  - `sessions-online`
  - `ui-page-catalog`
  - `quality-stats-overview`
  - `quality-stats-processes`
  - `quality-stats-operators`
- 当前门禁判断：
  - “所有链路 `40` 并发”的最低要求仍未满足
  - 但当前剩余真失败集合已经明确，后续无需再重复验证已通过的混合干扰项。
