# 后端服务层

## 1. 服务总览

下表列出后端全部 39 个 Service 文件，按文件名字母序排列。职责、依赖与挂载关系基于源码 `backend/app/services/` 与 `backend/app/api/v1/endpoints/` 验证。

| 服务文件 | 主要类/模块 | 域 | 职责 | 依赖 Service | 主要 Model | 对应 Endpoint |
|---------|------------|-----|------|-------------|-----------|--------------|
| `assist_authorization_service.py` | 函数集 | 生产执行 | 代班授权申请、审批、撤销、查询 | `authz_service`, `production_event_log_service` | ProductionAssistAuthorization, User | production.py |
| `audit_service.py` | 函数集 | 系统审计 | 审计日志写入与查询 | (无) | AuditLog, User | audits.py |
| `authz_cache_service.py` | 函数集 | 权限系统 | 权限缓存 TTL、Key 生成、Generation 标记 | (无) | (无) | deps.py (内部) |
| `authz_query_service.py` | 函数集 | 权限系统 | 权限码生效计算（模块→页面→功能→操作） | (无) | (无) | authz.py (间接) |
| `authz_read_service.py` | 函数集 | 权限系统 | 权限读缓存（本地内存+In-flight 并发控制） | (无) | (无) | authz.py (间接) |
| `authz_service.py` | 函数集 | 权限系统 | 权限主服务：默认值初始化、权限码查询、能力包管理、权限变更日志 | `authz_cache_service`, `authz_query_service`, `authz_read_service`, `authz_write_service` | Role, User, PermissionCatalog, RolePermissionGrant, AuthzModuleRevision, AuthzChangeLog | authz.py, deps.py, ui.py |
| `authz_snapshot_service.py` | 函数集 | 权限系统 | 用户权限快照（菜单/页面/能力包可见性） | `authz_service` | User | ui.py |
| `authz_write_service.py` | 函数集 | 权限系统 | 权限变更写入与 Capability Pack 变更日志 | (无) | RolePermissionGrant, AuthzChangeLog | authz.py (间接) |
| `bootstrap_seed_service.py` | 函数集 | 系统启动 | 系统首次启动种子数据（角色初始化、admin 账号创建、权限默认值） | `authz_service` | Role, User | system.py |
| `craft_service.py` | 函数集 | 工艺管理 | 系统母版模板管理、产品工艺模板管理、模板修订、看板数据、模板同步冲突检测 | `process_code_rule`, `production_order_service` | CraftSystemMasterTemplate, ProductProcessTemplate, ProcessStage, Process, Product, ProductionOrder | craft.py |
| `equipment_rule_service.py` | 函数集 | 设备管理 | 设备规则与运行参数 CRUD | (无) | EquipmentRule, EquipmentRuntimeParameter, Equipment | equipment.py |
| `equipment_service.py` | 函数集 | 设备管理 | 设备台账 CRUD、保养项目管理、保养计划管理、保养工单生成与执行、保养记录查询 | `audit_service`, `craft_service` | Equipment, MaintenanceItem, MaintenancePlan, MaintenanceWorkOrder, MaintenanceRecord, User, Role | equipment.py |
| `first_article_review_service.py` | 函数集 | 质量管理 | 首件评审会话（创建、审批、驳回、过期、取消） | `production_execution_service`, `production_event_log_service` | FirstArticleRecord, FirstArticleReviewSession, ProductionOrder, User | quality.py |
| `home_dashboard_service.py` | 函数集 | 首页仪表盘 | 首页仪表盘数据聚合（待办、质量统计、生产统计、消息概览） | `authz_snapshot_service`, `message_service`, `production_data_query_service`, `production_statistics_service`, `quality_service` | User | ui.py |
| `maintenance_scheduler_service.py` | 函数集 | 设备管理 | 保养工单定时自动生成循环（asyncio 后台任务） | `equipment_service`, `message_service`, `user_service` | (直接操作) | (后台任务，无直接 Endpoint) |
| `message_connection_manager.py` | `MessageConnectionManager` | 消息推送 | WebSocket 连接池管理（按 user_id 维护在线连接） | (无) | (WebSocket) | messages.py |
| `message_push_service.py` | 函数集 | 消息推送 | 向客户端推送实时事件（未读数变化、新消息、已读状态变化） | `message_connection_manager` | (WebSocket 推送) | messages.py (间接) |
| `message_service.py` | 函数集 | 消息推送 | 消息创建、已读管理、公告发布、消息列表查询、消息详情与跳转 | `authz_service`, `audit_service` | Message, MessageRecipient, User, Role, 及所有消息源 Model | messages.py |
| `online_status_service.py` | 函数集 | 用户权限 | 用户在线状态内存管理（touch/clear/查询） | (无) | (内存) | deps.py, sessions.py |
| `page_catalog_service.py` | 函数集 | 系统配置 | 页面目录静态数据导出 | (无) | (静态数据) | ui.py |
| `perf_capacity_permission_service.py` | 函数集 | 测试工具 | 性能测试用权限批量授予 | `authz_service` | User | system.py (测试接口) |
| `perf_sample_seed_service.py` | 函数集 | 测试工具 | 性能测试样本数据生成（产品、工艺、订单等） | `bootstrap_seed_service`, `craft_service`, `production_order_service` | Product, Process, ProductionOrder 等 | system.py (测试接口) |
| `perf_user_seed_service.py` | 函数集 | 测试工具 | 性能测试用户池批量创建 | `role_service`, `user_service` | User, Role, ProcessStage | system.py (测试接口) |
| `process_code_rule.py` | 函数集 | 产品工艺 | 工序编码校验规则（前缀匹配工段、序列号 01-99、唯一性） | (无) | Process, ProcessStage | (被 process_service, craft_service 调用) |
| `process_service.py` | 函数集 | 产品工艺 | 工序 CRUD（增删改查分页） | `process_code_rule` | Process, ProcessStage | processes.py |
| `product_service.py` | 函数集 | 产品管理 | 产品主数据与版本管理：创建、版本编辑、参数管理、生命周期状态流转、影响分析、历史记录 | `craft_service` | Product, ProductRevision, ProductParameter, ProductRevisionParameter, ProductParameterHistory, ProductProcessTemplate, ProductionOrder 等 | products.py |
| `production_data_query_service.py` | 函数集 | 生产执行 | 生产数据三视图（今日实时、未完工、手动筛选）与导出 | `production_event_log_service` | ProductionOrder, ProductionOrderProcess, ProductionRecord, User | production.py |
| `production_event_log_service.py` | 函数集 | 生产执行 | 订单事件日志写入与查询 | (无) | OrderEventLog, ProductionOrder | production.py (被多处调用) |
| `production_execution_service.py` | 函数集 | 生产执行 | 生产执行核心：首件校验、报工、子订单操作、校验码管理、并行模式门控 | `assist_authorization_service`, `authz_service`, `production_event_log_service`, `production_order_service`, `production_repair_service` | ProductionOrder, ProductionOrderProcess, ProductionSubOrder, ProductionRecord, FirstArticleRecord, DailyVerificationCode, User | production.py |
| `production_order_service.py` | 函数集 | 生产执行 | 生产订单 CRUD、订单流程管理、子订单创建、并行模式管理、订单导入导出 | `message_service`, `quality_supplier_service`, `assist_authorization_service`, `authz_service`, `production_event_log_service` | ProductionOrder, ProductionOrderProcess, ProductionSubOrder, ProductionRecord, Product, User, Supplier 等 | production.py |
| `production_repair_service.py` | 函数集 | 生产执行 | 维修单 CRUD、报废统计查询与导出、维修闭环 | `production_event_log_service`, `production_order_service`, `message_service` | RepairOrder, RepairCause, RepairDefectPhenomenon, ProductionScrapStatistics, ProductionOrder, User | production.py |
| `production_statistics_service.py` | 函数集 | 生产执行 | 生产订单概览统计（总数/进行中/已完成/完成数量） | (无) | ProductionOrder, ProductionOrderProcess, ProductionRecord | production.py, ui.py |
| `quality_service.py` | 函数集 | 质量管理 | 首件记录列表/详情/导出、质量概览统计、按产品/工序/人员/趋势统计 | (无) | FirstArticleRecord, FirstArticleDisposition, FirstArticleDispositionHistory, ProductionScrapStatistics, RepairOrder, RepairDefectPhenomenon, Product, User, DailyVerificationCode | quality.py |
| `quality_supplier_service.py` | 函数集 | 质量管理 | 供应商主数据 CRUD | (无) | Supplier | quality.py |
| `role_service.py` | 函数集 | 用户权限 | 角色 CRUD、用户角色关联计数 | (无) | Role, User, user_roles | roles.py |
| `session_service.py` | 函数集 | 用户权限 | 登录会话管理（登录/登出/在线列表/强制下线/登录日志）、Session Token 生命周期 | `online_status_service` | UserSession, LoginLog, User, Role | sessions.py, auth.py, deps.py |
| `user_export_task_service.py` | 函数集 | 用户权限 | 用户列表导出任务（异步 CSV/Excel 生成） | `audit_service`, `session_service`, `user_service` | User, UserExportTask | users.py |
| `user_service.py` | 函数集 | 用户权限 | 用户 CRUD、注册审批、密码管理、启用/停用/恢复/删除生命周期 | `authz_service`, `online_status_service`, `role_service`, `session_service` | User, Role, RegistrationRequest, UserSession, Process, ProcessStage, ProductionSubOrder | users.py, auth.py, deps.py |

