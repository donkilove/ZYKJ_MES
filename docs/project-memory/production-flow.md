# 核心生产执行流程

> 基于源码验证，最后更新：2026-05-01

## 1. 流程概览

```
创建工单 → 工单下发 → 首件检验 → 工序报工(含缺陷记录) → 下工序可见量释放 →
缺陷维修(自动/手动) → 维修完工(含报废/回流) → 工单完工 → 统计汇总
```

## 2. 状态常量总览

所有状态常量定义在 `backend/app/core/production_constants.py`：

| 层级 | 状态 | 中文 | 说明 |
|---|---|---|---|
| **工单** (Order) | `pending` | 待生产 | 初始状态 |
| | `in_progress` | 生产中 | 首件通过后进入 |
| | `completed` | 生产完成 | 手工完工或自然完工 |
| **工序** (Process) | `pending` | 待生产 | 下工序初始状态 |
| | `in_progress` | 进行中 | 该工序首件通过后 |
| | `partial` | 部分完成 | 报工后完成量 < 订单量 |
| | `completed` | 生产完成 | 该工序全部完成 |
| **子工单** (SubOrder) | `pending` | 待执行 | 操作员该工序初始状态 |
| | `in_progress` | 执行中 | 首件通过后 |
| | `done` | 已完成 | 该操作员该工序完成 |
| **维修工单** (RepairOrder) | `in_repair` | 维修中 | 缺陷产生时创建 |
| | `completed` | 已完成 | 维修完工 |
| **生产记录** (Record) | `first_article` | 首件 | 首件检验记录 |
| | `production` | 生产 | 批量报工记录 |

## 3. 各步骤详细说明

### 步骤 1: 创建工单

- **涉及 Model**: `ProductionOrder` (表名 `mes_order`), `Product`, `Supplier`, `ProcessStage`, `Process`
- **涉及 Service**: `production_order_service.create_order()`
- **API**: `POST /api/v1/production/orders`
- **权限**: `PERM_PROD_ORDERS_CREATE`
- **关键逻辑**:
  1. 校验订单编号唯一性 (`get_order_by_code`)
  2. 校验产品存在且处于活跃态 (`lifecycle_status == 'active'`)
  3. 根据 `process_codes` / `template_id` / `process_steps` 解析工艺路线 (`_resolve_route_steps`)
  4. 创建 `ProductionOrder`，状态初始为 `pending`，`current_process_code` 设为第一个工序
  5. 创建 `ProductionOrderProcess` 行（每工序一条），同时创建初始 `ProductionSubOrder` 分配给操作员
  6. 支持保存工艺路线为模板 (`_save_route_as_template` → `ProductProcessTemplate`)
  7. 记录工单事件日志 `OrderEventLog` (event_type: `order_created`)
  8. 发送消息通知给生产管理员和系统管理员

- **重要校验**:
  - `order_code` 必须唯一
  - `quantity > 0`
  - 产品必须存在且处于 active 状态
  - 供应商必须启用

### 步骤 2: 工单列表与详情

- **API**:
  - `GET /api/v1/production/orders` — 工单列表（支持关键词/状态/产品名/管道模式/日期范围筛选）
  - `GET /api/v1/production/orders/{order_id}` — 工单详情（含工序列表、子工单、生产记录、事件日志）
- **权限**: `PERM_PROD_ORDERS_LIST`, `PERM_PROD_ORDERS_DETAIL`
- **访问控制**: `can_user_access_order_detail()` — 校验当前用户是否在该工单的任一子工单中

### 步骤 3: 工单更新/删除

- **API**:
  - `PUT /api/v1/production/orders/{order_id}` — 更新工单
  - `DELETE /api/v1/production/orders/{order_id}` — 删除工单（仅 `pending` 状态可删）
- **注意**: 工单更新若涉及工艺路线变更且已有生产记录，将拒绝修改工序

### 步骤 4: 管道模式 (Pipeline Mode)

- **涉及 Model**: `ProcessPipelineInstance` (表名 `mes_process_pipeline_instance`)
- **API**:
  - `GET /api/v1/production/orders/{order_id}/pipeline-mode` — 查看管道模式
  - `PUT /api/v1/production/orders/{order_id}/pipeline-mode` — 开启/关闭管道模式
  - `GET /api/v1/production/pipeline-instances` — 管道实例列表
