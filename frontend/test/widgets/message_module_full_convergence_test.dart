import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/message/presentation/widgets/message_page_header.dart';
import 'package:mes_client/features/message/presentation/widgets/message_page_shell.dart';

void main() {
  group('MessageModuleFullConvergence', () {
    testWidgets('MessagePageShell renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: MessagePageShell(
                header: const MessagePageHeader(),
                tabBar: const TabBar(
                  tabs: [
                    Tab(text: '消息中心'),
                    Tab(text: '公告管理'),
                  ],
                ),
                tabBarView: const TabBarView(
                  children: [
                    Center(child: Text('消息中心')),
                    Center(child: Text('公告管理')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MessagePageShell), findsOneWidget);
      expect(find.byKey(const ValueKey('message-page-shell')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('message-page-header-slot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('message-page-tab-bar')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('message-page-header-slot')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('MessagePageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MessagePageHeader())),
      );

      expect(find.byType(MessagePageHeader), findsOneWidget);
    });
  });
}
