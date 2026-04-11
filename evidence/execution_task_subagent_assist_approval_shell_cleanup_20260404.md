# 执行子任务日志：代班审批残留壳层清理

## 基本信息
- 任务名称：代班审批残留壳层清理
- 执行时间：2026-04-04
- 执行角色：执行子 agent
- 目标：清理失效的代班审批壳层，保留代班记录/详情查看与“发起即生效”行为。

## 约束与假设
- 保持代班主流程为“发起即生效”，不恢复审批流。
- 保留代班记录页、详情查看与消息跳转到详情的能力。
- 不修改生产订单主链、状态体系、并行模式、首件页附加交互。
- 采用最小正确改动，不主动清理历史数据字段。

## 任务拆解
1. 清理后端 review API、请求模型、权限残留与消息待审批同步逻辑。
2. 清理前端 review service 与记录页默认待审批导向，保留详情查看。
3. 更新权限目录/功能映射，确保“查看代班记录”继续可用。
4. 运行后端与前端定向测试验证回归风险。

## 证据记录
- 证据#1
  来源：`backend/app/api/v1/endpoints/production.py`
  结论：存在 `/assist-authorizations/{authorization_id}/review` 路由，仅返回“无需审批”错误，属于失效审批壳层。
- 证据#2
  来源：`backend/app/services/assist_authorization_service.py`
  结论：`list_assist_authorizations` 使用 `production.assist_authorizations.review` 决定是否可查看全部记录，需要改绑到仍然有效的记录查看权限。
- 证据#3
  来源：`backend/app/services/message_service.py`
  结论：存在 `_sync_pending_assist_authorization_messages`，仅用于“代班审批待处理”通知，与现行流程不符。
- 证据#4
  来源：`frontend/lib/services/production_service.dart`
  结论：仍存在 `reviewAssistAuthorization` 客户端调用，应删除。
- 证据#5
  来源：`frontend/lib/pages/production_assist_approval_page.dart`
  结论：页面已是记录查询页，但默认筛选仍指向 `pending`，且内部命名仍保留 `canReview` 语义。

## 实施结果
- 删除后端 `review_assist_authorization` API 路由、请求模型与对应测试壳层。
- 将代班记录“查看全部”判定从审批权限切换为页面查看权限 `page.production_assist_approval.view`。
- 删除消息服务中仅服务于“待审批”的代班同步逻辑，并同步更新消息测试。
- 删除前端 `ProductionService.reviewAssistAuthorization` 及对应测试。
- 将记录页默认状态筛选改为“全部”，保留历史 `pending` 状态显示，但文案改为“待处理（历史）”。
- 将页面入参命名从 `canReview` 改为 `canViewRecords`，降低审批语义残留。
- 将 `feature.production.assist.records.view` 的动作权限从 `list + review` 收口为仅 `list`。

## 验证记录
- 后端：`python -m pytest tests/test_production_module_integration.py -k assist_authorization`
  结果：通过（1 passed）
- 后端：`python -m pytest tests/test_message_service_unit.py tests/test_message_module_integration.py`
  结果：通过（22 passed）
- 前端：`flutter test test/services/production_service_test.dart test/widgets/production_assist_approval_page_test.dart`
  结果：通过（All tests passed）

## 风险与补偿
- 风险：历史表结构中的 `reviewer/reviewed_at/review_remark` 字段仍保留，当前仅作为历史记录展示字段，不再承担审批入口。
- 补偿：本次未做迁移删除，避免影响历史数据与详情页展示；若后续确认无需展示，可单独发起数据模型瘦身任务。

## 最终结论
- 代班审批残留壳层已按最小边界清理完成。
- 代班记录查询、详情查看与发起即生效行为保持不变。
- 本次未发现需要继续阻塞交付的硬问题。
