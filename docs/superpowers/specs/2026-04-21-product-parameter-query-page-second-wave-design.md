# 产品参数查询页第二波迁移设计

## 1. 背景

前端 UI 基础件体系第一轮已经完成，当前仓库已经具备 `foundation / primitives / patterns` 三层能力，并且设置页、首页、消息中心已经完成第一批试点迁移。

产品模块第二波迁移也已经连续推进，当前已经完成：

1. `ProductVersionManagementPage` 第二波迁移
2. `ProductManagementPage` 第二波迁移
3. `ProductParameterManagementPage` 第二波迁移

这意味着产品模块内部已经完成了“版本工作区页”“主列表 + 侧栏 / 弹窗页”“复杂参数工作台页”的第二波验证。继续推进 `ProductParameterQueryPage`，可以把产品模块里剩余的最后一个核心页面一起收口，并验证“轻量查询页 + 只读参数弹窗”的第二波迁移边界。

`frontend/lib/features/product/presentation/product_parameter_query_page.dart` 当前复杂度低于参数管理页，但仍同时承载列表页、参数查看弹窗、Link 打开、导出动作和 `jump command` 直达查看逻辑。它非常适合作为产品模块第二波迁移的低风险收尾页。

## 2. 当前现状

### 2.1 页面是“轻查询列表 + 只读参数弹窗”的组合页

当前页面包含以下主要区域：

1. 顶部页头
2. 关键词与分类筛选区
3. 产品参数查询列表
4. 参数查看弹窗
5. 导出动作
6. `jump command` 直达查看弹窗链路

它不是复杂工作台页，但也不只是一个单表页，因为“查看参数”弹窗已经形成了一个稳定的二级只读工作区。

### 2.2 主文件承担了过多展示职责

`product_parameter_query_page.dart` 当前同时承担：

1. 查询页头与筛选区布局
2. 页内错误消息展示
3. 列表表格渲染
4. 参数查看弹窗整块渲染
5. Link 单元格按钮渲染
6. 空态 / 加载态装配
7. `jump command` 进入后查看链路

这导致主文件同时装配列表页与弹窗页的大段展示代码。虽然页面总体不重，但如果继续直接在这里叠加摘要信息，主文件会再次变胖，不利于产品模块第二波迁移样板的统一。

### 2.3 当前行为回归基础已经具备

当前产品模块已经存在较强的行为回归，尤其是：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

其中已经覆盖了：

1. 参数查询页使用专用只读查询接口
2. 参数查询首屏分页大小、启用状态和生效版本过滤口径
3. 参数查看弹窗链路
4. Link 类型参数打开外链
5. 导出链路
6. `jump command` 直达查看弹窗

但当前仍缺少：

1. 独立的 `frontend/test/widgets/product_parameter_query_page_test.dart`
2. 参数查看弹窗结构回归的独立锚点

这意味着“列表页是否完成第二波统一骨架”“弹窗展示层是否已拆出”“顶部摘要区是否稳定”仍缺少专门的页面级验证。

## 3. 已确认路线

### 3.1 页面迁移路线

本轮仍采用路线 B：中度迁移。

即：

1. 统一查询列表页骨架
2. 拆出参数查看弹窗展示层
3. 保持查询、导出、Link 打开和 `jump command` 语义不变

不采用路线 A 的原因是收益太低，不采用路线 C 的原因是会把页面迁移扩大成业务重构。

### 3.2 弹窗摘要区方案

参数查看弹窗顶部摘要区采用方案 C：可复用组件。

三种候选方案的判断如下：

#### 方案 A：直接内联到弹窗顶部

优点：

1. 改动最少

缺点：

1. 弹窗结构会继续贴在主文件或弹窗壳组件中
2. 后续若参数管理页、版本详情等场景需要相同摘要块，难以复用

#### 方案 B：弹窗专用头部组件

优点：

1. 结构清晰
2. 改动风险低

缺点：

1. 只能服务参数查询弹窗
2. 后续若出现相同摘要需求，仍需重复造轮子

#### 方案 C：轻量可复用摘要组件

优点：

1. 可以服务当前参数查询弹窗
2. 后续若参数管理页历史弹窗、参数详情侧栏等场景需要同类摘要，可直接复用
3. 复用范围仍限制在产品参数域，不会把抽象上升到过早的全局基础件

缺点：

1. 比方案 A / B 多一层组件抽象

### 最终选择

本轮明确采用：

1. 页面迁移路线 B
2. 弹窗摘要区方案 C

