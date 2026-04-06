# 本机辅助工具安装说明

## 目标

本文档记录 `ZYKJ_MES` 项目当前 Windows 主机辅助工具的安装状态、验证方式与项目用途。

## 工具状态总览

| 工具 | 用途 | 当前状态 | 启动或验证命令 | 对本项目的主要用途 |
| --- | --- | --- | --- | --- |
| Docker Desktop / Docker Compose | 容器运行与多服务编排 | 已可用，未重装 | `docker --version`；`docker compose version` | 启动数据库、后端依赖与本地联调环境 |
| GitHub CLI (`gh`) | GitHub 仓库、PR、Issue 与检查项操作 | 已安装并可用 | `C:\Program Files\GitHub CLI\gh.exe --version` | 后续 PR 创建、Issue 查看、远程仓库查询 |
| Bruno GUI | API 调试与接口集合管理 | 已安装并可用 | `winget list --id Bruno.Bruno`（本轮未做 GUI 交互启动验证） | 本地接口调试、接口集合维护 |
| Bruno CLI (`bru`) | API 集合命令行执行 | 已安装并可用 | `C:\Users\Donki\AppData\Roaming\npm\bru.cmd --version` | 命令行执行 Bruno 集合、联调与回归辅助 |
| Trivy | 镜像、文件系统与依赖漏洞扫描 | 已安装并可用 | `C:\Users\Donki\AppData\Local\Microsoft\WinGet\Links\trivy.exe --version` | 容器镜像与代码依赖安全扫描 |
| Syft | SBOM 生成 | 已安装并可用 | `C:\Users\Donki\AppData\Local\Microsoft\WinGet\Links\syft.exe version` | 生成依赖清单，配合漏洞扫描与审计 |
| mitmproxy / mitmdump | HTTP(S) 抓包与请求重放 | 已安装并可用 | `C:\Program Files\mitmproxy\bin\mitmdump.exe --version` | 前后端联调、接口抓包、流量排查 |
| Fiddler Everywhere | GUI 抓包与会话分析 | 已安装并可用 | `winget list --id Telerik.Fiddler.Everywhere`（本轮未做 GUI 交互启动验证） | 图形化查看会话、调试代理流量 |
| FlaUInspect | Windows UIA 树检查工具（历史工具） | 已弃用（历史保留，不作为主线） | 如需核对历史环境可用 `winget list --id FlaUI.FlaUInspect` | 不作为默认链路；当前测试主线为 `integration_test` |
| WinAppDriver | Windows UI 自动化驱动 | 已安装并可用 | `C:\Program Files (x86)\Windows Application Driver\WinAppDriver.exe /?`；短暂启动后退出 | Windows 桌面自动化回归与 UI 驱动联调 |

## 详细说明

### Docker Desktop / Docker Compose

- 处理方式：仅验证，不重装。
- 当前状态：已可用。
- 验证结果：`Docker version 29.2.1`；`Docker Compose version v5.1.0`。

### GitHub CLI

- 安装方式：`winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements --silent`
- 当前状态：已安装并可用。
- 验证结果：`gh version 2.89.0`。

### Bruno GUI / CLI

- GUI 安装方式：`winget install --id Bruno.Bruno -e --accept-source-agreements --accept-package-agreements --silent`
- CLI 安装方式：`npm install -g @usebruno/cli`
- 当前状态：GUI 与 CLI 均已安装并可用。
- 验证结果：`bru 3.2.1`；`winget list --id Bruno.Bruno` 命中 `3.2.2`。本轮未做 Bruno GUI 交互启动验证。

### Trivy

- 安装方式：`winget install --id AquaSecurity.Trivy -e --accept-source-agreements --accept-package-agreements --silent`
- 当前状态：已安装并可用。
- 验证结果：`Version: 0.69.3`。

### Syft

- 安装方式：`winget install --id Anchore.Syft -e --accept-source-agreements --accept-package-agreements --silent`
- 当前状态：已安装并可用。
- 验证结果：`Version: 1.42.3`。

### mitmproxy / Fiddler Everywhere

- mitmproxy 安装方式：`winget install --id mitmproxy.mitmproxy -e --accept-source-agreements --accept-package-agreements --silent`
- Fiddler Everywhere 安装方式：`winget install --id Telerik.Fiddler.Everywhere -e --accept-source-agreements --accept-package-agreements --silent`
- 当前状态：两者均已安装；`mitmdump` 可直接输出版本，Fiddler 以 `winget list` 结果为主。本轮未做 Fiddler GUI 交互启动验证。
- 验证结果：`Mitmproxy: 12.2.1 binary`；`winget list --id Telerik.Fiddler.Everywhere` 显示 `7.7.2`。

### FlaUInspect（弃用）/ WinAppDriver

- FlaUInspect 安装方式：`winget install --id FlaUI.FlaUInspect -e --accept-source-agreements --accept-package-agreements --silent`
- FlaUInspect 当前状态：已弃用（历史保留）；默认不再作为测试与验证链路。
- WinAppDriver 安装方式：`winget` 无包，已改用官方 MSI：`https://github.com/microsoft/WinAppDriver/releases/download/v1.2.1/WindowsApplicationDriver_1.2.1.msi`
- WinAppDriver 当前状态：已安装并可用。
- WinAppDriver 重试结果：2026-04-03 23:13 使用缓存 MSI 再次执行静默安装，详细日志写入 `%TEMP%\WinAppDriver_install_retry.log`，日志显示 `Installation completed successfully.` 且 `MainEngineThread is returning 0`。
- WinAppDriver 最小验证：`C:\Program Files (x86)\Windows Application Driver\WinAppDriver.exe /?` 可正常输出帮助；该命令返回退出码 `1` 属常见行为，不视为异常。短暂启动 2 秒后进程仍存活，随后主动结束，说明程序可正常拉起。

## PATH 刷新说明

- 本轮校准时，当前 agent 所在 PowerShell 会话未自动刷新新 PATH。
- 因此验证时优先使用绝对路径或 `winget list`。
- 对用户后续新开终端，通常可直接使用以下命令；若仍不可用，可重新打开终端后再试：`gh`、`bru`、`trivy`、`syft`。

## 最小自检结果

| 检查项 | 结果 |
| --- | --- |
| `docker --version` | `Docker version 29.2.1, build a5c7197` |
| `docker compose version` | `Docker Compose version v5.1.0` |
| `gh --version` | `gh version 2.89.0`（绝对路径验证） |
| `bru --version` | `3.2.1`（`C:\Users\Donki\AppData\Roaming\npm\bru.cmd`） |
| `trivy --version` | `Version: 0.69.3` |
| `syft version` | `Version: 1.42.3` |
| `mitmdump --version` | `Mitmproxy: 12.2.1 binary`（绝对路径验证） |
| Bruno GUI | `winget list --id Bruno.Bruno` 命中 `3.2.2`；本轮未做 GUI 交互启动验证 |
| Fiddler Everywhere | `winget list --id Telerik.Fiddler.Everywhere` 命中 `7.7.2`；本轮未做 GUI 交互启动验证 |
| FlaUInspect | 已弃用（历史保留，不纳入主线验证） |
| WinAppDriver | `WinAppDriver.exe /?` 正常输出帮助；短暂启动可拉起 |

## 结论

- 无迁移，直接校准（无需重装）。
- 本次目标清单均已确认可用，且已记录验证路径与未执行 GUI 交互验证的边界。