## 2. 核心业务域服务

### 2.1 用户权限域

- **UserService** (`user_service.py`): 用户全生命周期管理
  - 关键方法: `create_user`, `update_user`, `delete_user`, `restore_user`, `set_user_active`, `reset_user_password`, `change_user_password`, `list_users`, `get_user_for_auth`, `get_user_by_username`, `get_user_by_id`, `submit_registration_request`, `approve_registration_request`, `reject_registration_request`, `list_registration_requests`, `ensure_admin_account`, `count_active_system_admin_users`, `ensure_can_deactivate_user`, `normalize_users_to_single_role`
  - 依赖: `authz_service`, `online_status_service`, `role_service`, `session_service`
  - 使用 Model: `User`, `Role`, `RegistrationRequest`, `UserSession`, `Process`, `ProcessStage`, `ProductionSubOrder`
  - 数据类: `UserLifecycleChange`, `UserPasswordResetChange`

- **RoleService** (`role_service.py`): 角色管理
  - 关键方法: `list_roles`, `get_role_by_id`, `get_role_by_code`, `get_role_by_code_case_insensitive`, `get_roles_by_codes`, `create_role`, `update_role`, `delete_role`, `count_active_users_for_role`, `count_active_users_for_role_ids`
  - 依赖: (无其他 Service)
  - 使用 Model: `Role`, `User`, `user_roles`

