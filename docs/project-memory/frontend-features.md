# 前端功能模块

> 基于源码验证，编写于 2026-05-01。
> 源码根路径: `frontend/lib/`

## 概述

Flutter 前端采用 **模块化特征目录** 架构，共 13 个 feature 模块 + 1 个 core 基础设施层。导航基于 `MainShellPage` + `PageCatalog` 动态菜单/权限驱动，不依赖传统路由表（GoRouter/命名路由）。每个模块暴露约定页面入口，由 `MainShellPageRegistry` 按 `pageCode` 装配。

状态管理不依赖第三方框架（如 Riverpod/Bloc），而是使用 **ChangeNotifier + AnimatedBuilder** 自定义监听器模式。

---

## core/ — 基础设施层

**路径**: `lib/core/`

| 子目录 | 用途 |
|--------|------|
| `core/network/` | 封装 HTTP 客户端 (`http_client.dart`) 和 `ApiException` |
| `core/models/` | `AppSession`, `CurrentUser`, `AuthzSnapshot`, `PageCatalogItem` 等核心数据模型 |
| `core/services/` | `PageCatalogService` 等基础设施服务 |
| `core/ui/` | `MesLoadingState` 等通用 UI 组件 |
| `core/widgets/` | 通用 Widget |
| `core/config/` | 应用配置 |

### HTTP 客户端

`core/network/http_client.dart` — 包装 `package:http` 的 `get`/`post`/`put`/`patch`/`delete` 方法，统一 30 秒超时，捕获 `TimeoutException` 和 `ClientException` 转为 `ApiException`。

部分服务（如 `auth_service`、`message_service`）直接使用 `package:http`，其他多数服务引用 `http_client.dart`。

### API 响应结构

统一格式 `{ "data": {...}, "message": "...", "detail": "..." }`，各服务自行 `_decodeBody` 提取 `data` 字段。

---

## features/shell/ — 主壳与导航

**路径**: `lib/features/shell/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

应用的主容器与导航框架。管理侧边栏菜单、Tab 页签、权限快照、WebSocket 消息通知轮询、首页工作台数据。

### 关键文件

- `main_shell_page.dart` — Shell 入口 StatefulWidget，初始化全部子控制器
- `main_shell_page_registry.dart` — 按 `pageCode` 分发到各模块页面
- `main_shell_navigation.dart` — 菜单、Tab 构建与目标解析逻辑
- `main_shell_state.dart` — Shell 状态模型 (`MainShellViewState`)
- `main_shell_controller.dart` — Shell 主控制器
- `home_page.dart` — 首页工作台（含快捷跳转卡片）

### 导航机制

不依赖传统路由路径。核心是 **pageCode（页面编码）** 驱动的动态装配：

1. 服务端下发 `PageCatalogItem` 列表（`sidebar` / `tab` / `utility` 类型）
2. Shell 根据 `pageCode` 在 `MainShellPageRegistry.build()` 中 `switch-case` 选择实例化的页面 Widget
3. 菜单和 Tab 通过 `buildMainShellMenus()` 和 `filterVisibleTabCodesForParent()` 根据权限和可见性配置生成
4. 页面间跳转通过 `onNavigateToPageTarget(pageCode, tabCode, routePayloadJson)` 回调实现

支持的主页面编码: `home`, `user`, `product`, `equipment`, `production`, `quality`, `craft`, `message`  
工具页面编码: `software_settings`, `plugin_host`

### API 调用

- `GET /ui/home-dashboard` — 首页工作台数据

### 状态管理

`MainShellController` (ChangeNotifier) + `MainShellViewState` 管理全局状态，`AnimatedBuilder` 驱动渲染。

---

## features/auth/ — 认证与授权

**路径**: `lib/features/auth/`
**子目录**: `presentation/`, `services/`

### 主要职责

用户登录、注册、登出、令牌续期、当前用户信息获取、权限快照与权限管理（角色-权限矩阵、权限层级、能力包）。

### 服务

| 服务 | 文件 | 职责 |
|------|------|------|
| `AuthService` | `auth_service.dart` | 登录/注册/登出/令牌续期/获取当前用户 |
| `AuthzService` | `authz_service.dart` | 权限快照、角色权限、权限层级、能力包管理 |

### API 端点 (AuthService)

| 方法 | 路径 | 用途 |
|------|------|------|
| `POST` | `/auth/login` | 用户登录 |
| `POST` | `/auth/mobile-scan-review-login` | 扫码审核登录 |
| `POST` | `/auth/register` | 用户注册 |
| `GET` | `/auth/accounts` | 获取账户列表 |
| `GET` | `/auth/me` | 获取当前用户信息 |
| `POST` | `/auth/logout` | 登出 |
| `POST` | `/auth/renew-token` | 令牌续期 |

### API 端点 (AuthzService)

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/authz/snapshot` | 权限快照 |
| `GET` | `/authz/permissions/me` | 我的权限码列表 |
| `GET` | `/authz/permissions/catalog` | 权限目录 |
| `GET` | `/authz/role-permissions` | 角色权限详情 |
| `PUT` | `/authz/role-permissions/{roleCode}` | 更新角色权限 |
| `GET` | `/authz/role-permissions/matrix` | 角色权限矩阵 |
| `PUT` | `/authz/role-permissions/matrix` | 批量更新角色权限矩阵 |
| `GET` | `/authz/hierarchy/catalog` | 权限层级目录 |
| `GET` | `/authz/hierarchy/role-config` | 层级角色配置 |
| `PUT` | `/authz/hierarchy/role-config/{roleCode}` | 更新层级角色配置 |
| `POST` | `/authz/hierarchy/preview` | 预览权限层级 |
| `GET` | `/authz/capability-packs/catalog` | 能力包目录 |
| `GET` | `/authz/capability-packs/role-config` | 能力包角色配置 |
| `PUT` | `/authz/capability-packs/role-config/{roleCode}` | 更新能力包角色配置 |
| `PUT` | `/authz/capability-packs/batch-apply` | 批量应用能力包 |
| `GET` | `/authz/capability-packs/effective` | 能力包生效结果 |

