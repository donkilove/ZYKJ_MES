# MainShellPage Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `MainShellPage` 从“大而全”的 1137 行 StatefulWidget 拆成控制器、状态快照、纯计算、刷新协调、页面注册和纯视图壳层 6 个聚焦单元，同时保持现有对外行为、依赖注入方式和主壳层回归测试可用。

**Architecture:** 保留 `MainShellPage` 作为最外层 StatefulWidget，只负责生命周期桥接和依赖组装。壳层状态收敛到 `MainShellController + MainShellViewState`，菜单/跳转/快捷入口这类纯计算迁到 `main_shell_navigation.dart`，定时器与消息刷新迁到 `main_shell_refresh_coordinator.dart`，模块页装配迁到 `main_shell_page_registry.dart`，布局绘制迁到 `widgets/main_shell_scaffold.dart`。

**Tech Stack:** Flutter、Dart、`flutter_test`、现有 `AuthService` / `AuthzService` / `PageCatalogService` / `MessageService` / `HomeDashboardService`、现有 `MainShellPage` 依赖注入模式

---

## 文件结构

### 新增文件

- `frontend/lib/features/shell/presentation/main_shell_state.dart`
  - 定义 `MainShellViewState`、`MainShellMenuItem`、`MainShellResolvedTarget`
- `frontend/lib/features/shell/presentation/main_shell_navigation.dart`
  - 提供菜单生成、页签排序、默认跳转、快捷入口构建等纯函数
- `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`
  - 承担权限轮询、未读轮询、工作台防抖刷新、pending 补刷
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 按 `pageCode` 构造各模块页面，保留 builder override 能力
- `frontend/lib/features/shell/presentation/main_shell_controller.dart`
  - 编排用户加载、权限快照、目录刷新、导航状态和刷新协调器
- `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
  - 绘制菜单、提示条、无权限页、错误页、内容区
- `frontend/test/widgets/main_shell_navigation_test.dart`
  - 验证纯导航与菜单计算
- `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
  - 验证未读刷新、消息防抖、pending 补刷
- `frontend/test/widgets/main_shell_page_registry_test.dart`
  - 验证 builder 优先级、参数透传、消息模块跳转载荷
- `frontend/test/widgets/main_shell_controller_test.dart`
  - 验证初始化、401 退出、手动刷新和导航状态
- `frontend/test/widgets/main_shell_scaffold_test.dart`
  - 验证布局、角标、错误态、无权限态
- `frontend/test/widgets/main_shell_test_support.dart`
  - 提供 `_session`、目录、权限快照、假服务、假 websocket、工作台假数据等共享夹具

### 修改文件

- `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - 最终只保留 StatefulWidget 外壳、控制器创建/销毁、生命周期转发、`AnimatedBuilder`/`ListenableBuilder` 组合
- `frontend/test/widgets/main_shell_page_test.dart`
  - 只保留壳层级闭环回归，不再堆放纯逻辑测试

### 目录职责

- `presentation/`：壳层状态编排和页面装配
- `presentation/widgets/`：纯 UI 视图
- `test/widgets/`：当前仓库既有测试风格；继续沿用，不额外引入新测试目录风格

## 任务 1：抽离共享测试夹具与纯导航计算

**Files:**
- Create: `frontend/test/widgets/main_shell_test_support.dart`
- Create: `frontend/lib/features/shell/presentation/main_shell_state.dart`
- Create: `frontend/lib/features/shell/presentation/main_shell_navigation.dart`
- Create: `frontend/test/widgets/main_shell_navigation_test.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`

- [ ] **Step 1: 写失败测试，固定菜单、页签和目标页解析行为**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

import 'main_shell_test_support.dart';

void main() {
  test('buildMainShellMenus 按目录顺序生成首页与可见模块菜单', () {
    final menus = buildMainShellMenus(
      catalog: buildCatalog(),
      visibleSidebarCodes: const ['user', 'message'],
      homePageCode: 'home',
      iconForPage: iconForPageForTest,
    );

    expect(menus.map((item) => item.code).toList(), ['home', 'user', 'message']);
    expect(menus.first.title, '首页');
  });

  test('resolveMainShellTarget 会把 tab 解析成父模块并继承页签代码', () {
    final result = resolveMainShellTarget(
      requestedPageCode: 'account_settings',
      requestedTabCode: null,
      requestedRoutePayloadJson: '{"target_tab_code":"account_settings"}',
      catalog: buildCatalog(),
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
        MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
      ],
    );

    expect(result.hasAccess, isTrue);
    expect(result.pageCode, 'user');
    expect(result.tabCode, 'account_settings');
  });
}
```

