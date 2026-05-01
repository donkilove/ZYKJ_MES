# 权限模型 RBAC

> 基于源码 `backend/app/core/` 和 `backend/app/models/` 验证，版本日期：2026-05-01。

---

## 1. 认证流程

### 1.1 JWT Token 生成

**入口**: 登录接口（API 层调用） → `backend/app/core/security.py`

| 函数 | 说明 |
|------|------|
| `create_access_token(subject, extra_claims, *, expires_minutes)` | 签发 JWT access_token |
| `decode_access_token(token)` | 解码并验证 JWT |
| `get_password_hash(password)` | 使用 bcrypt 生成密码哈希 |
| `verify_password(plain_password, hashed_password)` | 验证明文密码与哈希 |
| `verify_password_cached(plain_password, hashed_password, *, cache_scope, ttl_seconds)` | 带本地缓存的密码验证（TTL 60s） |

**JWT Payload 结构** (`security.py:58-68`):
```python
{
    "sub": user_id,       # 用户 ID（字符串形式）
    "exp": expire_time,   # 过期时间（UTC）
    "iat": issued_at,     # 签发时间（UTC）
    # + extra_claims（可选），如 session token_id
}
```

**JWT 配置** (`config.py:68-71`):

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `jwt_secret_key` | `"replace_with_a_strong_secret"` | JWT 签名密钥（必须显式修改） |
| `jwt_algorithm` | `"HS256"` | JWT 签名算法 |
| `jwt_expire_minutes` | `120` | Token 默认有效期（分钟） |
| `mobile_scan_review_jwt_expire_minutes` | `10080` | 扫码复核专用 Token 有效期（7天） |

安全门禁：`ensure_runtime_settings_secure()` 在每次签发/解码时检查 `jwt_secret_key` 是否为不安全值。

### 1.2 Token 验证

**入口**: `backend/app/api/deps.py` → `get_current_user()` (`deps.py:168-230`)

**流程**:
1. FastAPI `OAuth2PasswordBearer` 从请求头 `Authorization: Bearer <token>` 提取 token
2. 调用 `security.decode_access_token(token)` 解析 JWT，得到 `sub`（user_id）和 `sid`（session_token_id）
3. 校验 session：调用 `touch_session_by_token_id()` 验证会话存在且状态为 `active`
4. 查询数据库用户：`get_user_for_auth(db, user_id)`
5. 校验用户有效性：非删除、非禁用
6. 调用 `touch_user(user.id)` 更新在线状态

**多级缓存** (deps.py 内置):
| 缓存 | TTL | 说明 |
|------|-----|------|
| `_AUTH_USER_CACHE` | 10s | 按 session_token_id 缓存 User 对象，仅用于 GET/HEAD 且排除特定路径 |
| `_PERMISSION_DECISION_CACHE` | 10s | 按 `role_key + permission_key` 缓存布尔决策 |
| `_SESSION_PERMISSION_DECISION_CACHE` | 20s | 按 `session_token_id + permission_code` 缓存（用于 `require_permission_fast`） |

缓存失效：由 `authz_cache_service._authz_cache_generation_value()` 驱动，当权限配置变更时 generation 递增，触发所有决策缓存清空。

### 1.3 关键类/函数一览

| 文件 | 函数 | 作用 |
|------|------|------|
| `security.py:55` | `create_access_token()` | JWT 签发 |
| `security.py:71` | `decode_access_token()` | JWT 解码与验证 |
| `security.py:19` | `verify_password()` | bcrypt 密码校验 |
| `deps.py:168` | `get_current_user()` | 从请求提取当前用户 |
| `deps.py:233` | `get_current_active_user()` | 包装 `get_current_user` |
| `deps.py:237` | `require_role_codes()` | 基于 role code 的依赖 |
| `deps.py:247` | `require_permission()` | 基于 permission code 的依赖 |
| `deps.py:272` | `require_any_permission()` | 满足任一权限即放行 |
| `deps.py:303` | `require_permission_fast()` | 轻量权限校验（跳过 User 对象完整加载） |
| `config.py:117` | `ensure_runtime_settings_secure()` | JWT/密码安全门禁 |

---

## 2. 授权流程

### 2.1 RBAC 核心

**入口**: `backend/app/core/rbac.py` + `deps.py` + `authz_service`

