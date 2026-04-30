import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/first_article_scan_review_mobile_page.dart';
import 'package:mes_client/features/production/presentation/scan_review_mobile_login_storage.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.token});

  final String token;
  static const int _expiresIn = 7 * 24 * 60 * 60;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<({int expiresIn, bool mustChangePassword, String token})>
  mobileScanReviewLogin({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    lastPassword = password;
    return (token: token, mustChangePassword: false, expiresIn: _expiresIn);
  }
}

class _FakeScanReviewLoginStorage implements ScanReviewMobileLoginStorage {
  String? accessToken;
  DateTime? expiresAt;
  String? username;

  @override
  Future<ScanReviewMobileLoginState?> read() async {
    if (accessToken == null || expiresAt == null) {
      return null;
    }
    return ScanReviewMobileLoginState(
      accessToken: accessToken!,
      expiresAt: expiresAt!,
      username: username,
    );
  }

  @override
  Future<void> write(ScanReviewMobileLoginState state) async {
    accessToken = state.accessToken;
    expiresAt = state.expiresAt;
    username = state.username;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    expiresAt = null;
    username = null;
  }
}

class _FakeProductionService extends ProductionService {
  _FakeProductionService() : super(AppSession(baseUrl: '', accessToken: ''));

  FirstArticleReviewSessionDetail detail = FirstArticleReviewSessionDetail(
    sessionId: 88,
    status: 'pending',
    expiresAt: DateTime.parse('2026-04-25T12:05:00Z'),
    orderId: 1,
    orderCode: 'MO-001',
    productName: '产品A',
    orderProcessId: 11,
    processName: '装配',
    operatorUserId: 8,
    operatorUsername: 'operator',
    templateId: 501,
    checkContent: '外观无划伤',
    testValue: '长度 10.01',
    participantUserIds: const [8, 9],
    reviewRemark: null,
  );
  FirstArticleReviewSubmitInput? lastSubmit;

  @override
  Future<FirstArticleReviewSessionDetail> getFirstArticleReviewSessionDetail({
    required String token,
  }) async {
    return detail;
  }

  @override
  Future<FirstArticleReviewSessionResult> submitFirstArticleReviewResult({
    required FirstArticleReviewSubmitInput request,
  }) async {
    lastSubmit = request;
    return FirstArticleReviewSessionResult(
      sessionId: 88,
      reviewUrl: null,
      expiresAt: detail.expiresAt,
      status: 'approved',
      firstArticleRecordId: 77,
      reviewerUserId: 3,
      reviewedAt: DateTime.parse('2026-04-25T12:02:00Z'),
      reviewRemark: request.reviewRemark,
    );
  }
}

void main() {
  testWidgets('手机扫码复核页登录后提交合格结果', (tester) async {
    final authService = _FakeAuthService(token: 'mobile-token');
    final productionService = _FakeProductionService();
    final storage = _FakeScanReviewLoginStorage();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FirstArticleScanReviewMobilePage(
          baseUrl: 'http://api.test',
          token: 'scan-token',
          authService: authService,
          productionServiceFactory: (_) => productionService,
          loginStorage: storage,
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '账号'), 'qa');
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(authService.lastUsername, 'qa');
    expect(find.text('MO-001'), findsOneWidget);
    expect(find.text('长度 10.01'), findsOneWidget);

    await tester.tap(find.text('合格'));
    await tester.enterText(find.widgetWithText(TextField, '备注（可选）'), '参数一致');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '提交复核'));
    await tester.tap(find.widgetWithText(FilledButton, '提交复核'));
    await tester.pumpAndSettle();

    expect(find.text('复核已提交'), findsOneWidget);
    expect(productionService.lastSubmit?.token, 'scan-token');
    expect(productionService.lastSubmit?.reviewResult, 'passed');
    expect(productionService.lastSubmit?.reviewRemark, '参数一致');
    expect(storage.accessToken, 'mobile-token');
    expect(storage.username, 'qa');
  });

  testWidgets('手机扫码复核页读取本地登录态后直接加载详情', (tester) async {
    final authService = _FakeAuthService(token: 'unused-token');
    final productionService = _FakeProductionService();
    final storage = _FakeScanReviewLoginStorage()
      ..accessToken = 'persisted-token'
      ..expiresAt = DateTime.now().add(const Duration(days: 3))
      ..username = 'saved-user';
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FirstArticleScanReviewMobilePage(
          baseUrl: 'http://api.test',
          token: 'scan-token',
          authService: authService,
          productionServiceFactory: (_) => productionService,
          loginStorage: storage,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(authService.lastUsername, isNull);
    expect(find.text('MO-001'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '切换账号'), findsOneWidget);
  });

  testWidgets('手机扫码复核页支持切换账号并清理本地登录态', (tester) async {
    final authService = _FakeAuthService(token: 'mobile-token');
    final productionService = _FakeProductionService();
    final storage = _FakeScanReviewLoginStorage();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FirstArticleScanReviewMobilePage(
          baseUrl: 'http://api.test',
          token: 'scan-token',
          authService: authService,
          productionServiceFactory: (_) => productionService,
          loginStorage: storage,
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '账号'), 'qa');
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '切换账号'));
    await tester.pumpAndSettle();

    expect(storage.accessToken, isNull);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
  });
}