- [ ] **Step 2: 运行测试，确认因为新文件与方法不存在而失败**

Run: `flutter test test/widgets/main_shell_navigation_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined name 'buildMainShellMenus'`

- [ ] **Step 3: 编写最小实现，提供状态快照与纯导航函数**

```dart
// frontend/lib/features/shell/presentation/main_shell_state.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class MainShellMenuItem {
  const MainShellMenuItem({
    required this.code,
    required this.title,
    required this.icon,
  });

  final String code;
  final String title;
  final IconData icon;
}

class MainShellResolvedTarget {
  const MainShellResolvedTarget({
    required this.pageCode,
    required this.tabCode,
    required this.routePayloadJson,
    required this.hasAccess,
  });

  final String pageCode;
  final String? tabCode;
  final String? routePayloadJson;
  final bool hasAccess;
}

class MainShellViewState {
  const MainShellViewState({
    this.loading = true,
    this.message = '',
    this.messageRefreshTick = 0,
    this.currentUser,
    this.authzSnapshot,
    this.catalog = fallbackPageCatalog,
    this.tabCodesByParent = const {},
    this.menus = const [],
    this.selectedPageCode = 'home',
    this.unreadCount = 0,
    this.preferredTabCode,
    this.preferredRoutePayloadJson,
    this.manualRefreshing = false,
    this.homeDashboardLoading = false,
    this.homeDashboardRefreshPending = false,
    this.lastManualRefreshAt,
    this.homeDashboardData,
  });

  final bool loading;
  final String message;
  final int messageRefreshTick;
  final CurrentUser? currentUser;
  final AuthzSnapshotResult? authzSnapshot;
  final List<PageCatalogItem> catalog;
  final Map<String, List<String>> tabCodesByParent;
  final List<MainShellMenuItem> menus;
  final String selectedPageCode;
  final int unreadCount;
  final String? preferredTabCode;
  final String? preferredRoutePayloadJson;
  final bool manualRefreshing;
  final bool homeDashboardLoading;
  final bool homeDashboardRefreshPending;
  final DateTime? lastManualRefreshAt;
  final HomeDashboardData? homeDashboardData;

  MainShellViewState copyWith({
    bool? loading,
    String? message,
    int? messageRefreshTick,
    CurrentUser? currentUser,
    AuthzSnapshotResult? authzSnapshot,
    List<PageCatalogItem>? catalog,
    Map<String, List<String>>? tabCodesByParent,
    List<MainShellMenuItem>? menus,
    String? selectedPageCode,
    int? unreadCount,
    String? preferredTabCode,
    String? preferredRoutePayloadJson,
    bool? manualRefreshing,
    bool? homeDashboardLoading,
    bool? homeDashboardRefreshPending,
    DateTime? lastManualRefreshAt,
    HomeDashboardData? homeDashboardData,
  }) {
    return MainShellViewState(
      loading: loading ?? this.loading,
      message: message ?? this.message,
      messageRefreshTick: messageRefreshTick ?? this.messageRefreshTick,
      currentUser: currentUser ?? this.currentUser,
      authzSnapshot: authzSnapshot ?? this.authzSnapshot,
      catalog: catalog ?? this.catalog,
      tabCodesByParent: tabCodesByParent ?? this.tabCodesByParent,
      menus: menus ?? this.menus,
      selectedPageCode: selectedPageCode ?? this.selectedPageCode,
      unreadCount: unreadCount ?? this.unreadCount,
      preferredTabCode: preferredTabCode ?? this.preferredTabCode,
      preferredRoutePayloadJson:
          preferredRoutePayloadJson ?? this.preferredRoutePayloadJson,
      manualRefreshing: manualRefreshing ?? this.manualRefreshing,
      homeDashboardLoading: homeDashboardLoading ?? this.homeDashboardLoading,
      homeDashboardRefreshPending:
          homeDashboardRefreshPending ?? this.homeDashboardRefreshPending,
      lastManualRefreshAt: lastManualRefreshAt ?? this.lastManualRefreshAt,
      homeDashboardData: homeDashboardData ?? this.homeDashboardData,
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/main_shell_navigation.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

typedef MainShellIconResolver = IconData Function(String pageCode);

List<MainShellMenuItem> buildMainShellMenus({
  required List<PageCatalogItem> catalog,
  required List<String> visibleSidebarCodes,
  required String homePageCode,
  required MainShellIconResolver iconForPage,
}) {
  final visibleCodeSet = visibleSidebarCodes.toSet();
  final sidebarPages = catalog.where((item) => item.pageType == 'sidebar').toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final homeItem = sidebarPages.where((item) => item.code == homePageCode).firstOrNull;
  final items = <MainShellMenuItem>[];

  for (final page in sidebarPages) {
    if (page.code == homePageCode) {
      continue;
    }
    if (!page.alwaysVisible && !visibleCodeSet.contains(page.code)) {
      continue;
    }
    items.add(
      MainShellMenuItem(
        code: page.code,
        title: page.name,
        icon: iconForPage(page.code),
      ),
    );
  }

  if (items.isNotEmpty || visibleCodeSet.contains(homePageCode)) {
    items.insert(
      0,
      MainShellMenuItem(
        code: homePageCode,
        title: homeItem?.name ?? '首页',
        icon: iconForPage(homePageCode),
      ),
    );
  }

  return items;
}

Map<String, List<String>> sortMainShellTabCodes({
  required Map<String, List<String>> tabCodesByParent,
  required List<PageCatalogItem> catalog,
}) {
  final sortOrderByCode = <String, int>{
    for (final item in catalog) item.code: item.sortOrder,
  };
  final result = <String, List<String>>{};
  tabCodesByParent.forEach((parentCode, tabCodes) {
    final sorted = [...tabCodes]
      ..sort((a, b) {
        final orderA = sortOrderByCode[a] ?? 9999;
        final orderB = sortOrderByCode[b] ?? 9999;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        return a.compareTo(b);
      });
    result[parentCode] = sorted;
  });
  return result;
}

List<String> filterVisibleTabCodesForParent({
  required Map<String, List<String>> tabCodesByParent,
  required List<PageCatalogItem> catalog,
  required String parentCode,
}) {
  final catalogCodes = catalog.map((item) => item.code).toSet();
  final tabCodes = tabCodesByParent[parentCode] ?? const <String>[];
  return tabCodes.where(catalogCodes.contains).toList();
}

String? defaultTabCodeForPage({
  required Map<String, List<String>> tabCodesByParent,
  required List<PageCatalogItem> catalog,
  required String parentCode,
}) {
  final visibleTabs = filterVisibleTabCodesForParent(
    tabCodesByParent: tabCodesByParent,
    catalog: catalog,
    parentCode: parentCode,
  );
  return visibleTabs.isEmpty ? null : visibleTabs.first;
}

String? defaultRoutePayloadJsonForTab(String? tabCode) {
  if (tabCode == null || tabCode.isEmpty) {
    return null;
  }
  return '{"target_tab_code":"$tabCode"}';
}

MainShellResolvedTarget resolveMainShellTarget({
  required String requestedPageCode,
  required String? requestedTabCode,
  required String? requestedRoutePayloadJson,
  required List<PageCatalogItem> catalog,
  required List<MainShellMenuItem> menus,
}) {
  var resolvedPageCode = requestedPageCode;
  var resolvedTabCode = requestedTabCode;
  final catalogItem =
      catalog.where((item) => item.code == requestedPageCode).firstOrNull;
  if (catalogItem != null && catalogItem.pageType == 'tab') {
    resolvedPageCode = catalogItem.parentCode ?? requestedPageCode;
    resolvedTabCode ??= requestedPageCode;
  }
  final hasAccess = menus.any((menu) => menu.code == resolvedPageCode);
  return MainShellResolvedTarget(
    pageCode: resolvedPageCode,
    tabCode: resolvedTabCode,
    routePayloadJson: requestedRoutePayloadJson,
    hasAccess: hasAccess,
  );
}

List<HomeQuickJumpEntry> buildMainShellQuickJumps({
  required List<MainShellMenuItem> menus,
  required Map<String, List<String>> tabCodesByParent,
  required List<PageCatalogItem> catalog,
  required String homePageCode,
}) {
  final entries = <HomeQuickJumpEntry>[];
  for (final menu in menus) {
    if (menu.code == homePageCode) {
      continue;
    }
    final defaultTabCode = defaultTabCodeForPage(
      tabCodesByParent: tabCodesByParent,
      catalog: catalog,
      parentCode: menu.code,
    );
    entries.add(
      HomeQuickJumpEntry(
        pageCode: menu.code,
        title: menu.title,
        icon: menu.icon,
        tabCode: defaultTabCode,
        routePayloadJson: defaultRoutePayloadJsonForTab(defaultTabCode),
      ),
    );
  }
  return entries;
}
```

