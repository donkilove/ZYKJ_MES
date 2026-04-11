import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/login_session_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/user/services/user_service.dart';

Finder _findSemanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
}

class _FakeSessionUserService extends UserService {
  _FakeSessionUserService()
    : super(AppSession(baseUrl: 'http://test', accessToken: 'token'));

  int listCalls = 0;
  int forceOfflineCalls = 0;
  int batchForceOfflineCalls = 0;
  int? lastListPage;
  int? lastListPageSize;
  String? lastKeyword;
  String? lastStatusFilter;
  String? lastForceOfflineSessionId;
  List<String>? lastBatchSessionIds;
  Object? listError;
  Object? forceOfflineError;
  Object? batchForceOfflineError;
  List<List<OnlineSessionItem>> responses = [_buildActiveSessions()];
  List<int>? responseTotals;

  @override
  Future<OnlineSessionListResult> listOnlineSessions({
    required int page,
    required int pageSize,
    String? keyword,
    String? statusFilter,
  }) async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    listCalls += 1;
    lastListPage = page;
    lastListPageSize = pageSize;
    lastKeyword = keyword;
    lastStatusFilter = statusFilter;
    final items = responses[(listCalls - 1).clamp(0, responses.length - 1)];
    final total = responseTotals == null
        ? items.length
        : responseTotals![(listCalls - 1).clamp(0, responseTotals!.length - 1)];
    return OnlineSessionListResult(total: total, items: items);
  }

  @override
  Future<ForceOfflineResult> forceOffline({
    required String sessionTokenId,
  }) async {
    final error = forceOfflineError;
    if (error != null) {
      throw error;
    }
    forceOfflineCalls += 1;
    lastForceOfflineSessionId = sessionTokenId;
    return ForceOfflineResult(affected: 1);
  }

  @override
  Future<ForceOfflineResult> batchForceOffline({
    required List<String> sessionTokenIds,
  }) async {
    final error = batchForceOfflineError;
    if (error != null) {
      throw error;
    }
    batchForceOfflineCalls += 1;
    lastBatchSessionIds = List<String>.from(sessionTokenIds);
    return ForceOfflineResult(affected: sessionTokenIds.length);
  }
}

List<OnlineSessionItem> _buildActiveSessions() {
  return [
    OnlineSessionItem(
      id: 1,
      sessionTokenId: 'session-1',
      userId: 101,
      username: 'alpha',
      roleCode: 'operator',
      roleName: '操作员',
      stageId: 10,
      stageName: '装配一段',
      loginTime: DateTime.parse('2026-03-21T08:00:00Z'),
      lastActiveAt: DateTime.parse('2026-03-21T08:10:00Z'),
      expiresAt: DateTime.parse('2026-03-21T10:00:00Z'),
      ipAddress: '10.0.0.1',
      terminalInfo: 'Edge',
      status: 'active',
    ),
    OnlineSessionItem(
      id: 2,
      sessionTokenId: 'session-2',
      userId: 102,
      username: 'beta',
      roleCode: 'production_admin',
      roleName: '生产管理员',
      stageId: null,
      stageName: null,
      loginTime: DateTime.parse('2026-03-21T08:05:00Z'),
      lastActiveAt: DateTime.parse('2026-03-21T08:15:00Z'),
      expiresAt: DateTime.parse('2026-03-21T10:05:00Z'),
      ipAddress: '10.0.0.2',
      terminalInfo: 'Chrome',
      status: 'active',
    ),
  ];
}

List<OnlineSessionItem> _buildSecondPageSessions() {
  return [
    OnlineSessionItem(
      id: 3,
      sessionTokenId: 'session-3',
      userId: 103,
      username: 'gamma',
      roleCode: 'quality_admin',
      roleName: '品质管理员',
      stageId: 12,
      stageName: '终检',
      loginTime: DateTime.parse('2026-03-21T08:20:00Z'),
      lastActiveAt: DateTime.parse('2026-03-21T08:30:00Z'),
      expiresAt: DateTime.parse('2026-03-21T10:20:00Z'),
      ipAddress: '10.0.0.3',
      terminalInfo: 'Firefox',
      status: 'active',
    ),
  ];
}

