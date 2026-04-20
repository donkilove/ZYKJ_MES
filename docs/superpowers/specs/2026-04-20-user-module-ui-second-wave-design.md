# 用户模块 UI 第二波迁移设计

## 1. 背景

前端 UI 基础件体系第一阶段已经完成，当前仓库已经具备 `foundation / primitives / patterns` 三层能力，并且设置页、首页、消息中心已经完成第一批试点迁移。

下一步不适合立即进入最复杂的超大页面，而应优先选择一组“中等复杂度、结构重复度高、测试基础较好”的页面，继续验证这套 UI 体系在 CRUD 类业务页上的适配性，并进一步沉淀更贴近业务页装配方式的统一骨架。

用户模块中的 `user_management_page.dart` 和 `registration_approval_page.dart` 正好满足这个条件，因此本轮将它们作为前端 UI 第二波迁移的首批试点。

## 2. 当前现状

### 2.1 用户模块入口壳层仍是旧式 Tab 壳

`frontend/lib/features/user/presentation/user_page.dart` 目前仍以 `TabBar + TabBarView` 直接装配多个子页，尚未接入新的页面骨架模式。

### 2.2 用户管理页已有统一化雏形，但仍是大页面

`frontend/lib/features/user/presentation/user_management_page.dart` 已经部分使用 `CrudPageHeader`、`SimplePaginationBar` 等旧统一件，但页面仍同时承担：

1. 查询状态
2. 列表数据装配
3. 在线状态轮询
4. 动作按钮区
5. 弹窗触发与回刷
6. 页内错误提示

这使得页面结构偏重、状态分散，难以进一步接入新的业务骨架。

### 2.3 注册审批页适合验证第二种 CRUD 形态

`frontend/lib/features/user/presentation/registration_approval_page.dart` 也已经部分接入旧统一件，但仍把筛选、列表、审批动作、路由跳转定位提示和分页状态集中在一个页面里。它适合用来验证“同一套骨架是否能覆盖另一种 CRUD / 审批型列表页”。

### 2.4 用户模块已有一定测试基础

当前已经存在：

1. `frontend/test/widgets/user_page_test.dart`
2. `frontend/test/widgets/user_management_page_test.dart`
3. `frontend/test/widgets/registration_approval_page_test.dart`
4. `frontend/test/widgets/account_settings_page_test.dart`
5. `frontend/test/widgets/login_session_page_test.dart`
6. `frontend/test/widgets/user_module_support_pages_test.dart`

这使得本轮迁移可以在不改变核心业务语义的前提下，用现有测试体系兜住结构调整风险。

## 3. 已确认路线

本轮采用路线 A：优先迁移“用户管理 + 注册审批”这一组最稳的 CRUD 试点页面。

选择该路线的原因如下：

1. 它们最贴近当前 `core/ui/patterns` 已具备的能力边界。
2. 它们的页面组织方式高度相似，适合沉淀第二层业务骨架。
3. 它们已有测试基础，迁移风险可控。
4. 它们能为后续 `role_management_page.dart`、`audit_log_page.dart` 提供直接模板。

本轮不将以下页面纳入首批试点：

1. `user_page.dart` 壳层
2. `account_settings_page.dart`
3. `login_session_page.dart`

## 4. 目标

1. 将用户管理页和注册审批页从“大页面直接拼装”迁移为“统一骨架 + 状态收敛 + 区块组件”的结构。
2. 在现有 `core/ui/patterns` 之上补齐更适合 CRUD 页面装配的业务骨架。
3. 统一两页的筛选区、页内反馈区、列表区和分页区组织方式。
4. 在不改变权限语义和后端调用口径的前提下，降低页面复杂度并提高可维护性。
5. 为后续用户模块其他列表页迁移提供可复用模板。

## 5. 非目标

1. 本轮不重做用户模块 `TabBar` 壳层。
2. 本轮不重写用户新建、编辑、重置密码、审批通过、审批驳回等业务弹窗流程。
3. 本轮不调整按钮显隐规则、权限语义或后端接口契约。
4. 本轮不将所有用户模块页面一次性迁移到新体系。

