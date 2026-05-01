# 任务日志：登录页公告栏真实可用性排查

- 日期：2026-04-22
- 执行人：Codex
- 当前状态：已完成
- 任务分类：CAT-03 Flutter 页面/交互改造

## 1. 输入来源

- 用户指令：现在这个公告栏能正常使用了吗？我需要它能真正的能够使用！
- 需求基线：
  - `AGENTS.md`
  - `docs/AGENTS/10-执行总则.md`
  - `docs/AGENTS/20-指挥官模式与工作流.md`
  - `docs/AGENTS/30-工具治理与验证门禁.md`
  - `docs/AGENTS/40-质量交付与留痕.md`
  - `docs/AGENTS/50-模板与索引.md`
- 代码范围：
  - `frontend/lib/features/misc/presentation/login_page.dart`
  - `frontend/lib/features/message/`
  - `backend/` 中公告与消息相关接口

## 1.1 前置说明

- 默认主线工具：`Sequential Thinking`、`update_plan`、`MCP_DOCKER`、宿主安全命令
- 缺失工具：无
- 缺失/降级原因：无
- 替代工具：无
- 影响范围：无

## 2. 任务目标、范围与非目标

### 任务目标

1. 判断当前登录页公告栏是否真正读取并展示后端公告。
2. 若当前仅为静态占位或链路不完整，补齐到真实可用。
3. 完成前后端与测试闭环验证。

### 任务范围

1. 登录前公告加载链路。
2. 前端公告请求与登录页展示逻辑。
3. 后端公告接口可见性与最小必要补充。

### 非目标

1. 不扩展到公告后台管理能力。
2. 不改动与公告无关的登录流程与页面风格。

## 3. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 规则文档与本轮 `Sequential Thinking` | 2026-04-22 | 已完成任务拆解并明确“真正可用”的验收标准 | Codex |
| E2 | 前端登录页与消息服务代码排查 | 2026-04-22 | 已确认登录页公告原实现仅在 `_session != null` 时可请求，未登录时只能显示静态占位 | Codex |
| E3 | 后端 `messages.py` 与 `publish_announcement()` 排查 | 2026-04-22 | 已确认后端原先没有匿名公告接口，但 `source_code` 持久化了 `range_type`，可安全筛出 `all` 全员公告 | Codex |
| E4 | 红灯测试：`login_page_test.dart` 新增用例 | 2026-04-22 | 已证明原登录页未登录状态下拿不到后端全员公告 | Codex |
| E5 | 最小实现补丁 | 2026-04-22 | 已新增公开公告接口、前端公开公告查询能力、登录页未登录加载与刷新能力 | Codex |
| E6 | `flutter test test/widgets/login_page_test.dart -r expanded` | 2026-04-22 | 登录页组件测试 13 项全部通过 | Codex |
| E7 | `flutter test test/services/message_service_test.dart -r expanded` | 2026-04-22 | 消息服务测试 3 项全部通过，公开公告接口请求头验证通过 | Codex |
| E8 | `python -m pytest backend/tests/test_message_service_unit.py -q` | 2026-04-22 | 后端消息服务单测 15 项全部通过，包含公开公告列表转换逻辑 | Codex |
| E9 | `flutter test integration_test/login_flow_test.dart -d windows --plain-name "登录页未登录时可展示全员公告" -r expanded` | 2026-04-22 | 登录入口集成测试通过，未登录状态可展示全员公告 | Codex |
| E10 | 本地后端实例真实联调：发布全员公告并读取 `/api/v1/messages/public-announcements` | 2026-04-22 | 已用当前工作区代码实际发布并读回全员公告，公共接口返回标题包含本轮验证公告 | Codex |
| E11 | 用户截图 + `backend-web` 容器日志 + `openapi.json` | 2026-04-22 | 已确认用户实际连的 `127.0.0.1:8000` 仍在跑旧镜像，请求 `/api/v1/messages/public-announcements` 时落到旧路由链路并返回 401，导致前端退回静态公告 | Codex |
| E12 | `python start_backend.py rebuild --service backend-web --service backend-worker` 后的 `openapi.json` 与接口抽检 | 2026-04-22 | 已将 Docker 后端重建到当前代码，`/api/v1/messages/public-announcements` 现已出现在 OpenAPI 且返回 200/真实公告列表 | Codex |

## 4. 执行计划

| 序号 | 步骤 | 目标 | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- |
| 1 | 建立 evidence 留痕 | 满足任务开始留痕要求 | 主日志与验证日志已建立 | 已完成 |
| 2 | 排查登录页公告链路 | 明确现状是否真实可用 | 能定位触发时机、请求方式、接口能力 | 已完成 |
| 3 | 以 TDD 修复缺失能力 | 让公告栏在真实链路下可用 | 先有失败测试，再有最小修复 | 已完成 |
| 4 | 验证与收口 | 形成闭环证据 | 测试、联调、evidence 完整 | 已完成 |

