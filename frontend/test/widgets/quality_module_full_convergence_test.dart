import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 1600, height: 1200, child: child),
    ),
  );
}

void main() {
  testWidgets('QualityPage 接入统一总页壳层并保留稳定页签栏锚点', (tester) async {
    await tester.pumpWidget(
      _host(
        QualityPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          visibleTabCodes: const [
            firstArticleManagementTabCode,
            qualityDataQueryTabCode,
            qualityTrendTabCode,
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: qualityDataQueryTabCode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quality-page-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('quality-page-tab-bar')), findsOneWidget);
    expect(find.text('每日首件'), findsOneWidget);
    expect(find.text('质量数据'), findsOneWidget);
    expect(find.text('质量趋势'), findsOneWidget);
  });
}
