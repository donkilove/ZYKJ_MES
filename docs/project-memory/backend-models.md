# 后端数据模型

## 基础设施

- **ORM**: SQLAlchemy 2.0 (DeclarativeBase)
- **Base 类**: `app.models.base.Base` → `app.db.base`（统一重新导出）
- **Session 工厂**: `app.db.session.SessionLocal` (sessionmaker)，生成器依赖 `get_db()`
- **公共混入**: `TimestampMixin` 提供 `created_at` / `updated_at`（DateTime+TZ, server_default=func.now()）
- **表命名约定**: `mes_*` 为业务表，`sys_*` 为系统表，`msg_*` 为消息表

---

## 1. 模型清单

共 55 个实体类（分布在 57 个 `.py` 文件中，含 2 个关联表定义文件），按域分组：

### 用户权限域（12 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| User | user.py | sys_user |
| Role | role.py | sys_role |
| RolePermissionGrant | role_permission_grant.py | sys_role_permission_grant |
| PermissionCatalog | permission_catalog.py | sys_permission_catalog |
| RegistrationRequest | registration_request.py | sys_registration_request |
| LoginLog | login_log.py | sys_login_log |
| UserSession | user_session.py | sys_user_session |
| UserExportTask | user_export_task.py | sys_user_export_task |
| AuditLog | audit_log.py | sys_audit_log |
| AuthzModuleRevision | authz_module_revision.py | sys_authz_module_revision |
| AuthzChangeLog | authz_change_log.py | sys_authz_change_log |
| AuthzChangeLogItem | authz_change_log.py | sys_authz_change_log_item |

关联表（associations.py）：
- `sys_user_role` — User ↔ Role 多对多
- `sys_user_process` — User ↔ Process 多对多

### 产品工艺域（15 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| Product | product.py | mes_product |
| ProductParameter | product_parameter.py | mes_product_parameter |
| ProductParameterHistory | product_parameter_history.py | mes_product_parameter_history |
| ProductRevision | product_revision.py | mes_product_revision |
| ProductRevisionParameter | product_revision_parameter.py | mes_product_revision_parameter |
| ProductProcessTemplate | product_process_template.py | mes_product_process_template |
| ProductProcessTemplateStep | product_process_template_step.py | mes_product_process_template_step |
| ProductProcessTemplateRevision | product_process_template_revision.py | mes_product_process_template_revision |
| ProductProcessTemplateRevisionStep | product_process_template_revision_step.py | mes_product_process_template_revision_step |
| CraftSystemMasterTemplate | craft_system_master_template.py | sys_craft_system_master_template |
| CraftSystemMasterTemplateStep | craft_system_master_template_step.py | sys_craft_system_master_template_step |
| CraftSystemMasterTemplateRevision | craft_system_master_template_revision.py | sys_craft_system_master_template_revision |
| CraftSystemMasterTemplateRevisionStep | craft_system_master_template_revision_step.py | sys_craft_system_master_template_revision_step |
| ProcessStage | process_stage.py | mes_process_stage |
| Process | process.py | mes_process |

### 生产执行域（9 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| ProductionOrder | production_order.py | mes_order |
| ProductionOrderProcess | production_order_process.py | mes_order_process |
| ProductionSubOrder | production_sub_order.py | mes_order_sub_order |
| ProductionRecord | production_record.py | mes_production_record |
| ProductionScrapStatistics | production_scrap_statistics.py | mes_production_scrap_statistics |
| ProductionAssistAuthorization | production_assist_authorization.py | mes_production_assist_authorization |
| OrderEventLog | order_event_log.py | mes_order_event_log |
| ProcessPipelineInstance | order_sub_order_pipeline_instance.py | mes_process_pipeline_instance |
| DailyVerificationCode | daily_verification_code.py | mes_daily_verification_code |

### 设备管理域（3 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| Equipment | equipment.py | mes_equipment |
| EquipmentRule | equipment_rule.py | mes_equipment_rule |
| EquipmentRuntimeParameter | equipment_runtime_parameter.py | mes_equipment_runtime_parameter |

