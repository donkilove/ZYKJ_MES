import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

final AppSession testSession = AppSession(
  baseUrl: 'http://example.test/api/v1',
  accessToken: 'token',
);

CurrentUser buildCurrentUser() {
  return CurrentUser(
    id: 1,
    username: 'tester',
    fullName: '测试用户',
    roleCode: 'quality_admin',
    roleName: '品质管理员',
    stageId: null,
    stageName: null,
  );
}

List<PageCatalogItem> buildCatalog() {
  return const [
    PageCatalogItem(
      code: 'home',
      name: '首页',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: true,
      sortOrder: 10,
    ),
    PageCatalogItem(
      code: 'user',
      name: '用户',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: false,
      sortOrder: 20,
    ),
    PageCatalogItem(
      code: 'user_management',
      name: '用户管理',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 21,
    ),
    PageCatalogItem(
      code: 'role_management',
      name: '角色管理',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 23,
    ),
    PageCatalogItem(
      code: 'account_settings',
      name: '个人中心',
      pageType: 'tab',
      parentCode: 'user',
      alwaysVisible: false,
      sortOrder: 25,
    ),
    PageCatalogItem(
      code: 'message',
      name: '消息',
      pageType: 'sidebar',
      parentCode: null,
      alwaysVisible: false,
      sortOrder: 80,
    ),
    PageCatalogItem(
      code: 'message_center',
      name: '消息中心',
      pageType: 'tab',
      parentCode: 'message',
      alwaysVisible: false,
      sortOrder: 81,
    ),
  ];
}

AuthzSnapshotModuleItem buildModuleItem(
  String moduleCode, {
  List<String> capabilityCodes = const [],
}) {
  return AuthzSnapshotModuleItem(
    moduleCode: moduleCode,
    moduleName: moduleCode,
    moduleRevision: 1,
    moduleEnabled: true,
    effectivePermissionCodes: const [],
    effectivePagePermissionCodes: const [],
    effectiveCapabilityCodes: capabilityCodes,
    effectiveActionPermissionCodes: const [],
  );
}

AuthzSnapshotResult buildSnapshot({
  List<String> visibleSidebarCodes = const ['user'],
  Map<String, List<String>> tabCodesByParent = const {
    'user': ['role_management', 'user_management'],
  },
  List<AuthzSnapshotModuleItem>? moduleItems,
}) {
  return AuthzSnapshotResult(
    revision: 1,
    roleCodes: const ['quality_admin'],
    visibleSidebarCodes: visibleSidebarCodes,
    tabCodesByParent: tabCodesByParent,
    moduleItems:
        moduleItems ?? [buildModuleItem('user'), buildModuleItem('message')],
  );
}

MessageItem buildMessageItem() {
  return MessageItem(
    id: 301,
    messageType: 'todo',
    priority: 'important',
    title: '请处理账号设置',
    summary: '点击后跳转到个人中心',
    content: '消息内容',
    sourceModule: 'user',
    sourceType: 'account',
    sourceCode: 'U-301',
    targetPageCode: 'account_settings',
    targetTabCode: null,
    targetRoutePayloadJson:
        '{"target_tab_code":"account_settings","anchor":"account-settings-change-password-anchor"}',
    status: 'active',
    inactiveReason: null,
    publishedAt: DateTime.parse('2026-04-01T08:00:00Z'),
    isRead: false,
    readAt: null,
    deliveredAt: DateTime.parse('2026-04-01T08:00:00Z'),
    deliveryStatus: 'delivered',
    deliveryAttemptCount: 1,
    lastPushAt: DateTime.parse('2026-04-01T08:00:00Z'),
    nextRetryAt: null,
  );
}

HomeDashboardData buildDashboardData() {
  return const HomeDashboardData(
    generatedAt: null,
    noticeCount: 0,
    todoSummary: HomeDashboardTodoSummary(
      totalCount: 0,
      pendingApprovalCount: 0,
      highPriorityCount: 0,
      exceptionCount: 0,
      overdueCount: 0,
    ),
    todoItems: [],
    riskItems: [],
    kpiItems: [],
    degradedBlocks: [],
  );
}

IconData iconForPageForTest(String pageCode) {
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
