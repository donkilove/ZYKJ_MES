# 任务日志：OpenCode 默认模型切换

- 日期：2026-04-09
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务执行，未派生子 agent

## 1. 输入来源
- 用户指令：`OpenCode` 指的是 `opencode CLI`，把默认模型改成第二张图高亮的模型。
- 需求基线：目标模型为 `OpenAI / GPT-5.4 (xhigh)`。
- 代码范围：
  - `evidence/`
  - `C:\Users\Donki\.config\opencode\opencode.json`
  - `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat`
  - `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.workspace.C--Users-Don.17trq9r.dat`

## 2. 任务目标、范围与非目标
### 任务目标
1. 确认 OpenCode 桌面界面对应的是 `opencode CLI` 配置，而不是 JetBrains 全局 LLM 配置。
2. 将默认模型切换为 `openai/gpt-5.4`，默认变体切换为 `xhigh`。
3. 用本机真实命令验证解析结果与新建会话落点。

### 任务范围
1. 检查 `opencode` 全局配置解析路径与字段语义。
2. 修改实际生效配置文件。
3. 记录会话级模型选择状态对“默认值显示”的影响。

### 非目标
1. 不修改 JetBrains AI Assistant 全局模型配置。
2. 不改动 OpenAI provider 的现有密钥与网关地址。
3. 不处理历史会话中已固定的模型选择状态。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `opencode --help`、`opencode run --help`、`opencode models openai` | 2026-04-09 19:xx | `model` 与 `variant` 分离；`openai/gpt-5.4` 与 `xhigh` 均受支持 | Codex |
| E2 | `opencode debug paths`、官方 schema `https://opencode.ai/config.json`、本机 SDK 类型定义 | 2026-04-09 19:xx | 实际配置路径为 `C:\Users\Donki\.config\opencode\opencode.json`；根级默认模型字段为 `model`，默认变体字段为 `agent.<name>.variant` | Codex |
| E3 | `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat` 与工作区状态文件 | 2026-04-09 19:xx | 桌面端会为既有会话保存独立的模型/variant 选择，默认值主要影响新会话 | Codex |
| E4 | 修改后的 `C:\Users\Donki\.config\opencode\opencode.json` | 2026-04-09 19:46 | 已写入 `model=openai/gpt-5.4`、`default_agent=build`、`agent.build.variant=xhigh`、`agent.plan.variant=xhigh` | Codex |
| E5 | `opencode debug config`、`opencode debug agent build`、`opencode debug agent plan`、`opencode run --format json "仅回复OK"`、`opencode export <session>` | 2026-04-09 19:47 | 解析结果与新建会话实际都落到 `openai/gpt-5.4` + `xhigh` | Codex |

## 4. 执行摘要
1. 先纠正任务范围，停止沿用 JetBrains 全局 LLM 配置思路，改按 `opencode CLI` 配置链路排查。
2. 通过本机 `opencode` 帮助与官方 schema 确认：
   - 根级 `model` 控制默认模型；
   - `agent.build.variant` / `agent.plan.variant` 控制对应 agent 的默认变体；
   - 当前全局配置目录为 `C:\Users\Donki\.config\opencode`。
3. 检查桌面状态文件后确认：已有会话会记住各自的模型选择，因此“默认模型”主要影响后续新会话。
4. 修改 `C:\Users\Donki\.config\opencode\opencode.json`，加入以下默认项：
   - `model = openai/gpt-5.4`
   - `default_agent = build`
   - `agent.build.model = openai/gpt-5.4`
   - `agent.build.variant = xhigh`
   - `agent.plan.model = openai/gpt-5.4`
   - `agent.plan.variant = xhigh`
5. 执行真实验证，确认解析结果和新创建会话都已命中目标模型。

## 5. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 配置定位 | 初始误将问题落到 JetBrains 全局模型配置 | 用户所说的 `OpenCode` 实为 `opencode CLI` | 切换到 `opencode` 全局配置、schema 与桌面状态文件排查 | 通过 |

## 6. 工具降级、硬阻塞与限制
- 不可用工具：无
- 降级原因：未启用子 agent；当前会话开发者约束要求仅在用户显式要求时才能派生子 agent
- 替代流程：使用“修改后独立命令解析验证 + 新建最小会话运行验证”作为等效补偿
- 影响范围：不影响本次默认模型切换结论
- 补偿措施：保留 `debug config`、`debug agent`、`run`、`export` 四层证据
- 硬阻塞：无

## 7. 交付判断
- 已完成项：
  - 确认 OpenCode 对应 `opencode CLI`
  - 修改全局默认模型为 `openai/gpt-5.4`
  - 修改 `build` 与 `plan` 默认变体为 `xhigh`
  - 完成解析级与运行级验证
  - 更新 `evidence/`
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 8. 迁移说明
- 无迁移，直接替换。