- [ ] **Step 4: 在主壳层中替换对应私有函数调用，验证新测试与现有壳层测试通过**

Run: `flutter test test/widgets/main_shell_navigation_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，且 `main_shell_page_test.dart` 仍全部通过

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/shell/presentation/main_shell_state.dart frontend/lib/features/shell/presentation/main_shell_navigation.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_navigation_test.dart frontend/test/widgets/main_shell_test_support.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "拆分 MainShell 导航与状态计算"
```

## 任务 2：抽离刷新协调器，收拢定时器与工作台刷新编排

**Files:**
- Create: `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`
- Create: `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 写失败测试，固定防抖合并、pending 补刷和首页可见性约束**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_refresh_coordinator.dart';

void main() {
  test('消息事件在防抖窗口内只触发一次工作台刷新', () async {
    var refreshCount = 0;
    final coordinator = MainShellRefreshCoordinator(
      isHomePageVisible: () => true,
      refreshUnreadCount: () async {},
      refreshVisibility: ({bool loadCatalog = false, bool silent = false}) async {},
      refreshHomeDashboard: ({bool silent = false}) async {
        refreshCount += 1;
      },
      debounceDuration: const Duration(milliseconds: 200),
      unreadPollInterval: const Duration(seconds: 30),
      visibilityPollInterval: const Duration(seconds: 30),
    );

    coordinator.scheduleHomeDashboardRefresh();
    coordinator.scheduleHomeDashboardRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 260));

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test('当前不在首页时不会触发工作台刷新', () async {
    var refreshCount = 0;
    final coordinator = MainShellRefreshCoordinator(
      isHomePageVisible: () => false,
      refreshUnreadCount: () async {},
      refreshVisibility: ({bool loadCatalog = false, bool silent = false}) async {},
      refreshHomeDashboard: ({bool silent = false}) async {
        refreshCount += 1;
      },
      debounceDuration: const Duration(milliseconds: 50),
      unreadPollInterval: const Duration(seconds: 30),
      visibilityPollInterval: const Duration(seconds: 30),
    );

    coordinator.scheduleHomeDashboardRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(refreshCount, 0);
    coordinator.dispose();
  });
}
```