### 维保域（4 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| MaintenanceItem | maintenance_item.py | mes_maintenance_item |
| MaintenancePlan | maintenance_plan.py | mes_maintenance_plan |
| MaintenanceWorkOrder | maintenance_work_order.py | mes_maintenance_work_order |
| MaintenanceRecord | maintenance_record.py | mes_maintenance_record |

### 维修域（4 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| RepairOrder | repair_order.py | mes_repair_order |
| RepairDefectPhenomenon | repair_defect_phenomenon.py | mes_repair_defect_phenomenon |
| RepairCause | repair_cause.py | mes_repair_cause |
| RepairReturnRoute | repair_return_route.py | mes_repair_return_route |

### 首件检验域（6 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| FirstArticleTemplate | first_article_template.py | mes_first_article_template |
| FirstArticleRecord | first_article_record.py | mes_first_article_record |
| FirstArticleParticipant | first_article_participant.py | mes_first_article_participant |
| FirstArticleReviewSession | first_article_review_session.py | mes_first_article_review_session |
| FirstArticleDisposition | first_article_disposition.py | mes_first_article_disposition |
| FirstArticleDispositionHistory | first_article_disposition_history.py | mes_first_article_disposition_history |

### 消息域（2 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| Message | message.py | msg_message |
| MessageRecipient | message_recipient.py | msg_message_recipient |

### 供应商域（1 个）

| 类名 | 文件 | 表名 |
|------|------|------|
| Supplier | supplier.py | mes_supplier |

---

## 2. 核心实体关系图

### 2.1 生产执行主链路

```
                              ┌─────────────────────┐
                              │       Product        │
                              └─────────┬───────────┘
                                        │ 1:N (product_id)
                              ┌─────────▼───────────┐
                    ┌─────────┤   ProductionOrder   ├─────────┐
                    │         └─────────┬───────────┘         │
                    │ 1:N              │ 1:N                  │ 1:N
                    │ (order_process)  │ (production_records) │ (first_article_records)
         ┌──────────▼──────────┐ ┌────▼──────────┐  ┌────────▼──────────┐
         │ProductionOrderProcess│ │ProductionRecord│  │ FirstArticleRecord│
         └──────────┬──────────┘ └────────────────┘  └───────────────────┘
                    │ 1:N (sub_orders)       ▲ N:1
         ┌──────────▼──────────┐             │
         │  ProductionSubOrder ├─────────────┘ (sub_order_id, nullable)
         └──────────┬──────────┘
                    │ 1:N (pipeline_instances)
         ┌──────────▼────────────────┐
         │ ProcessPipelineInstance   │
         └───────────────────────────┘
```

### 2.2 设备管理与维保链路

```
┌──────────┐
│ Equipment│
└────┬─────┘
     │ 1:N (plans)          1:N (work_orders)
     │              ┌───────────────┤
     ▼              ▼               ▼
┌─────────────┐  ┌─────────────────────┐  ┌────────────────┐
│MaintenancePlan│  │MaintenanceWorkOrder│  │  EquipmentRule │
└──────┬──────┘  └──────────┬──────────┘  └────────────────┘
       │ 1:N (work_orders)  │
       └─────────────────────┘
```

### 2.3 维修链路

```
┌──────────────────┐
│   RepairOrder    │
└──────┬───────────┘
       │ 1:N (defect_rows)  1:N (cause_rows)  1:N (return_routes)
       ▼                   ▼                  ▼
┌──────────────────┐ ┌────────────┐ ┌───────────────────┐
│RepairDefectPhenom│ │ RepairCause│ │ RepairReturnRoute │
└──────────────────┘ └────────────┘ └───────────────────┘
```

### 2.4 权限链路

