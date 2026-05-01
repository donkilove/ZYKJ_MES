# 指挥官执行留痕：指挥官模式工具可用性审计（2026-04-04）

## 1. 任务信息

- 任务名称：检查指挥官模式要求的工具哪些未安装或当前不可用
- 执行日期：2026-04-04
- 执行方式：指挥官模式
- 当前状态：已完成

## 2. 输入来源

- 用户指令：`现在检查一下指挥官模式中要求的工具哪些没有安装的！`
- 规则来源：`AGENTS.md`、`指挥官工作流程.md`、`docs/commander_tooling_governance.md`
- 接入说明：`docs/opencode_tooling_bundle.md`、`docs/host_tooling_bundle.md`

## 3. 判定口径

1. 若工具要求以当前会话可直接调用的 MCP/内建工具形态出现，则以“当前会话是否可用”为准。
2. 若工具要求以本机命令或 GUI 程序形态出现，则以 `Get-Command`、绝对路径、`winget list`、帮助/版本输出综合判定。
3. 若工具是仓库内置脚本能力，则以脚本文件存在且 `python tools/project_toolkit.py --help` 可列出子命令为准，不要求存在同名全局命令。

## 4. 关键检查动作

1. 读取规则文件：`AGENTS.md`、`指挥官工作流程.md`、`docs/commander_tooling_governance.md`
2. 检查当前 OpenCode CLI MCP 配置：`C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list`
3. 检查命令可用性：`serena`、`uvx`、`context7`、`gh`、`trivy`、`syft`、`playwright`、`flutter`、`bruno`、`mitmproxy`、`fiddler`、`openapi-validate`、`http-probe`、`uv`、`npx`、`python`
4. 检查绝对路径：`WinAppDriver.exe`、`bru.cmd` 及文档中记录的若干工具路径
5. 检查仓库内置工具脚本：`python tools/project_toolkit.py --help`

## 5. 实际检查结果

### 5.1 当前会话核心缺口

| 工具 | 结果 | 依据 | 影响 |
| --- | --- | --- | --- |
| Sequential Thinking MCP | 当前不可用 | 当前会话工具集中不存在该工具；OpenCode CLI `mcp list` 显示 `No MCP servers configured` | 无法按规则直接完成“先触发 Sequential Thinking” |
| Serena MCP | 当前不可用 | 当前会话工具集中不存在该工具；`serena`、`uvx` 均不可用；OpenCode CLI 未配置 MCP | 无法按规则直接完成语义级代码定位与最小编辑 |
| Context7 MCP | 当前不可用 | 当前会话工具集中不存在该工具；`context7` 命令不可用；OpenCode CLI 未配置 MCP | 涉及外部文档补证时只能走离线降级 |
| Playwright MCP | 当前不可用 | OpenCode CLI 未配置 MCP；`playwright` 命令不可用 | 页面自动化验证需降级 |

### 5.2 本机命令/程序缺失

| 工具 | 结果 | 依据 |
| --- | --- | --- |
| `gh` | 当前未安装 | `Get-Command gh` 未命中；`winget list --id GitHub.cli` 未命中 |
| `trivy` | 当前未安装 | `Get-Command trivy` 未命中；`winget list --id AquaSecurity.Trivy` 未命中 |
| `syft` | 当前未安装 | `Get-Command syft` 未命中；`winget list --id Anchore.Syft` 未命中 |
| `mitmproxy` / `mitmdump` | 当前未安装 | `Get-Command mitmproxy` 未命中；`winget list --id mitmproxy.mitmproxy` 未命中 |
| Fiddler Everywhere | 当前未安装 | 绝对路径未命中；`winget list --id Telerik.Fiddler.Everywhere` 未命中 |
| FlaUInspect | 当前未安装 | 绝对路径未命中；`winget list --id FlaUI.FlaUInspect` 未命中 |
| Bruno GUI | 当前未安装 | `winget list --id Bruno.Bruno` 未命中 |
| `uv` / `uvx` | 当前未安装 | `Get-Command uv`、`Get-Command uvx` 均未命中 |

### 5.3 已存在或可替代的能力

| 工具/能力 | 结果 | 依据 |
| --- | --- | --- |
| Task | 可用 | 当前会话内建工具可调用 |
| TodoWrite | 可用 | 当前会话内建工具可调用 |
| evidence 留痕 | 可用 | 仓库 `evidence/` 目录可写 |
| `python` | 可用 | `Get-Command python` 命中 `C:\Program Files\Python312\python.exe` |
| `npx` | 可用 | `Get-Command npx` 命中 `C:\Program Files\nodejs\npx.ps1` |
| `node` / `npm` | 可用 | `Get-Command node`、`npm` 命中 |
| `flutter` | 可用 | `Get-Command flutter` 命中 `C:\Users\Donki\develop\flutter\bin\flutter.bat` |
| Bruno CLI `bru` | 可用 | `C:\Users\Donki\AppData\Roaming\npm\bru.cmd` 存在 |
| WinAppDriver | 可用 | `C:\Program Files (x86)\Windows Application Driver\WinAppDriver.exe` 存在 |
| `openapi-validate` / `http-probe` / `postgres-mcp` / `flutter-ui` / `github-api` | 仓库已接入 | `tools/project_toolkit.py` 存在且 `--help` 可列出这些子命令 |

## 6. 与既有文档的偏差

1. `docs/host_tooling_bundle.md` 与 `evidence/commander_execution_20260403_host_tool_installation.md` 记录了多项主机工具“已安装并可用”。
2. 但本次实际检查中，`gh`、`trivy`、`syft`、`mitmproxy`、Fiddler Everywhere、FlaUInspect、Bruno GUI` 均未在当前系统中命中，说明文档与当前机器状态不一致，至少不能作为“仍已安装”的现时证据。
3. 当前更关键的问题是 OpenCode CLI `mcp list` 显示没有配置任何 MCP server，因此即使底层运行时如 `python`、`npx` 存在，MCP 类工具仍然处于未接入状态。

## 7. 风险与结论

1. 最大缺口不是单个辅助命令，而是指挥官模式核心 MCP 工具链当前未接通：`Sequential Thinking`、`Serena`、`Context7`、`Playwright` 都不能直接用。
2. 在这种状态下，只能按规则走降级口径，不能声称“完整按标准指挥官工具链执行”。
3. 发布前审计、远端协作、抓包排障、桌面控件检查等能力也存在明显缺口，因为 `gh`、`trivy`、`syft`、`mitmproxy`、Fiddler Everywhere、FlaUInspect` 当前均不可用。
4. 无迁移，直接替换。

## 8. 最终结论

- 当前未安装或当前不可用的重点工具：`Sequential Thinking MCP`、`Serena MCP`、`Context7 MCP`、`Playwright MCP`、`uv`/`uvx`、`gh`、`trivy`、`syft`、`mitmproxy`、Fiddler Everywhere、`FlaUInspect`、Bruno GUI。
- 当前仍可用的关键替代能力：`Task`、`TodoWrite`、`python`、`npx`、`node`、`npm`、`flutter`、Bruno CLI `bru`、WinAppDriver、`tools/project_toolkit.py` 提供的项目内置命令。