- **说明**: 管道模式允许并行工序之间通过 `pipeline_link_id` 关联，支持并行工序流水线执行。
  - 当工序间存在 parallel edge 时，下工序可见量按并行规则释放
  - 管道实例记录每个子工单在每个工序的管道序号和执行状态

### 步骤 5: 首件检验 (First Article)

- **涉及 Model**: `FirstArticleRecord` (表名 `mes_first_article_record`), `FirstArticleReviewSession`, `FirstArticleParticipant`, `FirstArticleTemplate`, `FirstArticleDisposition`
- **API**:
  - `POST /api/v1/production/orders/{order_id}/first-article` — 提交首件检验
  - `GET /api/v1/production/orders/{order_id}/first-article/templates` — 获取首件检验模板
  - `GET /api/v1/production/orders/{order_id}/first-article/participant-users` — 可选参与人员
  - `GET /api/v1/production/orders/{order_id}/first-article/parameters` — 获取产品参数
  - `POST /api/v1/production/orders/{order_id}/first-article/review-sessions` — 创建扫码复核会话
  - `GET /api/v1/production/orders/{order_id}/first-article/review-sessions/{session_id}/status` — 查询复核状态
  - `POST /api/v1/production/orders/{order_id}/first-article/review-sessions/{session_id}/refresh` — 刷新复核会话
  - `GET /api/v1/production/first-article/review-sessions/detail` — 查看复核详情
  - `POST /api/v1/production/first-article/review-sessions/submit` — 提交复核结果
- **权限**: `PERM_PROD_EXECUTION_FIRST_ARTICLE`, `PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW`
- **关键逻辑** (`submit_first_article`):
  1. 锁定工单和工序（`_lock_order_and_process` → `SELECT ... FOR UPDATE`）
  2. 校验工单未完成、工序状态允许（`pending`/`in_progress`/`partial`）
  3. 跨用户操作需代授授权（`ProductionAssistAuthorization`）
  4. 锁定子工单：子工单必须为 `pending`
  5. 管道模式下的门控校验（`_ensure_pipeline_sequence_gate`）
  6. 校验可生产数量（`_is_start_gate_allowed`）
  7. 校验验证码（当日验证码 `DailyVerificationCode`）
  8. 创建 `FirstArticleRecord`，关联参与人员
  9. 若首件通过 (`passed`)：工序状态 → `in_progress`，子工单 → `in_progress`，工单 → `in_progress`；同时创建 `ProductionRecord`（`record_type='first_article'`，`production_quantity=0`）
  10. 记录事件日志 (`first_article_passed` / `first_article_failed`)
  11. 消费代授授权（如使用）

### 步骤 6: 工序报工 (End Production)

- **涉及 Model**: `ProductionRecord` (表名 `mes_production_record`), `ProductionScrapStatistics`
- **API**: `POST /api/v1/production/orders/{order_id}/end-production`
- **权限**: `PERM_PROD_EXECUTION_END_PRODUCTION`
- **关键逻辑** (`end_production`):
  1. 锁定工单、工序、子工单
  2. 校验工单未完成、工序在 `in_progress`/`partial` 状态、子工单在 `in_progress` 状态
  3. 管道模式门控校验
  4. 计算最大可生产量（`visible_quantity - completed_quantity - in_progress_count + 1`）
  5. 更新工序完成量：`completed_quantity += quantity`
  6. 工序状态：`completed`（全部完成）或 `partial`（部分完成）
  7. 子工单状态归 `pending`（允许下次继续报工）
  8. **下工序可见量释放**：当前工序完成量释放到下一道工序的 `visible_quantity`（非管道模式）或按并行边规则释放
  9. 创建 `ProductionRecord`（`record_type='production'`）
  10. **缺陷处理**：若报工同时传入 `defect_items`，自动创建 `RepairOrder`（`create_repair_order(auto_created=True)`）
  11. 刷新工单状态（`_refresh_order_status`）
  12. 记录报工事件日志

### 步骤 7: 缺陷与维修