### 页面

登录页、注册页、强制修改密码页属于 `features/misc/`，不在此目录。auth 模块主要作为服务层被其他页面引用。

### 状态管理

直接从 `AppSession` 读取 `accessToken` 和 `baseUrl`，每次调用动态构造认证 Header。`AuthzSnapshot` 通过 `MainShellController` 级联持有和刷新。

---

## features/user/ — 用户管理

**路径**: `lib/features/user/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

用户 CRUD、角色管理、注册审核、在线会话管理、登录日志、审计日志、个人资料修改、用户导入导出、强制下线等。

### 服务

`UserService` (`user_service.dart`)

### API 端点

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/users` | 用户列表 |
| `GET` | `/users/{userId}` | 用户详情 |
| `POST` | `/users` | 创建用户 |
| `PUT` | `/users/{userId}` | 更新用户 |
| `POST` | `/users/{userId}/enable` | 启用用户 |
| `POST` | `/users/{userId}/disable` | 禁用用户 |
| `DELETE` | `/users/{userId}` | 删除用户 |
| `POST` | `/users/{userId}/restore` | 恢复用户 |
| `POST` | `/users/{userId}/reset-password` | 重置密码 |
| `GET` | `/users/online-status` | 批量查询在线状态 |
| `GET` | `/users/export` | 导出用户 CSV |
| `POST` | `/users/export-tasks` | 创建导出任务 |
| `GET` | `/users/export-tasks` | 导出任务列表 |
| `GET` | `/users/export-tasks/{taskId}` | 导出任务详情 |
| `GET` | `/users/export-tasks/{taskId}/download` | 下载导出文件 |
| `POST` | `/users/import` | 导入用户 (Multipart) |
| `GET` | `/roles` | 角色列表 |
| `POST` | `/roles` | 创建角色 |
| `PUT` | `/roles/{roleId}` | 更新角色 |
| `POST` | `/roles/{roleId}/enable` | 启用角色 |
| `POST` | `/roles/{roleId}/disable` | 禁用角色 |
| `DELETE` | `/roles/{roleId}` | 删除角色 |
| `GET` | `/auth/register-requests` | 注册审核列表 |
| `POST` | `/auth/register-requests/{id}/approve` | 批准注册 |
| `POST` | `/auth/register-requests/{id}/reject` | 拒绝注册 |
| `GET` | `/me/profile` | 个人资料 |
| `GET` | `/me/session` | 当前会话信息 |
| `POST` | `/me/password` | 修改密码 |
| `GET` | `/audits` | 审计日志 |
| `GET` | `/sessions/login-logs` | 登录日志 |
| `GET` | `/sessions/online` | 在线会话列表 |
| `POST` | `/sessions/force-offline` | 强制下线 |
| `POST` | `/sessions/force-offline/batch` | 批量强制下线 |
| `GET` | `/processes` | 工序列表（供用户分配工序参考） |

