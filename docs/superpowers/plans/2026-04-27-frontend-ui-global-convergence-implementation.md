# 前端全站 UI 一致性与布局合理性收敛实施计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 以用户管理页为视觉基线，把已建立的 `core/ui` 体系推广到前端全站可见界面；本计划在 9 小时窗口内交付审计、基线收口、用户模块整模收敛与可被复用的“模块改造剧本”，剩余模块按剧本分批推进。

**架构：** 采用四层结构（`core/ui/foundation` → `core/ui/primitives` → `core/ui/patterns` → 模块 widget），不新增设计体系；本轮通过“模板模块（用户）+ 改造剧本”降低后续模块的重复成本，剩余 11 个模块按剧本逐个收敛。

**技术栈：** Flutter + Dart、`MesPageHeader`、`MesFilterBar`、`MesToolbar`、`MesSectionCard`、`MesPaginationBar`、`MesEmptyState`、`MesErrorState`、`MesInlineBanner`、`MesDetailPanel`、`MesCrudPageScaffold`。

---

## 范围说明

设计文档位置：`docs/superpowers/specs/2026-04-27-frontend-ui-global-convergence-design.md`。

本计划交付物按窗口划分：

1. **9 小时窗口内**：阶段 0（审计）、阶段 1（基线收口）、阶段 2（用户模块全收敛）、阶段 3（输出改造剧本与文档）。
2. **窗口之后**：阶段 4（按改造剧本逐模块推进 product/equipment/production/quality/craft/message/misc/settings/shell/plugin_host/auth/time_sync 收敛）、阶段 5（重点页第二轮打磨）。

每个阶段都自带可见交付与 evidence 留痕，可独立验收。

---

## 阶段 0：全站审计与基线映射

### 任务 0.1：建立 evidence 任务日志

**文件：**
- 创建：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **创建文件**

```markdown
# 前端全站 UI 一致性与布局合理性收敛任务日志

## 起止时间
- 任务开始：2026-04-27
- 计划文件：docs/superpowers/plans/2026-04-27-frontend-ui-global-convergence-implementation.md
- 设计文件：docs/superpowers/specs/2026-04-27-frontend-ui-global-convergence-design.md

## 阶段 0：全站审计与基线映射

待补：审计输出、模板模块识别、剧本草案。

## 阶段 1：用户管理页基线收口

待补。

## 阶段 2：用户模块整模收敛

待补。

## 阶段 3：模块改造剧本与基线文档

待补。

## 后续阶段（窗口外）

待补。
```

- [ ] **Commit**

```bash
git add evidence/task_log_20260427_frontend_ui_global_convergence.md
git commit -m "新增前端全站 UI 收敛任务日志骨架"
```

---

### 任务 0.2：输出全站差异审计表

**文件：**
- 创建：`evidence/2026-04-27_前端全站UI差异审计表.md`

- [ ] **逐项采集差异**

按以下 8 个维度，遍历所有 page、dialog、panel 文件，记录"现状/与基线差距/处理策略"。处理策略限定为 `直接套壳`、`局部重排`、`结构重组` 三选一。

8 个维度：
1. 页面头部
2. 筛选区
3. 操作条
4. 内容容器
5. 列表与分页
6. 状态反馈（空/错/加载）
7. 浮层（dialog/drawer/panel）
8. 响应式与密度

输出表格格式：

```markdown
## auth 模块
| 文件 | 维度 | 现状 | 差距 | 策略 |
|------|------|------|------|------|
| ...  | ...  | ...  | ...  | ...  |
```

每个模块一节。审计目标不是改代码，是产出可被剧本引用的差距清单。

- [ ] **审计完成核对**

确认每个 feature 模块都有至少一条记录，每个 dialog/panel 都至少在"浮层"维度被覆盖。

- [ ] **Commit**

```bash
git add evidence/2026-04-27_前端全站UI差异审计表.md
git commit -m "新增前端全站 UI 差异审计表"
```

---

### 任务 0.3：把审计结论写回任务日志