- **涉及 Model**: `RepairOrder` (表名 `mes_repair_order`), `RepairDefectPhenomenon`, `RepairCause`, `RepairReturnRoute`
- **API**:
  - `GET /api/v1/production/repair-orders` — 维修工单列表
  - `POST /api/v1/production/orders/{order_id}/repair-orders` — 手动创建维修工单
  - `POST /api/v1/production/repair-orders/{repair_order_id}/complete` — 维修完工
  - `GET /api/v1/production/repair-orders/{repair_order_id}/phenomena-summary` — 缺陷现象汇总
  - `GET /api/v1/production/repair-orders/{repair_order_id}/detail` — 维修详情
  - `POST /api/v1/production/repair-orders/export` — 导出
- **权限**: `PERM_PROD_REPAIR_ORDERS_LIST`, `PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL`, `PERM_PROD_REPAIR_ORDERS_COMPLETE` 等
- **维修工单结构**:
  - `repair_quantity`: 待维修数量（缺陷总和）
  - `repaired_quantity`: 已修复数量
  - `scrap_quantity`: 报废数量
  - `scrap_replenished`: 报废是否已补数
  - 关联多个 `RepairDefectPhenomenon`（缺陷现象）、`RepairCause`（维修原因）、`RepairReturnRoute`（回流路由）

- **维修完工逻辑** (`complete_repair_order`):
  1. 记录维修原因 (cause_items)
  2. 统计报废数量 → 写入 `ProductionScrapStatistics`
  3. 处理回流路由 (`RepairReturnRoute`)：指定回流目标工序
  4. 若 `scrap_replenished=True`，创建报废补数记录
  5. 触发工单状态重新计算

### 步骤 8: 报废统计

- **涉及 Model**: `ProductionScrapStatistics` (表名 `mes_production_scrap_statistics`)
- **API**:
  - `GET /api/v1/production/scrap-statistics` — 报废统计列表
  - `GET /api/v1/production/scrap-statistics/{scrap_id}` — 报废详情（含关联维修记录、事件日志）
- **权限**: `PERM_PROD_SCRAP_STATISTICS_LIST`, `PERM_PROD_SCRAP_STATISTICS_DETAIL`
- **状态**: `pending_apply`（待处理）/ `applied`（已处理）

### 步骤 9: 代授授权

- **涉及 Model**: `ProductionAssistAuthorization` (表名 `mes_production_assist_authorization`)
- **API**:
  - `POST /api/v1/production/orders/{order_id}/assist-authorizations` — 创建代授授权
  - `DELETE /api/v1/production/orders/{order_id}/assist-authorizations/{authorization_id}` — 撤销
  - `GET /api/v1/production/assist-authorizations` — 列表
  - `GET /api/v1/production/assist-user-options` — 可选代授人
- **用途**: 允许操作员A代替操作员B执行首件检验或报工操作
- **代授操作类型**: `first_article`（首件检验）、`end_production`（结束生产/报工）

### 步骤 10: 工单完工

- **API**: `POST /api/v1/production/orders/{order_id}/complete`
- **权限**: `PERM_PROD_ORDERS_COMPLETE`
- **关键逻辑** (`complete_order_manually`):
  1. 校验登录密码
  2. 检查是否有未完工的维修工单（`in_repair` 状态），如有则拒绝完工
  3. 将全部工序设置为 `completed`，`completed_quantity` 设为订单数量
  4. 将所有子工单设置为 `done`
  5. 工单状态 → `completed`
  6. 级联关闭：取消待处理的首件复核会话、消费未使用的代授授权、作废激活的管道实例
  7. 记录完工事件日志

### 步骤 11: 统计汇总

- **API**:
  - `GET /api/v1/production/stats/overview` — 概览统计
    - `total_orders`, `pending_orders`, `in_progress_orders`, `completed_orders`
    - `total_quantity`, `finished_quantity`（最后工序完成量）
  - `GET /api/v1/production/stats/processes` — 按工序统计
  - `GET /api/v1/production/stats/operators` — 按操作员统计（基于 `ProductionRecord`）
  - `GET /api/v1/production/data/today-realtime` — 今日实时数据
  - `GET /api/v1/production/data/unfinished-progress` — 未完工进度
  - `GET /api/v1/production/data/manual` — 手动数据报表

