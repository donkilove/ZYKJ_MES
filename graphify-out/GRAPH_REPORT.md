# Graph Report - ZYKJ_MES (治理后)

> run_id: `e92e75ea-78e5-4617-bee2-594af9014a12`
> generated_at: 2026-05-02T01:50:25.228903+00:00
> source_commit: `a9f07bbdd7cf3ed2a9ee111357e1f5e4a0733e9a`
> curation_version: 1.0.0

## 质量摘要

- 治理前: 7732 节点 · 15644 条边
- 治理后: 6881 节点 · 14105 条边
- 已滤除节点: 851
- 已隐藏节点: 513
- 业务节点 Top20 占比: 70%
- 社区数: 183
- 社区命名覆盖率: 174/183

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
| 0 | 测试支撑 - 生产执行 (CraftStageListResult) | 测试模块 | 1004 |
| 1 | 设备管理 - 核心流程 | 设备管理 | 629 |
| 2 | 工艺管理 - 核心流程 | 工艺管理 | 479 |
| 3 | 生产执行 - ProductParameterQueryDialog | 生产执行 | 306 |
| 4 | 测试支撑 - 前端基础设施 (PluginSession) | 测试模块 | 367 |
| 5 | 生产执行 - HomeDashboardTodoItem | 生产执行 | 390 |
| 6 | 生产执行 - MyOrderItem | 生产执行 | 322 |
| 7 | 质量管理 - CraftKanbanPage | 质量管理 | 201 |
| 8 | 用户权限 - AuthzSnapshotResult | 用户权限 | 253 |
| 9 | 设备管理 - EquipmentLedgerListResult | 设备管理 | 225 |
| 10 | 用户权限 - UserItem | 用户权限 | 227 |
| 11 | 前端基础设施 - RegisterPageResult | 前端基础设施 | 143 |
| 12 | 产品管理 - ProductListResult | 产品管理 | 165 |
| 13 | 生产执行 - FirstArticleReviewSessionCommandResult | 生产执行 | 162 |
| 14 | 工艺管理 - ProcessManagementPage | 工艺管理 | 117 |
| 15 | 工艺管理 - ProcessConfigurationPage | 工艺管理 | 128 |
| 16 | 测试支撑 - 基础设施 | 测试模块 | 157 |
| 17 | 消息推送 - AnnouncementPublishResult | 消息推送 | 145 |
| 18 | 用户权限 - AuditLogPage | 用户权限 | 96 |
| 19 | 产品管理 - ProductParameterManagementPage | 产品管理 | 76 |
| 20 | 测试支撑 - 后端基础设施 (SeedResult) | 测试模块 | 84 |
| 21 | 质量管理 - DefectAnalysisResult | 质量管理 | 74 |
| 22 | 测试支撑 - 后端基础设施 (DailyVerificationCode) | 测试模块 | 61 |
| 23 | 消息推送 - 核心流程 | 消息推送 | 41 |
| 24 | 产品管理 - ProductManagementPage | 产品管理 | 49 |
| 25 | 基础设施 - SerialBridge | 基础设施 | 52 |
| 26 | 测试支撑 - 后端基础设施 | 测试模块 | 50 |
| 27 | 测试支撑 - 生产执行 (FirstArticleTemplateListResult) | 测试模块 | 38 |
| 28 | 工艺管理 - CraftStageItem | 工艺管理 | 45 |
| 29 | 测试支撑 - 通用验证 | 测试模块 | 35 |
| 30 | 测试支撑 - 通用验证 | 测试模块 | 32 |
| 31 | 测试支撑 - 通用验证 | 测试模块 | 32 |
| 32 | 测试支撑 - 通用验证 | 测试模块 | 31 |
| 33 | 未分类模块 33 | unknown | 29 |
| 34 | 插件系统 - FirstArticleReviewWebPageTest | 插件系统 | 25 |
| 35 | 基础设施 - 核心流程 | 基础设施 | 22 |
| 36 | unknown - 核心流程 | unknown | 21 |
| 37 | 测试支撑 - 通用验证 | 测试模块 | 20 |
| 38 | 测试支撑 - 通用验证 | 测试模块 | 18 |
| 39 | 测试支撑 - 通用验证 | 测试模块 | 13 |
| 40 | 用户权限 - DropdownMenuItem | 用户权限 | 9 |
| 41 | unknown - 核心流程 | unknown | 11 |
| 42 | 未分类模块 42 | unknown | 11 |
| 43 | 未分类模块 43 | unknown | 11 |
| 44 | 测试支撑 - 通用验证 | 测试模块 | 9 |
| 45 | 测试支撑 - 通用验证 | 测试模块 | 9 |
| 46 | 测试支撑 - 通用验证 | 测试模块 | 9 |
| 47 | 测试支撑 - 通用验证 | 测试模块 | 9 |
| 48 | 用户权限 - 核心流程 | 用户权限 | 8 |
| 49 | 测试支撑 - 通用验证 | 测试模块 | 8 |
| 50 | 测试支撑 - 通用验证 | 测试模块 | 7 |
| 51 | 测试支撑 - 通用验证 | 测试模块 | 7 |
| 52 | 测试支撑 - 通用验证 | 测试模块 | 7 |
| 53 | 测试支撑 - 通用验证 | 测试模块 | 7 |
| 54 | 前端基础设施 - 核心流程 | 前端基础设施 | 7 |
| 55 | 数据库迁移 - Add param_description to mes_product_parameter and before/after snapshots to mes | 数据库迁移 | 6 |
| 56 | 数据库迁移 - Add version_label column to mes_product_revision and backfill. | 数据库迁移 | 6 |
| 57 | 数据库迁移 - 核心流程 | 数据库迁移 | 6 |
| 58 | 数据库迁移 - 核心流程 | 数据库迁移 | 6 |
| 59 | 测试支撑 - 通用验证 | 测试模块 | 6 |
| 60 | 测试支撑 - 通用验证 | 测试模块 | 6 |
| 61 | 未分类模块 61 | unknown | 6 |
| 62 | 数据库迁移 - 核心流程 | 数据库迁移 | 5 |
| 63 | 数据库迁移 - 核心流程 | 数据库迁移 | 5 |
| 64 | 后端基础设施 - EquipmentProcessOption | 后端基础设施 | 5 |
| 65 | 测试支撑 - 通用验证 | 测试模块 | 5 |
| 66 | 前端基础设施 - PluginManifest | 前端基础设施 | 5 |
| 67 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 68 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 69 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 70 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 71 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 72 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 73 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 74 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 75 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 76 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 77 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 78 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 79 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 80 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 81 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 82 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 83 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 84 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 85 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 86 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 87 | 数据库迁移 - add remark to equipment and standard_description to maintenance_item  Revision I | 数据库迁移 | 4 |
| 88 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 89 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 90 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 91 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 92 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 93 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 94 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 95 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 96 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 97 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 98 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 99 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 100 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 101 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 102 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 103 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 104 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 105 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 106 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 107 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 108 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 109 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 110 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 111 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 112 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 113 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 114 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 115 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 116 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 117 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 118 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 119 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 120 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 121 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 122 | 数据库迁移 - 核心流程 | 数据库迁移 | 4 |
| 123 | 测试支撑 - 通用验证 | 测试模块 | 4 |
| 124 | 测试支撑 - 通用验证 | 测试模块 | 4 |
| 125 | 前端基础设施 - SoftwareSettings | 前端基础设施 | 4 |
| 126 | 后端基础设施 - 核心流程 | 后端基础设施 | 3 |
| 127 | 测试支撑 - 通用验证 | 测试模块 | 3 |
| 128 | 测试支撑 - 通用验证 | 测试模块 | 3 |
| 129 | 测试支撑 - 通用验证 | 测试模块 | 3 |
| 130 | 前端基础设施 - toString | 前端基础设施 | 3 |
| 131 | 前端基础设施 - PluginHostViewState | 前端基础设施 | 3 |
| 132 | 前端基础设施 - TimeSyncState | 前端基础设施 | 3 |
| 133 | 基础设施 - 添加一条 EXTRACTED 边，如果源和目标都存在且边不存在则添加 | 基础设施 | 3 |
| 134 | 基础设施 - 核心流程 | 基础设施 | 3 |
| 135 | 后端基础设施 - API endpoint modules. | 后端基础设施 | 2 |
| 136 | 后端基础设施 - Application startup bootstrap helpers. | 后端基础设施 | 2 |
| 137 | 后端基础设施 - ProductParameterTemplateItem | 后端基础设施 | 2 |
| 138 | 后端基础设施 - Core settings and shared utilities. | 后端基础设施 | 2 |
| 139 | 后端基础设施 - 核心流程 | 后端基础设施 | 2 |
| 140 | 后端基础设施 - Pydantic schema package. | 后端基础设施 | 2 |
| 141 | 未分类模块 141 | unknown | 2 |
| 142 | 前端基础设施 - CurrentUser | 前端基础设施 | 2 |
| 143 | 插件系统 - 核心流程 | 插件系统 | 2 |
| 144 | 基础设施 - Performance tooling helpers. | 基础设施 | 2 |
| 145 | unknown - 核心流程 | unknown | 1 |
| 146 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 147 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 148 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 149 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 150 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 151 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 152 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 153 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 154 | 后端基础设施 - 核心流程 | 后端基础设施 | 1 |
| 155 | unknown - 核心流程 | unknown | 1 |
| 156 | 前端基础设施 - 核心流程 | 前端基础设施 | 1 |
| 157 | 设备管理 - 核心流程 | 设备管理 | 1 |
| 158 | 产品管理 - 核心流程 | 产品管理 | 1 |
| 159 | 未分类模块 159 | unknown | 1 |
| 160 | 未分类模块 160 | unknown | 1 |
| 161 | 未分类模块 161 | unknown | 1 |
| 162 | 未分类模块 162 | unknown | 1 |
| 163 | 插件系统 - 核心流程 | 插件系统 | 1 |
| 164 | 插件系统 - 核心流程 | 插件系统 | 1 |
| 165 | 插件系统 - 核心流程 | 插件系统 | 1 |
| 166 | 插件系统 - 核心流程 | 插件系统 | 1 |
| 167 | 基础设施 - vendor_plugin_deps.ps1 | 基础设施 | 1 |
| 168 | 基础设施 - 对边不足的对象，构建导航层补充链路（按文件名/域匹配而非图的边）。 | 基础设施 | 1 |
| 169 | 基础设施 - 对边不足的对象，构建导航层补充链路（按文件名/域匹配而非图的边）。 | 基础设施 | 1 |
| 170 | 基础设施 - 运行 graphify update . 生成本轮原始图谱产物。 | 基础设施 | 1 |
| 171 | 基础设施 - 将 graphify update 生成的原始产物复制到 staging/raw/，注入 run_id 并缓存。          来源：graphify-ou | 基础设施 | 1 |
| 172 | 基础设施 - 生成 manifest.json 到 staging/。 | 基础设施 | 1 |
| 173 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 | 基础设施 | 1 |
| 174 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 | 基础设施 | 1 |
| 175 | 基础设施 - 按源文件路径搜索节点（路径标准化后匹配）。 | 基础设施 | 1 |
| 176 | 基础设施 - 选择契约主节点：精确label > models目录 > 显式类定义。 | 基础设施 | 1 |
| 177 | 基础设施 - 选择影响面主节点：优先 models 目录下精确匹配的。 | 基础设施 | 1 |
| 178 | 基础设施 - 获取 Graphify 版本，返回结构化 dict。 | 基础设施 | 1 |
| 179 | 基础设施 - 将 Graphify 原始产物复制到 staging/raw/，注入 run_id。 | 基础设施 | 1 |
| 180 | 基础设施 - 生成 manifest.json 到 staging/。 | 基础设施 | 1 |
| 181 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 | 基础设施 | 1 |
| 182 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 | 基础设施 | 1 |

