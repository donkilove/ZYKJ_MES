# 前端轮询治理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收敛主壳全局权限/未读轮询与消息中心、生产工单查询、个人中心页面级轮询，确保轮询只在前台且当前页面活跃时运行，并补齐可回归测试。

**Architecture:** 以主壳为统一轮询门禁源，增加“应用前后台态 + 当前模块/子页活跃态”双层约束。主壳协调器负责全局轮询的暂停与恢复，模块页和业务页通过新增 `pollingEnabled`/`moduleActive` 输入显式控制页面级 `Timer` 生命周期；消息中心额外移除列表加载后的重复摘要拉取。

**Tech Stack:** Flutter、Dart、`flutter_test`、`WidgetsBindingObserver`、`Timer`

---

## 文件结构

### 需要修改的文件

- `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`
  - 为主壳全局轮询增加启停能力与活跃态门禁。
- `frontend/lib/features/shell/presentation/main_shell_controller.dart`
  - 接入主壳轮询启停，处理应用前后台切换后的即时补拉。
- `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - 在生命周期变更时显式通知控制器，并把当前选中的主模块传给页面注册器。
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 向消息模块、用户模块、生产模块传递活跃态输入。
- `frontend/lib/features/user/presentation/user_page.dart`
  - 将当前 tab 是否活跃传给个人中心页。
- `frontend/lib/features/production/presentation/production_page.dart`
  - 将当前 tab 是否活跃传给生产订单查询页。
- `frontend/lib/features/message/presentation/message_center_page.dart`
  - 引入 `pollingEnabled` 控制轮询；去掉 `_load()` 后的重复摘要拉取。
- `frontend/lib/features/production/presentation/production_order_query_page.dart`
  - 引入 `pollingEnabled` 控制轮询。
- `frontend/lib/features/user/presentation/account_settings_page.dart`
  - 引入 `pollingEnabled` 控制会话轮询。

### 需要修改的测试文件

- `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
- `frontend/test/widgets/main_shell_page_test.dart`
- `frontend/test/widgets/message_center_page_test.dart`
- `frontend/test/widgets/production_order_query_page_test.dart`
- `frontend/test/widgets/account_settings_page_test.dart`

### 计划内不修改的文件

- 后端接口与模型文件
- 与轮询无关的 UI 样式文件
- 其他未涉及 `Timer` 的业务页

## Task 1: 主壳全局轮询启停治理

**Files:**
- Modify: `frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_controller.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Test: `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写主壳协调器的失败测试**

```dart
test('主壳轮询在暂停后不再触发权限与未读刷新', () async {
  var visibilityRefreshCount = 0;
  var unreadRefreshCount = 0;

  final coordinator = MainShellRefreshCoordinator(
    isHomePageVisible: () => true,
    refreshVisibility: ({bool loadCatalog = false, bool silent = false}) async {
      visibilityRefreshCount += 1;
    },
    refreshUnreadCount: () async {
      unreadRefreshCount += 1;
    },
    refreshHomeDashboard: ({bool silent = false}) async {},
    visibilityPollInterval: const Duration(milliseconds: 40),
    unreadPollInterval: const Duration(milliseconds: 40),
  );

  coordinator.startPolling();
  await Future<void>.delayed(const Duration(milliseconds: 55));
  coordinator.setPollingEnabled(false);
  final pausedVisibilityCount = visibilityRefreshCount;
  final pausedUnreadCount = unreadRefreshCount;

  await Future<void>.delayed(const Duration(milliseconds: 80));

  expect(visibilityRefreshCount, pausedVisibilityCount);
  expect(unreadRefreshCount, pausedUnreadCount);
  coordinator.dispose();
});
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/widgets/main_shell_refresh_coordinator_test.dart -r expanded`

Expected: FAIL，报出 `MainShellRefreshCoordinator` 不存在 `setPollingEnabled` 或轮询仍继续触发。

- [ ] **Step 3: 用最小实现给协调器加启停门禁**

