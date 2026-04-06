import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/pages/craft_kanban_page.dart';
import 'package:mes_client/pages/craft_page.dart';
import 'package:mes_client/pages/craft_reference_analysis_page.dart';
import 'package:mes_client/pages/process_configuration_page.dart';
import 'package:mes_client/pages/process_management_page.dart';

void main() {
  final session = AppSession(baseUrl: '', accessToken: '');

  Future<void> pumpCraftPage(
    WidgetTester tester, {
    required List<String> visibleTabCodes,
    String? preferredTabCode,
    String? routePayloadJson,
    void Function(String pageCode)? onNavigateToPage,
    Widget Function(String tabCode)? tabChildBuilder,
    Widget Function(String tabCode, Widget child)? tabPageBuilder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CraftPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: visibleTabCodes,
            capabilityCodes: const <String>{},
            preferredTabCode: preferredTabCode,
            routePayloadJson: routePayloadJson,
            onNavigateToPage: onNavigateToPage,
            tabChildBuilder: tabChildBuilder,
            tabPageBuilder: tabPageBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CraftPage 按既定顺序排序页签并尊重 preferredTabCode', (tester) async {
    await pumpCraftPage(
      tester,
      visibleTabCodes: const [
        craftReferenceAnalysisTabCode,
        'z_custom',
        craftKanbanTabCode,
        processManagementTabCode,
      ],
      preferredTabCode: craftKanbanTabCode,
      tabChildBuilder: (tabCode) =>
          Center(child: Text(tabCode, key: Key('content-$tabCode'))),
    );

    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();
    expect(tabs.map((item) => item.text), ['工序管理', '工艺看板', '引用分析', 'z_custom']);
    expect(find.byKey(const Key('content-craft_kanban')), findsOneWidget);
  });

  testWidgets('CraftPage 支持字符串 routePayloadJson 并分发到目标页签', (tester) async {
    await pumpCraftPage(
      tester,
      visibleTabCodes: const [
        processManagementTabCode,
        productionProcessConfigTabCode,
      ],
      preferredTabCode: productionProcessConfigTabCode,
      routePayloadJson:
          '{"target_tab_code":"process_management","process_id":"11"}',
      tabPageBuilder: (tabCode, child) {
        if (child is ProcessManagementPage) {
          return Center(
            child: Text('pm:${child.processId}:${child.jumpRequestId}'),
          );
        }
        if (child is ProcessConfigurationPage) {
          return Center(
            child: Text(
              'pc:${child.templateId}:${child.version}:${child.systemMasterVersions}:${child.jumpRequestId}',
            ),
          );
        }
        return child;
      },
    );

    expect(find.text('pm:11:1'), findsOneWidget);

    await pumpCraftPage(
      tester,
      visibleTabCodes: const [
        processManagementTabCode,
        productionProcessConfigTabCode,
      ],
      routePayloadJson:
          '{"target_tab_code":"production_process_config","template_id":"22","version":"3","system_master_versions":"1"}',
      tabPageBuilder: (tabCode, child) {
        if (child is ProcessManagementPage) {
          return Center(
            child: Text('pm:${child.processId}:${child.jumpRequestId}'),
          );
        }
        if (child is ProcessConfigurationPage) {
          return Center(
            child: Text(
              'pc:${child.templateId}:${child.version}:${child.systemMasterVersions}:${child.jumpRequestId}',
            ),
          );
        }
        return child;
      },
    );

    expect(find.text('pc:22:3:true:1'), findsOneWidget);
  });

  testWidgets('CraftPage 可分发引用分析回跳到工艺内外模块', (tester) async {
    String? capturedPageCode;

    await pumpCraftPage(
      tester,
      visibleTabCodes: const [
        processManagementTabCode,
        productionProcessConfigTabCode,
        craftKanbanTabCode,
        craftReferenceAnalysisTabCode,
      ],
      preferredTabCode: craftReferenceAnalysisTabCode,
      onNavigateToPage: (pageCode) => capturedPageCode = pageCode,
      tabPageBuilder: (tabCode, child) {
        if (child is CraftReferenceAnalysisPage) {
          return Column(
            children: [
              FilledButton(
                onPressed: () => child.onNavigate(
                  moduleCode: 'user',
                  jumpTarget: 'user-management?user_id=7',
                ),
                child: const Text('跳用户'),
              ),
              FilledButton(
                onPressed: () => child.onNavigate(
                  moduleCode: 'craft',
                  jumpTarget:
                      'process-configuration?template_id=22&version=3&system_master_versions=1',
                ),
                child: const Text('跳工艺配置'),
              ),
              FilledButton(
                onPressed: () => child.onNavigate(
                  moduleCode: 'craft',
                  jumpTarget: 'craft-kanban',
                ),
                child: const Text('跳工艺看板'),
              ),
            ],
          );
        }
        if (child is ProcessConfigurationPage) {
          return Center(
            child: Text(
              'config:${child.templateId}:${child.version}:${child.systemMasterVersions}:${child.jumpRequestId}',
            ),
          );
        }
        if (child is CraftKanbanPage) {
          return const Center(child: Text('kanban-page'));
        }
        return child;
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, '跳用户'));
    await tester.pumpAndSettle();
    expect(capturedPageCode, 'user');

    await tester.tap(find.widgetWithText(FilledButton, '跳工艺配置'));
    await tester.pumpAndSettle();
    expect(find.text('config:22:3:true:1'), findsOneWidget);

    await tester.tap(find.text('引用分析'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '跳工艺看板'));
    await tester.pumpAndSettle();
    expect(find.text('kanban-page'), findsOneWidget);
  });
}
