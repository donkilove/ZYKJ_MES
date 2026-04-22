# 用户模块完整收口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成用户模块完整收口，使 `UserPage` 总页壳层与 7 个页签全部进入统一口径，并补齐模块级验证与留痕闭环。

**Architecture:** 总体按一个总 spec、三批实施推进。第 1 批收口 `UserPage + user_management + registration_approval`，先解决总页壳层与主业务页的统一问题；第 2 批收口 `role_management + audit_log`，将管理/审计类页面拉齐到同一口径；第 3 批收口 `account_settings + login_session + function_permission_config`，解决支持页签稳定接入问题。每批都先写失败测试，再做最小实现，最后用 `flutter analyze`、页面级测试、模块级集成和 `evidence` 收口。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`docs/`、`evidence/` 操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 用户当前明确接受在 `main` 分支直接推进，因此计划不再引入额外工作树。  
> 当前工作区中与本计划无关的改动包括：`backend/.env` 以及若干未跟踪 `evidence` 文件。执行本计划时不要把这些文件纳入提交。

## 文件结构

### 新增文件

- `frontend/lib/features/user/presentation/widgets/user_page_shell.dart`
  - 用户模块总页壳层，统一页签栏、内容区和稳定语义锚点
- `frontend/test/widgets/user_module_full_convergence_test.dart`
  - 用户模块完整收口的壳层与模块级 widget 门禁
- `frontend/lib/features/user/presentation/widgets/role_management_page_header.dart`
  - 角色管理页头
- `frontend/lib/features/user/presentation/widgets/role_management_filter_section.dart`
  - 角色管理筛选区
- `frontend/lib/features/user/presentation/widgets/role_management_feedback_banner.dart`
  - 角色管理反馈区
- `frontend/lib/features/user/presentation/widgets/role_management_table_section.dart`
  - 角色管理表格区
- `frontend/lib/features/user/presentation/widgets/audit_log_page_header.dart`
  - 审计日志页头
- `frontend/lib/features/user/presentation/widgets/audit_log_filter_section.dart`
  - 审计日志筛选区
- `frontend/lib/features/user/presentation/widgets/audit_log_feedback_banner.dart`
  - 审计日志反馈区
- `frontend/lib/features/user/presentation/widgets/audit_log_table_section.dart`
  - 审计日志表格区
- `frontend/lib/features/user/presentation/widgets/account_settings_page_header.dart`
  - 个人中心页头
- `frontend/lib/features/user/presentation/widgets/login_session_page_header.dart`
  - 登录会话页头
- `frontend/lib/features/user/presentation/widgets/function_permission_config_page_header.dart`
  - 功能权限配置页头
- `evidence/2026-04-22_用户模块完整收口实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/lib/features/user/presentation/user_page.dart`
  - 将总页壳层收敛为稳定总控入口
- `frontend/lib/features/user/presentation/user_management_page.dart`
  - 与新壳层和统一模块验证口径对齐
- `frontend/lib/features/user/presentation/registration_approval_page.dart`
  - 与新壳层和统一模块验证口径对齐
- `frontend/lib/features/user/presentation/role_management_page.dart`
  - 接入统一 CRUD 骨架与共享件
- `frontend/lib/features/user/presentation/audit_log_page.dart`
  - 接入统一 CRUD 骨架与共享件
- `frontend/lib/features/user/presentation/account_settings_page.dart`
  - 接入用户模块统一页头与反馈出口
- `frontend/lib/features/user/presentation/login_session_page.dart`
  - 接入用户模块统一页头与反馈出口
- `frontend/lib/features/user/presentation/function_permission_config_page.dart`
  - 接入用户模块统一页头与反馈出口
- `frontend/test/widgets/user_page_test.dart`
  - 总页壳层稳定性与页签装配回归
- `frontend/test/widgets/user_management_page_test.dart`
  - 主业务页与壳层协同回归
- `frontend/test/widgets/registration_approval_page_test.dart`
  - 主业务页与壳层协同回归
- `frontend/test/widgets/user_module_support_pages_test.dart`
  - 角色、审计、个人中心、登录会话、功能权限配置回归