```dart
class MainShellRefreshCoordinator {
  bool _pollingEnabled = true;

  void startPolling() {
    _cancelPollingTimers();
    if (!_pollingEnabled) {
      return;
    }
    _visibilityTimer = Timer.periodic(visibilityPollInterval, (_) {
      if (_pollingEnabled) {
        refreshVisibility(silent: true);
      }
    });
    _unreadTimer = Timer.periodic(unreadPollInterval, (_) {
      if (_pollingEnabled) {
        refreshUnreadCount();
      }
    });
  }

  void setPollingEnabled(bool enabled) {
    if (_pollingEnabled == enabled) {
      return;
    }
    _pollingEnabled = enabled;
    if (!enabled) {
      _cancelPollingTimers();
      return;
    }
    startPolling();
  }

  void _cancelPollingTimers() {
    _visibilityTimer?.cancel();
    _unreadTimer?.cancel();
    _visibilityTimer = null;
    _unreadTimer = null;
  }
}
```

- [ ] **Step 4: 补主壳生命周期测试并验证恢复前台会立即补拉**

```dart
testWidgets('主壳从后台恢复时会立即补拉权限与未读', (tester) async {
  final authService = _CountingShellAuthService();
  final messageService = _CountingShellMessageService();

  await _pumpMainShellPage(
    tester,
    authService: authService,
    authzService: _TestShellAuthzService(),
    pageCatalogService: _TestShellPageCatalogService(),
    messageService: messageService,
    onLogout: () {},
  );

  final state = tester.state(find.byType(MainShellPage));
  (state as dynamic).didChangeAppLifecycleState(AppLifecycleState.paused);
  (state as dynamic).didChangeAppLifecycleState(AppLifecycleState.resumed);
  await tester.pumpAndSettle();

  expect(authService.callCount, greaterThanOrEqualTo(2));
  expect(messageService.unreadCountCallCount, greaterThanOrEqualTo(1));
});
```

- [ ] **Step 5: 在控制器和主壳页接入最小生命周期实现**

```dart
class MainShellController extends ChangeNotifier {
  bool _shellPollingEnabled = true;

  void setShellPollingEnabled(bool enabled) {
    if (_shellPollingEnabled == enabled) {
      return;
    }
    _shellPollingEnabled = enabled;
    _refreshCoordinator?.setPollingEnabled(enabled);
  }

  Future<void> handleAppLifecycleChanged(AppLifecycleState state) async {
    final enabled = state == AppLifecycleState.resumed;
    setShellPollingEnabled(enabled);
    if (enabled) {
      await handleAppResumed();
    }
  }
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  unawaited(_controller.handleAppLifecycleChanged(state));
}
```

- [ ] **Step 6: 运行主壳相关测试确认通过**

Run: `flutter test test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_test.dart -r expanded`

Expected: PASS，新增主壳轮询启停测试通过，既有主壳核心测试不回退。

- [ ] **Step 7: 提交这一批主壳轮询治理**

```bash
git add frontend/lib/features/shell/presentation/main_shell_refresh_coordinator.dart frontend/lib/features/shell/presentation/main_shell_controller.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_refresh_coordinator_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "主壳轮询改为按前后台状态启停"
```

## Task 2: 向模块页和业务页传递活跃态

**Files:**
- Modify: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Modify: `frontend/lib/features/user/presentation/user_page.dart`
- Modify: `frontend/lib/features/production/presentation/production_page.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写主壳页集成失败测试，要求当前模块收到活跃态**

```dart
testWidgets('主壳仅向当前模块传递 pollingEnabled', (tester) async {
  String? productionPageText;
  String? userPageText;

  await _pumpMainShellPage(
    tester,
    authService: _TestShellAuthService(),
    authzService: _TestShellAuthzService(
      snapshot: _buildSnapshot(
        visibleSidebarCodes: const ['user', 'production'],
        tabCodesByParent: const {
          'user': ['account_settings'],
          'production': ['production_order_query'],
        },
        moduleItems: [
          _buildModuleItem('user'),
          _buildModuleItem('production'),
        ],
      ),
    ),
    pageCatalogService: _TestShellPageCatalogService(),
    messageService: _TestShellMessageService(),
    userPageBuilder: ({required visibleTabCodes, required capabilityCodes, required session, required onLogout, String? preferredTabCode, String? routePayloadJson, VoidCallback? onVisibilityConfigSaved}) {
      userPageText = 'user-active';
      return const SizedBox.shrink();
    },
    productionPageBuilder: ({required visibleTabCodes, required capabilityCodes, required session, required onLogout, String? preferredTabCode, String? routePayloadJson}) {
      productionPageText = 'production-active';
      return const SizedBox.shrink();
    },
    onLogout: () {},
  );

  expect(userPageText, 'user-active');
  expect(productionPageText, isNull);
});
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/widgets/main_shell_page_test.dart -r expanded`

Expected: FAIL，当前测试拿不到模块活跃态，或者两个模块都被构建。

- [ ] **Step 3: 在页面注册器和模块页上加入活跃态参数**

```dart
typedef MainShellModulePageBuilder =
    Widget Function({
      required AppSession session,
      required VoidCallback onLogout,
      required List<String> visibleTabCodes,
      required Set<String> capabilityCodes,
      required bool moduleActive,
      String? preferredTabCode,
      String? routePayloadJson,
    });

