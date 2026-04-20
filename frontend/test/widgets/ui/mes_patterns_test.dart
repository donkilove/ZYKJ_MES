import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

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
}