- [ ] **Step 2: 运行测试，确认因为协调器文件和类型不存在而失败**

Run: `flutter test test/widgets/main_shell_refresh_coordinator_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MainShellRefreshCoordinator'`

- [ ] **Step 3: 实现刷新协调器，并让主壳层只保留状态更新回调**

```dart
// frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart
import 'dart:async';

typedef MainShellVisibilityRefresh = Future<void> Function({
  bool loadCatalog,
  bool silent,
});

typedef MainShellUnreadRefresh = Future<void> Function();
typedef MainShellDashboardRefresh = Future<void> Function({bool silent});

class MainShellRefreshCoordinator {
  MainShellRefreshCoordinator({
    required this.isHomePageVisible,
    required this.refreshVisibility,
    required this.refreshUnreadCount,
    required this.refreshHomeDashboard,
    this.visibilityPollInterval = const Duration(seconds: 15),
    this.unreadPollInterval = const Duration(seconds: 30),
    this.debounceDuration = const Duration(seconds: 2),
  });

  final bool Function() isHomePageVisible;
  final MainShellVisibilityRefresh refreshVisibility;
  final MainShellUnreadRefresh refreshUnreadCount;
  final MainShellDashboardRefresh refreshHomeDashboard;
  final Duration visibilityPollInterval;
  final Duration unreadPollInterval;
  final Duration debounceDuration;

  Timer? _visibilityTimer;
  Timer? _unreadTimer;
  Timer? _debounceTimer;

  void startPolling() {
    _visibilityTimer?.cancel();
    _unreadTimer?.cancel();
    _visibilityTimer = Timer.periodic(visibilityPollInterval, (_) {
      refreshVisibility(silent: true);
    });
    _unreadTimer = Timer.periodic(unreadPollInterval, (_) {
      refreshUnreadCount();
    });
  }

  void scheduleHomeDashboardRefresh() {
    if (!isHomePageVisible()) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      refreshHomeDashboard(silent: true);
    });
  }

  Future<void> handleAppResumed() async {
    await refreshVisibility(silent: true);
    await refreshUnreadCount();
  }

  void dispose() {
    _visibilityTimer?.cancel();
    _unreadTimer?.cancel();
    _debounceTimer?.cancel();
  }
}
```

