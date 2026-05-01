# 契约链路

> 每条链路追溯：数据模型 → 服务层 → API端点 → 前端页面 → 测试

## EquipmentLedgerItem

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_features_equipment_models_equipment_models_dart_equipmentledgeritem`
- 标签: `EquipmentLedgerItem`
- 源文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 关联概览 (1 条边)

| 层级 | 数量 |
|---|---|
| models | 1 |

### models

- `equipment_models.dart` — `frontend/lib/features/equipment/models/equipment_models.dart` — [defines]


## MaintenanceItemEntry

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_features_equipment_models_equipment_models_dart_maintenanceitementry`
- 标签: `MaintenanceItemEntry`
- 源文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 关联概览 (1 条边)

| 层级 | 数量 |
|---|---|
| models | 1 |

### models

- `equipment_models.dart` — `frontend/lib/features/equipment/models/equipment_models.dart` — [defines]


## ProductionOrder

- 主节点: `models_production_order_productionorder`
- 标签: `ProductionOrder`
- 源文件: `backend\app\models\production_order.py`
- 域: `production`

### 关联概览 (52 条边)

| 层级 | 数量 |
|---|---|
| models | 12 |
| services | 37 |
| other | 3 |

### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]
- `production_order.py` — `backend/app/models/production_order.py` — [contains]
- `ProductionOrderProcess` — `backend/app/models/production_order_process.py` — [has_many]
- `ProductionSubOrder` — `backend/app/models/production_sub_order.py` — [has_many]
- `ProductionRecord` — `backend/app/models/production_record.py` — [has_many]
- `ProductionScrapStatistics` — `backend/app/models/production_scrap_statistics.py` — [has_one]
- `FirstArticleRecord` — `backend/app/models/first_article_record.py` — [has_one]
- `RepairOrder` — `backend/app/models/repair_order.py` — [has_many]
- `ProductionAssistAuthorization` — `backend/app/models/production_assist_authorization.py` — [has_one]
- `Product` — `backend/app/models/product.py` — [belongs_to]
- `Process` — `backend/app/models/process.py` — [belongs_to]

### services

- `SystemMasterTemplateResolveResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictReason` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateImpactResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareRow` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepPayloadItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepResolvedItem` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanSample` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsRow` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictError` — `backend/app/services/craft_service.py` — [uses]
- `ReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `StageReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProcessReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceRow` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `SystemMasterTemplateVersionResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `从系统母版套版，创建指定产品的工艺模板草稿。` — `backend/app/services/craft_service.py` — [uses]
- `跨产品复制模板，来源记录保留在 template_name 中。` — `backend/app/services/craft_service.py` — [uses]
- `FirstArticleReviewSessionCommandResult` — `backend/app/services/first_article_review_service.py` — [uses]
- `FirstArticleReviewSessionDetailResult` — `backend/app/services/first_article_review_service.py` — [uses]
- `_MessageSourceRegistryEntry` — `backend/app/services/message_service.py` — [uses]
- `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `全部标记已读，返回更新条数（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `ProductionCraftSampleSeedResult` — `backend/app/services/perf_sample_seed_service.py` — [uses]
- `ProductionDataFilters` — `backend/app/services/production_data_query_service.py` — [uses]
- `RepairListFilters` — `backend/app/services/production_repair_service.py` — [uses]
- `ScrapStatisticsFilters` — `backend/app/services/production_repair_service.py` — [uses]
- `ProductImpactOrder` — `backend/app/services/product_service.py` — [uses]
- `ProductImpactResult` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareRow` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareResult` — `backend/app/services/product_service.py` — [uses]
- `ProductParameterVersionListRow` — `backend/app/services/product_service.py` — [uses]
- `create_order()` — `backend/app/services/production_order_service.py` — [calls]

### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `SmokeContext` — `tools/docker_backend_smoke.py` — [uses]


## Role

- 主节点: `models_role_role`
- 标签: `Role`
- 源文件: `backend\app\models\role.py`
- 域: `authz`

### 关联概览 (30 条边)

| 层级 | 数量 |
|---|---|
| models | 5 |
| services | 23 |
| other | 2 |

### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]
- `role.py` — `backend/app/models/role.py` — [contains]
- `User` — `backend/app/models/user.py` — [has_one]
- `PermissionCatalog` — `backend/app/models/permission_catalog.py` — [has_many]

### services

- `RedisError` — `backend/app/services/authz_service.py` — [uses]
- `PermissionCatalogRow` — `backend/app/services/authz_service.py` — [uses]
- `AuthzRevisionConflictError` — `backend/app/services/authz_service.py` — [uses]
- `SeedResult` — `backend/app/services/bootstrap_seed_service.py` — [uses]
- `MaintenanceAutoGenerateTrace` — `backend/app/services/equipment_service.py` — [uses]
- `Attempt to repair text that was produced by UTF-8/GBK mojibake.` — `backend/app/services/equipment_service.py` — [uses]
- `_MessageSourceRegistryEntry` — `backend/app/services/message_service.py` — [uses]
- `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `全部标记已读，返回更新条数（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `PerfUserPoolSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserAccountSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserSeedResult` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `SessionStatusSnapshot` — `backend/app/services/session_service.py` — [uses]
- `OnlineSessionProjection` — `backend/app/services/session_service.py` — [uses]
- `延长活跃session的过期时间，返回session行或None（不可续期）。` — `backend/app/services/session_service.py` — [uses]
- `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。` — `backend/app/services/session_service.py` — [uses]
- `UserLifecycleChange` — `backend/app/services/user_service.py` — [uses]
- `UserPasswordResetChange` — `backend/app/services/user_service.py` — [uses]
- `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。` — `backend/app/services/user_service.py` — [uses]
- `返回拥有指定角色且处于激活状态的用户 ID 列表` — `backend/app/services/user_service.py` — [uses]
- `_ensure_role_rows()` — `backend/app/services/authz_service.py` — [calls]
- `_ensure_roles()` — `backend/app/services/bootstrap_seed_service.py` — [calls]
- `create_role()` — `backend/app/services/role_service.py` — [calls]

### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]


## Product

- 主节点: `models_product_product`
- 标签: `Product`
- 源文件: `backend\app\models\product.py`
- 域: `product`

### 关联概览 (39 条边)

| 层级 | 数量 |
|---|---|
| models | 4 |
| services | 33 |
| other | 2 |

### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]
- `product.py` — `backend/app/models/product.py` — [contains]
- `ProductionOrder` — `backend/app/models/production_order.py` — [belongs_to]

### services

- `SystemMasterTemplateResolveResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictReason` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateImpactResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareRow` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepPayloadItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepResolvedItem` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanSample` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsRow` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictError` — `backend/app/services/craft_service.py` — [uses]
- `ReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `StageReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProcessReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceRow` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `SystemMasterTemplateVersionResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `从系统母版套版，创建指定产品的工艺模板草稿。` — `backend/app/services/craft_service.py` — [uses]
- `跨产品复制模板，来源记录保留在 template_name 中。` — `backend/app/services/craft_service.py` — [uses]
- `_MessageSourceRegistryEntry` — `backend/app/services/message_service.py` — [uses]
- `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `全部标记已读，返回更新条数（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `ProductionCraftSampleSeedResult` — `backend/app/services/perf_sample_seed_service.py` — [uses]
- `ProductImpactOrder` — `backend/app/services/product_service.py` — [uses]
- `ProductImpactResult` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareRow` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareResult` — `backend/app/services/product_service.py` — [uses]
- `ProductParameterVersionListRow` — `backend/app/services/product_service.py` — [uses]
- `_ensure_active_product()` — `backend/app/services/perf_sample_seed_service.py` — [calls]
- `create_product()` — `backend/app/services/product_service.py` — [calls]

### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]


## Process

- 主节点: `models_process_process`
- 标签: `Process`
- 源文件: `backend\app\models\process.py`
- 域: `craft`

### 关联概览 (40 条边)

| 层级 | 数量 |
|---|---|
| models | 4 |
| services | 34 |
| other | 2 |

### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]
- `process.py` — `backend/app/models/process.py` — [contains]
- `ProductionOrder` — `backend/app/models/production_order.py` — [belongs_to]

### services

- `SystemMasterTemplateResolveResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictReason` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateImpactResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareRow` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepPayloadItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepResolvedItem` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanSample` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsRow` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictError` — `backend/app/services/craft_service.py` — [uses]
- `ReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `StageReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProcessReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceRow` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `SystemMasterTemplateVersionResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `从系统母版套版，创建指定产品的工艺模板草稿。` — `backend/app/services/craft_service.py` — [uses]
- `跨产品复制模板，来源记录保留在 template_name 中。` — `backend/app/services/craft_service.py` — [uses]
- `ProductionCraftSampleSeedResult` — `backend/app/services/perf_sample_seed_service.py` — [uses]
- `PerfUserPoolSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserAccountSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserSeedResult` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `UserLifecycleChange` — `backend/app/services/user_service.py` — [uses]
- `UserPasswordResetChange` — `backend/app/services/user_service.py` — [uses]
- `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。` — `backend/app/services/user_service.py` — [uses]
- `返回拥有指定角色且处于激活状态的用户 ID 列表` — `backend/app/services/user_service.py` — [uses]
- `create_process()` — `backend/app/services/craft_service.py` — [calls]
- `_ensure_process()` — `backend/app/services/perf_sample_seed_service.py` — [calls]
- `_ensure_perf_stage_processes()` — `backend/app/services/perf_user_seed_service.py` — [calls]
- `create_process()` — `backend/app/services/process_service.py` — [calls]

### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]


## QualityInspection

> 图谱中未找到 `QualityInspection` 节点

## AppSession

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_core_models_app_session_dart_appsession`
- 标签: `AppSession`
- 源文件: `frontend\lib\core\models\app_session.dart`
- 域: `frontend-core`

### 关联概览 (1 条边)

| 层级 | 数量 |
|---|---|
| models | 1 |

