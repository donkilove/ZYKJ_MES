# 指挥官执行留痕：OpenCode 全量删除

## 1. 任务信息

- 任务名称：彻底删除本机 OpenCode 安装体与用户侧残留
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 输入来源

- 用户指令：帮我彻底删除 opencode
- 核对与删除范围：
  - `C:\Users\Donki\AppData\Local\OpenCode`
  - `C:\Users\Donki\AppData\Local\ai.opencode.desktop`
  - `C:\Users\Donki\AppData\Roaming\OpenCode`
  - `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop`
  - `C:\Users\Donki\.config\opencode`
  - `C:\Users\Donki\.local\share\opencode`
  - 桌面/开始菜单快捷方式
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenCode`
  - `HKCU:\Software\opencode`
  - `C:\Users\Donki\AppData\Local\Temp\OpenCode-*-updater-*`
  - `C:\Users\Donki\AppData\Roaming\Code\CachedExtensionVSIXs\sst-dev.opencode-0.0.13`

## 3. 关键结论

1. OpenCode 安装体、用户配置、数据库、日志、缓存、快捷方式与卸载注册表项均已删除。
2. OpenCode 临时更新目录已清理。
3. VS Code 中发现的 OpenCode 相关缓存包已清理。
4. 最终复核未再发现系统安装区、用户配置区、注册表或常见快捷方式目录中的 `OpenCode/opencode` 残留项。
5. 本轮未删除仓库 `evidence/` 下与排查过程有关的留痕文档；这些文件属于项目记录，不属于软件安装残留。

## 4. 已删除项

- `C:\Users\Donki\.config\opencode`
- `C:\Users\Donki\.local\share\opencode`
- `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop`
- `C:\Users\Donki\AppData\Roaming\OpenCode`
- `C:\Users\Donki\AppData\Local\ai.opencode.desktop`
- `C:\Users\Donki\AppData\Local\OpenCode`
- `C:\Users\Donki\Desktop\OpenCode.lnk`
- `C:\Users\Donki\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OpenCode.lnk`
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenCode`
- `HKCU:\Software\opencode`
- `C:\Users\Donki\AppData\Local\Temp\OpenCode-1.3.0-updater-4gDnoL`
- `C:\Users\Donki\AppData\Local\Temp\OpenCode-1.3.13-updater-tocvdD`
- `C:\Users\Donki\AppData\Local\Temp\OpenCode-1.3.2-updater-5balEX`
- `C:\Users\Donki\AppData\Local\Temp\OpenCode-1.3.3-updater-gzajym`
- `C:\Users\Donki\AppData\Local\Temp\OpenCode-1.3.9-updater-cemxNg`
- `C:\Users\Donki\AppData\Roaming\Code\CachedExtensionVSIXs\sst-dev.opencode-0.0.13`

## 5. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | 用户目录常见安装/配置路径扫描 | 2026-04-04 10:xx +08:00 | 定位安装体、配置与数据目录 |
| E2 | 进程检查 | 2026-04-04 10:xx +08:00 | 删除前无运行中 OpenCode 进程 |
| E3 | 注册表 `HKCU:\Software` 与卸载项扫描 | 2026-04-04 10:xx +08:00 | 定位并删除卸载项与软件根键 |
| E4 | `AppData\Local\Temp` 与 `AppData\Roaming\Code` 扫描 | 2026-04-04 10:xx +08:00 | 清理更新残留与 VS Code 缓存 |
| E5 | 删除后复核扫描 | 2026-04-04 10:xx +08:00 | 常见系统区/用户区未再发现 OpenCode 残留 |

## 6. 降级记录

- 不可用工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`
- 降级原因：当前会话未提供对应工具入口，且用户要求直接执行删除
- 替代措施：使用 `update_plan`、`shell_command` 与本地文件/注册表扫描完成删除和复核
- 影响范围：不影响本轮删除结论

## 7. 迁移说明

- 无迁移，直接删除。
