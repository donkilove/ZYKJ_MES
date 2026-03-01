import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';
import '../widgets/adaptive_table_container.dart';

class ProductParameterManagementPage extends StatefulWidget {
  const ProductParameterManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.jumpCommand,
    this.onJumpHandled,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
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
    '自定义参数',
  ];
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
  List<ProductItem> _products = const [];

  int _handledJumpSeq = 0;

  ProductItem? _editingProduct;
  bool _editorLoading = false;
  bool _editorSubmitting = false;
  String _editorMessage = '';
  List<_ParameterEditorRow> _editorRows = const [];
  bool _hasUnsavedChanges = false;
  int _editorRowIdSeed = 1;

  @override
  void initState() {
    super.initState();
    _productService = ProductService(widget.session);
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

  ProductItem? _findProductById(int productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
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
    final suggestions = <String>{..._presetCategorySuggestions};
    for (final row in _editorRows) {
      final category = row.categoryController.text.trim();
      if (category.isNotEmpty) {
        suggestions.add(category);
      }
    }
    return suggestions.toList();
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
      final result = await _productService.listProducts(
        page: 1,
        pageSize: 100,
        keyword: _keywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = result.items;
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

  Future<void> _handleJumpCommand(ProductJumpCommand command) async {
    _keywordController.text = command.productName;
    await _loadProducts();
    if (!mounted) {
      return;
    }
    if (command.action == 'edit') {
      final product = _findProductById(command.productId);
      if (product != null) {
        await _enterEditor(product);
        if (mounted && _editingProduct?.id == command.productId) {
          widget.onJumpHandled?.call(command.seq);
        }
      }
    }
  }

  Future<void> _showHistoryDialog(ProductItem product) async {
    ProductParameterHistoryListResult? historyResult;
    try {
      historyResult = await _productService.listProductParameterHistory(
        productId: product.id,
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('历史修改备注 - ${product.name}'),
          content: SizedBox(
            width: 760,
            height: 480,
            child: historyResult!.items.isEmpty
                ? const Center(child: Text('暂无历史记录'))
                : ListView.separated(
                    itemCount: historyResult.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = historyResult!.items[index];
                      final keySummary = item.changedKeys.isEmpty
                          ? '-'
                          : item.changedKeys.join(', ');
                      return ListTile(
                        title: Text(item.remark),
                        subtitle: Text(
                          '时间：${_formatTime(item.createdAt)}\n'
                          '操作人：${item.operatorUsername}   修改参数：$keySummary',
                        ),
                        isThreeLine: true,
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

  Future<bool> _exitEditor({bool force = false}) async {
    if (_editingProduct == null) {
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
      _editingProduct = null;
      _editorLoading = false;
      _editorSubmitting = false;
      _editorMessage = '';
      _hasUnsavedChanges = false;
    });
    return true;
  }

  Future<void> _enterEditor(ProductItem product) async {
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
      _editingProduct = product;
      _editorLoading = true;
      _editorSubmitting = false;
      _editorMessage = '';
      _hasUnsavedChanges = false;
      _remarkController.clear();
    });

    ProductParameterListResult result;
    try {
      result = await _productService.listProductParameters(
        productId: product.id,
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
    final product = _editingProduct;
    if (product == null || _editorSubmitting) {
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
      final result = await _productService.updateProductParameters(
        productId: product.id,
        remark: remark,
        items: items,
      );
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
      enabled: !_editorSubmitting,
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
    final iconColor = _editorSubmitting
        ? Theme.of(context).disabledColor
        : Theme.of(context).iconTheme.color;

    return Tooltip(
      message: '按住拖动排序',
      child: ReorderableDelayedDragStartListener(
        index: index,
        enabled: !_editorSubmitting,
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
            readOnly: isProductNameRow,
            onChanged: isProductNameRow ? null : (_) => _markDirty(),
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
            onChanged: _editorSubmitting
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
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _editorSubmitting
                          ? null
                          : () => _pickLinkValue(row),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('浏览'),
                    ),
                  ],
                )
              : TextField(
                  controller: row.valueController,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
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
                onPressed: _editorSubmitting || isProductNameRow
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
                    child: _editorRows.isEmpty
                        ? const Center(child: Text('暂无参数，请新增'))
                        : Scrollbar(
                            controller: _editorVerticalController,
                            thumbVisibility: true,
                            child: ReorderableListView.builder(
                              scrollController: _editorVerticalController,
                              buildDefaultDragHandles: false,
                              itemCount: _editorRows.length,
                              onReorder: (oldIndex, newIndex) {
                                if (_editorSubmitting) {
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
          onPressed: _editorSubmitting ? null : _saveEditor,
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
    final product = _editingProduct!;
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
              '编辑产品参数 - ${product.name}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            if (_hasUnsavedChanges)
              Chip(
                label: const Text('有未保存修改'),
                backgroundColor: theme.colorScheme.secondaryContainer,
                visualDensity: VisualDensity.compact,
              ),
            const Spacer(),
            IconButton(
              tooltip: '刷新参数',
              onPressed: _editorSubmitting ? null : () => _enterEditor(product),
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
                      onPressed: _editorSubmitting
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
                    onChanged: (_) => _markDirty(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '产品参数管理',
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
            FilledButton.icon(
              onPressed: _loading ? null : _loadProducts,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('总数：$_total', style: theme.textTheme.titleMedium),
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
              : _products.isEmpty
              ? const Center(child: Text('暂无产品'))
              : Card(
                  child: AdaptiveTableContainer(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('产品名称')),
                        DataColumn(label: Text('创建时间')),
                        DataColumn(label: Text('最后修改时间')),
                        DataColumn(label: Text('最后修改参数')),
                        DataColumn(label: Text('历史修改参数备注')),
                        DataColumn(label: Text('编辑产品参数')),
                      ],
                      rows: _products.map((product) {
                        return DataRow(
                          cells: [
                            DataCell(Text(product.name)),
                            DataCell(Text(_formatTime(product.createdAt))),
                            DataCell(Text(_formatTime(product.updatedAt))),
                            DataCell(Text(product.lastParameterSummary ?? '-')),
                            DataCell(
                              TextButton(
                                onPressed: () => _showHistoryDialog(product),
                                child: const Text('查看历史'),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () => _enterEditor(product),
                                child: const Text('编辑参数'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
      child: _editingProduct == null
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
  }) : nameController = TextEditingController(text: name),
       categoryController = TextEditingController(text: category),
       valueController = TextEditingController(text: value),
       parameterType = parameterType == 'Link' ? 'Link' : 'Text';

  _ParameterEditorRow.empty({required this.rowId})
    : nameController = TextEditingController(),
      categoryController = TextEditingController(),
      valueController = TextEditingController(),
      parameterType = 'Text';

  final int rowId;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController valueController;
  String parameterType;
  bool categoryListenerBound = false;

  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    valueController.dispose();
  }
}
