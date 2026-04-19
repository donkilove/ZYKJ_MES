# MainShellPage 拆解设计

## 1. 背景

当前 `frontend/lib/features/shell/presentation/main_shell_page.dart` 已达到 1137 行，单文件同时承担以下职责：

1. 登录后基础服务装配：`AuthService`、`AuthzService`、`PageCatalogService`、`MessageService`、`HomeDashboardService`
2. 用户与权限初始化：当前用户、权限快照、目录兜底、菜单生成、页签排序
3. 生命周期与定时任务：`WidgetsBindingObserver`、权限轮询、未读轮询
4. WebSocket 连接与事件处理：未读数、消息刷新 tick、工作台刷新触发
5. 首页工作台刷新编排：手动刷新、事件防抖、pending 补刷
6. 导航状态：当前模块、目标页签、跳转载荷、权限拦截、快捷跳转
7. 子页面装配：`HomePage` / `UserPage` / `ProductPage` / `EquipmentPage` / `ProductionPage` / `QualityPage` / `CraftPage` / `MessageCenterPage`
8. 壳层视图：左侧菜单、顶部提示、无权限页、错误页、内容区

这导致两个直接问题：

- 任一行为改动都容易触碰壳层其余状态流，回归半径过大。
- 测试虽然较全，但主要还是在围绕一个“大而全”的组件做集成验证，维护成本高。

## 2. 目标

1. 保持现有对外行为和依赖注入方式不变，不引入新的状态管理框架。
2. 把 `MainShellPage` 缩到 200 至 300 行量级，只保留页面装配和生命周期胶水。
3. 把“纯计算”“状态编排”“页面注册”“壳层视图”拆成独立单元。
4. 让测试可以按职责分层，而不是继续把新增逻辑都堆进 `main_shell_page_test.dart`。

## 3. 非目标

1. 本轮不改各业务模块页内部实现。
2. 本轮不引入 Provider、Riverpod、Bloc 等新框架。
3. 本轮不重写权限模型、消息协议或工作台接口。

## 4. 候选方案

### 方案 A：继续保留单文件，只做局部函数整理

- 做法：继续把大方法切成私有函数，但仍留在 `main_shell_page.dart`
- 优点：改动最小，短期合并风险最低
- 缺点：边界仍不清晰，文件体量不会真正下降，测试文件仍继续膨胀

### 方案 B：拆成“控制器 + 纯计算 + 页面注册 + 视图组件”，保留 StatefulWidget 外壳

- 做法：`MainShellPage` 仍是 StatefulWidget，但把核心职责拆到若干文件
- 优点：符合当前项目风格，不新增框架，便于渐进迁移
- 缺点：需要先梳理状态边界，第一轮拆分会有一定机械性工作

### 方案 C：直接引入新的状态管理架构并整体重写壳层

- 做法：以新的状态容器重写 `MainShellPage`
- 优点：理论上结构最整洁
- 缺点：与当前仓库风格偏离过大，回归风险最高，本轮明显过度设计

## 5. 推荐方案

推荐 **方案 B**。

原因：

1. 它能在不改外部调用方式的前提下，把当前 8 类职责拆开。
2. 它最适合沿用现有测试注入模式，避免一次性重写所有主壳测试。
3. 它允许按阶段拆分，每个阶段都能独立验证并稳定落地。

## 6. 推荐拆分边界

### 6.1 `main_shell_page.dart`

职责只保留：

- 创建和销毁控制器
- 监听控制器状态
- 组合 `MainShellScaffold`
- 将依赖注入透传给页面注册表

不再保留：

- 菜单计算
- 页签排序
- 权限快照与目录刷新细节
- WebSocket 事件解释
- 首页刷新防抖与 pending 补刷
- 各模块页面构建 switch

### 6.2 `main_shell_controller.dart`

建议新增，作为壳层状态编排核心。

职责：

- 初始化服务引用
- 执行 `loadCurrentUserAndVisibility`
- 协调权限刷新、未读刷新、工作台刷新
- 接收生命周期回调和 WebSocket 事件
- 持有可监听状态

边界：

- 不直接创建具体页面 Widget
- 不负责具体布局绘制

### 6.3 `main_shell_state.dart`

建议新增，定义壳层状态快照。

建议包含：

- `loading`
- `message`
- `currentUser`
- `authzSnapshot`
- `catalog`
- `tabCodesByParent`
- `menus`
- `selectedPageCode`
- `preferredTabCode`
- `preferredRoutePayloadJson`
- `unreadCount`
- `manualRefreshing`
- `lastManualRefreshAt`
- `homeDashboardData`

目标：

- 让视图层只消费状态，不再直接依赖一堆私有字段

### 6.4 `main_shell_navigation.dart`

建议新增，承载纯计算逻辑。

职责：