### 步骤 12: 我的工单 (操作员视角)

- **API**:
  - `GET /api/v1/production/my-orders` — 我的工单列表
  - `GET /api/v1/production/my-orders/{order_id}/context` — 工单上下文
  - `POST /api/v1/production/my-orders/export` — 导出
- **权限**: `PERM_PROD_MY_ORDERS_LIST`, `PERM_PROD_MY_ORDERS_CONTEXT`, `PERM_PROD_MY_ORDERS_EXPORT`
- **支持**: 代理模式 (`proxy_operator_user_id`) 查看他人工单，按工序筛选 (`current_process_id`)

## 4. 数据模型关系

```
Product ──1:N──> ProductionOrder (mes_order)
                     │
                     ├──1:N──> ProductionOrderProcess (mes_order_process)
                     │            │
                     │            ├──1:N──> ProductionSubOrder (mes_order_sub_order)
                     │            │            │
                     │            │            └──1:N──> ProcessPipelineInstance (mes_process_pipeline_instance)
                     │            │
                     │            ├──1:N──> FirstArticleRecord (mes_first_article_record)
                     │            │            │
                     │            │            ├──1:N──> FirstArticleParticipant (mes_first_article_participant)
                     │            │            ├──1:1──> FirstArticleDisposition (mes_first_article_disposition)
                     │            │            └──1:N──> FirstArticleReviewSession (mes_first_article_review_session)
                     │            │
                     │            └──1:N──> ProductionRecord (mes_production_record)
                     │
                     ├──1:N──> RepairOrder (mes_repair_order)
                     │            ├──1:N──> RepairDefectPhenomenon
                     │            ├──1:N──> RepairCause
                     │            └──1:N──> RepairReturnRoute
                     │
                     ├──1:N──> ProductionAssistAuthorization (mes_production_assist_authorization)
                     ├──1:N──> ProductionScrapStatistics (mes_production_scrap_statistics)
                     └──1:N──> OrderEventLog (mes_order_event_log)

Supplier ──1:N──> ProductionOrder
ProcessStage ──1:N──> ProductionOrderProcess
Process ──1:N──> ProductionOrderProcess
FirstArticleTemplate ──N:1──> Product
User ──1:N──> (operator/creator/reviewer/receiver/sender on multiple tables)
```

## 5. 关键 Service 方法

### production_order_service.py (2473 行)
| 方法 | 说明 |
|---|---|
| `create_order()` | 创建工单：校验唯一性、解析工艺路线、创建工序行/子工单、写日志 |
| `update_order()` | 更新工单：支持修改数量/工艺路线（无生产历史时） |
| `delete_order()` | 删除工单（仅 `pending` 状态） |
| `list_orders()` | 工单列表查询（含多条件筛选和分页） |
| `get_order_by_id()` | 获取单个工单（可选预加载关系） |
| `get_order_by_code()` | 按工单编号查询 |
| `complete_order_manually()` | 手工完工：关闭全部工序/子工单，级联关闭关联资源 |
| `_cascade_close_order_relations()` | 级联关闭：取消复核会话、消费代授授权、作废管道实例 |
| `list_my_orders()` | 操作员视角工单列表 |
| `get_my_order_context()` | 操作员工单上下文 |
| `export_orders_csv()` / `export_my_orders_csv()` | 导出工单为 CSV |
| `update_order_pipeline_mode()` | 管道模式开关 |
| `list_pipeline_instances()` | 管道实例列表 |
| `ensure_sub_orders_visible_quantity()` | 同步子工单可见量 |
| `allocate_pipeline_instance_for_process()` | 分配管道实例 |
| `_create_initial_sub_orders_for_process()` | 为工序创建初始子工单 |
| `_recalculate_order_current_process()` | 重算工单当前工序 |
| `can_user_access_order_detail()` | 访问控制 |
| `is_pipeline_parallel_edge_for_processes()` | 并行边判断 |
| `_refresh_order_status()` | 刷新工单状态（delegated from execution service） |

