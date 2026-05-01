# 任务日志：前端轮询治理

- 日期：2026-04-23
- 执行人：Codex
- 当前状态：进行中
- 指挥模式：子 agent 驱动执行；采用隔离工作树 `c:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\fpoll`

## 1. 输入来源

- 用户指令：先进行轮询治理！！！
- 需求基线：
  - `AGENTS.md`
  - `docs/AGENTS/00-导航与装配说明.md`
  - `docs/AGENTS/10-执行总则.md`
  - `docs/AGENTS/20-指挥官模式与工作流.md`
  - `docs/AGENTS/30-工具治理与验证门禁.md`
  - `docs/AGENTS/40-质量交付与留痕.md`
  - `docs/AGENTS/50-模板与索引.md`
- 代码范围：
  - `frontend/lib/features/shell`
  - `frontend/lib/features/message`
  - `frontend/lib/features/production`
  - `frontend/lib/features/user`
  - `frontend/test`

## 1.1 前置说明

- 默认主线工具：`using-superpowers`、`brainstorming`、`MCP_DOCKER sequentialthinking`、`update_plan`、宿主安全命令、Flutter 测试命令
- 缺失工具：`rg.exe`
- 缺失/降级原因：当前环境下 `rg.exe` 执行路径权限被拒绝
- 替代工具：宿主安全命令 `Get-Content`、`Get-ChildItem`、Flutter 命令、子 agent
- 影响范围：仅影响检索工具形态，不影响本轮实施与验证

## 2. 任务目标、范围与非目标

### 任务目标

1. 优先收敛当前前端重复轮询与隐藏页无意义轮询问题。
2. 在不破坏现有业务刷新的前提下减少前端和后端无效请求。

### 任务范围

1. 主壳轮询协调。
2. 消息中心、生产工单查询、个人中心的页面级轮询。
3. 对应测试与验证命令。

### 非目标

1. 本轮不做与轮询无关的 UI 重构。
2. 本轮不做后端接口改造。

## 3. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 本轮 `using-superpowers`、`brainstorming`、`Sequential Thinking`、`update_plan` | 2026-04-23 10:15 +08:00 | 已确认本轮聚焦轮询治理，并按先设计再实现的流程推进 | Codex |
| E2 | 现有代码抽查：`main_shell_refresh_coordinator.dart`、`message_center_page.dart`、`production_order_query_page.dart`、`account_settings_page.dart` | 2026-04-23 10:15 +08:00 | 已确认当前存在主壳与页面级轮询并存、页面离焦后仍继续轮询的问题 | Codex |
| E3 | 用户已逐节确认的轮询治理设计与设计文档 `docs/superpowers/specs/2026-04-23-frontend-polling-governance-design.md` | 2026-04-23 10:19 +08:00 | 已确定采用“统一活跃态门禁”方案，并覆盖主壳与页面级轮询 | Codex |
| E4 | 实施计划文档 `docs/superpowers/plans/2026-04-23-frontend-polling-governance-implementation.md` | 2026-04-23 10:24 +08:00 | 已形成可直接执行的 TDD 实施计划，覆盖主壳、消息中心、生产工单查询、个人中心与最终验证 | Codex |
| E5 | 用户选择 `Subagent-Driven`，已创建工作树 `c:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\fpoll`，并通过最小基线测试 `flutter test test/widgets/main_shell_refresh_coordinator_test.dart -r expanded` | 2026-04-23 10:32 +08:00 | 子 agent 可在隔离工作树内执行任务，当前基线可启动 | Codex |
| E6 | Task 1 实现子 agent `Parfit` 提交 `501d7cc` 与 `f3ab3fb` | 2026-04-23 10:48 +08:00 | 已完成主壳全局轮询启停与已排队防抖刷新取消约束 | Codex |
| E7 | Task 1 规格复核子 agent `Faraday` 与代码质量复核子 agent `Gibbs` | 2026-04-23 10:49 +08:00 | Task 1 当前已通过规格复核与代码质量复核；Windows generated 文件为任务外副作用 | Codex |
| E8 | Task 2 实现子 agent `Confucius` 提交 `530db3c` 与 `d98ea48` | 2026-04-23 11:03 +08:00 | 已建立主壳到用户/生产目标页面的 `pollingEnabled` 参数通路 | Codex |
| E9 | Task 2 红阶段代记：实现子 agent 回执 + 当前代码对比 | 2026-04-23 11:04 +08:00 | `main_shell_page_test.dart` 新增的两条活跃态传递测试在 `moduleActive`/`pollingEnabled` 通路落地前应失败；第一次实现仅包入未消费的 `InheritedWidget` 被规格复核驳回，后续以 `d98ea48` 将参数真正落到 `AccountSettingsPage` 与 `ProductionOrderQueryPage` 构造函数 | Codex |
| E10 | Task 2 规格复核子 agent `Nietzsche` 与代码质量复核子 agent `Noether` | 2026-04-23 11:09 +08:00 | Task 2 当前已通过规格与质量复核；保留意见仅为测试更偏装配验证，不阻塞继续实施 | Codex |
| E11 | Task 3 实现子 agent `Archimedes` 提交 `97fe693` | 2026-04-23 11:15 +08:00 | 已为消息中心建立 `pollingEnabled` 门禁，并把 summary 收口到同一加载链路 | Codex |
| E12 | Task 3 红阶段代记：实现子 agent 回执 + 当前代码对比 | 2026-04-23 11:16 +08:00 | `message_center_page_test.dart` 中新增的 3 条用例在 `MessageCenterPage` 尚无 `pollingEnabled` 参数且仍保留 `_refreshStats()` 独立调用时应失败；实现回执明确记录了首次运行因缺少 `pollingEnabled` 参数而失败，后续实现后转绿 | Codex |
| E13 | Task 3 后续实现提交 `0587398`、`9814a94` 与 `636f933` | 2026-04-23 11:28 +08:00 | 已补齐消息模块活跃态透传、刷新顺序、摘要慢/失败路径与旧轮次摘要隔离测试 | Codex |
| E14 | Task 3 规格复核子 agent `Erdos` 与代码质量复核子 agent `Pauli` | 2026-04-23 11:30 +08:00 | Task 3 当前已通过规格与代码质量复核；Windows generated 文件仍为任务外副作用 | Codex |
| E15 | 本地最终复跑 `flutter test test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart -r expanded` | 2026-04-24 00:05 +08:00 | Task 3 相关集成测试当前为绿，可继续执行 Task 4 | Codex |
| E16 | 本地最终验证 `flutter test ...` 与 `flutter analyze` | 2026-04-24 00:12 +08:00 | 目标测试集通过，但 `flutter analyze` 暴露 7 处由 builder 签名变更引起的测试编译错误，需要补齐最终验证收口 | Codex |