class UserPage extends StatefulWidget {
  const UserPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    required this.moduleActive,
    this.preferredTabCode,
    this.routePayloadJson,
    this.onVisibilityConfigSaved,
  });

  final bool moduleActive;
}
```

- [ ] **Step 4: 把 tab 活跃态继续传给个人中心和订单查询页**

```dart
final isVisible = widget.moduleActive && _currentTabIndex == currentIndex;

AccountSettingsPage(
  session: widget.session,
  onLogout: widget.onLogout,
  canChangePassword: _canChangeMyPassword,
  canViewSession: _canViewMySession,
  pollingEnabled: isVisible,
);

ProductionOrderQueryPage(
  session: widget.session,
  onLogout: widget.onLogout,
  canFirstArticle: _hasPermission(...),
  pollingEnabled: _currentSelectedTabCode() == productionOrderQueryTabCode,
);
```

- [ ] **Step 5: 运行主壳页测试确认模块活跃态链路通过**

Run: `flutter test test/widgets/main_shell_page_test.dart -r expanded`

Expected: PASS，当前模块和当前 tab 的活跃态能传递到目标业务页。

- [ ] **Step 6: 提交模块活跃态传递改动**

```bash
git add frontend/lib/features/shell/presentation/main_shell_page_registry.dart frontend/lib/features/user/presentation/user_page.dart frontend/lib/features/production/presentation/production_page.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "主壳向模块页面传递轮询活跃态"
```

## Task 3: 消息中心轮询门禁与重复请求收口

**Files:**
- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`

- [ ] **Step 1: 先写消息中心失败测试，要求失活时不启动轮询**

```dart
testWidgets('message center 在 pollingEnabled=false 时不会启动轮询', (tester) async {
  final service = _FakeMessageService();

  await _pumpMessageCenterPage(
    tester,
    service: service,
    pollingEnabled: false,
  );

  final initialPage = service.lastPage;
  await tester.pump(const Duration(seconds: 31));
  await tester.pumpAndSettle();

  expect(service.lastPage, initialPage);
});
```

- [ ] **Step 2: 再写恢复活跃即补拉的失败测试**

```dart
testWidgets('message center 从失活切回活跃时立即补拉一次', (tester) async {
  final service = _FakeMessageService();

  await _pumpMessageCenterPage(
    tester,
    service: service,
    pollingEnabled: false,
  );

  final listCallsBefore = service.listCallCount;

  await tester.pumpWidget(
    _buildMessageCenterHost(service: service, pollingEnabled: true),
  );
  await tester.pumpAndSettle();

  expect(service.listCallCount, listCallsBefore + 1);
});
```

- [ ] **Step 3: 运行消息中心测试确认先失败**

Run: `flutter test test/widgets/message_center_page_test.dart -r expanded`

Expected: FAIL，`MessageCenterPage` 还没有 `pollingEnabled`，且现有轮询始终常驻。

- [ ] **Step 4: 用最小实现给消息中心接入轮询门禁并移除重复摘要请求**

