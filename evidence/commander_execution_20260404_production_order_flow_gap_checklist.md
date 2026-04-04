# 生产订单流转完全复刻差异清单

## 1. 任务信息

- 任务名称：生产订单流转完全复刻差异清单整理
- 执行日期：2026-04-04
- 执行方式：对比结果收敛 + 执行子 agent 整理 + 验证子 agent 复核
- 当前状态：已完成
- 指挥模式：主 agent 拆解调度，子 agent 整理，独立子 agent 验证

## 2. 输入来源

- 既有对比日志：`evidence/commander_execution_20260404_production_order_flow_comparison.md`
- 执行子 agent：`task_id=ses_2a94b4f69ffe6CHKWqO3unh3Fu`
- 验证子 agent：`task_id=ses_2a94b4f56ffeLssEFPgRtdc1MX`

## 3. 最终判断

- 如果目标是“业务可用级复刻”，优先处理 P0 全部项和 P1 中的前两项。
- 如果目标是“完全对齐级复刻”，除上述项外，还要处理 P1 剩余项与 P2 交互/呈现差异。
- 当前项目距离“完全复刻”仍有 8 个可明确落单的差异点，其中 5 个属于必须处理项。

## 4. 逐项差异清单

| 序号 | 优先级 | 差异项 | 当前项目现状 | 参照项目目标形态 | 完全复刻是否必须处理 | 关键证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | P0 | 代班生效机制 | 发起后等待审批，存在审批页与审批接口 | 发起后立即生效，审批流程已取消 | 是 | `frontend/lib/pages/production_order_query_page.dart`、`frontend/lib/pages/production_assist_approval_page.dart`、`backend/app/api/v1/endpoints/production.py`、`src/ui/son_page/production_order_query_page.py`、`src/ui/son_page/production_order_management_page.py` |
| 2 | P0 | 工序/订单状态语义 | 使用 `pending/in_progress/partial/completed` 等更细状态，页面呈现含“部分完成” | 以“待生产/进行中/生产中/生产完成”为主，且影响再次首件与等待下一工序语义 | 是 | `backend/app/core/production_constants.py`、`frontend/lib/models/production_models.dart`、`src/ui/son_page/production_order_query_page.py`、`documents/生产订单流转逻辑需求文档.md` |
| 3 | P0 | 执行动作边界 | 前台主动作更偏“首件 + 报工”，缺少参照项目同语义的“开始生产 -> 结束生产”双动作闭环 | 首件通过后开始生产，再结束生产推进数量与工序 | 是 | `frontend/lib/pages/production_order_query_page.dart`、`backend/app/services/production_execution_service.py`、`src/service/order_service.py`、`src/ui/son_page/production_order_query_page.py` |
| 4 | P0 | 生产查询页按钮显隐门禁 | 后端已返回 `can_apply_assist`、`can_create_manual_repair` 等字段，但前端入口显隐更多按权限，不完全按运行态能力收口 | 只在满足流转条件时露出对应按钮，减少误操作入口 | 是 | `frontend/lib/pages/production_order_query_page.dart`、`frontend/lib/pages/production_order_query_detail_page.dart`、`backend/app/schemas/production.py`、`src/ui/son_page/production_order_query_page.py` |
| 5 | P1 | 管理侧手工结束订单鉴权 | 二次确认后直接完工，无密码校验 | 结束订单前需输入生产管理员密码，并提示强制释放状态 | 是 | `frontend/lib/pages/production_order_management_page.dart`、`backend/app/services/production_order_service.py`、`src/ui/mini_page/complete_order_window.py` |
| 6 | P1 | 流水线/并行模式配置门槛 | 开启并行模式需至少 2 道工序，且后端实例绑定/链路校验更强 | 参照项目入口要求至少选择 1 道工序，整体更接近轻量开关 | 是 | `frontend/lib/pages/production_order_management_page.dart`、`backend/app/services/production_execution_service.py`、`src/ui/mini_page/pipeline_mode_window.py` |
| 7 | P1 | 首件页附加交互 | 已有独立首件页，但未对齐“通知品质”等交互锚点 | 参照项目首件页包含更完整的首件执行配套动作 | 否 | `frontend/lib/pages/production_first_article_page.dart`、`src/ui/mini_page/first_article_window.py` |
| 8 | P2 | 并行实例追踪呈现 | 当前项目新增独立“并行实例追踪”页 | 参照项目未体现同层级独立追踪页，更偏内嵌于管理/查询流程 | 否 | `frontend/lib/pages/production_pipeline_instances_page.dart`、`src/ui/son_page/production_order_management_page.py` |

## 5. 容易遗漏的差异

1. 前端没有充分使用后端返回的运行态能力字段，导致“送修/代班”等入口暴露时机与参照项目不一致。
2. 流水线模式入口最小选择数不一致，容易因为主链路能跑通而被忽略。
3. 参照项目代班链路存在旧审批代码残留，但现行 UI 行为已转为“立即生效”，对比时应以可见业务行为为准。

## 6. 收口建议

### 6.1 业务可用级复刻

优先处理以下 6 项：

1. 代班改为发起即生效。
2. 对齐工序/订单状态语义。
3. 对齐“开始生产 -> 结束生产”动作边界。
4. 用运行态能力字段收口生产查询页按钮显隐。
5. 补上手工结束订单密码鉴权。
6. 放宽并对齐流水线/并行模式入口门槛。

### 6.2 完全对齐级复刻

除上述 6 项外，再处理：

1. 首件页附加交互对齐。
2. 是否保留独立“并行实例追踪”页，或收敛到参照项目的表现方式。

## 7. 迁移说明

- 无迁移，直接替换