### production_execution_service.py (977 行)
| 方法 | 说明 |
|---|---|
| `submit_first_article()` | 提交首件检验：锁定行、门控校验、验证码校验、创建首件记录、状态转移、创建首件生产记录 |
| `end_production()` | 工序报工：更新完成量、下工序放行、创建 ProductionRecord、自动创建维修工单（如有缺陷）、刷新工单状态 |
| `_lock_order_and_process()` | SELECT ... FOR UPDATE 锁定工单和工序 |
| `_lock_sub_order()` | 锁定或创建操作员子工单 |
| `_get_required_pipeline_instance()` | 获取请求的管道实例 |
| `_resolve_pipeline_instance_for_first_article()` | 首件管道实例解析 |
| `_ensure_pipeline_sequence_gate()` | 管道序列门控 |
| `_is_start_gate_allowed()` / `_is_end_gate_allowed()` | 管道启停门控 |
| `_refresh_order_status()` | 根据工序完成情况刷新工单状态 |

### production_repair_service.py (1033 行)
| 方法 | 说明 |
|---|---|
| `create_repair_order()` | 创建维修工单（自动 or 手动）：校验数量、生成维修单号、关联缺陷现象到生产记录 |
| `complete_repair_order()` | 维修完工：记录原因、处理报废、回流路由、补数逻辑 |
| `list_repair_orders()` | 维修工单列表 |
| `get_repair_order_by_id()` | 单个维修工单详情 |
| `get_repair_order_phenomena_summary()` | 缺陷现象汇总 |
| `create_manual_repair_order()` | 手动创建维修工单 |
| `list_scrap_statistics()` | 报废统计列表 |
| `export_repair_orders_csv()` / `export_scrap_statistics_csv()` | 导出 |

### production_event_log_service.py (108 行)
| 方法 | 说明 |
|---|---|
| `add_order_event_log()` | 添加工单事件日志（含快照） |
| `list_order_event_logs()` | 工单事件日志列表 |
| `search_order_event_logs_by_code()` | 按工单编号搜索事件 |

### production_statistics_service.py (164 行)
| 方法 | 说明 |
|---|---|
| `get_overview_stats()` | 概览统计（总量/待产/生产中/完成量和数量） |
| `get_process_stats()` | 按工序分组统计 |
| `get_operator_stats()` | 按操作员×工序统计产值 |

### production_data_query_service.py (838 行)
| 方法 | 说明 |
|---|---|
| `get_today_realtime_data()` | 今日实时生产数据 |
| `get_unfinished_progress_data()` | 未完工进度 |
| `get_manual_production_data()` | 自定义时间段数据 |
| `build_today_filters()` / `build_manual_filters()` | 构建查询过滤器 |
| `export_manual_production_data_csv()` | 导出 CSV |

## 6. 事件日志 (OrderEventLog)

每个关键操作都会写入 `OrderEventLog`（表名 `mes_order_event_log`），记录：
- 工单编号快照 (`order_code_snapshot`)
- 工单状态快照 (`order_status_snapshot`)
- 产品名称快照 (`product_name_snapshot`)
- 工序编码快照 (`process_code_snapshot`)
- 事件类型 (`event_type`): `order_created` / `first_article_passed` / `first_article_failed` / `production_reported` / `defect_repair_order_created` / `repair_order_created_manual` / `repair_order_completed` / `order_completed_manual` / `order_deleted` / `process_visible_quantity_released` 等

## 7. 并发控制

- 工单和工序：`SELECT ... FOR UPDATE` 悲观锁 (`_lock_order_and_process`)
- 子工单：`SELECT ... FOR UPDATE` (`_lock_sub_order`)
- 下工序可见量：`with_for_update()` 锁定
- 可生产量并发校验：比较 `quantity + defect_quantity` 与最大可生产量

## 8. 确认项

| 项目 | 数量/状态 |
|---|---|
| Production Service 文件 | 6 个（无 `production_service.py`，功能已拆分） |
| Production Model 文件 | 6 个 |
| First Article Model 文件 | 6 个 |
| Repair Model 文件 | 4 个 |
| 工单相关 Model | `ProductionOrder` (mes_order)，无独立 `order.py` |
| Production API 端点 | 约 28 个（含工单 CRUD、管道模式、首件检验、报工、维修、报废、统计、数据查询、代授授权、管道实例） |