- `frontend/integration_test/user_module_flow_test.dart`
  - 模块级主路径验证，最终通过 `UserPage` 壳层驱动
- `evidence/2026-04-20_用户模块UI第二波迁移实施.md`
  - 仅作为对照历史，不在本轮改写

## 任务 1：第 1 批，收口 UserPage 壳层与主业务页

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/user_page_shell.dart`
- Create: `frontend/test/widgets/user_module_full_convergence_test.dart`
- Modify: `frontend/lib/features/user/presentation/user_page.dart`
- Modify: `frontend/test/widgets/user_page_test.dart`
- Modify: `frontend/test/widgets/user_management_page_test.dart`
- Modify: `frontend/test/widgets/registration_approval_page_test.dart`
- Modify: `frontend/integration_test/user_module_flow_test.dart`

- [ ] **Step 1: 先写失败测试，固定总页壳层必须具备稳定锚点与三类子页装配**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
}

void main() {
  testWidgets('UserPage 接入统一总页壳层并保留稳定页签栏锚点', (tester) async {
    await tester.pumpWidget(
      _host(
        UserPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          visibleTabCodes: const [
            'user_management',
            'registration_approval',
            'role_management',
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: 'user_management',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user-page-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-page-tab-bar')), findsOneWidget);
    expect(find.text('用户管理'), findsOneWidget);
    expect(find.text('注册审批'), findsOneWidget);
    expect(find.text('角色管理'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行壳层测试，确认总页壳层尚未完成收口**

Run: `flutter test test/widgets/user_module_full_convergence_test.dart --plain-name "UserPage 接入统一总页壳层并保留稳定页签栏锚点"`

Expected: FAIL，报错包含找不到 `user-page-shell` 或 `user-page-tab-bar`

- [ ] **Step 3: 最小实现总页壳层，并让主业务页继续通过壳层装配**

```dart
// frontend/lib/features/user/presentation/widgets/user_page_shell.dart
import 'package:flutter/material.dart';