## 5. 过程记录

- 已完成规则读取、任务拆解与计划维护。
- 已排查确认当前登录页公告原实现并不真实可用：
  - `frontend/lib/features/misc/presentation/login_page.dart` 中 `_refreshAnnouncements()` 只有在 `_session != null` 时才执行；
  - 登录页 `_session` 仅在登录成功后才赋值，因此未登录状态只能显示静态公告；
  - `frontend/lib/features/message/services/message_service.dart` 原请求强依赖 `Authorization`；
  - `backend/app/api/v1/endpoints/messages.py` 原先也不存在匿名读取公告接口。
- 已确认后端公告发布时将 `range_type` 写入 `Message.source_code`，其中：
  - `all` 可视为登录前安全公开的全员公告；
  - `roles` / `users` 不应在登录前公开展示。
- 已按 TDD 先补失败测试：
  - 前端 widget 测试验证“登录页未登录时会加载后端全员公告”；
  - 后端与服务层补充公开公告行为覆盖。
- 已实施最小修复：
  - 后端新增 `/api/v1/messages/public-announcements`，仅返回 `source_code == "all"` 的有效全员公告；
  - 后端 `MessageItem` schema 补充 `expires_at`；
  - 前端 `MessageService` 新增 `public` 构造与 `getPublicAnnouncements()`；
  - 登录页新增 `publicAnnouncementLoader` 注入点，默认使用公开公告服务；
  - 登录页初始化与刷新账号时都会同步刷新公开公告；
  - 登录页公告头部刷新按钮改为未登录也可使用。
- 已完成验证：
  - `flutter test test/widgets/login_page_test.dart -r expanded`
  - `flutter test test/services/message_service_test.dart -r expanded`
  - `python -m pytest backend/tests/test_message_service_unit.py -q`
  - `flutter test integration_test/login_flow_test.dart -d windows --plain-name "登录页未登录时可展示全员公告" -r expanded`
  - `flutter analyze lib/features/misc/presentation/login_page.dart lib/features/message/services/message_service.dart test/widgets/login_page_test.dart test/services/message_service_test.dart`
  - `flutter analyze integration_test/login_flow_test.dart`
  - 使用本地 `uvicorn` 实例实际调用：
    - `POST /api/v1/messages/announcements`
    - `GET /api/v1/messages/public-announcements?page=1&page_size=5`
    - 真实返回标题包含本轮发布的 `登录页全员公告-20260422222851`
- 用户复测补充排查：
  - 用户截图显示标签为“静态公告”，说明登录页运行时 `_announcementError != null`
  - `docker logs zykj_mes-backend-web-1` 证据显示，登录页实际一直在请求 `GET /api/v1/messages/public-announcements?page=1&page_size=10`，但旧容器连续返回 `401`
  - 旧容器 `http://127.0.0.1:8000/openapi.json` 中缺少 `/api/v1/messages/public-announcements`
  - 由此确认根因不是前端再次回退，而是 `backend-web` 容器仍在运行旧镜像，没有加载本轮后端接口改动
- 已执行运行时修复：
  - `python start_backend.py rebuild --service backend-web --service backend-worker`
  - 重建后 `http://127.0.0.1:8000/openapi.json` 已包含 `/api/v1/messages/public-announcements`
  - 重建后 `GET http://127.0.0.1:8000/api/v1/messages/public-announcements?page=1&page_size=5` 返回 `200`
  - 当前真实返回公告标题包含：
    - `AAA`
    - `登录页全员公告-20260422222851`
    - `AAA`
  - 重建后容器日志已显示登录页请求该接口返回 `200`

## 6. 风险、阻塞与代偿

- 当前阻塞：无。
- 已处理风险：
  - 已避免将角色公告与定向公告暴露给未登录页面，仅公开 `all` 全员公告。
  - 已通过登录页注入式公告加载器解决 widget / integration 测试中的网络可控性问题。
  - 已确认并修复“用户正在使用的 Docker 后端未重建”的运行时偏差。
- 残余风险：
  - 旧数据中若历史全员公告文案不适合登录前公开，仍会被新公开接口读到，需业务自行清理历史公告内容。
  - 当前公开公告列表中的历史标题包含测试数据 `AAA`，若需更换为业务公告，需要由具有公告发布权限的账号发布新的全员公告。
- 代偿措施：
  - 按 CAT-02/CAT-03 同轮收敛前后端与验证，避免只修一端。

## 7. 交付判断

- 已完成项：
  - 规则读取
  - 任务拆解
  - evidence 起始建档
  - 现状核实
  - 前后端最小修复
  - widget / service / integration / 后端单测验证
  - 真实 API 联调验证
  - 用户实际运行的 Docker 后端重建与在线接口抽检
- 未完成项：
  - 无
- 是否满足任务目标：是
- 当前结论：可交付

## 8. 迁移说明

- 无迁移，直接替换
