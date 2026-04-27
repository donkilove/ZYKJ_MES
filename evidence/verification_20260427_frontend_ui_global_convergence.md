# 前端全站 UI 一致性与布局合理性收敛验证日志

## 起止时间
- 任务开始：2026-04-27
- 计划文件：docs/superpowers/plans/2026-04-27-frontend-ui-global-convergence-implementation.md
- 设计文件：docs/superpowers/specs/2026-04-27-frontend-ui-global-convergence-design.md

## 阶段 0：全站审计与基线映射

待补：审计输出、模板模块识别、剧本草案。

### 阶段 0 总结

- 审计表位置：`evidence/2026-04-27_前端全站UI差异审计表.md`
- 模板模块识别：用户模块（已半迁移，可作为剧本验证对象）
- 关键发现：
  - 全站约 25+ 个 page 仍引用 `SimplePaginationBar`（覆盖面最广的旧件）
  - 18 处页面/wrapper 仍依赖 `CrudPageHeader`，且其中 2 处 wrapper（包括用户管理页面头）已对外暴露 MesPageHeader 接口但内部仍对接旧件
  - 约 20 个 CRUD 型页面手写 `Padding + Column` 骨架，未使用 `MesCrudPageScaffold`
  - 约 18 个页面手写筛选区，未包裹 `MesFilterBar`
  - 约 25+ 处 `showLockedFormDialog` 调用，主要集中在 equipment/production/user/craft/product
  - 约 35 处裸 `CircularProgressIndicator`，未封装为标准加载状态件
  - 约 12 处手写 `Text(error)` 代替 `MesInlineBanner`
  - 用户管理页本身存在历史遗留：`UserManagementPageHeader` 仍走 `CrudPageHeader`，分页用 `SimplePaginationBar`，多处 `showLockedFormDialog`
- 模块成熟度排序：message > product > shell/settings > user > craft > quality > production > equipment
- 后续顺序：
  1. 阶段 1：以用户管理页为基线收口（页头切 MesPageHeader、分页切 MesPaginationBar、浮层脱离 LockedFormDialog、状态件接入 MesEmptyState/MesErrorState/MesInlineBanner）
  2. 阶段 2：用户模块 7 个子页面整模收敛
  3. 阶段 3：剧本与基线文档落地，开放给后续阶段使用

## 阶段 1：用户管理页基线收口

待补。

### 阶段 1 总结

- 任务清单完成情况：
  - T1.1：`LegacyLegacyUserManagementPage` 已重命名为 `UserManagementPage`，6 个文件同步修正，commit `764ec08`。
  - T1.2：分页条由 `SimplePaginationBar` 切换到 `MesPaginationBar`，commit `02744ea`。
  - T1.3（路径 B）：`showLockedFormDialog` 从 `core/widgets/locked_form_dialog.dart` 迁移到 `core/ui/patterns/mes_locked_form_dialog.dart`，函数改名为 `showMesLockedFormDialog`，全站 28+ 处调用方同步收敛，commit `0bf2e20`。
    - 决策点：原计划要求"用 AlertDialog 替换 LockedFormDialog"会导致 `barrierDismissible:false` + `PopScope(canPop:false)` 表单保护行为丢失（用户填表中途误关闭丢数据），与用户确认后改为路径 B：保留行为，仅做命名与位置对齐。
  - T1.4：`UserManagementFeedbackBanner` 现状已基于 `UserModuleFeedbackBanner` → `MesInlineBanner`，链路完整，无需变更。
  - T1.5：用户管理页空态由 `CrudListTableSection` 内部已转发到 `MesEmptyState`，错误态由外层 `UserManagementFeedbackBanner` (`MesInlineBanner.error`) 表达——这是合理的"banner 不替换数据"设计；加载态仍保留 `CircularProgressIndicator`，记入阶段 4 剧本的"加载态对齐"项。
- 用户管理页 import 已完全脱离 `core/widgets/` 旧件依赖（仅 `UserDataTable` 内部仍间接依赖 `CrudListTableSection`/`UnifiedListTableHeaderStyle`，二者本身已转发到新件，留待阶段 4 推进）。
- 验证：
  - `flutter analyze lib`：0 新增错误（仅 1 个无关 unused_field 警告，位于 `production/first_article_scan_review_mobile_page.dart`）
  - `flutter test test/widgets/user_management_page_test.dart`：60/60 通过
  - `flutter test test/widgets/main_shell_page_test.dart`：26/26 通过
  - `flutter test test/widgets/message_center_page_test.dart`：22/22 通过
  - `flutter test test/widgets/production_page_test.dart`：8/8 通过
- 用户管理页现具备"可被全站映射的基线资格"，进入阶段 2 整模收敛。

## 阶段 2：用户模块整模收敛

待补。

## 阶段 3：模块改造剧本与基线文档

待补。

## 后续阶段（窗口外）

待补。
