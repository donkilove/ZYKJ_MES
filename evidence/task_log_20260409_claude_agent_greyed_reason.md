# 任务日志：Claude Agent 置灰原因排查

- 日期：2026-04-09
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务排查，未派生子 agent

## 1. 输入来源
- 用户指令：为什么 Claude Agent 是灰色的？
- 需求基线：用户截图、JetBrains AI Assistant/ACP/Claude Agent 官方文档
- 代码范围：`evidence/`、本机 JetBrains AI/ACP 配置目录

## 2. 关键结论
1. 本机 `Claude Agent` 已安装，不是“没下载”导致的灰色。
2. 本机 JetBrains ACP 注册记录存在 `acp.registry.claude-acp`，且 `disabledAgents` 为空，不是被手动禁用。
3. 最可能原因是当前没有满足 Claude Agent 的认证条件。
4. JetBrains 官方说明显示 Claude Agent 只能通过 JetBrains AI 订阅或 Anthropic API key 使用，不支持直接使用普通 Claude 个人订阅登录。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 用户截图 | 2026-04-09 19:10:00 | `Claude Agent β` 与 `Codex` 在 AI Chat 选择器中呈灰色，而 `OpenCode β` 可选 | Codex |
| E2 | `C:\Users\Donki\AppData\Roaming\JetBrains\acp-agents\installed.json` | 2026-04-09 19:10:00 | `Claude Agent` 已注册安装，且未被列入 `disabledAgents` | Codex |
| E3 | JetBrains 官方 Claude Agent 文档 | 2026-04-09 19:10:00 | Claude Agent 可通过 JetBrains AI 订阅或 Anthropic API token 使用 | Codex |
| E4 | JetBrains 官方 AI Chat 文档 | 2026-04-09 19:10:00 | Claude Agent、Codex 初始都可能需要安装/授权；Claude Agent 认证方式是 JetBrains AI 或 Anthropic API key | Codex |
| E5 | JetBrains 官方 OAuth 文档 | 2026-04-09 19:10:00 | Codex 支持 OAuth 登录 ChatGPT；Claude Agent 文档未提供相同个人订阅登录路径 | Codex |

## 4. 交付判断
- 已完成项：官方文档核对、本机 ACP 注册状态核对、原因定位、修复建议整理
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 5. 迁移说明
- 无迁移，直接替换
