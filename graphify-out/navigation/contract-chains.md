# 契约链路

> 自动生成，基于治理后图谱
> 每条链路追溯：数据模型 → 服务层 → API端点 → 前端页面 → 测试

## EquipmentLedgerItem

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_features_equipment_models_equipment_models_dart_equipmentledgeritem`
- 源文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 直接关联 (1 条边)

#### models

- `equipment_models.dart` — `frontend\lib\features\equipment\models\equipment_models.dart` — [defines]


## MaintenanceItemEntry

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_features_equipment_models_equipment_models_dart_maintenanceitementry`
- 源文件: `frontend\lib\features\equipment\models\equipment_models.dart`
- 域: `equipment`

### 直接关联 (1 条边)

#### models

- `equipment_models.dart` — `frontend\lib\features\equipment\models\equipment_models.dart` — [defines]


## ProductionOrder

- 主节点: `models_production_order_productionorder`
- 源文件: `backend\app\models\production_order.py`
- 域: `production`

### 直接关联 (52 条边)

#### models

- `Base` — `backend\app\models\base.py` — [uses]
- `TimestampMixin` — `backend\app\models\base.py` — [uses]
- `production_order.py` — `backend\app\models\production_order.py` — [contains]
- `ProductionOrderProcess` — `backend\app\models\production_order_process.py` — [has_many]
- `ProductionSubOrder` — `backend\app\models\production_sub_order.py` — [has_many]
- `ProductionRecord` — `backend\app\models\production_record.py` — [has_many]
- `ProductionScrapStatistics` — `backend\app\models\production_scrap_statistics.py` — [has_one]
- `FirstArticleRecord` — `backend\app\models\first_article_record.py` — [has_one]
- `RepairOrder` — `backend\app\models\repair_order.py` — [has_many]
- `ProductionAssistAuthorization` — `backend\app\models\production_assist_authorization.py` — [has_one]

#### services

- `SystemMasterTemplateResolveResult` — `backend\app\services\craft_service.py` — [uses]
- `TemplateSyncConflictReason` — `backend\app\services\craft_service.py` — [uses]
- `TemplateSyncResult` — `backend\app\services\craft_service.py` — [uses]
- `TemplateImpactResult` — `backend\app\services\craft_service.py` — [uses]
- `TemplateVersionCompareRow` — `backend\app\services\craft_service.py` — [uses]
- `TemplateVersionCompareResult` — `backend\app\services\craft_service.py` — [uses]
- `TemplateStepPayloadItem` — `backend\app\services\craft_service.py` — [uses]
- `TemplateStepResolvedItem` — `backend\app\services\craft_service.py` — [uses]
- `CraftKanbanSample` — `backend\app\services\craft_service.py` — [uses]
- `CraftKanbanProcessMetricsRow` — `backend\app\services\craft_service.py` — [uses]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `SmokeContext` — `tools\docker_backend_smoke.py` — [uses]


## Role

- 主节点: `backend_app_models_role_py`
- 源文件: `backend\app\models\role.py`
- 域: `authz`

### 直接关联 (1 条边)

#### models

- `Role` — `backend\app\models\role.py` — [contains]


## Product

- 主节点: `backend_app_models_product_py`
- 源文件: `backend\app\models\product.py`
- 域: `product`

### 直接关联 (1 条边)

#### models

- `Product` — `backend\app\models\product.py` — [contains]


## Process

- 主节点: `models_order_sub_order_pipeline_instance_processpipelineinstance`
- 源文件: `backend\app\models\order_sub_order_pipeline_instance.py`
- 域: `backend-core`

### 直接关联 (7 条边)

#### models

- `Base` — `backend\app\models\base.py` — [uses]
- `TimestampMixin` — `backend\app\models\base.py` — [uses]
- `order_sub_order_pipeline_instance.py` — `backend\app\models\order_sub_order_pipeline_instance.py` — [contains]

#### services

- `allocate_pipeline_instance_for_process()` — `backend\app\services\production_order_service.py` — [calls]

#### other

- `Base` — `` — [inherits]
- `TimestampMixin` — `` — [inherits]
- `ProductionModuleIntegrationTest` — `backend\tests\test_production_module_integration.py` — [uses]


## QualityInspection

> 图谱中未找到 `QualityInspection` 节点，可能已被降噪滤除或不在当前扫描范围

## AppSession

- 主节点: `c_users_donki_desktop_zykj_mes_frontend_lib_core_models_app_session_dart_appsession`
- 源文件: `frontend\lib\core\models\app_session.dart`
- 域: `frontend-core`

### 直接关联 (1 条边)

#### models

- `app_session.dart` — `frontend\lib\core\models\app_session.dart` — [defines]


## User

- 主节点: `backend_app_models_user_py`
- 源文件: `backend\app\models\user.py`
- 域: `authz`

### 直接关联 (1 条边)

#### models

- `User` — `backend\app\models\user.py` — [contains]

