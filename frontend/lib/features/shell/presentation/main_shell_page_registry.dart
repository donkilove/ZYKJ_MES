import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/production/presentation/production_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/craft/presentation/craft_page.dart';
import 'package:mes_client/features/equipment/presentation/equipment_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';
import 'package:mes_client/features/shell/presentation/home_page.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';

typedef MainShellUserPageBuilder =
    Widget Function({
      required AppSession session,
      required VoidCallback onLogout,
      required List<String> visibleTabCodes,
      required Set<String> capabilityCodes,
      required bool moduleActive,
      String? preferredTabCode,
      String? routePayloadJson,
      VoidCallback? onVisibilityConfigSaved,
    });

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

class MainShellPageRegistry {
  const MainShellPageRegistry();

  Widget build({
    required String pageCode,
    required AppSession session,
    required MainShellViewState state,
    required VoidCallback onLogout,
    required Future<void> Function({bool loadCatalog}) onRefreshShellData,
    required void Function({
      required String pageCode,
      String? tabCode,
      String? routePayloadJson,
    })
    onNavigateToPageTarget,
    required VoidCallback onVisibilityConfigSaved,
    required MessageService messageService,
    required SoftwareSettingsController softwareSettingsController,
    required TimeSyncController timeSyncController,
    PluginHostController? pluginHostController,
    String? homeRefreshStatusText,
    void Function(int count)? onUnreadCountChanged,
    MainShellUserPageBuilder? userPageBuilder,
    MainShellModulePageBuilder? productPageBuilder,
    MainShellModulePageBuilder? equipmentPageBuilder,
    MainShellModulePageBuilder? productionPageBuilder,
    MainShellModulePageBuilder? qualityPageBuilder,
    MainShellModulePageBuilder? craftPageBuilder,
  }) {
    List<String> tabCodesFor(String parentCode) {
      return filterVisibleTabCodesForParent(
        tabCodesByParent: state.tabCodesByParent,
        catalog: state.catalog,
        parentCode: parentCode,
      );
    }

    Set<String> capabilityCodesFor(String moduleCode) {
      return state.authzSnapshot?.capabilityCodesForModule(moduleCode) ??
          const <String>{};
    }

    bool moduleActiveFor(String moduleCode) {
      return state.activeUtilityCode == null &&
          state.selectedPageCode == moduleCode;
    }

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
          onRefresh: () => onRefreshShellData(loadCatalog: false),
          refreshing: state.manualRefreshing,
          refreshStatusText: homeRefreshStatusText,
        );
      case 'user':
        final builder = userPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('user'),
                capabilityCodes: capabilityCodesFor('user'),
                moduleActive: moduleActiveFor('user'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
                onVisibilityConfigSaved: onVisibilityConfigSaved,
              )
            : UserPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('user'),
                capabilityCodes: capabilityCodesFor('user'),
                moduleActive: moduleActiveFor('user'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
                onVisibilityConfigSaved: onVisibilityConfigSaved,
              );
      case 'product':
        final builder = productPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('product'),
                capabilityCodes: capabilityCodesFor('product'),
                moduleActive: moduleActiveFor('product'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              )
            : ProductPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('product'),
                capabilityCodes: capabilityCodesFor('product'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              );
      case 'equipment':
        final builder = equipmentPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('equipment'),
                capabilityCodes: capabilityCodesFor('equipment'),
                moduleActive: moduleActiveFor('equipment'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              )
            : EquipmentPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('equipment'),
                capabilityCodes: capabilityCodesFor('equipment'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              );
      case 'production':
        final builder = productionPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('production'),
                capabilityCodes: capabilityCodesFor('production'),
                moduleActive: moduleActiveFor('production'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              )
            : ProductionPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('production'),
                capabilityCodes: capabilityCodesFor('production'),
                moduleActive: moduleActiveFor('production'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              );
      case 'quality':
        final builder = qualityPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('quality'),
                capabilityCodes: capabilityCodesFor('quality'),
                moduleActive: moduleActiveFor('quality'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              )
            : QualityPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('quality'),
                capabilityCodes: capabilityCodesFor('quality'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              );
      case 'craft':
        final builder = craftPageBuilder;
        return builder != null
            ? builder(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('craft'),
                capabilityCodes: capabilityCodesFor('craft'),
                moduleActive: moduleActiveFor('craft'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
              )
            : CraftPage(
                session: session,
                onLogout: onLogout,
                visibleTabCodes: tabCodesFor('craft'),
                capabilityCodes: capabilityCodesFor('craft'),
                preferredTabCode: state.preferredTabCode,
                routePayloadJson: state.preferredRoutePayloadJson,
                onNavigateToPage: (pageCode) {
                  onNavigateToPageTarget(pageCode: pageCode);
                },
              );
      case 'message':
        final messageCapabilityCodes = capabilityCodesFor('message');
        return MessageCenterPage(
          session: session,
          service: messageService,
          onLogout: onLogout,
          pollingEnabled: moduleActiveFor('message'),
          canPublishAnnouncement: messageCapabilityCodes.contains(
            'feature.message.announcement.publish',
          ),
          canViewDetail: messageCapabilityCodes.contains(
            'feature.message.detail.view',
          ),
          canUseJump: true,
          refreshTick: state.messageRefreshTick,
          onUnreadCountChanged: onUnreadCountChanged,
          onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
            onNavigateToPageTarget(
              pageCode: pageCode,
              tabCode: tabCode,
              routePayloadJson: routePayloadJson,
            );
          },
          routePayloadJson: state.preferredRoutePayloadJson,
          nowProvider: timeSyncController.effectiveClock.now,
        );
      case softwareSettingsUtilityCode:
        return SoftwareSettingsPage(
          controller: softwareSettingsController,
          timeSyncController: timeSyncController,
          apiBaseUrl: session.baseUrl,
        );
      case pluginHostUtilityCode:
        if (pluginHostController == null) {
          return const Center(child: Text('插件中心控制器缺失'));
        }
        return PluginHostPage(controller: pluginHostController);
      default:
        return Center(child: Text('页面暂未实现：$pageCode'));
    }
  }
}
