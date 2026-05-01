# 影响面分析

> 自动生成，基于治理后图谱
> 以核心对象为中心，列出上下游 1-2 跳的文件和模块

## ProductionOrder

### `ProductionOrder` — `backend\app\models\production_order.py`

#### 直接影响 (1-hop: 52 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\first_article_record.py`: `FirstArticleRecord`
- `backend\app\models\process.py`: `Process`
- `backend\app\models\product.py`: `Product`
- `backend\app\models\production_assist_authorization.py`: `ProductionAssistAuthorization`
- `backend\app\models\production_order.py`: `production_order.py`
- `backend\app\models\production_order_process.py`: `ProductionOrderProcess`
- `backend\app\models\production_record.py`: `ProductionRecord`
- `backend\app\models\production_scrap_statistics.py`: `ProductionScrapStatistics`
- `backend\app\models\production_sub_order.py`: `ProductionSubOrder`
- `backend\app\models\repair_order.py`: `RepairOrder`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult`, `TemplateImpactResult`, `TemplateVersionCompareRow` +17 more
- `backend\app\services\first_article_review_service.py`: `FirstArticleReviewSessionCommandResult`, `FirstArticleReviewSessionDetailResult`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`
- `backend\app\services\production_data_query_service.py`: `ProductionDataFilters`
- `backend\app\services\production_order_service.py`: `create_order()`
- `backend\app\services\production_repair_service.py`: `RepairListFilters`, `ScrapStatisticsFilters`
- `tools\docker_backend_smoke.py`: `SmokeContext`

#### 间接影响 (2-hop: 168 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\craft.py`: `_to_template_update_result()`, `_to_stage_reference_result()`, `_to_process_reference_result()` +6 more
- `backend\app\api\v1\endpoints\production.py`: `create_order_api()`, `get_scrap_statistics_api()`, `export_scrap_statistics_api()` +2 more
- `backend\app\api\v1\endpoints\quality.py`: `get_quality_scrap_statistics_api()`, `export_quality_scrap_statistics_api()`, `get_quality_repair_orders_api()` +1 more
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- ... 共 77 个文件

### `ProductionOrderProcess` — `backend\app\models\production_order_process.py`

#### 直接影响 (1-hop: 47 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\models\production_order_process.py`: `production_order_process.py`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult`, `TemplateImpactResult`, `TemplateVersionCompareRow` +18 more
- `backend\app\services\first_article_review_service.py`: `FirstArticleReviewSessionCommandResult`, `FirstArticleReviewSessionDetailResult`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`
- `backend\app\services\production_data_query_service.py`: `ProductionDataFilters`
- `backend\app\services\production_order_service.py`: `_build_order_process_rows()`, `update_order()`
- `backend\app\services\production_repair_service.py`: `RepairListFilters`, `ScrapStatisticsFilters`
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `返回拥有指定角色且处于激活状态的用户 ID 列表`
- `tools\docker_backend_smoke.py`: `SmokeContext`

#### 间接影响 (2-hop: 146 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\craft.py`: `_to_template_update_result()`, `_to_stage_reference_result()`, `_to_process_reference_result()` +6 more
- `backend\app\api\v1\endpoints\production.py`: `update_order_api()`, `get_scrap_statistics_api()`, `export_scrap_statistics_api()` +2 more
- `backend\app\api\v1\endpoints\quality.py`: `get_quality_scrap_statistics_api()`, `export_quality_scrap_statistics_api()`, `get_quality_repair_orders_api()` +1 more
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- ... 共 71 个文件

### `ProductionOrderItem` — `frontend\lib\features\production\models\production_models.dart`

#### 直接影响 (1-hop: 1 个节点)

- `frontend\lib\features\production\models\production_models.dart`: `production_models.dart`

#### 间接影响 (2-hop: 74 个节点)

- `frontend\lib\features\production\models\production_models.dart`: `ProductionOrderListResult`, `ProductionOrderProcessItem`, `ProductionSubOrderItem` +71 more

---

## Equipment

### `equipment.py` — `backend\app\models\equipment.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\equipment.py`: `Equipment`