`rbac.py` 定义角色常量与角色描述：
```python
ROLE_SYSTEM_ADMIN      = "system_admin"       # 系统管理员
ROLE_PRODUCTION_ADMIN   = "production_admin"   # 生产管理员
ROLE_QUALITY_ADMIN      = "quality_admin"      # 品质管理员
ROLE_OPERATOR           = "operator"           # 操作员
ROLE_MAINTENANCE_STAFF  = "maintenance_staff"  # 维修员
```

### 2.2 权限决策链路

```
HTTP 请求 → FastAPI 依赖注入(deps.py)
  → get_current_user()          # JWT 解析 + 会话验证 + 用户查询
  → require_permission(code)    # 权限决策
      → get_user_permission_codes(db, user)    # 查询 user 的有效 permission_codes
          → 从 RolePermissionGrant 表查询角色授权
          → system_admin 角色自动拥有所有权限
          → 非 system_admin 角色默认拥有 user 模块基础权限（公共权限集）
      → permission_code in effective_codes     # 匹配判断
      → 缓存决策结果（10s TTL）
  → 403 拒绝 或 放行
```

### 2.3 角色-权限关系

```
User (sys_user)
  └── user_roles (sys_user_role)  — N:1（UNIQUE 约束确保每用户仅一个角色）
        └── Role (sys_role)
              └── RolePermissionGrant (sys_role_permission_grant)  — N:M
                    └── PermissionCatalog (sys_permission_catalog)
```

> **重要**: `sys_user_role` 表有 `UNIQUE(user_id)` 约束，即每个用户只能绑定一个角色（非标准 N:M）。

实际关系：
- `User.roles` (relationship via `user_roles` 关联表) → Role
- `Role.users` (relationship back_populates) → User
- `RolePermissionGrant` 通过 `role_code` 外键关联 `sys_role.code`

### 2.4 系统管理员特权

`authz_catalog.py:1119-1134` 中的 `default_permission_granted()`:
- `role_code == "system_admin"` → **直接返回 True**，不检查任何权限
- 非管理员角色默认拥有「用户模块基础权限集」：个人中心、密码修改、会话查看等

### 2.5 默认页面可见性

`page_catalog.py:426-558` 中的 `DEFAULT_VISIBLE_PAGES_BY_ROLE`:
- `system_admin`: 全部页面（首页 + 所有模块）
- `production_admin`: 不含注册审批、角色管理、审计日志、登录日志、功能权限配置
- `quality_admin`: 仅质量相关 + 基础页面
- `operator`: 仅生产订单查询 + 基础页面
- `maintenance_staff`: 仅保养执行/记录 + 基础页面

### 2.6 权限依赖注入使用示例

```python
# 在 API 路由中使用
@router.get("/users", dependencies=[Depends(require_permission("user.users.list"))])
def list_users():
    ...

@router.post("/users", dependencies=[Depends(require_any_permission(["user.users.create", "user.users.import"]))])
def create_user():
    ...

@router.delete("/users/{user_id}", dependencies=[Depends(require_role_codes(["system_admin"]))])
def delete_user():
    ...
```

---

## 3. 权限目录

### 3.1 文件结构

| 文件 | 作用 |
|------|------|
| `app/core/rbac.py` | 角色码常量与定义 |
| `app/core/authz_hierarchy_catalog.py` | 模块定义 + Feature 定义（含分层依赖） |
| `app/core/authz_catalog.py` | 权限总目录：Module → Page → Feature → Action 四层 |

### 3.2 权限四层结构

```
Module (模块级)  →  permission_code = "module.{module_code}.access"
   ├── Page (页面级)  →  permission_code = "page.{page_code}.view"
   │     ├── Feature (功能级)  →  permission_code = "feature.{module}.{page}.{name}"
   │     │     └── Action (操作级) → permission_code = "{module}.{resource}.{action}"
   │     └── Action (操作级，也可直挂 Page 下)
   └── ...
```

### 3.3 资源类型