Future<void> _pumpSessionPage(
  WidgetTester tester, {
  required _FakeSessionUserService userService,
  bool canViewOnlineSessions = true,
  bool canForceOffline = true,
  VoidCallback? onLogout,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LoginSessionPage(
          session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
          onLogout: onLogout ?? () {},
          canViewOnlineSessions: canViewOnlineSessions,
          canForceOffline: canForceOffline,
          userService: userService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('登录会话页单个强制下线后会刷新列表', (tester) async {
    final userService = _FakeSessionUserService()
      ..responses = [_buildActiveSessions(), const []];

    await _pumpSessionPage(tester, userService: userService);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, '强制下线').first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '强制下线').first);
    await tester.pumpAndSettle();

    expect(userService.forceOfflineCalls, 1);
    expect(userService.lastForceOfflineSessionId, 'session-1');
    expect(userService.listCalls, greaterThanOrEqualTo(2));
    expect(find.text('暂无在线会话'), findsOneWidget);
  });

  testWidgets('登录会话页批量强制下线与选择状态机会同步按钮数量', (tester) async {
    final userService = _FakeSessionUserService()
      ..responses = [_buildActiveSessions(), const []];

    await _pumpSessionPage(tester, userService: userService);

    expect(find.text('批量强制下线（0）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（1）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（0）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（1）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（2）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（0）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（2）'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '批量强制下线（2）'));
    await tester.pumpAndSettle();

    expect(userService.batchForceOfflineCalls, 1);
    expect(
      userService.lastBatchSessionIds,
      unorderedEquals(['session-1', 'session-2']),
    );
    expect(find.text('暂无在线会话'), findsOneWidget);
    expect(find.text('批量强制下线（0）'), findsOneWidget);
  });

  testWidgets('登录会话页批量强制下线失败时提示错误', (tester) async {
    final userService = _FakeSessionUserService()
      ..batchForceOfflineError = ApiException('批量下线失败', 500);

    await _pumpSessionPage(tester, userService: userService);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '批量强制下线（2）'));
    await tester.pumpAndSettle();

    expect(find.text('批量下线失败'), findsOneWidget);
    expect(userService.batchForceOfflineCalls, 0);
  });

  testWidgets('登录会话页加载 401 时触发登出回调', (tester) async {
    final userService = _FakeSessionUserService()
      ..listError = ApiException('登录失效', 401);
    var logoutCalls = 0;

    await _pumpSessionPage(
      tester,
      userService: userService,
      onLogout: () {
        logoutCalls += 1;
      },
    );

    expect(logoutCalls, 1);
  });

  testWidgets('登录会话页支持搜索分页并在查询时回到第一页', (tester) async {
    final userService = _FakeSessionUserService()
      ..responses = [
        _buildActiveSessions(),
        _buildSecondPageSessions(),
        _buildSecondPageSessions(),
      ]
      ..responseTotals = [11, 11, 1];

    await _pumpSessionPage(tester, userService: userService);

    expect(userService.lastListPage, 1);
    expect(userService.lastListPageSize, 10);
    expect(userService.lastStatusFilter, 'active');

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pumpAndSettle();

    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('第 2 / 2 页'), findsOneWidget);
    expect(userService.lastListPage, 2);

    await tester.enterText(find.widgetWithText(TextField, '关键词'), 'gamma');
    await tester.tap(find.widgetWithText(OutlinedButton, '查询'));
    await tester.pumpAndSettle();

    expect(userService.lastListPage, 1);
    expect(userService.lastKeyword, 'gamma');
    expect(find.text('第 1 / 1 页'), findsOneWidget);
  });

  testWidgets('登录会话页翻页后选择状态机会按当前页重置', (tester) async {
    final userService = _FakeSessionUserService()
      ..responses = [
        _buildActiveSessions(),
        _buildSecondPageSessions(),
        _buildActiveSessions(),
      ]
      ..responseTotals = [11, 11, 11];

    await _pumpSessionPage(tester, userService: userService);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（1）'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pumpAndSettle();

    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('批量强制下线（0）'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('批量强制下线（1）'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '上一页'));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('批量强制下线（0）'), findsOneWidget);
  });

  testWidgets('登录会话页在无下线权限时展示列表但禁用操作', (tester) async {
    final userService = _FakeSessionUserService();

    await _pumpSessionPage(
      tester,
      userService: userService,
      canViewOnlineSessions: true,
      canForceOffline: false,
    );

    expect(find.text('alpha'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '批量强制下线（0）'), findsOneWidget);

    final batchButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '批量强制下线（0）'),
    );
    expect(batchButton.onPressed, isNull);

    final rowAction = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '强制下线').first,
    );
    expect(rowAction.onPressed, isNull);

    final headerCheckbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(headerCheckbox.onChanged, isNull);
  });

  testWidgets('登录会话页暴露稳定主区域与操作区语义标签', (tester) async {
    final userService = _FakeSessionUserService();

    await _pumpSessionPage(tester, userService: userService);

    expect(_findSemanticsLabel('登录会话主区域'), findsOneWidget);
    expect(_findSemanticsLabel('登录会话筛选与操作区'), findsOneWidget);
    expect(_findSemanticsLabel('在线会话列表区域'), findsOneWidget);
  });
}
