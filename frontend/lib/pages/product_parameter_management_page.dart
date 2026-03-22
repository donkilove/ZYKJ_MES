import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/unified_list_table_header_style.dart';

enum _ProductParameterManagementListAction { view, edit, history, export }

class ProductParameterManagementPage extends StatefulWidget {
  const ProductParameterManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.service,
    this.jumpCommand,
    this.onJumpHandled,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductService? service;
  final ProductJumpCommand? jumpCommand;
  final ValueChanged<int>? onJumpHandled;

  @override
  State<ProductParameterManagementPage> createState() =>
      _ProductParameterManagementPageState();
}

class _ProductParameterManagementPageState
    extends State<ProductParameterManagementPage> {
  static const String _productNameParameterKey = '产品名称';
  static const List<String> _presetCategorySuggestions = [
    '基础参数',
    '激光打标参数',
    '产品测试参数',
    '产品组装参数',
    '产品包装参数',
  ];
  static const Set<String> _allowedCategorySet = {
    '基础参数',
    '激光打标参数',
    '产品测试参数',
    '产品组装参数',
    '产品包装参数',
  };
  static const double _rowActionButtonSize = 36.0;
  static const double _rowActionGap = 4.0;
  static const double _rowActionColumnWidth =
      (_rowActionButtonSize * 2) + _rowActionGap + 8;
  static const double _editorMinContentWidth = 1180.0;

  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  final TextEditingController _remarkController = TextEditingController();
  final ScrollController _editorVerticalController = ScrollController();
  final ScrollController _editorHorizontalController = ScrollController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<ProductParameterVersionListItem> _versionRows = const [];
  String _selectedCategoryFilter = '';
  DateTime? _updatedAfter;
  DateTime? _updatedBefore;
  final TextEditingController _versionFilterController =
      TextEditingController();
  final TextEditingController _paramNameFilterController =
      TextEditingController();
  final TextEditingController _paramCategoryFilterController =
      TextEditingController();

  int _handledJumpSeq = 0;

  ProductParameterVersionListItem? _editingTarget;
  String _editingVersionLabel = '';
  String _editingLifecycleStatus = '';
  bool _editorLoading = false;
  bool _editorSubmitting = false;
  String _editorMessage = '';
  List<_ParameterEditorRow> _editorRows = const [];
  bool _hasUnsavedChanges = false;
  int _editorRowIdSeed = 1;
  String _editorGroupFilter = '';

  bool get _editorReadOnly =>
      _editingLifecycleStatus.isNotEmpty && _editingLifecycleStatus != 'draft';

  @override
  void initState() {
    super.initState();
    _productService = widget.service ?? ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductParameterManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final command = widget.jumpCommand;
    if (command == null || command.seq == _handledJumpSeq) {
      return;
    }
    if (command.targetTabCode != widget.tabCode) {
      return;
    }
    _handledJumpSeq = command.seq;
    unawaited(_handleJumpCommand(command));
  }

  @override
  void dispose() {
    _disposeEditorRows();
    _keywordController.dispose();
    _versionFilterController.dispose();
    _paramNameFilterController.dispose();
    _paramCategoryFilterController.dispose();
    _remarkController.dispose();
    _editorVerticalController.dispose();
    _editorHorizontalController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  String _historyTypeLabel(String value) {
    switch (value) {
      case 'create':
        return '创建';
      case 'copy':
        return '复制';
      case 'activate':
        return '生效';
      case 'disable':
        return '停用';
      case 'delete':
        return '删除';
      case 'rollback':
        return '回滚';
      default:
        return '编辑';
    }
  }

  String _lifecycleLabel(String value) {
    switch (value) {
      case 'draft':
        return '草稿';
      case 'effective':
        return '已生效';
      case 'obsolete':
        return '已失效';
      case 'disabled':
        return '已停用';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  List<PopupMenuEntry<_ProductParameterManagementListAction>>
  _buildListActionMenuItems() {
    return const [
      PopupMenuItem(
        value: _ProductParameterManagementListAction.view,
        child: Text('查看参数'),
      ),
      PopupMenuItem(
        value: _ProductParameterManagementListAction.history,
        child: Text('查看历史'),
      ),
      PopupMenuItem(
        value: _ProductParameterManagementListAction.edit,
        child: Text('编辑参数'),
      ),
      PopupMenuItem(
        value: _ProductParameterManagementListAction.export,
        child: Text('导出参数'),
      ),
    ];
  }

  Future<void> _handleListAction(
    _ProductParameterManagementListAction action,
    ProductParameterVersionListItem row,
  ) async {
    switch (action) {
      case _ProductParameterManagementListAction.view:
        await _enterEditor(row);
        return;
      case _ProductParameterManagementListAction.history:
        await _showHistoryDialog(row);
        return;
      case _ProductParameterManagementListAction.edit:
        await _enterEditor(row);
        return;
      case _ProductParameterManagementListAction.export:
        await _exportVersionParameters(row);
        return;
    }
  }

  ProductParameterVersionListItem? _findVersionRow(
    int productId,
    int? version,
  ) {
    ProductParameterVersionListItem? currentVersionRow;
    for (final row in _versionRows) {
      if (row.productId != productId) {
        continue;
      }
      if (version != null && row.version == version) {
        return row;
      }
      if (row.isCurrentVersion) {
        currentVersionRow = row;
      }
    }
    return currentVersionRow;
  }

  bool _isProductNameParameterName(String name) {
    return name.trim() == _productNameParameterKey;
  }

  bool _isProductNameRow(_ParameterEditorRow row) {
    return _isProductNameParameterName(row.nameController.text);
  }

  void _attachCategoryDirtyListener(_ParameterEditorRow row) {
    if (row.categoryListenerBound) {
      return;
    }
    row.categoryController.addListener(() {
      if (!mounted || _editorLoading) {
        return;
      }
      _markDirty();
    });
    row.categoryListenerBound = true;
  }

  List<String> _buildCategorySuggestions() {
    return _presetCategorySuggestions;
  }

  int _nextEditorRowId() {
    final id = _editorRowIdSeed;
    _editorRowIdSeed += 1;
    return id;
  }

  void _markDirty() {
    if (_hasUnsavedChanges) {
      return;
    }
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  void _disposeEditorRows() {
    for (final row in _editorRows) {
      row.dispose();
    }
    _editorRows = const [];
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final result = await _productService.listProductParameterVersions(
        page: 1,
        pageSize: 10000,
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        versionKeyword: _versionFilterController.text.trim(),
        updatedAfter: _updatedAfter,
        updatedBefore: _updatedBefore,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _versionRows = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载产品失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<ProductParameterVersionListItem> get _filteredVersionRows {
    return _versionRows.where((row) {
      final paramNameKeyword = _paramNameFilterController.text.trim();
      final paramCategoryKeyword = _paramCategoryFilterController.text.trim();
      final summary = row.parameterSummary ?? '';
      if (paramNameKeyword.isNotEmpty && !summary.contains(paramNameKeyword)) {
        return false;
      }
      if (paramCategoryKeyword.isNotEmpty &&
          !summary.contains(paramCategoryKeyword)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleJumpCommand(ProductJumpCommand command) async {
    _keywordController.text = command.productName;
    await _loadProducts();
    if (!mounted) {
      return;
    }
    if (command.action == 'edit') {
      final row = _findVersionRow(command.productId, command.targetVersion);
      if (row != null) {
        await _enterEditor(
          row,
          requestedVersionLabel: command.targetVersionLabel,
        );
        if (mounted && _editingTarget?.productId == command.productId) {
          widget.onJumpHandled?.call(command.seq);
        }
      }
    }
  }

  Future<void> _showHistoryDialog(ProductParameterVersionListItem row) async {
    ProductParameterHistoryListResult? historyResult;
    try {
      historyResult = await _productService.listProductParameterHistory(
        productId: row.productId,
        version: row.version,
        page: 1,
        pageSize: 100,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      _showSnackBar('加载历史失败：${_errorMessage(error)}');
      return;
    }

    if (!mounted) {
      return;
    }

    final dialogHistory = historyResult;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '历史修改备注 - ${row.productName}（${dialogHistory.versionLabel ?? row.versionLabel}）',
          ),
          content: SizedBox(
            width: 760,
            height: 480,
            child: dialogHistory.items.isEmpty
                ? const Center(child: Text('暂无历史记录'))
                : ListView.separated(
                    itemCount: dialogHistory.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = dialogHistory.items[index];
                      final keySummary = item.changedKeys.isEmpty
                          ? '无参数字段变化'
                          : item.changedKeys.join(', ');
                      final changeTypeLabel = _historyTypeLabel(
                        item.changeType,
                      );
                      return ListTile(
                        title: Text(item.remark),
                        subtitle: Text(
                          '时间：${_formatTime(item.createdAt)}\n'
                          '版本：${item.versionLabel ?? '-'}   操作人：${item.operatorUsername}   类型：$changeTypeLabel\n'
                          '参数：$keySummary',
                        ),
                        isThreeLine: true,
                        trailing:
                            item.beforeSnapshot != '{}' ||
                                item.afterSnapshot != '{}'
                            ? TextButton(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('变更前后快照'),
                                      content: SizedBox(
                                        width: 680,
                                        height: 400,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '变更前：',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              SelectableText(
                                                item.beforeSnapshot,
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                '变更后：',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              SelectableText(
                                                item.afterSnapshot,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: const Text('关闭'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('查看快照'),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportVersionParameters(
    ProductParameterVersionListItem row,
  ) async {
    try {
      final bytes = await _productService.exportProductVersionParameters(
        productId: row.productId,
        version: row.version,
      );
      final location = await getSaveLocation(
        suggestedName: '${row.productName}_${row.versionLabel}_参数.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) {
        return;
      }
      await XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: '${row.productName}_${row.versionLabel}_参数.csv',
      ).saveTo(location.path);
      _showSnackBar('导出成功：${location.path}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      _showSnackBar('导出失败：${_errorMessage(error)}');
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('放弃未保存的修改？'),
          content: const Text('当前编辑内容尚未保存，离开后将丢失本次修改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃修改'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmImpactForEffectiveUpdate(
    ProductImpactAnalysisResult impact,
  ) async {
    if (!impact.requiresConfirmation) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('变更影响确认'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '存在 ${impact.totalOrders} 条未完工订单（待开工 ${impact.pendingOrders}，生产中 ${impact.inProgressOrders}）。',
                ),
                const SizedBox(height: 8),
                const Text('确认后将按强制模式继续保存。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认继续'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _exitEditor({bool force = false}) async {
    if (_editingTarget == null) {
      return true;
    }

    if (!force) {
      final canLeave = await _confirmDiscardChanges();
      if (!canLeave) {
        return false;
      }
    }

    _disposeEditorRows();
    _remarkController.clear();
    if (!mounted) {
      return true;
    }
    setState(() {
      _editingTarget = null;
      _editingVersionLabel = '';
      _editingLifecycleStatus = '';
      _editorLoading = false;
      _editorSubmitting = false;
      _editorMessage = '';
      _hasUnsavedChanges = false;
    });
    return true;
  }

  Future<void> _enterEditor(
    ProductParameterVersionListItem row, {
    String? requestedVersionLabel,
  }) async {
    if (_editorSubmitting) {
      return;
    }
    if (!await _exitEditor()) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _editingTarget = row;
      _editorLoading = true;
      _editorSubmitting = false;
      _editorMessage = '';
      _hasUnsavedChanges = false;
      _remarkController.clear();
    });

    ProductParameterListResult result;
    try {
      result = await _productService.getProductVersionParameters(
        productId: row.productId,
        version: row.version,
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
        _editorRows = const [];
        _editorLoading = false;
        _editorMessage = '加载参数失败：${_errorMessage(error)}';
      });
      return;
    }

    final rows = result.items.map((item) {
      final row = _ParameterEditorRow.initial(
        rowId: _nextEditorRowId(),
        name: item.name,
        category: item.category,
        parameterType: item.type,
        value: item.value,
        description: item.description,
      );
      _attachCategoryDirtyListener(row);
      return row;
    }).toList();

    if (!mounted) {
      for (final row in rows) {
        row.dispose();
      }
      return;
    }

    _disposeEditorRows();
    setState(() {
      _editorRows = rows;
      _editingTarget = row;
      _editingVersionLabel = requestedVersionLabel ?? result.versionLabel;
      _editingLifecycleStatus = result.lifecycleStatus;
      _editorLoading = false;
      _editorMessage = '';
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _pickLinkValue(_ParameterEditorRow row) async {
    final file = await openFile();
    if (file == null) {
      return;
    }
    if (row.valueController.text == file.path) {
      return;
    }
    row.valueController.text = file.path;
    _markDirty();
  }

  Future<void> _saveEditor() async {
    final target = _editingTarget;
    if (target == null || _editorSubmitting) {
      return;
    }
    if (_editorReadOnly) {
      _showSnackBar('当前版本不是草稿，已切换为只读，请先在版本管理中复制或新建草稿版本');
      return;
    }

    final remark = _remarkController.text.trim();
    if (remark.isEmpty) {
      _showSnackBar('请填写本次修改备注');
      return;
    }

    final items = <ProductParameterUpdateItem>[];
    final nameSet = <String>{};
    var hasProductNameParameter = false;
    for (final row in _editorRows) {
      final name = row.nameController.text.trim();
      final category = row.categoryController.text.trim();
      final parameterType = row.parameterType.trim();
      final value = row.valueController.text.trim();

      if (name.isEmpty) {
        _showSnackBar('参数名称不能为空');
        return;
      }
      if (category.isEmpty) {
        _showSnackBar('参数分类不能为空');
        return;
      }
      if (!_allowedCategorySet.contains(category)) {
        _showSnackBar('参数分类仅允许使用固定枚举');
        return;
      }
      if (parameterType != 'Text' && parameterType != 'Link') {
        _showSnackBar('参数类型必须是 Text 或 Link');
        return;
      }
      if (nameSet.contains(name)) {
        _showSnackBar('参数名称重复：$name');
        return;
      }
      if (_isProductNameParameterName(name)) {
        hasProductNameParameter = true;
      }
      nameSet.add(name);
      items.add(
        ProductParameterUpdateItem(
          name: name,
          category: category,
          type: parameterType,
          value: value,
          description: row.descriptionController.text.trim(),
        ),
      );
    }
    if (!hasProductNameParameter) {
      _showSnackBar('产品名称参数不可删除');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _editorSubmitting = true;
      _editorMessage = '';
    });

    try {
      ProductParameterUpdateResult result;
      try {
        result = await _productService.updateProductParameters(
          productId: target.productId,
          version: target.version,
          remark: remark,
          items: items,
        );
      } on ApiException catch (error) {
        if (!error.message.contains('Impact confirmation required')) {
          rethrow;
        }
        final impact = await _productService.getProductImpactAnalysis(
          productId: target.productId,
          operation: 'update_parameters',
        );
        final confirmed = await _confirmImpactForEffectiveUpdate(impact);
        if (!confirmed) {
          if (mounted) {
            setState(() {
              _editorSubmitting = false;
            });
          }
          return;
        }
        result = await _productService.updateProductParameters(
          productId: target.productId,
          version: target.version,
          remark: remark,
          items: items,
          confirmed: true,
        );
      }
      if (!mounted) {
        return;
      }
      final changed = result.changedKeys.isEmpty
          ? '-'
          : result.changedKeys.join(', ');
      _showSnackBar('更新成功，修改参数：$changed');

      await _exitEditor(force: true);
      await _loadProducts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _editorSubmitting = false;
        _editorMessage = '更新参数失败：${_errorMessage(error)}';
      });
    }
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildEditorTableHeader() {
    return Row(
      children: [
        _buildHeaderCell('参数名称', flex: 3),
        const SizedBox(width: 8),
        _buildHeaderCell('参数分类', flex: 3),
        const SizedBox(width: 8),
        _buildHeaderCell('参数类型', flex: 2),
        const SizedBox(width: 8),
        _buildHeaderCell('参数值', flex: 5),
        const SizedBox(width: 8),
        _buildHeaderCell('参数说明', flex: 3),
        const SizedBox(width: _rowActionColumnWidth),
      ],
    );
  }

  Widget _buildRowActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints.tightFor(
        width: _rowActionButtonSize,
        height: _rowActionButtonSize,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCategoryInput(_ParameterEditorRow row) {
    _attachCategoryDirtyListener(row);
    return DropdownMenu<String>(
      controller: row.categoryController,
      enabled: !_editorSubmitting && !_editorReadOnly,
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      dropdownMenuEntries: _buildCategorySuggestions()
          .map((value) => DropdownMenuEntry<String>(value: value, label: value))
          .toList(),
      onSelected: (_) => _markDirty(),
    );
  }

  Widget _buildDragHandle({required int index}) {
    final iconColor = (_editorSubmitting || _editorReadOnly)
        ? Theme.of(context).disabledColor
        : Theme.of(context).iconTheme.color;

    return Tooltip(
      message: '按住拖动排序',
      child: ReorderableDelayedDragStartListener(
        index: index,
        enabled: !_editorSubmitting && !_editorReadOnly,
        child: SizedBox(
          width: _rowActionButtonSize,
          height: _rowActionButtonSize,
          child: Center(
            child: Icon(Icons.drag_indicator, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorTableRow({
    required int index,
    required _ParameterEditorRow row,
  }) {
    final isProductNameRow = _isProductNameRow(row);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.nameController,
            readOnly: isProductNameRow || _editorReadOnly,
            onChanged: (isProductNameRow || _editorReadOnly)
                ? null
                : (_) => _markDirty(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _buildCategoryInput(row)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            key: ValueKey('type-$index-${row.parameterType}'),
            initialValue: row.parameterType,
            items: const [
              DropdownMenuItem(value: 'Text', child: Text('Text')),
              DropdownMenuItem(value: 'Link', child: Text('Link')),
            ],
            onChanged: (_editorSubmitting || _editorReadOnly)
                ? null
                : (value) {
                    if (value == null || value == row.parameterType) {
                      return;
                    }
                    setState(() {
                      row.parameterType = value;
                    });
                    _markDirty();
                  },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: row.parameterType == 'Link'
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.valueController,
                        readOnly: _editorReadOnly,
                        onChanged: _editorReadOnly ? null : (_) => _markDirty(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: (_editorSubmitting || _editorReadOnly)
                          ? null
                          : () => _pickLinkValue(row),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('浏览'),
                    ),
                  ],
                )
              : TextField(
                  controller: row.valueController,
                  readOnly: _editorReadOnly,
                  onChanged: _editorReadOnly ? null : (_) => _markDirty(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.descriptionController,
            readOnly: _editorReadOnly,
            onChanged: _editorReadOnly ? null : (_) => _markDirty(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: '可选',
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _rowActionColumnWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildDragHandle(index: index),
              const SizedBox(width: _rowActionGap),
              _buildRowActionIconButton(
                icon: Icons.delete_outline,
                tooltip: isProductNameRow ? '产品名称参数不可删除' : '删除',
                onPressed:
                    _editorSubmitting || _editorReadOnly || isProductNameRow
                    ? null
                    : () {
                        setState(() {
                          final removed = _editorRows.removeAt(index);
                          removed.dispose();
                        });
                        _markDirty();
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTableArea() {
    if (_editorLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleRows = _editorGroupFilter.isEmpty
        ? _editorRows
        : _editorRows
              .where(
                (r) => r.categoryController.text.trim() == _editorGroupFilter,
              )
              .toList();
    final isFiltered = _editorGroupFilter.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < _editorMinContentWidth
            ? _editorMinContentWidth
            : constraints.maxWidth;

        return Scrollbar(
          controller: _editorHorizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _editorHorizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditorTableHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: visibleRows.isEmpty
                        ? const Center(child: Text('暂无参数，请新增'))
                        : isFiltered
                        ? Scrollbar(
                            controller: _editorVerticalController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _editorVerticalController,
                              itemCount: visibleRows.length,
                              itemBuilder: (context, index) {
                                final row = visibleRows[index];
                                final realIndex = _editorRows.indexOf(row);
                                return Padding(
                                  key: ValueKey(row.rowId),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildEditorTableRow(
                                    index: realIndex,
                                    row: row,
                                  ),
                                );
                              },
                            ),
                          )
                        : Scrollbar(
                            controller: _editorVerticalController,
                            thumbVisibility: true,
                            child: ReorderableListView.builder(
                              scrollController: _editorVerticalController,
                              buildDefaultDragHandles: false,
                              itemCount: _editorRows.length,
                              onReorder: (oldIndex, newIndex) {
                                if (_editorSubmitting || _editorReadOnly) {
                                  return;
                                }
                                setState(() {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = _editorRows.removeAt(oldIndex);
                                  _editorRows.insert(newIndex, item);
                                });
                                _markDirty();
                              },
                              itemBuilder: (context, index) {
                                final row = _editorRows[index];
                                return Padding(
                                  key: ValueKey(row.rowId),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildEditorTableRow(
                                    index: index,
                                    row: row,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorFooterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _editorSubmitting ? null : _exitEditor,
          child: const Text('取消'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: (_editorSubmitting || _editorReadOnly)
              ? null
              : _saveEditor,
          child: _editorSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存参数'),
        ),
      ],
    );
  }

  Widget _buildEditorView(ThemeData theme) {
    final target = _editingTarget!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _editorSubmitting ? null : _exitEditor,
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回列表'),
            ),
            const SizedBox(width: 8),
            Text(
              '编辑版本参数 - ${target.productName}（${_editingVersionLabel.isEmpty ? target.versionLabel : _editingVersionLabel}）',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            if (_editingLifecycleStatus.isNotEmpty)
              Chip(
                label: Text(
                  _editingLifecycleStatus == 'draft' ? '草稿可编辑' : '非草稿只读',
                ),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: 8),
            if (_hasUnsavedChanges)
              Chip(
                label: const Text('有未保存修改'),
                backgroundColor: theme.colorScheme.secondaryContainer,
                visualDensity: VisualDensity.compact,
              ),
            const Spacer(),
            SizedBox(
              width: 180,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '参数分组筛选',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _editorGroupFilter,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('全部分组'),
                      ),
                      ..._buildCategorySuggestions().map(
                        (c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _editorGroupFilter = value ?? '';
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '刷新参数',
              onPressed: _editorSubmitting
                  ? null
                  : () => _enterEditor(
                      target,
                      requestedVersionLabel: _editingVersionLabel.isEmpty
                          ? null
                          : _editingVersionLabel,
                    ),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_editorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _editorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_editorReadOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '当前版本不是草稿，参数仅可查看。如需修改，请先在版本管理中复制或新建草稿版本。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildEditorTableArea()),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: (_editorSubmitting || _editorReadOnly)
                          ? null
                          : () {
                              setState(() {
                                final row = _ParameterEditorRow.empty(
                                  rowId: _nextEditorRowId(),
                                );
                                _attachCategoryDirtyListener(row);
                                _editorRows = [..._editorRows, row];
                              });
                              _markDirty();
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('新增参数'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarkController,
                    maxLines: 2,
                    readOnly: _editorReadOnly,
                    onChanged: _editorReadOnly ? null : (_) => _markDirty(),
                    decoration: const InputDecoration(
                      labelText: '本次修改备注（必填）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEditorFooterActions(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(ThemeData theme) {
    final rows = _filteredVersionRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '版本参数列表',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _loadProducts,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索产品名称',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadProducts(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategoryFilter,
                decoration: const InputDecoration(
                  labelText: '分类筛选',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: '贴片', child: Text('贴片')),
                  DropdownMenuItem<String>(value: 'DTU', child: Text('DTU')),
                  DropdownMenuItem<String>(value: '套件', child: Text('套件')),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCategoryFilter = value ?? '';
                        });
                        _loadProducts();
                      },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _loadProducts,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _versionFilterController,
                decoration: const InputDecoration(
                  labelText: '版本号筛选',
                  hintText: '如 V1.2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _paramNameFilterController,
                decoration: const InputDecoration(
                  labelText: '参数摘要筛选',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadProducts(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _paramCategoryFilterController,
                decoration: const InputDecoration(
                  labelText: '摘要补充筛选',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadProducts(),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _updatedAfter ??
                            DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        helpText: '修改起始日期',
                      );
                      if (picked != null) {
                        setState(() => _updatedAfter = picked);
                      }
                    },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _updatedAfter != null
                    ? '起始：${_formatTime(_updatedAfter!).substring(0, 10)}'
                    : '修改起始日期',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _updatedBefore ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        helpText: '修改截止日期',
                      );
                      if (picked != null) {
                        setState(
                          () => _updatedBefore = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                            59,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _updatedBefore != null
                    ? '截止：${_formatTime(_updatedBefore!).substring(0, 10)}'
                    : '修改截止日期',
              ),
            ),
            if (_updatedAfter != null || _updatedBefore != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _updatedAfter = null;
                    _updatedBefore = null;
                  });
                },
                child: const Text('清除日期'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text('总数：$_total', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('首屏按版本行展示，查看/编辑/历史/导出均绑定当前版本行。', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
              ? const Center(child: Text('暂无版本参数记录'))
              : Card(
                  child: AdaptiveTableContainer(
                    child: UnifiedListTableHeaderStyle.wrap(
                      theme: theme,
                      child: DataTable(
                        columns: [
                          UnifiedListTableHeaderStyle.column(context, '产品名称'),
                          UnifiedListTableHeaderStyle.column(
                            context,
                            '版本标签/版本号',
                          ),
                          UnifiedListTableHeaderStyle.column(context, '版本状态'),
                          UnifiedListTableHeaderStyle.column(context, '参数摘要'),
                          UnifiedListTableHeaderStyle.column(context, '更新时间'),
                          UnifiedListTableHeaderStyle.column(
                            context,
                            '操作',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        rows: rows.map((row) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  row.productCategory.isEmpty
                                      ? row.productName
                                      : '${row.productName} / ${row.productCategory}',
                                ),
                              ),
                              DataCell(
                                Text('${row.versionLabel} / #${row.version}'),
                              ),
                              DataCell(
                                Text(
                                  [
                                    _lifecycleLabel(row.lifecycleStatus),
                                    if (row.isCurrentVersion) '当前版本',
                                    if (row.isEffectiveVersion) '生效版本',
                                  ].join(' / '),
                                ),
                              ),
                              DataCell(Text(row.parameterSummary ?? '-')),
                              DataCell(Text(_formatTime(row.updatedAt))),
                              DataCell(
                                UnifiedListTableHeaderStyle.actionMenuButton<
                                  _ProductParameterManagementListAction
                                >(
                                  theme: theme,
                                  onSelected: (action) {
                                    _handleListAction(action, row);
                                  },
                                  itemBuilder: (context) =>
                                      _buildListActionMenuItems(),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _editingTarget == null
          ? _buildListView(theme)
          : _buildEditorView(theme),
    );
  }
}

class _ParameterEditorRow {
  _ParameterEditorRow.initial({
    required this.rowId,
    required String name,
    required String category,
    required String parameterType,
    required String value,
    required String description,
  }) : nameController = TextEditingController(text: name),
       categoryController = TextEditingController(text: category),
       valueController = TextEditingController(text: value),
       descriptionController = TextEditingController(text: description),
       parameterType = parameterType == 'Link' ? 'Link' : 'Text';

  _ParameterEditorRow.empty({required this.rowId})
    : nameController = TextEditingController(),
      categoryController = TextEditingController(),
      valueController = TextEditingController(),
      descriptionController = TextEditingController(),
      parameterType = 'Text';

  final int rowId;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController valueController;
  final TextEditingController descriptionController;
  String parameterType;
  bool categoryListenerBound = false;

  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    valueController.dispose();
    descriptionController.dispose();
  }
}
