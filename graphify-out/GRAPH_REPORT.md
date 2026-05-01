# Graph Report - ZYKJ_MES (治理后)

> run_id: `cf3bd2be-8c51-425f-ac1c-2ea076a11592`
> generated_at: 2026-05-01T17:09:17.643654+00:00
> source_commit: `8e566d031fa307c8008aff992eb7c31b2b1d4ac0`
> curation_version: 1.0.0

## 质量摘要

- 治理前: 7715 节点 · 15629 条边
- 治理后: 6864 节点 · 14091 条边
- 已滤除节点: 851
- 已隐藏节点: 511
- 业务节点 Top20 占比: 70%
- 社区数: 174
- 社区命名覆盖率: 163/174

## Top 连接节点（治理后）

1. `success_response()` — 262 条边 — 域:`后端基础设施` — backend\app\schemas\common.py
2. `craft_service.py` — 102 条边 — 域:`工艺管理` — backend\app\services\craft_service.py
3. `User` — 101 条边 — 域:`用户权限` — backend\app\models\user.py
4. `authz_service.py` — 96 条边 — 域:`用户权限` — backend\app\services\authz_service.py
5. `production.py` — 93 条边 — 域:`生产执行` — backend\app\schemas\production.py
6. `ProcessStage` — 76 条边 — 域:`工艺管理` — backend\app\models\process_stage.py
7. `ProductionOrder` — 76 条边 — 域:`生产执行` — backend\app\models\production_order.py
8. `ProductionOrderProcess` — 75 条边 — 域:`生产执行` — backend\app\models\production_order_process.py
9. `production_models.dart` — 75 条边 — 域:`生产执行` — frontend\lib\features\production\models\production_models.dart
10. `write_audit_log()` — 72 条边 — 域:`后端基础设施` — backend\app\services\audit_service.py
11. `Process` — 71 条边 — 域:`工艺管理` — backend\app\models\process.py
12. `product_service.py` — 70 条边 — 域:`产品管理` — backend\app\services\product_service.py
13. `Product` — 68 条边 — 域:`产品管理` — backend\app\models\product.py
14. `product_parameter_management_page.dart` — 68 条边 — 域:`产品管理` — frontend\lib\features\product\presentation\product_parameter_management_page.dart
15. `process_configuration_page.dart` — 67 条边 — 域:`工艺管理` — frontend\lib\features\craft\presentation\process_configuration_page.dart
16. `craft.py` — 64 条边 — 域:`工艺管理` — backend\app\api\v1\endpoints\craft.py
17. `Role` — 64 条边 — 域:`用户权限` — backend\app\models\role.py
18. `user_management_page.dart` — 64 条边 — 域:`用户权限` — frontend\lib\features\user\presentation\user_management_page.dart
19. `production_order_service.py` — 63 条边 — 域:`生产执行` — backend\app\services\production_order_service.py
20. `equipment_service.py` — 62 条边 — 域:`设备管理` — backend\app\services\equipment_service.py

## 社区导航（治理后）

