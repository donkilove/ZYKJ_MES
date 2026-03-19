import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/pages/message_center_page.dart';
import 'package:mes_client/services/message_service.dart';

class _FakeMessageService extends MessageService {
  _FakeMessageService() : super(AppSession(baseUrl: '', accessToken: ''));

  bool lastTodoOnly = false;
  int batchReadCount = 0;

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 2,
      unreadCount: 2,
      todoUnreadCount: 1,
      urgentUnreadCount: 1,
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
  }) async {
    lastTodoOnly = todoOnly;
    final items = <MessageItem>[
      MessageItem.fromJson({
        'id': 1,
        'message_type': 'todo',
        'priority': 'urgent',
        'title': '待办消息',
        'summary': '请尽快处理',
        'content': '正文内容',
        'source_module': 'production',
        'source_type': 'repair_order',
        'source_code': 'RW-1',
        'target_page_code': 'production',
        'target_tab_code': 'production_repair_orders',
        'status': 'active',
        'published_at': '2026-03-19T08:00:00Z',
        'is_read': false,
      }),
      MessageItem.fromJson({
        'id': 2,
        'message_type': 'notice',
        'priority': 'normal',
        'title': '普通通知',
        'summary': '仅展示',
        'content': '正文内容',
        'source_module': 'quality',
        'source_type': 'first_article_record',
        'source_code': 'FA-1',
        'target_page_code': 'quality',
        'target_tab_code': 'first_article_management',
        'status': 'expired',
        'published_at': '2026-03-19T09:00:00Z',
        'is_read': false,
      }),
    ];
    final filtered = todoOnly
        ? items.where((item) => item.messageType == 'todo').toList()
        : items;
    return MessageListResult(items: filtered, total: filtered.length, page: page, pageSize: pageSize);
  }

  @override
  Future<void> markRead(int messageId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<int> markBatchRead(List<int> messageIds) async {
    batchReadCount = messageIds.length;
    return batchReadCount;
  }
}

void main() {
  testWidgets('message center supports preview, todo filter and batch read', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeMessageService();
    String? navigatedPage;
    String? navigatedTab;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: MessageCenterPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              service: service,
              onNavigateToPage: (pageCode, {tabCode}) {
                navigatedPage = pageCode;
                navigatedTab = tabCode;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('消息详情预览'), findsOneWidget);

    await tester.tap(find.text('待办消息').first);
    await tester.pumpAndSettle();
    expect(find.text('正文内容'), findsOneWidget);

    await tester.tap(find.text('仅看待处理'));
    await tester.pumpAndSettle();
    expect(service.lastTodoOnly, isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('批量已读'));
    await tester.pumpAndSettle();
    expect(service.batchReadCount, 1);

    await tester.tap(find.text('跳转业务'));
    await tester.pumpAndSettle();
    expect(navigatedPage, 'production');
    expect(navigatedTab, 'production_repair_orders');
  });
}
