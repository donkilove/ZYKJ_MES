import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';

void main() {
  testWidgets('MesPageHeader 展示标题、副标题和操作区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: MesPageHeader(
            title: '页面标题',
            subtitle: '页面说明',
            actions: [FilledButton(onPressed: () {}, child: const Text('新增'))],
          ),
        ),
      ),
    );

    expect(find.text('页面标题'), findsOneWidget);
    expect(find.text('页面说明'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
  });

  testWidgets('MesSectionCard 与 MesPaginationBar 可组合使用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: MesSectionCard(
            title: '列表区',
            child: MesPaginationBar(
              page: 1,
              totalPages: 3,
              total: 56,
              loading: false,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('列表区'), findsOneWidget);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(find.text('总数：56'), findsOneWidget);
  });

  testWidgets(
    'MesCrudPageScaffold 按固定顺序装配 header filters banner content pagination',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMesTheme(
            brightness: Brightness.light,
            visualDensity: VisualDensity.standard,
          ),
          home: const Scaffold(
            body: MesCrudPageScaffold(
              header: Text('header-slot'),
              filters: Text('filters-slot'),
              banner: MesInlineBanner.info(message: '页内提示'),
              content: Placeholder(),
              pagination: Text('pagination-slot'),
            ),
          ),
        ),
      );

      expect(find.text('header-slot'), findsOneWidget);
      expect(find.text('filters-slot'), findsOneWidget);
      expect(find.text('页内提示'), findsOneWidget);
      expect(find.text('pagination-slot'), findsOneWidget);
      expect(find.byType(MesInlineBanner), findsOneWidget);
    },
  );

  testWidgets('MesTableSectionHeader 支持标题、副标题和右侧动作', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: MesTableSectionHeader(
            title: '列表区',
            subtitle: '统一表格说明',
            trailing: Text('仅右侧动作'),
          ),
        ),
      ),
    );

    expect(find.text('列表区'), findsOneWidget);
    expect(find.text('统一表格说明'), findsOneWidget);
    expect(find.text('仅右侧动作'), findsOneWidget);
  });

  testWidgets('MesListDetailShell 在宽屏双栏、窄屏纵向堆叠并支持 banner', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> pumpShell(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMesTheme(
            brightness: Brightness.light,
            visualDensity: VisualDensity.standard,
          ),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 720,
              child: const MesListDetailShell(
                banner: MesInlineBanner.info(message: '顶部提示'),
                sidebar: ColoredBox(
                  key: ValueKey('sidebar-child'),
                  color: Colors.blue,
                  child: SizedBox.expand(),
                ),
                content: ColoredBox(
                  key: ValueKey('content-child'),
                  color: Colors.green,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpShell(1280);
    expect(find.text('顶部提示'), findsOneWidget);

    final wideSidebar = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final wideContent = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );
    expect(wideSidebar.left, lessThan(wideContent.left));
    expect(wideSidebar.top, equals(wideContent.top));

    await pumpShell(720);

    final narrowSidebar = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final narrowContent = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );
    expect(narrowSidebar.top, lessThan(narrowContent.top));
    expect(narrowSidebar.left, equals(narrowContent.left));
  });
}
