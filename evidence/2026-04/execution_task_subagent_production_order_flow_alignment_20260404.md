# 任务日志：生产订单流转定向对齐整改

## 基本信息
- 任务名称：生产订单流转定向对齐整改
- 执行时间：2026-04-04
- 执行角色：执行子 agent
- 目标：按已确认口径完成代班即时生效、查询页动作语义与显隐对齐、结束订单密码确认。

## 拆解与验收
- 步骤1：调整后端代班创建与 review 行为，保持底层状态体系不扩散变更。
- 步骤2：调整前端查询页/详情页动作文案与显隐，代班记录页改为记录查看导向。
- 步骤3：为手工结束订单增加前后端密码确认，并复用现有密码校验。
- 验收标准：
  - 代班创建后直接为可用状态，review 接口返回“无需审批”提示。
  - 查询页与详情页用户可见动作语义改为“开始首件/结束生产”，送修与代班入口受运行态字段控制。
  - 结束订单需输入当前登录用户密码，后端校验失败时拒绝执行。

## 证据记录
- 证据#1：`backend/app/services/assist_authorization_service.py`
  - 结论：代班创建状态改为 `approved`，审批消息链移除，review 统一返回“发起即生效，无需审批”。
- 证据#2：`backend/app/api/v1/endpoints/production.py`、`backend/app/schemas/production.py`
  - 结论：`/orders/{id}/complete` 新增密码请求体并复用 `verify_password` 校验。
- 证据#3：`frontend/lib/pages/production_order_query_page.dart`、`frontend/lib/pages/production_order_query_detail_page.dart`
  - 结论：动作文案改为“开始首件/结束生产”，送修/代班入口新增运行态显隐。
- 证据#4：`frontend/lib/pages/production_assist_approval_page.dart`
  - 结论：页面改为记录查看导向，审批按钮移除，增加“审批已取消”提示。
- 证据#5：定向测试命令输出
  - 结论：后端 production/message 定向测试与前端 service/widget 定向测试通过。

## 风险与补偿
- 未修改底层状态枚举，仅把新建代班直接落到 `approved`，历史 `pending` 记录仍可查询但不再可审批。
- 结束订单密码确认仅加在当前生产订单管理入口；详情页通过同一回调复用，无额外分叉。

## 结果
- 已按口径完成最小正确改动，并补充定向测试。
