# 任务日志：前端重大缺陷复盘

- 日期：2026-04-23
- 执行人：Codex
- 当前状态：已完成
- 指挥模式：未启用子 agent；受更高优先级开发者约束限制，采用“主流程评审 + 显式验证补偿”闭环

## 1. 输入来源

- 用户指令：你觉得前端还有什么重大缺陷吗？
- 需求基线：
  - `AGENTS.md`
  - `docs/AGENTS/00-导航与装配说明.md`
  - `docs/AGENTS/10-执行总则.md`
  - `docs/AGENTS/20-指挥官模式与工作流.md`
  - `docs/AGENTS/30-工具治理与验证门禁.md`
  - `docs/AGENTS/40-质量交付与留痕.md`
  - `docs/AGENTS/50-模板与索引.md`
- 代码范围：
  - `frontend/lib`
  - `frontend/test`
  - `frontend/integration_test`

## 1.1 前置说明

- 默认主线工具：`using-superpowers`、`MCP_DOCKER sequentialthinking`、`update_plan`、宿主安全命令、`flutter analyze`、`flutter test`
- 缺失工具：无
- 缺失/降级原因：受更高优先级开发者约束限制，本轮不能在未获用户显式授权时派发子 agent
- 替代工具：主流程代码审查 + 独立命令验证补偿
- 影响范围：执行/验证角色无法通过子 agent 物理分离，但不影响本轮问题识别与验证留痕

## 2. 任务目标、范围与非目标

### 任务目标

1. 判断当前前端是否仍存在“重大缺陷”级别的问题。
2. 用代码与真实验证结果支撑排序，而不是仅给风格建议。

### 任务范围

1. Flutter 前端入口、主壳、首页、消息中心、生产页与软件设置相关代码。
2. 既有前端 evidence 与当前测试表现。

### 非目标

1. 本轮不直接修改业务代码。
2. 本轮不做全量逐页功能验收。

## 3. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 本轮 `using-superpowers`、规则分册阅读、`Sequential Thinking` 与 `update_plan` | 2026-04-23 10:00 +08:00 | 已确认本轮按 CAT-03 前端评审执行，并以真实验证补偿替代子 agent 分离 | Codex |
| E2 | `frontend/lib/features/shell/presentation/home_page.dart`、`home_dashboard_todo_card.dart` | 2026-04-23 10:12 +08:00 | 首页只在 `dashboardData == null` 时回退到快捷入口；一旦后端返回空待办列表，首页主卡片将失去模块捷径 | Codex |
| E3 | `frontend/lib/features/message/presentation/message_center_page.dart`、`frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart` | 2026-04-23 10:14 +08:00 | 消息中心已接入 WS 事件驱动，但仍保留 30 秒轮询与摘要二次拉取，刷新链路重复 | Codex |
| E4 | `frontend/lib/features/production/presentation/production_order_query_page.dart`、`frontend/lib/features/user/presentation/account_settings_page.dart` | 2026-04-23 10:16 +08:00 | 生产工单查询和个人中心仍有页面级定时轮询，且未对路由离场/页面不可见做暂停治理 | Codex |
| E5 | `flutter analyze` | 2026-04-23 10:18 +08:00 | 静态分析零报错，当前主要风险不在 lint 层 | Codex |
| E6 | `flutter test test/widgets/app_bootstrap_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/widgets/account_settings_page_test.dart` | 2026-04-23 10:19 +08:00 | 目标测试集中出现 3 处失败，分别命中软件设置文案断言漂移、首页快捷入口回归、消息跳转交互失效/命中不稳定 | Codex |

## 4. 执行计划

| 序号 | 步骤 | 目标 | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- |
| 1 | 读取规则并完成任务拆解 | 满足规则装配与工具门禁 | 规则、拆解、计划齐备 | 已完成 |
| 2 | 补齐 evidence 起始记录 | 满足任务开始留痕 | 日志已建立 | 已完成 |
| 3 | 抽查关键前端链路 | 找出仍可能构成重大缺陷的问题 | 至少覆盖入口、主壳、首页、消息、生产、设置 | 已完成 |
| 4 | 运行真实验证 | 用命令确认问题不只是主观判断 | 至少包含分析与相关测试 | 已完成 |
| 5 | 形成结论并收尾留痕 | 满足交付与 evidence 闭环 | 结论、风险、验证结果齐备 | 已完成 |

