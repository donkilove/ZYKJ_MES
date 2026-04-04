# 指挥官执行留痕：OpenCode 插件修复 `Instructions are required`

## 1. 任务信息

- 任务名称：通过插件方式修复 OpenCode 上游兼容性错误
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 输入来源

- 用户指令：已重装 OpenCode，按之前插件方案开始修复 `Bad Request: {"detail":"Instructions are required"}`
- 生效配置：
  - `C:\Users\Donki\.config\opencode\opencode.json`
  - `baseURL = https://yb.saigou.work:2053/v1`
- 官方参考：
  - `https://opencode.ai/docs/plugins/`

## 3. 关键结论

1. 本轮已在 `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js` 落地正式兼容插件。
2. 插件已被 OpenCode 自动加载；`debug config` 中可见插件路径 `file:///C:/Users/Donki/.config/opencode/plugins/inject_via_fetch_patch.js`。
3. 本地隔离验证已确认：发送到 `/v1/responses` 的真实请求体顶层已补上非空 `instructions`。
4. 真实链路验证显示：原始错误 `Instructions are required` 已不再出现，随后暴露出的 `Unsupported parameter: max_output_tokens` 也已通过插件兼容处理。
5. 在兼容问题清除后，最新真实链路阻塞点变为上游返回 `401 token_invalidated`，属于认证状态问题，不再是 OpenCode 请求体兼容问题。

## 4. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat` | 2026-04-04 11:xx +08:00 | 重装后仍持续出现 `Instructions are required` |
| E2 | `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js` | 2026-04-04 11:xx +08:00 | 正式兼容插件已落地 |
| E3 | `https://opencode.ai/docs/plugins/` | 2026-04-04 | 官方说明本地 `plugins/` 目录中的插件会自动加载 |
| E4 | `C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\opencode_instructions_live_fix\last_request_body.json` | 2026-04-04 11:12 +08:00 | 隔离验证中真实请求体已包含顶层 `instructions` |
| E5 | `C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\opencode_instructions_live_fix\real_endpoint_fetch_patch_trace_v2.json` | 2026-04-04 11:15 +08:00 | 真实链路请求已注入 `instructions` 且移除 `max_output_tokens` |
| E6 | `C:\Users\Donki\.local\share\opencode\log\2026-04-04T031522.log` | 2026-04-04 11:15 +08:00 | 真实链路返回 `ok`，证明主请求已可跑通 |
| E7 | `C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\opencode_instructions_live_fix\real_endpoint_fetch_patch_trace_v3.json` | 2026-04-04 11:16 +08:00 | 最新真实链路仍走兼容插件，当前阻塞点已转为 `401 token_invalidated` |

## 5. 执行记录

- 2026-04-04 11:09 +08:00：复核重装后 OpenCode 配置目录、安装目录与桌面日志，确认仍报 `Instructions are required`。
- 2026-04-04 11:10 +08:00：确认官方插件 SDK 已恢复；参考官方插件文档确定本地 `plugins/` 目录自动加载策略。
- 2026-04-04 11:11 +08:00：创建正式插件 `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js`。
- 2026-04-04 11:12 +08:00：构建隔离验证环境 `evidence/opencode_instructions_live_fix/`，通过本地 mock 服务确认顶层 `instructions` 注入成功。
- 2026-04-04 11:13 +08:00：首次真实链路验证不再出现 `Instructions are required`，新暴露错误为 `Unsupported parameter: max_output_tokens`。
- 2026-04-04 11:15 +08:00：增强插件，兼容移除 `max_output_tokens`；真实链路验证返回 `ok`。
- 2026-04-04 11:16 +08:00：继续复测时，上游返回 `401 token_invalidated`，确认当前剩余阻塞点已从请求兼容性切换为认证状态。

## 6. 当前交付物

- 正式插件：
  - `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js`
- 隔离验证目录：
  - `C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\opencode_instructions_live_fix\`

## 7. 降级记录

- 不可用工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`
- 降级原因：当前会话未提供对应工具入口
- 替代措施：采用显式书面推演、`update_plan`、`shell_command`、本地插件 SDK、官方插件文档与桌面/运行日志核对继续执行
- 影响范围：不影响本轮修复结论

## 8. 后续建议

1. 当前插件可保留，后续即便重新启动 OpenCode，原始 `instructions` 兼容问题仍会继续被修复。
2. 若再次出现无法对话，优先检查 `yb.saigou.work:2053` 返回的是否仍是 `401 token_invalidated`，这已超出请求体兼容层。
3. 如需继续打通剩余阻塞，应转向刷新或更换上游认证令牌，而不是回退本轮插件改动。
