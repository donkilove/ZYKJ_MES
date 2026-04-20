# 产品版本管理页第二波迁移设计

## 1. 背景

前端 UI 基础件体系第一轮已经完成，当前仓库已经具备 `foundation / primitives / patterns` 三层能力，并且设置页、首页、消息中心已经完成第一批试点迁移。

用户模块第二波迁移也已经完成，验证了 `MesCrudPageScaffold`、共享反馈区、共享状态件和 CRUD 区块拆分在中等复杂度业务页上的可行性。这意味着当前前端已经不再缺“基础样式能力”，下一步更适合继续验证“高一层页面骨架”是否可以在真实业务页中稳定复用。

`frontend/lib/features/product/presentation/product_version_management_page.dart` 正好处于这个阶段最合适的复杂度区间：它不是最简单的 CRUD 页，也还没有进入工艺配置类超大页面的复杂度，但具备明显的“主列表 + 右侧工作区”结构，适合作为第二波页面迁移的样板页。

## 2. 当前现状

### 2.1 页面是典型的主从联动结构

当前页面由两大区域组成：

1. 左侧产品列表区
2. 右侧版本工作区

左侧负责搜索产品、分页浏览、选择产品；右侧负责版本工具栏、状态提示、版本表格和版本动作入口。这种结构已经超出普通 CRUD 页的单表格模式，更接近“主对象选择 + 从对象管理”的工作台页。

### 2.2 页面主文件承担了过多展示职责

`product_version_management_page.dart` 当前同时承担：

1. 产品列表渲染
2. 版本区工具栏渲染
3. 版本状态提示渲染
4. 版本表格渲染
5. 状态色与提示卡局部样式
6. 页面整体双栏布局拼装

这使得主文件既负责业务动作，又负责页面结构和局部视觉细节，后续继续统一 UI 体系时会越来越难维护。

### 2.3 当前页面仍使用旧式布局与局部视觉语义

当前顶层仍是 `Padding + Card + Row` 的手工拼装形式，状态展示也仍大量依赖本地 `Color` 常量、`Chip` 和局部 `Card` 提示，没有完全接入 `core/ui` 第二阶段模式件。

### 2.4 已有测试基础较好

当前已经存在较强的产品模块回归测试，尤其是：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

其中已经覆盖了：

1. 顶部操作入口显隐
2. 复制版本链路
3. 生效 / 停用 / 删除链路
4. 备注编辑
5. 参数导出
6. “无生效版本”提示

这为本轮迁移提供了较稳的行为兜底。

## 3. 已确认路线

本轮采用路线 B：主从骨架迁移。

三种候选路线的判断如下：

### 路线 A：最小样式迁移

仅把页头、卡片、状态色切换到 `core/ui`。

优点：

1. 风险最低
2. 改动边界小

缺点：

1. 无法沉淀新的高阶骨架
2. 主文件结构依然偏重

### 路线 B：主从骨架迁移

新增 `MesListDetailShell`，把页面正式收敛为：

1. 页头
2. 左侧产品选择区
3. 右侧版本工作区
4. 页内反馈区

优点：

1. 能顺势把 `core/ui` 从 CRUD 骨架推进到主从页骨架
2. 最符合该页天然结构
3. 仍然把本轮范围控制在展示层和页面装配层

缺点：

1. 工作量中等
2. 需要同步补页面级 widget test

### 路线 C：连同状态编排一起深拆

除了页面展示迁移，还同时把状态和动作继续下沉到 controller / coordinator。

优点：

1. 长期结构最干净

缺点：

1. 会把本轮从“页面迁移”扩大成“模块重构”
2. 不适合作为当前阶段的稳妥样板页

### 最终选择

本轮明确采用路线 B，不采用路线 A 和路线 C。

## 4. 目标

1. 将产品版本管理页从旧式双栏手工拼装，迁移为“统一页头 + 主从骨架 + 页面部件装配”的结构。
2. 在 `core/ui/patterns` 中新增可复用的 `MesListDetailShell`，为后续类似页面提供模板。
3. 把产品选择区、版本工具区、反馈区、版本表格区拆成稳定部件，降低主页面复杂度。
4. 统一状态展示、页内反馈和区块布局语言，使其与设置页、首页、消息中心、用户模块第二波迁移后的页面处于同一体系。
5. 在不改变现有业务动作语义的前提下，补齐页面级测试和 integration 观察点。

