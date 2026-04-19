import 'package:flutter/material.dart';

import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/shell/presentation/home_page.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

typedef MainShellIconResolver = IconData Function(String pageCode);

List<MainShellMenuItem> buildMainShellMenus({
  required List<PageCatalogItem> catalog,
  required List<String> visibleSidebarCodes,
  required String homePageCode,
  required MainShellIconResolver iconForPage,
}) {
  final visibleCodeSet = visibleSidebarCodes.toSet();
  final sidebarPages =
      catalog.where((item) => item.pageType == 'sidebar').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final items = <MainShellMenuItem>[];
  final homeCatalogItem = sidebarPages
      .where((item) => item.code == homePageCode)
      .firstOrNull;

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
        title: homeCatalogItem?.name ?? '首页',
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
    final tabCode = defaultTabCodeForPage(
      tabCodesByParent: tabCodesByParent,
      catalog: catalog,
      parentCode: menu.code,
    );
    entries.add(
      HomeQuickJumpEntry(
        pageCode: menu.code,
        title: menu.title,
        icon: menu.icon,
        tabCode: tabCode,
        routePayloadJson: defaultRoutePayloadJsonForTab(tabCode),
      ),
    );
  }
  return entries;
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

  final catalogItem = catalog
      .where((item) => item.code == requestedPageCode)
      .firstOrNull;
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
