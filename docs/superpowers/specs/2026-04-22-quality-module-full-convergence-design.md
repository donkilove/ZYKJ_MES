# 质量模块完整收口设计

## 1. 背景

质量模块当前已经具备总页与多页签结构，`QualityPage` 下挂有 7 个页签：

1. `first_article_management`
2. `quality_data_query`
3. `quality_scrap_statistics`
4. `quality_repair_orders`
5. `quality_trend`
6. `quality_defect_analysis`
7. `quality_supplier_management`

当前问题不是“页面不存在”，而是：

1. `QualityPage` 仍是旧式 `TabBar + TabBarView` 壳层
2. 页签之间可能仍存在不同代际的结构与验证口径
3. `quality_repair_orders` 挂在质量总页下，但代码位于 `production` 目录，维护边界容易模糊
4. 模块级验证尚未形成统一标准

因此这轮目标不是单页补丁，而是将质量模块推进到“总页壳层与全部页签都按统一口径被理解、被验证、被继续演进”的完整收口状态。

## 2. 当前现状

### 2.1 QualityPage 总页壳层仍是历史容器

`frontend/lib/features/quality/presentation/quality_page.dart` 当前仍直接以 `TabBar + TabBarView` 组织全部页签。它虽然可用，但本质上还只是一个功能容器，而不是稳定的模块总控壳层。

### 2.2 质量模块内部页签类型不同

当前至少存在三类页签：

1. 主业务页签
   - `first_article_management`
   - `quality_data_query`
   - `quality_scrap_statistics`
   - `quality_defect_analysis`
   - `quality_trend`
2. 支持 / 管理页签
   - `quality_supplier_management`
3. 跨域页签
   - `quality_repair_orders`

因此质量模块不能简单按“全部都是 CRUD 页”来统一。

### 2.3 跨域页签需要显式纳入质量模块口径

`quality_repair_orders` 的代码归属在 `production`，但只要它继续挂在 `QualityPage` 下，就必须按质量模块标准验收。这一轮要明确它是“质量总页下的跨域页签”，而不是灰区页面。

## 3. 总体路线

本轮采用：

1. 一个总 spec 覆盖整个质量模块完整收口
2. 后续实施拆成 3 批推进

不采用“一次实现到底”的原因：

1. 范围覆盖 1 个总页壳层和 7 个页签
2. 含有跨域页签
3. 当前工作流更适合“一个总方向 + 多个高内聚实现批次”

## 4. 目标

1. 将 `QualityPage` 推进为稳定的质量模块总控壳层。
2. 让 7 个页签全部进入统一口径。
3. 将 `quality_repair_orders` 明确视为“质量总页下的跨域页签”并纳入质量模块标准验收。
4. 让质量模块形成统一的验证与留痕闭环。

## 5. 非目标

1. 本轮不改后端接口契约。
2. 本轮不重构 `production` 模块中与 `quality_repair_orders` 无关的页面。
3. 本轮不把全部质量页强行做成同一种 CRUD 页面。
4. 本轮不把质量模块一次性压成单个实现批次。
5. 本轮不将其他模块一并纳入。

## 6. 完整收口后的目标结构状态

质量模块完整收口后，应达到以下状态：

### 6.1 总页壳层统一

`QualityPage` 不再只是“能切页签”的容器，而是稳定的质量模块总控壳层。它至少应做到：

1. 页签顺序、可见性、默认落点和跳转载荷处理都有明确口径
2. 7 个页签装配方式稳定
3. 后续新增或调整质量页签时，有明确壳层接入方式

### 6.2 主业务页进入统一口径

主业务页签应满足同一套判断标准：

1. 页面结构清晰
2. 反馈出口明确
3. 与总页壳层关系稳定
4. 后续可以继续按统一方式演进

### 6.3 跨目录页签按同一模块口径看待

`quality_repair_orders` 只要继续挂在 `QualityPage` 下，就必须满足和其他质量页签同等的模块口径，不能因目录不同而保留特殊过渡态。

### 6.4 模块级验证方式统一

完整收口后，质量模块应形成：

1. 总页壳层层面的稳定测试
2. 页签级回归
3. 至少一组质量模块主路径验证
4. 对应的 `evidence` 留痕闭环

## 7. 分层方式

### 7.1 总页壳层

`QualityPage` 单独作为一层，只负责：

1. 页签顺序与可见性
2. 默认页签与偏好页签切换
3. 路由载荷分发
4. 子页装配和壳层稳定性

它不应承担具体质量页签的业务规则判断。

### 7.2 主业务页签层

这一层包括：

1. `first_article_management`
2. `quality_data_query`
3. `quality_scrap_statistics`
4. `quality_defect_analysis`
5. `quality_trend`

这些页签都属于质量主业务域，应尽量按统一思路处理：

1. 页头
2. 筛选区
3. 反馈区
4. 主内容区 / 图表区 / 列表区
5. 页内动作入口

### 7.3 支持 / 跨域页签层

这一层包括：

1. `quality_repair_orders`
2. `quality_supplier_management`

其中 `quality_repair_orders` 明确视为“质量总页下的跨域页签”，后续实现与验证都按质量模块标准收口，但不扩散去改 `production` 模块其他内容。

## 8. 分批边界

### 第 1 批：总页壳层与主干业务页

覆盖：

1. `QualityPage`
2. `first_article_management`
3. `quality_data_query`

这一批解决：

1. `QualityPage` 是否能成为稳定总控壳层
2. 主干业务页是否进入统一口径

### 第 2 批：分析与统计页

覆盖：

1. `quality_scrap_statistics`
2. `quality_defect_analysis`
3. `quality_trend`

这一批解决：

1. 分析 / 统计型页面是否在结构、反馈和验证方式上与主干页统一
2. 模块内部是否仍存在明显代际差异

### 第 3 批：跨域与管理页

覆盖：

1. `quality_repair_orders`
2. `quality_supplier_management`

这一批解决：

1. 跨域页签是否在质量模块口径下稳定接入
2. 供应商管理等支持 / 管理页是否与质量总页形成统一闭环

## 9. 完成标准

以下条件全部满足，才算“质量模块完整收口”：

1. `QualityPage` 总页壳层完成收口
2. 7 个页签全部进入统一口径
3. `quality_repair_orders` 完成模块级归位
4. 形成总页壳层测试、页签级回归、模块级主路径验证和 `evidence` 闭环

## 10. 风险与控制方式

### 风险 1：范围滑成“质量模块全量重写”

控制方式：

1. 每一批只解决该批定义的问题
2. 不顺手重做不在本批目标里的页签

### 风险 2：跨域页签把边界搅乱

控制方式：

1. 在设计中明确 `quality_repair_orders` 是“质量总页下的跨域页签”
2. 实现时按质量模块口径验收
3. 不扩散去改 `production` 模块其他页面

### 风险 3：分析统计页被错误套成 CRUD 页

控制方式：

1. 对 `quality_scrap_statistics`、`quality_defect_analysis`、`quality_trend` 只要求“结构清晰、反馈明确、验证稳定”
2. 不强行套和列表管理页完全相同的页面骨架

## 11. 预期结果

本轮完成后，质量模块会从“总页能用、页签状态不一致”进入“总页壳层与全部页签都能按统一口径被维护”的状态。

也就是说：

1. `QualityPage` 变成稳定的总控壳层
2. 主业务页、分析统计页、支持 / 跨域页都完成模块级收口
3. 后续继续维护质量模块时，不再需要区分“这是历史页签”还是“这是已收口页签”

## 12. 迁移说明

- 无迁移，直接替换