- **SessionService** (`session_service.py`): 登录会话管理
  - 关键方法: `touch_session_by_token_id`, `create_login_session`, `end_session`, `force_offline_sessions`, `list_online_user_ids`, `list_online_sessions`, `list_login_logs`
  - 依赖: `online_status_service`
  - 使用 Model: `UserSession`, `LoginLog`, `User`, `Role`, `ProcessStage`
  - 数据类: `SessionStatusSnapshot`, `OnlineSessionProjection`

- **OnlineStatusService** (`online_status_service.py`): 在线状态内存管理
  - 关键方法: `touch_user`, `clear_user`, `get_user_online_snapshot`, `list_online_user_ids`
  - 依赖: (无)
  - 使用: 进程内存 `dict[int, datetime]`

- **AuthzService** (`authz_service.py`): 权限系统主服务（约 1505+ 行）
  - 关键方法: `get_user_permission_codes`, `get_permission_codes_for_role_codes`, `has_permission`, `validate_permission_code`, `list_permission_catalog_rows`, `list_permission_modules`, `get_capability_pack_role_config`, `save_capability_pack`, `get_authz_module_revision`, `get_authz_module_revision_map`, `ensure_authz_defaults`, `invalidate_permission_cache`, `get_permission_hierarchy_catalog`
  - 依赖: `authz_cache_service`, `authz_query_service`, `authz_read_service`, `authz_write_service`
  - 使用 Model: `Role`, `User`, `PermissionCatalog`, `RolePermissionGrant`, `AuthzModuleRevision`, `AuthzChangeLog`
  - 数据类: `PermissionCatalogRow`, `AuthzRevisionConflictError`
  - 支持 Redis 两级缓存（权限码 + 读缓存），带 In-flight 并发控制与惰性默认值初始化

