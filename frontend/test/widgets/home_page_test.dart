import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/current_user.dart';
import 'package:mes_client/pages/home_page.dart';

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
    required void Function(String pageCode) onNavigateToPage,
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
            onNavigateToPage: onNavigateToPage,
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
      onNavigateToPage: (_) {},
    );

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('欢迎使用 ZYKJ MES 系统'), findsOneWidget);
    expect(find.textContaining('测试用户'), findsOneWidget);
    expect(find.text(dateText), findsOneWidget);
    expect(find.text(weekday), findsOneWidget);
    expect(find.text('角色身份'), findsOneWidget);
    expect(find.text('品质管理员'), findsOneWidget);
  });

  testWidgets('首页快速跳转会回调目标页面编码', (tester) async {
    String? navigatedPageCode;

    await pumpHomePage(
      tester,
      currentUser: buildUser(),
      onNavigateToPage: (pageCode) {
        navigatedPageCode = pageCode;
      },
    );

    await tester.tap(
      find.descendant(of: find.byType(GridView), matching: find.text('产品')),
    );
    await tester.pumpAndSettle();

    expect(navigatedPageCode, 'product');
  });

  testWidgets('首页刷新按钮点击后保持工作台内容可见', (tester) async {
    await pumpHomePage(
      tester,
      currentUser: buildUser(roleName: null),
      onNavigateToPage: (_) {},
    );

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('暂无角色'), findsOneWidget);
    expect(find.text('快速跳转'), findsOneWidget);
  });
}
