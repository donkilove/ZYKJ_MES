import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';
import 'production_first_article_page.dart';
import 'production_order_query_detail_page.dart';

typedef ProductionOrderQueryExportSaver =
    Future<String?> Function({
      required String filename,
      required String contentBase64,
    });

class _DefectRowDraft {
  _DefectRowDraft({String? phenomenon, int? quantity})
    : phenomenonController = TextEditingController(text: phenomenon ?? ''),
      quantityController = TextEditingController(
        text: quantity == null ? '' : '$quantity',
      );

  final TextEditingController phenomenonController;
  final TextEditingController quantityController;

  void dispose() {
    phenomenonController.dispose();
    quantityController.dispose();
  }
}

class _ProductionSubmitPayload {
  const _ProductionSubmitPayload({
    required this.quantity,
    required this.defectItems,
  });

  final int quantity;
  final List<ProductionDefectItemInput> defectItems;
}

class _ManualRepairSubmitPayload {
  const _ManualRepairSubmitPayload({
    required this.productionQuantity,
    required this.defectItems,
  });

  final int productionQuantity;
  final List<ProductionDefectItemInput> defectItems;
}

class ProductionOrderQueryPage extends StatefulWidget {
  const ProductionOrderQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canFirstArticle,
    required this.canEndProduction,
    required this.canCreateManualRepairOrder,
    required this.canCreateAssistAuthorization,
    required this.canProxyView,
    required this.canExportCsv,
    this.service,
    this.craftService,
    this.saveExportFile,
    this.pollInterval = const Duration(seconds: 12),
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canFirstArticle;
  final bool canEndProduction;
  final bool canCreateManualRepairOrder;
  final bool canCreateAssistAuthorization;
  final bool canProxyView;
  final bool canExportCsv;
  final ProductionService? service;
  final CraftService? craftService;
  final ProductionOrderQueryExportSaver? saveExportFile;
  final Duration pollInterval;

  @override
  State<ProductionOrderQueryPage> createState() =>
      _ProductionOrderQueryPageState();
}

class _ProductionOrderQueryPageState extends State<ProductionOrderQueryPage> {
  late final ProductionService _service;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();
  Timer? _pollTimer;

  bool _loading = false;
  String _message = '';
  String _viewMode = 'own';
  String _orderStatusFilter = 'all';
  int? _currentProcessIdFilter;
  int? _proxyStageId;
  int? _proxyOperatorUserId;
  int _page = 1;
  int _total = 0;
  List<MyOrderItem> _items = const [];
  List<AssistUserOptionItem> _proxyOperators = const [];
  List<AssistUserOptionItem> _proxyViewOperators = const [];
  List<AssistUserOptionItem> _assistUsers = const [];
  List<CraftStageLightItem> _proxyStages = const [];

  static const int _pageSize = 200;

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    if (widget.canProxyView) {
      _loadProxyOperators();
      _loadProxyStages();
    }
    _loadOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _buildQuantitySummary(MyOrderItem item) {
    final assigned = item.userAssignedQuantity;
    final completed =
        item.userCompletedQuantity ?? item.processCompletedQuantity;
    if (assigned != null) {
      return '可见${item.visibleQuantity} / 分配$assigned / 完成$completed';
    }
    return '可见${item.visibleQuantity} / 完成$completed';
  }

