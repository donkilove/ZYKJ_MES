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

  test('停用主壳全局轮询后不再触发权限与未读刷新', () async {
    var visibilityRefreshCount = 0;
    var unreadRefreshCount = 0;
    final coordinator = MainShellRefreshCoordinator(
      isHomePageVisible: () => true,
      refreshUnreadCount: () async {
        unreadRefreshCount += 1;
      },
      refreshVisibility: ({bool loadCatalog = false, bool silent = false}) async {
        visibilityRefreshCount += 1;
      },
      refreshHomeDashboard: ({bool silent = false}) async {},
      debounceDuration: const Duration(milliseconds: 50),
      unreadPollInterval: const Duration(milliseconds: 80),
      visibilityPollInterval: const Duration(milliseconds: 60),
    );

    coordinator.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(visibilityRefreshCount, greaterThanOrEqualTo(1));
    expect(unreadRefreshCount, greaterThanOrEqualTo(1));

    final visibilityRefreshCountBeforePause = visibilityRefreshCount;
    final unreadRefreshCountBeforePause = unreadRefreshCount;

    coordinator.setGlobalPollingEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 160));

    expect(visibilityRefreshCount, visibilityRefreshCountBeforePause);
    expect(unreadRefreshCount, unreadRefreshCountBeforePause);
    coordinator.dispose();
  });

  test('停用全局轮询时会取消已排队的工作台防抖刷新，重新启用后可再次触发', () async {
    var refreshCount = 0;
    final coordinator = MainShellRefreshCoordinator(
      isHomePageVisible: () => true,
      refreshUnreadCount: () async {},
      refreshVisibility: ({bool loadCatalog = false, bool silent = false}) async {},
      refreshHomeDashboard: ({bool silent = false}) async {
        refreshCount += 1;
      },
      debounceDuration: const Duration(milliseconds: 120),
      unreadPollInterval: const Duration(seconds: 30),
      visibilityPollInterval: const Duration(seconds: 30),
    );

    coordinator.startPolling();
    coordinator.scheduleHomeDashboardRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    coordinator.setGlobalPollingEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 140));

    expect(refreshCount, 0);

    coordinator.setGlobalPollingEnabled(true);
    coordinator.scheduleHomeDashboardRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 140));

    expect(refreshCount, 1);
    coordinator.dispose();
  });
}
