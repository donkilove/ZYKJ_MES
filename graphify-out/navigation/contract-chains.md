# 契约链路

> 每条链路追溯：数据模型 → 服务层 → API端点 → 前端页面 → 测试
> 标注 `[导航推断]` 的链路为按文件/域匹配推断，非原始图边

## EquipmentLedgerItem

- 主节点标签: `EquipmentLedgerItem`
- 主节点文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 图谱关联 (0 条直接边)


### 导航补充链路 [导航推断，非原始图边]

- [后端数据模型] `EquipmentLedgerItem` — `frontend/lib/features/equipment/models/equipment_models.dart`
- [后端 Schema/DTO] `EquipmentLedgerItem` — `backend/app/schemas/equipment.py`
- [前端 Model] `EquipmentLedgerItem` — `frontend/lib/features/equipment/models/equipment_models.dart`
- [测试覆盖] `_buildEquipmentLedgerItem` — `frontend/test/widgets/equipment_module_pages_test.dart`


## MaintenanceItemEntry

- 主节点标签: `MaintenanceItemEntry`
- 主节点文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 图谱关联 (0 条直接边)


### 导航补充链路 [导航推断，非原始图边]

- [后端数据模型] `MaintenanceItemEntry` — `frontend/lib/features/equipment/models/equipment_models.dart`
- [后端 Schema/DTO] `MaintenanceItemEntry` — `backend/app/schemas/equipment.py`
- [前端 Model] `MaintenanceItemEntry` — `frontend/lib/features/equipment/models/equipment_models.dart`
- [测试覆盖] `_buildMaintenanceItemEntry` — `frontend/test/widgets/equipment_module_pages_test.dart`


## ProductionOrder

- 主节点标签: `ProductionOrder`
- 主节点文件: `backend\app\models\production_order.py`
- 域: `production`

### 图谱关联 (73 条直接边)

| 层级 | 数量 |
|---|---|
| models | 2 |
| services | 35 |
| test | 19 |
| other | 17 |

#### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]

#### services

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

#### test

