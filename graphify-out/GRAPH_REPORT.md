# Graph Report - ZYKJ_MES (治理后)

> run_id: `a5f77bed-d5de-4b83-b5f1-d72d03f1d666`
> generated_at: 2026-05-01T16:50:54.015707+00:00
> source_commit: `5ffdf8fdeb8c7bee611f4c524a179f97df528e5d`
> curation_version: 1.0.0

## 质量摘要

- 治理前: 7642 节点 · 15125 条边
- 治理后: 6792 节点 · 13594 条边
- 已滤除节点: 850
- 已隐藏节点: 509
- 业务节点 Top20 占比: 70%
- 社区数: 170
- 社区命名覆盖率: 159/170

## Top 连接节点（治理后）

1. `success_response()` — 262 条边 — 域:`后端基础设施` — backend\app\schemas\common.py
2. `craft_service.py` — 102 条边 — 域:`工艺管理` — backend\app\services\craft_service.py
3. `authz_service.py` — 96 条边 — 域:`用户权限` — backend\app\services\authz_service.py
4. `production.py` — 93 条边 — 域:`生产执行` — backend\app\schemas\production.py
5. `ProcessStage` — 76 条边 — 域:`工艺管理` — backend\app\models\process_stage.py
6. `production_models.dart` — 75 条边 — 域:`生产执行` — frontend\lib\features\production\models\production_models.dart
7. `write_audit_log()` — 72 条边 — 域:`后端基础设施` — backend\app\services\audit_service.py
8. `product_service.py` — 70 条边 — 域:`产品管理` — backend\app\services\product_service.py
9. `User` — 69 条边 — 域:`用户权限` — backend\app\models\user.py
10. `product_parameter_management_page.dart` — 68 条边 — 域:`产品管理` — frontend\lib\features\product\presentation\product_parameter_management_page.dart
11. `process_configuration_page.dart` — 67 条边 — 域:`工艺管理` — frontend\lib\features\craft\presentation\process_configuration_page.dart
12. `craft.py` — 64 条边 — 域:`工艺管理` — backend\app\api\v1\endpoints\craft.py
13. `user_management_page.dart` — 64 条边 — 域:`用户权限` — frontend\lib\features\user\presentation\user_management_page.dart
14. `production_order_service.py` — 63 条边 — 域:`生产执行` — backend\app\services\production_order_service.py
15. `equipment_service.py` — 62 条边 — 域:`设备管理` — backend\app\services\equipment_service.py
16. `production.py` — 61 条边 — 域:`生产执行` — backend\app\api\v1\endpoints\production.py
17. `Base` — 61 条边 — 域:`后端基础设施` — backend\app\models\base.py
18. `craft.py` — 61 条边 — 域:`工艺管理` — backend\app\schemas\craft.py
19. `ProductProcessTemplate` — 59 条边 — 域:`产品管理` — backend\app\models\product_process_template.py
20. `product_management_page.dart` — 57 条边 — 域:`产品管理` — frontend\lib\features\product\presentation\product_management_page.dart

## 社区导航（治理后）