```
User ──M:N──> sys_user_role <──M:N── Role
                                         │ 1:N (role_code → sys_role.code)
                                    ┌────▼────────────────┐
                                    │ RolePermissionGrant │
                                    └────┬────────────────┘
                                         │ N:1 (permission_code)
                                    ┌────▼────────────────┐
                                    │  PermissionCatalog  │
                                    └─────────────────────┘
```

### 2.5 产品工艺链路

```
Product ──1:N──> ProductParameter
Product ──1:N──> ProductRevision ──1:N──> ProductRevisionParameter
Product ──1:N──> ProductProcessTemplate ──1:N──> ProductProcessTemplateStep ──N:1──> ProcessStage
                                          │                                         │
                                          └──1:N──> ProductProcessTemplateRevision ──1:N──> RevisionStep ──N:1──> Process

CraftSystemMasterTemplate (单例, id=1)
  ──1:N──> CraftSystemMasterTemplateStep ──N:1──> ProcessStage / Process
  ──1:N──> CraftSystemMasterTemplateRevision ──1:N──> CraftSystemMasterTemplateRevisionStep ──N:1──> ProcessStage / Process
```

---

## 3. 各模型详细关系

### 3.1 User (sys_user)

- **外键**: `stage_id` → `mes_process_stage.id` (SET NULL)
- **关系**:
  - `roles`: M:N → Role，通过 `sys_user_role` 关联表
  - `processes`: M:N → Process，通过 `sys_user_process` 关联表
  - `stage`: N:1 → ProcessStage
- **反向引用来源**: ProductionOrder.created_by, ProductionRecord.operator, ProductionSubOrder.operator, ProductionAssistAuthorization (target/requester/helper/reviewer), ProductionScrapStatistics.operator, RepairOrder (sender/repair), RepairDefectPhenomenon.operator, RepairCause.operator, RepairReturnRoute.operator, OrderEventLog.operator, FirstArticleRecord (operator/reviewer), FirstArticleParticipant.user, FirstArticleReviewSession (operator/reviewer), FirstArticleDisposition.disposition_user, FirstArticleDispositionHistory.disposition_user, ProductParameterHistory.operator, ProductRevision.created_by, ProductProcessTemplate (created_by/updated_by), CraftSystemMasterTemplate (created_by/updated_by), CraftSystemMasterTemplateRevision.created_by, MaintenancePlan.default_executor, MaintenanceWorkOrder.executor, Message.created_by, MessageRecipient.recipient, AuditLog.operator, LoginLog.user, RegistrationRequest.reviewed_by, UserSession.user, UserExportTask.created_by, AuthzModuleRevision.updated_by, AuthzChangeLog.operator, DailyVerificationCode.created_by

### 3.2 Role (sys_role)

- **无外键**
- **关系**:
  - `users`: M:N → User，通过 `sys_user_role` 关联表
- **反向引用来源**: RolePermissionGrant（通过 `role_code` 非主键 FK → `sys_role.code`）

### 3.3 RolePermissionGrant (sys_role_permission_grant)

- **外键**:
  - `role_code` → `sys_role.code` (CASCADE)
  - `permission_code` → `sys_permission_catalog.permission_code` (CASCADE)
- **唯一约束**: `(role_code, permission_code)`

### 3.4 PermissionCatalog (sys_permission_catalog)

- **无外键**
- **字段**: `permission_code`, `permission_name`, `module_code`, `resource_type`, `parent_permission_code`, `is_enabled`
- **反向引用**: RolePermissionGrant.permission_code

### 3.5 Product (mes_product)

- **无外键**
- **关系**:
  - `parameters`: 1:N → ProductParameter，cascade all/delete-orphan
  - `parameter_histories`: 1:N → ProductParameterHistory，cascade all/delete-orphan
  - `revisions`: 1:N → ProductRevision，cascade all/delete-orphan，按 version desc 排序
- **反向引用来源**: ProductionOrder.product, ProductionScrapStatistics.product, RepairOrder.product, FirstArticleTemplate.product, ProductProcessTemplate.product, ProductRevisionParameter.product

