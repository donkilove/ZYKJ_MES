# 指挥官执行留痕：OpenCode 第三方扩展清理复核

## 1. 任务信息

- 任务名称：复核 OpenCode 第三方工具/扩展是否已清理
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 输入来源

- 用户指令：先把 OpenCode 中所有第三方工具删掉
- 核对范围：
  - `C:\Users\Donki\.config\opencode`
  - `C:\Users\Donki\UserData\Code\ZYKJ_MES\.opencode`
  - `C:\Users\Donki\.local\share\opencode\bin`

## 3. 关键结论

1. `C:\Users\Donki\.config\opencode` 当前仅保留 `opencode.json`，此前额外安装的 `node_modules`、`package.json`、`bun.lock`、`.gitignore` 已不存在。
2. 仓库内 `C:\Users\Donki\UserData\Code\ZYKJ_MES\.opencode` 已不存在，原有技能目录已删除。
3. 生效配置 `C:\Users\Donki\.config\opencode\opencode.json` 仍保留，`baseURL` 仍指向 `https://yb.saigou.work:2053/v1`，未被误删。
4. `C:\Users\Donki\.local\share\opencode\bin` 下残留的 `node_modules`、`package.json`、语言服务器与二进制文件属于 OpenCode 自带运行时组件，不属于本轮已清理的用户侧第三方扩展。

## 4. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | `C:\Users\Donki\.config\opencode` 目录清单 | 2026-04-04 10:xx +08:00 | 当前仅剩 `opencode.json` |
| E2 | `C:\Users\Donki\UserData\Code\ZYKJ_MES\.opencode` 路径检测 | 2026-04-04 10:xx +08:00 | `.opencode` 目录不存在 |
| E3 | `C:\Users\Donki\.config\opencode\opencode.json` | 2026-04-04 10:xx +08:00 | `baseURL` 仍为 `https://yb.saigou.work:2053/v1` |
| E4 | `C:\Users\Donki\.local\share\opencode\bin\package.json` | 2026-04-04 10:xx +08:00 | 目录内为 OpenCode 自带语言服务依赖 |

## 5. 降级记录

- 不可用工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`
- 降级原因：当前会话未提供对应工具入口
- 替代措施：使用 `update_plan`、`shell_command` 与本地文件核对完成复核并补记证据
- 影响范围：不影响本轮清理复核结论

## 6. 后续建议

1. 先完全退出并重启 OpenCode 桌面端，再复测同一配置。
2. 若仍报 `Instructions are required`，则可基本排除“用户侧第三方扩展残留”这一方向，根因更接近上游 `yb.saigou.work:2053` 对 `/v1/responses` 的兼容性要求。
3. 若后续仍要坚持该地址，可单独走“最小注入 `instructions`”补丁方案；若不再坚持该地址，则直接切回兼容端点。
