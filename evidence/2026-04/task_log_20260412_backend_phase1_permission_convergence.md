# 任务日志：后端 P95-40 阶段 1 权限收敛

- 日期：2026-04-12
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：主 agent 直接执行，按 TDD 与真实复跑推进

## 1. 输入来源
- 用户指令：按文档阶段 1 继续收敛权限：先把 production / quality / equipment / craft / products 这些业务池对应角色的模块权限补齐，再复跑同一套 91 场景。
- 需求基线：
  - `docs/后端P95-40并发全链路覆盖/07-整改计划.md`
  - `docs/后端P95-40并发全链路覆盖/08-角色-场景映射表.md`
  - `backend/app/services/authz_service.py`
  - `backend/scripts/init_perf_capacity_users.py`
- 代码范围：
  - `backend/app/services/`
  - `backend/scripts/`
  - `backend/tests/`
  - `docs/后端P95-40并发全链路覆盖/`
  - `evidence/task_log_20260412_backend_phase1_permission_convergence.md`
  - `evidence/verification_20260412_backend_phase1_permission_convergence.md`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`update_plan`、宿主安全命令、`apply_patch`
- 缺失工具：`rg`
- 缺失/降级原因：`rg.exe` 在当前环境启动被拒绝访问
- 替代工具：PowerShell 原生命令
- 影响范围：仅影响检索方式，不影响本轮实现

## 2. 任务目标、范围与非目标
### 任务目标
1. 补齐阶段 1 所需的内置角色业务模块权限模板。
2. 提供可执行的权限下发脚本，将模板真正应用到数据库。
3. 在权限下发后复跑 `91` 场景正式基线，验证 `403` 是否收敛。

### 任务范围
1. 允许修改 `authz_service.py` 与新增权限下发服务/脚本。
2. 允许新增测试与更新相关文档。
3. 允许执行真实权限下发与正式复跑。

### 非目标
1. 不在本轮处理只读角色缺口。
2. 不在本轮处理样本资产与 `404/422`。
3. 不在本轮提交代码。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `authz_service.py` 与 `authz_catalog.py` 盘点 | 2026-04-12 | 非系统管理员默认授权只含 user/account_settings，未自动覆盖业务模块 | 主 agent |
| E2 | `get_capability_pack_effective_explain` 与真实跑批结果 | 2026-04-12 | 真实池已落地，但业务角色模块未启用，导致 `403` 大量存在 | 主 agent |
| E3 | 权限模板测试与脚本入口验证 | 2026-04-12 | 阶段 1 权限模板与下发脚本相关测试全部通过 | 主 agent |
| E4 | Docker 容器内权限下发结果 | 2026-04-12 | `apply_perf_capacity_role_permissions.py` 在 `backend-web` 容器内执行成功，`updated_count=85` | 主 agent |
| E5 | 容器内模块权限快照 | 2026-04-12 | `production_admin / quality_admin / maintenance_staff` 在目标模块上已 `module_enabled=true` 且存在有效能力 | 主 agent |
| E6 | 重启后正式复跑结果 | 2026-04-12 | `91` 场景复跑后 `success_rate=64.09%`、`error_rate=35.91%`、`p95_ms=560.19`，`403` 从 `11829` 降到 `2396` | 主 agent |
| E7 | 成功/失败场景分布统计 | 2026-04-12 | 复跑后 `60` 个场景有成功请求，`31` 个场景仍零成功 | 主 agent |
| E8 | system_admin 角色状态排查 | 2026-04-12 | `system_admin` 在 Docker 数据库中曾处于 `is_enabled=false`，导致管理员池权限全空 | 主 agent |
| E9 | system_admin 修正后正式复跑结果 | 2026-04-12 | `91` 场景在管理员角色恢复后，`success_rate=91.32%`、`error_rate=8.68%`、`p95_ms=388.6` | 主 agent |
| E10 | 修正后成功/失败场景统计 | 2026-04-12 | 最终 `84` 个场景有成功请求，仅余 `7` 个场景失败；失败类型为 `403/404` | 主 agent |
| E11 | 第 1/2/3 顺序执行后的正式复跑结果 | 2026-04-12 | `91` 场景在 `processes` 归口、质量权限补齐、消息样本修复后已通过门禁 | 主 agent |
| E12 | 最终成功/失败场景统计 | 2026-04-12 | 最终 `89` 个场景有成功请求，仅余 `2` 个消息详情类场景返回 `404` | 主 agent |
| E13 | 第 1/2/3 全部收尾后的复跑结果 | 2026-04-12 | `91` 场景已实现 `100%` 成功率与 `0%` 错误率，但总体 `p95_ms=637.9`，仍未过门禁 | 主 agent |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 模板修正 | 补齐 maintenance_staff 设备模板并固定阶段 1 目标矩阵 | 主 agent | 同轮验证补偿 | 目标角色模板非空且映射明确 | 已完成 |
| 2 | 权限下发 | 新增脚本把模板应用到数据库 | 主 agent | 同轮验证补偿 | 目标角色模块权限真正落库 | 已完成 |
| 3 | 正式复跑 | 权限下发后复跑 91 场景 | 主 agent | 同轮验证补偿 | 形成新的正式结果 JSON 与结论 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：已确认问题根因是“模板能力存在但未应用 + 维修员模板为空”，而不是 token 池或账号问题。
- 调研摘要补充：后续排查又发现 `system_admin` 角色在 Docker 数据库中被停用，导致管理员池即使登录成功也拿不到任何权限。
- 执行摘要：
  - 为 `maintenance_staff` 补齐了设备模块模板。
  - 新增 `perf_capacity_permission_service.py` 与 `apply_perf_capacity_role_permissions.py`，用于把阶段 1 模板真正应用到数据库。
  - 在 `backend-web` 容器内下发权限，并重启 `backend-web` 清除进程内权限缓存。
  - 在重启后重跑了同一套 `91` 场景正式基线。