| 社区编号 | 业务名称 | 主域 | 节点数 |
|---|---|---|---|
| 0 | 设备管理 - ListTile | 设备管理 | 774 |
| 1 | 测试模块 - CraftStageListResult | 测试模块 | 622 |
| 2 | 测试模块 - ServerTimeSnapshot | 测试模块 | 513 |
| 3 | 产品管理 - ProductItem | 产品管理 | 421 |
| 4 | 测试模块 - TimestampMixin | 测试模块 | 470 |
| 5 | 工艺管理 - craft.py | 工艺管理 | 417 |
| 6 | 生产执行 - system.py | 生产执行 | 309 |
| 7 | 用户权限 - list_online_user_ids() | 用户权限 | 223 |
| 8 | 设备管理 - EquipmentLedgerListResult | 设备管理 | 213 |
| 9 | 用户权限 - jsonDecode | 用户权限 | 207 |
| 10 | 用户权限 - AuthzSnapshotResult | 用户权限 | 212 |
| 11 | 工艺管理 - craft_kanban_page.dart | 工艺管理 | 134 |
| 12 | 产品管理 - ProductListResult | 产品管理 | 171 |
| 13 | 生产执行 - recode process codes by stage  Revision ID: e7b9c1d2a3f4 Revises: c4f7d9e2a1b3 C | 生产执行 | 156 |
| 14 | 测试模块 - dirExists | 测试模块 | 132 |
| 15 | 消息推送 - AnnouncementPublishResult | 消息推送 | 148 |
| 16 | 基础设施 - CombinedAuthScenarioSuiteUnitTest | 基础设施 | 138 |
| 17 | 工艺管理 - Divider | 工艺管理 | 79 |
| 18 | 产品管理 - get_product_parameter_versions() | 产品管理 | 76 |
| 19 | 工艺管理 - process_configuration_page.dart | 工艺管理 | 74 |
| 20 | 用户权限 - UserModuleTableShell | 用户权限 | 72 |
| 21 | 生产执行 - FirstArticleTemplateListResult | 生产执行 | 68 |
| 22 | 质量管理 - DefectAnalysisResult | 质量管理 | 74 |
| 23 | 测试模块 - daily_verification_code.py | 测试模块 | 61 |
| 24 | 消息推送 - ClipRect | 消息推送 | 41 |
| 25 | 测试模块 - decode_access_token() | 测试模块 | 50 |
| 26 | 工艺管理 - CraftProcessLightListResult | 工艺管理 | 50 |
| 27 | 测试模块 - 模块 | 测试模块 | 35 |
| 28 | 用户权限 - function_permission_config_page.dart | 用户权限 | 29 |
| 29 | 测试模块 - AuthzServiceUnitTest | 测试模块 | 32 |
| 30 | 测试模块 - ProductModuleIntegrationTest | 测试模块 | 32 |
| 31 | 测试模块 - load_perf_sample_context() | 测试模块 | 31 |
| 32 | 未分类模块 32 | unknown | 29 |
| 33 | 后端基础设施 - HomeDashboardTodoSummary | 后端基础设施 | 28 |
| 34 | 插件系统 - first_article_review_page.py | 插件系统 | 25 |
| 35 | 测试模块 - FirstArticleScanReviewApiTest | 测试模块 | 22 |
| 36 | 基础设施 - project_toolkit.py | 基础设施 | 22 |
| 37 | 未分类模块 37 | unknown | 21 |
| 38 | 测试模块 - StartBackendScriptUnitTest | 测试模块 | 20 |
| 39 | 测试模块 - SessionServiceUnitTest | 测试模块 | 18 |
| 40 | 插件系统 - serial_bridge.py | 插件系统 | 15 |
| 41 | 测试模块 - MeEndpointUnitTest | 测试模块 | 13 |
| 42 | 后端基础设施 - build_parser() | 后端基础设施 | 12 |
| 43 | 消息推送 - Material | 消息推送 | 9 |
| 44 | 未分类模块 44 | unknown | 11 |
| 45 | 未分类模块 45 | unknown | 11 |
| 46 | 未分类模块 46 | unknown | 11 |
| 47 | 测试模块 - PerfProductionCraftSamplesIntegrationTest | 测试模块 | 10 |
| 48 | 测试模块 - ApiDepsUnitTest | 测试模块 | 9 |
| 49 | 测试模块 - AuthEndpointUnitTest | 测试模块 | 9 |
| 50 | 测试模块 - ListQueryOptimizationUnitTest | 测试模块 | 9 |
| 51 | 测试模块 - PerfCapacityPermissionServiceUnitTest | 测试模块 | 9 |
| 52 | 用户权限 - authz_cache_service.py | 用户权限 | 8 |
| 53 | 测试模块 - SecurityUnitTest | 测试模块 | 8 |
| 54 | 消息推送 - 模块 | 消息推送 | 4 |
| 55 | 测试模块 - DbSessionConfigUnitTest | 测试模块 | 7 |
| 56 | 测试模块 - DockerBackendSmokeUnitTest | 测试模块 | 7 |
| 57 | 测试模块 - PageCatalogUnitTest | 测试模块 | 7 |
| 58 | 前端基础设施 - mes_radius.dart | 前端基础设施 | 7 |
| 59 | 数据库迁移 - 9b2c3d4e_add_product_parameter_description_and_history_snapshots.py | 数据库迁移 | 6 |
| 60 | 数据库迁移 - add version_label to product revision  Revision ID: a1b2c3d4e5f6 Revises: 9b2c3d | 数据库迁移 | 6 |
| 61 | 数据库迁移 - c9d8e7f6a5b4_add_product_lifecycle_and_versions.py | 数据库迁移 | 6 |
| 62 | 数据库迁移 - o6p7q8r9s0t1_add_craft_template_tracking_and_step_fields.py | 数据库迁移 | 6 |
| 63 | 测试模块 - AuthzEndpointUnitTest | 测试模块 | 6 |
| 64 | 测试模块 - StartFrontendScriptUnitTest | 测试模块 | 6 |
| 65 | 未分类模块 65 | unknown | 6 |
| 66 | 数据库迁移 - c4f7d9e2a1b3_reconcile_system_master_template_schema.py | 数据库迁移 | 5 |
| 67 | 数据库迁移 - f1c2d3e4b5a6_add_template_lifecycle_versions_and_capacity.py | 数据库迁移 | 5 |
| 68 | 后端基础设施 - equipment_process.py | 后端基础设施 | 5 |
| 69 | 测试模块 - AppStartupWorkerSplitUnitTest | 测试模块 | 5 |
| 70 | 前端基础设施 - plugin_manifest.dart | 前端基础设施 | 5 |
| 71 | 数据库迁移 - 0998ac4f196a_merge_heads.py | 数据库迁移 | 4 |
| 72 | 数据库迁移 - 142349cbdee9_add_process_and_user_process_mapping.py | 数据库迁移 | 4 |
| 73 | 数据库迁移 - 1f4c2e6a9b10_update_equipment_code_and_name_uniqueness.py | 数据库迁移 | 4 |
| 74 | 数据库迁移 - 4d2f8a7b9c31_add_production_module_v1_tables.py | 数据库迁移 | 4 |
| 75 | 数据库迁移 - 7e4b2c1d_add_product_category_field.py | 数据库迁移 | 4 |
| 76 | 数据库迁移 - 8a1b2c3d_narrow_product_lifecycle_statuses.py | 数据库迁移 | 4 |
| 77 | 数据库迁移 - 91b7c6da4f20_add_registration_request_table.py | 数据库迁移 | 4 |
| 78 | 数据库迁移 - 9c2a4d6e8f11_make_work_order_plan_nullable_set_null.py | 数据库迁移 | 4 |
| 79 | 数据库迁移 - add authz module revision table  Revision ID: a1c3e5f7b9d2 Revises: f2b3c4d5e6f7 | 数据库迁移 | 4 |
| 80 | 数据库迁移 - a8b7c6d5e4f3_add_craft_module_v1_schema_and_reset_production.py | 数据库迁移 | 4 |
| 81 | 数据库迁移 - a9e6c1f4d2b7_drop_template_standard_capacity_fields.py | 数据库迁移 | 4 |
| 82 | 数据库迁移 - ab3f6d1e4c22_make_work_order_item_nullable_set_null.py | 数据库迁移 | 4 |
| 83 | 数据库迁移 - b1a2c3d4e5f6_add_craft_system_master_template_tables.py | 数据库迁移 | 4 |
| 84 | 数据库迁移 - add remark to mes_product  Revision ID: b2c3d4e5f6a7 Revises: a1b2c3d4e5f6 Creat | 数据库迁移 | 4 |
| 85 | 数据库迁移 - add production assist authorization table  Revision ID: b2f4e8a1c9d0 Revises: c9 | 数据库迁移 | 4 |
| 86 | 数据库迁移 - b7c8d9e0f1a2_add_equipment_module_tables.py | 数据库迁移 | 4 |
| 87 | 数据库迁移 - bc4d7e2f913a_make_work_order_equipment_nullable_set_null.py | 数据库迁移 | 4 |
| 88 | 数据库迁移 - add product tables  Revision ID: c3d9f7a1b2e4 Revises: e8f2b1c4d9a3 Create Date: | 数据库迁移 | 4 |
| 89 | 数据库迁移 - add is_deleted to sys_role  Revision ID: c3e5f7a9b1d2 Revises: b2c3d4e5f6a7 Crea | 数据库迁移 | 4 |
| 90 | 数据库迁移 - c4e6f8a1b2d3_sunset_page_visibility_add_authz_audit.py | 数据库迁移 | 4 |
| 91 | 数据库迁移 - c5d6e7f8a9b0_add_remark_and_standard_desc_fields.py | 数据库迁移 | 4 |
| 92 | 数据库迁移 - d15a9c4b7e32_add_work_order_snapshot_fields.py | 数据库迁移 | 4 |
| 93 | 数据库迁移 - d3a7b4c9e2f1_add_order_pipeline_mode_schema.py | 数据库迁移 | 4 |
| 94 | 数据库迁移 - add first_article_disposition table  Revision ID: d4e6f8a2b1c3 Revises: c3e5f7a9 | 数据库迁移 | 4 |
| 95 | 数据库迁移 - add page visibility table  Revision ID: d4e7a6b9c1f2 Revises: 91b7c6da4f20 Creat | 数据库迁移 | 4 |
| 96 | 数据库迁移 - d5e6f7a8b9c0_add_is_deleted_to_product.py | 数据库迁移 | 4 |
| 97 | 数据库迁移 - da2ddcd5aa2d_init_auth_and_user_tables.py | 数据库迁移 | 4 |
| 98 | 数据库迁移 - e1b2c3d4f5a6_add_repair_and_scrap_schema.py | 数据库迁移 | 4 |
| 99 | 数据库迁移 - e42f8a6c1d73_create_maintenance_record_table.py | 数据库迁移 | 4 |
| 100 | 数据库迁移 - e5f6a7b8c9d0_add_message_tables.py | 数据库迁移 | 4 |
| 101 | 数据库迁移 - e8f2b1c4d9a3_drop_permission_tables.py | 数据库迁移 | 4 |
| 102 | 数据库迁移 - f2b3c4d5e6f7_add_authz_permission_domain_tables.py | 数据库迁移 | 4 |
| 103 | 数据库迁移 - f3d4e5a6b7c8_upgrade_user_module_v1_schema.py | 数据库迁移 | 4 |
| 104 | 数据库迁移 - f6a1d2c3b4e5_upgrade_product_parameter_schema.py | 数据库迁移 | 4 |
| 105 | 数据库迁移 - f6a7b8c9d0e1_add_first_article_disposition_history.py | 数据库迁移 | 4 |
| 106 | 数据库迁移 - f94b1c2d3e45_add_execution_process_to_maintenance.py | 数据库迁移 | 4 |
| 107 | 数据库迁移 - g7b8c9d0e1f2_add_change_type_to_parameter_history.py | 数据库迁移 | 4 |
| 108 | 数据库迁移 - h1i2j3k4l5m6_add_equipment_rule_and_runtime_parameter.py | 数据库迁移 | 4 |
| 109 | 数据库迁移 - i1j2k3l4m5n6_add_craft_remark_and_stage_name_unique.py | 数据库迁移 | 4 |
| 110 | 数据库迁移 - j2k3l4m5n6o7_add_system_master_template_revision_tables.py | 数据库迁移 | 4 |
| 111 | 数据库迁移 - k3l4m5n6o7p8_enforce_single_role_per_user.py | 数据库迁移 | 4 |
| 112 | 数据库迁移 - m4n5o6p7q8r9_add_product_revision_parameter_table.py | 数据库迁移 | 4 |
| 113 | 数据库迁移 - n2o3p4q5r6s7_make_pipeline_sub_order_nullable.py | 数据库迁移 | 4 |
| 114 | 数据库迁移 - p7q8r9s0t1u2_preserve_production_order_event_logs.py | 数据库迁移 | 4 |
| 115 | 数据库迁移 - q8r9s0t1u2v3_extend_equipment_rule_and_parameter_state.py | 数据库迁移 | 4 |
| 116 | 数据库迁移 - r9s0t1u2v3w4_add_equipment_scope_fields.py | 数据库迁移 | 4 |
| 117 | 数据库迁移 - s0t1u2v3w4x5_add_operator_to_scrap_statistics.py | 数据库迁移 | 4 |
| 118 | 数据库迁移 - t1u2v3w4x5y6_harden_message_delivery_and_dedupe.py | 数据库迁移 | 4 |
| 119 | 数据库迁移 - u2v3w4x5y6z_add_execution_process_snapshot_to_maintenance_record.py | 数据库迁移 | 4 |
| 120 | 数据库迁移 - u7v8w9x0y1z2_drop_step_minutes_and_remark_fields.py | 数据库迁移 | 4 |
| 121 | 数据库迁移 - v3w4x5y6z7a_add_pipeline_link_and_repair_record_trace.py | 数据库迁移 | 4 |
| 122 | 数据库迁移 - v4x5y6z7a8b_drop_is_key_process_from_craft_steps.py | 数据库迁移 | 4 |
| 123 | 数据库迁移 - w6x7y8z9a0b_add_supplier_master_and_order_snapshot.py | 数据库迁移 | 4 |
| 124 | 数据库迁移 - x1y2z3a4b5c6_add_first_article_rich_form_schema.py | 数据库迁移 | 4 |
| 125 | 数据库迁移 - y7z8a9b0c1d2_add_user_export_task_table.py | 数据库迁移 | 4 |
| 126 | 数据库迁移 - z8a9b0c1d2e3_add_first_article_review_session.py | 数据库迁移 | 4 |
| 127 | 测试模块 - MaintenanceSchedulerServiceUnitTest | 测试模块 | 4 |
| 128 | 测试模块 - SystemTimeEndpointUnitTest | 测试模块 | 4 |
| 129 | 前端基础设施 - software_settings_models.dart | 前端基础设施 | 4 |
| 130 | 后端基础设施 - session.py | 后端基础设施 | 3 |
| 131 | 测试模块 - 模块 | 测试模块 | 3 |
| 132 | 测试模块 - ProductionExecutionServiceUnitTest | 测试模块 | 3 |
| 133 | 测试模块 - StartupBootstrapUnitTest | 测试模块 | 3 |
| 134 | 前端基础设施 - api_exception.dart | 前端基础设施 | 3 |
| 135 | 前端基础设施 - plugin_host_view_state.dart | 前端基础设施 | 3 |
| 136 | 前端基础设施 - time_sync_models.dart | 前端基础设施 | 3 |
| 137 | 后端基础设施 - API endpoint modules. | 后端基础设施 | 2 |
| 138 | 后端基础设施 - Application startup bootstrap helpers. | 后端基础设施 | 2 |
| 139 | 后端基础设施 - product_parameter_template.py | 后端基础设施 | 2 |
| 140 | 后端基础设施 - Core settings and shared utilities. | 后端基础设施 | 2 |
| 141 | 后端基础设施 - 模块 | 后端基础设施 | 2 |
| 142 | 后端基础设施 - Pydantic schema package. | 后端基础设施 | 2 |
| 143 | 未分类模块 143 | unknown | 2 |
| 144 | 前端基础设施 - current_user.dart | 前端基础设施 | 2 |
| 145 | 插件系统 - 模块 | 插件系统 | 2 |
| 146 | 基础设施 - Performance tooling helpers. | 基础设施 | 2 |
| 147 | unknown - 模块 | unknown | 1 |
| 148 | 后端基础设施 - 模块 | 后端基础设施 | 1 |
| 149 | 后端基础设施 - api.py | 后端基础设施 | 1 |
| 150 | 后端基础设施 - 模块 | 后端基础设施 | 1 |
| 151 | 后端基础设施 - product_lifecycle.py | 后端基础设施 | 1 |
| 152 | 后端基础设施 - rbac.py | 后端基础设施 | 1 |
| 153 | 后端基础设施 - base.py | 后端基础设施 | 1 |
| 154 | 后端基础设施 - associations.py | 后端基础设施 | 1 |
| 155 | 后端基础设施 - 模块 | 后端基础设施 | 1 |
| 156 | 后端基础设施 - 模块 | 后端基础设施 | 1 |
| 157 | unknown - 模块 | unknown | 1 |
| 158 | 前端基础设施 - runtime_endpoints.dart | 前端基础设施 | 1 |
| 159 | 设备管理 - maintenance_category_options.dart | 设备管理 | 1 |
| 160 | 产品管理 - product_category_options.dart | 产品管理 | 1 |
| 161 | 未分类模块 161 | unknown | 1 |
| 162 | 未分类模块 162 | unknown | 1 |
| 163 | 未分类模块 163 | unknown | 1 |
| 164 | 未分类模块 164 | unknown | 1 |
| 165 | 插件系统 - 模块 | 插件系统 | 1 |
| 166 | 插件系统 - launcher.py | 插件系统 | 1 |
| 167 | 插件系统 - 模块 | 插件系统 | 1 |
| 168 | 插件系统 - 模块 | 插件系统 | 1 |
| 169 | 基础设施 - vendor_plugin_deps.ps1 | 基础设施 | 1 |