- **Authz Snapshot** (`authz_snapshot_service.py`): 用户权限快照
  - 关键方法: `get_authz_snapshot`
  - 依赖: `authz_service`
  - 用于前端 UI 菜单/页面可见性计算

- **Authz 子服务** (内部工具层):
  - `authz_cache_service.py`: 缓存 Key 生成、TTL 计算、Generation 标记文件
  - `authz_query_service.py`: 权限码生效传播算法（模块→页面→功能→操作）
  - `authz_read_service.py`: 本地内存读缓存（带 In-flight 去重）
  - `authz_write_service.py`: 权限变更持久化与 Capability Pack 变更日志

### 2.2 生产执行域

- **ProductionOrderService** (`production_order_service.py`): 生产订单核心（2473 行，最大 Service）
  - 关键方法: `create_order`, `update_order`, `complete_order`, `delete_order`, `list_orders`, `get_order_detail`, `list_my_orders`, `create_sub_orders_for_process`, `allocate_pipeline_instance_for_process`, `ensure_sub_orders_visible_quantity`, `set_pipeline_mode`, `get_active_pipeline_instance_for_process`, `export_orders_csv`, `import_orders_from_csv`
  - 依赖: `message_service`, `quality_supplier_service`, `assist_authorization_service`, `authz_service`, `production_event_log_service`
  - 使用 Model: `ProductionOrder`, `ProductionOrderProcess`, `ProductionSubOrder`, `ProductionRecord`, `Product`, `User`, `Role`, `Supplier`, `ProductProcessTemplate`, `ProcessPipelineInstance`, `FirstArticleRecord`, `RepairOrder`, `OrderEventLog`

- **ProductionExecutionService** (`production_execution_service.py`): 生产执行（977 行）
  - 关键方法: `submit_first_article`, `submit_production_record`, `start_sub_order`, `complete_sub_order`, 首件检验与报工流程
  - 依赖: `assist_authorization_service`, `authz_service`, `production_event_log_service`, `production_order_service`, `production_repair_service`
  - 使用 Model: `ProductionOrder`, `ProductionOrderProcess`, `ProductionSubOrder`, `ProductionRecord`, `FirstArticleRecord`, `DailyVerificationCode`, `FirstArticleTemplate`, `FirstArticleParticipant`, `ProcessPipelineInstance`

- **ProductionDataQueryService** (`production_data_query_service.py`): 生产数据查询（838 行）
  - 关键方法: `get_today_realtime_data`, `get_unfinished_orders_data`, `build_today_filters`, `query_production_data`, `export_production_data_csv`
  - 依赖: `production_event_log_service`
  - 使用 Model: `ProductionOrder`, `ProductionOrderProcess`, `ProductionRecord`, `OrderEventLog`, `User`, `ProcessStage`

- **ProductionStatisticsService** (`production_statistics_service.py`): 生产统计
  - 关键方法: `get_overview_stats`
  - 依赖: (无)
  - 使用 Model: `ProductionOrder`, `ProductionOrderProcess`, `ProductionRecord`

