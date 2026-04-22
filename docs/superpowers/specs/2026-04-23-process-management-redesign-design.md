# 工序管理页统一骨架重构设计

## 1. 背景

`frontend/lib/features/craft/presentation/process_management_page.dart` 是当前前端中典型的历史大页之一。页面同时承担以下多类职责：

1. 页面生命周期与数据加载
2. 工段与工序列表展示
3. 搜索、筛选与聚焦工序状态
4. jump 承接与页面提示
5. 工段/工序弹窗与删除确认
6. 页面级布局与大量局部样式

当前实现虽然功能可用，但已经明显进入“单文件全包”的维护状态。继续在现有结构上叠加功能，会同时放大两个问题：

1. 页面结构难以理解与维护
2. 页面骨架风格难以继续向统一 UI 体系靠拢

本轮目标不是重写业务，而是在不改变业务行为和接口契约的前提下，把这张页改造成“结构清楚、风格统一、可继续演进”的工艺工作台。

## 2. 目标

1. 将 `process_management_page.dart` 从超大单文件重构为职责清晰的页面组合。
2. 让页面真正接入现有 `core/ui` 统一骨架，而不是仅局部替换几个卡片。
3. 在不改变接口契约、权限语义和交互结果的前提下，提升可维护性与统一度。

## 3. 非目标

1. 不修改后端接口和数据契约。
2. 不改变工段/工序增删改查业务规则。
3. 不改变 jump 承接语义、权限判断结果和关键交互路径。
4. 不在本轮引入新的全局状态管理方案或额外 controller/service 架构。
5. 不顺手重做整套工艺模块视觉。

## 4. 现状问题

### 4.1 文件职责混杂

当前页面将装配、状态、列表、详情、弹窗、提示和布局全部堆叠在同一个文件中，导致：

1. 单个变更的影响面过大
2. 局部功能难以独立理解
3. 页面结构难以复用到其他历史大页

### 4.2 页面骨架未统一

当前工艺模块已有 `CraftPageHeader`、`CraftPageShell` 等统一件，但 `process_management_page.dart` 仍主要依赖旧式 `CrudPageHeader`、手写 `Card`、局部 `DataTable` 和临时布局拼装。页面整体看上去更像“历史后台页”，而不是统一 UI 体系下的工作台。

### 4.3 状态边界不清晰

搜索、筛选、聚焦工序、jump 提示、反馈信息等状态混在页面 State 中，既影响左侧工段，也影响中间工序和右侧详情，后续继续演进容易形成更强耦合。

## 5. 已确认方向

本轮采用“激进重构型”，但严格限制在展示层和页面结构层，遵守以下边界：

1. 做 UI 骨架统一
2. 做页面拆分减重
3. 不改业务行为
4. 不改接口语义

换句话说，这次允许做较大规模的页面结构重组，但不允许借重构之名修改业务逻辑。

## 6. 总体架构

建议将当前页面重构为三层：

### 6.1 页面壳层

负责接收：

1. `session`
2. `onLogout`
3. `canWrite`
4. `processId`
5. `jumpRequestId`

并将这些顶层输入交给页面状态编排层和统一页面骨架。

### 6.2 页面状态编排层

负责：

1. 数据加载
2. jump 承接
3. 搜索与筛选
4. focused process
5. 页面反馈消息
6. 工段/工序动作分发

这一层依然驻留在页面附近，不上升为新的全局状态管理或业务服务层。

### 6.3 业务区块层

拆成若干独立 widgets，只负责单一区块的渲染与局部交互：

1. 页头
2. 反馈区
3. 工段面板
4. 工序面板
5. 聚焦工序详情面板
6. 工段弹窗
7. 工序弹窗

## 7. 文件拆分方案

建议拆分为以下文件：

### 7.1 页面入口

- `frontend/lib/features/craft/presentation/process_management_page.dart`

职责：

1. 页面入口
2. 连接统一骨架
3. 连接状态编排层
4. 保留少量生命周期入口

### 7.2 页面 widgets

- `frontend/lib/features/craft/presentation/widgets/process_management_page_header.dart`
  - 工艺模块语义页头，内部接 `MesPageHeader`
- `frontend/lib/features/craft/presentation/widgets/process_management_feedback_banner.dart`
  - 跳转定位、加载失败、权限提示统一出口
- `frontend/lib/features/craft/presentation/widgets/process_stage_panel.dart`
  - 工段搜索、工段列表、工段操作
- `frontend/lib/features/craft/presentation/widgets/process_item_panel.dart`
  - 工序搜索、工段筛选、工序表格、工序操作
- `frontend/lib/features/craft/presentation/widgets/process_focus_panel.dart`
  - 当前聚焦工序详情、说明、空态与未命中态
- `frontend/lib/features/craft/presentation/widgets/process_stage_dialog.dart`
  - 新建/编辑工段弹窗
