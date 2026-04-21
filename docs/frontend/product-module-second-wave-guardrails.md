# 产品模块第二波迁移治理说明

## 1. 固定页面模式

### 1.1 ProductVersionManagementPage
- 保持“产品选择面板 + 版本工作区”结构
- 左侧继续使用 `ProductSelectorPanel`
- 顶部继续使用 `ProductVersionPageHeader`
- 工作区继续保留 `ProductVersionFeedbackBanner`、`ProductVersionToolbar`、`ProductVersionTableSection`

### 1.2 ProductManagementPage
- 保持 `MesCrudPageScaffold`
- 主页面继续保留 `ProductManagementPageHeader`、`ProductManagementFilterSection`、`ProductManagementFeedbackBanner`、`ProductManagementTableSection`
- 产品详情继续使用 `ProductDetailDrawer`
- 版本管理继续使用 `ProductVersionDialog`

### 1.3 ProductParameterManagementPage
- 列表态继续保持 `MesCrudPageScaffold`
- 列表态继续保留 `ProductParameterManagementPageHeader`、`ProductParameterManagementFilterSection`、`ProductParameterManagementFeedbackBanner`、`ProductParameterVersionTableSection`
- 编辑态继续保留 `ProductParameterEditorHeader`、`ProductParameterEditorToolbar`、`ProductParameterEditorTable`、`ProductParameterEditorFooter`
- 历史链路继续保留 `ProductParameterHistoryDialog` 和 `ProductParameterHistorySnapshotDialog`

### 1.4 ProductParameterQueryPage
- 列表态继续保持 `MesCrudPageScaffold`
- 列表态继续保留 `ProductParameterQueryPageHeader`、`ProductParameterQueryFilterSection`、`ProductParameterQueryFeedbackBanner`、`ProductParameterQueryTableSection`
- 参数查看继续使用 `ProductParameterQueryDialog`
- 弹窗顶部继续保留 `ProductParameterSummaryHeader`

## 2. 禁止回退清单

1. 不允许把 `MesCrudPageScaffold` 改回手工 `Padding + Column + Row` 拼装。
2. 不允许把独立的详情侧栏、版本弹窗、历史弹窗、查询弹窗重新塞回主页面大文件。
3. 不允许把 `ProductParameterQueryPage` 的查询回退到产品管理列表接口。
4. 不允许把 `ProductParameterManagementPage` 的版本绑定、历史绑定和保存绑定改回旧参数接口兜底。
5. 不允许把产品模块第二波迁移后的核心动作入口改散或移出既定工作区。

## 3. 后续改造 Checklist

1. 改产品页前先确认是否仍复用当前页面模式。
2. 改动后先检查稳定 `ValueKey` 和核心锚点是否仍存在。
3. 改动后必须运行：
   - `flutter test test/widgets/product_module_second_wave_guard_test.dart`
   - `flutter test test/widgets/product_module_issue_regression_test.dart`
4. 若改动涉及接口口径，先确认没有回退到旧接口。