- [ ] **Step 4: 跑协调器测试和主壳层回归，确认事件链路保持一致**

Run: `flutter test test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，`main_shell_page_test.dart` 中与工作台刷新相关的场景仍通过

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_refresh_coordinator_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "拆分 MainShell 刷新协调逻辑"
```

## 任务 3：抽离页面注册表，替换超长 `_buildContent` 分发

**Files:**
- Create: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Create: `frontend/test/widgets/main_shell_page_registry_test.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 写失败测试，固定 builder override 优先级与消息模块参数透传**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page_registry.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

import 'main_shell_test_support.dart';

void main() {
  testWidgets('用户模块优先使用注入 builder', (tester) async {
    final registry = MainShellPageRegistry();
    final state = MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(),
      catalog: buildCatalog(),
      tabCodesByParent: const {
        'user': ['user_management'],
      },
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
        MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
      ],
      selectedPageCode: 'user',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: registry.build(
          pageCode: 'user',
          session: testSession,
          state: state,
          onLogout: () {},
          onNavigateToPageTarget: ({required pageCode, String? tabCode, String? routePayloadJson}) {},
          onVisibilityConfigSaved: () {},
          messageService: buildMessageService(),
          userPageBuilder: ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return const Text('override-user-page');
          },
        ),
      ),
    );

    expect(find.text('override-user-page'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为注册表文件和方法不存在而失败**

Run: `flutter test test/widgets/main_shell_page_registry_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MainShellPageRegistry'`

- [ ] **Step 3: 实现页面注册表，并让主壳层只负责传递上下文**