- `_buildMenus`
- `_sortTabsByCatalog`
- `_visible*TabCodes`
- `_defaultTabCodeForPage`
- `_defaultRoutePayloadJsonForTab`
- `resolvePageTarget`
- `buildHomeQuickJumps`

要求：

- 尽量做成纯函数或无状态 helper
- 这一层优先抽离，因为最容易写单元测试

### 6.5 `main_shell_refresh_coordinator.dart`

建议新增，承载“计时器 + 事件刷新”逻辑。

职责：

- 权限轮询
- 未读轮询
- 工作台防抖刷新
- pending 补刷
- WebSocket 事件到刷新动作的映射

目标：

- 把“什么时候刷新、刷新什么、如何合并刷新”从页面类中移出

### 6.6 `main_shell_page_registry.dart`

建议新增，替代当前 `_buildContent` 的超长 `switch`

职责：

- 根据 `pageCode` 返回目标页面
- 负责把 `visibleTabCodes`、`capabilityCodes`、`preferredTabCode`、`routePayloadJson` 组装给各模块页
- 保留现有 builder override 机制

收益：

- 后续新增模块或新增壳层注入参数时，不必继续膨胀主页面类

### 6.7 `widgets/main_shell_scaffold.dart`

建议新增，纯视图组件。

职责：

- 左侧菜单栏
- 未读角标展示
- 顶部消息条
- 内容容器
- 无权限页 / 错误页的视图组合

目标：

- 把布局和状态编排分离，主页面不再持有大段 UI 代码

## 7. 分阶段实施顺序

### 阶段 1：先抽纯计算和模型

目标：

- 新增 `main_shell_state.dart`
- 新增 `main_shell_navigation.dart`
- 从 `main_shell_page.dart` 移出菜单、页签、快捷跳转、目标页解析

原因：

- 这部分最稳定、最容易测、对运行时副作用最小

### 阶段 2：抽刷新协调器

目标：

- 把未读轮询、工作台防抖、pending 补刷、WebSocket 事件解释迁出

原因：

- 当前最难读、也最容易引发回归的就是“多来源刷新合并”逻辑

### 阶段 3：抽页面注册表

目标：

- 把 `_buildContent` 的模块分发逻辑迁出

原因：

- 这一步能显著降低主页面文件体积
- 同时不影响各模块页面内部代码

### 阶段 4：抽纯视图壳层

目标：

- 把菜单区、状态提示区、内容区布局迁到 `MainShellScaffold`

原因：

- 最后做视图层抽离，能避免前面阶段边拆状态边改布局导致回归面过大

## 8. 测试策略

### 8.1 保留现有主壳集成测试

`main_shell_page_test.dart` 先不删除，用它兜住现有总行为。

### 8.2 新增分层测试

建议新增：

- `test/features/shell/main_shell_navigation_test.dart`
  - 菜单排序
  - 可见页签过滤
  - 快捷跳转默认页签
  - tab -> parent 跳转解析

- `test/features/shell/main_shell_refresh_coordinator_test.dart`
  - 消息事件触发工作台刷新
  - 防抖窗口合并
  - pending 补刷
  - 非首页不触发刷新

- `test/features/shell/main_shell_page_registry_test.dart`
  - 各模块 builder 优先级
  - 注入参数透传
  - message 模块 jump 参数透传

- `test/features/shell/widgets/main_shell_scaffold_test.dart`
  - 菜单选中态
  - 未读角标
  - 错误态/无权限态展示

### 8.3 最终目标

- `main_shell_page_test.dart` 只保留壳层级关键闭环
- 细节行为迁移到更小粒度测试文件

## 9. 验收标准

1. `main_shell_page.dart` 控制在 300 行以内。
2. 原有主壳关键测试全部通过。
3. 新增拆分单元测试覆盖菜单、导航、刷新编排三类逻辑。
4. 外部调用 `MainShellPage` 的构造参数保持兼容。
5. 不引入新的状态管理依赖。

## 10. 风险与控制

### 风险 1：刷新链路拆分后遗漏边角事件

- 控制：先提取 `main_shell_refresh_coordinator`，并把现有 `main_shell_page_test.dart` 中的消息刷新测试全部保留

### 风险 2：页面注册表改动影响 builder override 注入

- 控制：对每个 `*PageBuilder` 保留现有签名，并补独立 registry 测试

### 风险 3：导航状态拆分后出现 tab/page 不一致

- 控制：把页面目标解析与默认页签生成全部收敛进 `main_shell_navigation.dart`，避免逻辑散落

## 11. 建议的下一步

如果继续实施，建议下一轮直接从 **阶段 1：抽纯计算和模型** 开始，而不是一上来拆 UI。

原因：

- 阶段 1 最容易稳定落地
- 改动边界最清晰
- 能最快给后续阶段建立可复用的状态与导航基座
