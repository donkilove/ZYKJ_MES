# 指挥官执行留痕：项目工具包接入（2026-04-03）

## 1. 任务信息

- 任务名称：为 `ZYKJ_MES` 项目接入 10 类工程工具能力
- 执行日期：2026-04-03
- 执行方式：指挥官模式拆解调度 + 子 agent 调研 + 子 agent 实现 + 子 agent 独立验证
- 当前状态：进行中

## 2. 输入来源

- 用户指令：`把这10个全部装上！`
- 上游清单来源：上一轮建议的 10 类工具
  1. Context7 MCP
  2. Serena MCP
  3. PostgreSQL / 数据库 MCP
  4. OpenAPI / Swagger 契约检查工具
  5. Playwright MCP
  6. Flutter UI 自动化 / 集成测试增强工具
  7. GitHub MCP / gh 深度集成工具
  8. ripgrep 增强统计 / 结构搜索工具
  9. HTTP 接口调试工具
  10. 编码 / 乱码诊断工具

## 3. 前置说明

- 仓库存在 `指挥官工作流程.md`，本轮按指挥官模式执行。
- 当前会话已可直接使用 `Task` 与 `Sequential Thinking`。
- 目标是把 10 类能力接入为当前项目可识别、可复用、可验证的工程工具链；若存在外部凭证依赖，需至少完成安装与配置骨架，并显式标注待填项。

## 4. 当前已知事实

- 证据 E1：`AGENTS.md`
  - 结论：主 agent 需负责拆解、留痕、派发与收口，不直接承担业务实现与最终验证。
- 证据 E2：`指挥官工作流程.md`
  - 结论：本轮必须按原子任务闭环推进。
- 证据 E3：`opencode.json`
  - 结论：项目当前仅已接入 `sequential_thinking`，其余工具未配置。

## 5. 任务目标

1. 为项目补齐上述 10 类工具能力的项目级接入。
2. 尽量优先采用 OpenCode 可识别的 `mcp`、`command`、脚本包装等标准形态。
3. 形成可审计的安装、验证与待填凭证说明。

## 6. 非目标

1. 不修改全局 OpenCode 用户配置。
2. 不替用户填写第三方平台密钥或 OAuth 凭证。
3. 不承诺所有第三方远端服务在无凭证情况下立即可执行真实业务调用。

## 7. 原子任务拆分

### A. 调研与选型

- A1：核定 10 类工具的最稳接入形态与包名 / 服务地址。
- A2：区分无凭证可直连、需本地依赖、需远端凭证三类。

### B. 实施接入

- B1：更新项目级 `opencode.json` 的 MCP / command / tool 配置。
- B2：为非 MCP 场景补充最小包装脚本或命令入口。
- B3：补充项目内说明文档，明确用途、启动方式、凭证要求。

### C. 独立验证

- C1：验证 OpenCode 能识别并列出 MCP。
- C2：验证自定义命令 / 脚本可输出帮助或完成只读自检。
- C3：汇总哪些已连接，哪些已安装待认证。

## 8. 当前验收标准

1. 10 类工具均在项目内有对应接入实体，不留口头方案。
2. 每类工具都能在配置、命令或脚本层面被明确定位。
3. 至少完成一次独立验证，输出可用状态分类。
4. 交付说明中明确“无迁移，直接替换”或等价迁移结论。

## 9. 风险与待确认

- 风险 R1：部分第三方工具官方包名可能变化，需以实时调研为准。
- 风险 R2：远端 MCP 可能因未认证显示未连接，但仍可视为已完成安装与项目接入。
- 风险 R3：Flutter UI 自动化工具生态可能更适合用包装脚本接入，而非直接 MCP。

## 10. 子 agent 调度计划

- 调研子 agent：并行确认 10 类工具的接入源与最小配置。
- 实现子 agent：根据调研结果修改项目配置与辅助文件。
- 验证子 agent：独立检查 MCP 列表、命令帮助、脚本可执行性与待认证项。

## 11. 子 agent 输出摘要

### 11.1 调研摘要

- 调研结论 A：`Context7`、`Serena`、`Playwright` 最适合直接以项目级 `mcp` 接入。
- 调研结论 B：`PostgreSQL` 能用本地 MCP，但更适合通过项目脚本包装连接串并默认禁用，避免因凭证或数据库未启动导致噪音失败。
- 调研结论 C：`OpenAPI`、`Flutter UI`、`GitHub`、`ripgrep/ast-grep`、`HTTP`、`编码诊断` 更适合项目脚本而非强行 MCP 化。

### 11.2 实现摘要

- 实现子 agent 已完成：
  - 更新 `opencode.json`，新增 `context7`、`serena`、`playwright`、`postgres`。
  - 新增 `tools/project_toolkit.py`，统一提供 8 个子命令入口。
  - 新增 `docs/opencode_tooling_bundle.md` 中文说明文档。
  - 用户级安装 `uv`，使 `Serena` 可由 `python -m uv` 拉起。

## 12. 验证闭环

### 12.1 首轮独立验证

- 结论：不通过。
- 失败项 F1：文档使用 `opencode mcp list`，与当前 Windows 环境实际可执行命令不一致。
- 失败项 F2：`tools/project_toolkit.py` 的中文帮助在当前 Windows 控制台输出乱码，不满足“帮助信息可用”。

### 12.2 修复重派

- 修复项 R1：将 `docs/opencode_tooling_bundle.md` 的 Windows MCP 验证命令改为 `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list`，并补充 PATH 已配置时可直接用 `opencode`。
- 修复项 R2：将 `tools/project_toolkit.py` 的 argparse 帮助改为 ASCII-first，顶部增加一行中文注释说明原因。

### 12.3 二轮独立验证

- 结论：通过。
- 验证结果：
  - `python tools/project_toolkit.py --help` 及 7 个关键子命令帮助均可读。
  - `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list` 可识别：
    - `sequential_thinking`：connected
    - `context7`：connected
    - `serena`：connected
    - `playwright`：connected
    - `postgres`：disabled

## 13. 最终结论

- 本轮已为项目接入并沉淀 10 类以上工具能力，覆盖用户要求。
- 其中可直接连接的 MCP 为：`sequential_thinking`、`context7`、`serena`、`playwright`。
- `postgres` 已接入但默认禁用，待数据库连接信息准备后启用。
- 其余能力已通过 `tools/project_toolkit.py` 与中文文档完成项目级落地。
- 无迁移，直接替换。