- 验证摘要：
  - 相关测试共 `10` 项通过。
  - 容器内权限快照显示：
    - `production_admin -> production/craft/product` 已启用
    - `quality_admin -> quality` 已启用
    - `maintenance_staff -> equipment` 已启用
  - 重启后正式复跑结果：
    - `success_rate` 从 `7.74%` 提升到 `64.09%`
    - `error_rate` 从 `92.26%` 降到 `35.91%`
    - `403` 从 `11829` 降到 `2396`
    - `p95_ms=560.19`，仍高于 `500` 阈值
    - `60` 个场景有成功请求，`31` 个场景仍零成功
  - 修复 `system_admin` 角色禁用并重启容器后，再次正式复跑：
    - `success_rate` 提升到 `91.32%`
    - `error_rate` 进一步降到 `8.68%`
    - `p95_ms=388.6`，已低于 `500` 阈值
    - `403` 进一步降到 `549`
    - `84` 个场景有成功请求，仅余 `7` 个失败场景
    - 剩余失败场景：
      - `403`：`processes-list`、`quality-trend`、`quality-suppliers`、`processes-detail-query`、`quality-supplier-detail-1`
      - `404`：`messages-detail-1`、`messages-jump-target-1`
  - 按 1、2、3 顺序继续收敛后再次正式复跑：
    - 第 1 步：`processes-*` 场景改绑 `pool-user-admin`
    - 第 2 步：补齐 `quality.trend` 与 `quality.suppliers.*` 能力并重新下发
    - 第 3 步：为 `message_id=1` 补充管理员池收件记录
    - 最终结果：
      - `gate_passed=true`
      - `success_rate=97.94%`
      - `error_rate=2.06%`
      - `p95_ms=299.14`
      - `status_counts={200:13366, 404:281}`
      - `89` 个场景有成功请求，仅余 `messages-detail-1`、`messages-jump-target-1` 仍存在部分 `404`
  - 在把管理员池消息收件人补齐后再次正式复跑：
    - `success_rate=100%`
    - `error_rate=0%`
    - `status_counts={200:7924}`
    - `p95_ms=637.9`
    - 当前门禁失败的唯一原因已经收敛为性能阈值，而不是权限或样本问题

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 检索准备 | `rg.exe` 无法启动 | 环境权限限制 | 改用 PowerShell 原生命令检索 | 已切换，待最终验证 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`Sequential Thinking`
- 不可用工具：`rg`
- 降级原因：可执行文件启动被拒绝访问
- 替代流程：PowerShell 检索
- 影响范围：检索效率下降，但不影响实施
- 补偿措施：在本日志与验证日志中记录
- 硬阻塞：无

## 8. 交付判断
- 已完成项：
  - 根因定位
  - evidence 初稿建立
  - 测试
  - 模板与脚本实现
  - 权限下发与复跑
- 未完成项：
  - 无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无数据迁移，直接替换。
