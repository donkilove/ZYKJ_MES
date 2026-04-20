# 产品管理页第二波迁移设计

## 1. 背景

前端 UI 基础件体系第一轮已经完成，当前仓库已经具备 `foundation / primitives / patterns` 三层能力，并且设置页、首页、消息中心已经完成第一批试点迁移。

用户模块第二波迁移已经验证了 `MesCrudPageScaffold` 在中等复杂 CRUD 页上的稳定性，产品版本管理页第二波迁移也已经验证了 `MesListDetailShell` 在“主列表 + 工作区”结构中的可复用性。这意味着当前前端已经具备继续推进“模块级第二波迁移”的基础条件。

`frontend/lib/features/product/presentation/product_management_page.dart` 是产品模块里最适合作为下一站的页面：它既是标准 CRUD 页面，又带有详情侧栏和版本管理弹窗，复杂度明显高于普通单表页，但还没有进入参数管理页那类高复杂工作台级页面。用它来做第二波迁移，可以继续验证“统一主骨架 + 展示层拆分 + 复杂弹窗展示层拆分”的组合策略。

## 2. 当前现状

### 2.1 页面是“筛选 + 列表 + 侧栏 / 弹窗”的复合 CRUD 页

当前页面包含以下主要区域：

1. 顶部页头
2. 筛选区
3. 产品列表区
4. 详情侧栏
5. 版本管理弹窗

这意味着它不只是一个普通的表格查询页，而是一个“主列表 + 扩展详情 + 二级操作工作区”组合页。

### 2.2 主文件承担了过多展示职责

`product_management_page.dart` 当前同时承担：

1. 筛选区布局
2. 列表表格渲染
3. 行级操作菜单构造
4. 页内错误消息展示
5. 详情侧栏整块渲染
6. 版本管理弹窗整块渲染
7. 详情侧栏内部参数快照、关联信息、变更记录渲染
8. 版本管理弹窗内部版本对比、版本列表、版本动作区渲染

这导致主文件同时承担页面结构、局部视觉、扩展工作区和业务动作入口，后续维护成本偏高。

### 2.3 当前页面仍主要使用旧式布局和本地视觉语义

页面顶层仍是 `Padding + CrudPageHeader + Row + CrudListTableSection + SimplePaginationBar` 的手工拼装形式，状态展示和区块组织也还没有完全切到 `core/ui` 第二阶段模式件。

### 2.4 当前测试基础较强，但结构回归缺口明显

当前产品模块已经存在较强的行为回归，尤其是：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

它已经覆盖了：

1. 筛选行为
2. 分页校正
3. 产品表单校验
4. 生命周期切换
5. 详情侧栏聚合展示
6. 版本管理弹窗链路
7. 参数入口与参数页联动

但当前仍缺少：

1. 独立的 `frontend/test/widgets/product_management_page_test.dart`
2. 产品管理页的最小 integration 观察点

这使得“结构是否统一”“页面骨架是否接入”仍主要依赖大回归文件来间接证明。

## 3. 已确认路线

本轮采用路线 B：中度迁移。

三种候选路线的判断如下：

### 路线 A：最小统一迁移

仅统一页头、筛选区、列表区、页内反馈，详情侧栏和版本管理弹窗保持原地不动。

优点：

1. 风险最低
2. 改动边界最小

缺点：

1. 主文件仍然过重
2. 第二波迁移收益不够大
3. 详情侧栏和版本管理弹窗仍无法纳入统一展示体系

### 路线 B：中度迁移

主页面统一之外，允许把详情侧栏和版本管理弹窗的展示层一起拆出，但不改业务逻辑、不改后端契约、不下沉 controller。

优点：

1. 能显著降低主文件体积
2. 能继续验证第二波迁移在“CRUD 页 + 侧栏 + 复杂弹窗”场景中的适配能力
3. 仍然可以把改动边界控制在展示层和页面装配层

缺点：

1. 工作量中等偏高
2. 需要新增页面级 widget test 和最小 integration test

### 路线 C：深拆重构

在路线 B 基础上，继续下沉详情侧栏和版本管理弹窗内部状态管理，重构版本对比、影响确认和弹窗内部状态流。

优点：

1. 长期结构最干净

缺点：

1. 会把“页面迁移”扩大成“模块重构”
2. 风险显著升高
3. 不适合作为当前阶段的稳妥推进方式

### 最终选择

本轮明确采用路线 B，不采用路线 A 和路线 C。

## 4. 目标

