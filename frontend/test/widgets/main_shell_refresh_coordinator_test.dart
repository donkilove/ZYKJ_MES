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