## 原社区编号 -> 业务名称映射

| 原编号 | 业务名称 |
|---|---|
| Community 0 | 测试支撑 - 生产执行 (CraftStageListResult) |
| Community 1 | 设备管理 - 核心流程 |
| Community 2 | 工艺管理 - 核心流程 |
| Community 3 | 生产执行 - ProductParameterQueryDialog |
| Community 4 | 测试支撑 - 前端基础设施 (PluginSession) |
| Community 5 | 生产执行 - HomeDashboardTodoItem |
| Community 6 | 生产执行 - MyOrderItem |
| Community 7 | 质量管理 - CraftKanbanPage |
| Community 8 | 用户权限 - AuthzSnapshotResult |
| Community 9 | 设备管理 - EquipmentLedgerListResult |
| Community 10 | 用户权限 - UserItem |
| Community 11 | 前端基础设施 - RegisterPageResult |
| Community 12 | 产品管理 - ProductListResult |
| Community 13 | 生产执行 - FirstArticleReviewSessionCommandResult |
| Community 14 | 工艺管理 - ProcessManagementPage |
| Community 15 | 工艺管理 - ProcessConfigurationPage |
| Community 16 | 测试支撑 - 基础设施 |
| Community 17 | 消息推送 - AnnouncementPublishResult |
| Community 18 | 用户权限 - AuditLogPage |
| Community 19 | 产品管理 - ProductParameterManagementPage |
| Community 20 | 测试支撑 - 后端基础设施 (SeedResult) |
| Community 21 | 质量管理 - DefectAnalysisResult |
| Community 22 | 测试支撑 - 后端基础设施 (DailyVerificationCode) |
| Community 23 | 消息推送 - 核心流程 |
| Community 24 | 产品管理 - ProductManagementPage |
| Community 25 | 基础设施 - SerialBridge |
| Community 26 | 测试支撑 - 后端基础设施 |
| Community 27 | 测试支撑 - 生产执行 (FirstArticleTemplateListResult) |
| Community 28 | 工艺管理 - CraftStageItem |
| Community 29 | 测试支撑 - 通用验证 |
| Community 30 | 测试支撑 - 通用验证 |
| Community 31 | 测试支撑 - 通用验证 |
| Community 32 | 测试支撑 - 通用验证 |
| Community 33 | 未分类模块 33 |
| Community 34 | 插件系统 - FirstArticleReviewWebPageTest |
| Community 35 | 基础设施 - 核心流程 |
| Community 36 | unknown - 核心流程 |
| Community 37 | 测试支撑 - 通用验证 |
| Community 38 | 测试支撑 - 通用验证 |
| Community 39 | 测试支撑 - 通用验证 |
| Community 40 | 用户权限 - DropdownMenuItem |
| Community 41 | unknown - 核心流程 |
| Community 42 | 未分类模块 42 |
| Community 43 | 未分类模块 43 |
| Community 44 | 测试支撑 - 通用验证 |
| Community 45 | 测试支撑 - 通用验证 |
| Community 46 | 测试支撑 - 通用验证 |
| Community 47 | 测试支撑 - 通用验证 |
| Community 48 | 用户权限 - 核心流程 |
| Community 49 | 测试支撑 - 通用验证 |
| Community 50 | 测试支撑 - 通用验证 |
| Community 51 | 测试支撑 - 通用验证 |
| Community 52 | 测试支撑 - 通用验证 |
| Community 53 | 测试支撑 - 通用验证 |
| Community 54 | 前端基础设施 - 核心流程 |
| Community 55 | 数据库迁移 - Add param_description to mes_product_parameter and before/after snapshots to mes |
| Community 56 | 数据库迁移 - Add version_label column to mes_product_revision and backfill. |
| Community 57 | 数据库迁移 - 核心流程 |
| Community 58 | 数据库迁移 - 核心流程 |
| Community 59 | 测试支撑 - 通用验证 |
| Community 60 | 测试支撑 - 通用验证 |
| Community 61 | 未分类模块 61 |
| Community 62 | 数据库迁移 - 核心流程 |
| Community 63 | 数据库迁移 - 核心流程 |
| Community 64 | 后端基础设施 - EquipmentProcessOption |
| Community 65 | 测试支撑 - 通用验证 |
| Community 66 | 前端基础设施 - PluginManifest |
| Community 67 | 数据库迁移 - 核心流程 |
| Community 68 | 数据库迁移 - 核心流程 |
| Community 69 | 数据库迁移 - 核心流程 |
| Community 70 | 数据库迁移 - 核心流程 |
| Community 71 | 数据库迁移 - 核心流程 |
| Community 72 | 数据库迁移 - 核心流程 |
| Community 73 | 数据库迁移 - 核心流程 |
| Community 74 | 数据库迁移 - 核心流程 |
| Community 75 | 数据库迁移 - 核心流程 |
| Community 76 | 数据库迁移 - 核心流程 |
| Community 77 | 数据库迁移 - 核心流程 |
| Community 78 | 数据库迁移 - 核心流程 |
| Community 79 | 数据库迁移 - 核心流程 |
| Community 80 | 数据库迁移 - 核心流程 |
| Community 81 | 数据库迁移 - 核心流程 |
| Community 82 | 数据库迁移 - 核心流程 |
| Community 83 | 数据库迁移 - 核心流程 |
| Community 84 | 数据库迁移 - 核心流程 |
| Community 85 | 数据库迁移 - 核心流程 |
| Community 86 | 数据库迁移 - 核心流程 |
| Community 87 | 数据库迁移 - add remark to equipment and standard_description to maintenance_item  Revision I |
| Community 88 | 数据库迁移 - 核心流程 |
| Community 89 | 数据库迁移 - 核心流程 |
| Community 90 | 数据库迁移 - 核心流程 |
| Community 91 | 数据库迁移 - 核心流程 |
| Community 92 | 数据库迁移 - 核心流程 |
| Community 93 | 数据库迁移 - 核心流程 |
| Community 94 | 数据库迁移 - 核心流程 |
| Community 95 | 数据库迁移 - 核心流程 |
| Community 96 | 数据库迁移 - 核心流程 |
| Community 97 | 数据库迁移 - 核心流程 |
| Community 98 | 数据库迁移 - 核心流程 |
| Community 99 | 数据库迁移 - 核心流程 |
| Community 100 | 数据库迁移 - 核心流程 |
| Community 101 | 数据库迁移 - 核心流程 |
| Community 102 | 数据库迁移 - 核心流程 |
| Community 103 | 数据库迁移 - 核心流程 |
| Community 104 | 数据库迁移 - 核心流程 |
| Community 105 | 数据库迁移 - 核心流程 |
| Community 106 | 数据库迁移 - 核心流程 |
| Community 107 | 数据库迁移 - 核心流程 |
| Community 108 | 数据库迁移 - 核心流程 |
| Community 109 | 数据库迁移 - 核心流程 |
| Community 110 | 数据库迁移 - 核心流程 |
| Community 111 | 数据库迁移 - 核心流程 |
| Community 112 | 数据库迁移 - 核心流程 |
| Community 113 | 数据库迁移 - 核心流程 |
| Community 114 | 数据库迁移 - 核心流程 |
| Community 115 | 数据库迁移 - 核心流程 |
| Community 116 | 数据库迁移 - 核心流程 |
| Community 117 | 数据库迁移 - 核心流程 |
| Community 118 | 数据库迁移 - 核心流程 |
| Community 119 | 数据库迁移 - 核心流程 |
| Community 120 | 数据库迁移 - 核心流程 |
| Community 121 | 数据库迁移 - 核心流程 |
| Community 122 | 数据库迁移 - 核心流程 |
| Community 123 | 测试支撑 - 通用验证 |
| Community 124 | 测试支撑 - 通用验证 |
| Community 125 | 前端基础设施 - SoftwareSettings |
| Community 126 | 后端基础设施 - 核心流程 |
| Community 127 | 测试支撑 - 通用验证 |
| Community 128 | 测试支撑 - 通用验证 |
| Community 129 | 测试支撑 - 通用验证 |
| Community 130 | 前端基础设施 - toString |
| Community 131 | 前端基础设施 - PluginHostViewState |
| Community 132 | 前端基础设施 - TimeSyncState |
| Community 133 | 基础设施 - 添加一条 EXTRACTED 边，如果源和目标都存在且边不存在则添加 |
| Community 134 | 基础设施 - 核心流程 |
| Community 135 | 后端基础设施 - API endpoint modules. |
| Community 136 | 后端基础设施 - Application startup bootstrap helpers. |
| Community 137 | 后端基础设施 - ProductParameterTemplateItem |
| Community 138 | 后端基础设施 - Core settings and shared utilities. |
| Community 139 | 后端基础设施 - 核心流程 |
| Community 140 | 后端基础设施 - Pydantic schema package. |
| Community 141 | 未分类模块 141 |
| Community 142 | 前端基础设施 - CurrentUser |
| Community 143 | 插件系统 - 核心流程 |
| Community 144 | 基础设施 - Performance tooling helpers. |
| Community 145 | unknown - 核心流程 |
| Community 146 | 后端基础设施 - 核心流程 |
| Community 147 | 后端基础设施 - 核心流程 |
| Community 148 | 后端基础设施 - 核心流程 |
| Community 149 | 后端基础设施 - 核心流程 |
| Community 150 | 后端基础设施 - 核心流程 |
| Community 151 | 后端基础设施 - 核心流程 |
| Community 152 | 后端基础设施 - 核心流程 |
| Community 153 | 后端基础设施 - 核心流程 |
| Community 154 | 后端基础设施 - 核心流程 |
| Community 155 | unknown - 核心流程 |
| Community 156 | 前端基础设施 - 核心流程 |
| Community 157 | 设备管理 - 核心流程 |
| Community 158 | 产品管理 - 核心流程 |
| Community 159 | 未分类模块 159 |
| Community 160 | 未分类模块 160 |
| Community 161 | 未分类模块 161 |
| Community 162 | 未分类模块 162 |
| Community 163 | 插件系统 - 核心流程 |
| Community 164 | 插件系统 - 核心流程 |
| Community 165 | 插件系统 - 核心流程 |
| Community 166 | 插件系统 - 核心流程 |
| Community 167 | 基础设施 - vendor_plugin_deps.ps1 |
| Community 168 | 基础设施 - 对边不足的对象，构建导航层补充链路（按文件名/域匹配而非图的边）。 |
| Community 169 | 基础设施 - 对边不足的对象，构建导航层补充链路（按文件名/域匹配而非图的边）。 |
| Community 170 | 基础设施 - 运行 graphify update . 生成本轮原始图谱产物。 |
| Community 171 | 基础设施 - 将 graphify update 生成的原始产物复制到 staging/raw/，注入 run_id 并缓存。          来源：graphify-ou |
| Community 172 | 基础设施 - 生成 manifest.json 到 staging/。 |
| Community 173 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 |
| Community 174 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 |
| Community 175 | 基础设施 - 按源文件路径搜索节点（路径标准化后匹配）。 |
| Community 176 | 基础设施 - 选择契约主节点：精确label > models目录 > 显式类定义。 |
| Community 177 | 基础设施 - 选择影响面主节点：优先 models 目录下精确匹配的。 |
| Community 178 | 基础设施 - 获取 Graphify 版本，返回结构化 dict。 |
| Community 179 | 基础设施 - 将 Graphify 原始产物复制到 staging/raw/，注入 run_id。 |
| Community 180 | 基础设施 - 生成 manifest.json 到 staging/。 |
| Community 181 | 基础设施 - 调用治理模块，产出 curated graph.json 到 staging/。 |
| Community 182 | 基础设施 - 将 staging 产物原子替换到正式 graphify-out 目录。 |

## 域分布

- 测试模块 (`tests`): 1869 节点
- 生产执行 (`production`): 734 节点
- 用户权限 (`authz`): 723 节点
- 工艺管理 (`craft`): 596 节点
- 前端基础设施 (`frontend-core`): 519 节点
- 产品管理 (`product`): 505 节点
- 设备管理 (`equipment`): 421 节点
- 后端基础设施 (`backend-core`): 334 节点
- 质量管理 (`quality`): 280 节点
- 数据库迁移 (`migrations`): 269 节点
- 基础设施 (`infrastructure`): 260 节点
- 消息推送 (`message`): 219 节点
- unknown (`unknown`): 122 节点
- 插件系统 (`plugin`): 30 节点

## 关系类型分布

- `calls`: 3997
- `defines`: 2917
- `imports`: 2595
- `contains`: 2159
- `uses`: 1587
- `method`: 622
- `inherits`: 131
- `rationale_for`: 97