### 3.6 ProductParameter (mes_product_parameter)

- **外键**: `product_id` → `mes_product.id` (CASCADE)
- **唯一约束**: `(product_id, param_key)`
- **关系**: `product`: N:1 → Product

### 3.7 ProductRevision (mes_product_revision)

- **外键**:
  - `product_id` → `mes_product.id` (CASCADE)
  - `source_revision_id` → `mes_product_revision.id` (SET NULL)，自引用
  - `created_by_user_id` → `sys_user.id` (SET NULL)
- **唯一约束**: `(product_id, version)`
- **关系**:
  - `product`: N:1 → Product
  - `source_revision`: N:1 → ProductRevision（自引用）
  - `created_by`: N:1 → User
  - `parameters`: 1:N → ProductRevisionParameter，cascade all/delete-orphan

### 3.8 ProcessStage (mes_process_stage)

- **无外键**
- **字段**: `code`, `name`, `sort_order`, `is_enabled`
- **关系**: `processes`: 1:N → Process
- **反向引用来源**: Process.stage, ProductionOrderProcess.stage, User.stage, ProductProcessTemplateStep.stage, CraftSystemMasterTemplateStep.stage, 以及各 RevisionStep.stage

### 3.9 Process (mes_process)

- **外键**: `stage_id` → `mes_process_stage.id` (RESTRICT)
- **关系**:
  - `users`: M:N → User，通过 `sys_user_process` 关联表
  - `stage`: N:1 → ProcessStage
- **反向引用来源**: ProductionOrderProcess.process, CraftSystemMasterTemplateStep.process, ProductProcessTemplateStep.process, 以及各 RevisionStep.process

### 3.10 ProductionOrder (mes_order)

- **外键**:
  - `product_id` → `mes_product.id` (RESTRICT)
  - `supplier_id` → `mes_supplier.id` (RESTRICT, nullable)
  - `process_template_id` → `mes_product_process_template.id` (SET NULL, nullable)
  - `created_by_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**:
  - `product`: N:1 → Product
  - `supplier`: N:1 → Supplier
  - `created_by`: N:1 → User
  - `process_template`: N:1 → ProductProcessTemplate
  - `processes`: 1:N → ProductionOrderProcess，cascade all/delete-orphan
  - `first_article_records`: 1:N → FirstArticleRecord，cascade all/delete-orphan
  - `production_records`: 1:N → ProductionRecord，cascade all/delete-orphan
  - `event_logs`: 1:N → OrderEventLog，cascade save-update/merge
  - `pipeline_instances`: 1:N → ProcessPipelineInstance，cascade all/delete-orphan

### 3.11 ProductionOrderProcess (mes_order_process)

- **外键**:
  - `order_id` → `mes_order.id` (CASCADE)
  - `process_id` → `mes_process.id` (RESTRICT)
  - `stage_id` → `mes_process_stage.id` (RESTRICT, nullable)
- **唯一约束**: `(order_id, process_order)`
- **关系**:
  - `order`: N:1 → ProductionOrder
  - `stage`: N:1 → ProcessStage
  - `process`: N:1 → Process
  - `sub_orders`: 1:N → ProductionSubOrder，cascade all/delete-orphan
  - `first_article_records`: 1:N → FirstArticleRecord，cascade all/delete-orphan
  - `production_records`: 1:N → ProductionRecord，cascade all/delete-orphan

### 3.12 ProductionSubOrder (mes_order_sub_order)

- **外键**:
  - `order_process_id` → `mes_order_process.id` (CASCADE)
  - `operator_user_id` → `sys_user.id` (RESTRICT)
- **唯一约束**: `(order_process_id, operator_user_id)`
- **关系**:
  - `order_process`: N:1 → ProductionOrderProcess
  - `operator`: N:1 → User
  - `production_records`: 1:N → ProductionRecord
  - `pipeline_instances`: 1:N → ProcessPipelineInstance

### 3.13 ProductionRecord (mes_production_record)

- **外键**:
  - `order_id` → `mes_order.id` (CASCADE)
  - `order_process_id` → `mes_order_process.id` (CASCADE)
  - `sub_order_id` → `mes_order_sub_order.id` (SET NULL, nullable)
  - `operator_user_id` → `sys_user.id` (RESTRICT)
- **关系**:
  - `order`: N:1 → ProductionOrder
  - `order_process`: N:1 → ProductionOrderProcess
  - `sub_order`: N:1 → ProductionSubOrder
  - `operator`: N:1 → User

### 3.14 ProcessPipelineInstance (mes_process_pipeline_instance)

- **外键**:
  - `sub_order_id` → `mes_order_sub_order.id` (SET NULL, nullable)
  - `order_id` → `mes_order.id` (CASCADE)
  - `order_process_id` → `mes_order_process.id` (CASCADE)
- **唯一约束**: `(sub_order_id, pipeline_seq)`, `pipeline_instance_no`
- **关系**:
  - `order`: N:1 → ProductionOrder
  - `order_process`: N:1 → ProductionOrderProcess
  - `sub_order`: N:1 → ProductionSubOrder

### 3.15 ProductionAssistAuthorization (mes_production_assist_authorization)

- **外键**:
  - `order_id` → `mes_order.id` (CASCADE)
  - `order_process_id` → `mes_order_process.id` (CASCADE)
  - `target_operator_user_id` → `sys_user.id` (RESTRICT)
  - `requester_user_id` → `sys_user.id` (RESTRICT)
  - `helper_user_id` → `sys_user.id` (RESTRICT)
  - `reviewer_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**（4 个指向 User 的 relationship，使用 foreign_keys 区分）:
  - `order`: N:1 → ProductionOrder
  - `order_process`: N:1 → ProductionOrderProcess
  - `target_operator`: N:1 → User
  - `requester`: N:1 → User
  - `helper`: N:1 → User
  - `reviewer`: N:1 → User