- `CraftModuleIntegrationTest` — `backend/tests/test_craft_module_integration.py` — [uses]
- `FirstArticleScanReviewApiTest` — `backend/tests/test_first_article_scan_review_api.py` — [uses]
- `MessageModuleIntegrationTest` — `backend/tests/test_message_module_integration.py` — [uses]
- `PerfProductionCraftSamplesIntegrationTest` — `backend/tests/test_perf_production_craft_samples_integration.py` — [uses]
- `PerfSampleSeedServiceUnitTest` — `backend/tests/test_perf_sample_seed_service_unit.py` — [uses]
- `ProductionModuleIntegrationTest` — `backend/tests/test_production_module_integration.py` — [uses]
- `ProductModuleIntegrationTest` — `backend/tests/test_product_module_integration.py` — [uses]
- `QualityModuleIntegrationTest` — `backend/tests/test_quality_module_integration.py` — [uses]
- `WriteGateRunResult` — `backend/tests/test_write_gate_integration.py` — [uses]
- `NoOpSampleHandler` — `backend/tests/test_write_gate_integration.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `SmokeContext` — `tools/docker_backend_smoke.py` — [uses]
- `NoOpSampleHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `BaselineOrderCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeStageDeleteReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeOrderReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessRuntimeReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]


## Role

- 主节点标签: `Role`
- 主节点文件: `backend\app\models\role.py`
- 域: `authz`

### 图谱关联 (59 条直接边)

| 层级 | 数量 |
|---|---|
| models | 2 |
| services | 19 |
| test | 22 |
| other | 16 |

#### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]

#### services

- `RedisError` — `backend/app/services/authz_service.py` — [uses]
- `PermissionCatalogRow` — `backend/app/services/authz_service.py` — [uses]
- `AuthzRevisionConflictError` — `backend/app/services/authz_service.py` — [uses]
- `SeedResult` — `backend/app/services/bootstrap_seed_service.py` — [uses]
- `MaintenanceAutoGenerateTrace` — `backend/app/services/equipment_service.py` — [uses]
- `_MessageSourceRegistryEntry` — `backend/app/services/message_service.py` — [uses]
- `PerfUserPoolSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserAccountSpec` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `PerfUserSeedResult` — `backend/app/services/perf_user_seed_service.py` — [uses]
- `SessionStatusSnapshot` — `backend/app/services/session_service.py` — [uses]

#### test

- `_FakeScalarResult` — `backend/tests/test_bootstrap_seed_service_unit.py` — [uses]
- `BootstrapSeedServiceUnitTest` — `backend/tests/test_bootstrap_seed_service_unit.py` — [uses]
- `EquipmentModuleIntegrationTest` — `backend/tests/test_equipment_module_integration.py` — [uses]
- `FirstArticleScanReviewApiTest` — `backend/tests/test_first_article_scan_review_api.py` — [uses]
- `MessageModuleIntegrationTest` — `backend/tests/test_message_module_integration.py` — [uses]
- `_FakeScalarResult` — `backend/tests/test_perf_user_seed_service_unit.py` — [uses]
- `PerfUserSeedServiceUnitTest` — `backend/tests/test_perf_user_seed_service_unit.py` — [uses]
- `ProductionModuleIntegrationTest` — `backend/tests/test_production_module_integration.py` — [uses]
- `QualityModuleIntegrationTest` — `backend/tests/test_quality_module_integration.py` — [uses]
- `BaseAPITestCase` — `backend/tests/test_ui_home_dashboard_integration.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `NoOpSampleHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `BaselineOrderCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeStageDeleteReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeOrderReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessRuntimeReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `SystemMasterTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]


## Product

- 主节点标签: `Product`
- 主节点文件: `backend\app\models\product.py`
- 域: `product`

### 图谱关联 (65 条直接边)

| 层级 | 数量 |
|---|---|
| models | 2 |
| services | 31 |
| test | 16 |
| other | 16 |

#### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]

#### services

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

#### test

- `CraftModuleIntegrationTest` — `backend/tests/test_craft_module_integration.py` — [uses]
- `FirstArticleScanReviewApiTest` — `backend/tests/test_first_article_scan_review_api.py` — [uses]
- `MessageModuleIntegrationTest` — `backend/tests/test_message_module_integration.py` — [uses]
- `ProductionModuleIntegrationTest` — `backend/tests/test_production_module_integration.py` — [uses]
- `ProductModuleIntegrationTest` — `backend/tests/test_product_module_integration.py` — [uses]
- `QualityModuleIntegrationTest` — `backend/tests/test_quality_module_integration.py` — [uses]
- `WriteGateRunResult` — `backend/tests/test_write_gate_integration.py` — [uses]
- `NoOpSampleHandler` — `backend/tests/test_write_gate_integration.py` — [uses]
- `ProductionOrderCreateSampleHandler` — `backend/tests/test_write_gate_integration.py` — [uses]
- `SupplierCreateSampleHandler` — `backend/tests/test_write_gate_integration.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `NoOpSampleHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `BaselineOrderCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeStageDeleteReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeOrderReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessRuntimeReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `SystemMasterTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]


## Process

- 主节点标签: `Process`
- 主节点文件: `backend\app\models\process.py`
- 域: `craft`

### 图谱关联 (69 条直接边)

| 层级 | 数量 |
|---|---|
| models | 2 |
| services | 33 |
| test | 18 |
| other | 16 |

#### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]

#### services

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

#### test

- `CraftModuleIntegrationTest` — `backend/tests/test_craft_module_integration.py` — [uses]
- `EquipmentModuleIntegrationTest` — `backend/tests/test_equipment_module_integration.py` — [uses]
- `FirstArticleScanReviewApiTest` — `backend/tests/test_first_article_scan_review_api.py` — [uses]
- `MessageModuleIntegrationTest` — `backend/tests/test_message_module_integration.py` — [uses]
- `PerfSampleSeedServiceUnitTest` — `backend/tests/test_perf_sample_seed_service_unit.py` — [uses]
- `_FakeScalarResult` — `backend/tests/test_perf_user_seed_service_unit.py` — [uses]
- `PerfUserSeedServiceUnitTest` — `backend/tests/test_perf_user_seed_service_unit.py` — [uses]
- `ProductionModuleIntegrationTest` — `backend/tests/test_production_module_integration.py` — [uses]
- `QualityModuleIntegrationTest` — `backend/tests/test_quality_module_integration.py` — [uses]
- `WriteGateRunResult` — `backend/tests/test_write_gate_integration.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `NoOpSampleHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `BaselineOrderCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeStageDeleteReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeOrderReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessRuntimeReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `SystemMasterTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]


## QualityInspection

> 图谱中未找到 `QualityInspection` 节点

## AppSession

- 主节点标签: `AppSession`
- 主节点文件: `frontend\lib\core\models\app_session.dart`
- 域: `frontend-core`

### 图谱关联 (0 条直接边)


### 导航补充链路 [导航推断，非原始图边]

- [后端数据模型] `AppSession` — `frontend/lib/core/models/app_session.dart`
- [前端 Model] `AppSession` — `frontend/lib/core/models/app_session.dart`
- [测试覆盖] `AppSession` — `frontend/test/widgets/product_module_issue_regression_test.dart`
- [测试覆盖] `AppSession` — `frontend/test/widgets/product_module_second_wave_guard_test.dart`
- [测试覆盖] `AppSession` — `frontend/test/widgets/product_page_test.dart`


## User

- 主节点标签: `User`
- 主节点文件: `backend\app\models\user.py`
- 域: `authz`

### 图谱关联 (96 条直接边)

| 层级 | 数量 |
|---|---|
| models | 2 |
| services | 57 |
| api | 1 |
| test | 19 |
| other | 17 |

#### models

- `Base` — `backend/app/models/base.py` — [uses]
- `TimestampMixin` — `backend/app/models/base.py` — [uses]

#### services

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

#### api

- `WebSocket 实时消息推送端点，通过首条 JSON 消息中的 token 鉴权` — `backend/app/api/v1/endpoints/messages.py` — [uses]

#### test

- `CraftModuleIntegrationTest` — `backend/tests/test_craft_module_integration.py` — [uses]
- `EquipmentModuleIntegrationTest` — `backend/tests/test_equipment_module_integration.py` — [uses]
- `FirstArticleScanReviewApiTest` — `backend/tests/test_first_article_scan_review_api.py` — [uses]
- `MessageModuleIntegrationTest` — `backend/tests/test_message_module_integration.py` — [uses]
- `PerfSampleSeedServiceUnitTest` — `backend/tests/test_perf_sample_seed_service_unit.py` — [uses]
- `ProductionModuleIntegrationTest` — `backend/tests/test_production_module_integration.py` — [uses]
- `QualityModuleIntegrationTest` — `backend/tests/test_quality_module_integration.py` — [uses]
- `BaseAPITestCase` — `backend/tests/test_ui_home_dashboard_integration.py` — [uses]
- `TestUiHomeDashboardIntegration` — `backend/tests/test_ui_home_dashboard_integration.py` — [uses]
- `UserModuleIntegrationTest` — `backend/tests/test_user_module_integration.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `SmokeContext` — `tools/docker_backend_smoke.py` — [uses]
- `NoOpSampleHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `BaselineOrderCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeTemplateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeStageDeleteReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `RuntimeOrderReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessCreateReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]
- `CraftProcessRuntimeReadyHandler` — `tools/perf/write_gate/sample_registry.py` — [uses]