## 6. 页面分层与职责拆解

两页都应从“页面同时承担所有职责”的结构，收敛为统一的五层结构。

### 6.1 页面壳层

页面壳层负责页头、筛选区、反馈区、内容区和分页区的整体装配。

建议新增面向 CRUD 页的统一骨架，例如 `MesCrudPageScaffold`，固定以下插槽：

1. `header`
2. `filters`
3. `banner`
4. `content`
5. `pagination`

页面主文件只负责组装这些插槽，不再直接在 `build` 中堆叠大段布局。

### 6.2 查询与状态层

页面自身保留查询条件、分页状态、加载状态、页内反馈和列表结果，不再让这些状态散落在各个区块组件回调中。

### 6.3 区块组件层

把筛选区、列表区、分页区、反馈区拆成稳定组件，让页面主文件更聚焦于“编排”，而不是“渲染细节”。

### 6.4 动作流层

新建、编辑、启停、删除、恢复、审批通过、审批驳回等动作继续在用户模块内部处理，但页面只负责触发，成功后的回刷通过统一入口完成。

### 6.5 行渲染层

状态文案、操作按钮、单元格展示、颜色语义等继续下沉到表格区或行级组件中，减少主页面对表格细节的直接感知。

## 7. 组件拆分与复用边界

### 7.1 用户管理页拆分建议

建议拆出以下组件：

1. `user_management_page_header`
2. `user_management_filter_section`
3. `user_management_action_bar`
4. `user_management_table_section`
5. `user_management_feedback_banner`
6. `user_management_pagination_section`

这些组件分别负责页头、筛选区、动作区、列表区、页内消息和分页区。

### 7.2 注册审批页拆分建议

建议拆出以下组件：

1. `registration_approval_page_header`
2. `registration_approval_filter_section`
3. `registration_approval_table_section`
4. `registration_approval_feedback_banner`
5. `registration_approval_pagination_section`

### 7.3 用户模块共用件边界

适合抽成用户模块共用件的内容包括：

1. `user_module_feedback_banner`
2. `user_module_status_chip`
3. `user_module_table_shell`
4. `user_module_filter_panel`

这些组件适合放在 `frontend/lib/features/user/presentation/widgets/shared/` 下，服务用户模块内部多页复用，但不直接上提到 `core/ui`。

### 7.4 适合补入 `core/ui/patterns` 的骨架

本轮更适合补到 `core/ui/patterns` 的，不是用户业务组件，而是更抽象的页面骨架：

1. `MesCrudPageScaffold`
2. `MesInlineBanner`
3. `MesTableSectionHeader`

它们分别用于统一 CRUD 页结构、页内反馈出口和表格区标题布局。

### 7.5 本轮不抽离的内容

以下内容本轮继续留在用户模块内部，不强行上提：

1. 用户新建、编辑、重置密码相关弹窗
2. 导出任务弹窗
3. 审批通过、审批驳回对话框

原因是这些流程业务差异较大，当前优先目标是稳定页面结构，而不是重写动作体系。

## 8. 数据流与状态流收敛

两页统一采用以下主流程：

`筛选条件 -> 查询动作 -> 列表结果 -> 页级反馈 -> 操作成功回刷`

### 8.1 用户管理页状态收敛

建议收敛为以下状态组：

1. 查询状态：`keyword / roleCode / isActive / deletedScope / page`
2. 页面状态：`loading / queryInFlight / message`
3. 列表状态：`users / total / totalPages`
4. 辅助状态：`roles / stages / myUserId / myRoleCode`
5. 特殊状态：在线轮询相关状态

在线轮询逻辑可以继续存在，但应封装为独立 section，不再散落在页面主结构周围。

### 8.2 注册审批页状态收敛

建议收敛为以下状态组：

1. 查询状态：`statusFilter / page`
2. 页面状态：`loading / message`
3. 列表状态：`items / total / totalPages`
4. 辅助状态：`roles / stages`
5. 跳转状态：`jumpRequestId / lastHandledRoutePayloadJson`