- **ProductionRepairService** (`production_repair_service.py`): 维修与报废（1033 行）
  - 关键方法: `create_repair_order`, `list_repair_orders`, `update_repair_order`, `complete_repair_order`, `list_scrap_statistics`, `apply_scrap`, `export_repair_orders_csv`, `export_scrap_statistics_csv`
  - 依赖: `production_event_log_service`, `production_order_service`, `message_service`
  - 使用 Model: `RepairOrder`, `RepairCause`, `RepairDefectPhenomenon`, `ProductionScrapStatistics`, `ProductionOrder`, `RepairReturnRoute`, `ProductionRecord`

- **ProductionEventLogService** (`production_event_log_service.py`): 订单事件日志
  - 关键方法: `add_order_event_log`, `list_order_event_logs`, `search_order_event_logs_by_code`
  - 依赖: (无)
  - 使用 Model: `OrderEventLog`, `ProductionOrder`

- **AssistAuthorizationService** (`assist_authorization_service.py`): 代班授权
  - 关键方法: `create_assist_authorization`, `approve_assist_authorization`, `reject_assist_authorization`, `cancel_assist_authorization`, `get_usable_assist_authorization_for_operation`, `mark_assist_authorization_used`, `list_assist_authorizations`
  - 依赖: `authz_service`, `production_event_log_service`
  - 使用 Model: `ProductionAssistAuthorization`, `ProductionOrder`, `ProductionOrderProcess`, `ProductionSubOrder`, `User`

### 2.3 质量管理域

- **QualityService** (`quality_service.py`): 质量管理核心（1502+ 行）
  - 关键方法: `list_first_articles`, `get_first_article_by_id`, `export_first_articles_csv`, `get_quality_overview`, `get_quality_process_stats`, `get_quality_operator_stats`, `get_quality_product_stats`, `get_quality_trend`
  - 依赖: (无其他 Service——纯SQL聚合)
  - 使用 Model: `FirstArticleRecord`, `FirstArticleDisposition`, `FirstArticleDispositionHistory`, `FirstArticleParticipant`, `ProductionOrder`, `ProductionOrderProcess`, `ProductionScrapStatistics`, `RepairOrder`, `RepairDefectPhenomenon`, `RepairCause`, `Product`, `User`, `DailyVerificationCode`
  - 内置本地缓存（5 秒 TTL），支持按日期、产品、工序、人员、结果多维度筛选

- **FirstArticleReviewService** (`first_article_review_service.py`): 首件评审（506 行）
  - 关键方法: `create_review_session`, `approve_review_session`, `reject_review_session`, `cancel_review_session`, `get_review_session_detail`
  - 依赖: `production_execution_service`, `production_event_log_service`
  - 使用 Model: `FirstArticleRecord`, `FirstArticleReviewSession`, `ProductionOrder`, `ProductionOrderProcess`, `User`

- **QualitySupplierService** (`quality_supplier_service.py`): 供应商管理
  - 关键方法: `get_supplier_by_id`, `list_suppliers`, `create_supplier`, `update_supplier`, `get_enabled_supplier_for_order`
  - 依赖: (无)
  - 使用 Model: `Supplier`, `ProductionOrder`

### 2.4 设备管理域

- **EquipmentService** (`equipment_service.py`): 设备管理核心（1568+ 行）
  - 关键方法: `get_equipment_by_id`, `list_equipment`, `create_equipment`, `update_equipment`, `delete_equipment`, `toggle_equipment`, `get_equipment_detail`, `list_maintenance_items`, `create_maintenance_item`, `update_maintenance_item`, `delete_maintenance_item`, `list_maintenance_plans`, `create_maintenance_plan`, `update_maintenance_plan`, `delete_maintenance_plan`, `generate_work_order_for_plan`, `generate_due_work_orders_for_today`, `list_work_orders`, `list_maintenance_records`, `start_work_order`, `complete_work_order`, `cancel_work_order`, `ensure_work_order_view_permission`, `ensure_maintenance_record_view_permission`
  - 依赖: `audit_service`, `craft_service`
  - 使用 Model: `Equipment`, `MaintenanceItem`, `MaintenancePlan`, `MaintenanceWorkOrder`, `MaintenanceRecord`, `User`, `Role`
  - 工单状态: `pending`, `in_progress`, `done`, `overdue`, `cancelled`
  - 权限控制: 基于角色码（ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN）与工段码的视图/操作双权限体系