  Future<String?> _saveExportFile({
    required String filename,
    required String contentBase64,
  }) async {
    final customSaver = widget.saveExportFile;
    if (customSaver != null) {
      return customSaver(filename: filename, contentBase64: contentBase64);
    }
    final bytes = base64Decode(contentBase64);
    final location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) {
      return null;
    }
    await XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: filename,
    ).saveTo(location.path);
    return location.path;
  }

  Future<void> _exportOrders() async {
    if (!widget.canExportCsv) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前账号无导出权限')));
      return;
    }
    if (_viewMode == 'proxy' &&
        (_proxyStageId == null || _proxyOperatorUserId == null)) {
      setState(() {
        _message = _emptyStateText;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.exportMyOrders(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        viewMode: _viewMode,
        proxyOperatorUserId: _proxyOperatorUserId,
        orderStatus: _orderStatusFilter,
        currentProcessId: _currentProcessIdFilter,
      );
      if (!mounted) {
        return;
      }
      if (result.contentBase64.isEmpty) {
        setState(() {
          _message = '导出失败：服务端返回空数据';
        });
        return;
      }
      final savedPath = await _saveExportFile(
        filename: result.fileName,
        contentBase64: result.contentBase64,
      );
      if (!mounted || savedPath == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功（${result.exportedCount} 条）：$savedPath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '导出失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleRowAction(String action, MyOrderItem item) async {
    switch (action) {
      case 'detail':
        await _openOrderDetailPage(item);
        return;
      case 'history':
        await _openOrderDetailPage(
          item,
          initialTab: ProductionOrderQueryDetailTab.event,
        );
        return;
      case 'first_article':
        await _openFirstArticlePage(item);
        return;
      case 'end_production':
        await _showEndProductionDialog(item);
        return;
      case 'manual_repair':
        await _showManualRepairDialog(item);
        return;
      case 'apply_assist':
        await _showApplyAssistDialog(item);
        return;
    }
  }

  Future<void> _loadProxyOperators() async {
    try {
      final result = await _service.listAssistUserOptions(
        page: 1,
        pageSize: 200,
        roleCode: 'operator',
      );
      if (!mounted) return;
      setState(() {
        _proxyOperators = result.items;
        if (_proxyOperatorUserId != null &&
            !_proxyOperators.any((item) => item.id == _proxyOperatorUserId)) {
          _proxyOperatorUserId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadProxyStages() async {
    try {
      final result = await _craftService.listStageLightOptions();
      if (!mounted) return;
      setState(() {
        _proxyStages = result.items;
        if (_proxyStageId != null &&
            !_proxyStages.any((item) => item.id == _proxyStageId)) {
          _proxyStageId = null;
          _proxyOperatorUserId = null;
          _proxyViewOperators = const [];
        }
      });
    } catch (_) {}
  }

  Future<void> _loadProxyViewOperators(int stageId) async {
    try {
      final result = await _service.listAssistUserOptions(
        page: 1,
        pageSize: 200,
        roleCode: 'operator',
        stageId: stageId,
      );
      if (!mounted || _proxyStageId != stageId) {
        return;
      }
      setState(() {
        _proxyViewOperators = result.items;
        if (_proxyOperatorUserId != null &&
            !_proxyViewOperators.any(
              (item) => item.id == _proxyOperatorUserId,
            )) {
          _proxyOperatorUserId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _ensureTargetOperatorsLoadedForAssistDialog() async {
    if (_proxyOperators.isNotEmpty) {
      return;
    }
    try {
      final result = await _service.listAssistUserOptions(
        page: 1,
        pageSize: 200,
        roleCode: 'operator',
      );
      _proxyOperators = result.items;
    } catch (_) {}
  }

  Future<void> _ensureAssistUsersLoaded() async {
    if (_assistUsers.isNotEmpty) return;
    final result = await _service.listAssistUserOptions(page: 1, pageSize: 200);
    _assistUsers = result.items;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (widget.pollInterval <= Duration.zero) {
      return;
    }
    _pollTimer = Timer.periodic(
      widget.pollInterval,
      (_) => _loadOrders(silent: true),
    );
  }

  Future<void> _loadOrders({bool silent = false, int? page}) async {
    final targetPage = page ?? _page;
    if (_viewMode == 'proxy' &&
        (_proxyStageId == null || _proxyOperatorUserId == null)) {
      if (mounted) {
        setState(() {
          _page = targetPage;
          _items = const [];
          _total = 0;
          _loading = false;
          _message = '';
        });
      }
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _message = '';
      });
    }
    try {
      final result = await _service.listMyOrders(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        viewMode: _viewMode,
        proxyOperatorUserId: _proxyOperatorUserId,
        orderStatus: _orderStatusFilter,
        currentProcessId: _currentProcessIdFilter,
      );
      if (!mounted) return;
      final totalPages = result.total <= 0
          ? 1
          : ((result.total + _pageSize - 1) ~/ _pageSize);
      if (result.total > 0 && targetPage > totalPages) {
        setState(() {
          _page = totalPages;
          _total = result.total;
          _items = const [];
        });
        await _loadOrders(silent: silent, page: totalPages);
        return;
      }
      setState(() {
        _page = targetPage;
        _items = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (!silent) {
        setState(() {
          _message = '加载工单失败：${_errorMessage(error)}';
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String get _emptyStateText {
    if (_viewMode != 'proxy') {
      return '暂无可执行生产工单';
    }
    if (_proxyStages.isEmpty) {
      return '暂无可用工段';
    }
    if (_proxyStageId == null) {
      return '请先选择工段，再选择代理操作员查看工单';
    }
    if (_proxyViewOperators.isEmpty) {
      return '当前工段下暂无可代理操作员';
    }
    if (_proxyOperatorUserId == null) {
      return '请先选择代理操作员后查看工单';
    }
    return '暂无可执行生产工单';
  }

  Future<MyOrderContextResult> _fetchOrderContextInCurrentView(
    int orderId,
  ) async {
    try {
      return await _service.getMyOrderContext(
        orderId: orderId,
        viewMode: _viewMode,
        proxyOperatorUserId: _proxyOperatorUserId,
      );
    } catch (error) {
      if (!mounted) {
        return MyOrderContextResult(found: false, item: null);
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return MyOrderContextResult(found: false, item: null);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return MyOrderContextResult(found: false, item: null);
    }
  }

  Future<void> _openOrderDetailPage(
    MyOrderItem item, {
    ProductionOrderQueryDetailTab initialTab =
        ProductionOrderQueryDetailTab.process,
  }) async {
    final needsRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductionOrderQueryDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          orderId: item.orderId,
          service: _service,
          canFirstArticle: widget.canFirstArticle,
          canEndProduction: widget.canEndProduction,
          canCreateManualRepairOrder: widget.canCreateManualRepairOrder,
          canCreateAssistAuthorization: widget.canCreateAssistAuthorization,
          initialOrderContext: item,
          onSubmitFirstArticle: (target) =>
              _openFirstArticlePage(target, reloadAfterAction: false),
          onEndProduction: (target) =>
              _showEndProductionDialog(target, reloadAfterAction: false),
          onCreateManualRepair: (target) =>
              _showManualRepairDialog(target, reloadAfterAction: false),
          onApplyAssist: (target) =>
              _showApplyAssistDialog(target, reloadAfterAction: false),
          onRefreshOrderContext: _fetchOrderContextInCurrentView,
          initialTab: initialTab,
        ),
      ),
    );
    if (needsRefresh == true && mounted) {
      await _loadOrders();
    }
  }

  Future<bool> _openFirstArticlePage(
    MyOrderItem item, {
    bool reloadAfterAction = true,
  }) async {
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ProductionFirstArticlePage(
            session: widget.session,
            onLogout: widget.onLogout,
            order: item,
            service: _service,
          ),
        ),
      );
      if (changed != true) {
        return false;
      }
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开始首件成功')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    }
  }

  Future<bool> _showEndProductionDialog(
    MyOrderItem item, {
    bool reloadAfterAction = true,
  }) async {
    final qtyController = TextEditingController(
      text: '${item.maxProducibleQuantity.clamp(1, 999999)}',
    );
    final defectRows = <_DefectRowDraft>[];
    try {
      final payload = await showLockedFormDialog<_ProductionSubmitPayload?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('结束生产'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '有效流转数量',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('不良现象（可选）'),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              defectRows.add(_DefectRowDraft());
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新增'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(defectRows.length, (index) {
                      final row = defectRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.phenomenonController,
                                decoration: const InputDecoration(
                                  labelText: '现象',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '数量',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  final removed = defectRows.removeAt(index);
                                  removed.dispose();
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final qty = int.tryParse(qtyController.text.trim());
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入有效结束生产数量')),
                    );
                    return;
                  }
                  final defects = <ProductionDefectItemInput>[];
                  for (final row in defectRows) {
                    final phenomenon = row.phenomenonController.text.trim();
                    final qtyText = row.quantityController.text.trim();
                    if (phenomenon.isEmpty && qtyText.isEmpty) {
                      continue;
                    }
                    final defectQty = int.tryParse(qtyText);
                    if (phenomenon.isEmpty ||
                        defectQty == null ||
                        defectQty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('不良明细需同时填写现象与正整数数量')),
                      );
                      return;
                    }
                    defects.add(
                      ProductionDefectItemInput(
                        phenomenon: phenomenon,
                        quantity: defectQty,
                      ),
                    );
                  }
                  final defectTotal = defects.fold<int>(
                    0,
                    (sum, entry) => sum + entry.quantity,
                  );
                  if (qty + defectTotal > item.maxProducibleQuantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '结束生产数量与异常数量合计不能超过当前可生产数量 ${item.maxProducibleQuantity}',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _ProductionSubmitPayload(
                      quantity: qty,
                      defectItems: defects,
                    ),
                  );
                },
                child: const Text('提交'),
              ),
            ],
          ),
        ),
      );
      if (payload == null) {
        return false;
      }
      await _service.endProduction(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        pipelineInstanceId: item.pipelineInstanceId,
        quantity: payload.quantity,
        effectiveOperatorUserId: item.operatorUserId,
        assistAuthorizationId: item.assistAuthorizationId,
        defectItems: payload.defectItems,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束生产成功')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        qtyController.dispose();
        for (final row in defectRows) {
          row.dispose();
        }
      });
    }
  }

  Future<bool> _showManualRepairDialog(
    MyOrderItem item, {
    bool reloadAfterAction = true,
  }) async {
    final productionQtyController = TextEditingController(
      text: '${item.maxProducibleQuantity.clamp(1, 999999)}',
    );
    final defectRows = <_DefectRowDraft>[_DefectRowDraft()];
    try {
      final payload = await showLockedFormDialog<_ManualRepairSubmitPayload?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('手工送修建单'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: productionQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '本次生产数量',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('不良现象明细'),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              defectRows.add(_DefectRowDraft());
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新增'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(defectRows.length, (index) {
                      final row = defectRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.phenomenonController,
                                decoration: const InputDecoration(
                                  labelText: '现象',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '数量',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: defectRows.length <= 1
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        final removed = defectRows.removeAt(
                                          index,
                                        );
                                        removed.dispose();
                                      });
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final productionQty = int.tryParse(
                    productionQtyController.text.trim(),
                  );
                  if (productionQty == null || productionQty <= 0) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('请输入本次生产数量')));
                    return;
                  }
                  final defects = <ProductionDefectItemInput>[];
                  for (final row in defectRows) {
                    final phenomenon = row.phenomenonController.text.trim();
                    final defectQty = int.tryParse(
                      row.quantityController.text.trim(),
                    );
                    if (phenomenon.isEmpty ||
                        defectQty == null ||
                        defectQty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请完整填写不良现象明细')),
                      );
                      return;
                    }
                    defects.add(
                      ProductionDefectItemInput(
                        phenomenon: phenomenon,
                        quantity: defectQty,
                      ),
                    );
                  }
                  Navigator.of(context).pop(
                    _ManualRepairSubmitPayload(
                      productionQuantity: productionQty,
                      defectItems: defects,
                    ),
                  );
                },
                child: const Text('提交建单'),
              ),
            ],
          ),
        ),
      );
      if (payload == null) {
        return false;
      }
      await _service.createManualRepairOrder(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        productionQuantity: payload.productionQuantity,
        defectItems: payload.defectItems,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('维修单创建成功')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        productionQtyController.dispose();
        for (final row in defectRows) {
          row.dispose();
        }
      });
    }
  }

  Future<bool> _showApplyAssistDialog(
    MyOrderItem item, {
    bool reloadAfterAction = true,
  }) async {
    await _ensureAssistUsersLoaded();
    await _ensureTargetOperatorsLoadedForAssistDialog();
    if (!mounted) {
      return false;
    }
    final targetOperators = _proxyOperators.isNotEmpty
        ? [
            ..._proxyOperators,
            if (item.operatorUserId != null &&
                !_proxyOperators.any((it) => it.id == item.operatorUserId))
              AssistUserOptionItem(
                id: item.operatorUserId!,
                username:
                    (item.operatorUsername == null ||
                        item.operatorUsername!.trim().isEmpty)
                    ? 'operator_${item.operatorUserId}'
                    : item.operatorUsername!,
                fullName: null,
                roleCodes: const ['operator'],
              ),
          ]
        : [
            if (item.operatorUserId != null)
              AssistUserOptionItem(
                id: item.operatorUserId!,
                username:
                    (item.operatorUsername == null ||
                        item.operatorUsername!.trim().isEmpty)
                    ? 'operator_${item.operatorUserId}'
                    : item.operatorUsername!,
                fullName: null,
                roleCodes: const ['operator'],
              ),
          ];
    int? targetId = item.operatorUserId;
    int? helperId;
    final reasonController = TextEditingController();
    try {
      final ok = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('发起代班'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: targetId,
                      decoration: const InputDecoration(
                        labelText: '目标操作员',
                        border: OutlineInputBorder(),
                      ),
                      items: targetOperators
                          .map(
                            (it) => DropdownMenuItem<int>(
                              value: it.id,
                              child: Text(it.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => targetId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: helperId,
                      decoration: const InputDecoration(
                        labelText: '代班人',
                        border: OutlineInputBorder(),
                      ),
                      items: _assistUsers
                          .map(
                            (it) => DropdownMenuItem<int>(
                              value: it.id,
                              child: Text(it.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => helperId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '代班原因（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('发起代班'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || targetId == null || helperId == null) {
        return false;
      }
      await _service.createAssistAuthorization(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        targetOperatorUserId: targetId!,
        helperUserId: helperId!,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('代班已发起并立即生效')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reasonController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final processFilterOptions =
        _items
            .map(
              (item) =>
                  (id: item.currentProcessId, name: item.currentProcessName),
            )
            .toSet()
            .toList()
          ..sort((left, right) {
            final byName = left.name.compareTo(right.name);
            if (byName != 0) {
              return byName;
            }
            return left.id.compareTo(right.id);
          });
    final hasSelectedProcess = _currentProcessIdFilter == null
        ? true
        : processFilterOptions.any(
            (entry) => entry.id == _currentProcessIdFilter,
          );
    if (_currentProcessIdFilter != null && !hasSelectedProcess) {
      processFilterOptions.insert(0, (
        id: _currentProcessIdFilter!,
        name: '工序',
      ));
    }
    final processDropdownValue = _currentProcessIdFilter;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrudPageHeader(
            title: '生产订单查询',
            onRefresh: _loading ? null : _loadOrders,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索订单号/产品/供应商/工序',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadOrders(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadOrders(page: 1),
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              if (widget.canExportCsv) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _exportOrders,
                  icon: const Icon(Icons.download),
                  label: const Text('导出CSV'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _viewMode,
                    decoration: const InputDecoration(
                      labelText: '工单视角',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'own', child: Text('我的工单')),
                      const DropdownMenuItem(
                        value: 'assist',
                        child: Text('我的代班工单'),
                      ),
                      if (widget.canProxyView)
                        const DropdownMenuItem(
                          value: 'proxy',
                          child: Text('代理操作员视角'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _viewMode) return;
                      setState(() {
                        _viewMode = value;
                        _page = 1;
                        if (_viewMode != 'proxy') {
                          _proxyStageId = null;
                          _proxyOperatorUserId = null;
                          _proxyViewOperators = const [];
                        }
                      });
                      if (value == 'proxy' && _proxyStages.isEmpty) {
                        _loadProxyStages();
                      }
                      _loadOrders(page: 1);
                    },
                  ),
                ),
                if (widget.canProxyView && _viewMode == 'proxy') ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_proxyStageId),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '代理工段',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      initialValue: _proxyStageId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('请选择工段'),
                        ),
                        ..._proxyStages.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.id,
                            child: Text(
                              entry.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == _proxyStageId) {
                          return;
                        }
                        setState(() {
                          _proxyStageId = value;
                          _proxyOperatorUserId = null;
                          _proxyViewOperators = const [];
                          _items = const [];
                          _total = 0;
                          _page = 1;
                        });
                        if (value != null) {
                          _loadProxyViewOperators(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'proxyOperator_${_proxyStageId ?? 0}_${_proxyOperatorUserId ?? 0}',
                      ),
                      isExpanded: true,
                      initialValue: _proxyOperatorUserId,
                      decoration: const InputDecoration(
                        labelText: '代理操作员',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _proxyViewOperators
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.id,
                              child: Text(
                                entry.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) => _proxyViewOperators
                          .map(
                            (entry) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _proxyStageId == null || _proxyViewOperators.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                _proxyOperatorUserId = value;
                                _page = 1;
                              });
                              _loadOrders(page: 1);
                            },
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _orderStatusFilter,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待生产')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('生产中'),
                      ),
                      DropdownMenuItem(value: 'completed', child: Text('生产完成')),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _orderStatusFilter) {
                        return;
                      }
                      setState(() {
                        _orderStatusFilter = value;
                        _page = 1;
                      });
                      _loadOrders(page: 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey<int?>(processDropdownValue),
                    initialValue: processDropdownValue,
                    decoration: const InputDecoration(
                      labelText: '当前工序',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部工序'),
                      ),
                      ...processFilterOptions.map(
                        (entry) => DropdownMenuItem<int?>(
                          value: entry.id,
                          child: Text('${entry.name} (#${entry.id})'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == _currentProcessIdFilter) {
                        return;
                      }
                      setState(() {
                        _currentProcessIdFilter = value;
                        _page = 1;
                      });
                      _loadOrders(page: 1);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: CrudListTableSection(
              cardKey: const ValueKey('productionOrderQueryListCard'),
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: _emptyStateText,
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columns: [
                  UnifiedListTableHeaderStyle.column(context, '订单编号'),
                  UnifiedListTableHeaderStyle.column(context, '产品型号'),
                  UnifiedListTableHeaderStyle.column(context, '供应商'),
                  UnifiedListTableHeaderStyle.column(context, '工序'),
                  UnifiedListTableHeaderStyle.column(context, '数量概况'),
                  UnifiedListTableHeaderStyle.column(context, '状态'),
                  UnifiedListTableHeaderStyle.column(context, '交货日期'),
                  UnifiedListTableHeaderStyle.column(context, '备注'),
                  UnifiedListTableHeaderStyle.column(context, '操作'),
                ],
                rows: _items.map((item) {
                  final supplierName = item.supplierName?.trim();
                  final remark = item.remark?.trim();
                  return DataRow(
                    cells: [
                      DataCell(Text(item.orderCode)),
                      DataCell(Text(item.productName)),
                      DataCell(
                        Text(
                          supplierName == null || supplierName.isEmpty
                              ? '-'
                              : supplierName,
                        ),
                      ),
                      DataCell(Text(item.currentProcessName)),
                      DataCell(Text(_buildQuantitySummary(item))),
                      DataCell(
                        Text(productionOrderStatusLabel(item.orderStatus)),
                      ),
                      DataCell(Text(_formatDate(item.dueDate))),
                      DataCell(
                        Text(remark == null || remark.isEmpty ? '-' : remark),
                      ),
                      DataCell(
                        UnifiedListTableHeaderStyle.actionMenuButton<String>(
                          theme: theme,
                          onSelected: (action) =>
                              _handleRowAction(action, item),
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'detail',
                              child: Text('详情'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'history',
                              child: Text('历史'),
                            ),
                            if (widget.canFirstArticle && item.canFirstArticle)
                              const PopupMenuItem<String>(
                                value: 'first_article',
                                child: Text('开始首件'),
                              ),
                            if (widget.canEndProduction &&
                                item.canEndProduction)
                              const PopupMenuItem<String>(
                                value: 'end_production',
                                child: Text('结束生产'),
                              ),
                            if (widget.canCreateManualRepairOrder &&
                                item.canCreateManualRepair)
                              const PopupMenuItem<String>(
                                value: 'manual_repair',
                                child: Text('送修'),
                              ),
                            if (widget.canCreateAssistAuthorization &&
                                item.canApplyAssist)
                              const PopupMenuItem<String>(
                                value: 'apply_assist',
                                child: Text('代班'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadOrders(page: _page - 1),
            onNext: () => _loadOrders(page: _page + 1),
          ),
        ],
      ),
    );
  }
}
