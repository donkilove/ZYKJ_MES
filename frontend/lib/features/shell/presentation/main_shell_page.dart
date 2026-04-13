import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';

import 'package:mes_client/core/models/authz_models.dart';

import 'package:mes_client/core/models/current_user.dart';

import 'package:mes_client/features/message/models/message_models.dart';

import 'package:mes_client/core/models/page_catalog_models.dart';

import 'package:mes_client/core/network/api_exception.dart';

import 'package:mes_client/features/auth/services/authz_service.dart';

import 'package:mes_client/features/auth/services/auth_service.dart';

import 'package:mes_client/features/message/services/message_service.dart';

import 'package:mes_client/features/message/services/message_ws_service.dart';

import 'package:mes_client/core/services/page_catalog_service.dart';

import 'package:mes_client/features/craft/presentation/craft_page.dart';

import 'package:mes_client/features/equipment/presentation/equipment_page.dart';

import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

import 'package:mes_client/features/shell/presentation/home_page.dart';

import 'package:mes_client/features/shell/services/home_dashboard_service.dart';

import 'package:mes_client/features/message/presentation/message_center_page.dart';

import 'package:mes_client/features/product/presentation/product_page.dart';

import 'package:mes_client/features/production/presentation/production_page.dart';

import 'package:mes_client/features/quality/presentation/quality_page.dart';

import 'package:mes_client/features/user/presentation/user_page.dart';

const String _homePageCode = 'home';

const String _userPageCode = 'user';

const String _productPageCode = 'product';

const String _equipmentPageCode = 'equipment';

const String _productionPageCode = 'production';

const String _qualityPageCode = 'quality';

const String _craftPageCode = 'craft';

const String _messagePageCode = 'message';

const Duration _visibilityRefreshInterval = Duration(seconds: 15);

const Duration _unreadPollInterval = Duration(seconds: 30);

const Duration _homeDashboardRefreshDebounceDuration = Duration(seconds: 2);

class _ShellMenuItem {
  const _ShellMenuItem({
    required this.code,

    required this.title,

    required this.icon,
  });

  final String code;

  final String title;