### models

- `app_session.dart` — `frontend/lib/core/models/app_session.dart` — [defines]


## User

- 主节点: `models_user_user`
- 标签: `User`
- 源文件: `backend\app\models\user.py`
- 域: `authz`

### 关联概览 (69 条边)

| 层级 | 数量 |
|---|---|
| models | 4 |
| services | 61 |
| api | 1 |
| other | 3 |

### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]
- `user.py` — `backend/app/models/user.py` — [contains]
- `Role` — `backend/app/models/role.py` — [has_one]

### services

- `RedisError` — `backend/app/services/authz_service.py` — [uses]
- `PermissionCatalogRow` — `backend/app/services/authz_service.py` — [uses]
- `AuthzRevisionConflictError` — `backend/app/services/authz_service.py` — [uses]
- `SeedResult` — `backend/app/services/bootstrap_seed_service.py` — [uses]
- `SystemMasterTemplateResolveResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictReason` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateImpactResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareRow` — `backend/app/services/craft_service.py` — [uses]
- `TemplateVersionCompareResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepPayloadItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateStepResolvedItem` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanSample` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsRow` — `backend/app/services/craft_service.py` — [uses]
- `CraftKanbanProcessMetricsResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateSyncConflictError` — `backend/app/services/craft_service.py` — [uses]
- `ReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `StageReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProcessReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceRow` — `backend/app/services/craft_service.py` — [uses]
- `ProductTemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `SystemMasterTemplateVersionResult` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceItem` — `backend/app/services/craft_service.py` — [uses]
- `TemplateReferenceResult` — `backend/app/services/craft_service.py` — [uses]
- `从系统母版套版，创建指定产品的工艺模板草稿。` — `backend/app/services/craft_service.py` — [uses]
- `跨产品复制模板，来源记录保留在 template_name 中。` — `backend/app/services/craft_service.py` — [uses]
- `MaintenanceAutoGenerateTrace` — `backend/app/services/equipment_service.py` — [uses]
- `Attempt to repair text that was produced by UTF-8/GBK mojibake.` — `backend/app/services/equipment_service.py` — [uses]
- `FirstArticleReviewSessionCommandResult` — `backend/app/services/first_article_review_service.py` — [uses]
- `FirstArticleReviewSessionDetailResult` — `backend/app/services/first_article_review_service.py` — [uses]
- `DashboardMessageSeed` — `backend/app/services/home_dashboard_service.py` — [uses]
- `_MessageSourceRegistryEntry` — `backend/app/services/message_service.py` — [uses]
- `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `全部标记已读，返回更新条数（不提交，由调用方负责 commit）` — `backend/app/services/message_service.py` — [uses]
- `PerfCapacityPermissionPlanItem` — `backend/app/services/perf_capacity_permission_service.py` — [uses]
- `PerfCapacityPermissionApplyResult` — `backend/app/services/perf_capacity_permission_service.py` — [uses]
- `ProductionCraftSampleSeedResult` — `backend/app/services/perf_sample_seed_service.py` — [uses]
- `PerfUserPoolSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserAccountSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserSeedResult` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `ProductionDataFilters` — `backend/app/services/production_data_query_service.py` — [uses]
- `RepairListFilters` — `backend/app/services/production_repair_service.py` — [uses]
- `ScrapStatisticsFilters` — `backend/app/services/production_repair_service.py` — [uses]
- `ProductImpactOrder` — `backend/app/services/product_service.py` — [uses]
- `ProductImpactResult` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareRow` — `backend/app/services/product_service.py` — [uses]
- `ProductVersionCompareResult` — `backend/app/services/product_service.py` — [uses]
- `ProductParameterVersionListRow` — `backend/app/services/product_service.py` — [uses]
- `SessionStatusSnapshot` — `backend/app/services/session_service.py` — [uses]
- `OnlineSessionProjection` — `backend/app/services/session_service.py` — [uses]
- `延长活跃session的过期时间，返回session行或None（不可续期）。` — `backend/app/services/session_service.py` — [uses]
- `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。` — `backend/app/services/session_service.py` — [uses]
- `UserLifecycleChange` — `backend/app/services/user_service.py` — [uses]
- `UserPasswordResetChange` — `backend/app/services/user_service.py` — [uses]
- `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。` — `backend/app/services/user_service.py` — [uses]
- `返回拥有指定角色且处于激活状态的用户 ID 列表` — `backend/app/services/user_service.py` — [uses]
- `_ensure_admin_user()` — `backend/app/services/bootstrap_seed_service.py` — [calls]
- `seed_perf_capacity_users()` — `backend/app/services/perf_user_seed_service.py` — [calls]
- `ensure_admin_account()` — `backend/app/services/user_service.py` — [calls]
- `create_user()` — `backend/app/services/user_service.py` — [calls]
- `approve_registration_request()` — `backend/app/services/user_service.py` — [calls]

### api

- `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权` — `backend/app/api/v1/endpoints/messages.py` — [uses]

### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `SmokeContext` — `tools/docker_backend_smoke.py` — [uses]