### 页面

`UserPage` — 多 Tab 用户管理主页面，支持子 Tab: 用户列表、角色管理、注册审核、审计日志、在线会话等。

### 状态管理

继承 `AppSession`，通过 `ChangeNotifier` 驱动筛选/分页/刷新。

---

## features/product/ — 产品与参数版本管理

**路径**: `lib/features/product/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

产品 CRUD、参数版本管理（创建/复制/激活/禁用/删除版本）、参数查询（有效参数/历史参数/版本比较）、产品生命周期管理、影响分析、导入导出。

### 服务

`ProductService` (`product_service.dart`)

### API 端点

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/products` | 产品列表 |
| `POST` | `/products` | 创建产品 |
| `GET` | `/products/{productId}` | 产品详情（单品） |
| `GET` | `/products/{productId}/detail` | 产品详情（含版本/模板） |
| `PUT` | `/products/{productId}` | 更新产品 |
| `POST` | `/products/{productId}/delete` | 删除产品（需密码确认） |
| `GET` | `/products/parameter-query` | 参数维度查询 |
| `GET` | `/products/parameter-versions` | 参数版本列表 |
| `GET` | `/products/{productId}/versions` | 产品版本列表 |
| `POST` | `/products/{productId}/versions` | 创建版本 |
| `POST` | `/products/{productId}/versions/{v}/copy` | 复制版本 |
| `POST` | `/products/{productId}/versions/{v}/activate` | 激活版本 |
| `POST` | `/products/{productId}/versions/{v}/disable` | 禁用版本 |
| `DELETE` | `/products/{productId}/versions/{v}` | 删除版本 |
| `PATCH` | `/products/{productId}/versions/{v}/note` | 更新版本备注 |
| `GET` | `/products/{productId}/versions/{v}/parameters` | 版本参数 |
| `GET` | `/products/{productId}/effective-parameters` | 有效参数 |
| `PUT` | `/products/{productId}/versions/{v}/parameters` | 更新参数 |
| `GET` | `/products/{productId}/parameter-history` | 参数历史 |
| `GET` | `/products/{productId}/versions/compare` | 版本比较 |
| `POST` | `/products/{productId}/lifecycle` | 生命周期变更 |
| `POST` | `/products/{productId}/rollback` | 产品回滚 |
| `GET` | `/products/{productId}/impact-analysis` | 影响分析 |
| `GET` | `/products/export/list` | 导出产品列表 |
| `GET` | `/products/parameters/export` | 导出参数 |
| `GET` | `/products/{productId}/versions/{v}/export` | 导出版本参数 CSV |

### 页面

`ProductPage` — 产品管理，Tab 切换：产品列表、参数版本管理、导入导出。

### 状态管理

列表分页 + 筛选通过 `ChangeNotifier` 管理。

---

## features/craft/ — 工艺管理

