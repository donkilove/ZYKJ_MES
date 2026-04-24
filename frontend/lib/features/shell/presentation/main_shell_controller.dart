import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_refresh_coordinator.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';

class MainShellController extends ChangeNotifier {
  MainShellController({
    required this.session,
    required this.onLogout,
    required AuthService authService,
    required AuthzService authzService,
    required PageCatalogService pageCatalogService,
    required MessageService messageService,
    required HomeDashboardService homeDashboardService,
    SoftwareSettingsController? softwareSettingsController,
    required MessageWsService Function({
      required String baseUrl,
      required String accessToken,
      required WsEventCallback onEvent,
      required void Function() onDisconnected,
    })
    messageWsServiceFactory,
  }) : _authService = authService,
       _authzService = authzService,
       _pageCatalogService = pageCatalogService,
       _messageService = messageService,
       _homeDashboardService = homeDashboardService,
       _softwareSettingsController =
           softwareSettingsController ?? SoftwareSettingsController.memory(),
       _messageWsServiceFactory = messageWsServiceFactory;

  final AppSession session;
  final VoidCallback onLogout;
  final AuthService _authService;
  final AuthzService _authzService;
  final PageCatalogService _pageCatalogService;
  final MessageService _messageService;
  final HomeDashboardService _homeDashboardService;
  final SoftwareSettingsController _softwareSettingsController;
  final MessageWsService Function({
    required String baseUrl,
    required String accessToken,
    required WsEventCallback onEvent,
    required void Function() onDisconnected,
  })
  _messageWsServiceFactory;

  MainShellViewState _state = const MainShellViewState();
  MainShellViewState get state => _state;
  MessageService get messageService => _messageService;
  bool _disposed = false;

  MainShellRefreshCoordinator? _refreshCoordinator;
  MessageWsService? _wsService;

  void attach({
    Duration visibilityPollInterval = const Duration(seconds: 15),
    Duration unreadPollInterval = const Duration(seconds: 30),
    Duration debounceDuration = const Duration(seconds: 2),
  }) {
    _refreshCoordinator ??= MainShellRefreshCoordinator(
      isHomePageVisible: _isHomePageVisible,
      refreshVisibility: refreshVisibility,
      refreshUnreadCount: refreshUnreadCount,
      refreshHomeDashboard: refreshHomeDashboard,
      visibilityPollInterval: visibilityPollInterval,
      unreadPollInterval: unreadPollInterval,
      debounceDuration: debounceDuration,
    );
    _refreshCoordinator!.startPolling();

    _wsService ??= _messageWsServiceFactory(
      baseUrl: session.baseUrl,
      accessToken: session.accessToken,
      onEvent: _onWsEvent,
      onDisconnected: () {},
    );
    _wsService!.connect();
  }

