# 指挥官执行留痕：OpenCode 删除后深度复核

## 1. 任务信息

- 任务名称：OpenCode 全量删除后的深度残留检查
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 检查范围

- 进程与命令解析
- Windows 服务、计划任务、启动项、Run 键
- 用户/系统环境变量与 PATH
- 常见安装目录、配置目录、缓存目录、快捷方式目录
- `Recent` 快捷方式、`Prefetch` 痕迹
- 用户配置目录中的文本引用
- 当前仓库内带 `opencode` 名称的文件与目录

## 3. 关键结论

1. 系统层面未再发现 OpenCode 安装体、运行进程、服务、计划任务、启动项、PATH 残留或快捷方式残留。
2. 注册表常见软件区与卸载区未再发现 `OpenCode/opencode` 相关键。
3. `Recent` 快捷方式与 `Prefetch` 未发现 OpenCode 可执行文件痕迹。
4. 深度扫描中未再发现系统级目录下带 `OpenCode/opencode` 名称的文件或目录；此前发现的 VS Code 缓存包已在上一轮删除。
5. 当前仍能看到的 `opencode` 相关项全部属于“项目工作区留痕/文档”或“其他软件源码文本中的普通字符串”，不构成 OpenCode 软件安装残留。

## 4. 非安装残留项说明

### 4.1 当前仓库内仍存在的相关项

- `C:\Users\Donki\UserData\Code\ZYKJ_MES\.git\opencode`
  - 内容为一串提交哈希，属于仓库内部文件，不是 OpenCode 安装体。
- `C:\Users\Donki\UserData\Code\ZYKJ_MES\docs\opencode_tooling_bundle.md`
  - 属于项目文档。
- `C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\...opencode...`
  - 属于本次与历史排查留痕、实验目录和任务日志。

### 4.2 其他软件中的普通字符串引用

- `C:\Users\Donki\.vscode\extensions\github.copilot-chat-0.42.3\...`
  - 仅是文本中提到 `OpenCode/AGENTS.md` 的说明字符串。
- `C:\Users\Donki\.vscode\extensions\ms-python.vscode-python-envs-1.26.0-win32-x64\readme.md`
  - 仅包含邮件地址 `opencode@microsoft.com`。
- `C:\Users\Donki\.vscode\extensions\openai.chatgpt-26.325.31654-win32-x64\...js.map`
  - 仅为源映射文件中的普通文本，不是 OpenCode 安装残留。

## 5. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | 进程/服务/命令解析检查 | 2026-04-04 10:xx +08:00 | 无运行中 OpenCode 进程、服务或可执行命令 |
| E2 | 计划任务、Run 键、环境变量检查 | 2026-04-04 10:xx +08:00 | 无启动项、任务项、PATH 或环境变量残留 |
| E3 | 常见系统目录深度扫描 | 2026-04-04 10:xx +08:00 | 无系统级文件/目录残留 |
| E4 | 快捷方式、Recent、Prefetch 检查 | 2026-04-04 10:xx +08:00 | 无执行入口与近期执行痕迹 |
| E5 | 用户配置文本引用检查 | 2026-04-04 10:xx +08:00 | 仅发现其他软件源码/文档中的普通字符串 |
| E6 | 当前仓库文件名扫描 | 2026-04-04 10:xx +08:00 | 仅剩项目文档、证据留痕与 `.git` 内部文件 |

## 6. 降级记录

- 不可用工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`
- 降级原因：当前会话未提供对应工具入口
- 替代措施：使用 `update_plan`、`shell_command`、本地文件系统/注册表/快捷方式/系统项扫描完成深度复核
- 影响范围：不影响本轮深度检查结论

## 7. 后续建议

1. 如果你的目标是“系统里彻底没有 OpenCode 软件残留”，当前已满足。
2. 如果你的目标是“连当前仓库里带 `opencode` 名字的文档、实验目录、留痕文件都删掉”，需要单独再做一轮“工作区清理”。
3. 工作区清理会影响审计留痕与历史排查记录，应与“系统卸载”分开处理。