**路径**: `lib/features/craft/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

工序阶段（stage）、工序（process）、工艺模板（template）的 CRUD，版本控制（发布/归档/回滚、版本历史与比较）、系统主模板管理、看板指标、导入导出。

### 服务

`CraftService` (`craft_service.dart`)

### API 端点

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/craft/stages` | 阶段列表 |
| `GET` | `/craft/stages/light` | 阶段轻量选项 |
| `GET` | `/craft/stages/detail` | 阶段详情 |
| `POST` | `/craft/stages` | 创建阶段 |
| `PUT` | `/craft/stages/{id}` | 更新阶段 |
| `DELETE` | `/craft/stages/{id}` | 删除阶段 |
| `GET` | `/craft/stages/{id}/references` | 阶段引用检查 |
| `GET` | `/craft/stages/export` | 导出阶段 |
| `GET` | `/craft/processes` | 工序列表 |
| `GET` | `/craft/processes/light` | 工序轻量选项 |
| `GET` | `/craft/processes/detail` | 工序详情 |
| `POST` | `/craft/processes` | 创建工序 |
| `PUT` | `/craft/processes/{id}` | 更新工序 |
| `DELETE` | `/craft/processes/{id}` | 删除工序 |
| `GET` | `/craft/processes/{id}/references` | 工序引用检查 |
| `GET` | `/craft/processes/export` | 导出工序 |
| `GET` | `/craft/templates` | 模板列表 |
| `GET` | `/craft/templates/{id}` | 模板详情 |
| `POST` | `/craft/templates` | 创建模板 |
| `PUT` | `/craft/templates/{id}` | 更新模板 |
| `DELETE` | `/craft/templates/{id}` | 删除模板 |
| `POST` | `/craft/templates/{id}/publish` | 发布模板 |
| `GET` | `/craft/templates/{id}/versions` | 模板版本历史 |
| `GET` | `/craft/templates/{id}/versions/compare` | 模板版本比较 |
| `POST` | `/craft/templates/{id}/rollback` | 模板回滚 |
| `POST` | `/craft/templates/{id}/enable` | 启用模板 |
| `POST` | `/craft/templates/{id}/disable` | 禁用模板 |
| `POST` | `/craft/templates/{id}/draft` | 创建草稿 |
| `POST` | `/craft/templates/{id}/archive` | 归档模板 |
| `POST` | `/craft/templates/{id}/unarchive` | 取消归档 |
| `POST` | `/craft/templates/{id}/copy` | 复制模板 |
| `POST` | `/craft/templates/{id}/copy-to-product` | 复制模板到产品 |
| `GET` | `/craft/templates/{id}/impact-analysis` | 模板影响分析 |
| `GET` | `/craft/templates/{id}/references` | 模板引用检查 |
| `GET` | `/craft/templates/{id}/export` | 导出单个模板 |
| `GET` | `/craft/templates/export` | 批量导出模板 |
| `POST` | `/craft/templates/import` | 导入模板 |
| `GET` | `/craft/system-master-template` | 系统主模板 |
| `POST` | `/craft/system-master-template` | 创建/更新系统主模板 |
| `POST` | `/craft/system-master-template/copy-to-product` | 系统主模板复制到产品 |
| `GET` | `/craft/system-master-template/versions` | 系统主模板版本 |
| `GET` | `/craft/kanban/process-metrics` | 看板工序指标 |
| `GET` | `/craft/kanban/process-metrics/export` | 导出看板指标 |
| `GET` | `/craft/products/{id}/template-references` | 产品模板引用 |

### 页面

`CraftPage` — 工艺管理主页面，Tab 切换：阶段管理、工序管理、模板管理、看板等。

### 状态管理

使用 `AppSession` + `ChangeNotifier` 模式，列表支持分页、关键词/启用状态筛选。

---

## features/equipment/ — 设备管理

