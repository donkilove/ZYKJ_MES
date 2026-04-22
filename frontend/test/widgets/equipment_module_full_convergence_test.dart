import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_page_shell.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_page_header.dart';

void main() {
  group('EquipmentModuleFullConvergence', () {
    testWidgets('EquipmentPageShell renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: EquipmentPageShell(
                tabBar: const TabBar(tabs: [
                  Tab(text: '设备台账'),
                  Tab(text: '保养项目'),
                ]),
                tabBarView: const TabBarView(children: [
                  Center(child: Text('设备台账')),
                  Center(child: Text('保养项目')),
                ]),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EquipmentPageShell), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('EquipmentPageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EquipmentPageHeader()),
        ),
      );

      expect(find.byType(EquipmentPageHeader), findsOneWidget);
    });
  });
}
