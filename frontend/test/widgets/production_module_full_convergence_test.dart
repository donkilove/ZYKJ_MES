import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/production/presentation/widgets/production_page_shell.dart';
import 'package:mes_client/features/production/presentation/widgets/production_page_header.dart';
import 'package:mes_client/features/production/presentation/widgets/production_order_status_chip.dart';
import 'package:mes_client/features/production/presentation/widgets/production_data_section_chip.dart';
import 'package:mes_client/features/production/models/production_models.dart';

void main() {
  group('ProductionModuleFullConvergence', () {
    testWidgets('ProductionPageShell renders correctly with TabController', (tester) async {
      final tabController = TabController(length: 2, vsync: tester);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: ProductionPageShell(
                tabBar: const TabBar(tabs: [
                  Tab(text: '订单管理'),
                  Tab(text: '订单查询'),
                ]),
                tabBarView: const TabBarView(children: [
                  Center(child: Text('订单管理')),
                  Center(child: Text('订单查询')),
                ]),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProductionPageShell), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
      
      tabController.dispose();
    });

    testWidgets('ProductionPageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProductionPageHeader()),
        ),
      );

      expect(find.byType(ProductionPageHeader), findsOneWidget);
    });

    testWidgets('ProductionOrderStatusChip renders pending status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionOrderStatusChip(status: 'pending'),
          ),
        ),
      );

      expect(find.byType(ProductionOrderStatusChip), findsOneWidget);
      expect(find.text('待生产'), findsOneWidget);
    });

    testWidgets('ProductionOrderStatusChip renders in_progress status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionOrderStatusChip(status: 'in_progress'),
          ),
        ),
      );

      expect(find.byType(ProductionOrderStatusChip), findsOneWidget);
      expect(find.text('生产中'), findsOneWidget);
    });

    testWidgets('ProductionOrderStatusChip renders completed status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionOrderStatusChip(status: 'completed'),
          ),
        ),
      );

      expect(find.byType(ProductionOrderStatusChip), findsOneWidget);
      expect(find.text('生产完成'), findsOneWidget);
    });

    testWidgets('ProductionDataSectionChip renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionDataSectionChip(section: ProductionDataSection.processStats),
          ),
        ),
      );

      expect(find.byType(ProductionDataSectionChip), findsOneWidget);
      expect(find.text('工序统计'), findsOneWidget);
    });

    testWidgets('ProductionDataSectionSelector renders all sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductionDataSectionSelector(
              selectedSection: ProductionDataSection.processStats,
              onSectionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ProductionDataSectionSelector), findsOneWidget);
      expect(find.byType(SegmentedButton<ProductionDataSection>), findsOneWidget);
      expect(find.text('工序统计'), findsOneWidget);
      expect(find.text('今日实时产量'), findsOneWidget);
      expect(find.text('人员统计'), findsOneWidget);
    });

    test('productionOrderStatusLabel returns correct labels', () {
      expect(productionOrderStatusLabel('pending'), '待生产');
      expect(productionOrderStatusLabel('in_progress'), '生产中');
      expect(productionOrderStatusLabel('completed'), '生产完成');
      expect(productionOrderStatusLabel('unknown'), 'unknown');
    });

    test('productionDataSectionLabel returns correct labels', () {
      expect(productionDataSectionLabel(ProductionDataSection.processStats), '工序统计');
      expect(productionDataSectionLabel(ProductionDataSection.todayRealtime), '今日实时产量');
      expect(productionDataSectionLabel(ProductionDataSection.operatorStats), '人员统计');
    });
  });
}