**路径**: `lib/features/equipment/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

设备台账 CRUD、保养项目/计划管理、保养工单执行（开始/完成/取消）、保养记录查询、设备规则管理、运行参数管理、设备归属人选项。

### 服务

`EquipmentService` (`equipment_service.dart`)

### API 端点

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/equipment/owners` | 归属人选项 |
| `GET` | `/equipment/ledger` | 设备台账列表 |
| `GET` | `/equipment/ledger/{id}/detail` | 设备详情 |
| `POST` | `/equipment/ledger` | 创建设备 |
| `PUT` | `/equipment/ledger/{id}` | 更新设备 |
| `DELETE` | `/equipment/ledger/{id}` | 删除设备 |
| `POST` | `/equipment/ledger/{id}/toggle` | 启/禁设备 |
| `GET` | `/equipment/items` | 保养项目列表 |
| `POST` | `/equipment/items` | 创建保养项目 |
| `PUT` | `/equipment/items/{id}` | 更新保养项目 |
| `DELETE` | `/equipment/items/{id}` | 删除保养项目 |
| `POST` | `/equipment/items/{id}/toggle` | 启/禁保养项目 |
| `GET` | `/equipment/plans` | 保养计划列表 |
| `POST` | `/equipment/plans` | 创建保养计划 |
| `PUT` | `/equipment/plans/{id}` | 更新保养计划 |
| `DELETE` | `/equipment/plans/{id}` | 删除保养计划 |
| `POST` | `/equipment/plans/{id}/toggle` | 启/禁保养计划 |
| `POST` | `/equipment/plans/{id}/generate` | 生成保养工单 |
| `GET` | `/equipment/executions` | 工单执行列表 |
| `GET` | `/equipment/executions/{id}/detail` | 工单详情 |
| `POST` | `/equipment/executions/{id}/start` | 开始执行 |
| `POST` | `/equipment/executions/{id}/complete` | 完成执行 |
| `POST` | `/equipment/executions/{id}/cancel` | 取消执行 |
| `GET` | `/equipment/records` | 保养记录列表 |
| `GET` | `/equipment/records/{id}/detail` | 保养记录详情 |
| `GET` | `/equipment/rules` | 设备规则列表 |
| `POST` | `/equipment/rules` | 创建设备规则 |
| `PUT` | `/equipment/rules/{id}` | 更新设备规则 |
| `PATCH` | `/equipment/rules/{id}/toggle` | 启用/禁用规则 |
| `DELETE` | `/equipment/rules/{id}` | 删除规则 |
| `GET` | `/equipment/runtime-parameters` | 运行参数列表 |
| `POST` | `/equipment/runtime-parameters` | 创建运行参数 |
| `PUT` | `/equipment/runtime-parameters/{id}` | 更新运行参数 |
| `PATCH` | `/equipment/runtime-parameters/{id}/toggle` | 启/禁运行参数 |
| `DELETE` | `/equipment/runtime-parameters/{id}` | 删除运行参数 |

### 页面

`EquipmentPage` — 设备管理主页面，Tab 覆盖设备台账、保养项目管理、保养计划、工单执行、保养记录、设备规则、运行参数。

### 状态管理

`ChangeNotifier` 管理模式，分页列表数据通过 Service 拉取。

---

## features/production/ — 生产管理

**路径**: `lib/features/production/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

生产订单 CRUD、我的任务（`my-orders`）、报工/完工、首件管理（提交/审核会话）、协助授权、产线流水线实例管理、报废统计、返修单管理、实时数据看板、手动查询统计与导出。

### 服务

`ProductionService` (`production_service.dart`) — 同时实现 `RepairScrapService` 接口

### API 端点（部分核心）

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/production/orders` | 生产订单列表 |
| `POST` | `/production/orders` | 创建订单 |
| `GET` | `/production/orders/{id}` | 订单详情 |
| `PUT` | `/production/orders/{id}` | 更新订单 |
| `DELETE` | `/production/orders/{id}` | 删除订单 |
| `POST` | `/production/orders/{id}/complete` | 完成订单 |
| `GET` | `/production/orders/{id}/pipeline-mode` | 流水线模式 |
| `PUT` | `/production/orders/{id}/pipeline-mode` | 设置流水线模式 |
| `GET` | `/production/orders/export` | 导出订单 |
| `GET` | `/production/my-orders` | 我的任务列表 |
| `GET` | `/production/my-orders/{id}/context` | 任务上下文 |
| `POST` | `/production/my-orders/export` | 导出我的任务 |
| `GET` | `/production/order-events/search` | 订单事件日志 |
| `POST` | `/production/orders/{id}/first-article` | 提交首件 |
| `GET` | `/production/orders/{id}/first-article/templates` | 首件模板 |
| `GET` | `/production/orders/{id}/first-article/parameters` | 首件参数 |
| `GET` | `/production/orders/{id}/first-article/participant-users` | 首件参与人选项 |
| `POST` | `/production/orders/{id}/first-article/review-sessions` | 创建首件审核 |
| `GET` | `/production/orders/{id}/first-article/review-sessions/{s}/status` | 审核状态 |
| `POST` | `/production/orders/{id}/first-article/review-sessions/{s}/refresh` | 刷新审核 |
| `GET` | `/production/first-article/review-sessions/detail` | 审核详情 |
| `POST` | `/production/first-article/review-sessions/submit` | 提交审核结果 |
| `POST` | `/production/orders/{id}/end-production` | 报工/完工 |
| `GET` | `/production/stats/overview` | 生产总览统计 |
| `GET` | `/production/stats/processes` | 工序统计 |
| `GET` | `/production/stats/operators` | 操作工统计 |
| `GET` | `/production/data/today-realtime` | 今日实时数据 |
| `GET` | `/production/data/unfinished-progress` | 未完工进度 |
| `GET` | `/production/data/manual` | 手动查询 |
| `POST` | `/production/data/manual/export` | 导出手动查询 |
| `GET` | `/production/assist-authorizations` | 协助授权列表 |
| `POST` | `/production/orders/{id}/assist-authorizations` | 创建协助授权 |
| `GET` | `/production/assist-user-options` | 协助用户选项 |
| `GET` | `/production/pipeline-instances` | 流水线实例列表 |
| `GET` | `/production/scrap-statistics` | 报废统计 |
| `POST` | `/production/scrap-statistics/export` | 导出报废统计 |
| `GET` | `/production/scrap-statistics/{id}` | 报废统计详情 |
| `GET` | `/production/repair-orders` | 返修单列表 |
| `GET` | `/production/repair-orders/{id}/detail` | 返修单详情 |
| `GET` | `/production/repair-orders/{id}/phenomena-summary` | 返修现象汇总 |
| `POST` | `/production/repair-orders/{id}/complete` | 完成返修 |
| `POST` | `/production/repair-orders/export` | 导出返修单 |
| `POST` | `/production/orders/{id}/repair-orders` | 创建手动返修单 |