```dart
// frontend/lib/features/shell/presentation/main_shell_page_registry.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/shell/presentation/home_page.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/equipment/presentation/equipment_page.dart';
import 'package:mes_client/features/production/presentation/production_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/craft/presentation/craft_page.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';

typedef MainShellUserPageBuilder = Widget Function({
  required AppSession session,
  required VoidCallback onLogout,
  required List<String> visibleTabCodes,
  required Set<String> capabilityCodes,
  String? preferredTabCode,
  String? routePayloadJson,
  VoidCallback? onVisibilityConfigSaved,
});

typedef MainShellModulePageBuilder = Widget Function({
  required AppSession session,
  required VoidCallback onLogout,
  required List<String> visibleTabCodes,
  required Set<String> capabilityCodes,
  String? preferredTabCode,
  String? routePayloadJson,
});

class MainShellPageRegistry {
  const MainShellPageRegistry();

  Widget build({
    required String pageCode,
    required AppSession session,
    required MainShellViewState state,
    required VoidCallback onLogout,
    required void Function({
      required String pageCode,
      String? tabCode,
      String? routePayloadJson,
    }) onNavigateToPageTarget,
    required VoidCallback onVisibilityConfigSaved,
    required MessageService messageService,
    MainShellUserPageBuilder? userPageBuilder,
    MainShellModulePageBuilder? productPageBuilder,
    MainShellModulePageBuilder? equipmentPageBuilder,
    MainShellModulePageBuilder? productionPageBuilder,
    MainShellModulePageBuilder? qualityPageBuilder,
    MainShellModulePageBuilder? craftPageBuilder,
  }) {
    final capabilityCodesFor = (String moduleCode) =>
        state.authzSnapshot?.capabilityCodesForModule(moduleCode) ??
        const <String>{};
    final tabCodesFor = (String parentCode) => filterVisibleTabCodesForParent(
      tabCodesByParent: state.tabCodesByParent,
      catalog: state.catalog,
      parentCode: parentCode,
    );

    switch (pageCode) {
      case 'home':
        return HomePage(
          currentUser: state.currentUser!,
          shortcuts: buildMainShellQuickJumps(
            menus: state.menus,
            tabCodesByParent: state.tabCodesByParent,
            catalog: state.catalog,
            homePageCode: 'home',
          ),
          dashboardData: state.homeDashboardData,
          onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
            onNavigateToPageTarget(
              pageCode: pageCode,
              tabCode: tabCode,
              routePayloadJson: routePayloadJson,
            );
          },
          onRefresh: () {},
          refreshing: state.manualRefreshing,
          refreshStatusText: state.lastManualRefreshAt == null
              ? null
              : '上次刷新：${state.lastManualRefreshAt}',
        );
      case 'user':
        final builder = userPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('user'),
                capabilityCodes: capabilityCodesFor('user'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
                onVisibilityConfigSaved: onVisibilityConfigSaved,
              )
            : UserPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('user'),
                capabilityCodes: capabilityCodesFor('user'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
                onVisibilityConfigSaved: onVisibilityConfigSaved,
              );
      case 'message':
        return MessageCenterPage(
          session: session,
          service: messageService,
          onLogout: onLogout,
          canPublishAnnouncement: capabilityCodesFor('message')
              .contains('feature.message.announcement.publish'),
          canViewDetail: capabilityCodesFor('message')
              .contains('feature.message.detail.view'),
          canUseJump: true,
          refreshTick: state.messageRefreshTick,
          onUnreadCountChanged: (_) {},
          onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
            onNavigateToPageTarget(
              pageCode: pageCode,
              tabCode: tabCode,
              routePayloadJson: routePayloadJson,
            );
          },
          routePayloadJson: state.preferredRoutePayloadJson,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
```

- [ ] **Step 4: 跑注册表测试和主壳层回归**

Run: `flutter test test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，主壳层现有 builder 注入相关测试不回退

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/shell/presentation/main_shell_page_registry.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_page_registry_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "拆分 MainShell 页面注册表"
```

## 任务 4：抽离控制器，收拢初始化、导航状态和 UI 触发动作

**Files:**
- Create: `frontend/lib/features/shell/presentation/main_shell_controller.dart`
- Create: `frontend/test/widgets/main_shell_controller_test.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`

- [ ] **Step 1: 写失败测试，固定初始化成功、401 退出与 UI 刷新行为**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/shell/presentation/main_shell_controller.dart';

import 'main_shell_test_support.dart';