| 社区编号 | 业务名称 | 主域 | 节点数 |
|---|---|---|---|
| 0 | 设备管理 - Spacer | 设备管理 | 728 |
| 1 | 测试支撑 - 前端基础设施 (expectLater) | 测试模块 | 826 |
| 2 | 工艺管理 - NoOpSampleHandler | 工艺管理 | 537 |
| 3 | 生产执行 - create_process_api() | 生产执行 | 481 |
| 4 | 工艺管理 - CraftStageListResult | 工艺管理 | 342 |
| 5 | 测试支撑 - 质量管理 (QualitySupplierListResult) | 测试模块 | 318 |
| 6 | 产品管理 - ProductItem | 产品管理 | 330 |
| 7 | 生产执行 - HomeDashboardTodoSummary | 生产执行 | 387 |
| 8 | 用户权限 - RoleManagementPage | 用户权限 | 312 |
| 9 | 用户权限 - AuthzSnapshotResult | 用户权限 | 249 |
| 10 | 设备管理 - EquipmentLedgerListResult | 设备管理 | 224 |
| 11 | 用户权限 - list_online_user_ids() | 用户权限 | 227 |
| 12 | 生产执行 - production_constants.py | 生产执行 | 163 |
| 13 | 基础设施 - 基础设施模块 | 基础设施 | 136 |
| 14 | 消息推送 - AnnouncementPublishResult | 消息推送 | 131 |
| 15 | 前端基础设施 - mes_theme.dart | 前端基础设施 | 72 |
| 16 | 生产执行 - FirstArticleTemplateListResult | 生产执行 | 72 |
| 17 | 用户权限 - first_article_disposition_page.dart | 用户权限 | 61 |
| 18 | 质量管理 - DefectAnalysisResult | 质量管理 | 74 |
| 19 | 设备管理 - ScrapStatisticsListResult | 设备管理 | 69 |
| 20 | 测试支撑 - 后端基础设施 (daily_verification_code.py) | 测试模块 | 61 |
| 21 | 测试支撑 - 后端基础设施 (me.py) | 测试模块 | 56 |
| 22 | 消息推送 - LayoutBuilder | 消息推送 | 41 |
| 23 | 测试支撑 - 后端基础设施 (main()) | 测试模块 | 52 |
| 24 | 基础设施 - serial_bridge.py | 基础设施 | 52 |
| 25 | 工艺管理 - craft_models.dart | 工艺管理 | 44 |
| 26 | 用户权限 - function_permission_config_page.dart | 用户权限 | 30 |
| 27 | 测试模块 - 测试模块模块 | 测试模块 | 35 |
| 28 | 测试模块 - 测试模块模块 | 测试模块 | 32 |
| 29 | 测试模块 - 测试模块模块 | 测试模块 | 32 |
| 30 | 测试模块 - 测试模块模块 | 测试模块 | 31 |
| 31 | 未分类模块 31 | unknown | 29 |
| 32 | 插件系统 - first_article_review_page.py | 插件系统 | 25 |
| 33 | 基础设施 - project_toolkit.py | 基础设施 | 22 |
| 34 | 未分类模块 34 | unknown | 21 |
| 35 | 测试模块 - 测试模块模块 | 测试模块 | 20 |
| 36 | 测试模块 - 测试模块模块 | 测试模块 | 18 |
| 37 | 测试模块 - 测试模块模块 | 测试模块 | 13 |
| 38 | 未分类模块 38 | unknown | 11 |
| 39 | 未分类模块 39 | unknown | 11 |
| 40 | 未分类模块 40 | unknown | 11 |
| 41 | 前端基础设施 - main_shell_refresh_coordinator.dart | 前端基础设施 | 10 |
| 42 | 测试模块 - 测试模块模块 | 测试模块 | 9 |
| 43 | 测试模块 - 测试模块模块 | 测试模块 | 9 |
| 44 | 测试模块 - 测试模块模块 | 测试模块 | 9 |
| 45 | 测试模块 - 测试模块模块 | 测试模块 | 9 |
| 46 | 用户权限 - authz_cache_service.py | 用户权限 | 8 |
| 47 | 测试模块 - 测试模块模块 | 测试模块 | 8 |
| 48 | 测试模块 - 测试模块模块 | 测试模块 | 7 |
| 49 | 测试模块 - 测试模块模块 | 测试模块 | 7 |
| 50 | 测试模块 - 测试模块模块 | 测试模块 | 7 |
| 51 | 测试模块 - 测试模块模块 | 测试模块 | 7 |
| 52 | 前端基础设施 - mes_radius.dart | 前端基础设施 | 7 |
| 53 | 数据库迁移 - 9b2c3d4e_add_product_parameter_description_and_history_snapshots.py | 数据库迁移 | 6 |
| 54 | 数据库迁移 - Add version_label column to mes_product_revision and backfill. | 数据库迁移 | 6 |
| 55 | 数据库迁移 - c9d8e7f6a5b4_add_product_lifecycle_and_versions.py | 数据库迁移 | 6 |
| 56 | 数据库迁移 - o6p7q8r9s0t1_add_craft_template_tracking_and_step_fields.py | 数据库迁移 | 6 |
| 57 | 测试模块 - 测试模块模块 | 测试模块 | 6 |
| 58 | 测试模块 - 测试模块模块 | 测试模块 | 6 |
| 59 | 未分类模块 59 | unknown | 6 |
| 60 | 数据库迁移 - c4f7d9e2a1b3_reconcile_system_master_template_schema.py | 数据库迁移 | 5 |
| 61 | 数据库迁移 - f1c2d3e4b5a6_add_template_lifecycle_versions_and_capacity.py | 数据库迁移 | 5 |
| 62 | 后端基础设施 - equipment_process.py | 后端基础设施 | 5 |
| 63 | 测试模块 - 测试模块模块 | 测试模块 | 5 |
| 64 | 前端基础设施 - plugin_manifest.dart | 前端基础设施 | 5 |
| 65 | 数据库迁移 - 0998ac4f196a_merge_heads.py | 数据库迁移 | 4 |
| 66 | 数据库迁移 - 142349cbdee9_add_process_and_user_process_mapping.py | 数据库迁移 | 4 |
| 67 | 数据库迁移 - 1f4c2e6a9b10_update_equipment_code_and_name_uniqueness.py | 数据库迁移 | 4 |
| 68 | 数据库迁移 - 4d2f8a7b9c31_add_production_module_v1_tables.py | 数据库迁移 | 4 |
| 69 | 数据库迁移 - 7e4b2c1d_add_product_category_field.py | 数据库迁移 | 4 |
| 70 | 数据库迁移 - 8a1b2c3d_narrow_product_lifecycle_statuses.py | 数据库迁移 | 4 |
| 71 | 数据库迁移 - 91b7c6da4f20_add_registration_request_table.py | 数据库迁移 | 4 |
| 72 | 数据库迁移 - 9c2a4d6e8f11_make_work_order_plan_nullable_set_null.py | 数据库迁移 | 4 |
| 73 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 74 | 数据库迁移 - a8b7c6d5e4f3_add_craft_module_v1_schema_and_reset_production.py | 数据库迁移 | 4 |
| 75 | 数据库迁移 - a9e6c1f4d2b7_drop_template_standard_capacity_fields.py | 数据库迁移 | 4 |
| 76 | 数据库迁移 - ab3f6d1e4c22_make_work_order_item_nullable_set_null.py | 数据库迁移 | 4 |
| 77 | 数据库迁移 - b1a2c3d4e5f6_add_craft_system_master_template_tables.py | 数据库迁移 | 4 |
| 78 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 79 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 80 | 数据库迁移 - b7c8d9e0f1a2_add_equipment_module_tables.py | 数据库迁移 | 4 |
| 81 | 数据库迁移 - bc4d7e2f913a_make_work_order_equipment_nullable_set_null.py | 数据库迁移 | 4 |
| 82 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 83 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 84 | 数据库迁移 - c4e6f8a1b2d3_sunset_page_visibility_add_authz_audit.py | 数据库迁移 | 4 |
| 85 | 数据库迁移 - c5d6e7f8a9b0_add_remark_and_standard_desc_fields.py | 数据库迁移 | 4 |
| 86 | 数据库迁移 - d15a9c4b7e32_add_work_order_snapshot_fields.py | 数据库迁移 | 4 |
| 87 | 数据库迁移 - d3a7b4c9e2f1_add_order_pipeline_mode_schema.py | 数据库迁移 | 4 |
| 88 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 89 | 数据库迁移 - 数据库迁移模块 | 数据库迁移 | 4 |
| 90 | 数据库迁移 - d5e6f7a8b9c0_add_is_deleted_to_product.py | 数据库迁移 | 4 |
| 91 | 数据库迁移 - da2ddcd5aa2d_init_auth_and_user_tables.py | 数据库迁移 | 4 |
| 92 | 数据库迁移 - e1b2c3d4f5a6_add_repair_and_scrap_schema.py | 数据库迁移 | 4 |
| 93 | 数据库迁移 - e42f8a6c1d73_create_maintenance_record_table.py | 数据库迁移 | 4 |
| 94 | 数据库迁移 - e5f6a7b8c9d0_add_message_tables.py | 数据库迁移 | 4 |
| 95 | 数据库迁移 - e8f2b1c4d9a3_drop_permission_tables.py | 数据库迁移 | 4 |
| 96 | 数据库迁移 - f2b3c4d5e6f7_add_authz_permission_domain_tables.py | 数据库迁移 | 4 |
| 97 | 数据库迁移 - f3d4e5a6b7c8_upgrade_user_module_v1_schema.py | 数据库迁移 | 4 |
| 98 | 数据库迁移 - f6a1d2c3b4e5_upgrade_product_parameter_schema.py | 数据库迁移 | 4 |
| 99 | 数据库迁移 - f6a7b8c9d0e1_add_first_article_disposition_history.py | 数据库迁移 | 4 |
| 100 | 数据库迁移 - f94b1c2d3e45_add_execution_process_to_maintenance.py | 数据库迁移 | 4 |
| 101 | 数据库迁移 - g7b8c9d0e1f2_add_change_type_to_parameter_history.py | 数据库迁移 | 4 |
| 102 | 数据库迁移 - h1i2j3k4l5m6_add_equipment_rule_and_runtime_parameter.py | 数据库迁移 | 4 |
| 103 | 数据库迁移 - i1j2k3l4m5n6_add_craft_remark_and_stage_name_unique.py | 数据库迁移 | 4 |
| 104 | 数据库迁移 - j2k3l4m5n6o7_add_system_master_template_revision_tables.py | 数据库迁移 | 4 |
| 105 | 数据库迁移 - k3l4m5n6o7p8_enforce_single_role_per_user.py | 数据库迁移 | 4 |
| 106 | 数据库迁移 - m4n5o6p7q8r9_add_product_revision_parameter_table.py | 数据库迁移 | 4 |
| 107 | 数据库迁移 - n2o3p4q5r6s7_make_pipeline_sub_order_nullable.py | 数据库迁移 | 4 |
| 108 | 数据库迁移 - p7q8r9s0t1u2_preserve_production_order_event_logs.py | 数据库迁移 | 4 |
| 109 | 数据库迁移 - q8r9s0t1u2v3_extend_equipment_rule_and_parameter_state.py | 数据库迁移 | 4 |
| 110 | 数据库迁移 - r9s0t1u2v3w4_add_equipment_scope_fields.py | 数据库迁移 | 4 |
| 111 | 数据库迁移 - s0t1u2v3w4x5_add_operator_to_scrap_statistics.py | 数据库迁移 | 4 |
| 112 | 数据库迁移 - t1u2v3w4x5y6_harden_message_delivery_and_dedupe.py | 数据库迁移 | 4 |
| 113 | 数据库迁移 - u2v3w4x5y6z_add_execution_process_snapshot_to_maintenance_record.py | 数据库迁移 | 4 |
| 114 | 数据库迁移 - u7v8w9x0y1z2_drop_step_minutes_and_remark_fields.py | 数据库迁移 | 4 |
| 115 | 数据库迁移 - v3w4x5y6z7a_add_pipeline_link_and_repair_record_trace.py | 数据库迁移 | 4 |
| 116 | 数据库迁移 - v4x5y6z7a8b_drop_is_key_process_from_craft_steps.py | 数据库迁移 | 4 |
| 117 | 数据库迁移 - w6x7y8z9a0b_add_supplier_master_and_order_snapshot.py | 数据库迁移 | 4 |
| 118 | 数据库迁移 - x1y2z3a4b5c6_add_first_article_rich_form_schema.py | 数据库迁移 | 4 |
| 119 | 数据库迁移 - y7z8a9b0c1d2_add_user_export_task_table.py | 数据库迁移 | 4 |
| 120 | 数据库迁移 - z8a9b0c1d2e3_add_first_article_review_session.py | 数据库迁移 | 4 |
| 121 | 测试模块 - 测试模块模块 | 测试模块 | 4 |
| 122 | 测试模块 - 测试模块模块 | 测试模块 | 4 |
| 123 | 前端基础设施 - software_settings_models.dart | 前端基础设施 | 4 |
| 124 | 后端基础设施 - session.py | 后端基础设施 | 3 |
| 125 | 测试模块 - 测试模块模块 | 测试模块 | 3 |
| 126 | 测试模块 - 测试模块模块 | 测试模块 | 3 |
| 127 | 测试模块 - 测试模块模块 | 测试模块 | 3 |
| 128 | 前端基础设施 - api_exception.dart | 前端基础设施 | 3 |
| 129 | 前端基础设施 - plugin_host_view_state.dart | 前端基础设施 | 3 |
| 130 | 前端基础设施 - time_sync_models.dart | 前端基础设施 | 3 |
| 131 | 基础设施 - enrich_graph.py | 基础设施 | 3 |
| 132 | 基础设施 - verify_governance.py | 基础设施 | 3 |
| 133 | 后端基础设施 - API endpoint modules. | 后端基础设施 | 2 |
| 134 | 后端基础设施 - Application startup bootstrap helpers. | 后端基础设施 | 2 |
| 135 | 后端基础设施 - product_parameter_template.py | 后端基础设施 | 2 |
| 136 | 后端基础设施 - Core settings and shared utilities. | 后端基础设施 | 2 |
| 137 | 后端基础设施 - 后端基础设施模块 | 后端基础设施 | 2 |
| 138 | 后端基础设施 - Pydantic schema package. | 后端基础设施 | 2 |
| 139 | 未分类模块 139 | unknown | 2 |
| 140 | 前端基础设施 - current_user.dart | 前端基础设施 | 2 |
| 141 | 插件系统 - 插件系统模块 | 插件系统 | 2 |
| 142 | 基础设施 - Performance tooling helpers. | 基础设施 | 2 |
| 143 | unknown - unknown模块 | unknown | 1 |
| 144 | 后端基础设施 - 后端基础设施模块 | 后端基础设施 | 1 |
| 145 | 后端基础设施 - api.py | 后端基础设施 | 1 |
| 146 | 后端基础设施 - 后端基础设施模块 | 后端基础设施 | 1 |
| 147 | 后端基础设施 - product_lifecycle.py | 后端基础设施 | 1 |
| 148 | 后端基础设施 - rbac.py | 后端基础设施 | 1 |
| 149 | 后端基础设施 - base.py | 后端基础设施 | 1 |
| 150 | 后端基础设施 - associations.py | 后端基础设施 | 1 |
| 151 | 后端基础设施 - 后端基础设施模块 | 后端基础设施 | 1 |
| 152 | 后端基础设施 - 后端基础设施模块 | 后端基础设施 | 1 |
| 153 | unknown - unknown模块 | unknown | 1 |
| 154 | 前端基础设施 - runtime_endpoints.dart | 前端基础设施 | 1 |
| 155 | 设备管理 - maintenance_category_options.dart | 设备管理 | 1 |
| 156 | 产品管理 - product_category_options.dart | 产品管理 | 1 |
| 157 | 未分类模块 157 | unknown | 1 |
| 158 | 未分类模块 158 | unknown | 1 |
| 159 | 未分类模块 159 | unknown | 1 |
| 160 | 未分类模块 160 | unknown | 1 |
| 161 | 插件系统 - 插件系统模块 | 插件系统 | 1 |
| 162 | 插件系统 - launcher.py | 插件系统 | 1 |
| 163 | 插件系统 - 插件系统模块 | 插件系统 | 1 |
| 164 | 插件系统 - 插件系统模块 | 插件系统 | 1 |
| 165 | 基础设施 - vendor_plugin_deps.ps1 | 基础设施 | 1 |
| 166 | 基础设施 - 按源文件路径搜索节点（路径标准化后匹配）。 | 基础设施 | 1 |
| 167 | 基础设施 - 选择契约主节点：精确label > models目录 > 显式类定义。 | 基础设施 | 1 |
| 168 | 基础设施 - 选择影响面主节点：优先 models 目录下精确匹配的。 | 基础设施 | 1 |
| 169 | 基础设施 - 获取 Graphify 版本，返回结构化 dict。 | 基础设施 | 1 |
| 170 | 基础设施 - 将 Graphify 原始产物复制到 staging/raw/，注入 run_id。 | 基础设施 | 1 |
| 171 | 基础设施 - 生成 manifest.json 到 staging/。 | 基础设施 | 1 |
| 172 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 | 基础设施 | 1 |
| 173 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 | 基础设施 | 1 |