class UserPageShell extends StatelessWidget {
  const UserPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('user-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('user-page-tab-bar'),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: tabBar,
            ),
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/user_page.dart
import 'package:mes_client/features/user/presentation/widgets/user_page_shell.dart';

@override
Widget build(BuildContext context) {
  final tabs = _buildTabs();
  if (tabs.isEmpty) {
    return const Center(child: Text('当前账号没有可访问的用户模块页面'));
  }

  return DefaultTabController(
    key: ValueKey('${tabs.map((item) => item.code).join('|')}|$_currentTabIndex'),
    length: tabs.length,
    initialIndex: _currentTabIndex.clamp(0, tabs.length - 1),
    child: Builder(
      builder: (context) {
        final tabController = DefaultTabController.of(context);
        _tabController = tabController;
        return UserPageShell(
          tabBar: TabBar(
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.zero,
            tabs: tabs.map((item) => Tab(text: item.title)).toList(),
          ),
          tabBarView: TabBarView(
            controller: tabController,
            children: tabs.map((item) => item.child).toList(),
          ),
        );
      },
    ),
  );
}
```

- [ ] **Step 4: 重新运行壳层测试，并补跑主业务页回归**

Run: `flutter test test/widgets/user_module_full_convergence_test.dart --plain-name "UserPage 接入统一总页壳层并保留稳定页签栏锚点"`

Expected: PASS

Run: `flutter test test/widgets/user_page_test.dart`

Expected: PASS

Run: `flutter test test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交第 1 批收口**

```bash
git add frontend/lib/features/user/presentation/widgets/user_page_shell.dart frontend/lib/features/user/presentation/user_page.dart frontend/test/widgets/user_module_full_convergence_test.dart frontend/test/widgets/user_page_test.dart frontend/test/widgets/user_management_page_test.dart frontend/test/widgets/registration_approval_page_test.dart frontend/integration_test/user_module_flow_test.dart
git commit -m "收口用户模块总页壳层与主业务页"
```

## 任务 2：第 2 批，收口 role_management 与 audit_log

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/role_management_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/role_management_filter_section.dart`
- Create: `frontend/lib/features/user/presentation/widgets/role_management_feedback_banner.dart`
- Create: `frontend/lib/features/user/presentation/widgets/role_management_table_section.dart`
- Create: `frontend/lib/features/user/presentation/widgets/audit_log_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/audit_log_filter_section.dart`
- Create: `frontend/lib/features/user/presentation/widgets/audit_log_feedback_banner.dart`
- Create: `frontend/lib/features/user/presentation/widgets/audit_log_table_section.dart`
- Modify: `frontend/lib/features/user/presentation/role_management_page.dart`
- Modify: `frontend/lib/features/user/presentation/audit_log_page.dart`
- Modify: `frontend/test/widgets/user_module_support_pages_test.dart`

- [ ] **Step 1: 先写失败测试，固定角色管理与审计日志进入统一页面口径**

```dart
// frontend/test/widgets/user_module_support_pages_test.dart
testWidgets('role management page 接入统一页头和列表区锚点', (tester) async {
  await _pumpPage(
    tester,
    RoleManagementPage(
      session: _session,
      onLogout: () {},
      canCreateRole: true,
      canEditRole: true,
      canToggleRole: true,
      canDeleteRole: true,
      userService: userService,
    ),
  );

  expect(find.byKey(const ValueKey('role-management-page-header')), findsOneWidget);
  expect(find.byKey(const ValueKey('role-management-table-section')), findsOneWidget);
});

testWidgets('audit log page 接入统一页头和筛选区锚点', (tester) async {
  await _pumpPage(
    tester,
    AuditLogPage(
      session: _session,
      onLogout: () {},
      userService: userService,
    ),
  );

  expect(find.byKey(const ValueKey('audit-log-page-header')), findsOneWidget);
  expect(find.byKey(const ValueKey('audit-log-filter-section')), findsOneWidget);
  expect(find.byKey(const ValueKey('audit-log-table-section')), findsOneWidget);
});
```

- [ ] **Step 2: 运行 support 页测试，确认锚点尚未存在**

Run: `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "role management page 接入统一页头和列表区锚点"`

Expected: FAIL，找不到 `role-management-page-header`

Run: `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "audit log page 接入统一页头和筛选区锚点"`

Expected: FAIL，找不到 `audit-log-page-header`

- [ ] **Step 3: 以最小实现接入统一页头 / 筛选 / 表格区**

```dart
// frontend/lib/features/user/presentation/widgets/role_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class RoleManagementPageHeader extends StatelessWidget {
  const RoleManagementPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('role-management-page-header'),
      child: MesPageHeader(
        title: '角色管理',
        subtitle: '统一管理角色、启停与删除动作。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/audit_log_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class AuditLogPageHeader extends StatelessWidget {
  const AuditLogPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('audit-log-page-header'),
      child: MesPageHeader(
        title: '审计日志',
        subtitle: '统一查看操作人、目标对象与动作结果。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/role_management_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/user/presentation/widgets/role_management_page_header.dart';

@override
Widget build(BuildContext context) {
  return MesCrudPageScaffold(
    header: RoleManagementPageHeader(
      loading: _loading,
      onRefresh: _loadRoles,
    ),
    content: KeyedSubtree(
      key: const ValueKey('role-management-table-section'),
      child: _buildRoleTable(),
    ),
    pagination: _buildPagination(),
  );
}
```

```dart
// frontend/lib/features/user/presentation/audit_log_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/user/presentation/widgets/audit_log_page_header.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';

@override
Widget build(BuildContext context) {
  return MesCrudPageScaffold(
    header: AuditLogPageHeader(
      loading: _loading,
      onRefresh: _loadAuditLogs,
    ),
    filters: UserModuleFilterPanel(
      sectionKey: const ValueKey('audit-log-filter-section'),
      child: _buildFilterContent(),
    ),
    content: KeyedSubtree(
      key: const ValueKey('audit-log-table-section'),
      child: _buildAuditTable(),
    ),
    pagination: _buildPagination(),
  );
}
```

- [ ] **Step 4: 重新运行 support 页测试**

Run: `flutter test test/widgets/user_module_support_pages_test.dart`

Expected: PASS

- [ ] **Step 5: 提交第 2 批收口**

```bash
git add frontend/lib/features/user/presentation/widgets/role_management_page_header.dart frontend/lib/features/user/presentation/widgets/audit_log_page_header.dart frontend/lib/features/user/presentation/role_management_page.dart frontend/lib/features/user/presentation/audit_log_page.dart frontend/test/widgets/user_module_support_pages_test.dart
git commit -m "收口用户模块组织与审计页"
```

## 任务 3：第 3 批，收口个人与配置页

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/account_settings_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/login_session_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/function_permission_config_page_header.dart`
- Modify: `frontend/lib/features/user/presentation/account_settings_page.dart`
- Modify: `frontend/lib/features/user/presentation/login_session_page.dart`
- Modify: `frontend/lib/features/user/presentation/function_permission_config_page.dart`
- Modify: `frontend/test/widgets/user_module_support_pages_test.dart`
- Modify: `frontend/integration_test/user_module_flow_test.dart`

- [ ] **Step 1: 先写失败测试，固定支持页签稳定接入与统一反馈出口**

```dart
// frontend/test/widgets/user_module_support_pages_test.dart
testWidgets('account settings page 接入统一页头锚点', (tester) async {
  await _pumpPage(
    tester,
    AccountSettingsPage(
      session: _session,
      onLogout: () {},
      canChangePassword: true,
      canViewSession: true,
    ),
  );

  expect(find.byKey(const ValueKey('account-settings-page-header')), findsOneWidget);
});

testWidgets('login session page 接入统一页头锚点', (tester) async {
  await _pumpPage(
    tester,
    LoginSessionPage(
      session: _session,
      onLogout: () {},
      canViewOnlineSessions: true,
      canForceOffline: true,
      userService: userService,
    ),
  );

  expect(find.byKey(const ValueKey('login-session-page-header')), findsOneWidget);
});

testWidgets('function permission config page 接入统一页头锚点', (tester) async {
  await _pumpPage(
    tester,
    FunctionPermissionConfigPage(
      session: _session,
      onLogout: () {},
      authzService: authzService,
      userService: userService,
    ),
  );

  expect(find.byKey(const ValueKey('function-permission-config-page-header')), findsOneWidget);
});
```

- [ ] **Step 2: 运行支持页测试，确认锚点尚未存在**

Run: `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "account settings page 接入统一页头锚点"`

Expected: FAIL

Run: `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "login session page 接入统一页头锚点"`

Expected: FAIL

Run: `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "function permission config page 接入统一页头锚点"`

Expected: FAIL

- [ ] **Step 3: 为三个支持页补统一页头，并更新模块级 integration 通过 UserPage 壳层驱动**

```dart
// frontend/lib/features/user/presentation/widgets/account_settings_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class AccountSettingsPageHeader extends StatelessWidget {
  const AccountSettingsPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('account-settings-page-header'),
      child: MesPageHeader(
        title: '个人中心',
        subtitle: '统一管理个人信息与密码修改入口。',
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/login_session_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class LoginSessionPageHeader extends StatelessWidget {
  const LoginSessionPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('login-session-page-header'),
      child: MesPageHeader(
        title: '登录会话',
        subtitle: '统一查看在线会话和强制下线入口。',
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/function_permission_config_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class FunctionPermissionConfigPageHeader extends StatelessWidget {
  const FunctionPermissionConfigPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('function-permission-config-page-header'),
      child: MesPageHeader(
        title: '功能权限配置',
        subtitle: '统一配置模块权限能力包。',
      ),
    );
  }
}
```

```dart
// frontend/integration_test/user_module_flow_test.dart
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';

testWidgets('用户模块通过总页壳层展示主业务页并可切到支持页签', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UserPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          visibleTabCodes: const [
            'user_management',
            'registration_approval',
            'account_settings',
          ],
          capabilityCodes: {
            UserFeaturePermissionCodes.userManagementCreate,
            UserFeaturePermissionCodes.userManagementUpdate,
            UserFeaturePermissionCodes.userManagementLifecycle,
            UserFeaturePermissionCodes.userManagementPasswordReset,
            UserFeaturePermissionCodes.userManagementDelete,
            UserFeaturePermissionCodes.userManagementExport,
            UserFeaturePermissionCodes.registrationApprovalApprove,
            UserFeaturePermissionCodes.registrationApprovalReject,
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('user-page-shell')), findsOneWidget);
  expect(find.text('用户管理'), findsOneWidget);
  await tester.tap(find.text('个人中心'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('account-settings-page-header')), findsOneWidget);
});
```

- [ ] **Step 4: 重新运行 support 页与用户模块 integration**

Run: `flutter test test/widgets/user_module_support_pages_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/user_module_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交第 3 批收口**

```bash
git add frontend/lib/features/user/presentation/widgets/account_settings_page_header.dart frontend/lib/features/user/presentation/widgets/login_session_page_header.dart frontend/lib/features/user/presentation/widgets/function_permission_config_page_header.dart frontend/lib/features/user/presentation/account_settings_page.dart frontend/lib/features/user/presentation/login_session_page.dart frontend/lib/features/user/presentation/function_permission_config_page.dart frontend/test/widgets/user_module_support_pages_test.dart frontend/integration_test/user_module_flow_test.dart
git commit -m "收口用户模块支持页签"
```

## 任务 4：最终验证与实施留痕

**Files:**
- Create: `evidence/2026-04-22_用户模块完整收口实施.md`

- [ ] **Step 1: 创建实施阶段 evidence 主日志**

```md
# 任务日志：用户模块完整收口实施

- 日期：2026-04-22
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：
  - 先补用户模块完整收口
- 设计规格：
  - `docs/superpowers/specs/2026-04-21-user-module-full-convergence-design.md`
- 实施计划：
  - `docs/superpowers/plans/2026-04-22-user-module-full-convergence-implementation.md`

## 2. 实施分段
- 任务 1：收口总页壳层与主业务页
- 任务 2：收口组织与审计页
- 任务 3：收口个人与配置页
- 任务 4：最终验证与实施留痕

## 3. 验证结果
- `flutter analyze`：通过
- `flutter test test/widgets/user_module_full_convergence_test.dart`：通过
- `flutter test test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart test/widgets/user_module_support_pages_test.dart test/widgets/user_page_test.dart`：通过
- `flutter test -d windows integration_test/user_module_flow_test.dart`：通过

## 4. 风险与补偿
- 本轮未改后端接口契约
- 本轮未引入新全局基础件，只在用户模块与既有 `core/ui` 范围内收口

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 2: 运行最终验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/user_module_full_convergence_test.dart test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart test/widgets/user_module_support_pages_test.dart test/widgets/user_page_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/user_module_flow_test.dart`

Expected: PASS

- [ ] **Step 3: 提交最终用户模块完整收口结果**

```bash
git add frontend/lib/features/user/presentation/user_page.dart frontend/lib/features/user/presentation/widgets/user_page_shell.dart frontend/lib/features/user/presentation/user_management_page.dart frontend/lib/features/user/presentation/registration_approval_page.dart frontend/lib/features/user/presentation/role_management_page.dart frontend/lib/features/user/presentation/audit_log_page.dart frontend/lib/features/user/presentation/account_settings_page.dart frontend/lib/features/user/presentation/login_session_page.dart frontend/lib/features/user/presentation/function_permission_config_page.dart frontend/lib/features/user/presentation/widgets/*.dart frontend/test/widgets/user_module_full_convergence_test.dart frontend/test/widgets/user_management_page_test.dart frontend/test/widgets/registration_approval_page_test.dart frontend/test/widgets/user_module_support_pages_test.dart frontend/test/widgets/user_page_test.dart frontend/integration_test/user_module_flow_test.dart evidence/2026-04-22_用户模块完整收口实施.md
git commit -m "完成用户模块完整收口"
```
