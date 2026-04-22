import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/widgets/announcement_card.dart';

void main() {
  group('AnnouncementCard', () {
    testWidgets('显示普通优先级公告', (tester) async {
      final item = MessageItem(
        id: 1,
        messageType: 'announcement',
        priority: 'normal',
        title: '测试公告',
        content: '这是测试内容',
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: null,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
        summary: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('普通'), findsOneWidget);
      expect(find.text('测试公告'), findsOneWidget);
      expect(find.text('这是测试内容'), findsOneWidget);
    });

    testWidgets('显示重要优先级公告', (tester) async {
      final item = MessageItem(
        id: 2,
        messageType: 'announcement',
        priority: 'important',
        title: '重要公告',
        content: '重要内容',
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: null,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
        summary: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('重要'), findsOneWidget);
      expect(find.text('重要公告'), findsOneWidget);
    });

    testWidgets('显示紧急优先级公告', (tester) async {
      final item = MessageItem(
        id: 3,
        messageType: 'announcement',
        priority: 'urgent',
        title: '紧急公告',
        content: '紧急内容',
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: null,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
        summary: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('紧急公告'), findsOneWidget);
    });

    testWidgets('显示有效期倒计时', (tester) async {
      final expiresAt = DateTime.now().add(const Duration(days: 5));
      final item = MessageItem(
        id: 4,
        messageType: 'announcement',
        priority: 'normal',
        title: '限时公告',
        content: '限时内容',
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: expiresAt,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
        summary: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.textContaining('剩余'), findsOneWidget);
      expect(find.textContaining('天'), findsOneWidget);
    });

    testWidgets('无 content 时显示 summary', (tester) async {
      final item = MessageItem(
        id: 5,
        messageType: 'announcement',
        priority: 'normal',
        title: '摘要公告',
        summary: '这是摘要内容',
        content: null,
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: null,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('这是摘要内容'), findsOneWidget);
    });

    testWidgets('content 和 summary 都为空时显示空', (tester) async {
      final item = MessageItem(
        id: 6,
        messageType: 'announcement',
        priority: 'normal',
        title: '无内容公告',
        summary: null,
        content: null,
        sourceModule: null,
        sourceType: null,
        sourceCode: null,
        targetPageCode: null,
        targetTabCode: null,
        targetRoutePayloadJson: null,
        status: 'active',
        inactiveReason: null,
        publishedAt: DateTime.now(),
        expiresAt: null,
        isRead: false,
        readAt: null,
        deliveredAt: null,
        deliveryStatus: 'delivered',
        deliveryAttemptCount: 0,
        lastPushAt: null,
        nextRetryAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('无内容公告'), findsOneWidget);
    });
  });
}
