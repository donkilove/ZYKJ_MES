import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/message/presentation/widgets/message_page_shell.dart';

void main() {
  group('MessageModuleFullConvergence', () {
    testWidgets('MessagePageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MessagePageHeader()),
        ),
      );

      expect(find.byType(MessagePageHeader), findsOneWidget);
    });
  });
}
