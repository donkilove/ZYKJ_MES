# 产品参数管理页第二波迁移设计

## 1. 背景

前端 UI 基础件体系第一轮已经完成，当前仓库已经具备 `foundation / primitives / patterns` 三层能力，并且设置页、首页、消息中心已经完成第一批试点迁移。

产品模块第二波迁移也已经继续向前推进，当前已经完成：

1. `ProductVersionManagementPage` 第二波迁移
2. `ProductManagementPage` 第二波迁移

这意味着产品模块内部已经完成了“主从页”和“中等复杂 CRUD 页 + 侧栏 + 弹窗”的第二波验证。下一步继续推进 `ProductParameterManagementPage`，可以把产品模块的第二波迁移补完整，并进一步验证“列表态 + 编辑工作区 + 历史弹窗”这类高复杂工作台页在统一 UI 体系中的落地方式。

`frontend/lib/features/product/presentation/product_parameter_management_page.dart` 当前是产品模块里复杂度最高的页面之一，既有版本参数列表，又有编辑工作区、历史弹窗、导出动作和 `jump command` 直达编辑态逻辑。它非常适合用来验证第二波迁移在“复杂编辑工作台页”上的边界。

## 2. 当前现状

### 2.1 页面是“列表 + 编辑器 + 历史弹窗”的复合工作台页

当前页面包含以下主要区域：

1. 版本参数列表区
2. 参数编辑工作区
3. 参数历史弹窗
4. 导出动作

这意味着它不是简单的 CRUD 页，而是一个带有明显工作流的复合编辑页。

### 2.2 主文件承担了过多展示职责

`product_parameter_management_page.dart` 当前同时承担：

1. 列表态页头与筛选区布局
2. 版本参数列表表格渲染
3. 编辑态头部和工具条布局
4. 参数编辑表格渲染
5. 参数行拖拽与按钮布局
6. 历史弹窗渲染
7. 快照弹窗渲染

这导致主文件同时包含列表页、编辑器页和弹窗页的大段展示代码，维护成本高、定位回归也更困难。

### 2.3 当前测试基础较强，但结构回归仍然缺位

当前产品模块已经存在较强行为回归，尤其是：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

其中已经覆盖了：

1. 参数列表首屏绑定版本行
2. 历史查询绑定所选版本
3. 编辑入口绑定所选版本
4. 保存入口绑定所选版本
5. Link 参数即时校验
6. 不回退旧参数接口

但当前仍缺少：

1. 独立的 `frontend/test/widgets/product_parameter_management_page_test.dart`
2. 本页的最小 integration 观察点

这意味着“结构是否统一”“列表态 / 编辑态 / 历史弹窗是否接入第二波骨架”仍主要依赖大回归文件间接证明。

## 3. 已确认路线

本轮采用路线 B：中度迁移。

三种候选路线的判断如下：

### 路线 A：最小迁移

只统一列表态主骨架，编辑器和历史弹窗基本不动。

优点：

1. 风险最低
2. 改动边界最小

缺点：

1. 主文件最重的部分依旧是编辑器和历史弹窗
2. 第二波迁移收益不够大

### 路线 B：中度迁移

统一列表态和编辑器页骨架，并把历史弹窗展示层一起拆出来，但参数保存逻辑、脏数据判断、服务调用和 `jump command` 处理仍保留在主页面。

优点：

1. 能显著压薄主文件
2. 能继续验证第二波迁移在复杂编辑工作台页上的适配能力
3. 仍然能把改动边界控制在展示层和页面装配层

缺点：

1. 工作量中等偏高
2. 需要新增页面级 widget test 和最小 integration test

### 路线 C：深拆重构

除了展示层迁移，还继续重构编辑器内部状态、参数行管理、保存前校验和跳转编排。

优点：

1. 长期结构最干净

缺点：

1. 会直接越过“页面迁移”的边界，变成“参数编辑器重写”
2. 风险显著升高
3. 不适合当前阶段的稳妥推进方式

### 最终选择

本轮明确采用路线 B，不采用路线 A 和路线 C。

## 4. 目标

1. 将 `ProductParameterManagementPage` 迁移为“统一列表态骨架 + 统一编辑态骨架 + 历史弹窗展示层拆分”的结构。
2. 把列表态中的页头、筛选区、反馈区、版本参数列表区从主页面拆出。
3. 把编辑态中的头部、工具条、编辑表格、底部动作区拆成稳定展示组件。
4. 把历史弹窗和快照弹窗拆成稳定展示层。
5. 在不改参数保存逻辑、不改服务契约、不改 `jump command` 语义的前提下，补齐页面级 widget test、产品模块回归断言和最小 integration 观察点。