```dart
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.pollingEnabled = true,
    this.canPublishAnnouncement = false,
  });

  final bool pollingEnabled;
}

@override
void initState() {
  super.initState();
  _service = widget.service ?? MessageService(widget.session);
  _userService = widget.userService ?? UserService(widget.session);
  _consumeRoutePayload(widget.routePayloadJson, triggerLoad: false);
  _load();
  _syncPollingState(forceRefreshOnEnable: false);
}

@override
void didUpdateWidget(covariant MessageCenterPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.pollingEnabled != oldWidget.pollingEnabled) {
    _syncPollingState(forceRefreshOnEnable: true);
  }
}

void _syncPollingState({required bool forceRefreshOnEnable}) {
  _pollTimer?.cancel();
  if (!widget.pollingEnabled) {
    return;
  }
  if (forceRefreshOnEnable) {
    _load(reset: false);
  }
  _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    _load(reset: false);
  });
}

Future<void> _load({bool reset = true}) async {
  ...
  final summary = MessageSummaryResult(
    totalCount: result.total,
    unreadCount: result.items.where((item) => !item.isRead).length,
    todoUnreadCount: result.items.where((item) => item.messageType == 'todo' && !item.isRead).length,
    urgentUnreadCount: result.items.where((item) => item.priority == 'urgent' && !item.isRead).length,
  );
  widget.onUnreadCountChanged?.call(summary.unreadCount);
  setState(() {
    _allMessageCount = summary.totalCount;
    _unreadCount = summary.unreadCount;
    _todoCount = summary.todoUnreadCount;
    _urgentCount = summary.urgentUnreadCount;
  });
}
```

- [ ] **Step 5: 运行消息中心测试确认通过**

Run: `flutter test test/widgets/message_center_page_test.dart -r expanded`

Expected: PASS，新增活跃态测试通过，既有筛选、跳转、列表行为不回退。

- [ ] **Step 6: 提交消息中心轮询治理**

```bash
git add frontend/lib/features/message/presentation/message_center_page.dart frontend/test/widgets/message_center_page_test.dart
git commit -m "消息中心轮询改为按活跃态运行"
```

## Task 4: 生产工单页与个人中心轮询门禁

**Files:**
- Modify: `frontend/lib/features/production/presentation/production_order_query_page.dart`
- Modify: `frontend/lib/features/user/presentation/account_settings_page.dart`
- Test: `frontend/test/widgets/production_order_query_page_test.dart`
- Test: `frontend/test/widgets/account_settings_page_test.dart`

- [ ] **Step 1: 先写生产工单页失败测试，要求失活时不轮询**

```dart
testWidgets('订单查询页在 pollingEnabled=false 时不会启动定时刷新', (tester) async {
  final service = _FakeProductionOrderQueryPageService();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductionOrderQueryPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          canFirstArticle: true,
          canEndProduction: true,
          canCreateManualRepairOrder: true,
          canCreateAssistAuthorization: true,
          canProxyView: false,
          canExportCsv: false,
          service: service,
          pollingEnabled: false,
          pollInterval: const Duration(milliseconds: 50),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  final callsBefore = service.requestedPages.length;
  await tester.pump(const Duration(milliseconds: 80));
  await tester.pumpAndSettle();

  expect(service.requestedPages.length, callsBefore);
});
```

- [ ] **Step 2: 再写个人中心失败测试，要求失活后不再刷新会话**

```dart
testWidgets('账号设置页在 pollingEnabled=false 时不会启动会话轮询', (tester) async {
  final userService = _FakeUserService();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AccountSettingsPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          canChangePassword: true,
          canViewSession: true,
          pollingEnabled: false,
          userService: userService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final callsBefore = userService.getMySessionCalls;
  await tester.pump(const Duration(seconds: 30));
  await tester.pumpAndSettle();

  expect(userService.getMySessionCalls, callsBefore);
});
```

- [ ] **Step 3: 运行两组测试确认先失败**

Run: `flutter test test/widgets/production_order_query_page_test.dart test/widgets/account_settings_page_test.dart -r expanded`

Expected: FAIL，两个页面都还没有 `pollingEnabled`，且轮询不受活跃态控制。

- [ ] **Step 4: 用最小实现接入页面级轮询门禁**

