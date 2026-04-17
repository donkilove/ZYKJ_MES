# 任务日志：MCP 注册与当前会话注入差异排查

- 日期：2026-04-16
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务直执；采用系统化调试流程，先收集证据后下结论

## 1. 输入来源
- 用户指令：技能没啥问题，但 MCP 服务有问题，我这里显示 codex 插件注册这些 MCP 服务器，但是你似乎没有用到，检查一下是什么原因
- 需求基线：
  - `AGENTS.md`
  - `docs/AGENTS/00-导航与装配说明.md`
  - `docs/AGENTS/10-执行总则.md`
  - `docs/AGENTS/20-指挥官模式与工作流.md`
  - `docs/AGENTS/30-工具治理与验证门禁.md`
  - `docs/AGENTS/40-质量交付与留痕.md`
  - `docs/AGENTS/50-模板与索引.md`
- 排查对象：
  - `/root/.codex/config.toml`
  - `/root/.codex/logs_2.sqlite`
  - `/root/.codex/state_5.sqlite`
  - `/root/.codex/sessions/2026/04/16/rollout-2026-04-16T23-23-52-019d96e4-38b6-75f1-9a40-dfc997cfbb92.jsonl`

## 1.1 前置说明
- 默认主线工具：`update_plan`、宿主安全命令、`serena`、`git`、`fetch`
- 缺失工具：`Sequential Thinking` 的会话级可调用入口、`rg`
- 缺失/降级原因：
  - 当前线程未暴露 `sequential-thinking` 对应函数工具
  - 宿主环境未安装 `rg`
- 替代工具：
  - 用 `systematic-debugging` 技能 + 书面拆解 + 日志/状态库核对
  - 用 `grep`、`sed`、`python3`、SQLite 查询代替 `rg`
- 影响范围：
  - 调试仍可完成，但需要直接查本地日志与状态库

## 2. 关键证据
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `/root/.codex/config.toml` | 2026-04-16 23:38:57 +0800 | 本地已注册 7 个 MCP 服务器：`fetch`、`filesystem`、`git`、`memory`、`playwright`、`sequential-thinking`、`serena` | Codex |
| E2 | 当前线程会话文件 `rollout-2026-04-16T23-23-52-019d96e4-38b6-75f1-9a40-dfc997cfbb92.jsonl` | 2026-04-16 23:40:09 +0800 | 当前线程实际调用记录只出现 `mcp__serena__*`、`mcp__git__*`、`mcp__fetch__fetch` 与 `list_mcp_*`，没有 `mcp__filesystem__*`、`mcp__memory__*`、`mcp__playwright__*`、`mcp__sequential*` | Codex |
| E3 | `/root/.codex/logs_2.sqlite` 中当前线程首个 `codex_client::transport` 请求体 | 2026-04-16 23:42:xx +0800 | 发给模型的 `tools` 数组共 47 个，其中 MCP 仅包含 `serena`、`git`、`fetch`，未包含 `filesystem`、`memory`、`playwright`、`sequential-thinking` 对应函数工具 | Codex |
| E4 | 另外两条线程 `019d960e-f423-7110-b5f9-67a9f50ca4c7`、`019d96c4-b81d-7da0-b66a-80898599613a` 的首个 `tools` 数组 | 2026-04-16 23:43:xx +0800 | 跨线程结果一致，均只注入 `serena`、`git`、`fetch`，说明不是单线程偶发遗漏 | Codex |
| E5 | `state_5.sqlite` 的 `thread_dynamic_tools` | 2026-04-16 23:40:52 +0800 | 当前线程无动态补挂工具记录，说明缺失工具没有在线程启动后热注入 | Codex |
| E6 | 两次 `mcp__fetch__fetch` 实测 | 2026-04-16 23:25:59 +0800 | `fetch` 虽被注入，但当前传输异常，报错 `Transport closed` | Codex |

## 3. 根因判断
### 3.1 已确认事实
1. 本地 Codex 配置层面，7 个 MCP 服务器都已注册。
2. 当前线程真正下发给模型的工具清单里，只包含 `serena`、`git`、`fetch` 三组 MCP。
3. `filesystem`、`memory`、`playwright`、`sequential-thinking` 没有以可调用函数工具的形式出现在当前线程里。
4. 这一现象在更早的其他线程中同样存在，不是本线程单次异常。

### 3.2 结论
- 问题不在“你没有注册”，而在“Codex 宿主没有把这 4 类 MCP 桥接进当前会话的工具数组”。
- 也就是说，界面上的“已开启/已注册”不等于“当前线程对模型可调用”。
- 我这边没有用到这 4 类 MCP，不是漏用，而是当前会话根本没有拿到对应函数入口。

### 3.3 最可能原因
1. 当前 Codex VS Code 运行时对会话可用工具做了固定注入/白名单过滤。
2. `filesystem`、`memory`、`playwright`、`sequential-thinking` 虽在本地配置中启用，但未被桥接为本线程可调用的 `mcp__...` 函数。
3. 该过滤是稳定存在的，因为跨多个线程的首个 `tools` 数组都一致。

## 4. 与用户观察的差异说明
- 用户界面显示的是“本地插件配置里有哪些 MCP 服务器被启用”。
- 模型实际能调用什么，要看线程启动时发给模型的 `tools` 数组。
- 本轮排查中，这两个层面不一致：
  - 配置层：7 个都在
  - 会话注入层：只有 `serena`、`git`、`fetch`

## 5. 建议下一步
1. 优先重载 VS Code 的 Codex 扩展或完全重启 Codex 会话后，新开一个线程再比对一次首个 `tools` 数组。
2. 若新线程仍只有这 3 组 MCP，基本可以判定是当前 Codex 版本或当前宿主桥接策略只暴露这 3 组。
3. 若你愿意，我下一步可以继续帮你做“重启后复测脚本/检查清单”，把 UI 启用状态与线程工具注入结果做一份可复现对照。

## 6. 交付判断
- 已完成项：
  - 检查本地 MCP 注册配置
  - 检查当前线程实际调用记录
  - 从传输日志提取线程启动时的 `tools` 数组
  - 跨线程对比注入结果
  - 输出根因判断与建议
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 7. 迁移说明
- 无迁移，直接替换
