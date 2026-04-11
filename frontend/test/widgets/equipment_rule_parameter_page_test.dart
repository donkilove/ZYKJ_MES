import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/equipment_rule_parameter_page.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

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
    : super(AppSession(baseUrl: '', accessToken: 'token')) {
    rules = <EquipmentRuleItem>[
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
    ];
    parameters = <EquipmentRuntimeParameterItem>[
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
    ];
  }

  final List<_RuntimeParameterRequest> runtimeParameterRequests =
      <_RuntimeParameterRequest>[];
  late List<EquipmentRuleItem> rules;
  late List<EquipmentRuntimeParameterItem> parameters;

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
    final filtered = rules.where((item) {
      final equipmentMatched =
          equipmentId == null || item.equipmentId == equipmentId;
      final keywordMatched =
          keyword == null ||
          keyword.trim().isEmpty ||
          item.ruleName.contains(keyword.trim()) ||
          item.ruleCode.contains(keyword.trim());
      final statusMatched = isEnabled == null || item.isEnabled == isEnabled;
      return equipmentMatched && keywordMatched && statusMatched;
    }).toList();
    return EquipmentRuleListResult(total: filtered.length, items: filtered);
  }

  @override
  Future<void> createEquipmentRule({
    int? equipmentId,
    String? equipmentType,
    required String ruleCode,
    required String ruleName,
    String ruleType = '',
    String conditionDesc = '',
    bool isEnabled = true,
    DateTime? effectiveAt,
    String remark = '',
  }) async {
    final id =
        (rules.map((item) => item.id).fold<int>(0, (a, b) => a > b ? a : b)) +
        1;
    rules = [
      ...rules,
      EquipmentRuleItem(
        id: id,
        equipmentId: equipmentId,
        equipmentType: equipmentType,
        equipmentCode: equipmentId == null ? null : 'EQ-$equipmentId',
        equipmentName: equipmentId == 101 ? '冲压机-1' : null,
        ruleCode: ruleCode,
        ruleName: ruleName,
        ruleType: ruleType,
        conditionDesc: conditionDesc,
        isEnabled: isEnabled,
        effectiveAt: effectiveAt,
        remark: remark,
        createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
      ),
    ];
  }

  @override
  Future<void> updateEquipmentRule({
    required int ruleId,
    int? equipmentId,
    String? equipmentType,
    required String ruleCode,
    required String ruleName,
    String ruleType = '',
    String conditionDesc = '',
    required bool isEnabled,
    DateTime? effectiveAt,
    String remark = '',
  }) async {
    rules = rules.map((item) {
      if (item.id != ruleId) {
        return item;
      }
      return EquipmentRuleItem(
        id: item.id,
        equipmentId: equipmentId,
        equipmentType: equipmentType,
        equipmentCode: equipmentId == null ? null : 'EQ-$equipmentId',
        equipmentName: equipmentId == 101 ? '冲压机-1' : null,
        ruleCode: ruleCode,
        ruleName: ruleName,
        ruleType: ruleType,
        conditionDesc: conditionDesc,
        isEnabled: isEnabled,
        effectiveAt: effectiveAt,
        remark: remark,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-03T00:00:00Z'),
      );
    }).toList();
  }

  @override
  Future<void> toggleEquipmentRule({
    required int ruleId,
    required bool isEnabled,
  }) async {
    rules = rules.map((item) {
      if (item.id != ruleId) {
        return item;
      }
      return EquipmentRuleItem(
        id: item.id,
        equipmentId: item.equipmentId,
        equipmentType: item.equipmentType,
        equipmentCode: item.equipmentCode,
        equipmentName: item.equipmentName,
        ruleCode: item.ruleCode,
        ruleName: item.ruleName,
        ruleType: item.ruleType,
        conditionDesc: item.conditionDesc,
        isEnabled: isEnabled,
        effectiveAt: item.effectiveAt,
        remark: item.remark,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-03T00:00:00Z'),
      );
    }).toList();
  }

  @override
  Future<void> deleteEquipmentRule(int ruleId) async {
    rules = rules.where((item) => item.id != ruleId).toList();
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
    final filtered = parameters.where((item) {
      final equipmentMatched =
          equipmentId == null || item.equipmentId == equipmentId;
      final typeMatched =
          equipmentType == null ||
          equipmentType.trim().isEmpty ||
          item.equipmentType == equipmentType.trim();
      final keywordMatched =
          keyword == null ||
          keyword.trim().isEmpty ||
          item.paramName.contains(keyword.trim()) ||
          item.paramCode.contains(keyword.trim());
      final statusMatched = isEnabled == null || item.isEnabled == isEnabled;
      return equipmentMatched && typeMatched && keywordMatched && statusMatched;
    }).toList();
    return EquipmentRuntimeParameterListResult(
      total: filtered.length,
      items: filtered,
    );
  }

  @override
  Future<void> createRuntimeParameter({
    int? equipmentId,
    String? equipmentType,
    required String paramCode,
    required String paramName,
    String unit = '',
    String? standardValue,
    String? upperLimit,
    String? lowerLimit,
    DateTime? effectiveAt,
    bool isEnabled = true,
    String remark = '',
  }) async {
    final id =
        (parameters
            .map((item) => item.id)
            .fold<int>(0, (a, b) => a > b ? a : b)) +
        1;
    parameters = [
      ...parameters,
      EquipmentRuntimeParameterItem(
        id: id,
        equipmentId: equipmentId,
        equipmentType: equipmentType,
        equipmentCode: equipmentId == null ? null : 'EQ-$equipmentId',
        equipmentName: equipmentId == 101 ? '冲压机-1' : null,
        paramCode: paramCode,
        paramName: paramName,
        unit: unit,
        standardValue: standardValue,
        upperLimit: upperLimit,
        lowerLimit: lowerLimit,
        effectiveAt: effectiveAt,
        isEnabled: isEnabled,
        remark: remark,
        createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
      ),
    ];
  }

  @override
  Future<void> updateRuntimeParameter({
    required int paramId,
    int? equipmentId,
    String? equipmentType,
    required String paramCode,
    required String paramName,
    String unit = '',
    String? standardValue,
    String? upperLimit,
    String? lowerLimit,
    DateTime? effectiveAt,
    bool isEnabled = true,
    String remark = '',
  }) async {
    parameters = parameters.map((item) {
      if (item.id != paramId) {
        return item;
      }
      return EquipmentRuntimeParameterItem(
        id: item.id,
        equipmentId: equipmentId,
        equipmentType: equipmentType,
        equipmentCode: equipmentId == null ? null : 'EQ-$equipmentId',
        equipmentName: equipmentId == 101 ? '冲压机-1' : null,
        paramCode: paramCode,
        paramName: paramName,
        unit: unit,
        standardValue: standardValue,
        upperLimit: upperLimit,
        lowerLimit: lowerLimit,
        effectiveAt: effectiveAt,
        isEnabled: isEnabled,
        remark: remark,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-03T00:00:00Z'),
      );
    }).toList();
  }

  @override
  Future<void> deleteRuntimeParameter(int paramId) async {
    parameters = parameters.where((item) => item.id != paramId).toList();
  }

  @override
  Future<void> toggleRuntimeParameter({
    required int paramId,
    required bool enabled,
  }) async {
    parameters = parameters.map((item) {
      if (item.id != paramId) {
        return item;
      }
      return EquipmentRuntimeParameterItem(
        id: item.id,
        equipmentId: item.equipmentId,
        equipmentType: item.equipmentType,
        equipmentCode: item.equipmentCode,
        equipmentName: item.equipmentName,
        paramCode: item.paramCode,
        paramName: item.paramName,
        unit: item.unit,
        standardValue: item.standardValue,
        upperLimit: item.upperLimit,
        lowerLimit: item.lowerLimit,
        effectiveAt: item.effectiveAt,
        isEnabled: enabled,
        remark: item.remark,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-03T00:00:00Z'),
      );
    }).toList();
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

Finder _dialogTextFields() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
}