## 5. 非目标

1. 本轮不改参数保存逻辑。
2. 本轮不改 `jump command` 语义。
3. 本轮不改 Link 参数校验规则。
4. 本轮不改草稿可编辑 / 非草稿只读规则。
5. 本轮不改服务契约，也不回退到旧参数接口。
6. 本轮不把历史弹窗改成交互式 diff 工作台。
7. 本轮不引入 controller / coordinator。
8. 本轮不追求移动端精细重绘，只要求窄宽度不崩。

## 6. 页面总体设计

### 6.1 顶层结构

页面收敛为两种主视图：

1. 列表态：版本参数列表页
2. 编辑态：版本参数编辑工作区

列表态顶层统一为：

1. `ProductParameterManagementPageHeader`
2. `ProductParameterManagementFilterSection`
3. `ProductParameterManagementFeedbackBanner`
4. `ProductParameterVersionTableSection`

编辑态顶层统一为：

1. `ProductParameterEditorHeader`
2. `ProductParameterEditorToolbar`
3. `ProductParameterEditorTable`
4. `ProductParameterEditorFooter`

历史弹窗单独拆为：

1. `ProductParameterHistoryDialog`
2. `ProductParameterHistorySnapshotDialog`

### 6.2 主页面职责

`product_parameter_management_page.dart` 保留以下职责：

1. 列表数据加载
2. 编辑态进入与退出
3. 参数保存
4. 历史查询与弹窗打开
5. 导出动作
6. `jump command` 处理
7. 脏数据确认与 Link 校验
8. 服务调用与权限判断

主页面不再直接承担大段列表态、编辑态和历史弹窗展示代码。

## 7. 页面组件拆分

建议新增以下组件：

1. `frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart`
2. `frontend/lib/features/product/presentation/widgets/product_parameter_management_filter_section.dart`
3. `frontend/lib/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart`
4. `frontend/lib/features/product/presentation/widgets/product_parameter_version_table_section.dart`
5. `frontend/lib/features/product/presentation/widgets/product_parameter_editor_header.dart`
6. `frontend/lib/features/product/presentation/widgets/product_parameter_editor_toolbar.dart`
7. `frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart`
8. `frontend/lib/features/product/presentation/widgets/product_parameter_editor_footer.dart`
9. `frontend/lib/features/product/presentation/widgets/product_parameter_history_dialog.dart`
10. `frontend/lib/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart`

如有必要，可继续新增：

1. `product_parameter_type_chip.dart`
2. `product_parameter_scope_badge.dart`

### 7.1 ProductParameterManagementPageHeader

职责：

1. 展示列表态页头
2. 提供刷新入口

### 7.2 ProductParameterManagementFilterSection

职责：

1. 产品名称筛选
2. 分类筛选
3. 列表态主操作入口

### 7.3 ProductParameterManagementFeedbackBanner

职责：

1. 列表态页内错误提示
2. 列表态统一反馈展示

### 7.4 ProductParameterVersionTableSection

职责：

1. 版本参数列表区
2. 版本状态展示
3. 操作列包装
4. 空态 / 加载态接入统一件

### 7.5 ProductParameterEditorHeader

职责：

1. 编辑态标题
2. 返回列表入口
3. 只读状态提示

### 7.6 ProductParameterEditorToolbar

职责：

1. 分组筛选
2. 刷新参数
3. 未保存修改提示

### 7.7 ProductParameterEditorTable

职责：

1. 参数编辑表格主体
2. 参数行展示
3. 拖拽区域展示
4. 行级删除按钮展示

### 7.8 ProductParameterEditorFooter

职责：

1. 新增参数入口
2. 备注输入
3. 保存 / 取消动作区

### 7.9 ProductParameterHistoryDialog

职责：

1. 展示历史弹窗整体骨架
2. 展示历史列表与摘要信息
3. 提供查看快照入口

### 7.10 ProductParameterHistorySnapshotDialog

职责：

1. 展示前后快照文本
2. 作为历史弹窗的二级展示层

## 8. 交互保持策略

本轮采用“结构重组、交互保守”的迁移策略。