## 4. 目标

1. 将 `ProductParameterQueryPage` 迁移为“统一查询页骨架 + 参数查看弹窗展示层拆分”的结构。
2. 把页头、筛选区、反馈区、列表区从主页面拆出。
3. 把参数查看弹窗拆成稳定展示层。
4. 在参数查看弹窗顶部增加一个很轻的摘要区，展示产品名、版本标签、参数总数等关键信息。
5. 将该摘要区设计为产品参数域内的可复用展示组件。
6. 在不改查询逻辑、不改导出逻辑、不改 `jump command` 行为的前提下，补齐页面级 widget test 与既有回归锚点。

## 5. 非目标

1. 本轮不改查询接口契约。
2. 本轮不改导出接口契约。
3. 本轮不改 `jump command` 语义。
4. 本轮不改 Link 参数打开规则。
5. 本轮不新增二次操作按钮或弹窗内工具条。
6. 本轮不把参数查看弹窗扩展成编辑弹窗。
7. 本轮不引入 controller / coordinator。
8. 本轮不把摘要组件上升为 `core/ui` 全局基础件。

## 6. 页面总体设计

### 6.1 顶层结构

查询页顶层统一为：

1. `ProductParameterQueryPageHeader`
2. `ProductParameterQueryFilterSection`
3. `ProductParameterQueryFeedbackBanner`
4. `ProductParameterQueryTableSection`

参数查看弹窗统一为：

1. `ProductParameterQueryDialog`
2. `ProductParameterSummaryHeader`

其中：

1. `ProductParameterQueryDialog` 负责弹窗骨架、表格区和关闭动作
2. `ProductParameterSummaryHeader` 负责顶部轻摘要展示

### 6.2 主页面职责

`product_parameter_query_page.dart` 保留以下职责：

1. 列表数据加载
2. 查询条件维护
3. 导出动作
4. `jump command` 处理
5. 参数查看数据请求
6. Link 打开动作
7. 服务调用与权限判断

主页面不再直接承担大段页头、筛选区、列表区和参数查看弹窗展示代码。

## 7. 页面组件拆分

建议新增以下组件：