## 原社区编号 -> 业务名称映射

| 原编号 | 业务名称 |
|---|---|
| Community 0 | 设备管理 - Spacer |
| Community 1 | 测试支撑 - 前端基础设施 (expectLater) |
| Community 2 | 工艺管理 - NoOpSampleHandler |
| Community 3 | 生产执行 - create_process_api() |
| Community 4 | 工艺管理 - CraftStageListResult |
| Community 5 | 测试支撑 - 质量管理 (QualitySupplierListResult) |
| Community 6 | 产品管理 - ProductItem |
| Community 7 | 生产执行 - HomeDashboardTodoSummary |
| Community 8 | 用户权限 - RoleManagementPage |
| Community 9 | 用户权限 - AuthzSnapshotResult |
| Community 10 | 设备管理 - EquipmentLedgerListResult |
| Community 11 | 用户权限 - list_online_user_ids() |
| Community 12 | 生产执行 - production_constants.py |
| Community 13 | 基础设施 - 基础设施模块 |
| Community 14 | 消息推送 - AnnouncementPublishResult |
| Community 15 | 前端基础设施 - mes_theme.dart |
| Community 16 | 生产执行 - FirstArticleTemplateListResult |
| Community 17 | 用户权限 - first_article_disposition_page.dart |
| Community 18 | 质量管理 - DefectAnalysisResult |
| Community 19 | 设备管理 - ScrapStatisticsListResult |
| Community 20 | 测试支撑 - 后端基础设施 (daily_verification_code.py) |
| Community 21 | 测试支撑 - 后端基础设施 (me.py) |
| Community 22 | 消息推送 - LayoutBuilder |
| Community 23 | 测试支撑 - 后端基础设施 (main()) |
| Community 24 | 基础设施 - serial_bridge.py |
| Community 25 | 工艺管理 - craft_models.dart |
| Community 26 | 用户权限 - function_permission_config_page.dart |
| Community 27 | 测试模块 - 测试模块模块 |
| Community 28 | 测试模块 - 测试模块模块 |
| Community 29 | 测试模块 - 测试模块模块 |
| Community 30 | 测试模块 - 测试模块模块 |
| Community 31 | 未分类模块 31 |
| Community 32 | 插件系统 - first_article_review_page.py |
| Community 33 | 基础设施 - project_toolkit.py |
| Community 34 | 未分类模块 34 |
| Community 35 | 测试模块 - 测试模块模块 |
| Community 36 | 测试模块 - 测试模块模块 |
| Community 37 | 测试模块 - 测试模块模块 |
| Community 38 | 未分类模块 38 |
| Community 39 | 未分类模块 39 |
| Community 40 | 未分类模块 40 |
| Community 41 | 前端基础设施 - main_shell_refresh_coordinator.dart |
| Community 42 | 测试模块 - 测试模块模块 |
| Community 43 | 测试模块 - 测试模块模块 |
| Community 44 | 测试模块 - 测试模块模块 |
| Community 45 | 测试模块 - 测试模块模块 |
| Community 46 | 用户权限 - authz_cache_service.py |
| Community 47 | 测试模块 - 测试模块模块 |
| Community 48 | 测试模块 - 测试模块模块 |
| Community 49 | 测试模块 - 测试模块模块 |
| Community 50 | 测试模块 - 测试模块模块 |
| Community 51 | 测试模块 - 测试模块模块 |
| Community 52 | 前端基础设施 - mes_radius.dart |
| Community 53 | 数据库迁移 - 9b2c3d4e_add_product_parameter_description_and_history_snapshots.py |
| Community 54 | 数据库迁移 - Add version_label column to mes_product_revision and backfill. |
| Community 55 | 数据库迁移 - c9d8e7f6a5b4_add_product_lifecycle_and_versions.py |
| Community 56 | 数据库迁移 - o6p7q8r9s0t1_add_craft_template_tracking_and_step_fields.py |
| Community 57 | 测试模块 - 测试模块模块 |
| Community 58 | 测试模块 - 测试模块模块 |
| Community 59 | 未分类模块 59 |
| Community 60 | 数据库迁移 - c4f7d9e2a1b3_reconcile_system_master_template_schema.py |
| Community 61 | 数据库迁移 - f1c2d3e4b5a6_add_template_lifecycle_versions_and_capacity.py |
| Community 62 | 后端基础设施 - equipment_process.py |
| Community 63 | 测试模块 - 测试模块模块 |
| Community 64 | 前端基础设施 - plugin_manifest.dart |
| Community 65 | 数据库迁移 - 0998ac4f196a_merge_heads.py |
| Community 66 | 数据库迁移 - 142349cbdee9_add_process_and_user_process_mapping.py |
| Community 67 | 数据库迁移 - 1f4c2e6a9b10_update_equipment_code_and_name_uniqueness.py |
| Community 68 | 数据库迁移 - 4d2f8a7b9c31_add_production_module_v1_tables.py |
| Community 69 | 数据库迁移 - 7e4b2c1d_add_product_category_field.py |
| Community 70 | 数据库迁移 - 8a1b2c3d_narrow_product_lifecycle_statuses.py |
| Community 71 | 数据库迁移 - 91b7c6da4f20_add_registration_request_table.py |
| Community 72 | 数据库迁移 - 9c2a4d6e8f11_make_work_order_plan_nullable_set_null.py |
| Community 73 | 数据库迁移 - 数据库迁移模块 |
| Community 74 | 数据库迁移 - a8b7c6d5e4f3_add_craft_module_v1_schema_and_reset_production.py |
| Community 75 | 数据库迁移 - a9e6c1f4d2b7_drop_template_standard_capacity_fields.py |
| Community 76 | 数据库迁移 - ab3f6d1e4c22_make_work_order_item_nullable_set_null.py |
| Community 77 | 数据库迁移 - b1a2c3d4e5f6_add_craft_system_master_template_tables.py |
| Community 78 | 数据库迁移 - 数据库迁移模块 |
| Community 79 | 数据库迁移 - 数据库迁移模块 |
| Community 80 | 数据库迁移 - b7c8d9e0f1a2_add_equipment_module_tables.py |
| Community 81 | 数据库迁移 - bc4d7e2f913a_make_work_order_equipment_nullable_set_null.py |
| Community 82 | 数据库迁移 - 数据库迁移模块 |
| Community 83 | 数据库迁移 - 数据库迁移模块 |
| Community 84 | 数据库迁移 - c4e6f8a1b2d3_sunset_page_visibility_add_authz_audit.py |
| Community 85 | 数据库迁移 - c5d6e7f8a9b0_add_remark_and_standard_desc_fields.py |
| Community 86 | 数据库迁移 - d15a9c4b7e32_add_work_order_snapshot_fields.py |
| Community 87 | 数据库迁移 - d3a7b4c9e2f1_add_order_pipeline_mode_schema.py |
| Community 88 | 数据库迁移 - 数据库迁移模块 |
| Community 89 | 数据库迁移 - 数据库迁移模块 |
| Community 90 | 数据库迁移 - d5e6f7a8b9c0_add_is_deleted_to_product.py |
| Community 91 | 数据库迁移 - da2ddcd5aa2d_init_auth_and_user_tables.py |
| Community 92 | 数据库迁移 - e1b2c3d4f5a6_add_repair_and_scrap_schema.py |
| Community 93 | 数据库迁移 - e42f8a6c1d73_create_maintenance_record_table.py |
| Community 94 | 数据库迁移 - e5f6a7b8c9d0_add_message_tables.py |
| Community 95 | 数据库迁移 - e8f2b1c4d9a3_drop_permission_tables.py |
| Community 96 | 数据库迁移 - f2b3c4d5e6f7_add_authz_permission_domain_tables.py |
| Community 97 | 数据库迁移 - f3d4e5a6b7c8_upgrade_user_module_v1_schema.py |
| Community 98 | 数据库迁移 - f6a1d2c3b4e5_upgrade_product_parameter_schema.py |
| Community 99 | 数据库迁移 - f6a7b8c9d0e1_add_first_article_disposition_history.py |
| Community 100 | 数据库迁移 - f94b1c2d3e45_add_execution_process_to_maintenance.py |
| Community 101 | 数据库迁移 - g7b8c9d0e1f2_add_change_type_to_parameter_history.py |
| Community 102 | 数据库迁移 - h1i2j3k4l5m6_add_equipment_rule_and_runtime_parameter.py |
| Community 103 | 数据库迁移 - i1j2k3l4m5n6_add_craft_remark_and_stage_name_unique.py |
| Community 104 | 数据库迁移 - j2k3l4m5n6o7_add_system_master_template_revision_tables.py |
| Community 105 | 数据库迁移 - k3l4m5n6o7p8_enforce_single_role_per_user.py |
| Community 106 | 数据库迁移 - m4n5o6p7q8r9_add_product_revision_parameter_table.py |
| Community 107 | 数据库迁移 - n2o3p4q5r6s7_make_pipeline_sub_order_nullable.py |
| Community 108 | 数据库迁移 - p7q8r9s0t1u2_preserve_production_order_event_logs.py |
| Community 109 | 数据库迁移 - q8r9s0t1u2v3_extend_equipment_rule_and_parameter_state.py |
| Community 110 | 数据库迁移 - r9s0t1u2v3w4_add_equipment_scope_fields.py |
| Community 111 | 数据库迁移 - s0t1u2v3w4x5_add_operator_to_scrap_statistics.py |
| Community 112 | 数据库迁移 - t1u2v3w4x5y6_harden_message_delivery_and_dedupe.py |
| Community 113 | 数据库迁移 - u2v3w4x5y6z_add_execution_process_snapshot_to_maintenance_record.py |
| Community 114 | 数据库迁移 - u7v8w9x0y1z2_drop_step_minutes_and_remark_fields.py |
| Community 115 | 数据库迁移 - v3w4x5y6z7a_add_pipeline_link_and_repair_record_trace.py |
| Community 116 | 数据库迁移 - v4x5y6z7a8b_drop_is_key_process_from_craft_steps.py |
| Community 117 | 数据库迁移 - w6x7y8z9a0b_add_supplier_master_and_order_snapshot.py |
| Community 118 | 数据库迁移 - x1y2z3a4b5c6_add_first_article_rich_form_schema.py |
| Community 119 | 数据库迁移 - y7z8a9b0c1d2_add_user_export_task_table.py |
| Community 120 | 数据库迁移 - z8a9b0c1d2e3_add_first_article_review_session.py |
| Community 121 | 测试模块 - 测试模块模块 |
| Community 122 | 测试模块 - 测试模块模块 |
| Community 123 | 前端基础设施 - software_settings_models.dart |
| Community 124 | 后端基础设施 - session.py |
| Community 125 | 测试模块 - 测试模块模块 |
| Community 126 | 测试模块 - 测试模块模块 |
| Community 127 | 测试模块 - 测试模块模块 |
| Community 128 | 前端基础设施 - api_exception.dart |
| Community 129 | 前端基础设施 - plugin_host_view_state.dart |
| Community 130 | 前端基础设施 - time_sync_models.dart |
| Community 131 | 基础设施 - enrich_graph.py |
| Community 132 | 基础设施 - verify_governance.py |
| Community 133 | 后端基础设施 - API endpoint modules. |
| Community 134 | 后端基础设施 - Application startup bootstrap helpers. |
| Community 135 | 后端基础设施 - product_parameter_template.py |
| Community 136 | 后端基础设施 - Core settings and shared utilities. |
| Community 137 | 后端基础设施 - 后端基础设施模块 |
| Community 138 | 后端基础设施 - Pydantic schema package. |
| Community 139 | 未分类模块 139 |
| Community 140 | 前端基础设施 - current_user.dart |
| Community 141 | 插件系统 - 插件系统模块 |
| Community 142 | 基础设施 - Performance tooling helpers. |
| Community 143 | unknown - unknown模块 |
| Community 144 | 后端基础设施 - 后端基础设施模块 |
| Community 145 | 后端基础设施 - api.py |
| Community 146 | 后端基础设施 - 后端基础设施模块 |
| Community 147 | 后端基础设施 - product_lifecycle.py |
| Community 148 | 后端基础设施 - rbac.py |
| Community 149 | 后端基础设施 - base.py |
| Community 150 | 后端基础设施 - associations.py |
| Community 151 | 后端基础设施 - 后端基础设施模块 |
| Community 152 | 后端基础设施 - 后端基础设施模块 |
| Community 153 | unknown - unknown模块 |
| Community 154 | 前端基础设施 - runtime_endpoints.dart |
| Community 155 | 设备管理 - maintenance_category_options.dart |
| Community 156 | 产品管理 - product_category_options.dart |
| Community 157 | 未分类模块 157 |
| Community 158 | 未分类模块 158 |
| Community 159 | 未分类模块 159 |
| Community 160 | 未分类模块 160 |
| Community 161 | 插件系统 - 插件系统模块 |
| Community 162 | 插件系统 - launcher.py |
| Community 163 | 插件系统 - 插件系统模块 |
| Community 164 | 插件系统 - 插件系统模块 |
| Community 165 | 基础设施 - vendor_plugin_deps.ps1 |
| Community 166 | 基础设施 - 按源文件路径搜索节点（路径标准化后匹配）。 |
| Community 167 | 基础设施 - 选择契约主节点：精确label > models目录 > 显式类定义。 |
| Community 168 | 基础设施 - 选择影响面主节点：优先 models 目录下精确匹配的。 |
| Community 169 | 基础设施 - 获取 Graphify 版本，返回结构化 dict。 |
| Community 170 | 基础设施 - 将 Graphify 原始产物复制到 staging/raw/，注入 run_id。 |
| Community 171 | 基础设施 - 生成 manifest.json 到 staging/。 |
| Community 172 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 |
| Community 173 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 |

## 域分布

- 测试模块 (`tests`): 1862 节点
- 生产执行 (`production`): 734 节点
- 用户权限 (`authz`): 723 节点
- 工艺管理 (`craft`): 596 节点
- 前端基础设施 (`frontend-core`): 519 节点
- 产品管理 (`product`): 505 节点
- 设备管理 (`equipment`): 421 节点
- 后端基础设施 (`backend-core`): 334 节点
- 质量管理 (`quality`): 280 节点
- 数据库迁移 (`migrations`): 269 节点
- 基础设施 (`infrastructure`): 250 节点
- 消息推送 (`message`): 219 节点
- unknown (`unknown`): 122 节点
- 插件系统 (`plugin`): 30 节点

## 关系类型分布

- `calls`: 3992
- `defines`: 2917
- `imports`: 2595
- `contains`: 2155
- `uses`: 1587
- `method`: 617
- `inherits`: 131
- `rationale_for`: 97