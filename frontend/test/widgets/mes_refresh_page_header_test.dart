import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

void main() {
  testWidgets('公共页头渲染标题和刷新按钮', (tester) async {
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MesRefreshPageHeader(
            title: '测试页',
            onRefresh: () {
              refreshCalls += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('测试页'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();

    expect(refreshCalls, 1);
  });

  testWidgets('公共页头支持副标题与刷新前操作区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MesRefreshPageHeader(
            title: '测试页',
            subtitle: '用于校验公共页头副标题',
            onRefresh: () {},
            actionsBeforeRefresh: const [
              SizedBox(
                width: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '筛选项',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('测试页'), findsOneWidget);
    expect(find.text('用于校验公共页头副标题'), findsOneWidget);
    expect(find.widgetWithText(TextField, '筛选项'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
  });
}
