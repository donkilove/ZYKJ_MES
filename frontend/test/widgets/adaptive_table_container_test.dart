import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';

void main() {
  testWidgets('AdaptiveTableContainer renders child with dual scroll areas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: AdaptiveTableContainer(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 600,
                height: 400,
                child: const Text('table-body'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('table-body'), findsOneWidget);
    expect(find.byType(Scrollbar), findsNWidgets(2));
    expect(find.byType(SingleChildScrollView), findsNWidgets(2));
  });

  testWidgets('AdaptiveTableContainer supports unbounded height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: AdaptiveTableContainer(
                child: SizedBox(
                  width: 600,
                  height: 200,
                  child: const Text('unbounded-table-body'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('unbounded-table-body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