## 5. 过程记录

- 已完成规则装配、任务拆解和 evidence 起始建档。
- 已复核近期前端 evidence，确认以下旧风险已有明显收敛：
  - 主壳不再使用旧版全量常驻式 `IndexedStack`。
  - 登录页已接入动态公告能力。
  - `integration_test` 已从两份超大脚本扩展为多份模块流。
- 已针对当前代码重新聚焦当前仍可能构成重大缺陷的区域：
  - 首页工作台是否仍保留模块捷径兜底。
  - 消息中心是否存在消息跳转与刷新链路回归。
  - 主壳、消息页、生产页、个人中心的轮询是否重复。
  - 回归测试是否仍能为近期改造提供可信保护。
- 已执行真实验证：
  - `flutter analyze` 通过。
  - 目标 widget 测试集中失败 3 项，说明当前前端的主要问题集中在行为回归保障与若干交互断层，而不是语法层面。

## 6. 审查结论

### 6.1 仍应视为重大缺陷的问题

1. **回归保障链已失真，关键前端 smoke 路径当前并非“绿色”状态。**
   - 目标测试集中直接失败 3 项，覆盖主壳、首页与消息中心。
   - 这意味着近期前端改动后的“可回归”能力还没真正闭环，后续继续改页面时很容易把现有行为继续带偏。

2. **首页工作台对后端待办数据过度依赖，导致模块快捷入口在空数据场景下消失。**
   - `HomePage` 只在 `dashboardData == null` 时构造本地快捷入口兜底；一旦后端返回“结构合法但 todoItems 为空”的结果，首页主卡片就只剩空状态，不再保留用户/产品等模块捷径。
   - 这已经被 `main_shell_page_test.dart` 中的失败用例命中，属于真实回归，而不是纯主观评审。

3. **消息中心的跳转交互存在布局/可点击性不稳定，并且刷新链路仍然重复。**
   - 在目标测试里，工艺消息“跳转”按钮出现命中失败，最终保留了上一条产品消息的导航结果。
   - 同时消息中心本身已接入主壳级 WebSocket 刷新信号，却仍保留页面级 30 秒轮询与 `_refreshStats()` 二次拉取，消息页在活跃态下会重复请求。

4. **轮询治理仍未完成，生产页与个人中心继续保留高频定时刷新。**
   - 主壳本身 15 秒拉权限、30 秒拉未读；生产工单页额外 12 秒轮询且单次页大小 200；个人中心再加 30 秒会话刷新。
   - 这些轮询都没有基于页面可见性或路由离场进行统一暂停治理，属于仍会影响线上负载和页面稳定性的结构性缺陷。

### 6.2 不再算“当前最大缺陷”的旧问题

- 会话清空与登录后不落盘这类旧版登录态矛盾，当前代码已不再沿用旧实现，不是本轮最主要问题。
- 前端主题/基础组件体系已经建立，当前更大的问题不在视觉统一，而在行为回归与刷新机制治理。

## 7. 风险、阻塞与代偿

- 当前阻塞：无。
- 已处理风险：通过代码阅读与真实 Flutter 命令交叉确认，避免把历史问题误判为现状问题。
- 残余风险：
  - 本轮没有逐页执行全部 widget 与 integration 测试，因此未覆盖全部业务页。
  - 由于未派发子 agent，执行与验证采用阶段隔离补偿而非物理隔离。
- 代偿措施：
  - 已额外执行与主壳/首页/消息/生产/个人中心强相关的目标测试集。
  - 已在日志中明确记录子 agent 未启用原因及影响范围。

## 8. 交付判断

- 已完成项：
  - 规则读取与任务拆解
  - evidence 起始/收尾留痕
  - 前端关键链路抽查
  - `flutter analyze`
  - 目标 widget 测试执行
  - 重大缺陷排序与证据归纳
- 未完成项：无
- 是否满足任务目标：是
- 当前结论：可交付

## 9. 迁移说明

- 无迁移，直接替换