#### 间接影响 (2-hop: 9 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\maintenance_plan.py`: `MaintenancePlan`
- `backend\app\models\maintenance_work_order.py`: `MaintenanceWorkOrder`
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`, `create_equipment()`

### `Equipment` — `backend\app\models\equipment.py`

#### 直接影响 (1-hop: 10 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\equipment.py`: `equipment.py`
- `backend\app\models\maintenance_plan.py`: `MaintenancePlan`
- `backend\app\models\maintenance_work_order.py`: `MaintenanceWorkOrder`
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`, `create_equipment()`

#### 间接影响 (2-hop: 93 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\equipment.py`: `create_equipment_ledger()`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- `backend\app\models\equipment_runtime_parameter.py`: `EquipmentRuntimeParameter`
- `backend\app\models\first_article_disposition.py`: `FirstArticleDisposition`
- `backend\app\models\first_article_disposition_history.py`: `FirstArticleDispositionHistory`, `首件处置历史记录表，每次处置均追加一条，禁止覆盖。`
- ... 共 61 个文件

### `equipment_rule.py` — `backend\app\models\equipment_rule.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\equipment_rule.py`: `EquipmentRule`

#### 间接影响 (2-hop: 19 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\services\equipment_rule_service.py`: `create_equipment_rule()`
- `tools\perf\write_gate\sample_registry.py`: `NoOpSampleHandler`, `BaselineOrderCreateReadyHandler`, `RuntimeTemplateReadyHandler` +11 more

---

## Role

### `role.py` — `backend\app\models\role.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\role.py`: `Role`

#### 间接影响 (2-hop: 29 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\permission_catalog.py`: `PermissionCatalog`
- `backend\app\models\user.py`: `User`
- `backend\app\services\authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError` +1 more
- `backend\app\services\bootstrap_seed_service.py`: `SeedResult`, `_ensure_roles()`
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult`
- `backend\app\services\role_service.py`: `create_role()`
- `backend\app\services\session_service.py`: `SessionStatusSnapshot`, `OnlineSessionProjection`, `延长活跃session的过期时间，返回session行或None（不可续期）。` +1 more
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。` +1 more

### `Role` — `backend\app\models\role.py`

#### 直接影响 (1-hop: 30 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\permission_catalog.py`: `PermissionCatalog`
- `backend\app\models\role.py`: `role.py`
- `backend\app\models\user.py`: `User`
- `backend\app\services\authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError`, `_ensure_role_rows()`
- `backend\app\services\bootstrap_seed_service.py`: `SeedResult`, `_ensure_roles()`
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult`
- `backend\app\services\role_service.py`: `create_role()`
- `backend\app\services\session_service.py`: `SessionStatusSnapshot`, `OnlineSessionProjection`, `延长活跃session的过期时间，返回session行或None（不可续期）。`, `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `返回拥有指定角色且处于激活状态的用户 ID 列表`

#### 间接影响 (2-hop: 141 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\messages.py`: `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权`
- `backend\app\api\v1\endpoints\roles.py`: `create_role_api()`
- `backend\app\core\authz_catalog.py`: `PermissionCatalogItem`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- ... 共 78 个文件

### `role_permission_grant.py` — `backend\app\models\role_permission_grant.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\role_permission_grant.py`: `RolePermissionGrant`

#### 间接影响 (2-hop: 11 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\services\authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError` +1 more
- `backend\app\services\authz_write_service.py`: `_apply_role_permission_changes()`
- `backend\tests\test_user_module_integration.py`: `UserModuleIntegrationTest`, `.test_role_permission_defaults_skip_pending_duplicate_grants()`

---

## AppSession

### `AppSession` — `frontend\lib\core\models\app_session.dart`

#### 直接影响 (1-hop: 1 个节点)

- `frontend\lib\core\models\app_session.dart`: `app_session.dart`

#### 间接影响 (2-hop: 1 个节点)

- `frontend\test\widgets\quality_module_regression_test.dart`: `dart:convert`

---

## Product

### `product.py` — `backend\app\models\product.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\product.py`: `Product`

#### 间接影响 (2-hop: 38 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult` +19 more
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`, `_ensure_active_product()`
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow` +3 more

### `Product` — `backend\app\models\product.py`

#### 直接影响 (1-hop: 39 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\product.py`: `product.py`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult`, `TemplateImpactResult`, `TemplateVersionCompareRow` +17 more
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`, `_ensure_active_product()`
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow`, `ProductVersionCompareResult`, `ProductParameterVersionListRow` +1 more