`authz_catalog.py:22-25`:
| 常量 | 值 | 说明 |
|------|-----|------|
| `AUTHZ_RESOURCE_MODULE` | `"module"` | 模块入口权限 |
| `AUTHZ_RESOURCE_PAGE` | `"page"` | 页面访问权限 |
| `AUTHZ_RESOURCE_FEATURE` | `"feature"` | 功能包权限（聚合一组 Action） |
| `AUTHZ_RESOURCE_ACTION` | `"action"` | 具体操作权限（CRUD 等） |

### 3.4 模块定义

| module_code | module_name | 权限码 |
|-------------|-------------|--------|
| `system` | 系统管理 | `module.system.access` |
| `user` | 用户管理 | `module.user.access` |
| `product` | 产品管理 | `module.product.access` |
| `equipment` | 设备管理 | `module.equipment.access` |
| `craft` | 工艺管理 | `module.craft.access` |
| `quality` | 质量管理 | `module.quality.access` |
| `production` | 生产管理 | `module.production.access` |
| `message` | 消息中心 | `module.message.access` |

### 3.5 Feature 定义

Feature 是权限打包的最小可分配单元（`authz_hierarchy_catalog.py:47-855`）。每个 Feature 包含：

| 字段 | 说明 |
|------|------|
| `permission_code` | Feature 自身的权限码 |
| `permission_name` | 中文名称 |
| `module_code` | 所属模块 |
| `page_code` | 所属页面 |
| `action_permission_codes` | 包含的一组 Action 权限码 |
| `dependency_permission_codes` | 依赖的其他 Feature |
| `hidden_in_capability_pack` | 是否在能力包中隐藏 |
| `assignable_role_codes` | 限定的可分配角色 |

总计约 **56 个 Feature 定义**，覆盖：
- 系统管理 (3): 权限目录查看、角色权限管理、强制下线
- 用户管理 (14): 用户 CRUD、注册审批、角色管理、审计日志、个人中心、登录日志
- 产品管理 (7): 产品目录、版本管理、参数管理
- 设备管理 (8): 设备台账、保养项目/计划/执行/记录、规则与参数
- 工艺管理 (6): 工段工序、工艺模板、看板、引用分析
- 质量管理 (12): 首件管理、数据统计、报废统计、维修订单、不良分析、供应商管理
- 生产管理 (12): 订单管理、并行模式、工单查询与执行、代班、数据查询、报废统计、维修订单、并行实例
- 消息管理 (5): 消息中心、已读管理、详情查看、跳转、公告发布

### 3.6 Action 权限

`authz_catalog.py:234-1088` 中的 `ACTION_DEFINITIONS`，总计约 **200+ 条** Action 权限。命名规范：`{module}.{resource}.{action}`。

示例：
- `user.users.list` — 查看用户列表
- `equipment.ledger.create` — 新增设备台账
- `craft.templates.publish` — 发布模板
- `production.orders.complete` — 结束生产订单
- `quality.suppliers.delete` — 删除供应商
- `message.announcements.publish` — 发布站内公告

---

## 4. 页面目录

### 4.1 文件位置

`backend/app/core/page_catalog.py`

### 4.2 页面类型

| 常量 | 值 | 说明 |
|------|-----|------|
| `PAGE_TYPE_SIDEBAR` | `"sidebar"` | 侧边栏顶层菜单（模块入口） |
| `PAGE_TYPE_TAB` | `"tab"` | 选项卡子页面（模块内页） |

### 4.3 页面树结构

`PAGE_CATALOG` (`page_catalog.py:61-413`) 定义了 **46 个页面条目**，通过 `parent_code` 形成两级树：

