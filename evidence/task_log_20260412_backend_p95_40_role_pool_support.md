# 任务日志：后端 P95-40 并发角色域 token 池支持

- 日期：2026-04-12
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：主 agent 直接执行，按 TDD 与同轮验证补偿推进

## 1. 输入来源
- 用户指令：使用 superpowers，根据 `docs/后端P95-40并发全链路覆盖/` 中的文档继续完成后端 P95-40 并发全链路覆盖任务。
- 需求基线：
  - `docs/后端P95-40并发全链路覆盖/07-整改计划.md`
  - `docs/后端P95-40并发全链路覆盖/08-角色-场景映射表.md`
  - `tools/project_toolkit.py`
  - `tools/perf/backend_capacity_gate.py`
- 代码范围：
  - `tools/project_toolkit.py`
  - `tools/perf/backend_capacity_gate.py`
  - `backend/tests/`
  - `docs/后端P95-40并发全链路覆盖/`
  - `evidence/task_log_20260412_backend_p95_40_role_pool_support.md`
  - `evidence/verification_20260412_backend_p95_40_role_pool_support.md`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`update_plan`、宿主安全命令、`apply_patch`
- 缺失工具：`rg`
- 缺失/降级原因：`rg.exe` 在当前环境启动被拒绝访问
- 替代工具：PowerShell 原生命令
- 影响范围：仅影响检索方式，不影响本轮实现结论

## 2. 任务目标、范围与非目标
### 任务目标
1. 基于整改计划阶段 1-2，为容量门禁工具补充按场景选择 token 池的能力。
2. 让场景配置文件可声明多 token 池与场景级 token 池绑定。
3. 用单元测试固定配置解析与 token 池选择行为。

### 任务范围
1. 允许修改 `tools/project_toolkit.py` 与 `tools/perf/backend_capacity_gate.py`。
2. 允许新增或修改相关单元测试。
3. 允许更新 `docs/后端P95-40并发全链路覆盖/` 中与执行口径相关的文档。

### 非目标
1. 不在本轮直接重写 `270` 场景或 `91` 场景全量配置。
2. 不直接完成权限矩阵、样本资产与 `405/422` 全量收敛。
3. 不在本轮给出新的性能通过结论。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `07-整改计划.md`、`08-角色-场景映射表.md` 盘点 | 2026-04-12 | 阶段 1-2 的核心缺口是“场景 -> 角色域 -> token 池”未在工具层落地 | 主 agent |
| E2 | `backend_capacity_gate.py` 与场景 JSON 现状盘点 | 2026-04-12 | 当前只有单一 token 池与单一 `login_user_prefix`，场景也未声明 token 池 | 主 agent |
| E3 | `pytest backend/tests/test_backend_capacity_gate_unit.py -q` | 2026-04-12 | 新增的 3 个单元测试全部通过 | 主 agent |
| E4 | `python tools/project_toolkit.py backend-capacity-gate --help` | 2026-04-12 | CLI 帮助成功输出，参数说明已包含 `token_pools`、`role_domain`、`token_pool` | 主 agent |
| E5 | 最终 `git status --short` | 2026-04-12 | 本轮工作集集中在工具代码、文档、测试与 evidence；另有非本轮新增的 `rg_availability_check` evidence 未处理 | 主 agent |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 配置建模 | 定义 token 池配置与场景绑定字段 | 主 agent | 同轮验证补偿 | 配置文件可表达多 token 池与场景级绑定 | 已完成 |
| 2 | 工具实现 | 让容量门禁按场景选择对应 token 池 | 主 agent | 同轮验证补偿 | 运行时可根据场景使用目标 token 池 | 已完成 |
| 3 | TDD 与文档 | 补单元测试和执行文档 | 主 agent | 同轮验证补偿 | 测试通过，文档口径同步 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：已完成整改计划、支撑文档、工具代码与场景配置现状盘点。
- 执行摘要：
  - 为 `ScenarioSpec` 新增 `role_domain` 与 `token_pool` 字段。
  - 新增 `TokenPoolSpec`、`ScenarioConfigBundle` 及多 token 池配置解析。
  - 为容量门禁运行时补充“场景 -> 指定 token 池”选择逻辑，并保留默认池兼容路径。
  - 更新 `project_toolkit.py` 帮助文案。
  - 更新 `04-执行说明与命令模板.md` 与 `08-角色-场景映射表.md`，同步工具层新能力。
  - 新增 `backend/tests/test_backend_capacity_gate_unit.py`，覆盖配置解析、未知 token 池校验、场景选池逻辑。
- 验证摘要：
  - `python -m pytest backend/tests/test_backend_capacity_gate_unit.py -q` 通过，`3 passed in 0.09s`。
  - `python tools/project_toolkit.py backend-capacity-gate --help` 通过，CLI 帮助已包含新增配置字段说明。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 检索准备 | `rg.exe` 无法启动 | 环境权限限制 | 改用 PowerShell 原生命令检索 | 已切换，待最终验证 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`Sequential Thinking`
- 不可用工具：`rg`
- 降级原因：可执行文件启动被拒绝访问
- 替代流程：PowerShell 定向检索 + `apply_patch` 编辑
- 影响范围：检索效率下降，但不影响实施
- 补偿措施：在本日志与验证日志中记录
- 硬阻塞：无

## 8. 交付判断
- 已完成项：
  - 文档与工具现状盘点
  - 分支切换
  - 本轮 evidence 初稿建立
  - 测试编写
  - 工具实现
  - 文档同步
  - 最终验证与日志回填
- 未完成项：
  - 无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无数据迁移，直接替换。
