import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class _IntegrationMessageService extends MessageService {
  _IntegrationMessageService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 1,
      unreadCount: 1,
      todoUnreadCount: 1,
      urgentUnreadCount: 0,
    );
  }

  @override
  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    return MessageListResult(
      items: [
        MessageItem.fromJson({
          'id': 1,
          'message_type': 'todo',
          'priority': 'urgent',
          'title': '待办消息',
          'summary': '请尽快处理',
          'content': '正文内容',
          'status': 'active',
          'published_at': '2026-04-20T08:00:00Z',
          'is_read': false,
          'delivery_status': 'delivered',
          'delivery_attempt_count': 1,
        }),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    );
  }

  @override
  Future<MessageDetailResult> getMessageDetail(int messageId) async {
    final item = MessageItem.fromJson({
      'id': messageId,
      'message_type': 'todo',
      'priority': 'urgent',
      'title': '待办消息',
      'summary': '请尽快处理',
      'content': '正文内容',
      'status': 'active',
      'published_at': '2026-04-20T08:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    });
    return MessageDetailResult(
      item: item,
      sourceId: null,
      failureReasonHint: null,
    );
  }
}

class _IntegrationUserService extends UserService {
  _IntegrationUserService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('消息中心桌面流展示统一页头、筛选区和详情预览', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: MessageCenterPage(
              session: AppSession(
                baseUrl: 'http://example.test/api/v1',
                accessToken: 'token',
              ),
              onLogout: () {},
              canPublishAnnouncement: false,
              canViewDetail: true,
              canUseJump: false,
              service: _IntegrationMessageService(),
              userService: _IntegrationUserService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('消息中心'), findsOneWidget);
    expect(find.text('消息概览'), findsOneWidget);
    expect(find.text('筛选条件'), findsOneWidget);
    expect(find.text('消息详情预览'), findsOneWidget);
  });
}
