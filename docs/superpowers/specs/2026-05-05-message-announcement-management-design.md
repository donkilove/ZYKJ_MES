# 消息中心公告管理子页设计

## 1. 背景

当前消息模块的公告能力仍停留在“消息中心里的一个动作入口”阶段：

- 前端 `MessageCenterPage` 以“消息列表、详情、已读、业务跳转”为核心，只在页头提供“发布公告”按钮。
- 前端没有“当前公告列表管理”页面，也没有“下线公告”操作。
- 后端当前仅提供公开公告读取与公告发布能力，缺少管理员视角的“当前生效公告管理”接口。
- 消息模块在页面目录与权限目录中已经具备 `message -> message_center` 的父子页结构，但前端主壳当前仍将 `pageCode='message'` 直接装配为 `MessageCenterPage`，没有把消息模块像 `user/product/production` 那样按子页承载。

随着需求从“能发布公告”升级为“管理员至少要能发布、下线公告”，公告已经不再只是消息中心里的附属动作，而是一个需要独立承载生命周期管理的对象。

## 2. 目标

1. 在“消息中心”模块下新增“公告管理”子页，承载管理员公告管理能力。
2. 覆盖本轮最小闭环：查看当前生效公告、发布公告、下线公告。
3. 保持公告仍归属于消息模块，不额外拆出新模块。
4. 收敛消息模块页面组织方式，使其与主壳现有 tab 化模块模式一致。

## 3. 非目标

1. 本轮不做历史公告档案页。
2. 本轮不做公告编辑、草稿、定时发布、复制复用、审批流。
3. 本轮不做公告效果统计、阅读分析、批量下线。
4. 本轮不改变登录页公开公告展示能力，只保证其不被本次改动破坏。

## 4. 现状摘要

### 4.1 前端

- `frontend/lib/features/message/presentation/message_center_page.dart`
  - 当前消息中心只负责消息列表与详情流。
  - `canPublishAnnouncement` 控制页头是否显示“发布公告”入口。
  - `_publishAnnouncement()` 仅打开 `AnnouncementPublishDialog`。
- `frontend/lib/features/message/presentation/widgets/message_center_action_dialogs.dart`
  - 仅提供 `showMessageCenterPublishDialog()`。
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 当前 `case 'message'` 直接返回 `MessageCenterPage`，没有像其他业务模块一样按可见 tab 组织子页。

### 4.2 后端

- `backend/app/api/v1/endpoints/messages.py`
  - 已有 `GET /messages/public-announcements`
  - 已有 `POST /messages/announcements`
  - 暂无“公告管理列表”与“公告下线”接口
- `backend/app/services/message_service.py`
  - `publish_announcement()` 已支持范围投放、优先级、过期时间
  - 消息状态主语义当前以 `active / source_unavailable / archived` 为主
  - 现有状态语义不足以表达“管理员主动下线公告”

### 4.3 页面与权限目录

- `backend/app/core/page_catalog.py`
  - 当前消息模块已有：
    - `message`（sidebar）
    - `message_center`（tab）
- `backend/app/core/authz_catalog.py` / `authz_hierarchy_catalog.py`
  - 当前与公告直接相关的现有能力只有 `message.announcements.publish`
  - 缺少“查看公告管理页”“下线公告”能力拆分

## 5. 候选方案

### 方案 A：继续把公告管理留在消息中心主页面

- 做法：
  - 继续在 `MessageCenterPage` 内扩展公告区、当前公告列表、下线按钮
- 优点：
  - 改动表面最少
- 缺点：
  - 混淆“普通用户收件箱”与“管理员公告运营台”两类职责
  - 会让刚重做过的消息中心再次膨胀
  - 后续继续扩展公告能力时，页面复杂度会持续上升

### 方案 B：在消息模块下新增“公告管理”子页

- 做法：
  - 保持 `message` 为父模块
  - 保留 `message_center`
  - 新增 `announcement_management` 子页
  - 管理员在消息模块内部切到该子页完成公告管理
- 优点：
  - 保持“公告属于消息体系”的业务归属
  - 将管理员管理流与普通消息处理流清晰拆开
  - 便于后续按需继续扩展公告管理能力
- 缺点：
  - 需要同时调整主壳消息模块装配方式与权限目录

### 方案 C：将公告管理拆成完全独立的新模块

- 做法：
  - 新增独立 sidebar 模块与页面树
- 优点：
  - 结构最独立
- 缺点：
  - 对当前范围明显过重
  - 破坏“公告属于消息系统”的自然归属
  - 增加导航层级与用户理解成本

## 6. 推荐方案

推荐 **方案 B：在消息模块下新增“公告管理”子页**。

原因：