### 3.16 Equipment (mes_equipment)

- **无外键**
- **关系**:
  - `plans`: 1:N → MaintenancePlan
  - `work_orders`: 1:N → MaintenanceWorkOrder
- **反向引用来源**: EquipmentRule.equipment, EquipmentRuntimeParameter.equipment

### 3.17 MaintenancePlan (mes_maintenance_plan)

- **外键**:
  - `equipment_id` → `mes_equipment.id` (RESTRICT)
  - `item_id` → `mes_maintenance_item.id` (RESTRICT)
  - `default_executor_user_id` → `sys_user.id` (SET NULL, nullable)
- **唯一约束**: `(equipment_id, item_id)`
- **关系**:
  - `equipment`: N:1 → Equipment
  - `item`: N:1 → MaintenanceItem
  - `default_executor`: N:1 → User
  - `work_orders`: 1:N → MaintenanceWorkOrder

### 3.18 MaintenanceWorkOrder (mes_maintenance_work_order)

- **外键**:
  - `plan_id` → `mes_maintenance_plan.id` (SET NULL, nullable)
  - `equipment_id` → `mes_equipment.id` (SET NULL, nullable)
  - `item_id` → `mes_maintenance_item.id` (SET NULL, nullable)
  - `executor_user_id` → `sys_user.id` (SET NULL, nullable)
- **唯一约束**: `(plan_id, due_date)`
- **关系**:
  - `plan`: N:1 → MaintenancePlan
  - `equipment`: N:1 → Equipment
  - `item`: N:1 → MaintenanceItem
  - `executor`: N:1 → User

### 3.19 MaintenanceRecord (mes_maintenance_record)

- **无外键关系**（`work_order_id` 为普通 int 列，未声明 ForeignKey）
- **唯一约束**: `work_order_id`
- **无 relationship 定义**

### 3.20 RepairOrder (mes_repair_order)

