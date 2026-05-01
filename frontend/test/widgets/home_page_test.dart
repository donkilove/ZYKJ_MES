import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/home_page.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_header.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_kpi_card.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_risk_card.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_todo_card.dart';

void main() {
  const desktopHeaderKey = Key('home_desktop_header');
  const desktopMainRowKey = Key('home_desktop_main_row');
  const desktopTodoPaneKey = Key('home_desktop_todo_pane');
  const desktopRightPaneKey = Key('home_desktop_right_pane');
  const desktopRiskPaneKey = Key('home_desktop_risk_pane');
  const desktopKpiPaneKey = Key('home_desktop_kpi_pane');

  CurrentUser buildUser({String? roleName = '品质管理员'}) {
    return CurrentUser(
      id: 1,
      username: 'tester',
      fullName: '测试用户',
      roleCode: roleName == null ? null : 'quality_admin',
      roleName: roleName,
      stageId: null,
      stageName: null,
    );
  }

  Future<void> pumpHomePage(
    WidgetTester tester, {
    required CurrentUser currentUser,
    required List<HomeQuickJumpEntry> shortcuts,
    required void Function(
      String pageCode, {
      String? tabCode,
      String? routePayloadJson,
    })
    onNavigateToPage,
    required Future<void> Function() onRefresh,
    bool refreshing = false,
    HomeDashboardData? dashboardData,
    Size viewportSize = const Size(1440, 1200),
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            currentUser: currentUser,
            shortcuts: shortcuts,
            onNavigateToPage: onNavigateToPage,
            onRefresh: onRefresh,
            refreshing: refreshing,
            dashboardData: dashboardData,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('桌面首页展示工作台核心卡片', (tester) async {
    await pumpHomePage(
      tester,
      currentUser: buildUser(),
      shortcuts: const [
        HomeQuickJumpEntry(
          pageCode: 'user',
          title: '用户',
          icon: Icons.group_rounded,
          tabCode: 'user_management',
          routePayloadJson: '{"target_tab_code":"user_management"}',
        ),
        HomeQuickJumpEntry(
          pageCode: 'product',
          title: '产品',
          icon: Icons.inventory_2_rounded,
          tabCode: 'product_management',
          routePayloadJson: '{"target_tab_code":"product_management"}',
        ),
      ],
      onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
      onRefresh: () async {},
    );

    expect(find.byKey(desktopHeaderKey), findsOneWidget);
    expect(find.byType(HomeDashboardHeader), findsOneWidget);
    expect(find.byType(MesPageHeader), findsOneWidget);

    expect(find.byKey(desktopMainRowKey), findsOneWidget);
    expect(find.byKey(desktopTodoPaneKey), findsOneWidget);
    expect(find.byKey(desktopRightPaneKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(desktopMainRowKey),
        matching: find.byKey(desktopTodoPaneKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(desktopMainRowKey),
        matching: find.byKey(desktopRightPaneKey),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(desktopTodoPaneKey),
        matching: find.byType(HomeDashboardTodoCard),
      ),
      findsOneWidget,
    );
    expect(find.byType(MesSectionCard), findsAtLeastNWidgets(3));
    expect(find.byKey(desktopRiskPaneKey), findsOneWidget);
    expect(find.byKey(desktopKpiPaneKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(desktopRiskPaneKey),
        matching: find.byType(HomeDashboardRiskCard),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(desktopKpiPaneKey),
        matching: find.byType(HomeDashboardKpiCard),
      ),
      findsOneWidget,
    );
    expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));

    expect(find.text('查看全部待办'), findsOneWidget);
    expect(find.text('上次刷新：12:00:00'), findsNothing);
  });

  testWidgets('首页快速跳转会回调目标页面编码与页签参数', (tester) async {
    String? navigatedPageCode;
    String? navigatedTabCode;
    String? navigatedPayload;

    await pumpHomePage(
      tester,
      currentUser: buildUser(),
      shortcuts: const [
        HomeQuickJumpEntry(
          pageCode: 'product',
          title: '产品',
          icon: Icons.inventory_2_rounded,
          tabCode: 'product_management',
          routePayloadJson: '{"target_tab_code":"product_management"}',
        ),
      ],
      onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
        navigatedPageCode = pageCode;
        navigatedTabCode = tabCode;
        navigatedPayload = routePayloadJson;
      },
      onRefresh: () async {},
    );

    await tester.tap(find.text('产品'));
    await tester.pumpAndSettle();

    expect(navigatedPageCode, 'product');
    expect(navigatedTabCode, 'product_management');
    expect(navigatedPayload, '{"target_tab_code":"product_management"}');
  });

  testWidgets('首页刷新按钮点击会触发业务刷新回调', (tester) async {
    var refreshCalled = false;

    await pumpHomePage(
      tester,
      currentUser: buildUser(roleName: null),
      shortcuts: const [
        HomeQuickJumpEntry(
          pageCode: 'user',
          title: '用户',
          icon: Icons.group_rounded,
        ),
      ],
      onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
      onRefresh: () async {
        refreshCalled = true;
      },
    );

    await tester.tap(find.byTooltip('刷新业务数据'));
    await tester.pumpAndSettle();

    expect(refreshCalled, isTrue);
    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('我的待办队列'), findsOneWidget);
    expect(find.text('用户'), findsOneWidget);
  });

  testWidgets('首页刷新中状态会禁用刷新按钮', (tester) async {
    var refreshCalled = false;

    await pumpHomePage(
      tester,
      currentUser: buildUser(),
      shortcuts: const [],
      onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
      onRefresh: () async {
        refreshCalled = true;
      },
      refreshing: true,
    );

    expect(find.byTooltip('刷新中'), findsOneWidget);
    expect(find.text('正在刷新业务数据...'), findsNothing);
    await tester.tap(find.byTooltip('刷新中'));
    await tester.pumpAndSettle();

    expect(refreshCalled, isFalse);
    expect(find.text('当前没有待处理事项'), findsOneWidget);
  });

  testWidgets('桌面首页默认高度下关键指标卡片不出现 overflow 异常', (tester) async {
    await pumpHomePage(
      tester,
      currentUser: buildUser(),
      shortcuts: const [],
      onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
      onRefresh: () async {},
      viewportSize: const Size(1216, 780),
      dashboardData: const HomeDashboardData(
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
        riskItems: [
          HomeDashboardMetricItem(
            code: 'production_exception',
            label: '生产异常',
            value: '0',
          ),
          HomeDashboardMetricItem(
            code: 'quality_warning',
            label: '质量预警',
            value: '0',
          ),
        ],
        kpiItems: [
          HomeDashboardMetricItem(
            code: 'wip_orders',
            label: '在制订单',
            value: '0',
          ),
          HomeDashboardMetricItem(
            code: 'today_output',
            label: '今日产量',
            value: '0',
          ),
          HomeDashboardMetricItem(
            code: 'first_pass_rate',
            label: '首件通过率',
            value: '0%',
          ),
          HomeDashboardMetricItem(
            code: 'scrap_count',
            label: '报废数',
            value: '0',
          ),
        ],
        degradedBlocks: [],
      ),
    );

    expect(find.textContaining('RenderFlex overflowed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
