import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('质量模块通过总页壳层展示主业务页与跨域页签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: QualityPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              visibleTabCodes: const [
                qualityDataQueryTabCode,
                qualityRepairOrdersTabCode,
                qualitySupplierManagementTabCode,
              ],
              capabilityCodes: const <String>{},
              preferredTabCode: qualitySupplierManagementTabCode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quality-page-shell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quality-supplier-management-page-header')),
      findsOneWidget,
    );
  });
}