1. `frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart`
2. `frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart`
3. `frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart`
4. `frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart`
5. `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
6. `frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart`

如弹窗内 Link 单元格渲染压力上升，可再按需新增：

1. `product_parameter_link_value_button.dart`

本轮不预设该组件，避免过度拆分。

### 7.1 ProductParameterQueryPageHeader

职责：

1. 展示页面标题
2. 提供刷新入口

### 7.2 ProductParameterQueryFilterSection

职责：

1. 产品名称查询
2. 产品分类筛选
3. 搜索动作
4. 导出动作入口

### 7.3 ProductParameterQueryFeedbackBanner

职责：

1. 页内错误提示
2. 页内统一反馈展示

### 7.4 ProductParameterQueryTableSection

职责：

1. 产品参数查询列表
2. 生效版本标签展示
3. 状态展示
4. 操作列包装
5. 空态 / 加载态接入统一件

### 7.5 ProductParameterQueryDialog

职责：

1. 展示参数查看弹窗整体骨架
2. 承接顶部摘要区
3. 承接参数表格区
4. 承接空态展示
5. 承接关闭动作区

### 7.6 ProductParameterSummaryHeader

职责：

1. 展示产品名
2. 展示版本标签
3. 展示参数总数
4. 视情况展示极轻量上下文说明，例如“仅展示生效参数”

约束：

1. 只负责展示，不提供动作按钮
2. 不自行请求数据
3. 不绑定页面级业务状态
4. 复用范围限定在产品参数域内

## 8. 顶部摘要区设计

### 8.1 展示信息

顶部摘要区只展示轻量信息，不承载任何操作。建议信息包括：

1. 产品名
2. 版本标签
3. 参数总数
4. 参数口径提示

其中“参数口径提示”建议固定为只读文案，例如：

1. `仅展示当前生效版本参数`

### 8.2 视觉层级

摘要区应比表格轻，不应做成新的工具条。建议采用：

1. 标题级产品名
2. 次级说明文本展示版本标签与参数总数
3. 与表格区之间保留一个稳定间距

### 8.3 空态位置

即使参数总数为 0，也保留顶部摘要区。空态提示仍放在摘要区下方的内容区域中。

这样可以保证：

1. 用户仍能确认自己当前看的是什么产品
2. 空态与产品上下文不脱节
3. 弹窗在“有数据 / 无数据”两种状态下结构稳定

## 9. 交互保持策略

本轮采用“结构重组、交互保守”的迁移策略。

以下行为必须保持不变：

1. 列表页仍只提供产品名称搜索和分类筛选
2. 列表页仍固定查询启用中的且已有生效版本的产品
3. 导出动作仍在页面顶部，不下沉到弹窗内
4. 列表行操作仍然只保留 `查看参数`
5. 参数查看弹窗仍保持只读
6. Link 类型参数仍可在弹窗内直接打开
7. `jump command` 仍然可以直达查看弹窗
8. 无生效版本时仍走当前提示弹窗口径

## 10. 数据流与状态边界

本轮不新增页面级 controller，状态仍保留在主页面内部，但收敛装配方式。

建议状态边界如下：

### 10.1 页面级状态

1. 查询列表数据
2. 查询条件
3. 页面提示消息
4. `jump command` 已处理序列号

### 10.2 弹窗数据输入

参数查看弹窗只接收：

1. 产品基础信息
2. 参数查询返回结果
3. Link 点击回调

摘要组件只接收：

1. 产品名
2. 版本标签
3. 参数总数
4. 可选口径提示

### 10.3 动作入口

主页面继续统一处理：

1. `_loadProducts()`
2. `_showParametersDialog()`
3. `_openLink()`
4. `_exportParameters()`
5. `_handleJumpCommand()`

组件只负责触发，不负责决定动作实现。

## 11. 测试设计

### 11.1 新增页面级 widget test

建议新增：

1. `frontend/test/widgets/product_parameter_query_page_test.dart`

至少覆盖：

1. 查询页统一骨架已接入
2. 页头、筛选区、反馈区、列表区已拆出
3. 参数查看弹窗已切到独立展示层
4. 顶部摘要区展示产品名、版本标签和参数总数
5. 空态时摘要区仍保留

### 11.2 保留并扩展既有回归

继续依赖：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

必须继续覆盖：

1. 参数查询首屏走只读查询接口
2. 分页大小不超过 200
3. 固定 `active + hasEffectiveVersion=true`
4. Link 打开链路
5. 导出链路
6. `jump command` 直达查看弹窗

如有必要，可补一条断言：

1. 弹窗顶部摘要区在 `jump command` 打开后同样正确展示

### 11.3 Integration 观察点

本页复杂度较低，可不强制新增独立 integration。

若实施阶段希望补主路径观察点，建议新增：

1. `frontend/integration_test/product_parameter_query_flow_test.dart`

最小观察路径为：

1. 进入参数查询页
2. 打开参数查看弹窗
3. 校验顶部摘要区存在

## 12. 实施顺序建议

建议按以下顺序实施：

1. 先拆查询页头、筛选区、反馈区和列表区
2. 再把主页面列表态接入统一骨架
3. 再拆参数查看弹窗壳组件
4. 再补 `ProductParameterSummaryHeader`
5. 最后补页面级测试、回归和 `evidence`

不建议一开始先抽 Link 单元格组件或继续泛化摘要区，因为这会把“轻量页面迁移”过早推向通用化重构。

## 13. 风险与控制方式

### 风险 1：为了复用而过度抽象

控制方式：

1. 摘要组件只服务产品参数域
2. 不上升到 `core/ui`
3. 不提前支持当前页面未用到的复杂变体

### 风险 2：弹窗拆分后误伤 Link 打开链路

控制方式：

1. Link 打开动作继续由主页面提供回调
2. 弹窗和摘要组件只负责展示
3. 保留既有回归测试

### 风险 3：空态和有数据态结构不一致

控制方式：

1. 空态时仍展示顶部摘要区
2. 仅在摘要区下方切换表格 / 空态内容

### 风险 4：轻页面迁移收益不足

控制方式：

1. 不只做内联微调
2. 必须把查询页顶层和弹窗展示层一起拆出
3. 补独立页面级 widget test，形成可复用样板

## 14. 预期结果

本轮完成后，`ProductParameterQueryPage` 应从“主页面直接承载查询列表和参数查看弹窗”升级为“统一查询页骨架 + 参数查看弹窗展示层拆分 + 轻量可复用摘要区”的结构。

预期收益：

1. 主文件显著变薄
2. 产品模块第二波迁移完整收口
3. 轻量查询页的第二波迁移边界得到验证
4. 参数查看弹窗的展示层和摘要层形成可复用样板
5. 查询、导出、Link 打开和 `jump command` 语义保持稳定

## 15. 迁移说明

- 无迁移，直接替换