1. 当前需求已经要求公告具备独立生命周期管理能力，继续塞回消息中心主页面会让职责持续混杂。
2. 公告本质上仍是消息系统的一类对象，保留在消息模块内比单独拆模块更符合现有架构。
3. 主壳当前对其他模块已经采用“父模块 + 子页”的承载方式，消息模块顺势收敛到一致模式，长期维护更稳。

## 7. 页面结构设计

### 7.1 页面层级

建议新增以下页面编码：

- 父模块：`message`
- 已有子页：`message_center`
- 新增子页：`announcement_management`

页面展示形式：

- 侧边栏进入“消息”
- 顶部 tab 至少包含：
  - `消息中心`
  - `公告管理`

默认行为建议：

- 对普通用户，仅看到 `消息中心`
- 对具有公告管理查看权限的管理员，显示 `公告管理`
- 消息模块默认首个可见 tab 作为落点；若用户显式跳转到 `announcement_management`，则按目标页签打开

### 7.2 公告管理子页页面边界

本轮只承载“当前生效公告管理”，不承载历史档案能力。

页面最小组成：

- 顶部操作区
  - `发布公告` 主按钮
  - 可选轻筛选：`全部当前公告 / 仅公开全员公告`
- 生效中公告列表
  - 标题
  - 优先级
  - 投放范围
  - 发布时间
  - 过期时间
  - 发布人
  - 当前状态
  - 操作：`查看`、`下线`
- 详情查看区
  - 完整正文
  - 投放范围明细
  - 收件人数
  - 发布时间
  - 失效时间

### 7.3 与消息中心主页面的关系

- `MessageCenterPage` 继续聚焦“我收到的消息”
- 原消息中心页头中的“发布公告”入口移除
- 所有公告管理动作统一收口到“公告管理”子页，避免双入口并存

## 8. 后端设计

### 8.1 状态语义

当前消息通用状态主要是：

- `active`
- `source_unavailable`
- `archived`

这不足以表达“管理员主动下线公告”。本轮建议为公告管理补充显式状态语义：

- `active`：公告生效中
- `offline`：管理员主动下线
- `archived`：长期归档态

约束建议：

- “当前生效公告”定义为：`status == active` 且未过期
- “已下线”定义为：`status == offline`
- “已过期”本轮不单独做独立管理页状态，只在查询逻辑中排除出“当前生效公告”
- 后续若需要长期收口，再由维护链路将过期或下线太久的公告归档为 `archived`

### 8.2 接口设计

#### 已复用接口

- `POST /messages/announcements`
  - 继续用于发布公告

#### 新增接口

- `GET /messages/announcements/active`
  - 用途：公告管理页读取当前生效公告
  - 支持可选筛选：
    - 是否仅查看公开全员公告
    - 优先级
    - 分页

- `POST /messages/announcements/{id}/offline`
  - 用途：管理员手动下线公告
  - 行为：
    - 校验该消息存在且类型为 `announcement`
    - 校验当前状态允许下线
    - 更新状态为 `offline`
    - 写审计日志

不推荐直接依赖普通消息列表接口 `GET /messages?message_type=announcement&status=active` 作为公告管理主接口，因为后续筛选语义会持续偏向管理页，而不是普通消息收件箱。

### 8.3 审计要求

公告发布与下线均需写审计日志。

发布日志保留现有逻辑，并补充与新管理流一致的上下文字段。

下线日志建议记录：

- 公告 ID
- 标题
- 操作人
- 下线时间
- 下线前状态
- 下线后状态
- 下线原因

本轮下线原因可以不强制前端填写，但接口和日志结构应预留字段。

## 9. 权限设计

当前仅有：

- `message.announcements.publish`

这不足以支持独立管理页。建议拆分为：

- `message.announcements.view`
- `message.announcements.publish`
- `message.announcements.offline`

并同步补齐对应 feature 能力：

- `feature.message.announcement.view`
- `feature.message.announcement.publish`
- `feature.message.announcement.offline`

页面与按钮控制建议：

- 是否显示“公告管理”子页：取决于 `message.announcements.view`
- 是否显示“发布公告”按钮：取决于 `message.announcements.publish`
- 是否显示“下线”操作：取决于 `message.announcements.offline`

## 10. 前端设计

### 10.1 主壳承载方式调整

当前 `MainShellPageRegistry` 对消息模块仍是：

- `pageCode='message'` -> 直接返回 `MessageCenterPage`

本轮建议将消息模块收敛到和其他模块一致的 tab 化承载方式：

- `message` 页面根据 `visibleTabCodes` 与 `preferredTabCode` 组织子内容
- `message_center` 对应消息中心页
- `announcement_management` 对应公告管理页

这样做的收益是：

1. 与 `user/product/equipment/production/quality/craft` 的主壳组织方式统一
2. 后续消息模块再增加其他管理子页时，不需要再次改主壳核心结构