Future<void> _openPopupAction(
  WidgetTester tester,
  Key key,
  String actionText,
) async {
  await tester.tap(
    find.descendant(of: find.byKey(key), matching: find.text('操作')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(actionText).last);
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

    await tester.tap(find.text('清除范围'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('equipment-parameter-scope-banner')),
      findsNothing,
    );
    expect(service.runtimeParameterRequests.last.equipmentId, isNull);
    expect(service.runtimeParameterRequests.last.equipmentType, isNull);
    expect(service.runtimeParameterRequests.last.isEnabled, isNull);
  });

  testWidgets('规则支持新增编辑停用删除', (tester) async {
    final service = _FakeEquipmentService();

    await _pumpPage(tester, service: service);

    await tester.tap(find.widgetWithText(FilledButton, '新增规则'));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogTextFields().at(0), 'RULE-12');
    await tester.enterText(_dialogTextFields().at(1), '温度规则');
    await tester.enterText(_dialogTextFields().at(5), '热处理机');
    await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('温度规则'), findsOneWidget);
    expect(service.rules.any((item) => item.ruleName == '温度规则'), isTrue);

    await _openPopupAction(
      tester,
      const Key('equipment-rule-actions-12'),
      '编辑',
    );
    await tester.enterText(_dialogTextFields().at(1), '温度规则-已编辑');
    await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('温度规则-已编辑'), findsOneWidget);

    await _openPopupAction(
      tester,
      const Key('equipment-rule-actions-12'),
      '停用',
    );
    expect(
      service.rules.singleWhere((item) => item.id == 12).isEnabled,
      isFalse,
    );

    await _openPopupAction(
      tester,
      const Key('equipment-rule-actions-12'),
      '删除',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.rules.any((item) => item.id == 12), isFalse);
    expect(find.text('温度规则-已编辑'), findsNothing);
  });

  testWidgets('运行参数支持新增编辑停用删除', (tester) async {
    final service = _FakeEquipmentService();

    await _pumpPage(tester, service: service);
    await tester.tap(find.text('运行参数'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '新增参数'));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogTextFields().at(0), 'TEMP');
    await tester.enterText(_dialogTextFields().at(1), '温度');
    await tester.enterText(_dialogTextFields().at(7), '热处理机');
    await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('温度'), findsOneWidget);
    expect(service.parameters.any((item) => item.paramName == '温度'), isTrue);

    await _openPopupAction(
      tester,
      const Key('equipment-parameter-actions-22'),
      '编辑',
    );
    await tester.enterText(_dialogTextFields().at(1), '温度-已编辑');
    await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('温度-已编辑'), findsOneWidget);

    await _openPopupAction(
      tester,
      const Key('equipment-parameter-actions-22'),
      '停用',
    );
    expect(
      service.parameters.singleWhere((item) => item.id == 22).isEnabled,
      isFalse,
    );

    await _openPopupAction(
      tester,
      const Key('equipment-parameter-actions-22'),
      '删除',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.parameters.any((item) => item.id == 22), isFalse);
    expect(find.text('温度-已编辑'), findsNothing);
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

  testWidgets('只读参数权限不会展示新增编辑入口', (tester) async {
    final service = _FakeEquipmentService();

    await _pumpPage(
      tester,
      service: service,
      canViewRules: false,
      canManageRules: false,
      canViewParameters: true,
      canManageParameters: false,
    );

    expect(find.text('运行参数'), findsOneWidget);
    expect(find.text('新增参数'), findsNothing);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });
}