void main() {
  test('initialize 成功后会写入当前用户、权限快照和菜单', () async {
    final controller = buildMainShellController();

    await controller.initialize();

    expect(controller.state.currentUser?.username, 'tester');
    expect(controller.state.authzSnapshot, isNotNull);
    expect(controller.state.menus.map((item) => item.code), contains('home'));
  });

  test('initialize 遇到 401 会触发 onLogout', () async {
    var logoutCalled = false;
    final controller = buildMainShellController(
      authService: buildAuthService(error: ApiException('unauthorized', 401)),
      onLogout: () {
        logoutCalled = true;
      },
    );

    await controller.initialize();

    expect(logoutCalled, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为控制器文件和构造器不存在而失败**

Run: `flutter test test/widgets/main_shell_controller_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MainShellController'`

- [ ] **Step 3: 实现控制器，并让 `MainShellPage` 只保留生命周期桥接**

```dart
// frontend/lib/features/shell/presentation/main_shell_controller.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_refresh_coordinator.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

class MainShellController extends ChangeNotifier {
  MainShellController({
    required this.session,
    required this.onLogout,
    required AuthService authService,
    required AuthzService authzService,
    required PageCatalogService pageCatalogService,
    required MessageService messageService,
    required HomeDashboardService homeDashboardService,
    required MessageWsService Function({
      required String baseUrl,
      required String accessToken,
      required WsEventCallback onEvent,
      required void Function() onDisconnected,
    }) messageWsServiceFactory,
  })  : _authService = authService,
        _authzService = authzService,
        _pageCatalogService = pageCatalogService,
        _messageService = messageService,
        _homeDashboardService = homeDashboardService,
        _messageWsServiceFactory = messageWsServiceFactory;

  final AppSession session;
  final VoidCallback onLogout;
  final AuthService _authService;
  final AuthzService _authzService;
  final PageCatalogService _pageCatalogService;
  final MessageService _messageService;
  final HomeDashboardService _homeDashboardService;
  final MessageWsService Function({
    required String baseUrl,
    required String accessToken,
    required WsEventCallback onEvent,
    required void Function() onDisconnected,
  }) _messageWsServiceFactory;

  MainShellViewState _state = const MainShellViewState();
  MainShellViewState get state => _state;

  MessageWsService? _wsService;
  MainShellRefreshCoordinator? _refreshCoordinator;

  Future<void> initialize() async {
    _setState(_state.copyWith(loading: true, message: ''));
    try {
      final currentUser = await _authService.getCurrentUser(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      );
      final catalog = await _pageCatalogService.listPageCatalog();
      final snapshot = await _authzService.loadAuthzSnapshot();
      final sortedCatalog = [...catalog]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final tabCodes = sortMainShellTabCodes(
        tabCodesByParent: snapshot.tabCodesByParent,
        catalog: sortedCatalog,
      );
      final menus = buildMainShellMenus(
        catalog: sortedCatalog,
        visibleSidebarCodes: snapshot.visibleSidebarCodes,
        homePageCode: 'home',
        iconForPage: iconForPageForController,
      );
      _setState(
        _state.copyWith(
          loading: false,
          currentUser: currentUser,
          authzSnapshot: snapshot,
          catalog: sortedCatalog,
          tabCodesByParent: tabCodes,
          menus: menus,
        ),
      );
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        onLogout();
        return;
      }
      _setState(
        _state.copyWith(
          loading: false,
          message: '加载当前用户失败：$error',
        ),
      );
    }
  }

  void navigateToPageTarget({
    required String pageCode,
    String? tabCode,
    String? routePayloadJson,
  }) {
    final result = resolveMainShellTarget(
      requestedPageCode: pageCode,
      requestedTabCode: tabCode,
      requestedRoutePayloadJson: routePayloadJson,
      catalog: _state.catalog,
      menus: _state.menus,
    );
    if (!result.hasAccess) {
      return;
    }
    _setState(
      _state.copyWith(
        selectedPageCode: result.pageCode,
        preferredTabCode: result.tabCode,
        preferredRoutePayloadJson: result.routePayloadJson,
      ),
    );
  }

  void _setState(MainShellViewState nextState) {
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshCoordinator?.dispose();
    _wsService?.disconnect();
    super.dispose();
  }
}
```

- [ ] **Step 4: 跑控制器测试与主壳层回归，确认主页面仍只暴露原构造参数**

Run: `flutter test test/widgets/main_shell_controller_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，`MainShellPage` 的现有注入测试保持通过

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/shell/presentation/main_shell_controller.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_controller_test.dart frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart
git commit -m "拆分 MainShell 控制器与初始化编排"
```

## 任务 5：抽离纯视图壳层，收薄 `MainShellPage`

**Files:**
- Create: `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
- Create: `frontend/test/widgets/main_shell_scaffold_test.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 写失败测试，固定菜单选中、角标、错误态和无权限态布局**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/shell/presentation/widgets/main_shell_scaffold.dart';

void main() {
  testWidgets('MainShellScaffold 渲染菜单、消息条和内容区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScaffold(
          state: const MainShellViewState(
            menus: [
              MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
              MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
            ],
            selectedPageCode: 'user',
            unreadCount: 7,
            message: '页面目录加载失败，已使用本地兜底配置。',
          ),
          currentUserDisplayName: '测试用户',
          content: const Text('content'),
          onSelectMenu: (_) {},
          onLogout: () {},
          onRetry: () {},
          showNoAccessPage: false,
          showErrorPage: false,
        ),
      ),
    );

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('页面目录加载失败，已使用本地兜底配置。'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为视图壳层文件不存在而失败**

Run: `flutter test test/widgets/main_shell_scaffold_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MainShellScaffold'`

- [ ] **Step 3: 实现纯视图壳层，并让 `MainShellPage` 收敛为 200 至 300 行外壳**

```dart
// frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    super.key,
    required this.state,
    required this.currentUserDisplayName,
    required this.content,
    required this.onSelectMenu,
    required this.onLogout,
    required this.onRetry,
    required this.showNoAccessPage,
    required this.showErrorPage,
  });

  final MainShellViewState state;
  final String currentUserDisplayName;
  final Widget content;
  final ValueChanged<String> onSelectMenu;
  final VoidCallback onLogout;
  final VoidCallback onRetry;
  final bool showNoAccessPage;
  final bool showErrorPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (showErrorPage) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.message.isEmpty ? '加载失败' : state.message),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (showNoAccessPage) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('当前账号暂无可访问页面'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onLogout, child: const Text('退出登录')),
            ],
          ),
        ),
      );
    }
    final selectedMenuCode = state.menus
        .where((item) => item.code == state.selectedPageCode)
        .map((item) => item.code)
        .firstOrNull ??
        state.menus.first.code;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ZYKJ MES', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(currentUserDisplayName),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.menus.length,
                      itemBuilder: (context, index) {
                        final menu = state.menus[index];
                        final selected = menu.code == selectedMenuCode;
                        return ListTile(
                          key: ValueKey('main-shell-menu-${menu.code}'),
                          selected: selected,
                          leading: menu.code == 'message' && state.unreadCount > 0
                              ? Badge(label: Text('${state.unreadCount}'), child: Icon(menu.icon))
                              : Icon(menu.icon),
                          title: Text(menu.title),
                          onTap: () => onSelectMenu(menu.code),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('退出登录'),
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (state.message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: theme.colorScheme.surfaceContainer,
                      child: Text(state.message),
                    ),
                  Expanded(
                    child: Container(
                      key: ValueKey('main-shell-content-$selectedMenuCode'),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 跑视图壳层测试与主壳层回归，再做静态分析**

Run: `flutter test test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_scaffold_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "拆分 MainShell 视图壳层"
```

## 任务 6：收尾清理与全量回归

**Files:**
- Modify: `frontend/test/widgets/main_shell_page_test.dart`
- Modify: `frontend/test/widgets/main_shell_test_support.dart`

- [ ] **Step 1: 精简主壳测试，只保留壳层级闭环**

```dart
// main_shell_page_test.dart 最终只保留以下几类闭环：
// 1. 主壳页会把用户模块可见页签按目录顺序装配给用户页
// 2. 首页刷新按钮不会重拉目录且会重拉用户与未读数
// 3. 消息未读角标会随着 websocket 事件刷新
// 4. 从消息中心跳转时会落到父模块并带上目标页签和载荷
// 5. 无权限目标跳转会提示并保持当前页面，不会静默回退
```

- [ ] **Step 2: 跑拆分后完整壳层相关回归**

Run: `flutter test test/widgets/main_shell_navigation_test.dart test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，所有测试文件通过

- [ ] **Step 3: 跑入口与登录回归，确认壳层拆分不影响登录后进入主壳**

Run: `flutter test test/widgets/app_bootstrap_page_test.dart test/widget_test.dart test/widgets/login_page_test.dart`

Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add frontend/test/widgets/main_shell_page_test.dart frontend/test/widgets/main_shell_test_support.dart
git commit -m "收敛 MainShell 回归测试边界"
```

- [ ] **Step 5: 最终验证**

Run: `flutter analyze && flutter test test/widgets/app_bootstrap_page_test.dart test/widget_test.dart test/widgets/login_page_test.dart test/widgets/main_shell_navigation_test.dart test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: `No issues found!` 且所有测试文件通过
