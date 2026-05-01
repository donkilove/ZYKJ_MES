# 消息模块二轮收敛执行日志

## 1. 任务信息

- 任务名称：消息模块二轮收敛
- 执行日期：2026-03-23
- 执行方式：执行子 agent 直接改码 + 定向验证
- 当前状态：已完成
- 指挥模式：主 agent 拆解调度，当前为执行子 agent 落地实现

## 2. 输入来源

- 用户指令：继续按指挥官模式处理“消息模块二轮收敛”，直接修改代码并运行针对性验证，不提交 git
- 复审剩余问题：同步入口首次投递依赖事件循环、失败重试未接入生产调度、维护链路仍为懒执行、失败闭环未真正进入生产消费
- 参考基线：`evidence/commander_execution_20260322_message_batch1_rectification.md`

## 3. 书面拆解

1. 保留既有消息分页、去重、公告选人与跳转链路，不覆盖已有整改。
2. 让同步业务入口在无事件循环时也执行首次投递，并把失败记录落到既有失败字段。
3. 增加生产可执行的消息维护循环，统一处理待补偿首次投递、失败重试、来源失效同步与过期归档。
4. 增加显式维护接口与前端触发入口，避免维护链路只存在于测试函数。
5. 跑后端 unittest/compileall、前端消息服务与页面测试、必要的 analyze，并记录环境限制。

## 4. 实际改动

- 后端配置与生命周期：`backend/app/core/config.py`、`backend/app/main.py`
- 后端服务与接口：`backend/app/services/message_service.py`、`backend/app/schemas/message.py`、`backend/app/api/v1/endpoints/messages.py`
- 后端测试：`backend/tests/test_message_service_unit.py`、`backend/tests/test_message_module_integration.py`
- 前端模型、服务、页面：`frontend/lib/models/message_models.dart`、`frontend/lib/services/message_service.dart`、`frontend/lib/pages/message_center_page.dart`
- 前端测试：`frontend/test/services/message_service_test.dart`、`frontend/test/widgets/message_center_page_test.dart`
- 联动修复：`frontend/lib/pages/product_parameter_management_page.dart`、`frontend/lib/pages/product_parameter_query_page.dart`

## 5. 关键实现结论

1. `create_message` 提交事务后，若当前同步入口无线程事件循环，会直接 `asyncio.run(...)` 执行首次投递；失败仍只影响消息投递，不回滚业务提交。
2. 新增 `compensate_pending_message_deliveries`，把长期停留在 `pending` 且未发生首次推送的记录拉入补偿链。
3. 新增 `run_message_delivery_maintenance_once` 与 `run_message_delivery_maintenance_loop`，生产启动后周期处理待补偿首次投递、失败重试、来源失效同步与历史归档。
4. 新增 `/api/v1/messages/maintenance/run` 显式维护入口，并在消息页增加“执行维护”按钮，便于人工触发与验证闭环。
5. 前端新增 `MessageMaintenanceResult` 与 `MessageService.runMaintenance()`，消息页在执行维护后展示补偿/重试/失效同步/归档结果。

## 6. 验证记录

| 命令 | 结果 | 说明 |
| --- | --- | --- |
| `".venv\Scripts\python.exe" -m unittest backend.tests.test_message_service_unit backend.tests.test_message_module_integration.MessageModuleIntegrationTest.test_message_maintenance_endpoint_runs_delivery_closure` | 通过 | 7 个后端消息单测/定向接口用例通过 |
| `".venv\Scripts\python.exe" -m compileall backend/app backend/tests backend/alembic` | 通过 | 后端应用、测试、迁移静态编译通过 |
| `flutter test test/services/message_service_test.dart test/widgets/message_center_page_test.dart` | 通过 | 4 个前端消息服务/页面测试通过 |
| `flutter analyze lib/models/message_models.dart lib/services/message_service.dart lib/pages/message_center_page.dart lib/pages/product_parameter_management_page.dart lib/pages/product_parameter_query_page.dart test/services/message_service_test.dart test/widgets/message_center_page_test.dart` | 通过 | 前端消息相关与联动修复静态检查通过 |

## 7. 已知限制

