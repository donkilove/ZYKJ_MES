import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';

AppSession _session() {
  return AppSession(baseUrl: 'http://test', accessToken: 'token');
}

ProductItem _buildProduct() {
  final fixedDate = DateTime.parse('2026-03-01T00:00:00Z');
  return ProductItem(
    id: 41,
    name: '产品41',
    category: '贴片',
    remark: '',
    lifecycleStatus: 'active',
    currentVersion: 2,
    currentVersionLabel: 'V1.1',
    effectiveVersion: 1,
    effectiveVersionLabel: 'V1.0',
    effectiveAt: fixedDate,
    inactiveReason: null,
    lastParameterSummary: null,
    createdAt: fixedDate,
    updatedAt: fixedDate,
  );
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('产品总页按默认顺序展示页签并应用 preferredTabCode', (tester) async {
    await tester.pumpWidget(
      _host(
        ProductPage(
          session: _session(),
          onLogout: () {},
          visibleTabCodes: const [
            productParameterQueryTabCode,
            productVersionManagementTabCode,
            productManagementTabCode,
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: productVersionManagementTabCode,
          tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('产品管理'), findsOneWidget);
    expect(find.text('版本管理'), findsOneWidget);
    expect(find.text('产品参数查询'), findsOneWidget);
    expect(find.text('tab:$productVersionManagementTabCode'), findsOneWidget);
  });

  testWidgets('产品总页收到 routePayloadJson 后会切换到目标页签', (tester) async {
    await tester.pumpWidget(
      _host(
        ProductPage(
          session: _session(),
          onLogout: () {},
          visibleTabCodes: const [
            productVersionManagementTabCode,
            productParameterQueryTabCode,
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: productVersionManagementTabCode,
          routePayloadJson:
              '{"target_tab_code":"product_parameter_query","action":"view","product_id":41,"product_name":"产品41"}',
          tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tab:$productParameterQueryTabCode'), findsOneWidget);
  });

  testWidgets('产品总页会响应产品管理页内跳转到参数页', (tester) async {
    ProductManagementPage? managementPage;

    await tester.pumpWidget(
      _host(
        ProductPage(
          session: _session(),
          onLogout: () {},
          visibleTabCodes: const [
            productManagementTabCode,
            productParameterManagementTabCode,
            productParameterQueryTabCode,
          ],
          capabilityCodes: const <String>{},
          preferredTabCode: productManagementTabCode,
          tabPageBuilder: (tabCode, child) {
            if (child is ProductManagementPage) {
              managementPage = child;
            }
            return Center(child: Text('tab:$tabCode'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final product = _buildProduct();
    expect(managementPage, isNotNull);

    managementPage!.onViewParameters(product);
    await tester.pumpAndSettle();
    expect(find.text('tab:$productParameterQueryTabCode'), findsOneWidget);

    managementPage!.onEditParameters(product);
    await tester.pumpAndSettle();
    expect(find.text('tab:$productParameterManagementTabCode'), findsOneWidget);
  });
}
