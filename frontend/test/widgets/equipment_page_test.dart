import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/equipment/presentation/equipment_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_page.dart';

class _PayloadProbe extends StatelessWidget {
  const _PayloadProbe({required this.code, this.payload});

  final String code;
  final String? payload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text('tab:$code'), Text('payload:${payload ?? 'null'}')],
    );
  }
}

Future<void> _pumpPage(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  final session = AppSession(baseUrl: '', accessToken: 'token');

  testWidgets('设备总页按默认顺序裁剪页签并命中 preferredTabCode', (tester) async {
    const payload = '{"action":"detail","work_order_id":88}';

    await _pumpPage(
      tester,
      EquipmentPage(
        session: session,
        onLogout: () {},
        visibleTabCodes: const [
          equipmentRuleParameterTabCode,
          'unknown_tab',
          maintenanceExecutionTabCode,
          equipmentLedgerTabCode,
        ],
        capabilityCodes: const {
          EquipmentFeaturePermissionCodes.executionsOperate,
          EquipmentFeaturePermissionCodes.rulesView,
          EquipmentFeaturePermissionCodes.runtimeParametersView,
        },
        preferredTabCode: maintenanceExecutionTabCode,
        routePayloadJson: payload,
        tabPageBuilder: (tabCode, child) {
          if (child is MaintenanceExecutionPage) {
            return _PayloadProbe(code: tabCode, payload: child.jumpPayloadJson);
          }
          return _PayloadProbe(code: tabCode);
        },
      ),
    );

    final tabs = tester
        .widgetList<Tab>(find.byType(Tab))
        .map((widget) => widget.text)
        .toList();
    expect(tabs, ['设备台账', '保养执行', '规则与参数']);
    expect(find.text('tab:$maintenanceExecutionTabCode'), findsOneWidget);
    expect(find.text('payload:$payload'), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(tabBar.controller?.index, 1);
    expect(find.text('unknown_tab'), findsNothing);
  });

  testWidgets('设备总页在无可见页签时展示空权限态', (tester) async {
    await _pumpPage(
      tester,
      EquipmentPage(
        session: session,
        onLogout: _noop,
        visibleTabCodes: ['unknown_tab'],
        capabilityCodes: <String>{},
      ),
    );

    expect(find.text('当前账号没有可访问的设备模块页面。'), findsOneWidget);
  });
}

void _noop() {}