**文件：**
- 修改：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **追加阶段 0 总结**

在“## 阶段 0”节下，追加：

```markdown
### 阶段 0 总结

- 审计表位置：evidence/2026-04-27_前端全站UI差异审计表.md
- 模板模块识别：用户模块（已部分迁移，可作为剧本验证对象）
- 关键发现：
  - 28 个 page 文件仍引用 core/widgets 旧件
  - 全部 page 文件均不直接使用 MesEmptyState/MesErrorState/MesInlineBanner，状态反馈集中在 sub-widget
  - 用户管理页存在 LegacyLegacyUserManagementPage 双重前缀命名
  - 用户管理页仍引用 locked_form_dialog 与 simple_pagination_bar 旧件
- 后续顺序：先收口用户管理页基线 → 再做用户模块整模收敛 → 输出剧本
```

- [ ] **Commit**

```bash
git add evidence/task_log_20260427_frontend_ui_global_convergence.md
git commit -m "回写阶段 0 审计结论到任务日志"
```

---

## 阶段 1：用户管理页基线收口

> 目的：让用户管理页本身具备"可被全站映射"的基线资格。这一阶段不大改业务，只做命名收口、旧件替换、状态反馈对齐。

### 任务 1.1：消除 LegacyLegacyUserManagementPage 双重前缀命名

**文件：**
- 修改：`frontend/lib/features/user/presentation/user_management_page.dart`
- 同步修改：所有引用 `LegacyLegacyUserManagementPage` 的文件（通过 grep 定位）

- [ ] **定位所有引用点**

执行：

```bash
cd frontend
grep -rn "LegacyLegacyUserManagementPage" lib test integration_test
```

预期：列出所有引用文件与行号。把结果记录到任务日志的“阶段 1”节。

- [ ] **重命名为 UserManagementPage**

把类名 `LegacyLegacyUserManagementPage` 改名为 `UserManagementPage`，包括：
- class 声明
- State 类（`_LegacyLegacyUserManagementPageState` → `_UserManagementPageState`）
- 所有 `createState()` 与 `extends State<...>` 处
- 所有 import 该类的调用方

**注意：** 仅做命名替换，不改任何业务行为。

- [ ] **运行分析**

```bash
cd frontend && flutter analyze lib test
```

预期：无新增错误。

- [ ] **运行用户管理页相关测试**

```bash
cd frontend
flutter test test/widgets --plain-name "用户" -r compact
```

预期：相关测试通过；若有按字符串匹配类名的旧断言失败，同步修正断言。

- [ ] **Commit**

```bash
git add -A
git commit -m "收口用户管理页类名双重 Legacy 前缀"
```

---

### 任务 1.2：替换 simple_pagination_bar 为 MesPaginationBar

**文件：**
- 修改：`frontend/lib/features/user/presentation/user_management_page.dart`
- 引用：`frontend/lib/core/ui/patterns/mes_pagination_bar.dart`

- [ ] **确认 MesPaginationBar 接口**

```bash
cd frontend
cat lib/core/ui/patterns/mes_pagination_bar.dart
```

记录其构造参数（页码、总数、每页数、回调），用于替换。

- [ ] **替换 import**

把 `import 'package:mes_client/core/widgets/simple_pagination_bar.dart';` 改为 `import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';`。

- [ ] **替换 widget 使用点**

在 `user_management_page.dart` 内查找 `SimplePaginationBar(` 的使用，替换为 `MesPaginationBar(`，参数按 MesPaginationBar 的实际签名对齐。

