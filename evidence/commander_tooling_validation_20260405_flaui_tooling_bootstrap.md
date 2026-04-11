# 指挥官工具化验证模板

## 1. 任务基础信息

- 任务名称：FlaUI + FlaUInspect 桌面自动化基础设施安装与接入
- 对应主日志：`evidence/commander_execution_20260405_flaui_tooling_bootstrap.md`
- 执行日期：2026-04-05
- 当前状态：进行中
- 记录责任：主 agent

## 2. 输入基线

- 用户目标：改用 `FlaUI + FlaUInspect` 作为当前项目 Windows 客户端桌面自动化方案，并先安装好。
- 流程基线：`指挥官工作流程.md`
- 工具治理基线：`docs/commander_tooling_governance.md`
- 主机工具基线：`docs/host_tooling_bundle.md`
- 相关输入路径：
  - `frontend/`
  - `start_frontend.py`
  - `docs/host_tooling_bundle.md`

## 3. 任务分类

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-03 | CAT-05 | Windows 桌面自动化、Flutter Windows 客户端、主机工具安装与验证 | G1/G2/G3/G4/G5/G6/G7 |

## 4. 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | Sequential Thinking | 默认触发 | 完成任务拆解、边界、原子任务与验收标准定义 | 拆解结果、任务边界、接入策略 | 2026-04-05 |
| 2 | 启动 | TodoWrite | 默认触发 | 维护在制项状态 | 任务队列与状态 | 2026-04-05 |
| 3 | 启动 | evidence | 默认触发 | 指挥官模式先留痕 | 主日志与工具化日志 | 2026-04-05 |
| 4 | 执行 | Task | 默认触发 | 派发主机状态核查、安装接入、独立复检 | 子 agent 输出与验证结论 | 2026-04-05 |
| 5 | 执行 | Bash | 默认触发 | 运行 `dotnet`、`winget`、主机工具验证与构建命令 | 状态输出、安装结果、构建日志 | 2026-04-05 |
| 6 | 验证 | FlaUInspect / FlaUI | 补充触发 | 验证桌面控件树与最小 smoke 可用性 | 控件树可见性、最小自动化结果 | 2026-04-05 |
| 7 | 执行 | Task | 默认触发 | 调研 Flutter Windows UIA 树并落地第一批真实桌面用例 | UIA 定位结论、用例代码、自测结果 | 2026-04-05 |
| 8 | 验证 | Task | 默认触发 | 对第一批桌面用例做独立复检 | 工程级与新增用例级复检结果 | 2026-04-05 |

## 5. 执行留痕

### 5.1 执行子 agent 操作

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | Task + Bash | 主机状态 | 核查 `dotnet`、`FlaUInspect`、`WinAppDriver`、PATH 与仓库现状 | 确认 `FlaUInspect` 已安装可用，唯一主阻塞为缺少 `.NET SDK` | `task_id=ses_2a4e7691dffeTFZ4anZ7qI5ABw` |
| 2 | Task + Read/Grep | 仓库脚手架 | 核查是否已有 `.csproj` 或桌面自动化目录 | 确认仓库此前没有桌面自动化工程，推荐新增 `desktop_tests/flaui/` | `task_id=ses_2a4e76908ffe6TrYNssMeFw5Pl` |
| 3 | Task + Bash + apply_patch | FlaUI 基础设施 | 安装 `.NET 8 SDK`，新增 `desktop_tests/flaui/` 工程并执行 `restore/test` | 工程落地并自测通过 | `task_id=ses_2a4e4e9a1ffeHH5j1I3f653Js1` |
| 4 | Task + Bash | 最终独立复检 | 独立验证 SDK、FlaUInspect、restore、test | 全部通过 | `task_id=ses_2a4df5f87ffeYI5PZlEV42bf3U` |
| 5 | Task + Bash + apply_patch | UIA 调研与第一批用例实现 | 调研登录页/主壳层/消息中心的 UIA 暴露，并新增桌面用例与辅助类 | 已落地首批 3 条真实桌面用例并自测通过 | `task_id=ses_2a4d625b9ffekWr1Vx0MzZNrMl` |
| 6 | Task + Bash | 第一批用例独立复检 | 独立重跑工程与 `DesktopNavigationTests` | 工程 `4/4` 通过，新增用例 `3/3` 通过 | `task_id=ses_2a4ca23acffe3LOnskY842aDvF` |

### 5.2 自测结果

- `dotnet --list-sdks`：通过，返回 `8.0.419`。
- `FlaUInspect.exe`：通过，路径存在且可最小拉起。
- `dotnet restore`：通过。
- `dotnet test`：通过，`1` 个 smoke 用例通过。
- UIA 调研：通过，已定位登录页、主壳层与消息中心关键文本/按钮。
- 第一批桌面用例自测：通过，工程级 `4/4`。

## 6. 验证留痕

