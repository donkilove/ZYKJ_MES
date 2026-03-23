import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/widgets/adaptive_table_container.dart';

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

  testWidgets(
    'AdaptiveTableContainer applies desktop padding and minimum width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 400));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              height: 400,
              child: AdaptiveTableContainer(
                minTableWidth: 1600,
                child: const SizedBox(
                  width: 200,
                  height: 200,
                  child: Text('desktop-table-body'),
                ),
              ),
            ),
          ),
        ),
      );

      final verticalScrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      final horizontalConstrainedBox = tester.widget<ConstrainedBox>(
        find.byType(ConstrainedBox).last,
      );

      expect(
        verticalScrollView.padding,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );
      expect(horizontalConstrainedBox.constraints.minWidth, 1600);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