**注意：** 若 MesPaginationBar 缺失某项 SimplePaginationBar 必需的能力（如自定义统计信息），不要在 MesPaginationBar 内增加非通用参数；改为在分页条上方独立放置统计信息行。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "用户管理" -r compact
```

预期：无错误，相关测试通过。

- [ ] **Commit**

```bash
git add -A
git commit -m "用户管理页分页条替换为 MesPaginationBar"
```

---

### 任务 1.3：替换 locked_form_dialog 为统一浮层壳层

**文件：**
- 修改：`frontend/lib/features/user/presentation/user_management_page.dart`
- 引用：`frontend/lib/core/widgets/locked_form_dialog.dart`（暂保留旧件，因其他模块仍在使用）

- [ ] **判定替换范围**

```bash
cd frontend
grep -rn "locked_form_dialog\|LockedFormDialog" lib
```

如果用户管理页是唯一引用点，直接换；如果其他模块也在用，本任务**不删旧件**，仅在用户管理页内换为基于 `MesSectionCard + AlertDialog` 的统一浮层组合，确保用户管理页内不再依赖旧件。

- [ ] **执行替换**

把 `user_management_page.dart` 中的 `LockedFormDialog(...)` 调用改为：

```dart
showDialog<T>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: contentBody,
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      FilledButton(onPressed: onConfirm, child: const Text('确认')),
    ],
  ),
);
```

具体 `title` / `contentBody` / `onConfirm` 替换为原 LockedFormDialog 调用处对应的实参。

**注意：** 浮层底部操作区按基线统一为“左取消、右主操作”，与 `MesPageHeader` 的动作语序一致。

- [ ] **删除 import**

移除 `import 'package:mes_client/core/widgets/locked_form_dialog.dart';`。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "用户管理" -r compact
```

预期：无错误，相关测试通过。

- [ ] **Commit**

```bash
git add -A
git commit -m "用户管理页解除对 LockedFormDialog 的依赖"
```

---

### 任务 1.4：把 user_management_feedback_banner 切换到 MesInlineBanner

**文件：**
- 修改：`frontend/lib/features/user/presentation/widgets/user_management_feedback_banner.dart`
- 引用：`frontend/lib/core/ui/patterns/mes_inline_banner.dart`

- [ ] **读取当前实现**

```bash
cd frontend && cat lib/features/user/presentation/widgets/user_management_feedback_banner.dart
```

确认它内部是否已直接基于 `MesInlineBanner`；若已是，跳过本任务并在日志中记“无需变更”；若不是，继续。

- [ ] **改造实现**

先确认 `MesInlineBanner` 的实际类型签名：

```bash
cd frontend && grep -n "class MesInlineBanner\|enum.*Severity\|severity" lib/core/ui/patterns/mes_inline_banner.dart
```

记下 severity 字段的真实类型名（可能是 `MesInlineBannerSeverity`、`MesBannerSeverity`、或直接用 `MesColors` 语义色），用于下方替换。

在 `user_management_feedback_banner.dart` 内：

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class UserManagementFeedbackBanner extends StatelessWidget {
  const UserManagementFeedbackBanner({
    super.key,
    required this.message,
    required this.severity,
    this.onDismiss,
  });

  final String message;
  // severity 类型按上一步的 grep 结果填入实际类型；下面以 MesInlineBannerSeverity 为占位
  final MesInlineBannerSeverity severity;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return MesInlineBanner(
      message: message,
      severity: severity,
      onDismiss: onDismiss,
    );
  }
}
```

**注意：** 不要在 banner 内自带颜色逻辑或自造 severity 枚举，统一沿用 `MesInlineBanner` 暴露的类型；调用方 `user_management_page.dart` 同步对齐。

- [ ] **更新调用方**

在 `user_management_page.dart` 中确认 `severity` 类型与新签名匹配，调整必要的字段映射。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "用户管理" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "用户管理反馈横幅基于 MesInlineBanner 重写"
```

---

### 任务 1.5：在用户管理页空数据/错误态接入 MesEmptyState 与 MesErrorState

**文件：**
- 修改：`frontend/lib/features/user/presentation/widgets/user_management_table_section.dart`

- [ ] **读取当前实现**

```bash
cd frontend && cat lib/features/user/presentation/widgets/user_management_table_section.dart
```

定位空数据占位与错误占位的渲染位置。

- [ ] **改造空态**

把现有空数据占位替换为：

