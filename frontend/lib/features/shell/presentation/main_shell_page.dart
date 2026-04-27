import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/shell/presentation/main_shell_controller.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page_registry.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/shell/presentation/widgets/main_shell_scaffold.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';

const Duration _visibilityRefreshInterval = Duration(seconds: 15);
const Duration _unreadPollInterval = Duration(seconds: 30);
const Duration _homeDashboardRefreshDebounceDuration = Duration(seconds: 2);

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.softwareSettingsController,
    required this.timeSyncController,
    this.messageWsServiceFactory,
    this.authService,
    this.authzService,
    this.pageCatalogService,
    this.messageService,
    this.homeDashboardService,
    this.pluginHostController,
    this.userPageBuilder,
    this.productPageBuilder,
    this.equipmentPageBuilder,
    this.productionPageBuilder,
    this.qualityPageBuilder,
    this.craftPageBuilder,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final SoftwareSettingsController softwareSettingsController;
  final TimeSyncController timeSyncController;
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
  final PluginHostController? pluginHostController;
  final MainShellUserPageBuilder? userPageBuilder;
  final MainShellModulePageBuilder? productPageBuilder;
  final MainShellModulePageBuilder? equipmentPageBuilder;
  final MainShellModulePageBuilder? productionPageBuilder;
  final MainShellModulePageBuilder? qualityPageBuilder;
  final MainShellModulePageBuilder? craftPageBuilder;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with WidgetsBindingObserver {
  final MainShellPageRegistry _pageRegistry = const MainShellPageRegistry();
  late final MainShellController _controller;
  late final PluginHostController _pluginHostController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final authService = widget.authService ?? AuthService();
    final authzService = widget.authzService ?? AuthzService(widget.session);
    final pageCatalogService =
        widget.pageCatalogService ?? PageCatalogService(widget.session);
    final messageService =
        widget.messageService ?? MessageService(widget.session);
    final homeDashboardService =
        widget.homeDashboardService ?? HomeDashboardService(widget.session);
    final pluginRuntimeLocator = PluginRuntimeLocator();
    _pluginHostController =
        widget.pluginHostController ??
        PluginHostController(
          catalogService: PluginCatalogService(
            pluginRootResolver: () async =>
                pluginRuntimeLocator.resolvePluginRoot(),
          ),
          processService: PluginProcessService(),
          runtimeLocator: pluginRuntimeLocator,
        );

    _controller = MainShellController(
      session: widget.session,
      onLogout: widget.onLogout,
      authService: authService,
      authzService: authzService,
      pageCatalogService: pageCatalogService,
      messageService: messageService,
      homeDashboardService: homeDashboardService,
      softwareSettingsController: widget.softwareSettingsController,
      messageWsServiceFactory:
          widget.messageWsServiceFactory ??
          ({
            required String baseUrl,
            required String accessToken,
            required WsEventCallback onEvent,
            required void Function() onDisconnected,
          }) {
            return MessageWsService(
              baseUrl: baseUrl,
              accessToken: accessToken,
              onEvent: onEvent,
              onDisconnected: onDisconnected,
            );
          },
    );

    _controller.attach(
      visibilityPollInterval: _visibilityRefreshInterval,
      unreadPollInterval: _unreadPollInterval,
      debounceDuration: _homeDashboardRefreshDebounceDuration,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pluginHostController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_controller.handleAppLifecycleStateChanged(state));
  }

  Future<void> _handleRetry() async {
    final state = _controller.state;
    if (state.currentUser == null || state.authzSnapshot == null) {
      await _controller.initialize();
      return;
    }
    await _controller.refreshShellDataFromUi();
  }

  void _showNoAccessSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('您没有访问该页面的权限')));
  }

  void _navigateToPageTarget({
    required String pageCode,
    String? tabCode,
    String? routePayloadJson,
  }) {
    final success = _controller.navigateToPageTarget(
      pageCode: pageCode,
      tabCode: tabCode,
      routePayloadJson: routePayloadJson,
    );
    if (!success) {
      _showNoAccessSnackBar();
    }
  }

  Widget _buildContent(String pageCode) {
    return _pageRegistry.build(
      pageCode: pageCode,
      session: widget.session,
      state: _controller.state,
      onLogout: widget.onLogout,
      onRefreshShellData: _controller.refreshShellDataFromUi,
      onNavigateToPageTarget:
          ({
            required String pageCode,
            String? tabCode,
            String? routePayloadJson,
          }) {
            _navigateToPageTarget(
              pageCode: pageCode,
              tabCode: tabCode,
              routePayloadJson: routePayloadJson,
            );
          },
      onVisibilityConfigSaved: () {
        unawaited(_controller.refreshVisibility(loadCatalog: false));
      },
      onUnreadCountChanged: _controller.updateUnreadCount,
      messageService: _controller.messageService,
      softwareSettingsController: widget.softwareSettingsController,
      timeSyncController: widget.timeSyncController,
      pluginHostController: _pluginHostController,
      homeRefreshStatusText: _controller.homeRefreshStatusText(),
      userPageBuilder: widget.userPageBuilder,
      productPageBuilder: widget.productPageBuilder,
      equipmentPageBuilder: widget.equipmentPageBuilder,
      productionPageBuilder: widget.productionPageBuilder,
      qualityPageBuilder: widget.qualityPageBuilder,
      craftPageBuilder: widget.craftPageBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller,
        _pluginHostController,
        widget.softwareSettingsController,
        widget.timeSyncController,
      ]),
      builder: (context, _) {
        final state = _controller.state;
        if (state.loading) {
          return const Scaffold(body: MesLoadingState(label: '工作台加载中...'));
        }

        final showErrorPage =
            state.currentUser == null || state.authzSnapshot == null;
        final showNoAccessPage = !showErrorPage && state.menus.isEmpty;
        final selectedMenuCode =
            state.menus
                .where((item) => item.code == state.selectedPageCode)
                .map((item) => item.code)
                .firstOrNull ??
            (state.menus.isEmpty ? 'home' : state.menus.first.code);
        final contentPageCode = state.activeUtilityCode ?? selectedMenuCode;
        final sidebarCollapsed =
            widget.softwareSettingsController.settings.sidebarPreference ==
            AppSidebarPreference.collapsed;
        final hideShellChrome =
            state.activeUtilityCode == pluginHostUtilityCode &&
            _pluginHostController.isFullscreenActive;

        return MainShellScaffold(
          state: state,
          currentUserDisplayName: state.currentUser?.displayName ?? '',
          content: showErrorPage || showNoAccessPage
              ? const SizedBox.shrink()
              : _buildContent(contentPageCode),
          onSelectMenu: _controller.selectMenu,
          onOpenPluginHost: _controller.openPluginHost,
          onOpenSoftwareSettings: _controller.openSoftwareSettings,
          sidebarCollapsed: sidebarCollapsed,
          onLogout: widget.onLogout,
          onRetry: () {
            unawaited(_handleRetry());
          },
          hideShellChrome: hideShellChrome,
          showNoAccessPage: showNoAccessPage,
          showErrorPage: showErrorPage,
        );
      },
    );
  }
}
