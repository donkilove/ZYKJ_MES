# 指挥官执行留痕：OpenCode 昨晚可用、今早失效时间线排查

## 1. 任务信息

- 任务名称：排查“昨晚还能用、今天不能用”是否由昨晚安装工具导致
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 关键问题

1. 2026-04-03 晚上的工具安装是否改坏了 OpenCode
2. `Instructions are required` 是否与昨晚安装动作存在直接时序关系

## 3. 关键结论

1. 没有证据表明 2026-04-03 晚上的工具安装改动了 OpenCode 全局 provider 配置。
2. 2026-04-03 晚上的安装内容主要是项目级 MCP / 脚本工具与本机辅助工具，范围包括 `Context7`、`Serena`、`Playwright`、`Postgres`、`gh`、`Bruno`、`Trivy`、`Syft`、`mitmproxy`、`WinAppDriver` 等，不包含 OpenCode 上游 `baseURL` 切换。
3. OpenCode 程序本体 `OpenCode.exe` 与 `opencode-cli.exe` 的最后修改时间均为 2026-04-01，说明昨晚未发生 OpenCode 客户端升级。
4. 当前最直接、最可追溯的异常前置动作，是 2026-04-04 09:05:38 至 09:08:00 +08:00 写入了一套新的 OpenCode 代理配置，端点为 `https://yb.saigou.work:2053/v1`。
5. 第一次被记录到的报错发生在 2026-04-04 10:26:17 +08:00，错误来自 `https://yb.saigou.work:2053/v1/responses` 返回 `Instructions are required`。
6. 因此，当前更大概率是“今天早上切换到新的代理配置后，上游兼容性不满足”，而不是“昨晚安装工程工具把 OpenCode 装坏了”。

## 4. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | [commander_execution_20260403_tooling_installation_bundle.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/commander_execution_20260403_tooling_installation_bundle.md) | 2026-04-04 10:4x +08:00 | 2026-04-03 夜间安装的是项目级工程工具接入，不是全局 OpenCode provider 改写 |
| E2 | [commander_execution_20260403_host_tool_installation.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/commander_execution_20260403_host_tool_installation.md) | 2026-04-04 10:4x +08:00 | 2026-04-03 夜间补装的是 Docker / gh / Bruno / Trivy / Syft / mitmproxy / WinAppDriver 等本机辅助工具 |
| E3 | [task_log_20260404_cc_switch_opencode_config.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/task_log_20260404_cc_switch_opencode_config.md) | 2026-04-04 10:4x +08:00 | 2026-04-04 09:05:38 至 09:08:00 写入新的 OpenCode 代理配置，`baseURL` 为 `https://yb.saigou.work:2053/v1` |
| E4 | `C:\Users\Donki\AppData\Local\OpenCode\OpenCode.exe` / `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe` | 2026-04-04 10:4x +08:00 | OpenCode 程序文件最后修改时间均为 2026-04-01，昨晚无客户端升级迹象 |
| E5 | `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\opencode.global.dat` | 2026-04-04 10:4x +08:00 | 2026-04-04 10:26:17 记录到首次 `Instructions are required`，请求 URL 为 `https://yb.saigou.work:2053/v1/responses` |

## 5. 推断说明

- “昨晚工具安装导致今天不能用”这一说法，目前缺少直接证据支撑。
- “今天早上切换到新的 OpenCode 代理配置后触发兼容性错误”这一说法，具备明确的时间先后与日志证据。
- 上述第二条是基于现有证据的最强推断，不是对全部外部因素的绝对排除。

## 6. 建议动作

1. 若目标是恢复“昨天那种可用状态”，优先回退或替换当前 `https://yb.saigou.work:2053/v1` 代理配置。
2. 若必须继续使用该代理，则应补上请求体顶层 `instructions` 注入，或要求代理放宽校验。
3. 不建议优先卸载昨晚安装的工程工具，因为它们与当前错误链路没有直接证据关联。

## 7. 迁移说明

- 无迁移，直接替换。