```dart
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';

// 列表为空时
return const MesEmptyState(
  title: '暂无用户',
  description: '调整筛选条件或新建用户后再查看。',
);
```

- [ ] **改造错误态**

把现有错误占位替换为：

```dart
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';

// 接口失败或权限不足时
return MesErrorState(
  title: '加载失败',
  description: errorMessage,
  onRetry: onReload,
);
```

`errorMessage` 与 `onReload` 来自表格区原有的错误数据流；不要新建错误数据通道。

- [ ] **加载态对齐**

加载态属于状态反馈基线的一部分，本轮也需对齐。优先级如下：

1. 若 `core/ui/patterns/` 已有专用 loading 组件（grep 确认）：直接使用。
2. 若没有：使用 `MesEmptyState` 的 loading 变体（若支持），或在表格容器内统一使用居中 `CircularProgressIndicator`，外层套 `MesSectionCard` 与一致内边距。

确认指令：

```bash
cd frontend && grep -rn "Loading\|loading\|skeleton\|Skeleton" lib/core/ui/patterns
```

按 grep 结果选择路径并落地；不要在表格区直接 `Container(child: CircularProgressIndicator())`，必须包在统一容器内，确保与空/错态视觉等高。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "用户管理" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "用户管理表格区空错状态切换到 MesEmptyState 与 MesErrorState"
```

---

### 任务 1.6：阶段 1 收口与回归

**文件：**
- 修改：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **跑前端高频回归命令**

```bash
cd frontend
flutter analyze
flutter test test/widgets/main_shell_page_test.dart -r compact
flutter test test/widgets/message_center_page_test.dart -r compact
flutter test test/widgets/production_page_test.dart -r compact
```

预期：全部通过。失败时记录失败原因到日志，并修复。

- [ ] **回写阶段 1 总结**

在任务日志“## 阶段 1”节下追加：

```markdown
### 阶段 1 总结

- LegacyLegacyUserManagementPage 已重命名为 UserManagementPage
- 用户管理页脱离 simple_pagination_bar 与 locked_form_dialog 旧件
- 反馈横幅 / 空态 / 错态 全部基于 core/ui/patterns 重写
- flutter analyze 与高频回归命令均通过
- 用户管理页现具备“可被全站映射的基线资格”
```

- [ ] **Commit**

```bash
git add -A
git commit -m "回写阶段 1 收口结论到任务日志"
```

---

## 阶段 2：用户模块整模收敛

> 目的：以用户管理页为模板，让用户模块的 7 个其他页面（注册审批、角色管理、审计日志、登录会话、账号设置、功能权限配置、用户模块壳层）形成统一骨架。

### 任务 2.1：注册审批页对齐基线

**文件：**
- 修改：`frontend/lib/features/user/presentation/registration_approval_page.dart`
- 修改（按需）：`frontend/lib/features/user/presentation/widgets/registration_approval_page_header.dart` 等

- [ ] **比对差异**

按 8 个基线维度对比 `registration_approval_page.dart` 与 `user_management_page.dart`，记录差距列表到任务日志。

- [ ] **替换 core/widgets 旧件**

```bash
cd frontend
grep -n "package:mes_client/core/widgets" lib/features/user/presentation/registration_approval_page.dart
```

把分页条、locked_form_dialog 等旧件替换路径，参考阶段 1 任务 1.2 / 1.3 的替换方式。

- [ ] **接入 MesEmptyState / MesErrorState / MesInlineBanner**

参考阶段 1 任务 1.4 / 1.5 的接入方式，把空/错/反馈三件统一切换。

- [ ] **页头 / 筛选 / 操作条对齐**

确保 `MesPageHeader` + `MesFilterBar` + `MesToolbar` 的组合方式与 `user_management_page.dart` 一致；若已使用，但参数顺序、间距、动作位置不同，按用户管理页样式调整。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "注册审批" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "注册审批页对齐用户管理基线"
```

---

### 任务 2.2：角色管理页对齐基线

