import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/quality/presentation/quality_supplier_management_page.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_supplier_form_dialog.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

void main() {
  final session = AppSession(baseUrl: 'http://localhost', accessToken: 'token');

  Widget wrapBody(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
  }

  testWidgets('质量页签可展示供应商管理入口', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '初始供应商', remark: '初始备注'),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualityPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [qualitySupplierManagementTabCode],
          capabilityCodes: const <String>{},
          preferredTabCode: qualitySupplierManagementTabCode,
          supplierService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('供应商管理'), findsAtLeastNWidgets(1));
    expect(find.text('初始供应商'), findsOneWidget);
  });

  testWidgets('质量供应商管理页接入统一页头锚点', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '初始供应商', remark: '初始备注'),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierManagementPage(
          session: session,
          onLogout: () {},
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-supplier-management-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('刷新页面'), findsNothing);
  });

  testWidgets('供应商管理页可完成新增编辑', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '初始供应商', remark: '初始备注'),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierManagementPage(
          session: session,
          onLogout: () {},
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('新增供应商'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '测试供应商B');
    await tester.enterText(find.widgetWithText(TextFormField, '备注'), '新增备注');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('当前为停用'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(find.text('测试供应商B'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '编辑').last);
    await tester.tap(find.widgetWithText(OutlinedButton, '编辑').last);
    await tester.pumpAndSettle();
    expect(find.text('当前为停用'), findsAtLeastNWidgets(1));
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('当前为启用'), findsAtLeastNWidgets(1));
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '更新供应商');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.updateCalls, 1);
    expect(find.text('更新供应商'), findsOneWidget);
    expect(find.text('停用'), findsNothing);
  });

  testWidgets('删除成功后刷新列表并提示成功', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 3, name: '待删除供应商', remark: '可删除'),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierManagementPage(
          session: session,
          onLogout: () {},
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('待删除供应商'), findsOneWidget);

    await tester.tap(find.text('删除').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(find.text('供应商已删除'), findsOneWidget);
    expect(find.text('待删除供应商'), findsNothing);
    expect(find.text('暂无供应商数据'), findsOneWidget);
  });

  testWidgets('删除被引用供应商时展示后端中文错误', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 7, name: '引用供应商', remark: '已被订单使用'),
    ])..deleteError = ApiException('供应商已被生产订单引用，无法删除', 409);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierManagementPage(
          session: session,
          onLogout: () {},
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('删除').first);
    await tester.tap(find.text('删除').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('供应商已被生产订单引用，无法删除'), findsOneWidget);
  });

  testWidgets('质量供应商表单弹窗展示宽版双栏骨架', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '初始供应商', remark: '初始备注'),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierFormDialog(
          supplierService: service,
          item: _buildSupplier(
            id: 8,
            name: '编辑供应商',
            remark: '历史备注',
            isEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-supplier-form-dialog')),
      findsOneWidget,
    );
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('状态与说明'), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('当前状态'), findsOneWidget);
  });

  testWidgets('供应商管理页支持关键词与启停筛选', (tester) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '供应商A', remark: '启用', isEnabled: true),
      _buildSupplier(id: 2, name: '供应商B', remark: '停用', isEnabled: false),
    ]);

    await tester.pumpWidget(
      wrapBody(
        QualitySupplierManagementPage(
          session: session,
          onLogout: () {},
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '搜索供应商名称'), '供应商B');
    await tester.tap(find.byType(DropdownButtonFormField<bool?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();

    expect(service.lastKeyword, '供应商B');
    expect(service.lastEnabled, isFalse);
  });
}

QualitySupplierItem _buildSupplier({
  required int id,
  required String name,
  String? remark,
  bool isEnabled = true,
}) {
  return QualitySupplierItem(
    id: id,
    name: name,
    remark: remark,
    isEnabled: isEnabled,
    createdAt: DateTime(2026, 4, 2, 8),
    updatedAt: DateTime(2026, 4, 2, 9),
  );
}

class _FakeQualitySupplierService extends QualitySupplierService {
  _FakeQualitySupplierService(List<QualitySupplierItem> initialItems)
    : _items = List<QualitySupplierItem>.from(initialItems),
      super(AppSession(baseUrl: 'http://localhost', accessToken: 'test-token'));

  final List<QualitySupplierItem> _items;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  String? lastKeyword;
  bool? lastEnabled;
  ApiException? deleteError;

  @override
  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    lastKeyword = keyword;
    lastEnabled = enabled;
    return QualitySupplierListResult(total: _items.length, items: [..._items]);
  }

  @override
  Future<QualitySupplierItem> createSupplier(
    QualitySupplierUpsertPayload payload,
  ) async {
    createCalls += 1;
    final item = QualitySupplierItem(
      id: _items.isEmpty ? 1 : _items.last.id + 1,
      name: payload.name,
      remark: payload.remark,
      isEnabled: payload.isEnabled,
      createdAt: DateTime(2026, 4, 2, 10),
      updatedAt: DateTime(2026, 4, 2, 10),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<QualitySupplierItem> updateSupplier(
    int supplierId,
    QualitySupplierUpsertPayload payload,
  ) async {
    updateCalls += 1;
    final index = _items.indexWhere((item) => item.id == supplierId);
    final updated = QualitySupplierItem(
      id: supplierId,
      name: payload.name,
      remark: payload.remark,
      isEnabled: payload.isEnabled,
      createdAt: _items[index].createdAt,
      updatedAt: DateTime(2026, 4, 2, 11),
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteSupplier(int supplierId) async {
    deleteCalls += 1;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    _items.removeWhere((item) => item.id == supplierId);
  }
}