### 页面

`ProductionPage` — 生产管理主页面，Tab 覆盖订单管理、我的任务、首件管理、协助授权、返修报废、生产统计等。

### 状态管理

`ChangeNotifier` 管理分页/筛选/视图模式状态。

---

## features/quality/ — 质量管理

**路径**: `lib/features/quality/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

首件检验记录查询与处置、质量统计分析（按产品/工序/操作工/趋势、总览）、缺陷分析、报废统计、返修单管理、供应商管理。

### 服务

| 服务 | 文件 | 职责 |
|------|------|------|
| `QualityService` | `quality_service.dart` | 首件检验、质量统计、缺陷分析、报废/返修 |
| `QualitySupplierService` | `quality_supplier_service.dart` | 供应商 CRUD |
| `RepairScrapService` | `repair_scrap_service.dart` | 报废/返修抽象接口（`QualityService` 和 `ProductionService` 均实现） |

### API 端点 (QualityService)

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/quality/first-articles` | 首件检验列表 |
| `GET` | `/quality/first-articles/{id}` | 首件详情 |
| `GET` | `/quality/first-articles/{id}/disposition-detail` | 首件处置详情 |
| `POST` | `/quality/first-articles/{id}/disposition` | 提交处置意见 |
| `POST` | `/quality/first-articles/export` | 导出首件列表 |
| `GET` | `/quality/stats/overview` | 质量总览统计 |
| `GET` | `/quality/stats/products` | 按产品统计 |
| `GET` | `/quality/stats/processes` | 按工序统计 |
| `GET` | `/quality/stats/operators` | 按操作工统计 |
| `POST` | `/quality/stats/export` | 导出质量统计 |
| `GET` | `/quality/trend` | 质量趋势 |
| `POST` | `/quality/trend/export` | 导出质量趋势 |
| `GET` | `/quality/defect-analysis` | 缺陷分析 |
| `POST` | `/quality/defect-analysis/export` | 导出缺陷分析 |
| `GET` | `/quality/scrap-statistics` | 报废统计 |
| `GET` | `/quality/scrap-statistics/{id}` | 报废详情 |
| `POST` | `/quality/scrap-statistics/export` | 导出报废统计 |
| `GET` | `/quality/repair-orders` | 返修单列表 |
| `GET` | `/quality/repair-orders/{id}/detail` | 返修单详情 |
| `GET` | `/quality/repair-orders/{id}/phenomena-summary` | 返修现象汇总 |
| `POST` | `/quality/repair-orders/{id}/complete` | 完成返修 |
| `POST` | `/quality/repair-orders/export` | 导出返修单 |