- `frontend/lib/features/craft/presentation/widgets/process_item_dialog.dart`
  - 新建/编辑工序弹窗
- `frontend/lib/features/craft/presentation/widgets/process_management_models.dart`
  - 页面内部 view model / action enum
- `frontend/lib/features/craft/presentation/widgets/process_management_state.dart`
  - 页面状态编排层

## 8. 页面最终骨架

页面骨架采用“三段式工作台”：

### 8.1 顶部页头

使用工艺模块自己的 `process_management_page_header.dart`，而不是直接保留旧 `CrudPageHeader`。

要求：

1. 标题和副标题接统一骨架语言
2. 刷新、新建工段、新建工序等页面级动作集中在页头动作区

### 8.2 顶部反馈区

独立于工作区存在，专门显示：

1. jump 定位结果
2. 数据加载失败
3. 权限与不可执行提示

这类信息不再散落在局部卡片中。

### 8.3 主体三栏工作台

从左到右：

1. 工段面板
2. 工序面板
3. 聚焦工序详情面板

三块区域都应接入统一 section 容器语言，至少在：

1. 标题层级
2. 区块边距
3. 卡片/容器语义
4. 空态承接

上保持一致。

### 8.4 弹窗区

新建/编辑工段、新建/编辑工序、删除确认全部拆出主页面文件，由主页面只负责触发和接收结果。

## 9. 状态下沉边界

### 9.1 保留在主页面入口层

仅保留：

1. widget 参数
2. 生命周期触发
3. 页面骨架装配

### 9.2 下沉到页面状态编排层

建议集中管理以下跨区块联动状态：

1. `_loading`
2. `_message`
3. `_jumpNotice`
4. `_stages`
5. `_processes`
6. `_stageKeyword`
7. `_processKeyword`
8. `_processStageFilter`
9. `_focusedProcessId`
10. `_lastHandledJumpRequestId`

### 9.3 仅留在局部区块中的状态

仅保留局部、不会跨区块联动的临时展示态：

1. 搜索框 controller
2. 面板内部展开/折叠
3. hover / selected 等纯展示态
4. 弹窗表单临时输入值

### 9.4 不纳入本轮的下沉范围

本轮不引入：

1. 独立 controller/service
2. 全局状态管理
3. 事件总线
4. 新的数据访问抽象

原因：本轮目标是页面结构重构，不是状态架构升级。

## 10. 统一骨架接法

### 10.1 统一的部分

本轮应统一：

1. 页面头部
2. 顶部反馈区
3. 区块标题与容器语言
4. 主要操作区的节奏
5. 右栏空态与聚焦详情承接方式

### 10.2 保留业务个性的部分

本轮不要求把工艺页改得和普通 CRUD 页面完全一样。应保留：

1. 工艺模块自身业务语义
2. 三栏工作台的专业信息密度
3. 左工段、中工序、右详情的工艺工作台气质

目标是“统一骨架语言”，不是“抹平业务特征”。

## 11. 验收标准

### 11.1 文件结构

完成后应满足：

1. 主页面文件显著减重
2. 工段、工序、详情、反馈、弹窗有独立文件
3. 主页面主要只剩装配与少量生命周期入口

### 11.2 页面结构

完成后应满足：

1. 页头统一为工艺模块的 header 语言
2. 顶部反馈区独立
3. 主体稳定为三栏工作台
4. 空态、未命中态、无选中态在右栏有统一承接

### 11.3 风格一致性

完成后应满足：

1. 三块工作区标题层级一致
2. 容器外观和边距节奏一致
3. 操作区节奏统一
4. 页面整体更接近首页、消息中心已经建立的统一骨架语言

### 11.4 维护性

完成后应满足：

1. 修改工段区不需要通读整页
2. 修改工序区和详情区影响面更小
3. 后续新增加区块时不需要继续扩张主文件

### 11.5 保持不变的部分

以下内容在验收时必须保持不变：

1. 接口请求方式
2. 工段/工序增删改查行为
3. jump 承接语义
4. 权限判断结果
5. 原有关键交互路径

## 12. 风险与控制

### 风险 1：拆分过度

表现：

1. 文件增多但边界不清
2. 理解成本反而上升

控制方式：

1. 每个文件只保留单一职责
2. 不引入额外全局状态和 controller 层

### 风险 2：重构过程中误伤业务行为

控制方式：

1. 明确“只改结构和骨架，不改业务规则”
2. 后续 implementation plan 中要求对关键交互做回归验证

### 风险 3：只拆文件但没有真正统一骨架

控制方式：

1. 页头、反馈区、三栏容器必须统一接入
2. 验收标准中同时检查结构和统一性

## 13. 最终预期

本轮完成后，`process_management_page.dart` 不再只是“被拆开的大页”，而是成为一张：

1. 结构清楚
2. 风格统一
3. 仍保留工艺业务特征
4. 能继续长期维护

的工艺工作台页面。

## 14. 迁移说明

- 无迁移，直接替换
