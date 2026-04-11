import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';

void main() {
  testWidgets('公共页头渲染标题和刷新按钮', (tester) async {
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrudPageHeader(
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
}