```
首页 (home, sidebar, always_visible)
├── 用户 (user, sidebar)
│   ├── 用户管理 (user_management, tab)
│   ├── 注册审批 (registration_approval, tab)
│   ├── 角色管理 (role_management, tab)
│   ├── 操作审计日志 (audit_log, tab)
│   ├── 个人中心/账号设置 (account_settings, tab)
│   ├── 登录日志/在线会话 (login_session, tab)
│   └── 功能权限配置 (function_permission_config, tab)
├── 产品 (product, sidebar)
│   ├── 产品管理 (product_management, tab)
│   ├── 版本管理 (product_version_management, tab)
│   ├── 产品参数管理 (product_parameter_management, tab)
│   └── 产品参数查询 (product_parameter_query, tab)
├── 设备 (equipment, sidebar)
│   ├── 设备台账 (equipment_ledger, tab)
│   ├── 保养项目 (maintenance_item, tab)
│   ├── 保养计划 (maintenance_plan, tab)
│   ├── 保养执行 (maintenance_execution, tab)
│   ├── 保养记录 (maintenance_record, tab)
│   └── 规则与参数 (equipment_rule_parameter, tab)
├── 生产 (production, sidebar)
│   ├── 订单管理 (production_order_management, tab)
│   ├── 订单查询 (production_order_query, tab)
│   ├── 代班记录 (production_assist_records, tab)
│   ├── 生产数据 (production_data_query, tab)
│   ├── 报废统计 (production_scrap_statistics, tab)
│   ├── 维修订单 (production_repair_orders, tab)
│   └── 并行实例追踪 (production_pipeline_instances, tab)
├── 质量 (quality, sidebar)
│   ├── 首件管理 (first_article_management, tab)
│   ├── 质量数据 (quality_data_query, tab)
│   ├── 报废统计 (quality_scrap_statistics, tab)
│   ├── 维修订单 (quality_repair_orders, tab)
│   ├── 质量趋势 (quality_trend, tab)
│   ├── 不良分析 (quality_defect_analysis, tab)
│   └── 供应商管理 (quality_supplier_management, tab, always_visible)
├── 工艺 (craft, sidebar)
│   ├── 工序管理 (process_management, tab)
│   ├── 生产工序配置 (production_process_config, tab)
│   ├── 工艺看板 (craft_kanban, tab)
│   └── 引用分析 (craft_reference_analysis, tab)
└── 消息 (message, sidebar)
    └── 消息中心 (message_center, tab)
```

### 4.4 前端渲染规则

- 前端通过调用后端 `/api/v1/pages/` 或等效接口获取 `PAGE_CATALOG`
- 根据当前用户的角色（`role_code`）和权限（`permission_codes`）过滤可见页面
- `always_visible=True` 的页面（"首页"、"供应商管理"）对所有角色可见
- 其余页面按 `DEFAULT_VISIBLE_PAGES_BY_ROLE` 结合 PermissionGrant 动态决定可见性
- `sort_order` 控制菜单排序

---

## 5. 数据模型

### 5.1 模型总览

| 模型 | 表名 | 说明 |
|------|------|------|
| `User` | `sys_user` | 用户 |
| `Role` | `sys_role` | 角色 |
| `user_roles` (Table) | `sys_user_role` | 用户-角色关联表 |
| `RolePermissionGrant` | `sys_role_permission_grant` | 角色-权限授权表 |
| `PermissionCatalog` | `sys_permission_catalog` | 权限目录（持久化冗余） |
| `AuthzModuleRevision` | `sys_authz_module_revision` | 模块权限版本号 |
| `AuthzChangeLog` | `sys_authz_change_log` | 权限变更日志 |
| `AuthzChangeLogItem` | `sys_authz_change_log_item` | 权限变更日志明细 |

### 5.2 User 模型 (`app/models/user.py`)

**表**: `sys_user`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int (PK) | 主键 |
| `username` | str(64), unique | 用户名 |
| `full_name` | str(128), nullable | 姓名 |
| `password_hash` | str(255) | bcrypt 密码哈希 |
| `is_active` | bool, default=True | 是否启用 |
| `is_superuser` | bool, default=False | 超管标记（预留） |
| `is_deleted` | bool, default=False | 软删除标记 |
| `deleted_at` | datetime, nullable | 删除时间 |
| `stage_id` | FK→mes_process_stage, nullable | 所属工段 |
| `remark` | str(255), nullable | 备注 |
| `must_change_password` | bool, default=False | 是否需强制修改密码 |
| `password_changed_at` | datetime, nullable | 上次密码修改时间 |
| `last_login_at` | datetime, nullable | 最后登录时间 |
| `last_login_ip` | str(64), nullable | 最后登录 IP |
| `last_login_terminal` | str(255), nullable | 最后登录终端 |

**关系**:
- `users.roles` → `Role`（通过 `user_roles` 关联表，N:1 因为 UNIQUE 约束）
- `users.processes` → `Process`（通过 `user_processes` 关联表）
- `users.stage` → `ProcessStage`（多对一）

### 5.3 Role 模型 (`app/models/role.py`)