### 8.3 统一动作入口

建议两页都收敛为以下四类主动作：

1. `loadInitialData()`
2. `reloadCurrentPage()`
3. `applyFiltersAndReload()`
4. `handleActionSuccess()`

页面中的各类回调最终都落到这几个入口，而不是在每个按钮、对话框回调里直接分散调用 `_loadUsers()` 或 `_loadRequests()`。

### 8.4 回刷策略统一

建议统一以下回刷规则：

1. 新建、编辑、启停、删除、恢复、审批结果类动作成功后：`reloadCurrentPage()`
2. 修改筛选条件后：`applyFiltersAndReload(page: 1)`
3. 点击刷新：`reloadCurrentPage()`
4. 首次进入页面：`loadInitialData()`
5. 路由跳转定位：先更新跳转状态，再统一触发数据加载入口

### 8.5 页内反馈与瞬时反馈分层

建议明确区分：

1. `message`
   用于页内持续反馈，例如权限不足、目标记录未定位到
2. `SnackBar`
   用于瞬时成功反馈，例如审批成功、导出任务已创建

两者不得混用，以避免页内状态与瞬时提示互相覆盖。

## 9. 测试、迁移顺序与风险控制

### 9.1 推荐迁移顺序

本轮推荐按以下顺序执行：

1. 先补齐或完善 `MesCrudPageScaffold`、`MesInlineBanner` 与必要的用户模块共用件
2. 再迁移 `user_management_page.dart`
3. 再迁移 `registration_approval_page.dart`
4. 最后统一补测试、integration 观察点与 `evidence`

不建议并行大范围改动，以避免把“稳妥试点”变成“范围失控的小型重构”。

### 9.2 Widget 测试要求

`frontend/test/widgets/user_management_page_test.dart` 至少应覆盖：

1. 新骨架是否接入
2. 筛选变化是否回到第一页
3. 查询、刷新、分页是否可用
4. 主要操作入口是否仍按权限显隐

`frontend/test/widgets/registration_approval_page_test.dart` 至少应覆盖：

1. 状态筛选
2. 路由跳转定位提示
3. 审批按钮显隐
4. 空态、错态与页内反馈

`frontend/test/widgets/user_page_test.dart` 至少保留最小回归，确保：

1. 两个子页迁移后，tab 装配未被破坏

### 9.3 Integration 观察点

本轮至少补齐以下关键观察点：

1. 进入用户管理页
2. 执行一次查询或筛选
3. 进入注册审批页
4. 看到统一后的页头、筛选区、列表区锚点

### 9.4 风险控制

本轮重点控制以下风险：

### 风险 1：权限语义漂移

控制方式：

1. 不改按钮显隐规则
2. 不改后端调用口径
3. 测试中保留权限显隐断言

### 风险 2：页面迁移变成弹窗流程重写

控制方式：

1. 现有业务弹窗先复用
2. 页面只收敛触发入口与回刷逻辑

### 风险 3：首批试点范围过大

控制方式：

1. 不同时重做 `user_page.dart` 壳层
2. 不将 `account_settings_page.dart` 纳入本轮
3. 先做列表页，再扩更多页面

### 风险 4：共用层抽象过高

控制方式：

1. 优先抽 CRUD 骨架与用户模块共用件
2. 不把所有用户模块组件都上提到 `core/ui`
3. 以第二批页面能否直接复用为准绳判断抽象是否成立

## 10. 预期结果

本轮完成后，用户管理页和注册审批页应从“旧式统一件 + 页面巨石拼装”升级为“统一 CRUD 骨架 + 区块组件 + 状态收敛”的结构。

预期收益包括：

1. 页面结构更清晰，主文件明显变薄
2. 页内反馈、筛选区、表格区和分页区组织方式统一
3. 测试锚点更稳定，后续维护成本更低
4. 角色管理、审计日志等后续页面可以直接复用这一模板

## 11. 迁移说明

- 无迁移，直接替换
