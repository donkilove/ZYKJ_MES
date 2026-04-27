# 前端 UI 基线说明

本文档记录 ZYKJ MES 前端的 UI 基线、视觉锚点与体系结构，用于指导新页面开发与存量页面收敛。

## 视觉基线

- **视觉锚点**：用户模块的用户管理页（`frontend/lib/features/user/presentation/user_management_page.dart`）
- **风格保持**：当前主题、品牌色、字体不变（种子色 `#006A67`、Material 3、Microsoft YaHei）
- **不引入**新设计系统或第三方 UI 库

## 体系四层

```
core/ui/foundation/    -- 设计 token（颜色/间距/圆角/字体层级）
core/ui/primitives/    -- 小颗粒基础件（Gap/Surface/InfoRow/StatusChip）
core/ui/patterns/      -- 页面级模式件（PageHeader/FilterBar/Toolbar 等）
features/<模块>/widgets/  -- 业务组装与表达
```

### `core/ui/foundation/`

设计 token 通过 `MesTokens.fromTheme(ThemeData)` 经 `ThemeExtension` 注入主题。

| 类别 | 类名 | 文件 |
|------|------|------|
| 聚合 | `MesTokens` | `mes_tokens.dart` |
| 颜色 | `MesColors`（12 个语义 token） | `mes_colors.dart` |
| 间距 | `MesSpacing`（xs=8 / sm=12 / md=16 / lg=20 / xl=24） | `mes_spacing.dart` |
| 圆角 | `MesRadius`（sm=10 / md=16 / lg=24） | `mes_radius.dart` |
| 字体层级 | `MesTypography`（pageTitle / sectionTitle / cardTitle / body / bodyStrong / caption / metric） | `mes_typography.dart` |
| 主题入口 | `buildMesTheme()` | `mes_theme.dart` |

### `core/ui/primitives/`

| 件 | 用途 |
|----|------|
| `MesGap` | 统一空白 |
| `MesInfoRow` | 行级标签:值 |
| `MesStatusChip` | 状态标记 |
| `MesSurface` | 标准容器壳 |

### `core/ui/patterns/`

| 件 | 用途 |
|----|------|
| `MesPageHeader` | 页面头部（标题 + 副标题 + 动作） |
| `MesFilterBar` | 筛选条件区 |
| `MesToolbar` | 操作条（主操作 + 次级操作） |
| `MesSectionCard` | 内容卡 |
| `MesCrudPageScaffold` | CRUD 页面壳层 |
| `MesTableSectionHeader` | 表格区头 |
| `MesPaginationBar` | 分页条 |
| `MesEmptyState` | 空数据占位 |
| `MesErrorState` | 错误占位（带重试） |
| `MesInlineBanner` | 内嵌反馈横幅（info/warning/error/success） |
| `MesDetailPanel` | 侧栏详情面板 |
| `MesListDetailShell` | 列表+详情双栏 |
| `MesMetricCard` | 指标卡 |
| `MesLockedFormDialog` (`showMesLockedFormDialog<T>(...)`) | 锁定型表单弹窗（`barrierDismissible:false` + `PopScope(canPop:false)`） |

## 八维基线

新页面与存量收敛都遵循以下八个维度。详细标准、代码模板与禁止事项见 `docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`。

1. **页面头部**：`MesPageHeader`
2. **筛选区**：`MesFilterBar`
3. **操作条**：`MesToolbar`
4. **内容容器**：`MesSectionCard` 或 `MesCrudPageScaffold`
5. **列表与分页**：`CrudListTableSection` + `MesPaginationBar`
6. **状态反馈**：`MesInlineBanner` / `MesEmptyState` / `MesErrorState`
7. **浮层**：`showMesLockedFormDialog` / `AlertDialog` / `MesDetailPanel`
8. **响应式与密度**：`LayoutBuilder` 断点

## 旧件清退口径

`core/widgets/` 下尚有以下旧件，按"自然清退"策略处理：

| 旧件 | 现状 | 处理 |
|------|------|------|
| `simple_pagination_bar.dart` | 内部转发到 `MesPaginationBar` | **新引用禁止**；存量按模块逐步替换 |
| `crud_page_header.dart` | 内部转发到 `MesPageHeader` | **新引用禁止**；存量保留至 wrapper 自然清退 |
| `crud_list_table_section.dart` | 内部已用 `MesEmptyState` | 暂保留，待 patterns 覆盖完整 CRUD 表格能力后清退 |
| `unified_list_table_header_style.dart` | 表头样式 helper | 与 `crud_list_table_section.dart` 同节奏清退 |
| `adaptive_table_container.dart` | 自适应表格容器 | 同上 |
| `locked_form_dialog.dart` | **已删除**，迁移到 `core/ui/patterns/mes_locked_form_dialog.dart` | 完成 |

## 例外与保留差异

业务上确实需要的布局差异，必须在改造剧本的"保留差异"小节中记录原因。本文档维护以下已知例外：

- **登录页 / 注册页 / 强制改密页**：自定义全屏布局，不适用 `MesPageHeader`/`MesCrudPageScaffold`
- **plugin_host_page**：自定义 `Row(Sidebar + Workspace)` 双栏，不适用 CRUD 模式
- **first_article_scan_review_mobile_page**：独立 `MaterialApp` 入口（移动端独立子应用），不适用 MES 标准外壳
- **shell.home_page**：仪表盘类布局，使用 `MesSectionCard` 但不强求与 CRUD 页同构
- **shell.main_shell_page**：应用外壳，使用 `MainShellScaffold`

## 维护原则

1. **不引入新设计体系**——所有新视觉需求先看是否能用现有 token + patterns 表达
2. **不为未来需求提前抽象**——模式至少出现 3 次，再上升至 patterns
3. **新页面直接基于 patterns**——不要再用 `core/widgets/` 旧件
4. **加载态对齐推迟**——本轮不强制统一裸 `CircularProgressIndicator`，等 patterns 提供 `MesLoadingState` 后全站对齐
5. **错误态优先 banner**——错误能用 `MesInlineBanner` 表达就不要替换整个内容区为 `MesErrorState`，避免丢失上次成功加载的数据

## 相关文档

- 设计文档：`docs/superpowers/specs/2026-04-27-frontend-ui-global-convergence-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-27-frontend-ui-global-convergence-implementation.md`
- 改造剧本：`docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`
- 全站差异审计表：`evidence/2026-04-27_前端全站UI差异审计表.md`
- 验证日志：`evidence/verification_20260427_frontend_ui_global_convergence.md`
- 前端基础件体系（前置）：`docs/superpowers/specs/2026-04-20-frontend-ui-foundation-design.md`