**表**: `sys_role`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int (PK) | 主键 |
| `code` | str(64), unique | 角色码（`system_admin` 等） |
| `name` | str(128) | 显示名称 |
| `description` | str(255), nullable | 角色描述 |
| `role_type` | str(32), default=`"custom"` | 角色类型 |
| `is_builtin` | bool, default=False | 是否内置角色 |
| `is_enabled` | bool, default=True | 是否启用 |
| `is_deleted` | bool, default=False | 软删除标记 |

所有模型继承 `TimestampMixin`（含 `created_at`、`updated_at`）。

**关系**:
- `Role.users` → `User`（反向关系，通过 `user_roles` 关联表）

### 5.4 User-Role 关联表 (`app/models/associations.py`)

**表**: `sys_user_role`

| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | FK→sys_user.id, PK | 用户 ID |
| `role_id` | FK→sys_role.id, PK | 角色 ID |

**约束**: `UNIQUE(user_id)` → 每个用户仅可绑定一个角色。

### 5.5 Role-Permission 授权表 (`app/models/role_permission_grant.py`)

**表**: `sys_role_permission_grant`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int (PK) | 主键 |
| `role_code` | str(64), FK→sys_role.code | 角色码 |
| `permission_code` | str(128), FK→sys_permission_catalog.permission_code | 权限码 |
| `granted` | bool, default=False | 是否授予 |

**约束**: `UNIQUE(role_code, permission_code)`。

### 5.6 Permission Catalog 持久化表 (`app/models/permission_catalog.py`)

**表**: `sys_permission_catalog`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int (PK) | 主键 |
| `permission_code` | str(128), unique | 权限码 |
| `permission_name` | str(128) | 中文名称 |
| `module_code` | str(64) | 所属模块 |
| `resource_type` | str(32) | 资源类型（module/page/feature/action） |
| `parent_permission_code` | str(128), nullable | 父权限码 |
| `is_enabled` | bool, default=True | 是否启用 |

此表由启动时的权限同步逻辑与 Python 源码中的 `PERMISSION_CATALOG` 保持一致。

### 5.7 Authz 变更审计模型

**`AuthzModuleRevision`** (`authz_module_revision.py`):
- `module_code` (unique): 模块码
- `revision`: 版本号（递增）
- `updated_by_user_id`: 操作人

用于驱动缓存失效（`deps.py` 中 `_sync_permission_decision_caches_with_generation`）。

**`AuthzChangeLog`** (`authz_change_log.py`):
- 权限配置变更的完整快照（`snapshot_json`）
- 支持回滚（`rollback_of_change_log_id`）

**`AuthzChangeLogItem`** (`authz_change_log.py`):
- 每条变更的 before/after 能力码差异
- `added_capability_codes` / `removed_capability_codes` / `effective_capability_codes`

---

## 6. 工序定义 (rbac.py)

`rbac.py:17-53` 中的 `DEFAULT_PROCESS_DEFINITIONS` 定义了 6 种工序：

| stage_code | stage_name | code | name |
|------------|------------|------|------|
| `laser_marking` | 激光打标 | `laser_marking_fiber` | 光纤打标 |
| `laser_marking` | 激光打标 | `laser_marking_uv` | 紫光打标 |
| `laser_marking` | 激光打标 | `laser_marking_auto_fiber` | 自动光纤打标 |
| `product_testing` | 产品测试 | `product_testing_general` | 通用测试 |
| `product_assembly` | 产品组装 | `product_assembly_general` | 通用组装 |
| `product_packaging` | 产品包装 | `product_packaging_general` | 通用包装 |

用户通过 `user_processes` 关联表与工序绑定，用于工序级数据隔离。

---

## 7. Redis 权限缓存

`config.py:38-40`:

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `authz_permission_cache_redis_enabled` | `True` | 是否启用 Redis 权限缓存 |
| `authz_permission_cache_prefix` | `"authz:permission:v1"` | Redis Key 前缀 |
| `authz_permission_cache_ttl_seconds` | `60` | Redis 缓存 TTL |

权限查询优先走进程内缓存（`dept.py` 多级缓存），Redis 作为分布式二级缓存（通过 `authz_cache_service` 实现）。

---

*本文档基于实际源码验证，类名、函数名、常量名均与源码保持一致。*