### 6.1 验证门禁检查

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | FLAUI-E1 | 已归类为 CAT-03 / CAT-05 |
| G2 | 通过 | 主日志 | 已记录默认触发工具与原因 |
| G3 | 通过 | FLAUI-E2/FLAUI-E4/FLAUI-E5 | 已形成执行与独立验证分离 |
| G4 | 通过 | FLAUI-E4/FLAUI-E5 | 已真实执行安装、restore、test 与最小可执行性验证 |
| G5 | 通过 | 主日志 | 已形成“触发 -> 执行 -> 验证 -> 收口”闭环 |
| G6 | 不适用 | 无 | 当前暂无工具降级 |
| G7 | 通过 | 主日志第 13 节 | 已声明无迁移，直接替换 |

### 6.2 独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| Task + Bash | T8 主机状态核查 | 独立执行 `dotnet --list-sdks`、检查 `FlaUInspect.exe` 路径并最小拉起 | 通过 | 主机前置条件满足 |
| Task + Bash | T9 FlaUI 基础设施落地 | 独立执行 `dotnet restore` 新工程 | 通过 | 新工程可独立 restore |
| Task + Bash | T10 最小 smoke 与独立复检 | 独立执行 `dotnet test` 新工程 | 通过 | smoke 已真实运行并通过 |
| Task + Bash | T11 UIA 控件树调研 | 只读核对新辅助类与用例边界 | 通过 | 关键 UIA 定位策略成立 |
| Task + Bash | T12 第一批 FlaUI 用例实现 | `dotnet test` 工程整体复检 | 通过 | 工程整体 `4/4` 通过 |
| Task + Bash | T13 第一批用例独立复检 | `dotnet test --filter "FullyQualifiedName~DesktopNavigationTests"` | 通过 | 新增用例 `3/3` 通过 |

### 6.3 关键观察

- 本轮关键不是单纯安装主机工具，而是让仓库具备可持续扩展的桌面自动化测试入口。
- 当前 `FlaUInspect` 已可作为桌面控件树探查工具使用，FlaUI 工程也已落地为独立最小工程。
- 当前已从“应用启动 + 主窗口出现”推进到“登录页元素、主壳层导航、消息中心入口”三条真实桌面用例。
- 当前定位策略仍主要依赖可见中文文本与控件类型，后续若要提升稳健性，可继续补更细的定位封装。

## 7. 失败重试

| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | T9 基础设施落地 | 初始 `dotnet restore` 失败 | 当前环境无 NuGet 包源配置 | 新增局部 `NuGet.Config` 指向 `nuget.org` | Task + Bash | 通过 |
| 1 | T9 基础设施落地 | 初始 `dotnet test` 编译失败 | 命名空间冲突与 FlaUI API 使用差异 | 修正工程源码后重跑 | Task + Bash | 通过 |
| 无 | T11-T13 | 无 | 无 | 无 | Task + Bash | 通过 |

## 8. 降级/阻塞/代记

### 8.1 工具降级

| 原工具 | 降级原因 | 替代工具或流程 | 影响范围 | 代偿措施 |
| --- | --- | --- | --- | --- |
| 无 | 无 | 无 | 无 | 无 |

### 8.2 阻塞记录

- 阻塞项：无
- 已尝试动作：已完成主机状态核查、SDK 安装、工程落地与独立复检
- 当前影响：无
- 下一步：后续可直接基于 `desktop_tests/flaui/` 扩展登录异常分支、主壳层模块跳转与消息详情等更深用例

### 8.3 evidence 代记

- 是否代记：是
- 代记责任人：主 agent
- 原始来源：执行子 agent / 验证子 agent 返回结果、命令输出、构建日志、smoke 结果
- 代记时间：2026-04-05
- 适用结论：统一沉淀工具触发、执行、验证与收口结论

## 9. 通过判定

- 是否完成“工具触发 -> 执行 -> 验证 -> 重试 -> 收口”闭环：否
- 是否完成“工具触发 -> 执行 -> 验证 -> 重试 -> 收口”闭环：是
- 是否满足主分类门禁：是
- 是否存在残余风险：有，当前仅覆盖首批桌面路径，尚未覆盖更复杂模块交互与长时间稳定性
- 最终判定：通过
- 判定时间：2026-04-05

## 10. 输出物

- 文档或代码输出：
  - `evidence/commander_execution_20260405_flaui_tooling_bootstrap.md`
  - `evidence/commander_tooling_validation_20260405_flaui_tooling_bootstrap.md`
- 代码输出：
  - `desktop_tests/flaui/NuGet.Config`
  - `desktop_tests/flaui/README.md`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/MesDesktop.FlaUI.Tests.csproj`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/MesClientPaths.cs`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/SmokeTests.cs`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/DesktopNavigationTests.cs`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/MesAppDriver.cs`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/MesLoginHelper.cs`
  - `desktop_tests/flaui/MesDesktop.FlaUI.Tests/UiTreeDebugHelper.cs`
- 证据输出：
  - `FLAUI-E1`
  - `FLAUI-E2`
  - `FLAUI-E3`
  - `FLAUI-E4`
  - `FLAUI-E5`

## 11. 迁移说明

- 无迁移，直接替换