- **EquipmentRuleService** (`equipment_rule_service.py`): 设备规则与运行参数
  - 关键方法: `list_rules`, `upsert_rule`, `delete_rule`, `list_runtime_parameters`, `upsert_runtime_parameter`, `delete_runtime_parameter`
  - 依赖: (无)
  - 使用 Model: `EquipmentRule`, `EquipmentRuntimeParameter`, `Equipment`

- **MaintenanceSchedulerService** (`maintenance_scheduler_service.py`): 保养自动生成调度器（136 行）
  - 关键方法: `run_maintenance_auto_generate_loop`（asyncio 后台定时循环）
  - 依赖: `equipment_service`, `message_service`, `user_service`
  - 可配置时区与执行时间（`settings.maintenance_auto_generate_timezone` + `maintenance_auto_generate_time`）

### 2.5 消息推送域

- **MessageService** (`message_service.py`): 消息中心（1609 行）
  - 关键方法: `create_message`, `create_message_for_users`, `get_message_summary`, `list_messages`, `get_message_detail`, `mark_as_read`, `publish_announcement`, `get_message_jump_info`, `cleanup_expired_messages`
  - 依赖: `authz_service`, `audit_service`
  - 使用 Model: `Message`, `MessageRecipient`, `User`, `Role`，及所有消息源 Model（14 种源类型）
  - 消息源映射: `registration_request`, `user_disable`, `force_offline`, `product_version`, `product_process_template`, `assist_authorization`, `production_order`, `maintenance_work_order`, `first_article_record`, `repair_order`, `first_article_disposition`, `production_scrap`, `announcement`

- **MessageConnectionManager** (`message_connection_manager.py`): WebSocket 连接管理
  - 类: `MessageConnectionManager`（全局单例 `message_connection_manager`）
  - 关键方法: `connect`, `connect_already_accepted`, `disconnect`, `push_to_user`, `online_user_ids`
  - 依赖: (无)

- **MessagePushService** (`message_push_service.py`): 实时推送
  - 关键方法: `push_unread_count_changed`, `push_message_created`, `push_message_read_state_changed`
  - 依赖: `message_connection_manager`

### 2.6 产品工艺域

- **ProductService** (`product_service.py`): 产品主数据与版本管理（1542+ 行）
  - 关键方法: `list_products`, `get_product_by_id`, `create_product`, `delete_product`, `list_product_parameters`, `create_product_revision`, `update_product_version_parameters`, `get_effective_product_parameters`, `analyze_product_impact`, `compare_product_versions`, `list_product_parameter_versions`, `sync_product_master_data_to_parameters`, `append_product_history_event`
  - 依赖: `craft_service`
  - 使用 Model: `Product`, `ProductRevision`, `ProductParameter`, `ProductRevisionParameter`, `ProductParameterHistory`, `ProductProcessTemplate`, `ProductProcessTemplateStep`, `ProductionOrder`, `FirstArticleRecord`, `ProductionScrapStatistics`, `RepairOrder`, `RepairDefectPhenomenon`, `RepairCause`
  - 数据类: `ProductImpactOrder`, `ProductImpactResult`, `ProductVersionCompareRow`, `ProductVersionCompareResult`, `ProductParameterVersionListRow`
  - 生命周期: `active`, `inactive`, `disabled`, `draft`, `effective`, `obsolete`

- **ProcessService** (`process_service.py`): 工序管理（114 行）
  - 关键方法: `list_processes`, `get_process_by_id`, `get_process_by_code`, `get_processes_by_codes`, `create_process`, `update_process`
  - 依赖: `process_code_rule`
  - 使用 Model: `Process`, `ProcessStage`