**文件：**
- 修改：`frontend/lib/features/user/presentation/role_management_page.dart`

- [ ] **比对差异并替换旧件**

参考任务 2.1 步骤；重点处理 `core/widgets/` 旧件依赖与浮层对齐。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "角色管理" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "角色管理页对齐用户管理基线"
```

---

### 任务 2.3：审计日志页对齐基线

**文件：**
- 修改：`frontend/lib/features/user/presentation/audit_log_page.dart`

- [ ] **比对差异并替换旧件**

参考任务 2.1 步骤。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "审计日志" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "审计日志页对齐用户管理基线"
```

---

### 任务 2.4：登录会话页对齐基线

**文件：**
- 修改：`frontend/lib/features/user/presentation/login_session_page.dart`

- [ ] **比对差异并替换旧件**

参考任务 2.1 步骤。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "登录会话" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "登录会话页对齐用户管理基线"
```

---

### 任务 2.5：账号设置与功能权限配置页对齐基线

**文件：**
- 修改：`frontend/lib/features/user/presentation/account_settings_page.dart`
- 修改：`frontend/lib/features/user/presentation/function_permission_config_page.dart`

- [ ] **比对差异**

这两个页面没有 `core/widgets/` 旧件依赖，重点确认页头、表单密度、保存动作位置与基线一致。

- [ ] **修正发现的差异**

按差异逐项收口；不引入新组件，只调整布局与公共件用法。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets --plain-name "账号设置\|功能权限" -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "账号设置与功能权限配置页对齐用户管理基线"
```

---

### 任务 2.6：用户模块壳层与导航对齐

**文件：**
- 修改：`frontend/lib/features/user/presentation/user_page.dart`
- 修改（按需）：`frontend/lib/features/user/presentation/widgets/user_page_shell.dart`

- [ ] **比对壳层结构**

确认 `UserPage` 的 tab 结构、间距、与各子页的连接方式与 `production_page_shell.dart` / `equipment_page_shell.dart` 类似；若不一致，统一壳层组合方式。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/user
flutter test test/widgets/main_shell_page_test.dart -r compact
```

- [ ] **Commit**

```bash
git add -A
git commit -m "用户模块壳层与导航对齐统一基线"
```

---

### 任务 2.7：用户模块集成测试回归

**文件：**
- 跑：`frontend/integration_test/login_flow_test.dart`
- 跑：`frontend/integration_test/home_shell_flow_test.dart`

- [ ] **运行集成测试**

```bash
cd frontend
flutter test integration_test/login_flow_test.dart
flutter test integration_test/home_shell_flow_test.dart
```

预期：通过；失败时记录失败用例与 root cause 到任务日志，并修复。

- [ ] **回写阶段 2 总结**

在任务日志“## 阶段 2”节下追加：

```markdown
### 阶段 2 总结

- 用户模块 7 个非基线页面已对齐用户管理页
- 全部脱离 core/widgets 旧件依赖
- 页头 / 筛选 / 操作条 / 表格 / 分页 / 反馈 / 空错 / 浮层 八维基线一致
- flutter analyze 与高频集成测试均通过
- 用户模块作为后续模块的“模板模块”地位确立
```

- [ ] **Commit**

```bash
git add -A
git commit -m "回写阶段 2 用户模块整模收敛结论"
```

---

## 阶段 3：模块改造剧本与基线文档

> 目的：把用户模块的收敛经验固化为可复用文档，让后续每个模块的改造有明确剧本可循。

### 任务 3.1：编写"模块改造剧本"

**文件：**
- 创建：`docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`

- [ ] **创建剧本文档**

```markdown
# 前端模块 UI 收敛改造剧本

## 适用对象
- 任意尚未对齐 core/ui/patterns 的 feature 模块。
- 用法：先参照"前置检查清单"，再依次执行"改造步骤"。

## 视觉基线
- 视觉锚点：`frontend/lib/features/user/presentation/user_management_page.dart`
- 公共件来源：`frontend/lib/core/ui/foundation/`、`frontend/lib/core/ui/primitives/`、`frontend/lib/core/ui/patterns/`

