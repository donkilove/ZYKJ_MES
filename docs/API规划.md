# MES API 规划（v1）

## 1. 基础约定

- Base URL：`/api/v1`
- 认证方式：`Authorization: Bearer <token>`
- 统一响应结构：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

## 2. 认证接口（Sprint 1 已实现）

- `POST /auth/login`：登录
- `POST /auth/register`：注册账号（用户名与姓名使用同一账号字段）
- `GET /auth/me`：当前登录用户信息（含角色、工序、权限）

## 3. 角色与权限（Sprint 1 已实现）

### 3.1 固定角色

- `system_admin`：系统管理员角色
- `production_admin`：生产管理员角色
- `quality_admin`：品质管理员角色
- `operator`：操作员角色

### 3.2 角色接口

- `GET /roles`：角色分页查询
- `GET /roles/{id}`：角色详情查询

### 3.3 权限接口

- `GET /permissions`：权限列表查询

## 4. 工序接口（Sprint 1 已实现）

- `GET /processes`：工序分页查询
- `POST /processes`：创建工序
- `PUT /processes/{id}`：更新工序名称

工艺模块 V1 兼容说明：

- `GET /processes` 继续保留，但返回语义升级为“小工序列表（包含 `stage_id/stage_code/stage_name`）”。
- 系统不再在启动时自动灌入默认工序，工段与小工序由工艺模块页面维护。

## 5. 用户接口（Sprint 1 已实现）

- `GET /users`：用户分页查询
- `POST /users`：创建用户
- `GET /users/{id}`：用户详情查询
- `PUT /users/{id}`：更新用户
- `DELETE /users/{id}`：删除用户

说明：

- 账号不再支持“禁用/启用”接口（已移除 `PATCH /users/{id}/status`）。
- 每个用户必须至少分配一个角色。
- 当角色包含 `operator` 时，必须分配至少一个工序。
- 非 `operator` 角色不允许分配工序。

## 6. 后续计划接口（Sprint 2+）

- 产品管理：`/products`
- 产品参数管理：`/product-param-templates`、`/product-param-items`
- 生产订单管理：`/production-orders`
- 首件管理：`/first-articles`
- 综合查询：`/queries/*`

## Production Module V1 (No Message Center)

### New APIs (`/api/v1`)

- `GET /production/orders`
- `POST /production/orders`
- `GET /production/orders/{order_id}`
- `PUT /production/orders/{order_id}`
- `DELETE /production/orders/{order_id}`
- `POST /production/orders/{order_id}/complete`
- `GET /production/my-orders`
- `POST /production/orders/{order_id}/first-article`
- `POST /production/orders/{order_id}/end-production`
- `GET /production/stats/overview`
- `GET /production/stats/processes`
- `GET /production/stats/operators`

### Scope Notes

- V1 focuses on order management, order query, and production data query.
- Message center, quality data tab, and repair tab are postponed to V2.
- Status values are persisted as English code values, and frontend is responsible for display mapping.

## Quality Module V1

### New APIs (`/api/v1`)

- `GET /quality/first-articles`
- `GET /quality/stats/overview`
- `GET /quality/stats/processes`
- `GET /quality/stats/operators`

### API Notes

- `GET /quality/first-articles`
  - Params: `date` (optional), `keyword` (optional), `page`, `page_size<=200`
  - Returns read-only daily verification code fields:
    - `query_date`
    - `verification_code`
    - `verification_code_source` (`stored` / `default` / `none`)
- `GET /quality/stats/*`
  - Params: `start_date` (optional), `end_date` (optional)
  - `end_date` uses inclusive semantics in business view (SQL uses `< end_date + 1 day`).

### Scope Notes

- V1 quality module uses only existing first-article/verification/order/production tables.
- No defect/scrap/repair models in this version.
- Result/status code values remain English in API output; frontend maps them to Chinese labels.

## 工艺模块 V1（工段 + 小工序 + 产品多模板）

### 新增页面 code（目录可见性）

- `craft`（sidebar）
- `process_management`（tab，parent=`craft`）
- `production_process_config`（tab，parent=`craft`）

默认可见角色：

- `system_admin`
- `production_admin`

### 新增 API（`/api/v1/craft`）

- `GET /craft/stages`
- `POST /craft/stages`
- `PUT /craft/stages/{stage_id}`
- `DELETE /craft/stages/{stage_id}`
- `GET /craft/processes`
- `POST /craft/processes`
- `PUT /craft/processes/{process_id}`
- `DELETE /craft/processes/{process_id}`
- `GET /craft/templates`
- `POST /craft/templates`
- `GET /craft/templates/{template_id}`
- `PUT /craft/templates/{template_id}`
- `DELETE /craft/templates/{template_id}`

### 生产接口升级（兼容）

- `POST /production/orders`、`PUT /production/orders/{order_id}` 新增字段：
  - `template_id`
  - `process_steps`（每步包含 `step_order/stage_id/process_id`）
  - `save_as_template`
  - `new_template_name`
  - `new_template_set_default`
- `process_codes` 保留一个版本周期作为兼容输入。
- `GET /production/orders/{order_id}`、`GET /production/my-orders` 每道工序新增：
  - `stage_code`
  - `stage_name`

### 模板同步规则

- `PUT /craft/templates/{template_id}` 支持 `sync_orders=true/false`。
- 同步范围为该模板关联的未完成订单：
  - `pending`：整单流程重建
  - `in_progress`：仅重建当前工序之后
- 若出现冲突（如当前工序无法对齐或后续已有报工记录），返回 `409`，并在响应中带 `sync_result.total/synced/skipped/reasons`。

### 迁移策略（清空后重建）

- 新增工段、模板、模板步骤表，并扩展订单/工序表的 stage 与模板快照字段。
- 生产域及工艺域数据按方案执行清空重建（不保留历史生产数据）。
- 设备保养 `execution_process_code` 语义升级为“工段 code”，由工艺配置驱动。
