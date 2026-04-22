# Quality 模块高优先级页面迁移设计

## 1. 概述

**目标：** 将 Quality 模块的 2 个高优先级页面迁移到 `MesCrudPageScaffold`，实现页面布局统一化。

**涉及页面：**
- `quality_trend_page.dart` - 质量趋势页面
- `quality_scrap_statistics_page.dart` - 质量报废统计页面

**设计原则：**
- 复用现有 Header 组件
- 保持功能逻辑不变
- 优化页面结构，提高可维护性

---

## 2. MesCrudPageScaffold 结构说明

```dart
MesCrudPageScaffold({
  required this.header,     // 页面头部
  this.filters,             // 筛选器区域（可选）
  this.banner,              // 横幅区域（可选）
  required this.content,     // 主内容区域
  this.pagination,          // 分页区域（可选）
  this.padding,             // 内边距（可选，默认 16）
})
```

---

## 3. QualityTrendPage 迁移设计

### 3.1 当前结构分析

**文件位置：** `frontend/lib/features/quality/presentation/quality_trend_page.dart`

**现有组件：**
- `QualityTrendPageHeader` - 页面头部（已存在）
- 日期选择器、输入框、筛选条件 - 内联实现
- 汇总卡片、图表、维度表格 - 内联实现

### 3.2 目标结构

```dart
MesCrudPageScaffold(
  header: QualityTrendPageHeader(...),
  filters: _buildFilterBar(theme),  // 提取为筛选器
  banner: _buildSummaryCards(context), // 汇总卡片作为 banner
  content: _buildMainContent(theme),   // 图表+维度+趋势表
)
```

### 3.3 迁移步骤

1. **提取 FilterBar Widget**
   - 将现有的 Wrap(filters) 提取为 `_buildFilterBar()` 方法
   - 返回一个 Row 或 Wrap 包含所有筛选控件

2. **重构 Banner 区域**
   - 将 `_buildSummaryCards()` 作为 `banner` 参数传入
   - 保持 4 张汇总卡片的布局

3. **重构 Content 区域**
   - 将图表、维度观察、趋势表格放入 `content`
   - 保持 ListView 滚动结构

4. **调整 Padding**
   - 使用默认 padding (16) 或根据需要调整

---

## 4. QualityScrapStatisticsPage 迁移设计

### 4.1 当前结构分析

**文件位置：** `frontend/lib/features/quality/presentation/quality_scrap_statistics_page.dart`

**现有结构：**
```dart
Column(
  children: [
    Padding(16,16,16,0) → QualityScrapStatisticsPageHeader(),
    Expanded(ProductionScrapStatisticsPage(...)),
  ],
)
```

### 4.2 目标结构

```dart
MesCrudPageScaffold(
  header: QualityScrapStatisticsPageHeader(),
  content: ProductionScrapStatisticsPage(...),
)
```

### 4.3 迁移步骤

1. **移除冗余 Padding**
   - `MesCrudPageScaffold` 提供默认 padding

2. **移除 Column 包装**
   - 直接返回 `MesCrudPageScaffold`

3. **传入 Header**
   - `header: const QualityScrapStatisticsPageHeader()`

4. **传入 Content**
   - `content: ProductionScrapStatisticsPage(...)`

---

## 5. 组件复用清单

| 组件 | 状态 | 说明 |
|------|------|------|
| `QualityTrendPageHeader` | ✅ 复用 | 无需修改 |
| `QualityScrapStatisticsPageHeader` | ✅ 复用 | 无需修改 |
| `MesCrudPageScaffold` | ✅ 复用 | 核心布局组件 |

---

## 6. 测试计划

### 6.1 QualityTrendPage 测试
- 验证 `MesCrudPageScaffold` 渲染
- 验证 header 包含刷新和导出按钮
- 验证 filters 区域包含日期选择器和输入框
- 验证 banner 区域显示 4 张汇总卡片
- 验证 content 区域包含图表和表格

### 6.2 QualityScrapStatisticsPage 测试
- 验证 `MesCrudPageScaffold` 渲染
- 验证 header 显示标题
- 验证 content 正确委托给 ProductionScrapStatisticsPage

---

## 7. 验收标准

- [ ] `QualityTrendPage` 使用 `MesCrudPageScaffold` 布局
- [ ] `QualityScrapStatisticsPage` 使用 `MesCrudPageScaffold` 布局
- [ ] 页面功能与迁移前保持一致
- [ ] 页面样式与其他已迁移页面保持统一
- [ ] 相关测试通过

---

## 8. 后续计划

完成高优先级页面后，继续迁移中优先级页面：
- `craft_kanban_page.dart` - 工艺看板页面
- `craft_reference_analysis_page.dart` - 工艺参照分析页面
- `production_data_page.dart` - 生产数据页面
- `production_pipeline_instances_page.dart` - 生产流程实例页面