## 八维基线

1. **页面头部**：`MesPageHeader(title, subtitle, actions)`，必有标题与动作层。
2. **筛选区**：`MesFilterBar`，单行控件 + 查询/重置 + 必要时换行。
3. **操作条**：`MesToolbar`，主操作右置，次级操作左置或收起。
4. **内容容器**：`MesSectionCard` 或 `MesCrudPageScaffold`，统一外边距与圆角。
5. **列表与分页**：`CrudListTableSection` + `MesPaginationBar`，避免 `SimplePaginationBar`。
6. **状态反馈**：`MesInlineBanner`、`MesEmptyState`、`MesErrorState` 三件套。
7. **浮层**：`AlertDialog` 系或 `MesDetailPanel`；底部操作区"左取消、右主操作"。
8. **响应式与密度**：宽屏双栏阈值 ≥ 1200px；中等宽度切单栏；工具条按需换行。

## 前置检查清单

- [ ] grep 出该模块所有 `core/widgets/` 旧件 import
- [ ] grep 出该模块所有 inline `Container(decoration: BoxDecoration(...))` 直接样式
- [ ] grep 出该模块所有 `showDialog` 调用与 dialog 文件
- [ ] 确认该模块是否有 `*_page_shell.dart` 与 `*_page_header.dart`

## 改造步骤

1. 替换分页条 → `MesPaginationBar`
2. 替换浮层 → `AlertDialog` + `MesSectionCard` 或 `MesDetailPanel`
3. 反馈横幅 → 基于 `MesInlineBanner`
4. 空数据占位 → `MesEmptyState`
5. 错误态占位 → `MesErrorState`
6. 页头 → `MesPageHeader`
7. 筛选区 → `MesFilterBar`
8. 操作条 → `MesToolbar`
9. 内容容器 → `MesSectionCard` 或 `MesCrudPageScaffold`
10. 验证：`flutter analyze lib/features/<模块>` + 模块对应 widget test + 主壳/集成回归

## 禁止事项

- 不在 `core/ui/patterns` 内增加业务相关参数。
- 不为单个模块新建独立设计 token。
- 不为追求统一抹掉业务确实需要的差异（保留差异需在剧本备注中记录）。
- 不在本剧本之外的范围内提交修改（业务逻辑、数据、权限不动）。

## 留痕要求

- 每完成一个模块，在 `evidence/task_log_20260427_frontend_ui_global_convergence.md` 追加一节，记录：
  - 模块名
  - 改造前/后差距点
  - 通过的 analyze / test 命令
  - 保留的差异及理由

## 模块剩余清单

按推荐顺序：

1. product
2. equipment
3. production
4. quality
5. craft
6. message
7. misc
8. settings
9. shell（仅 home_page，主壳本身保持现状）
10. plugin_host
11. auth（无 page，仅检查）
12. time_sync（无 page，仅检查）
```

- [ ] **Commit**

```bash
git add docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md
git commit -m "新增前端模块 UI 收敛改造剧本"
```

---

### 任务 3.2：编写全站 UI 基线说明文档

**文件：**
- 创建：`docs/frontend/ui-baseline.md`

- [ ] **检查 docs/frontend/ 目录**

```bash
ls c:/Users/Donki/Desktop/ZYKJ_MES/docs/frontend/ 2>/dev/null || echo "NOT_EXISTS"
```

若不存在，按文件创建即会自动建目录。

- [ ] **创建基线说明**

```markdown
# 前端 UI 基线说明

## 视觉基线
- 视觉锚点：用户模块的用户管理页（`frontend/lib/features/user/presentation/user_management_page.dart`）。
- 风格保持：当前主题、品牌色、字体不变。

