import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_footer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_table.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_toolbar.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_dialog.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart'
    show
        ProductParameterManagementListAction,
        ProductParameterVersionTableSection;
import 'package:mes_client/features/product/services/product_service.dart';

class ProductParameterManagementPage extends StatefulWidget {
  const ProductParameterManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.service,
    this.jumpCommand,
    this.onJumpHandled,
    this.canExportParameters = false,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductService? service;
  final ProductJumpCommand? jumpCommand;
  final ValueChanged<int>? onJumpHandled;
  final bool canExportParameters;

  @override
  State<ProductParameterManagementPage> createState() =>
      _ProductParameterManagementPageState();
}

class _ProductParameterManagementPageState
    extends State<ProductParameterManagementPage> {
  static const int _listPageSize = 200;
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
  static final RegExp _linkValuePattern = RegExp(
    r'^(https?://|\\\\|[A-Za-z]:[/\\])',
    caseSensitive: false,
  );

  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  final TextEditingController _remarkController = TextEditingController();
  final ScrollController _editorVerticalController = ScrollController();
  final ScrollController _editorHorizontalController = ScrollController();

  bool _loading = false;
  String _message = '';
  List<ProductParameterVersionListItem> _versionRows = const [];
  String _selectedCategoryFilter = '';

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
      case 'add':
        return '新增';
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

  String? _validateLinkValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (_linkValuePattern.hasMatch(trimmed)) {
      return null;
    }
    return 'Link 参数仅支持 http://、https://、\\\\、盘符绝对路径';
  }

  void _handleEditorValueChanged(_ParameterEditorRow row, String value) {
    if (row.parameterType == 'Link') {
      setState(() {});
    }
    _markDirty();
  }

  List<PopupMenuEntry<ProductParameterManagementListAction>>
  _buildListActionMenuItems() {
    return [
      PopupMenuItem(
        value: ProductParameterManagementListAction.view,
        child: Text('查看参数'),
      ),
      PopupMenuItem(
        value: ProductParameterManagementListAction.history,
        child: Text('查看历史'),
      ),
      PopupMenuItem(
        value: ProductParameterManagementListAction.edit,
        child: Text('编辑参数'),
      ),
      if (widget.canExportParameters)
        const PopupMenuItem(
          value: ProductParameterManagementListAction.export,
          child: Text('导出参数'),
        ),
    ];
  }

  Future<void> _handleListAction(
    ProductParameterManagementListAction action,
    ProductParameterVersionListItem row,
  ) async {
    switch (action) {
      case ProductParameterManagementListAction.view:
        await _enterEditor(row);
        return;
      case ProductParameterManagementListAction.history:
        await _showHistoryDialog(row);
        return;
      case ProductParameterManagementListAction.edit:
        await _enterEditor(row);
        return;
      case ProductParameterManagementListAction.export:
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
        pageSize: _listPageSize,
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _versionRows = result.items;
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
    return _versionRows;
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
        return ProductParameterHistoryDialog(
          row: row,
          history: dialogHistory,
          formatTime: _formatTime,
          historyTypeLabel: _historyTypeLabel,
          onClose: () => Navigator.of(context).pop(),
          onViewSnapshot: (item) {
            showDialog<void>(
              context: context,
              builder: (snapshotContext) {
                return ProductParameterHistorySnapshotDialog(
                  item: item,
                  onClose: () => Navigator.of(snapshotContext).pop(),
                );
              },
            );
          },
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
        return MesActionDialog(
          title: const Text('放弃未保存的修改？'),
          content: const Text('当前编辑内容尚未保存，离开后将丢失本次修改。'),
          cancelLabel: '继续编辑',
          confirmLabel: '放弃修改',
          isDestructive: true,
          onConfirm: () => Navigator.of(context).pop(true),
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
        return MesActionDialog(
          title: const Text('变更影响确认'),
          width: 520,
          content: Column(
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
          confirmLabel: '确认继续',
          onConfirm: () => Navigator.of(context).pop(true),
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
      if (parameterType == 'Link') {
        final linkError = _validateLinkValue(value);
        if (linkError != null) {
          _showSnackBar(linkError);
          return;
        }
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
    final linkError = row.parameterType == 'Link'
        ? _validateLinkValue(row.valueController.text)
        : null;
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
                        onChanged: _editorReadOnly
                            ? null
                            : (value) => _handleEditorValueChanged(row, value),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: '支持 http://、https://、\\\\、C:\\',
                          errorText: linkError,
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
                  onChanged: _editorReadOnly
                      ? null
                      : (value) => _handleEditorValueChanged(row, value),
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
      return const MesLoadingState(label: '参数编辑器加载中...');
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

  Widget _buildEditorView(ThemeData theme) {
    final target = _editingTarget!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductParameterEditorHeader(
          productName: target.productName,
          versionLabel: _editingVersionLabel.isEmpty
              ? target.versionLabel
              : _editingVersionLabel,
          lifecycleStatus: _editingLifecycleStatus,
          hasUnsavedChanges: _hasUnsavedChanges,
          onBack: _editorSubmitting ? null : _exitEditor,
        ),
        const SizedBox(height: 12),
        ProductParameterEditorToolbar(
          groupFilter: _editorGroupFilter,
          categorySuggestions: _buildCategorySuggestions(),
          hasUnsavedChanges: _hasUnsavedChanges,
          onGroupChanged: (value) {
            setState(() {
              _editorGroupFilter = value;
            });
          },
          onRefresh: () => _enterEditor(
            target,
            requestedVersionLabel: _editingVersionLabel.isEmpty
                ? null
                : _editingVersionLabel,
          ),
          refreshEnabled: !_editorSubmitting,
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
                  Expanded(
                    child: ProductParameterEditorTable(
                      child: _buildEditorTableArea(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProductParameterEditorFooter(
                    remarkController: _remarkController,
                    editorReadOnly: _editorReadOnly,
                    editorSubmitting: _editorSubmitting,
                    onAddRow: () {
                      setState(() {
                        final row = _ParameterEditorRow.empty(
                          rowId: _nextEditorRowId(),
                        );
                        _attachCategoryDirtyListener(row);
                        _editorRows = [..._editorRows, row];
                      });
                      _markDirty();
                    },
                    onCancel: _exitEditor,
                    onSave: _saveEditor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final rows = _filteredVersionRows;
    return MesCrudPageScaffold(
      header: ProductParameterManagementPageHeader(
        loading: _loading,
        onRefresh: _loadProducts,
      ),
      filters: ProductParameterManagementFilterSection(
        keywordController: _keywordController,
        selectedCategory: _selectedCategoryFilter,
        loading: _loading,
        onCategoryChanged: (value) {
          setState(() {
            _selectedCategoryFilter = value;
          });
          _loadProducts();
        },
        onSearch: _loadProducts,
      ),
      banner: _message.isEmpty
          ? null
          : ProductParameterManagementFeedbackBanner(message: _message),
      content: ProductParameterVersionTableSection(
        rows: rows,
        loading: _loading,
        emptyText: '暂无版本参数记录',
        formatTime: _formatTime,
        buildActionItems: (row) => _buildListActionMenuItems(),
        onSelected: _handleListAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _editingTarget == null
          ? _buildListView()
          : _buildEditorView(Theme.of(context)),
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
