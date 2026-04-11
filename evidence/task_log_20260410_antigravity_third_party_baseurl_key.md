# 任务日志：Antigravity 第三方 baseURL 与 key 接入判断

- 日期：2026-04-10
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务咨询，未派生子 agent

## 1. 输入来源
- 用户指令：google 的 Antigravity 软件怎么接入第三方的 baseURL 和 key？
- 需求基线：用户提供的 Antigravity 桌面图标、本机 Antigravity 安装目录与配置目录
- 代码范围：`evidence/`、`C:\Users\Donki\AppData\Local\Programs\Antigravity\resources\app\extensions\antigravity\`、`C:\Users\Donki\AppData\Roaming\Antigravity\`

## 2. 关键结论
1. 当前 Antigravity 桌面应用未暴露“第三方 LLM/OpenAI 兼容 `baseURL` + `API key`”的公开设置项。
2. 本机安装包内 `package.json` 可见的配置项仅包含扩展市场 URL、工作区搜索上限和少量编辑器行为项，没有模型 provider、自定义推理网关或 OpenAI 兼容入口。
3. Antigravity 支持的是 MCP 配置，`mcp_config.schema.json` 中可配置 `serverUrl`、`headers`、`oauth` 等字段，但这属于 MCP 服务接入，不等于把 Antigravity 自身大模型后端切到第三方 `baseURL`。
4. 若目标是“让 Antigravity 调用你自己的 OpenAI 兼容模型服务”，当前核查范围内没有官方可用入口；若目标是“接第三方 MCP 服务”，则可以通过 `mcp_config.json` 配置 `serverUrl` 与鉴权头实现。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 本机 `C:\Users\Donki\AppData\Local\Programs\Antigravity\resources\app\extensions\antigravity\package.json` | 2026-04-10 12:28:00 | Antigravity 暴露的配置项不包含第三方模型 `baseURL` / `API key` 设置 | Codex |
| E2 | 本机 `C:\Users\Donki\AppData\Local\Programs\Antigravity\resources\app\extensions\antigravity\schemas\mcp_config.schema.json` | 2026-04-10 12:28:00 | MCP 配置支持 `serverUrl`、`headers`、`oauth`，但作用域是 MCP 服务 | Codex |
| E3 | 本机 `C:\Users\Donki\AppData\Roaming\Antigravity\Preferences` | 2026-04-10 12:20:00 | 用户侧常规偏好文件未出现第三方模型 provider 配置痕迹 | Codex |
| E4 | 本机 `C:\Users\Donki\AppData\Roaming\Antigravity\logs\` 与安装目录关键字核查 | 2026-04-10 12:24:00 | 未发现公开暴露的 `baseURL` / `provider` 用户配置入口 | Codex |

## 4. 交付判断
- 已完成项：产品对象确认、本机安装包配置核查、MCP 与模型后端能力边界区分、可执行示例整理
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 5. 迁移说明
- 无迁移，直接替换