## 4. Task 1 收口

- 原子任务：主壳全局轮询启停治理
- 结果：已完成
- 实现提交：
  - `501d7cc` `主壳轮询改为按前后台状态启停`
  - `f3ab3fb` `补齐主壳防抖刷新停轮询约束`
- 实际改动：
  - `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`
  - `frontend/lib/features/shell/presentation/main_shell_controller.dart`
  - `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
  - `frontend/test/widgets/main_shell_page_test.dart`
- 规格复核结论：
  - 已满足“主壳后台停轮询、前台立即补拉并保持 WS reconnect”要求
  - 已满足整组 `flutter test test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_test.dart -r expanded` 通过要求
- 代码质量复核结论：
  - 已补齐后台前已排队的首页工作台防抖刷新取消逻辑
  - 已补齐对应高风险路径测试
- 任务外副作用：
  - `frontend/windows/flutter/generated_plugin_registrant.cc`
  - `frontend/windows/flutter/generated_plugin_registrant.h`
  - `frontend/windows/flutter/generated_plugins.cmake`
  - 当前仅存在 LF/CRLF 警告和工作区脏状态，无实质 diff，不纳入本任务

## 5. 失败重试记录

| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | Task 1 主壳全局轮询启停治理 | 整组 `main_shell_page_test.dart` 仍有两条既有失败，规格复核未通过 | 既有测试断言与当前页面真实文案/结构漂移，且红阶段证据未代记 | 在允许文件内同步修正测试断言并补回红阶段说明 | 通过 |
| 2 | Task 1 主壳全局轮询启停治理 | 代码质量复核指出后台前已排队的首页工作台防抖刷新未被取消 | `setGlobalPollingEnabled(false)` 只停周期轮询，未取消 `_debounceTimer` | 在协调器停轮询路径中取消 `_debounceTimer`，并新增对应测试 | 通过 |
| 3 | Task 2 模块活跃态通路 | 规格复核未通过：活跃态只包进未消费的 `InheritedWidget`，未真正传到目标页面 | 原 Task 2 计划边界过窄，无法仅凭 4 个文件完成真实参数传递 | 控制器已修正 Task 2 边界，额外允许最小增补 `account_settings_page.dart` 与 `production_order_query_page.dart` 构造参数 | 进行中 |
| 4 | Task 3 消息中心轮询门禁 | 代码质量复核未通过：主壳未向消息页透传活跃态，summary 并发处理与 `didUpdateWidget` 顺序存在风险 | 原 Task 3 边界过窄，只改消息页内部无法覆盖真实主壳集成路径 | 控制器已修正 Task 3 边界，额外允许最小增补 `main_shell_page_registry.dart` 与 `main_shell_page_test.dart` 处理消息模块活跃态透传与集成测试 | 进行中 |
| 5 | 最终整体验收 | 生产模块内部 tab 切换下的 `pollingEnabled` 更新未被触发 | `ProductionPage` 未监听 `TabController` 的 index 变化并 `setState`，导致订单查询页轮询活跃态可能滞后 | 增补生产模块 tab 切换联动与对应测试，再重跑最终验证 | 进行中 |

## 6. Task 2 收口

- 原子任务：模块活跃态参数通路
- 结果：已完成
- 实现提交：
  - `530db3c` `主壳向模块页面传递轮询活跃态`
  - `d98ea48` `补齐模块活跃态参数通路`
- 实际改动：
  - `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - `frontend/lib/features/user/presentation/user_page.dart`
  - `frontend/lib/features/production/presentation/production_page.dart`
  - `frontend/lib/features/user/presentation/account_settings_page.dart`
  - `frontend/lib/features/production/presentation/production_order_query_page.dart`
  - `frontend/test/widgets/main_shell_page_test.dart`
