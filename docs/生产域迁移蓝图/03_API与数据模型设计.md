# API 与数据模型设计（规划版）

## 1. 设计原则
- 新能力统一放在 `/api/v1/production/...`。
- 不破坏现有 V1 接口字段语义，采用“新增接口 + 扩展返回字段”策略。
- 每批独立迁移，模型与接口按批次落地。

## 2. A 批接口与模型（子订单分配 + 代班审批）
### 2.1 新增接口
- `GET /api/v1/production/assist-authorizations`
- `POST /api/v1/production/orders/{order_id}/assist-authorizations`
- `POST /api/v1/production/assist-authorizations/{id}/review`
- 扩展 `GET /api/v1/production/my-orders`（增加代理参数与授权态字段）

### 2.2 权限建议
- 列表查询：系统管理员、生产管理员可查全部；操作员可查与自己相关记录。
- 申请代班：系统管理员、生产管理员、操作员可发起（受订单/工序状态限制）。
- 审批：系统管理员、生产管理员。

### 2.3 请求与响应要点
- 申请请求包含：`order_id`、`process_code`、`target_role_code`、`helper_user_id`、`reason`。
- 审批请求包含：`approve`、`remark`。
- my-orders 新增可选参数：`proxy_role_code`、`proxy_operator_username`。
- my-orders 响应新增：`is_authorized`、`authorization_id`、`proxy_mode`、`target_role_code`。

### 2.4 新增数据表（建议）
- `production_assist_authorization`
  - 核心字段：`id`、`order_id`、`process_code`、`requester_user_id`、`helper_user_id`、`target_role_code`、`status`、`reason`、`reviewer_user_id`、`reviewed_at`、`created_at`、`updated_at`
  - 索引：`status`、`helper_user_id`、`(order_id, process_code)`

## 3. B 批接口与模型（并行生产）
### 3.1 新增接口
- `GET /api/v1/production/orders/{order_id}/pipeline-mode`
- `PUT /api/v1/production/orders/{order_id}/pipeline-mode`
- 扩展 `GET /api/v1/production/my-orders` 返回并行动作态

### 3.2 权限建议
- 查询：系统管理员、生产管理员、操作员（受可见性约束）。
- 配置更新：系统管理员、生产管理员。

### 3.3 请求与响应要点
- 更新请求包含：`enabled`、`pipeline_process_codes`（可选）。
- 查询响应包含：`enabled`、`pipeline_process_codes`、`updated_by`、`updated_at`。
- my-orders 响应新增：`pipeline_enabled`、`pipeline_start_allowed`、`pipeline_end_allowed`。

### 3.4 数据结构建议
- 扩展 `production_order`：
  - `pipeline_enabled`（bool）
  - `pipeline_process_codes`（json/text）
- 新增 `production_sub_order_pipeline_instance`：
  - `id`、`sub_order_id`、`order_id`、`process_code`、`pipeline_seq`、`instance_code`、`is_active`、`created_at`、`updated_at`
  - 唯一约束：`(sub_order_id, pipeline_seq)`、`instance_code`

## 4. C 批接口与模型（生产数据增强）
### 4.1 新增接口
- `GET /api/v1/production/data/today-realtime`
- `GET /api/v1/production/data/unfinished-progress`
- `GET /api/v1/production/data/manual`
- `POST /api/v1/production/data/manual/export`

### 4.2 权限建议
- 查询：系统管理员、生产管理员、质量管理员（按现有统计权限口径）。
- 导出：系统管理员、生产管理员。

### 4.3 请求与响应要点
- manual 查询参数：日期范围、产品、工段、工序、操作员、状态。
- 三类查询统一返回：
  - `summary`
  - `table_rows`
  - `chart_data`
  - `query_signature`
- 导出响应返回：`file_name`、`download_token` 或 `export_path`（按现网规范定稿）。

## 5. D 批接口与模型（报废统计 + 维修闭环）
### 5.1 新增接口
- `GET /api/v1/production/scrap-statistics`
- `POST /api/v1/production/scrap-statistics/export`
- `GET /api/v1/production/repair-orders`
- `GET /api/v1/production/repair-orders/{id}/phenomena-summary`
- `POST /api/v1/production/repair-orders/{id}/complete`
- `POST /api/v1/production/repair-orders/export`

### 5.2 权限建议
- 报废统计查询/导出：系统管理员、生产管理员、质量管理员（查询）/系统管理员与生产管理员（导出）。
- 维修完成：系统管理员、生产管理员。

### 5.3 请求与响应要点
- 维修完成请求包含：
  - `scrap_quantity`
  - `cause_items`（现象/原因/数量）
  - `return_allocations`（目标工序/回流数量）
- 校验规则：
  - `scrap_quantity + sum(return_allocations.quantity) == repair_quantity`
  - 回流目标工序必须在可选链路内
  - 数量均为正整数且不超范围

### 5.4 新增数据表（建议）
- `production_scrap_record`
- `production_repair_order`
- `production_repair_cause_item`
- `production_repair_return_route`

## 6. 事件日志约束（全批共用）
- A/B/C/D 所有关键动作写入 `order_event_log`：
  - 代班申请/审批
  - 并行模式启停与并行实例变化
  - 统计导出触发
  - 维修完成与回流结果
- 日志字段保持统一：`event_type`、`event_title`、`event_detail`、`payload_json`。

## 7. 迁移版本规划
- `alembic` 迁移拆分 4 个版本：
  - `A_assist_authorization`
  - `B_pipeline_mode`
  - `C_production_data_extension`（若无结构变更可省略）
  - `D_scrap_repair`
- 每个版本只包含当批结构变更，禁止跨批混入。
