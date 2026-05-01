# 影响面分析

> 以核心对象为中心，列出上下游 1-hop 的文件和模块

## ProductionOrder

### `ProductionOrder` — `backend\app\models\production_order.py` (域:production)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/craft_service.py`: `TemplateImpactResult`, `TemplateSyncResult`, `TemplateVersionCompareRow`, `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason` +17 more
- `backend/app/services/first_article_review_service.py`: `FirstArticleReviewSessionDetailResult`, `FirstArticleReviewSessionCommandResult`
- `backend/app/services/message_service.py`: `_MessageSourceRegistryEntry`
- `backend/app/services/perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend/app/services/product_service.py`: `ProductImpactResult`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductVersionCompareRow`
- `backend/app/services/production_data_query_service.py`: `ProductionDataFilters`
- `backend/app/services/production_order_service.py`: `create_order()`
- `backend/app/services/production_repair_service.py`: `ScrapStatisticsFilters`, `RepairListFilters`

#### other

- `tools/docker_backend_smoke.py`: `SmokeContext`
- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---

## Equipment

### `Equipment` — `backend\app\models\equipment.py` (域:equipment)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/equipment_service.py`: `create_equipment()`, `MaintenanceAutoGenerateTrace`

#### other

- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---

## Role

### `Role` — `backend\app\models\role.py` (域:authz)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/authz_service.py`: `AuthzRevisionConflictError`, `_ensure_role_rows()`, `RedisError`, `PermissionCatalogRow`
- `backend/app/services/bootstrap_seed_service.py`: `SeedResult`, `_ensure_roles()`
- `backend/app/services/equipment_service.py`: `MaintenanceAutoGenerateTrace`
- `backend/app/services/message_service.py`: `_MessageSourceRegistryEntry`
- `backend/app/services/perf_user_seed_service.py`: `PerfUserAccountSpec`, `PerfUserPoolSpec`, `PerfUserSeedResult`
- `backend/app/services/role_service.py`: `create_role()`
- `backend/app/services/session_service.py`: `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`, `OnlineSessionProjection`, `SessionStatusSnapshot`, `延长活跃session的过期时间，返回session行或None（不可续期）。`
- `backend/app/services/user_service.py`: `UserLifecycleChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `UserPasswordResetChange`

#### other

- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---

## AppSession

### `AppSession` — `frontend\lib\core\models\app_session.dart` (域:frontend-core)

---

## Product

### `Product` — `backend\app\models\product.py` (域:product)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/craft_service.py`: `TemplateImpactResult`, `TemplateSyncResult`, `TemplateVersionCompareRow`, `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason` +17 more
- `backend/app/services/message_service.py`: `_MessageSourceRegistryEntry`
- `backend/app/services/perf_sample_seed_service.py`: `_ensure_active_product()`, `ProductionCraftSampleSeedResult`
- `backend/app/services/product_service.py`: `ProductImpactResult`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductVersionCompareRow` +1 more

#### other

- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---

## Process

### `Process` — `backend\app\models\process.py` (域:craft)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/craft_service.py`: `TemplateImpactResult`, `TemplateSyncResult`, `TemplateVersionCompareRow`, `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason` +18 more
- `backend/app/services/perf_sample_seed_service.py`: `_ensure_process()`, `ProductionCraftSampleSeedResult`
- `backend/app/services/perf_user_seed_service.py`: `PerfUserAccountSpec`, `PerfUserPoolSpec`, `PerfUserSeedResult`, `_ensure_perf_stage_processes()`
- `backend/app/services/process_service.py`: `create_process()`
- `backend/app/services/user_service.py`: `UserLifecycleChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `UserPasswordResetChange`

#### other

- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---

## QualityInspection
> 图谱中未找到 `QualityInspection` 节点

## User

### `User` — `backend\app\models\user.py` (域:authz)

#### models

- `backend/app/models/base.py`: `Base`, `TimestampMixin`

#### services

- `backend/app/services/authz_service.py`: `AuthzRevisionConflictError`, `RedisError`, `PermissionCatalogRow`
- `backend/app/services/bootstrap_seed_service.py`: `SeedResult`, `_ensure_admin_user()`
- `backend/app/services/craft_service.py`: `TemplateImpactResult`, `TemplateSyncResult`, `TemplateVersionCompareRow`, `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason` +17 more
- `backend/app/services/equipment_service.py`: `MaintenanceAutoGenerateTrace`
- `backend/app/services/first_article_review_service.py`: `FirstArticleReviewSessionDetailResult`, `FirstArticleReviewSessionCommandResult`
- `backend/app/services/home_dashboard_service.py`: `DashboardMessageSeed`
- `backend/app/services/message_service.py`: `_MessageSourceRegistryEntry`
- `backend/app/services/perf_capacity_permission_service.py`: `PerfCapacityPermissionPlanItem`, `PerfCapacityPermissionApplyResult`
- `backend/app/services/perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend/app/services/perf_user_seed_service.py`: `seed_perf_capacity_users()`, `PerfUserAccountSpec`, `PerfUserPoolSpec`, `PerfUserSeedResult`
- `backend/app/services/product_service.py`: `ProductImpactResult`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`, `ProductImpactOrder`, `ProductVersionCompareRow`
- `backend/app/services/production_data_query_service.py`: `ProductionDataFilters`
- `backend/app/services/production_repair_service.py`: `ScrapStatisticsFilters`, `RepairListFilters`
- `backend/app/services/session_service.py`: `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`, `OnlineSessionProjection`, `SessionStatusSnapshot`, `延长活跃session的过期时间，返回session行或None（不可续期）。`
- `backend/app/services/user_service.py`: `UserPasswordResetChange`, `UserLifecycleChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `ensure_admin_account()`, `create_user()` +1 more

#### api

- `backend/app/api/v1/endpoints/messages.py`: `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权`

#### other

- `tools/docker_backend_smoke.py`: `SmokeContext`
- `tools/perf/write_gate/sample_registry.py`: `BaselineOrderCreateReadyHandler`, `RuntimeStageDeleteReadyHandler`, `NoOpSampleHandler`, `RuntimeTemplateReadyHandler`, `RuntimeOrderReadyHandler` +9 more

---