#### 间接影响 (2-hop: 122 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\craft.py`: `_to_template_update_result()`, `_to_stage_reference_result()`, `_to_process_reference_result()` +6 more
- `backend\app\api\v1\endpoints\products.py`: `create_product_api()`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- `backend\app\models\equipment_runtime_parameter.py`: `EquipmentRuntimeParameter`
- ... 共 68 个文件

### `production_assist_authorization.py` — `backend\app\models\production_assist_authorization.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\production_assist_authorization.py`: `ProductionAssistAuthorization`

#### 间接影响 (2-hop: 9 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\services\assist_authorization_service.py`: `create_assist_authorization()`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`

---

## Process

### `ProcessPipelineInstance` — `backend\app\models\order_sub_order_pipeline_instance.py`

#### 直接影响 (1-hop: 7 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\order_sub_order_pipeline_instance.py`: `order_sub_order_pipeline_instance.py`
- `backend\app\services\production_order_service.py`: `allocate_pipeline_instance_for_process()`
- `backend\tests\test_production_module_integration.py`: `ProductionModuleIntegrationTest`

#### 间接影响 (2-hop: 119 个节点)

- ``: `DeclarativeBase`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- `backend\app\models\equipment_runtime_parameter.py`: `EquipmentRuntimeParameter`
- `backend\app\models\first_article_disposition.py`: `FirstArticleDisposition`
- `backend\app\models\first_article_disposition_history.py`: `FirstArticleDispositionHistory`, `首件处置历史记录表，每次处置均追加一条，禁止覆盖。`
- ... 共 60 个文件

### `process.py` — `backend\app\models\process.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\process.py`: `Process`

#### 间接影响 (2-hop: 39 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult` +20 more
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`, `_ensure_process()`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult` +1 more
- `backend\app\services\process_service.py`: `create_process()`
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。` +1 more

### `Process` — `backend\app\models\process.py`

#### 直接影响 (1-hop: 40 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\process.py`: `process.py`
- `backend\app\models\production_order.py`: `ProductionOrder`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult`, `TemplateImpactResult`, `TemplateVersionCompareRow` +18 more
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`, `_ensure_process()`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult`, `_ensure_perf_stage_processes()`
- `backend\app\services\process_service.py`: `create_process()`
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `返回拥有指定角色且处于激活状态的用户 ID 列表`

#### 间接影响 (2-hop: 131 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\craft.py`: `_to_template_update_result()`, `_to_stage_reference_result()`, `_to_process_reference_result()` +7 more
- `backend\app\api\v1\endpoints\processes.py`: `create_process_api()`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- `backend\app\models\craft_system_master_template_revision_step.py`: `CraftSystemMasterTemplateRevisionStep`
- `backend\app\models\craft_system_master_template_step.py`: `CraftSystemMasterTemplateStep`
- `backend\app\models\daily_verification_code.py`: `DailyVerificationCode`
- `backend\app\models\equipment.py`: `Equipment`
- `backend\app\models\equipment_rule.py`: `EquipmentRule`
- `backend\app\models\equipment_runtime_parameter.py`: `EquipmentRuntimeParameter`
- ... 共 72 个文件

---

## QualityInspection

> 图谱中未找到 `QualityInspection` 节点

## User

### `user.py` — `backend\app\models\user.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\user.py`: `User`

