# 任务日志：后端全链路 40 并发 P95<500ms 收敛

- 日期：2026-04-19
- 执行人：Codex 主 agent
- 当前状态：进行中

## 1. 用户原始目标

- 用户目标：后端全链路在 40 并发下达到 `P95 < 500ms`。

## 2. 前置说明

- 默认主线工具：`Sequential Thinking`、`update_plan`、PowerShell、`pytest`、压测脚本。
- 缺失工具：无。
- 缺失/降级原因：无。
- 替代工具：无。
- 影响范围：无。

## 3. 启动留痕

- 启动时间：2026-04-19 08:18:00 +08:00
- 当前动作：根因定位（性能热点与计时口径核对）并准备最小可验证改动。
## 4. 本轮任务拆解（Sequential Thinking 摘要）

1. 先复现 `combined_40` 当前口径，确认真实慢场景而非主观判断。
2. 对阻塞执行链路的问题先做最小修复（账号池初始化失败、登录账号池越界）。
3. 复测全链路并比较参数调优前后数据，判定是否达到 `P95 < 500ms`。

## 5. 根因定位与执行记录

### 5.1 环境与链路问题（已收敛）

- 问题 A：本地脚本默认连 `127.0.0.1:5432`，在 Docker 默认不暴露数据库时失败。
  - 处理：使用 `python start_backend.py up --expose-db --db-port 5433 --no-build` 临时暴露数据库，并用 `DB_PORT=5433` 执行初始化脚本。
- 问题 B：`init_perf_capacity_users.py` 在无启用工序阶段时抛错：`operator 压测池至少需要一个已启用的工序阶段`。
  - 处理：按 TDD 修复 `perf_user_seed_service`，为 operator 池增加与 equipment 池一致的兜底阶段/工序创建逻辑。
- 问题 C：压测器登录用户名生成会超出账号池规模，产生伪 `401`。
  - 处理：按 TDD 修复 `backend_capacity_gate` 登录用户名生成策略，仅按 token pool 账号规模生成。

### 5.2 TDD 证据

1. 红灯：
   - `python -m pytest backend/tests/test_perf_user_seed_service_unit.py -k operator_pool_creates_fallback_stage_when_missing -q`
   - 结果：`1 failed`（命中 `operator` 阶段缺失异常）
2. 绿灯：
   - `python -m pytest backend/tests/test_perf_user_seed_service_unit.py -q`
   - 结果：`5 passed`
3. 红灯：
   - `python -m pytest backend/tests/test_backend_capacity_gate_unit.py -k build_login_usernames_for_pool_uses_token_count -q`
   - 结果：`1 failed`（函数缺失）
4. 绿灯：
   - `python -m pytest backend/tests/test_backend_capacity_gate_unit.py -k "build_login_usernames_for_pool_uses_token_count or filter_token_pools_skips_unused_default_pool" -q`
   - 结果：`2 passed`

## 6. 全链路压测复测结果

### 6.1 默认容量参数（当前主线）

- 文件：`.tmp_runtime/backend_40_e2e_combined_20260419_baseline.json`
- 结果：
  - `overall.total_requests = 336`
  - `overall.success_rate = 95.24%`
  - `overall.error_rate = 4.76%`
  - `overall.p95_ms = 2180.09`
  - `overall.p99_ms = 2758.00`
- 结论：未达成 `P95 < 500ms`。

### 6.2 提高 worker 与连接池后的对照实验

- 实验参数：`WEB_CONCURRENCY=16`，`DB_POOL_SIZE=16`，`DB_MAX_OVERFLOW=16`
- 文件：`.tmp_runtime/backend_40_e2e_combined_20260419_tuned16.json`
- 结果：
  - `overall.total_requests = 188`
  - `overall.success_rate = 87.77%`
  - `overall.error_rate = 12.23%`
  - `overall.p95_ms = 5790.46`
  - `overall.p99_ms = 7089.08`
- 结论：纯容量参数上调显著恶化延迟与错误率，不可作为收敛方向。

## 7. 本轮交付结论

- 已完成：
  1. 全链路目标复现与量化
  2. 两项阻塞链路修复（账号池初始化/登录池越界）
  3. 默认参数与调优参数对照验证
- 未完成：
  - 后端全链路 `40` 并发 `P95 < 500ms`
- 当前判断：
  - 当前瓶颈不是单纯并发参数配置问题，主要是多类业务接口在真实执行路径下的高成本处理叠加，需进入接口级热点治理。

## 8. 迁移说明

- 无迁移，直接替换

## 9. 结束留痕

- 结束时间：2026-04-19 10:24:00 +08:00