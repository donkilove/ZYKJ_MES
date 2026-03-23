import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/widgets/simple_pagination_bar.dart';

Future<void> _pumpPaginationBar(
  WidgetTester tester, {
  bool showTotal = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SimplePaginationBar(
          page: 2,
          totalPages: 5,
          total: 123,
          loading: false,
          showTotal: showTotal,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('分页组件默认显示总数', (tester) async {
    await _pumpPaginationBar(tester);

    expect(find.text('第 2 / 5 页'), findsOneWidget);
    expect(find.text('总数：123'), findsOneWidget);
  });

  testWidgets('分页组件关闭开关后隐藏总数', (tester) async {
    await _pumpPaginationBar(tester, showTotal: false);

    expect(find.text('第 2 / 5 页'), findsOneWidget);
    expect(find.textContaining('总数'), findsNothing);
  });
}
