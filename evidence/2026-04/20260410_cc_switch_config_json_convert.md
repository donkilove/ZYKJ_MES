# 任务日志：CC Switch 配置 JSON 格式核对与转换

- 日期：2026-04-10
- 执行人：OpenCode
- 当前状态：已完成
- 指挥模式：未触发；单任务直接执行

## 1. 输入来源
- 用户指令：查一下 CC Switch 的配置 JSON 格式，并将给定 OpenCode 配置转换为 CC Switch 配置 JSON。
- 需求基线：`AGENTS.md`
- 代码范围：无业务代码改动；仅留痕 `evidence/`

## 2. 任务目标、范围与非目标
### 任务目标
1. 核对 `CC Switch` 配置文件格式。
2. 将用户提供的 OpenCode 配置按可映射字段转换为 CC Switch JSON。

### 任务范围
1. 查阅公开文档/README。
2. 输出转换后的 JSON 与映射说明。

### 非目标
1. 不修改用户本地 Claude/CC Switch 配置文件。
2. 不补全 CC Switch 不支持的模型清单字段。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | npm `claude-code-switch` README | 2026-04-10 17:23:44 | `providers.json` 格式为 `{"name":{"base_url":"...","api_key":"..."}}` | OpenCode |
| E2 | 用户提供配置 | 2026-04-10 17:23:44 | 可映射字段仅有 `baseURL` 与 `apiKey`，模型清单不可直接映射 | OpenCode |

## 4. 执行摘要
- 通过网页抓取核对到 `claude-code-switch` README 中的配置文件格式。
- 识别到 CC Switch 仅支持 provider 基础连接信息，不支持 OpenCode 的 `models`、`variants`、`limit`、`agent`、`mcp`、`$schema` 结构。
- 输出按最小可用映射得到的 CC Switch JSON。
- 根据用户追加要求，按“多 provider 命名规范”扩展为一版可直接落盘的 `providers.json`，采用“上游网关前缀 + 模型名”作为键名，便于手动切换与识别。

## 5. 工具降级、硬阻塞与限制
- 不可用工具：GitHub 仓库主页直连返回 404。
- 降级原因：仓库主页不可直接获取。
- 替代流程：改用 npm 包 README 获取格式定义。
- 影响范围：无。
- 补偿措施：在交付中明确来源与不可映射字段。
- 硬阻塞：无。

## 6. 交付判断
- 已完成项：格式核对、JSON 转换、不可映射字段说明、多 provider 命名版 `providers.json`。
- 未完成项：无。
- 是否满足任务目标：是。
- 主 agent 最终结论：可交付。

## 7. 迁移说明
- 无迁移，直接替换。
