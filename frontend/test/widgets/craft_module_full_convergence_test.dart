import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/craft/presentation/widgets/craft_page_shell.dart';
import 'package:mes_client/features/craft/presentation/widgets/craft_page_header.dart';

void main() {
  group('CraftModuleFullConvergence', () {
    testWidgets('CraftPageShell renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: CraftPageShell(
                header: const CraftPageHeader(),
                tabBar: const TabBar(
                  tabs: [
                    Tab(text: '工序管理'),
                    Tab(text: '生产工序配置'),
                  ],
                ),
                tabBarView: const TabBarView(
                  children: [
                    Center(child: Text('工序管理')),
                    Center(child: Text('生产工序配置')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CraftPageShell), findsOneWidget);
      expect(
        find.byKey(const ValueKey('craft-page-header-slot')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('craft-page-tab-bar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('craft-page-header-slot')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('CraftPageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CraftPageHeader())),
      );

      expect(find.byType(CraftPageHeader), findsOneWidget);
    });
  });
}