## 原社区编号 -> 业务名称映射

| 原编号 | 业务名称 |
|---|---|
| Community 0 | 设备管理 - ListTile |
| Community 1 | 测试模块 - CraftStageListResult |
| Community 2 | 测试模块 - ServerTimeSnapshot |
| Community 3 | 产品管理 - ProductItem |
| Community 4 | 测试模块 - TimestampMixin |
| Community 5 | 工艺管理 - craft.py |
| Community 6 | 生产执行 - system.py |
| Community 7 | 用户权限 - list_online_user_ids() |
| Community 8 | 设备管理 - EquipmentLedgerListResult |
| Community 9 | 用户权限 - jsonDecode |
| Community 10 | 用户权限 - AuthzSnapshotResult |
| Community 11 | 工艺管理 - craft_kanban_page.dart |
| Community 12 | 产品管理 - ProductListResult |
| Community 13 | 生产执行 - recode process codes by stage  Revision ID: e7b9c1d2a3f4 Revises: c4f7d9e2a1b3 C |
| Community 14 | 测试模块 - dirExists |
| Community 15 | 消息推送 - AnnouncementPublishResult |
| Community 16 | 基础设施 - CombinedAuthScenarioSuiteUnitTest |
| Community 17 | 工艺管理 - Divider |
| Community 18 | 产品管理 - get_product_parameter_versions() |
| Community 19 | 工艺管理 - process_configuration_page.dart |
| Community 20 | 用户权限 - UserModuleTableShell |
| Community 21 | 生产执行 - FirstArticleTemplateListResult |
| Community 22 | 质量管理 - DefectAnalysisResult |
| Community 23 | 测试模块 - daily_verification_code.py |
| Community 24 | 消息推送 - ClipRect |
| Community 25 | 测试模块 - decode_access_token() |
| Community 26 | 工艺管理 - CraftProcessLightListResult |
| Community 27 | 测试模块 - 模块 |
| Community 28 | 用户权限 - function_permission_config_page.dart |
| Community 29 | 测试模块 - AuthzServiceUnitTest |
| Community 30 | 测试模块 - ProductModuleIntegrationTest |
| Community 31 | 测试模块 - load_perf_sample_context() |
| Community 32 | 未分类模块 32 |
| Community 33 | 后端基础设施 - HomeDashboardTodoSummary |
| Community 34 | 插件系统 - first_article_review_page.py |
| Community 35 | 测试模块 - FirstArticleScanReviewApiTest |
| Community 36 | 基础设施 - project_toolkit.py |
| Community 37 | 未分类模块 37 |
| Community 38 | 测试模块 - StartBackendScriptUnitTest |
| Community 39 | 测试模块 - SessionServiceUnitTest |
| Community 40 | 插件系统 - serial_bridge.py |
| Community 41 | 测试模块 - MeEndpointUnitTest |
| Community 42 | 后端基础设施 - build_parser() |
| Community 43 | 消息推送 - Material |
| Community 44 | 未分类模块 44 |
| Community 45 | 未分类模块 45 |
| Community 46 | 未分类模块 46 |
| Community 47 | 测试模块 - PerfProductionCraftSamplesIntegrationTest |
| Community 48 | 测试模块 - ApiDepsUnitTest |
| Community 49 | 测试模块 - AuthEndpointUnitTest |
| Community 50 | 测试模块 - ListQueryOptimizationUnitTest |
| Community 51 | 测试模块 - PerfCapacityPermissionServiceUnitTest |
| Community 52 | 用户权限 - authz_cache_service.py |
| Community 53 | 测试模块 - SecurityUnitTest |
| Community 54 | 消息推送 - 模块 |
| Community 55 | 测试模块 - DbSessionConfigUnitTest |
| Community 56 | 测试模块 - DockerBackendSmokeUnitTest |
| Community 57 | 测试模块 - PageCatalogUnitTest |
| Community 58 | 前端基础设施 - mes_radius.dart |
| Community 59 | 数据库迁移 - 9b2c3d4e_add_product_parameter_description_and_history_snapshots.py |
| Community 60 | 数据库迁移 - add version_label to product revision  Revision ID: a1b2c3d4e5f6 Revises: 9b2c3d |
| Community 61 | 数据库迁移 - c9d8e7f6a5b4_add_product_lifecycle_and_versions.py |
| Community 62 | 数据库迁移 - o6p7q8r9s0t1_add_craft_template_tracking_and_step_fields.py |
| Community 63 | 测试模块 - AuthzEndpointUnitTest |
| Community 64 | 测试模块 - StartFrontendScriptUnitTest |
| Community 65 | 未分类模块 65 |
| Community 66 | 数据库迁移 - c4f7d9e2a1b3_reconcile_system_master_template_schema.py |
| Community 67 | 数据库迁移 - f1c2d3e4b5a6_add_template_lifecycle_versions_and_capacity.py |
| Community 68 | 后端基础设施 - equipment_process.py |
| Community 69 | 测试模块 - AppStartupWorkerSplitUnitTest |
| Community 70 | 前端基础设施 - plugin_manifest.dart |
| Community 71 | 数据库迁移 - 0998ac4f196a_merge_heads.py |
| Community 72 | 数据库迁移 - 142349cbdee9_add_process_and_user_process_mapping.py |
| Community 73 | 数据库迁移 - 1f4c2e6a9b10_update_equipment_code_and_name_uniqueness.py |
| Community 74 | 数据库迁移 - 4d2f8a7b9c31_add_production_module_v1_tables.py |
| Community 75 | 数据库迁移 - 7e4b2c1d_add_product_category_field.py |
| Community 76 | 数据库迁移 - 8a1b2c3d_narrow_product_lifecycle_statuses.py |
| Community 77 | 数据库迁移 - 91b7c6da4f20_add_registration_request_table.py |
| Community 78 | 数据库迁移 - 9c2a4d6e8f11_make_work_order_plan_nullable_set_null.py |
| Community 79 | 数据库迁移 - add authz module revision table  Revision ID: a1c3e5f7b9d2 Revises: f2b3c4d5e6f7 |
| Community 80 | 数据库迁移 - a8b7c6d5e4f3_add_craft_module_v1_schema_and_reset_production.py |
| Community 81 | 数据库迁移 - a9e6c1f4d2b7_drop_template_standard_capacity_fields.py |
| Community 82 | 数据库迁移 - ab3f6d1e4c22_make_work_order_item_nullable_set_null.py |
| Community 83 | 数据库迁移 - b1a2c3d4e5f6_add_craft_system_master_template_tables.py |
| Community 84 | 数据库迁移 - add remark to mes_product  Revision ID: b2c3d4e5f6a7 Revises: a1b2c3d4e5f6 Creat |
| Community 85 | 数据库迁移 - add production assist authorization table  Revision ID: b2f4e8a1c9d0 Revises: c9 |
| Community 86 | 数据库迁移 - b7c8d9e0f1a2_add_equipment_module_tables.py |
| Community 87 | 数据库迁移 - bc4d7e2f913a_make_work_order_equipment_nullable_set_null.py |
| Community 88 | 数据库迁移 - add product tables  Revision ID: c3d9f7a1b2e4 Revises: e8f2b1c4d9a3 Create Date: |
| Community 89 | 数据库迁移 - add is_deleted to sys_role  Revision ID: c3e5f7a9b1d2 Revises: b2c3d4e5f6a7 Crea |
| Community 90 | 数据库迁移 - c4e6f8a1b2d3_sunset_page_visibility_add_authz_audit.py |
| Community 91 | 数据库迁移 - c5d6e7f8a9b0_add_remark_and_standard_desc_fields.py |
| Community 92 | 数据库迁移 - d15a9c4b7e32_add_work_order_snapshot_fields.py |
| Community 93 | 数据库迁移 - d3a7b4c9e2f1_add_order_pipeline_mode_schema.py |
| Community 94 | 数据库迁移 - add first_article_disposition table  Revision ID: d4e6f8a2b1c3 Revises: c3e5f7a9 |
| Community 95 | 数据库迁移 - add page visibility table  Revision ID: d4e7a6b9c1f2 Revises: 91b7c6da4f20 Creat |
| Community 96 | 数据库迁移 - d5e6f7a8b9c0_add_is_deleted_to_product.py |
| Community 97 | 数据库迁移 - da2ddcd5aa2d_init_auth_and_user_tables.py |
| Community 98 | 数据库迁移 - e1b2c3d4f5a6_add_repair_and_scrap_schema.py |
| Community 99 | 数据库迁移 - e42f8a6c1d73_create_maintenance_record_table.py |
| Community 100 | 数据库迁移 - e5f6a7b8c9d0_add_message_tables.py |
| Community 101 | 数据库迁移 - e8f2b1c4d9a3_drop_permission_tables.py |
| Community 102 | 数据库迁移 - f2b3c4d5e6f7_add_authz_permission_domain_tables.py |
| Community 103 | 数据库迁移 - f3d4e5a6b7c8_upgrade_user_module_v1_schema.py |
| Community 104 | 数据库迁移 - f6a1d2c3b4e5_upgrade_product_parameter_schema.py |
| Community 105 | 数据库迁移 - f6a7b8c9d0e1_add_first_article_disposition_history.py |
| Community 106 | 数据库迁移 - f94b1c2d3e45_add_execution_process_to_maintenance.py |
| Community 107 | 数据库迁移 - g7b8c9d0e1f2_add_change_type_to_parameter_history.py |
| Community 108 | 数据库迁移 - h1i2j3k4l5m6_add_equipment_rule_and_runtime_parameter.py |
| Community 109 | 数据库迁移 - i1j2k3l4m5n6_add_craft_remark_and_stage_name_unique.py |
| Community 110 | 数据库迁移 - j2k3l4m5n6o7_add_system_master_template_revision_tables.py |
| Community 111 | 数据库迁移 - k3l4m5n6o7p8_enforce_single_role_per_user.py |
| Community 112 | 数据库迁移 - m4n5o6p7q8r9_add_product_revision_parameter_table.py |
| Community 113 | 数据库迁移 - n2o3p4q5r6s7_make_pipeline_sub_order_nullable.py |
| Community 114 | 数据库迁移 - p7q8r9s0t1u2_preserve_production_order_event_logs.py |
| Community 115 | 数据库迁移 - q8r9s0t1u2v3_extend_equipment_rule_and_parameter_state.py |
| Community 116 | 数据库迁移 - r9s0t1u2v3w4_add_equipment_scope_fields.py |
| Community 117 | 数据库迁移 - s0t1u2v3w4x5_add_operator_to_scrap_statistics.py |
| Community 118 | 数据库迁移 - t1u2v3w4x5y6_harden_message_delivery_and_dedupe.py |
| Community 119 | 数据库迁移 - u2v3w4x5y6z_add_execution_process_snapshot_to_maintenance_record.py |
| Community 120 | 数据库迁移 - u7v8w9x0y1z2_drop_step_minutes_and_remark_fields.py |
| Community 121 | 数据库迁移 - v3w4x5y6z7a_add_pipeline_link_and_repair_record_trace.py |
| Community 122 | 数据库迁移 - v4x5y6z7a8b_drop_is_key_process_from_craft_steps.py |
| Community 123 | 数据库迁移 - w6x7y8z9a0b_add_supplier_master_and_order_snapshot.py |
| Community 124 | 数据库迁移 - x1y2z3a4b5c6_add_first_article_rich_form_schema.py |
| Community 125 | 数据库迁移 - y7z8a9b0c1d2_add_user_export_task_table.py |
| Community 126 | 数据库迁移 - z8a9b0c1d2e3_add_first_article_review_session.py |
| Community 127 | 测试模块 - MaintenanceSchedulerServiceUnitTest |
| Community 128 | 测试模块 - SystemTimeEndpointUnitTest |
| Community 129 | 前端基础设施 - software_settings_models.dart |
| Community 130 | 后端基础设施 - session.py |
| Community 131 | 测试模块 - 模块 |
| Community 132 | 测试模块 - ProductionExecutionServiceUnitTest |
| Community 133 | 测试模块 - StartupBootstrapUnitTest |
| Community 134 | 前端基础设施 - api_exception.dart |
| Community 135 | 前端基础设施 - plugin_host_view_state.dart |
| Community 136 | 前端基础设施 - time_sync_models.dart |
| Community 137 | 后端基础设施 - API endpoint modules. |
| Community 138 | 后端基础设施 - Application startup bootstrap helpers. |
| Community 139 | 后端基础设施 - product_parameter_template.py |
| Community 140 | 后端基础设施 - Core settings and shared utilities. |
| Community 141 | 后端基础设施 - 模块 |
| Community 142 | 后端基础设施 - Pydantic schema package. |
| Community 143 | 未分类模块 143 |
| Community 144 | 前端基础设施 - current_user.dart |
| Community 145 | 插件系统 - 模块 |
| Community 146 | 基础设施 - Performance tooling helpers. |
| Community 147 | unknown - 模块 |
| Community 148 | 后端基础设施 - 模块 |
| Community 149 | 后端基础设施 - api.py |
| Community 150 | 后端基础设施 - 模块 |
| Community 151 | 后端基础设施 - product_lifecycle.py |
| Community 152 | 后端基础设施 - rbac.py |
| Community 153 | 后端基础设施 - base.py |
| Community 154 | 后端基础设施 - associations.py |
| Community 155 | 后端基础设施 - 模块 |
| Community 156 | 后端基础设施 - 模块 |
| Community 157 | unknown - 模块 |
| Community 158 | 前端基础设施 - runtime_endpoints.dart |
| Community 159 | 设备管理 - maintenance_category_options.dart |
| Community 160 | 产品管理 - product_category_options.dart |
| Community 161 | 未分类模块 161 |
| Community 162 | 未分类模块 162 |
| Community 163 | 未分类模块 163 |
| Community 164 | 未分类模块 164 |
| Community 165 | 插件系统 - 模块 |
| Community 166 | 插件系统 - launcher.py |
| Community 167 | 插件系统 - 模块 |
| Community 168 | 插件系统 - 模块 |
| Community 169 | 基础设施 - vendor_plugin_deps.ps1 |

## 域分布

- 测试模块 (`tests`): 1862 节点
- 生产执行 (`production`): 734 节点
- 用户权限 (`authz`): 722 节点
- 工艺管理 (`craft`): 596 节点
- 前端基础设施 (`frontend-core`): 519 节点
- 产品管理 (`product`): 505 节点
- 设备管理 (`equipment`): 421 节点
- 后端基础设施 (`backend-core`): 334 节点
- 质量管理 (`quality`): 280 节点
- 数据库迁移 (`migrations`): 269 节点
- 消息推送 (`message`): 219 节点
- 基础设施 (`infrastructure`): 179 节点
- unknown (`unknown`): 122 节点
- 插件系统 (`plugin`): 30 节点

## 关系类型分布

- `calls`: 3849
- `defines`: 2916
- `imports`: 2595
- `contains`: 2106
- `uses`: 1277
- `method`: 617
- `inherits`: 131
- `rationale_for`: 88
- `has_many`: 7
- `has_one`: 4
- `belongs_to`: 4