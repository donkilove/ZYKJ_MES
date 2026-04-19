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