```dart
class ProductionOrderQueryPage extends StatefulWidget {
  const ProductionOrderQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canFirstArticle,
    required this.canEndProduction,
    required this.canCreateManualRepairOrder,
    required this.canCreateAssistAuthorization,
    required this.canProxyView,
    required this.canExportCsv,
    this.pollingEnabled = true,
    this.pollInterval = const Duration(seconds: 12),
  });

  final bool pollingEnabled;
}

void _syncPollingState({required bool forceRefreshOnEnable}) {
  _pollTimer?.cancel();
  if (!widget.pollingEnabled || widget.pollInterval <= Duration.zero) {
    return;
  }
  if (forceRefreshOnEnable) {
    _loadOrders(silent: true);
  }
  _pollTimer = Timer.periodic(widget.pollInterval, (_) => _loadOrders(silent: true));
}
```

```dart
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canChangePassword,
    required this.canViewSession,
    this.pollingEnabled = true,
  });

  final bool pollingEnabled;
}

void _syncSessionPolling({required bool forceRefreshOnEnable}) {
  _sessionRefreshTimer?.cancel();
  if (!widget.canViewSession || !widget.pollingEnabled) {
    return;
  }
  if (forceRefreshOnEnable) {
    _refreshSession();
  }
  _sessionRefreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => _refreshSession(),
  );
}
```

- [ ] **Step 5: 运行生产页和个人中心测试确认通过**

Run: `flutter test test/widgets/production_order_query_page_test.dart test/widgets/account_settings_page_test.dart -r expanded`

Expected: PASS，新增失活/恢复测试通过，既有业务操作测试不回退。

- [ ] **Step 6: 提交页面级轮询治理**

```bash
git add frontend/lib/features/production/presentation/production_order_query_page.dart frontend/lib/features/user/presentation/account_settings_page.dart frontend/test/widgets/production_order_query_page_test.dart frontend/test/widgets/account_settings_page_test.dart
git commit -m "页面轮询统一改为按活跃态启停"
```

## Task 5: 全链路验证与留痕

**Files:**
- Modify: `evidence/task_log_20260423_frontend_polling_governance.md`
- Modify: `evidence/verification_20260423_frontend_polling_governance.md`
- Test: `frontend/test/widgets/main_shell_refresh_coordinator_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`
- Test: `frontend/test/widgets/production_order_query_page_test.dart`
- Test: `frontend/test/widgets/account_settings_page_test.dart`

- [ ] **Step 1: 运行本轮目标测试集**

Run: `flutter test test/widgets/main_shell_refresh_coordinator_test.dart test/widgets/main_shell_page_test.dart test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/widgets/account_settings_page_test.dart -r expanded`

Expected: PASS，主壳、消息、生产、个人中心相关测试全部通过。

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 3: 更新任务日志中的执行与验证结果**

```md
## 5. 过程记录
- 已完成主壳全局轮询启停治理。
- 已完成消息中心、生产工单查询、个人中心轮询活跃态收敛。
- 已执行目标测试集与 `flutter analyze`。

## 8. 交付判断
- 已完成项：
  - 主壳权限/未读轮询前后台门禁
  - 页面级轮询活跃态门禁
  - 消息中心重复摘要请求收口
  - 自动化测试补齐
```

- [ ] **Step 4: 提交 evidence 收尾**

```bash
git add evidence/task_log_20260423_frontend_polling_governance.md evidence/verification_20260423_frontend_polling_governance.md
git commit -m "补齐前端轮询治理交付留痕"
```

## Self-Review

### Spec coverage

- 主壳全局轮询前后台门禁：Task 1
- 模块/子页活跃态传递：Task 2
- 消息中心重复刷新收口：Task 3
- 生产工单页与个人中心页面级轮询收口：Task 4
- 最终验证与 evidence：Task 5

### Placeholder scan

- 本计划未使用 `TODO`、`TBD`、`待补`、`实现细节略` 等占位语句。
- 每个任务都包含明确文件、测试命令、最小实现示例与提交口径。

### Type consistency

- 主壳协调器统一采用 `setPollingEnabled(bool enabled)`。
- 模块/页面统一采用 `moduleActive` 或 `pollingEnabled` 布尔输入。
- 页面恢复活跃统一采用“先补拉一次，再恢复周期轮询”的语义。