#### 间接影响 (2-hop: 68 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\api\v1\endpoints\messages.py`: `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\role.py`: `Role`
- `backend\app\services\authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError`
- `backend\app\services\bootstrap_seed_service.py`: `SeedResult`, `_ensure_admin_user()`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult` +19 more
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`
- `backend\app\services\first_article_review_service.py`: `FirstArticleReviewSessionCommandResult`, `FirstArticleReviewSessionDetailResult`
- `backend\app\services\home_dashboard_service.py`: `DashboardMessageSeed`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_capacity_permission_service.py`: `PerfCapacityPermissionPlanItem`, `PerfCapacityPermissionApplyResult`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult` +1 more
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow` +2 more
- ... 共 20 个文件

### `User` — `backend\app\models\user.py`

#### 直接影响 (1-hop: 69 个节点)

- ``: `Base`, `TimestampMixin`
- `backend\app\api\v1\endpoints\messages.py`: `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权`
- `backend\app\models\base.py`: `Base`, `TimestampMixin`
- `backend\app\models\role.py`: `Role`
- `backend\app\models\user.py`: `user.py`
- `backend\app\services\authz_service.py`: `RedisError`, `PermissionCatalogRow`, `AuthzRevisionConflictError`
- `backend\app\services\bootstrap_seed_service.py`: `SeedResult`, `_ensure_admin_user()`
- `backend\app\services\craft_service.py`: `SystemMasterTemplateResolveResult`, `TemplateSyncConflictReason`, `TemplateSyncResult`, `TemplateImpactResult`, `TemplateVersionCompareRow` +17 more
- `backend\app\services\equipment_service.py`: `MaintenanceAutoGenerateTrace`, `Attempt to repair text that was produced by UTF-8/GBK mojibake.`
- `backend\app\services\first_article_review_service.py`: `FirstArticleReviewSessionCommandResult`, `FirstArticleReviewSessionDetailResult`
- `backend\app\services\home_dashboard_service.py`: `DashboardMessageSeed`
- `backend\app\services\message_service.py`: `_MessageSourceRegistryEntry`, `标记单条消息已读，返回是否成功（不提交，由调用方负责 commit）`, `全部标记已读，返回更新条数（不提交，由调用方负责 commit）`
- `backend\app\services\perf_capacity_permission_service.py`: `PerfCapacityPermissionPlanItem`, `PerfCapacityPermissionApplyResult`
- `backend\app\services\perf_sample_seed_service.py`: `ProductionCraftSampleSeedResult`
- `backend\app\services\perf_user_seed_service.py`: `PerfUserPoolSpec`, `PerfUserAccountSpec`, `PerfUserSeedResult`, `seed_perf_capacity_users()`
- `backend\app\services\product_service.py`: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`
- `backend\app\services\production_data_query_service.py`: `ProductionDataFilters`
- `backend\app\services\production_repair_service.py`: `RepairListFilters`, `ScrapStatisticsFilters`
- `backend\app\services\session_service.py`: `SessionStatusSnapshot`, `OnlineSessionProjection`, `延长活跃session的过期时间，返回session行或None（不可续期）。`, `强制下线指定用户的所有活跃会话（可排除指定session）。      用于web登录时的单会话并发控制。`
- `backend\app\services\user_service.py`: `UserLifecycleChange`, `UserPasswordResetChange`, `鉴权读链专用：仅加载鉴权与公共用户信息所需字段。`, `返回拥有指定角色且处于激活状态的用户 ID 列表`, `ensure_admin_account()` +2 more
- `tools\docker_backend_smoke.py`: `SmokeContext`

#### 间接影响 (2-hop: 196 个节点)

- ``: `DeclarativeBase`
- `backend\app\api\v1\endpoints\auth.py`: `bootstrap_admin_account()`, `approve_registration()`
- `backend\app\api\v1\endpoints\craft.py`: `_to_template_update_result()`, `_to_stage_reference_result()`, `_to_process_reference_result()` +6 more
- `backend\app\api\v1\endpoints\messages.py`: `websocket_endpoint()`
- `backend\app\api\v1\endpoints\production.py`: `get_scrap_statistics_api()`, `export_scrap_statistics_api()`, `get_repair_orders_api()` +1 more
- `backend\app\api\v1\endpoints\quality.py`: `get_quality_scrap_statistics_api()`, `export_quality_scrap_statistics_api()`, `get_quality_repair_orders_api()` +1 more
- `backend\app\api\v1\endpoints\users.py`: `create_user_api()`, `import_users()`
- `backend\app\core\authz_catalog.py`: `PermissionCatalogItem`
- `backend\app\core\security.py`: `get_password_hash()`
- `backend\app\models\audit_log.py`: `AuditLog`
- `backend\app\models\authz_change_log.py`: `AuthzChangeLog`, `AuthzChangeLogItem`
- `backend\app\models\authz_module_revision.py`: `AuthzModuleRevision`
- `backend\app\models\base.py`: `base.py`
- `backend\app\models\craft_system_master_template.py`: `CraftSystemMasterTemplate`
- `backend\app\models\craft_system_master_template_revision.py`: `CraftSystemMasterTemplateRevision`
- ... 共 89 个文件

### `user_export_task.py` — `backend\app\models\user_export_task.py`

#### 直接影响 (1-hop: 1 个节点)

- `backend\app\models\user_export_task.py`: `UserExportTask`

#### 间接影响 (2-hop: 4 个节点)

- ``: `Base`
- `backend\app\models\base.py`: `Base`
- `backend\app\services\user_export_task_service.py`: `create_user_export_task()`
- `backend\tests\test_user_module_integration.py`: `UserModuleIntegrationTest`

---
