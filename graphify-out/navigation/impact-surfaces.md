# 影响面分析

> 以核心对象为中心，列出上下游 1-hop 的文件和模块

## ProductionOrder

### `ProductionOrder` — `backend\app\models\production_order.py` (域:production)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/first_article_record.py`: `FirstArticleRecord`
- `backend/app/models/process.py`: `Process`
- `backend/app/models/product.py`: `Product`
- `backend/app/models/production_assist_authorization.py`: `ProductionAssistAuthorization`
- `backend/app/models/production_order.py`: `production_order.py`
- `backend/app/models/production_order_process.py`: `ProductionOrderProcess`
- `backend/app/models/production_record.py`: `ProductionRecord`
- `backend/app/models/production_scrap_statistics.py`: `ProductionScrapStatistics`
- `backend/app/models/production_sub_order.py`: `ProductionSubOrder`
- `backend/app/models/repair_order.py`: `RepairOrder`

#### services

- `backend/app/services/craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateVersionCompareRow`, `TemplateSyncResult`, `TemplateImpactResult` +17 more
- `backend/app/services/first_article_review_service.py`: `FirstArticleReviewSessionDetailResult`, `FirstArticleReviewSessionCommandResult`
- `backend/app/services/message_service.py`: `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `_MessageSourceRegistryEntry`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend/app/services/perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend/app/services/product_service.py`: `ProductVersionCompareResult`, `ProductVersionCompareRow`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductImpactResult`
- `backend/app/services/production_data_query_service.py`: `ProductionDataFilters`
- `backend/app/services/production_order_service.py`: `create_order()`
- `backend/app/services/production_repair_service.py`: `RepairListFilters`, `ScrapStatisticsFilters`

#### other

- `tools/docker_backend_smoke.py`: `SmokeContext`

---

## Equipment

### `Equipment` — `backend\app\models\equipment.py` (域:equipment)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/equipment.py`: `equipment.py`
- `backend/app/models/maintenance_plan.py`: `MaintenancePlan`
- `backend/app/models/maintenance_work_order.py`: `MaintenanceWorkOrder`

#### services

- `backend/app/services/equipment_service.py`: `Attempt to repair text that was produced by UTF-8/GBK mojibake.`, `MaintenanceAutoGenerateTrace`, `create_equipment()`

---

## Role

### `Role` — `backend\app\models\role.py` (域:authz)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/permission_catalog.py`: `PermissionCatalog`
- `backend/app/models/role.py`: `role.py`
- `backend/app/models/user.py`: `User`

#### services

- `backend/app/services/authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError`, `_ensure_role_rows()`
- `backend/app/services/bootstrap_seed_service.py`: `SeedResult`, `_ensure_roles()`
- `backend/app/services/equipment_service.py`: `Attempt to repair text that was produced by UTF-8/GBK mojibake.`, `MaintenanceAutoGenerateTrace`
- `backend/app/services/message_service.py`: `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `_MessageSourceRegistryEntry`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend/app/services/perf_user_seed_service.py`: `PerfUserSeedResult`, `PerfUserPoolSpec`, `PerfUserAccountSpec`
- `backend/app/services/role_service.py`: `create_role()`
- `backend/app/services/session_service.py`: `OnlineSessionProjection`, `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`, `延长活跃session的过期时间，返回session行或None（不可续期）。`, `SessionStatusSnapshot`
- `backend/app/services/user_service.py`: `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `UserLifecycleChange`, `返回拥有指定角色且处于激活状态的用户 ID 列表`, `UserPasswordResetChange`

---

## AppSession

### `AppSession` — `frontend\lib\core\models\app_session.dart` (域:frontend-core)

#### models

- `frontend/lib/core/models/app_session.dart`: `app_session.dart`

---

## Product

### `Product` — `backend\app\models\product.py` (域:product)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/product.py`: `product.py`
- `backend/app/models/production_order.py`: `ProductionOrder`

#### services

- `backend/app/services/craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateVersionCompareRow`, `TemplateSyncResult`, `TemplateImpactResult` +17 more
- `backend/app/services/message_service.py`: `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `_MessageSourceRegistryEntry`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend/app/services/perf_sample_seed_service.py`: `_ensure_active_product()`, `ProductionCraftSampleSeedResult`
- `backend/app/services/product_service.py`: `ProductVersionCompareResult`, `ProductVersionCompareRow`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductImpactResult` +1 more

---

## Process

### `Process` — `backend\app\models\process.py` (域:craft)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/process.py`: `process.py`
- `backend/app/models/production_order.py`: `ProductionOrder`

#### services

- `backend/app/services/craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateVersionCompareRow`, `TemplateSyncResult`, `TemplateImpactResult` +18 more
- `backend/app/services/perf_sample_seed_service.py`: `_ensure_process()`, `ProductionCraftSampleSeedResult`
- `backend/app/services/perf_user_seed_service.py`: `PerfUserSeedResult`, `_ensure_perf_stage_processes()`, `PerfUserPoolSpec`, `PerfUserAccountSpec`
- `backend/app/services/process_service.py`: `create_process()`
- `backend/app/services/user_service.py`: `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `UserLifecycleChange`, `返回拥有指定角色且处于激活状态的用户 ID 列表`, `UserPasswordResetChange`

---

## QualityInspection

> 图谱中未找到 `QualityInspection` 节点

## User

### `User` — `backend\app\models\user.py` (域:authz)

#### models

- `backend/app/models/base.py`: `TimestampMixin`, `Base`
- `backend/app/models/role.py`: `Role`
- `backend/app/models/user.py`: `user.py`

#### services

- `backend/app/services/authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError`
- `backend/app/services/bootstrap_seed_service.py`: `SeedResult`, `_ensure_admin_user()`
- `backend/app/services/craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateVersionCompareRow`, `TemplateSyncResult`, `TemplateImpactResult` +17 more
- `backend/app/services/equipment_service.py`: `Attempt to repair text that was produced by UTF-8/GBK mojibake.`, `MaintenanceAutoGenerateTrace`
- `backend/app/services/first_article_review_service.py`: `FirstArticleReviewSessionDetailResult`, `FirstArticleReviewSessionCommandResult`
- `backend/app/services/home_dashboard_service.py`: `DashboardMessageSeed`
- `backend/app/services/message_service.py`: `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `_MessageSourceRegistryEntry`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend/app/services/perf_capacity_permission_service.py`: `PerfCapacityPermissionPlanItem`, `PerfCapacityPermissionApplyResult`
- `backend/app/services/perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend/app/services/perf_user_seed_service.py`: `PerfUserSeedResult`, `PerfUserPoolSpec`, `PerfUserAccountSpec`, `seed_perf_capacity_users()`
- `backend/app/services/product_service.py`: `ProductVersionCompareResult`, `ProductVersionCompareRow`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductImpactResult`
- `backend/app/services/production_data_query_service.py`: `ProductionDataFilters`
- `backend/app/services/production_repair_service.py`: `RepairListFilters`, `ScrapStatisticsFilters`
- `backend/app/services/session_service.py`: `OnlineSessionProjection`, `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`, `延长活跃session的过期时间，返回session行或None（不可续期）。`, `SessionStatusSnapshot`
- `backend/app/services/user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `ensure_admin_account()`, `返回拥有指定角色且处于激活状态的用户 ID 列表` +2 more

#### api

- `backend/app/api/v1/endpoints/messages.py`: `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权`

#### other

- `tools/docker_backend_smoke.py`: `SmokeContext`

---
