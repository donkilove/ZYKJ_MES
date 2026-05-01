# 指挥官执行留痕：OpenCode 提问报错 `Instructions are required` 排查

## 1. 任务信息

- 任务名称：排查 OpenCode 对话时报错 `Bad Request: {"detail":"Instructions are required"}`
- 执行日期：2026-04-04
- 执行方式：指挥官模式
- 当前状态：进行中
- 指挥模式：主 agent 负责拆解、派发、汇总与判定；原子任务由子 agent 执行与独立验证
- 工具能力边界：
  - 可用：`update_plan`、`shell_command`、`spawn_agent`、`wait_agent`、`apply_patch`
  - 不可用：`Sequential Thinking MCP`、`TodoWrite`、Serena MCP、Context7 MCP

## 2. 输入来源

- 用户指令：为什么我想 opencode 提问会有 `Bad Request: {"detail":"Instructions are required"}`
- 相关文件：
  - `AGENTS.md`
  - `指挥官工作流程.md`
  - `opencode.json`
  - `start_frontend.py`
- 参考留痕：
  - `evidence/opencode_skills_task_log_20260319.md`
  - `evidence/task_log_20260404_cc_switch_opencode_config.md`

## 3. 任务目标、范围与非目标

### 3.1 任务目标

1. 明确 OpenCode 报错的直接原因与触发条件。
2. 给出最小修复方案；若根因明确且改动边界清晰，则给出可落地配置修复建议。

### 3.2 任务范围

1. 检查本仓库 `opencode.json`、`AGENTS.md` 与本地 OpenCode 命令行为。
2. 必要时参考 OpenCode 官方文档或官方仓库，核对当前配置要求。

### 3.3 非目标

1. 不扩展排查与本次报错无关的前后端业务逻辑。
2. 不做与用户诉求无关的大范围 OpenCode 配置重构。

## 4. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `AGENTS.md` 与 `指挥官工作流程.md` 文件存在检查 | 2026-04-04 09:xx | 当前仓库触发指挥官模式执行要求 | 主 agent |
| E2 | `opencode.json` 当前内容 | 2026-04-04 09:xx | 当前配置仅声明 `mcp` 与 `permission.skill`，尚未见显式 `instructions` 配置 | 主 agent |
| E3 | `start_frontend.py` 当前内容 | 2026-04-04 09:xx | 与本次 OpenCode 请求体报错暂无直接关系，属于排除项 | 主 agent |
| E4 | 执行子 agent 调研输出 | 待补 | 待补 | 子 agent，主 agent evidence 代记 |
| E5 | 验证子 agent 复核输出 | 待补 | 待补 | 子 agent，主 agent evidence 代记 |

## 5. 指挥拆解结果

### 5.1 原子任务清单

| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 定位报错根因 | 确认 `instructions` 缺失发生在配置层、请求构造层还是 OpenCode 版本行为变化 | 已派发 `Cicero` | 待派发 | 能给出带证据的根因判断与最小修复方案 | 进行中 |
| 2 | 独立验证根因 | 独立复核原子任务 1 的判断是否成立 | 待派发 | 待派发 | 能独立确认或推翻根因与修复建议 | 待开始 |

### 5.2 排序依据

- 先确认根因，再决定是否需要最小配置修复，避免误改现有 OpenCode 配置。
- 验证子 agent 必须在执行子 agent 结论形成后独立复核，满足指挥官闭环要求。

## 6. 子 agent 输出摘要

### 6.1 调研/执行子 agent

- 原子任务 1：已派发 `Cicero`
- 责任范围：`opencode.json`、`AGENTS.md`、OpenCode 本地命令行为、必要的官方文档核对
- 当前结果：待回传

## 7. 验证结果

- 待执行子 agent 返回后派发独立验证子 agent。

## 8. 失败重试记录

- 暂无。

## 9. 实际改动

- `evidence/commander_execution_20260404_opencode_instructions_required.md`：建立本次排查任务日志。

## 10. 工具降级、硬阻塞与限制

### 10.1 工具降级记录

- 不可用工具：`Sequential Thinking MCP`、`TodoWrite`、Serena MCP、Context7 MCP
- 降级原因：当前会话未提供对应工具入口
- 触发时间：2026-04-04 09:xx
- 替代工具或替代流程：
  - 使用 `update_plan` 维护步骤与状态
  - 使用书面拆解 + 指挥官任务日志替代 Sequential Thinking 留痕
  - 使用 `shell_command`、必要时 `web` 核对官方资料
- 影响范围：无法直接使用仓库要求的首选 MCP 工具链
- 补偿措施：补齐日志、证据编号、子 agent 闭环与最终工具调用简报

### 10.2 evidence 代记说明

- 代记责任人：主 agent
- 代记原因：子 agent 无法直接写入本仓库 `evidence/`
- 代记内容范围：子 agent 调研摘要、验证命令与结论

### 10.3 硬阻塞

- 无

### 10.4 已知限制

- 目前尚未取得执行子 agent 对 OpenCode 当前版本行为的独立结论。
- 如需最终确认是否为上游版本变更，可能需要参考 OpenCode 官方文档或仓库代码。

## 11. 交付判断

- 已完成项：
  - 建立任务日志并记录降级原因
  - 完成任务拆解并派发执行子 agent
- 未完成项：
  - 根因确认
  - 独立验证闭环
- 是否满足任务目标：否
- 主 agent 最终结论：继续执行中

## 12. 输出文件

- `evidence/commander_execution_20260404_opencode_instructions_required.md`

## 13. 迁移说明

- 无迁移，直接替换。
