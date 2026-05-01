# 任务日志：OpenCode 本地 MCP 清理

- 日期：2026-04-10
- 执行人：OpenCode 主 agent
- 当前状态：已完成
- 指挥模式：未触发；单任务最小闭环执行

## 1. 输入来源
- 用户指令：说明 Git MCP 配置；移除 OpenCode 中 `postgres` 与 `serena` 的 MCP 注册，只保留 `MCP_DOCKER`；解释 LSP 与插件用途。
- 需求基线：`opencode.json`、`docs/opencode_tooling_bundle.md`
- 代码范围：项目根目录 OpenCode 配置

## 2. 任务目标、范围与非目标
### 任务目标
1. 清除项目级本地 MCP 注册，避免在 OpenCode UI 中继续出现 `postgres` 与 `serena`。
2. 保持 Docker 侧 `MCP_DOCKER` 能继续作为宿主 MCP 使用。
3. 向用户说明 Git MCP、LSP、插件的用途与配置方式。

### 任务范围
1. 移除项目级 `opencode.json` 中的本地 MCP 配置。
2. 对结果执行一次 OpenCode MCP 列表验证。

### 非目标
1. 不修改 Docker Desktop 中已安装的 MCP 服务器。
2. 不调整 OpenCode 全局配置与用户级配置。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `opencode.json` 现状核对 | 2026-04-10 | 项目级配置仅注册了 `serena` 与 `postgres` 两个本地 MCP | OpenCode |
| E2 | OpenCode 官方 Config/LSP/Plugins 文档 | 2026-04-10 | 项目级 `opencode.json` 会覆盖叠加配置；LSP 与插件分别是代码诊断和行为扩展机制 | OpenCode |

## 4. 执行摘要
- 计划动作：删除项目级 `opencode.json`，让 OpenCode 不再从仓库注入本地 MCP。
- 预期验证：执行 `opencode mcp list`，确认项目侧注册项不再出现。

## 5. 验证结果
- 验证命令：`opencode mcp list`
- 验证结论：通过
- 关键结果：当前仅显示 `MCP_DOCKER connected`，未再出现 `postgres` 与 `serena`
- 补充命令：`Test-Path opencode.json`
- 补充结果：`missing`

## 6. 交付判断
- 已完成项：
  - 删除项目级 `opencode.json`
  - 验证 OpenCode 当前仅保留 `MCP_DOCKER`
  - 整理 Git MCP、LSP 与插件的使用说明
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 7. 工具降级、硬阻塞与限制
- 不可用工具：无
- 降级原因：无
- 替代流程：无
- 影响范围：无
- 补偿措施：无
- 硬阻塞：无

## 8. 迁移说明
- 无迁移，直接替换