  final IconData icon;
}

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,

    required this.session,

    required this.onLogout,

    this.messageWsServiceFactory,
    this.authService,
    this.authzService,
    this.pageCatalogService,
    this.messageService,
    this.homeDashboardService,
    this.userPageBuilder,
    this.productPageBuilder,
    this.equipmentPageBuilder,
    this.productionPageBuilder,
    this.qualityPageBuilder,
    this.craftPageBuilder,
  });

  final AppSession session;

  final VoidCallback onLogout;

  final MessageWsService Function({
    required String baseUrl,
    required String accessToken,
    required WsEventCallback onEvent,
    required void Function() onDisconnected,
  })?
  messageWsServiceFactory;

  final AuthService? authService;
  final AuthzService? authzService;
  final PageCatalogService? pageCatalogService;
  final MessageService? messageService;
  final HomeDashboardService? homeDashboardService;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
    VoidCallback? onVisibilityConfigSaved,
  })?
  userPageBuilder;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
  })?
  productPageBuilder;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
  })?
  equipmentPageBuilder;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
  })?
  productionPageBuilder;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
  })?
  qualityPageBuilder;
  final Widget Function({
    required AppSession session,
    required VoidCallback onLogout,
    required List<String> visibleTabCodes,
    required Set<String> capabilityCodes,
    String? preferredTabCode,
    String? routePayloadJson,
  })?
  craftPageBuilder;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with WidgetsBindingObserver {
  late final AuthService _authService;
  late final AuthzService _authzService;

  late final PageCatalogService _pageCatalogService;

  late final MessageService _messageService;
  late final HomeDashboardService _homeDashboardService;

  MessageWsService? _wsService;

  Timer? _visibilityTimer;

  Timer? _unreadPollTimer;
  Timer? _homeDashboardRefreshDebounce;

  bool _refreshingVisibility = false;

  bool _loading = true;

  String _message = '';

  int _messageRefreshTick = 0;

  CurrentUser? _currentUser;

  AuthzSnapshotResult? _authzSnapshot;

  List<PageCatalogItem> _catalog = fallbackPageCatalog;

  Map<String, List<String>> _tabCodesByParent = const {};

  List<_ShellMenuItem> _menus = const [];

  String _selectedPageCode = _homePageCode;

  int _unreadCount = 0;

  String? _preferredTabCode;

  String? _preferredRoutePayloadJson;

  bool _manualRefreshing = false;
  bool _homeDashboardLoading = false;
  bool _homeDashboardRefreshPending = false;

  DateTime? _lastManualRefreshAt;
  HomeDashboardData? _homeDashboardData;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authService = widget.authService ?? AuthService();
    _authzService = widget.authzService ?? AuthzService(widget.session);
    _pageCatalogService =
        widget.pageCatalogService ?? PageCatalogService(widget.session);
    _messageService = widget.messageService ?? MessageService(widget.session);
    _homeDashboardService =
        widget.homeDashboardService ?? HomeDashboardService(widget.session);

    _loadCurrentUserAndVisibility();

    _startVisibilityPolling();
    _startUnreadPolling();
    _initWs();
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _unreadPollTimer?.cancel();
    _homeDashboardRefreshDebounce?.cancel();
    _wsService?.disconnect();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibility(silent: true);
      _wsService?.reconnect();
      _refreshUnreadCount();
    }
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  void _initWs() {
    final factory = widget.messageWsServiceFactory;
    _wsService = factory != null
        ? factory(
            baseUrl: widget.session.baseUrl,
            accessToken: widget.session.accessToken,
            onEvent: _onWsEvent,
            onDisconnected: () {},
          )
        : MessageWsService(
            baseUrl: widget.session.baseUrl,
            accessToken: widget.session.accessToken,
            onEvent: _onWsEvent,
            onDisconnected: () {},
          );
    _wsService!.connect();
  }

  void _onWsEvent(WsEvent event) {
    if (!mounted) return;
    if (event.event == 'connected' || event.event == 'unread_count_changed') {
      final count = event.unreadCount;
      if (count != null) {
        setState(() => _unreadCount = count);
      }
      if (event.event == 'unread_count_changed') {
        _scheduleHomeDashboardRefresh();
      }
    } else if (event.event == 'message_read_state_changed') {
      final count = event.unreadCount;
      setState(() {
        if (count != null) {
          _unreadCount = count;
        }
        _messageRefreshTick += 1;
      });
      _scheduleHomeDashboardRefresh();
    } else if (event.event == 'message_created') {
      final count = event.unreadCount;
      if (count != null) {
        setState(() {
          _unreadCount = count;
          _messageRefreshTick += 1;
        });
      } else {
        setState(() => _messageRefreshTick += 1);
        _refreshUnreadCount();
      }
      _scheduleHomeDashboardRefresh();
    }
  }

  void _startUnreadPolling() {
    _unreadPollTimer?.cancel();
    _unreadPollTimer = Timer.periodic(_unreadPollInterval, (_) {
      _refreshUnreadCount();
    });
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await _messageService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString();
  }

  String _formatClockTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String? _homeRefreshStatusText() {
    if (_manualRefreshing) {
      return '正在刷新业务数据...';
    }
    if (_lastManualRefreshAt == null) {
      return null;
    }
    return '上次刷新：${_formatClockTime(_lastManualRefreshAt!)}';
  }

  IconData _iconForPage(String pageCode) {
    switch (pageCode) {
      case _homePageCode:
        return Icons.home_rounded;

      case _userPageCode:
        return Icons.group_rounded;

      case _productPageCode:
        return Icons.inventory_2_rounded;

      case _equipmentPageCode:
        return Icons.precision_manufacturing_rounded;

      case _productionPageCode:
        return Icons.factory_rounded;

      case _qualityPageCode:
        return Icons.verified_user_rounded;

      case _craftPageCode:
        return Icons.route_rounded;

      case _messagePageCode:
        return Icons.notifications_rounded;

      default:
        return Icons.article_outlined;
    }
  }

  List<_ShellMenuItem> _buildMenus({
    required List<PageCatalogItem> catalog,

    required List<String> visibleSidebarCodes,
  }) {
    final visibleCodeSet = visibleSidebarCodes.toSet();

    final sidebarPages =
        catalog.where((item) => item.pageType == 'sidebar').toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final items = <_ShellMenuItem>[];

    final homeCatalogItem = sidebarPages
        .where((item) => item.code == _homePageCode)
        .firstOrNull;

    for (final page in sidebarPages) {
      if (page.code == _homePageCode) {
        continue;
      }

      if (!page.alwaysVisible && !visibleCodeSet.contains(page.code)) {
        continue;
      }

      items.add(
        _ShellMenuItem(
          code: page.code,

          title: page.name,

          icon: _iconForPage(page.code),
        ),
      );
    }

    if (items.isNotEmpty || visibleCodeSet.contains(_homePageCode)) {
      items.insert(
        0,

        _ShellMenuItem(
          code: _homePageCode,

          title: homeCatalogItem?.name ?? '首页',

          icon: _iconForPage(_homePageCode),
        ),
      );
    }

    return items;
  }

  Map<String, List<String>> _sortTabsByCatalog(
    Map<String, List<String>> tabCodesByParent,

    List<PageCatalogItem> catalog,
  ) {
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

  void _startVisibilityPolling() {
    _visibilityTimer?.cancel();

    _visibilityTimer = Timer.periodic(_visibilityRefreshInterval, (_) {
      _refreshVisibility(silent: true);
    });
  }

  Future<void> _loadCurrentUserAndVisibility() async {
    setState(() {
      _loading = true;

      _message = '';
    });

    try {
      final currentUser = await _authService.getCurrentUser(
        baseUrl: widget.session.baseUrl,

        accessToken: widget.session.accessToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = currentUser;
      });

      await _refreshVisibility(loadCatalog: true);
      await _refreshHomeDashboard(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorized(error)) {
        widget.onLogout();

        return;
      }

      setState(() {
        _message = '加载当前用户失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshVisibility({
    bool loadCatalog = false,

    bool silent = false,
  }) async {
    if (_refreshingVisibility) {
      return;
    }

    _refreshingVisibility = true;

    try {
      var catalog = _catalog;

      var usedFallbackCatalog = false;

      if (loadCatalog || catalog.isEmpty) {
        try {
          catalog = await _pageCatalogService.listPageCatalog();
        } catch (_) {
          catalog = fallbackPageCatalog;

          usedFallbackCatalog = true;
        }
      }

      final snapshot = await _authzService.loadAuthzSnapshot();

      final sortedCatalog = [...catalog]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final sortedTabCodes = _sortTabsByCatalog(
        snapshot.tabCodesByParent,

        sortedCatalog,
      );

      final menus = _buildMenus(
        catalog: sortedCatalog,

        visibleSidebarCodes: snapshot.visibleSidebarCodes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        String? navigationAdjustedMessage;
        _authzSnapshot = snapshot;
        _catalog = sortedCatalog;

        _tabCodesByParent = sortedTabCodes;

        _menus = menus;

        if (_menus.isEmpty) {
          _selectedPageCode = _homePageCode;
          _preferredTabCode = null;
          _preferredRoutePayloadJson = null;
        } else if (!_menus.any((item) => item.code == _selectedPageCode)) {
          final fallbackMenu = _menus.first;
          _selectedPageCode = _menus.first.code;
          _preferredTabCode = null;
          _preferredRoutePayloadJson = null;
          navigationAdjustedMessage = '当前页面权限已变更，已切换到${fallbackMenu.title}';
        }

        if (usedFallbackCatalog) {
          _message = '页面目录加载失败，已使用本地兜底配置。';
        } else if (navigationAdjustedMessage != null) {
          _message = navigationAdjustedMessage;
        } else if (!silent) {
          _message = '';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorized(error)) {
        widget.onLogout();

        return;
      }

      if (!silent) {
        setState(() {
          _message = '加载权限快照失败：${_errorMessage(error)}';
        });
      }
    } finally {
      _refreshingVisibility = false;
    }
  }

  Future<void> _handleVisibilityConfigSaved() async {
    await _refreshVisibility(loadCatalog: false);
  }

  bool _isHomePageVisible() {
    return _selectedPageCode == _homePageCode &&
        _menus.any((item) => item.code == _homePageCode);
  }

  Future<void> _refreshHomeDashboard({bool silent = false}) async {
    if (!mounted) {
      return;
    }
    if (!_isHomePageVisible()) {
      return;
    }
    if (_homeDashboardLoading) {
      _homeDashboardRefreshPending = true;
      return;
    }

    _homeDashboardLoading = true;
    try {
      final data = await _homeDashboardService.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _homeDashboardData = data;
      });
    } catch (error) {
      if (!mounted || silent) {
        return;
      }
      setState(() {
        _message = '加载首页工作台失败：${_errorMessage(error)}';
      });
    } finally {
      _homeDashboardLoading = false;
      if (_homeDashboardRefreshPending) {
        _homeDashboardRefreshPending = false;
        if (mounted && _isHomePageVisible()) {
          unawaited(_refreshHomeDashboard(silent: true));
        }
      }
    }
  }

  void _scheduleHomeDashboardRefresh() {
    if (!_isHomePageVisible()) {
      return;
    }
    _homeDashboardRefreshDebounce?.cancel();
    _homeDashboardRefreshDebounce = Timer(
      _homeDashboardRefreshDebounceDuration,
      () {
        _refreshHomeDashboard(silent: true);
      },
    );
  }

  List<String> _visibleUserTabCodes() {
    final tabCodes = _tabCodesByParent[_userPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleProductTabCodes() {
    final tabCodes = _tabCodesByParent[_productPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleEquipmentTabCodes() {
    final tabCodes = _tabCodesByParent[_equipmentPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleProductionTabCodes() {
    final tabCodes = _tabCodesByParent[_productionPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleQualityTabCodes() {
    final tabCodes = _tabCodesByParent[_qualityPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleCraftTabCodes() {
    final tabCodes = _tabCodesByParent[_craftPageCode] ?? const <String>[];

    final catalogCodes = _catalog.map((item) => item.code).toSet();

    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleTabCodesForPage(String pageCode) {
    switch (pageCode) {
      case _userPageCode:
        return _visibleUserTabCodes();
      case _productPageCode:
        return _visibleProductTabCodes();
      case _equipmentPageCode:
        return _visibleEquipmentTabCodes();
      case _productionPageCode:
        return _visibleProductionTabCodes();
      case _qualityPageCode:
        return _visibleQualityTabCodes();
      case _craftPageCode:
        return _visibleCraftTabCodes();
      default:
        return const <String>[];
    }
  }

  String? _defaultTabCodeForPage(String pageCode) {
    final tabCodes = _visibleTabCodesForPage(pageCode);
    if (tabCodes.isEmpty) {
      return null;
    }
    return tabCodes.first;
  }

  String? _defaultRoutePayloadJsonForTab(String? tabCode) {
    if (tabCode == null || tabCode.isEmpty) {
      return null;
    }
    return '{"target_tab_code":"$tabCode"}';
  }

  List<HomeQuickJumpEntry> _buildHomeQuickJumps() {
    final entries = <HomeQuickJumpEntry>[];
    for (final menu in _menus) {
      if (menu.code == _homePageCode) {
        continue;
      }
      final defaultTabCode = _defaultTabCodeForPage(menu.code);
      entries.add(
        HomeQuickJumpEntry(
          pageCode: menu.code,
          title: menu.title,
          icon: menu.icon,
          tabCode: defaultTabCode,
          routePayloadJson: _defaultRoutePayloadJsonForTab(defaultTabCode),
        ),
      );
    }
    return entries;
  }

  void _showNoAccessSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('您没有访问该页面的权限')));
  }

  void _navigateToPageTarget(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
    bool showDeniedMessage = true,
  }) {
    if (!mounted) {
      return;
    }

    var resolvedPageCode = pageCode;
    var resolvedTabCode = tabCode;

    final catalogItem = _catalog
        .where((item) => item.code == pageCode)
        .firstOrNull;
    if (catalogItem != null && catalogItem.pageType == 'tab') {
      resolvedPageCode = catalogItem.parentCode ?? pageCode;
      resolvedTabCode ??= pageCode;
    }

    final hasAccess = _menus.any((menu) => menu.code == resolvedPageCode);
    if (!hasAccess) {
      if (showDeniedMessage) {
        _showNoAccessSnackBar();
      }
      return;
    }

    setState(() {
      _selectedPageCode = resolvedPageCode;
      _preferredTabCode = resolvedTabCode;
      _preferredRoutePayloadJson = routePayloadJson;
    });
  }

  Future<void> _refreshShellDataFromUi({bool loadCatalog = true}) async {
    if (_manualRefreshing) {
      return;
    }

    setState(() {
      _manualRefreshing = true;
      _message = '';
    });

    try {
      final currentUserFuture = _authService.getCurrentUser(
        baseUrl: widget.session.baseUrl,
        accessToken: widget.session.accessToken,
      );
      final refreshVisibilityFuture = _refreshVisibility(
        loadCatalog: loadCatalog,
      );
      final refreshUnreadFuture = _refreshUnreadCount();
      final refreshDashboardFuture = _refreshHomeDashboard(silent: true);

      final currentUser = await currentUserFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = currentUser;
      });

      await Future.wait<void>([
        refreshVisibilityFuture,
        refreshUnreadFuture,
        refreshDashboardFuture,
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _lastManualRefreshAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }

      setState(() {
        _message = '刷新失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _manualRefreshing = false;
        });
      }
    }
  }

  Set<String> _capabilityCodesForModule(String moduleCode) {
    return _authzSnapshot?.capabilityCodesForModule(moduleCode) ??
        const <String>{};
  }

  Widget _buildContent(String pageCode) {
    switch (pageCode) {
      case _homePageCode:
        return HomePage(
          currentUser: _currentUser!,
          shortcuts: _buildHomeQuickJumps(),
          dashboardData: _homeDashboardData,
          onNavigateToPage:
              (pageCode, {String? tabCode, String? routePayloadJson}) {
                _navigateToPageTarget(
                  pageCode,
                  tabCode: tabCode,
                  routePayloadJson: routePayloadJson,
                );
              },
          onRefresh: () => _refreshShellDataFromUi(loadCatalog: false),
          refreshing: _manualRefreshing,
          refreshStatusText: _homeRefreshStatusText(),
        );

      case _userPageCode:
        final builder = widget.userPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleUserTabCodes(),
                capabilityCodes: _capabilityCodesForModule('user'),
                preferredTabCode: _selectedPageCode == _userPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _userPageCode
                    ? _preferredRoutePayloadJson
                    : null,
                onVisibilityConfigSaved: () {
                  _handleVisibilityConfigSaved();
                },
              )
            : UserPage(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleUserTabCodes(),
                capabilityCodes: _capabilityCodesForModule('user'),
                preferredTabCode: _selectedPageCode == _userPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _userPageCode
                    ? _preferredRoutePayloadJson
                    : null,
                onVisibilityConfigSaved: () {
                  _handleVisibilityConfigSaved();
                },
              );

      case _productPageCode:
        final builder = widget.productPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleProductTabCodes(),
                capabilityCodes: _capabilityCodesForModule('product'),
                preferredTabCode: _selectedPageCode == _productPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _productPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              )
            : ProductPage(
                session: widget.session,

                onLogout: widget.onLogout,

                visibleTabCodes: _visibleProductTabCodes(),

                capabilityCodes: _capabilityCodesForModule('product'),

                preferredTabCode: _selectedPageCode == _productPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _productPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              );

      case _equipmentPageCode:
        final builder = widget.equipmentPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleEquipmentTabCodes(),
                capabilityCodes: _capabilityCodesForModule('equipment'),
                preferredTabCode: _selectedPageCode == _equipmentPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _equipmentPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              )
            : EquipmentPage(
                session: widget.session,

                onLogout: widget.onLogout,

                visibleTabCodes: _visibleEquipmentTabCodes(),

                capabilityCodes: _capabilityCodesForModule('equipment'),

                preferredTabCode: _selectedPageCode == _equipmentPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _equipmentPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              );

      case _productionPageCode:
        final builder = widget.productionPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleProductionTabCodes(),
                capabilityCodes: _capabilityCodesForModule('production'),
                preferredTabCode: _selectedPageCode == _productionPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _productionPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              )
            : ProductionPage(
                session: widget.session,

                onLogout: widget.onLogout,

                visibleTabCodes: _visibleProductionTabCodes(),

                capabilityCodes: _capabilityCodesForModule('production'),

                preferredTabCode: _selectedPageCode == _productionPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _productionPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              );

      case _qualityPageCode:
        final builder = widget.qualityPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleQualityTabCodes(),
                capabilityCodes: _capabilityCodesForModule('quality'),
                preferredTabCode: _selectedPageCode == _qualityPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _qualityPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              )
            : QualityPage(
                session: widget.session,

                onLogout: widget.onLogout,

                visibleTabCodes: _visibleQualityTabCodes(),

                capabilityCodes: _capabilityCodesForModule('quality'),

                preferredTabCode: _selectedPageCode == _qualityPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _qualityPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              );

      case _craftPageCode:
        final builder = widget.craftPageBuilder;
        return builder != null
            ? builder(
                session: widget.session,
                onLogout: widget.onLogout,
                visibleTabCodes: _visibleCraftTabCodes(),
                capabilityCodes: _capabilityCodesForModule('craft'),
                preferredTabCode: _selectedPageCode == _craftPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _craftPageCode
                    ? _preferredRoutePayloadJson
                    : null,
              )
            : CraftPage(
                session: widget.session,

                onLogout: widget.onLogout,

                visibleTabCodes: _visibleCraftTabCodes(),

                capabilityCodes: _capabilityCodesForModule('craft'),
                preferredTabCode: _selectedPageCode == _craftPageCode
                    ? _preferredTabCode
                    : null,
                routePayloadJson: _selectedPageCode == _craftPageCode
                    ? _preferredRoutePayloadJson
                    : null,
                onNavigateToPage: (pageCode) {
                  _navigateToPageTarget(pageCode);
                },
              );

      case _messagePageCode:
        final messageCapabilityCodes = _capabilityCodesForModule('message');
        return MessageCenterPage(
          session: widget.session,
          service: _messageService,
          onLogout: widget.onLogout,
          canPublishAnnouncement: messageCapabilityCodes.contains(
            'feature.message.announcement.publish',
          ),
          canViewDetail: messageCapabilityCodes.contains(
            'feature.message.detail.view',
          ),
          // 真实跳转能力以 jump-target 接口返回为准，避免旧权限快照缺码时前端整段拦截。
          canUseJump: true,
          refreshTick: _messageRefreshTick,
          onUnreadCountChanged: (count) {
            if (mounted) setState(() => _unreadCount = count);
          },
          onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
            _navigateToPageTarget(
              pageCode,
              tabCode: tabCode,
              routePayloadJson: routePayloadJson,
            );
          },
          routePayloadJson: _selectedPageCode == _messagePageCode
              ? _preferredRoutePayloadJson
              : null,
        );

      default:
        return Center(child: Text('页面暂未实现：$pageCode'));
    }
  }

  Widget _buildNoAccessPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),

        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(Icons.block, size: 40),

                const SizedBox(height: 12),

                const Text('当前账号暂无可访问页面'),

                const SizedBox(height: 8),

                const Text('请联系系统管理员分配页面可见权限'),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _manualRefreshing
                            ? null
                            : () => _refreshShellDataFromUi(),

                        child: const Text('刷新'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onLogout,

                        child: const Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),

        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(Icons.error_outline, size: 40),

                const SizedBox(height: 12),

                Text(_message.isEmpty ? '加载失败' : _message),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onLogout,

                        child: const Text('退出登录'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton(
                        onPressed: _loadCurrentUserAndVisibility,

                        child: const Text('重试'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return Scaffold(body: _buildErrorPage());
    }

    if (_authzSnapshot == null) {
      return Scaffold(body: _buildErrorPage());
    }

    if (_menus.isEmpty) {
      return Scaffold(body: _buildNoAccessPage());
    }

    final selectedIndex = _menus.indexWhere(
      (menu) => menu.code == _selectedPageCode,
    );

    final safeSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;

    final selectedMenuCode = _menus[safeSelectedIndex].code;

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
                        Text(
                          'ZYKJ MES',

                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _currentUser!.displayName,

                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _menus.length,

                      itemBuilder: (context, index) {
                        final menu = _menus[index];

                        final selected = menu.code == selectedMenuCode;

                        final isMessage = menu.code == _messagePageCode;

                        return ListTile(
                          key: ValueKey('main-shell-menu-${menu.code}'),
                          selected: selected,

                          leading: isMessage && _unreadCount > 0
                              ? Badge(
                                  label: Text(
                                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                                  ),
                                  child: Icon(menu.icon),
                                )
                              : Icon(menu.icon),

                          title: Text(menu.title),

                          onTap: () {
                            if (_selectedPageCode == menu.code) {
                              return;
                            }
                            _navigateToPageTarget(menu.code);
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.logout),

                    title: const Text('退出登录'),

                    onTap: widget.onLogout,
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (_message.isNotEmpty)
                    Container(
                      width: double.infinity,

                      color: theme.colorScheme.surfaceContainer,

                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,

                        vertical: 8,
                      ),

                      child: Text(_message, style: theme.textTheme.bodyMedium),
                    ),

                  Expanded(
                    child: Container(
                      key: ValueKey('main-shell-content-$selectedMenuCode'),
                      child: IndexedStack(
                        index: safeSelectedIndex,

                        children: _menus
                            .map((menu) => _buildContent(menu.code))
                            .toList(),
                      ),
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
