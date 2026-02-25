import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/main.dart';

void main() {
  testWidgets('app boots to login or loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const MesClientApp());
    expect(find.byType(MesClientApp), findsOneWidget);
  });
}