- **外键**:
  - `source_order_id` → `mes_order.id` (SET NULL, nullable)
  - `product_id` → `mes_product.id` (SET NULL, nullable)
  - `source_order_process_id` → `mes_order_process.id` (SET NULL, nullable)
  - `sender_user_id` → `sys_user.id` (SET NULL, nullable)
  - `repair_operator_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**:
  - `source_order`: N:1 → ProductionOrder
  - `product`: N:1 → Product
  - `source_order_process`: N:1 → ProductionOrderProcess
  - `sender_user`: N:1 → User
  - `repair_operator_user`: N:1 → User
  - `defect_rows`: 1:N → RepairDefectPhenomenon，cascade all/delete-orphan
  - `cause_rows`: 1:N → RepairCause，cascade all/delete-orphan
  - `return_routes`: 1:N → RepairReturnRoute，cascade all/delete-orphan

### 3.21 RepairDefectPhenomenon (mes_repair_defect_phenomenon)

- **外键**:
  - `repair_order_id` → `mes_repair_order.id` (CASCADE)
  - `production_record_id` → `mes_production_record.id` (SET NULL, nullable)
  - `operator_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**:
  - `repair_order`: N:1 → RepairOrder
  - `operator_user`: N:1 → User
  - `production_record`: N:1 → ProductionRecord

### 3.22 RepairCause (mes_repair_cause)

- **外键**:
  - `repair_order_id` → `mes_repair_order.id` (CASCADE)
  - `operator_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**:
  - `repair_order`: N:1 → RepairOrder
  - `operator_user`: N:1 → User

### 3.23 FirstArticleRecord (mes_first_article_record)

- **外键**:
  - `order_id` → `mes_order.id` (CASCADE)
  - `order_process_id` → `mes_order_process.id` (CASCADE)
  - `operator_user_id` → `sys_user.id` (RESTRICT)
  - `template_id` → `mes_first_article_template.id` (SET NULL, nullable)
  - `reviewer_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**:
  - `order`: N:1 → ProductionOrder
  - `order_process`: N:1 → ProductionOrderProcess
  - `operator`: N:1 → User
  - `reviewer`: N:1 → User
  - `template`: N:1 → FirstArticleTemplate
  - `participants`: 1:N → FirstArticleParticipant，cascade all/delete-orphan

### 3.24 Message (msg_message)

- **外键**: `created_by_user_id` → `sys_user.id` (SET NULL, nullable)
- **关系**: `recipients`: 1:N → MessageRecipient，cascade all/delete-orphan
- **去重约束**: `dedupe_key` 非空时全局唯一（条件唯一索引）

### 3.25 MessageRecipient (msg_message_recipient)

- **外键**:
  - `message_id` → `msg_message.id` (CASCADE)
  - `recipient_user_id` → `sys_user.id` (CASCADE)
- **唯一约束**: `(message_id, recipient_user_id)`
- **关系**: `message`: N:1 → Message

### 3.26 Supplier (mes_supplier)

- **无外键**
- **关系**: `orders`: 1:N → ProductionOrder

### 3.27 AuditLog (sys_audit_log)

- **外键**: `operator_user_id` → `sys_user.id` (SET NULL, nullable)
- **无 relationship 定义**
- **字段**: 记录 `before_data`/`after_data` (JSON)、`action_code`、`target_type`、`target_id` 等

### 3.28 AuthzChangeLog (sys_authz_change_log)

- **外键**:
  - `operator_user_id` → `sys_user.id` (SET NULL, nullable)
  - `rollback_of_change_log_id` → `sys_authz_change_log.id` (SET NULL, nullable)，自引用
- **无 relationship 定义**
- **子实体**: AuthzChangeLogItem (sys_authz_change_log_item)，FK → sys_authz_change_log.id (CASCADE)

### 3.29 CraftSystemMasterTemplate (sys_craft_system_master_template)