## 5. 非目标

1. 本轮不改后端接口契约。
2. 本轮不重写版本新建、复制、生效、停用、删除、备注编辑、参数导出等业务逻辑。
3. 本轮不把详情弹窗改造成右侧常驻详情面板。
4. 本轮不联动重构 `ProductManagementPage`、`ProductParameterManagementPage`、`ProductParameterQueryPage`。
5. 本轮不继续下沉 controller / coordinator。
6. 本轮不追求移动端精细化适配，只要求窄宽度退化后结构不崩。

## 6. 页面总体设计

### 6.1 顶层结构

页面顶层统一为：

1. `ProductVersionPageHeader`
2. `ProductVersionFeedbackBanner`（可选）
3. `MesListDetailShell`

其中：

1. 页头负责标题和刷新动作
2. 反馈区负责页面级提示
3. 主从骨架负责左侧产品选择区与右侧版本工作区的组织

### 6.2 左侧产品选择区

左侧区域负责：

1. 产品搜索
2. 产品列表
3. 产品分页
4. 当前选中产品高亮
5. 产品停用状态提示

该区域不负责版本业务动作。

### 6.3 右侧版本工作区

右侧区域负责：

1. 当前产品标题
2. 顶部版本工具栏
3. “最近一次生效结果”提示
4. “当前无生效版本”提示
5. 版本表格
6. 行级版本操作入口

右侧区域不负责产品选择逻辑。

### 6.4 页面主文件职责

`product_version_management_page.dart` 保留以下职责：

1. 页面状态
2. 数据加载
3. `jump command` 处理
4. 版本动作入口
5. 弹窗调用
6. 页面部件装配

主页面不再直接承担大段布局细节和局部样式判断。

## 7. 新增高阶骨架：MesListDetailShell

### 7.1 定位

`MesListDetailShell` 是本轮最重要的新模式件，用于统一“左侧列表 / 右侧工作区”的主从页结构。

### 7.2 职责

它只负责：

1. `header`
2. `sidebar`
3. `content`
4. 可选 `banner`
5. 左右区宽度策略
6. 窄宽度退化方式

它不负责：

1. 业务数据
2. 具体产品 / 版本语义
3. 版本动作逻辑

### 7.3 第一版边界

第一版只需要支持当前页和未来类似页面的核心需求，不应扩成“万能工作台骨架”。因此不引入复杂业务插槽，也不在第一版里处理多级侧栏或内置操作栏。

## 8. 页面组件拆分

建议新增以下页面组件：

1. `frontend/lib/features/product/presentation/widgets/product_version_page_header.dart`
2. `frontend/lib/features/product/presentation/widgets/product_selector_panel.dart`
3. `frontend/lib/features/product/presentation/widgets/product_version_feedback_banner.dart`
4. `frontend/lib/features/product/presentation/widgets/product_version_toolbar.dart`
5. `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`

### 8.1 ProductVersionPageHeader

职责：

1. 展示页面标题
2. 提供刷新入口

### 8.2 ProductSelectorPanel

职责：

1. 产品搜索框
2. 产品列表
3. 产品分页
4. 当前选中产品态

### 8.3 ProductVersionFeedbackBanner

职责：

1. 页面级错误提示
2. 当前无生效版本提示
3. 最近一次生效结果提示

### 8.4 ProductVersionToolbar

职责：

1. 新建版本
2. 复制版本
3. 编辑版本说明
4. 导出参数
5. 立即生效
6. 刷新版本列表

### 8.5 ProductVersionTableSection

职责：

1. 版本表格
2. 版本状态展示
3. 行级菜单
4. 选中版本态

### 8.6 状态展示件

若版本状态语义可以直接复用现有 `MesStatusChip`，则不额外新增状态件；若版本状态语义存在明显差异，则只允许新增薄包装，不新增新的基础视觉语言。

## 9. 交互保持策略

本轮采用“结构重组、交互保守”的迁移策略。

以下行为必须保持不变：

1. 左侧先选产品，右侧再加载该产品版本区
2. `jump command` 仍能定位到目标产品
3. 顶部操作入口继续保留：
   - `新建版本`
   - `复制版本`
   - `编辑版本说明`
   - `导出参数`
   - `立即生效`
