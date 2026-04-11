import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/features/shell/presentation/home_page.dart';

void main() {
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
    String? refreshStatusText,
  }) async {
    tester.view.physicalSize = const Size(1440, 1200);
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
            refreshStatusText: refreshStatusText,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首页工作台展示标题欢迎卡日期和角色', (tester) async {
    final now = DateTime.now();
    final dateText =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekday = [
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ][now.weekday - 1];

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
      refreshStatusText: '上次刷新：12:00:00',
    );

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('欢迎使用 ZYKJ MES 系统'), findsOneWidget);
    expect(find.textContaining('测试用户'), findsOneWidget);
    expect(find.text(dateText), findsOneWidget);
    expect(find.text(weekday), findsOneWidget);
    expect(find.text('角色身份'), findsOneWidget);
    expect(find.text('品质管理员'), findsOneWidget);
    expect(find.text('用户'), findsOneWidget);
    expect(find.text('产品'), findsOneWidget);
    expect(find.text('上次刷新：12:00:00'), findsOneWidget);
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

    await tester.tap(
      find.descendant(of: find.byType(GridView), matching: find.text('产品')),
    );
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
    expect(find.text('暂无角色'), findsOneWidget);
    expect(find.text('快速跳转'), findsOneWidget);
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
      refreshStatusText: '正在刷新业务数据...',
    );

    expect(find.byTooltip('刷新中'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新中'));
    await tester.pumpAndSettle();

    expect(refreshCalled, isFalse);
    expect(find.text('暂无可快捷跳转的模块'), findsOneWidget);
  });
}