- **单例表**: CHECK 约束 `id = 1`
- **外键**: `created_by_user_id` / `updated_by_user_id` → `sys_user.id` (SET NULL)
- **关系**:
  - `created_by`: N:1 → User
  - `updated_by`: N:1 → User
  - `steps`: 1:N → CraftSystemMasterTemplateStep，cascade all/delete-orphan，按 step_order asc
  - `revisions`: 1:N → CraftSystemMasterTemplateRevision，cascade all/delete-orphan，按 version desc

### 3.30 ProductProcessTemplate (mes_product_process_template)

- **外键**:
  - `product_id` → `mes_product.id` (CASCADE)
  - `source_template_id` → `mes_product_process_template.id` (SET NULL)，自引用
  - `source_product_id` → `mes_product.id` (SET NULL)
  - `created_by_user_id` / `updated_by_user_id` → `sys_user.id` (SET NULL)
- **唯一约束**: `(product_id, template_name, version)`
- **关系**:
  - `product`: N:1 → Product
  - `source_template`: N:1 → ProductProcessTemplate（自引用）
  - `source_product`: N:1 → Product
  - `created_by` / `updated_by`: N:1 → User
  - `steps`: 1:N → ProductProcessTemplateStep，cascade all/delete-orphan，按 step_order asc
  - `revisions`: 1:N → ProductProcessTemplateRevision，cascade all/delete-orphan，按 version desc

---

## 4. 关键设计模式

### 4.1 多对多关联

- **User ↔ Role**: 通过 `sys_user_role` 关联表（associations.py），含唯一约束 `user_id`
- **User ↔ Process**: 通过 `sys_user_process` 关联表
- 均使用 `relationship(secondary=...)`，无显式中间实体

### 4.2 非主键外键

- `RolePermissionGrant.role_code` → `sys_role.code`（使用 String FK 关联唯一字段而非主键 id）
- `RolePermissionGrant.permission_code` → `sys_permission_catalog.permission_code`

### 4.3 同一表多 relationship

- `ProductionAssistAuthorization` 有 4 个指向 User 的关系，通过 `foreign_keys=[...]` 区分
- `RepairOrder` 有 2 个指向 User 的关系（sender / repair_operator）
- `ProductProcessTemplate` 有 2 个指向 Product 的关系（product / source_product）
- `ProductProcessTemplate` 有 2 个指向 User 的关系（created_by / updated_by）

### 4.4 自引用外键

- `ProductRevision.source_revision_id` → `mes_product_revision.id`
- `ProductProcessTemplateRevision.source_revision_id` → 自身表
- `ProductProcessTemplate.source_template_id` → 自身表
- `AuthzChangeLog.rollback_of_change_log_id` → 自身表

### 4.5 单例表

- `CraftSystemMasterTemplate`: CHECK 约束 `id = 1`，确保全局仅一行

### 4.6 快照/冗余字段模式

多个模型同时存储 FK 和冗余快照字段：
- ProductionOrder: `supplier_id` + `supplier_name`, `process_template_id` + `process_template_name` + `process_template_version`
- ProductionOrderProcess: `stage_id` + `stage_code` + `stage_name`, `process_id` + `process_code` + `process_name`
- RepairOrder: `source_order_id` + `source_order_code`, `product_id` + `product_name`
- MaintenanceWorkOrder: `equipment_id` + `source_equipment_code` + `source_equipment_name` 等多组快照

### 4.7 版本/修订体系

两个并行版本体系：
- **产品参数版本**: Product → ProductRevision → ProductRevisionParameter
- **工艺模板版本**: ProductProcessTemplate → ProductProcessTemplateRevision → ProductProcessTemplateRevisionStep

此外，`CraftSystemMasterTemplate` 也有独立的修订链。

---

## 5. ondelete 策略统计

| 策略 | 说明 | 典型场景 |
|------|------|----------|
| CASCADE | 删除主记录时级联删除子记录 | Order → OrderProcess → SubOrder → Record |
| RESTRICT | 存在关联记录时禁止删除主记录 | Product → Order, Process → OrderProcess |
| SET NULL | 删除主记录时将外键置空 | User → Order.created_by, Equipment → Rule |