### 10.2 公告管理页组件建议

建议新增独立页面，例如：

- `frontend/lib/features/message/presentation/announcement_management_page.dart`

并按现有模块风格拆出必要的展示组件与对话框。

推荐页面形态：

- 整页列表为主
- 发布公告使用弹窗复用现有发布表单能力
- 下线使用确认弹窗

不推荐直接复制消息中心的“双栏消息阅读”布局，因为公告管理本轮更偏“管理动作页”，不是阅读流。

### 10.3 服务层补充

建议在 `MessageService` 中新增：

- `getActiveAnnouncements()`
- `offlineAnnouncement()`

保留现有：

- `publishAnnouncement()`
- `getPublicAnnouncements()`

## 11. 数据与兼容性

### 11.1 数据迁移口径

若当前 `msg_message.status` 未允许 `offline`，需要补齐后端状态兼容逻辑与测试。

本轮推荐口径：

- 直接扩展公告可用状态语义，允许 `announcement` 类型使用 `offline`
- 不做历史数据迁移
- 历史 `active` 公告维持原状

### 11.2 兼容影响

- 登录页公开公告读取逻辑应继续只读取“当前公开生效公告”
- 下线后的全员公告不应继续出现在登录页公开公告接口结果中
- 普通消息列表与已读逻辑不应受公告管理页影响

## 12. 测试设计

### 12.1 后端测试

至少覆盖：

1. 发布公告后，能进入“当前生效公告”列表
2. 下线公告后，从“当前生效公告”列表消失
3. 下线后的公告不会继续出现在公开公告接口结果中
4. 无权限用户无法查看公告管理接口
5. 无权限用户无法执行公告下线
6. 已过期公告不会出现在“当前生效公告”列表

建议重点落在：

- `backend/tests/test_message_service_unit.py`
- `backend/tests/test_message_module_integration.py`
- 权限/目录相关测试

### 12.2 Flutter 页面测试

至少覆盖：

1. 消息模块在有权限时能展示 `公告管理` 子页
2. 公告管理页能正确渲染当前公告列表
3. 有发布权限时显示“发布公告”按钮
4. 有下线权限时显示“下线”操作
5. 下线成功后当前列表即时刷新
6. 消息中心主页面不再显示旧的“发布公告”入口

### 12.3 权限与导航回归

至少覆盖：

1. `page_catalog`、权限快照、可见 tab 显示一致
2. 无公告管理权限时，不应暴露 `announcement_management`
3. 主壳从消息模块默认落点到首个可见页签的逻辑不回归

### 12.4 公开公告回归

至少覆盖：

1. 登录页公开公告仍可读取当前全员公告
2. 下线后的全员公告不会继续展示

## 13. 分阶段实施顺序

### 阶段 1：后端补管理语义

- 新增公告管理查询接口
- 新增公告下线接口
- 新增权限与审计
- 明确 `active / offline / archived` 语义

原因：

- 若后端没有稳定管理语义，前端页面只能做伪管理

### 阶段 2：页面目录与权限目录补齐

- `page_catalog` 新增 `announcement_management`
- 权限目录新增公告查看/下线能力
- 主壳快照与 tab 可见性联动补齐

### 阶段 3：前端公告管理子页实现

- 新增公告管理页
- 接入当前生效公告列表
- 接入发布与下线操作

### 阶段 4：旧入口收口与回归

- 从消息中心主页面移除“发布公告”按钮
- 补齐回归测试
- 确认登录页公开公告链路不回归

## 14. 风险与权衡

### 风险 1：消息模块前端承载方式不一致

当前消息模块虽然在后端目录上已是父子页结构，但前端主壳仍把 `message` 直接装配为单页。  
本轮若只补公告页、不顺手收敛消息模块承载方式，后续会继续积累特例。

### 风险 2：状态语义与现有维护链路耦合

若简单复用 `archived` 或 `source_unavailable` 作为“下线”，会混淆人工运营动作与系统自动状态。  
因此本轮应明确保留 `offline` 作为管理员主动动作语义。

### 风险 3：双入口并存造成操作歧义

若保留消息中心页头“发布公告”，同时新增公告管理页，会导致管理员不清楚应从哪里完成公告操作。  
因此本轮推荐统一收口到公告管理页。

## 15. 验收标准

- [ ] 消息模块下新增 `公告管理` 子页
- [ ] 管理员可查看当前生效公告列表
- [ ] 管理员可发布公告
- [ ] 管理员可下线公告
- [ ] 下线后的公告不再出现在当前生效列表与公开公告展示中
- [ ] 消息中心主页面不再保留旧的发布公告入口
- [ ] 权限与导航显隐行为正确
- [ ] 相关后端、前端、回归测试通过