## 体系四层
1. `core/ui/foundation/`：颜色、间距、圆角、文字层级 token。
2. `core/ui/primitives/`：MesGap、MesInfoRow、MesStatusChip、MesSurface。
3. `core/ui/patterns/`：MesPageHeader、MesFilterBar、MesToolbar、MesSectionCard、MesPaginationBar、MesEmptyState、MesErrorState、MesInlineBanner、MesDetailPanel、MesCrudPageScaffold 等。
4. 模块 widget：负责组装与业务表达，不再承担底层样式细节。

## 八维基线（详见剧本文档）
1. 页面头部
2. 筛选区
3. 操作条
4. 内容容器
5. 列表与分页
6. 状态反馈
7. 浮层
8. 响应式与密度

## 改造剧本
- 文件位置：`docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`
- 用法：每个未对齐的模块都应按剧本逐项收敛。

## 例外口径
- 业务上确实需要的布局差异，必须在剧本"保留差异"小节中记录，不再单独造规则。

## 维护原则
- 不在本基线之外引入新设计体系。
- 不为未来需求提前抽象。
- 模式稳定重复出现，才上升至 patterns 公共层。
```

- [ ] **Commit**

```bash
git add docs/frontend/ui-baseline.md
git commit -m "新增前端 UI 基线说明文档"
```

---

### 任务 3.3：阶段 3 收口

**文件：**
- 修改：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **回写阶段 3 总结**

在任务日志“## 阶段 3”节下追加：

```markdown
### 阶段 3 总结

