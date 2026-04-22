# 生产模块完整收口设计

- 日期：2026-04-22
- 状态：已批准
- 负责人：Trae AI

## 1. 背景与目标

### 1.1 背景

生产模块是 MES 系统的核心模块之一，包含 9 个页签。当前 `ProductionPage` 使用旧式 `TabBar + TabBarView` 结构，未统一页头和页面模式。

### 1.2 目标

按三层分批方式完成生产模块完整收口：
- 统一总页壳层
- 主业务页签使用 `mes_crud_page_scaffold`
- 抽取模块级 widget
- 覆盖模块级 integration 测试

## 2. 范围

### 2.1 纳入范围

| 页签 | 当前状态 | 收口批次 |
|-----|---------|---------|
| 订单管理 | 未统一 | 第1批 |
| 订单查询 | 未统一 | 第1批 |
| 代班记录 | 未统一 | 第3批 |
| 工序统计/今日实时产量/人员统计 | 共用 `ProductionDataPage` | 第2批 |
| 报废统计 | 未统一 | 第2批 |
| 维修订单 | 未统一 | 第3批 |
| 并行实例追踪 | 未统一 | 第2批 |

### 2.2 排除范围

- `quality_repair_orders`（属于质量模块，两个入口各自保留）
- 后端 API 修改

## 3. 分批实施

### 第1批：总页壳层 + 主业务页签

#### 3.1.1 新增文件

| 文件 | 说明 |
|-----|------|
| `lib/features/production/presentation/widgets/production_page_shell.dart` | 总页壳层 |
| `lib/features/production/presentation/widgets/production_page_header.dart` | 统一页头 |
| `lib/features/production/presentation/widgets/production_order_status_chip.dart` | 订单状态 Chip |

#### 3.1.2 修改文件

| 文件 | 改造内容 |
|-----|---------|
| `lib/features/production/presentation/production_page.dart` | 使用 `ProductionPageShell` |
| `lib/features/production/presentation/production_order_management_page.dart` | 使用 `mes_crud_page_scaffold` |
| `lib/features/production/presentation/production_order_query_page.dart` | 使用 `mes_crud_page_scaffold` |

#### 3.1.3 验收标准

- [ ] `ProductionPageShell` 存在且被 `ProductionPage` 使用
- [ ] `ProductionPageHeader` 存在
- [ ] 订单管理页使用 `MesCrudPageScaffold` + `CrudListTableSection`
- [ ] 订单查询页使用 `MesCrudPageScaffold` + `CrudListTableSection`
- [ ] 订单状态使用 `ProductionOrderStatusChip`
- [ ] 单元测试通过
- [ ] 回归测试通过

---

### 第2批：数据统计类页签

#### 3.2.1 新增文件

| 文件 | 说明 |
|-----|------|
| `lib/features/production/presentation/widgets/production_data_section_chip.dart` | 数据统计 Section 切换 Chip |

#### 3.2.2 修改文件

| 文件 | 改造内容 |
|-----|---------|
| `lib/features/production/presentation/production_data_page.dart` | 使用 `mes_crud_page_scaffold`，抽取 Section Chip |
| `lib/features/production/presentation/production_scrap_statistics_page.dart` | 使用 `mes_crud_page_scaffold` |
| `lib/features/production/presentation/production_pipeline_instances_page.dart` | 使用 `mes_crud_page_scaffold` |

#### 3.2.3 验收标准

- [ ] `ProductionDataSectionChip` 存在且被 `ProductionDataPage` 使用
- [ ] 数据统计页三个 section 可切换
- [ ] 报废统计页使用统一组件
- [ ] 并行实例追踪页使用统一组件
- [ ] 单元测试通过
- [ ] 回归测试通过

---

### 第3批：辅助类页签

#### 3.3.1 修改文件

| 文件 | 改造内容 |
|-----|---------|
| `lib/features/production/presentation/production_assist_records_page.dart` | 使用 `mes_crud_page_scaffold` |
| `lib/features/production/presentation/production_repair_orders_page.dart` | 使用 `mes_crud_page_scaffold` |

#### 3.3.2 验收标准

- [ ] 代班记录页使用统一组件
- [ ] 维修订单页使用统一组件
- [ ] 模块级 integration 测试覆盖
- [ ] 模块级回归测试通过

---

## 4. 跨批次目标状态

### 4.1 架构模式

| 维度 | 目标 |
|-----|------|
| 总页壳层 | 使用 `ProductionPageShell` |
| 子页统一页头 | 使用 `ProductionPageHeader` |
| 主业务页 | 使用 `mes_crud_page_scaffold` |
| 表格样式 | 使用 `CrudListTableSection` + `UnifiedListTableHeaderStyle` |
| 分页 | 使用 `SimplePaginationBar` |
| 状态展示 | 抽取 `*StatusChip` widget |

### 4.2 模块级 widget

| Widget | 用途 |
|-------|------|
| `production_page_shell.dart` | 总页壳层 |
| `production_page_header.dart` | 统一页头 |
| `production_order_status_chip.dart` | 订单状态 |
| `production_data_section_chip.dart` | 数据统计 Section 切换 |
| `production_module_feedback_banner.dart` | Feedback Banner |

### 4.3 测试覆盖

| 测试文件 | 覆盖内容 |
|---------|---------|
| `production_module_full_convergence_test.dart` | 模块级完整回归 |
| `production_page_test.dart` | 总页壳层测试 |
| `production_order_management_page_test.dart` | 订单管理页测试 |
| `production_order_query_page_test.dart` | 订单查询页测试 |

## 5. 风险与约束

### 5.1 风险

- `ProductionOrderManagementPage` 代码量较大（约 850 行），重构需谨慎
- `ProductionOrderQueryPage` 可能有复杂筛选逻辑

### 5.2 约束

- 不修改后端 API
- 保持权限控制不变
- 不引入新的路由

## 6. 迁移说明

- 无数据迁移
- 直接替换旧组件
- 旧组件在验证通过后删除

## 7. 验收检查清单

### 第1批完成检查

- [ ] `ProductionPageShell` 已创建
- [ ] `ProductionPageHeader` 已创建
- [ ] `ProductionOrderStatusChip` 已创建
- [ ] `ProductionPage` 使用新壳层
- [ ] 订单管理页使用 `mes_crud_page_scaffold`
- [ ] 订单查询页使用 `mes_crud_page_scaffold`
- [ ] 单元测试通过
- [ ] Integration 测试通过

### 第2批完成检查

- [ ] `ProductionDataSectionChip` 已创建
- [ ] 数据统计页使用新 Chip
- [ ] 报废统计页使用统一组件
- [ ] 并行实例追踪页使用统一组件
- [ ] 单元测试通过
- [ ] Integration 测试通过

### 第3批完成检查

- [ ] 代班记录页使用统一组件
- [ ] 维修订单页使用统一组件
- [ ] 模块级 integration 测试覆盖
- [ ] 模块级回归测试通过
- [ ] 旧组件已清理