- 规格复核结论：
  - `AccountSettingsPage` 与 `ProductionOrderQueryPage` 现已真实收到 `pollingEnabled`
  - 空的 `InheritedWidget` 包装已移除
  - `flutter test test/widgets/main_shell_page_test.dart -r expanded` 通过
- 代码质量复核结论：
  - `moduleActive -> pollingEnabled` 参数通路当前清晰可用
  - 保留意见：新增测试更偏装配/通路验证，而非完整 UI 行为验证；该意见不阻塞继续实施
- 任务外副作用：
  - `frontend/windows/flutter/generated_plugin_registrant.cc`
  - `frontend/windows/flutter/generated_plugin_registrant.h`
  - `frontend/windows/flutter/generated_plugins.cmake`
  - 当前仍仅为工作树副作用，不纳入本任务

## 7. Task 3 进行中

- 原子任务：消息中心轮询门禁与重复请求收口
- 当前状态：已完成
- 实现提交：
  - `97fe693` `消息中心轮询改为按活跃态运行`
  - `0587398` `补齐消息中心活跃态透传与刷新顺序`
  - `9814a94` `收紧消息中心摘要慢路径阻塞`
  - `636f933` `补齐消息中心旧摘要隔离测试`
- 已完成内容：
  - `MessageCenterPage` 新增 `pollingEnabled` 默认参数
  - 主壳已通过 `MainShellPageRegistry` 真实透传 `pollingEnabled: moduleActiveFor('message')`
  - 页面轮询已按 `pollingEnabled` 启停
  - `false -> true` 时会立即补拉一次
  - `_load()` 后的 `_refreshStats()` 独立摘要请求已收口
  - 同帧停轮询 + refreshTick 变化不再额外触发列表刷新
  - 摘要慢/失败时列表主流程不被阻塞
  - 旧轮次慢摘要不会覆盖新轮次统计状态
- 当前验证：
  - `flutter test test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart -r expanded` 已通过
- 规格复核结论：
  - 消息模块活跃态透传、轮询门禁、刷新顺序与测试稳定性修补均已满足任务要求
- 代码质量复核结论：
  - `_loadRequestToken` 当前已通过回归测试锁住旧摘要污染新轮次状态的场景
  - 当前提交范围未见超范围业务改动

## 8. Task 4 进行中

- 原子任务：生产工单页与个人中心轮询门禁
- 当前状态：待接回实现结果
- 目标文件：
  - `frontend/lib/features/production/presentation/production_order_query_page.dart`
  - `frontend/lib/features/user/presentation/account_settings_page.dart`
  - `frontend/test/widgets/production_order_query_page_test.dart`
  - `frontend/test/widgets/account_settings_page_test.dart`

## 9. 最终验证阻塞

- 阻塞项：`flutter analyze` 未通过
- 当前现象：
  - `integration_test/home_shell_flow_test.dart` 中多个 builder 仍使用旧签名
  - `test/widgets/main_shell_page_registry_test.dart` 中 `userPageBuilder` 仍使用旧签名
- 根因：
  - Task 2 将 `MainShellUserPageBuilder` / `MainShellModulePageBuilder` 新增了必填参数 `moduleActive`
  - 相关测试替身构造器未同步签名
- 下一步：
  - 增补最终验证修复任务，只收编译错误，不改业务逻辑

## 10. 后续设计

- 2026-04-24：已完成消息中心重做设计确认，优先级为“信息更清楚”，设计文档已写入：
  - `docs/superpowers/specs/2026-04-24-message-center-redesign-design.md`

## 4. 迁移说明

- 无迁移，直接替换