### API 端点 (QualitySupplierService)

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/quality/suppliers` | 供应商列表 |
| `POST` | `/quality/suppliers` | 创建供应商 |
| `PUT` | `/quality/suppliers/{id}` | 更新供应商 |
| `DELETE` | `/quality/suppliers/{id}` | 删除供应商 |

### 页面

`QualityPage` — 质量管理主页面，Tab 覆盖首件检验、质量统计、趋势分析、缺陷分析、报废返修、供应商管理等。

### 状态管理

`ChangeNotifier` 管理模式，与 `ProductionService` 共享 `RepairScrapService` 接口。

---

## features/message/ — 消息中心

**路径**: `lib/features/message/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

站内消息中心：消息列表、未读计数、公告发布/查看、批量已读、消息跳转、消息维护、WebSocket 实时推送。

### 服务

| 服务 | 文件 | 职责 |
|------|------|------|
| `MessageService` | `message_service.dart` | REST API 消息操作 |
| `MessageWsService` | `message_ws_service.dart` | WebSocket 实时消息推送 |

### API 端点 (MessageService)

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/messages/unread-count` | 未读消息数 |
| `GET` | `/messages/summary` | 消息摘要 |
| `GET` | `/messages` | 消息列表 |
| `GET` | `/messages/public-announcements` | 公开公告 |
| `GET` | `/messages/{id}` | 消息详情 |
| `POST` | `/messages/{id}/read` | 标记已读 |
| `POST` | `/messages/read-all` | 全部已读 |
| `POST` | `/messages/read-batch` | 批量已读 |
| `GET` | `/messages/{id}/jump-target` | 消息跳转目标 |
| `POST` | `/messages/announcements` | 发布公告 |
| `POST` | `/messages/maintenance/run` | 执行消息维护 |

### WebSocket

连接路径: `ws://{baseUrl}/messages/ws`  
认证方式: 连接后发送 `{"type":"auth","token":"..."}`  
支持自动重连（指数退避，最大 30 秒）。

### 页面

`MessageCenterPage` — 消息列表 + 公告发布功能。Shell 内嵌轮询未读计数。

### 状态管理

`MessageService` 为独立性服务，`MessageWsService` 由 Shell 控制器管理生命周期。未读计数通过回调 `onUnreadCountChanged` 注入 Shell。

---

## features/settings/ — 软件设置

**路径**: `lib/features/settings/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

本地软件偏好设置（主题模式、布局密度、启动目标页面、侧边栏折叠、时钟同步开关），基于 `SharedPreferences` 持久化。

### 服务

`SoftwareSettingsService` (`software_settings_service.dart`) — 纯本地存储，无 API 调用。

### 设置项

| 键 | 值 | 说明 |
|----|-----|------|
| `software_settings.theme_preference` | `system`/`light`/`dark` | 主题 |
| `software_settings.density_preference` | `comfortable`/`compact` | 布局密度 |
| `software_settings.launch_target_preference` | `home`/`last_visited_module` | 启动目标 |
| `software_settings.sidebar_preference` | `expanded`/`collapsed` | 侧边栏 |
| `software_settings.time_sync_enabled` | `true`/`false` | 时钟同步 |
| `software_settings.last_visited_page_code` | 页面编码 | 上次访问页面 |

### 页面

`SoftwareSettingsPage` — 从 Shell 工具面板入口打开，由 `SoftwareSettingsController` 驱动。

### 状态管理

`SoftwareSettingsController` (ChangeNotifier) 持有当前设置快照，修改即时持久化。

---

## features/time_sync/ — 时钟同步

**路径**: `lib/features/time_sync/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

从服务端获取时间，与本地 Windows 系统时钟比较，提供校准后的 `DateTime.now` 给全应用使用。

### 服务

| 服务 | 文件 | 职责 |
|------|------|------|
| `ServerTimeService` | `server_time_service.dart` | 获取服务端时间快照 |
| `WindowsTimeSyncService` | `windows_time_sync_service.dart` | Windows 平台时钟同步 |

### API 端点

| 方法 | 路径 | 用途 |
|------|------|------|
| `GET` | `/system/time` | 获取服务端时间快照 |

