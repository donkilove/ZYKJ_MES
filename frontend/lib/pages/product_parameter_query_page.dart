import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../models/app_session.dart';
import '../models/product_models.dart';
import '../services/api_exception.dart';
import '../services/product_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/unified_list_table_header_style.dart';

const List<String> _productCategoryOptions = ['贴片', 'DTU', '套件'];

enum _ProductParameterQueryListAction { view }

class ProductParameterQueryPage extends StatefulWidget {
  const ProductParameterQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.jumpCommand,
    this.onJumpHandled,
    this.service,
    this.canExportParameters = false,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductJumpCommand? jumpCommand;
  final ValueChanged<int>? onJumpHandled;
  final ProductService? service;
  final bool canExportParameters;

  @override
  State<ProductParameterQueryPage> createState() =>
      _ProductParameterQueryPageState();
}

class _ProductParameterQueryPageState extends State<ProductParameterQueryPage> {
  late final ProductService _productService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<ProductItem> _products = const [];
  int _handledJumpSeq = 0;
  String _selectedCategoryFilter = '';
  String _selectedStatusFilter = '';
  final TextEditingController _versionFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _productService = widget.service ?? ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductParameterQueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final command = widget.jumpCommand;
    if (command == null) {
      return;
    }
    if (command.seq == _handledJumpSeq) {
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
    _keywordController.dispose();
    _versionFilterController.dispose();
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

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  String _lifecycleLabel(String value) {
    switch (value) {
      case 'active':
      case 'effective':
        return '启用';
      case 'inactive':
        return '停用';
      default:
        return value;
    }
  }

  List<PopupMenuEntry<_ProductParameterQueryListAction>>
  _buildListActionMenuItems() {
    return const [
      PopupMenuItem(
        value: _ProductParameterQueryListAction.view,
        child: Text('查看参数'),
      ),
    ];
  }

  Future<void> _handleListAction(
    _ProductParameterQueryListAction action,
    ProductItem product,
  ) async {
    switch (action) {
      case _ProductParameterQueryListAction.view:
        await _showParametersDialog(product);
        return;
    }
  }

  ProductItem? _findProductById(int productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _productService.listProductsForParameterQuery(
        page: 1,
        pageSize: 10000,
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        lifecycleStatus: _selectedStatusFilter,
        effectiveVersionKeyword: _versionFilterController.text.trim(),
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

  List<ProductItem> get _filteredProducts {
    return _products;
  }

  Future<void> _handleJumpCommand(ProductJumpCommand command) async {
    _keywordController.text = command.productName;
    await _loadProducts();
    if (!mounted) {
      return;
    }
    if (command.action == 'view') {
      final product = _findProductById(command.productId);
      if (product != null) {
        await _showParametersDialog(product);
        if (mounted) {
          widget.onJumpHandled?.call(command.seq);
        }
      }
    }
  }

  String _linkDisplayName(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return '-';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final pathSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      if (pathSegment.isNotEmpty) {
        return Uri.decodeComponent(pathSegment);
      }
      return uri.host.isEmpty ? value : uri.host;
    }
    final filename = p.basename(value);
    return filename.isEmpty ? value : filename;
  }

  Future<void> _openLink(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return;
    }

    Uri uri;
    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      uri = parsed;
    } else {
      uri = Uri.file(value, windows: true);
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：$value')));
    }
  }

  Widget _buildParameterValueCell(ProductParameterItem item) {
    final value = item.value.trim();
    if (item.type != 'Link') {
      return Text(value.isEmpty ? '-' : value);
    }
    if (value.isEmpty) {
      return const Text('-');
    }
    return TextButton(
      onPressed: () => _openLink(value),
      child: Text(_linkDisplayName(value), overflow: TextOverflow.ellipsis),
    );
  }

  Future<void> _exportParameters() async {
    try {
      final bytes = await _productService.exportProductParameters(
        keyword: _keywordController.text.trim(),
        category: _selectedCategoryFilter,
        lifecycleStatus: _selectedStatusFilter,
        versionKeyword: _versionFilterController.text.trim(),
        effectiveOnly: true,
      );
      final fileName = '产品参数查询_${DateTime.now().millisecondsSinceEpoch}.csv';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: fileName,
      );
      await file.saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：${_errorMessage(error)}')),
        );
      }
    }
  }

  Future<void> _showParametersDialog(ProductItem product) async {
    if (product.effectiveVersion == 0) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('产品参数 - ${product.name}'),
            content: const SizedBox(
              width: 420,
              child: Text('该产品暂无生效版本，无法查看参数。\n请先在产品管理中激活一个版本。'),
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
      return;
    }

    ProductParameterListResult result;
    try {
      result = await _productService.listProductParameters(
        productId: product.id,
        effectiveOnly: true,
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载参数失败：${_errorMessage(error)}')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('产品参数 - ${product.name}（${result.versionLabel}）'),
          content: SizedBox(
            width: 1000,
            height: 520,
            child: result.items.isEmpty
                ? const Center(child: Text('该产品暂无参数'))
                : AdaptiveTableContainer(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('参数名称')),
                        DataColumn(label: Text('参数分类')),
                        DataColumn(label: Text('参数类型')),
                        DataColumn(label: Text('参数值')),
                        DataColumn(label: Text('参数说明')),
                      ],
                      rows: result.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.name)),
                            DataCell(Text(item.category)),
                            DataCell(Text(item.type)),
                            DataCell(_buildParameterValueCell(item)),
                            DataCell(Text(item.description.isEmpty ? '-' : item.description)),
                          ],
                        );
                      }).toList(),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '产品参数查询',
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
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('全部')),
                    ..._productCategoryOptions.map(
                      (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                    ),
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
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  decoration: const InputDecoration(
                    labelText: '状态筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(value: '', child: Text('全部')),
                    DropdownMenuItem<String>(value: 'active', child: Text('启用')),
                    DropdownMenuItem<String>(value: 'inactive', child: Text('停用')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedStatusFilter = value ?? '';
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
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loading || !widget.canExportParameters
                    ? null
                    : _exportParameters,
                icon: const Icon(Icons.download),
                label: const Text('导出'),
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
                    labelText: '生效版本号筛选',
                    hintText: '如 V1.2',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadProducts(),
                ),
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
                      child: UnifiedListTableHeaderStyle.wrap(
                        theme: theme,
                        child: DataTable(
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '产品名称'),
                            UnifiedListTableHeaderStyle.column(context, '产品分类'),
                            UnifiedListTableHeaderStyle.column(context, '生效版本'),
                            UnifiedListTableHeaderStyle.column(context, '当前状态'),
                            UnifiedListTableHeaderStyle.column(context, '创建时间'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '操作',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          rows: _filteredProducts.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.category.isEmpty ? '-' : product.category)),
                                DataCell(
                                  Text(
                                    product.effectiveVersionLabel ??
                                        (product.effectiveVersion > 0
                                            ? 'V1.${product.effectiveVersion - 1}'
                                            : '-'),
                                  ),
                                ),
                                DataCell(Text(_lifecycleLabel(product.lifecycleStatus))),
                                DataCell(Text(_formatTime(product.createdAt))),
                                DataCell(
                                  UnifiedListTableHeaderStyle.actionMenuButton<
                                    _ProductParameterQueryListAction
                                  >(
                                    theme: theme,
                                    onSelected: (action) {
                                      _handleListAction(action, product);
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
      ),
    );
  }
}
