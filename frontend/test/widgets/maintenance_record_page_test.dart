import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/pages/maintenance_record_page.dart';
import 'package:mes_client/services/equipment_service.dart';

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService({required this.records})
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<MaintenanceRecordItem> records;

  @override
  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? locationKeyword,
    String? ownerName,
  }) async {
    return EquipmentLedgerListResult(total: 0, items: const []);
  }

  @override
  Future<List<EquipmentOwnerOption>> listAllOwners() async {
    return [
      EquipmentOwnerOption(
        userId: 8,
        username: 'worker',
        fullName: null,
      ),
    ];
  }

  @override
  Future<MaintenanceRecordListResult> listRecords({
    required int page,
    required int pageSize,
    String? keyword,
    int? executorId,
    DateTime? startDate,
    DateTime? endDate,
    String? resultSummary,
    int? equipmentId,
  }) async {
    return MaintenanceRecordListResult(total: records.length, items: records);
  }
}

MaintenanceRecordItem _buildRecord({required int id, String? attachmentLink}) {
  return MaintenanceRecordItem(
    id: id,
    workOrderId: 100 + id,
    equipmentName: '设备$id',
    itemName: '点检$id',
    dueDate: DateTime.parse('2026-03-31T00:00:00Z'),
    executorUserId: 8,
    executorUsername: 'worker',
    completedAt: DateTime.parse('2026-03-31T10:00:00Z'),
    resultSummary: '完成',
    resultRemark: '正常',
    attachmentLink: attachmentLink,
    attachmentName: attachmentLink == null ? null : 'a',
    createdAt: DateTime.parse('2026-03-31T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-31T10:00:00Z'),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeEquipmentService equipmentService,
  Future<void> Function(String urlText)? onOpenAttachment,
}) async {
  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MaintenanceRecordPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          equipmentService: equipmentService,
          onOpenAttachment: onOpenAttachment,
        ),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  testWidgets('有附件时展示可点击入口并触发复用打开能力', (tester) async {
    String? openedUrl;
    await _pumpPage(
      tester,
      equipmentService: _FakeEquipmentService(
        records: [_buildRecord(id: 1, attachmentLink: 'https://example.com/a')],
      ),
      onOpenAttachment: (urlText) async {
        openedUrl = urlText;
      },
    );

    expect(find.text('下载附件'), findsOneWidget);
    expect(find.text('无附件'), findsNothing);

    await tester.tap(find.text('下载附件'));
    await tester.pump();

    expect(openedUrl, 'https://example.com/a');
  });

  testWidgets('无附件时展示明确占位', (tester) async {
    await _pumpPage(
      tester,
      equipmentService: _FakeEquipmentService(
        records: [_buildRecord(id: 2, attachmentLink: '  ')],
      ),
    );

    expect(find.text('无附件'), findsOneWidget);
    expect(find.text('下载附件'), findsNothing);
  });

  testWidgets('存在候选人员时展示执行人筛选器', (tester) async {
    await _pumpPage(
      tester,
      equipmentService: _FakeEquipmentService(records: [_buildRecord(id: 3)]),
    );

    expect(find.text('执行人'), findsWidgets);
  });
}
