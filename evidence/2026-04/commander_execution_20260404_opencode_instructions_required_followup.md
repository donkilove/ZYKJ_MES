# 指挥官执行留痕：OpenCode 报错 `Instructions are required` 复核

## 1. 任务信息

- 任务名称：复核 OpenCode 对话时报错 `Bad Request: {"detail":"Instructions are required"}`
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 输入来源

- 用户问题：为啥会出现 `Bad Request: {"detail":"Instructions are required"}`？
- 排查范围：
  - `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat`
  - `C:\Users\Donki\.config\opencode\opencode.json`
  - `C:\Users\Donki\.config\opencode\node_modules\@opencode-ai\sdk\dist\v2\gen\types.gen.d.ts`

## 3. 关键结论

1. 报错来自 OpenCode 当前配置的上游接口 `https://yb.saigou.work:2053/v1/responses`，不是仓库业务代码抛出。
2. 本机实际生效的 OpenCode 配置文件是 `C:\Users\Donki\.config\opencode\opencode.json`，其中 `provider.openai.options.baseURL` 指向上述代理地址。
3. OpenCode 桌面端本地日志已记录两类上游返回：
   - `400 Bad Request: {"detail":"Instructions are required"}`
   - `403 OpenAI codex passthrough requires a non-empty instructions field`
4. 这说明当前代理/中转服务把 `/v1/responses` 请求中的 `instructions` 设成了强制必填；而当前 OpenCode 与该代理的兼容方式不匹配，所以请求被拒绝。
5. 本机 OpenCode 配置 schema 虽然存在顶层 `instructions` 配置位，但当前问题首先是“代理兼容性/约束”问题，优先应更换为兼容 OpenAI Responses API 的端点，或让代理放宽对 `instructions` 的强制校验。

## 4. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat` | 2026-04-04 10:0x +08:00 | 日志记录请求实际发往 `https://yb.saigou.work:2053/v1/responses`，并返回 `Instructions are required` / `requires a non-empty instructions field` |
| E2 | `C:\Users\Donki\.config\opencode\opencode.json` | 2026-04-04 10:0x +08:00 | 当前 `provider.openai.options.baseURL` 指向 `https://yb.saigou.work:2053/v1` |
| E3 | `C:\Users\Donki\.config\opencode\node_modules\@opencode-ai\sdk\dist\v2\gen\types.gen.d.ts` | 2026-04-04 10:0x +08:00 | OpenCode 配置 schema 存在 `instructions?: Array<string>`，但本轮报错仍由上游兼容性约束触发 |

## 5. 降级记录

- 不可用工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`
- 降级原因：当前会话未提供对应工具入口
- 替代措施：使用 `update_plan`、`shell_command`、本机 OpenCode 配置与日志检索补偿留痕
- 影响范围：无法按仓库首选 MCP 工具链直接取证，但不影响本轮根因判断

## 6. 建议动作

1. 优先将 `C:\Users\Donki\.config\opencode\opencode.json` 里的 `baseURL` 改回官方兼容端点，或改为已确认兼容 OpenAI Responses API 的中转端点。
2. 若必须继续使用 `yb.saigou.work:2053`，需要该服务端放宽校验，允许无 `instructions` 的 Responses 请求，或明确其要求的 `instructions` 注入方式。
3. 不建议先从仓库代码或当前提问内容排查，因为报错已明确发生在 OpenCode 到上游模型服务之间。

## 7. 迁移说明

- 无迁移，直接替换。