1. 将 `ProductManagementPage` 迁移为“统一页头 + CRUD 页面骨架 + 展示层装配”的结构。
2. 把筛选区、反馈区、列表区从主页面中拆出，降低主文件复杂度。
3. 把详情侧栏拆成稳定展示层，统一信息区块、参数快照、关联信息和变更记录的视觉语言。
4. 把版本管理弹窗拆成稳定展示层，并在不改变业务语义的前提下，拆出版本对比区和弹窗内部的展示子块。
5. 在不改后端契约、不改业务规则的前提下，补齐页面级 widget test、产品模块回归断言和最小 integration 观察点。

## 5. 非目标

1. 本轮不改后端接口契约。
2. 本轮不改产品生命周期业务规则。
3. 本轮不重写版本管理弹窗内部的业务逻辑。
4. 本轮不把详情侧栏改成页面常驻布局。
5. 本轮不联动改 `ProductParameterManagementPage` 和 `ProductParameterQueryPage`。
6. 本轮不引入页面级 controller / coordinator。
7. 本轮不追求移动端精细化重绘，只要求窄宽度不崩。

## 6. 页面总体设计

### 6.1 顶层结构

页面顶层统一为：

1. `ProductManagementPageHeader`
2. `ProductManagementFilterSection`
3. `ProductManagementFeedbackBanner`
4. `ProductManagementTableSection`
5. `MesPaginationBar`

其中：

1. 页头负责标题和刷新动作
2. 筛选区负责关键词、分类、状态、生效版本和顶部主动作
3. 反馈区负责页面级错误提示
4. 列表区负责表格主体和操作列包装
5. 分页区继续使用统一分页件

### 6.2 主页面职责

`product_management_page.dart` 保留以下职责：

1. 页面状态
2. 数据加载
3. 生命周期、导出、表单等业务动作入口
4. 行级菜单分发
5. 详情侧栏和版本管理弹窗的打开动作
6. 服务调用与权限判断

主页面不再直接承担大段筛选区、表格区、详情侧栏和版本弹窗展示代码。

## 7. 页面组件拆分

建议新增以下组件：