- **CraftService** (`craft_service.py`): 工艺管理（3779 行，最大 Service）
  - 关键方法: `resolve_system_master_template`, `create_template`, `update_template`, `publish_template`, `archive_template`, `list_stages`, `create_stage`, `update_stage`, `delete_stage`, `is_valid_stage_code`, `list_enabled_stage_options`, `get_kanban_data`, `sync_template_from_master`
  - 依赖: `process_code_rule`, `production_order_service`
  - 使用 Model: `CraftSystemMasterTemplate`, `CraftSystemMasterTemplateStep`, `CraftSystemMasterTemplateRevision`, `ProductProcessTemplate`, `ProductProcessTemplateStep`, `ProductProcessTemplateRevision`, `ProcessStage`, `Process`, `Product`, `ProductionOrder`, `ProductionOrderProcess`, `MaintenancePlan`, `MaintenanceWorkOrder`

- **ProcessCodeRule** (`process_code_rule.py`): 工序编码规则（59 行）
  - 关键方法: `normalize_process_code`, `validate_process_code_matches_stage`, `ensure_process_code_unique`, `get_stage_for_process_write`
  - 依赖: (无)
  - 使用 Model: `Process`, `ProcessStage`
  - 规则: 工序编码格式 `{stage_code}-{01..99}`

### 2.7 系统支撑域

- **AuditService** (`audit_service.py`): 审计日志
  - 关键方法: `write_audit_log`, `query_audit_logs`, `list_audit_logs`
  - 依赖: (无)
  - 使用 Model: `AuditLog`, `User`

- **BootstrapSeedService** (`bootstrap_seed_service.py`): 启动种子数据
  - 关键方法: `seed_initial_data`, `_ensure_roles`
  - 依赖: `authz_service`
  - 使用 Model: `Role`, `User`

- **HomeDashboardService** (`home_dashboard_service.py`): 首页仪表盘
  - 关键方法: `get_home_dashboard_data`, `select_dashboard_todo_items`, `build_dashboard_todo_summary`
  - 依赖: `authz_snapshot_service`, `message_service`, `production_data_query_service`, `production_statistics_service`, `quality_service`
  - 使用 Model: `User`, `HomeDashboardResult`

- **UserExportTaskService** (`user_export_task_service.py`): 用户导出任务
  - 关键方法: `create_export_task`, `process_export_task`, `list_export_tasks`
  - 依赖: `audit_service`, `session_service`, `user_service`
  - 使用 Model: `User`, `UserExportTask`

- **PageCatalogService** (`page_catalog_service.py`): 页面目录
  - 关键方法: `list_page_catalog_items`
  - 依赖: (无，纯静态数据)

- **PerfCapacityPermissionService** (`perf_capacity_permission_service.py`): 性能测试权限批量授予
- **PerfSampleSeedService** (`perf_sample_seed_service.py`): 性能测试样本数据生成
- **PerfUserSeedService** (`perf_user_seed_service.py`): 性能测试用户池创建

## 3. Service 依赖图（文字描述）

### 3.1 核心依赖链

```
deps.py（依赖注入层）
├── authz_cache_service (权限缓存代际)
├── online_status_service (在线状态)
├── authz_service (权限校验)
│   ├── authz_cache_service
│   ├── authz_query_service
│   ├── authz_read_service
│   └── authz_write_service
├── session_service (会话管理)
│   └── online_status_service
└── user_service (用户鉴权读取)
    ├── authz_service
    ├── online_status_service
    ├── role_service
    └── session_service
```

### 3.2 生产执行域依赖链

```
production_execution_service (生产执行)
├── assist_authorization_service (代班)
│   ├── authz_service
│   └── production_event_log_service
├── authz_service
├── production_event_log_service
├── production_order_service (订单管理)
│   ├── message_service
│   │   ├── authz_service
│   │   └── audit_service
│   ├── quality_supplier_service
│   ├── assist_authorization_service
│   ├── authz_service
│   └── production_event_log_service
└── production_repair_service (维修)
    ├── production_event_log_service
    ├── production_order_service
    └── message_service
```

### 3.3 质量管理域依赖链

```
quality.py (Endpoint) → quality_service.py (纯 SQL 聚合，无 Service 依赖)
quality.py (Endpoint) → first_article_review_service.py
    ├── production_execution_service
    │   └── ... (见生产执行域)
    └── production_event_log_service
quality.py (Endpoint) → quality_supplier_service.py (无 Service 依赖)
```