4. 行级菜单继续保留：
   - `查看详情`
   - `立即生效`
   - `复制版本`
   - `编辑版本说明`
   - `维护参数 / 查看参数`
   - `导出版本参数`
   - `停用版本`
   - `删除版本`
5. 详情仍保持弹窗，不改为常驻详情面板
6. 现有弹窗语义和成功 / 失败动作结果保持不变

## 10. 响应式布局策略

### 10.1 桌面宽度

保持左右双栏布局：

1. 左侧产品选择区为固定较窄宽度
2. 右侧版本工作区占剩余空间

### 10.2 中等宽度

仍保留双栏，但允许：

1. 左栏适度收缩
2. 右侧工具栏换行

### 10.3 窄宽度

`MesListDetailShell` 退化为上下结构：

1. 先展示产品选择区
2. 再展示版本工作区

当前阶段只要求窄宽度不崩，不要求移动端做精细化重绘。

## 11. 数据流与状态边界

本轮不新增页面级 controller，状态仍保留在主页面内部，但收敛装配方式。

建议状态边界如下：

### 11.1 页面级状态

1. 产品列表数据与分页状态
2. 当前选中产品
3. 版本列表数据
4. 当前选中版本
5. 加载状态
6. 页面反馈消息

### 11.2 页面部件输入

各页面部件只接收展示所需最小数据，不直接访问服务层。

### 11.3 动作入口

主页面继续统一处理：

1. `_createVersion()`
2. `_copyVersion()`
3. `_activateVersion()`
4. `_disableVersion()`
5. `_deleteVersion()`
6. `_editVersionNote()`
7. `_exportVersionParams()`
8. `_navigateToEditParams()`

组件只负责触发，不负责决定动作实现。

## 12. 测试设计

### 12.1 新增页面级 widget test

建议新增：

1. `frontend/test/widgets/product_version_management_page_test.dart`

至少覆盖：

1. `MesListDetailShell` 已接入
2. 左侧产品选择区已拆出
3. 右侧版本工作区已拆出
4. 顶部版本工具栏已拆出
5. 页面反馈区已接入

### 12.2 保留并扩展既有回归

继续依赖：

1. `frontend/test/widgets/product_module_issue_regression_test.dart`

必须继续覆盖：

1. 复制版本
2. 生效版本
3. 停用版本
4. 删除版本
5. 编辑备注
6. 导出参数
7. “无生效版本”提示
8. 顶部操作入口显隐

### 12.3 Integration 观察点

建议新增：

1. `frontend/integration_test/product_version_flow_test.dart`

至少观察以下主路径：

1. 进入版本管理页
2. 选择产品
3. 看到右侧版本工作区
4. 看到顶部操作入口

## 13. 实施顺序建议

建议按以下顺序实施：

1. 先新增 `MesListDetailShell` 及其独立 widget test
2. 再新增页面部件
3. 再迁移 `product_version_management_page.dart`
4. 最后补页面级测试、integration 和 `evidence`

不建议一开始直接改完整页面，以免把“骨架抽象验证”和“页面迁移”耦合在一起，导致定位风险困难。

## 14. 风险与控制方式

### 风险 1：迁移范围失控

控制方式：

1. 只迁展示层和页面装配层
2. 不联动重构其他产品模块页面
3. 不改后端契约

### 风险 2：测试面过大但缺少聚焦

控制方式：

1. 新增独立页面级 widget test
2. 继续保留产品模块大回归
3. 用 integration 只验证主路径，不把所有业务链路都塞进 integration

### 风险 3：MesListDetailShell 抽象过头

控制方式：

1. 第一版只支持主从布局核心插槽
2. 不引入过多业务插槽
3. 先以该页为唯一落点验证，再考虑推广

## 15. 预期结果

本轮完成后，产品版本管理页应从“大页面直接手工拼装”升级为“统一页头 + 主从骨架 + 页面部件装配”的结构。

预期收益：

1. 页面主文件显著变薄
2. `core/ui` 新增一层可复用主从页骨架
3. 产品模块后续类似页面迁移有了直接模板
4. 当前交互语义保持稳定，迁移风险可控

## 16. 迁移说明

- 无迁移，直接替换
