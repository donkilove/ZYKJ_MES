import 'package:flutter/material.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

const String softwareSettingsUtilityCode = 'software_settings';
const String pluginHostUtilityCode = 'plugin_host';

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

const Object _mainShellUnset = Object();

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
    this.activeUtilityCode,
    this.unreadCount = 0,
    this.preferredTabCode,
    this.preferredRoutePayloadJson,
    this.manualRefreshing = false,
    this.homeDashboardLoading = false,
    this.homeDashboardRefreshPending = false,
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
  final String? activeUtilityCode;
  final int unreadCount;
  final String? preferredTabCode;
  final String? preferredRoutePayloadJson;
  final bool manualRefreshing;
  final bool homeDashboardLoading;
  final bool homeDashboardRefreshPending;
  final HomeDashboardData? homeDashboardData;

  MainShellViewState copyWith({
    bool? loading,
    String? message,
    int? messageRefreshTick,
    Object? currentUser = _mainShellUnset,
    Object? authzSnapshot = _mainShellUnset,
    List<PageCatalogItem>? catalog,
    Map<String, List<String>>? tabCodesByParent,
    List<MainShellMenuItem>? menus,
    String? selectedPageCode,
    Object? activeUtilityCode = _mainShellUnset,
    int? unreadCount,
    Object? preferredTabCode = _mainShellUnset,
    Object? preferredRoutePayloadJson = _mainShellUnset,
    bool? manualRefreshing,
    bool? homeDashboardLoading,
    bool? homeDashboardRefreshPending,
    Object? homeDashboardData = _mainShellUnset,
  }) {
    return MainShellViewState(
      loading: loading ?? this.loading,
      message: message ?? this.message,
      messageRefreshTick: messageRefreshTick ?? this.messageRefreshTick,
      currentUser: currentUser == _mainShellUnset
          ? this.currentUser
          : currentUser as CurrentUser?,
      authzSnapshot: authzSnapshot == _mainShellUnset
          ? this.authzSnapshot
          : authzSnapshot as AuthzSnapshotResult?,
      catalog: catalog ?? this.catalog,
      tabCodesByParent: tabCodesByParent ?? this.tabCodesByParent,
      menus: menus ?? this.menus,
      selectedPageCode: selectedPageCode ?? this.selectedPageCode,
      activeUtilityCode: activeUtilityCode == _mainShellUnset
          ? this.activeUtilityCode
          : activeUtilityCode as String?,
      unreadCount: unreadCount ?? this.unreadCount,
      preferredTabCode: preferredTabCode == _mainShellUnset
          ? this.preferredTabCode
          : preferredTabCode as String?,
      preferredRoutePayloadJson: preferredRoutePayloadJson == _mainShellUnset
          ? this.preferredRoutePayloadJson
          : preferredRoutePayloadJson as String?,
      manualRefreshing: manualRefreshing ?? this.manualRefreshing,
      homeDashboardLoading: homeDashboardLoading ?? this.homeDashboardLoading,
      homeDashboardRefreshPending:
          homeDashboardRefreshPending ?? this.homeDashboardRefreshPending,
      homeDashboardData: homeDashboardData == _mainShellUnset
          ? this.homeDashboardData
          : homeDashboardData as HomeDashboardData?,
    );
  }
}