### 页面

无独立可视页面。`TimeSyncController` 作为全局控制器嵌入 Shell，通过 `nowProvider` 注入各模块（如消息中心）。

### 状态管理

`TimeSyncController` (ChangeNotifier) — 管理服务端时间偏移量，导出 `effectiveClock.now` 供全局使用。

---

## features/plugin_host/ — 插件中心

**路径**: `lib/features/plugin_host/`
**子目录**: `models/`, `presentation/`, `services/`

### 主要职责

本地 Python 插件管理：扫描插件目录、启动插件进程、WebView 展示插件前端、心跳检测与进程生命周期管理。

### 服务

| 服务 | 文件 | 职责 |
|------|------|------|
| `PluginCatalogService` | `plugin_catalog_service.dart` | 扫描插件目录 `manifest.json` |
| `PluginProcessService` | `plugin_process_service.dart` | 启动/停止/心跳检测 Python 插件进程 |
| `PluginRuntimeLocator` | `plugin_runtime_locator.dart` | 定位 Python 运行时环境 |

### API

无后端 API 调用。插件通过本地进程通信（stdout ready 消息 + HTTP heartbeat），WebView 加载插件提供的本地 URL。

### 页面

`PluginHostPage` — 工具面板入口，管理插件生命周期。`PluginHostWebviewPanel` — 插件 WebView 容器。

### 状态管理

`PluginHostController` (ChangeNotifier) 管理插件扫描、启动/停止/全屏状态。

---

## features/misc/ — 杂项页面

**路径**: `lib/features/misc/`
**子目录**: `presentation/` (仅 presentation，无 models/services)

### 主要职责

承载独立的未归类界面组件。

### 页面

| 文件 | 用途 |
|------|------|
| `login_page.dart` | 登录页面 |
| `register_page.dart` | 注册页面 |
| `force_change_password_page.dart` | 强制修改密码页面 |
| `daily_first_article_page.dart` | 每日首件页面 |
| `first_article_disposition_page.dart` | 首件处置页面 |

### API

不包含独立 Service，直接调用 `auth` 模块的 `AuthService` 等。

### 状态管理

页面本地状态 (`StatefulWidget` 的 `setState`)。

---

## 附录：模块目录结构汇总

| 模块 | models/ | services/ | presentation/ | widgets/ |
|------|---------|-----------|---------------|----------|
| shell | ✓ | ✓ | ✓ | ✓ (内嵌) |
| auth | — | ✓ | ✓ | — |
| user | ✓ | ✓ | ✓ | — |
| product | ✓ | ✓ | ✓ | — |
| craft | ✓ | ✓ | ✓ | — |
| equipment | ✓ | ✓ | ✓ | — |
| production | ✓ | ✓ | ✓ | — |
| quality | ✓ | ✓ | ✓ | — |
| message | ✓ | ✓ | ✓ | — |
| settings | ✓ | ✓ | ✓ | — |
| time_sync | ✓ | ✓ | ✓ | — |
| plugin_host | ✓ | ✓ | ✓ | ✓ (内嵌) |
| misc | — | — | ✓ | — |

## 附录：导航机制总结

```
用户登录 → AppSession → MainShellPage
                             ├── AuthService.getCurrentUser()
                             ├── AuthzService.loadAuthzSnapshot()
                             ├── PageCatalogService.loadCatalog()
                             ├── HomeDashboardService.load()
                             └── MessageWsService.connect()
                                    │
                          MainShellViewState
                             ├── menus: List<MainShellMenuItem>
                             ├── selectedPageCode: String
                             ├── tabCodesByParent: Map
                             └── authzSnapshot: AuthzSnapshot
                                    │
                          MainShellPageRegistry.build(pageCode)
                             ├── 'home' → HomePage
                             ├── 'user' → UserPage
                             ├── 'product' → ProductPage
                             ├── 'equipment' → EquipmentPage
                             ├── 'production' → ProductionPage
                             ├── 'quality' → QualityPage
                             ├── 'craft' → CraftPage
                             ├── 'message' → MessageCenterPage
                             ├── 'software_settings' → SoftwareSettingsPage
                             └── 'plugin_host' → PluginHostPage
```
