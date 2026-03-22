import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/pages/equipment_rule_parameter_page.dart';
import 'package:mes_client/services/equipment_service.dart';

class _RuntimeParameterRequest {
  const _RuntimeParameterRequest({
    required this.equipmentId,
    required this.equipmentType,
    required this.isEnabled,
  });

  final int? equipmentId;
  final String? equipmentType;
  final bool? isEnabled;
}

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<_RuntimeParameterRequest> runtimeParameterRequests =
      <_RuntimeParameterRequest>[];

  @override
  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? locationKeyword,
    String? ownerName,
  }) async {
    return EquipmentLedgerListResult(
      total: 1,
      items: [
        EquipmentLedgerItem(
          id: 101,
          code: 'EQ-101',
          name: '冲压机-1',
          model: 'MODEL-A',
          location: 'A区',
          ownerName: 'tester',
          remark: '',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<EquipmentRuleListResult> listEquipmentRules({
    int? equipmentId,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    return EquipmentRuleListResult(
      total: 1,
      items: [
        EquipmentRuleItem(
          id: 11,
          equipmentId: 101,
          equipmentType: '冲压机',
          equipmentCode: 'EQ-101',
          equipmentName: '冲压机-1',
          ruleCode: 'RULE-11',
          ruleName: '压力规则',
          ruleType: '阈值',
          conditionDesc: '压力超限',
          isEnabled: true,
          effectiveAt: DateTime.parse('2026-03-01T00:00:00Z'),
          remark: '联动测试',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<EquipmentRuntimeParameterListResult> listRuntimeParameters({
    int? equipmentId,
    String? equipmentType,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    runtimeParameterRequests.add(
      _RuntimeParameterRequest(
        equipmentId: equipmentId,
        equipmentType: equipmentType,
        isEnabled: isEnabled,
      ),
    );
    return EquipmentRuntimeParameterListResult(
      total: 1,
      items: [
        EquipmentRuntimeParameterItem(
          id: 21,
          equipmentId: 101,
          equipmentType: '冲压机',
          equipmentCode: 'EQ-101',
          equipmentName: '冲压机-1',
          paramCode: 'PRESSURE',
          paramName: '压力',
          unit: 'bar',
          standardValue: '1.2',
          upperLimit: '1.5',
          lowerLimit: '1.0',
          effectiveAt: DateTime.parse('2026-03-01T00:00:00Z'),
          isEnabled: true,
          remark: '联动测试',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required EquipmentService service,
  bool canViewRules = true,
  bool canManageRules = true,
  bool canViewParameters = true,
  bool canManageParameters = true,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EquipmentRuleParameterPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          canViewRules: canViewRules,
          canManageRules: canManageRules,
          canViewParameters: canViewParameters,
          canManageParameters: canManageParameters,
          service: service,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('规则可联动切换到参数页并带入同范围筛选', (tester) async {
    final service = _FakeEquipmentService();

    await _pumpPage(tester, service: service);

    expect(find.text('压力规则'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('equipment-rule-open-parameters-11')),
    );
    await tester.pumpAndSettle();

    expect(service.runtimeParameterRequests, isNotEmpty);
    expect(
      find.byKey(const Key('equipment-parameter-scope-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('当前按规则作用范围查看参数'), findsOneWidget);
    expect(find.textContaining('规则#11 压力规则'), findsOneWidget);
    expect(find.text('压力'), findsOneWidget);
    expect(service.runtimeParameterRequests.last.equipmentId, 101);
    expect(service.runtimeParameterRequests.last.equipmentType, '冲压机');
    expect(service.runtimeParameterRequests.last.isEnabled, isTrue);
  });

  testWidgets('只读规则权限不会展示新增编辑入口', (tester) async {
    final service = _FakeEquipmentService();

    await _pumpPage(
      tester,
      service: service,
      canViewRules: true,
      canManageRules: false,
      canViewParameters: false,
      canManageParameters: false,
    );

    expect(find.text('设备规则'), findsOneWidget);
    expect(find.text('新增规则'), findsNothing);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });
}