1. `frontend/lib/features/product/presentation/widgets/product_management_page_header.dart`
2. `frontend/lib/features/product/presentation/widgets/product_management_filter_section.dart`
3. `frontend/lib/features/product/presentation/widgets/product_management_feedback_banner.dart`
4. `frontend/lib/features/product/presentation/widgets/product_management_table_section.dart`
5. `frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart`
6. `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
7. `frontend/lib/features/product/presentation/widgets/product_version_dialog.dart`
8. `frontend/lib/features/product/presentation/widgets/product_version_compare_panel.dart`
9. `frontend/lib/features/product/presentation/widgets/product_related_info_section.dart`
10. `frontend/lib/features/product/presentation/widgets/product_history_timeline.dart`

### 7.1 ProductManagementPageHeader

职责：

1. 展示页面标题
2. 提供刷新入口

### 7.2 ProductManagementFilterSection

职责：

1. 关键词筛选
2. 分类筛选
3. 状态筛选
4. 生效版本筛选
5. 顶部主操作按钮区

### 7.3 ProductManagementFeedbackBanner

职责：

1. 页内错误提示
2. 页内统一反馈展示

### 7.4 ProductManagementTableSection

职责：

1. 产品表格
2. 产品状态展示
3. 操作列包装
4. 空态 / 加载态接入统一件

### 7.5 ProductManagementStatusChip

职责：

1. 产品状态语义薄包装
2. 若可直接复用 `MesStatusChip`，则仅在此封装状态映射，不新增新的基础视觉语言

### 7.6 ProductDetailDrawer

职责：

1. 展示产品详情侧栏整体骨架
2. 承接基本信息区
3. 承接参数快照区
4. 承接关联信息区
5. 承接变更记录区

### 7.7 ProductVersionDialog

职责：

1. 展示版本管理弹窗整体骨架
2. 承接版本顶部动作区
3. 承接版本对比区
4. 承接版本列表区
5. 承接版本行级动作入口

### 7.8 ProductVersionComparePanel

职责：

1. 展示版本对比结果
2. 展示新增 / 移除 / 变更统计与差异条目

### 7.9 ProductRelatedInfoSection

职责：

1. 展示详情侧栏中的关联信息块
2. 统一标题、数量和空态语言

### 7.10 ProductHistoryTimeline

职责：

1. 展示详情侧栏中的变更记录区
2. 统一时间、操作者和摘要排列

## 8. 交互保持策略

本轮采用“结构重组、交互保守”的迁移策略。

以下行为必须保持不变：

1. 顶部筛选仍是：关键词、分类、状态、生效版本
2. 顶部主动作仍是：搜索产品、添加产品、导出产品
3. 行级菜单语义仍是：
   - 查看详情
   - 停用 / 启用
   - 编辑产品
   - 版本管理
   - 查看参数
   - 编辑参数
   - 删除产品
4. 详情仍保持“右侧侧栏”进入方式
5. 版本管理仍保持“弹窗工作区”语义
6. 生命周期确认、影响分析确认、导出、详情聚合、版本对比、回滚、生效 / 停用 / 删除语义保持不变

## 9. 数据流与状态边界

本轮不新增页面级 controller，状态仍保留在主页面内部，但收敛装配方式。

建议状态边界如下：

### 9.1 页面级状态

1. 产品列表与分页状态
2. 筛选状态
3. 页内提示消息
4. 详情侧栏打开时的聚合详情数据
5. 版本管理弹窗内部当前装配所需状态

### 9.2 页面部件输入

各页面部件只接收展示所需最小数据，不直接访问服务层。

### 9.3 动作入口

主页面继续统一处理：

1. `_loadProducts()`
2. `_showCreateProductDialog()`
3. `_showEditProductDialog()`
4. `_changeLifecycle()`
5. `_deleteProduct()`
6. `_exportProducts()`
7. `_showDetailDrawer()`
8. `_showVersionDialog()`

组件只负责触发，不负责决定动作实现。

## 10. 测试设计

### 10.1 新增页面级 widget test

建议新增：

1. `frontend/test/widgets/product_management_page_test.dart`

至少覆盖：

1. `MesCrudPageScaffold` 已接入
2. 筛选区已拆出
3. 反馈区已接入
4. 列表区已拆出
5. 详情侧栏入口已保留
6. 版本管理弹窗入口已保留

### 10.2 保留并扩展既有回归

继续依赖：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

必须继续覆盖：

1. 产品筛选与分页校正
2. 产品表单校验
3. 生命周期切换
4. 详情侧栏聚合展示
5. 版本管理弹窗链路
6. 参数入口与参数页联动

### 10.3 Integration 观察点

建议新增：

1. `frontend/integration_test/product_management_flow_test.dart`

至少观察以下主路径：

1. 进入产品管理页
2. 使用筛选区
3. 打开详情侧栏
4. 打开版本管理弹窗

## 11. 实施顺序建议

建议按以下顺序实施：

1. 先抽 `ProductManagementPageHeader / ProductManagementFilterSection / ProductManagementFeedbackBanner / ProductManagementTableSection`
2. 再迁主页面顶层到 `MesCrudPageScaffold`
3. 再拆 `ProductDetailDrawer`
4. 再拆 `ProductVersionDialog`
5. 视情况继续薄拆 `ProductVersionComparePanel / ProductRelatedInfoSection / ProductHistoryTimeline`
6. 最后补页面级测试、产品模块回归、integration 和 `evidence`

不建议一开始就先拆版本管理弹窗，因为该块复杂度最高，先把主页面和详情侧栏稳住，更有利于控制风险。

## 12. 风险与控制方式

### 风险 1：版本管理弹窗范围失控

控制方式：

1. 只拆展示组件，不重写状态机
2. 不新建 controller
3. 服务调用与动作入口继续留在主页面

### 风险 2：详情侧栏拆分后回归面变大

控制方式：

1. 详情数据继续由主页面一次性准备
2. 侧栏组件只负责展示
3. 参数快照、关联信息、变更记录继续由既有回归覆盖

### 风险 3：测试继续堆在大回归文件里

控制方式：

1. 本轮必须新增 `product_management_page_test.dart`
2. 把结构回归从大回归文件中拆出来
3. 用 integration 只验证主路径，不塞入所有业务链路

### 风险 4：中度迁移误伤现有交互

控制方式：

1. 坚持“结构变、语义不变”
2. 菜单文案、确认逻辑、成功失败提示保持现状
3. 不改后端契约和业务规则

## 13. 预期结果

本轮完成后，`ProductManagementPage` 应从“大页面直接承载筛选、列表、详情侧栏、版本弹窗”升级为“统一主骨架 + 展示层装配 + 扩展工作区拆分”的结构。

预期收益：

1. 主文件显著变薄
2. 产品模块形成更完整的第二波迁移样板
3. `MesCrudPageScaffold` 在中等复杂 CRUD 页场景中进一步验证稳定
4. 详情侧栏和复杂弹窗的展示层拆分方式得到验证
5. 当前交互语义保持稳定，迁移风险可控

## 14. 迁移说明

- 无迁移，直接替换