- 当前测试库仍未应用既有消息迁移，因此消息模块旧集成用例全量执行会因 `msg_message_recipient.last_failure_reason` 等列缺失而失败；本轮按用户最低验证要求改为消息服务单测 + 定向接口用例 + `compileall`，未执行 `alembic upgrade head`。
- 本轮无新增迁移脚本；依赖的一轮消息迁移仍需在真实环境保持已升级状态。

## 8. 终轮补充收敛

- 修复消息页“全部消息”统计口径，改为使用摘要接口返回的全量总数，不再复用当前筛选列表总数。
- 增加 `message.messages.detail` / `message.messages.jump` 及对应 capability，前端消息页同步按“消息详情查看 / 来源跳转”拆分行为。
- 新增消息详情与跳转目标接口，前端展示投递状态、投递次数、最近投递、下次重试与公开化失败提示，满足排障但不直接暴露底层异常原文。
- 消息维护执行、来源失效、归档变化新增审计；维护按钮执行后写入 `message.maintenance.run` 审计。
- 补充用户停用、强制下线、生产订单创建/更新/并行模式更新/删除/手工完工等来源事件的消息生成覆盖。
- 终轮验证补充：`".venv\Scripts\python.exe" -m unittest backend.tests.test_message_service_unit`、`flutter test test/services/message_service_test.dart test/widgets/message_center_page_test.dart`、`flutter analyze ...`、`".venv\Scripts\python.exe" -m compileall backend/app backend/tests backend/alembic` 均通过。

## 9. 本轮执行子 agent 收口补记

- 时间：2026-03-23
- 目标：关闭最新复审残留点，继续收口消息统计语义、来源注册表与关键待处理来源事件。
- 书面拆解：
  1. 先补齐消息来源注册表，确保维护/失效/归档审计覆盖当前已投产来源类型。
  2. 修正摘要统计卡片口径，把“待处理 / 高优先级”从“未读语义”收敛为“当前有效消息语义”。
  3. 对注册审批待处理、代班审批待处理补即时消息，对首件不通过、工单逾期补维护期兜底消息。
  4. 运行消息相关后端 unittest + compileall、前端 test + analyze，记录结果与剩余风险。

## 10. 消息模块终收尾补记

- 时间：2026-03-23
- 目标：关闭静态终审对消息中心主列表的残留阻断，补齐状态、已读时间、明确详情入口，并让行内“跳转 / 已读 / 详情”动作并存且文案清晰。
- 书面拆解：
  1. 复核当前消息契约，确认后端已返回 `status`、`read_at` 等字段，本轮优先收口前端列表承载与展示结构，不回退既有统计、权限、维护、来源覆盖整改。
  2. 在消息模型补齐统一状态文案，避免页面各处重复散落判断。
  3. 重构消息主列表单行结构，显式展示消息状态、阅读状态、已读时间/未读态，并增加明确的“详情”入口。
  4. 调整列表点击语义为“选中并加载预览”，把“详情 / 已读 / 跳转”保留为并行动作，避免行点击吞掉终审要求的显式操作入口。
  5. 运行最低验证：后端消息单测、`compileall`、前端消息页 widget test、`analyze`。
- 实际改动：
  - `frontend/lib/models/message_models.dart`：新增消息状态中文映射与阅读状态文案。
  - `frontend/lib/pages/message_center_page.dart`：重构消息列表元信息与操作区，补齐状态、阅读时间、详情入口；详情预览/弹窗统一显示“消息状态 + 阅读状态”。
  - `frontend/test/widgets/message_center_page_test.dart`：补充主列表状态/详情/阅读时间断言，并同步 fake service 的 `read_at` 行为。
- 验证记录：
  - `python -m unittest backend.tests.test_message_service_unit`：通过，`Ran 10 tests ... OK`。
  - `python -m compileall backend/app`：通过。
  - `flutter test test/widgets/message_center_page_test.dart`：通过，`2 tests passed`。
  - `flutter analyze lib/models/message_models.dart lib/pages/message_center_page.dart test/widgets/message_center_page_test.dart`：通过，`No issues found!`。
- 剩余风险：
  - 本轮未新增后端字段，也未扩展真实环境联调；列表承载问题已在前端收口，但若终审后续把“详情入口必须免权限显示为只读态”定义得更严，还需再和权限设计稿核一次。