  Future<void> handleAppResumed() async {
    await _refreshCoordinator?.handleAppResumed();
    _wsService?.reconnect();
  }

  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        _refreshCoordinator?.setGlobalPollingEnabled(true);
        await handleAppResumed();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _refreshCoordinator?.setGlobalPollingEnabled(false);
        return;
    }
  }

  Future<void> initialize() async {
    _setState(_state.copyWith(loading: true, message: ''));

    late final CurrentUser currentUser;
    try {
      currentUser = await _authService.getCurrentUser(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        onLogout();
        return;
      }
      _setState(
        _state.copyWith(
          loading: false,
          message: '加载当前用户失败：${_errorMessage(error)}',
        ),
      );
      return;
    }

    _setState(_state.copyWith(currentUser: currentUser));

    await refreshVisibility(
      loadCatalog: true,
      applyLaunchTargetPreference: true,
    );
    await refreshHomeDashboard(silent: true);
    _setState(_state.copyWith(loading: false));
  }

  Future<void> refreshVisibility({
    bool loadCatalog = false,
    bool silent = false,
    bool applyLaunchTargetPreference = false,
  }) async {
    var catalog = _state.catalog;
    var usedFallbackCatalog = false;

    if (loadCatalog || catalog.isEmpty) {
      try {
        catalog = await _pageCatalogService.listPageCatalog();
      } catch (_) {
        catalog = fallbackPageCatalog;
        usedFallbackCatalog = true;
      }
    }

    try {
      final snapshot = await _authzService.loadAuthzSnapshot();
      final sortedCatalog = [...catalog]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final sortedTabCodes = sortMainShellTabCodes(
        tabCodesByParent: snapshot.tabCodesByParent,
        catalog: sortedCatalog,
      );
      final menus = buildMainShellMenus(
        catalog: sortedCatalog,
        visibleSidebarCodes: snapshot.visibleSidebarCodes,
        homePageCode: 'home',
        iconForPage: _iconForPage,
      );
      var selectedPageCode = _state.selectedPageCode;
      final rememberedPageCode = _rememberedLaunchPageCode(menus);
      String? preferredTabCode = _state.preferredTabCode;
      String? preferredRoutePayloadJson = _state.preferredRoutePayloadJson;
      var message = _state.message;

      if (menus.isEmpty) {
        selectedPageCode = 'home';
        preferredTabCode = null;
        preferredRoutePayloadJson = null;
      } else if (!menus.any((item) => item.code == selectedPageCode)) {
        selectedPageCode = rememberedPageCode ?? menus.first.code;
        preferredTabCode = null;
        preferredRoutePayloadJson = null;
        final fallbackTitle = menus
            .where((item) => item.code == selectedPageCode)
            .map((item) => item.title)
            .firstOrNull;
        if (fallbackTitle != null) {
          message = '当前页面权限已变更，已切换到$fallbackTitle';
        }
      } else if (applyLaunchTargetPreference &&
          selectedPageCode == 'home' &&
          rememberedPageCode != null) {
        selectedPageCode = rememberedPageCode;
        preferredTabCode = null;
        preferredRoutePayloadJson = null;
      } else if (!silent) {
        message = '';
      }

      if (usedFallbackCatalog) {
        message = '页面目录加载失败，已使用本地兜底配置。';
      }

      _setState(
        _state.copyWith(
          authzSnapshot: snapshot,
          catalog: sortedCatalog,
          tabCodesByParent: sortedTabCodes,
          menus: menus,
          selectedPageCode: selectedPageCode,
          preferredTabCode: preferredTabCode,
          preferredRoutePayloadJson: preferredRoutePayloadJson,
          message: message,
        ),
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        onLogout();
        return;
      }
      if (!silent) {
        _setState(_state.copyWith(message: '加载权限快照失败：${_errorMessage(error)}'));
      }
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _messageService.getUnreadCount();
      _setState(_state.copyWith(unreadCount: count));
    } catch (_) {}
  }

  Future<void> refreshHomeDashboard({bool silent = false}) async {
    if (!_isHomePageVisible()) {
      return;
    }
    if (_state.homeDashboardLoading) {
      _setState(_state.copyWith(homeDashboardRefreshPending: true));
      return;
    }

    _setState(
      _state.copyWith(
        homeDashboardLoading: true,
        homeDashboardRefreshPending: false,
      ),
    );

    try {
      final data = await _homeDashboardService.load();
      _setState(_state.copyWith(homeDashboardData: data));
    } catch (error) {
      if (!silent) {
        _setState(
          _state.copyWith(message: '加载首页工作台失败：${_errorMessage(error)}'),
        );
      }
    } finally {
      final shouldRefreshAgain = _state.homeDashboardRefreshPending;
      _setState(
        _state.copyWith(
          homeDashboardLoading: false,
          homeDashboardRefreshPending: false,
        ),
      );
      if (shouldRefreshAgain && _isHomePageVisible()) {
        refreshHomeDashboard(silent: true);
      }
    }
  }

  Future<void> refreshShellDataFromUi({bool loadCatalog = true}) async {
    if (_state.manualRefreshing) {
      return;
    }

    _setState(_state.copyWith(manualRefreshing: true, message: ''));

    try {
      final currentUserFuture = _authService.getCurrentUser(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      );
      final refreshVisibilityFuture = refreshVisibility(
        loadCatalog: loadCatalog,
      );
      final refreshUnreadFuture = refreshUnreadCount();
      final refreshDashboardFuture = refreshHomeDashboard(silent: true);

      final currentUser = await currentUserFuture;

      _setState(_state.copyWith(currentUser: currentUser));
      await Future.wait<void>([
        refreshVisibilityFuture,
        refreshUnreadFuture,
        refreshDashboardFuture,
      ]);
      _setState(_state.copyWith(lastManualRefreshAt: DateTime.now()));
    } catch (error) {
      if (_isUnauthorized(error)) {
        onLogout();
        return;
      }
      _setState(_state.copyWith(message: '刷新失败：${_errorMessage(error)}'));
    } finally {
      _setState(_state.copyWith(manualRefreshing: false));
    }
  }

  bool navigateToPageTarget({
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
      return false;
    }
    _setState(
      _state.copyWith(
        selectedPageCode: result.pageCode,
        activeUtilityCode: null,
        preferredTabCode: result.tabCode,
        preferredRoutePayloadJson: result.routePayloadJson,
      ),
    );
    if (result.pageCode != 'home') {
      unawaited(
        _softwareSettingsController.rememberLastVisitedPageCode(
          result.pageCode,
        ),
      );
    }
    return true;
  }

  void selectMenu(String pageCode) {
    if (_state.selectedPageCode == pageCode &&
        _state.activeUtilityCode == null) {
      return;
    }
    if (_state.activeUtilityCode != null &&
        _state.selectedPageCode == pageCode) {
      _setState(_state.copyWith(activeUtilityCode: null));
      return;
    }
    navigateToPageTarget(pageCode: pageCode);
  }

  void openSoftwareSettings() {
    if (_state.activeUtilityCode == softwareSettingsUtilityCode) {
      return;
    }
    _setState(_state.copyWith(activeUtilityCode: softwareSettingsUtilityCode));
  }

  void openPluginHost() {
    if (_state.activeUtilityCode == pluginHostUtilityCode) {
      return;
    }
    _setState(_state.copyWith(activeUtilityCode: pluginHostUtilityCode));
  }

  String? homeRefreshStatusText() {
    if (_state.manualRefreshing) {
      return '正在刷新业务数据...';
    }
    final value = _state.lastManualRefreshAt;
    if (value == null) {
      return null;
    }
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '上次刷新：$hour:$minute:$second';
  }

  void updateUnreadCount(int count) {
    _setState(_state.copyWith(unreadCount: count));
  }

  void _onWsEvent(WsEvent event) {
    if (event.event == 'connected' || event.event == 'unread_count_changed') {
      final count = event.unreadCount;
      if (count != null) {
        updateUnreadCount(count);
      }
      if (event.event == 'unread_count_changed') {
        _refreshCoordinator?.scheduleHomeDashboardRefresh();
      }
      return;
    }

    if (event.event == 'message_read_state_changed') {
      final count = event.unreadCount;
      _setState(
        _state.copyWith(
          unreadCount: count ?? _state.unreadCount,
          messageRefreshTick: _state.messageRefreshTick + 1,
        ),
      );
      _refreshCoordinator?.scheduleHomeDashboardRefresh();
      return;
    }

    if (event.event == 'message_created') {
      final count = event.unreadCount;
      _setState(
        _state.copyWith(
          unreadCount: count ?? _state.unreadCount,
          messageRefreshTick: _state.messageRefreshTick + 1,
        ),
      );
      if (count == null) {
        refreshUnreadCount();
      }
      _refreshCoordinator?.scheduleHomeDashboardRefresh();
    }
  }

  bool _isHomePageVisible() {
    return _state.activeUtilityCode == null &&
        _state.selectedPageCode == 'home' &&
        _state.menus.any((item) => item.code == 'home');
  }

  String? _rememberedLaunchPageCode(List<MainShellMenuItem> menus) {
    final settings = _softwareSettingsController.settings;
    if (settings.launchTargetPreference !=
        AppLaunchTargetPreference.lastVisitedModule) {
      return null;
    }
    final rememberedPageCode = settings.lastVisitedPageCode;
    if (rememberedPageCode == null || rememberedPageCode == 'home') {
      return null;
    }
    final hasAccess = menus.any((item) => item.code == rememberedPageCode);
    return hasAccess ? rememberedPageCode : null;
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  IconData _iconForPage(String pageCode) {
    switch (pageCode) {
      case 'home':
        return Icons.home_rounded;
      case 'user':
        return Icons.group_rounded;
      case 'product':
        return Icons.inventory_2_rounded;
      case 'equipment':
        return Icons.precision_manufacturing_rounded;
      case 'production':
        return Icons.factory_rounded;
      case 'quality':
        return Icons.verified_user_rounded;
      case 'craft':
        return Icons.route_rounded;
      case 'message':
        return Icons.notifications_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  void _setState(MainShellViewState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshCoordinator?.dispose();
    _wsService?.disconnect();
    super.dispose();
  }
}
