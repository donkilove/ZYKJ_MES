# 任务日志：Task 1 - code quality review（只读）

- 日期：2026-04-13
- 执行人：Codex（主 agent）
- 当前状态：进行中
- 指挥模式：未触发（本任务为单一原子任务：只读审阅，不含实现与独立验证闭环）

## 1. 输入来源
- 用户指令：对 Task 1 做 code quality review，不修改代码；关注 3 个文件；重点检查可扩展性、命名/边界/可读性、测试是否薄测。
- 需求基线：`AGENTS.md` + `docs/AGENTS/00/10/20/30/40/50`
- 代码范围：
  - `tools/perf/write_gate/sample_contract.py`
  - `tools/perf/backend_capacity_gate.py`
  - `backend/tests/test_backend_capacity_gate_unit.py`

## 1.1 前置说明
- 默认主线工具：Filesystem（读写 evidence）、宿主 PowerShell（必要时只读检索）
- 缺失工具：无
- 缺失/降级原因：无
- 替代工具：无
- 影响范围：无

## 2. 任务目标、范围与非目标
### 任务目标
1. 找出会立刻拖累后续 Task 2/3 的设计质量问题（结构、边界、命名、测试覆盖）。
2. 给出 PASS/FAIL 结论；若 FAIL，仅列 1-3 个最严重问题并给出代码定位。

### 任务范围
1. 仅审阅指定 3 个文件。
2. 仅输出审阅结论，不修改任何代码。

### 非目标
1. 不评估 spec 是否“最低限度通过”。
2. 不引入重构方案或改动建议的实现细节（除非为解释问题必需）。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 本文件（启动留痕） | 2026-04-13 | 任务范围/工具/目标已明确 | Codex |

## 7. 工具降级、硬阻塞与限制
- 默认主线工具：Filesystem + PowerShell
- 不可用工具：无
- 降级原因：无
- 替代流程：无
- 影响范围：无
- 补偿措施：无
- 硬阻塞：无

## 4. 审阅发现（摘要）

### 4.1 结论
- QUALITY_REVIEW：FAIL

### 4.2 关键问题（会拖累 Task 2/3）

1. `SampleContract` / `normalize_sample_contract` 的类型与演进边界过于宽松，后续扩展大概率返工。
   - 位置：`tools/perf/write_gate/sample_contract.py`：`normalize_sample_contract()` 将 `restore_strategy` 强制 `str(...).strip()`（会把非字符串类型静默转成字符串），且 contract 没有版本字段/枚举约束。
   - 影响：Task 2/3 一旦要把 sample contract 扩成“多字段 + 强校验 + 向后兼容/迁移策略”，现有“Any + 宽松字符串化”会迫使你们改解析策略、补 schema、补错误分支测试，等于重写这一层。

2. `ScenarioSpec` 中存在“配置来源耦合 + 未使用字段”的信号，容易把 Task 2/3 的复杂度放大。
   - 位置：`tools/perf/backend_capacity_gate.py`：`ScenarioSpec.sample_contract` 被加载（`_normalize_scenario()` 里 `normalize_sample_contract(raw.get("sample_contract"))`），但在该文件的执行路径（`_execute_scenario()` / `_request_scenario()` / `_run_capacity_gate()`）里并未消费。
   - 影响：这会让后续任务在“到底 contract 在哪里生效、如何影响请求、如何产出指标/日志”上出现边界漂移；如果 Task 2/3 需要让 contract 真正参与 gate 判定或请求构造，当前结构缺少明确的落点与测试护栏。

3. 单测覆盖集中在“能加载/能绑定”，但缺少对 gate 输出 contract 与核心指标字段的约束，后续改动容易无声破坏。
   - 位置：`backend/tests/test_backend_capacity_gate_unit.py`：测试覆盖了 token_pool 绑定、layer/sample_contract 读取、未知 token_pool 的拒绝，但没有覆盖 `MetricBucket.to_dict()` 输出字段（`p95_ms/p99_ms/error_rate/status_counts`）以及 `gate_passed` 判定（阈值边界）。
   - 影响：Task 2/3 若要新增指标字段、改变百分位算法、引入按 layer/scenario 分组阈值等，当前测试无法作为回归护栏，重构风险会集中爆发。

## 8. 交付判断
- 已完成项：按指定文件完成只读 code quality review；输出 FAIL 与 3 个最关键阻塞后续任务的问题点。
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付（仅审阅结论）

## 9. 迁移说明
- 无迁移，直接替换（本任务不产生代码变更）