### 3.4 设备管理域依赖链

```
equipment_service (设备)
├── audit_service
└── craft_service (is_valid_stage_code, list_enabled_stage_options)

equipment_rule_service (设备规则)
└── (无 Service 依赖)

maintenance_scheduler_service (后台定时任务)
├── equipment_service
├── message_service
└── user_service
```

### 3.5 消息推送域依赖链

```
message_service (消息中心)
├── authz_service
└── audit_service

message_push_service (实时推送)
└── message_connection_manager (WebSocket 连接池)
```

### 3.6 产品工艺域依赖链

```
product_service (产品)
└── craft_service (clone template)

craft_service (工艺 - 最大 Service)
├── process_code_rule
└── production_order_service

process_service (工序)
└── process_code_rule (无 Service 依赖)
```

### 3.7 首页仪表盘依赖链

```
home_dashboard_service (首页)
├── authz_snapshot_service
│   └── authz_service
├── message_service
├── production_data_query_service
├── production_statistics_service
└── quality_service
```

## 4. Endpoint → Service 挂载关系

| Endpoint 文件 | 直接调用的 Service | 主要功能 |
|--------------|-------------------|---------|
| `auth.py` | `user_service`, `session_service`, `authz_service` | 登录、登出、修改密码、Token |
| `authz.py` | `authz_service`, `authz_snapshot_service` | 权限目录、能力包配置、角色权限 |
| `users.py` | `user_service`, `user_export_task_service`, `role_service` | 用户 CRUD、注册审批、导出任务 |
| `roles.py` | `role_service` | 角色 CRUD |
| `sessions.py` | `session_service`, `online_status_service` | 在线会话、登录日志 |
| `products.py` | `product_service`, `craft_service` | 产品、版本、参数、影响分析 |
| `processes.py` | `process_service` | 工序 CRUD |
| `craft.py` | `craft_service`, `process_service`, `process_code_rule` | 工段、工艺模板、看板 |
| `production.py` | `production_order_service`, `production_execution_service`, `production_data_query_service`, `production_repair_service`, `production_statistics_service`, `assist_authorization_service` | 生产订单、执行、数据、维修、代班 |
| `quality.py` | `quality_service`, `first_article_review_service`, `quality_supplier_service` | 首件、质量统计、评审、供应商 |
| `equipment.py` | `equipment_service`, `equipment_rule_service` | 设备台账、保养、规则参数 |
| `messages.py` | `message_service`, `message_push_service`, `message_connection_manager` | 消息中心、公告、WebSocket |
| `audits.py` | `audit_service` | 审计日志 |
| `ui.py` | `authz_snapshot_service`, `home_dashboard_service`, `page_catalog_service` | 菜单/权限快照、首页仪表盘 |
| `system.py` | `bootstrap_seed_service`, `perf_*_service` | 系统初始化、性能测试数据生成 |
| `me.py` | `user_service` | 个人资料、密码修改 |

## 5. 架构特征

1. **所有 Service 均为函数集/模块级函数**，无需实例化，通过 `from app.services.xxx_service import func` 直接调用
2. **Session 传递**: 所有数据库操作均通过参数 `db: Session` 传入，由 FastAPI `Depends(get_db)` 注入
3. **权限校验**: 通过 `deps.py` 的 `require_permission(permission_code)` 依赖注入在路由层拦截，Service 层内部不做权限判断（除 `equipment_service` 的工单视图/操作权限之外）
4. **缓存策略**: 
   - 权限系统使用 Redis + 本地内存两级缓存，带 In-flight 并发控制
   - 质量统计使用本地缓存（5 秒 TTL）
   - 首页仪表盘使用本地缓存（5 秒 TTL）
   - 在线状态使用纯内存字典
5. **最大 Service**: `craft_service.py` (3779 行)、`production_order_service.py` (2473 行)、`message_service.py` (1609 行)
