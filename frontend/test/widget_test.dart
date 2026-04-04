import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用入口已启用中文本地化配置', (WidgetTester tester) async {
    await tester.pumpWidget(const MesClientApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, const Locale('zh', 'CN'));
    expect(app.supportedLocales, contains(const Locale('zh', 'CN')));
    expect(
      app.localizationsDelegates,
      contains(GlobalMaterialLocalizations.delegate),
    );
  });
}
