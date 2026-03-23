import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/widgets/simple_pagination_bar.dart';

Finder _topLevelWideRow() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Row && widget.children.any((child) => child is Expanded),
  );
}

Finder _topLevelCompactColumn() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Column &&
        widget.children.length == 3 &&
        widget.children.first is Wrap &&
        widget.children.last is Align,
  );
}

void main() {
  testWidgets('SimplePaginationBar uses row layout on wide width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            child: SimplePaginationBar(
              page: 2,
              totalPages: 10,
              total: 200,
              loading: false,
              pageSize: 50,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );

    expect(_topLevelWideRow(), findsOneWidget);
    expect(_topLevelCompactColumn(), findsNothing);
    expect(find.text('第 2 / 10 页'), findsOneWidget);
    expect(find.text('每页 50 条'), findsOneWidget);
    expect(find.text('总数：200'), findsOneWidget);
  });

  testWidgets('SimplePaginationBar uses stacked layout on compact width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 540,
            child: SimplePaginationBar(
              page: 1,
              totalPages: 5,
              total: 99,
              loading: true,
              pageSize: 20,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );

    expect(_topLevelCompactColumn(), findsOneWidget);
    expect(_topLevelWideRow(), findsNothing);
    expect(find.text('加载中...'), findsOneWidget);

    final previousButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '上一页'),
    );
    final nextButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '下一页'),
    );

    expect(previousButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('SimplePaginationBar supports page and page size selectors', (
    tester,
  ) async {
    int? selectedPage;
    int? selectedPageSize;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            child: SimplePaginationBar(
              page: 2,
              totalPages: 4,
              total: 120,
              loading: false,
              pageSize: 50,
              pageSizeOptions: const [20, 50, 100],
              onPageChanged: (value) => selectedPage = value,
              onPageSizeChanged: (value) => selectedPageSize = value,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('simple-pagination-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 4 页').last);
    await tester.pumpAndSettle();

    expect(selectedPage, 4);

    await tester.tap(
      find.byKey(const Key('simple-pagination-page-size-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 条/页').last);
    await tester.pumpAndSettle();

    expect(selectedPageSize, 100);
  });
}