以下行为必须保持不变：

1. 列表态仍然展示：产品名称、产品分类、版本标签/版本号、创建时间、版本状态、操作
2. 列表态操作仍然是：查看参数、查看历史、编辑参数、导出参数
3. 编辑态仍然保留：
   - 返回列表
   - 分组筛选
   - 刷新参数
   - 新增参数
   - 参数行拖拽排序
   - 参数行删除
   - 备注输入
   - 保存参数
4. `jump command` 仍然可以直达指定版本的编辑态
5. Link 类型参数的即时校验语义保持不变
6. 草稿可编辑、非草稿只读语义保持不变
7. 历史弹窗仍保留“查看快照”二级弹窗
8. 导出仍保持当前文件导出口径

## 9. 数据流与状态边界

本轮不新增页面级 controller，状态仍保留在主页面内部，但收敛装配方式。

建议状态边界如下：

### 9.1 页面级状态

1. 列表态数据与筛选状态
2. 当前编辑目标与编辑态状态
3. 参数编辑行集合
4. 脏数据状态
5. 历史弹窗相关数据
6. 页面提示消息

### 9.2 页面部件输入

各页面部件只接收展示所需最小数据，不直接访问服务层。

### 9.3 动作入口

主页面继续统一处理：

1. `_loadProducts()`
2. `_enterEditor()`
3. `_saveEditor()`
4. `_showHistoryDialog()`
5. `_exportVersionParameters()`
6. `_handleJumpCommand()`

组件只负责触发，不负责决定动作实现。

## 10. 测试设计

### 10.1 新增页面级 widget test

建议新增：

1. `frontend/test/widgets/product_parameter_management_page_test.dart`

至少覆盖：

1. 列表态统一骨架已接入
2. 编辑态统一骨架已接入
3. 历史弹窗入口保留
4. 编辑态头部、工具条、表格、底部动作区锚点已接入

### 10.2 保留并扩展既有回归

继续依赖：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

必须继续覆盖：

1. 版本行绑定
2. 历史查询绑定所选版本
3. 编辑入口绑定所选版本
4. 保存入口绑定所选版本
5. Link 校验
6. 不回退旧参数接口

### 10.3 Integration 观察点

建议新增：

1. `frontend/integration_test/product_parameter_management_flow_test.dart`

至少观察以下主路径：

1. 进入列表态
2. 打开编辑态
3. 打开历史弹窗

## 11. 实施顺序建议

建议按以下顺序实施：

1. 先拆列表态基础组件
2. 再将主页面列表态接入统一骨架
3. 再拆编辑态展示层
4. 再拆历史弹窗展示层
5. 最后补页面级测试、产品模块回归、integration 和 `evidence`

不建议一开始就先拆编辑器表格内部行为，因为那部分最容易触发参数编辑逻辑重构；先把“外层骨架”和“长布局拆分”稳住，风险更可控。

## 12. 风险与控制方式

### 风险 1：编辑器拆分后误伤参数编辑逻辑

控制方式：

1. 只拆展示层，不改参数编辑逻辑
2. 不改保存前整理流程
3. 不改脏数据确认逻辑

### 风险 2：历史弹窗拆分后把查询逻辑带跑

控制方式：

1. 历史查询继续由主页面发起
2. 弹窗组件只负责展示
3. 快照弹窗也只负责展示，不引入新的数据流

### 风险 3：编辑态与列表态切换回归

控制方式：

1. 主页面继续持有 `_editingTarget`
2. 主页面继续持有 `jump command` 处理状态
3. 列表 / 编辑切换逻辑不下沉到子组件

### 风险 4：测试继续只靠大回归文件

控制方式：

1. 本轮必须新增 `product_parameter_management_page_test.dart`
2. 把结构回归从大回归文件中拆出来
3. 用 integration 只验证主路径，不塞入全部编辑行为

## 13. 预期结果

本轮完成后，`ProductParameterManagementPage` 应从“大页面同时承载列表、编辑器、历史弹窗”升级为“统一列表态骨架 + 统一编辑态骨架 + 历史弹窗展示层拆分”的结构。

预期收益：

1. 主文件显著变薄
2. 产品模块第二波迁移形成更完整样板
3. 编辑工作台页的第二波迁移边界得到验证
4. 当前参数编辑语义保持稳定，迁移风险可控

## 14. 迁移说明

- 无迁移，直接替换