- 改造剧本：docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md
- 基线说明：docs/frontend/ui-baseline.md
- 9 小时窗口内交付物：审计表、用户管理页基线收口、用户模块整模收敛、剧本与基线文档
- 后续：按剧本逐模块推进 product → equipment → production → quality → craft → message → misc → settings → shell → plugin_host
```

- [ ] **Commit**

```bash
git add -A
git commit -m "回写阶段 3 收口结论与后续路径"
```

---

## 阶段 4：按剧本逐模块推进（窗口外）

> 每个子任务都是一次独立的模块收敛，可由 subagent 单独承接。任何一次执行前，必须先读 `docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`。

### 任务 4.1：product 模块按剧本收敛

**文件：**
- 修改：`frontend/lib/features/product/presentation/*.dart`（5 个 page）

- [ ] **按剧本"前置检查清单"产出本模块差距**

记录到 `evidence/task_log_20260427_frontend_ui_global_convergence.md` 的“## 阶段 4 / product”节。

- [ ] **按剧本"改造步骤"逐项执行**

每完成一个 page 提交一次 commit，commit 信息中文，格式："product 模块 <pageName> 对齐用户管理基线"。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/product
flutter test test/widgets --plain-name "产品" -r compact
```

- [ ] **追加模块小结到任务日志**

包括差距、保留的差异及理由、通过的命令。

- [ ] **最终 Commit**

```bash
git add -A
git commit -m "回写 product 模块按剧本收敛结论"
```

---

### 任务 4.2 ~ 4.10：equipment / production / quality / craft / message / misc / settings / shell / plugin_host 按剧本收敛

每个模块独立一项任务，结构与 4.1 完全一致。落地时重复以下骨架：

- [ ] **按剧本前置检查清单产出差距**
- [ ] **按改造步骤逐项执行，每 page 一次 commit**
- [ ] **运行该模块 analyze 与 widget 测试**
- [ ] **追加模块小结到任务日志**
- [ ] **最终 Commit**

模块顺序推荐：

1. **任务 4.2：product**（已写为示例，跳过）
2. **任务 4.3：equipment**（10 个 page，估时较长）
3. **任务 4.4：production**（16 个 page，估时最长）
4. **任务 4.5：quality**（6 个 page）
5. **任务 4.6：craft**（5 个 page）
6. **任务 4.7：message**（1 个 page，但有 preview panel 需对齐）
7. **任务 4.8：misc**（5 个独立页：login / force_change_password / register / daily_first_article / first_article_disposition）
8. **任务 4.9：settings + plugin_host**（合并执行：1 + 1 page）
9. **任务 4.10：shell.home + auth + time_sync**（home_page 收敛 + auth/time_sync 仅做 import 检查）

**对每个模块的额外要求：**

- **生产模块**特别注意 `production_first_article_page` 与 `first_article_scan_review_mobile_page`，前者有移动端布局差异，后者是独立移动 web 入口，保留差异需在剧本备注中记录。
- **misc.login_page**已有专门的"登录页公告"设计（`docs/superpowers/specs/2026-04-22-login-page-announcement-design.md`），收敛时不要破坏其公告区结构。
- **shell.home_page**已是仪表盘类布局，收敛策略以"页头 + 容器 + 状态反馈"为主，不强求与 CRUD 页同构。

---

## 阶段 5：重点页第二轮深打磨（窗口外）

> 在阶段 4 各模块收敛后，对最高频、最影响布局合理性的页面做第二轮打磨。

### 任务 5.1：识别第二轮打磨候选

**文件：**
- 修改：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **盘点候选**

按以下三类标记候选页面，记录到任务日志“## 阶段 5”节：
1. **高频页**：home_page、user_management_page、production_order_management_page、message_center_page
2. **复杂布局页**：production_pipeline_instances_page、craft_kanban_page、quality_trend_page
3. **断层最明显页**：阶段 4 任务日志中标注为"保留差异较多"的页面

- [ ] **Commit**

```bash
git add -A
git commit -m "阶段 5 第二轮打磨候选清单"
```

---

### 任务 5.2 ~ 5.N：逐页第二轮打磨

每个候选页一项任务，按以下骨架执行：

- [ ] **录入打磨目标**

具体改造点：留白节奏、信息层级、工具条换行、双栏与单栏切换阈值、浮层表单密度。

- [ ] **执行调整**

仅做布局合理性优化，不动业务逻辑、不动数据流。

- [ ] **运行分析与测试**

```bash
cd frontend
flutter analyze lib/features/<模块>
flutter test test/widgets --plain-name "<页面名>" -r compact
```

- [ ] **页面级真实查看**

启动前端：

```powershell
python start_backend.py
# 新终端
python start_frontend.py
```

人工查看该页面与相关浮层，确认改造效果；将检查结论记录到任务日志。

- [ ] **Commit**

```bash
git add -A
git commit -m "<页面名> 第二轮深打磨"
```

---

### 任务 5.最后：阶段 5 收口

**文件：**
- 修改：`evidence/task_log_20260427_frontend_ui_global_convergence.md`

- [ ] **回写阶段 5 总结**

记录每个打磨页的改造前后对比要点。

- [ ] **跑全量回归**

```bash
cd frontend
flutter analyze
flutter test
flutter test integration_test/login_flow_test.dart
flutter test integration_test/home_shell_flow_test.dart
flutter test integration_test/message_center_flow_test.dart
```

预期：全部通过。失败时回滚或修复，不留遗留。

- [ ] **最终 Commit**

```bash
git add -A
git commit -m "前端全站 UI 一致性与布局合理性收敛收尾"
```

---

## 验证总览

每个阶段结束都要满足：

1. `flutter analyze` 在受影响范围内零新增错误。
2. 该阶段触及的页面相关 widget test 通过。
3. 任务日志补齐该阶段的“总结”小节。
4. 提交信息为中文。

阶段 2 结束后追加：高频集成测试（login_flow / home_shell_flow / message_center_flow）通过。
阶段 5 结束后追加：`flutter test` 全量通过、三条集成测试通过。

---

## 范围与限制说明

- 9 小时窗口仅覆盖阶段 0 ~ 阶段 3。
- 阶段 4 ~ 5 按改造剧本分批推进，每批可由独立 subagent 承接。
- 不更换主题、不引入新设计系统、不改业务逻辑。
- 当前工作区有 `frontend/windows/flutter/generated_plugin_registrant.cc`、`frontend/windows/flutter/generated_plugins.cmake` 两个未提交生成文件改动，本计划全程不涉及这两个文件。
- 迁移口径：无迁移，直接替换。
